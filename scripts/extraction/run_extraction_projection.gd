class_name RunExtractionProjection
extends RefCounted

var _automatic_item_ids: Array[String] = []
var automatic_item_ids: Array[String]:
	get:
		return _automatic_item_ids.duplicate()

var _eligible_items: Array[ExtractionSelection] = []
var eligible_items: Array[ExtractionSelection]:
	get:
		return _copy_selections(_eligible_items)

var _selected_item_ids: Array[String] = []
var selected_item_ids: Array[String]:
	get:
		return _selected_item_ids.duplicate()

var _lost_item_ids: Array[String] = []
var lost_item_ids: Array[String]:
	get:
		return _lost_item_ids.duplicate()

var _capacity := 0
var capacity: int:
	get:
		return _capacity

var _errors: Array[String] = []
var errors: Array[String]:
	get:
		return _errors.duplicate()

var valid: bool:
	get:
		return _errors.is_empty()

static func create(
	automatic_ids: Array[String],
	eligible_values: Array[ExtractionSelection],
	selected_ids: Array[String],
	lost_ids: Array[String],
	capacity_value: int,
	error_values: Array[String],
) -> RunExtractionProjection:
	var result := RunExtractionProjection.new()
	result._automatic_item_ids = automatic_ids.duplicate()
	result._eligible_items = _copy_selections(eligible_values)
	result._selected_item_ids = selected_ids.duplicate()
	result._lost_item_ids = lost_ids.duplicate()
	result._capacity = maxi(0, capacity_value)
	result._errors = error_values.duplicate()
	return result

func to_dictionary() -> Dictionary:
	var eligible_documents: Array[Dictionary] = []
	for eligible: ExtractionSelection in _eligible_items:
		eligible_documents.append(eligible.to_dictionary())
	return {
		"automatic_item_ids": _automatic_item_ids.duplicate(),
		"eligible_items": eligible_documents,
		"selected_item_ids": _selected_item_ids.duplicate(),
		"lost_item_ids": _lost_item_ids.duplicate(),
		"capacity": _capacity,
		"valid": valid,
		"errors": _errors.duplicate(),
	}

static func _copy_selections(values: Array[ExtractionSelection]) -> Array[ExtractionSelection]:
	var result: Array[ExtractionSelection] = []
	for value: ExtractionSelection in values:
		result.append(value.copy() if value != null else null)
	return result
