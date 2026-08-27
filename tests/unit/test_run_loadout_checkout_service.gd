extends RefCounted

const PROFILE_ID := "profile-checkout01"
const RUN_ID := &"run-checkout-001"
const RUN_PLAYER_ID := &"run-player-001"
const LEADER_MEMBER_ID := 1
const CURRENT_RECOVERY_FIELDS: Array[String] = [
	"item_state", "leader_member_id", "run_id", "run_player_id", "run_seed", "selected_leader_class_id",
]

var _root_counter := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_request_bootstrap_and_codec_are_exact_and_defensive(failures)
	_test_profile_codec_rejects_malformed_or_duplicate_strict_run_ownership(failures)
	_test_checkout_transfers_exact_instances_once_and_replays_without_writing(failures)
	_test_checkout_empty_and_without_gear_contracts(failures)
	_test_checkout_rejections_and_save_failure_preserve_bytes(failures)
	_test_recovered_class_validation_reuses_checkout_rules_without_mutation(failures)
	_test_forfeit_is_atomic_replay_safe_and_never_uses_sandbox_remove(failures)
	return failures

func _test_profile_codec_rejects_malformed_or_duplicate_strict_run_ownership(failures: Array[String]) -> void:
	var duplicate_container_state := ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new(), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10),
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10),
	])
	var duplicate_container_bootstrap := RunItemBootstrap.create(RUN_ID, 4402, RUN_PLAYER_ID, LEADER_MEMBER_ID, duplicate_container_state)
	TestAssertions.truthy(
		not duplicate_container_bootstrap.item_state().validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).is_empty(),
		"ground bootstrap normalization cannot erase prior state construction errors",
		failures,
	)
	var item := _item("item-cross-domain-duplicate", &"forge_vanguard_sword", 0)
	var profile := _profile_with_loadout([item], {9: item.instance_id}, {}, "fighter")
	profile.resumable_run = ResumableRunItemCodec.encode(
		RunItemBootstrap.create(RUN_ID, 4402, RUN_PLAYER_ID, LEADER_MEMBER_ID, _run_state([item], {9: item.instance_id}))
	)
	var duplicate_error := ProfileCodec.validate_profile(profile)
	TestAssertions.truthy(duplicate_error.contains("also owned by profile storage"), "profile codec rejects duplicate instance ownership across profile and strict run domains", failures)
	var malformed := _profile_with_loadout([], {}, {}, "fighter")
	malformed.resumable_run = ResumableRunItemCodec.encode(
		RunItemBootstrap.create(RUN_ID, 4402, RUN_PLAYER_ID, LEADER_MEMBER_ID, _run_state([], {}))
	)
	malformed.resumable_run["unexpected"] = true
	var malformed_error := ProfileCodec.validate_profile(malformed)
	TestAssertions.truthy(malformed_error.contains("field=resumable_run") and malformed_error.contains("unexpected"), "profile codec selects strict exact-field validation when item_state is present", failures)

func _test_request_bootstrap_and_codec_are_exact_and_defensive(failures: Array[String]) -> void:
	var request := _request("checkout-defensive", true)
	var canonical := request.canonical_document()
	TestAssertions.equal(canonical.keys(), [
		"bring_in_gear",
		"leader_member_id",
		"profile_id",
		"run_id",
		"run_player_id",
		"run_seed",
		"selected_leader_class_id",
		"transaction_id",
	], "checkout request emits the exact canonical field set", failures)
	canonical["run_id"] = "escaped-request"
	TestAssertions.equal(request.canonical_document()["run_id"], String(RUN_ID), "canonical request result is defensive", failures)

	var source_state := _run_state([], {})
	var bootstrap := RunItemBootstrap.create(RUN_ID, 4402, RUN_PLAYER_ID, LEADER_MEMBER_ID, source_state, &"fighter")
	source_state.owner_id = "escaped-source"
	TestAssertions.equal(bootstrap.item_state().owner_id, String(RUN_PLAYER_ID), "bootstrap owns a defensive input state", failures)
	TestAssertions.equal(bootstrap.selected_leader_class_id, &"fighter", "bootstrap preserves the selected leader class", failures)
	var exposed := bootstrap.item_state()
	exposed.owner_id = "escaped-result"
	TestAssertions.equal(bootstrap.item_state().owner_id, String(RUN_PLAYER_ID), "bootstrap returns a defensive state", failures)
	var encoded := ResumableRunItemCodec.encode(bootstrap)
	var encoded_fields := encoded.keys()
	encoded_fields.sort()
	var expected_fields := CURRENT_RECOVERY_FIELDS.duplicate()
	expected_fields.sort()
	TestAssertions.equal(encoded_fields, expected_fields, "recovery fields are exact", failures)
	TestAssertions.equal(encoded.get("selected_leader_class_id", "missing"), "fighter", "recovery persists leader class", failures)
	var decoded := ResumableRunItemCodec.decode(encoded, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(decoded != null, "exact resumable bootstrap decodes", failures)
	if decoded != null:
		TestAssertions.equal(ResumableRunItemCodec.encode(decoded), encoded, "resumable bootstrap round trips exactly", failures)
		var decoded_state := decoded.item_state()
		decoded_state.owner_id = "escaped-decoded"
		TestAssertions.equal(decoded.item_state().owner_id, String(RUN_PLAYER_ID), "decoded bootstrap remains defensive", failures)
	var extra := encoded.duplicate(true)
	extra["profile_id"] = PROFILE_ID
	TestAssertions.equal(ResumableRunItemCodec.decode(extra, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG), null, "resumable codec rejects an extra profile field", failures)
	var missing := encoded.duplicate(true)
	missing.erase("selected_leader_class_id")
	TestAssertions.equal(ResumableRunItemCodec.decode(missing, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG), null, "resumable codec rejects a missing current field", failures)
	var non_string_class := encoded.duplicate(true)
	non_string_class["selected_leader_class_id"] = 7
	TestAssertions.equal(ResumableRunItemCodec.decode(non_string_class, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG), null, "resumable codec rejects a non-string leader class", failures)
	var malformed := encoded.duplicate(true)
	(malformed["item_state"] as Dictionary)["owner_id"] = "wrong-owner"
	TestAssertions.equal(ResumableRunItemCodec.decode(malformed, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG), null, "resumable codec rejects ownership identity drift", failures)

func _test_checkout_transfers_exact_instances_once_and_replays_without_writing(failures: Array[String]) -> void:
	var root := _case_root("checkout_success")
	var store := ProfileStore.new()
	var sword := _item("item-checkout-sword", &"forge_vanguard_sword", 0)
	var shield := _item("item-checkout-shield", &"forge_vanguard_shield", 1)
	var stashed := _item("item-checkout-stashed", &"forge_vanguard_armour", 2)
	var profile := _profile_with_loadout([sword, shield, stashed], {9: sword.instance_id, 10: shield.instance_id}, {7: stashed.instance_id}, "fighter")
	_save_profile(store, profile, root, "checkout fixture", failures)
	var service := RunLoadoutCheckoutService.new(ProfileMutationService.new(store))
	var request := _request("checkout-transfer", true)
	var request_before := request.canonical_document()
	var committed := service.checkout(PROFILE_ID, request, root)
	TestAssertions.truthy(committed.ok() and not committed.duplicate, "loadout checkout commits once", failures)
	TestAssertions.equal(committed.profile.resumable_run.get("selected_leader_class_id", "missing") if committed.profile != null else "missing", String(request.selected_leader_class_id), "checkout persists the authoritative requested leader class", failures)
	var loaded := store.load_profile(PROFILE_ID, root)
	TestAssertions.truthy(loaded.ok(), "checked-out profile reloads", failures)
	if not loaded.ok():
		ProfileTestSupport.remove_tree(root)
		return
	var saved := loaded.profile
	TestAssertions.equal(saved.leader_loadout["slots"], {}, "checkout empties the durable leader loadout", failures)
	TestAssertions.equal(saved.leader_loadout_class_id, "fighter", "checkout retains the selected loadout class", failures)
	TestAssertions.equal((saved.item_records["items"] as Array), [stashed.to_dictionary()], "checkout removes only equipped instances from the profile registry", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {"7": stashed.instance_id}, "checkout preserves unrelated stash placement", failures)
	TestAssertions.equal(request.canonical_document(), request_before, "checkout cannot mutate its request", failures)
	var bootstrap := service.bootstrap_from(committed.profile)
	TestAssertions.truthy(bootstrap != null, "successful checkout exposes a strict bootstrap from its committed profile", failures)
	if bootstrap != null:
		var state := bootstrap.item_state()
		TestAssertions.equal(state.registry().ids(), [shield.instance_id, sword.instance_id], "run registry owns the exact checked-out instances", failures)
		TestAssertions.equal(state.container(&"run-equipment-001").to_dictionary()["slots"], {"9": sword.instance_id, "10": shield.instance_id}, "leader run equipment preserves exact slot placement", failures)
		TestAssertions.equal(state.container(&"run-inventory").occupied_slots(), [], "checkout bootstrap begins with an empty run inventory", failures)
		var ground := state.container(&"run-ground-items")
		TestAssertions.truthy(ground != null, "checkout bootstrap includes run-ground ownership", failures)
		if ground != null:
			TestAssertions.equal(ground.container_kind, &"run_ground_items", "checkout ground kind is exact", failures)
			TestAssertions.equal(ground.capacity, 2048, "checkout ground capacity is exact", failures)
			TestAssertions.equal(ground.occupied_slots(), [], "checkout bootstrap begins with empty ground", failures)
		TestAssertions.equal(state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG), "", "checked-out run ownership is strict", failures)
	var saved_ids: Array[String] = []
	for item_document: Dictionary in saved.item_records["items"] as Array:
		saved_ids.append(String(item_document["instance_id"]))
	var run_ids := bootstrap.item_state().registry().ids() if bootstrap != null else []
	for instance_id: String in run_ids:
		TestAssertions.truthy(instance_id not in saved_ids, "checked-out instance %s has one durable ownership domain" % instance_id, failures)

	var path := store.profile_path(PROFILE_ID, root)
	var committed_bytes := FileAccess.get_file_as_bytes(path)
	var committed_hash := _file_hash(path)
	committed.profile.resumable_run.clear()
	TestAssertions.truthy(not store.load_profile(PROFILE_ID, root).profile.resumable_run.is_empty(), "checkout result profile is defensive from disk", failures)
	var replay := service.checkout(PROFILE_ID, request, root)
	TestAssertions.truthy(replay.ok() and replay.duplicate, "exact checkout replay returns duplicate success", failures)
	TestAssertions.equal(replay.profile.resumable_run.get("selected_leader_class_id", "missing") if replay.profile != null else "missing", String(request.selected_leader_class_id), "checkout replay returns the same persisted leader class", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), committed_bytes, "checkout replay performs no write", failures)
	TestAssertions.equal(_file_hash(path), committed_hash, "checkout replay preserves the exact file hash", failures)
	TestAssertions.truthy(service.bootstrap_from(replay.profile) != null, "checkout replay reconstructs its bootstrap from the committed projection", failures)
	var collision_request := _request("checkout-transfer", true, &"run-checkout-collision")
	_assert_failure(service.checkout(PROFILE_ID, collision_request, root), "transaction id conflict", "checkout collision", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), committed_bytes, "checkout collision preserves exact profile bytes", failures)
	var active_request := _request("checkout-active-run", true, &"run-checkout-active")
	_assert_failure(service.checkout(PROFILE_ID, active_request, root), "active resumable run", "active run checkout", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), committed_bytes, "active run rejection preserves exact profile bytes", failures)
	ProfileTestSupport.remove_tree(root)

func _test_checkout_empty_and_without_gear_contracts(failures: Array[String]) -> void:
	var empty_root := _case_root("empty_loadout")
	var empty_store := ProfileStore.new()
	var empty_profile := _profile_with_loadout([], {}, {}, "fighter")
	_save_profile(empty_store, empty_profile, empty_root, "empty checkout fixture", failures)
	var empty_service := RunLoadoutCheckoutService.new(ProfileMutationService.new(empty_store))
	var empty_result := empty_service.checkout(PROFILE_ID, _request("checkout-empty", true), empty_root)
	TestAssertions.truthy(empty_result.ok(), "empty leader loadout checks out successfully", failures)
	var empty_bootstrap := empty_service.bootstrap_from(empty_result.profile)
	TestAssertions.truthy(empty_bootstrap != null and empty_bootstrap.item_state().registry().size() == 0, "empty loadout creates an empty strict run bootstrap", failures)
	ProfileTestSupport.remove_tree(empty_root)

	var no_gear_root := _case_root("without_gear")
	var no_gear_store := ProfileStore.new()
	var sword := _item("item-left-at-home", &"forge_vanguard_sword", 0)
	var no_gear_profile := _profile_with_loadout([sword], {9: sword.instance_id}, {}, "fighter")
	var loadout_before := no_gear_profile.leader_loadout.duplicate(true)
	var records_before := no_gear_profile.item_records.duplicate(true)
	_save_profile(no_gear_store, no_gear_profile, no_gear_root, "without gear fixture", failures)
	var no_gear_service := RunLoadoutCheckoutService.new(ProfileMutationService.new(no_gear_store))
	var no_gear_request := RunLoadoutCheckoutRequest.create(
		"checkout-without-gear", PROFILE_ID, RUN_ID, 4402, RUN_PLAYER_ID, LEADER_MEMBER_ID, &"mage", false
	)
	var no_gear_result := no_gear_service.checkout(PROFILE_ID, no_gear_request, no_gear_root)
	TestAssertions.truthy(no_gear_result.ok(), "absent bring-in-gear succeeds without class transition", failures)
	var no_gear_saved := no_gear_store.load_profile(PROFILE_ID, no_gear_root).profile
	TestAssertions.equal(no_gear_saved.leader_loadout, loadout_before, "absent bring-in-gear leaves leader placement untouched", failures)
	TestAssertions.equal(no_gear_saved.leader_loadout_class_id, "fighter", "absent bring-in-gear leaves leader class untouched", failures)
	TestAssertions.equal(no_gear_saved.item_records, records_before, "absent bring-in-gear leaves profile items untouched", failures)
	var no_gear_bootstrap := no_gear_service.bootstrap_from(no_gear_result.profile)
	TestAssertions.truthy(no_gear_bootstrap != null and no_gear_bootstrap.item_state().registry().size() == 0, "absent bring-in-gear creates an empty run bootstrap", failures)
	ProfileTestSupport.remove_tree(no_gear_root)

func _test_checkout_rejections_and_save_failure_preserve_bytes(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"label": "wrong method profile", "method_profile": "profile-checkout-other", "request": _request("wrong-method-profile", true), "expected": "profile identity"},
		{"label": "wrong request profile", "method_profile": PROFILE_ID, "request": RunLoadoutCheckoutRequest.create("wrong-request-profile", "profile-checkout-other", RUN_ID, 4402, RUN_PLAYER_ID, 1, &"fighter", true), "expected": "profile identity"},
		{"label": "wrong selected class", "method_profile": PROFILE_ID, "request": RunLoadoutCheckoutRequest.create("wrong-class", PROFILE_ID, RUN_ID, 4402, RUN_PLAYER_ID, 1, &"mage", true), "expected": "leader class"},
	]
	for test_case: Dictionary in cases:
		var root := _case_root(test_case["label"])
		var store := ProfileStore.new()
		var sword := _item("item-%s" % String(test_case["label"]).validate_filename(), &"forge_vanguard_sword", 0)
		_save_profile(store, _profile_with_loadout([sword], {9: sword.instance_id}, {}, "fighter"), root, "%s fixture" % test_case["label"], failures)
		var path := store.profile_path(PROFILE_ID, root)
		var before := FileAccess.get_file_as_bytes(path)
		var rejected := RunLoadoutCheckoutService.new(ProfileMutationService.new(store)).checkout(test_case["method_profile"], test_case["request"], root)
		_assert_failure(rejected, test_case["expected"], test_case["label"], failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(path), before, "%s preserves exact profile bytes" % test_case["label"], failures)
		ProfileTestSupport.remove_tree(root)

	var eligibility_root := _case_root("ineligible_loadout")
	var eligibility_store := ProfileStore.new()
	var vestments := _item("item-ineligible-fighter", &"storm_chaplain_vestments", 0)
	_save_profile(eligibility_store, _profile_with_loadout([vestments], {1: vestments.instance_id}, {}, "fighter"), eligibility_root, "ineligible fixture", failures)
	var eligibility_path := eligibility_store.profile_path(PROFILE_ID, eligibility_root)
	var eligibility_before := FileAccess.get_file_as_bytes(eligibility_path)
	var ineligible := RunLoadoutCheckoutService.new(ProfileMutationService.new(eligibility_store)).checkout(PROFILE_ID, _request("ineligible-loadout", true), eligibility_root)
	_assert_failure(ineligible, "ineligible", "class-incompatible loadout", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(eligibility_path), eligibility_before, "eligibility rejection preserves exact profile bytes", failures)
	ProfileTestSupport.remove_tree(eligibility_root)

	var incomplete_root := _case_root("incomplete_loadout")
	var incomplete_store := ProfileStore.new()
	var quiver := _item("item-quiver-without-bow", &"greenwood_light_quiver", 0)
	_save_profile(incomplete_store, _profile_with_loadout([quiver], {10: quiver.instance_id}, {}, "ranger"), incomplete_root, "incomplete loadout fixture", failures)
	var incomplete_path := incomplete_store.profile_path(PROFILE_ID, incomplete_root)
	var incomplete_before := FileAccess.get_file_as_bytes(incomplete_path)
	var incomplete_request := RunLoadoutCheckoutRequest.create(
		"incomplete-loadout", PROFILE_ID, RUN_ID, 4402, RUN_PLAYER_ID, LEADER_MEMBER_ID, &"ranger", true
	)
	var incomplete := RunLoadoutCheckoutService.new(ProfileMutationService.new(incomplete_store)).checkout(PROFILE_ID, incomplete_request, incomplete_root)
	_assert_failure(incomplete, "ineligible", "incomplete quiver loadout", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(incomplete_path), incomplete_before, "incomplete loadout rejection preserves exact profile bytes", failures)
	ProfileTestSupport.remove_tree(incomplete_root)

	var save_root := _case_root("checkout_save_failure")
	var good_store := ProfileStore.new()
	var save_item := _item("item-checkout-save-failure", &"forge_vanguard_sword", 0)
	_save_profile(good_store, _profile_with_loadout([save_item], {9: save_item.instance_id}, {}, "fighter"), save_root, "save failure fixture", failures)
	var save_path := good_store.profile_path(PROFILE_ID, save_root)
	var save_before := FileAccess.get_file_as_bytes(save_path)
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var failed := RunLoadoutCheckoutService.new(ProfileMutationService.new(failing_store)).checkout(PROFILE_ID, _request("checkout-save-failure", true), save_root)
	_assert_failure(failed, "JSON_STORE_SAVE_ERROR", "checkout save failure", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(save_path), save_before, "checkout save failure preserves exact bytes", failures)
	TestAssertions.equal(good_store.load_profile(PROFILE_ID, save_root).profile.resumable_run, {}, "checkout save failure persists no run bootstrap", failures)
	ProfileTestSupport.remove_tree(save_root)

func _test_recovered_class_validation_reuses_checkout_rules_without_mutation(failures: Array[String]) -> void:
	var service := RunLoadoutCheckoutService.new()
	TestAssertions.equal(service.validate_recovered_class(null, &"fighter"), "PARTY_FORGE_RUN_RECOVERY_ERROR field=bootstrap reason=unavailable", "recovered-class validation rejects an unavailable bootstrap exactly", failures)
	var missing_leader_state := ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new(), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10),
		RunItemBootstrap.ground_items_container(String(RUN_PLAYER_ID)),
	])
	var missing_leader := RunItemBootstrap.create(RUN_ID, 4402, RUN_PLAYER_ID, LEADER_MEMBER_ID, missing_leader_state, &"fighter")
	TestAssertions.equal(service.validate_recovered_class(missing_leader, &"fighter"), "PARTY_FORGE_RUN_RECOVERY_ERROR field=leader_equipment reason=missing", "recovered-class validation requires the exact leader equipment container", failures)

	var empty := RunItemBootstrap.create(RUN_ID, 4402, RUN_PLAYER_ID, LEADER_MEMBER_ID, _run_state([], {}), &"fighter")
	var empty_before := empty.item_state().to_dictionary()
	TestAssertions.equal(service.validate_recovered_class(empty, &"unknown_class"), "PARTY_FORGE_RUN_RECOVERY_ERROR field=selected_leader_class_id reason=unknown leader class", "recovered-class validation reports unknown catalog class exactly", failures)
	TestAssertions.equal(service.validate_recovered_class(empty, &"fighter"), "", "recovered-class validation accepts an eligible empty loadout", failures)
	TestAssertions.equal(empty.item_state().to_dictionary(), empty_before, "recovered-class validation leaves bootstrap item state unchanged", failures)

	var vestments := _item("item-recovered-incompatible", &"storm_chaplain_vestments", 0)
	var incompatible := RunItemBootstrap.create(RUN_ID, 4402, RUN_PLAYER_ID, LEADER_MEMBER_ID, _run_state([vestments], {1: vestments.instance_id}), &"fighter")
	var incompatibility := service.validate_recovered_class(incompatible, &"fighter")
	TestAssertions.truthy(incompatibility.begins_with("PARTY_FORGE_RUN_RECOVERY_ERROR") and incompatibility.contains("ineligible"), "recovered-class validation reuses checkout equipment eligibility with recovery prefix", failures)
	TestAssertions.truthy(not incompatibility.contains("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR"), "recovered-class validation exposes no checkout-prefixed diagnostic", failures)

func _test_forfeit_is_atomic_replay_safe_and_never_uses_sandbox_remove(failures: Array[String]) -> void:
	var source_text := FileAccess.get_file_as_string("res://scripts/run/run_loadout_checkout_service.gd")
	TestAssertions.truthy(not source_text.contains("SANDBOX_REMOVE") and not source_text.contains("sandbox_remove"), "forfeit implementation does not call or expose sandbox remove", failures)
	var root := _case_root("forfeit")
	var store := ProfileStore.new()
	var sword := _item("item-forfeit-sword", &"forge_vanguard_sword", 0)
	_save_profile(store, _profile_with_loadout([], {}, {}, "fighter"), root, "forfeit source fixture", failures)
	var unrelated := ProfileMutationService.new(store).grant_gold(PROFILE_ID, "forfeit-unrelated-gold", 1, root)
	TestAssertions.truthy(unrelated.ok(), "forfeit fixture records history before the doomed item exists", failures)
	var unrelated_record_before := (store.load_profile(PROFILE_ID, root).profile.applied_transactions["forfeit-unrelated-gold"] as Dictionary).duplicate(true)
	var equipped := store.load_profile(PROFILE_ID, root).profile
	equipped.item_records = ItemRegistry.new([sword]).to_dictionary()
	equipped.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, EquipmentSlotIndex.capacity(), {9: sword.instance_id}
	).to_dictionary()
	TestAssertions.equal(store.save_profile(equipped, root), "", "forfeit fixture equips the future run item", failures)
	var pre_checkout := ProfileMutationService.new(store).grant_gold(PROFILE_ID, "forfeit-pre-checkout-gold", 1, root)
	TestAssertions.truthy(pre_checkout.ok(), "forfeit fixture records a pre-checkout transaction containing the future run item", failures)
	var service := RunLoadoutCheckoutService.new(ProfileMutationService.new(store))
	var checkout := service.checkout(PROFILE_ID, _request("forfeit-checkout", true), root)
	TestAssertions.truthy(checkout.ok(), "forfeit fixture checks out", failures)
	var checkout_record_before := (store.load_profile(PROFILE_ID, root).profile.applied_transactions["forfeit-checkout"] as Dictionary).duplicate(true)
	var path := store.profile_path(PROFILE_ID, root)
	var active_bytes := FileAccess.get_file_as_bytes(path)
	var wrong := service.forfeit(PROFILE_ID, &"run-stale-001", root)
	_assert_failure(wrong, "run identity", "stale forfeit", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), active_bytes, "stale forfeit preserves strict run and items", failures)

	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var failed_save := RunLoadoutCheckoutService.new(ProfileMutationService.new(failing_store)).forfeit(PROFILE_ID, RUN_ID, root)
	_assert_failure(failed_save, "JSON_STORE_SAVE_ERROR", "forfeit save failure", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), active_bytes, "forfeit save failure preserves strict run and items", failures)

	var forfeited := service.forfeit(PROFILE_ID, RUN_ID, root)
	TestAssertions.truthy(forfeited.ok() and not forfeited.duplicate, "matching full-death forfeit commits once", failures)
	var saved := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.equal(saved.resumable_run, {}, "forfeit clears the entire matching resumable run", failures)
	TestAssertions.equal(saved.item_records["items"], [], "forfeit never reconstructs checked-out items in profile storage", failures)
	var checkout_record := saved.applied_transactions.get("forfeit-checkout", {}) as Dictionary
	TestAssertions.truthy(not checkout_record.is_empty(), "forfeit preserves the checkout idempotency record", failures)
	for immutable_field: String in ["operation", "fingerprint", "committed_at_unix"]:
		TestAssertions.equal(checkout_record.get(immutable_field), checkout_record_before.get(immutable_field), "forfeit preserves checkout transaction %s" % immutable_field, failures)
	var checkout_snapshot := checkout_record.get("result_profile", {}) as Dictionary
	TestAssertions.equal(checkout_snapshot.get("resumable_run", {}), {}, "forfeit revokes the checked-out run from the historical checkout result", failures)
	TestAssertions.equal(saved.applied_transactions.get("forfeit-unrelated-gold", {}), unrelated_record_before, "forfeit leaves unrelated historical results byte-for-byte equivalent", failures)
	var forfeited_bytes := FileAccess.get_file_as_bytes(path)
	var forfeited_text := FileAccess.get_file_as_string(path)
	TestAssertions.truthy(not forfeited_text.contains(sword.instance_id), "forfeit removes checked-out instance ids from all durable profile history", failures)
	TestAssertions.truthy(not forfeited_text.contains("\"item_state\""), "forfeit removes strict run item state from all durable profile history", failures)
	var backup_path := "%s.bak" % path
	TestAssertions.truthy(FileAccess.file_exists(backup_path), "forfeit retains a valid recovery generation", failures)
	var backup_text := FileAccess.get_file_as_string(backup_path)
	TestAssertions.truthy(not backup_text.contains(sword.instance_id) and not backup_text.contains("\"item_state\""), "forfeit recovery generation contains no doomed run items", failures)
	var directory := DirAccess.open(root)
	if directory != null:
		for file_name: String in directory.get_files():
			var artifact_text := FileAccess.get_file_as_string(root.path_join(file_name))
			TestAssertions.truthy(not artifact_text.contains(sword.instance_id), "forfeit artifact %s contains no doomed item id" % file_name, failures)
	var checkout_replay := service.checkout(PROFILE_ID, _request("forfeit-checkout", true), root)
	TestAssertions.truthy(checkout_replay.ok() and checkout_replay.duplicate, "forfeited checkout still replays as a duplicate", failures)
	TestAssertions.equal(service.bootstrap_from(checkout_replay.profile), null, "forfeited checkout replay cannot reconstruct a usable bootstrap", failures)
	TestAssertions.truthy(not JSON.stringify(checkout_replay.profile.to_dictionary()).contains(sword.instance_id), "forfeited checkout replay exposes no lost item instance", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), forfeited_bytes, "forfeited checkout replay performs no write", failures)
	var pre_checkout_replay := ProfileMutationService.new(store).grant_gold(PROFILE_ID, "forfeit-pre-checkout-gold", 1, root)
	TestAssertions.truthy(pre_checkout_replay.ok() and pre_checkout_replay.duplicate, "affected pre-checkout transaction keeps duplicate replay semantics", failures)
	TestAssertions.truthy(not JSON.stringify(pre_checkout_replay.profile.to_dictionary()).contains(sword.instance_id), "pre-checkout replay cannot recover a forfeited item", failures)
	TestAssertions.equal(service.bootstrap_from(pre_checkout_replay.profile), null, "pre-checkout replay cannot recover the forfeited run bootstrap", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), forfeited_bytes, "affected pre-checkout replay performs no write", failures)
	var replay := service.forfeit(PROFILE_ID, RUN_ID, root)
	TestAssertions.truthy(replay.ok() and replay.duplicate, "matching forfeit replay is duplicate success", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), forfeited_bytes, "forfeit replay performs no write", failures)
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("corrupt forfeited primary")
		corrupt.close()
	var recovered := store.load_profile(PROFILE_ID, root)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "corrupt forfeited primary recovers the sanitized generation", failures)
	if recovered.ok():
		TestAssertions.equal(recovered.profile.resumable_run, {}, "recovered forfeited generation has no run bootstrap", failures)
		TestAssertions.truthy(not JSON.stringify(recovered.profile.to_dictionary()).contains(sword.instance_id), "recovered forfeited generation has no doomed item", failures)

	var collision_root := _case_root("forfeit_collision")
	var collision_store := ProfileStore.new()
	var collision_item := _item("item-forfeit-collision", &"forge_vanguard_sword", 0)
	_save_profile(collision_store, _profile_with_loadout([collision_item], {9: collision_item.instance_id}, {}, "fighter"), collision_root, "forfeit collision source", failures)
	var collision_service := RunLoadoutCheckoutService.new(ProfileMutationService.new(collision_store))
	TestAssertions.truthy(collision_service.checkout(PROFILE_ID, _request("collision-checkout", true), collision_root).ok(), "forfeit collision fixture checks out", failures)
	var seeded := ProfileMutationService.new(collision_store).apply(
		PROFILE_ID,
		"forfeit:%s" % RUN_ID,
		func(_candidate: ProfileState) -> String: return "",
		collision_root,
		-1,
		"different_operation",
		{"run_id": String(RUN_ID)}
	)
	TestAssertions.truthy(seeded.ok(), "forfeit collision fixture seeds a conflicting journal entry", failures)
	var collision_path := collision_store.profile_path(PROFILE_ID, collision_root)
	var collision_before := FileAccess.get_file_as_bytes(collision_path)
	_assert_failure(collision_service.forfeit(PROFILE_ID, RUN_ID, collision_root), "transaction id conflict", "forfeit collision", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(collision_path), collision_before, "forfeit collision preserves active run bytes", failures)
	ProfileTestSupport.remove_tree(collision_root)
	ProfileTestSupport.remove_tree(root)

func _request(transaction_id: String, bring_in_gear: bool, run_id: StringName = RUN_ID) -> RunLoadoutCheckoutRequest:
	return RunLoadoutCheckoutRequest.create(
		transaction_id,
		PROFILE_ID,
		run_id,
		4402,
		RUN_PLAYER_ID,
		LEADER_MEMBER_ID,
		&"fighter",
		bring_in_gear
	)

func _profile_with_loadout(items: Array[ItemInstance], loadout_slots: Dictionary, stash_slots: Dictionary, class_id: String) -> ProfileState:
	var profile := ProfileState.new_profile(PROFILE_ID, "Checkout Tester", 1000)
	profile.inventory_columns = 2
	profile.item_records = ItemRegistry.new(items).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, EquipmentSlotIndex.capacity(), loadout_slots
	).to_dictionary()
	profile.leader_loadout_class_id = class_id
	if not stash_slots.is_empty():
		profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-000", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, stash_slots).to_dictionary()]
	return profile

func _run_state(items: Array[ItemInstance], equipment_slots: Dictionary) -> ItemOwnershipState:
	return ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new(items), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), equipment_slots),
		ItemSlotContainer.create(&"run-ground-items", &"run_ground_items", String(RUN_PLAYER_ID), 2048),
	])

func _item(instance_id: String, base_id: StringName, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 28
	item.rarity_id = &"common"
	item.origin = {
		"issuer_namespace": "profile:%s" % PROFILE_ID,
		"seed": 4402,
		"sequence": sequence,
		"source": "run_checkout_test",
	}
	return item

func _save_profile(store: ProfileStore, profile: ProfileState, root: String, label: String, failures: Array[String]) -> void:
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "%s saves" % label, failures)

func _assert_failure(result: ProfileMutationResult, expected: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not result.ok(), "%s is rejected" % label, failures)
	TestAssertions.equal(result.profile, null, "%s exposes no candidate profile" % label, failures)
	TestAssertions.truthy(result.error.contains(expected), "%s reports %s" % [label, expected], failures)
	TestAssertions.truthy(not result.duplicate, "%s is not duplicate success" % label, failures)

func _file_hash(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()

func _case_root(label: String) -> String:
	_root_counter += 1
	return "user://tests/run_loadout_checkout_%s_%d_%d_%d" % [label.validate_filename(), OS.get_process_id(), Time.get_ticks_usec(), _root_counter]
