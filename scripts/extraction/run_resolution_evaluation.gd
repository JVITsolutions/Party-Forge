class_name RunResolutionEvaluation
extends RefCounted

enum FailureCategory {
	NONE,
	STALE_SELECTION,
	RUN_IDENTITY_MISMATCH,
	OWNERSHIP_VERIFICATION,
	ELIGIBILITY_INVALID,
	STASH_REDUCIBLE,
	STASH_AUTOMATIC_ONLY,
	SELECTION_OVER_CAPACITY,
	DUPLICATE_SOURCE_COLLISION,
	DUPLICATE_RECEIPT_UNAVAILABLE,
	INTERNAL,
}

var _extraction: RunExtractionProjection
var extraction: RunExtractionProjection:
	get: return _copy_extraction(_extraction)
var mandatory_stash_slots := 0
var ordinary_stash_slots := 0
var required_stash_slots := 0
var available_stash_slots := 0
var automatic_only_blocked := false
var error := ""
var failure_category := FailureCategory.NONE
var player_reason := ""
var mandatory_stash_slots_known := true
var ordinary_stash_slots_known := true
var required_stash_slots_known := true
var available_stash_slots_known := true

static func create(
	extraction_value: RunExtractionProjection,
	mandatory_value: int,
	ordinary_value: int,
	available_value: int,
	error_value: String = "",
	failure_category_value: FailureCategory = FailureCategory.NONE,
	player_reason_value: String = "",
	mandatory_known_value: bool = true,
	ordinary_known_value: bool = true,
	available_known_value: bool = true,
) -> RunResolutionEvaluation:
	var result := RunResolutionEvaluation.new()
	result._extraction = _copy_extraction(extraction_value)
	result.mandatory_stash_slots = maxi(0, mandatory_value)
	result.ordinary_stash_slots = maxi(0, ordinary_value)
	result.required_stash_slots = result.mandatory_stash_slots + result.ordinary_stash_slots
	result.available_stash_slots = maxi(0, available_value)
	result.mandatory_stash_slots_known = mandatory_known_value
	result.ordinary_stash_slots_known = ordinary_known_value
	result.required_stash_slots_known = mandatory_known_value and ordinary_known_value
	result.available_stash_slots_known = available_known_value
	result.automatic_only_blocked = mandatory_known_value and available_known_value and result.mandatory_stash_slots > result.available_stash_slots
	result.error = error_value
	result.failure_category = failure_category_value
	result.player_reason = player_reason_value
	return result

func ok() -> bool:
	return _extraction != null and _extraction.valid and error.is_empty()

static func _copy_extraction(value: RunExtractionProjection) -> RunExtractionProjection:
	if value == null:
		return null
	return RunExtractionProjection.create(
		value.automatic_item_ids, value.eligible_items, value.selected_item_ids,
		value.lost_item_ids, value.capacity, value.errors, value.failure_kind,
	)
