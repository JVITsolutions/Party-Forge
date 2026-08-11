class_name ItemPatternSelector
extends RefCounted

static func select(
	request: ItemGenerationRequest,
	rarity: ItemRarityDefinition,
	trace: ItemGenerationTrace
) -> ItemAffixPatternDefinition:
	var rejected: Dictionary = {}
	var candidates: Array[ItemAffixPatternDefinition] = rarity.patterns.duplicate()
	candidates.sort_custom(func(left: ItemAffixPatternDefinition, right: ItemAffixPatternDefinition) -> bool:
		return String(left.id) < String(right.id)
	)

	var eligible: Array[StringName] = []
	var weights: Dictionary = {}
	var definitions_by_id: Dictionary = {}
	for pattern: ItemAffixPatternDefinition in candidates:
		if pattern == null:
			continue
		var rejection := ItemGenerationEligibility.pattern_rejection(pattern, request)
		if not rejection.is_empty():
			rejected[pattern.id] = rejection
			continue
		eligible.append(pattern.id)
		weights[pattern.id] = pattern.weight
		definitions_by_id[pattern.id] = pattern

	var stage_salt := StringName("pattern:%s" % rarity.id)
	var selected_id := ItemDeterministicRandom.weighted_id(
		request.seed,
		request.generation_sequence,
		stage_salt,
		0,
		weights
	)
	if eligible.is_empty():
		rejected[rarity.id] = "no_eligible_pattern"
	trace.record(&"pattern", eligible, rejected, weights, selected_id)
	return definitions_by_id.get(selected_id) as ItemAffixPatternDefinition
