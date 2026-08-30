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
	return result

static func failure(error_value: String) -> RunResolutionPreflightResult:
	var result := RunResolutionPreflightResult.new()
	result.error = error_value
	return result

func ok() -> bool:
	return _extraction != null and _extraction.valid and error.is_empty()
