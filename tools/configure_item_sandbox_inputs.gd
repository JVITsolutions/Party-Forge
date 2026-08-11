extends SceneTree

func _initialize() -> void:
	_set_action(&"item_sandbox_previous_tab", [_button(JOY_BUTTON_LEFT_SHOULDER)])
	_set_action(&"item_sandbox_next_tab", [_button(JOY_BUTTON_RIGHT_SHOULDER)])
	_set_action(&"item_sandbox_scroll_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_set_action(&"item_sandbox_scroll_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	ProjectSettings.save()
	print("PARTY_FORGE_ITEM_SANDBOX_INPUTS_OK")
	quit(0)

func _set_action(action: StringName, required_events: Array[InputEvent]) -> void:
	var setting_path := "input/%s" % action
	var existing: Variant = ProjectSettings.get_setting(setting_path, {})
	var setting := existing.duplicate() as Dictionary if existing is Dictionary else {}
	var events: Array[InputEvent] = []
	for value: Variant in setting.get("events", []):
		if value is InputEvent:
			events.append(value)
	for required: InputEvent in required_events:
		if not events.any(func(event: InputEvent) -> bool: return event.is_match(required, true)):
			events.append(required)
	setting["deadzone"] = float(setting.get("deadzone", 0.2))
	setting["events"] = events
	ProjectSettings.set_setting(setting_path, setting)

func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	return event

func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	return event
