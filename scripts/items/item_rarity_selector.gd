class_name ItemRaritySelector
extends RefCounted

static func select(
	request: ItemGenerationRequest,
	foundation: ItemFoundationCatalog,
	trace: ItemGenerationTrace
) -> ItemRarityDefinition:
	var rejected: Dictionary = {}
	var candidates: Array[ItemRarityDefinition] = foundation.rarities.duplicate()
	if not request.forced_rarity_id.is_empty():
		var forced := foundation.rarity(request.forced_rarity_id)
		if forced == null:
			rejected[request.forced_rarity_id] = "unknown_forced_rarity"
			trace.record(&"rarity", [], rejected, {}, &"")
			return null
	candidates.sort_custom(func(left: ItemRarityDefinition, right: ItemRarityDefinition) -> bool:
		return String(left.id) < String(right.id)
	)

	var eligible: Array[StringName] = []
	var weights: Dictionary = {}
	var definitions_by_id: Dictionary = {}
	for rarity: ItemRarityDefinition in candidates:
		if rarity == null:
			continue
		var rejection := ItemGenerationEligibility.rarity_rejection(rarity, request)
		if not rejection.is_empty():
			rejected[rarity.id] = rejection
			continue
		var weight := ItemGenerationWeightPolicy.rarity_weight(rarity, request)
		eligible.append(rarity.id)
		weights[rarity.id] = weight
		definitions_by_id[rarity.id] = rarity

	var selected_id := ItemDeterministicRandom.weighted_id(
		request.seed,
		request.generation_sequence,
		&"rarity",
		0,
		weights
	)
	trace.record(&"rarity", eligible, rejected, weights, selected_id)
	return definitions_by_id.get(selected_id) as ItemRarityDefinition
