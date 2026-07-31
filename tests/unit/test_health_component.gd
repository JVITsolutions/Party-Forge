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

    _test_damage_floor(failures)
    _test_damage_floor_clamping(failures)
    _test_damage_floor_survives_max_health_changes(failures)
    _test_damage_never_heals_below_floor(failures)
    return failures

func _test_damage_floor(failures: Array[String]) -> void:
    var health: HealthComponent = HealthScript.new()
    var has_floor_api := health.has_method(&"configure_damage_floor")
    var has_feedback_signal := health.has_signal(&"damage_received")
    TestAssertions.truthy(has_floor_api, "health exposes an injected damage floor", failures)
    TestAssertions.truthy(has_feedback_signal, "health exposes valid damage-attempt feedback", failures)
    if not has_floor_api or not has_feedback_signal:
        health.free()
        return

    health.configure(100.0, true, 8.0, 0.5)
    health.call(&"configure_damage_floor", 1.0)
    var changes := [0]
    var received: Array[Vector2] = []
    health.health_changed.connect(func(_current: float, _maximum: float) -> void: changes[0] += 1)
    health.connect(&"damage_received", func(attempted: float, removed: float) -> void: received.append(Vector2(attempted, removed)))

    TestAssertions.equal(health.apply_damage(500.0), 99.0, "God Mode reports actual health removed", failures)
    TestAssertions.equal(health.current_health, 1.0, "God Mode stops damage at one", failures)
    TestAssertions.truthy(not health.is_dead and not health.is_downed, "God Mode avoids death and downing", failures)
    TestAssertions.equal(changes[0], 1, "God Mode still emits health-change feedback", failures)
    TestAssertions.equal(received, [Vector2(500.0, 99.0)], "God Mode reports attempted and removed damage", failures)

    health.apply_damage(20.0)
    TestAssertions.equal(received, [Vector2(500.0, 99.0), Vector2(20.0, 0.0)], "repeated damage at one health still emits feedback", failures)
    TestAssertions.equal(health.heal(20.0), 20.0, "healing remains functional", failures)
    health.kill()
    TestAssertions.truthy(health.is_dead and health.current_health == 0.0, "explicit kill remains authoritative", failures)
    health.set_max_health(50.0, true)
    TestAssertions.equal(health.current_health, 0.0, "maximum-health changes do not revive an explicitly killed actor", failures)
    health.free()

func _test_damage_floor_clamping(failures: Array[String]) -> void:
    var health: HealthComponent = HealthScript.new()
    if not health.has_method(&"configure_damage_floor"):
        health.free()
        return
    health.configure(10.0, true, 8.0, 0.5)
    health.call(&"configure_damage_floor", 50.0)
    TestAssertions.equal(health.apply_damage(5.0), 0.0, "damage floor clamps to maximum health", failures)
    TestAssertions.equal(health.current_health, 10.0, "oversized damage floor cannot exceed maximum health", failures)
    health.call(&"configure_damage_floor", -5.0)
    TestAssertions.equal(health.apply_damage(50.0), 10.0, "negative damage floor resets to zero", failures)
    TestAssertions.truthy(health.is_dead, "zero damage floor preserves leader death", failures)
    health.free()

func _test_damage_floor_survives_max_health_changes(failures: Array[String]) -> void:
    var health: HealthComponent = HealthScript.new()
    health.configure(100.0, true, 8.0, 0.5)
    health.configure_damage_floor(1.0)
    health.apply_damage(500.0)
    health.set_max_health(50.0, true)
    TestAssertions.equal(health.current_health, 1.0, "preserved fraction cannot move current health below its floor", failures)
    var received: Array[Vector2] = []
    health.damage_received.connect(func(attempted: float, removed: float) -> void: received.append(Vector2(attempted, removed)))
    TestAssertions.equal(health.apply_damage(10.0), 0.0, "damage after a maximum-health reduction never reports negative removal", failures)
    TestAssertions.equal(health.current_health, 1.0, "damage after a maximum-health reduction never raises health", failures)
    TestAssertions.equal(received, [Vector2(10.0, 0.0)], "damage feedback after a maximum-health reduction reports zero removal", failures)
    health.free()

    var reconfigured: HealthComponent = HealthScript.new()
    reconfigured.configure(100.0, true, 8.0, 0.5)
    reconfigured.configure_damage_floor(80.0)
    reconfigured.configure(50.0, true, 8.0, 0.5)
    reconfigured.set_max_health(100.0, false)
    reconfigured.heal(50.0)
    TestAssertions.equal(reconfigured.apply_damage(60.0), 50.0, "configure re-clamps a stale floor to the reduced maximum", failures)
    TestAssertions.equal(reconfigured.current_health, 50.0, "re-clamped floor remains bounded after a later maximum increase", failures)
    reconfigured.free()

func _test_damage_never_heals_below_floor(failures: Array[String]) -> void:
    var health: HealthComponent = HealthScript.new()
    health.configure(100.0, true, 8.0, 0.5)
    health.configure_damage_floor(1.0)
    health.current_health = 0.5
    var received: Array[Vector2] = []
    health.damage_received.connect(func(attempted: float, removed: float) -> void: received.append(Vector2(attempted, removed)))
    TestAssertions.equal(health.apply_damage(10.0), 0.0, "damage below the configured floor never reports negative removal", failures)
    TestAssertions.equal(health.current_health, 0.5, "damage below the configured floor never raises current health", failures)
    TestAssertions.equal(received, [Vector2(10.0, 0.0)], "damage below the floor reports a zero-removal attempt", failures)
    health.free()
