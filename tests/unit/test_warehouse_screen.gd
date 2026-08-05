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
	var filtered := projection.displayed_items("windrunner", &"common", &"ring", &"name")
	TestAssertions.equal(filtered.size(), 1, "Warehouse search filters display only", failures)
	TestAssertions.equal(projection.stash_tabs[0]["slots"], {"99": "item-ring"}, "display search/filter/sort never rewrites placement", failures)
	var bulk: Array = []
	screen.bulk_action_requested.connect(func(action: StringName, ids: PackedStringArray) -> void: bulk.append([action, ids]))
	(screen.get_node("Overlay/Frame/Layout/Footer/Category") as Button).pressed.emit()
	TestAssertions.equal((bulk[0] as Array)[0] if not bulk.is_empty() else &"", &"category", "Warehouse category control emits intent only", failures)
	screen.apply_viewport_size(Vector2i(3840, 2160))
	TestAssertions.truthy(not (screen.get_node("Overlay/Frame/Layout/Body") as BoxContainer).vertical, "4K Warehouse remains wide and container-driven", failures)
	screen.free()
	return failures
