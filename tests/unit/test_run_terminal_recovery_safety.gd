extends RefCounted

const REQUIRED_PATHS: PackedStringArray = [
	"res://scripts/run/run_terminal_recovery_record.gd",
	"res://scripts/run/run_terminal_recovery_record_result.gd",
	"res://scripts/run/run_terminal_recovery_codec.gd",
	"res://scripts/run/run_terminal_recovery_service.gd",
	"res://scripts/run/run_terminal_recovery_safety_result.gd",
]

const PROFILE_ID := "profile-terminal-safety"
const RUN_ID := &"run-terminal-safety"
const RUN_PLAYER_ID := &"terminal-safety-player"
const RUN_SEED := 9917
const ITEM_ID := "item-terminal-safety"
const ITEM_ID_SECOND := "item-terminal-safety-second"

class PostCommitSanitationFailingStore extends AtomicJsonStore:
	func _cleanup_paths(_paths: Array[String]) -> Error:
		return ERR_CANT_CREATE

	func _sanitize_remaining_artifacts(_paths: Array[String], _contents: String, _validator: Callable, _expected_canonical: String) -> Error:
		return ERR_CANT_CREATE

class TerminalPrecommitFailStore extends AtomicJsonStore:
	var failure_path := ""

	func _remove(path: String) -> Error:
		if path == failure_path:
			return ERR_CANT_CREATE
		return super._remove(path)

	func _write_text(path: String, contents: String) -> Error:
		if path == failure_path:
			return ERR_CANT_CREATE
		return super._write_text(path, contents)

class CompletionInterleavingMutationService extends ProfileMutationService:
	var test_store: ProfileStore
	var drift_profile: ProfileState
	var injected_bytes := PackedByteArray()

	func _init(store_value: ProfileStore, drift_value: ProfileState) -> void:
		test_store = store_value
		drift_profile = drift_value
		super(store_value)

	func apply_irreversible_terminal_completion(
		profile_id: String,
		transaction_id: String,
		terminal_run_id: StringName,
		terminal_instance_ids: Array[String],
		mutate: Callable,
		root: String = ProfileStore.DEFAULT_ROOT,
		now_unix: int = -1,
		operation: String = "",
		request: Dictionary = {},
	) -> ProfileMutationResult:
		var injected_error := test_store.save_profile(drift_profile, root)
		if not injected_error.is_empty():
			var failure := ProfileMutationResult.new()
			failure.error = injected_error
			return failure
		injected_bytes = FileAccess.get_file_as_bytes(test_store.profile_path(profile_id, root))
		return super.apply_irreversible_terminal_completion(
			profile_id, transaction_id, terminal_run_id, terminal_instance_ids,
			mutate, root, now_unix, operation, request,
		)

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_schema_six_defaults_are_copy_owned(failures)
	_test_terminal_codec_fails_closed(failures)
	_test_valid_typed_record_roundtrips(failures)
	_test_recursive_v5_migration_and_strict_v6_fields(failures)
	_test_populated_overflow_storage_and_projection_behavior(failures)
	_test_terminal_persistence_and_typed_safety(failures)
	_test_terminal_persistence_canonicalizes_high_precision_live_source(failures)
	_test_pre_resolution_safety_direct_full_matrix(failures)
	_test_terminal_completion_service_contract(failures)
	_test_completion_revalidates_complete_resolved_transaction(failures)
	_test_completion_revalidates_inside_mutation_callback(failures)
	_test_completion_rejects_missing_or_mismatched_applied_resolution(failures)
	_test_completion_rejects_coordinated_noncanonical_selection_permutation(failures)
	_test_terminal_completion_invalid_and_storage_failures(failures)
	_test_resolved_terminal_safety_one_field_matrix(failures)
	_test_protect_displaced_gear_is_automatic_only_atomic_and_idempotent(failures)
	_test_protect_displaced_gear_failure_matrix(failures)
	_test_irreversible_terminal_completion_sanitizes_every_generation(failures)
	return failures

func _test_schema_six_defaults_are_copy_owned(failures: Array[String]) -> void:
	var profile := ProfileState.new_profile("profile-terminal-safety", "Terminal Safety", 1000)
	TestAssertions.equal(ProfileState.SCHEMA_VERSION, 6, "terminal durability promotes profile schema to six", failures)
	TestAssertions.equal(profile.get("terminal_resolution"), {}, "new profile has no terminal receipt", failures)
	TestAssertions.equal(profile.get("terminal_recovery_overflow"), ItemSlotContainer.create(
		&"terminal-recovery-overflow", &"profile_terminal_recovery_overflow",
		profile.profile_id, EquipmentSlotIndex.capacity(),
	).to_dictionary(), "new profile owns the exact empty recovery overflow", failures)
	var encoded := profile.to_dictionary()
	if encoded.get("terminal_resolution") is Dictionary:
		(encoded["terminal_resolution"] as Dictionary)["escaped"] = true
	if encoded.get("terminal_recovery_overflow") is Dictionary:
		(encoded["terminal_recovery_overflow"] as Dictionary)["slots"] = {0: "escaped"}
	TestAssertions.equal(profile.get("terminal_resolution"), {}, "terminal receipt dictionary is defensive", failures)
	var overflow: Variant = profile.get("terminal_recovery_overflow")
	TestAssertions.equal((overflow as Dictionary).get("slots") if overflow is Dictionary else null, {}, "overflow document is defensive", failures)

func _test_terminal_codec_fails_closed(failures: Array[String]) -> void:
	var path := "res://scripts/run/run_terminal_recovery_codec.gd"
	if not ResourceLoader.exists(path):
		return
	var codec := load(path) as Script
	if codec == null:
		return
	for malformed: Dictionary in [{}, {"schema_version": 1}, {"schema_version": 99, "unexpected": true}]:
		var decoded: Variant = codec.call(&"decode", malformed)
		TestAssertions.truthy(decoded != null and not bool(decoded.call(&"ok")), "terminal recovery codec rejects malformed exact-field document", failures)
	var fixture := _fixture(false)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 3.0, fixture.context).snapshot
	var empty_ids: Array[String] = []
	var valid: Variant = RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION, snapshot, empty_ids, "", empty_ids, "", null, "",
	)
	TestAssertions.truthy(_ok(valid), "strict codec fixture begins as a valid choosing record", failures)
	if _ok(valid):
		var base := valid.get("record").call(&"to_dictionary") as Dictionary
		var unknown := base.duplicate(true)
		unknown["single_unknown_field"] = true
		var unknown_result: Variant = codec.call(&"decode", unknown)
		TestAssertions.truthy(not _ok(unknown_result) and String(unknown_result.get("error")).contains("single_unknown_field"), "one unknown field fails closed readably", failures)
		for test_case: Dictionary in [
			{"label": "choosing reason", "stage": RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION, "selection": [], "transaction": "", "reason": "not interrupted"},
			{"label": "selection without transaction", "stage": RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION, "selection": [ITEM_ID], "transaction": "", "reason": ""},
			{"label": "interrupted without transaction", "stage": RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, "selection": [ITEM_ID], "transaction": "", "reason": "write failed"},
			{"label": "interrupted without reason", "stage": RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, "selection": [ITEM_ID], "transaction": "terminal-selection", "reason": ""},
		]:
			var malformed_stage := base.duplicate(true)
			malformed_stage["stage"] = test_case.stage
			malformed_stage["selected_item_ids"] = (test_case.selection as Array).duplicate()
			malformed_stage["transaction_id"] = test_case.transaction
			malformed_stage["interruption_reason"] = test_case.reason
			TestAssertions.truthy(not _ok(codec.call(&"decode", malformed_stage)), "%s stage/field combination fails closed" % test_case.label, failures)
	_free_fixture(fixture, "")

func _test_recursive_v5_migration_and_strict_v6_fields(failures: Array[String]) -> void:
	var v5 := ProfileState.new_profile("profile-terminal-migrate", "Migrate", 1000).to_dictionary()
	v5["schema_version"] = 5
	v5.erase("terminal_resolution")
	v5.erase("terminal_recovery_overflow")
	var nested := v5.duplicate(true)
	nested["applied_transactions"] = {}
	var second_snapshot := nested.duplicate(true)
	second_snapshot["updated_at_unix"] = 1001
	v5["applied_transactions"] = {"legacy-v5": {
		"operation": "legacy", "fingerprint": "a".repeat(64), "committed_at_unix": 1000,
		"result_profile": nested,
	}, "legacy-v5-two": {
		"operation": "legacy-two", "fingerprint": "b".repeat(64), "committed_at_unix": 1001,
		"result_profile": second_snapshot,
	}}
	var migrated := ProfileMigrator.migrate_document(v5)
	TestAssertions.truthy(migrated.ok(), "v5 profile migrates every root transaction result snapshot", failures)
	if migrated.ok():
		var document := migrated.profile.to_dictionary()
		for transaction_id: String in ["legacy-v5", "legacy-v5-two"]:
			var result_profile := document["applied_transactions"][transaction_id]["result_profile"] as Dictionary
			TestAssertions.equal(result_profile.get("schema_version"), 6, "%s v5 result snapshot migrates to v6" % transaction_id, failures)
			TestAssertions.equal(result_profile.get("terminal_resolution"), {}, "%s migration invents no receipt" % transaction_id, failures)
			TestAssertions.equal((result_profile.get("terminal_recovery_overflow") as Dictionary).get("slots"), {}, "%s migration invents no overflow contents" % transaction_id, failures)
			TestAssertions.equal(result_profile.get("applied_transactions"), {}, "%s result snapshot remains journal-free" % transaction_id, failures)
	var malformed := ProfileState.new_profile("profile-terminal-strict", "Strict", 1000).to_dictionary()
	malformed["terminal_resolution"] = {"schema_version": 1, "unexpected": true}
	TestAssertions.truthy(not ProfileCodec.decode_document(malformed).ok(), "v6 malformed terminal record fails closed", failures)
	malformed = ProfileState.new_profile("profile-terminal-strict", "Strict", 1000).to_dictionary()
	(malformed["terminal_recovery_overflow"] as Dictionary)["container_kind"] = "profile_stash_tab"
	TestAssertions.truthy(not ProfileCodec.decode_document(malformed).ok(), "v6 overflow cannot masquerade as ordinary stash", failures)

func _test_valid_typed_record_roundtrips(failures: Array[String]) -> void:
	var fixture := _fixture(false)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 72.5, fixture.context).snapshot
	var record_script := load("res://scripts/run/run_terminal_recovery_record.gd") as Script
	var codec := load("res://scripts/run/run_terminal_recovery_codec.gd") as Script
	var empty_ids: Array[String] = []
	var pre: Variant = record_script.call(&"create", 0, snapshot, empty_ids, "", empty_ids, "", null, "")
	TestAssertions.truthy(_ok(pre), "valid pre-resolution record constructs through the typed codec", failures)
	if _ok(pre):
		var decoded: Variant = codec.call(&"decode", pre.get("record").call(&"to_dictionary"))
		TestAssertions.truthy(_ok(decoded), "valid pre-resolution record roundtrips", failures)
		TestAssertions.equal(decoded.get("record").call(&"to_dictionary"), pre.get("record").call(&"to_dictionary"), "pre-resolution roundtrip preserves exact typed truth", failures)
	var selection := ExtractionSelection.create(ITEM_ID, &"run-inventory", 0)
	var automatic_ids: Array[String] = []
	var eligible: Array[ExtractionSelection] = [selection]
	var selected_ids: Array[String] = [ITEM_ID]
	var lost_ids: Array[String] = []
	var errors: Array[String] = []
	var accepted := RunExtractionProjection.create(automatic_ids, eligible, selected_ids, lost_ids, 1, errors)
	var transaction := "terminal-resolution:%s:%s" % [RUN_ID, JSON.stringify([selection.to_dictionary()]).sha256_text()]
	var resolved: Variant = record_script.call(&"create", 2, snapshot, selected_ids, transaction, empty_ids, "", accepted, transaction)
	TestAssertions.truthy(_ok(resolved), "valid resolved record constructs from accepted extraction", failures)
	if _ok(resolved):
		var resolved_decoded: Variant = codec.call(&"decode", resolved.get("record").call(&"to_dictionary"))
		TestAssertions.truthy(_ok(resolved_decoded), "valid resolved record roundtrips", failures)
		TestAssertions.equal(resolved_decoded.get("record").call(&"to_dictionary"), resolved.get("record").call(&"to_dictionary"), "resolved roundtrip preserves exact accepted transaction", failures)
	_free_fixture(fixture, "")

func _test_populated_overflow_storage_and_projection_behavior(failures: Array[String]) -> void:
	var fixture := _fixture(false)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 12.0, fixture.context).snapshot
	var root := _case_root("overflow_drain")
	var profile := _overflow_profile(snapshot, false)
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(profile, root), "", "populated overflow fixture saves as unique profile ownership", failures)
	var service := ProfileItemStorageService.new(ProfileMutationService.new(store))
	var move := ItemTransactionRequest.move("overflow-drain", PROFILE_ID, ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 0, ITEM_ID, &"stash-tab-terminal", 3)
	var moved := service.apply(PROFILE_ID, move, root)
	TestAssertions.truthy(moved.ok(), "an older overflow item drains to an empty ordinary stash slot", failures)
	if moved.ok():
		var saved := store.load_profile(PROFILE_ID, root).profile
		TestAssertions.equal(saved.terminal_recovery_overflow["slots"], {}, "overflow drain clears only the exact source slot", failures)
		TestAssertions.equal(saved.stash_tabs[0]["slots"], {"3": ITEM_ID}, "overflow drain preserves exact item identity in ordinary stash", failures)
		TestAssertions.equal((saved.item_records["items"] as Array).size(), 1, "overflow drain preserves the item registry", failures)
	ProfileTestSupport.remove_tree(root)

	var occupied_root := _case_root("overflow_occupied_target")
	var occupied := _overflow_profile(snapshot, false)
	var blocker := _profile_item("item-overflow-stash-blocker", 1)
	occupied.item_records = ItemRegistry.new([_profile_item(ITEM_ID, 0), blocker]).to_dictionary()
	occupied.stash_tabs[0]["slots"] = {"3": blocker.instance_id}
	TestAssertions.equal(store.save_profile(occupied, occupied_root), "", "occupied overflow target fixture saves", failures)
	var occupied_hash := FileAccess.get_sha256(store.profile_path(PROFILE_ID, occupied_root))
	var occupied_move := service.apply(PROFILE_ID, ItemTransactionRequest.move("overflow-occupied", PROFILE_ID, ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 0, ITEM_ID, &"stash-tab-terminal", 3), occupied_root)
	TestAssertions.truthy(not occupied_move.ok() and occupied_move.error.to_lower().contains("empty"), "older overflow item rejects a nonempty ordinary stash target readably", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, occupied_root)), occupied_hash, "occupied-target rejection is write-free", failures)
	ProfileTestSupport.remove_tree(occupied_root)

	var protected_root := _case_root("overflow_protected")
	var protected_profile := _overflow_profile(snapshot, true)
	TestAssertions.equal(store.save_profile(protected_profile, protected_root), "", "protected overflow fixture saves", failures)
	var protected_hash := FileAccess.get_sha256(store.profile_path(PROFILE_ID, protected_root))
	var locked := service.apply(PROFILE_ID, ItemTransactionRequest.move("overflow-locked", PROFILE_ID, ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 0, ITEM_ID, &"stash-tab-terminal", 3), protected_root)
	TestAssertions.truthy(not locked.ok() and locked.error.contains("Available after terminal resolution"), "current-record protected item stays locked with the exact readable reason", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, protected_root)), protected_hash, "protected overflow rejection is write-free", failures)
	for rejected_request: ItemTransactionRequest in [
		ItemTransactionRequest.create("overflow-create", PROFILE_ID, ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 1, _profile_item("item-overflow-create", 1)),
		ItemTransactionRequest.swap("overflow-swap", PROFILE_ID, ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 0, ITEM_ID, &"stash-tab-terminal", 0),
		ItemTransactionRequest.move("overflow-leader", PROFILE_ID, ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 0, ITEM_ID, &"leader-loadout", 0),
		ItemTransactionRequest.move("overflow-destination", PROFILE_ID, &"stash-tab-terminal", 0, "", ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 1),
	]:
		var rejected := service.apply(PROFILE_ID, rejected_request, protected_root)
		TestAssertions.truthy(not rejected.ok(), "overflow rejects create, swap, leader, and destination misuse", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, protected_root)), protected_hash, "all overflow misuse preserves exact profile bytes", failures)
	var projection := ProfileStorageProjection.from_profile(protected_profile, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, null)
	TestAssertions.truthy(projection.valid, "storage projection decodes populated overflow ownership", failures)
	var overflow_projection: Variant = projection.get("terminal_recovery_overflow")
	TestAssertions.equal((overflow_projection as Dictionary).get("slots") if overflow_projection is Dictionary else null, {"0": ITEM_ID}, "storage projection exposes populated overflow separately", failures)
	TestAssertions.truthy(projection.stash_tabs.all(func(tab: Dictionary) -> bool: return String(tab["container_id"]) != String(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID)), "overflow is excluded from ordinary stash destination tabs", failures)
	var duplicate_owner := protected_profile.to_dictionary()
	(duplicate_owner["stash_tabs"] as Array)[0]["slots"] = {"0": ITEM_ID}
	var duplicate_decoded := ProfileCodec.decode_document(duplicate_owner)
	TestAssertions.truthy(not duplicate_decoded.ok() and duplicate_decoded.error.to_lower().contains("owned"), "schema-6 codec rejects one item owned by stash and recovery overflow", failures)
	ProfileTestSupport.remove_tree(protected_root)
	_free_fixture(fixture, "")

func _test_terminal_persistence_and_typed_safety(failures: Array[String]) -> void:
	if not ResourceLoader.exists("res://scripts/run/run_terminal_recovery_service.gd"):
		failures.append("terminal persistence and safety behaviors are blocked solely because run_terminal_recovery_service.gd is missing")
		return
	var recovery_script := load("res://scripts/run/run_terminal_recovery_service.gd") as Script
	var fixture := _fixture(true)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 44.0, fixture.context).snapshot
	var root := _case_root("persist_initial")
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(fixture.profile, root), "", "terminal persistence fixture saves older strict bootstrap", failures)
	var service: Variant = recovery_script.new(ProfileMutationService.new(store), store)
	var persisted: Variant = service.call(&"persist_initial", PROFILE_ID, snapshot, root)
	TestAssertions.truthy(_ok(persisted), "initial terminal persistence atomically checkpoints newer valid live item state", failures)
	var durable := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.equal(durable.resumable_run.get("item_state"), snapshot.resolution_source.item_state.to_dictionary(), "terminal capture replaces only strict bootstrap item state with captured source truth", failures)
	TestAssertions.truthy(not durable.terminal_resolution.is_empty(), "terminal capture commits the recovery record in the same write", failures)
	var altered_cases: Array[Dictionary] = [
		{"label": "seed", "kind": "seed"},
		{"label": "player", "kind": "player"},
		{"label": "leader", "kind": "leader"},
		{"label": "source", "kind": "source"},
	]
	var retry_executed := 0
	for test_case: Dictionary in altered_cases:
		var changed_document := snapshot.to_dictionary()
		match String(test_case.kind):
			"seed":
				changed_document["run_seed"] = snapshot.run_seed + 1
				(changed_document["resolution_source"] as Dictionary)["run_seed"] = snapshot.run_seed + 1
			"player":
				changed_document["run_player_id"] = "terminal-safety-player-other"
				var source_document := changed_document["resolution_source"] as Dictionary
				source_document["run_player_id"] = "terminal-safety-player-other"
				var item_state := source_document["item_state"] as Dictionary
				item_state["owner_id"] = "terminal-safety-player-other"
				for container: Dictionary in item_state["containers"]:
					container["owner_id"] = "terminal-safety-player-other"
			"leader":
				changed_document["leader_member_id"] = 2
				(changed_document["members"] as Array)[0]["member_id"] = 2
				var source_document := changed_document["resolution_source"] as Dictionary
				source_document["leader_member_id"] = 2
				(source_document["party_members"] as Array)[0]["member_id"] = 2
			"source":
				(changed_document["resolution_source"]["item_state"]["registry"]["items"] as Array)[0]["item_level"] = 21
		var changed := RunTerminalSnapshot.from_dictionary(changed_document)
		TestAssertions.truthy(changed.ok(), "%s retry snapshot remains typed and valid: %s" % [test_case.label, changed.error], failures)
		if not changed.ok():
			continue
		var before_bytes := FileAccess.get_file_as_bytes(store.profile_path(PROFILE_ID, root))
		var rejected: Variant = service.call(&"persist_initial", PROFILE_ID, changed.snapshot, root)
		TestAssertions.truthy(not _ok(rejected), "committed terminal capture rejects changed %s input" % test_case.label, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(store.profile_path(PROFILE_ID, root)), before_bytes, "changed %s capture retry is write-free" % test_case.label, failures)
		retry_executed += 1
	TestAssertions.equal(retry_executed, altered_cases.size(), "every changed terminal-capture retry executes", failures)

	var capture_transaction := "terminal-capture:%s" % snapshot.run_id
	var stale_result_profile := store.load_profile(PROFILE_ID, root).profile
	(stale_result_profile.applied_transactions[capture_transaction]["result_profile"] as Dictionary)["terminal_resolution"] = {}
	TestAssertions.equal(ProfileCodec.validate_profile(stale_result_profile), "", "stale committed capture result fixture remains structurally valid", failures)
	TestAssertions.equal(store.save_profile(stale_result_profile, root), "", "stale committed capture result fixture saves", failures)
	var stale_result_bytes := FileAccess.get_file_as_bytes(store.profile_path(PROFILE_ID, root))
	var stale_result_retry: Variant = service.call(&"persist_initial", PROFILE_ID, snapshot, root)
	TestAssertions.truthy(not _ok(stale_result_retry), "committed terminal capture validates returned durable truth against the supplied snapshot", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(store.profile_path(PROFILE_ID, root)), stale_result_bytes, "stale committed capture result rejection is write-free", failures)
	ProfileTestSupport.remove_tree(root)

	var mismatch_root := _case_root("persist_identity")
	var mismatched: ProfileState = fixture.profile.copy()
	mismatched.resumable_run["run_id"] = "run-other"
	TestAssertions.equal(store.save_profile(mismatched, mismatch_root), "", "stale identity fixture saves", failures)
	var mismatch_hash := FileAccess.get_sha256(store.profile_path(PROFILE_ID, mismatch_root))
	TestAssertions.truthy(not _ok(service.call(&"persist_initial", PROFILE_ID, snapshot, mismatch_root)), "stale run identity rejects terminal capture", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, mismatch_root)), mismatch_hash, "stale run identity rejection is write-free", failures)
	ProfileTestSupport.remove_tree(mismatch_root)

	var failure_root := _case_root("persist_failure")
	TestAssertions.equal(store.save_profile(fixture.profile, failure_root), "", "save failure fixture saves", failures)
	var failure_hash := FileAccess.get_sha256(store.profile_path(PROFILE_ID, failure_root))
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var failing: Variant = recovery_script.new(ProfileMutationService.new(failing_store), failing_store)
	TestAssertions.truthy(not _ok(failing.call(&"persist_initial", PROFILE_ID, snapshot, failure_root)), "injected save failure rejects terminal capture", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, failure_root)), failure_hash, "injected save failure exposes neither checkpoint nor record", failures)
	TestAssertions.equal(store.load_profile(PROFILE_ID, failure_root).profile.terminal_resolution, {}, "injected save failure leaves receipt empty", failures)
	ProfileTestSupport.remove_tree(failure_root)
	_free_fixture(fixture, "")

func _test_terminal_persistence_canonicalizes_high_precision_live_source(failures: Array[String]) -> void:
	var fixture := _fixture(true)
	fixture.context._item_state = _run_state_high_precision()
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 44.5, fixture.context).snapshot
	var root := _case_root("persist_high_precision")
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(fixture.profile, root), "", "high-precision terminal fixture saves older strict bootstrap", failures)
	var service := RunTerminalRecoveryService.new(ProfileMutationService.new(store), store)
	var persisted := service.persist_initial(PROFILE_ID, snapshot, root)
	TestAssertions.truthy(persisted.ok(), "high-precision live affix persists through the canonical durable boundary: %s" % persisted.error, failures)
	if persisted.ok():
		var durable := store.load_profile(PROFILE_ID, root).profile
		var inspected := service.inspect(durable)
		TestAssertions.truthy(inspected.ok(), "canonical high-precision receipt resumes exactly", failures)
		if inspected.ok():
			TestAssertions.equal(durable.resumable_run["item_state"], inspected.record.snapshot.resolution_source.item_state.to_dictionary(), "durable bootstrap and terminal source retain exact canonical identity", failures)
			var drift_document := inspected.record.snapshot.to_dictionary()
			(drift_document["resolution_source"]["item_state"]["registry"]["items"][0]["affixes"][0]["rolls"][0] as Dictionary)["value"] = 9.41167032718658
			var drift := RunTerminalSnapshot.from_dictionary(drift_document)
			TestAssertions.truthy(drift.ok() and not service.persist_initial(PROFILE_ID, drift.snapshot, root).ok(), "genuine canonical affix drift still rejects duplicate terminal capture", failures)
	ProfileTestSupport.remove_tree(root)
	_free_fixture(fixture, "")

func _test_pre_resolution_safety_direct_full_matrix(failures: Array[String]) -> void:
	var fixture := _fixture(true)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 45.0, fixture.context).snapshot
	var profile: ProfileState = (fixture.profile as ProfileState).copy()
	profile.resumable_run["item_state"] = snapshot.resolution_source.item_state.to_dictionary()
	var empty_ids: Array[String] = []
	profile.terminal_resolution = RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION,
		snapshot, empty_ids, "", empty_ids, "", null, "",
	).record.to_dictionary()
	TestAssertions.equal(ProfileCodec.validate_profile(profile), "", "direct pre-resolution safety fixture is structurally durable", failures)
	var recovery := RunRecoveryService.new()
	var before_profile := profile.to_dictionary()
	var before_snapshot := snapshot.to_dictionary()
	var exact := recovery.verify_terminal_safety(profile, snapshot)
	TestAssertions.truthy(exact.ok(), "direct exact pre-resolution receipt and strict bootstrap pass safety", failures)
	TestAssertions.equal(profile.to_dictionary(), before_profile, "direct pre-resolution safety preserves profile input", failures)
	TestAssertions.equal(snapshot.to_dictionary(), before_snapshot, "direct pre-resolution safety preserves snapshot input", failures)
	var canonical_projection := RunExtractionPolicy.project_source(snapshot.resolution_source, profile, [])
	var surviving_documents: Array[Dictionary] = []
	for selection: ExtractionSelection in canonical_projection.eligible_items:
		if selection.item_id == ITEM_ID:
			surviving_documents.append(selection.to_dictionary())
	var stale_ids: Array[String] = [ITEM_ID, "item-stale-terminal-selection"]
	var stale_transaction := "terminal-resolution:%s:%s" % [snapshot.run_id, JSON.stringify(surviving_documents).sha256_text()]
	var stale_record := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION,
		snapshot, stale_ids, stale_transaction, empty_ids, "", null, "",
	)
	var stale_profile := profile.copy()
	stale_profile.terminal_resolution = stale_record.record.to_dictionary() if stale_record.ok() else {}
	TestAssertions.truthy(stale_record.ok() and ProfileCodec.validate_profile(stale_profile).is_empty(), "stale-selection safety fixture remains structurally valid", failures)
	var stale_safety := recovery.verify_terminal_safety(stale_profile, snapshot)
	TestAssertions.truthy(not stale_safety.ok(), "pre-resolution safety rejects a stale selected ID even when the transaction digest is recomputed over the surviving canonical subset", failures)
	var cases: Array[Dictionary] = [
		{"label": "profile", "target": "record", "path": ["snapshot", "profile_id"], "value": "profile-other"},
		{"label": "outcome", "target": "record", "path": ["snapshot", "outcome"], "value": RunTerminalSnapshot.Outcome.DEFEAT},
		{"label": "run", "target": "record", "path": ["snapshot", "run_id"], "value": "run-other"},
		{"label": "seed", "target": "record", "path": ["snapshot", "run_seed"], "value": RUN_SEED + 1},
		{"label": "player", "target": "record", "path": ["snapshot", "run_player_id"], "value": "player-other"},
		{"label": "leader", "target": "record", "path": ["snapshot", "leader_member_id"], "value": 2},
		{"label": "member", "target": "record", "path": ["snapshot", "members", 0, "class_id"], "value": "mage"},
		{"label": "source member", "target": "record", "path": ["snapshot", "resolution_source", "party_members", 0, "class_id"], "value": "mage"},
		{"label": "source item record", "target": "record", "path": ["snapshot", "resolution_source", "item_state", "registry", "items", 0, "item_level"], "value": 21},
		{"label": "source container", "target": "record", "path": ["snapshot", "resolution_source", "item_state", "containers", 2, "container_id"], "value": "run-inventory-other"},
		{"label": "source slot", "target": "record", "path": ["snapshot", "resolution_source", "item_state", "containers", 2, "slots"], "value": {"1": ITEM_ID}},
		{"label": "selection", "target": "record", "path": ["selected_item_ids"], "value": [ITEM_ID]},
		{"label": "transaction", "target": "record", "path": ["transaction_id"], "value": "terminal-selection-other"},
		{"label": "stage", "target": "record", "path": ["stage"], "value": RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED},
		{"label": "bootstrap run", "target": "bootstrap", "path": ["run_id"], "value": "run-other"},
		{"label": "bootstrap seed", "target": "bootstrap", "path": ["run_seed"], "value": RUN_SEED + 1},
		{"label": "bootstrap player", "target": "bootstrap", "path": ["run_player_id"], "value": "player-other"},
		{"label": "bootstrap leader", "target": "bootstrap", "path": ["leader_member_id"], "value": 2},
		{"label": "bootstrap item record", "target": "bootstrap", "path": ["item_state", "registry", "items", 0, "item_level"], "value": 21},
		{"label": "bootstrap container", "target": "bootstrap", "path": ["item_state", "containers", 2, "container_id"], "value": "run-inventory-other"},
		{"label": "bootstrap slot", "target": "bootstrap", "path": ["item_state", "containers", 2, "slots"], "value": {"1": ITEM_ID}},
	]
	var executed := 0
	for test_case: Dictionary in cases:
		var changed := profile.copy()
		if test_case.target == "record":
			_set_nested_variant(changed.terminal_resolution, test_case.path, test_case.value)
		else:
			_set_nested_variant(changed.resumable_run, test_case.path, test_case.value)
		var unsafe := recovery.verify_terminal_safety(changed, snapshot)
		TestAssertions.truthy(not unsafe.ok(), "%s divergence fails direct pre-resolution safety" % test_case.label, failures)
		executed += 1
	TestAssertions.equal(executed, cases.size(), "every direct pre-resolution safety mutation body executes", failures)
	_free_fixture(fixture, "")

func _test_irreversible_terminal_completion_sanitizes_every_generation(failures: Array[String]) -> void:
	var mutations := ProfileMutationService.new()
	if not mutations.has_method(&"apply_irreversible_terminal_completion"):
		failures.append("irreversible terminal sanitation behavior is blocked because ProfileMutationService.apply_irreversible_terminal_completion is missing")
		return
	var fixture := _fixture(false)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 7.0, fixture.context).snapshot
	var profile := _overflow_profile(snapshot, true)
	var root := _case_root("irreversible")
	var store := ProfileStore.new()
	var historical := profile.to_dictionary()
	historical["applied_transactions"] = {}
	profile.applied_transactions = {"old-terminal": {"operation": "old", "fingerprint": "a".repeat(64), "committed_at_unix": 1000, "result_profile": historical}}
	TestAssertions.equal(store.save_profile(profile, root), "", "irreversible terminal fixture saves primary", failures)
	profile.gold = 1
	TestAssertions.equal(store.save_profile(profile, root), "", "irreversible terminal fixture saves backup generation", failures)
	var path := store.profile_path(PROFILE_ID, root)
	var stale_text := JSON.stringify(historical)
	for suffix: String in [".tmp", ".bak.previous", ".irreversible-primary.tmp", ".irreversible-backup.tmp", ".irreversible-primary.previous", ".irreversible-backup.previous"]:
		_write_text(path + suffix, stale_text)
	var calls := {"count": 0}
	var terminal_ids: Array[String] = [ITEM_ID]
	var result: Variant = mutations.call(&"apply_irreversible_terminal_completion", PROFILE_ID, "terminal-complete:%s" % RUN_ID, RUN_ID, terminal_ids, func(candidate: ProfileState) -> String:
		calls["count"] = int(calls["count"]) + 1
		candidate.terminal_resolution = {}
		return "", root, -1, "terminal_completion", {"profile_id": PROFILE_ID, "run_id": String(RUN_ID)})
	TestAssertions.truthy(_ok(result), "irreversible terminal completion commits sanitized truth", failures)
	TestAssertions.equal(int(calls["count"]), 1, "first irreversible completion mutates exactly once", failures)
	for active_path: String in [path, path + ".bak"]:
		var decoded := ProfileCodec.decode(FileAccess.get_file_as_string(active_path))
		TestAssertions.truthy(decoded.ok() and decoded.profile.terminal_resolution.is_empty(), "%s has no terminal receipt" % active_path.get_file(), failures)
		TestAssertions.truthy(not JSON.stringify(decoded.profile.applied_transactions).contains(ITEM_ID), "%s historical snapshots contain no terminal-source item" % active_path.get_file(), failures)
	for suffix: String in [".tmp", ".bak.previous", ".irreversible-primary.tmp", ".irreversible-backup.tmp", ".irreversible-primary.previous", ".irreversible-backup.previous"]:
		var artifact := path + suffix
		TestAssertions.truthy(not FileAccess.file_exists(artifact) or (not FileAccess.get_file_as_string(artifact).contains(String(RUN_ID)) and not FileAccess.get_file_as_string(artifact).contains(ITEM_ID)), "stale terminal truth is absent from %s" % artifact.get_file(), failures)
	var replay: Variant = mutations.call(&"apply_irreversible_terminal_completion", PROFILE_ID, "terminal-complete:%s" % RUN_ID, RUN_ID, terminal_ids, func(_candidate: ProfileState) -> String:
		calls["count"] = int(calls["count"]) + 1
		return "unexpected", root, -1, "terminal_completion", {"profile_id": PROFILE_ID, "run_id": String(RUN_ID)})
	TestAssertions.truthy(_ok(replay) and bool(replay.get("duplicate")), "committed-unsanitized duplicate retry replays durable completion", failures)
	TestAssertions.equal(int(calls["count"]), 1, "committed duplicate retry does not mutate twice", failures)
	ProfileTestSupport.remove_tree(root)

	var debt_root := _case_root("irreversible_sanitation_debt")
	var debt_profile := _overflow_profile(snapshot, true)
	TestAssertions.equal(store.save_profile(debt_profile, debt_root), "", "post-commit sanitation failure fixture saves", failures)
	var debt_calls := {"count": 0}
	var failing_store := ProfileStore.new(PostCommitSanitationFailingStore.new())
	var failing_mutations := ProfileMutationService.new(failing_store)
	var first_debt: Variant = failing_mutations.call(&"apply_irreversible_terminal_completion", PROFILE_ID, "terminal-complete-debt:%s" % RUN_ID, RUN_ID, terminal_ids, func(candidate: ProfileState) -> String:
		debt_calls["count"] = int(debt_calls["count"]) + 1
		candidate.terminal_resolution = {}
		return "", debt_root, -1, "terminal_completion", {"profile_id": PROFILE_ID, "run_id": String(RUN_ID)})
	TestAssertions.truthy(not _ok(first_debt) and String(first_debt.get("error")).contains("sanitize"), "committed plus unsanitized first call does not authorize navigation", failures)
	TestAssertions.equal(int(debt_calls["count"]), 1, "committed-unsanitized first call mutates exactly once", failures)
	var second_debt: Variant = failing_mutations.call(&"apply_irreversible_terminal_completion", PROFILE_ID, "terminal-complete-debt:%s" % RUN_ID, RUN_ID, terminal_ids, func(_candidate: ProfileState) -> String:
		debt_calls["count"] = int(debt_calls["count"]) + 1
		return "unexpected", debt_root, -1, "terminal_completion", {"profile_id": PROFILE_ID, "run_id": String(RUN_ID)})
	TestAssertions.truthy(not _ok(second_debt), "duplicate retry stays blocked while sanitation still fails", failures)
	TestAssertions.equal(int(debt_calls["count"]), 1, "blocked sanitation retry never reapplies terminal mutation", failures)
	var healed: Variant = ProfileMutationService.new(ProfileStore.new()).call(&"apply_irreversible_terminal_completion", PROFILE_ID, "terminal-complete-debt:%s" % RUN_ID, RUN_ID, terminal_ids, func(_candidate: ProfileState) -> String:
		debt_calls["count"] = int(debt_calls["count"]) + 1
		return "unexpected", debt_root, -1, "terminal_completion", {"profile_id": PROFILE_ID, "run_id": String(RUN_ID)})
	TestAssertions.truthy(_ok(healed) and bool(healed.get("duplicate")), "same committed retry authorizes only after sanitation succeeds", failures)
	TestAssertions.equal(int(debt_calls["count"]), 1, "successful sanitation-only retry still mutates exactly once overall", failures)
	ProfileTestSupport.remove_tree(debt_root)
	_free_fixture(fixture, "")

func _test_protect_displaced_gear_is_automatic_only_atomic_and_idempotent(failures: Array[String]) -> void:
	if not ResourceLoader.exists("res://scripts/run/run_terminal_recovery_service.gd"):
		failures.append("automatic-only displaced-gear protection behavior is blocked solely because run_terminal_recovery_service.gd is missing")
		return
	var preflight_test: Variant = (load("res://tests/unit/test_run_resolution_preflight.gd") as Script).new()
	var unlocks: Array[String] = [RunExtractionPolicy.AUTOMATIC_LEADER_UNLOCK]
	var fixture: Dictionary = preflight_test.call("_fixture", "terminal-protect-behavior", 0, unlocks, 1)
	preflight_test.call("_seed_prior_loadout", fixture)
	var store := fixture.store as ProfileStore
	var profile := store.load_profile(String((fixture.profile as ProfileState).profile_id), fixture.root).profile
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 5.0, fixture.context).snapshot
	var recovery: Variant = (load("res://scripts/run/run_terminal_recovery_service.gd") as Script).new(ProfileMutationService.new(store), store)
	TestAssertions.truthy(_ok(recovery.call("persist_initial", profile.profile_id, snapshot, fixture.root)), "protection fixture persists initial terminal truth", failures)
	profile = store.load_profile(profile.profile_id, fixture.root).profile
	var inspected: Variant = recovery.call("inspect", profile)
	TestAssertions.truthy(_ok(inspected), "protection fixture inspects typed recovery record", failures)
	if not _ok(inspected):
		preflight_test.call("_cleanup", fixture)
		return
	var selections: Array[ExtractionSelection] = []
	var request := RunResolutionRequest.create("terminal-protect-preflight", profile.profile_id, snapshot.run_id, snapshot.run_seed, snapshot.run_player_id, snapshot.leader_member_id, selections)
	var blocked := RunResolutionService.new().preflight_source(profile, snapshot.resolution_source, request)
	TestAssertions.truthy(not blocked.ok() and blocked.automatic_only_blocked, "only automatic displaced gear exposes protection", failures)
	var empty_ids: Array[String] = []
	var choosing := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION,
		snapshot, empty_ids, request.transaction_id, empty_ids, "", null, "",
	)
	TestAssertions.truthy(choosing.ok(), "confirmed choosing-stage protection authority fixture is valid", failures)
	profile.terminal_resolution = choosing.record.to_dictionary()
	TestAssertions.equal(store.save_profile(profile, fixture.root), "", "confirmed choosing-stage protection authority fixture saves", failures)
	var before_choosing := FileAccess.get_file_as_bytes(store.profile_path(profile.profile_id, fixture.root))
	var choosing_rejected: Variant = recovery.call("protect_displaced_gear", profile.profile_id, choosing.record, fixture.root)
	TestAssertions.truthy(not _ok(choosing_rejected) and _error(choosing_rejected).to_lower().contains("stage"), "automatic-only preflight cannot authorize protection before the durable interrupted stage", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(store.profile_path(profile.profile_id, fixture.root)), before_choosing, "choosing-stage protection rejection is write-free", failures)
	var interrupted := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED,
		snapshot, empty_ids, request.transaction_id, empty_ids, blocked.player_reason, null, "",
	)
	TestAssertions.truthy(interrupted.ok(), "automatic-only interrupted protection authority fixture is valid", failures)
	profile.terminal_resolution = interrupted.record.to_dictionary()
	TestAssertions.equal(store.save_profile(profile, fixture.root), "", "automatic-only interrupted protection authority fixture saves", failures)
	var before_registry := profile.item_records.duplicate(true)
	var protected: Variant = recovery.call("protect_displaced_gear", profile.profile_id, interrupted.record, fixture.root)
	TestAssertions.truthy(_ok(protected), "confirmed automatic-only protection commits", failures)
	var saved := store.load_profile(profile.profile_id, fixture.root).profile
	TestAssertions.equal(saved.leader_loadout["slots"], {}, "protection clears every occupied permanent leader slot", failures)
	TestAssertions.equal(saved.terminal_recovery_overflow["slots"], {"0": "item-preflight-prior-head", "10": "item-preflight-prior-shield"}, "protection moves exact permanent gear to matching overflow slots", failures)
	TestAssertions.equal(saved.item_records, before_registry, "protection preserves every item registry record byte-structurally", failures)
	TestAssertions.equal(saved.terminal_resolution.get("protected_displaced_item_ids", []), ["item-preflight-prior-head", "item-preflight-prior-shield"], "protection records the exact stable confirmation copy", failures)
	var replay: Variant = recovery.call("protect_displaced_gear", profile.profile_id, interrupted.record, fixture.root)
	TestAssertions.truthy(_ok(replay) and bool(replay.get("duplicate")), "same protection request is idempotent", failures)
	var after := store.load_profile(profile.profile_id, fixture.root).profile
	TestAssertions.equal(after.to_dictionary(), saved.to_dictionary(), "idempotent protection preserves exact durable truth", failures)
	var accepted := RunResolutionService.new().preflight_source(after, snapshot.resolution_source, request)
	TestAssertions.truthy(accepted.ok() and accepted.mandatory_stash_slots == 0, "protection rerun preflight is accepted with zero mandatory displaced slots: %s / %s" % [accepted.error, accepted.player_reason], failures)
	var cold: Variant = recovery.call("inspect", after)
	TestAssertions.truthy(_ok(cold) and cold.get("record").get("protected_displaced_item_ids") == ["item-preflight-prior-head", "item-preflight-prior-shield"], "cold resume retains overflow and protected IDs", failures)
	var changed_snapshot_document: Dictionary = inspected.get("record").get("snapshot").to_dictionary()
	changed_snapshot_document["elapsed_seconds"] = float(changed_snapshot_document["elapsed_seconds"]) + 1.0
	var changed_snapshot := RunTerminalSnapshot.from_dictionary(changed_snapshot_document)
	var changed_record := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION,
		changed_snapshot.snapshot if changed_snapshot.ok() else null,
		empty_ids, "", empty_ids, "", null, "",
	)
	TestAssertions.truthy(changed_snapshot.ok() and changed_record.ok(), "changed protection replay record remains typed and valid", failures)
	var before_changed_record := FileAccess.get_file_as_bytes(store.profile_path(profile.profile_id, fixture.root))
	var changed_record_replay: Variant = recovery.call("protect_displaced_gear", profile.profile_id, changed_record.record, fixture.root)
	TestAssertions.truthy(not _ok(changed_record_replay), "committed protection replay rejects a different supplied record", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(store.profile_path(profile.profile_id, fixture.root)), before_changed_record, "changed protection record replay is write-free", failures)

	var drifted_result := store.load_profile(profile.profile_id, fixture.root).profile
	(drifted_result.terminal_recovery_overflow["slots"] as Dictionary).erase("0")
	(drifted_result.leader_loadout["slots"] as Dictionary)["0"] = "item-preflight-prior-head"
	TestAssertions.equal(ProfileCodec.validate_profile(drifted_result), "", "protection durable-result drift fixture remains structurally valid", failures)
	TestAssertions.equal(store.save_profile(drifted_result, fixture.root), "", "protection durable-result drift fixture saves", failures)
	var before_result_drift := FileAccess.get_file_as_bytes(store.profile_path(profile.profile_id, fixture.root))
	var result_drift_replay: Variant = recovery.call("protect_displaced_gear", profile.profile_id, interrupted.record, fixture.root)
	TestAssertions.truthy(not _ok(result_drift_replay), "committed protection replay rejects durable placement drift", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(store.profile_path(profile.profile_id, fixture.root)), before_result_drift, "durable protection result rejection is write-free", failures)
	preflight_test.call("_cleanup", fixture)

	var full_fixture: Dictionary = preflight_test.call("_fixture", "terminal-protect-full-overflow", 0, unlocks, 1)
	preflight_test.call("_seed_prior_loadout", full_fixture)
	var full_store := full_fixture.store as ProfileStore
	var full_profile := full_store.load_profile(String((full_fixture.profile as ProfileState).profile_id), full_fixture.root).profile
	var full_snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 6.0, full_fixture.context).snapshot
	var full_recovery: Variant = (load("res://scripts/run/run_terminal_recovery_service.gd") as Script).new(ProfileMutationService.new(full_store), full_store)
	TestAssertions.truthy(_ok(full_recovery.call("persist_initial", full_profile.profile_id, full_snapshot, full_fixture.root)), "full-overflow protection fixture persists terminal truth", failures)
	full_profile = full_store.load_profile(full_profile.profile_id, full_fixture.root).profile
	var decoded_registry := ItemRegistry._decode(full_profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	var all_items: Array[ItemInstance] = []
	for existing_id: String in (decoded_registry.value as ItemRegistry).ids(): all_items.append((decoded_registry.value as ItemRegistry).item(existing_id))
	var full_slots: Dictionary = {}
	for slot: int in EquipmentSlotIndex.capacity():
		var filler: ItemInstance = preflight_test.call("_profile_item", "item-terminal-overflow-filler-%02d" % slot, 500 + slot, &"forge_vanguard_sword")
		all_items.append(filler)
		full_slots[slot] = filler.instance_id
	full_profile.item_records = ItemRegistry.new(all_items).to_dictionary()
	full_profile.terminal_recovery_overflow = ItemSlotContainer.create(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, ItemSlotContainer.PROFILE_TERMINAL_RECOVERY_OVERFLOW, full_profile.profile_id, EquipmentSlotIndex.capacity(), full_slots).to_dictionary()
	full_profile.terminal_resolution = RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, full_snapshot, empty_ids,
		"terminal-full-overflow-preflight", empty_ids, "Automatic displaced gear is blocked.", null, "",
	).record.to_dictionary()
	TestAssertions.equal(full_store.save_profile(full_profile, full_fixture.root), "", "full overflow fixture persists", failures)
	var full_inspected: Variant = full_recovery.call("inspect", full_profile)
	var full_hash := FileAccess.get_sha256(full_store.profile_path(full_profile.profile_id, full_fixture.root))
	var full_rejected: Variant = full_recovery.call("protect_displaced_gear", full_profile.profile_id, full_inspected.get("record"), full_fixture.root)
	TestAssertions.truthy(not _ok(full_rejected) and String(full_rejected.get("error")).to_lower().contains("overflow"), "nonempty/full overflow rejects protection readably", failures)
	TestAssertions.equal(FileAccess.get_sha256(full_store.profile_path(full_profile.profile_id, full_fixture.root)), full_hash, "full overflow protection failure is atomic", failures)
	preflight_test.call("_cleanup", full_fixture)

func _test_protect_displaced_gear_failure_matrix(failures: Array[String]) -> void:
	var preflight_test: Variant = (load("res://tests/unit/test_run_resolution_preflight.gd") as Script).new()
	var automatic_unlocks: Array[String] = [RunExtractionPolicy.AUTOMATIC_LEADER_UNLOCK]
	var partial_fixture: Dictionary = preflight_test.call("_fixture", "protect-partial-overflow", 0, automatic_unlocks, 1)
	preflight_test.call("_seed_prior_loadout", partial_fixture)
	var partial_store := partial_fixture.store as ProfileStore
	var partial_id := String((partial_fixture.profile as ProfileState).profile_id)
	var partial_profile := partial_store.load_profile(partial_id, partial_fixture.root).profile
	var partial_snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 14.0, partial_fixture.context).snapshot
	var empty_ids: Array[String] = []
	partial_profile.terminal_resolution = RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, partial_snapshot, empty_ids,
		"terminal-partial-overflow-preflight", empty_ids, "Automatic displaced gear is blocked.", null, "",
	).record.to_dictionary()
	var decoded := ItemRegistry._decode(partial_profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	var items: Array[ItemInstance] = []
	for existing_id: String in (decoded.value as ItemRegistry).ids():
		items.append((decoded.value as ItemRegistry).item(existing_id))
	var older := _profile_item("item-older-overflow", 900)
	items.append(older)
	partial_profile.item_records = ItemRegistry.new(items).to_dictionary()
	partial_profile.terminal_recovery_overflow = ItemSlotContainer.create(
		ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID,
		ItemSlotContainer.PROFILE_TERMINAL_RECOVERY_OVERFLOW,
		partial_profile.profile_id, EquipmentSlotIndex.capacity(), {5: older.instance_id},
	).to_dictionary()
	TestAssertions.equal(partial_store.save_profile(partial_profile, partial_fixture.root), "", "partially nonempty overflow protection fixture saves", failures)
	var partial_hash := FileAccess.get_sha256(partial_store.profile_path(partial_id, partial_fixture.root))
	var partial_service := RunTerminalRecoveryService.new(ProfileMutationService.new(partial_store), partial_store)
	var partial_record := RunTerminalRecoveryCodec.decode(partial_profile.terminal_resolution).record
	var partial := partial_service.protect_displaced_gear(partial_id, partial_record, partial_fixture.root)
	TestAssertions.truthy(not partial.ok() and (_error(partial).to_lower().contains("empty") or _error(partial).to_lower().contains("nonempty")), "partially nonempty overflow rejects protection even when numeric capacity remains: %s" % _error(partial), failures)
	TestAssertions.equal(FileAccess.get_sha256(partial_store.profile_path(partial_id, partial_fixture.root)), partial_hash, "partial-overflow protection rejection is atomic", failures)
	preflight_test.call("_cleanup", partial_fixture)

	var reducible_fixture: Dictionary = preflight_test.call("_fixture", "protect-reducible-unavailable", 1, [], 0)
	preflight_test.call("_seed_prior_loadout", reducible_fixture)
	var reducible_store := reducible_fixture.store as ProfileStore
	var reducible_id := String((reducible_fixture.profile as ProfileState).profile_id)
	var reducible_profile := reducible_store.load_profile(reducible_id, reducible_fixture.root).profile
	var reducible_snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 15.0, reducible_fixture.context).snapshot
	reducible_profile.terminal_resolution = RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, reducible_snapshot, empty_ids,
		"terminal-reducible-preflight", empty_ids, "Resolution was interrupted.", null, "",
	).record.to_dictionary()
	TestAssertions.equal(reducible_store.save_profile(reducible_profile, reducible_fixture.root), "", "reducible protection-unavailable fixture saves", failures)
	var reducible_service := RunTerminalRecoveryService.new(ProfileMutationService.new(reducible_store), reducible_store)
	var reducible := reducible_service.protect_displaced_gear(reducible_id, RunTerminalRecoveryCodec.decode(reducible_profile.terminal_resolution).record, reducible_fixture.root)
	TestAssertions.truthy(not reducible.ok() and _error(reducible).to_lower().contains("automatic"), "ordinary reducible capacity never exposes displaced-gear protection: %s" % _error(reducible), failures)
	preflight_test.call("_cleanup", reducible_fixture)

	var save_fixture: Dictionary = preflight_test.call("_fixture", "protect-save-failure", 0, automatic_unlocks, 1)
	preflight_test.call("_seed_prior_loadout", save_fixture)
	var good_store := save_fixture.store as ProfileStore
	var save_id := String((save_fixture.profile as ProfileState).profile_id)
	var save_profile := good_store.load_profile(save_id, save_fixture.root).profile
	var save_snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 16.0, save_fixture.context).snapshot
	save_profile.terminal_resolution = RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, save_snapshot, empty_ids,
		"terminal-save-failure-preflight", empty_ids, "Automatic displaced gear is blocked.", null, "",
	).record.to_dictionary()
	TestAssertions.equal(good_store.save_profile(save_profile, save_fixture.root), "", "protection save-failure fixture saves", failures)
	var save_hash := FileAccess.get_sha256(good_store.profile_path(save_id, save_fixture.root))
	var failing_documents := AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE)
	var failing_store := ProfileStore.new(failing_documents)
	var save_failure := RunTerminalRecoveryService.new(ProfileMutationService.new(failing_store), failing_store).protect_displaced_gear(
		save_id, RunTerminalRecoveryCodec.decode(save_profile.terminal_resolution).record, save_fixture.root,
	)
	TestAssertions.truthy(not save_failure.ok() and _error(save_failure).contains("promote"), "protection storage failure reports the real atomic save boundary: %s" % _error(save_failure), failures)
	TestAssertions.equal(FileAccess.get_sha256(good_store.profile_path(save_id, save_fixture.root)), save_hash, "protection save failure preserves exact profile bytes", failures)
	preflight_test.call("_cleanup", save_fixture)

func _test_terminal_completion_service_contract(failures: Array[String]) -> void:
	var fixture := _fixture(true)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 17.0, fixture.context).snapshot
	var resolved: ProfileState = _resolved_profile(fixture.profile, snapshot, true)
	var root := _case_root("completion_service")
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(resolved, root), "", "resolved completion service fixture saves", failures)
	var service := RunTerminalRecoveryService.new(ProfileMutationService.new(store), store)
	var completed := service.complete_terminal(PROFILE_ID, RUN_ID, root)
	TestAssertions.truthy(_ok(completed), "complete_terminal clears one exact resolved receipt through the irreversible boundary", failures)
	if _ok(completed):
		var durable := store.load_profile(PROFILE_ID, root).profile
		var transaction_id := "terminal-complete:%s" % RUN_ID
		TestAssertions.equal(durable.terminal_resolution, {}, "terminal completion clears only the resolved receipt", failures)
		TestAssertions.truthy(durable.applied_transactions.has(transaction_id), "terminal completion commits the exact stable transaction ID", failures)
		var record := durable.applied_transactions[transaction_id] as Dictionary
		TestAssertions.equal(String(record.get("operation", "")), "terminal_completion", "terminal completion records the exact canonical operation", failures)
		TestAssertions.equal((record.get("result_profile", {}) as Dictionary).get("terminal_resolution", null), {}, "completion receipt result snapshot is already sanitized", failures)
		var replay := service.complete_terminal(PROFILE_ID, RUN_ID, root)
		TestAssertions.truthy(_ok(replay) and replay.duplicate, "receipt-free committed retry replays by the stable run transaction", failures)
		TestAssertions.equal(replay.profile.to_dictionary() if _ok(replay) else {}, completed.profile.to_dictionary(), "duplicate completion returns the same retained-item projection as the first completion", failures)
		TestAssertions.truthy(_ok(replay) and ITEM_ID in JSON.stringify(replay.profile.item_records), "duplicate completion projection retains legitimately extracted items", failures)
		TestAssertions.equal(store.load_profile(PROFILE_ID, root).profile.to_dictionary(), durable.to_dictionary(), "duplicate completion replay performs no new mutation", failures)
	ProfileTestSupport.remove_tree(root)

	var wrong_root := _case_root("completion_wrong_run")
	TestAssertions.equal(store.save_profile(resolved, wrong_root), "", "wrong-run completion fixture saves", failures)
	var wrong_hash := FileAccess.get_sha256(store.profile_path(PROFILE_ID, wrong_root))
	var wrong := service.complete_terminal(PROFILE_ID, &"run-terminal-other", wrong_root)
	TestAssertions.truthy(not _ok(wrong) and _error(wrong).to_lower().contains("run"), "complete_terminal rejects a mismatched run identity readably", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, wrong_root)), wrong_hash, "wrong-run completion is write-free", failures)
	ProfileTestSupport.remove_tree(wrong_root)

	var pre_root := _case_root("completion_pre_resolution")
	var pre: ProfileState = (fixture.profile as ProfileState).copy()
	var empty_ids: Array[String] = []
	pre.terminal_resolution = RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION, snapshot, empty_ids, "", empty_ids, "", null, "",
	).record.to_dictionary()
	TestAssertions.equal(store.save_profile(pre, pre_root), "", "pre-resolution completion fixture saves", failures)
	var pre_hash := FileAccess.get_sha256(store.profile_path(PROFILE_ID, pre_root))
	var premature := RunTerminalRecoveryService.new(ProfileMutationService.new(store), store).complete_terminal(PROFILE_ID, RUN_ID, pre_root)
	TestAssertions.truthy(not _ok(premature) and (_error(premature).to_lower().contains("resolved") or _error(premature).to_lower().contains("stage")), "complete_terminal rejects a pre-resolution receipt", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, pre_root)), pre_hash, "pre-resolution completion is write-free", failures)
	ProfileTestSupport.remove_tree(pre_root)

	var zero_fixture := _fixture(false)
	var zero_snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.DEFEAT, 18.0, zero_fixture.context).snapshot
	var zero: ProfileState = _resolved_profile(zero_fixture.profile, zero_snapshot, false)
	var zero_root := _case_root("completion_zero_items")
	TestAssertions.equal(store.save_profile(zero, zero_root), "", "zero-item resolved completion fixture saves", failures)
	var zero_complete := RunTerminalRecoveryService.new(ProfileMutationService.new(store), store).complete_terminal(PROFILE_ID, RUN_ID, zero_root)
	TestAssertions.truthy(_ok(zero_complete), "zero-item terminal completion still sanitizes by resolved run identity", failures)
	if _ok(zero_complete):
		var zero_durable := store.load_profile(PROFILE_ID, zero_root).profile
		for transaction: Variant in zero_durable.applied_transactions.values():
			var result_profile := (transaction as Dictionary).get("result_profile", {}) as Dictionary
			TestAssertions.equal(result_profile.get("terminal_resolution", null), {}, "zero-item completion leaves no historical terminal receipt", failures)
	ProfileTestSupport.remove_tree(zero_root)
	_free_fixture(zero_fixture, "")
	_free_fixture(fixture, "")

func _test_completion_revalidates_complete_resolved_transaction(failures: Array[String]) -> void:
	var fixture := _fixture(true)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 18.0, fixture.context).snapshot
	var exact := _resolved_profile(fixture.profile, snapshot, true)
	var applied_id := String(exact.terminal_resolution.get("applied_transaction_id", ""))
	var cases: Array[Dictionary] = [
		{"label": "operation", "kind": "path", "path": ["applied_transactions", applied_id, "operation"], "value": "not_run_resolution"},
		{"label": "fingerprint", "kind": "path", "path": ["applied_transactions", applied_id, "fingerprint"], "value": "a".repeat(64)},
		{"label": "receipt schema", "kind": "path", "path": ["applied_transactions", applied_id, "receipt", "schema_version"], "value": 2},
		{"label": "receipt source", "kind": "path", "path": ["applied_transactions", applied_id, "receipt", "source_fingerprint"], "value": "b".repeat(64)},
		{"label": "receipt request", "kind": "path", "path": ["applied_transactions", applied_id, "receipt", "request_fingerprint"], "value": "c".repeat(64)},
		{"label": "result snapshot", "kind": "path", "path": ["applied_transactions", applied_id, "result_profile", "item_records", "items", 0, "item_level"], "value": 21},
		{"label": "durable placement", "kind": "path", "path": ["stash_tabs", 0, "slots"], "value": {"1": ITEM_ID}},
	]
	var store := ProfileStore.new()
	var executed := 0
	for test_case: Dictionary in cases:
		var candidate := exact.copy()
		var document := candidate.to_dictionary()
		_set_nested_variant(document, test_case.path, test_case.value)
		var decoded := ProfileCodec.decode_document(document)
		TestAssertions.truthy(decoded.ok(), "%s completion-drift fixture remains structurally valid: %s" % [test_case.label, decoded.error], failures)
		if not decoded.ok():
			continue
		var root := _case_root("completion_full_transaction_%s" % String(test_case.label).replace(" ", "_"))
		TestAssertions.equal(store.save_profile(decoded.profile, root), "", "%s completion-drift fixture saves" % test_case.label, failures)
		var path := store.profile_path(PROFILE_ID, root)
		var before_bytes := FileAccess.get_file_as_bytes(path)
		var rejected := RunTerminalRecoveryService.new(ProfileMutationService.new(store), store).complete_terminal(PROFILE_ID, RUN_ID, root)
		TestAssertions.truthy(not rejected.ok(), "complete_terminal rejects resolved transaction %s drift" % test_case.label, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "%s completion drift is write-free" % test_case.label, failures)
		executed += 1
		ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(executed, cases.size(), "every completion transaction drift mutation executes", failures)
	_free_fixture(fixture, "")

func _test_completion_revalidates_inside_mutation_callback(failures: Array[String]) -> void:
	var fixture := _fixture(true)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 18.25, fixture.context).snapshot
	var exact := _resolved_profile(fixture.profile, snapshot, true)
	var applied_id := String(exact.terminal_resolution.get("applied_transaction_id", ""))
	var drift := exact.copy()
	(drift.applied_transactions[applied_id] as Dictionary)["operation"] = "not_run_resolution"
	TestAssertions.equal(ProfileCodec.validate_profile(drift), "", "completion callback drift fixture remains structurally valid", failures)
	var root := _case_root("completion_callback_revalidation")
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(exact, root), "", "completion callback exact fixture saves", failures)
	var interleaving := CompletionInterleavingMutationService.new(store, drift)
	var rejected := RunTerminalRecoveryService.new(interleaving, store).complete_terminal(PROFILE_ID, RUN_ID, root)
	TestAssertions.truthy(not rejected.ok(), "complete_terminal revalidates resolved truth inside the mutation callback", failures)
	var path := store.profile_path(PROFILE_ID, root)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), interleaving.injected_bytes, "callback-time drift rejection adds no completion write", failures)
	var durable := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.truthy(not durable.terminal_resolution.is_empty() and not durable.applied_transactions.has("terminal-complete:%s" % RUN_ID), "callback-time drift cannot clear receipt or authorize completion", failures)
	ProfileTestSupport.remove_tree(root)
	_free_fixture(fixture, "")

func _test_completion_rejects_missing_or_mismatched_applied_resolution(failures: Array[String]) -> void:
	var fixture := _fixture(true)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 18.5, fixture.context).snapshot
	var exact := _resolved_profile(fixture.profile, snapshot, true)
	var original_transaction := String(exact.terminal_resolution.get("applied_transaction_id", ""))
	var store := ProfileStore.new()
	for test_case: Dictionary in [
		{"label": "missing", "replacement": ""},
		{"label": "mismatched", "replacement": "terminal-resolution:other"},
	]:
		var candidate := exact.copy()
		var record := (candidate.applied_transactions[original_transaction] as Dictionary).duplicate(true)
		candidate.applied_transactions = {}
		if not String(test_case.replacement).is_empty():
			candidate.applied_transactions[String(test_case.replacement)] = record
		TestAssertions.equal(ProfileCodec.validate_profile(candidate), "", "%s applied-resolution fixture remains structurally valid" % test_case.label, failures)
		var root := _case_root("completion_applied_%s" % test_case.label)
		TestAssertions.equal(store.save_profile(candidate, root), "", "%s applied-resolution fixture saves" % test_case.label, failures)
		var before_hash := FileAccess.get_sha256(store.profile_path(PROFILE_ID, root))
		var rejected := RunTerminalRecoveryService.new(ProfileMutationService.new(store), store).complete_terminal(PROFILE_ID, RUN_ID, root)
		TestAssertions.truthy(not rejected.ok() and _error(rejected).to_lower().contains("applied"), "complete_terminal rejects a structurally resolved receipt with %s applied resolution" % test_case.label, failures)
		TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, root)), before_hash, "%s applied-resolution rejection is write-free" % test_case.label, failures)
		ProfileTestSupport.remove_tree(root)
	_free_fixture(fixture, "")

func _test_completion_rejects_coordinated_noncanonical_selection_permutation(failures: Array[String]) -> void:
	var fixture := _fixture(true)
	fixture.context._item_state = _run_state_pair()
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 18.75, fixture.context).snapshot
	var coordinated_permutation := _resolved_profile_with_coordinated_permutation(fixture.profile, snapshot)
	TestAssertions.equal(ProfileCodec.validate_profile(coordinated_permutation), "", "coordinated noncanonical selection permutation remains structurally valid", failures)
	var root := _case_root("completion_coordinated_permutation")
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(coordinated_permutation, root), "", "coordinated noncanonical selection permutation saves", failures)
	var path := store.profile_path(PROFILE_ID, root)
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var rejected := RunTerminalRecoveryService.new(ProfileMutationService.new(store), store).complete_terminal(PROFILE_ID, RUN_ID, root)
	TestAssertions.truthy(not rejected.ok() and _error(rejected).contains("selected_item_ids"), "completion rejects a coordinated noncanonical selected-ID permutation", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "coordinated selection permutation rejection is write-free", failures)
	ProfileTestSupport.remove_tree(root)
	_free_fixture(fixture, "")

func _test_terminal_completion_invalid_and_storage_failures(failures: Array[String]) -> void:
	var fixture := _fixture(true)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 19.0, fixture.context).snapshot
	var resolved: ProfileState = _resolved_profile(fixture.profile, snapshot, true)
	var root := _case_root("completion_invalid")
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(resolved, root), "", "invalid completion argument fixture saves", failures)
	var mutations := ProfileMutationService.new(store)
	var calls := {"count": 0}
	var mutate := func(_candidate: ProfileState) -> String:
		calls["count"] = int(calls["count"]) + 1
		return ""
	var item_ids: Array[String] = [ITEM_ID]
	var duplicate_ids: Array[String] = [ITEM_ID, ITEM_ID]
	var empty_id: Array[String] = [""]
	var cases: Array[Dictionary] = [
		{"label": "empty run", "run": &"", "ids": item_ids, "callback": mutate, "operation": "terminal_completion"},
		{"label": "duplicate instance", "run": RUN_ID, "ids": duplicate_ids, "callback": mutate, "operation": "terminal_completion"},
		{"label": "empty instance", "run": RUN_ID, "ids": empty_id, "callback": mutate, "operation": "terminal_completion"},
		{"label": "missing callback", "run": RUN_ID, "ids": item_ids, "callback": Callable(), "operation": "terminal_completion"},
		{"label": "missing operation", "run": RUN_ID, "ids": item_ids, "callback": mutate, "operation": ""},
	]
	var before_hash := FileAccess.get_sha256(store.profile_path(PROFILE_ID, root))
	for test_case: Dictionary in cases:
		var rejected := mutations.apply_irreversible_terminal_completion(
			PROFILE_ID, "terminal-invalid-%s" % String(test_case.label).replace(" ", "-"),
			test_case.run, test_case.ids, test_case.callback, root, -1,
			test_case.operation, {"profile_id": PROFILE_ID, "run_id": String(test_case.run)},
		)
		TestAssertions.truthy(not rejected.ok(), "%s terminal completion argument fails closed" % test_case.label, failures)
	TestAssertions.equal(int(calls["count"]), 0, "invalid terminal completion arguments never invoke mutation", failures)
	TestAssertions.equal(FileAccess.get_sha256(store.profile_path(PROFILE_ID, root)), before_hash, "invalid completion arguments perform no write", failures)
	ProfileTestSupport.remove_tree(root)

	var precommit_root := _case_root("completion_precommit_failure")
	TestAssertions.equal(store.save_profile(resolved, precommit_root), "", "terminal precommit failure fixture saves", failures)
	var precommit_path := store.profile_path(PROFILE_ID, precommit_root)
	_write_text(precommit_path + ".tmp", "stale-terminal-artifact")
	var precommit_documents := TerminalPrecommitFailStore.new()
	precommit_documents.failure_path = precommit_path + ".tmp"
	var precommit := RunTerminalRecoveryService.new(ProfileMutationService.new(ProfileStore.new(precommit_documents)), ProfileStore.new(precommit_documents)).complete_terminal(PROFILE_ID, RUN_ID, precommit_root)
	TestAssertions.truthy(not _ok(precommit) and _error(precommit).contains("preflight"), "terminal completion precommit failure blocks authorization at artifact sanitation", failures)
	TestAssertions.truthy(store.load_profile(PROFILE_ID, precommit_root).ok(), "terminal precommit failure preserves a recoverable active generation", failures)
	ProfileTestSupport.remove_tree(precommit_root)

	var promotion_root := _case_root("completion_promotion_failure")
	TestAssertions.equal(store.save_profile(resolved, promotion_root), "", "terminal promotion failure fixture saves", failures)
	var promotions := {"count": 0}
	var failing_documents := AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error:
		promotions["count"] = int(promotions["count"]) + 1
		return ERR_CANT_CREATE
	)
	var promotion_store := ProfileStore.new(failing_documents)
	var failed := RunTerminalRecoveryService.new(ProfileMutationService.new(promotion_store), promotion_store).complete_terminal(PROFILE_ID, RUN_ID, promotion_root)
	TestAssertions.truthy(not _ok(failed) and _error(failed).contains("promote"), "terminal completion promotion failure blocks authorization", failures)
	TestAssertions.truthy(store.load_profile(PROFILE_ID, promotion_root).ok(), "terminal promotion failure preserves the prior recoverable generation", failures)
	ProfileTestSupport.remove_tree(promotion_root)
	_free_fixture(fixture, "")

func _test_resolved_terminal_safety_one_field_matrix(failures: Array[String]) -> void:
	var recovery := RunRecoveryService.new()
	var fixture := _fixture(true)
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 8.0, fixture.context).snapshot
	var durable := _resolved_profile(fixture.profile, snapshot, true)
	TestAssertions.equal(ProfileCodec.validate_profile(durable), "", "direct resolved safety fixture is structurally durable", failures)
	var profile_before := durable.to_dictionary()
	var snapshot_before := snapshot.to_dictionary()
	var exact := recovery.verify_terminal_safety(durable, snapshot)
	TestAssertions.truthy(_ok(exact), "absent resumable run plus exact resolved receipt and placements passes safety", failures)
	TestAssertions.equal(durable.to_dictionary(), profile_before, "resolved safety preserves input profile", failures)
	TestAssertions.equal(snapshot.to_dictionary(), snapshot_before, "resolved safety preserves input snapshot", failures)
	var cases: Array[Dictionary] = [
		{"label": "profile", "path": ["terminal_resolution", "snapshot", "profile_id"], "value": "profile-other"},
		{"label": "outcome", "path": ["terminal_resolution", "snapshot", "outcome"], "value": RunTerminalSnapshot.Outcome.DEFEAT},
		{"label": "run", "path": ["terminal_resolution", "snapshot", "run_id"], "value": "run-other"},
		{"label": "seed", "path": ["terminal_resolution", "snapshot", "run_seed"], "value": RUN_SEED + 1},
		{"label": "player", "path": ["terminal_resolution", "snapshot", "run_player_id"], "value": "player-other"},
		{"label": "leader", "path": ["terminal_resolution", "snapshot", "leader_member_id"], "value": 2},
		{"label": "member", "path": ["terminal_resolution", "snapshot", "members", 0, "class_id"], "value": "mage"},
		{"label": "source member", "path": ["terminal_resolution", "snapshot", "resolution_source", "party_members", 0, "class_id"], "value": "mage"},
		{"label": "source item record", "path": ["terminal_resolution", "snapshot", "resolution_source", "item_state", "registry", "items", 0, "item_level"], "value": 21},
		{"label": "source container", "path": ["terminal_resolution", "snapshot", "resolution_source", "item_state", "containers", 2, "container_id"], "value": "run-other"},
		{"label": "source slot", "path": ["terminal_resolution", "snapshot", "resolution_source", "item_state", "containers", 2, "slots"], "value": {"1": ITEM_ID}},
		{"label": "record selection", "path": ["terminal_resolution", "selected_item_ids"], "value": []},
		{"label": "accepted selection", "path": ["terminal_resolution", "accepted_extraction", "selected_item_ids"], "value": []},
		{"label": "record transaction", "path": ["terminal_resolution", "transaction_id"], "value": "terminal-other"},
		{"label": "applied transaction", "path": ["terminal_resolution", "applied_transaction_id"], "value": "terminal-other"},
		{"label": "applied operation", "path": ["applied_transactions", String(durable.terminal_resolution["applied_transaction_id"]), "operation"], "value": "unrelated_operation"},
		{"label": "applied fingerprint", "path": ["applied_transactions", String(durable.terminal_resolution["applied_transaction_id"]), "fingerprint"], "value": "a".repeat(64)},
		{"label": "applied receipt source", "path": ["applied_transactions", String(durable.terminal_resolution["applied_transaction_id"]), "receipt", "source_fingerprint"], "value": "b".repeat(64)},
		{"label": "applied receipt request", "path": ["applied_transactions", String(durable.terminal_resolution["applied_transaction_id"]), "receipt", "request_fingerprint"], "value": "c".repeat(64)},
		{"label": "applied receipt schema", "path": ["applied_transactions", String(durable.terminal_resolution["applied_transaction_id"]), "receipt", "schema_version"], "value": 2},
		{"label": "missing applied receipt", "special": "receipt_missing"},
		{"label": "extra applied receipt field", "special": "receipt_extra"},
		{"label": "stage", "path": ["terminal_resolution", "stage"], "value": RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED},
		{"label": "durable item record", "path": ["item_records", "items", 0, "item_level"], "value": 21},
		{"label": "durable stash placement", "path": ["stash_tabs", 0, "slots"], "value": {"2": ITEM_ID}},
		{"label": "durable leader-loadout placement", "special": "leader"},
		{"label": "durable overflow placement", "special": "overflow"},
	]
	var executed := 0
	for test_case: Dictionary in cases:
		var changed_document := durable.to_dictionary()
		if test_case.has("special"):
			if test_case.special == "receipt_missing":
				(changed_document["applied_transactions"][String(durable.terminal_resolution["applied_transaction_id"])] as Dictionary).erase("receipt")
			elif test_case.special == "receipt_extra":
				(changed_document["applied_transactions"][String(durable.terminal_resolution["applied_transaction_id"])]["receipt"] as Dictionary)["extra"] = true
			else:
				(changed_document["stash_tabs"] as Array)[0]["slots"] = {}
			if test_case.special == "leader":
				(changed_document["leader_loadout"] as Dictionary)["slots"] = {"9": ITEM_ID}
			elif test_case.special == "overflow":
				(changed_document["terminal_recovery_overflow"] as Dictionary)["slots"] = {"0": ITEM_ID}
		else:
			_set_nested_variant(changed_document, test_case.path, test_case.value)
		var decoded := ProfileCodec.decode_document(changed_document)
		var changed: ProfileState = decoded.profile if decoded.ok() else durable.copy()
		if not decoded.ok():
			changed.terminal_resolution = (changed_document["terminal_resolution"] as Dictionary).duplicate(true)
			changed.item_records = (changed_document["item_records"] as Dictionary).duplicate(true)
			changed.stash_tabs = (changed_document["stash_tabs"] as Array).duplicate(true)
			changed.terminal_recovery_overflow = (changed_document["terminal_recovery_overflow"] as Dictionary).duplicate(true)
		var unsafe: Variant = recovery.call("verify_terminal_safety", changed, snapshot)
		TestAssertions.truthy(not _ok(unsafe), "%s one-field mismatch fails resolved safety" % test_case.label, failures)
		executed += 1
	TestAssertions.equal(executed, cases.size(), "every direct resolved safety mutation body executes", failures)
	_free_fixture(fixture, "")

func _resolved_profile(profile_value: ProfileState, snapshot: RunTerminalSnapshot, include_item: bool) -> ProfileState:
	var profile := profile_value.copy()
	profile.resumable_run = {}
	var automatic_ids: Array[String] = []
	var eligible: Array[ExtractionSelection] = []
	var selected_ids: Array[String] = []
	var lost_ids: Array[String] = []
	if include_item:
		var item := _run_item()
		profile.item_records = ItemRegistry.new([item]).to_dictionary()
		profile.stash_tabs[0]["slots"] = {"0": ITEM_ID}
		eligible.append(ExtractionSelection.create(ITEM_ID, &"run-inventory", 0))
		selected_ids.append(ITEM_ID)
	else:
		profile.item_records = ItemRegistry.new([]).to_dictionary()
		profile.stash_tabs[0]["slots"] = {}
	var accepted := RunExtractionProjection.create(
		automatic_ids, eligible, selected_ids, lost_ids,
		profile.extraction_capacity, [],
	)
	var documents: Array[Dictionary] = []
	for selection: ExtractionSelection in eligible:
		documents.append(selection.to_dictionary())
	var transaction := "terminal-resolution:%s:%s" % [snapshot.run_id, JSON.stringify(documents).sha256_text()]
	var empty_protected: Array[String] = []
	var record := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION,
		snapshot, selected_ids, transaction, empty_protected, "", accepted, transaction,
	)
	profile.terminal_resolution = record.record.to_dictionary() if record.ok() else {}
	var request := RunResolutionRequest.create(transaction, snapshot.profile_id, snapshot.run_id, snapshot.run_seed, snapshot.run_player_id, snapshot.leader_member_id, eligible)
	var result_profile := profile.to_dictionary()
	result_profile["applied_transactions"] = {}
	profile.applied_transactions = {transaction: {
		"operation": "run_resolution",
		"fingerprint": ProfileMutationService._fingerprint("run_resolution", request.canonical_document()),
		"committed_at_unix": profile.updated_at_unix,
		"result_profile": result_profile,
		"receipt": {
			"schema_version": 1,
			"source_fingerprint": JSON.stringify(snapshot.resolution_source.to_dictionary(), "", true, true).sha256_text(),
			"request_fingerprint": JSON.stringify(request.canonical_document(), "", true, true).sha256_text(),
		},
	}}
	return profile

func _resolved_profile_with_coordinated_permutation(profile_value: ProfileState, snapshot: RunTerminalSnapshot) -> ProfileState:
	var profile := profile_value.copy()
	profile.resumable_run = {}
	profile.extraction_capacity = 2
	profile.item_records = ItemRegistry.new([_run_item(), _run_item_second()]).to_dictionary()
	profile.stash_tabs[0]["slots"] = {"0": ITEM_ID, "1": ITEM_ID_SECOND}
	var eligible: Array[ExtractionSelection] = [
		ExtractionSelection.create(ITEM_ID, &"run-inventory", 0),
		ExtractionSelection.create(ITEM_ID_SECOND, &"run-inventory", 1),
	]
	var noncanonical_ids: Array[String] = [ITEM_ID_SECOND, ITEM_ID]
	var accepted := RunExtractionProjection.create([], eligible, noncanonical_ids, [], profile.extraction_capacity, [])
	var canonical_documents: Array[Dictionary] = []
	for selection: ExtractionSelection in eligible:
		canonical_documents.append(selection.to_dictionary())
	var transaction := "terminal-resolution:%s:%s" % [snapshot.run_id, JSON.stringify(canonical_documents).sha256_text()]
	var record := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION,
		snapshot, noncanonical_ids, transaction, [], "", accepted, transaction,
	)
	profile.terminal_resolution = record.record.to_dictionary() if record.ok() else {}
	var request := RunResolutionRequest.create(transaction, snapshot.profile_id, snapshot.run_id, snapshot.run_seed, snapshot.run_player_id, snapshot.leader_member_id, eligible)
	var result_profile := profile.to_dictionary()
	result_profile["applied_transactions"] = {}
	profile.applied_transactions = {transaction: {
		"operation": "run_resolution",
		"fingerprint": ProfileMutationService._fingerprint("run_resolution", request.canonical_document()),
		"committed_at_unix": profile.updated_at_unix,
		"result_profile": result_profile,
		"receipt": {
			"schema_version": 1,
			"source_fingerprint": JSON.stringify(snapshot.resolution_source.to_dictionary(), "", true, true).sha256_text(),
			"request_fingerprint": JSON.stringify(request.canonical_document(), "", true, true).sha256_text(),
		},
	}}
	return profile

func _overflow_profile(snapshot: RunTerminalSnapshot, protected: bool) -> ProfileState:
	var profile := ProfileState.new_profile(PROFILE_ID, "Overflow", 1000)
	profile.inventory_columns = 1
	profile.item_records = ItemRegistry.new([_profile_item(ITEM_ID, 0)]).to_dictionary()
	profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-terminal", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, ItemSlotContainer.STASH_CAPACITY).to_dictionary()]
	profile.terminal_recovery_overflow = ItemSlotContainer.create(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, ItemSlotContainer.PROFILE_TERMINAL_RECOVERY_OVERFLOW, PROFILE_ID, EquipmentSlotIndex.capacity(), {0: ITEM_ID}).to_dictionary()
	if protected:
		var record_script := load("res://scripts/run/run_terminal_recovery_record.gd") as Script
		var selected_ids: Array[String] = []
		var protected_ids: Array[String] = [ITEM_ID]
		profile.terminal_resolution = record_script.call(&"create", 1, snapshot, selected_ids, "terminal-overflow-protection", protected_ids, "automatic extraction needs displaced gear protection", null, "").get("record").call(&"to_dictionary")
	return profile

func _fixture(live_newer: bool) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var empty_state := _run_state(false)
	var bootstrap := RunItemBootstrap.create(RUN_ID, RUN_SEED, RUN_PLAYER_ID, 1, empty_state, &"fighter")
	var profile := ProfileState.new_profile(PROFILE_ID, "Terminal Safety", 1000)
	profile.inventory_columns = 2; profile.extraction_capacity = 1; profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-terminal-safety", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100).to_dictionary()]
	var context := PlayerRunContext.new()
	assert(context.configure(RUN_PLAYER_ID, 0, profile, RUN_SEED, party, 100, bootstrap).is_empty())
	context._item_state = _run_state(true) if live_newer else empty_state.copy()
	if not live_newer:
		profile.resumable_run = ResumableRunItemCodec.encode(RunItemBootstrap.create(RUN_ID, RUN_SEED, RUN_PLAYER_ID, 1, context.item_state(), &"fighter"))
	return {"profile": profile, "context": context, "party": party}

func _run_state(with_item: bool) -> ItemOwnershipState:
	var items: Array[ItemInstance] = []
	if with_item:
		items.append(_run_item())
	return ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new(items), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10, {0: ITEM_ID} if with_item else {}),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity()),
		RunItemBootstrap.ground_items_container(String(RUN_PLAYER_ID)),
	])

func _run_state_pair() -> ItemOwnershipState:
	return ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new([_run_item(), _run_item_second()]), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10, {0: ITEM_ID, 1: ITEM_ID_SECOND}),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity()),
		RunItemBootstrap.ground_items_container(String(RUN_PLAYER_ID)),
	])

func _run_item() -> ItemInstance:
	var item := _profile_item(ITEM_ID, 0)
	item.origin["issuer_namespace"] = "run:%s:%d:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID]
	return item

func _run_state_high_precision() -> ItemOwnershipState:
	var item := _run_item()
	var roll := ItemModifierRoll.new()
	roll.stat_id = &"constitution"
	roll.operation = StatModifier.Operation.FLAT
	roll.value = 8.411670327186584
	var affix := ItemAffixInstance.new()
	affix.definition_id = &"stout"
	affix.affix_kind = "prefix"
	affix.tier = 3
	affix.rolls = [roll]
	item.affixes = [affix]
	return ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new([item]), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10, {0: ITEM_ID}),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity()),
		RunItemBootstrap.ground_items_container(String(RUN_PLAYER_ID)),
	])

func _run_item_second() -> ItemInstance:
	var item := _profile_item(ITEM_ID_SECOND, 1)
	item.origin["issuer_namespace"] = "run:%s:%d:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID]
	return item

func _profile_item(instance_id: String, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id; item.base_definition_id = &"forge_vanguard_sword"; item.item_level = 20; item.rarity_id = &"common"; item.affixes = []
	item.origin = {"issuer_namespace": "profile:%s" % PROFILE_ID, "seed": 77, "sequence": sequence, "source": "terminal_safety_test"}
	return item

func _set_nested(document: Dictionary, path: Array, value: Variant) -> void:
	var cursor := document
	for index: int in path.size() - 1:
		cursor = cursor[path[index]] as Dictionary
	cursor[path[-1]] = value

func _set_nested_variant(document: Dictionary, path: Array, value: Variant) -> void:
	var cursor: Variant = document
	for index: int in path.size() - 1:
		var key: Variant = path[index]
		cursor = (cursor as Dictionary)[key] if cursor is Dictionary else (cursor as Array)[int(key)]
	var last: Variant = path[-1]
	if cursor is Dictionary:
		(cursor as Dictionary)[last] = value
	else:
		(cursor as Array)[int(last)] = value

func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(value); file.close()

func _case_root(label: String) -> String:
	return "user://tests/run_terminal_safety_%d_%d_%s" % [OS.get_process_id(), Time.get_ticks_usec(), label]

func _ok(value: Variant) -> bool:
	return value != null and value.has_method(&"ok") and bool(value.call(&"ok"))

func _error(value: Variant) -> String:
	return String(value.get("error")) if value != null else ""

func _free_fixture(fixture: Dictionary, root: String) -> void:
	if not fixture.is_empty() and fixture.get("party") is PartyManager: (fixture.party as PartyManager).free()
	if not root.is_empty(): ProfileTestSupport.remove_tree(root)
