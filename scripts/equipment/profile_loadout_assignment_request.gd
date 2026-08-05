class_name ProfileLoadoutAssignmentRequest
extends RefCounted

const SCHEMA_VERSION := 1

var _transaction_id := ""
var _profile_id := ""
var _selected_class_id: StringName
var _item_id := ""
var _source_container_id: StringName
var _source_slot := -1
var _destination_container_id: StringName
var _destination_slot := -1
var _expected_destination_item_id := ""
var _state_fingerprint := ""

var transaction_id: String: get = _get_transaction_id
var profile_id: String: get = _get_profile_id
var selected_class_id: StringName: get = _get_selected_class_id
var item_id: String: get = _get_item_id
var source_container_id: StringName: get = _get_source_container_id
var source_slot: int: get = _get_source_slot
var destination_container_id: StringName: get = _get_destination_container_id
var destination_slot: int: get = _get_destination_slot
var expected_destination_item_id: String: get = _get_expected_destination_item_id
var state_fingerprint: String: get = _get_state_fingerprint

static func create(
	transaction_id_value: String,
	profile_id_value: String,
	selected_class_id_value: StringName,
	item_id_value: String,
	source_container_id_value: StringName,
	source_slot_value: int,
	destination_container_id_value: StringName,
	destination_slot_value: int,
	expected_destination_item_id_value: String,
	state_fingerprint_value: String,
) -> ProfileLoadoutAssignmentRequest:
	var result := ProfileLoadoutAssignmentRequest.new()
	result._transaction_id = transaction_id_value
	result._profile_id = profile_id_value
	result._selected_class_id = selected_class_id_value
	result._item_id = item_id_value
	result._source_container_id = source_container_id_value
	result._source_slot = source_slot_value
	result._destination_container_id = destination_container_id_value
	result._destination_slot = destination_slot_value
	result._expected_destination_item_id = expected_destination_item_id_value
	result._state_fingerprint = state_fingerprint_value
	return result

static func fingerprint_for(profile: ProfileState) -> String:
	if profile == null:
		return ""
	var containers: Array = [profile.leader_loadout.duplicate(true)]
	containers.append_array(profile.stash_tabs.duplicate(true))
	var decoded := ItemOwnershipState.decode({
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": profile.profile_id,
		"registry": profile.item_records.duplicate(true),
		"containers": containers,
	}, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not decoded.ok():
		return ""
	var stored_stash_order: Array[String] = []
	for tab_document: Dictionary in profile.stash_tabs:
		stored_stash_order.append(String(tab_document.get("container_id", "")))
	return JSON.stringify(_canonicalize({
		"profile_id": profile.profile_id,
		"leader_loadout_class_id": profile.leader_loadout_class_id,
		"ownership": decoded.state.to_dictionary(),
		"stored_stash_order": stored_stash_order,
	})).sha256_text()

func canonical_document() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"transaction_id": _transaction_id,
		"profile_id": _profile_id,
		"selected_class_id": String(_selected_class_id),
		"item_id": _item_id,
		"source_container_id": String(_source_container_id),
		"source_slot": _source_slot,
		"destination_container_id": String(_destination_container_id),
		"destination_slot": _destination_slot,
		"expected_destination_item_id": _expected_destination_item_id,
		"state_fingerprint": _state_fingerprint,
	}

func _get_transaction_id() -> String: return _transaction_id
func _get_profile_id() -> String: return _profile_id
func _get_selected_class_id() -> StringName: return _selected_class_id
func _get_item_id() -> String: return _item_id
func _get_source_container_id() -> StringName: return _source_container_id
func _get_source_slot() -> int: return _source_slot
func _get_destination_container_id() -> StringName: return _destination_container_id
func _get_destination_slot() -> int: return _destination_slot
func _get_expected_destination_item_id() -> String: return _expected_destination_item_id
func _get_state_fingerprint() -> String: return _state_fingerprint

static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key: Variant in source:
			keys.append(String(key))
		keys.sort()
		var result: Dictionary = {}
		for key: String in keys:
			var source_key: Variant = key if source.has(key) else StringName(key)
			result[key] = _canonicalize(source[source_key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value as Array:
			result.append(_canonicalize(item))
		return result
	return String(value) if value is StringName else value
