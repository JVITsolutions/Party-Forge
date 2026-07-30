extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_fractional_and_step_invariance(failures)
	_test_clamping_and_unavailable_states(failures)
	_test_recovery_after_revive(failures)
	return failures

func _test_fractional_and_step_invariance(failures: Array[String]) -> void:
	var quarter_health := _damaged_health(100.0, 50.0)
	var quarter_recovery := RecoveryController.new()
	quarter_recovery.configure(quarter_health, func() -> float: return 10.0)
	TestAssertions.near(quarter_recovery.advance(0.25), 2.5, 0.001, "quarter-step recovery is rate times delta", failures)
	for index: int in range(3):
		quarter_recovery.advance(0.25)
	var full_health := _damaged_health(100.0, 50.0)
	var full_recovery := RecoveryController.new()
	full_recovery.configure(full_health, func() -> float: return 10.0)
	TestAssertions.near(full_recovery.advance(1.0), 10.0, 0.001, "full-step recovery amount", failures)
	TestAssertions.near(quarter_health.current_health, full_health.current_health, 0.001, "four quarter-steps equal one full step", failures)
	quarter_recovery.free()
	quarter_health.free()
	full_recovery.free()
	full_health.free()

func _test_clamping_and_unavailable_states(failures: Array[String]) -> void:
	var clamped_health := _damaged_health(100.0, 95.0)
	var clamped_recovery := RecoveryController.new()
	clamped_recovery.configure(clamped_health, func() -> float: return 10.0)
	TestAssertions.near(clamped_recovery.advance(1.0), 5.0, 0.001, "recovery reports only health restored at cap", failures)
	TestAssertions.near(clamped_recovery.advance(1.0), 0.0, 0.001, "full health does not recover", failures)
	clamped_recovery.free()
	clamped_health.free()

	var downed_health := _damaged_health(100.0, 0.0)
	downed_health.apply_damage(100.0)
	var downed_recovery := RecoveryController.new()
	downed_recovery.configure(downed_health, func() -> float: return 10.0)
	TestAssertions.near(downed_recovery.advance(1.0), 0.0, 0.001, "downed target does not recover", failures)
	downed_recovery.free()
	downed_health.free()

	var dead_health := HealthComponent.new()
	dead_health.configure(100.0, true, 8.0, 0.5)
	dead_health.apply_damage(100.0)
	var dead_recovery := RecoveryController.new()
	dead_recovery.configure(dead_health, func() -> float: return 10.0)
	TestAssertions.near(dead_recovery.advance(1.0), 0.0, 0.001, "dead target does not recover", failures)
	dead_recovery.free()
	dead_health.free()

func _test_recovery_after_revive(failures: Array[String]) -> void:
	var health := HealthComponent.new()
	health.configure(100.0, false, 8.0, 0.5)
	health.apply_damage(100.0)
	health.advance_time(8.0)
	var recovery := RecoveryController.new()
	recovery.configure(health, func() -> float: return 10.0)
	TestAssertions.near(recovery.advance(0.25), 2.5, 0.001, "recovery resumes after revive", failures)
	TestAssertions.near(health.current_health, 52.5, 0.001, "revived target receives continuous recovery", failures)
	recovery.free()
	health.free()

func _damaged_health(maximum: float, current: float) -> HealthComponent:
	var health := HealthComponent.new()
	health.configure(maximum, false, 8.0, 0.5)
	health.current_health = current
	return health
