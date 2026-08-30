class_name RunTerminalFlow
extends RefCounted

enum State { IDLE, PERSISTING_RECOVERY, CHOOSING_EXTRACTION, PREFLIGHTING, RESOLVING, RESOLUTION_INTERRUPTED, RESOLVED_AWAITING_PROJECTION, PROJECTION_INTERRUPTED, FINALIZED }

signal extraction_ready(projection: RunExtractionProjection)
signal resolution_pending
signal result_ready(snapshot: RunTerminalSnapshot, result: RunResolutionResult)
signal resolution_failed(reason: String, retry_allowed: bool)
signal projection_failed(reason: String)

const ERROR_PREFIX := "PARTY_FORGE_RUN_TERMINAL_FLOW_ERROR"

var _recovery: RunTerminalRecoveryService
var _resolution: RunResolutionService
var _state := State.IDLE
var _snapshot: RunTerminalSnapshot
var _projection: RunExtractionProjection
var _accepted: RunResolutionResult
var _transaction_base := ""
var _transaction_id := ""
var _request: RunResolutionRequest
var _confirmed_preflight: RunResolutionPreflightResult
var _initial_persistence_interrupted := false
var _last_automatic_only_blocked := false
var _profile_root := ProfileStore.DEFAULT_ROOT

func _init(recovery_service: RunTerminalRecoveryService = null, resolution_service: RunResolutionService = null) -> void:
	_recovery = recovery_service if recovery_service != null else RunTerminalRecoveryService.new()
	_resolution = resolution_service if resolution_service != null else RunResolutionService.new()

func can_begin() -> bool: return _state == State.IDLE
func state() -> State: return _state
func transaction_base() -> String: return _transaction_base
func transaction_id() -> String: return _transaction_id
func extraction_projection() -> RunExtractionProjection: return RunResolutionEvaluation._copy_extraction(_projection)
func snapshot() -> RunTerminalSnapshot: return _snapshot.copy() if _snapshot != null else null
func accepted_result() -> RunResolutionResult:
	if _accepted == null or not _accepted.ok(): return null
	return RunResolutionResult.success(_accepted.profile, _accepted.duplicate, _accepted.accepted_extraction, _accepted.protected_displaced_item_ids)

func begin(outcome: RunTerminalSnapshot.Outcome, elapsed_seconds: float, context: PlayerRunContext, profile: ProfileState, profile_root: String) -> RunTerminalBeginResult:
	if not can_begin(): return RunTerminalBeginResult.failure(RunTerminalBeginResult.Code.CAPTURE_FAILED, _error("state", "terminal event is already active"))
	var captured := RunTerminalSnapshotBuilder.new().capture(outcome, elapsed_seconds, context)
	if not captured.ok() or profile == null or captured.snapshot.profile_id != profile.profile_id:
		return RunTerminalBeginResult.failure(RunTerminalBeginResult.Code.CAPTURE_FAILED, captured.error if not captured.error.is_empty() else _error("profile_id", "profile and captured run must match"))
	_snapshot = captured.snapshot
	_profile_root = profile_root
	_transaction_base = "terminal-resolution:%s" % _snapshot.run_id
	_state = State.PERSISTING_RECOVERY
	var persisted := _recovery.persist_initial(_snapshot.profile_id, _snapshot, profile_root)
	if not persisted.ok():
		_state = State.RESOLUTION_INTERRUPTED
		_initial_persistence_interrupted = true
		return RunTerminalBeginResult.failure(RunTerminalBeginResult.Code.PERSISTENCE_FAILED, persisted.error, _snapshot)
	var projected_error := _project_from_profile(persisted.profile, [])
	if not projected_error.is_empty():
		_state = State.RESOLUTION_INTERRUPTED
		_initial_persistence_interrupted = true
		return RunTerminalBeginResult.failure(RunTerminalBeginResult.Code.PERSISTENCE_FAILED, projected_error, _snapshot)
	_state = State.CHOOSING_EXTRACTION
	extraction_ready.emit(extraction_projection())
	return RunTerminalBeginResult.ready(_snapshot)

func retry_persist_initial(profile_root: String) -> ProfileMutationResult:
	if _state != State.RESOLUTION_INTERRUPTED or not _initial_persistence_interrupted or _snapshot == null:
		return _mutation_failure("initial persistence retry is unavailable")
	_state = State.PERSISTING_RECOVERY
	var persisted := _recovery.persist_initial(_snapshot.profile_id, _snapshot, profile_root)
	if not persisted.ok():
		_state = State.RESOLUTION_INTERRUPTED
		return persisted
	var projection_error := _project_from_profile(persisted.profile, [])
	if not projection_error.is_empty():
		_state = State.RESOLUTION_INTERRUPTED
		return _mutation_failure(projection_error)
	_initial_persistence_interrupted = false
	_state = State.CHOOSING_EXTRACTION
	extraction_ready.emit(extraction_projection())
	return persisted

func confirm_extraction(item_ids: Array[String], profile: ProfileState) -> RunResolutionPreflightResult:
	if _state != State.CHOOSING_EXTRACTION or _snapshot == null or profile == null:
		return RunResolutionPreflightResult.failure(_error("state", "extraction confirmation is unavailable"))
	var seen: Dictionary = {}
	for item_id: String in item_ids:
		if seen.has(item_id): return RunResolutionPreflightResult.failure(_error("selection", "duplicate item %s" % item_id))
		seen[item_id] = true
	var base := RunExtractionPolicy.project_source(_snapshot.resolution_source, profile, [])
	if base == null or not base.valid:
		return RunResolutionPreflightResult.failure(_error("selection", "policy source changed"))
	var selections: Array[ExtractionSelection] = []
	var documents: Array[Dictionary] = []
	for eligible: ExtractionSelection in base.eligible_items:
		if seen.has(eligible.item_id):
			selections.append(eligible)
			documents.append(eligible.to_dictionary())
	if selections.size() != seen.size(): return RunResolutionPreflightResult.failure(_error("selection", "selected items changed"))
	if selections.size() > base.capacity: return RunResolutionPreflightResult.failure(_error("capacity", "selected items exceed extraction capacity"))
	var next_transaction := "%s:%s" % [_transaction_base, JSON.stringify(documents).sha256_text()]
	if _request != null:
		if _transaction_id == next_transaction and _confirmed_preflight != null: return _copy_preflight(_confirmed_preflight)
		return RunResolutionPreflightResult.failure(_error("state", "a different selection is already confirmed"))
	var request := RunResolutionRequest.create(next_transaction, _snapshot.profile_id, _snapshot.run_id, _snapshot.run_seed, _snapshot.run_player_id, _snapshot.leader_member_id, selections)
	_state = State.PREFLIGHTING
	var preflight := RunResolutionService.new().preflight_source(profile, _snapshot.resolution_source, request)
	_last_automatic_only_blocked = preflight.automatic_only_blocked
	if not preflight.ok():
		if preflight.automatic_only_blocked:
			var selected_ids: Array[String] = []
			for selection: ExtractionSelection in selections:
				selected_ids.append(selection.item_id)
			var reason := preflight.player_reason if not preflight.player_reason.strip_edges().is_empty() else preflight.error
			var interrupted := RunTerminalRecoveryRecord.create(
				RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED,
				_snapshot, selected_ids, next_transaction, [], reason, null, "",
			)
			if not interrupted.ok():
				_last_automatic_only_blocked = false
				_state = State.CHOOSING_EXTRACTION
				return RunResolutionPreflightResult.failure(interrupted.error)
			var persisted_interruption := _recovery.persist_selection(_snapshot.profile_id, interrupted.record, _profile_root)
			if not persisted_interruption.ok():
				_last_automatic_only_blocked = false
				_state = State.CHOOSING_EXTRACTION
				return RunResolutionPreflightResult.failure(persisted_interruption.error)
			_transaction_id = next_transaction
			_request = request
			_projection = preflight.extraction
			_confirmed_preflight = _copy_preflight(preflight)
			_state = State.RESOLUTION_INTERRUPTED
		else:
			_state = State.CHOOSING_EXTRACTION
		return preflight
	var record_result := RunTerminalRecoveryRecord.create(RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION, _snapshot, preflight.extraction.selected_item_ids, next_transaction, [], "", null, "")
	if not record_result.ok():
		_state = State.CHOOSING_EXTRACTION
		return RunResolutionPreflightResult.failure(record_result.error)
	var persisted := _recovery.persist_selection(_snapshot.profile_id, record_result.record, _profile_root)
	if not persisted.ok():
		_state = State.CHOOSING_EXTRACTION
		return RunResolutionPreflightResult.failure(persisted.error)
	_transaction_id = next_transaction
	_request = request
	_projection = preflight.extraction
	_confirmed_preflight = _copy_preflight(preflight)
	_state = State.CHOOSING_EXTRACTION
	return _copy_preflight(preflight)

func resolve(profile_id: String, profile_root: String) -> RunResolutionResult:
	if _snapshot == null or _request == null or profile_id != _snapshot.profile_id or _state not in [State.CHOOSING_EXTRACTION, State.RESOLUTION_INTERRUPTED] or _initial_persistence_interrupted or _last_automatic_only_blocked:
		return RunResolutionResult.failure(_error("request", "confirmed selection is unavailable"))
	_state = State.RESOLVING
	resolution_pending.emit()
	var result := _resolution.resolve_terminal_source(profile_id, _snapshot.resolution_source, _request, profile_root)
	if not result.ok():
		var interrupted := RunTerminalRecoveryRecord.create(RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, _snapshot, _projection.selected_item_ids, _transaction_id, [], result.error, null, "")
		if interrupted.ok(): _recovery.persist_selection(profile_id, interrupted.record, profile_root)
		_state = State.RESOLUTION_INTERRUPTED
		resolution_failed.emit(result.error, true)
		return result
	_accepted = RunResolutionResult.success(result.profile, result.duplicate, result.accepted_extraction, result.protected_displaced_item_ids)
	_state = State.RESOLVED_AWAITING_PROJECTION
	result_ready.emit(snapshot(), accepted_result())
	return accepted_result()

func resume(record: RunTerminalRecoveryRecord, profile: ProfileState, _profile_root: String) -> RunTerminalSnapshotResult:
	if _state != State.IDLE or record == null or profile == null:
		return RunTerminalSnapshotResult.failure(_error("state", "terminal resume is unavailable"))
	var inspected := _recovery.inspect(profile)
	if not inspected.ok() or inspected.record.to_dictionary() != record.to_dictionary():
		return RunTerminalSnapshotResult.failure(inspected.error if not inspected.error.is_empty() else _error("record", "durable record changed"))
	_snapshot = record.snapshot
	self._profile_root = _profile_root
	_transaction_base = "terminal-resolution:%s" % _snapshot.run_id
	_transaction_id = record.transaction_id
	if record.stage == RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION:
		var safety := RunRecoveryService.new().verify_terminal_safety(profile, _snapshot)
		if not safety.ok(): return RunTerminalSnapshotResult.failure(safety.error)
		_accepted = RunResolutionResult.success(profile, true, record.accepted_extraction, record.protected_displaced_item_ids)
		_state = State.RESOLVED_AWAITING_PROJECTION
		return RunTerminalSnapshotResult.success(_snapshot)
	var projection_error := _project_from_profile(profile, record.selected_item_ids)
	if not projection_error.is_empty(): return RunTerminalSnapshotResult.failure(projection_error)
	if not record.transaction_id.is_empty():
		_request = RunResolutionRequest.create(record.transaction_id, _snapshot.profile_id, _snapshot.run_id, _snapshot.run_seed, _snapshot.run_player_id, _snapshot.leader_member_id, _selections_for_ids(_projection, record.selected_item_ids))
		_confirmed_preflight = RunResolutionService.new().preflight_source(profile, _snapshot.resolution_source, _request)
		_last_automatic_only_blocked = (
			record.stage == RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED
			and _confirmed_preflight.automatic_only_blocked
			and record.interruption_reason == _confirmed_preflight.player_reason
		)
	_state = State.RESOLUTION_INTERRUPTED if record.stage == RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED else State.CHOOSING_EXTRACTION
	return RunTerminalSnapshotResult.success(_snapshot)

func protect_displaced_gear(profile_id: String, profile_root: String) -> ProfileMutationResult:
	if _state != State.RESOLUTION_INTERRUPTED or not _last_automatic_only_blocked or _snapshot == null:
		return _mutation_failure("displaced gear protection is unavailable")
	var loaded := ProfileStore.new().load_profile(profile_id, profile_root)
	if not loaded.ok(): return _mutation_failure(loaded.error)
	var inspected := _recovery.inspect(loaded.profile)
	if not inspected.ok(): return _mutation_failure(inspected.error)
	var protected := _recovery.protect_displaced_gear(profile_id, inspected.record, profile_root)
	if not protected.ok(): return protected
	var projection_error := _project_from_profile(protected.profile, [])
	if not projection_error.is_empty(): return _mutation_failure(projection_error)
	_last_automatic_only_blocked = false
	_transaction_id = ""
	_request = null
	_confirmed_preflight = null
	_state = State.CHOOSING_EXTRACTION
	extraction_ready.emit(extraction_projection())
	return protected

func retry_projection(profile: ProfileState) -> RunResolutionResult:
	if _state not in [State.PROJECTION_INTERRUPTED, State.RESOLVED_AWAITING_PROJECTION] or _snapshot == null:
		return RunResolutionResult.failure(_error("projection", "retry is unavailable"))
	var safety := RunRecoveryService.new().verify_terminal_safety(profile, _snapshot)
	if not safety.ok(): return RunResolutionResult.failure(safety.error)
	var record := safety.record
	_accepted = RunResolutionResult.success(profile, true, record.accepted_extraction, record.protected_displaced_item_ids)
	_state = State.RESOLVED_AWAITING_PROJECTION
	return accepted_result()

func mark_projection_interrupted(reason: String) -> bool:
	if _state != State.RESOLVED_AWAITING_PROJECTION or reason.strip_edges().is_empty() or not _durable_resolved_receipt_is_valid(): return false
	_state = State.PROJECTION_INTERRUPTED
	projection_failed.emit(reason)
	return true

func finalize() -> bool:
	if _state != State.RESOLVED_AWAITING_PROJECTION or _accepted == null or not _durable_resolved_receipt_is_valid(): return false
	_state = State.FINALIZED
	return true

func _durable_resolved_receipt_is_valid() -> bool:
	if _snapshot == null or _snapshot.profile_id.strip_edges().is_empty():
		return false
	var loaded := ProfileStore.new().load_profile(_snapshot.profile_id, _profile_root)
	if not loaded.ok():
		return false
	var safety := RunRecoveryService.new().verify_terminal_safety(loaded.profile, _snapshot)
	return safety.ok() and safety.record.stage == RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION

func _project_from_profile(profile: ProfileState, selected_ids: Array[String]) -> String:
	var base := RunExtractionPolicy.project_source(_snapshot.resolution_source, profile, [])
	if base == null or not base.valid: return _error("projection", "terminal extraction source is invalid")
	var selections := _selections_for_ids(base, selected_ids)
	if selections.size() != selected_ids.size(): return _error("projection", "persisted selection changed")
	var projected := RunExtractionPolicy.project_source(_snapshot.resolution_source, profile, selections)
	if projected == null or not projected.valid: return _error("projection", "persisted extraction projection is invalid")
	_projection = projected
	return ""

func _selections_for_ids(projection: RunExtractionProjection, ids: Array[String]) -> Array[ExtractionSelection]:
	var wanted: Dictionary = {}; for item_id: String in ids: wanted[item_id] = true
	var result: Array[ExtractionSelection] = []
	for selection: ExtractionSelection in projection.eligible_items:
		if wanted.has(selection.item_id): result.append(selection)
	return result

func _copy_preflight(value: RunResolutionPreflightResult) -> RunResolutionPreflightResult:
	if value == null: return null
	var evaluation := RunResolutionEvaluation.create(value.extraction, value.mandatory_stash_slots, value.ordinary_stash_slots, value.available_stash_slots, value.error, value.failure_category, value.player_reason, value.mandatory_stash_slots_known, value.ordinary_stash_slots_known, value.available_stash_slots_known)
	return RunResolutionPreflightResult.from_evaluation(evaluation)

func _mutation_failure(reason: String) -> ProfileMutationResult:
	var result := ProfileMutationResult.new(); result.error = _error("state", reason); return result
func _error(field: String, reason: String) -> String: return "%s field=%s reason=%s" % [ERROR_PREFIX, field, reason]
