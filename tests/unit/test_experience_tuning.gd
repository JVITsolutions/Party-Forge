extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var tuning := ExperienceTuning.new()
	var actual := PackedInt32Array()
	for level: int in range(1, 7):
		actual.append(tuning.requirement_for_level(level))
	TestAssertions.equal(actual, PackedInt32Array([20, 30, 44, 62, 84, 110]), "approved XP sequence", failures)
	TestAssertions.equal(tuning.validate(), PackedStringArray(), "default XP tuning validates", failures)
	for level: int in range(1, 12):
		TestAssertions.truthy(
			tuning.requirement_for_level(level + 1) > tuning.requirement_for_level(level),
			"XP requirements increase from level %d" % level,
			failures,
		)

	var invalid := ExperienceTuning.new()
	invalid.acceleration = -1.0
	TestAssertions.equal(
		invalid.validate(),
		PackedStringArray(["PARTY_FORGE_XP_ERROR field=acceleration"]),
		"invalid XP diagnostic",
		failures,
	)
	TestAssertions.equal(invalid.requirement_for_level(6), 110, "invalid XP term uses safe fallback", failures)

	invalid = ExperienceTuning.new()
	invalid.base_cost = NAN
	invalid.linear_growth = -0.5
	TestAssertions.equal(
		invalid.validate(),
		PackedStringArray([
			"PARTY_FORGE_XP_ERROR field=base_cost",
			"PARTY_FORGE_XP_ERROR field=linear_growth",
		]),
		"all invalid XP fields are diagnostic",
		failures,
	)
	TestAssertions.equal(invalid.requirement_for_level(2), 30, "invalid XP fields use independent safe fallbacks", failures)
	TestAssertions.equal(tuning.requirement_for_level(0), 20, "nonpositive levels use level one", failures)
	return failures
