class_name RunTerminalRecoveryService
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_RUN_TERMINAL_RECOVERY_ERROR"
const CAPTURE_OPERATION := "terminal_capture"
const SELECTION_OPERATION := "terminal_selection"
const PROTECTION_OPERATION := "terminal_protect_displaced"
const COMPLETION_OPERATION := "terminal_completion"

var _mutations: ProfileMutationService
var _store: ProfileStore

func _init(mutations: ProfileMutationService = null, store: ProfileStore = null) -> void:
	_store = store if store != null else ProfileStore.new()
	_mutations = mutations if mutations != null else ProfileMutationService.new(_store)

func persist_initial(profile_id: String, snapshot: RunTerminalSnapshot, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	if snapshot == null:
		return _failure(profile_id, "terminal-capture", "snapshot is required")
	var decoded_snapshot := RunTerminalSnapshot.from_dictionary(snapshot.to_dictionary())
	if not decoded_snapshot.ok() or snapshot.profile_id != profile_id:
		return _failure(profile_id, "terminal-capture", "snapshot identity is invalid")
	var transaction_id := "terminal-capture:%s" % snapshot.run_id
	var empty_ids: Array[String] = []
	var request := {
		"profile_id": profile_id,
		"run_id": String(snapshot.run_id),
		"snapshot": snapshot.to_dictionary(),
	}
	var mutation := _mutations.apply(profile_id, transaction_id, func(candidate: ProfileState) -> String:
		var identity_error := _validate_bootstrap_identity(candidate, snapshot, false)
		if not identity_error.is_empty():
			return identity_error
		candidate.resumable_run["item_state"] = snapshot.resolution_source.item_state.to_dictionary()
		var strict_error := _validate_bootstrap_identity(candidate, snapshot, true)
		if not strict_error.is_empty():
			return strict_error
		var created := RunTerminalRecoveryRecord.create(
			RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION,
			snapshot, empty_ids, "", empty_ids, "", null, "",
		)
		if not created.ok():
			return created.error
		candidate.terminal_resolution = created.record.to_dictionary()
		return ""
	, root, -1, CAPTURE_OPERATION, request)
	if not mutation.ok():
		return mutation
	var projection_error := _validate_initial_projection(mutation.profile, snapshot)
	if not projection_error.is_empty():
		return _failure(profile_id, transaction_id, projection_error)
	return mutation

func persist_selection(profile_id: String, record: RunTerminalRecoveryRecord, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	if record == null or record.snapshot == null or record.snapshot.profile_id != profile_id:
		return _failure(profile_id, "terminal-selection", "record identity is invalid")
	if record.transaction_id.strip_edges().is_empty():
		return _failure(profile_id, "terminal-selection", "resolution transaction is required")
	var transaction_id := "%s:%s" % ["terminal-interruption" if record.stage == RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED else "terminal-selection", record.transaction_id]
	var request := {
		"profile_id": profile_id,
		"run_id": String(record.snapshot.run_id),
		"resolution_transaction_id": record.transaction_id,
		"selected_item_ids": record.selected_item_ids,
		"stage": int(record.stage),
	}
	return _mutations.apply(profile_id, transaction_id, func(candidate: ProfileState) -> String:
		var current := inspect(candidate)
		if not current.ok():
			return current.error
		if current.record.stage == RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION:
			return _error("stage", "resolved terminal truth cannot be replaced")
		if current.record.snapshot.to_dictionary() != record.snapshot.to_dictionary():
			return _error("snapshot", "selection must match durable terminal truth")
		candidate.terminal_resolution = record.to_dictionary()
		return ""
	, root, -1, SELECTION_OPERATION, request)

func inspect(profile: ProfileState) -> RunTerminalRecoveryRecordResult:
	if profile == null:
		return RunTerminalRecoveryRecordResult.failure(_error("profile", "must not be null"))
	var decoded := RunTerminalRecoveryCodec.decode(profile.terminal_resolution)
	if not decoded.ok():
		return decoded
	var record := decoded.record
	if record.snapshot.profile_id != profile.profile_id:
		return RunTerminalRecoveryRecordResult.failure(_error("profile_id", "receipt and profile must match"))
	if record.stage != RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION:
		var identity_error := _validate_bootstrap_identity(profile, record.snapshot, true)
		if not identity_error.is_empty():
			return RunTerminalRecoveryRecordResult.failure(identity_error)
	return decoded

func mark_resolved_candidate(candidate: ProfileState, request: RunResolutionRequest, accepted_extraction: RunExtractionProjection) -> String:
	if candidate == null or request == null or accepted_extraction == null or not accepted_extraction.valid:
		return _error("resolution", "candidate, request, and accepted extraction are required")
	var current := RunTerminalRecoveryCodec.decode(candidate.terminal_resolution)
	if not current.ok():
		return current.error
	var record := current.record
	if record.stage == RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION:
		return _error("stage", "terminal receipt is already resolved")
	if not _request_matches_snapshot(request, record.snapshot):
		return _error("run_identity", "request must match durable terminal truth")
	if record.transaction_id != request.transaction_id:
		return _error("transaction_id", "request must match persisted selection transaction")
	if record.selected_item_ids != accepted_extraction.selected_item_ids:
		return _error("selected_item_ids", "accepted extraction must match persisted selection")
	var resolved := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION,
		record.snapshot, record.selected_item_ids, record.transaction_id,
		record.protected_displaced_item_ids, "", accepted_extraction, request.transaction_id,
	)
	if not resolved.ok():
		return resolved.error
	candidate.terminal_resolution = resolved.record.to_dictionary()
	return ""

func complete_terminal(profile_id: String, run_id: StringName, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	var clean_run_id := String(run_id).strip_edges()
	if clean_run_id.is_empty():
		return _failure(profile_id, "terminal-complete", "run id is required")
	var transaction_id := "terminal-complete:%s" % clean_run_id
	var loaded := _store.load_profile(profile_id, root)
	if not loaded.ok():
		return _failure(profile_id, transaction_id, loaded.error if not loaded.error.is_empty() else "profile is missing")
	var terminal_ids: Array[String] = []
	if loaded.profile.terminal_resolution.is_empty():
		if not loaded.profile.applied_transactions.has(transaction_id):
			return _failure(profile_id, transaction_id, "resolved terminal receipt is required")
	else:
		var decoded_record := RunTerminalRecoveryCodec.decode(loaded.profile.terminal_resolution)
		if not decoded_record.ok():
			return _failure(profile_id, transaction_id, decoded_record.error)
		if decoded_record.record.stage != RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION:
			return _failure(profile_id, transaction_id, "terminal receipt is not resolved")
		var safety := RunRecoveryService.new(null, null, _store).verify_terminal_safety(loaded.profile, decoded_record.record.snapshot)
		if not safety.ok():
			return _failure(profile_id, transaction_id, safety.error)
		var record := safety.record
		if record.snapshot.run_id != run_id:
			return _failure(profile_id, transaction_id, "run identity does not match resolved receipt")
		terminal_ids = record.snapshot.resolution_source.item_state.registry().ids()
	var request := {"profile_id": profile_id, "run_id": clean_run_id}
	var complete_mutation := func(candidate: ProfileState) -> String:
		var current := inspect(candidate)
		if not current.ok(): return current.error
		var record := current.record
		if record.stage != RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION or record.snapshot.run_id != run_id:
			return _error("stage", "exact resolved terminal receipt is required")
		var safety := RunRecoveryService.new(null, null, _store).verify_terminal_safety(candidate, record.snapshot)
		if not safety.ok():
			return safety.error
		candidate.terminal_resolution = {}
		return ""
	return _mutations.apply_irreversible_terminal_completion(
		profile_id, transaction_id, run_id, terminal_ids,
		complete_mutation, root, -1, COMPLETION_OPERATION, request,
	)

func protect_displaced_gear(profile_id: String, record: RunTerminalRecoveryRecord, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	if record == null or record.snapshot == null or record.snapshot.profile_id != profile_id:
		return _failure(profile_id, "terminal-protect-displaced", "record identity is invalid")
	var loaded := _store.load_profile(profile_id, root)
	if not loaded.ok():
		return _failure(profile_id, "terminal-protect-displaced", loaded.error if not loaded.error.is_empty() else "profile is missing")
	var prefix := "terminal-protect-displaced:%s:" % record.snapshot.run_id
	var request := {
		"profile_id": profile_id,
		"run_id": String(record.snapshot.run_id),
		"record": record.to_dictionary(),
	}
	var expected_fingerprint := ProfileMutationService._fingerprint(PROTECTION_OPERATION, request)
	var transaction_id := ""
	for applied_id: Variant in loaded.profile.applied_transactions:
		if not String(applied_id).begins_with(prefix):
			continue
		var applied := loaded.profile.applied_transactions[applied_id] as Dictionary
		if String(applied.get("operation", "")) != PROTECTION_OPERATION or String(applied.get("fingerprint", "")) != expected_fingerprint:
			continue
		if not transaction_id.is_empty():
			return _failure(profile_id, prefix, "multiple committed protection transactions match the supplied record")
		transaction_id = String(applied_id)
	if not transaction_id.is_empty():
		var duplicate := _mutations.apply(profile_id, transaction_id, func(_candidate: ProfileState) -> String:
			return _error("duplicate", "committed protection unexpectedly invoked its mutation")
		, root, -1, PROTECTION_OPERATION, request)
		if not duplicate.ok():
			return duplicate
		var duplicate_error := _validate_protection_projection(loaded.profile, duplicate.profile, record)
		if not duplicate_error.is_empty():
			return _failure(profile_id, transaction_id, duplicate_error)
		return duplicate
	var current := RunTerminalRecoveryCodec.decode(loaded.profile.terminal_resolution)
	if not current.ok() or current.record.to_dictionary() != record.to_dictionary():
		return _failure(profile_id, "terminal-protect-displaced", current.error if not current.ok() else "record is stale")
	var leader_decoded := ItemSlotContainer._decode(loaded.profile.leader_loadout, "leader_loadout")
	var overflow_decoded := ItemSlotContainer._decode(loaded.profile.terminal_recovery_overflow, "terminal_recovery_overflow")
	if leader_decoded.error != "" or overflow_decoded.error != "":
		return _failure(profile_id, prefix, "loadout or overflow is invalid")
	var leader := leader_decoded.value as ItemSlotContainer
	var overflow := overflow_decoded.value as ItemSlotContainer
	if not overflow.occupied_slots().is_empty():
		return _failure(profile_id, prefix, "recovery overflow must be empty")
	if leader.occupied_slots().is_empty() and transaction_id.is_empty():
		return _failure(profile_id, prefix, "current leader loadout is empty")
	var selections: Array[ExtractionSelection] = []
	var base_projection := RunExtractionPolicy.project_source(record.snapshot.resolution_source, loaded.profile, selections)
	if base_projection == null:
		return _failure(profile_id, prefix, "automatic extraction preflight is unavailable")
	var eligible_by_id: Dictionary = {}
	for eligible: ExtractionSelection in base_projection.eligible_items:
		eligible_by_id[eligible.item_id] = eligible
	for item_id: String in record.selected_item_ids:
		if not eligible_by_id.has(item_id):
			return _failure(profile_id, prefix, "persisted selection is stale")
		selections.append(eligible_by_id[item_id])
	var preflight_transaction := record.transaction_id if not record.transaction_id.is_empty() else "terminal-protect-preflight:%s" % record.snapshot.run_id
	var resolution_request := RunResolutionRequest.create(preflight_transaction, profile_id, record.snapshot.run_id, record.snapshot.run_seed, record.snapshot.run_player_id, record.snapshot.leader_member_id, selections)
	var preflight := RunResolutionService.new().preflight_source(loaded.profile, record.snapshot.resolution_source, resolution_request)
	if preflight.ok() or not preflight.automatic_only_blocked:
		return _failure(profile_id, prefix, "protection is available only for automatic-only blockage")
	if transaction_id.is_empty():
		var canonical_loadout := JSON.stringify(loaded.profile.leader_loadout, "", true, true)
		transaction_id = "%s%s" % [prefix, canonical_loadout.sha256_text()]
	return _mutations.apply(profile_id, transaction_id, func(candidate: ProfileState) -> String:
		var durable := RunTerminalRecoveryCodec.decode(candidate.terminal_resolution)
		if not durable.ok() or durable.record.to_dictionary() != record.to_dictionary():
			return _error("record", "durable terminal record changed")
		var leader_result := ItemSlotContainer._decode(candidate.leader_loadout, "leader_loadout")
		var overflow_result := ItemSlotContainer._decode(candidate.terminal_recovery_overflow, "terminal_recovery_overflow")
		if leader_result.error != "" or overflow_result.error != "": return _error("containers", "loadout or overflow is invalid")
		var durable_leader := leader_result.value as ItemSlotContainer
		var durable_overflow := overflow_result.value as ItemSlotContainer
		if not durable_overflow.occupied_slots().is_empty(): return _error("terminal_recovery_overflow", "must be empty")
		var protected_ids: Array[String] = []
		for slot: int in durable_leader.occupied_slots():
			var item_id := durable_leader.item_id_at(slot)
			protected_ids.append(item_id)
			durable_overflow._set_item_id(slot, item_id)
			durable_leader._clear_slot(slot)
		candidate.leader_loadout = durable_leader.to_dictionary()
		candidate.terminal_recovery_overflow = durable_overflow.to_dictionary()
		var updated := RunTerminalRecoveryRecord.create(
			record.stage, record.snapshot, record.selected_item_ids, record.transaction_id,
			protected_ids, record.interruption_reason, null, "",
		)
		if not updated.ok(): return updated.error
		candidate.terminal_resolution = updated.record.to_dictionary()
		return ""
	, root, -1, PROTECTION_OPERATION, request)

func _validate_bootstrap_identity(profile: ProfileState, snapshot: RunTerminalSnapshot, require_exact_item_state: bool) -> String:
	if profile == null or snapshot == null or profile.profile_id != snapshot.profile_id:
		return _error("profile_id", "profile and terminal snapshot must match")
	var validation := ResumableRunItemCodec.validate_document(profile.resumable_run, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not validation.is_empty():
		return _error("resumable_run", validation)
	var run := profile.resumable_run
	if StringName(run["run_id"]) != snapshot.run_id or int(run["run_seed"]) != snapshot.run_seed or StringName(run["run_player_id"]) != snapshot.run_player_id or int(run["leader_member_id"]) != snapshot.leader_member_id:
		return _error("run_identity", "strict bootstrap and terminal snapshot must match")
	if require_exact_item_state and run["item_state"] != snapshot.resolution_source.item_state.to_dictionary():
		return _error("item_state", "strict bootstrap must exactly match captured source")
	return ""

func _validate_initial_projection(profile: ProfileState, snapshot: RunTerminalSnapshot) -> String:
	var identity_error := _validate_bootstrap_identity(profile, snapshot, true)
	if not identity_error.is_empty():
		return identity_error
	var decoded := RunTerminalRecoveryCodec.decode(profile.terminal_resolution)
	if not decoded.ok():
		return decoded.error
	var empty_ids: Array[String] = []
	var expected := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION,
		snapshot, empty_ids, "", empty_ids, "", null, "",
	)
	if not expected.ok() or decoded.record.to_dictionary() != expected.record.to_dictionary():
		return _error("terminal_resolution", "committed capture result does not match the supplied snapshot")
	return ""

func _validate_protection_projection(live: ProfileState, committed: ProfileState, supplied: RunTerminalRecoveryRecord) -> String:
	if live == null or committed == null or supplied == null:
		return _error("protection", "live, committed, and supplied truth are required")
	for field: String in ["item_records", "leader_loadout", "terminal_recovery_overflow", "terminal_resolution"]:
		if live.to_dictionary().get(field) != committed.to_dictionary().get(field):
			return _error(field, "durable protection result diverges from the committed result")
	var decoded := RunTerminalRecoveryCodec.decode(committed.terminal_resolution)
	if not decoded.ok():
		return decoded.error
	var durable := decoded.record
	if (
		durable.stage != supplied.stage
		or durable.snapshot.to_dictionary() != supplied.snapshot.to_dictionary()
		or durable.selected_item_ids != supplied.selected_item_ids
		or durable.transaction_id != supplied.transaction_id
		or durable.interruption_reason != supplied.interruption_reason
	):
		return _error("record", "committed protection result does not match the supplied record")
	return ""

func _request_matches_snapshot(request: RunResolutionRequest, snapshot: RunTerminalSnapshot) -> bool:
	return request.profile_id == snapshot.profile_id and request.run_id == snapshot.run_id and request.run_seed == snapshot.run_seed and request.run_player_id == snapshot.run_player_id and request.leader_member_id == snapshot.leader_member_id

func _failure(profile_id: String, transaction_id: String, reason: String) -> ProfileMutationResult:
	var result := ProfileMutationResult.new()
	result.error = "%s profile=%s transaction=%s reason=%s" % [ERROR_PREFIX, profile_id, transaction_id, reason]
	return result

func _error(field: String, reason: String) -> String:
	return "%s field=%s reason=%s" % [ERROR_PREFIX, field, reason]
