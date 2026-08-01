extends RefCounted

const ID := "profile-12345678"
const MAX_INT := 0x7fffffffffffffff

var _root := ""

func run() -> Array[String]:
	var failures: Array[String] = []
	_root = "user://tests/profile_mutation_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_root)
	_test_duplicate_transactions_do_not_reapply(failures)
	_reset_profile(failures)
	_test_grant_helpers_and_amount_boundaries(failures)
	_reset_profile(failures)
	_test_prologue_completion_semantics(failures)
	_reset_profile(failures)
	_test_callback_and_load_failures_leave_state_unchanged(failures)
	_reset_profile(failures)
	_test_failed_save_leaves_prior_generation_readable(failures)
	ProfileTestSupport.remove_tree(_root)
	return failures

func _test_duplicate_transactions_do_not_reapply(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	_test_fixture_save(store, failures)
	var service := ProfileMutationService.new(store)
	var invocations := [0]
	var mutate := func(profile: ProfileState) -> String:
		invocations[0] += 1
		profile.gold += 25
		profile.tree_allocations["party-forge-city-v1"] = ["city-heart"]
		return ""
	var first := service.apply(ID, "enemy-42-gold", mutate, _root, 2000)
	var retry := service.apply(ID, "enemy-42-gold", mutate, _root, 9000)
	TestAssertions.truthy(first.ok() and not first.duplicate, "first mutation commits", failures)
	TestAssertions.truthy(retry.ok() and retry.duplicate, "retry reports prior commit", failures)
	TestAssertions.equal(invocations[0], 1, "duplicate transaction does not invoke callback", failures)
	var saved := store.load_profile(ID, _root).profile
	TestAssertions.equal(saved.gold, 25, "duplicate transaction does not reapply value", failures)
	TestAssertions.equal(saved.updated_at_unix, 2000, "duplicate transaction preserves update timestamp", failures)
	TestAssertions.equal(saved.applied_transactions.get("enemy-42-gold"), 2000, "transaction keeps original timestamp", failures)
	TestAssertions.equal(saved.applied_transactions.size(), 1, "transaction map grows once per commit", failures)
	var persisted_timestamp: Variant = saved.applied_transactions["enemy-42-gold"]
	TestAssertions.truthy(typeof(persisted_timestamp) in [TYPE_INT, TYPE_FLOAT] and float(persisted_timestamp) == floor(float(persisted_timestamp)), "transaction timestamp persists as an integral JSON number", failures)
	(first.profile.tree_allocations["party-forge-city-v1"] as Array).append("shared-stash")
	retry.profile.gold = 999
	var isolated := store.load_profile(ID, _root).profile
	TestAssertions.equal((isolated.tree_allocations["party-forge-city-v1"] as Array).size(), 1, "successful result is a deep copy", failures)
	TestAssertions.equal(isolated.gold, 25, "duplicate result is isolated from persisted state", failures)

func _test_grant_helpers_and_amount_boundaries(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var service := ProfileMutationService.new(store)
	var gold := service.grant_gold(ID, "gold-positive", 25, _root)
	var points := service.grant_passive_points(ID, "points-positive", 3, _root)
	TestAssertions.truthy(gold.ok() and points.ok(), "positive grant helpers commit", failures)
	var saved := store.load_profile(ID, _root).profile
	TestAssertions.equal(saved.gold, 25, "gold grant adds the requested amount", failures)
	TestAssertions.equal(saved.passive_points_available, 3, "passive grant adds available points", failures)
	TestAssertions.equal(saved.passive_points_lifetime_earned, 3, "passive grant accounts lifetime earnings", failures)
	TestAssertions.equal(saved.applied_transactions.size(), 2, "each successful grant records one transaction", failures)
	var uneven_totals := saved.copy()
	uneven_totals.passive_points_available = 2
	uneven_totals.passive_points_lifetime_earned = 10
	uneven_totals.updated_at_unix = 2500
	TestAssertions.equal(store.save_profile(uneven_totals, _root), "", "lifetime accounting fixture saves", failures)
	var lifetime_grant := service.grant_passive_points(ID, "points-existing-lifetime", 3, _root)
	TestAssertions.truthy(lifetime_grant.ok(), "passive grant with prior lifetime commits", failures)
	saved = store.load_profile(ID, _root).profile
	TestAssertions.equal(saved.passive_points_available, 5, "passive grant adds to current available points", failures)
	TestAssertions.equal(saved.passive_points_lifetime_earned, 13, "passive grant adds to existing lifetime total", failures)
	for invalid_amount: int in [0, -1]:
		var invalid_gold := service.grant_gold(ID, "gold-invalid-%d" % invalid_amount, invalid_amount, _root)
		var invalid_points := service.grant_passive_points(ID, "points-invalid-%d" % invalid_amount, invalid_amount, _root)
		TestAssertions.truthy(not invalid_gold.ok() and invalid_gold.error.contains("gold amount must be positive"), "gold rejects non-positive amount %d" % invalid_amount, failures)
		TestAssertions.truthy(not invalid_points.ok() and invalid_points.error.contains("passive point amount must be positive"), "passive points reject non-positive amount %d" % invalid_amount, failures)
	var after_invalid := store.load_profile(ID, _root).profile
	TestAssertions.equal(after_invalid.to_dictionary(), saved.to_dictionary(), "rejected amounts do not change persisted state", failures)
	var near_limit_value := MAX_INT - 1023
	var overflowing_amount := 1024
	var near_limit := after_invalid.copy()
	near_limit.gold = near_limit_value
	near_limit.passive_points_available = near_limit_value
	near_limit.passive_points_lifetime_earned = near_limit_value
	near_limit.updated_at_unix = 3000
	TestAssertions.equal(store.save_profile(near_limit, _root), "", "overflow fixture saves", failures)
	TestAssertions.equal(store.load_profile(ID, _root).profile.gold, near_limit_value, "overflow fixture round trips exactly", failures)
	var gold_overflow := service.grant_gold(ID, "gold-overflow", overflowing_amount, _root)
	var points_overflow := service.grant_passive_points(ID, "points-overflow", overflowing_amount, _root)
	TestAssertions.truthy(not gold_overflow.ok() and gold_overflow.error.contains("gold amount overflow"), "gold rejects integer overflow", failures)
	TestAssertions.truthy(not points_overflow.ok() and points_overflow.error.contains("passive point amount overflow"), "passive points reject integer overflow", failures)
	var after_overflow := store.load_profile(ID, _root).profile
	TestAssertions.equal(after_overflow.gold, near_limit_value, "gold overflow leaves value unchanged", failures)
	TestAssertions.equal(after_overflow.passive_points_available, near_limit_value, "passive overflow leaves available points unchanged", failures)
	TestAssertions.equal(after_overflow.passive_points_lifetime_earned, near_limit_value, "passive overflow leaves lifetime points unchanged", failures)
	TestAssertions.truthy(not after_overflow.applied_transactions.has("gold-overflow") and not after_overflow.applied_transactions.has("points-overflow"), "overflow does not record transactions", failures)

func _test_prologue_completion_semantics(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var service := ProfileMutationService.new(store)
	var prologue := service.complete_prologue(ID, "prologue-complete", _root)
	var retry := service.complete_prologue(ID, "prologue-complete", _root)
	TestAssertions.truthy(prologue.ok() and retry.ok() and retry.duplicate, "prologue completion retries by transaction", failures)
	var saved := store.load_profile(ID, _root).profile
	TestAssertions.equal(saved.prologue_state, ProfileState.PrologueState.COMPLETED, "prologue marks complete", failures)
	TestAssertions.equal(saved.passive_points_available, 1, "prologue awards exactly one available point", failures)
	TestAssertions.equal(saved.passive_points_lifetime_earned, 1, "prologue awards exactly one lifetime point", failures)
	TestAssertions.truthy("city-heart" in saved.permanent_feature_unlocks, "prologue unlocks City heart", failures)
	TestAssertions.truthy("party-forge-city-v1" in saved.discovered_trees, "prologue reveals City tree", failures)
	var different_transaction := service.complete_prologue(ID, "prologue-complete-again", _root)
	TestAssertions.truthy(not different_transaction.ok() and different_transaction.error.contains("prologue already completed with different transaction"), "completed state rejects a different transaction", failures)
	var unchanged := store.load_profile(ID, _root).profile
	TestAssertions.equal(unchanged.to_dictionary(), saved.to_dictionary(), "state-level prologue rejection changes nothing", failures)

func _test_callback_and_load_failures_leave_state_unchanged(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var service := ProfileMutationService.new(store)
	for transaction_id: String in ["", "   "]:
		var invalid_gold := service.grant_gold(ID, transaction_id, 25, _root)
		var invalid_points := service.grant_passive_points(ID, transaction_id, 1, _root)
		var invalid_prologue := service.complete_prologue(ID, transaction_id, _root)
		TestAssertions.truthy(not invalid_gold.ok() and invalid_gold.error.contains("transaction id is required"), "gold rejects blank transaction id", failures)
		TestAssertions.truthy(not invalid_points.ok() and invalid_points.error.contains("transaction id is required"), "passive points reject blank transaction id", failures)
		TestAssertions.truthy(not invalid_prologue.ok() and invalid_prologue.error.contains("transaction id is required"), "prologue rejects blank transaction id", failures)
	var missing := service.grant_gold("profile-missing1", "missing-gold", 25, _root)
	TestAssertions.truthy(not missing.ok() and missing.error.contains("profile is missing"), "missing profile fails closed", failures)
	TestAssertions.truthy(not FileAccess.file_exists(store.profile_path("profile-missing1", _root)), "missing profile is not materialized", failures)
	var before := store.load_profile(ID, _root).profile
	var missing_callback := service.apply(ID, "missing-callback", Callable(), _root, 4000)
	TestAssertions.truthy(not missing_callback.ok() and missing_callback.error.contains("mutation is missing"), "invalid callable is rejected", failures)
	var callback_error := service.apply(ID, "callback-error", func(profile: ProfileState) -> String:
		profile.gold = 500
		return "PROFILE_MUTATION_ERROR reason=fixture callback failed"
	, _root, 4001)
	TestAssertions.equal(callback_error.error, "PROFILE_MUTATION_ERROR reason=fixture callback failed", "callback error is surfaced unchanged", failures)
	var invalid_return := service.apply(ID, "invalid-return", func(profile: ProfileState) -> Variant:
		profile.gold = 600
		return 123
	, _root, 4002)
	TestAssertions.truthy(not invalid_return.ok() and invalid_return.error.contains("mutation must return String"), "invalid callback return reports stable error", failures)
	var after_callbacks := store.load_profile(ID, _root).profile
	TestAssertions.equal(after_callbacks.to_dictionary(), before.to_dictionary(), "callback failures do not persist working-copy changes", failures)
	var corrupt_path := store.profile_path(ID, _root)
	var corrupt_bytes := "{not valid json"
	var corrupt := FileAccess.open(corrupt_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string(corrupt_bytes)
		corrupt.close()
	var corrupt_result := service.grant_gold(ID, "corrupt-gold", 25, _root)
	TestAssertions.truthy(not corrupt_result.ok() and corrupt_result.error.contains("JSON_STORE_LOAD_ERROR"), "corrupt profile load error is surfaced", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(corrupt_path), corrupt_bytes, "corrupt profile is not replaced", failures)

func _test_failed_save_leaves_prior_generation_readable(failures: Array[String]) -> void:
	var good := ProfileStore.new()
	var before := good.load_profile(ID, _root).profile
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var failed := ProfileMutationService.new(failing_store).apply(ID, "failed-save", func(profile: ProfileState) -> String:
		profile.gold += 50
		return ""
	, _root, 5000)
	TestAssertions.truthy(not failed.ok() and failed.error.contains("JSON_STORE_SAVE_ERROR") and failed.error.contains("stage=promote"), "failed atomic save reports stable persistence diagnostics", failures)
	var after := good.load_profile(ID, _root)
	TestAssertions.truthy(after.ok(), "prior persisted state remains readable after failed save", failures)
	TestAssertions.equal(after.profile.to_dictionary(), before.to_dictionary(), "failed save retains values timestamps and transactions", failures)
	TestAssertions.truthy(not after.profile.applied_transactions.has("failed-save"), "failed save does not leave an idempotency record", failures)

func _reset_profile(failures: Array[String]) -> void:
	ProfileTestSupport.remove_tree(_root)
	_test_fixture_save(ProfileStore.new(), failures)

func _test_fixture_save(store: ProfileStore, failures: Array[String]) -> void:
	TestAssertions.equal(store.save_profile(ProfileState.new_profile(ID, "Jacob", 1000), _root), "", "profile mutation fixture saves", failures)
