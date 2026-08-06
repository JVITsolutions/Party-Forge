extends SceneTree

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var failures: Array[String] = []
	var storage := Task9StorageFixture.storage(false)
	var origin := Button.new()
	origin.name = "StorageOrigin"
	origin.text = "Origin"
	root.add_child(origin)
	var armoury := (load("res://scenes/ui/armoury/armoury_screen.tscn") as PackedScene).instantiate() as ArmouryScreen
	var warehouse := (load("res://scenes/ui/warehouse/warehouse_screen.tscn") as PackedScene).instantiate() as WarehouseScreen
	root.add_child(armoury)
	root.add_child(warehouse)
	armoury.configure_classes(GameCatalog.load_defaults().classes)
	armoury.close_requested.connect(armoury.close)
	warehouse.close_requested.connect(warehouse.close)
	for viewport_size: Vector2i in SIZES:
		root.content_scale_size = Vector2i(1920, 1080)
		root.size = viewport_size
		armoury.apply_viewport_size(viewport_size)
		armoury.open(storage, origin)
		await process_frame
		_assert(armoury.equipment_button_count() == 11, "Armoury has eleven leader slots at %s" % viewport_size, failures)
		_assert(armoury.stash_tab_count() == 3, "Armoury reaches every stash tab at %s" % viewport_size, failures)
		var armoury_ring := armoury.get_node("Overlay/Frame/Layout/Body/Stash/Scroll/Grid").get_child(99) as StorageSlotButton
		_assert(armoury_ring.text.is_empty() and armoury_ring.icon != null, "Armoury uses icon-only occupied cells at %s" % viewport_size, failures)
		armoury_ring.inspection_started.emit(armoury_ring)
		var armoury_tooltip := armoury.get_node("Overlay/ItemTooltip") as Control
		_assert(armoury_tooltip.visible and int(armoury_tooltip.call("card_count")) == 1, "Armoury opens shared item tooltip at %s" % viewport_size, failures)
		_assert(_inside(root.gui_get_focus_owner(), armoury), "Armoury focus is contained at %s" % viewport_size, failures)
		_assert(_frame_reachable(armoury.get_node("Overlay/Frame") as Control), "Armoury frame stays on-screen at %s" % viewport_size, failures)
		var tabs := armoury.get_node("Overlay/Frame/Layout/Body/Stash/Tabs") as TabBar
		for tab: int in tabs.tab_count:
			tabs.current_tab = tab
			await process_frame
			_assert((armoury.get_node("Overlay/Frame/Layout/Body/Stash/Scroll/Grid") as GridContainer).get_child_count() == 100, "Armoury tab %d exposes full capacity at %s" % [tab, viewport_size], failures)
		armoury.close()
		await process_frame
		_assert(root.gui_get_focus_owner() == origin, "Armoury close restores origin focus at %s" % viewport_size, failures)

		warehouse.apply_viewport_size(viewport_size)
		warehouse.open(storage, origin)
		await process_frame
		_assert(warehouse.stash_tab_count() == 3 and warehouse.slot_button_count() == 100, "Warehouse tabs/grid reachable at %s" % viewport_size, failures)
		var warehouse_ring := _button_for_item(warehouse.get_node("Overlay/Frame/Layout/Body/Storage/Scroll/Grid") as GridContainer, "item-ring")
		_assert(warehouse_ring != null and warehouse_ring.text.is_empty() and warehouse_ring.icon != null, "Warehouse uses icon-only occupied cells at %s" % viewport_size, failures)
		if warehouse_ring != null:
			warehouse_ring.inspection_started.emit(warehouse_ring)
		var warehouse_tooltip := warehouse.get_node("Overlay/ItemTooltip") as Control
		_assert(warehouse_tooltip.visible and int(warehouse_tooltip.call("card_count")) == 1, "Warehouse opens shared item tooltip at %s" % viewport_size, failures)
		_assert(_inside(root.gui_get_focus_owner(), warehouse), "Warehouse focus is contained at %s" % viewport_size, failures)
		_assert(_frame_reachable(warehouse.get_node("Overlay/Frame") as Control), "Warehouse frame stays on-screen at %s" % viewport_size, failures)
		for path: String in ["Search", "Rarity", "ItemType", "Sort"]:
			_assert((warehouse.get_node("Overlay/Frame/Layout/Organization/%s" % path) as Control).is_visible_in_tree(), "Warehouse %s reachable at %s" % [path, viewport_size], failures)
		warehouse.close()
		await process_frame
		_assert(root.gui_get_focus_owner() == origin, "Warehouse close restores origin focus at %s" % viewport_size, failures)
		print("TASK9_STORAGE_RESOLUTION_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])

	var equip_events: Array = []
	armoury.open(storage, origin)
	armoury.equip_requested.connect(func(item_id: String, slot_id: StringName, class_id: StringName) -> void: equip_events.append([item_id, slot_id, class_id]))
	await process_frame
	var stash_slot := armoury.get_node("Overlay/Frame/Layout/Body/Stash/Scroll/Grid").get_child(99) as StorageSlotButton
	stash_slot.grab_focus()
	await process_frame
	await _parse_action(&"item_sandbox_pickup")
	var leader_slot := armoury.get_node("Overlay/Frame/Layout/Body/Equipment/Slots").get_child(6) as StorageSlotButton
	leader_slot.grab_focus()
	await process_frame
	await _parse_action(&"ui_accept")
	_assert(not equip_events.is_empty() and equip_events[0][0] == "item-ring" and equip_events[0][1] == &"ring_left", "synthetic west-pickup/south-place emits exact equip intent", failures)
	armoury.close()
	var move_events: Array = []
	warehouse.move_requested.connect(func(item_id: String, container_id: StringName, slot: int) -> void: move_events.append([item_id, container_id, slot]))
	warehouse.open(storage, origin)
	await process_frame
	var warehouse_grid := warehouse.get_node("Overlay/Frame/Layout/Body/Storage/Scroll/Grid") as GridContainer
	var warehouse_source := _button_for_item(warehouse_grid, "item-ring")
	warehouse_source.grab_focus()
	await process_frame
	await _parse_action(&"item_sandbox_pickup")
	var warehouse_target := _button_for_slot(warehouse_grid, 4)
	warehouse_target.grab_focus()
	await process_frame
	await _parse_action(&"ui_accept")
	_assert(not move_events.is_empty() and move_events[0] == ["item-ring", &"stash-tab-zeta", 4], "Warehouse real west/south routing emits exact persisted-slot move intent", failures)
	warehouse.close()
	_assert(armoury.projection().stash_tabs == warehouse.projection().stash_tabs, "Armoury and Warehouse share exact item placements", failures)
	_assert(armoury.projection().storage_projection().item_records == warehouse.projection().storage_projection().item_records, "Armoury and Warehouse share exact inspector records", failures)
	armoury.close()
	armoury.queue_free()
	warehouse.queue_free()
	origin.queue_free()
	await process_frame
	for failure: String in failures:
		push_error("TASK9_STORAGE_INTEGRATION_FAILURE: %s" % failure)
	print("TASK9_STORAGE_RESPONSIVE_SUMMARY: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

func _parse_action(action: StringName) -> void:
	Input.parse_input_event(_action(action))
	await process_frame
	var release := _action(action)
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _inside(control: Control, ancestor: Node) -> bool:
	return control != null and (control == ancestor or ancestor.is_ancestor_of(control))

func _frame_reachable(frame: Control) -> bool:
	return frame != null and frame.is_visible_in_tree() and frame.size.x > 0.0 and frame.size.y > 0.0 and frame.position.x >= 0.0 and frame.position.y >= 0.0

func _button_for_item(grid: GridContainer, item_id: String) -> StorageSlotButton:
	for child: Node in grid.get_children():
		var button := child as StorageSlotButton
		if button != null and button.item_id == item_id: return button
	return null

func _button_for_slot(grid: GridContainer, slot: int) -> StorageSlotButton:
	for child: Node in grid.get_children():
		var button := child as StorageSlotButton
		if button != null and button.slot == slot: return button
	return null

func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
