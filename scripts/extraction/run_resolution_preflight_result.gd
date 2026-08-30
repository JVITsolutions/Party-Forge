class_name RunResolutionPreflightResult
extends RefCounted

var _extraction: RunExtractionProjection
var extraction: RunExtractionProjection:
	get: return RunResolutionEvaluation._copy_extraction(_extraction)
var mandatory_stash_slots := 0
var ordinary_stash_slots := 0
var required_stash_slots := 0
var available_stash_slots := 0
var automatic_only_blocked := false
var error := ""
var failure_category := RunResolutionEvaluation.FailureCategory.NONE
var player_reason := ""
var mandatory_stash_slots_known := true
var ordinary_stash_slots_known := true
var required_stash_slots_known := true
var available_stash_slots_known := true

static func from_evaluation(evaluation: RunResolutionEvaluation) -> RunResolutionPreflightResult:
	if evaluation == null:
		return failure("PARTY_FORGE_RUN_RESOLUTION_ERROR field=evaluation reason=must be available")
	var result := RunResolutionPreflightResult.new()
	result._extraction = evaluation.extraction
	result.mandatory_stash_slots = evaluation.mandatory_stash_slots
	result.ordinary_stash_slots = evaluation.ordinary_stash_slots
	result.required_stash_slots = evaluation.required_stash_slots
	result.available_stash_slots = evaluation.available_stash_slots
	result.automatic_only_blocked = evaluation.automatic_only_blocked
	result.error = evaluation.error
	result.failure_category = evaluation.failure_category
	result.player_reason = evaluation.player_reason
	result.mandatory_stash_slots_known = evaluation.mandatory_stash_slots_known
	result.ordinary_stash_slots_known = evaluation.ordinary_stash_slots_known
	result.required_stash_slots_known = evaluation.required_stash_slots_known
	result.available_stash_slots_known = evaluation.available_stash_slots_known
	return result

static func failure(error_value: String, failure_category_value: RunResolutionEvaluation.FailureCategory = RunResolutionEvaluation.FailureCategory.INTERNAL, player_reason_value: String = "Something changed while preparing the run resolution. Review it and try again.") -> RunResolutionPreflightResult:
	var result := RunResolutionPreflightResult.new()
	result.error = error_value
	result.failure_category = failure_category_value
	result.player_reason = player_reason_value
	result.mandatory_stash_slots_known = false
	result.ordinary_stash_slots_known = false
	result.required_stash_slots_known = false
	result.available_stash_slots_known = false
	return result

func ok() -> bool:
	return _extraction != null and _extraction.valid and error.is_empty()
