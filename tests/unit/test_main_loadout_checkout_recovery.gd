extends RefCounted

class RefreshFailureManager extends ProfileManager:
	var refresh_calls := 0
	var fail_on_call := 2
	var failure_reason := "injected post-checkout refresh failure"

	func refresh_profile(profile_id: String) -> String:
		refresh_calls += 1
		if refresh_calls == fail_on_call:
			return "PROFILE_REFRESH_ERROR profile=%s error=%s" % [profile_id, failure_reason]
		return super.refresh_profile(profile_id)


class BootstrapFailureCheckout extends RunLoadoutCheckoutService:
	var checkout_calls := 0
	var bootstrap_calls := 0

	func checkout(profile_id: String, request: RunLoadoutCheckoutRequest, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		checkout_calls += 1
		return super.checkout(profile_id, request, root)

	func bootstrap_from(profile: ProfileState) -> RunItemBootstrap:
		bootstrap_calls += 1
		if bootstrap_calls == 1:
			return null
		return super.bootstrap_from(profile)


class InjectedContextFailure extends PlayerRunContext:
	func configure(
		run_player_id_value: StringName,
		slot: int,
		profile: ProfileState,
		run_seed_value: int,
		manager: PartyManager,
		experience_multiplier: int,
		item_bootstrap: RunItemBootstrap = null,
		run_inventory_minimum_capacity: int = -1,
	) -> PackedStringArray:
		return PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=injected reason=post-checkout context failure"])


class RejectFirstCheckout extends RunLoadoutCheckoutService:
	var checkout_calls := 0

	func checkout(profile_id: String, request: RunLoadoutCheckoutRequest, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		checkout_calls += 1
		if checkout_calls == 1:
			var rejected := ProfileMutationResult.new()
			rejected.error = "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=injected reason=checkout rejected after transition"
			return rejected
		return super.checkout(profile_id, request, root)


class RecoveryCheckoutSpy extends RunLoadoutCheckoutService:
	var checkout_calls := 0
	var forfeit_calls := 0

	func checkout(profile_id: String, request: RunLoadoutCheckoutRequest, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		checkout_calls += 1
		return super.checkout(profile_id, request, root)

	func forfeit(profile_id: String, run_id: StringName, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		forfeit_calls += 1
		return super.forfeit(profile_id, run_id, root)


class RecoveryServiceSpy extends RunRecoveryService:
	var inspect_calls := 0
	var inspected_class_ids: Array[StringName] = []
	var bind_calls := 0
	var forfeit_calls := 0

	func inspect(profile: ProfileState) -> RunRecoveryResult:
		inspect_calls += 1
		var result := super.inspect(profile)
		inspected_class_ids.append(result.selected_leader_class_id)
		return result

	func bind_legacy_class(profile_id: String, class_id: StringName, root: String = ProfileStore.DEFAULT_ROOT) -> RunRecoveryResult:
		bind_calls += 1
		return super.bind_legacy_class(profile_id, class_id, root)

	func forfeit(profile_id: String, run_id: StringName, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		forfeit_calls += 1
		return super.forfeit(profile_id, run_id, root)


class ForfeitFailureRecovery extends RecoveryServiceSpy:
	func forfeit(_profile_id: String, _run_id: StringName, _root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		forfeit_calls += 1
		var result := ProfileMutationResult.new()
		result.error = "PARTY_FORGE_RUN_RECOVERY_ERROR field=forfeit reason=injected persistence failure"
		return result


const DURABLE_PROFILE_ID := "profile-main-durable-recovery"
const DURABLE_RUN_ID := &"run-main-durable-recovery-42"
const DURABLE_PLAYER_ID := &"run-player-main-recovery"
const DURABLE_RUN_SEED := 90421


func run() -> Array[String]:
	var failures: Array[String] = []
	var main_script := load("res://scripts/game/main.gd") as Script
	var source := FileAccess.get_file_as_string("res://scripts/game/main.gd")
	TestAssertions.truthy("_pending_checkout_recovery" in source, "main owns explicit same-session checkout recovery state", failures)
	TestAssertions.truthy("_run_context_factory" in source, "main owns an injectable production context factory", failures)
	TestAssertions.truthy("_run_recovery" in source, "main owns an injectable durable recovery service", failures)
	TestAssertions.truthy("func _start_committed_run(" in source, "main owns one shared committed-bootstrap start", failures)
	TestAssertions.truthy(main_script != null, "main recovery fixture script loads", failures)
	if not failures.is_empty():
		return failures
	_test_durable_retry_reuses_exact_checkout(failures)
	_test_transition_commit_then_checkout_rejection_retries_without_retransition(failures)
	_test_durable_route_resumes_without_checkout(failures)
	_test_refresh_failure_rejects_cached_ready_recovery(failures)
	_test_legacy_binding_refreshes_reinspects_and_rejects_incompatible_bytes(failures)
	_test_durable_context_failure_preserves_recovery(failures)
	_test_strict_abandonment_and_forfeit_failure(failures)
	_test_committed_forfeit_refresh_failure_is_terminal(failures)
	return failures


func _test_durable_retry_reuses_exact_checkout(failures: Array[String]) -> void:
	var root := "user://tests/main_checkout_recovery_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(root)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = root
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	var created := main.profile_manager.create_profile("Checkout Recovery")
	TestAssertions.truthy(created.ok(), "recovery fixture creates active profile", failures)
	var profile_id := created.profile.profile_id
	var manager := RefreshFailureManager.new()
	TestAssertions.equal(manager.bootstrap(root), "", "injected manager bootstraps the real durable profile", failures)
	main.profile_manager = manager
	var checkout := BootstrapFailureCheckout.new()
	main.set("_loadout_checkout", checkout)
	var context_factory_calls: Array[int] = [0]
	main.set("_run_context_factory", func() -> PlayerRunContext:
		context_factory_calls[0] += 1
		return InjectedContextFailure.new() if context_factory_calls[0] == 1 else PlayerRunContext.new()
	)
	main.call("_open_run_setup")
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var fighter_focus := selector.selection_focus(&"fighter")

	TestAssertions.truthy(not main.select_leader_class(&"fighter"), "post-commit refresh failure leaves run unstarted", failures)
	var durable := ProfileStore.new().load_profile(profile_id, root).profile
	var exact_resumable := durable.resumable_run.duplicate(true)
	var exact_run_id := String(exact_resumable.get("run_id", ""))
	TestAssertions.truthy(not exact_run_id.is_empty(), "failed start preserves the durable committed bootstrap", failures)
	TestAssertions.equal(checkout.checkout_calls, 1, "failed post-checkout refresh performs exactly one checkout mutation", failures)
	_assert_reachable_error(main, selector, fighter_focus, "injected post-checkout refresh failure", "refresh failure", failures)

	var wrong := manager.create_profile("Wrong Recovery Profile")
	TestAssertions.truthy(wrong.ok(), "wrong-profile recovery fixture creates another profile", failures)
	TestAssertions.truthy(not main.select_leader_class(&"fighter"), "same-session recovery rejects the wrong active profile", failures)
	TestAssertions.equal(checkout.checkout_calls, 1, "wrong profile cannot issue a second checkout", failures)
	TestAssertions.equal(manager.select_profile(profile_id), "", "recovery fixture restores original profile", failures)
	TestAssertions.truthy(not main.select_leader_class(&"ranger"), "same-session recovery rejects a different selected class", failures)
	TestAssertions.equal(checkout.checkout_calls, 1, "wrong class cannot issue a second checkout", failures)

	TestAssertions.truthy(not main.select_leader_class(&"fighter"), "post-commit bootstrap reconstruction failure remains retryable", failures)
	TestAssertions.equal(checkout.checkout_calls, 1, "bootstrap failure does not repeat checkout", failures)
	TestAssertions.equal(ProfileStore.new().load_profile(profile_id, root).profile.resumable_run, exact_resumable, "bootstrap failure preserves exact durable checked-out state", failures)
	_assert_reachable_error(main, selector, fighter_focus, "committed bootstrap unavailable", "bootstrap failure", failures)

	var recovery := (main.get("_pending_checkout_recovery") as Dictionary).duplicate(true)
	var tampered := recovery.duplicate(true)
	var tampered_document := (tampered["resumable_run"] as Dictionary).duplicate(true)
	tampered_document["run_id"] = "run-tampered"
	tampered["resumable_run"] = tampered_document
	main.set("_pending_checkout_recovery", tampered)
	TestAssertions.truthy(not main.select_leader_class(&"fighter"), "same-session recovery rejects a mismatched expected bootstrap", failures)
	TestAssertions.equal(checkout.checkout_calls, 1, "mismatched bootstrap cannot issue a second checkout", failures)
	main.set("_pending_checkout_recovery", recovery)

	TestAssertions.truthy(not main.select_leader_class(&"fighter"), "post-checkout context failure leaves run unstarted and retryable", failures)
	TestAssertions.equal(checkout.checkout_calls, 1, "context failure does not repeat checkout", failures)
	TestAssertions.equal(String(ProfileStore.new().load_profile(profile_id, root).profile.resumable_run["run_id"]), exact_run_id, "context failure retains the exact committed run identity", failures)
	_assert_reachable_error(main, selector, fighter_focus, "post-checkout context failure", "context failure", failures)

	TestAssertions.truthy(main.select_leader_class(&"fighter"), "retry starts from the exact committed bootstrap", failures)
	TestAssertions.truthy(main.run_started and main.active_run_context != null, "recovered checkout starts a complete run context", failures)
	TestAssertions.equal(String(main.active_run_context.run_id), exact_run_id, "recovered context uses the original durable run id", failures)
	TestAssertions.equal(checkout.checkout_calls, 1, "successful recovery never issues a second checkout mutation", failures)
	TestAssertions.equal(_checkout_transaction_count(ProfileStore.new().load_profile(profile_id, root).profile), 1, "durable journal contains one checkout operation after recovery", failures)
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()
	ProfileTestSupport.remove_tree(root)


func _assert_reachable_error(main: PartyForgeMain, selector: ClassSelectionPanel, expected_focus: Control, detail: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not main.run_started and selector.is_open(), "%s keeps visible run setup open" % label, failures)
	var status := selector.get_node("Content/GateStatus") as Label
	TestAssertions.truthy(status.visible and status.text.contains(detail), "%s exposes a stable player-visible error" % label, failures)
	var focus := (Engine.get_main_loop() as SceneTree).root.gui_get_focus_owner()
	if focus == null:
		focus = selector.get("_pending_initial_focus") as Control
	TestAssertions.equal(focus, expected_focus, "%s leaves exact class retry focus reachable" % label, failures)


func _checkout_transaction_count(profile: ProfileState) -> int:
	var count := 0
	for entry: Variant in profile.applied_transactions.values():
		if entry is Dictionary and String((entry as Dictionary).get("operation", "")) == "run_loadout_checkout":
			count += 1
	return count


func _test_transition_commit_then_checkout_rejection_retries_without_retransition(failures: Array[String]) -> void:
	var root := "user://tests/main_transition_checkout_retry_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(root)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = root
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	var created := main.profile_manager.create_profile("Transition Retry")
	TestAssertions.truthy(created.ok(), "transition-retry fixture creates active profile", failures)
	var profile := main.profile_manager.active_profile()
	var sword := ItemInstance.new()
	sword.instance_id = "item-transition-retry-sword"
	sword.base_definition_id = &"forge_vanguard_sword"
	sword.item_level = 1
	sword.rarity_id = &"common"
	sword.origin = {"issuer_namespace": "profile:%s" % profile.profile_id, "seed": 661, "sequence": 0, "source": "transition_retry_test"}
	profile.item_records = ItemRegistry.new([sword]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, profile.profile_id, EquipmentSlotIndex.capacity(), {0: sword.instance_id}).to_dictionary()
	profile.leader_loadout_class_id = "fighter"
	profile.stash_tabs = []
	profile.permanent_feature_unlocks = ["bring_in_gear", "equipment_inventory", "stash"]
	TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "transition-retry fixture persists overflowing incompatible loadout", failures)
	TestAssertions.equal(main.profile_manager.refresh_profile(profile.profile_id), "", "transition-retry fixture refreshes authoritative profile", failures)
	var checkout := RejectFirstCheckout.new()
	main.set("_loadout_checkout", checkout)
	main.call("_open_run_setup")
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var mage_focus := selector.selection_focus(&"mage")
	var warning := main.get_node("LoadoutWarningDialog")
	warning.call("_ready")
	TestAssertions.truthy(not main.select_leader_class(&"mage"), "overflowing selection opens destructive gate", failures)
	(warning.get_node("Overlay/Frame/Layout/Actions/Continue") as Button).pressed.emit()
	var exact_token := String((warning.call("projection") as LoadoutCompatibilityProjection).confirmation_token)
	var before_direct := FileAccess.get_file_as_bytes(ProfileStore.new().profile_path(profile.profile_id, root))
	warning.emit_signal("destroy_confirmed", exact_token)
	TestAssertions.equal(FileAccess.get_file_as_bytes(ProfileStore.new().profile_path(profile.profile_id, root)), before_direct, "direct exact-token signal cannot mutate before a completed hold", failures)
	TestAssertions.equal(checkout.checkout_calls, 0, "direct exact-token signal cannot start checkout", failures)
	warning.call("advance_destroy_hold", 1.25, true)
	TestAssertions.truthy(not main.run_started and not warning.call("is_open") and selector.is_open(), "committed transition plus rejected checkout restores visible run setup", failures)
	_assert_reachable_error(main, selector, mage_focus, "checkout rejected after transition", "transition checkout rejection", failures)
	var transitioned := ProfileStore.new().load_profile(profile.profile_id, root).profile
	TestAssertions.truthy(not JSON.stringify(transitioned.to_dictionary()).contains(sword.instance_id), "legitimate hold destroys the exact overflow item once", failures)
	TestAssertions.equal(_operation_count(transitioned, "loadout_transition"), 1, "legitimate hold commits one transition journal entry", failures)
	TestAssertions.equal(checkout.checkout_calls, 1, "post-transition checkout rejection is attempted once", failures)
	warning.emit_signal("destroy_confirmed", exact_token)
	TestAssertions.equal(_operation_count(ProfileStore.new().load_profile(profile.profile_id, root).profile, "loadout_transition"), 1, "replayed public signal cannot duplicate committed transition", failures)

	TestAssertions.truthy(main.select_leader_class(&"mage"), "retry after rejected checkout starts from already-transitioned profile", failures)
	var saved := ProfileStore.new().load_profile(profile.profile_id, root).profile
	TestAssertions.equal(_operation_count(saved, "loadout_transition"), 1, "retry does not repeat transition or destruction", failures)
	TestAssertions.equal(_operation_count(saved, "run_loadout_checkout"), 1, "retry commits one checkout journal entry", failures)
	TestAssertions.equal(checkout.checkout_calls, 2, "retry performs only the necessary second checkout attempt", failures)
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()
	ProfileTestSupport.remove_tree(root)


func _operation_count(profile: ProfileState, operation: String) -> int:
	var count := 0
	for entry: Variant in profile.applied_transactions.values():
		if entry is Dictionary and String((entry as Dictionary).get("operation", "")) == operation:
			count += 1
	return count


func _test_durable_route_resumes_without_checkout(failures: Array[String]) -> void:
	var root := _recovery_root("ready_resume")
	var original_profile := _save_recovery_profile(root, &"fighter")
	var original := RunRecoveryService.new().inspect(original_profile)
	TestAssertions.truthy(original.ready(), "durable resume fixture is strictly ready", failures)
	var checkout_spy := RecoveryCheckoutSpy.new()
	var recovery_spy := RecoveryServiceSpy.new(checkout_spy)
	var main := _recovery_main(root, checkout_spy, recovery_spy)
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var dialog := main.get_node("RunRecoveryDialog")
	TestAssertions.equal(menu.projection().primary_route_id, MainMenuViewModel.ROUTE_RUN_RECOVERY, "restart projects the durable recovery route", failures)
	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_RUN_RECOVERY)
	TestAssertions.truthy(dialog.is_open() and not menu.is_open(), "recovery route opens the dedicated dialog", failures)
	dialog.resume_requested.emit()
	TestAssertions.equal(checkout_spy.checkout_calls, 0, "durable resume performs zero checkouts", failures)
	TestAssertions.truthy(main.run_started and main.active_run_context != null, "ready recovery starts gameplay", failures)
	TestAssertions.equal(main.active_run_context.run_id, original.run_id, "runtime preserves recovered run id", failures)
	TestAssertions.equal(main.game_run.run_seed, original.bootstrap.run_seed, "runtime preserves recovered seed", failures)
	TestAssertions.equal(main.spawn_director.run_seed, original.bootstrap.run_seed, "spawn schedule preserves recovered seed", failures)
	TestAssertions.equal(main.active_run_context.item_state().to_dictionary(), original.bootstrap.item_state().to_dictionary(), "runtime preserves checked-out item state", failures)
	TestAssertions.equal(recovery_spy.inspect_calls, 1, "ready route inspects durable recovery once", failures)
	_cleanup_recovery_main(main, root)


func _test_refresh_failure_rejects_cached_ready_recovery(failures: Array[String]) -> void:
	var root := _recovery_root("stale_refresh_failure")
	_save_recovery_profile(root, &"fighter")
	var checkout_spy := RecoveryCheckoutSpy.new()
	var recovery_spy := RecoveryServiceSpy.new(checkout_spy)
	var main := _recovery_main(root, checkout_spy, recovery_spy)
	var manager := RefreshFailureManager.new()
	manager.fail_on_call = 1
	manager.failure_reason = "injected recovery route refresh failure"
	TestAssertions.equal(manager.bootstrap(root), "", "refresh-failure manager bootstraps cached READY recovery", failures)
	main.profile_manager = manager
	var context_factory_calls: Array[int] = [0]
	main.set("_run_context_factory", func() -> PlayerRunContext:
		context_factory_calls[0] += 1
		return PlayerRunContext.new()
	)
	var dialog := main.get_node("RunRecoveryDialog")
	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_RUN_RECOVERY)
	TestAssertions.equal(recovery_spy.inspect_calls, 0, "refresh failure never inspects stale cached READY recovery", failures)
	TestAssertions.equal(main.get("_active_run_recovery"), null, "refresh failure retains no actionable cached recovery", failures)
	_assert_terminal_recovery_dialog(dialog, "Unable to refresh this interrupted run.", "injected recovery route refresh failure", "route refresh failure", failures)
	dialog.resume_requested.emit()
	dialog.legacy_class_requested.emit(&"fighter")
	dialog.abandon_requested.emit(DURABLE_RUN_ID)
	TestAssertions.equal(checkout_spy.checkout_calls, 0, "stale recovery refresh failure performs zero checkout mutations", failures)
	TestAssertions.equal(recovery_spy.bind_calls, 0, "stale recovery refresh failure cannot bind a legacy class", failures)
	TestAssertions.equal(recovery_spy.forfeit_calls, 0, "stale recovery refresh failure cannot abandon the run", failures)
	TestAssertions.equal(context_factory_calls[0], 0, "stale recovery refresh failure never attempts runtime start", failures)
	TestAssertions.truthy(not main.run_started and main.active_run_context == null, "stale recovery refresh failure leaves runtime untouched", failures)
	_cleanup_recovery_main(main, root)


func _test_legacy_binding_refreshes_reinspects_and_rejects_incompatible_bytes(failures: Array[String]) -> void:
	var root := _recovery_root("legacy_bind")
	_save_recovery_profile(root, &"")
	var checkout_spy := RecoveryCheckoutSpy.new()
	var recovery_spy := RecoveryServiceSpy.new(checkout_spy)
	var main := _recovery_main(root, checkout_spy, recovery_spy)
	var dialog := main.get_node("RunRecoveryDialog")
	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_RUN_RECOVERY)
	dialog.legacy_class_requested.emit(&"fighter")
	TestAssertions.equal(recovery_spy.bind_calls, 1, "legacy selection binds exactly once", failures)
	TestAssertions.truthy(recovery_spy.inspect_calls >= 2 and recovery_spy.inspected_class_ids[-1] == &"fighter", "legacy binding reinspects the refreshed bound profile", failures)
	TestAssertions.equal(main.active_profile().resumable_run.get("selected_leader_class_id", ""), "fighter", "manager refresh observes the bound durable class", failures)
	TestAssertions.truthy(main.run_started, "legacy binding starts only after READY reinspection", failures)
	TestAssertions.equal(checkout_spy.checkout_calls, 0, "legacy binding never performs checkout", failures)
	_cleanup_recovery_main(main, root)

	var incompatible_root := _recovery_root("legacy_incompatible")
	var vestments := _recovery_item("item-main-incompatible", &"storm_chaplain_vestments")
	_save_recovery_profile(incompatible_root, &"", [vestments], {1: vestments.instance_id})
	var path := ProfileStore.new().profile_path(DURABLE_PROFILE_ID, incompatible_root)
	var before := FileAccess.get_file_as_bytes(path)
	var incompatible_checkout := RecoveryCheckoutSpy.new()
	var incompatible_recovery := RecoveryServiceSpy.new(incompatible_checkout)
	var incompatible_main := _recovery_main(incompatible_root, incompatible_checkout, incompatible_recovery)
	var incompatible_dialog := incompatible_main.get_node("RunRecoveryDialog")
	incompatible_main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_RUN_RECOVERY)
	incompatible_dialog.legacy_class_requested.emit(&"fighter")
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before, "incompatible legacy binding preserves exact profile bytes", failures)
	TestAssertions.equal(incompatible_checkout.checkout_calls, 0, "incompatible legacy binding performs zero checkouts", failures)
	TestAssertions.truthy(incompatible_dialog.is_open() and not incompatible_main.run_started, "incompatible binding leaves recovery available", failures)
	TestAssertions.truthy((incompatible_dialog.get_node("Overlay/Frame/Layout/Status") as Label).text == "Unable to bind that leader class.", "incompatible binding uses safe player-facing copy", failures)
	TestAssertions.truthy((incompatible_dialog.get_node("Overlay/Frame/Layout/TechnicalDetail") as Label).text.contains("ineligible"), "incompatible binding preserves technical diagnostics", failures)
	_cleanup_recovery_main(incompatible_main, incompatible_root)


func _test_durable_context_failure_preserves_recovery(failures: Array[String]) -> void:
	var root := _recovery_root("context_failure")
	_save_recovery_profile(root, &"fighter")
	var path := ProfileStore.new().profile_path(DURABLE_PROFILE_ID, root)
	var before := FileAccess.get_file_as_bytes(path)
	var checkout_spy := RecoveryCheckoutSpy.new()
	var recovery_spy := RecoveryServiceSpy.new(checkout_spy)
	var main := _recovery_main(root, checkout_spy, recovery_spy)
	main.set("_run_context_factory", func() -> PlayerRunContext: return InjectedContextFailure.new())
	var dialog := main.get_node("RunRecoveryDialog")
	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_RUN_RECOVERY)
	dialog.resume_requested.emit()
	TestAssertions.truthy(not main.run_started and dialog.is_open(), "context failure keeps recovery dialog available", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before, "context failure preserves exact durable recovery bytes", failures)
	TestAssertions.equal(checkout_spy.checkout_calls, 0, "context failure performs zero checkouts", failures)
	TestAssertions.equal((dialog.get_node("Overlay/Frame/Layout/Status") as Label).text, "Unable to resume this run.", "context failure uses safe player-facing copy", failures)
	TestAssertions.truthy((dialog.get_node("Overlay/Frame/Layout/TechnicalDetail") as Label).text.contains("post-checkout context failure"), "context failure exposes technical diagnostics separately", failures)
	main.set("_run_context_factory", func() -> PlayerRunContext: return PlayerRunContext.new())
	dialog.resume_requested.emit()
	TestAssertions.truthy(main.run_started and main.active_run_context != null, "context failure leaves the same durable recovery retryable", failures)
	TestAssertions.equal(checkout_spy.checkout_calls, 0, "context retry still performs zero checkouts", failures)
	_cleanup_recovery_main(main, root)


func _test_strict_abandonment_and_forfeit_failure(failures: Array[String]) -> void:
	var root := _recovery_root("forfeit_success")
	_save_recovery_profile(root, &"fighter")
	var checkout_spy := RecoveryCheckoutSpy.new()
	var recovery_spy := RecoveryServiceSpy.new(checkout_spy)
	var main := _recovery_main(root, checkout_spy, recovery_spy)
	var dialog := main.get_node("RunRecoveryDialog")
	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_RUN_RECOVERY)
	dialog.abandon_requested.emit(&"run-forged-wrong-id")
	TestAssertions.equal(recovery_spy.forfeit_calls, 0, "forged abandonment intent cannot call forfeit", failures)
	TestAssertions.truthy(not ProfileStore.new().load_profile(DURABLE_PROFILE_ID, root).profile.resumable_run.is_empty(), "forged abandonment preserves durable recovery", failures)
	dialog.abandon_requested.emit(DURABLE_RUN_ID)
	TestAssertions.equal(recovery_spy.forfeit_calls, 1, "confirmed exact abandonment calls strict forfeit once", failures)
	TestAssertions.equal(checkout_spy.forfeit_calls, 1, "strict recovery delegates one real forfeit mutation", failures)
	TestAssertions.truthy(ProfileStore.new().load_profile(DURABLE_PROFILE_ID, root).profile.resumable_run.is_empty(), "successful forfeit clears durable recovery", failures)
	TestAssertions.truthy(not dialog.is_open() and (main.get_node("MainMenuScreen") as MainMenuScreen).is_open(), "successful forfeit closes recovery and refreshes the menu", failures)
	_cleanup_recovery_main(main, root)

	var failure_root := _recovery_root("forfeit_failure")
	_save_recovery_profile(failure_root, &"fighter")
	var path := ProfileStore.new().profile_path(DURABLE_PROFILE_ID, failure_root)
	var before := FileAccess.get_file_as_bytes(path)
	var failure_checkout := RecoveryCheckoutSpy.new()
	var failure_recovery := ForfeitFailureRecovery.new(failure_checkout)
	var failure_main := _recovery_main(failure_root, failure_checkout, failure_recovery)
	var failure_dialog := failure_main.get_node("RunRecoveryDialog")
	failure_main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_RUN_RECOVERY)
	failure_dialog.abandon_requested.emit(DURABLE_RUN_ID)
	TestAssertions.equal(failure_recovery.forfeit_calls, 1, "failed forfeit is attempted exactly once", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before, "failed forfeit preserves exact recovery bytes", failures)
	TestAssertions.truthy(failure_dialog.is_open() and not failure_main.active_profile().resumable_run.is_empty(), "forfeit error leaves dialog and recovery available", failures)
	TestAssertions.equal((failure_dialog.get_node("Overlay/Frame/Layout/Status") as Label).text, "Unable to abandon this run.", "forfeit failure uses safe player-facing copy", failures)
	TestAssertions.truthy((failure_dialog.get_node("Overlay/Frame/Layout/TechnicalDetail") as Label).text.contains("injected persistence failure"), "forfeit failure exposes technical detail separately", failures)
	_cleanup_recovery_main(failure_main, failure_root)


func _test_committed_forfeit_refresh_failure_is_terminal(failures: Array[String]) -> void:
	var root := _recovery_root("forfeit_refresh_failure")
	_save_recovery_profile(root, &"fighter")
	var checkout_spy := RecoveryCheckoutSpy.new()
	var recovery_spy := RecoveryServiceSpy.new(checkout_spy)
	var main := _recovery_main(root, checkout_spy, recovery_spy)
	var manager := RefreshFailureManager.new()
	manager.fail_on_call = 2
	manager.failure_reason = "injected post-forfeit refresh failure"
	TestAssertions.equal(manager.bootstrap(root), "", "post-forfeit refresh manager bootstraps durable recovery", failures)
	main.profile_manager = manager
	var dialog := main.get_node("RunRecoveryDialog")
	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_RUN_RECOVERY)
	dialog.abandon_requested.emit(DURABLE_RUN_ID)
	TestAssertions.equal(recovery_spy.forfeit_calls, 1, "committed abandonment calls recovery forfeit once before refresh failure", failures)
	TestAssertions.equal(checkout_spy.forfeit_calls, 1, "committed abandonment performs one durable forfeit mutation", failures)
	TestAssertions.truthy(ProfileStore.new().load_profile(DURABLE_PROFILE_ID, root).profile.resumable_run.is_empty(), "forfeit remains durably committed when manager refresh fails", failures)
	TestAssertions.equal(main.get("_active_run_recovery"), null, "committed forfeit clears actionable recovery before refresh", failures)
	_assert_terminal_recovery_dialog(dialog, "The run was abandoned, but the profile could not be refreshed.", "injected post-forfeit refresh failure", "post-forfeit refresh failure", failures)
	dialog.abandon_requested.emit(DURABLE_RUN_ID)
	(dialog.get_node("AbandonConfirmation") as ConfirmationDialog).confirmed.emit()
	TestAssertions.equal(recovery_spy.forfeit_calls, 1, "terminal post-forfeit failure cannot call recovery forfeit again", failures)
	TestAssertions.equal(checkout_spy.forfeit_calls, 1, "terminal post-forfeit failure cannot repeat durable mutation", failures)
	TestAssertions.equal(checkout_spy.checkout_calls, 0, "post-forfeit refresh failure never performs checkout", failures)
	TestAssertions.truthy(not main.run_started and main.active_run_context == null, "post-forfeit refresh failure leaves runtime stopped", failures)
	_cleanup_recovery_main(main, root)


func _assert_terminal_recovery_dialog(dialog: Node, safe_message: String, technical_detail: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(dialog.is_open(), "%s keeps recovery failure visible" % label, failures)
	TestAssertions.equal((dialog.get_node("Overlay/Frame/Layout/Status") as Label).text, safe_message, "%s uses safe player-facing copy" % label, failures)
	var technical := dialog.get_node("Overlay/Frame/Layout/TechnicalDetail") as Label
	TestAssertions.truthy(technical.visible and technical.text.contains(technical_detail), "%s exposes technical diagnostics separately" % label, failures)
	for path: String in [
		"Overlay/Frame/Layout/Actions/Resume",
		"Overlay/Frame/Layout/ClassPicker",
		"Overlay/Frame/Layout/Actions/Bind",
		"Overlay/Frame/Layout/Actions/Abandon",
	]:
		var control := dialog.get_node(path) as Control
		TestAssertions.truthy(not control.visible and control.get("disabled"), "%s disables and hides %s" % [label, control.name], failures)
	var cancel := dialog.get_node("Overlay/Frame/Layout/Actions/Cancel") as Button
	TestAssertions.truthy(cancel.visible and not cancel.disabled, "%s leaves Cancel available" % label, failures)
	TestAssertions.equal(dialog.get("_initial_focus"), cancel, "%s focuses Cancel deterministically" % label, failures)


func _save_recovery_profile(
	root: String,
	class_id: StringName,
	items: Array[ItemInstance] = [],
	equipment_slots: Dictionary = {},
) -> ProfileState:
	ProfileTestSupport.remove_tree(root)
	var profile := ProfileState.new_profile(DURABLE_PROFILE_ID, "Main Recovery Tester", 1000)
	profile.inventory_columns = 2
	var state := ItemOwnershipState.create(String(DURABLE_PLAYER_ID), ItemRegistry.new(items), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(DURABLE_PLAYER_ID), 10),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(DURABLE_PLAYER_ID), EquipmentSlotIndex.capacity(), equipment_slots),
		RunItemBootstrap.ground_items_container(String(DURABLE_PLAYER_ID)),
	])
	profile.resumable_run = ResumableRunItemCodec.encode(RunItemBootstrap.create(DURABLE_RUN_ID, DURABLE_RUN_SEED, DURABLE_PLAYER_ID, 1, state, class_id))
	var error := ProfileStore.new().save_profile(profile, root)
	assert(error.is_empty(), error)
	return profile


func _recovery_item(instance_id: String, base_id: StringName) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 28
	item.rarity_id = &"common"
	item.origin = {
		"issuer_namespace": "profile:%s" % DURABLE_PROFILE_ID,
		"seed": DURABLE_RUN_SEED,
		"sequence": 0,
		"source": "main_recovery_test",
	}
	return item


func _recovery_main(root: String, checkout: RecoveryCheckoutSpy, recovery: RunRecoveryService) -> PartyForgeMain:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = root
	main.set("_loadout_checkout", checkout)
	main.set("_run_recovery", recovery)
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	main.get_node("RunRecoveryDialog").call("_ready")
	return main


func _cleanup_recovery_main(main: PartyForgeMain, root: String) -> void:
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()
	ProfileTestSupport.remove_tree(root)


func _recovery_root(label: String) -> String:
	return "user://tests/main_durable_recovery_%s_%d_%d" % [label, OS.get_process_id(), Time.get_ticks_usec()]
