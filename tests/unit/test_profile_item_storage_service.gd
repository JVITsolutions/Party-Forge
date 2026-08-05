extends RefCounted

const PROFILE_ID := "profile-storage02"
const STASH_ID := &"stash-tab-000"
const LEADER_ID := &"leader-loadout"

var _root_counter := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists("res://scripts/profile/profile_item_storage_service.gd"):
		TestAssertions.truthy(false, "profile item storage service implementation exists", failures)
		return failures
	_test_persistent_create_replay_collision_and_defensive_results(failures)
	_test_create_preconditions_and_task_four_failures_are_atomic(failures)
	_test_injected_save_failure_is_atomic(failures)
	_test_non_create_preserves_sequence(failures)
	_test_leader_loadout_requests_are_rejected(failures)
	_test_persistent_sandbox_remove_is_rejected(failures)
	return failures

func _test_persistent_create_replay_collision_and_defensive_results(failures: Array[String]) -> void:
	var root := _case_root("create_replay")
	var store := ProfileStore.new()
	_save_profile(store, _empty_profile(), root, "create/replay fixture", failures)
	var service := ProfileItemStorageService.new(ProfileMutationService.new(store), ItemContainerTransactionService.new())
	var source_item := _item("item-persistent-create", 0)
	var request := ItemTransactionRequest.create("profile-item-create", PROFILE_ID, STASH_ID, 42, source_item)
	var request_before := request.canonical_document()
	source_item.instance_id = "mutated-after-request"
	source_item.origin["seed"] = "mutated-after-request"

	var created := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(created.ok() and not created.duplicate, "persistent create commits once", failures)
	var loaded := store.load_profile(PROFILE_ID, root)
	TestAssertions.truthy(loaded.ok(), "persistent create reloads", failures)
	if not loaded.ok():
		ProfileTestSupport.remove_tree(root)
		return
	var saved := loaded.profile
	TestAssertions.equal((saved.item_records["items"] as Array).size(), 1, "persistent create reloads one item", failures)
	TestAssertions.equal(saved.item_records["items"][0], request_before["create_item"], "persistent create preserves the complete requested item", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {"42": "item-persistent-create"}, "persistent create reloads one exact slot", failures)
	TestAssertions.equal(saved.next_item_sequence, 1, "successful create consumes exactly one sequence", failures)
	TestAssertions.equal(request.canonical_document(), request_before, "storage apply cannot mutate the canonical request", failures)
	var transaction := saved.applied_transactions["profile-item-create"] as Dictionary
	TestAssertions.equal(transaction["operation"], "item_storage_transaction", "outer durable journal uses the exact storage operation", failures)
	TestAssertions.equal(
		transaction["fingerprint"],
		ProfileMutationService._fingerprint("item_storage_transaction", request.canonical_document()),
		"outer journal fingerprints the complete canonical item request",
		failures
	)

	var committed_hash := _file_hash(store.profile_path(PROFILE_ID, root))
	var first_projection := created.profile.to_dictionary()
	created.profile.item_records["items"][0]["origin"]["seed"] = "escaped-first-result"
	created.profile.stash_tabs[0]["slots"].clear()
	TestAssertions.equal(store.load_profile(PROFILE_ID, root).profile.item_records["items"][0], request_before["create_item"], "successful result is deeply defensive from disk", failures)

	var replay := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(replay.ok() and replay.duplicate, "outer replay returns the committed projection as a duplicate", failures)
	TestAssertions.equal(replay.profile.to_dictionary(), first_projection, "outer replay returns the original committed projection", failures)
	TestAssertions.equal(_file_hash(store.profile_path(PROFILE_ID, root)), committed_hash, "outer replay performs no file write", failures)
	replay.profile.item_records["items"][0]["origin"]["seed"] = "escaped-replay-result"
	TestAssertions.equal(store.load_profile(PROFILE_ID, root).profile.item_records["items"][0], request_before["create_item"], "replay result is deeply defensive from disk", failures)

	var collision_request := ItemTransactionRequest.create("profile-item-create", PROFILE_ID, STASH_ID, 43, _item("item-persistent-create", 0))
	var collision := service.apply(PROFILE_ID, collision_request, root)
	_assert_failed_result(collision, "transaction id conflict", "outer transaction collision", failures)
	TestAssertions.equal(_file_hash(store.profile_path(PROFILE_ID, root)), committed_hash, "outer collision performs no file write", failures)
	TestAssertions.equal(store.load_profile(PROFILE_ID, root).profile.next_item_sequence, 1, "outer collision consumes no sequence", failures)
	ProfileTestSupport.remove_tree(root)

func _test_create_preconditions_and_task_four_failures_are_atomic(failures: Array[String]) -> void:
	var null_root := _case_root("null_request")
	var null_store := ProfileStore.new()
	_save_profile(null_store, _empty_profile(), null_root, "null request fixture", failures)
	var null_hash := _file_hash(null_store.profile_path(PROFILE_ID, null_root))
	var null_result := ProfileItemStorageService.new(ProfileMutationService.new(null_store)).apply(PROFILE_ID, null, null_root)
	_assert_failed_result(null_result, "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR", "null request", failures)
	TestAssertions.equal(_file_hash(null_store.profile_path(PROFILE_ID, null_root)), null_hash, "null request performs no file write", failures)
	ProfileTestSupport.remove_tree(null_root)

	var cases: Array[Dictionary] = [
		{
			"label": "owner mismatch",
			"request": ItemTransactionRequest.create("owner-mismatch", "profile-other002", STASH_ID, 0, _item("item-owner-mismatch", 0)),
			"expected": "code=UNKNOWN_OWNER",
		},
		{
			"label": "origin namespace mismatch",
			"request": ItemTransactionRequest.create("namespace-mismatch", PROFILE_ID, STASH_ID, 0, _item_with_origin("item-namespace-mismatch", "profile:profile-other002", 0)),
			"expected": "origin.issuer_namespace",
		},
		{
			"label": "origin sequence mismatch",
			"request": ItemTransactionRequest.create("sequence-mismatch", PROFILE_ID, STASH_ID, 0, _item("item-sequence-mismatch", 1)),
			"expected": "origin.sequence",
		},
		{
			"label": "fractional origin sequence",
			"request": ItemTransactionRequest.create("fractional-sequence", PROFILE_ID, STASH_ID, 0, _item_with_origin("item-fractional-sequence", "profile:%s" % PROFILE_ID, 0.5)),
			"expected": "origin.sequence",
		},
		{
			"label": "invalid destination",
			"request": ItemTransactionRequest.create("invalid-destination", PROFILE_ID, STASH_ID, 100, _item("item-invalid-destination", 0)),
			"expected": "code=SLOT_OUT_OF_BOUNDS",
		},
	]
	for test_case: Dictionary in cases:
		var root := _case_root(test_case["label"])
		var store := ProfileStore.new()
		_save_profile(store, _empty_profile(), root, "%s fixture" % test_case["label"], failures)
		var before_hash := _file_hash(store.profile_path(PROFILE_ID, root))
		var rejected := ProfileItemStorageService.new(ProfileMutationService.new(store)).apply(PROFILE_ID, test_case["request"], root)
		_assert_failed_result(rejected, test_case["expected"], test_case["label"], failures)
		TestAssertions.equal(_file_hash(store.profile_path(PROFILE_ID, root)), before_hash, "%s preserves the complete file hash" % test_case["label"], failures)
		TestAssertions.equal(store.load_profile(PROFILE_ID, root).profile.next_item_sequence, 0, "%s consumes no sequence" % test_case["label"], failures)
		ProfileTestSupport.remove_tree(root)

	var exhausted_root := _case_root("sequence_exhausted")
	var exhausted_store := ProfileStore.new()
	var exhausted_profile := _empty_profile()
	exhausted_profile.next_item_sequence = ProfileCodec.JSON_SAFE_INTEGER_MAX
	_save_profile(exhausted_store, exhausted_profile, exhausted_root, "sequence exhaustion fixture", failures)
	var exhausted_hash := _file_hash(exhausted_store.profile_path(PROFILE_ID, exhausted_root))
	var exhausted_request := ItemTransactionRequest.create("sequence-exhausted", PROFILE_ID, STASH_ID, 0, _item("item-sequence-exhausted", ProfileCodec.JSON_SAFE_INTEGER_MAX))
	var exhausted := ProfileItemStorageService.new(ProfileMutationService.new(exhausted_store)).apply(PROFILE_ID, exhausted_request, exhausted_root)
	_assert_failed_result(exhausted, "next_item_sequence", "sequence exhaustion", failures)
	TestAssertions.equal(_file_hash(exhausted_store.profile_path(PROFILE_ID, exhausted_root)), exhausted_hash, "sequence exhaustion performs no file write", failures)
	TestAssertions.equal(exhausted_store.load_profile(PROFILE_ID, exhausted_root).profile.next_item_sequence, ProfileCodec.JSON_SAFE_INTEGER_MAX, "sequence exhaustion consumes no sequence", failures)
	ProfileTestSupport.remove_tree(exhausted_root)

	var duplicate_root := _case_root("duplicate_instance")
	var duplicate_store := ProfileStore.new()
	var duplicate_profile := _profile_with_item(_item("item-duplicate-persistent", 0), 0, 1)
	_save_profile(duplicate_store, duplicate_profile, duplicate_root, "duplicate instance fixture", failures)
	var duplicate_hash := _file_hash(duplicate_store.profile_path(PROFILE_ID, duplicate_root))
	var duplicate_item := _item("item-duplicate-persistent", 1)
	var duplicate_request := ItemTransactionRequest.create("duplicate-instance", PROFILE_ID, STASH_ID, 1, duplicate_item)
	var duplicate := ProfileItemStorageService.new(ProfileMutationService.new(duplicate_store)).apply(PROFILE_ID, duplicate_request, duplicate_root)
	_assert_failed_result(duplicate, "code=DUPLICATE_INSTANCE", "duplicate instance", failures)
	TestAssertions.equal(_file_hash(duplicate_store.profile_path(PROFILE_ID, duplicate_root)), duplicate_hash, "duplicate instance performs no file write", failures)
	TestAssertions.equal(duplicate_store.load_profile(PROFILE_ID, duplicate_root).profile.next_item_sequence, 1, "duplicate instance consumes no sequence", failures)
	ProfileTestSupport.remove_tree(duplicate_root)

func _test_injected_save_failure_is_atomic(failures: Array[String]) -> void:
	var root := _case_root("save_failure")
	var good_store := ProfileStore.new()
	_save_profile(good_store, _empty_profile(), root, "save failure fixture", failures)
	var before_hash := _file_hash(good_store.profile_path(PROFILE_ID, root))
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var service := ProfileItemStorageService.new(ProfileMutationService.new(failing_store), ItemContainerTransactionService.new())
	var failed := service.apply(PROFILE_ID, ItemTransactionRequest.create("create-save-fails", PROFILE_ID, STASH_ID, 9, _item("item-save-fails", 0)), root)
	_assert_failed_result(failed, "JSON_STORE_SAVE_ERROR", "injected save failure", failures)
	TestAssertions.equal(_file_hash(good_store.profile_path(PROFILE_ID, root)), before_hash, "injected save failure preserves profile bytes", failures)
	var reloaded := good_store.load_profile(PROFILE_ID, root).profile
	TestAssertions.equal(reloaded.next_item_sequence, 0, "injected save failure consumes no sequence", failures)
	TestAssertions.equal(reloaded.item_records, {"schema_version": 1, "items": []}, "injected save failure persists no partial item", failures)
	TestAssertions.equal(reloaded.stash_tabs[0]["slots"], {}, "injected save failure persists no partial slot", failures)
	ProfileTestSupport.remove_tree(root)

func _test_non_create_preserves_sequence(failures: Array[String]) -> void:
	var root := _case_root("non_create")
	var store := ProfileStore.new()
	var item := _item("item-move-persistent", 6)
	var equipped := _item("item-equipped-preserved", 5)
	var profile := _empty_profile()
	profile.item_records = ItemRegistry.new([equipped, item]).to_dictionary()
	profile.set("leader_loadout", _loadout_document({9: equipped.instance_id}))
	profile.set("leader_loadout_class_id", "fighter")
	profile.stash_tabs = [_tab_document({0: item.instance_id})]
	profile.next_item_sequence = 7
	var loadout_before := profile.get("leader_loadout") as Dictionary
	_save_profile(store, profile, root, "non-create fixture", failures)
	var request := ItemTransactionRequest.move("move-persistent", PROFILE_ID, STASH_ID, 0, item.instance_id, STASH_ID, 99)
	var moved := ProfileItemStorageService.new(ProfileMutationService.new(store)).apply(PROFILE_ID, request, root)
	TestAssertions.truthy(moved.ok() and not moved.duplicate, "persistent non-create transaction commits", failures)
	var saved := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.equal(saved.next_item_sequence, 7, "non-create transaction preserves issuance sequence", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {"99": item.instance_id}, "non-create transaction preserves exact move placement", failures)
	TestAssertions.equal(saved.item_records["items"], [equipped.to_dictionary(), item.to_dictionary()], "non-create transaction preserves complete sorted item records", failures)
	TestAssertions.equal(saved.get("leader_loadout"), loadout_before, "stash-only transaction preserves the exact leader loadout", failures)
	TestAssertions.equal(saved.get("leader_loadout_class_id"), "fighter", "stash-only transaction preserves the leader class ID", failures)
	ProfileTestSupport.remove_tree(root)

func _test_leader_loadout_requests_are_rejected(failures: Array[String]) -> void:
	var root := _case_root("leader_loadout_rejected")
	var store := ProfileStore.new()
	var equipped := _item("item-equipped-rejected", 0)
	var stashed := _item("item-stashed-rejected", 1)
	var profile := _empty_profile()
	profile.item_records = ItemRegistry.new([equipped, stashed]).to_dictionary()
	profile.set("leader_loadout", _loadout_document({9: equipped.instance_id}))
	profile.set("leader_loadout_class_id", "fighter")
	profile.stash_tabs = [_tab_document({0: stashed.instance_id})]
	profile.next_item_sequence = 2
	_save_profile(store, profile, root, "leader-loadout policy fixture", failures)
	var path := store.profile_path(PROFILE_ID, root)
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var requests: Array[ItemTransactionRequest] = [
		ItemTransactionRequest.create("create-to-leader", PROFILE_ID, LEADER_ID, 0, _item("item-create-to-leader", 2)),
		ItemTransactionRequest.move("move-from-leader", PROFILE_ID, LEADER_ID, 9, equipped.instance_id, STASH_ID, 1),
		ItemTransactionRequest.move("move-to-leader", PROFILE_ID, STASH_ID, 0, stashed.instance_id, LEADER_ID, 0),
		ItemTransactionRequest.swap("swap-with-leader", PROFILE_ID, STASH_ID, 0, stashed.instance_id, LEADER_ID, 9),
	]
	var service := ProfileItemStorageService.new(ProfileMutationService.new(store))
	for request: ItemTransactionRequest in requests:
		var rejected := service.apply(PROFILE_ID, request, root)
		_assert_failed_result(rejected, "leader-loadout", request.transaction_id, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "%s preserves exact profile bytes" % request.transaction_id, failures)
	var saved := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.equal(saved.get("leader_loadout"), _loadout_document({9: equipped.instance_id}), "rejected generic requests preserve leader placement", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {"0": stashed.instance_id}, "rejected generic requests preserve stash placement", failures)
	TestAssertions.equal(saved.next_item_sequence, 2, "rejected generic requests consume no sequence", failures)
	TestAssertions.equal(saved.applied_transactions, {}, "rejected generic requests record no durable transactions", failures)
	ProfileTestSupport.remove_tree(root)

func _test_persistent_sandbox_remove_is_rejected(failures: Array[String]) -> void:
	var root := _case_root("sandbox_remove_rejected")
	var store := ProfileStore.new()
	var item := _item("item-persistent-remove-forbidden", 0)
	var profile := _profile_with_item(item, 37, 1)
	_save_profile(store, profile, root, "persistent sandbox-remove fixture", failures)
	var path := store.profile_path(PROFILE_ID, root)
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var before_hash := _file_hash(path)
	var request := ItemTransactionRequest.sandbox_remove(
		"persistent-remove-forbidden",
		PROFILE_ID,
		STASH_ID,
		37,
		item.instance_id
	)
	var rejected := ProfileItemStorageService.new(ProfileMutationService.new(store)).apply(PROFILE_ID, request, root)
	var expected_error := "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.operation reason=unsupported persistent operation sandbox_remove"
	TestAssertions.equal(rejected.error, expected_error, "persistent sandbox remove reports the stable production-policy error", failures)
	_assert_failed_result(rejected, expected_error, "persistent sandbox remove", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "persistent sandbox remove preserves exact profile bytes", failures)
	TestAssertions.equal(_file_hash(path), before_hash, "persistent sandbox remove preserves the profile file hash", failures)
	var saved := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.equal(saved.item_records["items"], [item.to_dictionary()], "persistent sandbox remove preserves the item record", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {"37": item.instance_id}, "persistent sandbox remove preserves the exact slot", failures)
	TestAssertions.equal(saved.next_item_sequence, 1, "persistent sandbox remove preserves the issuance sequence", failures)
	TestAssertions.truthy(not saved.applied_transactions.has("persistent-remove-forbidden"), "persistent sandbox remove records no durable transaction", failures)
	ProfileTestSupport.remove_tree(root)

func _assert_failed_result(result: ProfileMutationResult, expected_text: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not result.ok(), "%s is rejected" % label, failures)
	TestAssertions.equal(result.profile, null, "%s exposes no partial profile" % label, failures)
	TestAssertions.truthy(result.error.contains(expected_text), "%s reports %s" % [label, expected_text], failures)
	TestAssertions.truthy(not result.duplicate, "%s is not a duplicate success" % label, failures)

func _empty_profile() -> ProfileState:
	var profile := ProfileState.new_profile(PROFILE_ID, "Item Storage Tester", 1000)
	profile.stash_tabs = [_tab_document({})]
	return profile

func _profile_with_item(item: ItemInstance, slot: int, next_sequence: int) -> ProfileState:
	var profile := _empty_profile()
	profile.item_records = ItemRegistry.new([item]).to_dictionary()
	profile.stash_tabs = [_tab_document({slot: item.instance_id})]
	profile.next_item_sequence = next_sequence
	return profile

func _tab_document(slots: Dictionary) -> Dictionary:
	return ItemSlotContainer.create(STASH_ID, ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, slots).to_dictionary()

func _loadout_document(slots: Dictionary) -> Dictionary:
	return ItemSlotContainer.create(LEADER_ID, ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, 11, slots).to_dictionary()

func _item(instance_id: String, sequence: int) -> ItemInstance:
	return _item_with_origin(instance_id, "profile:%s" % PROFILE_ID, sequence)

func _item_with_origin(instance_id: String, namespace_value: String, sequence_value: Variant) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = &"forge_vanguard_sword"
	item.item_level = 28
	item.rarity_id = &"common"
	item.origin = {
		"issuer_namespace": namespace_value,
		"seed": 4402,
		"sequence": sequence_value,
		"source": "profile_storage_test",
	}
	return item

func _save_profile(store: ProfileStore, profile: ProfileState, root: String, label: String, failures: Array[String]) -> void:
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "%s saves" % label, failures)

func _file_hash(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()

func _case_root(label: String) -> String:
	_root_counter += 1
	return "user://tests/profile_item_storage_%s_%d_%d_%d" % [label.validate_filename(), OS.get_process_id(), Time.get_ticks_usec(), _root_counter]
