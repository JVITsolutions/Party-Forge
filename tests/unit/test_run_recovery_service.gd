extends RefCounted

const PROFILE_ID := "profile-recovery01"
const RUN_ID := &"run-recovery-001"
const RUN_PLAYER_ID := &"run-recovery-player-001"
const LEADER_MEMBER_ID := 1

class MutationSpy extends ProfileMutationService:
	var _operation_counts: Dictionary = {}

	func apply(
		profile_id: String,
		transaction_id: String,
		mutate: Callable,
		root: String = ProfileStore.DEFAULT_ROOT,
		now_unix: int = -1,
		operation: String = "",
		request: Dictionary = {},
	) -> ProfileMutationResult:
		_operation_counts[operation] = int(_operation_counts.get(operation, 0)) + 1
		return super.apply(profile_id, transaction_id, mutate, root, now_unix, operation, request)

	func operation_count(operation: String) -> int:
		return int(_operation_counts.get(operation, 0))

var _root_counter := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_result_contract_and_inspection_are_typed_and_defensive(failures)
	_test_inspection_rejects_malformed_unknown_and_incompatible_recovery(failures)
	_test_restart_assertion_targets_restarted_dependency(failures)
	_test_legacy_binding_is_atomic_durable_and_never_checks_out(failures)
	_test_binding_persistence_failure_preserves_exact_bytes(failures)
	_test_forfeit_requires_the_exact_recovered_run(failures)
	return failures


func _test_restart_assertion_targets_restarted_dependency(failures: Array[String]) -> void:
	var source := FileAccess.get_file_as_string("res://tests/unit/test_run_recovery_service.gd")
	var restarted_assertion := "restarted_" + "spy.operation_count(RunLoadoutCheckoutService.CHECKOUT_OPERATION)"
	TestAssertions.truthy(restarted_assertion in source, "restart checkout assertion observes the fresh restarted dependency", failures)


func _test_result_contract_and_inspection_are_typed_and_defensive(failures: Array[String]) -> void:
	var service := RunRecoveryService.new()
	var current := _profile_with_recovery(&"fighter")
	var current_before := current.to_dictionary()
	var ready := service.inspect(current)
	TestAssertions.equal(ready.code, RunRecoveryResult.Code.READY, "current strict recovery is ready", failures)
	TestAssertions.truthy(ready.ready(), "ready result satisfies its complete contract", failures)
	TestAssertions.equal(ready.run_id, RUN_ID, "ready result exposes exact run identity", failures)
	TestAssertions.equal(ready.selected_leader_class_id, &"fighter", "ready result exposes the durable class", failures)
	TestAssertions.truthy(ready.can_forfeit, "ready recovery can be forfeited", failures)
	TestAssertions.equal(ready.error, "", "ready recovery has no error", failures)
	ready.profile.resumable_run.clear()
	var exposed_state := ready.bootstrap.item_state()
	exposed_state.owner_id = "escaped-recovery-result"
	TestAssertions.equal(current.to_dictionary(), current_before, "result profile is a defensive copy", failures)
	TestAssertions.equal(ready.bootstrap.item_state().owner_id, String(RUN_PLAYER_ID), "result bootstrap item state is defensive", failures)

	var legacy := _profile_with_recovery(&"")
	var class_required := service.inspect(legacy)
	TestAssertions.equal(class_required.code, RunRecoveryResult.Code.CLASS_REQUIRED, "legacy strict recovery requires a class", failures)
	TestAssertions.truthy(not class_required.ready(), "class-required result is not ready", failures)
	TestAssertions.equal(class_required.run_id, RUN_ID, "class-required result exposes exact run identity", failures)
	TestAssertions.truthy(class_required.can_forfeit, "class-required recovery can be forfeited", failures)
	TestAssertions.equal(class_required.error, "", "class-required recovery is structurally valid", failures)

	var empty := ProfileState.new_profile("profile-recovery-empty", "Empty Recovery", 1000)
	var unavailable := service.inspect(empty)
	TestAssertions.equal(unavailable.code, RunRecoveryResult.Code.INVALID, "empty recovery is invalid", failures)
	TestAssertions.truthy(not unavailable.can_forfeit, "empty recovery cannot be forfeited", failures)
	TestAssertions.equal(unavailable.run_id, &"", "empty recovery exposes no run identity", failures)
	TestAssertions.equal(unavailable.profile, null, "empty recovery exposes no candidate profile", failures)
	TestAssertions.truthy(unavailable.error.contains("strict bootstrap unavailable"), "empty recovery reports unavailable strict bootstrap", failures)

	var missing_profile := service.inspect(null)
	TestAssertions.equal(missing_profile.code, RunRecoveryResult.Code.INVALID, "null profile is invalid", failures)
	TestAssertions.equal(missing_profile.error, "PARTY_FORGE_RUN_RECOVERY_ERROR field=profile reason=must not be null", "null profile reports exact recovery error", failures)

func _test_inspection_rejects_malformed_unknown_and_incompatible_recovery(failures: Array[String]) -> void:
	var service := RunRecoveryService.new()
	var malformed := _profile_with_recovery(&"fighter")
	malformed.resumable_run["run_seed"] = 0
	var malformed_result := service.inspect(malformed)
	TestAssertions.equal(malformed_result.code, RunRecoveryResult.Code.INVALID, "malformed strict bootstrap is invalid", failures)
	TestAssertions.truthy(malformed_result.error.contains("field=profile") and malformed_result.error.contains("run_seed"), "malformed bootstrap reports structural profile failure", failures)
	TestAssertions.truthy(not malformed_result.can_forfeit, "malformed bootstrap cannot be forfeited without a decoded identity", failures)

	var unknown := service.inspect(_profile_with_recovery(&"unknown_class"))
	TestAssertions.equal(unknown.code, RunRecoveryResult.Code.INVALID, "unknown recovered class is invalid", failures)
	TestAssertions.equal(unknown.error, "PARTY_FORGE_RUN_RECOVERY_ERROR field=selected_leader_class_id reason=unknown leader class", "unknown class uses exact recovery diagnostic", failures)
	TestAssertions.equal(unknown.run_id, RUN_ID, "unknown class retains exact run identity", failures)
	TestAssertions.truthy(unknown.can_forfeit, "structurally valid unknown-class recovery can be forfeited", failures)

	var vestments := _item("item-recovery-incompatible", &"storm_chaplain_vestments", 0)
	var incompatible := service.inspect(_profile_with_recovery(&"fighter", [vestments], {1: vestments.instance_id}))
	TestAssertions.equal(incompatible.code, RunRecoveryResult.Code.INVALID, "class-incompatible recovered equipment is invalid", failures)
	TestAssertions.truthy(incompatible.error.begins_with("PARTY_FORGE_RUN_RECOVERY_ERROR") and incompatible.error.contains("ineligible"), "incompatible equipment reuses recovery-prefixed eligibility diagnostics", failures)
	TestAssertions.equal(incompatible.run_id, RUN_ID, "incompatible class retains exact run identity", failures)
	TestAssertions.truthy(incompatible.can_forfeit, "structurally valid incompatible recovery can be forfeited", failures)

func _test_legacy_binding_is_atomic_durable_and_never_checks_out(failures: Array[String]) -> void:
	var root := _case_root("legacy_binding")
	var store := ProfileStore.new()
	var sword := _item("item-recovery-bound", &"forge_vanguard_sword", 0)
	var legacy := _profile_with_recovery(&"", [sword], {9: sword.instance_id})
	_save_profile(store, legacy, root, "legacy binding fixture", failures)
	var original := RunLoadoutCheckoutService.new().bootstrap_from(legacy)
	var spy := MutationSpy.new(store)
	var checkout := RunLoadoutCheckoutService.new(spy)
	var service := RunRecoveryService.new(checkout, spy, store)
	var bound := service.bind_legacy_class(PROFILE_ID, &"fighter", root)
	TestAssertions.equal(bound.code, RunRecoveryResult.Code.READY, "legacy class binding returns ready recovery", failures)
	TestAssertions.truthy(bound.ready(), "bound recovery satisfies ready contract", failures)
	TestAssertions.equal(spy.operation_count(RunLoadoutCheckoutService.CHECKOUT_OPERATION), 0, "recovery never checks out again", failures)
	TestAssertions.equal(spy.operation_count("bind_run_recovery_class"), 1, "binding uses one mutation transaction", failures)
	TestAssertions.equal(bound.bootstrap.run_id, original.run_id, "binding preserves run id", failures)
	TestAssertions.equal(bound.bootstrap.item_state().to_dictionary(), original.item_state().to_dictionary(), "binding preserves checked-out items", failures)
	var saved := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.equal(saved.resumable_run["selected_leader_class_id"], "fighter", "binding persists only the selected class marker", failures)
	var transaction_id := "bind-run-class:%s:%s" % [RUN_ID, &"fighter"]
	TestAssertions.truthy(saved.applied_transactions.has(transaction_id), "binding persists the deterministic transaction id", failures)
	if saved.applied_transactions.has(transaction_id):
		TestAssertions.equal((saved.applied_transactions[transaction_id] as Dictionary)["operation"], "bind_run_recovery_class", "binding journal records the exact operation", failures)

	var restarted_manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new())
	TestAssertions.equal(restarted_manager.bootstrap(root), "", "profile manager restarts from bound recovery", failures)
	var restarted_store := ProfileStore.new()
	var restarted_spy := MutationSpy.new(restarted_store)
	var restarted_checkout := RunLoadoutCheckoutService.new(restarted_spy)
	var restarted_service := RunRecoveryService.new(restarted_checkout, restarted_spy, restarted_store)
	var restarted := restarted_service.inspect(restarted_manager.active_profile())
	TestAssertions.equal(restarted.code, RunRecoveryResult.Code.READY, "disk restart returns directly ready without another class request", failures)
	TestAssertions.equal(restarted.selected_leader_class_id, &"fighter", "disk restart retains the bound class", failures)
	TestAssertions.equal(restarted_spy.operation_count(RunLoadoutCheckoutService.CHECKOUT_OPERATION), 0, "restart performs no checkout through the fresh restarted dependency", failures)
	ProfileTestSupport.remove_tree(root)

func _test_binding_persistence_failure_preserves_exact_bytes(failures: Array[String]) -> void:
	var root := _case_root("binding_save_failure")
	var good_store := ProfileStore.new()
	var legacy := _profile_with_recovery(&"")
	_save_profile(good_store, legacy, root, "binding save failure fixture", failures)
	var path := good_store.profile_path(PROFILE_ID, root)
	var bytes_before := FileAccess.get_file_as_bytes(path)
	var recovery_before := good_store.load_profile(PROFILE_ID, root).profile.resumable_run.duplicate(true)
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var spy := MutationSpy.new(failing_store)
	var failed := RunRecoveryService.new(RunLoadoutCheckoutService.new(spy), spy, failing_store).bind_legacy_class(PROFILE_ID, &"fighter", root)
	TestAssertions.equal(failed.code, RunRecoveryResult.Code.PERSISTENCE_FAILED, "binding save failure has the persistence-failed code", failures)
	TestAssertions.truthy(failed.error.contains("JSON_STORE_SAVE_ERROR"), "binding save failure exposes atomic store diagnostics", failures)
	TestAssertions.equal(failed.profile, null, "binding save failure exposes no candidate profile", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), bytes_before, "binding persistence failure preserves exact primary bytes", failures)
	TestAssertions.equal(good_store.load_profile(PROFILE_ID, root).profile.resumable_run, recovery_before, "binding persistence failure preserves exact durable recovery", failures)
	TestAssertions.equal(spy.operation_count(RunLoadoutCheckoutService.CHECKOUT_OPERATION), 0, "failed binding never checks out", failures)
	ProfileTestSupport.remove_tree(root)

func _test_forfeit_requires_the_exact_recovered_run(failures: Array[String]) -> void:
	var root := _case_root("strict_forfeit")
	var store := ProfileStore.new()
	var profile := _profile_with_recovery(&"fighter")
	_save_profile(store, profile, root, "strict forfeit fixture", failures)
	var path := store.profile_path(PROFILE_ID, root)
	var before := FileAccess.get_file_as_bytes(path)
	var service := RunRecoveryService.new(RunLoadoutCheckoutService.new(ProfileMutationService.new(store)), ProfileMutationService.new(store), store)
	var wrong := service.forfeit(PROFILE_ID, &"run-recovery-wrong", root)
	TestAssertions.truthy(not wrong.ok() and wrong.error.contains("run identity mismatch"), "forfeit rejects a nonmatching run identity", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before, "nonmatching forfeit preserves exact recovery bytes", failures)
	var forfeited := service.forfeit(PROFILE_ID, RUN_ID, root)
	TestAssertions.truthy(forfeited.ok(), "matching recovery can be forfeited", failures)
	TestAssertions.equal(store.load_profile(PROFILE_ID, root).profile.resumable_run, {}, "matching forfeit clears strict recovery", failures)
	ProfileTestSupport.remove_tree(root)

func _profile_with_recovery(
	class_id: StringName,
	items: Array[ItemInstance] = [],
	equipment_slots: Dictionary = {},
) -> ProfileState:
	var profile := ProfileState.new_profile(PROFILE_ID, "Recovery Tester", 1000)
	profile.inventory_columns = 2
	var state := ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new(items), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), equipment_slots),
		RunItemBootstrap.ground_items_container(String(RUN_PLAYER_ID)),
	])
	profile.resumable_run = ResumableRunItemCodec.encode(
		RunItemBootstrap.create(RUN_ID, 4501, RUN_PLAYER_ID, LEADER_MEMBER_ID, state, class_id)
	)
	return profile

func _item(instance_id: String, base_id: StringName, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 28
	item.rarity_id = &"common"
	item.origin = {
		"issuer_namespace": "profile:%s" % PROFILE_ID,
		"seed": 4501,
		"sequence": sequence,
		"source": "run_recovery_test",
	}
	return item

func _save_profile(store: ProfileStore, profile: ProfileState, root: String, label: String, failures: Array[String]) -> void:
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "%s saves" % label, failures)

func _case_root(label: String) -> String:
	_root_counter += 1
	return "user://tests/run_recovery_%s_%d_%d_%d" % [label.validate_filename(), OS.get_process_id(), Time.get_ticks_usec(), _root_counter]
