extends RefCounted

const PROFILE_ID := "profile-transition01"

var _root_counter := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_projection_is_canonical_deterministic_and_defensive(failures)
	_test_registry_record_order_is_fingerprint_canonical(failures)
	_test_projection_enforces_reserved_slots_attributes_and_malformed_inputs(failures)
	_test_nonoverflow_transition_is_atomic_replay_safe_and_exact(failures)
	_test_transition_to_empty_loadout_retains_selected_class(failures)
	_test_overflow_transition_destroys_only_confirmed_instances(failures)
	_test_overflow_irreversible_save_failure_preserves_all_artifacts(failures)
	_test_transition_rejections_and_save_failure_preserve_bytes(failures)
	_test_compatible_identity_and_slot_change_stales_request(failures)
	_test_overflow_source_record_change_stales_request(failures)
	_test_unrelated_stash_record_change_stales_request(failures)
	_test_leader_loadout_class_change_stales_request(failures)
	_test_unrelated_stash_occupancy_change_stales_request(failures)
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
	TestAssertions.equal(incompatibles[0].get("display_name", ""), "Dawn Bulwark Crown", "projection exposes the exact equipment display name for warning UI", failures)
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
	TestAssertions.equal(projection.state_fingerprint.length(), 64, "projection exposes the exact preflight state fingerprint", failures)
	TestAssertions.equal(projection.confirmation_document().keys(), [
		"incompatible_sources", "overflow_item_ids", "planned_stash_destinations", "selected_class_id",
	], "confirmation document exposes the exact token field set", failures)

	var repeated := service.project(profile, mage, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(repeated.confirmation_document(), projection.confirmation_document(), "projection is deterministic", failures)
	TestAssertions.equal(repeated.confirmation_token, projection.confirmation_token, "deterministic projection has stable token", failures)
	TestAssertions.equal(repeated.state_fingerprint, projection.state_fingerprint, "deterministic projection has stable state fingerprint", failures)
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

func _test_registry_record_order_is_fingerprint_canonical(failures: Array[String]) -> void:
	var root := _case_root("registry_order")
	var store := ProfileStore.new()
	var plate := _item("item-registry-order-z-plate", &"dawn_bulwark_plate", 0)
	var ring := _item("item-registry-order-a-ring", &"windrunner_band", 1)
	var original := _profile(
		[plate, ring],
		{1: plate.instance_id},
		[_stash(&"stash-tab-000", {50: ring.instance_id})],
		"fighter",
	)
	var reordered := original.copy()
	var reordered_records := reordered.item_records.duplicate(true)
	(reordered_records["items"] as Array).reverse()
	reordered.item_records = reordered_records
	TestAssertions.truthy(original.item_records != reordered.item_records, "registry-order fixture changes raw item array order", failures)
	TestAssertions.equal(ProfileCodec.validate_profile(reordered), "", "reordered registry remains a valid strict profile", failures)
	var original_decode := ItemRegistry._decode(original.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	var reordered_decode := ItemRegistry._decode(reordered.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(String(original_decode["error"]), "", "original registry strictly decodes", failures)
	TestAssertions.equal(String(reordered_decode["error"]), "", "reordered registry strictly decodes", failures)
	var original_registry := original_decode["value"] as ItemRegistry
	var reordered_registry := reordered_decode["value"] as ItemRegistry
	TestAssertions.equal(reordered_registry.to_dictionary(), original_registry.to_dictionary(), "record order preserves exact decoded registry semantics", failures)

	var original_projection := _project(original, &"mage")
	var reordered_projection := _project(reordered, &"mage")
	TestAssertions.truthy(original_projection.valid and reordered_projection.valid, "equivalent registries both project", failures)
	TestAssertions.equal(reordered_projection.confirmation_token, original_projection.confirmation_token, "record order leaves confirmation token unchanged", failures)
	TestAssertions.equal(reordered_projection.state_fingerprint, original_projection.state_fingerprint, "record order leaves deterministic state fingerprint unchanged", failures)
	_save_profile(store, reordered, root, "reordered registry transition fixture", failures)
	var committed := LoadoutTransitionService.new(ProfileMutationService.new(store)).apply(
		PROFILE_ID,
		_request("transition-registry-order", original_projection),
		root,
	)
	TestAssertions.truthy(committed.ok(), "request projected before record reordering still commits", failures)
	var saved := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.equal(saved.leader_loadout["slots"], {}, "record-order transition moves the incompatible item", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {"0": plate.instance_id, "50": ring.instance_id}, "record-order transition preserves stored stash semantics", failures)
	_assert_exact_item(saved, plate, "record-order moved plate", failures)
	_assert_exact_item(saved, ring, "record-order unrelated ring", failures)
	ProfileTestSupport.remove_tree(root)

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
		"planned_stash_destinations", "profile_id", "selected_class_id", "state_fingerprint", "transaction_id",
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
	var backup_path := "%s.bak" % path
	TestAssertions.truthy(FileAccess.file_exists(backup_path), "ordinary nonoverflow transition rotates a backup generation", failures)
	var backup_decode := ProfileCodec.decode(FileAccess.get_file_as_string(backup_path))
	TestAssertions.truthy(backup_decode.ok(), "ordinary nonoverflow transition backup decodes", failures)
	if backup_decode.ok():
		TestAssertions.equal(backup_decode.profile.leader_loadout_class_id, "fighter", "ordinary nonoverflow transition retains the pre-transition profile in backup", failures)
		TestAssertions.equal(backup_decode.profile.leader_loadout["slots"], {"0": crown.instance_id, "1": plate.instance_id, "6": ring.instance_id}, "ordinary nonoverflow backup retains the pre-transition loadout", failures)
	var committed_bytes := FileAccess.get_file_as_bytes(path)
	var replay := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(replay.ok() and replay.duplicate, "exact transition replay returns duplicate success", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), committed_bytes, "transition replay performs no write", failures)
	var collision := LoadoutTransitionRequest.create(
		request.transaction_id, PROFILE_ID, &"fighter", request.incompatible_sources,
		request.planned_stash_destinations, request.overflow_item_ids, true, false,
		LoadoutCompatibilityProjection.confirmation_token_for(&"fighter", request.incompatible_sources, request.planned_stash_destinations, request.overflow_item_ids),
		request.state_fingerprint,
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
	var historical_invocations := [0]
	var historical_mutation := func(candidate: ProfileState) -> String:
		historical_invocations[0] += 1
		candidate.gold += 7
		return ""
	var mutations := ProfileMutationService.new(store)
	var historical := mutations.apply(
		PROFILE_ID,
		"transition-overflow-history",
		historical_mutation,
		root,
		2000,
		"test_overflow_history",
		{"amount": 7},
	)
	TestAssertions.truthy(historical.ok(), "ordinary historical transaction commits while overflow item exists", failures)
	TestAssertions.truthy(_contains_string(historical.profile.to_dictionary(), plate.instance_id), "historical result initially exposes the later destroyed item", failures)
	profile = store.load_profile(PROFILE_ID, root).profile
	var projection := _project(profile, &"mage")
	TestAssertions.equal(projection.planned_stash_destinations, [
		{"instance_id": crown.instance_id, "destination_container_id": "stash-tab-000", "destination_slot": 99},
	], "overflow plan moves the first canonical incompatible item", failures)
	TestAssertions.equal(projection.overflow_item_ids, [plate.instance_id], "overflow plan names the exact later incompatible item", failures)
	var service := LoadoutTransitionService.new(mutations)
	var request := _request("transition-overflow", projection)
	var committed := service.apply(PROFILE_ID, request, root)
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
	TestAssertions.truthy(not _contains_string(saved.to_dictionary(), plate.instance_id), "committed destructive profile and transaction journal contain no destroyed ID", failures)
	var path := store.profile_path(PROFILE_ID, root)
	var backup_path := "%s.bak" % path
	var backup_decode := ProfileCodec.decode(FileAccess.get_file_as_string(backup_path))
	TestAssertions.truthy(backup_decode.ok(), "destructive transition creates a valid sanitized backup", failures)
	if backup_decode.ok():
		var backup_registry := ItemRegistry._decode(backup_decode.profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)["value"] as ItemRegistry
		TestAssertions.truthy(not backup_registry.has(plate.instance_id), "destructive transition backup cannot restore the destroyed instance", failures)
		TestAssertions.truthy(not _contains_string(backup_decode.profile.to_dictionary(), plate.instance_id), "destructive transition backup journal contains no destroyed ID", failures)
	var committed_primary := FileAccess.get_file_as_bytes(path)
	var committed_backup := FileAccess.get_file_as_bytes(backup_path)
	var replay := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(replay.ok() and replay.duplicate, "destructive transition replay is idempotent", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), committed_primary, "destructive transition replay does not rewrite primary", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(backup_path), committed_backup, "destructive transition replay does not rewrite backup", failures)
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("corrupt destructive transition primary")
		corrupt.close()
	var recovered := store.load_profile(PROFILE_ID, root)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "destructive transition recovers its sanitized backup after primary corruption", failures)
	if recovered.ok():
		var recovered_registry := ItemRegistry._decode(recovered.profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)["value"] as ItemRegistry
		TestAssertions.truthy(not recovered_registry.has(plate.instance_id), "corrupt-primary recovery cannot resurrect the destroyed instance", failures)
		TestAssertions.truthy(not _contains_string(recovered.profile.to_dictionary(), plate.instance_id), "corrupt-primary recovery journal contains no destroyed ID", failures)
	var historical_replay := mutations.apply(
		PROFILE_ID,
		"transition-overflow-history",
		historical_mutation,
		root,
		9000,
		"test_overflow_history",
		{"amount": 7},
	)
	TestAssertions.truthy(historical_replay.ok() and historical_replay.duplicate, "older transaction replay after destructive backup recovery remains duplicate", failures)
	TestAssertions.equal(historical_invocations[0], 1, "older transaction replay never invokes its mutation again", failures)
	if historical_replay.ok():
		TestAssertions.truthy(not _contains_string(historical_replay.profile.to_dictionary(), plate.instance_id), "older duplicate result cannot expose the destroyed ID", failures)
	var corrupt_primary_bytes := FileAccess.get_file_as_bytes(path)
	var recovered_replay := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(recovered_replay.ok() and recovered_replay.duplicate, "destructive replay recovered from backup remains idempotent", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), corrupt_primary_bytes, "backup-recovered destructive replay performs no write", failures)
	var recovered_after_replay := store.load_profile(PROFILE_ID, root)
	if recovered_after_replay.ok():
		var replay_registry := ItemRegistry._decode(recovered_after_replay.profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)["value"] as ItemRegistry
		TestAssertions.truthy(not replay_registry.has(plate.instance_id), "backup-recovered replay cannot restore the destroyed instance", failures)
	ProfileTestSupport.remove_tree(root)

func _test_overflow_irreversible_save_failure_preserves_all_artifacts(failures: Array[String]) -> void:
	var root := _case_root("overflow_irreversible_failure")
	var good_store := ProfileStore.new()
	var plate := _item("item-overflow-failure-plate", &"dawn_bulwark_plate", 0)
	var profile := _profile([plate], {1: plate.instance_id}, [], "fighter")
	_save_profile(good_store, profile, root, "destructive failure source fixture", failures)
	TestAssertions.equal(good_store.save_profile(profile, root), "", "destructive failure fixture creates a prior backup generation", failures)
	var before := _file_snapshot(root)
	var promotion_count := [0]
	var failing_documents := AtomicJsonStore.new(func(temporary: String, target: String) -> Error:
		promotion_count[0] += 1
		if promotion_count[0] == 2:
			return ERR_CANT_CREATE
		return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
	)
	var failing_store := ProfileStore.new(failing_documents)
	var projection := _project(profile, &"mage")
	TestAssertions.equal(projection.overflow_item_ids, [plate.instance_id], "destructive failure fixture requires irreversible overflow", failures)
	var failed := LoadoutTransitionService.new(ProfileMutationService.new(failing_store)).apply(
		PROFILE_ID,
		_request("transition-overflow-irreversible-failure", projection),
		root,
	)
	_assert_failure(failed, "stage=promote-primary", "destructive irreversible save failure", failures)
	TestAssertions.equal(_file_snapshot(root), before, "destructive irreversible save failure preserves exact prior primary backup and artifact bytes", failures)
	var loaded := good_store.load_profile(PROFILE_ID, root)
	TestAssertions.truthy(loaded.ok(), "destructive failure leaves the prior profile readable", failures)
	if loaded.ok():
		var registry := ItemRegistry._decode(loaded.profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)["value"] as ItemRegistry
		TestAssertions.truthy(registry.has(plate.instance_id), "failed destructive save leaves the candidate item owned", failures)
		TestAssertions.truthy(not loaded.profile.applied_transactions.has("transition-overflow-irreversible-failure"), "failed destructive save records no transaction", failures)
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
		projection.state_fingerprint,
	)
	var cases: Array[Dictionary] = [
		{"label": "missing token", "request": LoadoutTransitionRequest.create("reject-missing-token", PROFILE_ID, &"mage", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, true, false, "", projection.state_fingerprint), "expected": "confirmation token"},
		{"label": "stale token", "request": LoadoutTransitionRequest.create("reject-stale-token", PROFILE_ID, &"mage", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, true, false, "0".repeat(64), projection.state_fingerprint), "expected": "confirmation token"},
		{"label": "not confirmed", "request": LoadoutTransitionRequest.create("reject-not-confirmed", PROFILE_ID, &"mage", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, false, false, projection.confirmation_token, projection.state_fingerprint), "expected": "confirmation required"},
		{"label": "cancelled", "request": LoadoutTransitionRequest.create("reject-cancelled", PROFILE_ID, &"mage", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, true, true, projection.confirmation_token, projection.state_fingerprint), "expected": "cancelled"},
		{"label": "wrong request profile", "request": LoadoutTransitionRequest.create("reject-wrong-profile", "profile-transition-other", &"mage", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, true, false, projection.confirmation_token, projection.state_fingerprint), "expected": "profile identity"},
		{"label": "unknown class", "request": LoadoutTransitionRequest.create("reject-unknown-class", PROFILE_ID, &"unknown", projection.incompatible_sources(), projection.planned_stash_destinations, projection.overflow_item_ids, true, false, projection.confirmation_token, projection.state_fingerprint), "expected": "unknown selected class"},
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

func _test_compatible_identity_and_slot_change_stales_request(failures: Array[String]) -> void:
	var root := _case_root("stale_compatible")
	var store := ProfileStore.new()
	var plate := _item("item-stale-compatible-plate", &"dawn_bulwark_plate", 0)
	var original_ring := _item("item-stale-compatible-ring-original", &"windrunner_band", 1)
	var replacement_ring := _item("item-stale-compatible-ring-replacement", &"windrunner_band", 2)
	var original := _profile(
		[plate, original_ring],
		{1: plate.instance_id, 6: original_ring.instance_id},
		[_stash(&"stash-tab-000", {})],
		"fighter",
	)
	_save_profile(store, original, root, "compatible stale-state source fixture", failures)
	var request := _request("reject-stale-compatible", _project(original, &"mage"))
	var changed := _profile(
		[plate, replacement_ring],
		{1: plate.instance_id, 7: replacement_ring.instance_id},
		[_stash(&"stash-tab-000", {})],
		"fighter",
	)
	TestAssertions.equal(store.save_profile(changed, root), "", "compatible stale-state fixture changes only compatible identity and slot", failures)
	_assert_stale_rejection_preserves_all_bytes(store, root, request, "compatible identity and slot change", failures)
	ProfileTestSupport.remove_tree(root)

func _test_overflow_source_record_change_stales_request(failures: Array[String]) -> void:
	var root := _case_root("stale_overflow_record")
	var store := ProfileStore.new()
	var plate := _item("item-stale-overflow-record-plate", &"dawn_bulwark_plate", 0)
	var original := _profile([plate], {1: plate.instance_id}, [], "fighter")
	_save_profile(store, original, root, "overflow record stale-state source fixture", failures)
	var projection := _project(original, &"mage")
	TestAssertions.equal(projection.planned_stash_destinations, [], "overflow record source has no stash destination", failures)
	TestAssertions.equal(projection.overflow_item_ids, [plate.instance_id], "overflow record source plans exact destructive item", failures)
	var request := _request("reject-stale-overflow-record", projection)
	var changed := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.truthy(_set_item_level(changed, plate.instance_id, plate.item_level + 1), "overflow record fixture finds equipped source record", failures)
	TestAssertions.equal(changed.leader_loadout, original.leader_loadout, "overflow record mutation preserves leader placement", failures)
	TestAssertions.equal(changed.stash_tabs, original.stash_tabs, "overflow record mutation preserves stored stash order and placement", failures)
	TestAssertions.equal(ProfileCodec.validate_profile(changed), "", "overflow record mutation remains a valid strict profile", failures)
	TestAssertions.equal(store.save_profile(changed, root), "", "overflow record fixture changes only equipped source data", failures)
	var changed_projection := _project(changed, &"mage")
	TestAssertions.equal(changed_projection.confirmation_document(), projection.confirmation_document(), "equipped record mutation preserves the narrow destructive confirmation document", failures)
	TestAssertions.equal(changed_projection.confirmation_token, projection.confirmation_token, "equipped record mutation preserves the narrow destructive confirmation token", failures)
	TestAssertions.truthy(changed_projection.state_fingerprint != projection.state_fingerprint, "equipped record mutation changes the complete preflight state fingerprint", failures)
	_assert_stale_rejection_preserves_all_bytes(store, root, request, "equipped overflow source record change", failures)
	ProfileTestSupport.remove_tree(root)

func _test_unrelated_stash_record_change_stales_request(failures: Array[String]) -> void:
	var root := _case_root("stale_stash_record")
	var store := ProfileStore.new()
	var plate := _item("item-stale-stash-record-plate", &"dawn_bulwark_plate", 0)
	var unrelated := _item("item-stale-stash-record-unrelated", &"windrunner_band", 1)
	var original := _profile(
		[plate, unrelated],
		{1: plate.instance_id},
		[_stash(&"stash-tab-000", {50: unrelated.instance_id})],
		"fighter",
	)
	_save_profile(store, original, root, "stash record stale-state source fixture", failures)
	var projection := _project(original, &"mage")
	TestAssertions.equal(projection.planned_stash_destinations, [
		{"instance_id": plate.instance_id, "destination_container_id": "stash-tab-000", "destination_slot": 0},
	], "stash record source plans a stable destination unrelated to the changed item", failures)
	var request := _request("reject-stale-stash-record", projection)
	var changed := store.load_profile(PROFILE_ID, root).profile
	TestAssertions.truthy(_set_item_level(changed, unrelated.instance_id, unrelated.item_level + 1), "stash record fixture finds unrelated stored record", failures)
	TestAssertions.equal(changed.leader_loadout, original.leader_loadout, "stash record mutation preserves leader placement", failures)
	TestAssertions.equal(changed.stash_tabs, original.stash_tabs, "stash record mutation preserves stored stash order and placement", failures)
	TestAssertions.equal(ProfileCodec.validate_profile(changed), "", "stash record mutation remains a valid strict profile", failures)
	TestAssertions.equal(store.save_profile(changed, root), "", "stash record fixture changes only unrelated stash item data", failures)
	var changed_projection := _project(changed, &"mage")
	TestAssertions.equal(changed_projection.confirmation_document(), projection.confirmation_document(), "unrelated stash record mutation preserves the transition plan", failures)
	TestAssertions.equal(changed_projection.confirmation_token, projection.confirmation_token, "unrelated stash record mutation preserves the narrow confirmation token", failures)
	TestAssertions.truthy(changed_projection.state_fingerprint != projection.state_fingerprint, "unrelated stash record mutation changes the complete preflight state fingerprint", failures)
	_assert_stale_rejection_preserves_all_bytes(store, root, request, "unrelated stash item record change", failures)
	ProfileTestSupport.remove_tree(root)

func _test_leader_loadout_class_change_stales_request(failures: Array[String]) -> void:
	var root := _case_root("stale_class")
	var store := ProfileStore.new()
	var plate := _item("item-stale-class-plate", &"dawn_bulwark_plate", 0)
	var original := _profile([plate], {1: plate.instance_id}, [_stash(&"stash-tab-000", {})], "fighter")
	_save_profile(store, original, root, "class stale-state source fixture", failures)
	var request := _request("reject-stale-class", _project(original, &"mage"))
	var changed := original.copy()
	changed.leader_loadout_class_id = "ranger"
	TestAssertions.equal(store.save_profile(changed, root), "", "class stale-state fixture changes only stored leader class", failures)
	_assert_stale_rejection_preserves_all_bytes(store, root, request, "leader loadout class change", failures)
	ProfileTestSupport.remove_tree(root)

func _test_unrelated_stash_occupancy_change_stales_request(failures: Array[String]) -> void:
	var root := _case_root("stale_stash")
	var store := ProfileStore.new()
	var plate := _item("item-stale-stash-plate", &"dawn_bulwark_plate", 0)
	var first := _item("item-stale-stash-first", &"windrunner_band", 1)
	var unrelated := _item("item-stale-stash-unrelated", &"windrunner_band", 2)
	var original := _profile(
		[plate, first, unrelated],
		{1: plate.instance_id},
		[_stash(&"stash-tab-000", {0: first.instance_id, 50: unrelated.instance_id})],
		"fighter",
	)
	_save_profile(store, original, root, "stash stale-state source fixture", failures)
	var projection := _project(original, &"mage")
	TestAssertions.equal(projection.planned_stash_destinations, [
		{"instance_id": plate.instance_id, "destination_container_id": "stash-tab-000", "destination_slot": 1},
	], "stash stale-state source plans the stable first-empty destination", failures)
	var request := _request("reject-stale-stash", projection)
	var changed := original.copy()
	(changed.stash_tabs[0]["slots"] as Dictionary).erase("50")
	(changed.stash_tabs[0]["slots"] as Dictionary)["51"] = unrelated.instance_id
	TestAssertions.equal(store.save_profile(changed, root), "", "stash stale-state fixture changes unrelated occupancy only", failures)
	TestAssertions.equal(_project(changed, &"mage").planned_stash_destinations, projection.planned_stash_destinations, "unrelated stash move preserves the original first-empty plan", failures)
	_assert_stale_rejection_preserves_all_bytes(store, root, request, "unrelated stash occupancy change", failures)
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
		projection.state_fingerprint,
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

func _set_item_level(profile: ProfileState, instance_id: String, item_level: int) -> bool:
	var records := profile.item_records.duplicate(true)
	var items := records.get("items", []) as Array
	for index: int in items.size():
		var item_document := items[index] as Dictionary
		if String(item_document.get("instance_id", "")) == instance_id:
			item_document["item_level"] = item_level
			profile.item_records = records
			return true
	return false

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

func _file_snapshot(root: String) -> Dictionary:
	var snapshot: Dictionary = {}
	for file_name: String in DirAccess.get_files_at(root):
		snapshot[file_name] = FileAccess.get_file_as_bytes(root.path_join(file_name))
	return snapshot

func _contains_string(value: Variant, needle: String) -> bool:
	if value is String or value is StringName:
		return String(value) == needle
	if value is Array:
		for child: Variant in value as Array:
			if _contains_string(child, needle):
				return true
		return false
	if value is Dictionary:
		for key: Variant in value as Dictionary:
			if _contains_string(key, needle) or _contains_string((value as Dictionary)[key], needle):
				return true
	return false

func _assert_failure(result: ProfileMutationResult, expected: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not result.ok(), "%s is rejected" % label, failures)
	TestAssertions.equal(result.profile, null, "%s exposes no candidate profile" % label, failures)
	TestAssertions.truthy(result.error.contains(expected), "%s reports %s" % [label, expected], failures)
	TestAssertions.truthy(not result.duplicate, "%s is not duplicate success" % label, failures)

func _assert_stale_rejection_preserves_all_bytes(
	store: ProfileStore,
	root: String,
	request: LoadoutTransitionRequest,
	label: String,
	failures: Array[String],
) -> void:
	var path := store.profile_path(PROFILE_ID, root)
	var backup_path := "%s.bak" % path
	TestAssertions.truthy(FileAccess.file_exists(backup_path), "%s has a backup generation before rejection" % label, failures)
	var primary_before := FileAccess.get_file_as_bytes(path)
	var backup_before := FileAccess.get_file_as_bytes(backup_path)
	var loaded_before := store.load_profile(PROFILE_ID, root)
	TestAssertions.truthy(loaded_before.ok(), "%s current profile loads before rejection" % label, failures)
	var profile_before := JSON.stringify(loaded_before.profile.to_dictionary()).to_utf8_buffer() if loaded_before.ok() else PackedByteArray()
	var service := LoadoutTransitionService.new(ProfileMutationService.new(store))
	_assert_failure(service.apply(PROFILE_ID, request, root), "stale projection", label, failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), primary_before, "%s preserves exact primary bytes" % label, failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(backup_path), backup_before, "%s preserves exact backup bytes" % label, failures)
	var loaded_after := store.load_profile(PROFILE_ID, root)
	TestAssertions.truthy(loaded_after.ok(), "%s current profile loads after rejection" % label, failures)
	var profile_after := JSON.stringify(loaded_after.profile.to_dictionary()).to_utf8_buffer() if loaded_after.ok() else PackedByteArray()
	TestAssertions.equal(profile_after, profile_before, "%s preserves exact decoded profile bytes" % label, failures)

func _case_root(label: String) -> String:
	_root_counter += 1
	return "user://tests/loadout_transition_%s_%d_%d_%d" % [label.validate_filename(), OS.get_process_id(), Time.get_ticks_usec(), _root_counter]
