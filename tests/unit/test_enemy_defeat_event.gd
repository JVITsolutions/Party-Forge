extends RefCounted

const EVENT_SCRIPT_PATH := "res://scripts/loot/enemy_defeat_event.gd"

var _event_script: Script

func run() -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists(EVENT_SCRIPT_PATH):
		failures.append("enemy defeat event script exists")
		return failures
	_event_script = load(EVENT_SCRIPT_PATH) as Script
	TestAssertions.truthy(_event_script != null, "enemy defeat event script loads", failures)
	if _event_script == null:
		return failures
	_test_typed_event_creation(failures)
	_test_sequence_validation(failures)
	_test_time_validation(failures)
	_test_source_category_validation(failures)
	return failures

func _test_typed_event_creation(failures: Array[String]) -> void:
	var event: RefCounted = _event_script.call(
		&"create",
		1337,
		7,
		9,
		&"spitter",
		&"ordinary_specialist",
		Vector3(2.0, 0.0, 4.0),
		300.0,
	)
	TestAssertions.truthy(event != null and event.get_script() == _event_script, "factory returns a typed defeat event", failures)
	if event == null:
		return
	TestAssertions.equal(event.get(&"run_seed"), 1337, "event retains run seed", failures)
	TestAssertions.equal(event.get(&"defeat_sequence"), 7, "event retains defeat sequence", failures)
	TestAssertions.equal(event.get(&"enemy_sequence"), 9, "event retains enemy sequence", failures)
	TestAssertions.equal(event.get(&"enemy_id"), &"spitter", "event retains enemy id", failures)
	TestAssertions.equal(event.get(&"source_category"), &"ordinary_specialist", "event retains source category", failures)
	TestAssertions.equal(event.get(&"world_position"), Vector3(2.0, 0.0, 4.0), "event retains world position", failures)
	TestAssertions.near(float(event.get(&"encounter_seconds")), 300.0, 0.001, "event retains encounter time", failures)
	TestAssertions.truthy((event.call(&"validate") as PackedStringArray).is_empty(), "typed defeat event validates", failures)

func _test_sequence_validation(failures: Array[String]) -> void:
	var zero_defeat := _event(0, 1, &"ordinary_melee", 0.0)
	TestAssertions.truthy(
		(zero_defeat.call(&"validate") as PackedStringArray).has("PARTY_FORGE_LOOT_ERROR field=defeat_sequence reason=must be positive"),
		"zero defeat sequence is rejected",
		failures,
	)
	var zero_enemy := _event(1, 0, &"ordinary_melee", 0.0)
	TestAssertions.truthy(
		(zero_enemy.call(&"validate") as PackedStringArray).has("PARTY_FORGE_LOOT_ERROR field=enemy_sequence reason=must be positive"),
		"zero enemy sequence is rejected",
		failures,
	)

func _test_time_validation(failures: Array[String]) -> void:
	for invalid_time: float in [-0.01, NAN, INF, -INF]:
		var event := _event(1, 1, &"ordinary_melee", invalid_time)
		TestAssertions.truthy(
			(event.call(&"validate") as PackedStringArray).has("PARTY_FORGE_LOOT_ERROR field=encounter_seconds reason=must be finite and nonnegative"),
			"invalid encounter time is rejected: %s" % invalid_time,
			failures,
		)

func _test_source_category_validation(failures: Array[String]) -> void:
	for category: StringName in [&"ordinary_melee", &"ordinary_specialist", &"elite", &"boss"]:
		TestAssertions.equal(_event(1, 1, category, 0.0).call(&"validate"), PackedStringArray(), "known source category validates: %s" % category, failures)
	var unknown := _event(1, 1, &"champion", 0.0)
	TestAssertions.truthy(
		(unknown.call(&"validate") as PackedStringArray).has("PARTY_FORGE_LOOT_ERROR field=source_category reason=unknown category champion"),
		"unknown source category is rejected",
		failures,
	)

func _event(defeat_sequence: int, enemy_sequence: int, category: StringName, seconds: float) -> RefCounted:
	return _event_script.call(&"create", 1337, defeat_sequence, enemy_sequence, &"swarmer", category, Vector3.ZERO, seconds) as RefCounted
