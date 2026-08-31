class_name WarehouseLockedDialog
extends CanvasLayer

signal city_tree_requested(return_focus: Control)
signal closed

enum Guidance { CITY_TREE_AVAILABLE, PROLOGUE_REQUIRED, TEMPORARILY_UNAVAILABLE }

const TITLE := "WAREHOUSE LOCKED"
const REQUIREMENT := "Requires Stash Access"
const AVAILABLE_BODY := "Unlock Stash Access in the City tree to open permanent storage."
const PROLOGUE_BODY := "Complete the prologue to access the City tree. Then unlock Stash Access to open the Warehouse."
const UNAVAILABLE_BODY := "City services are temporarily unavailable. Try again later."

var _return_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view_city_tree().pressed.connect(_on_view_city_tree)
	_back().pressed.connect(_on_back)


func open(guidance: Guidance, return_focus: Control) -> bool:
	_return_focus = return_focus
	_title().text = TITLE
	_requirement().text = REQUIREMENT
	match guidance:
		Guidance.CITY_TREE_AVAILABLE:
			_body().text = AVAILABLE_BODY
			_view_city_tree().visible = true
			_view_city_tree().disabled = false
		Guidance.PROLOGUE_REQUIRED:
			_body().text = PROLOGUE_BODY
			_view_city_tree().visible = false
			_view_city_tree().disabled = true
		Guidance.TEMPORARILY_UNAVAILABLE:
			_body().text = UNAVAILABLE_BODY
			_view_city_tree().visible = false
			_view_city_tree().disabled = true
	visible = true
	_rebuild_focus_loop()
	if is_inside_tree():
		_initial_focus().grab_focus()
	return true


func close(restore_focus := true) -> void:
	visible = false
	var target := _return_focus
	_return_focus = null
	if restore_focus and target != null and is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed(&"ui_cancel"):
		close(true)
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _on_view_city_tree() -> void:
	var target := _return_focus
	close(false)
	city_tree_requested.emit(target)


func _on_back() -> void:
	close(true)


func _initial_focus() -> Button:
	return _view_city_tree() if _view_city_tree().visible else _back()


func _rebuild_focus_loop() -> void:
	var controls: Array[Button] = [_back()]
	if _view_city_tree().visible:
		controls.push_front(_view_city_tree())
	for index: int in controls.size():
		var control := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var previous := controls[posmod(index - 1, controls.size())]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_next = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_right = control.get_path_to(next)
		control.focus_neighbor_bottom = control.get_path_to(next)


func _title() -> Label: return get_node("Overlay/Frame/Layout/Title") as Label
func _requirement() -> Label: return get_node("Overlay/Frame/Layout/Requirement") as Label
func _body() -> Label: return get_node("Overlay/Frame/Layout/Body") as Label
func _view_city_tree() -> Button: return get_node("Overlay/Frame/Layout/Actions/ViewCityTree") as Button
func _back() -> Button: return get_node("Overlay/Frame/Layout/Actions/Back") as Button
