extends RefCounted

const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const ISSUER_NAMESPACE := "generation:test"
const GOLDEN_COMMON := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.172786754480471}],\"tier\":2}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-4bf817c72b18f86df8718cb3af718fcdd265a9a8ca6b37df17eb10747adb5bc7-0000000000000101\",\"item_level\":750,\"origin\":{\"issuer_namespace\":\"generation:test\",\"seed\":424242,\"sequence\":101,\"source\":{\"generation\":{\"domain\":\"ordinary_drop\",\"generator_version\":1,\"item_level\":750,\"request_sequence\":7,\"source_id\":\"ordinary_enemy\"}}},\"rarity_id\":\"common\",\"schema_version\":1}"
const GOLDEN_UNCOMMON := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.172786754480471}],\"tier\":2},{\"affix_kind\":\"prefix\",\"definition_id\":\"stout\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"constitution\",\"value\":1.63195639848709}],\"tier\":1}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-4bf817c72b18f86df8718cb3af718fcdd265a9a8ca6b37df17eb10747adb5bc7-0000000000000102\",\"item_level\":750,\"origin\":{\"issuer_namespace\":\"generation:test\",\"seed\":424242,\"sequence\":102,\"source\":{\"generation\":{\"domain\":\"ordinary_drop\",\"generator_version\":1,\"item_level\":750,\"request_sequence\":7,\"source_id\":\"ordinary_enemy\"}}},\"rarity_id\":\"uncommon\",\"schema_version\":1}"
const GOLDEN_RARE := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.172786754480471}],\"tier\":2},{\"affix_kind\":\"prefix\",\"definition_id\":\"stout\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"constitution\",\"value\":1.63195639848709}],\"tier\":1},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_reach\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"attack_range\",\"value\":0.248318827866737}],\"tier\":3}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-4bf817c72b18f86df8718cb3af718fcdd265a9a8ca6b37df17eb10747adb5bc7-0000000000000103\",\"item_level\":750,\"origin\":{\"issuer_namespace\":\"generation:test\",\"seed\":424242,\"sequence\":103,\"source\":{\"generation\":{\"domain\":\"ordinary_drop\",\"generator_version\":1,\"item_level\":750,\"request_sequence\":7,\"source_id\":\"ordinary_enemy\"}}},\"rarity_id\":\"rare\",\"schema_version\":1}"
const GOLDEN_EPIC := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.172786754480471}],\"tier\":2},{\"affix_kind\":\"prefix\",\"definition_id\":\"stout\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"constitution\",\"value\":1.63195639848709}],\"tier\":1},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_reach\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"attack_range\",\"value\":0.248318827866737}],\"tier\":3},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_rime\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"cold_damage\",\"value\":0.271506341806361}],\"tier\":3}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-4bf817c72b18f86df8718cb3af718fcdd265a9a8ca6b37df17eb10747adb5bc7-0000000000000104\",\"item_level\":750,\"origin\":{\"issuer_namespace\":\"generation:test\",\"seed\":424242,\"sequence\":104,\"source\":{\"generation\":{\"domain\":\"ordinary_drop\",\"generator_version\":1,\"item_level\":750,\"request_sequence\":7,\"source_id\":\"ordinary_enemy\"}}},\"rarity_id\":\"epic\",\"schema_version\":1}"
const GOLDEN_LEGENDARY := "{\"affixes\":[{\"affix_kind\":\"implicit\",\"definition_id\":\"tempered_edge\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"physical_damage\",\"value\":0.172786754480471}],\"tier\":2},{\"affix_kind\":\"prefix\",\"definition_id\":\"stout\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"constitution\",\"value\":1.63195639848709}],\"tier\":1},{\"affix_kind\":\"prefix\",\"definition_id\":\"keen\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"dexterity\",\"value\":2.69180417060852}],\"tier\":1},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_reach\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"attack_range\",\"value\":0.248318827866737}],\"tier\":3},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_rime\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"cold_damage\",\"value\":0.271506341806361}],\"tier\":3}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-4bf817c72b18f86df8718cb3af718fcdd265a9a8ca6b37df17eb10747adb5bc7-0000000000000105\",\"item_level\":750,\"origin\":{\"issuer_namespace\":\"generation:test\",\"seed\":424242,\"sequence\":105,\"source\":{\"generation\":{\"domain\":\"ordinary_drop\",\"generator_version\":1,\"item_level\":750,\"request_sequence\":7,\"source_id\":\"ordinary_enemy\"}}},\"rarity_id\":\"legendary\",\"schema_version\":1}"

func run() -> Array[String]:
	var failures: Array[String] = []
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var foundation := load(FOUNDATION_PATH) as ItemFoundationCatalog
	TestAssertions.truthy(equipment != null and foundation != null, "generation catalogs load", failures)
	if equipment == null or foundation == null:
		return failures
	_test_fixed_seed_items(equipment, foundation, failures)
	_test_deterministic_sequences(equipment, foundation, failures)
	_test_structured_failures(equipment, foundation, failures)
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
		TestAssertions.equal(ItemInstanceCodec.encode(result.item), golden_by_rarity[rarity_id], "%s fixed request has exact schema-one dictionary" % rarity_id, failures)
		TestAssertions.equal(result.item.affixes[0].affix_kind, "implicit", "%s guaranteed implicit is first" % rarity_id, failures)
		var origin := result.item.origin
		var origin_keys: Array = origin.keys()
		origin_keys.sort()
		TestAssertions.equal(origin_keys, ["issuer_namespace", "seed", "sequence", "source"], "%s origin preserves four top-level fields" % rarity_id, failures)
		TestAssertions.truthy(not origin.has("generator_version"), "%s generator provenance is not top-level" % rarity_id, failures)
		TestAssertions.equal(origin["source"]["generation"]["generator_version"], 1, "%s generator version is nested under source" % rarity_id, failures)
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
	var changed_request := _request(&"rare")
	changed_request.generation_sequence += 1
	var changed := ItemGenerationService.generate(changed_request, ISSUER_NAMESPACE, caller_item_sequence, equipment, foundation)
	TestAssertions.truthy(changed.ok(), "changed generation sequence succeeds", failures)
	if first.ok() and changed.ok():
		TestAssertions.truthy(first.item.to_dictionary() != changed.item.to_dictionary(), "generation sequence changes deterministic output", failures)
	TestAssertions.equal(caller_item_sequence, 401, "successful generation does not mutate caller item sequence", failures)

func _test_structured_failures(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var invalid := ItemGenerationService.generate(null, ISSUER_NAMESPACE, 1, equipment, foundation)
	_assert_failure(invalid, null, &"request", &"invalid_request", failures)
	TestAssertions.truthy(String(invalid.failure.details.get("message", "")).begins_with("PARTY_FORGE_ITEM_GENERATION_ERROR"), "invalid request carries exact structured diagnostic", failures)

	var base_request := _request(&"common")
	base_request.forced_base_id = &"missing_base"
	_assert_failure(ItemGenerationService.generate(base_request, ISSUER_NAMESPACE, 2, equipment, foundation), base_request, &"base", &"no_eligible_base", failures)

	var rarity_request := _request(&"mythic")
	_assert_failure(ItemGenerationService.generate(rarity_request, ISSUER_NAMESPACE, 3, equipment, foundation), rarity_request, &"rarity", &"no_eligible_rarity", failures)

	var pattern_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var common_index := pattern_foundation.rarities.find(pattern_foundation.rarity(&"common"))
	pattern_foundation.rarities[common_index] = pattern_foundation.rarities[common_index].duplicate(true) as ItemRarityDefinition
	pattern_foundation.rarities[common_index].patterns = []
	var pattern_request := _request(&"common")
	_assert_failure(ItemGenerationService.generate(pattern_request, ISSUER_NAMESPACE, 4, equipment, pattern_foundation), pattern_request, &"pattern", &"no_eligible_pattern", failures)

	var affix_request := _request(&"uncommon")
	affix_request.forced_base_id = &"forge_vanguard_helmet"
	affix_request.required_affix_tags = [&"melee"]
	_assert_failure(ItemGenerationService.generate(affix_request, ISSUER_NAMESPACE, 5, equipment, foundation), affix_request, &"affix", &"no_eligible_affix", failures)

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
