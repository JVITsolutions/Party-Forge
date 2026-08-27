class_name RunRecoveryDialog
extends CanvasLayer

signal resume_requested
signal legacy_class_requested(class_id: StringName)
signal abandon_requested(run_id: StringName)
signal cancelled

var _code := RunRecoveryResult.Code.INVALID
var _run_id: StringName = &""
var _profile_name := ""
var _can_forfeit := false
var _return_focus: Control
var _initial_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_connect_controls()


func open(result: RunRecoveryResult, classes: Array[ClassDefinition], profile_name: String, return_focus: Control = null) -> bool:
	if result == null:
		close()
		return false
	_code = result.code
	_run_id = result.run_id
	_profile_name = profile_name.strip_edges()
	_can_forfeit = result.can_forfeit and not _run_id.is_empty()
	_return_focus = return_focus
	_populate_classes(classes)
	_render(result)
	visible = true
	_focus_initial_control()
	return true


func close() -> void:
	_abandon_confirmation().hide()
	visible = false
	_code = RunRecoveryResult.Code.INVALID
	_run_id = &""
	_profile_name = ""
	_can_forfeit = false
	_initial_focus = null
	if _return_focus != null and is_instance_valid(_return_focus) and _return_focus.is_inside_tree() and _return_focus.is_visible_in_tree() and _return_focus.focus_mode != Control.FOCUS_NONE:
		_return_focus.grab_focus()
	_return_focus = null


func is_open() -> bool:
	return visible


func show_failure(safe_message: String, technical_detail: String, terminal: bool = false) -> void:
	if terminal:
		_enter_terminal_failure()
	_status().text = safe_message
	_technical_detail().text = technical_detail
	_technical_detail().visible = not technical_detail.strip_edges().is_empty()
	_technical_heading().visible = _technical_detail().visible
	if is_open():
		_focus_initial_control()


func _enter_terminal_failure() -> void:
	_abandon_confirmation().hide()
	_code = RunRecoveryResult.Code.INVALID
	_run_id = &""
	_can_forfeit = false
	for control: Control in [_resume_button(), _class_picker(), _bind_button(), _abandon_button()]:
		control.visible = false
		control.set("disabled", true)
	_cancel_button().visible = true
	_cancel_button().disabled = false
	_initial_focus = _cancel_button()
	_rebuild_focus_loop()


func _input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed(&"ui_cancel"):
		return
	if _abandon_confirmation().visible:
		_abandon_confirmation().hide()
		_focus_control(_abandon_button())
	else:
		_on_cancel_pressed()
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _render(result: RunRecoveryResult) -> void:
	_title().text = "Recover Interrupted Run"
	_technical_detail().text = result.error
	_technical_detail().visible = not result.error.strip_edges().is_empty()
	_technical_heading().visible = _technical_detail().visible
	var ready := result.ready()
	var class_required := result.code == RunRecoveryResult.Code.CLASS_REQUIRED
	_resume_button().visible = ready
	_resume_button().disabled = not ready
	_class_picker().visible = class_required
	_class_picker().disabled = not class_required or _class_picker().item_count == 0
	_bind_button().visible = class_required
	_bind_button().disabled = not class_required or _class_picker().item_count == 0
	_abandon_button().visible = _can_forfeit
	_abandon_button().disabled = not _can_forfeit
	if _resume_button().visible and not _resume_button().disabled:
		_initial_focus = _resume_button()
	elif _class_picker().visible and not _class_picker().disabled:
		_initial_focus = _class_picker()
	elif _abandon_button().visible and not _abandon_button().disabled:
		_initial_focus = _abandon_button()
	else:
		_initial_focus = _cancel_button()
	match result.code:
		RunRecoveryResult.Code.READY:
			_status().text = "Resume this interrupted run with its original party and items."
		RunRecoveryResult.Code.CLASS_REQUIRED:
			_status().text = "Choose the leader class used by this legacy run before resuming."
		RunRecoveryResult.Code.PERSISTENCE_FAILED:
			_status().text = "Unable to read this interrupted run."
		_:
			_status().text = "This interrupted run cannot be resumed safely."
	_rebuild_focus_loop()


func _populate_classes(classes: Array[ClassDefinition]) -> void:
	var picker := _class_picker()
	picker.clear()
	for definition: ClassDefinition in classes:
		if definition == null or definition.id.is_empty():
			continue
		picker.add_item(definition.display_name if not definition.display_name.strip_edges().is_empty() else String(definition.id))
		picker.set_item_metadata(picker.item_count - 1, definition.id)
	if picker.item_count > 0:
		picker.select(0)


func _focus_initial_control() -> void:
	_focus_control(_initial_focus)


func _focus_control(control: Control) -> void:
	if control != null and control.is_inside_tree() and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
		control.grab_focus()


func _connect_controls() -> void:
	if not _resume_button().pressed.is_connected(_on_resume_pressed): _resume_button().pressed.connect(_on_resume_pressed)
	if not _bind_button().pressed.is_connected(_on_bind_pressed): _bind_button().pressed.connect(_on_bind_pressed)
	if not _abandon_button().pressed.is_connected(_on_abandon_pressed): _abandon_button().pressed.connect(_on_abandon_pressed)
	if not _cancel_button().pressed.is_connected(_on_cancel_pressed): _cancel_button().pressed.connect(_on_cancel_pressed)
	if not _abandon_confirmation().confirmed.is_connected(_on_abandon_confirmed): _abandon_confirmation().confirmed.connect(_on_abandon_confirmed)
	if not _abandon_confirmation().canceled.is_connected(_on_abandon_confirmation_cancelled): _abandon_confirmation().canceled.connect(_on_abandon_confirmation_cancelled)
	if not _abandon_confirmation().close_requested.is_connected(_on_abandon_confirmation_cancelled): _abandon_confirmation().close_requested.connect(_on_abandon_confirmation_cancelled)


func _on_resume_pressed() -> void:
	if is_open() and _code == RunRecoveryResult.Code.READY:
		resume_requested.emit()


func _on_bind_pressed() -> void:
	if not is_open() or _code != RunRecoveryResult.Code.CLASS_REQUIRED or _class_picker().selected < 0:
		return
	var class_id := StringName(_class_picker().get_item_metadata(_class_picker().selected))
	if not class_id.is_empty():
		legacy_class_requested.emit(class_id)


func _on_abandon_pressed() -> void:
	if not is_open() or not _can_forfeit:
		return
	var profile_label := _profile_name if not _profile_name.is_empty() else "the active profile"
	_abandon_confirmation().dialog_text = "Abandon the interrupted run for %s?\n\nRun ID: %s\n\nAll run-owned items will be permanently lost." % [profile_label, String(_run_id)]
	if _abandon_confirmation().is_inside_tree():
		_abandon_confirmation().popup_centered()
		_focus_control(_abandon_confirmation().get_ok_button())


func _on_abandon_confirmed() -> void:
	if is_open() and _can_forfeit and not _run_id.is_empty():
		abandon_requested.emit(_run_id)


func _on_abandon_confirmation_cancelled() -> void:
	_abandon_confirmation().hide()
	_focus_control(_abandon_button())


func _on_cancel_pressed() -> void:
	if not is_open():
		return
	cancelled.emit()
	close()


func _rebuild_focus_loop() -> void:
	var controls: Array[Control] = []
	for control: Control in [_class_picker(), _resume_button(), _bind_button(), _abandon_button(), _cancel_button()]:
		if control.visible and not control.disabled:
			controls.append(control)
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


func _title() -> Label: return get_node("Overlay/Frame/Layout/Title") as Label
func _status() -> Label: return get_node("Overlay/Frame/Layout/Status") as Label
func _technical_heading() -> Label: return get_node("Overlay/Frame/Layout/TechnicalHeading") as Label
func _technical_detail() -> Label: return get_node("Overlay/Frame/Layout/TechnicalDetail") as Label
func _class_picker() -> OptionButton: return get_node("Overlay/Frame/Layout/ClassPicker") as OptionButton
func _resume_button() -> Button: return get_node("Overlay/Frame/Layout/Actions/Resume") as Button
func _bind_button() -> Button: return get_node("Overlay/Frame/Layout/Actions/Bind") as Button
func _abandon_button() -> Button: return get_node("Overlay/Frame/Layout/Actions/Abandon") as Button
func _cancel_button() -> Button: return get_node("Overlay/Frame/Layout/Actions/Cancel") as Button
func _abandon_confirmation() -> ConfirmationDialog: return get_node("AbandonConfirmation") as ConfirmationDialog
