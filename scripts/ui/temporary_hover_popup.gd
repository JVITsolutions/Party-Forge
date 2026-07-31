class_name TemporaryHoverPopup
extends PanelContainer

signal dismissed
signal pin_changed(pinned: bool)

const CONTROLLER_SCROLL_SPEED := 560.0
const INPUT_DEADZONE := 0.15

@export var scroll_target_path: NodePath
@export var pin_button_path: NodePath
@export var unpinned_icon: Texture2D
@export var pinned_icon: Texture2D

var _source_id := &""
var _source_active := false
var _hold_active := false
var _pinned := false
var _scroll_axis := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var button := _pin_button()
	if button != null and not button.pressed.is_connected(toggle_pin):
		button.pressed.connect(toggle_pin)
	_sync_pin_button()


func present_source(source_id: StringName) -> bool:
	if source_id.is_empty():
		return false
	if _pinned and not is_current_source(source_id):
		return false
	var changed := not is_current_source(source_id)
	_source_id = source_id
	_source_active = true
	visible = true
	if changed:
		scroll_to_top()
	return true


func release_source(source_id: StringName) -> void:
	if not is_current_source(source_id):
		return
	_source_active = false
	_dismiss_if_unretained()


func set_hold_active(active: bool) -> void:
	_hold_active = active
	if not _hold_active:
		_dismiss_if_unretained()


func toggle_pin() -> void:
	if not visible:
		return
	_pinned = not _pinned
	_sync_pin_button()
	pin_changed.emit(_pinned)
	if not _pinned:
		_dismiss_if_unretained()


func force_dismiss() -> void:
	var was_visible := visible
	var was_pinned := _pinned
	_source_id = &""
	_source_active = false
	_hold_active = false
	_pinned = false
	_scroll_axis = 0.0
	visible = false
	scroll_to_top()
	_sync_pin_button()
	if was_pinned:
		pin_changed.emit(false)
	if was_visible:
		dismissed.emit()


func is_pinned() -> bool:
	return _pinned


func is_current_source(source_id: StringName) -> bool:
	return not _source_id.is_empty() and _source_id == source_id


func scroll_to_top() -> void:
	var scroll := _scroll_target()
	if scroll != null:
		scroll.scroll_vertical = 0


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(&"tooltip_hold"):
		if event.is_action_pressed(&"tooltip_hold"):
			var visible_before_press := visible
			set_hold_active(true)
			if visible_before_press:
				_mark_input_handled()
			return
		if event.is_action_released(&"tooltip_hold"):
			var visible_before_release := visible
			set_hold_active(false)
			if visible_before_release:
				_mark_input_handled()
			return
	if not visible:
		return
	if InputMap.has_action(&"tooltip_pin") and event.is_action_pressed(&"tooltip_pin"):
		toggle_pin()
		_mark_input_handled()
		return
	if InputMap.has_action(&"tooltip_scroll_up") and InputMap.has_action(&"tooltip_scroll_down"):
		_scroll_axis = event.get_action_strength(&"tooltip_scroll_down") - event.get_action_strength(&"tooltip_scroll_up")
		if absf(_scroll_axis) >= INPUT_DEADZONE:
			_mark_input_handled()


func _process(delta: float) -> void:
	if not visible or absf(_scroll_axis) < INPUT_DEADZONE:
		return
	var scroll := _scroll_target()
	if scroll != null:
		scroll.scroll_vertical += int(roundf(_scroll_axis * CONTROLLER_SCROLL_SPEED * delta))


func _dismiss_if_unretained() -> void:
	if visible and not _source_active and not _hold_active and not _pinned:
		force_dismiss()


func _pin_button() -> Button:
	return get_node_or_null(pin_button_path) as Button if not pin_button_path.is_empty() else null


func _scroll_target() -> ScrollContainer:
	return get_node_or_null(scroll_target_path) as ScrollContainer if not scroll_target_path.is_empty() else null


func _sync_pin_button() -> void:
	var button := _pin_button()
	if button == null:
		return
	button.button_pressed = _pinned
	button.icon = pinned_icon if _pinned else unpinned_icon
	var action := "Unpin details" if _pinned else "Pin details"
	button.tooltip_text = action
	button.accessibility_name = action


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()
