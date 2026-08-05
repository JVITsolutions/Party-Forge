class_name ItemSlotContainer
extends RefCounted

const SCHEMA_VERSION := 1
const RUN_INVENTORY := &"run_inventory"
const PROFILE_STASH_TAB := &"profile_stash_tab"
const DEVELOPER_INVENTORY := &"developer_inventory"
const DEVELOPER_STASH_TAB := &"developer_stash_tab"
const FIELDS: Array[String] = ["schema_version", "container_id", "container_kind", "owner_id", "capacity", "slots"]
const INVENTORY_CAPACITY_MAX := 40
const STASH_CAPACITY := 100

var schema_version := SCHEMA_VERSION
var container_id: StringName
var container_kind: StringName
var owner_id: String
var capacity: int
var _slots: Dictionary = {}
var _construction_error_field: String
var _construction_error_reason: String

static func create(
	container_id_value: StringName,
	container_kind_value: StringName,
	owner_id_value: String,
	capacity_value: int,
	slots: Dictionary = {}
) -> ItemSlotContainer:
	var result := ItemSlotContainer.new()
	result.container_id = container_id_value
	result.container_kind = container_kind_value
	result.owner_id = owner_id_value
	result.capacity = capacity_value
	for key: Variant in slots:
		var slot := -1
		if typeof(key) == TYPE_INT:
			slot = int(key)
		elif typeof(key) == TYPE_STRING and _canonical_slot_key(String(key)):
			slot = String(key).to_int()
		else:
			result._set_construction_error("slots[%s]" % String(key), "must be an integer slot")
			continue
		if result._slots.has(slot):
			result._set_construction_error("slots[%d]" % slot, "duplicate slot")
			continue
		result._slots[slot] = String(slots[key])
	return result

func item_id_at(slot: int) -> String:
	return String(_slots.get(slot, ""))

func occupied_slots() -> Array[int]:
	var result: Array[int] = []
	for key: Variant in _slots:
		result.append(int(key))
	result.sort()
	return result

func first_empty_slot() -> int:
	for slot: int in capacity:
		if not _slots.has(slot):
			return slot
	return -1

func copy() -> ItemSlotContainer:
	var result := ItemSlotContainer.new()
	result.schema_version = schema_version
	result.container_id = container_id
	result.container_kind = container_kind
	result.owner_id = owner_id
	result.capacity = capacity
	result._construction_error_field = _construction_error_field
	result._construction_error_reason = _construction_error_reason
	for slot: int in occupied_slots():
		result._slots[slot] = String(_slots[slot])
	return result

func to_dictionary() -> Dictionary:
	var slot_document: Dictionary = {}
	for slot: int in occupied_slots():
		slot_document[str(slot)] = String(_slots[slot])
	return {
		"schema_version": schema_version,
		"container_id": String(container_id),
		"container_kind": String(container_kind),
		"owner_id": owner_id,
		"capacity": capacity,
		"slots": slot_document,
	}

func _validation_error(path: String) -> String:
	if schema_version != SCHEMA_VERSION:
		return _error("%s.schema_version" % path, "must equal supported schema %d" % SCHEMA_VERSION)
	if String(container_id).strip_edges().is_empty():
		return _error("%s.container_id" % path, "must be a non-empty string")
	if String(container_kind) not in _known_kind_strings():
		return _error("%s.container_kind" % path, "unknown container kind %s" % container_kind)
	if owner_id.strip_edges().is_empty():
		return _error("%s.owner_id" % path, "must be a non-empty string")
	if container_kind == RUN_INVENTORY or container_kind == DEVELOPER_INVENTORY:
		if capacity < 0 or capacity > INVENTORY_CAPACITY_MAX:
			return _error("%s.capacity" % path, "%s capacity must be in range 0..40" % container_kind)
	elif capacity != STASH_CAPACITY:
		return _error("%s.capacity" % path, "%s capacity must equal 100" % container_kind)
	if not _construction_error_field.is_empty():
		return _error("%s.%s" % [path, _construction_error_field], _construction_error_reason)
	for slot: int in occupied_slots():
		if slot < 0 or slot >= capacity:
			var range_text := "empty" if capacity == 0 else "0..%d" % (capacity - 1)
			return _error("%s.slots[%d]" % [path, slot], "slot must be in range %s" % range_text)
		if String(_slots[slot]).strip_edges().is_empty():
			return _error("%s.slots[%d]" % [path, slot], "instance ID must be a non-empty string")
	return ""

static func _decode(document: Variant, path: String) -> Dictionary:
	if not document is Dictionary:
		return {"value": null, "error": _error(path, "must be a dictionary")}
	var data := document as Dictionary
	var fields_error := ItemRegistry._exact_fields(data, FIELDS, path)
	if not fields_error.is_empty():
		return {"value": null, "error": _error_from_registry(fields_error)}
	if not ItemInstanceCodec._is_json_int(data["schema_version"], SCHEMA_VERSION, SCHEMA_VERSION):
		return {"value": null, "error": _error("%s.schema_version" % path, "must equal supported schema %d" % SCHEMA_VERSION)}
	for field: String in ["container_id", "container_kind", "owner_id"]:
		if typeof(data[field]) != TYPE_STRING or String(data[field]).strip_edges().is_empty():
			return {"value": null, "error": _error("%s.%s" % [path, field], "must be a non-empty string")}
	if not ItemInstanceCodec._is_json_int(data["capacity"], -ItemInstanceCodec.JSON_SAFE_INTEGER_MAX, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
		return {"value": null, "error": _error("%s.capacity" % path, "must be a JSON-safe integer")}
	if not data["slots"] is Dictionary:
		return {"value": null, "error": _error("%s.slots" % path, "must be a dictionary")}
	var decoded_slots: Dictionary = {}
	for key: Variant in data["slots"] as Dictionary:
		if typeof(key) != TYPE_STRING or not _canonical_slot_key(String(key)):
			return {"value": null, "error": _error("%s.slots[%s]" % [path, String(key)], "must be a canonical unsigned decimal string")}
		var slot := String(key).to_int()
		var item_id: Variant = (data["slots"] as Dictionary)[key]
		if typeof(item_id) != TYPE_STRING or String(item_id).strip_edges().is_empty():
			return {"value": null, "error": _error("%s.slots[%s]" % [path, key], "instance ID must be a non-empty string")}
		decoded_slots[slot] = String(item_id)
	var result := create(
		StringName(String(data["container_id"])),
		StringName(String(data["container_kind"])),
		String(data["owner_id"]),
		int(data["capacity"]),
		decoded_slots
	)
	var validation_error := result._validation_error(path)
	if not validation_error.is_empty():
		return {"value": null, "error": validation_error}
	return {"value": result, "error": ""}

static func _canonical_slot_key(value: String) -> bool:
	if value.is_empty() or not value.is_valid_int() or value.begins_with("+") or value.begins_with("-"):
		return false
	var slot := value.to_int()
	return slot >= 0 and str(slot) == value

static func _known_kind_strings() -> Array[String]:
	return [String(RUN_INVENTORY), String(PROFILE_STASH_TAB), String(DEVELOPER_INVENTORY), String(DEVELOPER_STASH_TAB)]

static func _error_from_registry(error: String) -> String:
	return error.replace("PARTY_FORGE_ITEM_REGISTRY_ERROR", "PARTY_FORGE_CONTAINER_ERROR")

static func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_CONTAINER_ERROR field=%s reason=%s" % [field, reason]

func _set_construction_error(field: String, reason: String) -> void:
	if _construction_error_field.is_empty():
		_construction_error_field = field
		_construction_error_reason = reason
