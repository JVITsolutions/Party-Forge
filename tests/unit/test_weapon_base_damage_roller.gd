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
	_test_required_inputs_and_unknown_rarity_reject(failures)
	_test_malformed_profiles_reject_before_rolling(failures)
	_test_runtime_roll_values_fail_closed(failures)
	_test_strict_canonical_snapshot_and_real_defensive_copies(failures)
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
	TestAssertions.equal(_component_evidence_without_random(provenance_components), ItemGenerationTrace.canonical_json_copy(_component_evidence_without_random(expected_provenance["components"] as Array)), "roller provenance stores sorted bounds and final ranges", failures)
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

func _test_required_inputs_and_unknown_rarity_reject(failures: Array[String]) -> void:
	var request := ItemGenerationRequest.create(991, 4, 500, &"roller_test", &"ordinary_drop", [&"rare"])
	var base := EquipmentBaseDefinition.new()
	base.id = &"input_blade"
	base.weapon_damage_profile = _profile(&"input_profile", 1, [_curve(&"physical", 10.0, 20.0)])
	var rarity := _rarity(&"rare")
	_assert_input_rejection(null, base, rarity, ItemGenerationTrace.new(), "request", "missing", failures)
	_assert_input_rejection(request, null, rarity, ItemGenerationTrace.new(), "base", "missing", failures)
	_assert_input_rejection(request, base, null, ItemGenerationTrace.new(), "rarity", "missing", failures)
	var missing_trace := _roll(request, base, rarity, null)
	_assert_empty_failure(missing_trace, "PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage field=trace reason=missing", "missing trace", failures)

	var unknown_rarity := _rarity(&"mythic")
	var profiled_trace := ItemGenerationTrace.new()
	var profiled := _roll(request, base, unknown_rarity, profiled_trace)
	_assert_empty_failure(profiled, "PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage profile=input_profile field=rarity_id value=mythic reason=unsupported rarity", "profiled unknown rarity", failures)
	_assert_rejected_trace(profiled_trace, "input_profile", "unsupported_rarity", "input_profile", "rarity_id", "unsupported rarity", {"value": "mythic"}, failures)

	var support_base := EquipmentBaseDefinition.new()
	support_base.id = &"support_focus"
	var support_trace := ItemGenerationTrace.new()
	var support := _roll(request, support_base, unknown_rarity, support_trace)
	_assert_empty_failure(support, "PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage field=rarity_id value=mythic reason=unsupported rarity", "no-profile unknown rarity", failures)
	_assert_rejected_trace(support_trace, "<none>", "unsupported_rarity", "", "rarity_id", "unsupported rarity", {"value": "mythic"}, failures)

func _test_malformed_profiles_reject_before_rolling(failures: Array[String]) -> void:
	var request := ItemGenerationRequest.create(991, 4, 500, &"roller_test", &"ordinary_drop", [&"rare"])
	var rarity := _rarity(&"rare")

	var empty_id := _profile(&"", 1, [_curve(&"physical", 10.0, 20.0)])
	_assert_malformed_profile(request, rarity, empty_id, "profile.id", "must be non-empty", failures)
	var invalid_minimum := _profile(&"invalid_minimum", 0, [_curve(&"physical", 10.0, 20.0)])
	_assert_malformed_profile(request, rarity, invalid_minimum, "minimum_item_level", "must be between 1 and 1000", failures)
	var empty_components := _profile(&"empty_components", 1, [])
	_assert_malformed_profile(request, rarity, empty_components, "components", "requires at least one component", failures)

	var invalid_quality_cases := [
		{"field": &"quality_minimum", "value": NAN},
		{"field": &"quality_minimum", "value": 0.84},
		{"field": &"quality_maximum", "value": INF},
		{"field": &"quality_maximum", "value": 0.99},
	]
	for test_case: Dictionary in invalid_quality_cases:
		var profile := _profile(StringName("invalid_%s_%s" % [test_case["field"], str(test_case["value"])]), 1, [_curve(&"physical", 10.0, 20.0)])
		profile.set(test_case["field"], test_case["value"])
		_assert_malformed_profile(request, rarity, profile, "quality_bounds", "must equal 0.85..1.00", failures)

	var missing_curve := _profile(&"missing_curve", 1, [null])
	_assert_malformed_profile(request, rarity, missing_curve, "components[0]", "curve is missing", failures)
	var empty_type := _profile(&"empty_type", 1, [_curve(&"", 10.0, 20.0)])
	_assert_malformed_profile(request, rarity, empty_type, "components[0].damage_type_id", "must be non-empty", failures)
	var duplicate_type := _profile(&"duplicate_type", 1, [_curve(&"physical", 10.0, 20.0), _curve(&"physical", 30.0, 40.0)])
	_assert_malformed_profile(request, rarity, duplicate_type, "components[1].damage_type_id", "duplicate damage type physical", failures)
	var unknown_type := _profile(&"unknown_type", 1, [_curve(&"radiant", 10.0, 20.0)])
	_assert_malformed_profile(request, rarity, unknown_type, "components[0].damage_type_id", "unknown damage type radiant", failures)

	var anchor_cases := [
		{"field": &"minimum_at_level_1", "value": NAN, "reason": "must be finite"},
		{"field": &"maximum_at_level_1", "value": -1.0, "reason": "must be nonnegative"},
		{"field": &"maximum_at_level_1", "value": 5.0, "minimum": 10.0, "reason": "level 1 range is inverted"},
		{"field": &"maximum_at_level_1000", "value": 5.0, "minimum_1000": 10.0, "reason": "level 1000 range is inverted"},
		{"field": &"minimum_at_level_1000", "value": 9.0, "reason": "minimum anchors must be monotonic"},
		{"field": &"maximum_at_level_1000", "value": 19.0, "reason": "maximum anchors must be monotonic"},
	]
	for index: int in anchor_cases.size():
		var test_case := anchor_cases[index] as Dictionary
		var curve := _curve(&"physical", float(test_case.get("minimum", 10.0)), 20.0)
		curve.minimum_at_level_1000 = float(test_case.get("minimum_1000", 10.0))
		curve.maximum_at_level_1000 = 20.0
		curve.set(test_case["field"], test_case["value"])
		var profile := _profile(StringName("invalid_anchor_%d" % index), 1, [curve])
		_assert_malformed_profile(request, rarity, profile, "components[0].%s" % test_case["field"], test_case["reason"], failures)

func _test_runtime_roll_values_fail_closed(failures: Array[String]) -> void:
	var request := ItemGenerationRequest.create(991, 4, 500, &"roller_test", &"ordinary_drop", [&"legendary"])
	var base := EquipmentBaseDefinition.new()
	base.id = &"overflow_blade"
	var curve := _curve(&"physical", 1.35e308, 1.35e308)
	base.weapon_damage_profile = _profile(&"overflow_profile", 1, [curve])
	var trace := ItemGenerationTrace.new()
	var result := _roll(request, base, _rarity(&"legendary"), trace)
	_assert_empty_failure(result, "PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage profile=overflow_profile field=components.physical.bounds reason=must be finite nonnegative and ordered", "overflowed interpolated bounds", failures)
	_assert_rejected_trace(trace, "overflow_profile", "invalid_roll", "overflow_profile", "components.physical.bounds", "must be finite nonnegative and ordered", {}, failures)

func _test_strict_canonical_snapshot_and_real_defensive_copies(failures: Array[String]) -> void:
	var trace := ItemGenerationTrace.new()
	var no_ids: Array[StringName] = []
	var accepted: Variant = trace.call(&"record", &"canonical", no_ids, {}, {}, &"", {"integral": 10.0, "name": &"physical"})
	TestAssertions.equal(accepted, true, "trace reports accepted canonical evidence", failures)
	TestAssertions.equal(trace.stages[0]["details"], {"integral": 10, "name": "physical"}, "trace canonicalizes integral floats and StringNames once", failures)
	TestAssertions.equal(typeof(trace.stages[0]["details"]["integral"]), TYPE_INT, "canonical integral is stored as an integer", failures)
	var baseline := trace.stages
	TestAssertions.equal(trace.call(&"record", &"unsupported", no_ids, {}, {}, &"", {"bad": NodePath("unsupported")}), false, "trace rejects unsupported variants", failures)
	TestAssertions.equal(trace.call(&"record", &"unsafe", no_ids, {}, {}, &"", {"bad": ItemInstanceCodec.JSON_SAFE_INTEGER_MAX + 1}), false, "trace rejects unsafe integers", failures)
	TestAssertions.equal(trace.call(&"record", &"nonfinite", no_ids, {}, {}, &"", {"bad": INF}), false, "trace rejects nonfinite details", failures)
	TestAssertions.equal(trace.stages, baseline, "strict trace rejection never mutates recorded evidence", failures)

	var base := EquipmentBaseDefinition.new()
	base.id = &"canonical_blade"
	base.weapon_damage_profile = _profile(&"canonical_profile", 1, [_curve(&"physical", 10.0, 20.0)])
	var request := ItemGenerationRequest.create(991, 4, 500, &"roller_test", &"ordinary_drop", [&"rare"])
	var roll_trace := ItemGenerationTrace.new()
	var result := _roll(request, base, _rarity(&"rare"), roll_trace)
	TestAssertions.truthy(result != null and bool(result.call(&"ok")), "canonical roll succeeds", failures)
	if result == null or not bool(result.call(&"ok")):
		return
	var expected := result.get(&"provenance").duplicate(true) as Dictionary
	var trace_details := roll_trace.stages[0]["details"] as Dictionary
	TestAssertions.equal(trace_details, expected, "roll result and trace use one exact canonical provenance", failures)
	TestAssertions.equal(typeof(((expected["components"] as Array)[0]["bounds"] as Dictionary)["minimum"]), TYPE_INT, "roll-result integral bounds use canonical integer representation", failures)
	var equipment := load("res://data/equipment/core_equipment_catalog.tres") as EquipmentCatalog
	var foundation := load("res://data/items/core_item_foundation_catalog.tres") as ItemFoundationCatalog
	var issued := ItemInstanceIssuer.issue(
		"base-damage-copy-test", 1, {"generation": {"base_damage": result.get(&"provenance")}}, request.seed,
		{"affixes": [], "base_definition_id": "forge_vanguard_sword", "base_damage_components": result.get(&"components"), "item_level": 500, "rarity_id": "rare"},
		equipment, foundation
	)
	TestAssertions.truthy(issued.ok(), "canonical provenance fixture issues", failures)
	if not issued.ok():
		return
	var issued_provenance := issued.item.origin["source"]["generation"]["base_damage"] as Dictionary
	TestAssertions.equal(issued_provenance, expected, "issued provenance exactly matches result and trace representation", failures)

	((result.get(&"provenance")["components"] as Array)[0] as Dictionary)["quality"] = -1.0
	TestAssertions.equal(roll_trace.stages[0]["details"], expected, "mutating actual result provenance cannot rewrite trace details", failures)
	TestAssertions.equal(issued.item.origin["source"]["generation"]["base_damage"], expected, "mutating actual result provenance cannot rewrite issued provenance", failures)
	var exposed_trace := roll_trace.stages
	(((exposed_trace[0] as Dictionary)["details"]["components"] as Array)[0] as Dictionary)["quality"] = -2.0
	TestAssertions.equal(float(((result.get(&"provenance")["components"] as Array)[0] as Dictionary)["quality"]), -1.0, "mutating exposed trace copy cannot rewrite result provenance", failures)
	TestAssertions.equal(issued.item.origin["source"]["generation"]["base_damage"], expected, "mutating exposed trace copy cannot rewrite issued provenance", failures)

func _assert_input_rejection(
	request: ItemGenerationRequest,
	base: EquipmentBaseDefinition,
	rarity: ItemRarityDefinition,
	trace: ItemGenerationTrace,
	field: String,
	reason: String,
	failures: Array[String]
) -> void:
	var result := _roll(request, base, rarity, trace)
	_assert_empty_failure(result, "PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage field=%s reason=%s" % [field, reason], "missing %s" % field, failures)
	_assert_rejected_trace(trace, "<%s>" % field, "missing_%s" % field, "", field, reason, {}, failures)

func _assert_malformed_profile(
	request: ItemGenerationRequest,
	rarity: ItemRarityDefinition,
	profile: WeaponDamageProfile,
	field: String,
	reason: String,
	failures: Array[String]
) -> void:
	var base := EquipmentBaseDefinition.new()
	base.id = &"malformed_blade"
	base.weapon_damage_profile = profile
	var trace := ItemGenerationTrace.new()
	var result := _roll(request, base, rarity, trace)
	var profile_id := String(profile.id) if not profile.id.is_empty() else "<empty>"
	_assert_empty_failure(result, "PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage profile=%s field=%s reason=%s" % [profile_id, field, reason], "%s malformed profile" % field, failures)
	_assert_rejected_trace(trace, profile_id, "invalid_profile", String(profile.id), field, reason, {}, failures)

func _assert_empty_failure(result: RefCounted, expected_error: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(result != null and not bool(result.call(&"ok")), "%s rejects" % label, failures)
	if result == null:
		return
	TestAssertions.equal(result.get(&"components"), [], "%s returns no partial components" % label, failures)
	TestAssertions.equal(result.get(&"quality_by_type"), {}, "%s returns no partial quality" % label, failures)
	TestAssertions.equal(result.get(&"provenance"), {}, "%s returns no partial provenance" % label, failures)
	TestAssertions.equal(result.get(&"error"), expected_error, "%s diagnostic is stable" % label, failures)

func _assert_rejected_trace(
	trace: ItemGenerationTrace,
	rejected_id: String,
	rejected_code: String,
	profile_id: String,
	field: String,
	reason: String,
	extra_details: Dictionary,
	failures: Array[String]
) -> void:
	var details := {"field": field, "outcome": "rejected", "profile_id": profile_id, "reason": reason}
	for key: Variant in extra_details:
		details[key] = extra_details[key]
	TestAssertions.equal(trace.stages, [{
		"stage": "base_damage", "eligible": [], "rejected": {rejected_id: rejected_code}, "weights": {}, "selected": "", "details": details,
	}], "%s rejection trace is exact" % field, failures)
	TestAssertions.truthy(_is_json_value(trace.stages), "%s rejection trace is finite JSON" % field, failures)

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
