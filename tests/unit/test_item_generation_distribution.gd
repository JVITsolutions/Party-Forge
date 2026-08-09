extends RefCounted

const BATCH_SIZE := 5000
const PIPELINE_REPLAY_HASH := "2eee553b990823f87038db64aac90ce02a844e6da16bddeb19d4bd76ed3ce044"
const TIER_REPLAY_HASH := "876b63e583cb4b3b67a495b7f96b372075e7e533bdbea7e3ce0246c0d023b57a"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_live_pipeline_replay_and_hard_gates(failures)
	_test_item_level_tier_direction(failures)
	_test_charisma_rare_family_direction(failures)
	_test_party_base_bias_direction(failures)
	return failures

func _test_live_pipeline_replay_and_hard_gates(failures: Array[String]) -> void:
	var first := _live_pipeline_batch(failures)
	var replay := _live_pipeline_batch(failures)
	TestAssertions.equal(first, replay, "5,000-stage batch replays exactly", failures)
	TestAssertions.equal(first, PIPELINE_REPLAY_HASH, "5,000-stage batch has exact golden hash", failures)

func _live_pipeline_batch(failures: Array[String]) -> String:
	var foundation := load("res://data/items/core_item_foundation_catalog.tres") as ItemFoundationCatalog
	var equipment := load("res://data/equipment/core_equipment_catalog.tres") as EquipmentCatalog
	var records: Array[Dictionary] = []
	for sequence: int in BATCH_SIZE:
		var request := ItemGenerationRequest.create(
			807031,
			sequence,
			1 + (sequence % ItemGenerationRequest.MAX_ITEM_LEVEL),
			&"ordinary_enemy",
			&"ordinary_drop",
			foundation.ordinary_rarity_ids()
		)
		request.unlock_tags = [&"rarity_rare_unlocked", &"rarity_epic_unlocked", &"rarity_legendary_unlocked"]
		request.charisma_value = 75.0
		var trace := ItemGenerationTrace.new()
		var base := ItemBaseSelector.select(request, equipment, trace)
		var rarity := ItemRaritySelector.select(request, foundation, trace)
		var pattern := ItemPatternSelector.select(request, rarity, trace) if rarity != null else null
		var assembled := ItemAffixAssembler.assemble(request, base, rarity, pattern, foundation, trace)
		TestAssertions.truthy(base != null and rarity != null and pattern != null and assembled.ok(), "pipeline selection %d succeeds without issuance" % sequence, failures)
		if base == null or rarity == null or pattern == null or not assembled.ok():
			continue
		_audit_hard_gates(request, base, rarity, pattern, assembled.affixes, foundation, failures)
		var affix_rows: Array[Dictionary] = []
		for instance: ItemAffixInstance in assembled.affixes:
			affix_rows.append({"id": String(instance.definition_id), "kind": instance.affix_kind, "tier": instance.tier})
		records.append({
			"base": String(base.id),
			"rarity": String(rarity.id),
			"pattern": String(pattern.id),
			"affixes": affix_rows,
		})
	return JSON.stringify(records).sha256_text()

func _audit_hard_gates(
	request: ItemGenerationRequest,
	base: EquipmentBaseDefinition,
	rarity: ItemRarityDefinition,
	pattern: ItemAffixPatternDefinition,
	instances: Array[ItemAffixInstance],
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var base_tags := base.normalized_generation_tags()
	TestAssertions.truthy(request.required_base_tags.all(func(tag: StringName) -> bool: return tag in base_tags), "selected base passes required tags", failures)
	TestAssertions.truthy(request.excluded_base_tags.all(func(tag: StringName) -> bool: return tag not in base_tags), "selected base passes excluded tags", failures)
	TestAssertions.truthy(rarity.instance_supported and rarity.ordinary_generation_enabled, "selected rarity is ordinary-supported", failures)
	TestAssertions.truthy(rarity.id in request.permitted_rarity_ids, "selected rarity is permitted", failures)
	TestAssertions.truthy(rarity.required_unlock_tags.all(func(tag: StringName) -> bool: return tag in request.unlock_tags), "selected rarity passes unlocks", failures)
	TestAssertions.truthy(pattern in rarity.patterns, "selected pattern belongs to rarity", failures)
	TestAssertions.truthy(pattern.allowed_generation_domains.is_empty() or request.generation_domain in pattern.allowed_generation_domains, "selected pattern passes domain", failures)
	var explicit_counts := {"prefix": 0, "suffix": 0, "special": 0}
	var blocked_families: Dictionary = {}
	for instance: ItemAffixInstance in instances:
		var definition := foundation.affix(instance.definition_id)
		TestAssertions.truthy(definition != null, "selected affix is registered", failures)
		if definition == null:
			continue
		if instance.affix_kind == "implicit":
			TestAssertions.truthy(instance.definition_id in base.implicit_affix_ids, "selected implicit belongs to base", failures)
		else:
			explicit_counts[instance.affix_kind] = int(explicit_counts.get(instance.affix_kind, 0)) + 1
		TestAssertions.truthy(definition.required_item_tags.all(func(tag: StringName) -> bool: return tag in base_tags), "selected affix passes required item tags", failures)
		TestAssertions.truthy(definition.excluded_item_tags.all(func(tag: StringName) -> bool: return tag not in base_tags), "selected affix passes excluded item tags", failures)
		TestAssertions.truthy(request.required_affix_tags.all(func(tag: StringName) -> bool: return tag in base_tags), "selected affix passes request-required tags", failures)
		TestAssertions.truthy(request.excluded_affix_tags.all(func(tag: StringName) -> bool: return tag not in base_tags), "selected affix passes request-excluded tags", failures)
		TestAssertions.truthy(definition.allowed_generation_domains.is_empty() or request.generation_domain in definition.allowed_generation_domains, "selected affix passes domain", failures)
		TestAssertions.truthy(definition.allowed_source_ids.is_empty() or request.source_id in definition.allowed_source_ids, "selected affix passes source", failures)
		TestAssertions.truthy(definition.allowed_rarity_ids.is_empty() or rarity.id in definition.allowed_rarity_ids, "selected affix passes rarity", failures)
		TestAssertions.truthy(definition.required_unlock_tags.all(func(tag: StringName) -> bool: return tag in request.unlock_tags), "selected affix passes unlocks", failures)
		for family_id: StringName in definition.modifier_family_ids:
			TestAssertions.truthy(not blocked_families.has(family_id), "selected affix family is not duplicated", failures)
			blocked_families[family_id] = true
		var tier := definition.tier_definition(instance.tier)
		TestAssertions.truthy(tier != null, "selected tier is registered", failures)
		if tier != null:
			TestAssertions.truthy(tier.minimum_item_level <= request.item_level, "selected tier passes item level", failures)
			TestAssertions.truthy(tier.allowed_rarity_ids.is_empty() or rarity.id in tier.allowed_rarity_ids, "selected tier passes rarity", failures)
			TestAssertions.truthy(tier.allowed_source_ids.is_empty() or request.source_id in tier.allowed_source_ids, "selected tier passes source", failures)
			TestAssertions.truthy(tier.allowed_generation_domains.is_empty() or request.generation_domain in tier.allowed_generation_domains, "selected tier passes domain", failures)
			TestAssertions.equal(instance.rolls.size(), definition.effects.size(), "selected affix has one roll per effect", failures)
			for effect_index: int in mini(instance.rolls.size(), definition.effects.size()):
				var bounds := tier.roll_bounds(effect_index)
				var roll := instance.rolls[effect_index]
				TestAssertions.truthy(roll.value >= bounds.x and roll.value <= bounds.y, "selected roll stays inside tier bounds", failures)
				TestAssertions.equal(roll.stat_id, definition.effects[effect_index].stat_id, "selected roll keeps effect stat", failures)
				TestAssertions.equal(roll.operation, definition.effects[effect_index].operation, "selected roll keeps effect operation", failures)
	TestAssertions.equal(int(explicit_counts["prefix"]), pattern.prefix_count, "selected prefix count matches pattern", failures)
	TestAssertions.equal(int(explicit_counts["suffix"]), pattern.suffix_count, "selected suffix count matches pattern", failures)
	TestAssertions.equal(int(explicit_counts["special"]), pattern.special_count, "selected special count matches pattern", failures)

func _test_item_level_tier_direction(failures: Array[String]) -> void:
	var low := _tier_batch(1)
	var high := _tier_batch(1000)
	TestAssertions.truthy(float(high["average"]) > float(low["average"]), "high item level trends upward", failures)
	TestAssertions.equal(high["hash"], TIER_REPLAY_HASH, "high-level tier batch has exact golden hash", failures)
	TestAssertions.equal(_tier_batch(1000)["hash"], high["hash"], "tier batch replays exactly", failures)

func _tier_batch(item_level: int) -> Dictionary:
	var tiers: Array[ItemAffixTierDefinition] = [
		_tier(1, 1, 100.0),
		_tier(2, 200, 40.0),
		_tier(3, 800, 10.0),
	]
	var selected_tiers: Array[int] = []
	var total := 0.0
	for sequence: int in BATCH_SIZE:
		var request := _request(sequence, item_level, 0.0)
		var weights: Dictionary = {}
		for tier: ItemAffixTierDefinition in tiers:
			if tier.minimum_item_level <= item_level:
				weights[StringName(str(tier.tier))] = ItemGenerationWeightPolicy.tier_weight(tier, request)
		var selected := int(String(ItemDeterministicRandom.weighted_id(request.seed, request.generation_sequence, &"tier:distribution", 0, weights)))
		selected_tiers.append(selected)
		total += selected
	return {"average": total / BATCH_SIZE, "hash": JSON.stringify(selected_tiers).sha256_text()}

func _test_charisma_rare_family_direction(failures: Array[String]) -> void:
	var zero_rate := _rare_family_rate(0.0)
	var charisma_100_rate := _rare_family_rate(100.0)
	var charisma_1000_rate := _rare_family_rate(1000.0)
	var charisma_100_gain := charisma_100_rate - zero_rate
	var charisma_1000_gain := charisma_1000_rate - zero_rate
	TestAssertions.truthy(charisma_100_rate > zero_rate, "Charisma 100 improves rare-family rate", failures)
	TestAssertions.truthy(charisma_1000_rate > charisma_100_rate, "Charisma 1000 improves beyond Charisma 100", failures)
	TestAssertions.truthy(charisma_1000_rate - charisma_100_rate < charisma_100_gain, "Charisma marginal gain diminishes", failures)
	TestAssertions.truthy(charisma_1000_gain < charisma_100_gain * 2.0, "total Charisma gains reflect diminishing returns", failures)

func _rare_family_rate(charisma: float) -> float:
	var affixes: Array[ItemAffixDefinition] = []
	affixes.append(_weighted_affix(&"common_family", 1000.0))
	for index: int in 5:
		affixes.append(_weighted_affix(StringName("rare_family_%d" % index), 10.0))
	var rare_count := 0
	for sequence: int in BATCH_SIZE:
		var request := _request(sequence, 1000, charisma)
		var weights: Dictionary = {}
		for affix: ItemAffixDefinition in affixes:
			weights[affix.id] = ItemGenerationWeightPolicy.affix_weight(affix, request)
		var selected := ItemDeterministicRandom.weighted_id(request.seed, request.generation_sequence, &"affix:distribution", 0, weights)
		if String(selected).begins_with("rare_family_"):
			rare_count += 1
	return float(rare_count) / BATCH_SIZE

func _test_party_base_bias_direction(failures: Array[String]) -> void:
	var catalog := EquipmentCatalog.new()
	catalog.definitions = [
		_base(&"melee_base", &"melee"),
		_base(&"caster_base", &"caster"),
		_base(&"global_base", &"global", false),
	]
	var neutral := _base_batch(catalog, [])
	var melee_party := _base_batch(catalog, [&"melee"])
	TestAssertions.truthy(int(melee_party["melee_count"]) > int(neutral["melee_count"]), "party bias increases matching bases", failures)
	TestAssertions.truthy(int(melee_party["off_count"]) > 0, "party bias preserves off-party drops", failures)
	TestAssertions.equal(_base_batch(catalog, [&"melee"])["hash"], melee_party["hash"], "party-bias batch replays exactly", failures)

func _base_batch(catalog: EquipmentCatalog, party_tags: Array[StringName]) -> Dictionary:
	var selected_ids: Array[String] = []
	var melee_count := 0
	var off_count := 0
	for sequence: int in BATCH_SIZE:
		var request := _request(sequence, 500, 0.0)
		request.party_archetype_tags = party_tags.duplicate()
		var selected := ItemBaseSelector.select(request, catalog, ItemGenerationTrace.new())
		selected_ids.append(String(selected.id))
		if selected.id == &"melee_base":
			melee_count += 1
		else:
			off_count += 1
	return {"melee_count": melee_count, "off_count": off_count, "hash": JSON.stringify(selected_ids).sha256_text()}

func _request(sequence: int, item_level: int, charisma: float) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(991733, sequence, item_level, &"ordinary_enemy", &"ordinary_drop", [&"common"])
	request.charisma_value = charisma
	return request

func _tier(number: int, minimum_level: int, weight: float) -> ItemAffixTierDefinition:
	var tier := ItemAffixTierDefinition.new()
	tier.tier = number
	tier.minimum_item_level = minimum_level
	tier.base_weight = weight
	tier.minimum_rolls = [0.0]
	tier.maximum_rolls = [1.0]
	return tier

func _weighted_affix(id: StringName, weight: float) -> ItemAffixDefinition:
	var affix := ItemAffixDefinition.new()
	affix.id = id
	affix.base_weight = weight
	return affix

func _base(id: StringName, archetype: StringName, restrict_to_archetype := true) -> EquipmentBaseDefinition:
	var base := EquipmentBaseDefinition.new()
	base.id = id
	base.generation_weight = 100.0
	base.generation_tags = [archetype]
	if restrict_to_archetype:
		base.required_any_tags = [archetype]
	return base
