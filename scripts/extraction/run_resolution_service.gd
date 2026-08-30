class_name RunResolutionService
extends RefCounted

const OPERATION := "run_resolution"
const ERROR_PREFIX := "PARTY_FORGE_RUN_RESOLUTION_ERROR"

var _mutations: ProfileMutationService

func _init(mutations: ProfileMutationService = null) -> void:
	_mutations = mutations if mutations != null else ProfileMutationService.new()

func preflight(
	profile: ProfileState,
	context: PlayerRunContext,
	request: RunResolutionRequest,
) -> RunResolutionPreflightResult:
	var request_error := _validate_request(profile.profile_id if profile != null else "", context, request)
	if not request_error.is_empty():
		return RunResolutionPreflightResult.failure(request_error, RunResolutionEvaluation.FailureCategory.RUN_IDENTITY_MISMATCH, _identity_player_reason())
	var source_result := RunResolutionSource.from_context(context, request.leader_member_id)
	if not source_result.ok():
		return RunResolutionPreflightResult.failure(source_result.error, _source_failure_category(source_result.failure_kind), _source_player_reason(source_result.failure_kind))
	return preflight_source(profile, source_result.source, request)

func preflight_source(
	profile: ProfileState,
	source: RunResolutionSource,
	request: RunResolutionRequest,
) -> RunResolutionPreflightResult:
	var request_error := _validate_source_request(profile.profile_id if profile != null else "", source, request)
	if not request_error.is_empty():
		return RunResolutionPreflightResult.failure(request_error, RunResolutionEvaluation.FailureCategory.RUN_IDENTITY_MISMATCH, _identity_player_reason())
	var candidate := profile.copy()
	if candidate == null:
		return RunResolutionPreflightResult.failure(_error("field=profile reason=defensive copy unavailable"))
	return RunResolutionPreflightResult.from_evaluation(RunResolutionEvaluator.evaluate(candidate, source, request))

func resolve(
	profile_id: String,
	context: PlayerRunContext,
	request: RunResolutionRequest,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> RunResolutionResult:
	var request_error := _validate_request(profile_id, context, request)
	if not request_error.is_empty():
		return RunResolutionResult.failure(request_error, RunResolutionEvaluation.FailureCategory.RUN_IDENTITY_MISMATCH, _identity_player_reason())
	var marker_error := context.item_resolution_error(request.transaction_id)
	if not marker_error.is_empty():
		return RunResolutionResult.failure(marker_error, RunResolutionEvaluation.FailureCategory.INTERNAL, "This run's items were already resolved with another transaction. Nothing was moved.")
	var source_result := RunResolutionSource.from_context(context, request.leader_member_id)
	if not source_result.ok():
		return RunResolutionResult.failure(source_result.error, _source_failure_category(source_result.failure_kind), _source_player_reason(source_result.failure_kind))
	var result := resolve_source(profile_id, source_result.source, request, root)
	if result.ok():
		context.mark_items_resolved(request.transaction_id)
	return result

func resolve_source(
	profile_id: String,
	source: RunResolutionSource,
	request: RunResolutionRequest,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> RunResolutionResult:
	var request_error := _validate_source_request(profile_id, source, request)
	if not request_error.is_empty():
		return RunResolutionResult.failure(request_error, RunResolutionEvaluation.FailureCategory.RUN_IDENTITY_MISMATCH, _identity_player_reason())
	var accepted_holder: Dictionary = {}
	var evaluation_holder: Dictionary = {}
	var receipt_holder: Dictionary = {}
	var source_fingerprint := _document_fingerprint(source.to_dictionary())
	var mutation := _mutations.apply_with_resumable_run_revocation(
		profile_id,
		request.transaction_id,
		request.run_id,
		func(candidate: ProfileState) -> String:
			var evaluation := RunResolutionEvaluator.evaluate(candidate, source, request)
			evaluation_holder["evaluation"] = evaluation
			if not evaluation.ok():
				return evaluation.error
			accepted_holder["extraction"] = evaluation.extraction
			receipt_holder["schema_version"] = 1
			receipt_holder["source_fingerprint"] = source_fingerprint
			receipt_holder["projection_fingerprint"] = _document_fingerprint(evaluation.extraction.to_dictionary())
			return "",
		root,
		-1,
		OPERATION,
		request.canonical_document(),
		receipt_holder,
	)
	if not mutation.ok():
		var rejected := evaluation_holder.get("evaluation") as RunResolutionEvaluation
		if rejected != null:
			return RunResolutionResult.failure(mutation.error, rejected.failure_category, rejected.player_reason)
		return RunResolutionResult.failure(mutation.error)
	var accepted_extraction := accepted_holder.get("extraction") as RunExtractionProjection
	if mutation.duplicate:
		var receipt := mutation.receipt
		if receipt.is_empty():
			return RunResolutionResult.failure(_error("field=duplicate.receipt reason=legacy transaction has no exact source receipt"), RunResolutionEvaluation.FailureCategory.DUPLICATE_RECEIPT_UNAVAILABLE, "This resolution was already committed, but its exact extraction receipt is unavailable. Nothing was moved.")
		if not _valid_receipt(receipt):
			return RunResolutionResult.failure(_error("field=duplicate.receipt reason=stored receipt is invalid"), RunResolutionEvaluation.FailureCategory.DUPLICATE_RECEIPT_UNAVAILABLE, "This resolution was already committed, but its exact extraction receipt is unavailable. Nothing was moved.")
		if String(receipt["source_fingerprint"]) != source_fingerprint:
			return RunResolutionResult.failure(_error("field=duplicate.source reason=source fingerprint collision"), RunResolutionEvaluation.FailureCategory.DUPLICATE_SOURCE_COLLISION, "This resolution was already committed from different run contents. Nothing was moved.")
		accepted_extraction = RunExtractionPolicy.project_source(source, mutation.profile, request.ordinary_selections)
		if accepted_extraction == null or not accepted_extraction.valid:
			return RunResolutionResult.failure(_error("field=duplicate.extraction reason=stored result cannot be matched to the accepted request"))
		if _document_fingerprint(accepted_extraction.to_dictionary()) != String(receipt["projection_fingerprint"]):
			return RunResolutionResult.failure(_error("field=duplicate.extraction reason=accepted projection fingerprint mismatch"), RunResolutionEvaluation.FailureCategory.DUPLICATE_SOURCE_COLLISION, "This resolution was already committed from different run contents. Nothing was moved.")
	if accepted_extraction == null or not accepted_extraction.valid:
		return RunResolutionResult.failure(_error("field=extraction reason=accepted projection unavailable"))
	return RunResolutionResult.success(mutation.profile, mutation.duplicate, accepted_extraction)

func _validate_request(profile_id: String, context: PlayerRunContext, request: RunResolutionRequest) -> String:
	var common := _validate_request_fields(profile_id, request)
	if not common.is_empty(): return common
	if context == null: return _error("field=context reason=must not be null")
	if context.profile_id != request.profile_id or context.run_id != request.run_id or context.run_seed != request.run_seed or context.run_player_id != request.run_player_id:
		return _error("field=run_identity reason=context and request must match")
	return ""

func _validate_source_request(profile_id: String, source: RunResolutionSource, request: RunResolutionRequest) -> String:
	var common := _validate_request_fields(profile_id, request)
	if not common.is_empty(): return common
	if source == null: return _error("field=source reason=must not be null")
	if source.profile_id != request.profile_id or source.run_id != request.run_id or source.run_seed != request.run_seed or source.run_player_id != request.run_player_id or source.leader_member_id != request.leader_member_id:
		return _error("field=run_identity reason=resolution source and request must match")
	return ""

func _validate_request_fields(profile_id: String, request: RunResolutionRequest) -> String:
	if request == null: return _error("field=request reason=must not be null")
	if request.transaction_id.strip_edges().is_empty(): return _error("field=transaction_id reason=must not be empty")
	if profile_id != request.profile_id: return _error("field=profile_id reason=profile identity mismatch")
	if String(request.run_id).strip_edges().is_empty(): return _error("field=run_id reason=must not be empty")
	if request.run_seed <= 0: return _error("field=run_seed reason=must be positive")
	if String(request.run_player_id).strip_edges().is_empty(): return _error("field=run_player_id reason=must not be empty")
	if request.leader_member_id <= 0: return _error("field=leader_member_id reason=must be positive")
	for index: int in request.ordinary_selections.size():
		if request.ordinary_selections[index] == null: return _error("field=ordinary_selections[%d] reason=must not be null" % index)
	return ""

func _error(detail: String) -> String:
	return "%s %s" % [ERROR_PREFIX, detail]

func _identity_player_reason() -> String:
	return "This no longer matches the saved run. Return to run recovery."

func _document_fingerprint(document: Dictionary) -> String:
	return JSON.stringify(document, "", true, true).sha256_text()

func _source_failure_category(kind: RunResolutionSourceResult.FailureKind) -> RunResolutionEvaluation.FailureCategory:
	match kind:
		RunResolutionSourceResult.FailureKind.IDENTITY_MISMATCH:
			return RunResolutionEvaluation.FailureCategory.RUN_IDENTITY_MISMATCH
		RunResolutionSourceResult.FailureKind.OWNERSHIP_VERIFICATION:
			return RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION
		_:
			return RunResolutionEvaluation.FailureCategory.INTERNAL

func _source_player_reason(kind: RunResolutionSourceResult.FailureKind) -> String:
	match kind:
		RunResolutionSourceResult.FailureKind.IDENTITY_MISMATCH:
			return _identity_player_reason()
		RunResolutionSourceResult.FailureKind.OWNERSHIP_VERIFICATION:
			return "Item ownership could not be verified. Nothing was moved."
		_:
			return "The saved run source is unavailable. Nothing was moved."

func _valid_receipt(receipt: Dictionary) -> bool:
	return (
		receipt.size() == 3
		and (receipt.get("schema_version") is int or receipt.get("schema_version") is float)
		and float(receipt["schema_version"]) == floor(float(receipt["schema_version"]))
		and int(receipt["schema_version"]) == 1
		and _is_lower_hex(String(receipt.get("source_fingerprint", "")), 64)
		and _is_lower_hex(String(receipt.get("projection_fingerprint", "")), 64)
	)

func _is_lower_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true
