class_name RunResolutionService
extends RefCounted

const OPERATION := "run_resolution"
const ERROR_PREFIX := "PARTY_FORGE_RUN_RESOLUTION_ERROR"

var _mutations: ProfileMutationService
var _evaluator: Callable

func _init(mutations: ProfileMutationService = null, evaluator: Callable = Callable()) -> void:
	_mutations = mutations if mutations != null else ProfileMutationService.new()
	_evaluator = evaluator if evaluator.is_valid() else Callable(RunResolutionEvaluator, "evaluate")

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
	return RunResolutionPreflightResult.from_evaluation(_evaluator.call(candidate, source, request) as RunResolutionEvaluation)

func resolve_terminal_source(
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
	var protected_holder: Dictionary = {}
	var terminal_recovery := RunTerminalRecoveryService.new()
	var receipt := {
		"schema_version": 1,
		"source_fingerprint": _document_fingerprint(source.to_dictionary()),
		"request_fingerprint": _document_fingerprint(request.canonical_document()),
	}
	var terminal_mutation := func(candidate: ProfileState) -> String:
		var current := terminal_recovery.inspect(candidate)
		if not current.ok(): return current.error
		var record := current.record
		if record.stage == RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION:
			return _error("field=terminal_resolution.stage reason=must be pre-resolution")
		if record.snapshot.resolution_source.to_dictionary() != source.to_dictionary():
			return _error("field=terminal_resolution.source reason=must match persisted terminal source")
		if record.transaction_id != request.transaction_id:
			return _error("field=terminal_resolution.transaction_id reason=must match persisted selection")
		var evaluation := _evaluator.call(candidate, source, request) as RunResolutionEvaluation
		evaluation_holder["evaluation"] = evaluation
		if evaluation == null or not evaluation.ok():
			return evaluation.error if evaluation != null else _error("field=evaluation reason=must be available")
		accepted_holder["extraction"] = evaluation.extraction
		protected_holder["ids"] = record.protected_displaced_item_ids
		var reward_error := CityVictoryRewardPolicy.apply(candidate, record.snapshot.outcome)
		if not reward_error.is_empty():
			return reward_error
		return terminal_recovery.mark_resolved_candidate(candidate, request, evaluation.extraction)
	var mutation := _mutations.apply_with_resumable_run_revocation(
		profile_id, request.transaction_id, request.run_id, terminal_mutation,
		root, -1, OPERATION, request.canonical_document(), receipt,
	)
	if not mutation.ok():
		var rejected := evaluation_holder.get("evaluation") as RunResolutionEvaluation
		if rejected != null and not rejected.ok():
			return RunResolutionResult.failure(mutation.error, rejected.failure_category, rejected.player_reason)
		return RunResolutionResult.failure(mutation.error)
	var accepted := accepted_holder.get("extraction") as RunExtractionProjection
	var protected_ids: Array[String] = []
	var resolved_profile := mutation.profile
	if mutation.duplicate:
		var live_load := _mutations.load_current_profile(profile_id, root)
		if not live_load.ok():
			return RunResolutionResult.failure(_error("field=duplicate.profile reason=current live profile is unavailable error=%s" % live_load.error))
		var live_profile := live_load.profile
		var live_validation := ProfileCodec.validate_profile(live_profile)
		if not live_validation.is_empty():
			return RunResolutionResult.failure(_error("field=duplicate.profile reason=current live profile is invalid error=%s" % live_validation))
		var decoded := RunTerminalRecoveryCodec.decode(live_profile.terminal_resolution)
		if not decoded.ok() or decoded.record.stage != RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION:
			return RunResolutionResult.failure(_error("field=duplicate.terminal_resolution reason=resolved receipt is unavailable"))
		var safety := RunRecoveryService.new().verify_terminal_safety(live_profile, decoded.record.snapshot)
		if not safety.ok():
			return RunResolutionResult.failure(_error("field=duplicate.terminal_resolution reason=current live resolved truth is unsafe error=%s" % safety.error))
		if not _valid_terminal_receipt(mutation.receipt, source, request):
			return RunResolutionResult.failure(_error("field=duplicate.receipt reason=stored terminal receipt does not match exact source and request"))
		var duplicate_error := _validate_terminal_duplicate(decoded.record, source, request)
		if not duplicate_error.is_empty():
			return RunResolutionResult.failure(duplicate_error)
		accepted = decoded.record.accepted_extraction
		protected_ids = decoded.record.protected_displaced_item_ids
		resolved_profile = live_profile
	else:
		protected_ids = protected_holder.get("ids", []) as Array[String]
	if accepted == null or not accepted.valid:
		return RunResolutionResult.failure(_error("field=accepted_extraction reason=resolved receipt is unavailable"))
	return RunResolutionResult.success(resolved_profile, mutation.duplicate, accepted, protected_ids)

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
			var evaluation := _evaluator.call(candidate, source, request) as RunResolutionEvaluation
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

func _valid_terminal_receipt(receipt: Dictionary, source: RunResolutionSource, request: RunResolutionRequest) -> bool:
	return (
		receipt.size() == 3
		and (receipt.get("schema_version") is int or receipt.get("schema_version") is float)
		and float(receipt["schema_version"]) == floor(float(receipt["schema_version"]))
		and int(receipt["schema_version"]) == 1
		and String(receipt.get("source_fingerprint", "")) == _document_fingerprint(source.to_dictionary())
		and String(receipt.get("request_fingerprint", "")) == _document_fingerprint(request.canonical_document())
	)

func _validate_terminal_duplicate(record: RunTerminalRecoveryRecord, source: RunResolutionSource, request: RunResolutionRequest) -> String:
	if record.snapshot.resolution_source.to_dictionary() != source.to_dictionary():
		return _error("field=duplicate.source reason=decoded terminal source does not match the supplied source")
	if record.transaction_id != request.transaction_id:
		return _error("field=duplicate.request reason=transaction does not match the resolved terminal record")
	var wanted: Dictionary = {}
	for item_id: String in record.selected_item_ids:
		wanted[item_id] = true
	var selections: Array[ExtractionSelection] = []
	var reconstructed_ids: Array[String] = []
	for selection: ExtractionSelection in record.accepted_extraction.eligible_items:
		if wanted.has(selection.item_id):
			selections.append(selection)
			reconstructed_ids.append(selection.item_id)
	if reconstructed_ids != record.selected_item_ids:
		return _error("field=duplicate.request reason=resolved selection order is not canonical")
	var reconstructed := RunResolutionRequest.create(
		record.transaction_id,
		record.snapshot.profile_id,
		record.snapshot.run_id,
		record.snapshot.run_seed,
		record.snapshot.run_player_id,
		record.snapshot.leader_member_id,
		selections,
	)
	if reconstructed.canonical_document() != request.canonical_document():
		return _error("field=duplicate.request reason=canonical request does not match the resolved terminal record")
	return ""

func _is_lower_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true
