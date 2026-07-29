extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    var nearest_hostile := CombatTarget.new(null, Vector3(2.0, 0.0, 0.0), 2)
    var farther_hostile := CombatTarget.new(null, Vector3(5.0, 0.0, 0.0), 2)
    var distant_hostile := CombatTarget.new(null, Vector3(20.0, 0.0, 0.0), 2)
    var candidates: Array[CombatTarget] = [nearest_hostile, farther_hostile, distant_hostile]
    TestAssertions.equal(TargetSelector.nearest(Vector3.ZERO, candidates, 10.0, 1), nearest_hostile, "nearest hostile selected", failures)

    var same_team := CombatTarget.new(null, Vector3(1.0, 0.0, 0.0), 1)
    var with_same_team: Array[CombatTarget] = [same_team, nearest_hostile, farther_hostile]
    TestAssertions.equal(TargetSelector.nearest(Vector3.ZERO, with_same_team, 10.0, 1), nearest_hostile, "same team excluded", failures)

    var unavailable := CombatTarget.new(null, Vector3(0.5, 0.0, 0.0), 2)
    unavailable.is_available = false
    var with_unavailable: Array[CombatTarget] = [unavailable, nearest_hostile, farther_hostile]
    TestAssertions.equal(TargetSelector.nearest(Vector3.ZERO, with_unavailable, 10.0, 1), nearest_hostile, "unavailable target excluded", failures)
    TestAssertions.equal(TargetSelector.nearest(Vector3.ZERO, candidates, 1.0, 1), null, "out of range returns null", failures)

    var tie_left := CombatTarget.new(null, Vector3(-2.0, 0.0, 0.0), 2)
    var tie_right := CombatTarget.new(null, Vector3(2.0, 0.0, 0.0), 2)
    var ties_forward: Array[CombatTarget] = [tie_right, tie_left]
    var ties_reverse: Array[CombatTarget] = [tie_left, tie_right]
    TestAssertions.equal(TargetSelector.nearest(Vector3.ZERO, ties_forward, 10.0, 1), tie_left, "tie uses lexicographic position", failures)
    TestAssertions.equal(TargetSelector.nearest(Vector3.ZERO, ties_reverse, 10.0, 1), tie_left, "tie ignores candidate order", failures)

    var catalog := GameCatalog.load_defaults()
    var controller := AttackController.new()
    var attack: AttackDefinition = catalog.class_by_id(&"fighter").primary_attack
    controller.configure(attack, 1)
    TestAssertions.equal(controller.try_attack(Vector3.ZERO, candidates), nearest_hostile, "first attack succeeds", failures)
    TestAssertions.equal(controller.try_attack(Vector3.ZERO, candidates), null, "immediate attack blocked by cooldown", failures)
    controller.advance(attack.cooldown)
    TestAssertions.equal(controller.try_attack(Vector3.ZERO, candidates), nearest_hostile, "full cooldown restores attack", failures)
    controller.free()
    return failures
