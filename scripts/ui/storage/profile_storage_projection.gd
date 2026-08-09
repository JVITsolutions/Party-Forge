class_name ProfileStorageProjection
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_PROFILE_STORAGE_PROJECTION_ERROR"
const PRESENTATION_PROJECTOR := preload("res://scripts/ui/storage/item_presentation_projector.gd")
const COMPARISON_PROJECTOR := preload("res://scripts/ui/storage/equipment_comparison_projection_service.gd")
const DEFAULT_ATTRIBUTE_PROJECTION: AttributeProjectionTuning = preload("res://data/stats/default_attribute_projection.tres")

var valid := false
var error := ""
var profile_id := ""
var active_class_id: StringName
var _leader_slots: Array[Dictionary] = []
var _stash_tabs: Array[Dictionary] = []
var _item_records: Dictionary = {}
var _profile: ProfileState
var _state: ItemOwnershipState
var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog
var _stats: StatCatalog
var _class_definition: ClassDefinition
var _current_activation: EquipmentActivationResult
var _current_resolution: MemberStatResolution
var _assignment_service: ProfileLoadoutAssignmentService
var _comparison_cache_by_item: Dictionary = {}

var leader_slots: Array[Dictionary]: get = _get_leader_slots
var stash_tabs: Array[Dictionary]: get = _get_stash_tabs
var item_records: Dictionary: get = _get_item_records

static func from_profile(
	profile: ProfileState,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog = GameCatalog.STAT_CATALOG,
	class_definition: ClassDefinition = null,
) -> ProfileStorageProjection:
	var result := ProfileStorageProjection.new()
	if profile == null or equipment == null or foundation == null:
		result.error = "%s field=input reason=profile and catalogs are required" % ERROR_PREFIX
		return result
	var containers: Array = [profile.leader_loadout.duplicate(true)]
	containers.append_array(profile.stash_tabs.duplicate(true))
	var decoded := ItemOwnershipState.decode({
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": profile.profile_id,
		"registry": profile.item_records.duplicate(true),
		"containers": containers,
	}, equipment, foundation)
	if not decoded.ok():
		result.error = "%s field=ownership reason=%s" % [ERROR_PREFIX, decoded.error]
		return result
	var state := decoded.state
	var leader := state.container(&"leader-loadout")
	if leader == null:
		result.error = "%s field=leader_loadout reason=canonical container is missing" % ERROR_PREFIX
		return result
	result.profile_id = profile.profile_id
	result.active_class_id = StringName(profile.leader_loadout_class_id)
	result._profile = profile.copy()
	result._state = state.copy()
	result._equipment = equipment
	result._foundation = foundation
	result._stats = stats
	result._class_definition = class_definition
	if result._class_definition == null and not result.active_class_id.is_empty():
		result._class_definition = GameCatalog.load_defaults().class_by_id(result.active_class_id)
	if result._class_definition != null:
		result._assignment_service = ProfileLoadoutAssignmentService.new(
			null, null, equipment, foundation, result._comparison_classes()
		)
		result._current_activation = result._resolve_activation(state)
		if not result._current_activation.ok():
			result.error = "%s field=activation reason=%s" % [ERROR_PREFIX, result._current_activation.error]
			return result
		result._current_resolution = result._resolve_stats(result._current_activation, [])
		if not result._current_resolution.ok():
			result.error = "%s field=stats reason=%s" % [ERROR_PREFIX, result._current_resolution.error]
			return result
	for index: int in EquipmentSlotIndex.capacity():
		var instance_id := leader.item_id_at(index)
		result._leader_slots.append({
			"slot_id": String(EquipmentSlotIndex.slot_for(index)),
			"slot": index,
			"instance_id": instance_id,
		})
	for stored: Dictionary in profile.stash_tabs:
		var id := StringName(String(stored.get("container_id", "")))
		var tab := state.container(id)
		if tab == null:
			result.error = "%s field=stash_tabs reason=stored tab %s is missing" % [ERROR_PREFIX, id]
			return result
		result._stash_tabs.append({
			"container_id": String(tab.container_id),
			"capacity": tab.capacity,
			"slots": tab.to_dictionary()["slots"].duplicate(true),
		})
	var registry := state.registry()
	for instance_id: String in registry.ids():
		var detail: Dictionary = PRESENTATION_PROJECTOR.project(
			registry.item(instance_id), equipment, foundation, stats, class_definition
		)
		if detail.is_empty():
			result.error = "%s field=item_records instance=%s reason=presentation data is unavailable" % [ERROR_PREFIX, instance_id]
			return result
		if result._container_has_item(leader, instance_id) and result._current_activation != null:
			detail["is_disabled"] = not result._current_activation.is_active(instance_id)
			detail["disabled_requirement_lines"] = result._disabled_requirement_lines(state, result._current_activation, instance_id)
		result._item_records[instance_id] = detail
	result.valid = true
	return result

func copy() -> ProfileStorageProjection:
	var result := ProfileStorageProjection.new()
	result.valid = valid
	result.error = error
	result.profile_id = profile_id
	result.active_class_id = active_class_id
	result._leader_slots = _leader_slots.duplicate(true)
	result._stash_tabs = _stash_tabs.duplicate(true)
	result._item_records = _item_records.duplicate(true)
	result._profile = _profile.copy() if _profile != null else null
	result._state = _state.copy() if _state != null else null
	result._equipment = _equipment
	result._foundation = _foundation
	result._stats = _stats
	result._class_definition = _class_definition
	result._current_activation = _current_activation.copy() if _current_activation != null else null
	result._current_resolution = _current_resolution
	result._assignment_service = _assignment_service
	result._comparison_cache_by_item = _comparison_cache_by_item.duplicate(true)
	return result

func is_loadout_empty() -> bool:
	return _leader_slots.all(func(entry: Dictionary) -> bool: return String(entry["instance_id"]).is_empty())

func item(instance_id: String) -> Dictionary:
	return (_item_records.get(instance_id, {}) as Dictionary).duplicate(true)

func comparison_lines_by_slot(instance_id: String) -> Dictionary:
	if _comparison_cache_by_item.has(instance_id):
		return (_comparison_cache_by_item[instance_id] as Dictionary).duplicate(true)
	var result: Dictionary = {}
	if not valid or instance_id.is_empty() or _profile == null or _state == null or _class_definition == null or _current_activation == null or _current_resolution == null:
		return result
	var detail := item(instance_id)
	if detail.is_empty():
		return result
	var source := _location_for(instance_id)
	if source.is_empty():
		return result
	var compatible: Array = detail.get("compatible_slot_ids", [])
	for slot_value: Variant in compatible:
		var slot_id := String(slot_value)
		var slot_index := EquipmentSlotIndex.index_for(StringName(slot_id))
		if slot_index < 0:
			continue
		result[slot_id] = [] as Array[Dictionary]
		var leader := _state.container(&"leader-loadout")
		var occupied := leader.item_id_at(slot_index) if leader != null else ""
		if String(source.get("container_id", "")) == "leader-loadout" and int(source.get("slot", -1)) == slot_index:
			continue
		var request := ProfileLoadoutAssignmentRequest.create(
			"tooltip-preview-%s-%s" % [instance_id, slot_id],
			_profile.profile_id,
			_class_definition.id,
			instance_id,
			StringName(String(source.get("container_id", ""))),
			int(source.get("slot", -1)),
			&"leader-loadout",
			slot_index,
			occupied,
			ProfileLoadoutAssignmentRequest.fingerprint_for(_profile),
		)
		var preview := _assignment_service.preview(_profile, request)
		if not preview.ok():
			result[slot_id] = [_comparison_unavailable_row(slot_id)]
			continue
		var candidate_state := _decode_profile_state(preview.profile)
		if candidate_state == null:
			result[slot_id] = [_comparison_unavailable_row(slot_id)]
			continue
		var candidate_activation := _resolve_activation(candidate_state)
		if not candidate_activation.ok() or not candidate_activation.is_active(instance_id):
			result[slot_id] = [_comparison_unavailable_row(slot_id)]
			continue
		var candidate_resolution := _resolve_stats(candidate_activation, [])
		if not candidate_resolution.ok():
			result[slot_id] = [_comparison_unavailable_row(slot_id)]
			continue
		result[slot_id] = COMPARISON_PROJECTOR.compare(
			_current_resolution.final_stats,
			candidate_resolution.final_stats,
			_stats,
			_action_estimates(_current_activation),
			_action_estimates(candidate_activation),
			_current_activation,
			candidate_activation,
			instance_id,
			_item_labels(),
			_disabled_lines_by_item(candidate_state, candidate_activation),
		)
	_comparison_cache_by_item[instance_id] = result.duplicate(true)
	return result.duplicate(true)

func _resolve_activation(state: ItemOwnershipState) -> EquipmentActivationResult:
	return EquipmentActivationResolver.resolve(
		1,
		&"leader-loadout",
		state,
		_equipment,
		_foundation,
		_stats,
		_class_definition.stat_base_values(),
		_class_definition.capability_tags,
		[],
		0,
	)

func _comparison_classes() -> GameCatalog:
	var classes := GameCatalog.load_defaults()
	for index: int in classes.classes.size():
		if classes.classes[index] != null and classes.classes[index].id == _class_definition.id:
			classes.classes[index] = _class_definition
			break
	return classes

func _resolve_stats(activation: EquipmentActivationResult, action_tags: Array[StringName]) -> MemberStatResolution:
	if activation == null or not activation.ok():
		return MemberStatResolution.failure("activation is unavailable")
	var sources: Array[StatModifierSource] = [activation.source]
	return MemberStatResolutionService.resolve(
		1,
		_stats,
		_class_definition.stat_base_values(),
		_class_definition.capability_tags,
		sources,
		action_tags,
		0,
		DEFAULT_ATTRIBUTE_PROJECTION,
	)

func _action_estimates(activation: EquipmentActivationResult) -> Array:
	var result: Array = []
	for attack: AttackDefinition in _class_definition.owned_actions():
		if attack == null or attack.is_healing():
			continue
		var action_resolution := _resolve_stats(activation, DamageResolver.action_tags_for(attack))
		if action_resolution.ok():
			result.append(ActionCombatEstimateService.estimate_from_snapshot(attack, action_resolution.final_stats, GameCatalog.DAMAGE_TYPES))
	return result

func _location_for(instance_id: String) -> Dictionary:
	for container: ItemSlotContainer in _state.containers():
		for slot_index: int in container.occupied_slots():
			if container.item_id_at(slot_index) == instance_id:
				return {"container_id": String(container.container_id), "slot": slot_index}
	return {}

func _decode_profile_state(profile: ProfileState) -> ItemOwnershipState:
	var containers: Array = [profile.leader_loadout.duplicate(true)]
	containers.append_array(profile.stash_tabs.duplicate(true))
	var decoded := ItemOwnershipState.decode({
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": profile.profile_id,
		"registry": profile.item_records.duplicate(true),
		"containers": containers,
	}, _equipment, _foundation)
	return decoded.state if decoded.ok() else null

func _item_labels() -> Dictionary:
	var result: Dictionary = {}
	for instance_id: Variant in _item_records:
		result[String(instance_id)] = String((_item_records[instance_id] as Dictionary).get("name", instance_id))
	return result

func _disabled_lines_by_item(state: ItemOwnershipState, activation: EquipmentActivationResult) -> Dictionary:
	var result: Dictionary = {}
	if state == null or activation == null:
		return result
	for item_id: String in state.registry().ids():
		if activation.is_active(item_id) or activation.disabled_reasons(item_id).is_empty():
			continue
		result[item_id] = _disabled_requirement_lines(state, activation, item_id)
	return result

func _disabled_requirement_lines(state: ItemOwnershipState, activation: EquipmentActivationResult, item_id: String) -> PackedStringArray:
	var lines := PackedStringArray()
	if state == null or activation == null or activation.raw_attributes == null:
		return lines
	var item := state.registry().item(item_id)
	var base := _equipment.definition(item.base_definition_id) if item != null else null
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
		var definition := _stats.definition(attribute_id) if _stats != null else null
		var label := definition.display_name if definition != null else String(attribute_id).replace("_", " ").capitalize()
		lines.append("Requires %s %s (has %s)" % [label, _number(required), _number(available)])
	return lines

static func _comparison_unavailable_row(slot_id: String) -> Dictionary:
	var label := slot_id.replace("_", " ").capitalize()
	return {
		"row_type": "warning",
		"stat_id": StringName("comparison_unavailable:%s" % slot_id),
		"delta": -1.0,
		"direction": -1,
		"text": "▼ Cannot equip in %s — projected comparison unavailable" % label,
		"accessible_text": "Item cannot be equipped in %s; projected comparison unavailable" % label,
	}

static func _number(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")

func _container_has_item(container: ItemSlotContainer, instance_id: String) -> bool:
	if container == null:
		return false
	for slot_index: int in container.occupied_slots():
		if container.item_id_at(slot_index) == instance_id:
			return true
	return false

static func inspector_text(detail: Dictionary) -> String:
	if detail.is_empty():
		return "Select an item"
	var lines := PackedStringArray([
		String(detail.get("name", "Unknown Item")),
		"%s • Item Level %d" % [String(detail.get("rarity_name", "Unknown Rarity")), int(detail.get("item_level", 0))],
		String(detail.get("item_type_id", "unknown")),
	])
	var affixes_value: Variant = detail.get("affixes", [])
	if not affixes_value is Array or (affixes_value as Array).is_empty():
		lines.append("Affixes: None")
		return "\n".join(lines)
	lines.append("Affixes:")
	for affix_value: Variant in affixes_value as Array:
		if not affix_value is Dictionary:
			lines.append("- Unknown affix")
			continue
		var affix := affix_value as Dictionary
		var identity := String(affix.get("definition_id", "unknown"))
		var display_name := String(affix.get("display_name", "")).strip_edges()
		var label := "%s (%s)" % [identity, display_name] if not display_name.is_empty() else identity
		lines.append("- %s • Tier %d" % [label, int(affix.get("tier", 0))])
		var rolls_value: Variant = affix.get("rolls", [])
		if not rolls_value is Array or (rolls_value as Array).is_empty():
			lines.append("  No rolls")
			continue
		for roll_value: Variant in rolls_value as Array:
			if not roll_value is Dictionary:
				lines.append("  Unknown roll")
				continue
			var roll := roll_value as Dictionary
			var operation := String(roll.get("operation_name", ""))
			if operation.is_empty(): operation = operation_name(int(roll.get("operation", -1)))
			lines.append("  %s • %s • %s" % [String(roll.get("stat_id", "unknown")), operation, str(roll.get("value", 0))])
	return "\n".join(lines)

static func operation_name(operation: int) -> String:
	match operation:
		StatModifier.Operation.FLAT: return "Flat"
		StatModifier.Operation.INCREASED: return "Increased"
		StatModifier.Operation.REDUCED: return "Reduced"
		StatModifier.Operation.MORE: return "More"
		StatModifier.Operation.LESS: return "Less"
		_: return "Unknown (%d)" % operation

func _get_leader_slots() -> Array[Dictionary]: return _leader_slots.duplicate(true)
func _get_stash_tabs() -> Array[Dictionary]: return _stash_tabs.duplicate(true)
func _get_item_records() -> Dictionary: return _item_records.duplicate(true)
