extends RefCounted

const CURVE_PATH := "res://scripts/items/weapon_damage_component_curve.gd"
const PROFILE_PATH := "res://scripts/items/weapon_damage_profile.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(CURVE_PATH), "weapon damage curve contract exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(PROFILE_PATH), "weapon damage profile contract exists", failures)
	if not ResourceLoader.exists(CURVE_PATH) or not ResourceLoader.exists(PROFILE_PATH):
		return failures
	_test_curve_interpolation(failures)
	_test_exact_rarity_and_quality_policy(failures)
	_test_profile_validation(failures)
	return failures

func _test_curve_interpolation(failures: Array[String]) -> void:
	var curve := _new_curve()
	curve.damage_type_id = &"physical"
	curve.minimum_at_level_1 = 1.0
	curve.maximum_at_level_1 = 2.0
	curve.minimum_at_level_1000 = 1000.0
	curve.maximum_at_level_1000 = 2000.0
	TestAssertions.equal(curve.call(&"range_at", 1), Vector2(1.0, 2.0), "level 1 uses the first exact anchors", failures)
	TestAssertions.equal(curve.call(&"range_at", 500), Vector2(500.0, 1000.0), "level 500 interpolates over the exact 1..1000 span", failures)
	TestAssertions.equal(curve.call(&"range_at", 1000), Vector2(1000.0, 2000.0), "level 1000 uses the final exact anchors", failures)

func _test_exact_rarity_and_quality_policy(failures: Array[String]) -> void:
	var profile := _valid_profile(&"rarity_policy")
	TestAssertions.equal(profile.get(&"quality_minimum"), 0.85, "quality minimum is exactly 0.85", failures)
	TestAssertions.equal(profile.get(&"quality_maximum"), 1.00, "quality maximum is exactly 1.00", failures)
	var expected := {
		&"common": 1.00,
		&"uncommon": 1.08,
		&"rare": 1.18,
		&"epic": 1.32,
		&"legendary": 1.50,
	}
	for rarity_id: StringName in expected:
		TestAssertions.equal(profile.call(&"rarity_multiplier", rarity_id), expected[rarity_id], "%s rarity multiplier is exact" % rarity_id, failures)
	TestAssertions.equal(profile.call(&"rarity_multiplier", &"missing"), 0.0, "unknown rarity fails closed", failures)

	profile.set(&"quality_minimum", 0.86)
	TestAssertions.truthy(_contains(profile.call(&"validate", GameCatalog.DAMAGE_TYPES), "quality bounds must be exactly 0.85..1.00"), "altered quality minimum is rejected", failures)
	profile.set(&"quality_minimum", 0.85)
	profile.set(&"quality_maximum", 0.99)
	TestAssertions.truthy(_contains(profile.call(&"validate", GameCatalog.DAMAGE_TYPES), "quality bounds must be exactly 0.85..1.00"), "altered quality maximum is rejected", failures)

func _test_profile_validation(failures: Array[String]) -> void:
	var valid := _valid_profile(&"valid_profile")
	TestAssertions.equal(valid.call(&"validate", GameCatalog.DAMAGE_TYPES), PackedStringArray(), "finite monotonic registered profile validates", failures)

	var duplicate := _valid_profile(&"duplicate_profile")
	(duplicate.get(&"components") as Array).append(_curve(&"physical", 3.0, 5.0, 30.0, 50.0))
	TestAssertions.truthy(_contains(duplicate.call(&"validate", GameCatalog.DAMAGE_TYPES), "duplicate damage type physical"), "duplicate damage types are rejected", failures)

	var malformed_cases: Array[Dictionary] = [
		{"field": &"minimum_at_level_1", "value": NAN, "error": "minimum_at_level_1 must be finite", "label": "nonfinite level 1 minimum"},
		{"field": &"maximum_at_level_1", "value": INF, "error": "maximum_at_level_1 must be finite", "label": "nonfinite level 1 maximum"},
		{"field": &"minimum_at_level_1000", "value": NAN, "error": "minimum_at_level_1000 must be finite", "label": "nonfinite level 1000 minimum"},
		{"field": &"maximum_at_level_1000", "value": INF, "error": "maximum_at_level_1000 must be finite", "label": "nonfinite level 1000 maximum"},
		{"field": &"maximum_at_level_1", "value": 9.0, "error": "level 1 range is inverted", "label": "inverted level 1 range"},
		{"field": &"maximum_at_level_1000", "value": 99.0, "error": "level 1000 range is inverted", "label": "inverted level 1000 range"},
		{"field": &"minimum_at_level_1000", "value": 9.0, "error": "minimum anchors must be monotonic", "label": "decreasing minimum anchors"},
		{"field": &"maximum_at_level_1000", "value": 19.0, "error": "maximum anchors must be monotonic", "label": "decreasing maximum anchors"},
	]
	for test_case: Dictionary in malformed_cases:
		var profile := _valid_profile(StringName("malformed_%s" % test_case["field"]))
		(profile.get(&"components") as Array)[0].set(test_case["field"], test_case["value"])
		TestAssertions.truthy(_contains(profile.call(&"validate", GameCatalog.DAMAGE_TYPES), test_case["error"]), "%s is rejected" % test_case["label"], failures)

	var unknown := _valid_profile(&"unknown_type_profile")
	(unknown.get(&"components") as Array)[0].set(&"damage_type_id", &"radiant")
	TestAssertions.truthy(_contains(unknown.call(&"validate", GameCatalog.DAMAGE_TYPES), "unknown damage type radiant"), "unregistered damage type is rejected", failures)
	TestAssertions.truthy(_contains(valid.call(&"validate", null), "damage type catalog is missing"), "missing damage catalog is rejected", failures)

	var no_components := _new_profile()
	no_components.set(&"id", &"empty_profile")
	TestAssertions.truthy(_contains(no_components.call(&"validate", GameCatalog.DAMAGE_TYPES), "requires at least one component"), "profile without components is rejected", failures)

func _valid_profile(profile_id: StringName) -> Resource:
	var profile := _new_profile()
	profile.set(&"id", profile_id)
	profile.set(&"minimum_item_level", 1)
	profile.set(&"quality_minimum", 0.85)
	profile.set(&"quality_maximum", 1.00)
	(profile.get(&"components") as Array).append(_curve(&"physical", 10.0, 20.0, 100.0, 200.0))
	return profile

func _curve(type_id: StringName, minimum_1: float, maximum_1: float, minimum_1000: float, maximum_1000: float) -> Resource:
	var curve := _new_curve()
	curve.set(&"damage_type_id", type_id)
	curve.set(&"minimum_at_level_1", minimum_1)
	curve.set(&"maximum_at_level_1", maximum_1)
	curve.set(&"minimum_at_level_1000", minimum_1000)
	curve.set(&"maximum_at_level_1000", maximum_1000)
	return curve

func _new_profile() -> Resource:
	return (load(PROFILE_PATH) as Script).new() as Resource

func _new_curve() -> Resource:
	return (load(CURVE_PATH) as Script).new() as Resource

func _contains(errors: PackedStringArray, fragment: String) -> bool:
	return Array(errors).any(func(error: String) -> bool: return fragment in error)
