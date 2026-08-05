extends RefCounted

const PROFILE_ID := "profile-loadout-assign"
var _counter := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_equip_replay_collision_stale_and_save_failure(failures)
	_test_unequip_swap_class_and_reserved_rules(failures)
	return failures

func _test_equip_replay_collision_stale_and_save_failure(failures: Array[String]) -> void:
	var root := _root("equip")
	var store := ProfileStore.new()
	var crown := _item("item-equip-crown", &"dawn_bulwark_crown", 0)
	var ring := _item("item-unrelated-ring", &"windrunner_band", 1)
	var profile := _profile([crown, ring], {}, [{3: crown.instance_id}, {88: ring.instance_id}], "")
	TestAssertions.equal(store.save_profile(profile, root), "", "assignment fixture saves", failures)
	var request := _request("assign-equip", profile, &"fighter", crown.instance_id, &"stash-tab-zeta", 3, &"leader-loadout", 0, "")
	var reordered_profile := profile.copy()
	reordered_profile.stash_tabs.reverse()
	TestAssertions.truthy(
		ProfileLoadoutAssignmentRequest.fingerprint_for(profile) != ProfileLoadoutAssignmentRequest.fingerprint_for(reordered_profile),
		"complete preflight fingerprint includes stored stash-tab order",
		failures,
	)
	var escaped := request.canonical_document()
	escaped["item_id"] = "escaped"
	TestAssertions.equal(request.item_id, crown.instance_id, "assignment request is immutable and defensive", failures)
	var service := ProfileLoadoutAssignmentService.new(ProfileMutationService.new(store))
	var committed := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(committed.ok(), "stash item equips atomically", failures)
	TestAssertions.equal(committed.profile.leader_loadout["slots"], {"0": crown.instance_id}, "equip preserves exact leader slot", failures)
	TestAssertions.equal(committed.profile.leader_loadout_class_id, "fighter", "first equipped item binds target class", failures)
	TestAssertions.equal(committed.profile.stash_tabs[0]["slots"], {}, "equip clears exact source without compacting", failures)
	TestAssertions.equal(committed.profile.stash_tabs[1]["slots"], {"88": ring.instance_id}, "equip preserves unrelated sparse tab and order", failures)
	var replay := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(replay.ok() and replay.duplicate, "exact assignment replay is idempotent", failures)
	var collision_request := _request("assign-equip", profile, &"fighter", crown.instance_id, &"stash-tab-zeta", 3, &"leader-loadout", 1, "")
	var collision := service.apply(PROFILE_ID, collision_request, root)
	TestAssertions.truthy(not collision.ok() and collision.error.contains("transaction id conflict"), "assignment transaction collision is rejected", failures)
	var before := store.load_profile(PROFILE_ID, root).profile
	var stale := _request("assign-stale", profile, &"fighter", crown.instance_id, &"stash-tab-zeta", 3, &"leader-loadout", 0, "")
	var stale_result := service.apply(PROFILE_ID, stale, root)
	TestAssertions.truthy(not stale_result.ok() and stale_result.error.contains("stale"), "complete preflight fingerprint rejects stale state", failures)
	TestAssertions.equal(store.load_profile(PROFILE_ID, root).profile.to_dictionary(), before.to_dictionary(), "stale rejection preserves decoded profile", failures)

	var save_root := _root("save_failure")
	var save_profile := _profile([crown.copy()], {}, [{3: crown.instance_id}, {}], "")
	TestAssertions.equal(store.save_profile(save_profile, save_root), "", "save failure source saves", failures)
	TestAssertions.equal(store.save_profile(save_profile, save_root), "", "save failure source creates verified backup generation", failures)
	var path := store.profile_path(PROFILE_ID, save_root)
	var primary_before := FileAccess.get_file_as_bytes(path)
	var backup_before := FileAccess.get_file_as_bytes("%s.bak" % path)
	var decoded_before := store.load_profile(PROFILE_ID, save_root).profile.to_dictionary()
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var failed := ProfileLoadoutAssignmentService.new(ProfileMutationService.new(failing_store)).apply(
		PROFILE_ID, _request("assign-save-fail", save_profile, &"fighter", crown.instance_id, &"stash-tab-zeta", 3, &"leader-loadout", 0, ""), save_root,
	)
	TestAssertions.truthy(not failed.ok() and failed.error.contains("JSON_STORE_SAVE_ERROR"), "save failure is reported", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), primary_before, "save failure preserves exact primary bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % path), backup_before, "save failure preserves exact backup bytes", failures)
	TestAssertions.equal(store.load_profile(PROFILE_ID, save_root).profile.to_dictionary(), decoded_before, "save failure preserves exact decoded profile bytes", failures)
	ProfileTestSupport.remove_tree(root)
	ProfileTestSupport.remove_tree(save_root)

func _test_unequip_swap_class_and_reserved_rules(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var crown_a := _item("item-crown-a", &"dawn_bulwark_crown", 0)
	var crown_b := _item("item-crown-b", &"dawn_bulwark_crown", 1)
	var root := _root("swap")
	var profile := _profile([crown_a, crown_b], {0: crown_a.instance_id}, [{7: crown_b.instance_id}, {}], "fighter")
	TestAssertions.equal(store.save_profile(profile, root), "", "swap fixture saves", failures)
	var service := ProfileLoadoutAssignmentService.new(ProfileMutationService.new(store))
	var swapped := service.apply(PROFILE_ID, _request("assign-swap", profile, &"fighter", crown_b.instance_id, &"stash-tab-zeta", 7, &"leader-loadout", 0, crown_a.instance_id), root)
	TestAssertions.truthy(swapped.ok(), "occupied loadout slot swaps exact item identities", failures)
	TestAssertions.equal(swapped.profile.leader_loadout["slots"], {"0": crown_b.instance_id}, "swap equips requested item", failures)
	TestAssertions.equal(swapped.profile.stash_tabs[0]["slots"], {"7": crown_a.instance_id}, "swap returns occupied item to exact source", failures)
	var class_rejected := service.apply(PROFILE_ID, _request("assign-class-change", swapped.profile, &"mage", crown_b.instance_id, &"leader-loadout", 0, &"stash-tab-zeta", 8, ""), root)
	TestAssertions.truthy(not class_rejected.ok() and class_rejected.error.contains("compatibility transition"), "nonempty class change routes to future transition boundary", failures)
	var unequipped := service.apply(PROFILE_ID, _request("assign-unequip", swapped.profile, &"fighter", crown_b.instance_id, &"leader-loadout", 0, &"stash-tab-alpha", 22, ""), root)
	TestAssertions.truthy(unequipped.ok(), "leader item unequips to exact stash slot", failures)
	TestAssertions.equal(unequipped.profile.leader_loadout["slots"], {}, "unequip clears exact leader slot", failures)
	TestAssertions.equal(unequipped.profile.stash_tabs[1]["slots"], {"22": crown_b.instance_id}, "unequip preserves exact destination placement", failures)

	var rules_root := _root("reserved")
	var bow := _item("item-bow", &"greenwood_recurve_bow", 2)
	var shield := _item("item-shield", &"forge_vanguard_shield", 3)
	var rules := _profile([bow, shield], {9: bow.instance_id}, [{5: shield.instance_id}, {}], "ranger")
	TestAssertions.equal(store.save_profile(rules, rules_root), "", "reserved-rule fixture saves", failures)
	var rejected := service.apply(PROFILE_ID, _request("assign-reserved", rules, &"ranger", shield.instance_id, &"stash-tab-zeta", 5, &"leader-loadout", 10, ""), rules_root)
	TestAssertions.truthy(not rejected.ok() and rejected.error.contains("ineligible resulting loadout"), "complete resulting loadout rechecks class and reserved offhand eligibility", failures)
	TestAssertions.equal(store.load_profile(PROFILE_ID, rules_root).profile.to_dictionary(), rules.to_dictionary(), "eligibility rejection preserves profile", failures)
	ProfileTestSupport.remove_tree(root)
	ProfileTestSupport.remove_tree(rules_root)

func _profile(items: Array[ItemInstance], leader_slots: Dictionary, tab_slots: Array[Dictionary], class_id: String) -> ProfileState:
	var profile := ProfileState.new_profile(PROFILE_ID, "Assignment Tester", 1000)
	profile.item_records = ItemRegistry.new(items).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, 11, leader_slots).to_dictionary()
	profile.leader_loadout_class_id = class_id
	profile.stash_tabs = [
		ItemSlotContainer.create(&"stash-tab-zeta", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, tab_slots[0]).to_dictionary(),
		ItemSlotContainer.create(&"stash-tab-alpha", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, tab_slots[1]).to_dictionary(),
	]
	return profile

func _request(transaction_id: String, profile: ProfileState, class_id: StringName, item_id: String, source_id: StringName, source_slot: int, destination_id: StringName, destination_slot: int, occupied: String) -> ProfileLoadoutAssignmentRequest:
	return ProfileLoadoutAssignmentRequest.create(transaction_id, PROFILE_ID, class_id, item_id, source_id, source_slot, destination_id, destination_slot, occupied, ProfileLoadoutAssignmentRequest.fingerprint_for(profile))

func _item(instance_id: String, base_id: StringName, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 31
	item.rarity_id = &"common"
	item.origin = {"issuer_namespace": "profile:%s" % PROFILE_ID, "seed": 19, "sequence": sequence, "source": "assignment_test"}
	return item

func _root(label: String) -> String:
	_counter += 1
	return "user://tests/profile_loadout_assignment_%s_%d_%d" % [label, OS.get_process_id(), _counter]
