extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_normalized_base_tags_and_validation(failures)
	_test_weight_policy(failures)
	_test_base_selection_soft_bias_and_stability(failures)
	_test_base_selection_hard_filters(failures)
	_test_forced_base_rejections(failures)
	_test_tempered_edge_is_limited_to_forge_vanguard_sword(failures)
	return failures

func _test_normalized_base_tags_and_validation(failures: Array[String]) -> void:
	var base := _base(&"normalized", [&"melee", &"bonus"])
	base.required_all_tags = [&"martial"]
	base.required_any_tags = [&"vanguard", &"melee"]
	var expected_tags: Array[StringName] = [&"bonus", &"main_hand", &"martial", &"melee", &"one_hand_sword", &"vanguard", &"weapon"]
	expected_tags.sort()
	TestAssertions.equal(
		base.normalized_generation_tags(),
		expected_tags,
		"generation tags are a sorted unique union of explicit, eligibility, and type tags",
		failures
	)
	TestAssertions.equal(base.generation_tags, [&"melee", &"bonus"], "normalization does not mutate authored tags", failures)

	var global := _base(&"global")
	TestAssertions.truthy(&"global" in global.normalized_generation_tags(), "unrestricted bases gain the global tag", failures)

	var invalid := _base(&"invalid")
	invalid.generation_weight = INF
	TestAssertions.truthy(_has_diagnostic(invalid.validate(), "generation weight must be finite and positive"), "nonfinite generation weight fails", failures)
	invalid.generation_weight = 0.0
	TestAssertions.truthy(_has_diagnostic(invalid.validate(), "generation weight must be finite and positive"), "nonpositive generation weight fails", failures)
	invalid.generation_weight = 100.0
	invalid.generation_tags = [&""]
	TestAssertions.truthy(_has_diagnostic(invalid.validate(), "generation tag is empty"), "empty explicit generation tag fails", failures)
	invalid.generation_tags = [&"melee", &"melee"]
	TestAssertions.truthy(_has_diagnostic(invalid.validate(), "duplicate generation tag melee"), "duplicate explicit generation tag fails", failures)
	invalid.generation_tags = []
	invalid.implicit_affix_ids = [&"tempered_edge", &"tempered_edge"]
	TestAssertions.truthy(_has_diagnostic(invalid.validate(), "duplicate implicit affix tempered_edge"), "duplicate implicit affix id fails", failures)
	invalid.implicit_affix_ids = []
	invalid.generation_tags = [&"melee"]
	invalid.excluded_tags = [&"melee"]
	TestAssertions.truthy(_has_diagnostic(invalid.validate(), "generation tag melee is excluded"), "normalized generation and excluded tags cannot overlap", failures)

func _test_weight_policy(failures: Array[String]) -> void:
	var request := _request()
	request.party_archetype_tags = [&"melee"]
	var melee := _base(&"melee_base", [&"melee"])
	var caster := _base(&"caster_base", [&"caster"])
	var global := _base(&"global_base")
	TestAssertions.equal(ItemGenerationWeightPolicy.base_weight(melee, request), 300.0, "matching party tag applies exact 3.0 multiplier", failures)
	TestAssertions.equal(ItemGenerationWeightPolicy.base_weight(global, request), 100.0, "global base weight remains unchanged", failures)
	TestAssertions.truthy(ItemGenerationWeightPolicy.base_weight(caster, request) > 0.0, "off-party base weight remains positive", failures)
	TestAssertions.equal(ItemGenerationWeightPolicy.progress(1), 0.0, "item level one starts at zero progress", failures)
	TestAssertions.equal(ItemGenerationWeightPolicy.progress(1000), 1.0, "item level one thousand reaches full progress", failures)
	TestAssertions.equal(ItemGenerationWeightPolicy.progress(2000), 1.0, "item progress clamps above the supported range", failures)
	TestAssertions.equal(ItemGenerationWeightPolicy.diminishing_charisma(-10.0), 0.0, "negative charisma has no weight influence", failures)
	TestAssertions.equal(ItemGenerationWeightPolicy.diminishing_charisma(100.0), 0.5, "charisma uses the exact diminishing curve", failures)

	request.item_level = 1000
	request.heat = 10.0
	request.charisma_value = 100.0
	var rarity := ItemRarityDefinition.new()
	rarity.rarity_rank = 3
	rarity.base_weight = 20.0
	TestAssertions.near(ItemGenerationWeightPolicy.rarity_weight(rarity, request), 31.2, 0.00001, "rarity weight uses exact progress and Heat factors", failures)
	var affix := ItemAffixDefinition.new()
	affix.base_weight = 100.0
	TestAssertions.near(ItemGenerationWeightPolicy.affix_weight(affix, request), 186.34375, 0.00001, "affix weight uses exact scarcity and Charisma factors", failures)
	var tier := ItemAffixTierDefinition.new()
	tier.tier = 4
	tier.base_weight = 50.0
	TestAssertions.near(ItemGenerationWeightPolicy.tier_weight(tier, request), 80.0, 0.00001, "tier weight uses exact progress factor", failures)
	TestAssertions.near(ItemGenerationWeightPolicy.roll_quality(0.5, 100.0), 0.541497215, 0.00001, "roll quality uses exact Charisma exponent", failures)

func _test_base_selection_soft_bias_and_stability(failures: Array[String]) -> void:
	var melee := _base(&"melee_base", [&"melee"])
	var caster := _base(&"caster_base", [&"caster"])
	var global := _base(&"global_base")
	var equipment := _catalog([global, caster, melee])
	var request := _request()
	request.party_archetype_tags = [&"melee"]
	var first_trace := ItemGenerationTrace.new()
	var first := ItemBaseSelector.select(request, equipment, first_trace)
	var second_trace := ItemGenerationTrace.new()
	var second := ItemBaseSelector.select(request, _catalog([melee, global, caster]), second_trace)
	TestAssertions.truthy(first != null, "soft-biased selection returns a base", failures)
	TestAssertions.truthy(second != null, "reordered catalog selection returns a base", failures)
	if first != null and second != null:
		TestAssertions.equal(first.id, second.id, "same request is stable across catalog ordering", failures)
	TestAssertions.equal(first_trace.stages, second_trace.stages, "repeated selection records stable trace evidence", failures)
	if not first_trace.stages.is_empty():
		var stage := first_trace.stages[0]
		TestAssertions.equal(stage["stage"], "base", "base selector records the base stage", failures)
		TestAssertions.equal(stage["eligible"], ["caster_base", "global_base", "melee_base"], "all soft-biased bases remain eligible", failures)
		TestAssertions.equal(stage["weights"], {"caster_base": 100.0, "global_base": 100.0, "melee_base": 300.0}, "trace records exact soft-bias weights", failures)

func _test_base_selection_hard_filters(failures: Array[String]) -> void:
	var melee := _base(&"melee_base", [&"melee"])
	var caster := _base(&"caster_base", [&"caster"])
	var global := _base(&"global_base")
	var invalid := _base(&"invalid_base", [&"melee"])
	invalid.generation_weight = NAN
	var equipment := _catalog([global, caster, melee, invalid])
	var request := _request()
	request.required_base_tags = [&"melee"]
	var trace := ItemGenerationTrace.new()
	var selected := ItemBaseSelector.select(request, equipment, trace)
	TestAssertions.truthy(selected != null and selected.id == &"melee_base", "required tags hard-filter before weighting", failures)
	if not trace.stages.is_empty():
		var rejected := (trace.stages[0] as Dictionary)["rejected"] as Dictionary
		TestAssertions.equal(rejected["caster_base"], "missing_required_tag", "missing required tag uses stable rejection code", failures)
		TestAssertions.equal(rejected["global_base"], "missing_required_tag", "global base cannot bypass a required tag", failures)
		TestAssertions.equal(rejected["invalid_base"], "invalid_weight", "invalid surviving weight uses stable rejection code", failures)

	request = _request()
	request.excluded_base_tags = [&"melee"]
	trace = ItemGenerationTrace.new()
	selected = ItemBaseSelector.select(request, equipment, trace)
	TestAssertions.truthy(selected != null and selected.id != &"melee_base", "excluded tags hard-filter before weighting", failures)
	if not trace.stages.is_empty():
		var rejected := (trace.stages[0] as Dictionary)["rejected"] as Dictionary
		TestAssertions.equal(rejected["melee_base"], "excluded_tag", "excluded tag uses stable rejection code", failures)

func _test_forced_base_rejections(failures: Array[String]) -> void:
	var melee := _base(&"melee_base", [&"melee"])
	var caster := _base(&"caster_base", [&"caster"])
	var equipment := _catalog([melee, caster])
	var request := _request()
	request.forced_base_id = &"unknown_base"
	var trace := ItemGenerationTrace.new()
	TestAssertions.equal(ItemBaseSelector.select(request, equipment, trace), null, "unknown forced base returns null", failures)
	if not trace.stages.is_empty():
		TestAssertions.equal((trace.stages[0] as Dictionary)["rejected"], {"unknown_base": "unknown_forced_base"}, "unknown forced base uses stable rejection code", failures)

	request = _request()
	request.forced_base_id = &"caster_base"
	request.required_base_tags = [&"melee"]
	trace = ItemGenerationTrace.new()
	TestAssertions.equal(ItemBaseSelector.select(request, equipment, trace), null, "filtered forced base returns null", failures)
	if not trace.stages.is_empty():
		TestAssertions.equal((trace.stages[0] as Dictionary)["rejected"], {"caster_base": "missing_required_tag"}, "filtered forced base preserves the hard-filter code", failures)

func _test_tempered_edge_is_limited_to_forge_vanguard_sword(failures: Array[String]) -> void:
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var containing: Array[StringName] = []
	for base: EquipmentBaseDefinition in equipment.definitions:
		if base != null and &"tempered_edge" in base.implicit_affix_ids:
			containing.append(base.id)
	TestAssertions.equal(containing, [&"forge_vanguard_sword"], "tempered_edge is authored only on the Forge Vanguard sword", failures)

func _request() -> ItemGenerationRequest:
	return ItemGenerationRequest.create(991, 4, 250, &"ordinary_enemy", &"ordinary_drop", [&"common"])

func _catalog(definitions: Array[EquipmentBaseDefinition]) -> EquipmentCatalog:
	var catalog := EquipmentCatalog.new()
	catalog.definitions = definitions
	return catalog

func _base(id: StringName, tags: Array[StringName] = []) -> EquipmentBaseDefinition:
	var base := EquipmentBaseDefinition.new()
	base.id = id
	base.display_name = String(id)
	base.item_type_id = &"main_hand"
	base.compatible_slot_ids = [&"main_hand"]
	base.weight_class_id = &"weapon"
	base.weapon_family_id = &"one_hand_sword"
	base.implicit_family_id = &"test"
	base.generation_tags = tags.duplicate()
	var presentation := EquipmentVisualDefinition.new()
	presentation.id = id
	presentation.slot_id = &"main_hand"
	presentation.geometry_key = &"test"
	base.presentation = presentation
	return base

func _has_diagnostic(errors: PackedStringArray, expected: String) -> bool:
	return expected in "\n".join(errors)
