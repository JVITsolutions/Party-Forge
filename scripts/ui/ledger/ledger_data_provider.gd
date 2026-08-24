class_name LedgerDataProvider
extends RefCounted

signal data_changed(member_id: int)
signal party_changed

const GROUP_ORDER: Array[StringName] = [&"overview", &"attributes", &"offense", &"defense", &"resistances", &"utility"]

var party: PartyManager
var catalog: GameCatalog
var health_provider: Callable
var progression_provider: Callable
var progression_context: PlayerRunContext
var item_context: PlayerRunContext
var equipment_catalog: EquipmentCatalog
var item_foundation: ItemFoundationCatalog
var _health_components: Dictionary = {}
var _suppressed_item_member_id := 0

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if progression_context != null and is_instance_valid(progression_context):
		var callback := Callable(self, "_on_progression_changed")
		if progression_context.progression_changed.is_connected(callback):
			progression_context.progression_changed.disconnect(callback)
	progression_context = null
	progression_provider = Callable()
	item_context = null
	equipment_catalog = null
	item_foundation = null

func configure(
	manager: PartyManager,
	game_catalog: GameCatalog,
	runtime_health: Callable,
	progression_provider: Callable = Callable(),
	progression_context: PlayerRunContext = null,
	item_context: PlayerRunContext = null,
	equipment_catalog: EquipmentCatalog = null,
	item_foundation: ItemFoundationCatalog = null,
) -> void:
	_disconnect_party()
	_disconnect_progression_context()
	party = manager
	catalog = game_catalog
	health_provider = runtime_health
	self.progression_provider = progression_provider
	self.progression_context = progression_context
	self.item_context = item_context
	self.equipment_catalog = equipment_catalog
	self.item_foundation = item_foundation
	if party != null:
		party.member_added.connect(_on_member_added)
		party.stats_changed.connect(_on_stats_changed)
		party.upgrades_changed.connect(_on_upgrades_changed)
		party.class_rank_changed.connect(_on_class_rank_changed)
		party.active_traits_changed.connect(_on_traits_changed)
	if self.progression_context != null:
		self.progression_context.progression_changed.connect(_on_progression_changed)

func member_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if party == null:
		return rows
	for member: PartyMemberState in party.members:
		var health: Dictionary = health_provider.call(member.member_id) if health_provider.is_valid() else {}
		_observe_health_component(member.member_id, health.get("component") as HealthComponent)
		var row := {
			"member_id": member.member_id,
			"character_name": member.character_name,
			"class_name": member.class_definition.display_name,
			"class_color": member.class_definition.color,
			"class_rank": party.get_class_rank(member.class_definition.id),
			"role_name": UpgradePresentationService.role_name(member.class_definition.role),
			"health_current": float(health.get("current", 0.0)),
			"health_maximum": float(health.get("maximum", 0.0)),
			"is_downed": bool(health.get("is_downed", false)),
			"is_dead": bool(health.get("is_dead", false)),
			"traits": member.class_definition.traits.duplicate(),
			"capabilities": member.capability_tags.duplicate(),
		}
		var progression := progression_provider.call(member.member_id) as CharacterProgressionState if progression_provider.is_valid() else null
		var required := ExperienceSystem.DEFAULT_TUNING.requirement_for_level(1)
		if progression != null:
			required = progression.experience_required
		row["character_level"] = progression.level if progression != null else 1
		row["experience"] = progression.experience if progression != null else 0
		row["experience_required"] = required
		row["experience_fraction"] = float(row.experience) / float(maxi(required, 1))
		row["guaranteed_growth_count"] = progression.guaranteed_growth_history.size() if progression != null else 0
		row["milestone_count"] = progression.milestone_outcomes.size() if progression != null else 0
		rows.append(row)
	return rows

func stat_rows(member_id: int, show_all := false) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var snapshot := party.stats_for(member_id) if party != null else null
	if snapshot == null:
		return rows
	for definition: StatDefinition in PartyManager.STAT_CATALOG.all():
		var breakdown := snapshot.breakdown(definition.id)
		if not show_all and not _is_visible(definition, snapshot, breakdown):
			continue
		rows.append({
			"stat_id": definition.id,
			"group_id": definition.ui_group,
			"display_name": definition.display_name,
			"value": snapshot.value(definition.id, definition.default_value),
			"formatted_value": definition.format_value(snapshot.value(definition.id, definition.default_value)),
			"keyword_id": definition.keyword_id,
			"sort_key": "%02d|%s" % [_group_index(definition.ui_group), definition.display_name],
		})
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.sort_key < right.sort_key)
	return rows

func stat_detail(member_id: int, stat_id: StringName) -> Dictionary:
	var definition := PartyManager.STAT_CATALOG.definition(stat_id)
	var snapshot := party.stats_for(member_id) if party != null else null
	if definition == null or snapshot == null:
		return {"title": "Missing definition: %s" % stat_id, "sources": []}
	var keyword := catalog.keywords.definition(definition.keyword_id) if catalog != null and catalog.keywords != null else null
	return {
		"title": definition.display_name,
		"value_text": definition.format_value(snapshot.value(stat_id, definition.default_value)),
		"description": keyword.explanation if keyword != null else "Missing definition: %s" % definition.keyword_id,
		"cap_text": _cap_text(definition),
		"sources": _formatted_breakdown(definition, snapshot.breakdown(stat_id)),
	}

func _formatted_breakdown(definition: StatDefinition, rows: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Dictionary in rows:
		var row := source.duplicate(true)
		var operation := int(row.get("operation", -1))
		var value := float(row.get("value", 0.0))
		if operation == -1:
			row["formatted_value"] = definition.format_value(value)
		elif operation == StatModifier.Operation.FLAT:
			row["formatted_value"] = definition.format_modifier_value(absf(value))
			row["formatted_modifier"] = "%s%s" % ["+" if value >= 0.0 else "-", definition.format_modifier_value(absf(value))]
		else:
			row["formatted_value"] = _number_text(absf(value) * 100.0) + "%"
			var operation_label: String = {
				StatModifier.Operation.INCREASED: "increased",
				StatModifier.Operation.REDUCED: "reduced",
				StatModifier.Operation.MORE: "more",
				StatModifier.Operation.LESS: "less",
			}.get(operation, "")
			row["formatted_modifier"] = "%s%s%% %s" % [
				"+" if value >= 0.0 else "-", _number_text(absf(value) * 100.0), operation_label,
			]
		result.append(row)
	return result

func combat_estimate_rows(member_id: int) -> Array[ActionCombatEstimate]:
	var rows: Array[ActionCombatEstimate] = []
	var member := party.member_by_id(member_id) if party != null else null
	if member == null or catalog == null:
		return rows
	for attack: AttackDefinition in member.class_definition.owned_actions():
		if attack == null or (not attack.is_healing() and attack.damage_components.is_empty()):
			continue
		rows.append(ActionCombatEstimateService.estimate(attack, member_id, party, catalog.damage_types))
	return rows

func upgrade_rows(member_id: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var member := party.member_by_id(member_id) if party != null else null
	if member == null or catalog == null:
		return rows
	for definition: UpgradeDefinition in catalog.upgrades:
		var owner_id := member_id if definition.is_single_recipient() else 0
		var rank := party.upgrade_rank(definition.id, owner_id)
		if rank <= 0 or not definition.is_member_eligible(member):
			continue
		rows.append(_authored_upgrade_row(definition, rank))
	for stat_id: StringName in PartyManager.PARTY_STAT_IDS:
		var rank := party.party_stat_rank(stat_id)
		if rank > 0:
			rows.append(_party_stat_row(stat_id, rank))
	for trait_id: StringName in member.class_definition.traits:
		if party.active_tier(trait_id) > 0:
			rows.append(_trait_row(trait_id))
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.sort_key < right.sort_key)
	return rows

func upgrade_detail(row: Dictionary) -> Dictionary:
	var definition := row.get("definition") as UpgradeDefinition
	if definition != null:
		var content := UpgradePresentationService.owned_tooltip(definition, int(row.rank), PartyManager.STAT_CATALOG, catalog.keywords)
		content["ownership"] = row.get("ownership", "")
		content["applicability"] = row.get("applicability", "")
		return content
	return {
		"title": row.get("display_name", ""),
		"rank_text": row.get("rank_text", ""),
		"ownership": row.get("ownership", ""),
		"description": row.get("description", ""),
		"effect_lines": row.get("effect_lines", []),
		"applicability": row.get("applicability", ""),
		"eligibility_text": row.get("applicability", ""),
		"inheritance_text": "",
		"keyword_lines": [],
	}

func inventory_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var state := _owned_item_state()
	var container := item_context.run_inventory() if state != null else null
	if container == null or container.owner_id != state.owner_id:
		return rows
	for slot: int in container.capacity:
		var item_id := container.item_id_at(slot)
		rows.append({
			"container_id": container.container_id,
			"slot": slot,
			"item_id": item_id,
			"detail": _project_item(item_id, 0),
		})
	return rows.duplicate(true)

func equipment_rows(member_id: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var state := _owned_item_state()
	var container := item_context.equipment_for(member_id) if state != null else null
	if container != null and container.owner_id != state.owner_id:
		container = null
	for slot_id: StringName in EquipmentSlotCatalog.SHEET_SLOT_IDS:
		var slot := EquipmentSlotIndex.index_for(slot_id)
		var item_id := container.item_id_at(slot) if container != null else ""
		rows.append({
			"container_id": container.container_id if container != null else StringName("run-equipment-%03d" % member_id),
			"slot_id": slot_id,
			"slot": slot,
			"item_id": item_id,
			"detail": _project_item(item_id, member_id),
		})
	return rows.duplicate(true)

func item_detail(item_id: String, member_id: int) -> Dictionary:
	return _project_item(item_id, member_id).duplicate(true)

func comparison_rows(item_id: String, member_id: int) -> Array[Dictionary]:
	var state := _owned_item_state()
	var item := _owned_item(item_id, state)
	var member := party.member_by_id(member_id) if party != null else null
	if item == null or member == null or equipment_catalog == null or item_foundation == null:
		return []
	var base := equipment_catalog.definition(item.base_definition_id)
	if base == null:
		return []
	var preview: EquipmentTransitionResult
	for slot_id: StringName in base.compatible_slot_ids:
		var candidate := item_context.preview_equipment_assignment(
			member_id,
			item_id,
			slot_id,
			equipment_catalog,
			item_foundation,
		)
		if candidate.ok():
			preview = candidate
			break
	if preview == null or not preview.ok():
		return []
	var current_stats := party.stats_for(member_id)
	var candidate_resolution := preview.resolution()
	var current_activation := item_context.equipment_activation(member_id)
	var candidate_activation := preview.activation()
	if current_stats == null or candidate_resolution == null or not candidate_resolution.ok() or not current_activation.ok() or not candidate_activation.ok():
		return []
	var rows := EquipmentComparisonProjectionService.compare(
		current_stats,
		candidate_resolution.final_stats,
		GameCatalog.STAT_CATALOG,
		combat_estimate_rows(member_id),
		[],
		current_activation,
		candidate_activation,
		item_id,
		_item_labels(state, member_id),
		_disabled_lines_by_item(preview.state(), candidate_activation),
		catalog.damage_types if catalog != null else GameCatalog.DAMAGE_TYPES,
	)
	return rows.duplicate(true)

func move_or_equip(request: Dictionary) -> Dictionary:
	var member_id := int(request.get("member_id", 0))
	if item_context == null or equipment_catalog == null or item_foundation == null or member_id <= 0:
		return {"accepted": false, "error": "PARTY_FORGE_LEDGER_ITEM_ERROR reason=invalid request"}
	var transaction := request.get("transaction") as ItemTransactionRequest
	if transaction != null:
		var transaction_result := item_context.apply_item_transaction(transaction, equipment_catalog, item_foundation)
		var accepted := transaction_result != null and transaction_result.ok()
		if accepted:
			data_changed.emit(member_id)
		return {
			"accepted": accepted,
			"code": int(transaction_result.code) if transaction_result != null else int(ItemTransactionResult.Code.INVALID_REQUEST),
			"duplicate": transaction_result.duplicate if transaction_result != null else false,
		}
	var item_id := String(request.get("item_id", ""))
	var slot_id := StringName(String(request.get("slot_id", "")))
	if item_id.is_empty():
		return {"accepted": false, "error": "PARTY_FORGE_LEDGER_ITEM_ERROR reason=invalid request"}
	var exact_keys: Array[String] = ["source_container_id", "source_slot", "destination_container_id", "destination_slot"]
	var exact_requested := exact_keys.any(func(key: String) -> bool: return request.has(key))
	if exact_requested and not exact_keys.all(func(key: String) -> bool: return request.has(key)):
		return {"accepted": false, "error": "PARTY_FORGE_LEDGER_ITEM_ERROR reason=incomplete exact endpoints"}
	_suppressed_item_member_id = member_id
	var assignment: EquipmentAssignmentResult
	if exact_requested:
		assignment = item_context.assign_equipment_exact(
			member_id,
			item_id,
			StringName(String(request.get("source_container_id", ""))),
			int(request.get("source_slot", -1)),
			StringName(String(request.get("destination_container_id", ""))),
			int(request.get("destination_slot", -1)),
			equipment_catalog,
			item_foundation,
		)
	else:
		assignment = item_context.assign_equipment(member_id, item_id, slot_id, equipment_catalog, item_foundation)
	_suppressed_item_member_id = 0
	var accepted := assignment != null and assignment.ok()
	if accepted:
		data_changed.emit(member_id)
	return {
		"accepted": accepted,
		"error": assignment.error if assignment != null else "PARTY_FORGE_LEDGER_ITEM_ERROR reason=assignment unavailable",
	}

func _owned_item_state() -> ItemOwnershipState:
	if item_context == null or not is_instance_valid(item_context):
		return null
	var state := item_context.item_state()
	if state == null or state.owner_id != String(item_context.run_player_id):
		return null
	return state

func _owned_item(item_id: String, state: ItemOwnershipState = null) -> ItemInstance:
	if item_id.strip_edges().is_empty():
		return null
	var owned_state := state if state != null else _owned_item_state()
	var registry := owned_state.registry() if owned_state != null else null
	return registry.item(item_id) if registry != null else null

func _project_item(item_id: String, member_id: int) -> Dictionary:
	var state := _owned_item_state()
	var item := _owned_item(item_id, state)
	if item == null or equipment_catalog == null or item_foundation == null:
		return {}
	var member := party.member_by_id(member_id) if party != null and member_id > 0 else null
	var detail := ItemPresentationProjector.project(
		item,
		equipment_catalog,
		item_foundation,
		GameCatalog.STAT_CATALOG,
		member.class_definition if member != null else null,
		catalog.damage_types if catalog != null else GameCatalog.DAMAGE_TYPES,
	)
	if detail.is_empty() or detail.has("error") or member_id <= 0:
		return detail.duplicate(true)
	var activation := item_context.equipment_activation(member_id)
	var inactive_reasons := activation.disabled_reasons(item_id) if activation != null and activation.ok() else PackedStringArray()
	if not inactive_reasons.is_empty():
		detail["is_disabled"] = true
		detail["inactive_reasons"] = inactive_reasons.duplicate()
		var requirement_lines := _disabled_requirement_lines(state, activation, item_id)
		detail["disabled_requirement_lines"] = requirement_lines if not requirement_lines.is_empty() else inactive_reasons.duplicate()
	return detail.duplicate(true)

func _item_labels(state: ItemOwnershipState, member_id: int) -> Dictionary:
	var result: Dictionary = {}
	var registry := state.registry() if state != null else null
	if registry == null:
		return result
	for item_id: String in registry.ids():
		result[item_id] = String(_project_item(item_id, member_id).get("name", item_id))
	return result

func _disabled_lines_by_item(state: ItemOwnershipState, activation: EquipmentActivationResult) -> Dictionary:
	var result: Dictionary = {}
	var registry := state.registry() if state != null else null
	if registry == null or activation == null or not activation.ok():
		return result
	for item_id: String in registry.ids():
		var reasons := activation.disabled_reasons(item_id)
		if reasons.is_empty():
			continue
		var lines := _disabled_requirement_lines(state, activation, item_id)
		result[item_id] = lines if not lines.is_empty() else reasons
	return result

func _disabled_requirement_lines(state: ItemOwnershipState, activation: EquipmentActivationResult, item_id: String) -> PackedStringArray:
	var lines := PackedStringArray()
	if state == null or activation == null or activation.raw_attributes == null or equipment_catalog == null:
		return lines
	var registry := state.registry()
	var item := registry.item(item_id) if registry != null else null
	var base := equipment_catalog.definition(item.base_definition_id) if item != null else null
	if base == null:
		return lines
	var attribute_ids: Array[StringName] = []
	for attribute_id: Variant in base.attribute_requirements:
		attribute_ids.append(StringName(attribute_id))
	attribute_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for attribute_id: StringName in attribute_ids:
		var required := float(base.attribute_requirements.get(attribute_id, base.attribute_requirements.get(String(attribute_id), 0.0)))
		var available := activation.raw_attributes.value(attribute_id, 0.0)
		if available >= required:
			continue
		var definition := GameCatalog.STAT_CATALOG.definition(attribute_id)
		var label := definition.display_name if definition != null else String(attribute_id).replace("_", " ").capitalize()
		lines.append("Requires %s %s (has %s)" % [label, _number_text(required), _number_text(available)])
	return lines

func _is_visible(definition: StatDefinition, snapshot: ResolvedStatSnapshot, breakdown: Array[Dictionary]) -> bool:
	var has_meaningful_modifier := breakdown.any(func(row: Dictionary) -> bool:
		return int(row.get("operation", -1)) != -1 and not is_zero_approx(float(row.get("value", 0.0)))
	)
	if definition.visibility == StatDefinition.Visibility.UNIVERSAL:
		return true
	if definition.visibility == StatDefinition.Visibility.CAPABILITY:
		return has_meaningful_modifier or definition.capability_tags.any(
			func(tag: StringName) -> bool: return tag in snapshot.capabilities
		)
	return has_meaningful_modifier or not is_equal_approx(
		snapshot.value(definition.id, definition.default_value),
		definition.default_value
	)

func _group_index(group_id: StringName) -> int:
	var index := GROUP_ORDER.find(group_id)
	return index if index >= 0 else GROUP_ORDER.size()

func _cap_text(definition: StatDefinition) -> String:
	var parts := PackedStringArray()
	if definition.has_minimum:
		parts.append("Minimum %s" % definition.format_value(definition.minimum))
	if definition.has_maximum:
		parts.append("Maximum %s" % definition.format_value(definition.maximum))
	return " · ".join(parts)

func _authored_upgrade_row(definition: UpgradeDefinition, rank: int) -> Dictionary:
	var ownership := "Personal"
	var order := 0
	match definition.scope:
		UpgradeDefinition.Scope.CLASS_SPECIFIC:
			ownership = "Class"
			order = 1
		UpgradeDefinition.Scope.PARTY:
			ownership = "Party"
			order = 2
		UpgradeDefinition.Scope.TRAIT:
			ownership = "Trait"
			order = 3
	return {
		"id": definition.id,
		"display_name": definition.display_name,
		"rank": rank,
		"rank_text": "Rank %d / %d" % [rank, definition.max_rank],
		"ownership": ownership,
		"description": definition.description,
		"applicability": "Applies to %s." % ownership.to_lower(),
		"definition": definition,
		"sort_key": "%02d|%s" % [order, definition.display_name],
	}

func _party_stat_row(stat_id: StringName, rank: int) -> Dictionary:
	var definition := PartyManager.STAT_CATALOG.definition(stat_id)
	var stat_name := definition.display_name if definition != null else String(stat_id).capitalize()
	var bonus := party.party_stat_multiplier(stat_id) - 1.0
	return {
		"id": StringName("party_%s" % stat_id),
		"display_name": "Party %s" % stat_name,
		"rank": rank,
		"rank_text": "Rank %d / %d" % [rank, party.upgrade_tuning.party_stat_max_rank],
		"ownership": "Party",
		"description": "A foundational party upgrade affecting every current member.",
		"effect_lines": ["%s%% increased %s." % [_number_text(bonus * 100.0), stat_name]],
		"applicability": "Applies to the whole current party.",
		"definition": null,
		"sort_key": "02|Party %s" % stat_name,
	}

func _trait_row(trait_id: StringName) -> Dictionary:
	var definition := party.trait_definition(trait_id)
	var display_name := definition.display_name if definition != null else String(trait_id).capitalize()
	var tier := party.active_tier(trait_id)
	var mastery := party.trait_upgrade_rank(trait_id)
	return {
		"id": StringName("active_trait_%s" % trait_id),
		"display_name": display_name,
		"rank": mastery,
		"rank_text": "Tier %d · Mastery %d" % [tier, mastery],
		"ownership": "Trait",
		"description": "An active party-composition synergy.",
		"effect_lines": ["Current value: %s" % _number_text(party.effective_trait_value(trait_id))],
		"applicability": "Applies because the selected character has the %s trait." % display_name,
		"definition": null,
		"sort_key": "03|%s" % display_name,
	}

func _on_member_added(member: PartyMemberState) -> void:
	party_changed.emit()
	data_changed.emit(member.member_id)

func _on_stats_changed(member_id: int) -> void:
	if member_id == _suppressed_item_member_id:
		return
	data_changed.emit(member_id)

func _on_upgrades_changed() -> void:
	data_changed.emit(0)

func _on_class_rank_changed(_class_id: StringName, _rank: int) -> void:
	data_changed.emit(0)

func _on_traits_changed(_tiers: Dictionary) -> void:
	data_changed.emit(0)

func _on_progression_changed(member_id: int) -> void:
	data_changed.emit(member_id)

func _observe_health_component(member_id: int, component: HealthComponent) -> void:
	if component == null or not is_instance_valid(component):
		return
	if _health_components.get(member_id) == component:
		return
	_disconnect_health(member_id)
	_health_components[member_id] = component
	component.health_changed.connect(Callable(self, "_on_health_changed").bind(member_id))
	component.downed.connect(Callable(self, "_on_health_state_changed").bind(member_id))
	component.revived.connect(Callable(self, "_on_health_state_changed").bind(member_id))
	component.died.connect(Callable(self, "_on_health_state_changed").bind(member_id))

func _on_health_changed(_current: float, _maximum: float, member_id: int) -> void:
	data_changed.emit(member_id)

func _on_health_state_changed(member_id: int) -> void:
	data_changed.emit(member_id)

func _disconnect_health(member_id: int) -> void:
	var component := _health_components.get(member_id) as HealthComponent
	_health_components.erase(member_id)
	if component == null or not is_instance_valid(component):
		return
	var callbacks := [
		[component.health_changed, Callable(self, "_on_health_changed").bind(member_id)],
		[component.downed, Callable(self, "_on_health_state_changed").bind(member_id)],
		[component.revived, Callable(self, "_on_health_state_changed").bind(member_id)],
		[component.died, Callable(self, "_on_health_state_changed").bind(member_id)],
	]
	for pair: Array in callbacks:
		var signal_value: Signal = pair[0]
		var callback: Callable = pair[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)

func _number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.4f" % value).rstrip("0").rstrip(".")

func _disconnect_party() -> void:
	for member_id: Variant in _health_components.keys():
		_disconnect_health(int(member_id))
	if party == null:
		return
	var connections := [
		[party.member_added, Callable(self, "_on_member_added")],
		[party.stats_changed, Callable(self, "_on_stats_changed")],
		[party.upgrades_changed, Callable(self, "_on_upgrades_changed")],
		[party.class_rank_changed, Callable(self, "_on_class_rank_changed")],
		[party.active_traits_changed, Callable(self, "_on_traits_changed")],
	]
	for connection: Array in connections:
		var signal_value: Signal = connection[0]
		var callback: Callable = connection[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)

func _disconnect_progression_context() -> void:
	if progression_context != null and is_instance_valid(progression_context):
		var callback := Callable(self, "_on_progression_changed")
		if progression_context.progression_changed.is_connected(callback):
			progression_context.progression_changed.disconnect(callback)
	progression_context = null
	progression_provider = Callable()
