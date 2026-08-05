class_name Task9StorageFixture
extends RefCounted

const PROFILE_ID := "profile-task9-ui"

static func storage(nonempty: bool, empty_active_class_id: StringName = &"") -> ProfileStorageProjection:
	var ring := _item("item-ring", &"windrunner_band", 0)
	ring.rarity_id = &"uncommon"
	var affix := ItemAffixInstance.new()
	affix.definition_id = &"stout"
	affix.affix_kind = "prefix"
	affix.tier = 2
	var roll := ItemModifierRoll.new()
	roll.stat_id = &"constitution"
	roll.operation = StatModifier.Operation.FLAT
	roll.value = 5.0
	affix.rolls.append(roll)
	ring.affixes.append(affix)
	var crown := _item("item-crown", &"dawn_bulwark_crown", 1)
	var items: Array[ItemInstance] = [ring, crown]
	var profile := ProfileState.new_profile(PROFILE_ID, "Task 9 UI", 1000)
	profile.item_records = ItemRegistry.new(items).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, 11, {0: crown.instance_id} if nonempty else {}).to_dictionary()
	profile.leader_loadout_class_id = "fighter" if nonempty else String(empty_active_class_id)
	profile.stash_tabs = [
		ItemSlotContainer.create(&"stash-tab-zeta", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, {99: ring.instance_id}).to_dictionary(),
		ItemSlotContainer.create(&"stash-tab-alpha", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, {}).to_dictionary(),
		ItemSlotContainer.create(&"stash-tab-middle", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, {}).to_dictionary(),
	]
	if not nonempty:
		(profile.stash_tabs[1]["slots"] as Dictionary)["7"] = crown.instance_id
	return ProfileStorageProjection.from_profile(profile, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)

static func sorting_storage() -> ProfileStorageProjection:
	var storm := _item("item-storm", &"storm_ring", 0, 50)
	var wind := _item("item-wind", &"windrunner_band", 1, 50)
	var pact := _item("item-pact", &"pact_ring", 2, 10)
	var profile := ProfileState.new_profile(PROFILE_ID, "Task 9 Sort", 1000)
	profile.item_records = ItemRegistry.new([storm, wind, pact]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, 11).to_dictionary()
	profile.stash_tabs = [
		ItemSlotContainer.create(&"stash-tab-sort", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, {
			3: storm.instance_id,
			7: wind.instance_id,
			9: pact.instance_id,
		}).to_dictionary(),
	]
	return ProfileStorageProjection.from_profile(profile, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)

static func _item(instance_id: String, base_id: StringName, sequence: int, item_level: int = 31) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = item_level
	item.rarity_id = &"common"
	item.origin = {"issuer_namespace": "profile:%s" % PROFILE_ID, "seed": 29, "sequence": sequence, "source": "task9_ui_test"}
	return item
