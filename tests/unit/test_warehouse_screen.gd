extends RefCounted

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
	var inspector_text := (screen.get_node("Overlay/Frame/Layout/Body/Inspector/Content/Detail") as Label).text
	for expected: String in ["stout", "Stout", "Tier 2", "Flat", "constitution", "5"]:
		TestAssertions.truthy(inspector_text.contains(expected), "Warehouse inspector renders affix field: %s" % expected, failures)
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
	screen.free()
	return failures

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
