extends RefCounted

const EXPECTED := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_back": [JOY_AXIS_LEFT_Y, 1.0],
}

func run() -> Array[String]:
	var failures: Array[String] = []
	for action_id: StringName in EXPECTED:
		var expected: Array = EXPECTED[action_id]
		var matching := InputMap.action_get_events(action_id).filter(func(event: InputEvent) -> bool:
			return event is InputEventJoypadMotion \
				and (event as InputEventJoypadMotion).axis == expected[0] \
				and is_equal_approx((event as InputEventJoypadMotion).axis_value, expected[1])
		)
		TestAssertions.equal(matching.size(), 1, "%s has its left-stick direction" % action_id, failures)
		TestAssertions.near(InputMap.action_get_deadzone(action_id), 0.2, 0.001, "%s retains movement deadzone" % action_id, failures)
	return failures
