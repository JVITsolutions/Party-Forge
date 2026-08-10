extends RefCounted

const LIVE_SET_ARCHETYPES := {
	"dawn_bulwark": &"melee",
	"forge_vanguard": &"melee",
	"nightstep": &"melee",
	"greenwood": &"ranged",
	"siege_archer": &"ranged",
	"emberweave": &"caster",
	"grave_covenant": &"caster",
	"rime_scholar": &"caster",
	"storm_chaplain": &"caster",
}

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_normalized_base_tags_and_validation(failures)
	_test_weight_policy(failures)
	_test_live_catalog_smart_loot_archetypes(failures)
	_test_base_selection_soft_bias_and_stability(failures)
	_test_base_selection_hard_filters(failures)
	_test_forced_base_rejections(failures)
	_test_tempered_edge_is_limited_to_forge_vanguard_sword(failures)
	_test_rarity_selection_authorization_and_unlocks(failures)
	_test_rarity_eligibility_order(failures)
	_test_upper_rarity_generator_gates_preserve_direct_issuance(failures)
	_test_pattern_selection_uses_exact_domain_compatible_patterns(failures)
	_test_pattern_selection_records_empty_pool(failures)
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

func _test_live_catalog_smart_loot_archetypes(failures: Array[String]) -> void:
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var normalized_union: Array[StringName] = []
	var expected_melee_ids: Array[StringName] = []
	TestAssertions.equal(equipment.definitions.size(), 99, "live smart-loot authoring covers all 99 catalogued bases", failures)
	for base: EquipmentBaseDefinition in equipment.definitions:
		if base == null:
			continue
		var set_id := base.resource_path.get_base_dir().get_file()
		var expected_tag: StringName = LIVE_SET_ARCHETYPES.get(set_id, &"")
		TestAssertions.truthy(not expected_tag.is_empty(), "%s belongs to a registered equipment-set directory" % base.id, failures)
		TestAssertions.equal(base.generation_tags, [expected_tag], "%s authors exactly its %s class identity" % [base.id, expected_tag], failures)
		if expected_tag == &"melee":
			expected_melee_ids.append(base.id)
		for tag: StringName in base.normalized_generation_tags():
			if tag not in normalized_union:
				normalized_union.append(tag)
	for required_tag: StringName in [&"melee", &"ranged", &"caster", &"global"]:
		TestAssertions.truthy(required_tag in normalized_union, "live normalized generation union includes %s" % required_tag, failures)

	var request := _request()
	request.party_archetype_tags = [&"melee"]
	var melee := equipment.definition(&"forge_vanguard_sword")
	var off_party := equipment.definition(&"greenwood_recurve_bow")
	var global_capable := equipment.definition(&"cinder_ring")
	TestAssertions.equal(ItemGenerationWeightPolicy.base_weight(melee, request), melee.generation_weight * 3.0, "representative live melee base receives exact 3.0x weight", failures)
	TestAssertions.equal(ItemGenerationWeightPolicy.base_weight(off_party, request), off_party.generation_weight, "representative off-party live base retains authored weight", failures)
	TestAssertions.truthy(ItemGenerationWeightPolicy.base_weight(off_party, request) > 0.0, "representative off-party live base remains eligible", failures)
	TestAssertions.truthy(&"global" in global_capable.normalized_generation_tags(), "unrestricted live base retains normalized global capability", failures)
	TestAssertions.equal(ItemGenerationWeightPolicy.base_weight(global_capable, request), global_capable.generation_weight, "global-capable off-party base retains authored weight", failures)
	TestAssertions.truthy(ItemGenerationWeightPolicy.base_weight(global_capable, request) > 0.0, "global-capable off-party live base remains eligible", failures)

	request = _request()
	request.required_base_tags = [&"melee"]
	TestAssertions.equal(request.validate(foundation), "", "required live melee base tag validates against the canonical manifest", failures)
	var trace := ItemGenerationTrace.new()
	var selected := ItemBaseSelector.select(request, equipment, trace)
	expected_melee_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	TestAssertions.truthy(selected != null and &"melee" in selected.normalized_generation_tags(), "required melee selection returns a live melee base", failures)
	if not trace.stages.is_empty():
		TestAssertions.equal((trace.stages[0] as Dictionary)["eligible"], Array(expected_melee_ids, TYPE_STRING, &"", null), "required melee filter exposes exactly the live melee candidates", failures)

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

func _test_rarity_selection_authorization_and_unlocks(failures: Array[String]) -> void:
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var request := _request()
	request.permitted_rarity_ids = [&"common", &"uncommon"]
	var trace := ItemGenerationTrace.new()
	var selected := ItemRaritySelector.select(request, foundation, trace)
	TestAssertions.truthy(selected != null and selected.id in request.permitted_rarity_ids, "rarity selection stays within the request-permitted pool", failures)
	if not trace.stages.is_empty():
		var stage := trace.stages[0]
		TestAssertions.equal(stage["eligible"], ["common", "uncommon"], "only permitted ordinary rarities reach weighting", failures)
		TestAssertions.equal((stage["rejected"] as Dictionary)["rare"], "not_permitted", "permission is checked before rarity unlocks", failures)

	for locked_id: StringName in [&"rare", &"epic", &"legendary"]:
		request = _request()
		request.permitted_rarity_ids = [locked_id]
		request.forced_rarity_id = locked_id
		trace = ItemGenerationTrace.new()
		TestAssertions.equal(ItemRaritySelector.select(request, foundation, trace), null, "locked forced %s cannot bypass its unlock" % locked_id, failures)
		if not trace.stages.is_empty():
			TestAssertions.equal((trace.stages[0] as Dictionary)["rejected"][String(locked_id)], "missing_unlock_tag", "locked %s records the hard unlock rejection" % locked_id, failures)

	request = _request()
	request.permitted_rarity_ids = [&"rare"]
	request.forced_rarity_id = &"rare"
	request.unlock_tags = [&"rarity_rare_unlocked"]
	trace = ItemGenerationTrace.new()
	selected = ItemRaritySelector.select(request, foundation, trace)
	TestAssertions.truthy(selected != null and selected.id == &"rare", "unlocked permitted forced Rare is selectable", failures)

func _test_rarity_eligibility_order(failures: Array[String]) -> void:
	var rarity := ItemRarityDefinition.new()
	rarity.id = &"ordered"
	rarity.instance_supported = false
	rarity.ordinary_generation_enabled = false
	rarity.required_unlock_tags = [&"ordered_unlock"]
	var foundation := ItemFoundationCatalog.new()
	foundation.rarities = [rarity]
	var request := ItemGenerationRequest.create(17, 2, 100, &"ordinary_enemy", &"ordinary_drop", [&"common"])
	request.forced_rarity_id = &"ordered"
	var trace := ItemGenerationTrace.new()
	TestAssertions.equal(ItemRaritySelector.select(request, foundation, trace), null, "unsupported rarity is rejected", failures)
	TestAssertions.equal((trace.stages[0] as Dictionary)["rejected"], {"ordered": "instance_unsupported"}, "instance support is the first post-registration gate", failures)

	rarity.instance_supported = true
	trace = ItemGenerationTrace.new()
	TestAssertions.equal(ItemRaritySelector.select(request, foundation, trace), null, "unpermitted rarity is rejected", failures)
	TestAssertions.equal((trace.stages[0] as Dictionary)["rejected"], {"ordered": "not_permitted"}, "request permission precedes ordinary and unlock gates", failures)

	request.permitted_rarity_ids = [&"ordered"]
	trace = ItemGenerationTrace.new()
	TestAssertions.equal(ItemRaritySelector.select(request, foundation, trace), null, "ordinary-disabled rarity is rejected", failures)
	TestAssertions.equal((trace.stages[0] as Dictionary)["rejected"], {"ordered": "ordinary_generation_disabled"}, "ordinary support precedes unlock and forced-id gates", failures)

	rarity.ordinary_generation_enabled = true
	trace = ItemGenerationTrace.new()
	TestAssertions.equal(ItemRaritySelector.select(request, foundation, trace), null, "locked rarity is rejected", failures)
	TestAssertions.equal((trace.stages[0] as Dictionary)["rejected"], {"ordered": "missing_unlock_tag"}, "unlock gate precedes the forced-id filter", failures)

	request.unlock_tags = [&"ordered_unlock"]
	trace = ItemGenerationTrace.new()
	TestAssertions.equal(ItemRaritySelector.select(request, foundation, trace), rarity, "registered supported permitted ordinary unlocked forced rarity survives every gate", failures)

	request.forced_rarity_id = &"missing"
	trace = ItemGenerationTrace.new()
	TestAssertions.equal(ItemRaritySelector.select(request, foundation, trace), null, "unregistered forced rarity is rejected", failures)
	TestAssertions.equal((trace.stages[0] as Dictionary)["rejected"], {"missing": "unknown_forced_rarity"}, "registration is checked before all candidate gates", failures)

func _test_upper_rarity_generator_gates_preserve_direct_issuance(failures: Array[String]) -> void:
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	for domain: StringName in [&"ordinary_drop", &"developer"]:
		var request := ItemGenerationRequest.create(991, 4, 500, &"developer", domain, [&"mythic"])
		request.forced_rarity_id = &"mythic"
		var trace := ItemGenerationTrace.new()
		TestAssertions.equal(ItemRaritySelector.select(request, foundation, trace), null, "forced Mythic is unavailable to the %s generator" % domain, failures)
		if not trace.stages.is_empty():
			TestAssertions.equal((trace.stages[0] as Dictionary)["rejected"]["mythic"], "ordinary_generation_disabled", "upper rarity system gate is preserved in %s" % domain, failures)

	var issued := ItemInstanceIssuer.issue(
		"task-five:upper-rarity-fixture",
		0,
		"task_five_fixture",
		991,
		{"affixes": [], "base_definition_id": "forge_vanguard_sword", "base_damage_components": [], "item_level": 500, "rarity_id": "mythic"},
		GameCatalog.EQUIPMENT_CATALOG,
		foundation
	)
	TestAssertions.truthy(issued.ok(), "direct ItemInstanceIssuer Mythic fixtures remain valid", failures)

func _test_pattern_selection_uses_exact_domain_compatible_patterns(failures: Array[String]) -> void:
	var rarity := ItemRarityDefinition.new()
	rarity.id = &"test_rarity"
	var ordinary := _pattern(&"ordinary_pattern", 2.0, [&"ordinary_drop"])
	var ordinary_second := _pattern(&"ordinary_second", 1.3, [&"ordinary_drop"])
	var developer := _pattern(&"developer_pattern", 100.0, [&"developer"])
	var invalid := _pattern(&"invalid_pattern", NAN)
	rarity.patterns = [developer, invalid, ordinary_second, ordinary]
	var request := _request()
	var first_trace := ItemGenerationTrace.new()
	var selected := ItemPatternSelector.select(request, rarity, first_trace)
	var expected_id := ItemDeterministicRandom.weighted_id(request.seed, request.generation_sequence, &"pattern:test_rarity", 0, {&"ordinary_pattern": 2.0, &"ordinary_second": 1.3})
	TestAssertions.equal(selected.id if selected != null else &"", expected_id, "pattern selection uses the exact rarity-specific deterministic salt", failures)
	if not first_trace.stages.is_empty():
		var stage := first_trace.stages[0]
		TestAssertions.equal(stage["stage"], "pattern", "pattern selector records the canonical pattern stage", failures)
		TestAssertions.equal(stage["eligible"], ["ordinary_pattern", "ordinary_second"], "only exact domain-compatible patterns reach weighting", failures)
		TestAssertions.equal(stage["weights"], {"ordinary_pattern": 2.0, "ordinary_second": 1.3}, "patterns use their exact authored weights", failures)
		TestAssertions.equal((stage["rejected"] as Dictionary)["developer_pattern"], "domain_not_allowed", "domain mismatch uses a stable rejection code", failures)
		TestAssertions.equal((stage["rejected"] as Dictionary)["invalid_pattern"], "invalid_weight", "nonfinite pattern weight is rejected before selection", failures)

	var reordered := ItemRarityDefinition.new()
	reordered.id = rarity.id
	reordered.patterns = [ordinary, developer, ordinary_second, invalid]
	var second_trace := ItemGenerationTrace.new()
	var repeated := ItemPatternSelector.select(request, reordered, second_trace)
	TestAssertions.equal(repeated.id if repeated != null else &"", selected.id if selected != null else &"", "pattern selection is stable across authored ordering", failures)
	TestAssertions.equal(second_trace.stages, first_trace.stages, "pattern traces are stable across authored ordering", failures)

func _test_pattern_selection_records_empty_pool(failures: Array[String]) -> void:
	var request := ItemGenerationRequest.create(991, 4, 500, &"developer", &"developer", [&"mythic"])
	var rarity := GameCatalog.ITEM_FOUNDATION_CATALOG.rarity(&"mythic")
	var trace := ItemGenerationTrace.new()
	TestAssertions.equal(ItemPatternSelector.select(request, rarity, trace), null, "rarity without implemented patterns returns null", failures)
	if not trace.stages.is_empty():
		TestAssertions.equal((trace.stages[0] as Dictionary)["rejected"], {"mythic": "no_eligible_pattern"}, "empty pattern pool records no_eligible_pattern", failures)

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

func _pattern(id: StringName, weight: float, domains: Array[StringName] = []) -> ItemAffixPatternDefinition:
	var pattern := ItemAffixPatternDefinition.new()
	pattern.id = id
	pattern.weight = weight
	pattern.allowed_generation_domains = domains.duplicate()
	return pattern

func _has_diagnostic(errors: PackedStringArray, expected: String) -> bool:
	return expected in "\n".join(errors)
