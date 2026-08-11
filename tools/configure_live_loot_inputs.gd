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
	ProjectSettings.set_setting(setting_path, normalized_setting(existing, button))

static func normalized_setting(existing: Variant, button: JoyButton) -> Dictionary:
	var setting := existing as Dictionary if existing is Dictionary else {}
	var required := InputEventJoypadButton.new()
	required.device = -1
	required.button_index = button
	var events: Array[InputEvent] = [required]
	return {
		"deadzone": float(setting.get("deadzone", 0.2)),
		"events": events,
	}
