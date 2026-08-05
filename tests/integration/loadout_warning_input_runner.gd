extends SceneTree

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var failures: Array[String] = []
	root.content_scale_size = Vector2i(1920, 1080)
	var origin := Button.new()
	origin.name = "Class_mage"
	origin.text = "Mage"
	root.add_child(origin)
	var dialog := (load("res://scenes/ui/loadout_warning/loadout_warning_dialog.tscn") as PackedScene).instantiate()
	root.add_child(dialog)
	var armoury := (load("res://scenes/ui/armoury/armoury_screen.tscn") as PackedScene).instantiate() as ArmouryScreen
	root.add_child(armoury)
	armoury.configure_classes(GameCatalog.load_defaults().classes)
	var projection := _projection()

	for viewport_size: Vector2i in SIZES:
		root.size = viewport_size
		dialog.call("apply_viewport_size", viewport_size)
		dialog.call("open", projection, origin)
		await process_frame
		var frame := dialog.get_node("Overlay/Frame") as Control
		var scroll := dialog.get_node("Overlay/Frame/Layout/Scroll") as ScrollContainer
		var details := dialog.get_node("Overlay/Frame/Layout/Scroll/Details") as Label
		_assert(_frame_reachable(frame), "warning frame reachable at %s" % viewport_size, failures)
		_assert(details.size.y > scroll.size.y, "long exact item/reason list scrolls at %s" % viewport_size, failures)
		_assert(_inside(root.gui_get_focus_owner(), dialog), "warning contains initial controller focus at %s" % viewport_size, failures)
		dialog.call("close")
		await process_frame
	print("TASK10_LOADOUT_WARNING_RESPONSIVE_PASS")
	root.size = Vector2i(1920, 1080)

	var cancellations: Array[int] = [0]
	dialog.connect("cancelled", func() -> void: cancellations[0] += 1)
	dialog.call("open", projection, origin)
	await process_frame
	await _joy_button(JOY_BUTTON_B, 0.0)
	_assert(cancellations[0] == 1 and not dialog.call("is_open"), "real controller cancel closes without confirmation", failures)
	_assert(root.gui_get_focus_owner() == origin, "controller cancel restores exact origin focus", failures)

	var armoury_redirects: Array[int] = [0]
	dialog.connect("go_to_armoury", func() -> void:
		armoury_redirects[0] += 1
		dialog.call("close")
		armoury.open(Task9StorageFixture.storage(false), origin)
		armoury.set_pending_run_class(&"mage")
	)
	dialog.call("open", projection, origin)
	await process_frame
	await _mouse_click(dialog.get_node("Overlay/Frame/Layout/Actions/Armoury") as Button)
	_assert(armoury_redirects[0] == 1 and armoury.is_open(), "real mouse Go to Armoury opens Task 9 interface", failures)
	_assert((armoury.get_node("Overlay/Frame/Layout/Header/Class") as Label).text.contains("Pending Run: mage"), "Armoury redirect displays selected class only", failures)
	armoury.close()
	await process_frame
	_assert(root.gui_get_focus_owner() == origin, "Armoury return restores exact selection origin", failures)

	var confirmations: Array[String] = []
	dialog.connect("destroy_confirmed", func(token: String) -> void: confirmations.append(token))
	dialog.call("open", projection, origin)
	await process_frame
	await _mouse_click(dialog.get_node("Overlay/Frame/Layout/Actions/Continue") as Button)
	(dialog.get_node("Overlay/Frame/Layout/Actions/HoldDestroy") as Button).grab_focus()
	await process_frame
	await _joy_button(JOY_BUTTON_A, 0.0)
	await _joy_button(JOY_BUTTON_Y, 0.45)
	_assert(confirmations.is_empty(), "ordinary accept and short controller hold do not confirm", failures)
	await _joy_button(JOY_BUTTON_Y, 1.30)
	_assert(confirmations == [projection.confirmation_token], "real controller continuous hold emits exact token once", failures)
	print("TASK10_LOADOUT_WARNING_CONTROLLER_PASS")

	confirmations.clear()
	dialog.call("open", projection, origin)
	await process_frame
	await _mouse_click(dialog.get_node("Overlay/Frame/Layout/Actions/Continue") as Button)
	var destroy := dialog.get_node("Overlay/Frame/Layout/Actions/HoldDestroy") as Button
	await _mouse_hold(destroy, 0.55)
	dialog.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _mouse_hold(destroy, 0.80)
	_assert(confirmations.is_empty(), "focus loss resets split mouse hold progress", failures)
	await _mouse_hold(destroy, 1.30)
	_assert(confirmations == [projection.confirmation_token], "real mouse continuous hold emits exact token once", failures)
	print("TASK10_LOADOUT_WARNING_MOUSE_PASS")

	dialog.call("close")
	armoury.queue_free()
	dialog.queue_free()
	origin.queue_free()
	await process_frame
	for failure: String in failures:
		push_error("TASK10_LOADOUT_WARNING_INPUT_FAILURE: %s" % failure)
	print("TASK10_LOADOUT_WARNING_INPUT_SUMMARY: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _projection() -> LoadoutCompatibilityProjection:
	var entries: Array[Dictionary] = []
	var destinations: Array[Dictionary] = []
	for index: int in 10:
		var instance_id := "item-warning-%02d" % index
		entries.append({
			"base_definition_id": "warning_item_%02d" % index,
			"display_name": "Warning Equipment %02d" % index,
			"instance_id": instance_id,
			"reasons": ["PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=selected class cannot use this deliberately long exact eligibility requirement" % instance_id],
			"slot_id": "slot_%02d" % index,
			"source_container_id": "leader-loadout",
			"source_slot": index,
		})
		if index < 9:
			destinations.append({"instance_id": instance_id, "destination_container_id": "stash-tab-alpha", "destination_slot": 90 + index})
	return LoadoutCompatibilityProjection.success(&"mage", [], entries, destinations, ["item-warning-09"], "b".repeat(64))


func _joy_button(button_index: JoyButton, held_seconds: float) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	if held_seconds > 0.0:
		await create_timer(held_seconds).timeout
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _mouse_click(button: Button) -> void:
	await _mouse_hold(button, 0.0)


func _mouse_hold(button: Button, held_seconds: float) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	if held_seconds > 0.0:
		await create_timer(held_seconds).timeout
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _inside(control: Control, ancestor: Node) -> bool:
	return control != null and (control == ancestor or ancestor.is_ancestor_of(control))


func _frame_reachable(frame: Control) -> bool:
	return frame != null and frame.is_visible_in_tree() and frame.size.x > 0.0 and frame.size.y > 0.0 and frame.position.x >= 0.0 and frame.position.y >= 0.0


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
