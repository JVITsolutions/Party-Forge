extends RefCounted

const ROLLER_PATH := "res://scripts/items/weapon_base_damage_roller.gd"
const RESULT_PATH := "res://scripts/items/weapon_base_damage_roll_result.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(ROLLER_PATH), "weapon base damage roller exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(RESULT_PATH), "weapon base damage roll result exists", failures)
	if not ResourceLoader.exists(ROLLER_PATH) or not ResourceLoader.exists(RESULT_PATH):
		return failures
	_test_fixed_named_substreams_and_rarity_scale(failures)
	_test_non_damage_base_is_an_explicit_empty_success(failures)
	_test_profile_request_failure_is_stable(failures)
	return failures

func _test_fixed_named_substreams_and_rarity_scale(failures: Array[String]) -> void:
	var base := EquipmentBaseDefinition.new()
	base.id = &"hybrid_blade"
	base.weapon_damage_profile = _profile(&"hybrid_profile", 1, [
		_curve(&"physical", 30.0, 40.0),
		_curve(&"fire", 10.0, 20.0),
	])
	var request := ItemGenerationRequest.create(991, 4, 500, &"roller_test", &"ordinary_drop", [&"common", &"rare"])
	var rare := _rarity(&"rare")
	var trace := ItemGenerationTrace.new()
	var result := _roll(request, base, rare, trace)
	TestAssertions.truthy(result != null and bool(result.call(&"ok")), "valid hybrid profile rolls successfully", failures)
	if result == null or not bool(result.call(&"ok")):
		return
	var expected_components := [
		{"damage_type_id": "fire", "minimum_damage": 10.96, "maximum_damage": 21.91},
		{"damage_type_id": "physical", "minimum_damage": 32.02, "maximum_damage": 42.70},
	]
	var expected_quality := {
		"fire": 0.92844741642475,
		"physical": 0.90460618138313,
	}
	var expected_provenance := {
		"profile_id": "hybrid_profile",
		"item_level": 500,
		"rarity_multiplier": 1.18,
		"components": [
			{
				"damage_type_id": "fire",
				"bounds": {"minimum": 10.0, "maximum": 20.0},
				"unit": 0.52298277616501,
				"quality": 0.92844741642475,
				"range": {"minimum": 10.96, "maximum": 21.91},
			},
			{
				"damage_type_id": "physical",
				"bounds": {"minimum": 30.0, "maximum": 40.0},
				"unit": 0.36404120922089,
				"quality": 0.90460618138313,
				"range": {"minimum": 32.02, "maximum": 42.70},
			},
		],
	}
	TestAssertions.equal(result.get(&"components"), expected_components, "hybrid components are sorted and use exact rare multiplication", failures)
	var quality_by_type := result.get(&"quality_by_type") as Dictionary
	TestAssertions.equal(quality_by_type.keys(), ["fire", "physical"], "hybrid quality map follows sorted damage types", failures)
	TestAssertions.near(float(quality_by_type["fire"]), float(expected_quality["fire"]), 0.00000000000001, "fixed seed and sequence produce exact fire quality", failures)
	TestAssertions.near(float(quality_by_type["physical"]), float(expected_quality["physical"]), 0.00000000000001, "fixed seed and sequence produce exact physical quality", failures)
	var provenance := result.get(&"provenance") as Dictionary
	TestAssertions.equal(provenance["profile_id"], expected_provenance["profile_id"], "roller provenance stores the profile id", failures)
	TestAssertions.equal(provenance["item_level"], expected_provenance["item_level"], "roller provenance stores the item level", failures)
	TestAssertions.equal(provenance["rarity_multiplier"], expected_provenance["rarity_multiplier"], "roller provenance stores the exact rarity multiplier", failures)
	var provenance_components := provenance["components"] as Array
	TestAssertions.equal(_component_evidence_without_random(provenance_components), _component_evidence_without_random(expected_provenance["components"] as Array), "roller provenance stores sorted bounds and final ranges", failures)
	for index: int in provenance_components.size():
		TestAssertions.near(float(provenance_components[index]["unit"]), float((expected_provenance["components"] as Array)[index]["unit"]), 0.00000000000001, "component %d stores its fixed unit" % index, failures)
		TestAssertions.near(float(provenance_components[index]["quality"]), float((expected_provenance["components"] as Array)[index]["quality"]), 0.00000000000001, "component %d stores its fixed quality" % index, failures)
	var recorded_stage := trace.stages[0]
	TestAssertions.equal(_stage_without_details(recorded_stage), {
		"stage": "base_damage", "eligible": ["fire", "physical"], "rejected": {}, "weights": {}, "selected": "hybrid_profile",
	}, "base damage trace records the named stage and sorted types", failures)
	TestAssertions.equal(recorded_stage["details"], provenance, "trace and result retain the same canonical base-damage evidence", failures)
	TestAssertions.truthy(_is_json_value(trace.stages), "base damage trace details are JSON-safe", failures)

	var common_trace := ItemGenerationTrace.new()
	var common_result := _roll(request, base, _rarity(&"common"), common_trace)
	TestAssertions.truthy(common_result != null and bool(common_result.call(&"ok")), "common profile roll succeeds", failures)
	if common_result != null and bool(common_result.call(&"ok")):
		TestAssertions.equal(common_result.get(&"quality_by_type"), result.get(&"quality_by_type"), "rarity cannot shift named quality substreams", failures)
		TestAssertions.equal(common_result.get(&"components"), [
			{"damage_type_id": "fire", "minimum_damage": 9.28, "maximum_damage": 18.57},
			{"damage_type_id": "physical", "minimum_damage": 27.14, "maximum_damage": 36.18},
		], "common output applies the exact 1.00 rarity multiplier", failures)

	(expected_provenance["components"] as Array)[0]["quality"] = -1.0
	TestAssertions.near(float((trace.stages[0]["details"]["components"] as Array)[0]["quality"]), 0.92844741642475, 0.00000000000001, "trace owns a deep canonical details copy", failures)

func _test_non_damage_base_is_an_explicit_empty_success(failures: Array[String]) -> void:
	var base := EquipmentBaseDefinition.new()
	base.id = &"support_focus"
	var request := ItemGenerationRequest.create(991, 4, 500, &"roller_test", &"ordinary_drop", [&"rare"])
	var trace := ItemGenerationTrace.new()
	var result := _roll(request, base, _rarity(&"rare"), trace)
	TestAssertions.truthy(result != null and bool(result.call(&"ok")), "base without explicit damage profile succeeds", failures)
	if result == null or not bool(result.call(&"ok")):
		return
	var expected_provenance := {
		"profile_id": "",
		"item_level": 500,
		"rarity_multiplier": 1.18,
		"components": [],
		"outcome": "no_profile",
	}
	TestAssertions.equal(result.get(&"components"), [], "non-damage base rolls no components", failures)
	TestAssertions.equal(result.get(&"quality_by_type"), {}, "non-damage base rolls no quality", failures)
	TestAssertions.equal(result.get(&"provenance"), expected_provenance, "non-damage result explains its no-profile outcome", failures)
	TestAssertions.equal(trace.stages, [{
		"stage": "base_damage", "eligible": [], "rejected": {}, "weights": {}, "selected": "", "details": expected_provenance,
	}], "non-damage trace records the named stage explicitly", failures)

func _test_profile_request_failure_is_stable(failures: Array[String]) -> void:
	var base := EquipmentBaseDefinition.new()
	base.id = &"gated_blade"
	base.weapon_damage_profile = _profile(&"gated_profile", 501, [_curve(&"physical", 30.0, 40.0)])
	var request := ItemGenerationRequest.create(991, 4, 500, &"roller_test", &"ordinary_drop", [&"rare"])
	var trace := ItemGenerationTrace.new()
	var result := _roll(request, base, _rarity(&"rare"), trace)
	TestAssertions.truthy(result != null and not bool(result.call(&"ok")), "profile minimum item level rejects the request", failures)
	if result == null:
		return
	TestAssertions.equal(result.get(&"components"), [], "failed roll exposes no partial components", failures)
	TestAssertions.equal(result.get(&"quality_by_type"), {}, "failed roll exposes no partial quality", failures)
	TestAssertions.equal(
		result.get(&"error"),
		"PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage profile=gated_profile field=item_level value=500 reason=below minimum 501",
		"profile request rejection has a stable diagnostic",
		failures
	)
	TestAssertions.equal(trace.stages, [{
		"stage": "base_damage",
		"eligible": [],
		"rejected": {"gated_profile": "item_level_below_minimum"},
		"weights": {},
		"selected": "",
		"details": {"profile_id": "gated_profile", "item_level": 500, "minimum_item_level": 501, "outcome": "rejected"},
	}], "rejected profile still records one stable base-damage trace row", failures)

func _roll(request: ItemGenerationRequest, base: EquipmentBaseDefinition, rarity: ItemRarityDefinition, trace: ItemGenerationTrace) -> RefCounted:
	return (load(ROLLER_PATH) as Script).call(&"roll", request, base, rarity, trace) as RefCounted

func _profile(profile_id: StringName, minimum_item_level: int, curves: Array[WeaponDamageComponentCurve]) -> WeaponDamageProfile:
	var profile := WeaponDamageProfile.new()
	profile.id = profile_id
	profile.minimum_item_level = minimum_item_level
	profile.components = curves
	return profile

func _curve(damage_type_id: StringName, minimum: float, maximum: float) -> WeaponDamageComponentCurve:
	var curve := WeaponDamageComponentCurve.new()
	curve.damage_type_id = damage_type_id
	curve.minimum_at_level_1 = minimum
	curve.maximum_at_level_1 = maximum
	curve.minimum_at_level_1000 = minimum
	curve.maximum_at_level_1000 = maximum
	return curve

func _rarity(rarity_id: StringName) -> ItemRarityDefinition:
	var rarity := ItemRarityDefinition.new()
	rarity.id = rarity_id
	return rarity

func _is_json_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return typeof(value) != TYPE_FLOAT or is_finite(float(value))
		TYPE_ARRAY:
			return (value as Array).all(func(entry: Variant) -> bool: return _is_json_value(entry))
		TYPE_DICTIONARY:
			for key: Variant in value as Dictionary:
				if typeof(key) != TYPE_STRING or not _is_json_value((value as Dictionary)[key]):
					return false
			return true
	return false

func _component_evidence_without_random(components: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for component: Dictionary in components:
		result.append({
			"damage_type_id": component["damage_type_id"],
			"bounds": component["bounds"],
			"range": component["range"],
		})
	return result

func _stage_without_details(stage: Dictionary) -> Dictionary:
	var result := stage.duplicate(true)
	result.erase("details")
	return result
