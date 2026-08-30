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
		return RunResolutionPreflightResult.failure(request_error)
	var source_result := RunResolutionSource.from_context(context, request.leader_member_id)
	if not source_result.ok():
		return RunResolutionPreflightResult.failure(source_result.error)
	return preflight_source(profile, source_result.source, request)

func preflight_source(
	profile: ProfileState,
	source: RunResolutionSource,
	request: RunResolutionRequest,
) -> RunResolutionPreflightResult:
	var request_error := _validate_source_request(profile.profile_id if profile != null else "", source, request)
	if not request_error.is_empty():
		return RunResolutionPreflightResult.failure(request_error)
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
		return RunResolutionResult.failure(request_error)
	var marker_error := context.item_resolution_error(request.transaction_id)
	if not marker_error.is_empty():
		return RunResolutionResult.failure(marker_error)
	var source_result := RunResolutionSource.from_context(context, request.leader_member_id)
	if not source_result.ok():
		return RunResolutionResult.failure(source_result.error)
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
		return RunResolutionResult.failure(request_error)
	var accepted_holder: Dictionary = {}
	var mutation := _mutations.apply_with_resumable_run_revocation(
		profile_id,
		request.transaction_id,
		request.run_id,
		func(candidate: ProfileState) -> String:
			var evaluation := RunResolutionEvaluator.evaluate(candidate, source, request)
			if not evaluation.ok():
				return evaluation.error
			accepted_holder["extraction"] = evaluation.extraction
			return "",
		root,
		-1,
		OPERATION,
		request.canonical_document(),
	)
	if not mutation.ok():
		return RunResolutionResult.failure(mutation.error)
	var accepted_extraction := accepted_holder.get("extraction") as RunExtractionProjection
	if mutation.duplicate:
		accepted_extraction = RunExtractionPolicy.project_source(source, mutation.profile, request.ordinary_selections)
		if accepted_extraction == null or not accepted_extraction.valid:
			return RunResolutionResult.failure(_error("field=duplicate.extraction reason=stored result cannot be matched to the accepted request"))
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
