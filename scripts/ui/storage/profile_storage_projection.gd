class_name ProfileStorageProjection
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_PROFILE_STORAGE_PROJECTION_ERROR"

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

static func from_profile(profile: ProfileState, equipment: EquipmentCatalog, foundation: ItemFoundationCatalog) -> ProfileStorageProjection:
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
		var item := registry.item(instance_id)
		var base := equipment.definition(item.base_definition_id)
		var rarity := foundation.rarity(item.rarity_id)
		result._item_records[instance_id] = {
			"instance_id": instance_id,
			"base_definition_id": String(item.base_definition_id),
			"name": base.display_name,
			"item_type_id": String(base.item_type_id),
			"icon_path": _icon_path(base),
			"rarity_id": String(item.rarity_id),
			"rarity_name": rarity.display_name,
			"item_level": item.item_level,
			"affixes": item.to_dictionary()["affixes"].duplicate(true),
			"item": item.to_dictionary(),
		}
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

func _get_leader_slots() -> Array[Dictionary]: return _leader_slots.duplicate(true)
func _get_stash_tabs() -> Array[Dictionary]: return _stash_tabs.duplicate(true)
func _get_item_records() -> Dictionary: return _item_records.duplicate(true)

static func _icon_path(base: EquipmentBaseDefinition) -> String:
	var path := "res://assets/ui/equipment/runtime/%s/%s_128.png" % [String(base.implicit_family_id), String(base.id)]
	return path if ResourceLoader.exists(path) else ""
