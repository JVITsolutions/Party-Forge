class_name ItemTransactionRequest
extends RefCounted

const SCHEMA_VERSION := 1
const CREATE_AND_PLACE := "create_and_place"
const MOVE_TO_EMPTY := "move_to_empty"
const SWAP_OCCUPIED := "swap_occupied"
const SANDBOX_REMOVE := "sandbox_remove"

var schema_version := SCHEMA_VERSION
var transaction_id: String
var operation: String
var owner_id: String
var source_container_id: String
var source_slot: int = -1
var expected_instance_id: String
var destination_container_id: String
var destination_slot: int = -1
var _create_item: ItemInstance
var create_item: ItemInstance:
	get:
		return _create_item.copy() if _create_item != null else null
	set(value):
		_create_item = value.copy() if value != null else null

static func create(
	transaction_id_value: String,
	owner_id_value: String,
	destination_container_id_value: StringName,
	destination_slot_value: int,
	item: ItemInstance
) -> ItemTransactionRequest:
	var result := ItemTransactionRequest.new()
	result.transaction_id = transaction_id_value
	result.operation = CREATE_AND_PLACE
	result.owner_id = owner_id_value
	result.destination_container_id = String(destination_container_id_value)
	result.destination_slot = destination_slot_value
	result.create_item = item
	return result

static func move(
	transaction_id_value: String,
	owner_id_value: String,
	source_container_id_value: StringName,
	source_slot_value: int,
	expected_instance_id_value: String,
	destination_container_id_value: StringName,
	destination_slot_value: int
) -> ItemTransactionRequest:
	return _placement_request(
		transaction_id_value,
		MOVE_TO_EMPTY,
		owner_id_value,
		source_container_id_value,
		source_slot_value,
		expected_instance_id_value,
		destination_container_id_value,
		destination_slot_value
	)

static func swap(
	transaction_id_value: String,
	owner_id_value: String,
	source_container_id_value: StringName,
	source_slot_value: int,
	expected_instance_id_value: String,
	destination_container_id_value: StringName,
	destination_slot_value: int
) -> ItemTransactionRequest:
	return _placement_request(
		transaction_id_value,
		SWAP_OCCUPIED,
		owner_id_value,
		source_container_id_value,
		source_slot_value,
		expected_instance_id_value,
		destination_container_id_value,
		destination_slot_value
	)

static func sandbox_remove(
	transaction_id_value: String,
	owner_id_value: String,
	source_container_id_value: StringName,
	source_slot_value: int,
	expected_instance_id_value: String
) -> ItemTransactionRequest:
	var result := ItemTransactionRequest.new()
	result.transaction_id = transaction_id_value
	result.operation = SANDBOX_REMOVE
	result.owner_id = owner_id_value
	result.source_container_id = String(source_container_id_value)
	result.source_slot = source_slot_value
	result.expected_instance_id = expected_instance_id_value
	return result

func canonical_document() -> Dictionary:
	var result: Dictionary = {}
	result["schema_version"] = schema_version
	result["transaction_id"] = transaction_id
	result["operation"] = operation
	result["owner_id"] = owner_id
	result["source_container_id"] = source_container_id
	result["source_slot"] = source_slot
	result["expected_instance_id"] = expected_instance_id
	result["destination_container_id"] = destination_container_id
	result["destination_slot"] = destination_slot
	result["create_item"] = _create_item.to_dictionary() if _create_item != null else null
	return result

func fingerprint() -> String:
	return JSON.stringify(canonical_document()).sha256_text()

static func _placement_request(
	transaction_id_value: String,
	operation_value: String,
	owner_id_value: String,
	source_container_id_value: StringName,
	source_slot_value: int,
	expected_instance_id_value: String,
	destination_container_id_value: StringName,
	destination_slot_value: int
) -> ItemTransactionRequest:
	var result := ItemTransactionRequest.new()
	result.transaction_id = transaction_id_value
	result.operation = operation_value
	result.owner_id = owner_id_value
	result.source_container_id = String(source_container_id_value)
	result.source_slot = source_slot_value
	result.expected_instance_id = expected_instance_id_value
	result.destination_container_id = String(destination_container_id_value)
	result.destination_slot = destination_slot_value
	return result
