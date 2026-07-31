extends SceneTree


func _initialize() -> void:
	_set_key_action(&"tooltip_hold", KEY_ALT)
	_set_button_action(&"tooltip_pin", JOY_BUTTON_Y)
	_set_axis_action(&"tooltip_scroll_up", JOY_AXIS_RIGHT_Y, -1.0)
	_set_axis_action(&"tooltip_scroll_down", JOY_AXIS_RIGHT_Y, 1.0)
	ProjectSettings.save()
	print("PARTY_FORGE_TOOLTIP_INPUTS_OK")
	quit(0)


func _set_key_action(action: StringName, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	_set_action(action, [event])


func _set_button_action(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	_set_action(action, [event])


func _set_axis_action(action: StringName, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	_set_action(action, [event])


func _set_action(action: StringName, events: Array[InputEvent]) -> void:
	ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.2, "events": events})
