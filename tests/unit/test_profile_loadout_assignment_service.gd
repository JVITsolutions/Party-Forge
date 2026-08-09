extends RefCounted

const PROFILE_ID := "profile-loadout-assign"
var _counter := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_equip_replay_collision_stale_and_save_failure(failures)
	_test_unequip_swap_class_and_reserved_rules(failures)
	_test_pure_preview_matches_apply(failures)
	_test_preview_allows_disabled_dependents_and_rejects_inactive_candidate(failures)
	_test_reverse_swap_rejects_inactive_item_entering_loadout(failures)
	_test_two_hand_displacement_and_reverse_swap_parity(failures)
	_test_displacement_uses_later_configured_stash_first_vacancy(failures)
	return failures


func _test_pure_preview_matches_apply(failures: Array[String]) -> void:
	var root := _root("pure_preview")
	var store := ProfileStore.new()
	var crown := _item("item-preview-crown", &"dawn_bulwark_crown", 20)
	var profile := _profile([crown], {}, [{3: crown.instance_id}, {}], "")
	TestAssertions.equal(store.save_profile(profile, root), "", "preview parity fixture saves", failures)
	var request := _request("preview-equip", profile, &"fighter", crown.instance_id, &"stash-tab-zeta", 3, &"leader-loadout", 0, "")
	var profile_before := profile.to_dictionary()
	var request_before := request.canonical_document()
	var disk_before := FileAccess.get_file_as_bytes(store.profile_path(PROFILE_ID, root))
	var service := ProfileLoadoutAssignmentService.new(ProfileMutationService.new(store))
	TestAssertions.truthy(service.has_method("preview"), "profile loadout service exposes pure preview", failures)
	if not service.has_method("preview"):
		ProfileTestSupport.remove_tree(root)
		return
	var preview := service.call("preview", profile, request) as ProfileMutationResult
	TestAssertions.truthy(preview != null and preview.ok(), "public loadout preview succeeds without persistence", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "preview does not mutate the supplied profile", failures)
	TestAssertions.equal(request.canonical_document(), request_before, "preview does not mutate the immutable request", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(store.profile_path(PROFILE_ID, root)), disk_before, "preview writes no profile bytes", failures)
	var committed := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(committed.ok(), "previewed request still commits", failures)
	if preview != null and preview.ok() and committed.ok():
		TestAssertions.equal(_assignment_projection(preview.profile), _assignment_projection(committed.profile), "preview ownership candidate matches committed candidate", failures)
	ProfileTestSupport.remove_tree(root)


func _assignment_projection(profile: ProfileState) -> Dictionary:
	return {
		"item_records": profile.item_records.duplicate(true),
		"leader_loadout": profile.leader_loadout.duplicate(true),
		"leader_loadout_class_id": profile.leader_loadout_class_id,
		"stash_tabs": profile.stash_tabs.duplicate(true),
	}


func _test_preview_allows_disabled_dependents_and_rejects_inactive_candidate(failures: Array[String]) -> void:
	var root := _root("disabled_preview")
	var store := ProfileStore.new()
	var support := _item_with_affix("item-support", &"forge_vanguard_sword", 30, _stout(2.0))
	var dependent := _item("item-dependent", &"forge_vanguard_helmet", 31)
	var replacement := _item("item-replacement", &"forge_vanguard_hammer", 32)
	var inactive := _item("item-inactive", &"forge_vanguard_boots", 33)
	var profile := _profile(
		[support, dependent, replacement, inactive],
		{EquipmentSlotIndex.index_for(&"helmet"): dependent.instance_id, EquipmentSlotIndex.index_for(&"main_hand"): support.instance_id},
		[{3: replacement.instance_id, 4: inactive.instance_id}, {}],
		"fighter",
	)
	TestAssertions.equal(store.save_profile(profile, root), "", "disabled preview fixture saves", failures)
	var equipment := _requirements_catalog()
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG.duplicate(true) as ItemFoundationCatalog
	var classes := GameCatalog.load_defaults()
	var fighter := classes.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	fighter.base_stat_overrides = {&"constitution": 3.0}
	for index: int in classes.classes.size():
		if classes.classes[index].id == &"fighter":
			classes.classes[index] = fighter
	var service := ProfileLoadoutAssignmentService.new(ProfileMutationService.new(store), null, equipment, foundation, classes)
	var swap_request := _request(
		"disabled-dependent-preview", profile, &"fighter", replacement.instance_id,
		&"stash-tab-zeta", 3, &"leader-loadout", EquipmentSlotIndex.index_for(&"main_hand"), support.instance_id,
	)
	var profile_before := profile.to_dictionary()
	var preview := service.preview(profile, swap_request)
	TestAssertions.truthy(preview.ok(), "support replacement may leave existing dependent equipped but disabled", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "disabled-dependent preview preserves supplied profile", failures)
	if preview.ok():
		var candidate_state := _ownership(preview.profile, equipment, foundation)
		var activation := EquipmentActivationResolver.resolve(
			1, &"leader-loadout", candidate_state, equipment, foundation, GameCatalog.STAT_CATALOG,
			fighter.stat_base_values(), fighter.capability_tags, [], 0,
		)
		TestAssertions.truthy(activation.ok() and activation.is_active(replacement.instance_id), "replacement is active in candidate", failures)
		TestAssertions.truthy(not activation.is_active(dependent.instance_id), "dependent remains equipped but disabled", failures)
		TestAssertions.truthy(not activation.disabled_reasons(dependent.instance_id).is_empty(), "disabled dependent exposes exact unmet requirement", failures)
	var committed := service.apply(PROFILE_ID, swap_request, root)
	TestAssertions.truthy(committed.ok(), "disabled-dependent candidate commits through the same path", failures)
	if preview.ok() and committed.ok():
		TestAssertions.equal(_assignment_projection(preview.profile), _assignment_projection(committed.profile), "disabled-dependent preview matches apply", failures)

	var inactive_profile := committed.profile if committed.ok() else profile
	var inactive_request := _request(
		"inactive-candidate-preview", inactive_profile, &"fighter", inactive.instance_id,
		&"stash-tab-zeta", 4, &"leader-loadout", EquipmentSlotIndex.index_for(&"boots"), "",
	)
	var inactive_before := inactive_profile.to_dictionary()
	var rejected := service.preview(inactive_profile, inactive_request)
	TestAssertions.truthy(not rejected.ok() and rejected.error.contains("newly placed item is inactive"), "newly placed inactive item is rejected", failures)
	TestAssertions.equal(inactive_profile.to_dictionary(), inactive_before, "inactive rejection preserves supplied profile", failures)
	ProfileTestSupport.remove_tree(root)


func _requirements_catalog() -> EquipmentCatalog:
	var result := EquipmentCatalog.new()
	for definition: EquipmentBaseDefinition in GameCatalog.EQUIPMENT_CATALOG.definitions:
		var owned := definition.duplicate(true) as EquipmentBaseDefinition
		if owned.id == &"forge_vanguard_helmet":
			owned.attribute_requirements = {&"constitution": 5.0}
		elif owned.id == &"forge_vanguard_boots":
			owned.attribute_requirements = {&"constitution": 10.0}
		result.definitions.append(owned)
	return result


func _hammer_requirements_catalog() -> EquipmentCatalog:
	var result := _requirements_catalog()
	for definition: EquipmentBaseDefinition in result.definitions:
		if definition.id == &"forge_vanguard_hammer":
			definition.attribute_requirements = {&"constitution": 10.0}
	return result


func _test_reverse_swap_rejects_inactive_item_entering_loadout(failures: Array[String]) -> void:
	var support := _item("reverse-support", &"forge_vanguard_sword", 50)
	var inactive := _item("reverse-inactive", &"forge_vanguard_hammer", 51)
	var profile := _profile(
		[support, inactive],
		{EquipmentSlotIndex.index_for(&"main_hand"): support.instance_id},
		[{7: inactive.instance_id}, {}],
		"fighter",
	)
	var classes := GameCatalog.load_defaults()
	var fighter := classes.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	fighter.base_stat_overrides = {&"constitution": 3.0}
	for index: int in classes.classes.size():
		if classes.classes[index].id == &"fighter":
			classes.classes[index] = fighter
	var service := ProfileLoadoutAssignmentService.new(null, null, _hammer_requirements_catalog(), GameCatalog.ITEM_FOUNDATION_CATALOG, classes)
	var request := _request(
		"reverse-inactive-swap", profile, &"fighter", support.instance_id,
		&"leader-loadout", EquipmentSlotIndex.index_for(&"main_hand"), &"stash-tab-zeta", 7, inactive.instance_id,
	)
	var before := profile.to_dictionary()
	var preview := service.preview(profile, request)
	TestAssertions.truthy(not preview.ok() and preview.error.contains("newly placed item is inactive") and preview.error.contains(inactive.instance_id), "reverse occupied swap rejects the inactive item entering the loadout", failures)
	TestAssertions.equal(profile.to_dictionary(), before, "reverse occupied swap rejection preserves supplied profile", failures)


func _test_two_hand_displacement_and_reverse_swap_parity(failures: Array[String]) -> void:
	var root := _root("two_hand_displacement")
	var store := ProfileStore.new()
	var light_bow := _item("profile-light-bow", &"greenwood_recurve_bow", 70)
	var light_quiver := _item("profile-light-quiver", &"greenwood_light_quiver", 71)
	var greatbow := _item("profile-greatbow", &"siege_greatbow", 72)
	var profile := _profile(
		[light_bow, light_quiver, greatbow],
		{
			EquipmentSlotIndex.index_for(&"main_hand"): light_bow.instance_id,
			EquipmentSlotIndex.index_for(&"off_hand"): light_quiver.instance_id,
		},
		[{7: greatbow.instance_id}, {}],
		"marksman",
	)
	TestAssertions.equal(store.save_profile(profile, root), "", "two-hand displacement fixture saves", failures)
	var service := ProfileLoadoutAssignmentService.new(ProfileMutationService.new(store))
	var equip_request := _request(
		"profile-greatbow-equip", profile, &"marksman", greatbow.instance_id,
		&"stash-tab-zeta", 7, &"leader-loadout", EquipmentSlotIndex.index_for(&"main_hand"), light_bow.instance_id,
	)
	var profile_before := profile.to_dictionary()
	var item_records_before := profile.item_records.duplicate(true)
	var preview := service.preview(profile, equip_request)
	TestAssertions.truthy(preview.ok(), "profile preview accepts occupied main-hand swap with reserved offhand displacement", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "displacement preview leaves its input profile unchanged", failures)
	if preview.ok():
		TestAssertions.equal(preview.profile.leader_loadout["slots"], {"9": greatbow.instance_id}, "two-hand preview equips only the greatbow", failures)
		TestAssertions.equal(preview.profile.stash_tabs[0]["slots"], {"0": light_quiver.instance_id, "7": light_bow.instance_id}, "two-hand preview stores displaced items deterministically", failures)
		TestAssertions.equal(preview.profile.item_records, item_records_before, "two-hand preview preserves immutable item records", failures)
	var committed := service.apply(PROFILE_ID, equip_request, root)
	TestAssertions.truthy(committed.ok(), "profile apply accepts the previewed displacement", failures)
	if preview.ok() and committed.ok():
		TestAssertions.equal(_assignment_projection(committed.profile), _assignment_projection(preview.profile), "two-hand displacement preview matches apply", failures)
		var reverse_request := _request(
			"profile-greatbow-reverse", committed.profile, &"marksman", greatbow.instance_id,
			&"leader-loadout", EquipmentSlotIndex.index_for(&"main_hand"), &"stash-tab-zeta", 7, light_bow.instance_id,
		)
		var reverse_preview := service.preview(committed.profile, reverse_request)
		TestAssertions.truthy(reverse_preview.ok(), "reverse occupied swap restores the stored main-hand item", failures)
		if reverse_preview.ok():
			TestAssertions.equal(reverse_preview.profile.leader_loadout["slots"], {"9": light_bow.instance_id}, "reverse swap puts the displaced storage item into the vacated equipment slot", failures)
			TestAssertions.equal(reverse_preview.profile.stash_tabs[0]["slots"], {"0": light_quiver.instance_id, "7": greatbow.instance_id}, "reverse swap preserves every exact item identity", failures)
			TestAssertions.equal(reverse_preview.profile.item_records, item_records_before, "reverse swap preserves immutable item records", failures)
		var reverse_commit := service.apply(PROFILE_ID, reverse_request, root)
		TestAssertions.truthy(reverse_commit.ok(), "reverse occupied swap commits", failures)
		if reverse_preview.ok() and reverse_commit.ok():
			TestAssertions.equal(_assignment_projection(reverse_commit.profile), _assignment_projection(reverse_preview.profile), "reverse swap preview matches apply", failures)
	ProfileTestSupport.remove_tree(root)


func _test_displacement_uses_later_configured_stash_first_vacancy(failures: Array[String]) -> void:
	var root := _root("later_stash_displacement")
	var store := ProfileStore.new()
	var light_bow := _item("priority-light-bow", &"greenwood_recurve_bow", 100)
	var light_quiver := _item("priority-light-quiver", &"greenwood_light_quiver", 101)
	var greatbow := _item("priority-greatbow", &"siege_greatbow", 102)
	var items: Array[ItemInstance] = [light_bow, light_quiver, greatbow]
	var primary_slots: Dictionary = {}
	for slot: int in ItemSlotContainer.STASH_CAPACITY:
		if slot == 7:
			primary_slots[slot] = greatbow.instance_id
			continue
		var filler := _item("priority-primary-%03d" % slot, &"steady_hand_ring", 200 + slot)
		items.append(filler)
		primary_slots[slot] = filler.instance_id
	var later_slots: Dictionary = {}
	for slot: int in 4:
		var filler := _item("priority-later-%03d" % slot, &"steady_hand_ring", 400 + slot)
		items.append(filler)
		later_slots[slot] = filler.instance_id
	var profile := ProfileState.new_profile(PROFILE_ID, "Storage Priority", 1000)
	profile.item_records = ItemRegistry.new(items).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, EquipmentSlotIndex.capacity(),
		{
			EquipmentSlotIndex.index_for(&"main_hand"): light_bow.instance_id,
			EquipmentSlotIndex.index_for(&"off_hand"): light_quiver.instance_id,
		},
	).to_dictionary()
	profile.leader_loadout_class_id = "marksman"
	profile.stash_tabs = [
		ItemSlotContainer.create(&"stash-tab-zeta", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, ItemSlotContainer.STASH_CAPACITY, primary_slots).to_dictionary(),
		ItemSlotContainer.create(&"stash-tab-alpha", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, ItemSlotContainer.STASH_CAPACITY, later_slots).to_dictionary(),
		ItemSlotContainer.create(&"stash-tab-omega", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, ItemSlotContainer.STASH_CAPACITY).to_dictionary(),
	]
	TestAssertions.equal(store.save_profile(profile, root), "", "later-stash displacement fixture saves", failures)
	var request := _request(
		"profile-storage-priority", profile, &"marksman", greatbow.instance_id,
		&"stash-tab-zeta", 7, &"leader-loadout", EquipmentSlotIndex.index_for(&"main_hand"), light_bow.instance_id,
	)
	var profile_before := profile.to_dictionary()
	var records_before := profile.item_records.duplicate(true)
	var service := ProfileLoadoutAssignmentService.new(ProfileMutationService.new(store))
	var preview := service.preview(profile, request)
	TestAssertions.truthy(preview.ok(), "full primary stash falls through to a later configured stash", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "storage-priority preview preserves its input profile", failures)
	if preview.ok():
		TestAssertions.equal(preview.profile.leader_loadout["slots"], {"9": greatbow.instance_id}, "storage-priority preview equips the requested greatbow", failures)
		TestAssertions.equal((preview.profile.stash_tabs[0]["slots"] as Dictionary).size(), ItemSlotContainer.STASH_CAPACITY, "primary storage remains full after exact occupied swap", failures)
		TestAssertions.equal(preview.profile.stash_tabs[0]["slots"]["7"], light_bow.instance_id, "occupied main-hand item returns to the exact primary source slot", failures)
		TestAssertions.equal(preview.profile.stash_tabs[1]["slots"]["4"], light_quiver.instance_id, "reserved offhand uses the first vacancy in the next configured stash", failures)
		TestAssertions.equal((preview.profile.stash_tabs[2]["slots"] as Dictionary), {}, "later empty stash remains untouched because configured order wins", failures)
		TestAssertions.equal(preview.profile.item_records, records_before, "cross-stash displacement preserves every immutable item record", failures)
	var committed := service.apply(PROFILE_ID, request, root)
	TestAssertions.truthy(committed.ok(), "cross-stash displacement commits", failures)
	if preview.ok() and committed.ok():
		TestAssertions.equal(_assignment_projection(committed.profile), _assignment_projection(preview.profile), "cross-stash displacement preview matches apply", failures)
	ProfileTestSupport.remove_tree(root)


func _item_with_affix(instance_id: String, base_id: StringName, sequence: int, affix: ItemAffixInstance) -> ItemInstance:
	var result := _item(instance_id, base_id, sequence)
	result.affixes = [affix]
	return result


func _stout(value: float) -> ItemAffixInstance:
	var roll := ItemModifierRoll.new()
	roll.stat_id = &"constitution"
	roll.operation = StatModifier.Operation.FLAT
	roll.value = value
	var result := ItemAffixInstance.new()
	result.definition_id = &"stout"
	result.affix_kind = "prefix"
	result.tier = 1
	result.rolls = [roll]
	return result


func _ownership(profile: ProfileState, equipment: EquipmentCatalog, foundation: ItemFoundationCatalog) -> ItemOwnershipState:
	var containers: Array = [profile.leader_loadout.duplicate(true)]
	containers.append_array(profile.stash_tabs.duplicate(true))
	var decoded := ItemOwnershipState.decode({
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": profile.profile_id,
		"registry": profile.item_records.duplicate(true),
		"containers": containers,
	}, equipment, foundation)
	return decoded.state if decoded.ok() else null

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
