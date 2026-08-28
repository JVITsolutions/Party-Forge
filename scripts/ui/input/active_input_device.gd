class_name ActiveInputDevice
extends RefCounted

const KEYBOARD_MOUSE := &"keyboard_mouse"
const CONTROLLER := &"controller"

var device_kind: StringName = KEYBOARD_MOUSE


func observe(event: InputEvent) -> bool:
	var observed_kind := device_kind
	if event is InputEventJoypadButton:
		if not (event as InputEventJoypadButton).pressed:
			return false
		observed_kind = CONTROLLER
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) < 0.5:
			return false
		observed_kind = CONTROLLER
	elif event is InputEventKey:
		if not (event as InputEventKey).pressed:
			return false
		observed_kind = KEYBOARD_MOUSE
	elif event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed:
			return false
		observed_kind = KEYBOARD_MOUSE
	elif event is InputEventMouseMotion:
		observed_kind = KEYBOARD_MOUSE
	else:
		return false
	if observed_kind == device_kind:
		return false
	device_kind = observed_kind
	return true
