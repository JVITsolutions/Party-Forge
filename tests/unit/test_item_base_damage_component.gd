extends RefCounted

const COMPONENT_PATH := "res://scripts/items/item_base_damage_component.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(COMPONENT_PATH), "base damage component implementation exists", failures)
	var component_script := load(COMPONENT_PATH) as Script if ResourceLoader.exists(COMPONENT_PATH) else null
	if component_script == null:
		return failures
	_assert_value_contract(component_script, failures)
	_assert_validation(component_script, failures)
	return failures

func _assert_value_contract(component_script: Script, failures: Array[String]) -> void:
	var component: RefCounted = component_script.call("create", &"physical", 7.0, 11.0)
	TestAssertions.equal(component.call("to_dictionary"), {
		"damage_type_id": "physical",
		"minimum_damage": 7.0,
		"maximum_damage": 11.0,
	}, "base damage serializes exact fields", failures)
	TestAssertions.equal(component.call("validate", GameCatalog.DAMAGE_TYPES), "", "registered finite base damage validates", failures)

	var copied: RefCounted = component.call("copy")
	copied.set("damage_type_id", &"fire")
	copied.set("minimum_damage", 99.0)
	copied.set("maximum_damage", 101.0)
	TestAssertions.equal(component.call("to_dictionary"), {
		"damage_type_id": "physical",
		"minimum_damage": 7.0,
		"maximum_damage": 11.0,
	}, "base damage copy owns all values", failures)

func _assert_validation(component_script: Script, failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"component": component_script.call("create", &"", 7.0, 11.0), "field": "damage_type_id", "label": "empty damage type"},
		{"component": component_script.call("create", &"missing", 7.0, 11.0), "field": "damage_type_id", "label": "unknown damage type"},
		{"component": component_script.call("create", &"physical", NAN, 11.0), "field": "minimum_damage", "label": "nonfinite minimum"},
		{"component": component_script.call("create", &"physical", 7.0, INF), "field": "maximum_damage", "label": "nonfinite maximum"},
		{"component": component_script.call("create", &"physical", -0.01, 11.0), "field": "minimum_damage", "label": "negative minimum"},
		{"component": component_script.call("create", &"physical", 7.0, -0.01), "field": "maximum_damage", "label": "negative maximum"},
		{"component": component_script.call("create", &"physical", 12.0, 11.0), "field": "minimum_damage", "label": "inverted range"},
	]
	for test_case: Dictionary in cases:
		var error := str((test_case["component"] as RefCounted).call("validate", GameCatalog.DAMAGE_TYPES))
		TestAssertions.truthy(not error.is_empty(), "%s is rejected" % test_case["label"], failures)
		TestAssertions.truthy(error.contains("field=%s" % test_case["field"]), "%s identifies its field" % test_case["label"], failures)

	var missing_component: RefCounted = component_script.call("create", &"physical", 7.0, 11.0)
	var missing_catalog := str(missing_component.call("validate", null))
	TestAssertions.truthy(not missing_catalog.is_empty() and missing_catalog.contains("field=damage_type_id"), "missing damage catalog rejects validation", failures)
