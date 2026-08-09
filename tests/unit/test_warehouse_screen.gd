extends RefCounted

const EXPECTED_SUPPORTED_RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"mythic", &"exotic", &"ascendant", &"divine", &"eternal"]

func run() -> Array[String]:
	var failures: Array[String] = []
	var constants := (load("res://scripts/ui/main_menu/main_menu_view_model.gd") as Script).get_script_constant_map()
	TestAssertions.equal(constants.get("ROUTE_ARMOURY", &""), &"armoury", "Armoury route is exact", failures)
	TestAssertions.equal(constants.get("ROUTE_WAREHOUSE", &""), &"warehouse", "Warehouse route is exact", failures)
	var storage := Task9StorageFixture.storage(true)
	var screen := (load("res://scenes/ui/warehouse/warehouse_screen.tscn") as PackedScene).instantiate() as WarehouseScreen
	screen.call("_ready")
	screen.open(storage)
	TestAssertions.equal(screen.process_mode, Node.PROCESS_MODE_ALWAYS, "Warehouse processes while paused", failures)
	TestAssertions.equal(screen.stash_tab_count(), 3, "Warehouse reaches every unlocked stash tab", failures)
	TestAssertions.equal(screen.slot_button_count(), 100, "Warehouse exposes full selected sparse tab capacity", failures)
	TestAssertions.truthy(screen.get_node_or_null("Overlay/Frame/Layout/Body/Equipment") == null, "Warehouse has no equipment sheet", failures)
	for path: String in ["Organization/Search", "Organization/Rarity", "Organization/ItemType", "Organization/Sort", "Footer/Category", "Footer/BulkMove"]:
		TestAssertions.truthy(screen.get_node_or_null("Overlay/Frame/Layout/%s" % path) != null, "Warehouse organization control exists: %s" % path, failures)
	_assert_supported_rarity_filters(screen, failures)
	var projection := screen.projection()
	TestAssertions.equal(projection.stash_tabs[0]["slots"], {"99": "item-ring"}, "Warehouse retains exact shared sparse placement", failures)
	TestAssertions.equal(projection.item("item-ring")["instance_id"], "item-ring", "Warehouse shares exact item identity", failures)
	var filtered := projection.displayed_items("windrunner", &"uncommon", &"ring", &"name")
	TestAssertions.equal(filtered.size(), 1, "Warehouse search filters display only", failures)
	TestAssertions.equal(projection.stash_tabs[0]["slots"], {"99": "item-ring"}, "display search/filter/sort never rewrites placement", failures)
	var bulk: Array = []
	screen.bulk_action_requested.connect(func(action: StringName, ids: PackedStringArray) -> void: bulk.append([action, ids]))
	(screen.get_node("Overlay/Frame/Layout/Footer/Category") as Button).pressed.emit()
	TestAssertions.equal((bulk[0] as Array)[0] if not bulk.is_empty() else &"", &"category", "Warehouse category control emits intent only", failures)
	TestAssertions.truthy(screen.get_node_or_null("Overlay/Frame/Layout/Footer/BulkSelect") is Button, "Warehouse exposes an accessible explicit bulk-selection control", failures)
	screen.call("_select_item", "item-ring")
	TestAssertions.equal(screen.selected_item_detail()["instance_id"], "item-ring", "Warehouse selected-item API remains available without a persistent inspector", failures)
	TestAssertions.truthy(screen.get_node_or_null("Overlay/Frame/Layout/Body/Inspector") == null, "Warehouse removes the persistent inspector column", failures)
	var occupied := _button_for_item(screen, "item-ring")
	TestAssertions.equal(occupied.text, "", "occupied Warehouse card renders no slot number or truncated name", failures)
	TestAssertions.truthy(occupied.icon != null, "occupied Warehouse card renders its authored icon", failures)
	var empty := _button_for_slot(screen, 0)
	TestAssertions.equal(empty.text, "", "empty Warehouse storage cell remains visually neutral", failures)
	TestAssertions.truthy(empty.accessibility_name.contains("Empty storage slot"), "empty Warehouse cell retains accessible location context", failures)
	screen.apply_viewport_size(Vector2i(3840, 2160))
	TestAssertions.truthy(not (screen.get_node("Overlay/Frame/Layout/Body") as BoxContainer).vertical, "4K Warehouse remains wide and container-driven", failures)

	var sort_storage := Task9StorageFixture.sorting_storage()
	screen.open(sort_storage)
	var exact_before := screen.projection().stash_tabs.duplicate(true)
	var sort_control := screen.get_node("Overlay/Frame/Layout/Organization/Sort") as OptionButton
	sort_control.select(1)
	sort_control.item_selected.emit(1)
	TestAssertions.equal(_visible_ids(screen, 3), PackedStringArray(["item-pact", "item-storm", "item-wind"]), "Name sort visibly reorders occupied cards", failures)
	TestAssertions.equal(_visible_slots(screen, 3), PackedInt32Array([9, 3, 7]), "Name-sorted cards retain true persisted slot metadata", failures)
	sort_control.select(2)
	sort_control.item_selected.emit(2)
	TestAssertions.equal(_visible_ids(screen, 3), PackedStringArray(["item-storm", "item-wind", "item-pact"]), "Item Level sort is stable for ties and visible", failures)
	TestAssertions.equal(_visible_slots(screen, 3), PackedInt32Array([3, 7, 9]), "Item Level-sorted cards retain true destination metadata", failures)
	TestAssertions.equal(screen.projection().stash_tabs, exact_before, "display sorting leaves shared projection placement byte-exact", failures)

	screen.open(_comparison_storage(), null, true)
	var compare_button := _button_for_item(screen, "stash-ring")
	compare_button.inspection_started.emit(compare_button)
	var tooltip := screen.get_node("Overlay/ItemTooltip") as Control
	TestAssertions.truthy(tooltip.visible, "Warehouse focus or hover opens the shared item tooltip", failures)
	tooltip.call("set_compare_active", true)
	TestAssertions.equal(int(tooltip.call("card_count")), 3, "Warehouse ring compares against both occupied leader ring slots", failures)
	tooltip.call("toggle_pin")
	screen.close()
	TestAssertions.truthy(not tooltip.visible and not bool(tooltip.call("is_pinned")), "closing Warehouse force-dismisses and unpins its tooltip", failures)
	screen.free()
	return failures

func _assert_supported_rarity_filters(screen: WarehouseScreen, failures: Array[String]) -> void:
	var control := screen.get_node("Overlay/Frame/Layout/Organization/Rarity") as OptionButton
	TestAssertions.equal(control.item_count, EXPECTED_SUPPORTED_RARITIES.size() + 1, "Warehouse exposes All plus all ten supported rarities", failures)
	TestAssertions.equal(StringName(control.get_item_metadata(0)), &"", "Warehouse All Rarities metadata is empty", failures)
	var actual_ids: Array[StringName] = []
	for index: int in range(1, control.item_count):
		actual_ids.append(StringName(control.get_item_metadata(index)))
		var rarity_id := EXPECTED_SUPPORTED_RARITIES[index - 1] if index - 1 < EXPECTED_SUPPORTED_RARITIES.size() else &""
		TestAssertions.equal(control.get_item_text(index), String(rarity_id).capitalize(), "Warehouse rarity %d label follows manifest order" % index, failures)
	TestAssertions.equal(actual_ids, EXPECTED_SUPPORTED_RARITIES, "Warehouse rarity filter metadata follows all ten supported IDs in manifest order", failures)
	for rarity_id: StringName in [&"exotic", &"ascendant", &"divine"]:
		TestAssertions.truthy(rarity_id in actual_ids, "Warehouse includes supported %s rarity filter" % rarity_id, failures)

func _visible_ids(screen: WarehouseScreen, count: int) -> PackedStringArray:
	var result := PackedStringArray()
	var grid := screen.get_node("Overlay/Frame/Layout/Body/Storage/Scroll/Grid") as GridContainer
	for index: int in mini(count, grid.get_child_count()): result.append((grid.get_child(index) as StorageSlotButton).item_id)
	return result

func _visible_slots(screen: WarehouseScreen, count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var grid := screen.get_node("Overlay/Frame/Layout/Body/Storage/Scroll/Grid") as GridContainer
	for index: int in mini(count, grid.get_child_count()): result.append((grid.get_child(index) as StorageSlotButton).slot)
	return result


func _button_for_item(screen: WarehouseScreen, item_id: String) -> StorageSlotButton:
	var grid := screen.get_node("Overlay/Frame/Layout/Body/Storage/Scroll/Grid") as GridContainer
	for child: Node in grid.get_children():
		var button := child as StorageSlotButton
		if button != null and button.item_id == item_id:
			return button
	return null


func _button_for_slot(screen: WarehouseScreen, slot: int) -> StorageSlotButton:
	var grid := screen.get_node("Overlay/Frame/Layout/Body/Storage/Scroll/Grid") as GridContainer
	for child: Node in grid.get_children():
		var button := child as StorageSlotButton
		if button != null and button.slot == slot:
			return button
	return null


func _comparison_storage() -> ProfileStorageProjection:
	var stash_ring := _item("stash-ring", &"windrunner_band", 0)
	var left_ring := _item("left-ring", &"storm_ring", 1)
	var right_ring := _item("right-ring", &"pact_ring", 2)
	var profile := ProfileState.new_profile("warehouse-comparison", "Warehouse Comparison", 1000)
	profile.item_records = ItemRegistry.new([stash_ring, left_ring, right_ring]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout",
		ItemSlotContainer.PROFILE_LEADER_EQUIPMENT,
		profile.profile_id,
		11,
		{6: left_ring.instance_id, 7: right_ring.instance_id},
	).to_dictionary()
	profile.leader_loadout_class_id = "fighter"
	profile.stash_tabs = [ItemSlotContainer.create(
		&"stash-tab-compare",
		ItemSlotContainer.PROFILE_STASH_TAB,
		profile.profile_id,
		100,
		{99: stash_ring.instance_id},
	).to_dictionary()]
	return ProfileStorageProjection.from_profile(
		profile,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		GameCatalog.STAT_CATALOG,
		GameCatalog.load_defaults().class_by_id(&"fighter"),
	)


func _item(instance_id: String, base_id: StringName, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 31
	item.rarity_id = &"rare"
	item.origin = {"issuer_namespace": "profile:warehouse-comparison", "seed": 45, "sequence": sequence, "source": "warehouse_test"}
	return item
