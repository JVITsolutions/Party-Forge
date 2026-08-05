extends RefCounted

const PROFILE_ID := "profile-transition01"

var _root_counter := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_projection_is_canonical_deterministic_and_defensive(failures)
	_test_projection_enforces_reserved_slots_attributes_and_malformed_inputs(failures)
	_test_nonoverflow_transition_is_atomic_replay_safe_and_exact(failures)
	_test_transition_to_empty_loadout_retains_selected_class(failures)
	_test_overflow_transition_destroys_only_confirmed_instances(failures)
	_test_transition_rejections_and_save_failure_preserve_bytes(failures)
	return failures

func _test_projection_is_canonical_deterministic_and_defensive(failures: Array[String]) -> void:
	var items: Array[ItemInstance] = []
	var crown := _item("item-projection-crown", &"dawn_bulwark_crown", 0)
	var plate := _item("item-projection-plate", &"dawn_bulwark_plate", 1)
	var ring := _item("item-projection-ring", &"windrunner_band", 2)
	items.append_array([crown, plate, ring])
	var first_slots: Dictionary = {}
	for slot: int in 99:
		var filler := _item("item-projection-filler-%03d" % slot, &"windrunner_band", 10 + slot)
		items.append(filler)
		first_slots[slot] = filler.instance_id
	var profile := _profile(
		items,
		{0: crown.instance_id, 1: plate.instance_id, 6: ring.instance_id},
		[
			_stash(&"stash-tab-zeta", first_slots),
			_stash(&"stash-tab-alpha", {}),
		],
		"fighter",
	)
	var mage := GameCatalog.load_defaults().class_by_id(&"mage")
	var service := LoadoutCompatibilityService.new()
	var projection := service.project(profile, mage, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(projection.valid, "mixed compatibility projection succeeds", failures)
	TestAssertions.equal(projection.error, "", "valid projection has no error", failures)
	TestAssertions.equal(projection.selected_class_id, &"mage", "projection exposes selected authoritative class", failures)
	TestAssertions.equal(_ids(projection.compatible_items), [ring.instance_id], "projection retains compatible equipment", failures)
	TestAssertions.equal(_ids(projection.incompatible_items), [crown.instance_id, plate.instance_id], "projection uses canonical equipment-slot order", failures)
	var incompatibles := projection.incompatible_items
	TestAssertions.equal(incompatibles[0]["source_container_id"], "leader-loadout", "incompatible source names the leader container", failures)
	TestAssertions.equal(incompatibles[0]["source_slot"], 0, "incompatible source preserves exact equipment position", failures)
	TestAssertions.equal(incompatibles[0]["slot_id"], "helmet", "incompatible source exposes canonical slot id", failures)
	TestAssertions.equal(incompatibles[0]["reasons"], [
		"PARTY_FORGE_EQUIPMENT_ERROR item=dawn_bulwark_crown reason=missing weight capability armour_heavy",
		"PARTY_FORGE_EQUIPMENT_ERROR item=dawn_bulwark_crown reason=missing tag martial",
		"PARTY_FORGE_EQUIPMENT_ERROR item=dawn_bulwark_crown reason=missing tag vanguard",
	], "projection preserves exact stable eligibility reasons", failures)
	TestAssertions.equal(projection.planned_stash_destinations, [
		{"instance_id": crown.instance_id, "destination_container_id": "stash-tab-zeta", "destination_slot": 99},
		{"instance_id": plate.instance_id, "destination_container_id": "stash-tab-alpha", "destination_slot": 0},
	], "stash plan follows stored nonlexical tab order and first-empty slots", failures)
	TestAssertions.equal(projection.overflow_item_ids, [], "sufficient stash produces no overflow", failures)
	TestAssertions.equal(projection.confirmation_token, _expected_token(projection.confirmation_document()), "confirmation token is canonical SHA-256", failures)
	TestAssertions.equal(projection.confirmation_document().keys(), [
		"incompatible_sources", "overflow_item_ids", "planned_stash_destinations", "selected_class_id",
	], "confirmation document exposes the exact token field set", failures)

	var repeated := service.project(profile, mage, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(repeated.confirmation_document(), projection.confirmation_document(), "projection is deterministic", failures)
	TestAssertions.equal(repeated.confirmation_token, projection.confirmation_token, "deterministic projection has stable token", failures)
	var escaped_items := projection.incompatible_items
	escaped_items[0]["instance_id"] = "escaped"
	var escaped_destinations := projection.planned_stash_destinations
	escaped_destinations[0]["destination_slot"] = 4
	var escaped_overflow := projection.overflow_item_ids
	escaped_overflow.append("escaped")
	TestAssertions.equal(_ids(projection.incompatible_items), [crown.instance_id, plate.instance_id], "projection item results are defensive", failures)
	TestAssertions.equal(projection.planned_stash_destinations[0]["destination_slot"], 99, "projection destination results are defensive", failures)
	TestAssertions.equal(projection.overflow_item_ids, [], "projection overflow results are defensive", failures)

	var same_class := service.project(profile, GameCatalog.load_defaults().class_by_id(&"fighter"), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(same_class.valid, "same-class projection succeeds", failures)
	TestAssertions.equal(_ids(same_class.compatible_items), [crown.instance_id, plate.instance_id, ring.instance_id], "same-class equipment remains compatible in slot order", failures)
	TestAssertions.equal(same_class.incompatible_items, [], "same-class equipment needs no transition", failures)

	var no_space := _profile([crown, plate], {0: crown.instance_id, 1: plate.instance_id}, [], "fighter")
	var no_space_projection := service.project(no_space, mage, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(no_space_projection.valid, "zero-stash projection remains a valid warning plan", failures)
	TestAssertions.equal(no_space_projection.planned_stash_destinations, [], "zero stash has no planned moves", failures)
	TestAssertions.equal(no_space_projection.overflow_item_ids, [crown.instance_id, plate.instance_id], "zero stash overflows in canonical equipment order", failures)

func _test_projection_enforces_reserved_slots_attributes_and_malformed_inputs(failures: Array[String]) -> void:
	var service := LoadoutCompatibilityService.new()
	var ranger := GameCatalog.load_defaults().class_by_id(&"ranger")
	var bow := _item("item-rule-bow", &"greenwood_recurve_bow", 0)
	var matching := _item("item-rule-quiver-match", &"greenwood_light_quiver", 1)
	var matching_profile := _profile([bow, matching], {9: bow.instance_id, 10: matching.instance_id}, [], "ranger")
	var matching_projection := service.project(matching_profile, ranger, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(_ids(matching_projection.compatible_items), [bow.instance_id, matching.instance_id], "matching bow and quiver remain compatible", failures)
	TestAssertions.equal(matching_projection.incompatible_items, [], "matching reserved-slot exception has no rejection", failures)

	var shield := _item("item-rule-shield", &"forge_vanguard_shield", 2)
	var reserved_profile := _profile([bow, shield], {9: bow.instance_id, 10: shield.instance_id}, [], "ranger")
	var reserved_projection := service.project(reserved_profile, ranger, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(_ids(reserved_projection.compatible_items), [bow.instance_id], "compatible two-hand main hand is accumulated", failures)
	TestAssertions.equal(_ids(reserved_projection.incompatible_items), [shield.instance_id], "ordinary offhand is rejected from a reserved slot", failures)
	TestAssertions.truthy(String((reserved_projection.incompatible_items[0]["reasons"] as Array)[0]).contains("offhand reserved by greenwood_recurve_bow"), "reserved-slot reason is stable and specific", failures)

	var orphan_quiver := _profile([matching], {10: matching.instance_id}, [], "ranger")
	var orphan_projection := service.project(orphan_quiver, ranger, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(_ids(orphan_projection.incompatible_items), [matching.instance_id], "quiver without a compatible main hand is rejected", failures)
	TestAssertions.truthy(String((orphan_projection.incompatible_items[0]["reasons"] as Array).back()).contains("quiver requires a compatible main-hand bow"), "orphan quiver exposes an exact structural reason", failures)

	var custom_equipment := _equipment_with_requirement(&"forge_vanguard_sword", &"strength", 5.0)
	var sword := _item("item-rule-strength", &"forge_vanguard_sword", 3)
	var strength_profile := _profile([sword], {9: sword.instance_id}, [], "fighter")
	var strong_fighter := GameCatalog.load_defaults().class_by_id(&"fighter").duplicate(true) as ClassDefinition
	strong_fighter.base_stat_overrides = {&"strength": 6.0}
	var strong_projection := service.project(strength_profile, strong_fighter, custom_equipment, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(_ids(strong_projection.compatible_items), [sword.instance_id], "base core attributes satisfy equipment requirements", failures)
	var weak_fighter := GameCatalog.load_defaults().class_by_id(&"fighter").duplicate(true) as ClassDefinition
	weak_fighter.base_stat_overrides = {&"strength": 4.0}
	var weak_projection := service.project(strength_profile, weak_fighter, custom_equipment, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(_ids(weak_projection.incompatible_items), [sword.instance_id], "insufficient base core attribute rejects equipment", failures)
	TestAssertions.truthy(String((weak_projection.incompatible_items[0]["reasons"] as Array)[0]).contains("reason=attribute strength"), "attribute rejection preserves eligibility reason", failures)

	var missing_class := service.project(strength_profile, null, custom_equipment, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(not missing_class.valid and missing_class.error.contains("class"), "missing selected class returns an invalid projection", failures)
	var unknown := _item("item-rule-unknown", &"not-a-real-base", 4)
	var unknown_profile := _profile([unknown], {0: unknown.instance_id}, [], "fighter")
	var unknown_projection := service.project(unknown_profile, ranger, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(not unknown_projection.valid and unknown_projection.error.contains("unknown equipment base"), "unknown item base returns an invalid projection", failures)
	var malformed := strength_profile.copy()
	malformed.leader_loadout["slots"] = {"0": sword.instance_id, "1": sword.instance_id}
	var malformed_projection := service.project(malformed, strong_fighter, custom_equipment, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(not malformed_projection.valid and malformed_projection.error.contains("references"), "duplicate ownership returns an invalid projection", failures)

func _test_nonoverflow_transition_is_atomic_replay_safe_and_exact(failures: Array[String]) -> void:
	var root := _case_root("nonoverflow")
	var store := ProfileStore.new()
	var crown := _item("item-transition-crown", &"dawn_bulwark_crown", 0)
	var plate := _item("item-transition-plate", &"dawn_bulwark_plate", 1)
	var ring := _item("item-transition-ring", &"windrunner_band", 2)
	var existing := _item("item-transition-existing", &"windrunner_band", 3)
	var profile := _profile(
		[crown, plate, ring, existing],
		{0: crown.instance_id, 1: plate.instance_id, 6: ring.instance_id},
		[
			_stash(&"stash-tab-later", {0: existing.instance_id}),
			_stash(&"stash-tab-earlier", {}),
		],
		"fighter",
	)
	_save_profile(store, profile, root, "nonoverflow transition fixture", failures)
	var projection := _project(profile, &"mage")
	var request := _request("transition-nonoverflow", projection)
	var request_before := request.canonical_document()
	TestAssertions.equal(request_before.keys(), [
		"cancelled", "confirmation_token", "confirmed", "incompatible_sources", "overflow_item_ids",
		"planned_stash_destinations", "profile_id", "selected_class_id", "transaction_id",
	], "transition request fingerprints the exact contracted fields", failures)
	var escaped_sources := request.incompatible_sources
	escaped_sources[0]["instance_id"] = "escaped"
	var escaped_destinations := request.planned_stash_destinations
	escaped_destinations[0]["destination_slot"] = 77
	var escaped_overflow := request.overflow_item_ids
	escaped_overflow.append("escaped")
	TestAssertions.equal(request.canonical_document(), request_before, "transition request owns defensive inputs and outputs", failures)

	var service := LoadoutTransitionService.new(ProfileMutationService.new(store))
	var committed := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(committed.ok() and not committed.duplicate, "nonoverflow transition commits once", failures)
	var loaded := store.load_profile(PROFILE_ID, root)
	TestAssertions.truthy(loaded.ok(), "nonoverflow transition reloads", failures)
	if not loaded.ok():
		ProfileTestSupport.remove_tree(root)
		return
	var saved := loaded.profile
	TestAssertions.equal(saved.leader_loadout_class_id, "mage", "transition always records selected target class", failures)
	TestAssertions.equal(saved.leader_loadout["slots"], {"6": ring.instance_id}, "transition preserves compatible leader slot exactly", failures)
	TestAssertions.equal(saved.stash_tabs.map(func(tab: Dictionary) -> String: return String(tab["container_id"])), ["stash-tab-later", "stash-tab-earlier"], "transition preserves stored stash-tab order", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {"0": existing.instance_id, "1": crown.instance_id, "2": plate.instance_id}, "transition moves every incompatible item to exact planned positions", failures)
	TestAssertions.equal(saved.stash_tabs[1]["slots"], {}, "transition leaves later empty stored tab unchanged", failures)
	_assert_exact_item(saved, crown, "moved crown", failures)
	_assert_exact_item(saved, plate, "moved plate", failures)
	_assert_exact_item(saved, ring, "retained ring", failures)
	_assert_exact_item(saved, existing, "unrelated stash item", failures)
	var post_projection := _project(saved, &"mage")
	TestAssertions.truthy(post_projection.valid and post_projection.incompatible_items.is_empty(), "retained loadout is valid for selected class", failures)
	var path := store.profile_path(PROFILE_ID, root)
	var committed_bytes := FileAccess.get_file_as_bytes(path)
	var replay := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(replay.ok() and replay.duplicate, "exact transition replay returns duplicate success", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), committed_bytes, "transition replay performs no write", failures)
	var collision := LoadoutTransitionRequest.create(
		request.transaction_id, PROFILE_ID, &"fighter", request.incompatible_sources,
		request.planned_stash_destinations, request.overflow_item_ids, true, false,
		LoadoutCompatibilityProjection.confirmation_token_for(&"fighter", request.incompatible_sources, request.planned_stash_destinations, request.overflow_item_ids),
	)
	_assert_failure(service.apply(PROFILE_ID, collision, root), "transaction id conflict", "transition collision", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), committed_bytes, "transition collision preserves exact committed bytes", failures)
	ProfileTestSupport.remove_tree(root)

func _test_transition_to_empty_loadout_retains_selected_class(failures: Array[String]) -> void:
	var root := _case_root("empty_result")
	var store := ProfileStore.new()
	var plate := _item("item-empty-result-plate", &"dawn_bulwark_plate", 0)
	var profile := _profile([plate], {1: plate.instance_id}, [_stash(&"stash-tab-000", {})], "fighter")
	_save_profile(store, profile, root, "empty-result transition fixture", failures)
	var projection := _project(profile, &"mage")
	var committed := LoadoutTransitionService.new(ProfileMutationService.new(store)).apply(
		PROFILE_ID,
		_request("transition-empty-result", projection),
		root,
	)
	TestAssertions.truthy(committed.ok(), "all-incompatible transition commits", failures)
	var saved := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.equal(saved.leader_loadout["slots"], {}, "all-incompatible transition leaves an empty leader loadout", failures)
	TestAssertions.equal(saved.leader_loadout_class_id, "mage", "empty leader loadout retains selected target class", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {"0": plate.instance_id}, "empty-result transition preserves the moved instance", failures)
	ProfileTestSupport.remove_tree(root)

func _test_overflow_transition_destroys_only_confirmed_instances(failures: Array[String]) -> void:
	var source_text := FileAccess.get_file_as_string("res://scripts/equipment/loadout_transition_service.gd")
	TestAssertions.truthy(not source_text.contains("SANDBOX_REMOVE") and not source_text.contains("sandbox_remove"), "production transition does not call or expose sandbox removal", failures)
	var root := _case_root("overflow")
	var store := ProfileStore.new()
	var items: Array[ItemInstance] = []
	var crown := _item("item-overflow-crown", &"dawn_bulwark_crown", 0)
	var plate := _item("item-overflow-plate", &"dawn_bulwark_plate", 1)
	var ring := _item("item-overflow-ring", &"windrunner_band", 2)
	items.append_array([crown, plate, ring])
	var stash_slots: Dictionary = {}
	for slot: int in 99:
		var filler := _item("item-overflow-filler-%03d" % slot, &"windrunner_band", 10 + slot)
		items.append(filler)
		stash_slots[slot] = filler.instance_id
	var profile := _profile(items, {0: crown.instance_id, 1: plate.instance_id, 6: ring.instance_id}, [_stash(&"stash-tab-000", stash_slots)], "fighter")
	_save_profile(store, profile, root, "overflow transition fixture", failures)
	var projection := _project(profile, &"mage")
	TestAssertions.equal(projection.planned_stash_destinations, [
		{"instance_id": crown.instance_id, "destination_container_id": "stash-tab-000", "destination_slot": 99},
	], "overflow plan moves the first canonical incompatible item", failures)
	TestAssertions.equal(projection.overflow_item_ids, [plate.instance_id], "overflow plan names the exact later incompatible item", failures)
	var service := LoadoutTransitionService.new(ProfileMutationService.new(store))
	var committed := service.apply(PROFILE_ID, _request("transition-overflow", projection), root)
	TestAssertions.truthy(committed.ok(), "explicitly confirmed overflow transition commits", failures)
	var saved := store.load_profile(PROFILE_ID, root).profile
	var saved_registry := ItemRegistry._decode(saved.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)["value"] as ItemRegistry
	TestAssertions.truthy(saved_registry.has(crown.instance_id), "planned incompatible item remains owned", failures)
	TestAssertions.truthy(not saved_registry.has(plate.instance_id), "only exact confirmed overflow instance is destroyed", failures)
	TestAssertions.truthy(saved_registry.has(ring.instance_id), "compatible item is never destroyed", failures)
	for slot: int in 99:
		TestAssertions.truthy(saved_registry.has("item-overflow-filler-%03d" % slot), "unrelated filler %d survives overflow reconstruction" % slot, failures)
	TestAssertions.equal(saved.leader_loadout["slots"], {"6": ring.instance_id}, "overflow transition preserves compatible leader placement", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"].get("99", ""), crown.instance_id, "planned item uses the exact confirmed stash destination", failures)
	TestAssertions.equal(saved.leader_loadout_class_id, "mage", "overflow transition records selected target class", failures)
	TestAssertions.equal(ProfileCodec.validate_profile(saved), "", "overflow candidate reconstruction passes complete ownership validation", failures)
	ProfileTestSupport.remove_tree(root)

func _test_transition_rejections_and_save_failure_preserve_bytes(failures: Array[String]) -> void:
	var root := _case_root("rejections")
	var store := ProfileStore.new()
	var plate := _item("item-rejection-plate", &"dawn_bulwark_plate", 0)
	var profile := _profile([plate], {1: plate.instance_id}, [_stash(&"stash-tab-000", {})], "fighter")
	_save_profile(store, profile, root, "transition rejection fixture", failures)
	var projection := _project(profile, &"mage")
	var service := LoadoutTransitionService.new(ProfileMutationService.new(store))
	var path := store.profile_path(PROFILE_ID, root)
	var before := FileAccess.get_file_as_bytes(path)
	var wrong_known_class := LoadoutTransitionRequest.create(
		"reject-wrong-known-class", PROFILE_ID, &"fighter", projection.incompatible_sources(),
		projection.planned_stash_destinations, projection.overflow_item_ids, true, false,
		LoadoutCompatibilityProjection.confirmation_token_for(&"fighter", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids),
	)
	var cases: Array[Dictionary] = [
		{"label": "missing token", "request": LoadoutTransitionRequest.create("reject-missing-token", PROFILE_ID, &"mage", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, true, false, ""), "expected": "confirmation token"},
		{"label": "stale token", "request": LoadoutTransitionRequest.create("reject-stale-token", PROFILE_ID, &"mage", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, true, false, "0".repeat(64)), "expected": "confirmation token"},
		{"label": "not confirmed", "request": LoadoutTransitionRequest.create("reject-not-confirmed", PROFILE_ID, &"mage", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, false, false, projection.confirmation_token), "expected": "confirmation required"},
		{"label": "cancelled", "request": LoadoutTransitionRequest.create("reject-cancelled", PROFILE_ID, &"mage", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, true, true, projection.confirmation_token), "expected": "cancelled"},
		{"label": "wrong request profile", "request": LoadoutTransitionRequest.create("reject-wrong-profile", "profile-transition-other", &"mage", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, true, false, projection.confirmation_token), "expected": "profile identity"},
		{"label": "unknown class", "request": LoadoutTransitionRequest.create("reject-unknown-class", PROFILE_ID, &"unknown", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, true, false, projection.confirmation_token), "expected": "unknown selected class"},
		{"label": "wrong known class", "request": wrong_known_class, "expected": "stale projection"},
	]
	for test_case: Dictionary in cases:
		_assert_failure(service.apply(PROFILE_ID, test_case["request"], root), test_case["expected"], test_case["label"], failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(path), before, "%s preserves exact profile bytes" % test_case["label"], failures)

	var stale_request := _request("reject-stale-plan", projection)
	var current := store.load_profile(PROFILE_ID, root).profile
	var blocker := _item("item-rejection-blocker", &"windrunner_band", 1)
	var registry_decode := ItemRegistry._decode(current.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	var current_items: Array[ItemInstance] = []
	var current_registry := registry_decode["value"] as ItemRegistry
	for instance_id: String in current_registry.ids():
		current_items.append(current_registry.item(instance_id))
	current_items.append(blocker)
	current.item_records = ItemRegistry.new(current_items).to_dictionary()
	(current.stash_tabs[0]["slots"] as Dictionary)["0"] = blocker.instance_id
	TestAssertions.equal(store.save_profile(current, root), "", "stale-plan fixture changes stash after projection", failures)
	var stale_bytes := FileAccess.get_file_as_bytes(path)
	_assert_failure(service.apply(PROFILE_ID, stale_request, root), "stale projection", "changed stash stale plan", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), stale_bytes, "stale plan preserves current profile bytes", failures)

	var loadout_root := _case_root("changed_loadout")
	var loadout_store := ProfileStore.new()
	_save_profile(loadout_store, profile, loadout_root, "changed-loadout source fixture", failures)
	var old_projection := _project(profile, &"mage")
	var old_request := _request("reject-changed-loadout", old_projection)
	var changed := loadout_store.load_profile(PROFILE_ID, loadout_root).profile
	changed.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, EquipmentSlotIndex.capacity()).to_dictionary()
	changed.stash_tabs[0]["slots"] = {"0": plate.instance_id}
	TestAssertions.equal(loadout_store.save_profile(changed, loadout_root), "", "changed-loadout fixture remains valid", failures)
	var changed_path := loadout_store.profile_path(PROFILE_ID, loadout_root)
	var changed_bytes := FileAccess.get_file_as_bytes(changed_path)
	_assert_failure(LoadoutTransitionService.new(ProfileMutationService.new(loadout_store)).apply(PROFILE_ID, old_request, loadout_root), "stale projection", "changed loadout stale plan", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(changed_path), changed_bytes, "changed loadout rejection preserves bytes", failures)
	ProfileTestSupport.remove_tree(loadout_root)

	var save_root := _case_root("save_failure")
	var good_store := ProfileStore.new()
	_save_profile(good_store, profile, save_root, "transition save-failure fixture", failures)
	var save_projection := _project(profile, &"mage")
	var save_path := good_store.profile_path(PROFILE_ID, save_root)
	var save_before := FileAccess.get_file_as_bytes(save_path)
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var failed := LoadoutTransitionService.new(ProfileMutationService.new(failing_store)).apply(PROFILE_ID, _request("transition-save-failure", save_projection), save_root)
	_assert_failure(failed, "JSON_STORE_SAVE_ERROR", "transition save failure", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(save_path), save_before, "transition save failure preserves exact profile bytes", failures)
	TestAssertions.equal(good_store.load_profile(PROFILE_ID, save_root).profile.leader_loadout["slots"], {"1": plate.instance_id}, "save failure leaves item in original leader slot", failures)
	ProfileTestSupport.remove_tree(save_root)
	ProfileTestSupport.remove_tree(root)

func _project(profile: ProfileState, class_id: StringName) -> LoadoutCompatibilityProjection:
	return LoadoutCompatibilityService.new().project(
		profile,
		GameCatalog.load_defaults().class_by_id(class_id),
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)

func _request(transaction_id: String, projection: LoadoutCompatibilityProjection) -> LoadoutTransitionRequest:
	return LoadoutTransitionRequest.create(
		transaction_id,
		PROFILE_ID,
		projection.selected_class_id,
		projection.incompatible_sources(),
		projection.planned_stash_destinations,
		projection.overflow_item_ids,
		true,
		false,
		projection.confirmation_token,
	)

func _profile(items: Array[ItemInstance], loadout_slots: Dictionary, tabs: Array[Dictionary], class_id: String) -> ProfileState:
	var profile := ProfileState.new_profile(PROFILE_ID, "Transition Tester", 1000)
	profile.item_records = ItemRegistry.new(items).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, EquipmentSlotIndex.capacity(), loadout_slots,
	).to_dictionary()
	profile.leader_loadout_class_id = class_id
	profile.stash_tabs = tabs.duplicate(true)
	return profile

func _stash(id: StringName, slots: Dictionary) -> Dictionary:
	return ItemSlotContainer.create(id, ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, ItemSlotContainer.STASH_CAPACITY, slots).to_dictionary()

func _item(instance_id: String, base_id: StringName, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 31
	item.rarity_id = &"common"
	item.origin = {
		"issuer_namespace": "profile:%s" % PROFILE_ID,
		"seed": 8808,
		"sequence": sequence,
		"source": "loadout_transition_test",
	}
	return item

func _equipment_with_requirement(base_id: StringName, attribute_id: StringName, requirement: float) -> EquipmentCatalog:
	var result := EquipmentCatalog.new()
	for definition: EquipmentBaseDefinition in GameCatalog.EQUIPMENT_CATALOG.definitions:
		var owned := definition.duplicate(true) as EquipmentBaseDefinition
		if owned.id == base_id:
			owned.attribute_requirements = {attribute_id: requirement}
		result.definitions.append(owned)
	return result

func _ids(entries: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in entries:
		result.append(String(entry["instance_id"]))
	return result

func _expected_token(document: Dictionary) -> String:
	return JSON.stringify(_canonicalize(document)).sha256_text()

func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key: Variant in source:
			keys.append(String(key))
		keys.sort()
		var result: Dictionary = {}
		for key: String in keys:
			result[key] = _canonicalize(source[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value as Array:
			result.append(_canonicalize(item))
		return result
	return value

func _assert_exact_item(profile: ProfileState, expected: ItemInstance, label: String, failures: Array[String]) -> void:
	var decoded := ItemRegistry._decode(profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(String(decoded["error"]), "", "%s registry decodes" % label, failures)
	var registry := decoded["value"] as ItemRegistry
	TestAssertions.equal(registry.item(expected.instance_id).to_dictionary() if registry != null and registry.has(expected.instance_id) else {}, expected.to_dictionary(), "%s preserves exact instance" % label, failures)

func _save_profile(store: ProfileStore, profile: ProfileState, root: String, label: String, failures: Array[String]) -> void:
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "%s saves" % label, failures)

func _assert_failure(result: ProfileMutationResult, expected: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not result.ok(), "%s is rejected" % label, failures)
	TestAssertions.equal(result.profile, null, "%s exposes no candidate profile" % label, failures)
	TestAssertions.truthy(result.error.contains(expected), "%s reports %s" % [label, expected], failures)
	TestAssertions.truthy(not result.duplicate, "%s is not duplicate success" % label, failures)

func _case_root(label: String) -> String:
	_root_counter += 1
	return "user://tests/loadout_transition_%s_%d_%d_%d" % [label.validate_filename(), OS.get_process_id(), Time.get_ticks_usec(), _root_counter]
