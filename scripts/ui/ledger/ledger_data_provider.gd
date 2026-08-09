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
var _health_components: Dictionary = {}

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if progression_context != null and is_instance_valid(progression_context):
		var callback := Callable(self, "_on_progression_changed")
		if progression_context.progression_changed.is_connected(callback):
			progression_context.progression_changed.disconnect(callback)
	progression_context = null
	progression_provider = Callable()

func configure(
	manager: PartyManager,
	game_catalog: GameCatalog,
	runtime_health: Callable,
	progression_provider: Callable = Callable(),
	progression_context: PlayerRunContext = null,
) -> void:
	_disconnect_party()
	_disconnect_progression_context()
	party = manager
	catalog = game_catalog
	health_provider = runtime_health
	self.progression_provider = progression_provider
	self.progression_context = progression_context
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
		"sources": snapshot.breakdown(stat_id),
	}

func combat_estimate_rows(member_id: int) -> Array[ActionCombatEstimate]:
	var rows: Array[ActionCombatEstimate] = []
	var member := party.member_by_id(member_id) if party != null else null
	if member == null or catalog == null:
		return rows
	var seen_ids: Dictionary = {}
	var seen_instances: Dictionary = {}
	for attack: AttackDefinition in _owned_actions(member.class_definition):
		if attack == null or attack.is_healing() or attack.damage_components.is_empty():
			continue
		var instance_key := attack.get_instance_id()
		if seen_instances.has(instance_key) or (not attack.id.is_empty() and seen_ids.has(attack.id)):
			continue
		seen_instances[instance_key] = true
		if not attack.id.is_empty():
			seen_ids[attack.id] = true
		rows.append(ActionCombatEstimateService.estimate(attack, member_id, party, catalog.damage_types))
	return rows

func _owned_actions(definition: ClassDefinition) -> Array[AttackDefinition]:
	var result: Array[AttackDefinition] = []
	if definition == null:
		return result
	if definition.primary_attack != null:
		result.append(definition.primary_attack)
	if definition.support_action != null:
		result.append(definition.support_action)
	return result

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
