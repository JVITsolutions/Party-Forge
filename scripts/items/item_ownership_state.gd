class_name ItemOwnershipState
extends RefCounted

const SCHEMA_VERSION := 1
const FIELDS: Array[String] = ["schema_version", "owner_id", "registry", "containers"]

var schema_version := SCHEMA_VERSION
var owner_id: String
var _registry: ItemRegistry
var _containers: Dictionary = {}
var _construction_error_field: String
var _construction_error_reason: String

static func create(
	owner_id_value: String,
	registry_value: ItemRegistry,
	container_values: Array[ItemSlotContainer]
) -> ItemOwnershipState:
	var result := ItemOwnershipState.new()
	result.owner_id = owner_id_value
	result._registry = registry_value.copy() if registry_value != null else null
	for index: int in container_values.size():
		var container_value := container_values[index]
		if container_value == null:
			result._set_construction_error("containers[%d]" % index, "must not be null")
			continue
		var key := String(container_value.container_id)
		if result._containers.has(key):
			result._set_construction_error("containers[%d].container_id" % index, "duplicate container ID %s" % key)
			continue
		result._containers[key] = container_value.copy()
	return result

func registry() -> ItemRegistry:
	return _registry.copy() if _registry != null else null

func container(container_id_value: StringName) -> ItemSlotContainer:
	var value := _containers.get(String(container_id_value)) as ItemSlotContainer
	return value.copy() if value != null else null

func containers() -> Array[ItemSlotContainer]:
	var result: Array[ItemSlotContainer] = []
	for key: String in _container_ids():
		result.append((_containers[key] as ItemSlotContainer).copy())
	return result

func copy() -> ItemOwnershipState:
	var result := ItemOwnershipState.create(owner_id, _registry, containers())
	result.schema_version = schema_version
	result._construction_error_field = _construction_error_field
	result._construction_error_reason = _construction_error_reason
	return result

func to_dictionary() -> Dictionary:
	var container_documents: Array[Dictionary] = []
	for key: String in _container_ids():
		container_documents.append((_containers[key] as ItemSlotContainer).to_dictionary())
	return {
		"schema_version": schema_version,
		"owner_id": owner_id,
		"registry": _registry.to_dictionary() if _registry != null else {},
		"containers": container_documents,
	}

func validate(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog) -> String:
	if schema_version != SCHEMA_VERSION:
		return _error("schema_version", "must equal supported schema %d" % SCHEMA_VERSION)
	if owner_id.strip_edges().is_empty():
		return _error("owner_id", "must be a non-empty string")
	if _registry == null:
		return ItemRegistry._error("registry", "must not be null")
	var registry_error := _registry._validation_error(equipment, foundation)
	if not registry_error.is_empty():
		return registry_error
	if not _construction_error_field.is_empty():
		return _error(_construction_error_field, _construction_error_reason)
	var references: Dictionary = {}
	var sorted_container_ids := _container_ids()
	for index: int in sorted_container_ids.size():
		var container_value := _containers[sorted_container_ids[index]] as ItemSlotContainer
		var path := "containers[%d]" % index
		var container_error := container_value._validation_error(path)
		if not container_error.is_empty():
			return container_error
		if container_value.owner_id != owner_id:
			return _error("%s.owner_id" % path, "must match state owner %s" % owner_id)
		for slot: int in container_value.occupied_slots():
			var instance_id := container_value.item_id_at(slot)
			if not _registry.has(instance_id):
				return ItemRegistry._error("%s.slots[%d]" % [path, slot], "unknown instance ID %s" % instance_id)
			references[instance_id] = int(references.get(instance_id, 0)) + 1
	for instance_id: String in _registry.ids():
		var count := int(references.get(instance_id, 0))
		if count != 1:
			return ItemRegistry._error("instance_id", "instance %s has %d references" % [instance_id, count])
	return ""

static func decode(
	document: Variant,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> ItemOwnershipStateDecodeResult:
	var result := ItemOwnershipStateDecodeResult.new()
	if not document is Dictionary:
		result.error = _error("document", "must be a dictionary")
		return result
	var data := document as Dictionary
	var fields_error := ItemRegistry._exact_fields(data, FIELDS, "document")
	if not fields_error.is_empty():
		result.error = ItemSlotContainer._error_from_registry(fields_error)
		return result
	if not ItemInstanceCodec._is_json_int(data["schema_version"], SCHEMA_VERSION, SCHEMA_VERSION):
		result.error = _error("schema_version", "must equal supported schema %d" % SCHEMA_VERSION)
		return result
	if typeof(data["owner_id"]) != TYPE_STRING or String(data["owner_id"]).strip_edges().is_empty():
		result.error = _error("owner_id", "must be a non-empty string")
		return result
	var registry_decode := ItemRegistry._decode(data["registry"], equipment, foundation)
	if not String(registry_decode["error"]).is_empty():
		result.error = String(registry_decode["error"])
		return result
	if not data["containers"] is Array:
		result.error = _error("containers", "must be an array")
		return result
	var container_values: Array[ItemSlotContainer] = []
	var seen_container_ids: Dictionary = {}
	var container_documents := data["containers"] as Array
	for index: int in container_documents.size():
		var path := "containers[%d]" % index
		var container_decode := ItemSlotContainer._decode(container_documents[index], path)
		if not String(container_decode["error"]).is_empty():
			result.error = String(container_decode["error"])
			return result
		var container_value := container_decode["value"] as ItemSlotContainer
		var container_id_value := String(container_value.container_id)
		if seen_container_ids.has(container_id_value):
			result.error = _error("%s.container_id" % path, "duplicate container ID %s" % container_id_value)
			return result
		seen_container_ids[container_id_value] = true
		if container_value.owner_id != String(data["owner_id"]):
			result.error = _error("%s.owner_id" % path, "must match state owner %s" % String(data["owner_id"]))
			return result
		container_values.append(container_value)
	var candidate := create(String(data["owner_id"]), registry_decode["value"] as ItemRegistry, container_values)
	result.error = candidate.validate(equipment, foundation)
	if not result.error.is_empty():
		return result
	result.state = candidate
	return result

func _container_ids() -> Array[String]:
	var result: Array[String] = []
	for key: Variant in _containers:
		result.append(String(key))
	result.sort()
	return result

static func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_CONTAINER_ERROR field=%s reason=%s" % [field, reason]

func _set_construction_error(field: String, reason: String) -> void:
	if _construction_error_field.is_empty():
		_construction_error_field = field
		_construction_error_reason = reason
