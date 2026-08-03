extends RefCounted


func run() -> Array[String]:
	var failures: Array[String] = []
	_assert_motion_action(&"passive_tree_navigate_left", JOY_AXIS_LEFT_X, -1.0, 0.2, failures)
	_assert_motion_action(&"passive_tree_navigate_right", JOY_AXIS_LEFT_X, 1.0, 0.2, failures)
	_assert_motion_action(&"passive_tree_navigate_up", JOY_AXIS_LEFT_Y, -1.0, 0.2, failures)
	_assert_motion_action(&"passive_tree_navigate_down", JOY_AXIS_LEFT_Y, 1.0, 0.2, failures)
	_assert_button(&"passive_tree_navigate_left", JOY_BUTTON_DPAD_LEFT, failures)
	_assert_button(&"passive_tree_navigate_right", JOY_BUTTON_DPAD_RIGHT, failures)
	_assert_button(&"passive_tree_navigate_up", JOY_BUTTON_DPAD_UP, failures)
	_assert_button(&"passive_tree_navigate_down", JOY_BUTTON_DPAD_DOWN, failures)
	_assert_motion_action(&"passive_tree_pan_left", JOY_AXIS_RIGHT_X, -1.0, 0.2, failures)
	_assert_motion_action(&"passive_tree_pan_right", JOY_AXIS_RIGHT_X, 1.0, 0.2, failures)
	_assert_motion_action(&"passive_tree_pan_up", JOY_AXIS_RIGHT_Y, -1.0, 0.2, failures)
	_assert_motion_action(&"passive_tree_pan_down", JOY_AXIS_RIGHT_Y, 1.0, 0.2, failures)
	_assert_motion_action(&"passive_tree_zoom_in", JOY_AXIS_TRIGGER_RIGHT, 1.0, 0.2, failures)
	_assert_motion_action(&"passive_tree_zoom_out", JOY_AXIS_TRIGGER_LEFT, 1.0, 0.2, failures)
	_assert_button(&"passive_tree_allocate", JOY_BUTTON_A, failures)
	_assert_key(&"passive_tree_allocate", KEY_ENTER, failures)
	_assert_button(&"passive_tree_refund", JOY_BUTTON_X, failures)
	_assert_key(&"passive_tree_refund", KEY_R, failures)
	_assert_button(&"passive_tree_close", JOY_BUTTON_B, failures)
	_assert_key(&"passive_tree_close", KEY_ESCAPE, failures)
	return failures


func _assert_motion_action(action: StringName, axis: JoyAxis, sign_value: float, deadzone: float, failures: Array[String]) -> void:
	TestAssertions.truthy(InputMap.has_action(action), "%s exists" % action, failures)
	if not InputMap.has_action(action):
		return
	TestAssertions.near(InputMap.action_get_deadzone(action), deadzone, 0.0001, "%s uses exact deadzone" % action, failures)
	var matches := InputMap.action_get_events(action).filter(func(event: InputEvent) -> bool:
		return event is InputEventJoypadMotion and event.device == 0 and event.axis == axis and is_equal_approx(signf(event.axis_value), signf(sign_value)))
	TestAssertions.equal(matches.size(), 1, "%s has one exact device-0 motion binding" % action, failures)


func _assert_button(action: StringName, button: JoyButton, failures: Array[String]) -> void:
	TestAssertions.truthy(InputMap.has_action(action), "%s exists for controller button" % action, failures)
	if not InputMap.has_action(action):
		return
	var matches := InputMap.action_get_events(action).filter(func(event: InputEvent) -> bool:
		return event is InputEventJoypadButton and event.device == 0 and event.button_index == button)
	TestAssertions.equal(matches.size(), 1, "%s has one exact device-0 button binding" % action, failures)


func _assert_key(action: StringName, keycode: Key, failures: Array[String]) -> void:
	TestAssertions.truthy(InputMap.has_action(action), "%s exists for keyboard key" % action, failures)
	if not InputMap.has_action(action):
		return
	var matches := InputMap.action_get_events(action).filter(func(event: InputEvent) -> bool:
		return event is InputEventKey and (event.keycode == keycode or event.physical_keycode == keycode))
	TestAssertions.equal(matches.size(), 1, "%s has one exact keyboard binding" % action, failures)
