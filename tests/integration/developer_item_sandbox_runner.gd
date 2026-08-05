extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/ui/developer_item_sandbox.tscn")
const DOCUMENT_PATH := "user://developer_item_sandbox/sandbox.json"
const SANDBOX_ROOT := "user://developer_item_sandbox"
const LOGICAL_SIZE := Vector2i(1920, 1080)
const TARGET_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const ACTION_PATHS: Array[NodePath] = [
	^"Overlay/Frame/Layout/Actions/FirstEmptyInventory",
	^"Overlay/Frame/Layout/Actions/FirstEmptyStash",
	^"Overlay/Frame/Layout/Actions/Save",
	^"Overlay/Frame/Layout/Actions/Reload",
	^"Overlay/Frame/Layout/Actions/IntegrityScan",
	^"Overlay/Frame/Layout/Actions/Reset",
]

var _failures: Array[String] = []
var _verified_resolution_sizes: Array[Vector2i] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_cleanup()
	root.mode = Window.MODE_WINDOWED
	_assert(root.mode == Window.MODE_WINDOWED or DisplayServer.get_name() == "headless", "sandbox resolution runner uses a true windowed target or the approved headless SubViewport fallback")
	_assert(root.content_scale_size == LOGICAL_SIZE, "sandbox resolution runner retains the project 1920x1080 logical canvas")
	_assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "sandbox resolution runner uses the project canvas_items stretch policy")
	for viewport_size: Vector2i in TARGET_SIZES:
		await _exercise_resolution(viewport_size)
	await _exercise_controller_and_mouse()
	_finish()


func _exercise_resolution(viewport_size: Vector2i) -> void:
	var label := "%dx%d" % [viewport_size.x, viewport_size.y]
	var failures_before := _failures.size()
	root.size = viewport_size
	await _frames(4)
	var geometry_viewport: Viewport = root
	var geometry_parent: Node = root
	var headless_viewport: SubViewport = null
	if root.mode == Window.MODE_WINDOWED:
		_assert(root.size == viewport_size, "%s root Window reaches the exact requested physical size" % label)
		_assert(Vector2i(root.get_visible_rect().size) == LOGICAL_SIZE, "%s canvas_items stretch retains the exact 1920x1080 logical viewport" % label)
	else:
		headless_viewport = SubViewport.new()
		headless_viewport.size = viewport_size
		headless_viewport.size_2d_override = LOGICAL_SIZE
		headless_viewport.size_2d_override_stretch = true
		headless_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(headless_viewport)
		await _frames(4)
		geometry_viewport = headless_viewport
		geometry_parent = headless_viewport
		_assert(headless_viewport.size == viewport_size, "%s headless SubViewport reaches the exact requested physical target" % label)
		_assert(headless_viewport.size_2d_override == LOGICAL_SIZE and headless_viewport.size_2d_override_stretch, "%s headless SubViewport explicitly retains the stretched 1920x1080 logical canvas" % label)
	var sandbox := SANDBOX_SCENE.instantiate() as DeveloperItemSandbox
	geometry_parent.add_child(sandbox)
	await _frames(3)
	_assert(sandbox.has_method(&"apply_viewport_size"), "%s sandbox exposes deterministic viewport layout" % label)
	_assert(sandbox.has_method(&"slot_button_count"), "%s sandbox exposes real slot count diagnostic" % label)
	_assert(sandbox.has_method(&"selected_item_detail"), "%s sandbox exposes defensive selected-item detail" % label)
	_assert(sandbox.has_method(&"integrity_error"), "%s sandbox exposes read-only integrity status" % label)
	if not sandbox.has_method(&"apply_viewport_size"):
		sandbox.free()
		if headless_viewport != null:
			headless_viewport.free()
		await process_frame
		return
	# The physical Window target changes per marker while production Controls lay
	# out in the project's fixed canvas_items logical viewport.
	sandbox.call(&"apply_viewport_size", LOGICAL_SIZE)
	_assert(sandbox.open(), "%s production sandbox opens" % label)
	await _frames(3)
	var overlay := sandbox.get_node("Overlay") as Control
	var frame := sandbox.get_node("Overlay/Frame") as Control
	var body := sandbox.get_node("Overlay/Frame/Layout/Body") as BoxContainer
	var inventory_panel := sandbox.get_node("Overlay/Frame/Layout/Body/InventoryPanel") as Control
	var stash_panel := sandbox.get_node("Overlay/Frame/Layout/Body/StashPanel") as Control
	var inspector_panel := sandbox.get_node("Overlay/Frame/Layout/Body/InspectorPanel") as Control
	var stash_scroll := sandbox.get_node("Overlay/Frame/Layout/Body/StashPanel/StashScroll") as ScrollContainer
	var stash_grid := sandbox.get_node("Overlay/Frame/Layout/Body/StashPanel/StashScroll/StashSlots") as GridContainer
	var inspector_scroll := sandbox.get_node("Overlay/Frame/Layout/Body/InspectorPanel/InspectorScroll") as ScrollContainer
	var inspector := sandbox.get_node("Overlay/Frame/Layout/Body/InspectorPanel/InspectorScroll/Inspector") as Label
	var close_button := sandbox.get_node("Overlay/Frame/Layout/Header/Close") as Button
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(LOGICAL_SIZE)) if headless_viewport != null else geometry_viewport.get_visible_rect()
	var frame_rect := frame.get_global_rect()
	_assert(_rect_near(overlay.get_global_rect(), viewport_rect), "%s overlay covers the visible viewport" % label)
	_assert(_contained(viewport_rect, frame_rect), "%s frame stays inside the visible viewport" % label)
	for panel: Control in [inventory_panel, stash_panel, inspector_panel]:
		_assert(panel.is_visible_in_tree() and panel.get_global_rect().has_area(), "%s %s is visible with positive geometry" % [label, panel.name])
		_assert(_contained(frame_rect, panel.get_global_rect()), "%s %s stays inside the safe frame" % [label, panel.name])
	for action_path: NodePath in ACTION_PATHS:
		var action := sandbox.get_node(action_path) as Button
		_assert(action.is_visible_in_tree() and _contained(frame_rect, action.get_global_rect()), "%s action %s stays visible inside the safe frame" % [label, action.name])
	_assert(close_button.is_visible_in_tree() and _contained(frame_rect, close_button.get_global_rect()), "%s Close stays visible inside the safe frame" % label)
	_assert(inspector_scroll.is_visible_in_tree() and _contained(frame_rect, inspector_scroll.get_global_rect()), "%s inspector scroll remains reachable" % label)
	_assert(inspector.focus_mode != Control.FOCUS_NONE, "%s inspector remains controller-focusable" % label)
	_assert(int(sandbox.call(&"slot_button_count")) == 105, "%s exact 5 + 100 slot count is reported" % label)
	_assert(stash_grid.get_child_count() == 100, "%s production stash owns 100 real buttons" % label)
	var scroll_bar := stash_scroll.get_v_scroll_bar()
	print("ITEM_SANDBOX_SCROLL_METRICS size=%s max=%d page=%d grid_height=%.1f viewport_height=%.1f" % [
		label,
		int(scroll_bar.max_value),
		int(scroll_bar.page),
		stash_grid.get_global_rect().size.y,
		stash_scroll.get_global_rect().size.y,
	])
	_assert(scroll_bar.max_value > scroll_bar.page, "%s stash genuinely overflows its scroll viewport" % label)
	var minimum_scroll := int(scroll_bar.min_value)
	stash_scroll.scroll_vertical = int(scroll_bar.max_value)
	await _frames(2)
	var last_slot := stash_grid.get_child(99) as Button
	_assert(stash_scroll.scroll_vertical > minimum_scroll, "%s stash scrolling changes the real scroll value" % label)
	_assert(_intersects(stash_scroll.get_global_rect(), last_slot.get_global_rect()), "%s stash scroll reaches the final slot" % label)
	_assert(_closed_focus_graph(sandbox), "%s focus traversal covers every slot/action/Inspector/Close and closes inside the modal" % label)
	_assert(String(sandbox.call(&"integrity_error")).is_empty(), "%s usable sandbox reports no integrity error" % label)
	if _failures.size() == failures_before:
		_verified_resolution_sizes.append(viewport_size)
	sandbox.free()
	if headless_viewport != null:
		headless_viewport.free()
	await process_frame


func _exercise_controller_and_mouse() -> void:
	root.size = TARGET_SIZES[0]
	await _frames(4)
	_assert(root.size == TARGET_SIZES[0], "controller fixture reaches the exact 1920x1080 physical Window size")
	_assert(Vector2i(root.get_visible_rect().size) == LOGICAL_SIZE, "controller fixture retains the 1920x1080 logical canvas")
	var sandbox := SANDBOX_SCENE.instantiate() as DeveloperItemSandbox
	root.add_child(sandbox)
	await _frames(3)
	if not sandbox.has_method(&"apply_viewport_size"):
		_assert(false, "controller fixture requires deterministic viewport layout")
		sandbox.free()
		return
	sandbox.call(&"apply_viewport_size", LOGICAL_SIZE)
	_assert(sandbox.open(), "controller fixture opens production sandbox")
	await _frames(3)
	var inventory := sandbox.get_node("Overlay/Frame/Layout/Body/InventoryPanel/InventorySlots") as GridContainer
	var stash := sandbox.get_node("Overlay/Frame/Layout/Body/StashPanel/StashScroll/StashSlots") as GridContainer
	var save := sandbox.get_node("Overlay/Frame/Layout/Actions/Save") as Button
	var reset := sandbox.get_node("Overlay/Frame/Layout/Actions/Reset") as Button
	var source := stash.get_child(0) as Button
	var inventory_four := inventory.get_child(4) as Button

	# West-face pickup, real D-pad navigation, then south-face placement.
	var moved_item_id := String(source.get_meta("item_id", ""))
	var bytes_before_move := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	source.grab_focus()
	await process_frame
	await _joy_button(JOY_BUTTON_X)
	_assert(sandbox.is_holding_item(), "west face picks up the actual focused stash item")
	await _joy_button(JOY_BUTTON_DPAD_UP)
	_assert(root.gui_get_focus_owner() == inventory_four, "D-pad navigation follows the explicit closed graph to inventory slot 4")
	await _joy_button(JOY_BUTTON_A)
	_assert(String(inventory_four.get_meta("item_id", "")) == moved_item_id, "south face places the held item into the focused destination")
	_assert(not sandbox.is_holding_item(), "south-face placement clears held mode")
	_assert(FileAccess.get_file_as_bytes(DOCUMENT_PATH) != bytes_before_move, "south-face placement persists new bytes")
	_assert((sandbox.projection()["transaction_journal"] as Array).size() == 1, "south-face placement persists one canonical journal entry")

	# South while not holding remains inspection-only.
	var inspection_projection := sandbox.projection()
	var inspection_bytes := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	inventory_four.grab_focus()
	await _joy_button(JOY_BUTTON_A)
	_assert(not sandbox.is_holding_item(), "south face while not holding remains inspection-only")
	_assert(sandbox.projection() == inspection_projection, "inspection-only south preserves ownership state")
	_assert(FileAccess.get_file_as_bytes(DOCUMENT_PATH) == inspection_bytes, "inspection-only south preserves persisted bytes")
	var selected_detail := sandbox.call(&"selected_item_detail") as Dictionary
	_assert(String(selected_detail.get("instance_id", "")) == moved_item_id, "selected-item diagnostic follows real focused inspection")
	selected_detail["instance_id"] = "escaped"
	_assert(String((sandbox.call(&"selected_item_detail") as Dictionary).get("instance_id", "")) == moved_item_id, "selected-item diagnostic is defensive")

	# Occupied placement is an exact swap.
	reset.pressed.emit()
	await _frames(2)
	source = stash.get_child(0) as Button
	var occupied_destination := stash.get_child(1) as Button
	var source_id := String(source.get_meta("item_id", ""))
	var destination_id := String(occupied_destination.get_meta("item_id", ""))
	source.grab_focus()
	await _joy_button(JOY_BUTTON_X)
	await _joy_button(JOY_BUTTON_DPAD_DOWN)
	_assert(root.gui_get_focus_owner() == occupied_destination, "D-pad moves held focus to the next occupied stash slot")
	await _joy_button(JOY_BUTTON_A)
	_assert(String(source.get_meta("item_id", "")) == destination_id and String(occupied_destination.get_meta("item_id", "")) == source_id, "south-face placement swaps the exact occupied slots")

	# East-face cancel clears held mode first and preserves exact state/bytes.
	reset.pressed.emit()
	await _frames(2)
	source = stash.get_child(0) as Button
	source.grab_focus()
	await _joy_button(JOY_BUTTON_X)
	var cancel_projection := sandbox.projection()
	var cancel_bytes := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	await _joy_button(JOY_BUTTON_B)
	_assert(sandbox.is_open() and not sandbox.is_holding_item(), "east face cancels held mode before closing the modal")
	_assert(sandbox.projection() == cancel_projection, "held east-face cancel preserves ownership state")
	_assert(FileAccess.get_file_as_bytes(DOCUMENT_PATH) == cancel_bytes, "held east-face cancel preserves persisted bytes")

	# A non-slot focus owner cannot use a historically focused empty destination.
	source.grab_focus()
	await _joy_button(JOY_BUTTON_X)
	(inventory.get_child(0) as Button).grab_focus()
	await process_frame
	save.grab_focus()
	await process_frame
	var stale_projection := sandbox.projection()
	var stale_bytes := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	await _joy_button(JOY_BUTTON_A)
	_assert(root.gui_get_focus_owner() == save, "non-slot Save remains the actual focus owner")
	_assert(not sandbox.is_holding_item(), "south on a non-slot control clears held mode safely")
	_assert(sandbox.projection() == stale_projection and FileAccess.get_file_as_bytes(DOCUMENT_PATH) == stale_bytes, "south on a non-slot cannot act on a stale slot")

	# Godot's actual drag callbacks cover move, occupied swap, and outside release.
	reset.pressed.emit()
	await _frames(2)
	source = stash.get_child(0) as Button
	var inventory_zero := inventory.get_child(0) as Button
	var drag_item_id := String(source.get_meta("item_id", ""))
	var drag_data: Variant = source.call(&"_get_drag_data", Vector2.ZERO)
	_assert(drag_data is Dictionary and bool(inventory_zero.call(&"_can_drop_data", Vector2.ZERO, drag_data)), "real drag callbacks accept an empty destination")
	inventory_zero.call(&"_drop_data", Vector2.ZERO, drag_data)
	_assert(String(inventory_zero.get_meta("item_id", "")) == drag_item_id, "real drag callback moves to an empty destination")
	var swap_source := stash.get_child(1) as Button
	var swap_source_id := String(swap_source.get_meta("item_id", ""))
	var swap_data: Variant = swap_source.call(&"_get_drag_data", Vector2.ZERO)
	_assert(bool(inventory_zero.call(&"_can_drop_data", Vector2.ZERO, swap_data)), "real drag callbacks accept an occupied destination")
	inventory_zero.call(&"_drop_data", Vector2.ZERO, swap_data)
	_assert(String(inventory_zero.get_meta("item_id", "")) == swap_source_id and String(swap_source.get_meta("item_id", "")) == drag_item_id, "real drag callback swaps exact occupied slots")
	var invalid_source := stash.get_child(2) as Button
	var invalid_projection := sandbox.projection()
	var invalid_bytes := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	var invalid_drag: Variant = invalid_source.call(&"_get_drag_data", Vector2.ZERO)
	_assert(invalid_drag is Dictionary and sandbox.is_holding_item(), "outside-drop fixture begins through the real drag callback")
	sandbox.call(&"_finish_drag", false)
	_assert(not sandbox.is_holding_item(), "invalid outside drop clears the held visual")
	_assert(sandbox.projection() == invalid_projection and FileAccess.get_file_as_bytes(DOCUMENT_PATH) == invalid_bytes, "invalid outside drop preserves exact state and bytes")
	_assert(String(sandbox.call(&"integrity_error")).is_empty(), "controller and mouse transactions leave integrity clear")

	# East face without a held item closes the top modal.
	await _joy_button(JOY_BUTTON_B)
	_assert(not sandbox.is_open(), "east face without a held item closes the sandbox")
	sandbox.free()
	await process_frame


func _closed_focus_graph(sandbox: DeveloperItemSandbox) -> bool:
	var controls: Array[Control] = []
	var inventory := sandbox.get_node("Overlay/Frame/Layout/Body/InventoryPanel/InventorySlots") as GridContainer
	var stash := sandbox.get_node("Overlay/Frame/Layout/Body/StashPanel/StashScroll/StashSlots") as GridContainer
	for child: Node in inventory.get_children() + stash.get_children():
		controls.append(child as Control)
	controls.append(sandbox.get_node("Overlay/Frame/Layout/Body/InspectorPanel/InspectorScroll/Inspector") as Control)
	for path: NodePath in ACTION_PATHS:
		controls.append(sandbox.get_node(path) as Control)
	controls.append(sandbox.get_node("Overlay/Frame/Layout/Header/Close") as Control)
	if controls.size() != 113:
		return false
	var visited: Dictionary = {}
	var current := controls[0]
	for _index: int in controls.size():
		if current == null or current not in controls or visited.has(current.get_instance_id()):
			return false
		visited[current.get_instance_id()] = true
		for property_name: StringName in [&"focus_next", &"focus_previous", &"focus_neighbor_top", &"focus_neighbor_bottom", &"focus_neighbor_left", &"focus_neighbor_right"]:
			var target_path := current.get(property_name) as NodePath
			if target_path.is_empty() or current.get_node_or_null(target_path) not in controls:
				return false
		current = current.get_node_or_null(current.focus_next) as Control
	return current == controls[0] and visited.size() == controls.size()


func _joy_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _contained(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(1.0).encloses(inner) and inner.has_area()


func _intersects(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(1.0).intersects(inner) and inner.has_area()


func _rect_near(first: Rect2, second: Rect2) -> bool:
	return first.position.distance_to(second.position) <= 1.0 and first.size.distance_to(second.size) <= 1.0


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	_cleanup()
	_assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SANDBOX_ROOT)), "cleanup removes every Task 10 root before summary")
	if _failures.is_empty():
		for viewport_size: Vector2i in _verified_resolution_sizes:
			print("ITEM_SANDBOX_RESOLUTION_PASS size=%dx%d slots=105" % [viewport_size.x, viewport_size.y])
		print("ITEM_SANDBOX_CONTROLLER_PASS")
		print("ITEM_SANDBOX_UI_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("ITEM_SANDBOX_UI_FAILURE: %s" % failure)
	print("ITEM_SANDBOX_UI_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _cleanup() -> void:
	ProfileTestSupport.remove_tree(SANDBOX_ROOT)
