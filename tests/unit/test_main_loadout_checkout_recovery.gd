extends RefCounted

class RefreshFailureManager extends ProfileManager:
	var refresh_calls := 0
	var fail_on_call := 2

	func refresh_profile(profile_id: String) -> String:
		refresh_calls += 1
		if refresh_calls == fail_on_call:
			return "PROFILE_REFRESH_ERROR profile=%s error=injected post-checkout refresh failure" % profile_id
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


func run() -> Array[String]:
	var failures: Array[String] = []
	var main_script := load("res://scripts/game/main.gd") as Script
	var source := FileAccess.get_file_as_string("res://scripts/game/main.gd")
	TestAssertions.truthy("_pending_checkout_recovery" in source, "main owns explicit same-session checkout recovery state", failures)
	TestAssertions.truthy("_run_context_factory" in source, "main owns an injectable production context factory", failures)
	TestAssertions.truthy(main_script != null, "main recovery fixture script loads", failures)
	if not failures.is_empty():
		return failures
	_test_durable_retry_reuses_exact_checkout(failures)
	_test_transition_commit_then_checkout_rejection_retries_without_retransition(failures)
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
