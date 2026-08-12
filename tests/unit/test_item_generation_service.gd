extends RefCounted

const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const ISSUER_NAMESPACE := "generation:test"
const CONTENT_SEQUENCE_SEVEN := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.326673947304856}],\"tier\":5},{\"affix_kind\":\"prefix\",\"definition_id\":\"profane\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"chaos_damage\",\"value\":0.069241715429026}],\"tier\":3},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_insight\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"wisdom\",\"value\":2.81314188241959}],\"tier\":3}],\"base_definition_id\":\"forge_vanguard_sword\",\"rarity_id\":\"rare\"}"
const CONTENT_SEQUENCE_EIGHT := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.220470999617385}],\"tier\":3},{\"affix_kind\":\"prefix\",\"definition_id\":\"profane\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"chaos_damage\",\"value\":0.118231963744778}],\"tier\":5},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_endurance\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"constitution\",\"value\":2.4775482416153}],\"tier\":2}],\"base_definition_id\":\"forge_vanguard_sword\",\"rarity_id\":\"rare\"}"
const GOLDEN_RARE_TRACE_SHA256 := "0de5e24e1f539c554c591d6f53dab2f30b3e4dd1c47b44c09f1da0e475f055e0"
const GOLDEN_COMMON := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.172786754480471}],\"tier\":2}],\"base_damage_components\":[{\"damage_type_id\":\"physical\",\"maximum_damage\":255.8,\"minimum_damage\":170.46}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-4bf817c72b18f86df8718cb3af718fcdd265a9a8ca6b37df17eb10747adb5bc7-0000000000000101\",\"item_level\":750,\"origin\":{\"issuer_namespace\":\"generation:test\",\"seed\":424242,\"sequence\":101,\"source\":{\"generation\":{\"base_damage\":{\"components\":[{\"bounds\":{\"maximum\":295.155151367188,\"minimum\":196.68669128418},\"damage_type_id\":\"physical\",\"quality\":0.866669005900621,\"range\":{\"maximum\":255.8,\"minimum\":170.46},\"unit\":0.111126706004143}],\"item_level\":750,\"profile_id\":\"weapon_profile_forge_vanguard_sword\",\"rarity_multiplier\":1},\"domain\":\"ordinary_drop\",\"forced_base_id\":\"forge_vanguard_sword\",\"forced_rarity_id\":\"common\",\"generator_version\":2,\"item_level\":750,\"request_sequence\":7,\"selected_base_id\":\"forge_vanguard_sword\",\"selected_rarity_id\":\"common\",\"source_id\":\"ordinary_enemy\"}}},\"rarity_id\":\"common\",\"schema_version\":2}"
const GOLDEN_UNCOMMON := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.272786758915513}],\"tier\":3},{\"affix_kind\":\"prefix\",\"definition_id\":\"profane\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"chaos_damage\",\"value\":0.069241715429026}],\"tier\":3}],\"base_damage_components\":[{\"damage_type_id\":\"physical\",\"maximum_damage\":276.27,\"minimum_damage\":184.1}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-4bf817c72b18f86df8718cb3af718fcdd265a9a8ca6b37df17eb10747adb5bc7-0000000000000102\",\"item_level\":750,\"origin\":{\"issuer_namespace\":\"generation:test\",\"seed\":424242,\"sequence\":102,\"source\":{\"generation\":{\"base_damage\":{\"components\":[{\"bounds\":{\"maximum\":295.155151367188,\"minimum\":196.68669128418},\"damage_type_id\":\"physical\",\"quality\":0.866669005900621,\"range\":{\"maximum\":276.27,\"minimum\":184.1},\"unit\":0.111126706004143}],\"item_level\":750,\"profile_id\":\"weapon_profile_forge_vanguard_sword\",\"rarity_multiplier\":1.08},\"domain\":\"ordinary_drop\",\"forced_base_id\":\"forge_vanguard_sword\",\"forced_rarity_id\":\"uncommon\",\"generator_version\":2,\"item_level\":750,\"request_sequence\":7,\"selected_base_id\":\"forge_vanguard_sword\",\"selected_rarity_id\":\"uncommon\",\"source_id\":\"ordinary_enemy\"}}},\"rarity_id\":\"uncommon\",\"schema_version\":2}"
const GOLDEN_RARE := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.326673947304856}],\"tier\":5},{\"affix_kind\":\"prefix\",\"definition_id\":\"profane\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"chaos_damage\",\"value\":0.069241715429026}],\"tier\":3},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_insight\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"wisdom\",\"value\":2.81314188241959}],\"tier\":3}],\"base_damage_components\":[{\"damage_type_id\":\"physical\",\"maximum_damage\":301.85,\"minimum_damage\":201.15}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-4bf817c72b18f86df8718cb3af718fcdd265a9a8ca6b37df17eb10747adb5bc7-0000000000000103\",\"item_level\":750,\"origin\":{\"issuer_namespace\":\"generation:test\",\"seed\":424242,\"sequence\":103,\"source\":{\"generation\":{\"base_damage\":{\"components\":[{\"bounds\":{\"maximum\":295.155151367188,\"minimum\":196.68669128418},\"damage_type_id\":\"physical\",\"quality\":0.866669005900621,\"range\":{\"maximum\":301.85,\"minimum\":201.15},\"unit\":0.111126706004143}],\"item_level\":750,\"profile_id\":\"weapon_profile_forge_vanguard_sword\",\"rarity_multiplier\":1.18},\"domain\":\"ordinary_drop\",\"forced_base_id\":\"forge_vanguard_sword\",\"forced_rarity_id\":\"rare\",\"generator_version\":2,\"item_level\":750,\"request_sequence\":7,\"selected_base_id\":\"forge_vanguard_sword\",\"selected_rarity_id\":\"rare\",\"source_id\":\"ordinary_enemy\"}}},\"rarity_id\":\"rare\",\"schema_version\":2}"
const GOLDEN_EPIC := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.326673947304856}],\"tier\":5},{\"affix_kind\":\"prefix\",\"definition_id\":\"profane\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"chaos_damage\",\"value\":0.0850316432367559}],\"tier\":4},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_insight\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"wisdom\",\"value\":2.81314188241959}],\"tier\":3},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_velocity\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"projectile_speed\",\"value\":0.0795842987391882}],\"tier\":1}],\"base_damage_components\":[{\"damage_type_id\":\"physical\",\"maximum_damage\":337.66,\"minimum_damage\":225.01}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-4bf817c72b18f86df8718cb3af718fcdd265a9a8ca6b37df17eb10747adb5bc7-0000000000000104\",\"item_level\":750,\"origin\":{\"issuer_namespace\":\"generation:test\",\"seed\":424242,\"sequence\":104,\"source\":{\"generation\":{\"base_damage\":{\"components\":[{\"bounds\":{\"maximum\":295.155151367188,\"minimum\":196.68669128418},\"damage_type_id\":\"physical\",\"quality\":0.866669005900621,\"range\":{\"maximum\":337.66,\"minimum\":225.01},\"unit\":0.111126706004143}],\"item_level\":750,\"profile_id\":\"weapon_profile_forge_vanguard_sword\",\"rarity_multiplier\":1.32},\"domain\":\"ordinary_drop\",\"forced_base_id\":\"forge_vanguard_sword\",\"forced_rarity_id\":\"epic\",\"generator_version\":2,\"item_level\":750,\"request_sequence\":7,\"selected_base_id\":\"forge_vanguard_sword\",\"selected_rarity_id\":\"epic\",\"source_id\":\"ordinary_enemy\"}}},\"rarity_id\":\"epic\",\"schema_version\":2}"
const GOLDEN_LEGENDARY := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.326673947304856}],\"tier\":5},{\"affix_kind\":\"prefix\",\"definition_id\":\"profane\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"chaos_damage\",\"value\":0.0850316432367559}],\"tier\":4},{\"affix_kind\":\"prefix\",\"definition_id\":\"martial_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.136549603022358}],\"tier\":5},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_insight\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"wisdom\",\"value\":2.81314188241959}],\"tier\":3},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_velocity\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"projectile_speed\",\"value\":0.0795842987391882}],\"tier\":1}],\"base_damage_components\":[{\"damage_type_id\":\"physical\",\"maximum_damage\":383.7,\"minimum_damage\":255.69}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-4bf817c72b18f86df8718cb3af718fcdd265a9a8ca6b37df17eb10747adb5bc7-0000000000000105\",\"item_level\":750,\"origin\":{\"issuer_namespace\":\"generation:test\",\"seed\":424242,\"sequence\":105,\"source\":{\"generation\":{\"base_damage\":{\"components\":[{\"bounds\":{\"maximum\":295.155151367188,\"minimum\":196.68669128418},\"damage_type_id\":\"physical\",\"quality\":0.866669005900621,\"range\":{\"maximum\":383.7,\"minimum\":255.69},\"unit\":0.111126706004143}],\"item_level\":750,\"profile_id\":\"weapon_profile_forge_vanguard_sword\",\"rarity_multiplier\":1.5},\"domain\":\"ordinary_drop\",\"forced_base_id\":\"forge_vanguard_sword\",\"forced_rarity_id\":\"legendary\",\"generator_version\":2,\"item_level\":750,\"request_sequence\":7,\"selected_base_id\":\"forge_vanguard_sword\",\"selected_rarity_id\":\"legendary\",\"source_id\":\"ordinary_enemy\"}}},\"rarity_id\":\"legendary\",\"schema_version\":2}"

func run() -> Array[String]:
	var failures: Array[String] = []
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var foundation := load(FOUNDATION_PATH) as ItemFoundationCatalog
	TestAssertions.truthy(equipment != null and foundation != null, "generation catalogs load", failures)
	if equipment == null or foundation == null:
		return failures
	_test_fixed_seed_items(equipment, foundation, failures)
	_test_deterministic_sequences(equipment, foundation, failures)
	_test_damage_profile_does_not_shift_existing_generation(equipment, foundation, failures)
	_test_structured_failures(equipment, foundation, failures)
	_test_base_damage_failure_precedes_pattern_affix_and_issuance(equipment, foundation, failures)
	_test_affix_unlock_gate(equipment, foundation, failures)
	_test_codec_immutability(equipment, foundation, failures)
	return failures

func _test_fixed_seed_items(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var golden_by_rarity := {
		&"common": GOLDEN_COMMON,
		&"uncommon": GOLDEN_UNCOMMON,
		&"rare": GOLDEN_RARE,
		&"epic": GOLDEN_EPIC,
		&"legendary": GOLDEN_LEGENDARY,
	}
	for rarity_id: StringName in golden_by_rarity:
		var sequence := 100 + foundation.rarity(rarity_id).rarity_rank
		var result := ItemGenerationService.generate(_request(rarity_id), ISSUER_NAMESPACE, sequence, equipment, foundation)
		TestAssertions.truthy(result != null and result.ok(), "%s fixed request succeeds" % rarity_id, failures)
		if result == null or not result.ok():
			continue
		var exact_document := result.item.to_dictionary()
		var exact_golden: String = golden_by_rarity[rarity_id]
		exact_golden = exact_golden.replace("\"domain\":\"ordinary_drop\"", "\"difficulty_id\":\"normal\",\"domain\":\"ordinary_drop\"")
		exact_golden = exact_golden.replace("\"generator_version\":2", "\"generator_version\":2,\"heat\":0")
		TestAssertions.equal(ItemInstanceCodec.encode(result.item), exact_golden, "%s fixed request has exact schema-two dictionary" % rarity_id, failures)
		if rarity_id == &"rare":
			TestAssertions.equal(JSON.stringify(result.trace.stages).sha256_text(), GOLDEN_RARE_TRACE_SHA256, "rare fixed request has exact trace bytes", failures)
		TestAssertions.equal(result.item.affixes[0].affix_kind, "implicit", "%s guaranteed implicit is first" % rarity_id, failures)
		var origin := result.item.origin
		var origin_keys: Array = origin.keys()
		origin_keys.sort()
		TestAssertions.equal(origin_keys, ["issuer_namespace", "seed", "sequence", "source"], "%s origin preserves four top-level fields" % rarity_id, failures)
		TestAssertions.truthy(not origin.has("generator_version"), "%s generator provenance is not top-level" % rarity_id, failures)
		TestAssertions.equal(origin["source"]["generation"]["generator_version"], 2, "%s generator version is nested under source" % rarity_id, failures)
		TestAssertions.equal(origin["source"]["generation"]["selected_base_id"], "forge_vanguard_sword", "%s selected base provenance is exact" % rarity_id, failures)
		TestAssertions.equal(origin["source"]["generation"]["selected_rarity_id"], String(rarity_id), "%s selected rarity provenance is exact" % rarity_id, failures)
		TestAssertions.equal(origin["source"]["generation"]["difficulty_id"], "normal", "%s difficulty provenance is exact" % rarity_id, failures)
		TestAssertions.near(float(origin["source"]["generation"]["heat"]), 0.0, 0.001, "%s Heat provenance is exact" % rarity_id, failures)
		TestAssertions.equal(origin["source"]["generation"]["forced_base_id"], "forge_vanguard_sword", "%s authorized forced base provenance is exact" % rarity_id, failures)
		TestAssertions.equal(origin["source"]["generation"]["forced_rarity_id"], String(rarity_id), "%s authorized forced rarity provenance is exact" % rarity_id, failures)
		var decoded := ItemInstanceCodec.decode(JSON.parse_string(ItemInstanceCodec.encode(result.item)), equipment, foundation)
		TestAssertions.truthy(decoded.ok(), "%s encoded item decodes" % rarity_id, failures)
		if decoded.ok():
			TestAssertions.equal(JSON.stringify(decoded.item.to_dictionary()), JSON.stringify(exact_document), "%s codec preserves exact generated dictionary" % rarity_id, failures)

func _test_deterministic_sequences(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var request := _request(&"rare")
	var caller_item_sequence := 401
	var first := ItemGenerationService.generate(request, ISSUER_NAMESPACE, caller_item_sequence, equipment, foundation)
	var repeated := ItemGenerationService.generate(request, ISSUER_NAMESPACE, caller_item_sequence, equipment, foundation)
	TestAssertions.truthy(first.ok() and repeated.ok(), "repeated request results succeed", failures)
	if first.ok() and repeated.ok():
		TestAssertions.equal(first.item.to_dictionary(), repeated.item.to_dictionary(), "same request and item sequence repeat exactly", failures)
		TestAssertions.equal(_generation_content(first.item), CONTENT_SEQUENCE_SEVEN, "sequence seven generation content is exact", failures)
	var changed_request := _request(&"rare")
	changed_request.generation_sequence += 1
	var changed := ItemGenerationService.generate(changed_request, ISSUER_NAMESPACE, caller_item_sequence, equipment, foundation)
	TestAssertions.truthy(changed.ok(), "changed generation sequence succeeds", failures)
	if first.ok() and changed.ok():
		TestAssertions.equal(_generation_content(changed.item), CONTENT_SEQUENCE_EIGHT, "sequence eight generation content is exact", failures)
		TestAssertions.truthy(_generation_content(first.item) != _generation_content(changed.item), "generation sequence changes generated affixes independently of identity and origin", failures)
	TestAssertions.equal(caller_item_sequence, 401, "successful generation does not mutate caller item sequence", failures)

func _test_damage_profile_does_not_shift_existing_generation(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var request := _request(&"rare")
	var without_profile_equipment := equipment.duplicate(true) as EquipmentCatalog
	var sword_index := without_profile_equipment.definitions.find(without_profile_equipment.definition(&"forge_vanguard_sword"))
	without_profile_equipment.definitions[sword_index] = without_profile_equipment.definitions[sword_index].duplicate(true) as EquipmentBaseDefinition
	without_profile_equipment.definitions[sword_index].weapon_damage_profile = null
	var without_profile := ItemGenerationService.generate(request, ISSUER_NAMESPACE, 501, without_profile_equipment, foundation)
	var profiled_equipment := without_profile_equipment.duplicate(true) as EquipmentCatalog
	profiled_equipment.definitions[sword_index] = profiled_equipment.definitions[sword_index].duplicate(true) as EquipmentBaseDefinition
	var profile := WeaponDamageProfile.new()
	profile.id = &"test_sword_damage"
	var curve := WeaponDamageComponentCurve.new()
	curve.damage_type_id = &"physical"
	curve.minimum_at_level_1 = 10.0
	curve.maximum_at_level_1 = 20.0
	curve.minimum_at_level_1000 = 10.0
	curve.maximum_at_level_1000 = 20.0
	profile.components = [curve]
	profiled_equipment.definitions[sword_index].weapon_damage_profile = profile
	var with_profile := ItemGenerationService.generate(request, ISSUER_NAMESPACE, 501, profiled_equipment, foundation)
	TestAssertions.truthy(without_profile.ok() and with_profile.ok(), "profile insertion comparison generations succeed", failures)
	if not without_profile.ok() or not with_profile.ok():
		return
	TestAssertions.equal(_generation_content(with_profile.item), _generation_content(without_profile.item), "damage profile does not shift base rarity pattern affix tier or roll selections", failures)
	TestAssertions.equal(_trace_without_base_damage(with_profile.trace), _trace_without_base_damage(without_profile.trace), "damage profile does not shift any existing deterministic trace stage", failures)
	TestAssertions.equal(without_profile.item.base_damage_components, [], "base without profile still issues no damage components", failures)
	TestAssertions.equal(with_profile.item.to_dictionary()["base_damage_components"], [
		{"damage_type_id": "physical", "minimum_damage": 10.23, "maximum_damage": 20.45},
	], "profile insertion changes only immutable issued base damage values", failures)
	var generation := with_profile.item.origin["source"]["generation"] as Dictionary
	var stored_base_damage := generation.get("base_damage") as Dictionary
	TestAssertions.equal(_base_damage_provenance_without_random(stored_base_damage), {
		"profile_id": "test_sword_damage",
		"item_level": 750,
		"rarity_multiplier": 1.18,
		"components": [{
			"damage_type_id": "physical",
			"bounds": {"minimum": 10, "maximum": 20},
			"range": {"minimum": 10.23, "maximum": 20.45},
		}],
	}, "issued origin stores the exact canonical base-damage bounds and ranges", failures)
	var stored_component := (stored_base_damage["components"] as Array)[0] as Dictionary
	TestAssertions.near(float(stored_component["unit"]), 0.11112670600414, 0.00000000000001, "issued origin stores the fixed base-damage unit", failures)
	TestAssertions.near(float(stored_component["quality"]), 0.86666900590062, 0.00000000000001, "issued origin stores the fixed base-damage quality", failures)
	var item_before_profile_mutation := with_profile.item.to_dictionary()
	var exposed_trace := with_profile.trace.stages
	for stage: Dictionary in exposed_trace:
		if stage["stage"] == "base_damage":
			((stage["details"]["components"] as Array)[0] as Dictionary)["quality"] = -1.0
	TestAssertions.equal(with_profile.item.to_dictionary(), item_before_profile_mutation, "mutating exposed generation trace cannot rewrite issued provenance", failures)
	profile.quality_minimum = 0.1
	curve.minimum_at_level_1 = 999.0
	TestAssertions.equal(with_profile.item.to_dictionary(), item_before_profile_mutation, "issued damage and provenance never recalculate from the live profile", failures)

func _test_structured_failures(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var invalid := ItemGenerationService.generate(null, ISSUER_NAMESPACE, 1, equipment, foundation)
	_assert_failure(invalid, null, &"request", &"invalid_request", failures)
	TestAssertions.truthy(String(invalid.failure.details.get("message", "")).begins_with("PARTY_FORGE_ITEM_GENERATION_ERROR"), "invalid request carries exact structured diagnostic", failures)

	var missing_foundation_request := _request(&"common")
	var missing_foundation := ItemGenerationService.generate(missing_foundation_request, ISSUER_NAMESPACE, 1, equipment, null)
	_assert_failure(missing_foundation, missing_foundation_request, &"request", &"invalid_request", failures)
	TestAssertions.equal(missing_foundation.failure.details, {"message": "PARTY_FORGE_ITEM_GENERATION_ERROR stage=request field=foundation reason=manifest missing"}, "missing foundation has a stable diagnostic", failures)

	var missing_equipment_request := _request(&"common")
	var missing_equipment := ItemGenerationService.generate(missing_equipment_request, ISSUER_NAMESPACE, 1, null, foundation)
	_assert_failure(missing_equipment, missing_equipment_request, &"base", &"no_eligible_base", failures)
	TestAssertions.equal(missing_equipment.failure.details, {"rejected": {"<catalog>": "equipment_catalog_missing"}}, "missing equipment has a stable base rejection", failures)

	var base_request := _request(&"common")
	base_request.forced_base_id = &"missing_base"
	var base_failure := ItemGenerationService.generate(base_request, ISSUER_NAMESPACE, 2, equipment, foundation)
	_assert_failure(base_failure, base_request, &"base", &"no_eligible_base", failures)
	TestAssertions.equal(base_failure.failure.details, {"rejected": {"missing_base": "unknown_forced_base"}}, "base failure copies canonical selector rejection summary", failures)

	var rarity_request := _request(&"mythic")
	var rarity_failure := ItemGenerationService.generate(rarity_request, ISSUER_NAMESPACE, 3, equipment, foundation)
	_assert_failure(rarity_failure, rarity_request, &"rarity", &"no_eligible_rarity", failures)
	TestAssertions.equal(rarity_failure.failure.details.get("rejected", {}).get("mythic", ""), "ordinary_generation_disabled", "rarity failure copies relevant canonical selector rejection", failures)

	var pattern_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var common_index := pattern_foundation.rarities.find(pattern_foundation.rarity(&"common"))
	pattern_foundation.rarities[common_index] = pattern_foundation.rarities[common_index].duplicate(true) as ItemRarityDefinition
	pattern_foundation.rarities[common_index].patterns = []
	var pattern_request := _request(&"common")
	var pattern_failure := ItemGenerationService.generate(pattern_request, ISSUER_NAMESPACE, 4, equipment, pattern_foundation)
	_assert_failure(pattern_failure, pattern_request, &"pattern", &"no_eligible_pattern", failures)
	TestAssertions.equal(pattern_failure.failure.details, {"rarity_id": "common", "rejected": {"common": "no_eligible_pattern"}}, "pattern failure copies canonical selector rejection summary", failures)

	var affix_request := _request(&"uncommon")
	affix_request.forced_base_id = &"forge_vanguard_helmet"
	affix_request.required_affix_tags = [&"ranged"]
	var affix_equipment := equipment.duplicate(true) as EquipmentCatalog
	var helmet_index := affix_equipment.definitions.find(affix_equipment.definition(&"forge_vanguard_helmet"))
	affix_equipment.definitions[helmet_index] = affix_equipment.definitions[helmet_index].duplicate(true) as EquipmentBaseDefinition
	affix_equipment.definitions[helmet_index].implicit_affix_ids = []
	_assert_failure(ItemGenerationService.generate(affix_request, ISSUER_NAMESPACE, 5, affix_equipment, foundation), affix_request, &"affix", &"no_eligible_affix", failures)

	var tier_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var tempered_index := tier_foundation.affixes.find(tier_foundation.affix(&"tempered_edge"))
	tier_foundation.affixes[tempered_index] = tier_foundation.affixes[tempered_index].duplicate(true) as ItemAffixDefinition
	for tier_index: int in tier_foundation.affixes[tempered_index].tiers.size():
		tier_foundation.affixes[tempered_index].tiers[tier_index] = tier_foundation.affixes[tempered_index].tiers[tier_index].duplicate(true) as ItemAffixTierDefinition
		tier_foundation.affixes[tempered_index].tiers[tier_index].base_weight = NAN
	var tier_request := _request(&"common")
	var tier_failure := ItemGenerationService.generate(tier_request, ISSUER_NAMESPACE, 6, equipment, tier_foundation)
	_assert_failure(tier_failure, tier_request, &"affix", &"invalid_implicit_affix", failures)
	TestAssertions.equal(tier_failure.failure.details.get("reason", ""), "no_eligible_tier", "tier exhaustion remains visible in affix failure details", failures)

	var issuer_request := _request(&"common")
	var caller_item_sequence := 77
	var issuer_failure := ItemGenerationService.generate(issuer_request, " ", caller_item_sequence, equipment, foundation)
	_assert_failure(issuer_failure, issuer_request, &"issuance", &"issuer_rejected", failures)
	TestAssertions.truthy(String(issuer_failure.failure.details.get("message", "")).contains("field=issuer_namespace"), "issuer failure preserves issuer diagnostic", failures)
	TestAssertions.equal(caller_item_sequence, 77, "failed generation does not mutate caller item sequence", failures)

	var negative_item_sequence := -1
	var negative_sequence_failure := ItemGenerationService.generate(issuer_request, ISSUER_NAMESPACE, negative_item_sequence, equipment, foundation)
	_assert_failure(negative_sequence_failure, issuer_request, &"issuance", &"issuer_rejected", failures)
	TestAssertions.truthy(String(negative_sequence_failure.failure.details.get("message", "")).contains("field=sequence"), "negative item sequence preserves issuer diagnostic", failures)
	TestAssertions.equal(negative_item_sequence, -1, "negative caller item sequence remains unchanged", failures)

	var oversized_item_sequence := ItemInstanceCodec.JSON_SAFE_INTEGER_MAX + 1
	var oversized_sequence_failure := ItemGenerationService.generate(issuer_request, ISSUER_NAMESPACE, oversized_item_sequence, equipment, foundation)
	_assert_failure(oversized_sequence_failure, issuer_request, &"issuance", &"issuer_rejected", failures)
	TestAssertions.truthy(String(oversized_sequence_failure.failure.details.get("message", "")).contains("field=sequence"), "oversized item sequence preserves issuer diagnostic", failures)
	TestAssertions.equal(oversized_item_sequence, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX + 1, "oversized caller item sequence remains unchanged", failures)

func _test_base_damage_failure_precedes_pattern_affix_and_issuance(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var gated_equipment := equipment.duplicate(true) as EquipmentCatalog
	var sword_index := gated_equipment.definitions.find(gated_equipment.definition(&"forge_vanguard_sword"))
	gated_equipment.definitions[sword_index] = gated_equipment.definitions[sword_index].duplicate(true) as EquipmentBaseDefinition
	var profile := WeaponDamageProfile.new()
	profile.id = &"future_sword_damage"
	profile.minimum_item_level = 751
	var curve := WeaponDamageComponentCurve.new()
	curve.damage_type_id = &"physical"
	curve.minimum_at_level_1 = 10.0
	curve.maximum_at_level_1 = 20.0
	curve.minimum_at_level_1000 = 100.0
	curve.maximum_at_level_1000 = 200.0
	profile.components = [curve]
	gated_equipment.definitions[sword_index].weapon_damage_profile = profile
	var request := _request(&"rare")
	var caller_item_sequence := 777
	var result := ItemGenerationService.generate(request, " ", caller_item_sequence, gated_equipment, foundation)
	_assert_failure(result, request, &"base_damage", &"profile_rejected", failures)
	TestAssertions.equal(result.failure.details, {
		"message": "PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage profile=future_sword_damage field=item_level value=750 reason=below minimum 751",
	}, "base-damage service failure preserves the stable roller diagnostic", failures)
	TestAssertions.equal(result.trace.stages.map(func(stage: Dictionary) -> String: return stage["stage"]), ["base", "rarity", "base_damage"], "base-damage failure happens before pattern or affix assembly", failures)
	TestAssertions.equal(caller_item_sequence, 777, "base-damage failure never consumes the caller issuance sequence", failures)

func _test_affix_unlock_gate(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var gated_equipment := equipment.duplicate(true) as EquipmentCatalog
	var helmet_index := gated_equipment.definitions.find(gated_equipment.definition(&"forge_vanguard_helmet"))
	gated_equipment.definitions[helmet_index] = gated_equipment.definitions[helmet_index].duplicate(true) as EquipmentBaseDefinition
	gated_equipment.definitions[helmet_index].implicit_affix_ids = []
	var gated_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var uncommon_index := gated_foundation.rarities.find(gated_foundation.rarity(&"uncommon"))
	gated_foundation.rarities[uncommon_index] = gated_foundation.rarities[uncommon_index].duplicate(true) as ItemRarityDefinition
	gated_foundation.rarities[uncommon_index].patterns = [gated_foundation.rarities[uncommon_index].patterns[0]]
	var gated_affix := gated_foundation.affix(&"stout").duplicate(true) as ItemAffixDefinition
	gated_affix.required_unlock_tags = [&"affix_stout_unlocked"]
	gated_foundation.affixes = [gated_affix]
	var request := _request(&"uncommon")
	request.forced_base_id = &"forge_vanguard_helmet"
	request.unlock_tags = []
	_assert_failure(ItemGenerationService.generate(request, ISSUER_NAMESPACE, 900, gated_equipment, gated_foundation), request, &"affix", &"no_eligible_affix", failures)
	request.unlock_tags = [&"affix_stout_unlocked"]
	var unlocked := ItemGenerationService.generate(request, ISSUER_NAMESPACE, 901, gated_equipment, gated_foundation)
	TestAssertions.truthy(unlocked.ok(), "unlock-gated affix generates after its manifest unlock is supplied", failures)
	if unlocked.ok():
		TestAssertions.equal(unlocked.item.affixes[0].definition_id, &"stout", "unlocked service result contains gated affix", failures)

func _test_codec_immutability(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var generated := ItemGenerationService.generate(_request(&"rare"), ISSUER_NAMESPACE, 103, equipment, foundation)
	TestAssertions.truthy(generated.ok(), "immutability fixture generates", failures)
	if not generated.ok():
		return
	var decode_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var decoded := ItemInstanceCodec.decode(JSON.parse_string(ItemInstanceCodec.encode(generated.item)), equipment, decode_foundation)
	TestAssertions.truthy(decoded.ok(), "immutability fixture decodes", failures)
	if not decoded.ok():
		return
	var stored_before := decoded.item.to_dictionary()
	var definition_id := decoded.item.affixes[0].definition_id
	var definition_index := decode_foundation.affixes.find(decode_foundation.affix(definition_id))
	decode_foundation.affixes[definition_index] = decode_foundation.affixes[definition_index].duplicate(true) as ItemAffixDefinition
	var tier_index := decoded.item.affixes[0].tier - 1
	decode_foundation.affixes[definition_index].tiers[tier_index] = decode_foundation.affixes[definition_index].tiers[tier_index].duplicate(true) as ItemAffixTierDefinition
	decode_foundation.affixes[definition_index].tiers[tier_index].minimum_rolls[0] = -999.0
	decode_foundation.affixes[definition_index].tiers[tier_index].maximum_rolls[0] = 999.0
	TestAssertions.equal(decoded.item.to_dictionary(), stored_before, "post-decode catalog tier mutation cannot rewrite stored rolls", failures)

func _assert_failure(result: ItemGenerationResult, request: ItemGenerationRequest, stage: StringName, code: StringName, failures: Array[String]) -> void:
	TestAssertions.truthy(result != null and not result.ok(), "%s failure returns a failed result" % stage, failures)
	if result == null:
		return
	TestAssertions.equal(result.item, null, "%s failure exposes no item" % stage, failures)
	TestAssertions.truthy(result.failure != null, "%s failure exposes structured failure" % stage, failures)
	TestAssertions.truthy(result.trace != null, "%s failure preserves trace" % stage, failures)
	if result.failure == null:
		return
	TestAssertions.equal(result.failure.stage, stage, "%s failure records stage" % stage, failures)
	TestAssertions.equal(result.failure.code, code, "%s failure records stable code" % stage, failures)
	TestAssertions.equal(result.failure.generator_version, 2, "%s failure records generator version" % stage, failures)
	if request != null:
		TestAssertions.equal(result.failure.source_id, request.source_id, "%s failure copies request source" % stage, failures)
		TestAssertions.equal(result.failure.seed, request.seed, "%s failure copies request seed" % stage, failures)
		TestAssertions.equal(result.failure.generation_sequence, request.generation_sequence, "%s failure copies request sequence" % stage, failures)

func _request(rarity_id: StringName) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(424242, 7, 750, &"ordinary_enemy", &"ordinary_drop", [rarity_id])
	request.forced_base_id = &"forge_vanguard_sword"
	request.forced_rarity_id = rarity_id
	request.unlock_tags = [&"rarity_rare_unlocked", &"rarity_epic_unlocked", &"rarity_legendary_unlocked"]
	return request

func _trace_without_base_damage(trace: ItemGenerationTrace) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stage: Dictionary in trace.stages:
		if stage["stage"] != "base_damage":
			result.append(stage)
	return result

func _base_damage_provenance_without_random(provenance: Dictionary) -> Dictionary:
	var result := provenance.duplicate(true)
	for component: Dictionary in result.get("components", []):
		component.erase("unit")
		component.erase("quality")
	return result

func _generation_content(item: ItemInstance) -> String:
	var affixes: Array[Dictionary] = []
	for affix: ItemAffixInstance in item.affixes:
		affixes.append(affix.to_dictionary())
	return JSON.stringify({
		"affixes": affixes,
		"base_definition_id": String(item.base_definition_id),
		"rarity_id": String(item.rarity_id),
	})
