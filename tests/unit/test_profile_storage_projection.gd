extends RefCounted

const PROFILE_ID := "profile-storage-projection"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_disabled_cascade_projection(failures)
	_test_rejected_preview_suppresses_raw_fallback(failures)
	var first := _item("item-zeta", &"dawn_bulwark_crown", 0)
	var second := _item("item-alpha", &"windrunner_band", 1)
	var equipped_ring := _item("item-equipped-ring", &"windrunner_band", 2)
	second.rarity_id = &"uncommon"
	var affix := ItemAffixInstance.new()
	affix.definition_id = &"stout"
	affix.affix_kind = "prefix"
	affix.tier = 2
	var roll := ItemModifierRoll.new()
	roll.stat_id = &"constitution"
	roll.operation = StatModifier.Operation.FLAT
	roll.value = 5.0
	affix.rolls.append(roll)
	second.affixes.append(affix)
	var profile := ProfileState.new_profile(PROFILE_ID, "Projection Tester", 1000)
	profile.item_records = ItemRegistry.new([first, second, equipped_ring] as Array[ItemInstance]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID,
		EquipmentSlotIndex.capacity(), {0: first.instance_id, EquipmentSlotIndex.index_for(&"ring_left"): equipped_ring.instance_id},
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
	TestAssertions.equal(detail["rarity_name"], "Uncommon", "inspector exposes authoritative rarity", failures)
	TestAssertions.equal(detail["item_level"], 31, "inspector exposes item level", failures)
	TestAssertions.equal(detail["affixes"], [{
		"definition_id": "stout",
		"display_name": "Stout",
		"affix_kind": "prefix",
		"tier": 2,
		"rolls": [{
			"stat_id": "constitution",
			"stat_name": "Constitution",
			"operation": StatModifier.Operation.FLAT,
			"operation_name": "Flat",
			"value": 5.0,
			"effect_text": "+5 Constitution",
			"minimum_roll": 4.0,
			"maximum_roll": 6.0,
			"roll_fraction": 0.5,
		}],
	}], "inspector exposes complete projected affix identity and roll fields", failures)
	TestAssertions.equal(detail["compatible_slot_ids"], ["ring_left", "ring_right"], "inspector exposes compatible slots", failures)
	TestAssertions.equal(detail["modifier_totals"], {"constitution|0": 5.0}, "inspector exposes safe comparable totals", failures)
	TestAssertions.equal(detail.get("is_disabled"), false, "stored candidate defaults to active presentation", failures)
	TestAssertions.equal(detail.get("disabled_requirement_lines"), PackedStringArray(), "active presentation has no disabled reasons", failures)
	TestAssertions.truthy(String(detail["icon_path"]).ends_with("windrunner_band_128.png"), "inspector exposes authoritative equipment icon", failures)
	TestAssertions.truthy(projection.has_method("comparison_lines_by_slot"), "projection exposes dry-run comparison rows", failures)
	if projection.has_method("comparison_lines_by_slot"):
		var by_slot: Dictionary = projection.comparison_lines_by_slot(second.instance_id)
		TestAssertions.truthy(by_slot.has("ring_left"), "compatible occupied slot receives a projection", failures)
		var left_rows: Array = by_slot.get("ring_left", [])
		TestAssertions.truthy(left_rows.any(func(row: Dictionary) -> bool:
			return String(row.get("stat_id", "")) == "constitution" and is_equal_approx(float(row.get("delta", 0.0)), 5.0)
		), "dry run compares final Constitution", failures)
		TestAssertions.truthy(left_rows.any(func(row: Dictionary) -> bool:
			return String(row.get("stat_id", "")) == "max_health" and is_equal_approx(float(row.get("delta", 0.0)), 15.0)
		), "attribute item includes derived maximum health", failures)
		TestAssertions.truthy(left_rows.any(func(row: Dictionary) -> bool:
			return String(row.get("stat_id", "")) == "health_regeneration" and is_equal_approx(float(row.get("delta", 0.0)), 0.25)
		), "attribute item includes derived defensive regeneration", failures)
	var escaped_tabs := projection.stash_tabs
	escaped_tabs[0]["slots"] = {}
	var escaped_slots := projection.leader_slots
	escaped_slots[0]["instance_id"] = "escaped"
	var escaped_detail := projection.item(second.instance_id)
	escaped_detail["name"] = "escaped"
	(escaped_detail["affixes"] as Array)[0]["display_name"] = "escaped"
	TestAssertions.equal(projection.stash_tabs[0]["slots"], {"99": second.instance_id}, "stash projection is defensive", failures)
	TestAssertions.equal(projection.leader_slots[0]["instance_id"], first.instance_id, "leader projection is defensive", failures)
	TestAssertions.equal(projection.item(second.instance_id)["name"], "Windrunner Band", "inspector is defensive", failures)
	TestAssertions.equal(projection.item(second.instance_id)["affixes"][0]["display_name"], "Stout", "projected affix documents are defensive", failures)
	var malformed_text := ProfileStorageProjection.inspector_text({"affixes": [{"rolls": [null]}]})
	TestAssertions.truthy(malformed_text.contains("Unknown roll"), "inspector formatting tolerates malformed projected affixes", failures)
	var malformed := profile.copy()
	malformed.stash_tabs.reverse()
	(malformed.stash_tabs[0]["slots"] as Dictionary)["0"] = first.instance_id
	var rejected := ProfileStorageProjection.from_profile(malformed, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(not rejected.valid and rejected.error.contains("ownership"), "strict projection rejects duplicate ownership", failures)
	return failures


func _test_disabled_cascade_projection(failures: Array[String]) -> void:
	var equipment := _requirements_catalog()
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG.duplicate(true) as ItemFoundationCatalog
	var fighter := GameCatalog.load_defaults().class_by_id(&"fighter").duplicate(true) as ClassDefinition
	fighter.base_stat_overrides = {&"constitution": 3.0}
	var support := _item_with_affix("cascade-support", &"forge_vanguard_sword", 40, _stout(2.0))
	var dependent := _item("cascade-dependent", &"forge_vanguard_helmet", 41)
	var replacement := _item("cascade-replacement", &"forge_vanguard_hammer", 42)
	var profile := ProfileState.new_profile(PROFILE_ID, "Cascade Projection", 1000)
	profile.item_records = ItemRegistry.new([support, dependent, replacement] as Array[ItemInstance]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, EquipmentSlotIndex.capacity(),
		{EquipmentSlotIndex.index_for(&"helmet"): dependent.instance_id, EquipmentSlotIndex.index_for(&"main_hand"): support.instance_id},
	).to_dictionary()
	profile.leader_loadout_class_id = "fighter"
	profile.stash_tabs = [_stash(&"stash-tab-cascade", {3: replacement.instance_id})]
	var projection := ProfileStorageProjection.from_profile(profile, equipment, foundation, GameCatalog.STAT_CATALOG, fighter)
	TestAssertions.truthy(projection.valid, "cascade projection accepts supported dependent", failures)
	if projection.valid:
		var rows: Array = projection.comparison_lines_by_slot(replacement.instance_id).get("main_hand", [])
		TestAssertions.truthy(rows.any(func(row: Dictionary) -> bool:
			return String(row.get("row_type", "")) == "warning" and String(row.get("item_id", "")) == dependent.instance_id and String(row.get("text", "")).contains("Requires Constitution 5 (has 3)")
		), "support replacement projects a prominent disabled-dependent warning", failures)

	var disabled_profile := profile.copy()
	disabled_profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, EquipmentSlotIndex.capacity(),
		{EquipmentSlotIndex.index_for(&"helmet"): dependent.instance_id, EquipmentSlotIndex.index_for(&"main_hand"): replacement.instance_id},
	).to_dictionary()
	disabled_profile.stash_tabs = [_stash(&"stash-tab-cascade", {3: support.instance_id})]
	var disabled_projection := ProfileStorageProjection.from_profile(disabled_profile, equipment, foundation, GameCatalog.STAT_CATALOG, fighter)
	TestAssertions.truthy(disabled_projection.valid, "disabled equipped profile remains projectable", failures)
	if disabled_projection.valid:
		var disabled_detail := disabled_projection.item(dependent.instance_id)
		TestAssertions.equal(disabled_detail.get("is_disabled"), true, "disabled equipped detail is annotated", failures)
		TestAssertions.equal(PackedStringArray(disabled_detail.get("disabled_requirement_lines", PackedStringArray())), PackedStringArray(["Requires Constitution 5 (has 3)"]), "disabled detail carries exact human requirement wording", failures)


func _test_rejected_preview_suppresses_raw_fallback(failures: Array[String]) -> void:
	var equipped := _item("failure-equipped-boots", &"forge_vanguard_boots", 60)
	var incompatible := _item("failure-incompatible-boots", &"greenwood_boots", 61)
	var profile := ProfileState.new_profile(PROFILE_ID, "Projection Failure", 1000)
	profile.item_records = ItemRegistry.new([equipped, incompatible] as Array[ItemInstance]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, EquipmentSlotIndex.capacity(),
		{EquipmentSlotIndex.index_for(&"boots"): equipped.instance_id},
	).to_dictionary()
	profile.leader_loadout_class_id = "fighter"
	profile.stash_tabs = [_stash(&"stash-tab-failure", {4: incompatible.instance_id})]
	var projection := ProfileStorageProjection.from_profile(profile, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(projection.valid, "failed-preview fixture projects its current valid loadout", failures)
	if projection.valid:
		var by_slot := projection.comparison_lines_by_slot(incompatible.instance_id)
		TestAssertions.truthy(by_slot.has("boots"), "rejected dry run still marks the compatible slot as projected", failures)
		TestAssertions.truthy((by_slot.get("boots", []) as Array).any(func(row: Dictionary) -> bool:
			return String(row.get("row_type", "")) == "warning" and String(row.get("accessible_text", "")).contains("cannot be equipped")
		), "rejected dry run exposes an accessible projection warning instead of raw modifier fallback", failures)


func _requirements_catalog() -> EquipmentCatalog:
	var result := EquipmentCatalog.new()
	for definition: EquipmentBaseDefinition in GameCatalog.EQUIPMENT_CATALOG.definitions:
		var owned := definition.duplicate(true) as EquipmentBaseDefinition
		if owned.id == &"forge_vanguard_helmet":
			owned.attribute_requirements = {&"constitution": 5.0}
		result.definitions.append(owned)
	return result


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
