extends SceneTree


func _initialize() -> void:
	_set_action(&"settings_previous_tab", JOY_BUTTON_LEFT_SHOULDER)
	_set_action(&"settings_next_tab", JOY_BUTTON_RIGHT_SHOULDER)
	_append_joypad_action(&"ui_accept", JOY_BUTTON_A)
	ProjectSettings.save()
	print("PARTY_FORGE_SETTINGS_INPUTS_OK")
	quit(0)


func _set_action(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.2, "events": [event]})


func _append_joypad_action(action: StringName, button: JoyButton) -> void:
	var events := InputMap.action_get_events(action)
	var has_button := events.any(func(event: InputEvent) -> bool:
		return event is InputEventJoypadButton and event.button_index == button
	)
	if not has_button:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		events.append(event)
	ProjectSettings.set_setting("input/%s" % action, {"deadzone": InputMap.action_get_deadzone(action), "events": events})
