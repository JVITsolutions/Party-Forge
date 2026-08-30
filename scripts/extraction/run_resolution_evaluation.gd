class_name RunResolutionEvaluation
extends RefCounted

var _extraction: RunExtractionProjection
var extraction: RunExtractionProjection:
	get: return _copy_extraction(_extraction)
var mandatory_stash_slots := 0
var ordinary_stash_slots := 0
var required_stash_slots := 0
var available_stash_slots := 0
var automatic_only_blocked := false
var error := ""

static func create(
	extraction_value: RunExtractionProjection,
	mandatory_value: int,
	ordinary_value: int,
	available_value: int,
	error_value: String = "",
) -> RunResolutionEvaluation:
	var result := RunResolutionEvaluation.new()
	result._extraction = _copy_extraction(extraction_value)
	result.mandatory_stash_slots = maxi(0, mandatory_value)
	result.ordinary_stash_slots = maxi(0, ordinary_value)
	result.required_stash_slots = result.mandatory_stash_slots + result.ordinary_stash_slots
	result.available_stash_slots = maxi(0, available_value)
	result.automatic_only_blocked = result.mandatory_stash_slots > result.available_stash_slots
	result.error = error_value
	return result

func ok() -> bool:
	return _extraction != null and _extraction.valid and error.is_empty()

static func _copy_extraction(value: RunExtractionProjection) -> RunExtractionProjection:
	if value == null:
		return null
	return RunExtractionProjection.create(
		value.automatic_item_ids, value.eligible_items, value.selected_item_ids,
		value.lost_item_ids, value.capacity, value.errors,
	)
