extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var attack := AttackDefinition.new()
	attack.id = &"geometry_test"
	attack.kind = AttackDefinition.Kind.MELEE_CLEAVE
	attack.range = 2.0
	attack.area_radius = 0.9
	var geometry := ResolvedAttackGeometry.from_attack(attack, 1.5, 2.0)
	TestAssertions.near(geometry.range, 3.0, 0.001, "range multiplier scales range only", failures)
	TestAssertions.near(geometry.area_radius, 1.8, 0.001, "area multiplier scales area only", failures)
	var fallback := ResolvedAttackGeometry.from_attack(attack, NAN, -4.0)
	TestAssertions.near(fallback.range, 2.0, 0.001, "invalid range multiplier falls back to one", failures)
	TestAssertions.near(fallback.area_radius, 0.0, 0.001, "negative area multiplier clamps safely", failures)
	return failures
