class_name RunResolutionResult
extends RefCounted

var _profile: ProfileState
var profile: ProfileState:
	get:
		return _profile.copy() if _profile != null else null

var error := ""
var duplicate := false
var failure_category := RunResolutionEvaluation.FailureCategory.NONE
var player_reason := ""
var _accepted_extraction: RunExtractionProjection
var accepted_extraction: RunExtractionProjection:
	get:
		return RunResolutionEvaluation._copy_extraction(_accepted_extraction)
var _protected_displaced_item_ids: Array[String] = []
var protected_displaced_item_ids: Array[String]:
	get:
		return _protected_displaced_item_ids.duplicate()

static func success(
	profile_value: ProfileState,
	duplicate_value: bool,
	accepted_extraction_value: RunExtractionProjection,
	protected_displaced_item_ids_value: Array[String] = [],
) -> RunResolutionResult:
	var result := RunResolutionResult.new()
	result._profile = profile_value.copy() if profile_value != null else null
	result.duplicate = duplicate_value
	result._accepted_extraction = RunResolutionEvaluation._copy_extraction(accepted_extraction_value)
	result._protected_displaced_item_ids = protected_displaced_item_ids_value.duplicate()
	return result

static func failure(error_value: String, failure_category_value: RunResolutionEvaluation.FailureCategory = RunResolutionEvaluation.FailureCategory.INTERNAL, player_reason_value: String = "Something changed while resolving the run. Nothing was moved.") -> RunResolutionResult:
	var result := RunResolutionResult.new()
	result.error = error_value
	result.failure_category = failure_category_value
	result.player_reason = player_reason_value
	return result

func ok() -> bool:
	return _profile != null and _accepted_extraction != null and _accepted_extraction.valid and error.is_empty()
