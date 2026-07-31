extends SceneTree

func _initialize() -> void:
	_set_action(&"character_ledger", [_key(KEY_TAB), _key(KEY_I), _button(JOY_BUTTON_BACK)])
	_set_action(&"pause_menu", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_set_action(&"ledger_previous_page", [_button(JOY_BUTTON_LEFT_SHOULDER)])
	_set_action(&"ledger_next_page", [_button(JOY_BUTTON_RIGHT_SHOULDER)])
	ProjectSettings.save()
	print("PARTY_FORGE_LEDGER_INPUTS_OK")
	quit(0)

func _set_action(action: StringName, events: Array) -> void:
	ProjectSettings.set_setting("input/%s" % action, {
		"deadzone": 0.2,
		"events": events,
	})

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event

func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
