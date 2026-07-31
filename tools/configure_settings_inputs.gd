extends SceneTree


func _initialize() -> void:
	_set_action(&"settings_previous_tab", JOY_BUTTON_LEFT_SHOULDER)
	_set_action(&"settings_next_tab", JOY_BUTTON_RIGHT_SHOULDER)
	ProjectSettings.save()
	print("PARTY_FORGE_SETTINGS_INPUTS_OK")
	quit(0)


func _set_action(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.2, "events": [event]})
