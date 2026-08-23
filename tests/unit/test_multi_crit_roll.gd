extends RefCounted

const ROLL_PATH := "res://scripts/combat/multi_crit_roll.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(ROLL_PATH), "multi-crit roll metadata exists", failures)
	if not ResourceLoader.exists(ROLL_PATH):
		return failures
	var roll_script := load(ROLL_PATH) as Script
	TestAssertions.truthy(roll_script != null and roll_script.can_instantiate(), "multi-crit roll metadata parses", failures)
	if roll_script == null or not roll_script.can_instantiate():
		return failures
	_test_boundaries(roll_script, failures)
	_test_processing_ceiling(roll_script, failures)
	_test_metadata_is_immutable(roll_script, failures)
	return failures

func _test_boundaries(roll_script: Script, failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"label": "0 percent", "chance": 0.0, "draws": [], "flags": [false], "requested": 1, "processed": 1, "guaranteed": 0, "fractional": 0.0, "draw": -1.0, "success": false, "consumed": false, "draw_count": 0},
		{"label": "5 percent succeeds below boundary", "chance": 0.05, "draws": [0.04], "flags": [true], "requested": 1, "processed": 1, "guaranteed": 0, "fractional": 0.05, "draw": 0.04, "success": true, "consumed": true, "draw_count": 1},
		{"label": "5 percent fails at boundary", "chance": 0.05, "draws": [0.05], "flags": [false], "requested": 1, "processed": 1, "guaranteed": 0, "fractional": 0.05, "draw": 0.05, "success": false, "consumed": true, "draw_count": 1},
		{"label": "99 percent succeeds below boundary", "chance": 0.99, "draws": [0.98], "flags": [true], "requested": 1, "processed": 1, "guaranteed": 0, "fractional": 0.99, "draw": 0.98, "success": true, "consumed": true, "draw_count": 1},
		{"label": "99 percent fails at boundary", "chance": 0.99, "draws": [0.99], "flags": [false], "requested": 1, "processed": 1, "guaranteed": 0, "fractional": 0.99, "draw": 0.99, "success": false, "consumed": true, "draw_count": 1},
		{"label": "100 percent is guaranteed", "chance": 1.0, "draws": [], "flags": [true], "requested": 1, "processed": 1, "guaranteed": 1, "fractional": 0.0, "draw": -1.0, "success": false, "consumed": false, "draw_count": 0},
		{"label": "105 percent succeeds below boundary", "chance": 1.05, "draws": [0.04], "flags": [true, true], "requested": 2, "processed": 2, "guaranteed": 1, "fractional": 0.05, "draw": 0.04, "success": true, "consumed": true, "draw_count": 1},
		{"label": "105 percent fails at boundary", "chance": 1.05, "draws": [0.05], "flags": [true], "requested": 2, "processed": 1, "guaranteed": 1, "fractional": 0.05, "draw": 0.05, "success": false, "consumed": true, "draw_count": 1},
		{"label": "1150 percent succeeds below boundary", "chance": 11.50, "draws": [0.49], "flags": [true, true, true, true, true, true, true, true, true, true, true, true], "requested": 12, "processed": 12, "guaranteed": 11, "fractional": 0.50, "draw": 0.49, "success": true, "consumed": true, "draw_count": 1},
		{"label": "1150 percent fails at boundary", "chance": 11.50, "draws": [0.50], "flags": [true, true, true, true, true, true, true, true, true, true, true], "requested": 12, "processed": 11, "guaranteed": 11, "fractional": 0.50, "draw": 0.50, "success": false, "consumed": true, "draw_count": 1},
	]
	for row: Dictionary in cases:
		var prescribed: Array[float] = []
		prescribed.assign(row["draws"])
		var rng := CombatRng.new(300, prescribed)
		var roll: Object = roll_script.call("create", float(row["chance"]), rng)
		var label := String(row["label"])
		TestAssertions.truthy(roll != null, "%s creates roll metadata" % label, failures)
		if roll == null:
			continue
		TestAssertions.near(float(roll.get("crit_chance")), float(row["chance"]), 0.000001, "%s normalized chance" % label, failures)
		TestAssertions.equal(roll.get("requested_instances"), row["requested"], "%s requested instances" % label, failures)
		TestAssertions.equal(roll.get("processed_instances"), row["processed"], "%s processed instances" % label, failures)
		TestAssertions.equal(roll.get("guaranteed_instances"), row["guaranteed"], "%s guaranteed instances" % label, failures)
		TestAssertions.near(float(roll.get("fractional_chance")), float(row["fractional"]), 0.000001, "%s fractional chance" % label, failures)
		TestAssertions.near(float(roll.get("fractional_draw")), float(row["draw"]), 0.000001, "%s fractional draw" % label, failures)
		TestAssertions.equal(roll.get("fractional_success"), row["success"], "%s fractional result" % label, failures)
		TestAssertions.equal(roll.get("fractional_draw_consumed"), row["consumed"], "%s draw-consumed evidence" % label, failures)
		TestAssertions.equal(roll.get("ceiling_truncated"), false, "%s is not ceiling-truncated" % label, failures)
		TestAssertions.equal(roll.get("critical_flags"), row["flags"], "%s ordered critical flags" % label, failures)
		TestAssertions.equal(rng.draw_count, row["draw_count"], "%s exact RNG consumption" % label, failures)

func _test_processing_ceiling(roll_script: Script, failures: Array[String]) -> void:
	var rng := CombatRng.new(301, [0.0])
	var roll: Object = roll_script.call("create", 10000.05, rng)
	TestAssertions.truthy(roll != null, "ceiling case creates roll metadata", failures)
	if roll == null:
		return
	var flags: Array = roll.get("critical_flags")
	TestAssertions.near(float(roll.get("crit_chance")), 10000.05, 0.000001, "ceiling preserves uncapped normalized chance", failures)
	TestAssertions.equal(roll.get("requested_instances"), 10001, "ceiling reports uncapped potential request", failures)
	TestAssertions.equal(roll.get("processed_instances"), 10000, "ceiling processes exactly 10000 instances", failures)
	TestAssertions.equal(roll.get("guaranteed_instances"), 10000, "ceiling preserves uncapped guaranteed count", failures)
	TestAssertions.truthy(bool(roll.get("ceiling_truncated")), "ceiling records truncation", failures)
	TestAssertions.equal(flags.size(), 10000, "ceiling never allocates more than 10000 flags", failures)
	TestAssertions.truthy(flags.all(func(flag: Variant) -> bool: return bool(flag)), "ceiling flags preserve guaranteed ordering", failures)
	TestAssertions.near(float(roll.get("fractional_chance")), 0.05, 0.000001, "ceiling preserves unprocessed fractional chance", failures)
	TestAssertions.truthy(not bool(roll.get("fractional_draw_consumed")), "full ceiling does not process fractional draw", failures)
	TestAssertions.near(float(roll.get("fractional_draw")), -1.0, 0.000001, "full ceiling has no fractional draw evidence", failures)
	TestAssertions.equal(rng.draw_count, 0, "full ceiling consumes no fractional RNG draw", failures)

func _test_metadata_is_immutable(roll_script: Script, failures: Array[String]) -> void:
	var roll: Object = roll_script.call("create", 1.05, CombatRng.new(302, [0.04]))
	if roll == null:
		TestAssertions.truthy(false, "immutable fixture creates roll metadata", failures)
		return
	var exposed: Array = roll.get("critical_flags")
	exposed[0] = false
	exposed.clear()
	roll.set("crit_chance", 99.0)
	roll.set("requested_instances", 99)
	roll.set("processed_instances", 99)
	roll.set("guaranteed_instances", 99)
	roll.set("fractional_chance", 0.99)
	roll.set("fractional_draw", 0.99)
	roll.set("fractional_success", false)
	roll.set("fractional_draw_consumed", false)
	roll.set("ceiling_truncated", true)
	roll.set("critical_flags", [false])
	TestAssertions.near(float(roll.get("crit_chance")), 1.05, 0.000001, "normalized chance is immutable", failures)
	TestAssertions.equal(roll.get("requested_instances"), 2, "requested count is immutable", failures)
	TestAssertions.equal(roll.get("processed_instances"), 2, "processed count is immutable", failures)
	TestAssertions.equal(roll.get("guaranteed_instances"), 1, "guaranteed count is immutable", failures)
	TestAssertions.near(float(roll.get("fractional_chance")), 0.05, 0.000001, "fractional chance is immutable", failures)
	TestAssertions.near(float(roll.get("fractional_draw")), 0.04, 0.000001, "fractional draw is immutable", failures)
	TestAssertions.truthy(bool(roll.get("fractional_success")), "fractional result is immutable", failures)
	TestAssertions.truthy(bool(roll.get("fractional_draw_consumed")), "draw-consumed evidence is immutable", failures)
	TestAssertions.truthy(not bool(roll.get("ceiling_truncated")), "truncation evidence is immutable", failures)
	TestAssertions.equal(roll.get("critical_flags"), [true, true], "ordered flags are copied and immutable", failures)
