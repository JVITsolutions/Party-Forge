extends RefCounted

const HealthScript := preload("res://scripts/combat/health_component.gd")

func run() -> Array[String]:
    var failures: Array[String] = []
    var companion: HealthComponent = HealthScript.new()
    companion.configure(100.0, false, 8.0, 0.5)
    TestAssertions.near(companion.apply_damage(13.0), 13.0, 0.001, "final damage is exact", failures)
    TestAssertions.near(companion.apply_damage(500.0), 87.0, 0.001, "overkill reports actual removal", failures)
    TestAssertions.truthy(companion.is_downed, "companion is downed", failures)
    companion.advance_time(7.9)
    TestAssertions.truthy(companion.is_downed, "companion remains downed before delay", failures)
    companion.advance_time(0.1)
    TestAssertions.truthy(not companion.is_downed, "companion revives", failures)
    TestAssertions.near(companion.current_health, 50.0, 0.001, "revive health fraction", failures)
    companion.free()

    var runtime_companion: HealthComponent = HealthScript.new()
    runtime_companion.configure(100.0, false, 8.0, 0.5)
    runtime_companion.apply_damage(100.0)
    TestAssertions.truthy(runtime_companion.has_method("_process"), "runtime health component owns revive clock", failures)
    if runtime_companion.has_method("_process"):
        runtime_companion.call("_process", 8.0)
        TestAssertions.truthy(not runtime_companion.is_downed, "runtime process revives companion", failures)
    runtime_companion.free()

    var leader: HealthComponent = HealthScript.new()
    leader.configure(80.0, true, 8.0, 0.5)
    leader.apply_damage(80.0)
    TestAssertions.truthy(leader.is_dead, "leader dies", failures)
    leader.apply_damage(10.0)
    TestAssertions.near(leader.current_health, 0.0, 0.001, "terminal damage is idempotent", failures)
    leader.free()
    return failures
