extends SceneTree

func _initialize() -> void:
	_set_action(&"world_loot_previous", JOY_BUTTON_DPAD_LEFT)
	_set_action(&"world_loot_next", JOY_BUTTON_DPAD_RIGHT)
	ProjectSettings.save()
	print("PARTY_FORGE_LIVE_LOOT_INPUTS_OK")
	quit(0)

func _set_action(action: StringName, button: JoyButton) -> void:
	var setting_path := "input/%s" % action
	var existing: Variant = ProjectSettings.get_setting(setting_path, {})
	var setting := existing.duplicate() as Dictionary if existing is Dictionary else {}
	var events: Array[InputEvent] = []
	for value: Variant in setting.get("events", []):
		if value is InputEvent:
			events.append(value)
	var required := InputEventJoypadButton.new()
	required.device = -1
	required.button_index = button
	if not events.any(func(event: InputEvent) -> bool: return event.is_match(required, true)):
		events.append(required)
	setting["deadzone"] = float(setting.get("deadzone", 0.2))
	setting["events"] = events
	ProjectSettings.set_setting(setting_path, setting)
