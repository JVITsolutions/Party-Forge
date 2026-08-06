class_name ProfileStorageProjection
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_PROFILE_STORAGE_PROJECTION_ERROR"
const PRESENTATION_PROJECTOR := preload("res://scripts/ui/storage/item_presentation_projector.gd")

var valid := false
var error := ""
var profile_id := ""
var active_class_id: StringName
var _leader_slots: Array[Dictionary] = []
var _stash_tabs: Array[Dictionary] = []
var _item_records: Dictionary = {}

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
	return result

func is_loadout_empty() -> bool:
	return _leader_slots.all(func(entry: Dictionary) -> bool: return String(entry["instance_id"]).is_empty())

func item(instance_id: String) -> Dictionary:
	return (_item_records.get(instance_id, {}) as Dictionary).duplicate(true)

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
