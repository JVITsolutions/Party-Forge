class_name ItemBaseSelector
extends RefCounted

static func select(
	request: ItemGenerationRequest,
	equipment: EquipmentCatalog,
	trace: ItemGenerationTrace
) -> EquipmentBaseDefinition:
	var rejected: Dictionary = {}
	var candidates: Array[EquipmentBaseDefinition] = []
	if not request.forced_base_id.is_empty():
		var forced := equipment.definition(request.forced_base_id)
		if forced == null:
			rejected[request.forced_base_id] = "unknown_forced_base"
			trace.record(&"base", [], rejected, {}, &"")
			return null
		candidates.append(forced)
	else:
		candidates = equipment.definitions.duplicate()
	candidates.sort_custom(func(left: EquipmentBaseDefinition, right: EquipmentBaseDefinition) -> bool:
		return String(left.id) < String(right.id)
	)

	var eligible: Array[StringName] = []
	var weights: Dictionary = {}
	var definitions_by_id: Dictionary = {}
	for base: EquipmentBaseDefinition in candidates:
		if base == null:
			continue
		var rejection := ItemGenerationEligibility.base_rejection(base, request)
		if not rejection.is_empty():
			rejected[base.id] = rejection
			continue
		var weight := ItemGenerationWeightPolicy.base_weight(base, request)
		eligible.append(base.id)
		weights[base.id] = weight
		definitions_by_id[base.id] = base

	var selected_id := ItemDeterministicRandom.weighted_id(
		request.seed,
		request.generation_sequence,
		&"base",
		0,
		weights
	)
	trace.record(&"base", eligible, rejected, weights, selected_id)
	return definitions_by_id.get(selected_id) as EquipmentBaseDefinition
