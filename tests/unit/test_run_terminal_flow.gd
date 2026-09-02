extends RefCounted

const FLOW_PATH := "res://scripts/run/run_terminal_flow.gd"
const RECOVERY_PATH := "res://scripts/run/run_terminal_recovery_service.gd"
const PROFILE_ID := "profile-terminal-flow"
const RUN_ID := &"run-terminal-flow"
const RUN_PLAYER_ID := &"terminal-flow-player"
const RUN_SEED := 8811
const LEADER_ID := 1
const ITEM_A := "item-terminal-a"
const ITEM_B := "item-terminal-b"
const ITEM_C := "item-terminal-c"
const STATE_CHOOSING_EXTRACTION := 2
const STATE_RESOLUTION_INTERRUPTED := 5
const STATE_RESOLVED_AWAITING_PROJECTION := 6
const STATE_PROJECTION_INTERRUPTED := 7
const STATE_FINALIZED := 8
const BEGIN_READY := 0
const BEGIN_CAPTURE_FAILED := 1
const BEGIN_PERSISTENCE_FAILED := 2
const RECOVERY_STAGE_RESOLVED := 2

var _case_sequence := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_invalid_capture_and_identity_mismatch_are_write_free(failures)
	if not _terminal_authorities_available(failures):
		return failures
	_test_initial_persistence_failure_retry_and_once_only_activation(failures)
	_test_committed_initial_capture_projection_retry(failures)
	_test_selection_matrix_and_exact_transaction_identity(failures)
	_test_resolution_failure_retries_the_identical_request_and_mutates_once(failures)
	_test_pre_resolution_cold_resume_restores_choosing_interrupted_and_selection(failures)
	_test_protection_and_reducible_interruptions(failures)
	_test_post_protection_resolution_failure_preserves_recovery(failures)
	_test_generic_and_terminal_resolution_boundaries(failures)
	_test_victory_reward_outcome_and_existing_city(failures)
	_test_victory_reward_failure_atomicity(failures)
	_test_terminal_duplicate_revalidates_live_resolved_truth(failures)
	_test_projection_retry_uses_durable_truth_without_resolution_or_mutation(failures)
	return failures

func _terminal_authorities_available(failures: Array[String]) -> bool:
	var available := true
	if not ResourceLoader.exists(FLOW_PATH):
		failures.append("terminal flow behavioral coverage is blocked solely because run_terminal_flow.gd is missing")
		available = false
	if not ResourceLoader.exists(RECOVERY_PATH):
		failures.append("terminal persistence behavioral coverage is blocked solely because run_terminal_recovery_service.gd is missing")
		available = false
	return available

func _test_invalid_capture_and_identity_mismatch_are_write_free(failures: Array[String]) -> void:
	if not ResourceLoader.exists(FLOW_PATH):
		return
	var flow_script := load(FLOW_PATH) as Script
	if flow_script == null:
		failures.append("terminal flow behavioral coverage is blocked because run_terminal_flow.gd does not load")
		return
	var flow: Variant = flow_script.new()
	var invalid: Variant = flow.call(&"begin", RunTerminalSnapshot.Outcome.VICTORY, 90.0, null, null, _case_root("invalid"))
	TestAssertions.equal(int(invalid.get("code")) if invalid != null else -1, BEGIN_CAPTURE_FAILED, "invalid capture reports the typed capture-failed result", failures)
	TestAssertions.truthy(bool(flow.call(&"can_begin")), "invalid capture does not consume once-only activation", failures)
	TestAssertions.equal(String(flow.call(&"transaction_base")), "", "invalid capture invents no transaction identity", failures)
	var fixture := _fixture(2)
	var root := _case_root("identity_mismatch")
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(fixture.profile, root), "", "identity mismatch fixture saves", failures)
	var before := FileAccess.get_sha256(store.profile_path(PROFILE_ID, root))
	var wrong_profile: ProfileState = fixture.profile.copy()
	wrong_profile.profile_id = "profile-terminal-other"
	var mismatch: Variant = flow_script.new().call(&"begin", RunTerminalSnapshot.Outcome.VICTORY, 90.0, fixture.context, wrong_profile, root)
	TestAssertions.equal(int(mismatch.get("code")) if mismatch != null else -1, BEGIN_CAPTURE_FAILED, "profile/run identity mismatch fails during capture", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, root)), before, "identity mismatch performs no profile write", failures)
	_free_fixture(fixture, root)

func _test_initial_persistence_failure_retry_and_once_only_activation(failures: Array[String]) -> void:
	var fixture := _fixture(2)
	var root := _case_root("persist_retry")
	var good_store := ProfileStore.new()
	TestAssertions.equal(good_store.save_profile(fixture.profile, root), "", "persistence retry fixture saves", failures)
	var before_hash := FileAccess.get_sha256(good_store.profile_path(PROFILE_ID, root))
	var injection := {"failures_remaining": 2}
	var documents := AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error:
		if int(injection["failures_remaining"]) > 0:
			injection["failures_remaining"] = int(injection["failures_remaining"]) - 1
			return ERR_CANT_CREATE
		return DirAccess.rename_absolute(ProjectSettings.globalize_path(_temporary), ProjectSettings.globalize_path(_target))
	)
	var injected_store := ProfileStore.new(documents)
	var recovery: Variant = (load(RECOVERY_PATH) as Script).new(ProfileMutationService.new(injected_store), injected_store)
	var flow: Variant = (load(FLOW_PATH) as Script).new(recovery, RunResolutionService.new())
	var failed: Variant = flow.call(&"begin", RunTerminalSnapshot.Outcome.VICTORY, 90.0, fixture.context, fixture.profile, root)
	TestAssertions.equal(int(failed.get("code")) if failed != null else -1, BEGIN_PERSISTENCE_FAILED, "initial persistence failure is typed separately from capture failure", failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_RESOLUTION_INTERRUPTED, "initial persistence failure enters the durable interruption state", failures)
	TestAssertions.truthy(not bool(flow.call(&"can_begin")), "initial persistence failure keeps duplicate activation and consequence actions unavailable", failures)
	TestAssertions.equal(FileAccess.get_sha256(good_store.profile_path(PROFILE_ID, root)), before_hash, "initial persistence failure exposes neither checkpoint nor terminal record", failures)
	TestAssertions.equal(good_store.load_profile(PROFILE_ID, root).profile.terminal_resolution, {}, "failed initial persistence writes no receipt", failures)
	var failed_retry: Variant = flow.call(&"retry_persist_initial", root)
	TestAssertions.truthy(not _ok(failed_retry), "retry_persist_initial reports a repeated durable write failure", failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_RESOLUTION_INTERRUPTED, "failed initial retry remains in the initial-persistence interruption", failures)
	TestAssertions.equal(FileAccess.get_sha256(good_store.profile_path(PROFILE_ID, root)), before_hash, "failed initial retry remains write-free", failures)
	TestAssertions.equal(good_store.load_profile(PROFILE_ID, root).profile.terminal_resolution, {}, "failed initial retry exposes no partial receipt", failures)
	var retry: Variant = flow.call(&"retry_persist_initial", root)
	TestAssertions.truthy(_ok(retry), "retry_persist_initial reuses the captured snapshot and succeeds durably: %s" % _error(retry), failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_CHOOSING_EXTRACTION, "successful initial retry opens extraction only after persistence", failures)
	TestAssertions.equal(String(flow.call(&"transaction_base")), "terminal-resolution:%s" % RUN_ID, "initial retry preserves the original base identity", failures)
	var durable := good_store.load_profile(PROFILE_ID, root)
	TestAssertions.truthy(durable.ok() and not durable.profile.terminal_resolution.is_empty(), "successful retry durably publishes the initial terminal record", failures)
	var hash_after_retry := FileAccess.get_sha256(good_store.profile_path(PROFILE_ID, root))
	var duplicate_retry: Variant = flow.call(&"retry_persist_initial", root)
	TestAssertions.truthy(not _ok(duplicate_retry), "initial persistence retry rejects duplicate pending activation", failures)
	TestAssertions.equal(FileAccess.get_sha256(good_store.profile_path(PROFILE_ID, root)), hash_after_retry, "duplicate initial retry performs no write", failures)
	var duplicate_begin: Variant = flow.call(&"begin", RunTerminalSnapshot.Outcome.VICTORY, 90.0, fixture.context, fixture.profile, root)
	TestAssertions.truthy(duplicate_begin != null and int(duplicate_begin.get("code")) != BEGIN_READY, "once-only flow rejects a duplicate terminal event", failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_CHOOSING_EXTRACTION, "duplicate terminal event cannot disturb the active picker", failures)
	_free_fixture(fixture, root)

func _test_committed_initial_capture_projection_retry(failures: Array[String]) -> void:
	var fixture := _fixture(2)
	var root := _case_root("committed_capture_projection_retry")
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(fixture.profile, root), "", "committed capture projection-retry fixture saves", failures)
	var recovery_script := GDScript.new()
	recovery_script.source_code = """extends \"res://scripts/run/run_terminal_recovery_service.gd\"
var persist_calls := 0
func persist_initial(profile_id: String, snapshot: RunTerminalSnapshot, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
    persist_calls += 1
    var result := super.persist_initial(profile_id, snapshot, root)
    if persist_calls == 1 and result.ok():
        var mismatched := result.profile.copy()
        mismatched.profile_id = \"profile-projection-mismatch\"
        result.profile = mismatched
    return result
"""
	if recovery_script.reload() != OK:
		failures.append("committed capture projection-retry collaborator compiles")
		_free_fixture(fixture, root)
		return
	var recovery: Variant = recovery_script.new(ProfileMutationService.new(store), store)
	var flow: Variant = (load(FLOW_PATH) as Script).new(recovery, RunResolutionService.new())
	var first: Variant = flow.call(&"begin", RunTerminalSnapshot.Outcome.VICTORY, 90.0, fixture.context, fixture.profile, root)
	TestAssertions.equal(int(first.get("code")) if first != null else -1, BEGIN_PERSISTENCE_FAILED, "post-commit projection failure remains typed as initial terminal publication failure", failures)
	TestAssertions.truthy(not store.load_profile(PROFILE_ID, root).profile.terminal_resolution.is_empty(), "post-commit projection failure retains the durable initial receipt", failures)
	var retry: Variant = flow.call(&"retry_persist_initial", root)
	TestAssertions.truthy(_ok(retry), "post-commit projection failure retries the idempotent initial capture: %s" % _error(retry), failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_CHOOSING_EXTRACTION, "post-commit projection retry reaches extraction without recapture", failures)
	TestAssertions.equal(int(recovery.get("persist_calls")), 2, "post-commit projection retry reuses the same capture exactly once", failures)
	_free_fixture(fixture, root)

func _test_selection_matrix_and_exact_transaction_identity(failures: Array[String]) -> void:
	var zero_capacity := _begun_flow(0, "zero_capacity", failures)
	if not zero_capacity.is_empty():
		var zero_before := FileAccess.get_sha256(zero_capacity.store.profile_path(PROFILE_ID, zero_capacity.root))
		var zero_result: Variant = zero_capacity.flow.call(&"confirm_extraction", _strings([]), zero_capacity.store.load_profile(PROFILE_ID, zero_capacity.root).profile)
		TestAssertions.truthy(_ok(zero_result), "zero extraction capacity accepts the exact empty ordinary selection", failures)
		TestAssertions.equal(_selected_ids(zero_result), [], "zero capacity confirms no ordinary items", failures)
		TestAssertions.equal(String(zero_capacity.flow.call(&"transaction_id")), _expected_transaction(zero_capacity.flow, []), "zero capacity receives the exact empty-selection transaction identity", failures)
		TestAssertions.truthy(FileAccess.get_sha256(zero_capacity.store.profile_path(PROFILE_ID, zero_capacity.root)) != zero_before, "zero-capacity confirmation durably records the exact empty selection", failures)
		_cleanup_begun(zero_capacity)
	var all_fit := _begun_flow(3, "all_fit", failures)
	if all_fit.is_empty(): return
	var all_ids := _eligible_ids(all_fit.flow.call(&"extraction_projection"))
	var all_result: Variant = all_fit.flow.call(&"confirm_extraction", all_ids, all_fit.store.load_profile(PROFILE_ID, all_fit.root).profile)
	TestAssertions.truthy(_ok(all_result), "all eligible items fit and confirm as one canonical selection", failures)
	TestAssertions.equal(_selected_ids(all_result), all_ids, "all-fit confirmation maps exact policy selections", failures)
	_cleanup_begun(all_fit)
	var constrained := _begun_flow(2, "constrained_a", failures)
	var permutation := _begun_flow(2, "constrained_b", failures)
	var changed := _begun_flow(2, "constrained_changed", failures)
	if constrained.is_empty() or permutation.is_empty() or changed.is_empty():
		_cleanup_begun(constrained); _cleanup_begun(permutation); _cleanup_begun(changed); return
	var canonical_ids := _eligible_ids(constrained.flow.call(&"extraction_projection"))
	var first_result: Variant = constrained.flow.call(&"confirm_extraction", _strings([canonical_ids[2], canonical_ids[0]]), constrained.store.load_profile(PROFILE_ID, constrained.root).profile)
	var second_result: Variant = permutation.flow.call(&"confirm_extraction", _strings([canonical_ids[0], canonical_ids[2]]), permutation.store.load_profile(PROFILE_ID, permutation.root).profile)
	TestAssertions.truthy(_ok(first_result) and _ok(second_result), "constrained selections accept both input permutations", failures)
	TestAssertions.equal(_selected_ids(first_result), [canonical_ids[0], canonical_ids[2]], "constrained selections rebuild in eligible-item order", failures)
	var first_transaction := String(constrained.flow.call(&"transaction_id"))
	var duplicate_confirm_hash := FileAccess.get_sha256(constrained.store.profile_path(PROFILE_ID, constrained.root))
	var duplicate_confirm: Variant = constrained.flow.call(&"confirm_extraction", _strings([canonical_ids[2], canonical_ids[0]]), constrained.store.load_profile(PROFILE_ID, constrained.root).profile)
	TestAssertions.truthy(_ok(duplicate_confirm), "duplicate Confirm reuses the already accepted canonical selection", failures)
	TestAssertions.equal(_selected_ids(duplicate_confirm), [canonical_ids[0], canonical_ids[2]], "duplicate Confirm returns the exact accepted projection", failures)
	TestAssertions.equal(String(constrained.flow.call(&"transaction_id")), first_transaction, "duplicate Confirm reuses the exact request transaction", failures)
	TestAssertions.equal(FileAccess.get_sha256(constrained.store.profile_path(PROFILE_ID, constrained.root)), duplicate_confirm_hash, "duplicate Confirm performs no second selection write", failures)
	TestAssertions.equal(String(permutation.flow.call(&"transaction_id")), first_transaction, "selection transaction identity is permutation-stable", failures)
	TestAssertions.equal(first_transaction, _expected_transaction(constrained.flow, [canonical_ids[0], canonical_ids[2]]), "selection transaction is the exact full canonical SHA-256 identity", failures)
	var changed_result: Variant = changed.flow.call(&"confirm_extraction", _strings([canonical_ids[0], canonical_ids[1]]), changed.store.load_profile(PROFILE_ID, changed.root).profile)
	TestAssertions.truthy(_ok(changed_result), "a different valid constrained selection confirms", failures)
	TestAssertions.truthy(String(changed.flow.call(&"transaction_id")) != first_transaction, "changed canonical selection receives a different transaction identity", failures)
	var persisted: ProfileState = constrained.store.load_profile(PROFILE_ID, constrained.root).profile
	TestAssertions.equal(String(persisted.terminal_resolution.get("transaction_id", "")), first_transaction, "canonical selection is persisted before resolution mutation", failures)
	TestAssertions.equal(persisted.terminal_resolution.get("selected_item_ids", []), [canonical_ids[0], canonical_ids[2]], "durable selection stores canonical IDs rather than click order", failures)
	_cleanup_begun(constrained); _cleanup_begun(permutation); _cleanup_begun(changed)
	for test_case: Dictionary in [
		{"label": "duplicate", "capacity": 2, "ids": [ITEM_A, ITEM_A], "fragment": "duplicate"},
		{"label": "stale", "capacity": 2, "ids": ["item-terminal-stale"], "fragment": "changed"},
		{"label": "over_capacity", "capacity": 1, "ids": [ITEM_A, ITEM_B], "fragment": "capacity"},
	]:
		var rejected := _begun_flow(int(test_case.capacity), String(test_case.label), failures)
		if rejected.is_empty(): continue
		var before_hash := FileAccess.get_sha256(rejected.store.profile_path(PROFILE_ID, rejected.root))
		var result: Variant = rejected.flow.call(&"confirm_extraction", _strings(test_case.ids), rejected.store.load_profile(PROFILE_ID, rejected.root).profile)
		TestAssertions.truthy(not _ok(result) and _error(result).to_lower().contains(String(test_case.fragment)), "%s canonical selection is rejected readably" % test_case.label, failures)
		TestAssertions.equal(String(rejected.flow.call(&"transaction_id")), "", "%s rejection invents no transaction" % test_case.label, failures)
		TestAssertions.equal(FileAccess.get_sha256(rejected.store.profile_path(PROFILE_ID, rejected.root)), before_hash, "%s rejection performs no selection write" % test_case.label, failures)
		TestAssertions.equal(int(rejected.flow.call(&"state")), STATE_CHOOSING_EXTRACTION, "%s rejection remains at policy-backed choice" % test_case.label, failures)
		_cleanup_begun(rejected)

func _test_resolution_failure_retries_the_identical_request_and_mutates_once(failures: Array[String]) -> void:
	var resolution_script := _fail_first_recording_resolution_script()
	if resolution_script == null:
		failures.append("resolution retry behavior could not compile its real service collaborator")
		return
	var fixture := _fixture(1)
	var root := _case_root("resolution_retry_identity")
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(fixture.profile, root), "", "resolution retry fixture saves", failures)
	var evaluator_counts := {"calls": 0}
	var evaluator := func(profile: ProfileState, source: RunResolutionSource, request: RunResolutionRequest) -> RunResolutionEvaluation:
		evaluator_counts["calls"] = int(evaluator_counts["calls"]) + 1
		return RunResolutionEvaluator.evaluate(profile, source, request)
	var resolution: Variant = resolution_script.new(ProfileMutationService.new(store), evaluator)
	var recovery: Variant = (load(RECOVERY_PATH) as Script).new(ProfileMutationService.new(store), store)
	var flow: Variant = (load(FLOW_PATH) as Script).new(recovery, resolution)
	var begun: Variant = flow.call(&"begin", RunTerminalSnapshot.Outcome.VICTORY, 90.0, fixture.context, fixture.profile, root)
	TestAssertions.truthy(_ok(begun), "resolution retry flow begins against real durable recovery", failures)
	if not _ok(begun):
		failures.append("resolution retry identity/once-only assertions skipped because the default-failure flow cannot begin")
		_free_fixture(fixture, root)
		return
	var confirmed: Variant = flow.call(&"confirm_extraction", _strings([ITEM_A]), store.load_profile(PROFILE_ID, root).profile)
	TestAssertions.truthy(_ok(confirmed), "resolution retry flow confirms one exact item", failures)
	if not _ok(confirmed):
		failures.append("resolution retry identity/once-only assertions skipped because confirmation is unavailable")
		_free_fixture(fixture, root)
		return
	var exact_transaction := String(flow.call(&"transaction_id"))
	var first_failure: Variant = flow.call(&"resolve", PROFILE_ID, root)
	TestAssertions.truthy(not _ok(first_failure) and _error(first_failure).contains("injected first resolution interruption"), "first terminal resolution failure is readable and retryable", failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_RESOLUTION_INTERRUPTED, "resolution failure enters the distinct resolution interruption state", failures)
	TestAssertions.equal(resolution.get("request_documents").size(), 1, "failed resolution receives exactly one request", failures)
	TestAssertions.equal(String((resolution.get("request_documents") as Array)[0].get("transaction_id", "")), exact_transaction, "failed resolution receives the confirmed transaction", failures)
	var after_failure := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.equal(after_failure.passive_points_available, 0, "failed terminal resolution grants no passive point", failures)
	TestAssertions.truthy(CityVictoryRewardPolicy.CITY_TREE_ID not in after_failure.discovered_trees, "failed terminal resolution does not reveal City", failures)
	var retried: Variant = flow.call(&"resolve", PROFILE_ID, root)
	TestAssertions.truthy(_ok(retried) and not bool(retried.get("duplicate")), "resolution retry succeeds without manufacturing a duplicate", failures)
	TestAssertions.equal(resolution.get("request_documents").size(), 2, "resolution retry delegates exactly twice including the injected interruption", failures)
	TestAssertions.equal((resolution.get("request_documents") as Array)[1], (resolution.get("request_documents") as Array)[0], "resolution retry reuses the byte-structurally identical canonical request", failures)
	TestAssertions.equal(int(resolution.get("delegated_calls")), 1, "only the successful retry reaches the real terminal resolver", failures)
	TestAssertions.equal(int(evaluator_counts["calls"]), 2, "one pure preflight plus one durable resolution mutation evaluate exactly once each", failures)
	var durable := store.load_profile(PROFILE_ID, root)
	var decoded := ItemRegistry._decode(durable.profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(durable.ok() and String(decoded.error).is_empty(), "once-only resolution leaves valid durable ownership", failures)
	if durable.ok() and String(decoded.error).is_empty():
		TestAssertions.equal((decoded.value as ItemRegistry).ids().count(ITEM_A), 1, "once-only resolution owns the selected item exactly once", failures)
		TestAssertions.equal(durable.profile.passive_points_available, 1, "successful retry grants exactly one victory point", failures)
		TestAssertions.equal(durable.profile.tree_allocations.get(CityVictoryRewardPolicy.CITY_TREE_ID, []), [CityVictoryRewardPolicy.CITY_ROOT_ID], "successful retry reveals City and seeds its free root", failures)
	var after_success := FileAccess.get_sha256(store.profile_path(PROFILE_ID, root))
	var invalid_post_success: Variant = flow.call(&"resolve", PROFILE_ID, root)
	TestAssertions.truthy(not _ok(invalid_post_success), "resolved flow rejects a further resolution transition", failures)
	TestAssertions.equal(int(resolution.get("delegated_calls")), 1, "post-success retry cannot invoke the terminal mutation again", failures)
	TestAssertions.equal(int(evaluator_counts["calls"]), 2, "post-success retry cannot reevaluate either preflight or accepted mutation", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, root)), after_success, "post-success retry performs no write", failures)
	_free_fixture(fixture, root)

func _test_pre_resolution_cold_resume_restores_choosing_interrupted_and_selection(failures: Array[String]) -> void:
	var begun := _begun_flow(2, "cold_pre_resolution", failures)
	if begun.is_empty():
		failures.append("pre-resolution cold-resume assertions skipped because the default-failure flow cannot begin")
		return
	var recovery: Variant = (load(RECOVERY_PATH) as Script).new(ProfileMutationService.new(begun.store), begun.store)
	var choosing_profile: ProfileState = begun.store.load_profile(PROFILE_ID, begun.root).profile
	var choosing_record: Variant = recovery.call(&"inspect", choosing_profile)
	TestAssertions.truthy(_ok(choosing_record), "cold resume inspects the durable choosing record", failures)
	if not _ok(choosing_record):
		failures.append("pre-resolution cold-resume assertions skipped because durable choosing inspection failed")
		_cleanup_begun(begun)
		return
	var cold_choosing: Variant = (load(FLOW_PATH) as Script).new(recovery, RunResolutionService.new(ProfileMutationService.new(begun.store)))
	TestAssertions.truthy(_ok(cold_choosing.call(&"resume", choosing_record.get("record"), choosing_profile, begun.root)), "cold resume reconstructs the choosing picker from typed durable truth", failures)
	TestAssertions.equal(int(cold_choosing.call(&"state")), STATE_CHOOSING_EXTRACTION, "cold choosing resume never returns to combat recovery", failures)
	TestAssertions.equal(_eligible_ids(cold_choosing.call(&"extraction_projection")), _eligible_ids(begun.flow.call(&"extraction_projection")), "cold choosing resume restores the exact policy projection", failures)
	var confirmed: Variant = begun.flow.call(&"confirm_extraction", _strings([ITEM_B]), choosing_profile)
	TestAssertions.truthy(_ok(confirmed), "cold selection fixture confirms one canonical selection", failures)
	if not _ok(confirmed):
		failures.append("selection/interrupted cold-resume assertions skipped because confirmation is unavailable")
		_cleanup_begun(begun)
		return
	var confirmed_transaction := String(begun.flow.call(&"transaction_id"))
	var selected_profile: ProfileState = begun.store.load_profile(PROFILE_ID, begun.root).profile
	var selected_record: Variant = recovery.call(&"inspect", selected_profile)
	TestAssertions.truthy(_ok(selected_record), "cold resume inspects the durable confirmed selection", failures)
	var cold_selected: Variant = (load(FLOW_PATH) as Script).new(recovery, RunResolutionService.new(ProfileMutationService.new(begun.store)))
	TestAssertions.truthy(_ok(cold_selected.call(&"resume", selected_record.get("record"), selected_profile, begun.root)), "cold resume reconstructs a confirmed pre-resolution selection", failures)
	TestAssertions.equal(String(cold_selected.call(&"transaction_id")), confirmed_transaction, "cold selection resume restores the exact confirmed transaction", failures)
	TestAssertions.equal(_strings(cold_selected.call(&"extraction_projection").get("selected_item_ids")), [ITEM_B], "cold selection resume restores exact selected IDs", failures)
	var interruption_script := _fail_first_recording_resolution_script()
	if interruption_script != null:
		begun.flow.set("_resolution", interruption_script.new(ProfileMutationService.new(begun.store)))
	var interrupted: Variant = begun.flow.call(&"resolve", PROFILE_ID, begun.root)
	TestAssertions.truthy(not _ok(interrupted), "injected resolver produces a pre-resolution interruption fixture", failures)
	TestAssertions.equal(int(begun.flow.call(&"state")), STATE_RESOLUTION_INTERRUPTED, "failed resolution persists the explicit interrupted state", failures)
	var interrupted_profile: ProfileState = begun.store.load_profile(PROFILE_ID, begun.root).profile
	var interrupted_record: Variant = recovery.call(&"inspect", interrupted_profile)
	TestAssertions.truthy(_ok(interrupted_record) and int(interrupted_record.get("record").get("stage")) == RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, "cold resume inspects the durable interrupted record", failures)
	if _ok(interrupted_record):
		var cold_interrupted: Variant = (load(FLOW_PATH) as Script).new(recovery, RunResolutionService.new(ProfileMutationService.new(begun.store)))
		TestAssertions.truthy(_ok(cold_interrupted.call(&"resume", interrupted_record.get("record"), interrupted_profile, begun.root)), "cold resume reconstructs the interrupted terminal flow", failures)
		TestAssertions.equal(int(cold_interrupted.call(&"state")), STATE_RESOLUTION_INTERRUPTED, "cold interrupted resume remains retryable and never enters combat", failures)
		TestAssertions.equal(String(cold_interrupted.call(&"transaction_id")), confirmed_transaction, "cold interrupted resume retains the exact retry request identity", failures)
		TestAssertions.equal(_strings(cold_interrupted.call(&"extraction_projection").get("selected_item_ids")), [ITEM_B], "cold interrupted resume retains the confirmed canonical selection", failures)
	_cleanup_begun(begun)

func _test_generic_and_terminal_resolution_boundaries(failures: Array[String]) -> void:
	var generic := _fixture(3)
	var generic_root := _case_root("generic")
	var generic_store := ProfileStore.new()
	TestAssertions.equal(generic_store.save_profile(generic.profile, generic_root), "", "generic resolution fixture saves", failures)
	var source_result := RunResolutionSource.from_context(generic.context, LEADER_ID)
	var selections: Array[ExtractionSelection] = [ExtractionSelection.create(ITEM_A, &"run-inventory", 0)]
	var generic_request := RunResolutionRequest.create("generic-terminal-agnostic", PROFILE_ID, RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, selections)
	var generic_result := RunResolutionService.new(ProfileMutationService.new(generic_store)).resolve_source(PROFILE_ID, source_result.source, generic_request, generic_root)
	TestAssertions.truthy(generic_result.ok(), "generic resolve_source remains terminal-agnostic with an empty terminal record", failures)
	_free_fixture(generic, generic_root)
	var mismatch := _fixture(3)
	var mismatch_root := _case_root("terminal_requires_record")
	var mismatch_store := ProfileStore.new()
	TestAssertions.equal(mismatch_store.save_profile(mismatch.profile, mismatch_root), "", "terminal record mismatch fixture saves", failures)
	var mismatch_source := RunResolutionSource.from_context(mismatch.context, LEADER_ID).source
	var terminal_request := RunResolutionRequest.create("terminal-resolution:%s:missing-record" % RUN_ID, PROFILE_ID, RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, selections)
	var mismatch_hash := FileAccess.get_sha256(mismatch_store.profile_path(PROFILE_ID, mismatch_root))
	var terminal_service := RunResolutionService.new(ProfileMutationService.new(mismatch_store))
	if not terminal_service.has_method(&"resolve_terminal_source"):
		failures.append("terminal resolve behavior is blocked because RunResolutionService.resolve_terminal_source is missing")
	else:
		var rejected: Variant = terminal_service.call(&"resolve_terminal_source", PROFILE_ID, mismatch_source, terminal_request, mismatch_root)
		TestAssertions.truthy(not _ok(rejected), "terminal resolve rejects an empty recovery record", failures)
		TestAssertions.equal(FileAccess.get_sha256(mismatch_store.profile_path(PROFILE_ID, mismatch_root)), mismatch_hash, "empty-record terminal resolve performs no write", failures)
	_free_fixture(mismatch, mismatch_root)
	var begun := _begun_flow(2, "terminal_resolve", failures)
	if begun.is_empty(): return
	var ids := _eligible_ids(begun.flow.call(&"extraction_projection"))
	TestAssertions.truthy(_ok(begun.flow.call(&"confirm_extraction", _strings([ids[1]]), begun.store.load_profile(PROFILE_ID, begun.root).profile)), "terminal resolution fixture confirms", failures)
	var resolved: Variant = begun.flow.call(&"resolve", PROFILE_ID, begun.root)
	TestAssertions.truthy(_ok(resolved) and not bool(resolved.get("duplicate")), "terminal resolution mutates exactly once", failures)
	var durable: ProfileState = begun.store.load_profile(PROFILE_ID, begun.root).profile
	TestAssertions.equal(durable.resumable_run, {}, "terminal resolution atomically revokes the strict run", failures)
	TestAssertions.equal(int(durable.terminal_resolution.get("stage", -1)), RECOVERY_STAGE_RESOLVED, "terminal resolution atomically writes the resolved receipt", failures)
	TestAssertions.equal(durable.passive_points_available, 1, "first committed terminal victory grants one available point", failures)
	TestAssertions.equal(durable.passive_points_lifetime_earned, 1, "first committed terminal victory grants one lifetime point", failures)
	TestAssertions.equal(durable.discovered_trees, [CityVictoryRewardPolicy.CITY_TREE_ID], "first committed terminal victory reveals City", failures)
	TestAssertions.equal(durable.tree_allocations.get(CityVictoryRewardPolicy.CITY_TREE_ID, []), [CityVictoryRewardPolicy.CITY_ROOT_ID], "first committed terminal victory seeds the free City root", failures)
	TestAssertions.equal(int(begun.flow.call(&"state")), STATE_RESOLVED_AWAITING_PROJECTION, "successful resolution awaits recap projection", failures)
	TestAssertions.truthy(bool(begun.flow.call(&"finalize")), "resolved presentation finalizes", failures)
	TestAssertions.equal(int(begun.flow.call(&"state")), STATE_FINALIZED, "finalize enters the action-visible state", failures)
	TestAssertions.truthy(not begun.store.load_profile(PROFILE_ID, begun.root).profile.terminal_resolution.is_empty(), "finalize retains the durable receipt while actions are visible", failures)
	var recovery: Variant = (load(RECOVERY_PATH) as Script).new().call(&"inspect", durable)
	TestAssertions.truthy(_ok(recovery), "resolved receipt reconstructs from durable truth", failures)
	var cold: Variant = (load(FLOW_PATH) as Script).new()
	var cold_resume: Variant = cold.call(&"resume", recovery.get("record"), durable, begun.root)
	TestAssertions.truthy(_ok(cold_resume), "a crash immediately after resolve cold-resumes the recap: %s" % _error(cold_resume), failures)
	TestAssertions.equal(int(cold.call(&"state")), STATE_RESOLVED_AWAITING_PROJECTION, "cold resolved resume never re-enters resolution", failures)
	var duplicate_bytes := FileAccess.get_file_as_bytes(begun.store.profile_path(PROFILE_ID, begun.root))
	var duplicate := RunResolutionService.new(ProfileMutationService.new(begun.store)).resolve_terminal_source(
		PROFILE_ID, begun.flow.call(&"snapshot").resolution_source,
		begun.flow.get("_request") as RunResolutionRequest, begun.root,
	)
	TestAssertions.truthy(duplicate.ok() and duplicate.duplicate, "same terminal transaction replays as a duplicate", failures)
	TestAssertions.equal(begun.store.load_profile(PROFILE_ID, begun.root).profile.passive_points_available, 1, "same terminal transaction cannot grant a second point", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(begun.store.profile_path(PROFILE_ID, begun.root)), duplicate_bytes, "ordinary terminal duplicate is write-free", failures)
	var changed_source_document: Dictionary = begun.flow.call(&"snapshot").resolution_source.to_dictionary()
	(changed_source_document["item_state"]["registry"]["items"] as Array)[0]["item_level"] = 29
	var changed_source := RunResolutionSource.from_dictionary(changed_source_document)
	TestAssertions.truthy(changed_source.ok(), "terminal duplicate changed-source fixture remains typed and valid", failures)
	var before_duplicate_bytes := FileAccess.get_file_as_bytes(begun.store.profile_path(PROFILE_ID, begun.root))
	var duplicate_collision := RunResolutionService.new(ProfileMutationService.new(begun.store)).resolve_terminal_source(
		PROFILE_ID, changed_source.source, begun.flow.get("_request") as RunResolutionRequest, begun.root,
	)
	TestAssertions.truthy(not duplicate_collision.ok(), "same-request terminal duplicate rejects a different typed source", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(begun.store.profile_path(PROFILE_ID, begun.root)), before_duplicate_bytes, "same-request different-source terminal duplicate is write-free", failures)
	_cleanup_begun(begun)

func _test_victory_reward_outcome_and_existing_city(failures: Array[String]) -> void:
	var defeated := _begun_flow(0, "defeat_reward", failures, RunTerminalSnapshot.Outcome.DEFEAT)
	if defeated.is_empty():
		return
	TestAssertions.truthy(_ok(defeated.flow.call(&"confirm_extraction", _strings([]), defeated.store.load_profile(PROFILE_ID, defeated.root).profile)), "defeat fixture confirms empty extraction", failures)
	TestAssertions.truthy(_ok(defeated.flow.call(&"resolve", PROFILE_ID, defeated.root)), "defeat terminal resolution commits", failures)
	var defeated_profile: ProfileState = defeated.store.load_profile(PROFILE_ID, defeated.root).profile
	TestAssertions.equal(defeated_profile.passive_points_available, 0, "defeat grants no passive point", failures)
	TestAssertions.truthy(CityVictoryRewardPolicy.CITY_TREE_ID not in defeated_profile.discovered_trees, "defeat does not reveal City", failures)
	TestAssertions.truthy(not defeated_profile.tree_allocations.has(CityVictoryRewardPolicy.CITY_TREE_ID), "defeat does not seed City Heart", failures)
	_cleanup_begun(defeated)

	var existing := _begun_flow(0, "existing_city_victory", failures, RunTerminalSnapshot.Outcome.VICTORY, func(profile: ProfileState) -> void:
		profile.discovered_trees = [CityVictoryRewardPolicy.CITY_TREE_ID]
		profile.tree_allocations[CityVictoryRewardPolicy.CITY_TREE_ID] = [CityVictoryRewardPolicy.CITY_ROOT_ID]
		profile.passive_points_available = 4
		profile.passive_points_lifetime_earned = 7
	)
	if existing.is_empty():
		return
	TestAssertions.truthy(_ok(existing.flow.call(&"confirm_extraction", _strings([]), existing.store.load_profile(PROFILE_ID, existing.root).profile)), "existing-City fixture confirms empty extraction", failures)
	TestAssertions.truthy(_ok(existing.flow.call(&"resolve", PROFILE_ID, existing.root)), "later unique victory commits", failures)
	var rewarded: ProfileState = existing.store.load_profile(PROFILE_ID, existing.root).profile
	TestAssertions.equal(rewarded.passive_points_available, 5, "later unique victory grants one additional available point", failures)
	TestAssertions.equal(rewarded.passive_points_lifetime_earned, 8, "later unique victory grants one additional lifetime point", failures)
	TestAssertions.equal(rewarded.tree_allocations[CityVictoryRewardPolicy.CITY_TREE_ID], [CityVictoryRewardPolicy.CITY_ROOT_ID], "later victory does not duplicate City Heart", failures)
	_cleanup_begun(existing)

func _test_victory_reward_failure_atomicity(failures: Array[String]) -> void:
	var begun := _begun_flow(0, "victory_reward_failures", failures)
	if begun.is_empty():
		return
	TestAssertions.truthy(_ok(begun.flow.call(&"confirm_extraction", _strings([]), begun.store.load_profile(PROFILE_ID, begun.root).profile)), "reward-failure fixture confirms empty extraction", failures)
	var source: RunResolutionSource = begun.flow.call(&"snapshot").resolution_source
	var request := begun.flow.get("_request") as RunResolutionRequest
	var path: String = begun.store.profile_path(PROFILE_ID, begun.root)
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var before_profile: Dictionary = begun.store.load_profile(PROFILE_ID, begun.root).profile.to_dictionary()

	var evaluator_failure := RunResolutionService.new(ProfileMutationService.new(begun.store), func(_candidate: ProfileState, _source: RunResolutionSource, _request: RunResolutionRequest) -> RunResolutionEvaluation:
		return RunResolutionEvaluation.create(null, 0, 0, 0, "injected evaluator failure", RunResolutionEvaluation.FailureCategory.INTERNAL, "Injected evaluator failure")
	).resolve_terminal_source(PROFILE_ID, source, request, begun.root)
	TestAssertions.truthy(not evaluator_failure.ok() and evaluator_failure.error.contains("injected evaluator failure"), "evaluator failure rejects terminal reward", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "evaluator failure leaves exact profile bytes unchanged", failures)

	var marker_failure := RunResolutionService.new(ProfileMutationService.new(begun.store), func(candidate: ProfileState, live_source: RunResolutionSource, live_request: RunResolutionRequest) -> RunResolutionEvaluation:
		var evaluation := RunResolutionEvaluator.evaluate(candidate, live_source, live_request)
		candidate.terminal_resolution = {}
		return evaluation
	).resolve_terminal_source(PROFILE_ID, source, request, begun.root)
	TestAssertions.truthy(not marker_failure.ok() and marker_failure.error.contains("terminal"), "post-reward terminal marker failure rejects the transaction", failures)
	TestAssertions.equal(marker_failure.failure_category, RunResolutionEvaluation.FailureCategory.INTERNAL, "post-reward marker failure retains the internal failure category", failures)
	TestAssertions.truthy(not marker_failure.player_reason.is_empty(), "post-reward marker failure retains safe player copy", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "post-reward marker failure publishes no extraction City root point or terminal stage", failures)

	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var save_failure := RunResolutionService.new(ProfileMutationService.new(failing_store)).resolve_terminal_source(PROFILE_ID, source, request, begun.root)
	TestAssertions.truthy(not save_failure.ok() and save_failure.error.contains("JSON_STORE_SAVE_ERROR"), "save failure rejects the complete victory transaction", failures)
	TestAssertions.equal(save_failure.failure_category, RunResolutionEvaluation.FailureCategory.INTERNAL, "post-evaluation save failure retains the internal failure category", failures)
	TestAssertions.truthy(not save_failure.player_reason.is_empty(), "post-evaluation save failure retains safe player copy", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "save failure preserves exact durable profile bytes", failures)
	TestAssertions.equal(begun.store.load_profile(PROFILE_ID, begun.root).profile.to_dictionary(), before_profile, "all reward failure paths preserve the complete profile projection", failures)
	_cleanup_begun(begun)

	var overflow := _begun_flow(0, "victory_reward_overflow", failures, RunTerminalSnapshot.Outcome.VICTORY, func(profile: ProfileState) -> void:
		profile.passive_points_available = ProfileCodec.JSON_SAFE_INTEGER_MAX
		profile.passive_points_lifetime_earned = ProfileCodec.JSON_SAFE_INTEGER_MAX
	)
	if overflow.is_empty():
		return
	TestAssertions.truthy(_ok(overflow.flow.call(&"confirm_extraction", _strings([]), overflow.store.load_profile(PROFILE_ID, overflow.root).profile)), "overflow fixture confirms empty extraction", failures)
	var overflow_path: String = overflow.store.profile_path(PROFILE_ID, overflow.root)
	var overflow_bytes := FileAccess.get_file_as_bytes(overflow_path)
	var overflow_result := RunResolutionService.new(ProfileMutationService.new(overflow.store)).resolve_terminal_source(
		PROFILE_ID, overflow.flow.call(&"snapshot").resolution_source,
		overflow.flow.get("_request") as RunResolutionRequest, overflow.root,
	)
	TestAssertions.truthy(not overflow_result.ok() and overflow_result.error.contains("passive_points") and overflow_result.error.contains("overflow"), "victory overflow rejects at the reward boundary", failures)
	TestAssertions.equal(overflow_result.failure_category, RunResolutionEvaluation.FailureCategory.INTERNAL, "victory overflow retains the internal failure category", failures)
	TestAssertions.truthy(not overflow_result.player_reason.is_empty(), "victory overflow retains safe player copy", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(overflow_path), overflow_bytes, "victory overflow is write-free", failures)
	_cleanup_begun(overflow)

func _test_terminal_duplicate_revalidates_live_resolved_truth(failures: Array[String]) -> void:
	var begun := _begun_flow(2, "terminal_duplicate_live_drift", failures)
	if begun.is_empty(): return
	var ids := _eligible_ids(begun.flow.call(&"extraction_projection"))
	TestAssertions.truthy(_ok(begun.flow.call(&"confirm_extraction", _strings([ids[0]]), begun.store.load_profile(PROFILE_ID, begun.root).profile)), "live-drift duplicate fixture confirms", failures)
	var committed: Variant = begun.flow.call(&"resolve", PROFILE_ID, begun.root)
	TestAssertions.truthy(_ok(committed) and not bool(committed.get("duplicate")), "live-drift duplicate fixture resolves once", failures)
	var store := begun.store as ProfileStore
	var live := store.load_profile(PROFILE_ID, begun.root).profile
	var applied_id := String(live.terminal_resolution.get("applied_transaction_id", ""))
	var historical_result := (live.applied_transactions[applied_id]["result_profile"] as Dictionary).duplicate(true)
	var drifted_terminal := live.terminal_resolution.duplicate(true)
	(drifted_terminal["snapshot"] as Dictionary)["elapsed_seconds"] = float((drifted_terminal["snapshot"] as Dictionary)["elapsed_seconds"]) + 1.0
	live.terminal_resolution = drifted_terminal
	TestAssertions.equal(ProfileCodec.validate_profile(live), "", "live terminal-only drift remains structurally valid", failures)
	TestAssertions.equal(store.save_profile(live, begun.root), "", "live terminal-only drift saves", failures)
	var reloaded := store.load_profile(PROFILE_ID, begun.root).profile
	TestAssertions.equal(reloaded.applied_transactions[applied_id]["result_profile"], historical_result, "live terminal-only drift preserves the historical journal result", failures)
	var path := store.profile_path(PROFILE_ID, begun.root)
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var replay := RunResolutionService.new(ProfileMutationService.new(store)).resolve_terminal_source(
		PROFILE_ID,
		begun.flow.call(&"snapshot").resolution_source,
		begun.flow.get("_request") as RunResolutionRequest,
		begun.root,
	)
	TestAssertions.truthy(not replay.ok(), "ordinary terminal duplicate rejects drift in the current live resolved record", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "live resolved-record drift rejection is write-free", failures)
	_cleanup_begun(begun)

func _test_protection_and_reducible_interruptions(failures: Array[String]) -> void:
	var preflight_test: Variant = (load("res://tests/unit/test_run_resolution_preflight.gd") as Script).new()
	var automatic_fixture: Dictionary = preflight_test.call(
		"_fixture", "flow-automatic-protect", 0,
		_strings([RunExtractionPolicy.AUTOMATIC_LEADER_UNLOCK]), 1,
	)
	preflight_test.call("_seed_prior_loadout", automatic_fixture)
	var automatic_id := String((automatic_fixture.profile as ProfileState).profile_id)
	var automatic_profile := (automatic_fixture.store as ProfileStore).load_profile(automatic_id, automatic_fixture.root).profile
	var automatic_flow: Variant = (load(FLOW_PATH) as Script).new()
	var automatic_begin: Variant = automatic_flow.call(
		&"begin", RunTerminalSnapshot.Outcome.VICTORY, 41.0,
		automatic_fixture.context, automatic_profile, automatic_fixture.root,
	)
	TestAssertions.truthy(_ok(automatic_begin), "automatic-only protection flow begins from durable source truth: %s" % _error(automatic_begin), failures)
	if _ok(automatic_begin):
		var blocked: Variant = automatic_flow.call(
			&"confirm_extraction", _strings([]),
			(automatic_fixture.store as ProfileStore).load_profile(automatic_id, automatic_fixture.root).profile,
		)
		TestAssertions.truthy(not _ok(blocked) and bool(blocked.get("automatic_only_blocked")), "automatic-only blockage exposes the typed displaced-gear interruption", failures)
		var interrupted_profile: ProfileState = (automatic_fixture.store as ProfileStore).load_profile(automatic_id, automatic_fixture.root).profile
		var interrupted := RunTerminalRecoveryService.new().inspect(interrupted_profile)
		var interrupted_record := interrupted.record if interrupted.ok() else null
		TestAssertions.truthy(interrupted.ok() and interrupted_record.stage == RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, "automatic-only blockage persists the canonical interrupted stage before Protect is exposed", failures)
		TestAssertions.equal(interrupted_record.transaction_id if interrupted_record != null else "", _expected_transaction(automatic_flow, []), "automatic-only interruption persists the confirmed canonical transaction", failures)
		TestAssertions.equal(interrupted_record.selected_item_ids if interrupted_record != null else [], _strings([]), "automatic-only interruption persists the confirmed canonical selection", failures)
		TestAssertions.equal(interrupted_record.interruption_reason if interrupted_record != null else "", String(blocked.get("player_reason")), "automatic-only interruption persists its exact readable reason", failures)
		var cold_flow: Variant = (load(FLOW_PATH) as Script).new(
			RunTerminalRecoveryService.new(ProfileMutationService.new(automatic_fixture.store), automatic_fixture.store),
			RunResolutionService.new(ProfileMutationService.new(automatic_fixture.store)),
		)
		var cold_resume: Variant = cold_flow.call(&"resume", interrupted_record, interrupted_profile, automatic_fixture.root) if interrupted_record != null else null
		TestAssertions.truthy(_ok(cold_resume) and int(cold_flow.call(&"state")) == STATE_RESOLUTION_INTERRUPTED, "cold resume restores the automatic-only interruption", failures)
		TestAssertions.truthy(bool(cold_flow.call(&"automatic_only_blocked")), "cold resume restores Protect eligibility only after the same typed automatic-only preflight", failures)
		var protected: Variant = cold_flow.call(&"protect_displaced_gear", automatic_id, automatic_fixture.root)
		TestAssertions.truthy(protected is RunResolutionPreflightResult and _ok(protected), "confirmed protection returns the immediate typed post-protection preflight", failures)
		TestAssertions.equal(int(protected.get("mandatory_stash_slots")) if protected is RunResolutionPreflightResult else -1, 0, "post-protection result proves zero mandatory displaced slots before picker presentation", failures)
		TestAssertions.equal(int(cold_flow.call(&"state")), STATE_CHOOSING_EXTRACTION, "successful protection reruns preflight and returns to extraction", failures)
		var refreshed: Variant = cold_flow.call(
			&"confirm_extraction", _strings([]),
			(automatic_fixture.store as ProfileStore).load_profile(automatic_id, automatic_fixture.root).profile,
		)
		TestAssertions.truthy(_ok(refreshed) and int(refreshed.get("mandatory_stash_slots")) == 0, "protection repreflight removes every mandatory displaced slot", failures)
	else:
		failures.append("automatic-only protection transition/repreflight body skipped because typed begin remains RED")
	preflight_test.call("_cleanup", automatic_fixture)

	var reducible_fixture: Dictionary = preflight_test.call("_fixture", "flow-reducible", 1, [], 0)
	var reducible_id := String((reducible_fixture.profile as ProfileState).profile_id)
	var reducible_profile := (reducible_fixture.store as ProfileStore).load_profile(reducible_id, reducible_fixture.root).profile
	var reducible_flow: Variant = (load(FLOW_PATH) as Script).new()
	var reducible_begin: Variant = reducible_flow.call(
		&"begin", RunTerminalSnapshot.Outcome.VICTORY, 42.0,
		reducible_fixture.context, reducible_profile, reducible_fixture.root,
	)
	TestAssertions.truthy(_ok(reducible_begin), "reducible-capacity interruption flow begins from durable source truth: %s" % _error(reducible_begin), failures)
	if _ok(reducible_begin):
		var ids := _eligible_ids(reducible_flow.call(&"extraction_projection"))
		var reduced: Variant = reducible_flow.call(&"confirm_extraction", _strings([ids[0]]), reducible_profile)
		TestAssertions.truthy(not _ok(reduced) and int(reduced.get("failure_category")) == RunResolutionEvaluation.FailureCategory.STASH_REDUCIBLE, "reducible capacity failure retains its typed reducer category", failures)
		TestAssertions.truthy(not bool(reduced.get("automatic_only_blocked")), "reducible capacity never authorizes Protect Displaced Gear", failures)
		TestAssertions.equal(int(reducible_flow.call(&"state")), STATE_CHOOSING_EXTRACTION, "reducible interruption stays at the picker for a smaller selection", failures)
		TestAssertions.truthy(not _ok(reducible_flow.call(&"protect_displaced_gear", reducible_id, reducible_fixture.root)), "reducible interruption rejects the irreversible protection transition", failures)
	else:
		failures.append("reducible preflight interruption body skipped because typed begin remains RED")
	preflight_test.call("_cleanup", reducible_fixture)


func _test_post_protection_resolution_failure_preserves_recovery(failures: Array[String]) -> void:
	var resolution_script := _fail_first_recording_resolution_script()
	var preflight_test: Variant = (load("res://tests/unit/test_run_resolution_preflight.gd") as Script).new()
	if resolution_script == null:
		failures.append("post-protection interruption behavior could not compile its real service collaborator")
		return
	for changed_selection: bool in [false, true]:
		var disposition := "changed" if changed_selection else "same"
		var fixture: Dictionary = preflight_test.call(
			"_fixture", "flow-protected-resolution-%s-%d" % [disposition, Time.get_ticks_usec()], 1,
			_strings([RunExtractionPolicy.AUTOMATIC_LEADER_UNLOCK]), 1,
		)
		preflight_test.call("_seed_prior_loadout", fixture)
		var store := fixture.store as ProfileStore
		var profile := store.load_profile(String((fixture.profile as ProfileState).profile_id), fixture.root).profile
		var profile_id := profile.profile_id
		var mutations := ProfileMutationService.new(store)
		var recovery := RunTerminalRecoveryService.new(mutations, store)
		var resolution: Variant = resolution_script.new(mutations)
		var flow := RunTerminalFlow.new(recovery, resolution)
		var begun := flow.begin(RunTerminalSnapshot.Outcome.VICTORY, 43.0, fixture.context, profile, fixture.root)
		TestAssertions.truthy(begun.ok(), "%s-selection protected interruption fixture begins" % disposition, failures)
		if not begun.ok():
			preflight_test.call("_cleanup", fixture)
			continue
		var original_selected := flow.extraction_projection().selected_item_ids
		var automatic := flow.confirm_extraction(original_selected, store.load_profile(profile_id, fixture.root).profile)
		TestAssertions.truthy(not automatic.ok() and automatic.automatic_only_blocked, "%s-selection fixture reaches automatic-only interruption" % disposition, failures)
		var interrupted_transaction := flow.transaction_id()
		var protected := flow.protect_displaced_gear(profile_id, fixture.root)
		TestAssertions.truthy(protected.ok() and flow.state() == STATE_CHOOSING_EXTRACTION, "%s-selection fixture protects then returns to editable extraction" % disposition, failures)
		var protected_profile := store.load_profile(profile_id, fixture.root).profile
		var protected_inspection := recovery.inspect(protected_profile)
		var protected_ids: Array[String] = protected_inspection.record.protected_displaced_item_ids if protected_inspection.ok() else []
		TestAssertions.truthy(protected_inspection.ok() and not protected_ids.is_empty(), "%s-selection fixture owns exact protected overflow IDs" % disposition, failures)
		var next_selected: Array[String] = original_selected.duplicate()
		if changed_selection:
			var eligible_ids := _eligible_ids(flow.extraction_projection())
			if not eligible_ids.is_empty():
				next_selected.clear()
				next_selected.append(eligible_ids[0])
		var reconfirmed := flow.confirm_extraction(next_selected, protected_profile)
		TestAssertions.truthy(reconfirmed.ok(), "%s-selection fixture confirms after protection" % disposition, failures)
		var resolution_transaction := flow.transaction_id()
		TestAssertions.equal(resolution_transaction == interrupted_transaction, not changed_selection, "%s-selection canonical transaction identity is exact" % disposition, failures)
		var applied_before := store.load_profile(profile_id, fixture.root).profile.applied_transactions.size()
		var failed := flow.resolve(profile_id, fixture.root)
		TestAssertions.truthy(not failed.ok() and failed.error.contains("injected first resolution interruption"), "%s-selection resolver failure remains readable" % disposition, failures)
		var durable_profile := store.load_profile(profile_id, fixture.root).profile
		var durable := recovery.inspect(durable_profile)
		TestAssertions.truthy(durable.ok() and durable.record.stage == RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, "%s-selection resolver failure durably owns the interrupted stage" % disposition, failures)
		if durable.ok():
			TestAssertions.equal(durable.record.protected_displaced_item_ids, protected_ids, "%s-selection resolver failure retains exact protected IDs" % disposition, failures)
			TestAssertions.equal(durable.record.interruption_reason, failed.error, "%s-selection durable interruption retains exact resolver reason" % disposition, failures)
		TestAssertions.equal(durable_profile.applied_transactions.size(), applied_before + 1, "%s-selection resolver failure commits one distinct interruption phase" % disposition, failures)
		var cold := RunTerminalFlow.new(recovery, RunResolutionService.new(ProfileMutationService.new(store)))
		TestAssertions.truthy(durable.ok() and cold.resume(durable.record, durable_profile, fixture.root).ok(), "%s-selection protected interruption cold-resumes" % disposition, failures)
		TestAssertions.equal(cold.state(), STATE_RESOLUTION_INTERRUPTED, "%s-selection cold resume remains resolution-interrupted" % disposition, failures)
		if not protected_ids.is_empty():
			var overflow := ItemSlotContainer._decode(durable_profile.terminal_recovery_overflow, "terminal_recovery_overflow")
			var protected_slot := -1
			if String(overflow.error).is_empty():
				for slot: int in (overflow.value as ItemSlotContainer).occupied_slots():
					if (overflow.value as ItemSlotContainer).item_id_at(slot) == protected_ids[0]:
						protected_slot = slot
						break
			var lock_before := FileAccess.get_sha256(store.profile_path(profile_id, fixture.root))
			var locked := ProfileItemStorageService.new(ProfileMutationService.new(store)).apply(
				profile_id,
				ItemTransactionRequest.move("protected-interruption-lock-%s" % disposition, profile_id, ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, protected_slot, protected_ids[0], &"stash-tab-000", 99),
				fixture.root,
			)
			TestAssertions.truthy(not locked.ok() and locked.error.contains("Available after terminal resolution"), "%s-selection cold recovery retains exact protected storage lock" % disposition, failures)
			TestAssertions.equal(FileAccess.get_sha256(store.profile_path(profile_id, fixture.root)), lock_before, "%s-selection protected storage lock rejection is write-free" % disposition, failures)
		preflight_test.call("_cleanup", fixture)

func _test_projection_retry_uses_durable_truth_without_resolution_or_mutation(failures: Array[String]) -> void:
	var mutation_script := _counting_mutation_script()
	var resolution_script := _counting_resolution_script()
	if mutation_script == null or resolution_script == null:
		failures.append("projection retry call-count behavior could not compile its real collaborator spies"); return
	var fixture := _fixture(2)
	var root := _case_root("projection_retry")
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(fixture.profile, root), "", "projection retry fixture saves", failures)
	var mutations: Variant = mutation_script.new(store)
	var evaluator_counts := {"calls": 0}
	var evaluator := func(profile: ProfileState, source: RunResolutionSource, request: RunResolutionRequest) -> RunResolutionEvaluation:
		evaluator_counts["calls"] = int(evaluator_counts["calls"]) + 1
		return RunResolutionEvaluator.evaluate(profile, source, request)
	var resolution: Variant = resolution_script.new(mutations, evaluator)
	var recovery: Variant = (load(RECOVERY_PATH) as Script).new(mutations, store)
	var flow: Variant = (load(FLOW_PATH) as Script).new(recovery, resolution)
	TestAssertions.truthy(_ok(flow.call(&"begin", RunTerminalSnapshot.Outcome.VICTORY, 33.0, fixture.context, fixture.profile, root)), "projection retry flow begins", failures)
	TestAssertions.truthy(_ok(flow.call(&"confirm_extraction", _strings([ITEM_A]), store.load_profile(PROFILE_ID, root).profile)), "projection retry flow confirms", failures)
	TestAssertions.truthy(_ok(flow.call(&"resolve", PROFILE_ID, root)), "projection retry flow resolves once", failures)
	var durable_before_projection := store.load_profile(PROFILE_ID, root).profile
	var missing_receipt := durable_before_projection.copy()
	missing_receipt.terminal_resolution = {}
	TestAssertions.equal(store.save_profile(missing_receipt, root), "", "projection-interruption receipt-drift fixture saves", failures)
	TestAssertions.truthy(not bool(flow.call(&"mark_projection_interrupted", "recap projection failed")), "projection interruption rejects a missing durable resolved receipt", failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_RESOLVED_AWAITING_PROJECTION, "rejected projection interruption preserves resolved state", failures)
	TestAssertions.equal(store.save_profile(durable_before_projection, root), "", "projection-interruption exact receipt restores", failures)
	TestAssertions.truthy(bool(flow.call(&"mark_projection_interrupted", "recap projection failed")), "projection failure retains a retryable receipt", failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_PROJECTION_INTERRUPTED, "projection failure has a distinct state", failures)
	mutations.set("calls", 0); resolution.set("terminal_calls", 0); evaluator_counts["calls"] = 0
	var durable := store.load_profile(PROFILE_ID, root).profile
	var wrong := durable.copy()
	wrong.terminal_resolution["applied_transaction_id"] = "wrong-transaction"
	TestAssertions.truthy(not _ok(flow.call(&"retry_projection", wrong)), "projection retry fails closed against mismatched durable truth", failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_PROJECTION_INTERRUPTED, "failed projection retry remains retryable", failures)
	TestAssertions.truthy(_ok(flow.call(&"retry_projection", durable)), "projection retry rebuilds accepted result from durable truth", failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_RESOLVED_AWAITING_PROJECTION, "successful projection retry returns to recap", failures)
	var first_accepted: Variant = flow.call(&"accepted_result")
	if first_accepted != null:
		var escaped_ids: Array[String] = first_accepted.get("protected_displaced_item_ids")
		escaped_ids.append("escaped-protected-id")
		var escaped_projection: RunExtractionProjection = first_accepted.get("accepted_extraction")
		if escaped_projection != null:
			escaped_projection._selected_item_ids.append("escaped-selected-id")
		var defensive: Variant = flow.call(&"accepted_result")
		TestAssertions.truthy(defensive != first_accepted, "accepted_result returns a defensive result object", failures)
		TestAssertions.truthy("escaped-protected-id" not in defensive.get("protected_displaced_item_ids"), "accepted_result protects displaced IDs from caller mutation", failures)
		TestAssertions.truthy("escaped-selected-id" not in defensive.get("accepted_extraction").get("selected_item_ids"), "accepted_result protects accepted extraction from caller mutation", failures)
	else:
		failures.append("defensive accepted_result body skipped because projection retry has no accepted result")
	TestAssertions.truthy(_ok(flow.call(&"retry_projection", durable)), "repeated successful projection retry is bounded and idempotent", failures)
	TestAssertions.equal(int(mutations.get("calls")), 0, "projection retry makes zero profile mutation calls", failures)
	TestAssertions.equal(int(resolution.get("terminal_calls")), 0, "projection retry makes zero resolution service calls", failures)
	TestAssertions.equal(int(evaluator_counts["calls"]), 0, "projection retry makes zero evaluator calls", failures)
	var durable_before_finalize := store.load_profile(PROFILE_ID, root).profile
	var replaced_receipt := durable_before_finalize.copy()
	replaced_receipt.terminal_resolution = {}
	TestAssertions.equal(store.save_profile(replaced_receipt, root), "", "finalize receipt-drift fixture saves", failures)
	TestAssertions.truthy(not bool(flow.call(&"finalize")), "finalize rejects replaced durable resolved truth", failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_RESOLVED_AWAITING_PROJECTION, "rejected finalize never exposes consequence actions", failures)
	TestAssertions.equal(store.save_profile(durable_before_finalize, root), "", "finalize exact receipt restores", failures)
	TestAssertions.truthy(bool(flow.call(&"finalize")), "projection retry result finalizes only after durable receipt verification", failures)
	var finalized_hash := FileAccess.get_sha256(store.profile_path(PROFILE_ID, root))
	for rejected: Dictionary in [
		{"label": "begin", "result": flow.call(&"begin", RunTerminalSnapshot.Outcome.VICTORY, 33.0, fixture.context, fixture.profile, root)},
		{"label": "confirm", "result": flow.call(&"confirm_extraction", _strings([ITEM_A]), durable)},
		{"label": "resolve", "result": flow.call(&"resolve", PROFILE_ID, root)},
		{"label": "projection interrupt", "result": flow.call(&"mark_projection_interrupted", "late")},
		{"label": "projection retry", "result": flow.call(&"retry_projection", durable)},
		{"label": "protect", "result": flow.call(&"protect_displaced_gear", PROFILE_ID, root)},
	]:
		var value: Variant = rejected.result
		var rejected_ok := bool(value) if value is bool else _ok(value)
		TestAssertions.truthy(not rejected_ok, "FINALIZED rejects %s transition" % rejected.label, failures)
	TestAssertions.equal(int(flow.call(&"state")), STATE_FINALIZED, "no invalid transition leaves FINALIZED", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, root)), finalized_hash, "post-FINALIZED invalid transitions perform no write", failures)
	TestAssertions.equal(int(mutations.get("calls")), 0, "post-FINALIZED invalid transitions invoke no mutation", failures)
	TestAssertions.equal(int(resolution.get("terminal_calls")), 0, "post-FINALIZED invalid transitions invoke no resolution", failures)
	_free_fixture(fixture, root)

func _begun_flow(
	capacity: int,
	label: String,
	failures: Array[String],
	outcome: RunTerminalSnapshot.Outcome = RunTerminalSnapshot.Outcome.VICTORY,
	prepare_profile: Callable = Callable(),
) -> Dictionary:
	var fixture := _fixture(capacity)
	if prepare_profile.is_valid():
		prepare_profile.call(fixture.profile)
	var root := _case_root(label)
	var store := ProfileStore.new()
	if not store.save_profile(fixture.profile, root).is_empty():
		failures.append("%s fixture could not save" % label); _free_fixture(fixture, root); return {}
	var flow: Variant = (load(FLOW_PATH) as Script).new()
	var result: Variant = flow.call(&"begin", outcome, 90.0, fixture.context, fixture.profile, root)
	if not _ok(result):
		failures.append("%s terminal flow could not begin: %s" % [label, _error(result)]); _free_fixture(fixture, root); return {}
	TestAssertions.equal(int(flow.call(&"state")), STATE_CHOOSING_EXTRACTION, "%s opens extraction only after persistence" % label, failures)
	return {"fixture": fixture, "root": root, "store": store, "flow": flow}

func _fixture(capacity: int) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var state := ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new([_item(ITEM_A, 0), _item(ITEM_B, 1), _item(ITEM_C, 2)]), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10, {0: ITEM_A, 1: ITEM_B, 2: ITEM_C}),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity()),
		RunItemBootstrap.ground_items_container(String(RUN_PLAYER_ID)),
	])
	var bootstrap := RunItemBootstrap.create(RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, state, &"fighter")
	var profile := ProfileState.new_profile(PROFILE_ID, "Terminal Flow", 1000)
	profile.inventory_columns = 2; profile.extraction_capacity = capacity; profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-terminal-flow", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, ItemSlotContainer.STASH_CAPACITY).to_dictionary()]
	var context := PlayerRunContext.new()
	assert(context.configure(RUN_PLAYER_ID, 0, profile, RUN_SEED, party, 100, bootstrap).is_empty())
	return {"profile": profile, "party": party, "context": context}

func _item(instance_id: String, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id; item.base_definition_id = &"forge_vanguard_sword"; item.item_level = 28; item.rarity_id = &"common"; item.affixes = []
	item.origin = {"issuer_namespace": "run:%s:%d:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID], "seed": RUN_SEED, "sequence": sequence, "source": "terminal_flow_test"}
	return item

func _eligible_ids(projection: Variant) -> Array[String]:
	var ids: Array[String] = []
	if projection != null:
		for selection: ExtractionSelection in projection.get("eligible_items"): ids.append(selection.item_id)
	return ids

func _selected_ids(result: Variant) -> Array[String]:
	var projection: Variant = result.get("extraction") if result != null else null
	return _strings(projection.get("selected_item_ids")) if projection != null else []

func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result

func _expected_transaction(flow: Variant, selected_ids: Array[String]) -> String:
	var wanted: Dictionary = {}
	for item_id: String in selected_ids: wanted[item_id] = true
	var documents: Array[Dictionary] = []
	for selection: ExtractionSelection in flow.call(&"extraction_projection").get("eligible_items"):
		if wanted.has(selection.item_id): documents.append(selection.to_dictionary())
	return "%s:%s" % [flow.call(&"transaction_base"), JSON.stringify(documents).sha256_text()]

func _fail_first_recording_resolution_script() -> Script:
	var script := GDScript.new()
	script.source_code = """extends \"res://scripts/extraction/run_resolution_service.gd\"
var request_documents: Array[Dictionary] = []
var delegated_calls := 0
func resolve_terminal_source(profile_id: String, source: RunResolutionSource, request: RunResolutionRequest, root: String = ProfileStore.DEFAULT_ROOT) -> RunResolutionResult:
    request_documents.append(request.canonical_document())
    if request_documents.size() == 1:
        return RunResolutionResult.failure(\"PARTY_FORGE_RUN_RESOLUTION_ERROR field=resolution reason=injected first resolution interruption\")
    delegated_calls += 1
    return super.resolve_terminal_source(profile_id, source, request, root)
"""
	return script if script.reload() == OK else null

func _counting_mutation_script() -> Script:
	var script := GDScript.new()
	script.source_code = """extends \"res://scripts/profile/profile_mutation_service.gd\"
var calls := 0
func apply(profile_id: String, transaction_id: String, mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1, operation: String = \"\", request: Dictionary = {}) -> ProfileMutationResult:
    calls += 1
    return super.apply(profile_id, transaction_id, mutate, root, now_unix, operation, request)
func apply_irreversible_terminal_completion(profile_id: String, transaction_id: String, terminal_run_id: StringName, terminal_instance_ids: Array[String], mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1, operation: String = \"\", request: Dictionary = {}) -> ProfileMutationResult:
    calls += 1
    return super.apply_irreversible_terminal_completion(profile_id, transaction_id, terminal_run_id, terminal_instance_ids, mutate, root, now_unix, operation, request)
"""
	return script if script.reload() == OK else null

func _counting_resolution_script() -> Script:
	var script := GDScript.new()
	script.source_code = """extends \"res://scripts/extraction/run_resolution_service.gd\"
var terminal_calls := 0
func resolve_terminal_source(profile_id: String, source: RunResolutionSource, request: RunResolutionRequest, root: String = ProfileStore.DEFAULT_ROOT) -> RunResolutionResult:
    terminal_calls += 1
    return super.resolve_terminal_source(profile_id, source, request, root)
"""
	return script if script.reload() == OK else null

func _ok(value: Variant) -> bool: return value != null and value.has_method(&"ok") and bool(value.call(&"ok"))
func _error(value: Variant) -> String: return String(value.get("error")) if value != null else "result is null"
func _case_root(label: String) -> String:
	_case_sequence += 1
	return "user://tests/run_terminal_flow_%d_%d_%s_%d" % [OS.get_process_id(), Time.get_ticks_usec(), label, _case_sequence]
func _cleanup_begun(value: Dictionary) -> void:
	if not value.is_empty(): _free_fixture(value.fixture, String(value.root))
func _free_fixture(fixture: Dictionary, root: String) -> void:
	if not fixture.is_empty() and fixture.get("party") is PartyManager: (fixture.party as PartyManager).free()
	ProfileTestSupport.remove_tree(root)
