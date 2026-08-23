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
	_test_percentage_point_snapping(roll_script, failures)
	_test_processing_ceiling(roll_script, failures)
	_test_large_finite_chances(roll_script, failures)
	_test_nonfinite_chances_are_rejected(roll_script, failures)
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

func _test_percentage_point_snapping(roll_script: Script, failures: Array[String]) -> void:
	for row: Dictionary in [
		{"label": "legacy off-grid value", "chance": 0.0111, "expected": 0.01, "draw": 0.009, "critical": true},
		{"label": "below half-point boundary", "chance": 0.0149, "expected": 0.01, "draw": 0.01, "critical": false},
		{"label": "above half-point boundary", "chance": 0.0151, "expected": 0.02, "draw": 0.019, "critical": true},
	]:
		var rng := CombatRng.new(3001, [float(row["draw"])])
		var roll: Object = roll_script.call("create", float(row["chance"]), rng)
		var label := String(row["label"])
		TestAssertions.near(float(roll.get("crit_chance")), float(row["expected"]), 0.000001, "%s snaps to an exact percentage point" % label, failures)
		TestAssertions.near(float(roll.get("fractional_chance")), float(row["expected"]), 0.000001, "%s uses the snapped roll boundary" % label, failures)
		TestAssertions.equal(roll.get("critical_flags"), [bool(row["critical"])], "%s compares the prescribed draw to the snapped boundary" % label, failures)
		TestAssertions.equal(rng.draw_count, 1, "%s consumes exactly one processable draw" % label, failures)

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

func _test_large_finite_chances(roll_script: Script, failures: Array[String]) -> void:
	var near_conversion_boundary := 9.0e16
	var boundary_rng := CombatRng.new(303, [0.0])
	var boundary_roll: Object = roll_script.call("create", near_conversion_boundary, boundary_rng)
	TestAssertions.truthy(boundary_roll != null, "near-conversion-boundary chance creates metadata", failures)
	if boundary_roll != null:
		var boundary_flags: Array = boundary_roll.get("critical_flags")
		TestAssertions.equal(boundary_roll.get("crit_chance"), near_conversion_boundary, "near-conversion-boundary chance is preserved", failures)
		TestAssertions.equal(boundary_roll.get("requested_instances"), 90000000000000000, "near-conversion-boundary requested count does not wrap", failures)
		TestAssertions.equal(boundary_roll.get("guaranteed_instances"), 90000000000000000, "near-conversion-boundary guaranteed count does not wrap", failures)
		TestAssertions.equal(boundary_roll.get("processed_instances"), 10000, "near-conversion-boundary processing stays bounded", failures)
		TestAssertions.truthy(bool(boundary_roll.get("ceiling_truncated")), "near-conversion-boundary records truncation", failures)
		TestAssertions.equal(boundary_flags.size(), 10000, "near-conversion-boundary allocates only the ceiling", failures)
		TestAssertions.truthy(boundary_flags.all(func(flag: Variant) -> bool: return bool(flag)), "near-conversion-boundary never wraps to a normal flag", failures)
		TestAssertions.equal(boundary_rng.draw_count, 0, "near-conversion-boundary full ceiling consumes no remainder draw", failures)
	for transition: Dictionary in [
		{"label": "below", "chance": 89999999999999984.0, "count": 89999999999999984},
		{"label": "above", "chance": 90000000000000016.0, "count": 90000000000000016},
	]:
		var transition_rng := CombatRng.new(3031, [0.0])
		var transition_roll: Object = roll_script.call("create", float(transition["chance"]), transition_rng)
		var label := String(transition["label"])
		TestAssertions.equal(transition_roll.get("crit_chance"), transition["chance"], "%s safe-snapping transition preserves chance" % label, failures)
		TestAssertions.equal(transition_roll.get("requested_instances"), transition["count"], "%s safe-snapping transition preserves requested count" % label, failures)
		TestAssertions.equal(transition_roll.get("guaranteed_instances"), transition["count"], "%s safe-snapping transition preserves guaranteed count" % label, failures)
		TestAssertions.equal(transition_roll.get("processed_instances"), 10000, "%s safe-snapping transition remains bounded" % label, failures)
		TestAssertions.truthy(not bool(transition_roll.get("requested_count_overflow")), "%s safe-snapping transition needs no count saturation" % label, failures)
		TestAssertions.equal(transition_rng.draw_count, 0, "%s safe-snapping transition consumes no remainder draw" % label, failures)
	for transition: Dictionary in [
		{"label": "below", "chance": 90071992547408.98, "requested": 90071992547409, "guaranteed": 90071992547408},
		{"label": "at", "chance": 90071992547409.0, "requested": 90071992547409, "guaranteed": 90071992547409},
		{"label": "above", "chance": 90071992547409.02, "requested": 90071992547410, "guaranteed": 90071992547409},
	]:
		var transition_rng := CombatRng.new(3032, [0.0])
		var transition_roll: Object = roll_script.call("create", float(transition["chance"]), transition_rng)
		var label := String(transition["label"])
		TestAssertions.equal(transition_roll.get("crit_chance"), transition["chance"], "%s exact-product transition preserves authoritative chance" % label, failures)
		TestAssertions.equal(transition_roll.get("requested_instances"), transition["requested"], "%s exact-product transition preserves requested count" % label, failures)
		TestAssertions.equal(transition_roll.get("guaranteed_instances"), transition["guaranteed"], "%s exact-product transition preserves guaranteed count" % label, failures)
		TestAssertions.equal(transition_roll.get("processed_instances"), 10000, "%s exact-product transition remains bounded" % label, failures)
		TestAssertions.truthy(not bool(transition_roll.get("requested_count_overflow")), "%s exact-product transition needs no saturation" % label, failures)
		TestAssertions.equal(transition_rng.draw_count, 0, "%s exact-product transition consumes no unprocessable draw" % label, failures)
	for transition: Dictionary in [
		{"label": "last binary64 step below INT64 limit", "chance": 9223372036854774784.0, "count": 9223372036854774784, "overflow": false},
		{"label": "INT64 limit", "chance": 9223372036854775808.0, "count": 9223372036854775807, "overflow": true},
	]:
		var transition_rng := CombatRng.new(3033, [0.0])
		var transition_roll: Object = roll_script.call("create", float(transition["chance"]), transition_rng)
		var label := String(transition["label"])
		TestAssertions.equal(transition_roll.get("crit_chance"), transition["chance"], "%s preserves finite chance" % label, failures)
		TestAssertions.equal(transition_roll.get("requested_instances"), transition["count"], "%s saturates requested count without wrapping" % label, failures)
		TestAssertions.equal(transition_roll.get("guaranteed_instances"), transition["count"], "%s saturates guaranteed count without wrapping" % label, failures)
		TestAssertions.equal(transition_roll.get("requested_count_overflow"), transition["overflow"], "%s reports saturation precisely" % label, failures)
		TestAssertions.equal(transition_roll.get("processed_instances"), 10000, "%s remains bounded" % label, failures)
		TestAssertions.equal(transition_rng.draw_count, 0, "%s consumes no unprocessable draw" % label, failures)

	var huge_chance := 1.0e100
	var huge_rng := CombatRng.new(304, [0.0])
	var huge_roll: Object = roll_script.call("create", huge_chance, huge_rng)
	TestAssertions.truthy(huge_roll != null, "huge finite chance creates metadata", failures)
	if huge_roll == null:
		return
	var huge_flags: Array = huge_roll.get("critical_flags")
	TestAssertions.equal(huge_roll.get("crit_chance"), huge_chance, "huge finite chance is preserved", failures)
	TestAssertions.equal(huge_roll.get("requested_instances"), 9223372036854775807, "huge requested count saturates at INT64_MAX", failures)
	TestAssertions.equal(huge_roll.get("guaranteed_instances"), 9223372036854775807, "huge guaranteed count saturates at INT64_MAX", failures)
	TestAssertions.equal(huge_roll.get("processed_instances"), 10000, "huge finite chance processes exactly the ceiling", failures)
	TestAssertions.truthy(bool(huge_roll.get("ceiling_truncated")), "huge finite chance records ceiling truncation", failures)
	TestAssertions.equal(huge_flags.size(), 10000, "huge finite chance allocates only the ceiling", failures)
	TestAssertions.truthy(huge_flags.all(func(flag: Variant) -> bool: return bool(flag)), "huge finite chance produces only guaranteed critical flags", failures)
	TestAssertions.equal(huge_rng.draw_count, 0, "huge finite chance consumes no unprocessable remainder draw", failures)
	var has_overflow := _has_property(huge_roll, &"requested_count_overflow")
	TestAssertions.truthy(has_overflow, "huge finite chance exposes count-overflow diagnostics", failures)
	if has_overflow:
		TestAssertions.truthy(bool(huge_roll.get("requested_count_overflow")), "huge finite chance marks count overflow", failures)
		var copied: Object = huge_roll.call("copy")
		TestAssertions.truthy(copied != null and bool(copied.get("requested_count_overflow")), "defensive copy preserves count-overflow diagnostics", failures)

func _test_nonfinite_chances_are_rejected(roll_script: Script, failures: Array[String]) -> void:
	for row: Dictionary in [
		{"label": "NaN", "chance": NAN},
		{"label": "positive infinity", "chance": INF},
		{"label": "negative infinity", "chance": -INF},
	]:
		var rng := CombatRng.new(305, [0.0])
		var roll: Object = roll_script.call("create", float(row["chance"]), rng)
		var label := String(row["label"])
		TestAssertions.truthy(roll != null, "%s returns structured rejection metadata" % label, failures)
		if roll == null:
			continue
		var has_valid := _has_property(roll, &"valid")
		var has_error := _has_property(roll, &"error_reason")
		TestAssertions.truthy(has_valid and has_error, "%s exposes structured validity diagnostics" % label, failures)
		if not has_valid or not has_error:
			continue
		TestAssertions.truthy(not bool(roll.get("valid")), "%s is explicitly rejected" % label, failures)
		TestAssertions.truthy(String(roll.get("error_reason")).contains("chance must be finite"), "%s reports the finite-chance requirement" % label, failures)
		TestAssertions.equal(roll.get("requested_instances"), 0, "%s requests no instances" % label, failures)
		TestAssertions.equal(roll.get("processed_instances"), 0, "%s processes no instances" % label, failures)
		TestAssertions.equal((roll.get("critical_flags") as Array).size(), 0, "%s produces no valid-looking flag" % label, failures)
		TestAssertions.equal(rng.draw_count, 0, "%s consumes no RNG" % label, failures)
		roll.set("valid", true)
		roll.set("error_reason", "")
		TestAssertions.truthy(not bool(roll.get("valid")), "%s validity diagnostic is immutable" % label, failures)
		TestAssertions.truthy(String(roll.get("error_reason")).contains("chance must be finite"), "%s error diagnostic is immutable" % label, failures)
		var copied: Object = roll.call("copy")
		TestAssertions.truthy(copied != null and not bool(copied.get("valid")), "%s defensive copy preserves rejection" % label, failures)
		TestAssertions.truthy(copied != null and String(copied.get("error_reason")).contains("chance must be finite"), "%s defensive copy preserves error diagnostics" % label, failures)

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
	var overflow_roll: Object = roll_script.call("create", 1.0e100, CombatRng.new(306))
	if overflow_roll != null and _has_property(overflow_roll, &"requested_count_overflow"):
		overflow_roll.set("requested_count_overflow", false)
		TestAssertions.truthy(bool(overflow_roll.get("requested_count_overflow")), "count-overflow diagnostics are immutable", failures)

func _has_property(object: Object, property_name: StringName) -> bool:
	return object.get_property_list().any(func(property: Dictionary) -> bool:
		return property.get("name") == property_name
	)
