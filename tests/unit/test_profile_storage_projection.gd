extends RefCounted

const PROFILE_ID := "profile-storage-projection"

func run() -> Array[String]:
	var failures: Array[String] = []
	var first := _item("item-zeta", &"dawn_bulwark_crown", 0)
	var second := _item("item-alpha", &"windrunner_band", 1)
	var profile := ProfileState.new_profile(PROFILE_ID, "Projection Tester", 1000)
	profile.item_records = ItemRegistry.new([first, second] as Array[ItemInstance]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID,
		EquipmentSlotIndex.capacity(), {0: first.instance_id},
	).to_dictionary()
	profile.leader_loadout_class_id = "fighter"
	profile.stash_tabs = [
		_stash(&"stash-tab-zeta", {99: second.instance_id}),
		_stash(&"stash-tab-alpha", {}),
		_stash(&"stash-tab-middle", {}),
	]
	var projection := ProfileStorageProjection.from_profile(profile, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(projection.valid, "strict shared storage projection succeeds", failures)
	TestAssertions.equal(projection.active_class_id, &"fighter", "projection exposes active loadout class", failures)
	TestAssertions.equal(projection.leader_slots.size(), 11, "projection exposes eleven canonical leader slots", failures)
	TestAssertions.equal(projection.leader_slots[0], {"slot_id": "helmet", "slot": 0, "instance_id": first.instance_id}, "leader placement is exact", failures)
	TestAssertions.equal(_tab_ids(projection.stash_tabs), ["stash-tab-zeta", "stash-tab-alpha", "stash-tab-middle"], "stored nonlexical stash order is exact", failures)
	TestAssertions.equal(projection.stash_tabs[0]["capacity"], 100, "stash capacity is exact", failures)
	TestAssertions.equal(projection.stash_tabs[0]["slots"], {"99": second.instance_id}, "sparse stash placement is exact", failures)
	var detail := projection.item(second.instance_id)
	TestAssertions.equal(detail["instance_id"], second.instance_id, "inspector exposes exact item identity", failures)
	TestAssertions.equal(detail["name"], "Windrunner Band", "inspector exposes authoritative name", failures)
	TestAssertions.equal(detail["rarity_name"], "Common", "inspector exposes authoritative rarity", failures)
	TestAssertions.equal(detail["item_level"], 31, "inspector exposes item level", failures)
	TestAssertions.equal(detail["affixes"], [], "inspector exposes affixes", failures)
	TestAssertions.truthy(String(detail["icon_path"]).ends_with("windrunner_band_128.png"), "inspector exposes authoritative equipment icon", failures)
	var escaped_tabs := projection.stash_tabs
	escaped_tabs[0]["slots"] = {}
	var escaped_slots := projection.leader_slots
	escaped_slots[0]["instance_id"] = "escaped"
	var escaped_detail := projection.item(second.instance_id)
	escaped_detail["name"] = "escaped"
	TestAssertions.equal(projection.stash_tabs[0]["slots"], {"99": second.instance_id}, "stash projection is defensive", failures)
	TestAssertions.equal(projection.leader_slots[0]["instance_id"], first.instance_id, "leader projection is defensive", failures)
	TestAssertions.equal(projection.item(second.instance_id)["name"], "Windrunner Band", "inspector is defensive", failures)
	var malformed := profile.copy()
	malformed.stash_tabs.reverse()
	(malformed.stash_tabs[0]["slots"] as Dictionary)["0"] = first.instance_id
	var rejected := ProfileStorageProjection.from_profile(malformed, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(not rejected.valid and rejected.error.contains("ownership"), "strict projection rejects duplicate ownership", failures)
	return failures

func _stash(id: StringName, slots: Dictionary) -> Dictionary:
	return ItemSlotContainer.create(id, ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, slots).to_dictionary()

func _item(instance_id: String, base_id: StringName, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 31
	item.rarity_id = &"common"
	item.origin = {"issuer_namespace": "profile:%s" % PROFILE_ID, "seed": 9, "sequence": sequence, "source": "projection_test"}
	return item

func _tab_ids(tabs: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for tab: Dictionary in tabs:
		result.append(String(tab["container_id"]))
	return result
