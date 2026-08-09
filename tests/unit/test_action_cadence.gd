extends RefCounted

const CADENCE_PATH := "res://scripts/combat/action_cadence.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	var script := load(CADENCE_PATH) as Script
	TestAssertions.truthy(script != null and script.can_instantiate(), "shared action cadence helper parses", failures)
	if script == null or not script.can_instantiate():
		return failures
	_test_neutral_compatibility(script, failures)
	_test_rate_multipliers_combine_once(script, failures)
	_test_invalid_inputs_and_derived_overflow(script, failures)
	return failures


func _test_neutral_compatibility(script: Script, failures: Array[String]) -> void:
	var cadence := script.call("resolve", 2.0, 1.0, 1.0) as RefCounted
	TestAssertions.truthy(cadence != null and bool(cadence.call("ok")), "neutral cadence resolves", failures)
	if cadence == null:
		return
	TestAssertions.near(float(cadence.get("progress_multiplier")), 1.0, 0.0001, "neutral cadence preserves runtime progress", failures)
	TestAssertions.near(float(cadence.get("effective_cooldown")), 2.0, 0.0001, "neutral cadence preserves authored cooldown seconds", failures)
	TestAssertions.near(float(cadence.get("actions_per_second")), 0.5, 0.0001, "neutral cadence preserves authored action rate", failures)


func _test_rate_multipliers_combine_once(script: Script, failures: Array[String]) -> void:
	var cadence := script.call("resolve", 2.0, 1.25, 1.2) as RefCounted
	TestAssertions.truthy(cadence != null and bool(cadence.call("ok")), "combined cadence resolves", failures)
	if cadence == null:
		return
	TestAssertions.near(float(cadence.get("progress_multiplier")), 1.5, 0.0001, "attack speed and cooldown recovery multiply once", failures)
	TestAssertions.near(float(cadence.get("effective_cooldown")), 4.0 / 3.0, 0.0001, "effective cooldown uses the combined progress multiplier", failures)
	TestAssertions.near(float(cadence.get("actions_per_second")), 0.75, 0.0001, "action rate is reciprocal effective cooldown", failures)


func _test_invalid_inputs_and_derived_overflow(script: Script, failures: Array[String]) -> void:
	for case: Dictionary in [
		{"cooldown": 0.0, "attack_speed": 1.0, "cooldown_rate": 1.0, "detail": "authored cooldown"},
		{"cooldown": -1.0, "attack_speed": 1.0, "cooldown_rate": 1.0, "detail": "authored cooldown"},
		{"cooldown": INF, "attack_speed": 1.0, "cooldown_rate": 1.0, "detail": "authored cooldown"},
		{"cooldown": 1.0, "attack_speed": -1.0, "cooldown_rate": 1.0, "detail": "attack speed"},
		{"cooldown": 1.0, "attack_speed": INF, "cooldown_rate": 1.0, "detail": "attack speed"},
		{"cooldown": 1.0, "attack_speed": 1.0, "cooldown_rate": -1.0, "detail": "cooldown recovery"},
		{"cooldown": 1.0, "attack_speed": 1.0, "cooldown_rate": INF, "detail": "cooldown recovery"},
		{"cooldown": 1.0, "attack_speed": 1.0e308, "cooldown_rate": 1.0e308, "detail": "progress multiplier"},
		{"cooldown": 1.0e308, "attack_speed": 1.0e-308, "cooldown_rate": 1.0, "detail": "effective cooldown"},
		{"cooldown": 1.0e-200, "attack_speed": 1.0e200, "cooldown_rate": 1.0, "detail": "action rate"},
	]:
		var cadence := script.call("resolve", case.cooldown, case.attack_speed, case.cooldown_rate) as RefCounted
		TestAssertions.truthy(cadence != null and not bool(cadence.call("ok")), "%s invalid cadence rejects" % case.detail, failures)
		if cadence != null:
			TestAssertions.truthy(String(case.detail) in String(cadence.get("error")).to_lower(), "%s rejection is contextual" % case.detail, failures)
