class_name ItemRegistry
extends RefCounted

const SCHEMA_VERSION := 1
const FIELDS: Array[String] = ["schema_version", "items"]

var schema_version := SCHEMA_VERSION
var _items: Dictionary = {}
var _construction_error_field: String
var _construction_error_reason: String

func _init(items: Array[ItemInstance] = []) -> void:
	for index: int in items.size():
		var item_value := items[index]
		if item_value == null:
			_set_construction_error("items[%d]" % index, "must not be null")
			continue
		if item_value.instance_id.is_empty():
			_set_construction_error("items[%d].instance_id" % index, "must be a non-empty string")
			continue
		if _items.has(item_value.instance_id):
			_set_construction_error("items[%d].instance_id" % index, "duplicate instance ID %s" % item_value.instance_id)
			continue
		_items[item_value.instance_id] = item_value.copy()

func has(instance_id: String) -> bool:
	return _items.has(instance_id)

func item(instance_id: String) -> ItemInstance:
	var value := _items.get(instance_id) as ItemInstance
	return value.copy() if value != null else null

func ids() -> Array[String]:
	var result: Array[String] = []
	for key: Variant in _items:
		result.append(String(key))
	result.sort()
	return result

func size() -> int:
	return _items.size()

func _insert(item_value: ItemInstance) -> void:
	if item_value == null:
		return
	_items[item_value.instance_id] = item_value.copy()

func _erase(instance_id: String) -> void:
	_items.erase(instance_id)

func copy() -> ItemRegistry:
	var result := ItemRegistry.new()
	result.schema_version = schema_version
	result._construction_error_field = _construction_error_field
	result._construction_error_reason = _construction_error_reason
	for instance_id: String in ids():
		result._items[instance_id] = (_items[instance_id] as ItemInstance).copy()
	return result

func to_dictionary() -> Dictionary:
	var documents: Array[Dictionary] = []
	for instance_id: String in ids():
		documents.append((_items[instance_id] as ItemInstance).to_dictionary())
	return {
		"schema_version": schema_version,
		"items": documents,
	}

func _validation_error(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	path: String = "registry"
) -> String:
	if schema_version != SCHEMA_VERSION:
		return _error("%s.schema_version" % path, "must equal supported schema %d" % SCHEMA_VERSION)
	if not _construction_error_field.is_empty():
		return _error("%s.%s" % [path, _construction_error_field], _construction_error_reason)
	var sorted_ids := ids()
	for index: int in sorted_ids.size():
		var item_error := ItemInstanceCodec.validate(_items[sorted_ids[index]] as ItemInstance, equipment, foundation)
		if not item_error.is_empty():
			return _error("%s.items[%d]" % [path, index], item_error)
	return ""

static func _decode(
	document: Variant,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	path: String = "registry"
) -> Dictionary:
	if not document is Dictionary:
		return {"value": null, "error": _error(path, "must be a dictionary")}
	var data := document as Dictionary
	var fields_error := _exact_fields(data, FIELDS, path)
	if not fields_error.is_empty():
		return {"value": null, "error": fields_error}
	if not _is_json_int(data["schema_version"], SCHEMA_VERSION, SCHEMA_VERSION):
		return {"value": null, "error": _error("%s.schema_version" % path, "must equal supported schema %d" % SCHEMA_VERSION)}
	if not data["items"] is Array:
		return {"value": null, "error": _error("%s.items" % path, "must be an array")}
	var decoded_items: Array[ItemInstance] = []
	var seen_ids: Dictionary = {}
	var item_documents := data["items"] as Array
	for index: int in item_documents.size():
		var decoded := ItemInstanceCodec.decode(item_documents[index], equipment, foundation)
		if not decoded.ok():
			return {"value": null, "error": _error("%s.items[%d]" % [path, index], decoded.error)}
		if seen_ids.has(decoded.item.instance_id):
			return {
				"value": null,
				"error": _error("%s.items[%d].instance_id" % [path, index], "duplicate instance ID %s" % decoded.item.instance_id),
			}
		seen_ids[decoded.item.instance_id] = true
		decoded_items.append(decoded.item)
	return {"value": ItemRegistry.new(decoded_items), "error": ""}

static func _exact_fields(data: Dictionary, expected: Array[String], path: String) -> String:
	var missing: Array[String] = []
	for field: String in expected:
		if not data.has(field):
			missing.append(field)
	var unexpected: Array[String] = []
	for key: Variant in data:
		if typeof(key) != TYPE_STRING:
			unexpected.append(String(key))
		elif String(key) not in expected:
			unexpected.append(String(key))
	unexpected.sort()
	if missing.is_empty() and unexpected.is_empty():
		return ""
	var reasons: Array[String] = []
	if not missing.is_empty():
		reasons.append("missing fields %s" % ",".join(missing))
	if not unexpected.is_empty():
		reasons.append("unexpected fields %s" % ",".join(unexpected))
	return _error(path, "; ".join(reasons))

static func _is_json_int(value: Variant, minimum: int, maximum: int) -> bool:
	return ItemInstanceCodec._is_json_int(value, minimum, maximum)

static func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_ITEM_REGISTRY_ERROR field=%s reason=%s" % [field, reason]

func _set_construction_error(field: String, reason: String) -> void:
	if _construction_error_field.is_empty():
		_construction_error_field = field
		_construction_error_reason = reason
