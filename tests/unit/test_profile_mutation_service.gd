extends RefCounted

const ID := "profile-12345678"
const JSON_SAFE_INTEGER_MAX := 9007199254740991

var _root := ""

class CleanupFailingAtomicJsonStore extends AtomicJsonStore:
	var failure_path := ""

	func _remove(path: String) -> Error:
		if path == failure_path:
			return ERR_CANT_CREATE
		return super._remove(path)

func run() -> Array[String]:
	var failures: Array[String] = []
	_root = "user://tests/profile_mutation_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_root)
	_test_duplicate_transactions_do_not_reapply(failures)
	_reset_profile(failures)
	_test_optional_transaction_receipt_is_defensive(failures)
	_reset_profile(failures)
	_test_commit_timestamp_is_monotonic(failures)
	_test_protected_metadata_changes_are_rejected(failures)
	_reset_profile(failures)
	_test_validation_failure_leaves_state_unchanged(failures)
	_reset_profile(failures)
	_test_duplicate_recovered_from_backup_does_not_rewrite(failures)
	_reset_profile(failures)
	_test_grant_helpers_and_amount_boundaries(failures)
	_reset_profile(failures)
	_test_prologue_completion_semantics(failures)
	_reset_profile(failures)
	_test_prologue_canonicalizes_existing_projection(failures)
	_reset_profile(failures)
	_test_historical_prologue_duplicate_preserves_result(failures)
	_reset_profile(failures)
	_test_callback_and_load_failures_leave_state_unchanged(failures)
	_reset_profile(failures)
	_test_failed_save_leaves_prior_generation_readable(failures)
	_reset_profile(failures)
	_test_post_commit_cleanup_is_successful_to_caller(failures)
	ProfileTestSupport.remove_tree(_root)
	return failures

func _test_optional_transaction_receipt_is_defensive(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var service := ProfileMutationService.new(store)
	var receipt := {"schema_version": 1, "source_fingerprint": "a".repeat(64), "projection_fingerprint": "b".repeat(64)}
	var durable_receipt := {"schema_version": 1.0, "source_fingerprint": "a".repeat(64), "projection_fingerprint": "b".repeat(64)}
	var first := service.apply_with_resumable_run_revocation(ID, "receipt-transaction", &"receipt-run", func(profile: ProfileState) -> String:
		profile.gold += 1
		return ""
	, _root, 2000, "receipt_test", {}, receipt)
	TestAssertions.truthy(first.ok() and not first.duplicate, "mutation with optional receipt commits", failures)
	TestAssertions.equal(first.receipt, durable_receipt, "first result exposes exact durable transaction receipt", failures)
	var escaped := first.receipt
	escaped["schema_version"] = 999
	var duplicate := service.apply_with_resumable_run_revocation(ID, "receipt-transaction", &"receipt-run", func(_profile: ProfileState) -> String:
		return "should not run"
	, _root, 3000, "receipt_test", {}, {})
	TestAssertions.truthy(duplicate.ok() and duplicate.duplicate, "receipt transaction replays", failures)
	TestAssertions.equal(duplicate.receipt, durable_receipt, "duplicate receipt is durable and defensive", failures)
	var saved := store.load_profile(ID, _root).profile
	TestAssertions.equal(saved.applied_transactions["receipt-transaction"].get("receipt", {}), durable_receipt, "receipt is copy-owned by transaction journal", failures)

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
	var first := service.apply(ID, "enemy-42-gold", mutate, _root, 2000, "test_gold", {"amount": 25})
	var intervening := service.grant_gold(ID, "enemy-43-gold", 10, _root)
	var retry := service.apply(ID, "enemy-42-gold", mutate, _root, 9000, "test_gold", {"amount": 25})
	TestAssertions.truthy(first.ok() and not first.duplicate, "first mutation commits", failures)
	TestAssertions.truthy(intervening.ok(), "intervening mutation commits", failures)
	TestAssertions.truthy(retry.ok() and retry.duplicate, "retry reports prior commit", failures)
	TestAssertions.equal(invocations[0], 1, "duplicate transaction does not invoke callback", failures)
	TestAssertions.equal(first.profile.to_dictionary(), retry.profile.to_dictionary(), "retry returns the identical committed profile projection after intervening mutations", failures)
	TestAssertions.truthy(first.profile.applied_transactions.is_empty() and retry.profile.applied_transactions.is_empty(), "mutation results expose journal-free committed projections", failures)
	var saved := store.load_profile(ID, _root).profile
	TestAssertions.equal(saved.gold, 35, "duplicate transaction does not reapply value", failures)
	TestAssertions.equal(retry.profile.gold, 25, "retry returns the original committed profile result", failures)
	TestAssertions.equal(retry.profile.updated_at_unix, 2000, "retry returns the original committed timestamp", failures)
	var transaction: Variant = saved.applied_transactions.get("enemy-42-gold", {})
	TestAssertions.truthy(transaction is Dictionary, "transaction persists as a structured record", failures)
	if transaction is Dictionary:
		TestAssertions.equal(transaction.get("operation"), "test_gold", "transaction records its operation", failures)
		TestAssertions.equal(transaction.get("committed_at_unix"), 2000, "transaction keeps original timestamp", failures)
		TestAssertions.truthy(str(transaction.get("fingerprint", "")).length() == 64, "transaction stores a SHA-256 request fingerprint", failures)
	TestAssertions.equal(saved.applied_transactions.size(), 2, "transaction map grows once per commit", failures)
	(first.profile.tree_allocations["party-forge-city-v1"] as Array).append("shared-stash")
	retry.profile.gold = 999
	var isolated := store.load_profile(ID, _root).profile
	TestAssertions.equal((isolated.tree_allocations["party-forge-city-v1"] as Array).size(), 1, "successful result is a deep copy", failures)
	TestAssertions.equal(isolated.gold, 35, "duplicate result is isolated from persisted state", failures)
	var collision := service.grant_passive_points(ID, "enemy-42-gold", 1, _root)
	TestAssertions.truthy(not collision.ok() and collision.error.contains("transaction id conflict"), "same key with a different operation is rejected", failures)
	var changed_payload := service.grant_gold(ID, "enemy-43-gold", 11, _root)
	TestAssertions.truthy(not changed_payload.ok() and changed_payload.error.contains("transaction id conflict"), "same key with a different payload is rejected", failures)

func _test_commit_timestamp_is_monotonic(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var newer := store.load_profile(ID, _root).profile
	newer.updated_at_unix = 5000
	TestAssertions.equal(store.save_profile(newer, _root), "", "monotonic timestamp fixture saves", failures)
	var committed := ProfileMutationService.new(store).apply(ID, "older-clock", func(profile: ProfileState) -> String:
		profile.gold += 1
		return ""
	, _root, 2000, "test_older_clock", {})
	TestAssertions.truthy(committed.ok(), "mutation with older caller clock commits", failures)
	var saved := store.load_profile(ID, _root).profile
	TestAssertions.equal(saved.gold, 1, "older caller clock still commits value", failures)
	TestAssertions.equal(saved.updated_at_unix, 5000, "committed update time never regresses", failures)
	var record: Variant = saved.applied_transactions.get("older-clock")
	TestAssertions.truthy(record is Dictionary, "monotonic transaction persists as a structured record", failures)
	if record is Dictionary:
		TestAssertions.equal(record.get("committed_at_unix"), saved.updated_at_unix, "transaction records the committed monotonic timestamp", failures)

func _test_protected_metadata_changes_are_rejected(failures: Array[String]) -> void:
	_assert_protected_rejection("protect-schema", "schema_version", func(profile: ProfileState) -> String:
		profile.schema_version += 1
		return ""
	, "", failures)
	_assert_protected_rejection("protect-id", "profile_id", func(profile: ProfileState) -> String:
		profile.profile_id = "profile-redirect1"
		return ""
	, "profile-redirect1", failures)
	_assert_protected_rejection("protect-created", "created_at_unix", func(profile: ProfileState) -> String:
		profile.created_at_unix = 999
		return ""
	, "", failures)
	_assert_protected_rejection("protect-updated", "updated_at_unix", func(profile: ProfileState) -> String:
		profile.updated_at_unix = 9999
		return ""
	, "", failures)
	_assert_protected_rejection("protect-transactions-clear", "applied_transactions", func(profile: ProfileState) -> String:
		profile.applied_transactions.clear()
		return ""
	, "", failures)
	_assert_protected_rejection("protect-transactions-rewrite", "applied_transactions", func(profile: ProfileState) -> String:
		profile.applied_transactions["seed-transaction"] = 9999
		return ""
	, "", failures)
	_assert_protected_rejection("protect-transactions-inject", "applied_transactions", func(profile: ProfileState) -> String:
		profile.applied_transactions["injected"] = {"nested": 1}
		return ""
	, "", failures)

func _test_validation_failure_leaves_state_unchanged(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var before := store.load_profile(ID, _root).profile.to_dictionary()
	var failed := ProfileMutationService.new(store).apply(ID, "invalid-display-name", func(profile: ProfileState) -> String:
		profile.display_name = ""
		return ""
	, _root, 6000, "test_invalid_display_name", {})
	TestAssertions.truthy(not failed.ok() and failed.error.contains("PROFILE_VALIDATION_ERROR"), "normal-field validation failure is surfaced", failures)
	var after := store.load_profile(ID, _root).profile
	TestAssertions.equal(after.to_dictionary(), before, "validation failure leaves persisted dictionary unchanged", failures)
	TestAssertions.truthy(not after.applied_transactions.has("invalid-display-name"), "validation failure records no transaction", failures)

func _test_duplicate_recovered_from_backup_does_not_rewrite(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var committed := ProfileMutationService.new(store).apply(ID, "backup-transaction", func(profile: ProfileState) -> String:
		profile.gold = 10
		return ""
	, _root, 2000, "test_backup_transaction", {"gold": 10})
	TestAssertions.truthy(committed.ok(), "backup duplicate fixture saves prior transaction", failures)
	var backup_generation := store.load_profile(ID, _root).profile
	var newer := backup_generation.copy()
	newer.gold = 20
	newer.updated_at_unix = 3000
	TestAssertions.equal(store.save_profile(newer, _root), "", "backup duplicate fixture creates newer primary", failures)
	var primary_path := store.profile_path(ID, _root)
	var corrupt_bytes := "corrupt newer primary"
	var corrupt := FileAccess.open(primary_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string(corrupt_bytes)
		corrupt.close()
	var invocations := [0]
	var duplicate := ProfileMutationService.new(store).apply(ID, "backup-transaction", func(profile: ProfileState) -> String:
		invocations[0] += 1
		profile.gold += 100
		return ""
	, _root, 9000, "test_backup_transaction", {"gold": 10})
	TestAssertions.truthy(duplicate.ok() and duplicate.duplicate, "backup-recovered prior transaction reports duplicate", failures)
	TestAssertions.equal(invocations[0], 0, "backup-recovered duplicate does not invoke callback", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(primary_path), corrupt_bytes, "backup-recovered duplicate does not rewrite corrupt primary", failures)
	duplicate.profile.gold = 999
	var recovered := store.load_profile(ID, _root)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "duplicate leaves backup recovery path intact", failures)
	TestAssertions.equal(recovered.profile.gold, 10, "backup-recovered duplicate result is isolated", failures)

func _assert_protected_rejection(transaction_id: String, field: String, mutate: Callable, redirected_id: String, failures: Array[String]) -> void:
	ProfileTestSupport.remove_tree(_root)
	var store := ProfileStore.new()
	var fixture := ProfileState.new_profile(ID, "Jacob", 1000)
	fixture.updated_at_unix = 1500
	TestAssertions.equal(store.save_profile(fixture, _root), "", "protected field fixture saves for %s" % field, failures)
	var seeded := ProfileMutationService.new(store).apply(ID, "seed-transaction", func(_profile: ProfileState) -> String: return "", _root, 1500, "test_seed", {})
	TestAssertions.truthy(seeded.ok(), "protected field fixture records a valid seed transaction for %s" % field, failures)
	var before := store.load_profile(ID, _root).profile.to_dictionary()
	var rejected := ProfileMutationService.new(store).apply(ID, transaction_id, mutate, _root, 2000, "test_protected_%s" % field, {})
	TestAssertions.equal(rejected.error, "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=protected field changed field=%s" % [ID, transaction_id, field], "protected field change is rejected for %s" % field, failures)
	var after := store.load_profile(ID, _root).profile
	TestAssertions.equal(after.to_dictionary(), before, "protected field rejection preserves original dictionary for %s" % field, failures)
	TestAssertions.truthy(not after.applied_transactions.has(transaction_id), "protected field rejection records no transaction for %s" % field, failures)
	if not redirected_id.is_empty():
		TestAssertions.truthy(not FileAccess.file_exists(store.profile_path(redirected_id, _root)), "profile id rejection creates no redirected file", failures)

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
	var near_limit_value := JSON_SAFE_INTEGER_MAX - 1023
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
	var exact_limit := after_overflow.copy()
	exact_limit.gold = JSON_SAFE_INTEGER_MAX
	exact_limit.updated_at_unix = 3001
	TestAssertions.equal(store.save_profile(exact_limit, _root), "", "JSON-safe integer limit persists exactly", failures)
	TestAssertions.equal(store.load_profile(ID, _root).profile.gold, JSON_SAFE_INTEGER_MAX, "JSON-safe integer limit reloads exactly", failures)
	var beyond_safe_limit := service.grant_gold(ID, "gold-json-unsafe", 1, _root)
	TestAssertions.truthy(not beyond_safe_limit.ok() and beyond_safe_limit.error.contains("gold amount overflow"), "gold rejects values beyond the JSON-safe integer limit", failures)

func _test_prologue_completion_semantics(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var service := ProfileMutationService.new(store)
	var prologue := service.complete_prologue(ID, "prologue-complete", _root)
	var retry := service.complete_prologue(ID, "prologue-complete", _root)
	TestAssertions.truthy(prologue.ok() and retry.ok() and retry.duplicate, "prologue completion retries by transaction", failures)
	var saved := store.load_profile(ID, _root).profile
	TestAssertions.equal(saved.prologue_state, ProfileState.PrologueState.COMPLETED, "prologue marks complete", failures)
	TestAssertions.equal(saved.passive_points_available, 0, "prologue awards no passive point", failures)
	TestAssertions.equal(saved.passive_points_lifetime_earned, 0, "prologue changes no lifetime point accounting", failures)
	TestAssertions.truthy("city-heart" not in saved.permanent_feature_unlocks, "prologue no longer invents a City-heart feature unlock", failures)
	TestAssertions.truthy("party-forge-city-v1" not in saved.discovered_trees, "prologue no longer reveals City", failures)
	TestAssertions.equal(saved.tree_allocations.get("party-forge-city-v1", []), [], "prologue no longer seeds the City root", failures)
	TestAssertions.equal(retry.profile.tree_allocations.get("party-forge-city-v1", []), [], "prologue retry preserves the no-reward result", failures)
	var different_transaction := service.complete_prologue(ID, "prologue-complete-again", _root)
	TestAssertions.truthy(not different_transaction.ok() and different_transaction.error.contains("prologue already completed with different transaction"), "completed state rejects a different transaction", failures)
	var unchanged := store.load_profile(ID, _root).profile
	TestAssertions.equal(unchanged.to_dictionary(), saved.to_dictionary(), "state-level prologue rejection changes nothing", failures)

func _test_prologue_canonicalizes_existing_projection(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var profile := store.load_profile(ID, _root).profile
	profile.permanent_feature_unlocks = ["zeta-unlock", "city-heart", "zeta-unlock"]
	profile.discovered_trees = ["zeta-tree", "party-forge-city-v1", "zeta-tree"]
	profile.tree_allocations["party-forge-city-v1"] = ["legacy-node", "city-heart", "legacy-node"]
	TestAssertions.equal(store.save_profile(profile, _root), "", "prologue canonicalization fixture saves", failures)
	var completed := ProfileMutationService.new(store).complete_prologue(ID, "canonical-prologue", _root)
	var saved := store.load_profile(ID, _root).profile
	TestAssertions.truthy(completed.ok(), "prologue completes with existing compatible projections", failures)
	TestAssertions.equal(saved.permanent_feature_unlocks, ["zeta-unlock", "city-heart", "zeta-unlock"], "prologue preserves existing feature projections byte-for-byte in value order", failures)
	TestAssertions.equal(saved.discovered_trees, ["zeta-tree", "party-forge-city-v1", "zeta-tree"], "prologue preserves existing tree discovery order and duplicates", failures)
	TestAssertions.equal(saved.tree_allocations["party-forge-city-v1"], ["legacy-node", "city-heart", "legacy-node"], "prologue preserves the existing City allocation projection", failures)

func _test_historical_prologue_duplicate_preserves_result(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var historical := ProfileState.new_profile(ID, "Jacob", 1000)
	historical.updated_at_unix = 2000
	historical.prologue_state = ProfileState.PrologueState.COMPLETED
	historical.passive_points_available = 1
	historical.passive_points_lifetime_earned = 1
	historical.permanent_feature_unlocks = ["city-heart"]
	historical.discovered_trees = ["party-forge-city-v1"]
	var historical_result := historical.to_dictionary()
	historical.applied_transactions["historical-prologue"] = {
		"operation": "complete_prologue",
		"fingerprint": ("complete_prologue\n{}" as String).sha256_text(),
		"committed_at_unix": 2000,
		"result_profile": historical_result,
	}
	TestAssertions.equal(store.save_profile(historical, _root), "", "historical prologue transaction fixture saves", failures)
	var before := store.load_profile(ID, _root).profile.to_dictionary()
	var replay := ProfileMutationService.new(store).complete_prologue(ID, "historical-prologue", _root)
	TestAssertions.truthy(replay.ok() and replay.duplicate, "historical prologue transaction replays as a duplicate", failures)
	TestAssertions.truthy(not replay.profile.tree_allocations.has("party-forge-city-v1"), "historical result keeps its pre-explicit-root schema", failures)
	var after := store.load_profile(ID, _root).profile.to_dictionary()
	TestAssertions.equal(after, before, "historical duplicate does not rewrite the stored profile or result snapshot", failures)

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
	var missing_operation := service.apply(ID, "missing-operation", func(_profile: ProfileState) -> String: return "", _root, 4000)
	TestAssertions.truthy(not missing_operation.ok() and missing_operation.error.contains("operation is required"), "generic mutation requires an explicit operation descriptor", failures)
	var unsafe_request := service.apply(ID, "unsafe-request", func(_profile: ProfileState) -> String: return "", _root, 4000, "test_unsafe_request", {"amount": 9007199254740992})
	TestAssertions.truthy(not unsafe_request.ok() and unsafe_request.error.contains("invalid request") and unsafe_request.error.contains("JSON-safe integer"), "request fingerprints reject unsafe integer payloads", failures)
	var missing_callback := service.apply(ID, "missing-callback", Callable(), _root, 4000)
	TestAssertions.truthy(not missing_callback.ok() and missing_callback.error.contains("mutation is missing"), "invalid callable is rejected", failures)
	var callback_error := service.apply(ID, "callback-error", func(profile: ProfileState) -> String:
		profile.gold = 500
		return "PROFILE_MUTATION_ERROR reason=fixture callback failed"
	, _root, 4001, "test_callback_error", {})
	TestAssertions.equal(callback_error.error, "PROFILE_MUTATION_ERROR reason=fixture callback failed", "callback error is surfaced unchanged", failures)
	var invalid_return := service.apply(ID, "invalid-return", func(profile: ProfileState) -> Variant:
		profile.gold = 600
		return 123
	, _root, 4002, "test_invalid_return", {})
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
	, _root, 5000, "test_failed_save", {})
	TestAssertions.truthy(not failed.ok() and failed.error.contains("JSON_STORE_SAVE_ERROR") and failed.error.contains("stage=promote"), "failed atomic save reports stable persistence diagnostics", failures)
	var after := good.load_profile(ID, _root)
	TestAssertions.truthy(after.ok(), "prior persisted state remains readable after failed save", failures)
	TestAssertions.equal(after.profile.to_dictionary(), before.to_dictionary(), "failed save retains values timestamps and transactions", failures)
	TestAssertions.truthy(not after.profile.applied_transactions.has("failed-save"), "failed save does not leave an idempotency record", failures)

func _test_post_commit_cleanup_is_successful_to_caller(failures: Array[String]) -> void:
	var documents := CleanupFailingAtomicJsonStore.new()
	var store := ProfileStore.new(documents)
	var first := store.load_profile(ID, _root).profile
	first.updated_at_unix = 1100
	TestAssertions.equal(store.save_profile(first, _root), "", "mutation cleanup fixture creates backup", failures)
	documents.failure_path = "%s.bak.previous" % store.profile_path(ID, _root)
	var committed := ProfileMutationService.new(store).grant_gold(ID, "cleanup-commit", 5, _root)
	TestAssertions.truthy(committed.ok(), "verified mutation remains successful when only post-commit cleanup fails", failures)
	var saved := store.load_profile(ID, _root).profile
	TestAssertions.equal(saved.gold, 5, "post-commit cleanup failure retains mutation value", failures)
	TestAssertions.truthy(saved.applied_transactions.has("cleanup-commit"), "post-commit cleanup failure retains idempotency record", failures)

func _reset_profile(failures: Array[String]) -> void:
	ProfileTestSupport.remove_tree(_root)
	_test_fixture_save(ProfileStore.new(), failures)

func _test_fixture_save(store: ProfileStore, failures: Array[String]) -> void:
	TestAssertions.equal(store.save_profile(ProfileState.new_profile(ID, "Jacob", 1000), _root), "", "profile mutation fixture saves", failures)
