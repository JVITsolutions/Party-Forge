extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var profile := EnemyProjectileProfile.new()
	profile.hit_radius = -1.0
	profile.max_lifetime = NAN
	profile.tell_duration = -0.1
	var errors: Array = Array(profile.validate(&"test_enemy"))
	TestAssertions.truthy(errors.any(func(value: String) -> bool: return "hit radius" in value), "negative hit radius fails", failures)
	TestAssertions.truthy(errors.any(func(value: String) -> bool: return "lifetime" in value), "non-finite lifetime fails", failures)
	TestAssertions.truthy(errors.any(func(value: String) -> bool: return "tell duration" in value), "negative tell fails", failures)
	var enemy := EnemyDefinition.new()
	enemy.id = &"missing_profile"
	enemy.behavior = EnemyDefinition.Behavior.SPITTER
	TestAssertions.truthy(Array(enemy.validate()).any(func(value: String) -> bool: return "projectile profile" in value), "ranged behavior requires profile", failures)
	return failures
