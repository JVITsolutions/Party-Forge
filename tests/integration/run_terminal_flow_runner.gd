extends SceneTree

const PROFILE_ROOT := "user://tests/run_terminal_flow_profiles"
const SETTINGS_PATH := "user://tests/run_terminal_flow_settings.cfg"
const MAIN_SCENE := preload("res://scenes/game/main.tscn")
const RESTART_INTENT_PATH := "res://scripts/ui/run_setup/run_setup_restart_intent.gd"
const ACTION_ROOT := "Frame/Content/Footer/Actions/"
const CITY_TREE_ID := "party-forge-city-v1"
const CITY_ROOT_NODE_ID := "city-heart"

class CountingMutationService extends ProfileMutationService:
	var apply_calls := 0
	var revocation_calls := 0
	var completion_calls := 0

	func apply(profile_id: String, transaction_id: String, mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1, operation: String = "", request: Dictionary = {}) -> ProfileMutationResult:
		apply_calls += 1
		return super.apply(profile_id, transaction_id, mutate, root, now_unix, operation, request)

	func apply_irreversible_terminal_completion(profile_id: String, transaction_id: String, terminal_run_id: StringName, terminal_instance_ids: Array[String], mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1, operation: String = "", request: Dictionary = {}) -> ProfileMutationResult:
		completion_calls += 1
		return super.apply_irreversible_terminal_completion(profile_id, transaction_id, terminal_run_id, terminal_instance_ids, mutate, root, now_unix, operation, request)

	func apply_with_resumable_run_revocation(profile_id: String, transaction_id: String, revoked_run_id: StringName, mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1, operation: String = "", request: Dictionary = {}, receipt: Dictionary = {}) -> ProfileMutationResult:
		revocation_calls += 1
		return super.apply_with_resumable_run_revocation(profile_id, transaction_id, revoked_run_id, mutate, root, now_unix, operation, request, receipt)


class ScriptedTerminalRecovery extends RunTerminalRecoveryService:
	var persist_initial_calls := 0
	var persist_selection_calls := 0
	var persist_resolution_interruption_calls := 0
	var protect_calls := 0
	var complete_calls := 0
	var inspect_calls := 0
	var initial_failures_remaining := 0
	var protect_failures_remaining := 0
	var complete_failures_remaining := 0
	var reentrant: Callable
	var persisted_selection_records: Array[Dictionary] = []
	var persisted_resolution_interruption_records: Array[Dictionary] = []

	func _init(store: ProfileStore) -> void:
		super(ProfileMutationService.new(store), store)

	func persist_initial(profile_id: String, snapshot: RunTerminalSnapshot, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		persist_initial_calls += 1
		_reenter_once()
		if initial_failures_remaining > 0:
			initial_failures_remaining -= 1
			return _failed("injected terminal-save failure")
		return super.persist_initial(profile_id, snapshot, root)

	func inspect(profile: ProfileState) -> RunTerminalRecoveryRecordResult:
		inspect_calls += 1
		return super.inspect(profile)

	func persist_selection(profile_id: String, record: RunTerminalRecoveryRecord, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		persist_selection_calls += 1
		persisted_selection_records.append(record.to_dictionary() if record != null else {})
		return super.persist_selection(profile_id, record, root)

	func persist_resolution_interruption(profile_id: String, record: RunTerminalRecoveryRecord, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		persist_resolution_interruption_calls += 1
		persisted_resolution_interruption_records.append(record.to_dictionary() if record != null else {})
		return super.persist_resolution_interruption(profile_id, record, root)

	func protect_displaced_gear(profile_id: String, record: RunTerminalRecoveryRecord, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		protect_calls += 1
		_reenter_once()
		if protect_failures_remaining > 0:
			protect_failures_remaining -= 1
			return _failed("injected protection failure")
		return super.protect_displaced_gear(profile_id, record, root)

	func complete_terminal(profile_id: String, run_id: StringName, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		complete_calls += 1
		_reenter_once()
		if complete_failures_remaining > 0:
			complete_failures_remaining -= 1
			return _failed("injected terminal-completion failure")
		return super.complete_terminal(profile_id, run_id, root)

	func _reenter_once() -> void:
		var callback := reentrant
		reentrant = Callable()
		if callback.is_valid(): callback.call()

	func _failed(reason: String) -> ProfileMutationResult:
		var result := ProfileMutationResult.new()
		result.error = "PARTY_FORGE_RUN_TERMINAL_RECOVERY_ERROR reason=%s" % reason
		return result


class CountingResolutionService extends RunResolutionService:
	var terminal_calls := 0
	var preflight_calls := 0
	var evaluator_calls := 0
	var failures_remaining := 0
	var request_documents: Array[Dictionary] = []
	var mutations: CountingMutationService
	var reentrant: Callable

	func _init(store: ProfileStore) -> void:
		mutations = CountingMutationService.new(store)
		super(mutations, _evaluate)

	func preflight_source(profile: ProfileState, source: RunResolutionSource, request: RunResolutionRequest) -> RunResolutionPreflightResult:
		preflight_calls += 1
		return super.preflight_source(profile, source, request)

	func resolve_terminal_source(profile_id: String, source: RunResolutionSource, request: RunResolutionRequest, root: String = ProfileStore.DEFAULT_ROOT) -> RunResolutionResult:
		terminal_calls += 1
		request_documents.append(request.canonical_document())
		var callback := reentrant
		reentrant = Callable()
		if callback.is_valid(): callback.call()
		if failures_remaining > 0:
			failures_remaining -= 1
			return RunResolutionResult.failure("PARTY_FORGE_RUN_RESOLUTION_ERROR reason=injected resolution failure")
		return super.resolve_terminal_source(profile_id, source, request, root)

	func _evaluate(profile: ProfileState, source: RunResolutionSource, request: RunResolutionRequest) -> RunResolutionEvaluation:
		evaluator_calls += 1
		return RunResolutionEvaluator.evaluate(profile, source, request)


class ScriptedProfileManager extends ProfileManager:
	var delegate: ProfileManager
	var refresh_calls := 0
	var fail_on_calls: Dictionary = {}
	var reentrant: Callable

	func _init(delegate_value: ProfileManager) -> void:
		delegate = delegate_value

	func active_profile() -> ProfileState:
		return delegate.active_profile()

	func refresh_profile(profile_id: String) -> String:
		refresh_calls += 1
		var callback := reentrant
		reentrant = Callable()
		if callback.is_valid(): callback.call()
		if bool(fail_on_calls.get(refresh_calls, false)):
			return "PROFILE_LOAD_ERROR reason=injected projection refresh failure"
		return delegate.refresh_profile(profile_id)


class FailingFinalizeFlow extends RunTerminalFlow:
	var failures_remaining := 1
	var finalize_calls := 0

	func _init(recovery: RunTerminalRecoveryService, resolution: RunResolutionService) -> void:
		super(recovery, resolution)

	func finalize() -> bool:
		finalize_calls += 1
		if failures_remaining > 0:
			failures_remaining -= 1
			return false
		return super.finalize()


var _failures: Array[String] = []
var _case_sequence := 0


func _initialize() -> void:
	if "--check-only" in OS.get_cmdline_args():
		quit(0)
		return
	call_deferred(&"_run")


func _run() -> void:
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	_test_binding_contract()
	await _test_initial_save_retry_matrix()
	await _test_committed_initial_save_refresh_retry()
	await _test_resolution_retry_matrix()
	await _test_projection_retry_same_session_and_cold()
	await _test_automatic_only_protection_matrix()
	await _test_protection_changed_selection_new_request()
	await _test_post_protection_resolution_failure_recovery()
	await _test_armoury_round_trip_and_focus_fallback()
	await _test_finalized_action_completion_matrix()
	await _test_committed_completion_refresh_retry()
	await _test_no_current_scene_fallbacks()
	await _test_cold_pre_resolution_precedence_and_duplicate_terminal()
	await _test_victory_defeat_recap_and_finalize_retention()
	_test_restart_intent_copy_and_one_shot_metadata()
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	_finish()


func _test_binding_contract() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/game/main.gd")
	var accepted := _function_body(main_source, "_on_terminal_resolution_accepted")
	_assert("func configure_terminal_lifecycle(" in main_source, "Main exposes the typed terminal lifecycle injection boundary")
	_assert("_terminal_flow.fresh()" in main_source, "cold and rebuilt Main flows preserve injected typed collaborators")
	_assert(accepted.find("_build_terminal_result") >= 0 and accepted.find("_build_terminal_result") < accepted.find("_terminal_flow.finalize") and accepted.find("_terminal_flow.finalize") < accepted.find("_clear_live_loot"), "recap build, durable finalize, and cleanup retain exact destructive order")


func _test_initial_save_retry_matrix() -> void:
	var fixture := _fixture("initial-save", 3)
	var recovery := ScriptedTerminalRecovery.new(fixture.store)
	recovery.initial_failures_remaining = 2
	var resolution := CountingResolutionService.new(fixture.store)
	var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, _route_spy())
	main.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	await process_frame
	var panel := _result_panel(main)
	_assert(recovery.persist_initial_calls == 1, "initial terminal capture attempts exactly one durable save")
	_assert(_visible_actions(panel) == ["RetryTerminalSave"], "initial-save failure exposes only Retry Terminal Save")
	_assert(_focused_action(panel) == "RetryTerminalSave", "initial-save failure focuses the exact retry-only action")
	_assert((fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile.terminal_resolution.is_empty(), "initial-save failure writes no recovery record")
	var retry := _action(panel, "RetryTerminalSave")
	recovery.reentrant = func() -> void: retry.pressed.emit()
	retry.pressed.emit()
	await process_frame
	_assert(recovery.persist_initial_calls == 2, "pending Retry Save suppresses a reentrant duplicate click")
	_assert(_visible_actions(panel) == ["RetryTerminalSave"] and _focused_action(panel) == "RetryTerminalSave", "failed retry restores the exact retry-only surface and focus")
	retry.pressed.emit()
	await process_frame
	_assert(recovery.persist_initial_calls == 3 and (main.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).visible, "second Retry Save succeeds and opens extraction")
	_assert(not (fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile.terminal_resolution.is_empty(), "picker opens only after the terminal record is durable")
	_assert(resolution.terminal_calls == 0 and resolution.evaluator_calls == 0 and resolution.mutations.apply_calls == 0, "terminal-save retry never resolves, evaluates, or mutates extraction")
	_cleanup_case(main, fixture)


func _test_committed_initial_save_refresh_retry() -> void:
	var fixture := _fixture("initial-committed-refresh", 3)
	var recovery := ScriptedTerminalRecovery.new(fixture.store)
	var resolution := CountingResolutionService.new(fixture.store)
	var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, _route_spy())
	var manager := ScriptedProfileManager.new(main.profile_manager)
	manager.fail_on_calls = {1: true}
	main.profile_manager = manager
	main.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	await process_frame
	var panel := _result_panel(main)
	var actions := _visible_actions(panel)
	_assert(recovery.persist_initial_calls == 1 and not (fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile.terminal_resolution.is_empty(), "initial save commits exactly once before injected refresh failure")
	_assert(panel.visible and actions.size() == 1 and "RetryTerminalSave" not in actions, "post-commit refresh failure exposes one refresh/rebuild action, never Retry Terminal Save")
	if actions.size() == 1:
		_action(panel, actions[0]).pressed.emit()
		await process_frame
	_assert(recovery.persist_initial_calls == 1, "post-commit refresh retry never persists the initial snapshot twice")
	_assert((main.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).visible, "successful post-commit refresh retry rebuilds and opens extraction")
	_cleanup_case(main, fixture)


func _test_resolution_retry_matrix() -> void:
	var fixture := _fixture("resolution-retry", 3)
	var recovery := ScriptedTerminalRecovery.new(fixture.store)
	var resolution := CountingResolutionService.new(fixture.store)
	resolution.failures_remaining = 1
	var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, _route_spy())
	main.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	await process_frame
	(main.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).confirm_requested.emit()
	await process_frame
	var panel := _result_panel(main)
	_assert(resolution.terminal_calls == 1 and _focused_action(panel) == "RetryResolution", "failed resolution presents and focuses Retry Resolution")
	var first_request := resolution.request_documents[0].duplicate(true) if not resolution.request_documents.is_empty() else {}
	var evaluator_before_retry := resolution.evaluator_calls
	var mutation_before_retry := resolution.mutations.revocation_calls
	var retry := _action(panel, "RetryResolution")
	resolution.reentrant = func() -> void: retry.pressed.emit()
	retry.pressed.emit()
	await process_frame
	_assert(resolution.terminal_calls == 2, "resolution retry suppresses a reentrant duplicate")
	_assert(resolution.request_documents.size() == 2 and resolution.request_documents[1] == first_request, "resolution retry reuses the exact confirmed request")
	_assert(resolution.evaluator_calls == evaluator_before_retry + 2 and resolution.mutations.revocation_calls == mutation_before_retry + 1, "resolution retry adds one recovery preflight, one mutation evaluation, and one mutation")
	_assert(_terminal_state(main) == RunTerminalFlow.State.FINALIZED and _result_panel(main).visible, "successful resolution retry reaches finalized recap")
	retry.pressed.emit()
	_assert(resolution.terminal_calls == 2, "hidden finalized retry action cannot resolve again")
	_cleanup_case(main, fixture)


func _test_projection_retry_same_session_and_cold() -> void:
	var fixture := _fixture("projection-same-session", 3)
	var recovery := ScriptedTerminalRecovery.new(fixture.store)
	var resolution := CountingResolutionService.new(fixture.store)
	var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, _route_spy())
	var manager := ScriptedProfileManager.new(main.profile_manager)
	manager.fail_on_calls = {3: true, 4: true}
	main.profile_manager = manager
	main.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	(main.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).confirm_requested.emit()
	await process_frame
	var panel := _result_panel(main)
	_assert(_focused_action(panel) == "RetryProjection" and resolution.terminal_calls == 1, "post-resolution refresh failure exposes exact Retry Results without a second resolve")
	var before := _resolution_counts(resolution)
	var retry := _action(panel, "RetryProjection")
	manager.reentrant = func() -> void: retry.pressed.emit()
	retry.pressed.emit()
	await process_frame
	_assert(_resolution_counts(resolution) == before and _focused_action(panel) == "RetryProjection", "failed projection retry and reentrant duplicate perform zero resolve/evaluator/mutation calls")
	retry.pressed.emit()
	await process_frame
	_assert(_resolution_counts(resolution) == before and _terminal_state(main) == RunTerminalFlow.State.FINALIZED, "successful same-session projection retry remains projection-only and finalizes")
	_cleanup_case(main, fixture)

	var cold_fixture := _fixture("projection-cold", 3)
	var cold_recovery := ScriptedTerminalRecovery.new(cold_fixture.store)
	var first_resolution := CountingResolutionService.new(cold_fixture.store)
	var first := await _main_for_fixture(cold_fixture, RunTerminalFlow.new(cold_recovery, first_resolution), cold_recovery, _route_spy())
	var cold_manager := ScriptedProfileManager.new(first.profile_manager)
	cold_manager.fail_on_calls = {3: true}
	first.profile_manager = cold_manager
	first.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	(first.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).confirm_requested.emit()
	await process_frame
	_assert(_focused_action(_result_panel(first)) == "RetryProjection", "cold projection fixture stops after durable resolution and before recap")
	first.free()
	await process_frame
	var cold_resolution := CountingResolutionService.new(cold_fixture.store)
	var cold := await _main_for_fixture(cold_fixture, RunTerminalFlow.new(cold_recovery, cold_resolution), cold_recovery, _route_spy(), false)
	await process_frame
	_assert(_terminal_state(cold) == RunTerminalFlow.State.FINALIZED and _result_panel(cold).visible, "cold resolved receipt rebuilds the finalized recap")
	_assert(_resolution_counts(cold_resolution) == {"resolve": 0, "evaluate": 0, "mutate": 0}, "cold projection recovery performs zero resolve/evaluator/mutation calls")
	_cleanup_case(cold, cold_fixture)


func _test_automatic_only_protection_matrix() -> void:
	var fixture := _fixture("automatic-protect", 0, true)
	var recovery := ScriptedTerminalRecovery.new(fixture.store)
	recovery.protect_failures_remaining = 1
	var resolution := CountingResolutionService.new(fixture.store)
	var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, _route_spy())
	main.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	(main.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).confirm_requested.emit()
	await process_frame
	var panel := _result_panel(main)
	_assert(_focused_action(panel) == "ProtectDisplacedGear" and "ProtectDisplacedGear" in _visible_actions(panel), "automatic-only interruption exposes and focuses Protect Displaced Gear")
	var before_bytes := FileAccess.get_file_as_bytes((fixture.store as ProfileStore).profile_path(fixture.profile_id, fixture.root))
	_action(panel, "ProtectDisplacedGear").pressed.emit()
	await process_frame
	_assert((panel.get_node("Frame/Content/Confirmation/Content/Actions/Cancel") as Button).has_focus(), "Protect confirmation defaults to non-destructive Cancel")
	(panel.get_node("Frame/Content/Confirmation/Content/Actions/Confirm") as Button).pressed.emit()
	await process_frame
	_assert(recovery.protect_calls == 1 and FileAccess.get_file_as_bytes((fixture.store as ProfileStore).profile_path(fixture.profile_id, fixture.root)) == before_bytes, "failed protection is atomic")
	_assert(_focused_action(panel) == "ProtectDisplacedGear", "failed protection restores exact Protect focus")
	var preflight_calls_before_success := resolution.preflight_calls
	_action(panel, "ProtectDisplacedGear").pressed.emit()
	(panel.get_node("Frame/Content/Confirmation/Content/Actions/Confirm") as Button).pressed.emit()
	await process_frame
	var durable := (fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile
	var protected_flow := main.get("_terminal_flow") as RunTerminalFlow
	_assert(recovery.protect_calls == 2 and not durable.terminal_recovery_overflow.get("slots", {}).is_empty(), "successful protection durably moves displaced gear to Recovery Overflow")
	_assert(resolution.preflight_calls == preflight_calls_before_success + 1, "successful protection immediately reruns the same typed preflight exactly once")
	_assert(protected_flow.transaction_id().is_empty() and protected_flow.confirmed_preflight() == null, "successful protection clears the confirmed request and transaction")
	_assert(_terminal_state(main) == RunTerminalFlow.State.CHOOSING_EXTRACTION and (main.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).visible, "successful post-protection preflight returns to an editable extraction picker")
	_cleanup_case(main, fixture)


func _test_protection_changed_selection_new_request() -> void:
	var fixture := _fixture("protect-new-selection", 1, true)
	var recovery := ScriptedTerminalRecovery.new(fixture.store)
	var resolution := CountingResolutionService.new(fixture.store)
	var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, _route_spy())
	main.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	var extraction := main.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel
	extraction.confirm_requested.emit()
	await process_frame
	if _terminal_state(main) == RunTerminalFlow.State.CHOOSING_EXTRACTION:
		extraction.unused_capacity_acknowledged.emit()
		await process_frame
	var flow := main.get("_terminal_flow") as RunTerminalFlow
	var interrupted_transaction := flow.transaction_id()
	var interrupted_record := recovery.inspect((fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile).record
	var interrupted_selected_ids: Array[String] = interrupted_record.selected_item_ids if interrupted_record != null else []
	var panel := _result_panel(main)
	_assert(not interrupted_transaction.is_empty() and _focused_action(panel) == "ProtectDisplacedGear", "changed-selection protection fixture owns one canonical automatic-only interruption")
	_action(panel, "ProtectDisplacedGear").pressed.emit()
	(panel.get_node("Frame/Content/Confirmation/Content/Actions/Confirm") as Button).pressed.emit()
	await process_frame
	var eligible := flow.extraction_projection().eligible_items
	_assert(_terminal_state(main) == RunTerminalFlow.State.CHOOSING_EXTRACTION and not eligible.is_empty(), "successful protection returns an editable picker")
	if not eligible.is_empty():
		main.call(&"_on_terminal_item_toggle_requested", (eligible[0] as ExtractionSelection).item_id)
	var changed_selected_ids: Array[String] = (main.get("_terminal_selection") as TerminalExtractionSelectionController).selected_item_ids()
	_assert(changed_selected_ids.is_empty() and changed_selected_ids != interrupted_selected_ids, "post-protection picker owns a changed empty selection before reconfirmation")
	if changed_selected_ids != interrupted_selected_ids:
		extraction.confirm_requested.emit()
		await process_frame
		var warning := extraction.get_node("UnusedCapacityWarning") as Control
		_assert(warning.visible, "changed empty selection requires exact unused-capacity acknowledgement")
		extraction.unused_capacity_acknowledged.emit()
		await process_frame
	var resolved_transaction := flow.transaction_id()
	var request_transaction := String(resolution.request_documents[-1].get("transaction_id", "")) if not resolution.request_documents.is_empty() else ""
	_assert(not resolved_transaction.is_empty() and resolved_transaction != interrupted_transaction, "changed post-protection selection creates a new canonical transaction")
	_assert(request_transaction == resolved_transaction and resolution.terminal_calls == 1, "changed post-protection selection resolves exactly once with the new canonical request")
	_cleanup_case(main, fixture)


func _test_post_protection_resolution_failure_recovery() -> void:
	for changed_selection: bool in [false, true]:
		var variant := "changed" if changed_selection else "same"
		var fixture := _fixture("protect-resolution-failure-%s" % variant, 1, true)
		var recovery := ScriptedTerminalRecovery.new(fixture.store)
		var resolution := CountingResolutionService.new(fixture.store)
		var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, _route_spy())
		main.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
		var extraction := main.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel
		extraction.confirm_requested.emit()
		await process_frame
		if _terminal_state(main) == RunTerminalFlow.State.CHOOSING_EXTRACTION:
			extraction.unused_capacity_acknowledged.emit()
			await process_frame
		var interrupted_profile := (fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile
		var interrupted := recovery.inspect(interrupted_profile).record
		var interrupted_selected: Array[String] = interrupted.selected_item_ids if interrupted != null else []
		var panel := _result_panel(main)
		_assert(interrupted != null and interrupted.stage == RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED and _focused_action(panel) == "ProtectDisplacedGear", "%s-selection fixture reaches exact automatic-only interruption" % variant)
		_action(panel, "ProtectDisplacedGear").pressed.emit()
		(panel.get_node("Frame/Content/Confirmation/Content/Actions/Confirm") as Button).pressed.emit()
		await process_frame
		var protected_profile := (fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile
		var protected_record := recovery.inspect(protected_profile).record
		var protected_ids: Array[String] = protected_record.protected_displaced_item_ids if protected_record != null else []
		var controller := main.get("_terminal_selection") as TerminalExtractionSelectionController
		var post_protect_selected := controller.selected_item_ids()
		_assert(not protected_ids.is_empty() and post_protect_selected == interrupted_selected, "%s-selection Protect preserves exact selection and owns durable protected IDs" % variant)
		if changed_selection:
			var eligible := (main.get("_terminal_flow") as RunTerminalFlow).extraction_projection().eligible_items
			if not eligible.is_empty():
				main.call(&"_on_terminal_item_toggle_requested", (eligible[0] as ExtractionSelection).item_id)
			post_protect_selected = controller.selected_item_ids()
			_assert(post_protect_selected.is_empty() and post_protect_selected != interrupted_selected, "changed-selection failure fixture owns an exact changed empty selection")
		var applied_before := protected_profile.applied_transactions.size()
		var evaluator_before := resolution.evaluator_calls
		var mutation_before := resolution.mutations.revocation_calls
		resolution.failures_remaining = 1
		extraction.confirm_requested.emit()
		await process_frame
		if changed_selection:
			var warning := extraction.get_node("UnusedCapacityWarning") as Control
			_assert(warning.visible, "changed-selection failure requires exact unused-capacity acknowledgement")
			extraction.unused_capacity_acknowledged.emit()
			await process_frame
		var failed_profile := (fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile
		var failed_record := recovery.inspect(failed_profile).record
		var submitted := recovery.persisted_resolution_interruption_records[-1] if not recovery.persisted_resolution_interruption_records.is_empty() else {}
		_assert(recovery.persist_selection_calls == 2 and recovery.persist_resolution_interruption_calls == 1 and int(submitted.get("stage", -1)) == RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, "%s-selection failure persists exactly one typed resolution-failure interruption after automatic blockage and confirmed selection" % variant)
		_assert(submitted.get("protected_displaced_item_ids", []) == protected_ids, "%s-selection resolution-failure write carries the exact protected displaced IDs" % variant)
		_assert(failed_record != null and failed_record.stage == RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED and failed_record.selected_item_ids == post_protect_selected, "%s-selection durable failure owns exact RESOLUTION_INTERRUPTED stage and selection" % variant)
		_assert(failed_record != null and failed_record.protected_displaced_item_ids == protected_ids and failed_record.interruption_reason.contains("injected resolution failure"), "%s-selection durable failure retains exact protected IDs and the new resolution failure" % variant)
		_assert(failed_profile.applied_transactions.size() == applied_before + 2, "%s-selection confirmation and resolution failure commit under distinct transaction phases" % variant)
		_assert(resolution.terminal_calls == 1 and resolution.request_documents.size() == 1 and resolution.evaluator_calls == evaluator_before + 1 and resolution.mutations.revocation_calls == mutation_before, "%s-selection failure performs one resolve preflight/call and zero extraction mutations" % variant)
		if current_scene == main:
			current_scene = null
		main.free()
		await process_frame
		var cold_resolution := CountingResolutionService.new(fixture.store)
		var cold := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, cold_resolution), recovery, _route_spy(), false)
		await process_frame
		var cold_panel := _result_panel(cold)
		_assert(_terminal_state(cold) == RunTerminalFlow.State.RESOLUTION_INTERRUPTED and cold_panel.visible and _focused_action(cold_panel) == "RetryResolution", "%s-selection protected failure survives cold Main resume at exact Retry Resolution state" % variant)
		_action(cold_panel, "OpenArmoury").pressed.emit()
		await process_frame
		var armoury := cold.get_node("ArmouryScreen") as ArmouryScreen
		var grid := armoury.get_node_or_null("Overlay/Frame/Layout/Body/RecoveryOverflow/Scroll/Grid") as GridContainer
		var locked_ids: Array[String] = []
		if grid != null:
			for child: Node in grid.get_children():
				if child is StorageSlotButton:
					var detail := (child as StorageSlotButton).detail()
					var instance_id := String(detail.get("instance_id", ""))
					if instance_id in protected_ids and String(detail.get("move_locked_reason", "")) == "Available after terminal resolution":
						locked_ids.append(instance_id)
		var expected_locked := protected_ids.duplicate()
		locked_ids.sort()
		expected_locked.sort()
		_assert(armoury.is_open() and locked_ids == expected_locked, "%s-selection cold Armoury keeps every protected overflow slot exactly locked" % variant)
		_assert(recovery.persist_selection_calls == 2 and recovery.persist_resolution_interruption_calls == 1 and cold_resolution.terminal_calls == 0 and cold_resolution.mutations.revocation_calls == 0, "%s-selection cold resume and Armoury inspection perform zero persistence, resolve, or extraction mutation" % variant)
		_cleanup_case(cold, fixture)


func _test_armoury_round_trip_and_focus_fallback() -> void:
	var fixture := _fixture("armoury-return", 3)
	var recovery := ScriptedTerminalRecovery.new(fixture.store)
	var resolution := CountingResolutionService.new(fixture.store)
	resolution.failures_remaining = 1
	var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, _route_spy())
	main.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	(main.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).confirm_requested.emit()
	await process_frame
	var panel := _result_panel(main)
	var inspect_before := recovery.inspect_calls
	var preflight_before := resolution.preflight_calls
	_action(panel, "OpenArmoury").pressed.emit()
	await process_frame
	var armoury := main.get_node("ArmouryScreen") as ArmouryScreen
	_assert(armoury.is_open() and not panel.visible, "Open Armoury enters real storage without clearing the receipt")
	armoury.close_requested.emit()
	await process_frame
	_assert(panel.visible and _focused_action(panel) == "OpenArmoury", "Armoury close refreshes terminal UI and restores exact initiating focus")
	_assert(recovery.inspect_calls > inspect_before and resolution.preflight_calls > preflight_before, "Armoury return verifies the receipt and reruns preflight")
	_cleanup_case(main, fixture)

	var fallback_fixture := _fixture("armoury-fallback", 3)
	var fallback_recovery := ScriptedTerminalRecovery.new(fallback_fixture.store)
	var fallback_resolution := CountingResolutionService.new(fallback_fixture.store)
	fallback_resolution.failures_remaining = 1
	var fallback := await _main_for_fixture(fallback_fixture, RunTerminalFlow.new(fallback_recovery, fallback_resolution), fallback_recovery, _route_spy())
	fallback.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	(fallback.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).confirm_requested.emit()
	await process_frame
	var fallback_panel := _result_panel(fallback)
	_action(fallback_panel, "OpenArmoury").pressed.emit()
	await process_frame
	var fallback_armoury := fallback.get_node("ArmouryScreen") as ArmouryScreen
	var changed := (fallback_fixture.store as ProfileStore).load_profile(fallback_fixture.profile_id, fallback_fixture.root).profile
	changed.terminal_resolution = {}
	(fallback_fixture.store as ProfileStore).save_profile(changed, fallback_fixture.root)
	fallback_armoury.close_requested.emit()
	await process_frame
	_assert(fallback_panel.visible and _focused_action(fallback_panel) == "RetryResolution", "invalidated Armoury origin falls back to the enabled stage action")
	_cleanup_case(fallback, fallback_fixture)


func _test_finalized_action_completion_matrix() -> void:
	for action_name: String in ["RestartRun", "ReturnToForge", "QuitApplication"]:
		var label := "complete-%s" % action_name.to_snake_case().replace("_", "-")
		var fixture := _fixture(label, 3)
		var recovery := ScriptedTerminalRecovery.new(fixture.store)
		recovery.complete_failures_remaining = 1
		var resolution := CountingResolutionService.new(fixture.store)
		var routes := _route_spy()
		var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, routes)
		await _finalize_main(main, RunTerminalSnapshot.Outcome.VICTORY)
		var panel := _result_panel(main)
		var action := _action(panel, action_name)
		action.pressed.emit()
		await process_frame
		var route_key := "quit" if action_name == "QuitApplication" else "reload"
		_assert(recovery.complete_calls == 1 and int(routes[route_key]) == 0, "%s completion failure invokes no host route" % action_name)
		_assert(not (fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile.terminal_resolution.is_empty(), "%s completion failure retains the durable receipt" % action_name)
		_assert(_focused_action(panel) == action_name and _reason_text(panel).contains("Retry"), "%s completion failure restores exact action focus and readable retry" % action_name)
		recovery.reentrant = func() -> void: action.pressed.emit()
		action.pressed.emit()
		await process_frame
		_assert(recovery.complete_calls == 2, "%s successful retry suppresses a reentrant duplicate" % action_name)
		_assert((fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile.terminal_resolution.is_empty(), "%s successful retry durably clears the receipt" % action_name)
		_assert(int(routes[route_key]) == 1, "%s successful retry invokes its exact intercepted host route once" % action_name)
		if action_name == "RestartRun":
			var intent: RunSetupRestartIntent = get_meta(&"party_forge_run_setup_restart_intent") as RunSetupRestartIntent if has_meta(&"party_forge_run_setup_restart_intent") else null
			_assert(intent != null and intent.profile_id == fixture.profile_id and intent.class_id == &"fighter", "Restart Run stores exact prior profile/class intent only after completion")
			if has_meta(&"party_forge_run_setup_restart_intent"): remove_meta(&"party_forge_run_setup_restart_intent")
		_cleanup_case(main, fixture)


func _test_committed_completion_refresh_retry() -> void:
	var fixture := _fixture("completion-committed-refresh", 3)
	var recovery := ScriptedTerminalRecovery.new(fixture.store)
	var resolution := CountingResolutionService.new(fixture.store)
	var routes := _route_spy()
	var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, routes)
	await _finalize_main(main, RunTerminalSnapshot.Outcome.VICTORY)
	var manager := ScriptedProfileManager.new(main.profile_manager)
	manager.fail_on_calls = {2: true}
	main.profile_manager = manager
	var panel := _result_panel(main)
	_action(panel, "ReturnToForge").pressed.emit()
	await process_frame
	_assert(recovery.complete_calls == 1 and (fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile.terminal_resolution.is_empty(), "terminal completion commits exactly once before injected refresh failure")
	_assert(int(routes.reload) == 0 and _visible_actions(panel) == ["ReturnToForge"] and _focused_action(panel) == "ReturnToForge", "committed completion refresh failure exposes only exact Return refresh+route retry")
	_action(panel, "ReturnToForge").pressed.emit()
	await process_frame
	_assert(recovery.complete_calls == 1, "committed completion retry refreshes only and never completes twice")
	_assert(manager.refresh_calls == 3 and int(routes.reload) == 1, "committed completion retry refreshes once then routes exactly once")
	_cleanup_case(main, fixture)


func _test_no_current_scene_fallbacks() -> void:
	current_scene = null
	_assert(current_scene == null, "runner owns the no-current-scene navigation fixture")
	var restart_fixture := _fixture("restart-null-scene", 3)
	var restart_recovery := ScriptedTerminalRecovery.new(restart_fixture.store)
	var restart := await _main_for_fixture(restart_fixture, RunTerminalFlow.new(restart_recovery, CountingResolutionService.new(restart_fixture.store)), restart_recovery, {}, true, false)
	await _finalize_main(restart, RunTerminalSnapshot.Outcome.VICTORY)
	_action(_result_panel(restart), "RestartRun").pressed.emit()
	await process_frame
	var lobby := restart.get_node("HUD/ClassSelection") as ClassSelectionPanel
	_assert(lobby.is_open() and lobby.selection_focus(&"fighter") != null, "no-current-scene Restart clears then opens the preselected lobby safely")
	_assert((restart_fixture.store as ProfileStore).load_profile(restart_fixture.profile_id, restart_fixture.root).profile.terminal_resolution.is_empty(), "no-current-scene Restart clears the receipt before direct lobby fallback")
	_cleanup_case(restart, restart_fixture)

	var finalized_return_fixture := _fixture("finalized-return-null-scene", 3)
	var finalized_return_recovery := ScriptedTerminalRecovery.new(finalized_return_fixture.store)
	var finalized_return := await _main_for_fixture(finalized_return_fixture, RunTerminalFlow.new(finalized_return_recovery, CountingResolutionService.new(finalized_return_fixture.store)), finalized_return_recovery, {}, true, false)
	await _finalize_main(finalized_return, RunTerminalSnapshot.Outcome.VICTORY)
	_action(_result_panel(finalized_return), "ReturnToForge").pressed.emit()
	await process_frame
	_assert(finalized_return_recovery.complete_calls == 1 and (finalized_return_fixture.store as ProfileStore).load_profile(finalized_return_fixture.profile_id, finalized_return_fixture.root).profile.terminal_resolution.is_empty(), "finalized no-current-scene Return clears the durable receipt exactly once")
	_assert((finalized_return.get_node("MainMenuScreen") as MainMenuScreen).is_open() and not (finalized_return.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).visible and not _result_panel(finalized_return).visible, "finalized no-current-scene Return opens the normal front end safely")
	_cleanup_case(finalized_return, finalized_return_fixture)

	var return_fixture := _fixture("return-null-scene", 3)
	var return_recovery := ScriptedTerminalRecovery.new(return_fixture.store)
	var returning := await _main_for_fixture(return_fixture, RunTerminalFlow.new(return_recovery, CountingResolutionService.new(return_fixture.store)), return_recovery, {}, true, false)
	returning.call(&"_on_terminal", RunTerminalSnapshot.Outcome.DEFEAT)
	await process_frame
	returning.call(&"_on_return_to_forge_requested")
	await process_frame
	_assert(not (return_fixture.store as ProfileStore).load_profile(return_fixture.profile_id, return_fixture.root).profile.terminal_resolution.is_empty(), "pre-resolution no-current-scene Return preserves the durable receipt")
	_assert((returning.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).visible, "pre-resolution no-current-scene Return re-presents terminal recovery")
	_assert(not (returning.get_node("MainMenuScreen") as MainMenuScreen).is_open(), "pre-resolution no-current-scene Return never exposes the normal front end")
	_cleanup_case(returning, return_fixture)


func _test_cold_pre_resolution_precedence_and_duplicate_terminal() -> void:
	var fixture := _fixture("cold-precedence", 3)
	var recovery := ScriptedTerminalRecovery.new(fixture.store)
	var resolution := CountingResolutionService.new(fixture.store)
	var first := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, _route_spy())
	first.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	first.call(&"_on_terminal", RunTerminalSnapshot.Outcome.DEFEAT)
	await process_frame
	_assert(recovery.persist_initial_calls == 1 and _terminal_state(first) == RunTerminalFlow.State.CHOOSING_EXTRACTION, "duplicate terminal event captures and persists exactly once")
	var snapshot := (first.get("_terminal_flow") as RunTerminalFlow).snapshot()
	_assert(snapshot.outcome == RunTerminalSnapshot.Outcome.VICTORY, "duplicate terminal event cannot overwrite the first captured outcome")
	first.free()
	await process_frame
	var intent_script := load(RESTART_INTENT_PATH) as GDScript
	set_meta(&"party_forge_run_setup_restart_intent", intent_script.call(&"create", fixture.profile_id, &"mage", ""))
	var cold_resolution := CountingResolutionService.new(fixture.store)
	var cold := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, cold_resolution), recovery, _route_spy(), false)
	await process_frame
	_assert((cold.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).visible, "cold pre-resolution boot reopens terminal extraction")
	_assert(not (cold.get_node("MainMenuScreen") as MainMenuScreen).is_open() and not (cold.get_node("HUD/ClassSelection") as ClassSelectionPanel).is_open(), "terminal receipt takes precedence over ordinary front end and restart lobby")
	_assert(not has_meta(&"party_forge_run_setup_restart_intent"), "terminal-precedence boot consumes stale restart metadata exactly once")
	_assert(cold_resolution.terminal_calls == 0 and cold_resolution.mutations.apply_calls == 0, "cold pre-resolution recovery does not resolve or mutate extraction")
	_cleanup_case(cold, fixture)


func _test_victory_defeat_recap_and_finalize_retention() -> void:
	for outcome: RunTerminalSnapshot.Outcome in [RunTerminalSnapshot.Outcome.VICTORY, RunTerminalSnapshot.Outcome.DEFEAT]:
		var label := "victory" if outcome == RunTerminalSnapshot.Outcome.VICTORY else "defeat"
		var fixture := _fixture("recap-%s" % label, 3)
		var recovery := ScriptedTerminalRecovery.new(fixture.store)
		var resolution := CountingResolutionService.new(fixture.store)
		var main := await _main_for_fixture(fixture, RunTerminalFlow.new(recovery, resolution), recovery, _route_spy())
		await _finalize_main(main, outcome)
		var projection := main.get("_terminal_result_projection") as RunResultProjection
		_assert(projection != null and _recap_outcome(projection) == label.capitalize(), "%s terminal event produces an exact %s recap" % [label, label])
		var durable := (fixture.store as ProfileStore).load_profile(fixture.profile_id, fixture.root).profile
		_assert(not durable.terminal_resolution.is_empty(), "%s finalized recap retains its durable receipt until an action" % label)
		var city_allocations: Array = durable.tree_allocations.get(CITY_TREE_ID, [])
		if outcome == RunTerminalSnapshot.Outcome.VICTORY:
			_assert(durable.passive_points_available == 0 and durable.passive_points_lifetime_earned == 0, "first-victory terminal integration reveals City without granting a passive point")
			_assert(durable.discovered_trees.count(CITY_TREE_ID) == 1, "victory terminal integration reveals City exactly once")
			_assert(city_allocations.count(CITY_ROOT_NODE_ID) == 1, "victory terminal integration seeds City Heart exactly once")
		else:
			_assert(durable.passive_points_available == 0 and durable.passive_points_lifetime_earned == 0, "defeat terminal integration grants no passive point")
			_assert(not durable.discovered_trees.has(CITY_TREE_ID), "defeat terminal integration does not reveal City")
			_assert(city_allocations.is_empty(), "defeat terminal integration does not seed City Heart")
		_cleanup_case(main, fixture)

	var live := await _started_live_main("finalize-retention")
	if live == null:
		return
	var registry := live.ground_item_registry as GroundItemRegistry
	var event := EnemyDefeatEvent.create(1337, 9701, 9701, &"swarmer", &"ordinary_melee", live.leader.position, 30.0)
	var report := live.personal_loot_drop_coordinator.resolve_defeat(event)
	live.call(&"_record_personal_loot_report", report)
	var live_ids: Array[StringName] = []
	for record: GroundItemRecord in registry.all_records(): live_ids.append(record.drop_id)
	var store := ProfileStore.new()
	var recovery := ScriptedTerminalRecovery.new(store)
	var resolution := CountingResolutionService.new(store)
	var flow := FailingFinalizeFlow.new(recovery, resolution)
	_assert(live.configure_terminal_lifecycle(flow, recovery, func() -> void: pass, func() -> void: pass), "finalize-failure fixture installs typed lifecycle authorities")
	live.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
	(live.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel).confirm_requested.emit()
	await process_frame
	_assert(flow.finalize_calls == 1 and _focused_action(_result_panel(live)) == "RetryProjection", "injected finalize failure enters exact Retry Results state")
	var retained_ids: Array[StringName] = []
	for record: GroundItemRecord in registry.all_records(): retained_ids.append(record.drop_id)
	_assert(registry == live.ground_item_registry and retained_ids == live_ids, "finalize failure retains every disposable live-loot record")
	_cleanup_live_main(live)


func _test_restart_intent_copy_and_one_shot_metadata() -> void:
	var script := load(RESTART_INTENT_PATH) as GDScript
	var intent: RunSetupRestartIntent = script.call(&"create", "profile-a", &"fighter", "")
	var copied := intent.copy()
	_assert(intent.valid(), "restart intent validates exact nonempty profile/class")
	_assert(copied != intent and copied.profile_id == "profile-a" and copied.class_id == &"fighter", "restart intent defensive copy preserves exact route data")
	var invalid: RunSetupRestartIntent = script.call(&"create", "", &"", "Previous selection is unavailable.")
	_assert(not invalid.valid() and invalid.reason == "Previous selection is unavailable.", "invalid restart route retains explicit unresolved reason")
	set_meta(RunSetupRestartIntent.META_KEY, copied)
	var consumed := get_meta(RunSetupRestartIntent.META_KEY) as RunSetupRestartIntent
	remove_meta(RunSetupRestartIntent.META_KEY)
	_assert(consumed != null and not has_meta(RunSetupRestartIntent.META_KEY), "restart metadata is consumable exactly once")


func _fixture(label: String, extraction_capacity: int, automatic_only: bool = false) -> Dictionary:
	_case_sequence += 1
	var root_path := PROFILE_ROOT.path_join("%03d-%s" % [_case_sequence, label])
	ProfileTestSupport.remove_tree(root_path)
	var profile_id := "terminal-%03d-%s" % [_case_sequence, label]
	var run_id := StringName("run-%03d-%s" % [_case_sequence, label])
	var run_player_id := StringName("player-%03d-%s" % [_case_sequence, label])
	var run_seed := 41000 + _case_sequence
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var leader_id := party.members[0].member_id
	var inventory_item := _item(profile_id, run_seed, run_player_id, "run-%s-inventory" % label, 0, &"forge_vanguard_sword", false)
	var run_items: Array[ItemInstance] = [inventory_item]
	var containers: Array[ItemSlotContainer] = [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(run_player_id), 10, {0: inventory_item.instance_id}),
	]
	var equipment_slots: Dictionary = {}
	if automatic_only:
		var run_head := _item(profile_id, run_seed, run_player_id, "run-%s-head" % label, 1, &"forge_vanguard_helmet", false)
		var run_hand := _item(profile_id, run_seed, run_player_id, "run-%s-hand" % label, 2, &"forge_vanguard_sword", false)
		run_items.append_array([run_head, run_hand])
		equipment_slots = {0: run_head.instance_id, 9: run_hand.instance_id}
	containers.append(ItemSlotContainer.create("run-equipment-%03d" % leader_id, ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(run_player_id), EquipmentSlotIndex.capacity(), equipment_slots))
	containers.append(RunItemBootstrap.ground_items_container(String(run_player_id)))
	var ownership := ItemOwnershipState.create(String(run_player_id), ItemRegistry.new(run_items), containers)
	var bootstrap := RunItemBootstrap.create(run_id, run_seed, run_player_id, leader_id, ownership, &"fighter")
	var profile := ProfileState.new_profile(profile_id, "Terminal %03d" % _case_sequence, 1000 + _case_sequence)
	profile.inventory_columns = 2
	profile.extraction_capacity = extraction_capacity
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var profile_items: Array[ItemInstance] = []
	var stash_slots: Dictionary = {}
	if automatic_only:
		profile.permanent_feature_unlocks.append(RunExtractionPolicy.AUTOMATIC_LEADER_UNLOCK)
		for slot: int in 99:
			var filler := _item(profile_id, run_seed, run_player_id, "profile-%s-filler-%03d" % [label, slot], 100 + slot, &"forge_vanguard_sword", true)
			profile_items.append(filler)
			stash_slots[slot] = filler.instance_id
		var prior_head := _item(profile_id, run_seed, run_player_id, "profile-%s-prior-head" % label, 400, &"forge_vanguard_helmet", true)
		var prior_shield := _item(profile_id, run_seed, run_player_id, "profile-%s-prior-shield" % label, 401, &"forge_vanguard_shield", true)
		profile_items.append_array([prior_head, prior_shield])
		profile.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, profile_id, EquipmentSlotIndex.capacity(), {0: prior_head.instance_id, 10: prior_shield.instance_id}).to_dictionary()
		profile.leader_loadout_class_id = "fighter"
	profile.item_records = ItemRegistry.new(profile_items).to_dictionary()
	profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-000", ItemSlotContainer.PROFILE_STASH_TAB, profile_id, 100, stash_slots).to_dictionary()]
	var store := ProfileStore.new()
	var save_error := store.save_profile(profile, root_path)
	_assert(save_error.is_empty(), "%s fixture saves a valid durable profile: %s" % [label, save_error])
	var context := PlayerRunContext.new()
	var context_error := context.configure(run_player_id, 0, profile, run_seed, party, 100, bootstrap)
	_assert(context_error.is_empty(), "%s fixture configures a strict run context: %s" % [label, context_error])
	return {"root": root_path, "store": store, "profile": profile, "profile_id": profile_id, "context": context, "party": party}


func _item(profile_id: String, run_seed: int, run_player_id: StringName, instance_id: String, sequence: int, base_id: StringName, permanent: bool) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 28
	item.rarity_id = &"common"
	item.affixes = []
	item.origin = {
		"issuer_namespace": "profile:%s" % profile_id if permanent else "run:%s:%d:%s" % [profile_id, run_seed, run_player_id],
		"seed": run_seed,
		"sequence": sequence,
		"source": "run_terminal_flow_runner",
	}
	return item


func _main_for_fixture(fixture: Dictionary, flow: RunTerminalFlow, recovery: RunTerminalRecoveryService, routes: Dictionary, attach_context: bool = true, intercept_routes: bool = true) -> PartyForgeMain:
	var main := MAIN_SCENE.instantiate() as PartyForgeMain
	main.profile_root = String(fixture.root)
	main.settings_path = SETTINGS_PATH
	var reload_route := func() -> void: routes.reload = int(routes.get("reload", 0)) + 1
	var quit_route := func() -> void: routes.quit = int(routes.get("quit", 0)) + 1
	var configured := main.configure_terminal_lifecycle(flow, recovery, reload_route if intercept_routes else Callable(), quit_route if intercept_routes else Callable())
	_assert(configured, "fixture installs typed terminal lifecycle authorities")
	root.add_child(main)
	await process_frame
	await process_frame
	if intercept_routes:
		current_scene = main
	if attach_context:
		main.active_run_context = fixture.context as PlayerRunContext
	return main


func _started_live_main(suffix: String) -> PartyForgeMain:
	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	settings.unlock_all_implemented_content = true
	settings.set("force_personal_drops", true)
	settings.set("personal_drop_source_category_override", &"ordinary_specialist")
	var main := MAIN_SCENE.instantiate() as PartyForgeMain
	main.profile_root = PROFILE_ROOT.path_join("live-%s" % suffix)
	main.settings_path = SETTINGS_PATH
	root.add_child(main)
	await process_frame
	if main.profile_manager.active_profile() == null:
		main.profile_manager.create_profile("Terminal Live")
	main.saved_settings = settings.copy()
	if not main.select_leader_class(&"fighter"):
		_assert(false, "live terminal fixture starts an active run")
		main.free()
		return null
	return main


func _finalize_main(main: PartyForgeMain, outcome: RunTerminalSnapshot.Outcome) -> void:
	main.call(&"_on_terminal", outcome)
	await process_frame
	var extraction := main.get_node("HUD/TerminalExtraction") as TerminalExtractionPanel
	extraction.confirm_requested.emit()
	await process_frame


func _route_spy() -> Dictionary:
	return {"reload": 0, "quit": 0}


func _resolution_counts(resolution: CountingResolutionService) -> Dictionary:
	return {"resolve": resolution.terminal_calls, "evaluate": resolution.evaluator_calls, "mutate": resolution.mutations.revocation_calls}


func _terminal_state(main: PartyForgeMain) -> int:
	return int((main.get("_terminal_flow") as RunTerminalFlow).state())


func _result_panel(main: PartyForgeMain) -> RunResultPanel:
	return main.get_node("HUD/RunResultPanel") as RunResultPanel


func _action(panel: RunResultPanel, action_name: String) -> Button:
	return panel.get_node(ACTION_ROOT + action_name) as Button


func _visible_actions(panel: RunResultPanel) -> Array[String]:
	var result: Array[String] = []
	for action_name: String in RunResultPanel.ACTION_NAMES:
		if _action(panel, action_name).visible:
			result.append(action_name)
	return result


func _focused_action(panel: RunResultPanel) -> String:
	var focus := root.gui_get_focus_owner()
	if focus == null or not panel.is_ancestor_of(focus):
		return ""
	return focus.name


func _reason_text(panel: RunResultPanel) -> String:
	return (panel.get_node("Frame/Content/Header/ReadableReason") as Label).text


func _recap_outcome(projection: RunResultProjection) -> String:
	if projection == null:
		return ""
	for section: RunRecapSectionProjection in projection.sections:
		if section.section_id != &"outcome":
			continue
		for entry: RunRecapEntryProjection in section.entries:
			if entry.label == "Outcome":
				return entry.value
	return ""


func _cleanup_case(main: Variant, fixture: Dictionary) -> void:
	paused = false
	if is_instance_valid(main) and current_scene == main:
		current_scene = null
	if main != null and is_instance_valid(main):
		main.free()
	if fixture.get("party") is PartyManager and is_instance_valid(fixture.party):
		(fixture.party as PartyManager).free()
	ProfileTestSupport.remove_tree(String(fixture.get("root", "")))


func _cleanup_live_main(main: PartyForgeMain) -> void:
	paused = false
	if current_scene == main:
		current_scene = null
	if main != null and is_instance_valid(main):
		var live_root := String(main.profile_root)
		main.free()
		ProfileTestSupport.remove_tree(live_root)


func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _cleanup_settings() -> void:
	for path: String in [SETTINGS_PATH, "%s.tmp" % SETTINGS_PATH, "%s.bak" % SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("RUN_TERMINAL_FLOW_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("RUN_TERMINAL_FLOW_FAILURE: %s" % failure)
	print("RUN_TERMINAL_FLOW_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
