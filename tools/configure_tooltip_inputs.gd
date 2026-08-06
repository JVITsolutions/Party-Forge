extends SceneTree


func _initialize() -> void:
	_set_key_action(&"tooltip_hold", KEY_ALT)
	_set_button_action(&"tooltip_pin", JOY_BUTTON_Y)
	_set_axis_action(&"tooltip_scroll_up", JOY_AXIS_RIGHT_Y, -1.0)
	_set_axis_action(&"tooltip_scroll_down", JOY_AXIS_RIGHT_Y, 1.0)
	_set_action(&"tooltip_compare", [_key(KEY_ALT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_set_action(&"tooltip_advanced", [_key(KEY_SHIFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
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


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	return event


func _set_action(action: StringName, events: Array[InputEvent]) -> void:
	var setting_path := "input/%s" % action
	var existing_value: Variant = ProjectSettings.get_setting(setting_path, {})
	var setting: Dictionary = {}
	if existing_value is Dictionary:
		setting = existing_value.duplicate()
	var merged_events: Array[InputEvent] = []
	for existing_event: Variant in setting.get("events", []):
		if existing_event is InputEvent:
			merged_events.append(existing_event)
	for required_event: InputEvent in events:
		if not _has_matching_event(merged_events, required_event):
			merged_events.append(required_event)
	if not setting.has("deadzone"):
		setting["deadzone"] = 0.2
	setting["events"] = merged_events
	ProjectSettings.set_setting(setting_path, setting)


func _has_matching_event(events: Array[InputEvent], required_event: InputEvent) -> bool:
	for existing_event: InputEvent in events:
		if existing_event.is_match(required_event, true):
			return true
	return false
