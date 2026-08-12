extends RefCounted

const TUNING_PATH := "res://data/items/personal_loot_tuning.tres"
const EVENT_SCRIPT_PATH := "res://scripts/loot/enemy_defeat_event.gd"
const POLICY_SCRIPT_PATH := "res://scripts/loot/encounter_item_level_policy.gd"

var _event_script: Script
var _policy_script: Script

func run() -> Array[String]:
	var failures: Array[String] = []
	for path: String in [EVENT_SCRIPT_PATH, POLICY_SCRIPT_PATH, TUNING_PATH]:
		if not ResourceLoader.exists(path):
			failures.append("required loot-domain resource exists: %s" % path)
	if not failures.is_empty():
		return failures
	_event_script = load(EVENT_SCRIPT_PATH) as Script
	_policy_script = load(POLICY_SCRIPT_PATH) as Script
	var tuning := load(TUNING_PATH) as Resource
	TestAssertions.truthy(_event_script != null, "enemy defeat event script loads", failures)
	TestAssertions.truthy(_policy_script != null, "encounter item level policy script loads", failures)
	TestAssertions.truthy(tuning != null, "personal loot tuning resource loads", failures)
	if _event_script == null or _policy_script == null or tuning == null:
		return failures
	_test_exact_tuning_defaults(tuning, failures)
	_test_explicit_curve(tuning, failures)
	_test_monotonic_scaling(tuning, failures)
	_test_category_seams(tuning, failures)
	_test_item_level_clamps(tuning, failures)
	return failures

func _test_exact_tuning_defaults(tuning: Resource, failures: Array[String]) -> void:
	var drop_basis_points: Dictionary = tuning.get(&"drop_basis_points")
	TestAssertions.equal(drop_basis_points, {
		&"ordinary_melee": 100,
		&"ordinary_specialist": 200,
		&"elite": 0,
		&"boss": 0,
	}, "drop basis points preserve exact approved defaults", failures)
	TestAssertions.near(float(tuning.get(&"seconds_per_item_level")), 12.0, 0.001, "seconds per item level default", failures)
	TestAssertions.equal(tuning.get(&"specialist_item_level_bonus"), 1, "specialist item-level bonus default", failures)
	TestAssertions.equal(tuning.get(&"elite_item_level_bonus"), 5, "elite item-level bonus default", failures)
	TestAssertions.equal(tuning.get(&"boss_item_level_bonus"), 10, "boss item-level bonus default", failures)
	TestAssertions.equal(tuning.get(&"difficulty_item_level_bonus"), {&"normal": 0}, "difficulty item-level defaults", failures)
	TestAssertions.near(float(tuning.get(&"heat_item_levels_per_point")), 0.25, 0.001, "Heat scaling default", failures)
	TestAssertions.near(float(tuning.get(&"pickup_interaction_radius")), 3.5, 0.001, "pickup interaction radius default", failures)
	TestAssertions.near(float(tuning.get(&"controller_target_query_radius")), 30.0, 0.001, "controller query radius default", failures)
	TestAssertions.equal(drop_basis_points[&"boss"], 0, "boss category support does not enable boss drops", failures)

func _test_explicit_curve(tuning: Resource, failures: Array[String]) -> void:
	var event: RefCounted = _event_script.call(&"create", 1337, 7, 9, &"spitter", &"ordinary_specialist", Vector3(2.0, 0.0, 4.0), 300.0)
	var level: int = _resolve(event, &"normal", 0.0, tuning)
	TestAssertions.equal(level, 27, "five-minute specialist item level follows the approved curve", failures)

func _test_monotonic_scaling(tuning: Resource, failures: Array[String]) -> void:
	var base := _event(&"ordinary_melee", 120.0)
	var later := _event(&"ordinary_melee", 132.0)
	var base_level := _resolve(base, &"normal", 0.0, tuning)
	TestAssertions.equal(base_level, 11, "ten two-minute intervals follow the explicit time curve", failures)
	TestAssertions.equal(_resolve(later, &"normal", 0.0, tuning), base_level + 1, "elapsed encounter time scales monotonically", failures)
	TestAssertions.equal(_resolve(base, &"normal", 8.0, tuning), base_level + 2, "Heat scales monotonically through floor", failures)
	var difficulty_tuning := tuning.duplicate(true) as Resource
	difficulty_tuning.set(&"difficulty_item_level_bonus", {&"normal": 0, &"veteran": 4})
	TestAssertions.equal(_resolve(base, &"veteran", 0.0, difficulty_tuning), base_level + 4, "difficulty bonus scales monotonically", failures)

func _test_category_seams(tuning: Resource, failures: Array[String]) -> void:
	TestAssertions.equal(_resolve(_event(&"ordinary_melee", 0.0), &"normal", 0.0, tuning), 1, "ordinary melee has no category bonus", failures)
	TestAssertions.equal(_resolve(_event(&"ordinary_specialist", 0.0), &"normal", 0.0, tuning), 2, "ordinary specialist uses exact category bonus", failures)
	TestAssertions.equal(_resolve(_event(&"elite", 0.0), &"normal", 0.0, tuning), 6, "elite data seam uses exact category bonus", failures)
	TestAssertions.equal(_resolve(_event(&"boss", 0.0), &"normal", 0.0, tuning), 11, "boss data seam uses exact category bonus", failures)

func _test_item_level_clamps(tuning: Resource, failures: Array[String]) -> void:
	var low_tuning := tuning.duplicate(true) as Resource
	low_tuning.set(&"difficulty_item_level_bonus", {&"normal": -100})
	TestAssertions.equal(_resolve(_event(&"ordinary_melee", 0.0), &"normal", 0.0, low_tuning), ItemGenerationRequest.MIN_ITEM_LEVEL, "item level clamps at lower production bound", failures)
	TestAssertions.equal(_resolve(_event(&"boss", 120000.0), &"normal", 0.0, tuning), ItemGenerationRequest.MAX_ITEM_LEVEL, "item level clamps at upper production bound", failures)

func _event(category: StringName, seconds: float) -> RefCounted:
	return _event_script.call(&"create", 1337, 1, 1, &"test_enemy", category, Vector3.ZERO, seconds) as RefCounted

func _resolve(event: RefCounted, difficulty_id: StringName, heat: float, tuning: Resource) -> int:
	return int(_policy_script.call(&"resolve", event, difficulty_id, heat, tuning))
