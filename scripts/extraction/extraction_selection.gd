class_name ExtractionSelection
extends RefCounted

var _item_id := ""
var item_id: String:
	get:
		return _item_id

var _expected_source_container_id := &""
var expected_source_container_id: StringName:
	get:
		return _expected_source_container_id

var _expected_source_slot := -1
var expected_source_slot: int:
	get:
		return _expected_source_slot

static func create(
	item_id_value: String,
	expected_source_container_id_value: StringName,
	expected_source_slot_value: int,
) -> ExtractionSelection:
	var result := ExtractionSelection.new()
	result._item_id = item_id_value
	result._expected_source_container_id = expected_source_container_id_value
	result._expected_source_slot = expected_source_slot_value
	return result

func copy() -> ExtractionSelection:
	return create(_item_id, _expected_source_container_id, _expected_source_slot)

func to_dictionary() -> Dictionary:
	return {
		"item_id": _item_id,
		"expected_source_container_id": String(_expected_source_container_id),
		"expected_source_slot": _expected_source_slot,
	}
