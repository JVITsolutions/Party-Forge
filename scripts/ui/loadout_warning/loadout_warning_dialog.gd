class_name LoadoutWarningDialog
extends CanvasLayer

enum State { CLOSED, INCOMPATIBLE, DESTRUCTIVE_CONFIRMATION }

const DESTRUCTIVE_HOLD_SECONDS := 1.25
const DESTROY_KEY := KEY_D
const DESTROY_CONTROLLER_BUTTON := JOY_BUTTON_Y
const CONTROLLER_SCROLL_STEP := 160
const RIGHT_STICK_DEADZONE := 0.35

signal go_to_armoury
signal choose_another_class
signal continue_anyway
signal destroy_confirmed(confirmation_token: String)
signal cancelled

var _state := State.CLOSED
var _projection: LoadoutCompatibilityProjection
var _return_focus: Control
var _hold_seconds := 0.0
var _destroy_held := false
var _destroy_emitted := false
var _destroy_authorization := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(true)
	_connect_controls()


func open(projection_value: LoadoutCompatibilityProjection, return_focus: Control = null) -> bool:
	_reset_hold()
	if projection_value == null or not projection_value.valid or projection_value.incompatible_items.is_empty():
		close()
		return false
	_projection = _copy_projection(projection_value)
	_return_focus = return_focus
	_set_state(State.INCOMPATIBLE)
	visible = true
	_render()
	if is_inside_tree():
		_go_to_armoury_button().grab_focus()
	return true


func close() -> void:
	_reset_hold()
	_state = State.CLOSED
	_projection = null
	visible = false
	if _return_focus != null and is_instance_valid(_return_focus) and _return_focus.is_inside_tree() and _return_focus.is_visible_in_tree() and _return_focus.focus_mode != Control.FOCUS_NONE:
		_return_focus.grab_focus()
	_return_focus = null


func is_open() -> bool:
	return visible and _state != State.CLOSED


func state() -> State:
	return _state


func projection() -> LoadoutCompatibilityProjection:
	return _copy_projection(_projection)


func details_text() -> String:
	return _details().text


func show_error(message: String) -> void:
	_error_status().text = message
	_error_status().visible = not message.strip_edges().is_empty()
	if is_inside_tree() and is_open():
		_cancel_button().grab_focus()


func apply_viewport_size(size: Vector2i) -> void:
	var compact := size.x < 1400 or size.y < 850
	var margin := 12.0 if compact else 48.0
	_frame().offset_left = margin
	_frame().offset_top = margin
	_frame().offset_right = -margin
	_frame().offset_bottom = -margin
	_actions().vertical = compact


func advance_destroy_hold(delta: float, held: bool) -> void:
	if _state != State.DESTRUCTIVE_CONFIRMATION or _projection == null or _destroy_emitted:
		_reset_hold_progress()
		return
	if not held:
		_reset_hold_progress()
		return
	_hold_seconds += maxf(delta, 0.0)
	_progress().value = minf(_hold_seconds / DESTRUCTIVE_HOLD_SECONDS * 100.0, 100.0)
	_hold_status().text = "Hold D / Controller Y / mouse for %.2f seconds" % maxf(DESTRUCTIVE_HOLD_SECONDS - _hold_seconds, 0.0)
	if _hold_seconds < DESTRUCTIVE_HOLD_SECONDS:
		return
	_destroy_emitted = true
	_destroy_held = false
	var token := _projection.confirmation_token
	_destroy_authorization = token
	_reset_hold_progress()
	destroy_confirmed.emit(token)


func consume_destroy_authorization(confirmation_token: String) -> bool:
	var authorized := (
		_state == State.DESTRUCTIVE_CONFIRMATION
		and _projection != null
		and not confirmation_token.is_empty()
		and confirmation_token == _projection.confirmation_token
		and confirmation_token == _destroy_authorization
	)
	_destroy_authorization = ""
	return authorized


func _process(delta: float) -> void:
	if _destroy_held:
		advance_destroy_hold(delta, true)


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		cancelled.emit()
		close()
		_mark_input_handled()
		return
	if _scroll_from_controller(event):
		_mark_input_handled()
		return
	if _state != State.DESTRUCTIVE_CONFIRMATION:
		return
	if _is_explicit_destroy_press(event):
		_set_destroy_held(true)
		_mark_input_handled()
	elif _is_explicit_destroy_release(event):
		_set_destroy_held(false)
		_mark_input_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_set_destroy_held(false)


func _set_state(value: State) -> void:
	if value != _state:
		_reset_hold()
	_state = value


func _render() -> void:
	if _projection == null:
		return
	_selected_class().text = "Selected Class: %s" % String(_projection.selected_class_id)
	show_error("")
	var destructive := _state == State.DESTRUCTIVE_CONFIRMATION
	_title().text = "Equipment Will Be Destroyed" if destructive else "Incompatible Leader Equipment"
	_details().text = _destructive_details() if destructive else _incompatible_details()
	_go_to_armoury_button().text = "Return to Armoury" if destructive else "Go to Armoury"
	_choose_button().visible = not destructive
	_continue_button().visible = not destructive
	_destroy_button().visible = destructive
	_progress().visible = destructive
	_hold_status().visible = destructive
	_reset_hold_progress()
	_rebuild_focus_loop()


func _incompatible_details() -> String:
	var lines: Array[String] = ["Selected Class: %s" % String(_projection.selected_class_id), ""]
	var destinations := _destination_by_item()
	for entry: Dictionary in _projection.incompatible_items:
		lines.append("%s — %s (slot %d)" % [_item_name(entry), String(entry["slot_id"]), int(entry["source_slot"]) + 1])
		for reason: Variant in entry.get("reasons", []):
			lines.append("  %s" % String(reason))
		var destination := destinations.get(String(entry["instance_id"]), {}) as Dictionary
		if not destination.is_empty():
			lines.append("  Move to %s slot %d" % [String(destination["destination_container_id"]), int(destination["destination_slot"]) + 1])
		elif String(entry["instance_id"]) in _projection.overflow_item_ids:
			lines.append("  No stash space — requires destructive confirmation")
		lines.append("")
	lines.append("Planned stash moves: %d" % _projection.planned_stash_destinations.size())
	lines.append("Overflow items: %d" % _projection.overflow_item_ids.size())
	return "\n".join(lines)


func _destructive_details() -> String:
	var lines: Array[String] = ["Selected Class: %s" % String(_projection.selected_class_id), ""]
	var items := _item_by_id()
	for destination: Dictionary in _projection.planned_stash_destinations:
		var entry := items.get(String(destination["instance_id"]), {}) as Dictionary
		lines.append("Move: %s to %s slot %d" % [_item_name(entry), String(destination["destination_container_id"]), int(destination["destination_slot"]) + 1])
	for instance_id: String in _projection.overflow_item_ids:
		lines.append("Destroy: %s" % _item_name(items.get(instance_id, {}) as Dictionary))
	lines.append("")
	lines.append("Destroyed equipment cannot be recovered.")
	return "\n".join(lines)


func _copy_projection(source: LoadoutCompatibilityProjection) -> LoadoutCompatibilityProjection:
	if source == null:
		return null
	if not source.valid:
		return LoadoutCompatibilityProjection.failure(source.error)
	return LoadoutCompatibilityProjection.success(
		source.selected_class_id,
		source.compatible_items,
		source.incompatible_items,
		source.planned_stash_destinations,
		source.overflow_item_ids,
		source.state_fingerprint,
	)


func _destination_by_item() -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in _projection.planned_stash_destinations:
		result[String(entry["instance_id"])] = entry.duplicate(true)
	return result


func _item_by_id() -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in _projection.incompatible_items:
		result[String(entry["instance_id"])] = entry.duplicate(true)
	return result


func _item_name(entry: Dictionary) -> String:
	return String(entry.get("display_name", entry.get("base_definition_id", entry.get("instance_id", "Unknown Item"))))


func _on_go_to_armoury_pressed() -> void:
	if is_open():
		go_to_armoury.emit()


func _on_choose_another_pressed() -> void:
	if _state == State.INCOMPATIBLE:
		choose_another_class.emit()


func _on_continue_pressed() -> void:
	if _state != State.INCOMPATIBLE or _projection == null:
		return
	if not _projection.overflow_item_ids.is_empty():
		_set_state(State.DESTRUCTIVE_CONFIRMATION)
		_render()
		if is_inside_tree():
			_go_to_armoury_button().grab_focus()
		return
	continue_anyway.emit()


func _on_cancel_pressed() -> void:
	if not is_open():
		return
	cancelled.emit()
	close()


func _set_destroy_held(held: bool) -> void:
	if not held:
		_destroy_held = false
		_destroy_authorization = ""
		_reset_hold_progress()
		return
	if _state == State.DESTRUCTIVE_CONFIRMATION and not _destroy_emitted:
		if _destroy_held:
			_destroy_authorization = ""
			_reset_hold_progress()
		_destroy_held = true


func _reset_hold() -> void:
	_destroy_held = false
	_destroy_emitted = false
	_destroy_authorization = ""
	_reset_hold_progress()


func _reset_hold_progress() -> void:
	_hold_seconds = 0.0
	if is_instance_valid(_progress()):
		_progress().value = 0.0
	if is_instance_valid(_hold_status()):
		_hold_status().text = "Hold D / Controller Y / mouse for 1.25 seconds"


func _on_destroy_button_down() -> void:
	_set_destroy_held(true)


func _on_destroy_button_up() -> void:
	_set_destroy_held(false)


func _on_destroy_focus_exited() -> void:
	_set_destroy_held(false)


func _is_explicit_destroy_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo and (key.physical_keycode == DESTROY_KEY or key.keycode == DESTROY_KEY)
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return button.pressed and button.button_index == DESTROY_CONTROLLER_BUTTON
	return false


func _is_explicit_destroy_release(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return not key.pressed and (key.physical_keycode == DESTROY_KEY or key.keycode == DESTROY_KEY)
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return not button.pressed and button.button_index == DESTROY_CONTROLLER_BUTTON
	return false


func _mark_input_handled() -> void:
	if is_inside_tree() and get_viewport() != null:
		get_viewport().set_input_as_handled()


func _connect_controls() -> void:
	if not _go_to_armoury_button().pressed.is_connected(_on_go_to_armoury_pressed): _go_to_armoury_button().pressed.connect(_on_go_to_armoury_pressed)
	if not _choose_button().pressed.is_connected(_on_choose_another_pressed): _choose_button().pressed.connect(_on_choose_another_pressed)
	if not _continue_button().pressed.is_connected(_on_continue_pressed): _continue_button().pressed.connect(_on_continue_pressed)
	if not _cancel_button().pressed.is_connected(_on_cancel_pressed): _cancel_button().pressed.connect(_on_cancel_pressed)
	if not _destroy_button().button_down.is_connected(_on_destroy_button_down): _destroy_button().button_down.connect(_on_destroy_button_down)
	if not _destroy_button().button_up.is_connected(_on_destroy_button_up): _destroy_button().button_up.connect(_on_destroy_button_up)
	if not _destroy_button().focus_exited.is_connected(_on_destroy_focus_exited): _destroy_button().focus_exited.connect(_on_destroy_focus_exited)


func _rebuild_focus_loop() -> void:
	var controls: Array[Control] = [_go_to_armoury_button()]
	if _choose_button().visible: controls.append(_choose_button())
	if _continue_button().visible: controls.append(_continue_button())
	if _destroy_button().visible: controls.append(_destroy_button())
	controls.append(_cancel_button())
	for index: int in controls.size():
		var current := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var previous := controls[posmod(index - 1, controls.size())]
		current.focus_mode = Control.FOCUS_ALL
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_neighbor_left = current.get_path_to(previous)
		current.focus_neighbor_right = current.get_path_to(next)
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(next)


func _scroll_from_controller(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis != JOY_AXIS_RIGHT_Y or absf(motion.axis_value) < RIGHT_STICK_DEADZONE:
			return false
		_scroll_details(roundi(float(CONTROLLER_SCROLL_STEP) * motion.axis_value))
		return true
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if not button.pressed or button.button_index not in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			return false
		_scroll_details(-CONTROLLER_SCROLL_STEP if button.button_index == JOY_BUTTON_DPAD_UP else CONTROLLER_SCROLL_STEP)
	return false


func _scroll_details(amount: int) -> void:
	var scroll := get_node("Overlay/Frame/Layout/Scroll") as ScrollContainer
	var bar := scroll.get_v_scroll_bar()
	var maximum := maxi(ceili(bar.max_value - bar.page), 0)
	scroll.scroll_vertical = clampi(scroll.scroll_vertical + amount, 0, maximum)


func _frame() -> Control: return get_node("Overlay/Frame") as Control
func _title() -> Label: return get_node("Overlay/Frame/Layout/Title") as Label
func _selected_class() -> Label: return get_node("Overlay/Frame/Layout/SelectedClass") as Label
func _details() -> Label: return get_node("Overlay/Frame/Layout/Scroll/Details") as Label
func _actions() -> BoxContainer: return get_node("Overlay/Frame/Layout/Actions") as BoxContainer
func _go_to_armoury_button() -> Button: return get_node("Overlay/Frame/Layout/Actions/Armoury") as Button
func _choose_button() -> Button: return get_node("Overlay/Frame/Layout/Actions/ChooseAnother") as Button
func _continue_button() -> Button: return get_node("Overlay/Frame/Layout/Actions/Continue") as Button
func _destroy_button() -> Button: return get_node("Overlay/Frame/Layout/Actions/HoldDestroy") as Button
func _cancel_button() -> Button: return get_node("Overlay/Frame/Layout/Actions/Cancel") as Button
func _progress() -> ProgressBar: return get_node("Overlay/Frame/Layout/HoldProgress") as ProgressBar
func _hold_status() -> Label: return get_node("Overlay/Frame/Layout/HoldStatus") as Label
func _error_status() -> Label: return get_node("Overlay/Frame/Layout/ErrorStatus") as Label
