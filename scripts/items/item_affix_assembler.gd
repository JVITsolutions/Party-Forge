class_name ItemAffixAssembler
extends RefCounted

static func assemble(
	request: ItemGenerationRequest,
	base: EquipmentBaseDefinition,
	rarity: ItemRarityDefinition,
	pattern: ItemAffixPatternDefinition,
	foundation: ItemFoundationCatalog,
	trace: ItemGenerationTrace
) -> ItemAffixAssemblyResult:
	if request == null or base == null or rarity == null or pattern == null or foundation == null or trace == null:
		return _failure(&"invalid_assembly_input", {})

	var assembled: Array[ItemAffixInstance] = []
	var blocked_ids: Dictionary = {}
	var blocked_families: Dictionary = {}
	var base_tags := base.normalized_generation_tags()

	for implicit_index: int in base.implicit_affix_ids.size():
		var implicit_id := base.implicit_affix_ids[implicit_index]
		var definition := foundation.affix(implicit_id)
		if definition == null:
			return _failure(&"unknown_implicit_affix", {"affix_id": String(implicit_id), "slot": implicit_index})
		if definition.affix_kind != "implicit":
			return _failure(&"invalid_implicit_affix", {"affix_id": String(implicit_id), "kind": definition.affix_kind, "slot": implicit_index})
		var rejection := ItemGenerationEligibility.affix_rejection(definition, request, base_tags, rarity.id, blocked_ids, blocked_families)
		if not rejection.is_empty():
			return _failure(&"invalid_implicit_affix", {"affix_id": String(implicit_id), "reason": rejection, "slot": implicit_index})
		var slot := "implicit:%d" % implicit_index
		var built := _build_instance(definition, request, rarity.id, slot, trace)
		if built.error_code != &"":
			return built
		assembled.append(built.affixes[0])
		_block_definition(definition, blocked_ids, blocked_families)

	for request_kind: String in ["prefix", "suffix", "special"]:
		var slot_count := _slot_count(pattern, request_kind)
		for slot_index: int in slot_count:
			var filled := _fill_explicit_slot(
				request_kind,
				slot_index,
				request,
				base_tags,
				rarity.id,
				foundation,
				blocked_ids,
				blocked_families,
				trace
			)
			if not filled.ok():
				return filled
			var instance := filled.affixes[0]
			assembled.append(instance)
			_block_definition(foundation.affix(instance.definition_id), blocked_ids, blocked_families)

	var result := ItemAffixAssemblyResult.new()
	result.affixes = assembled
	return result

static func _fill_explicit_slot(
	kind: String,
	slot_index: int,
	request: ItemGenerationRequest,
	base_tags: Array[StringName],
	rarity_id: StringName,
	foundation: ItemFoundationCatalog,
	blocked_ids: Dictionary,
	blocked_families: Dictionary,
	trace: ItemGenerationTrace
) -> ItemAffixAssemblyResult:
	var candidates := foundation.affixes.duplicate()
	candidates.sort_custom(func(left: ItemAffixDefinition, right: ItemAffixDefinition) -> bool:
		if left == null:
			return false
		if right == null:
			return true
		return String(left.id) < String(right.id)
	)
	var eligible: Array[StringName] = []
	var rejected: Dictionary = {}
	var weights: Dictionary = {}
	var definitions_by_id: Dictionary = {}
	for definition: ItemAffixDefinition in candidates:
		if definition == null:
			continue
		if definition.affix_kind != kind:
			continue
		var reason := ItemGenerationEligibility.affix_rejection(definition, request, base_tags, rarity_id, blocked_ids, blocked_families)
		if not reason.is_empty():
			rejected[definition.id] = reason
			continue
		var weight := ItemGenerationWeightPolicy.affix_weight(definition, request, base_tags)
		if not is_finite(weight) or weight <= 0.0:
			rejected[definition.id] = "invalid_weight"
			continue
		eligible.append(definition.id)
		weights[definition.id] = weight
		definitions_by_id[definition.id] = definition

	var slot := "%s:%d" % [kind, slot_index]
	var stage := StringName("affix:%s" % slot)
	if eligible.is_empty():
		trace.record(stage, eligible, rejected, weights, &"")
		return _failure(&"no_eligible_affix", {"kind": kind, "slot": slot_index})
	var total_weight := _affix_weight_total(eligible, weights)
	if not is_finite(total_weight) or total_weight <= 0.0:
		trace.record(stage, eligible, rejected, weights, &"")
		return _failure(&"invalid_affix_weight_total", {"kind": kind, "slot": slot_index})
	var selected_id := _weighted_affix_id(request, stage, eligible, weights, total_weight)
	trace.record(stage, eligible, rejected, weights, selected_id)
	var selected := definitions_by_id.get(selected_id) as ItemAffixDefinition
	if selected == null:
		return _failure(&"no_eligible_affix", {"kind": kind, "slot": slot_index})
	return _build_instance(selected, request, rarity_id, slot, trace)

static func _build_instance(
	definition: ItemAffixDefinition,
	request: ItemGenerationRequest,
	rarity_id: StringName,
	slot: String,
	trace: ItemGenerationTrace
) -> ItemAffixAssemblyResult:
	var tiers := ItemGenerationEligibility.eligible_tiers(definition, request, rarity_id)
	var eligible_ids: Array[StringName] = []
	var trace_weights: Dictionary = {}
	for tier: ItemAffixTierDefinition in tiers:
		var display_id := StringName(str(tier.tier))
		var weight := ItemGenerationWeightPolicy.tier_weight(tier, request)
		eligible_ids.append(display_id)
		trace_weights[display_id] = weight
	var stage := StringName("tier:%s:%s" % [slot, definition.id])
	var total_weight := _tier_weight_total(tiers, trace_weights)
	if not is_finite(total_weight) or total_weight <= 0.0:
		trace.record(stage, eligible_ids, {}, trace_weights, &"")
		return _failure(&"invalid_tier_weight_total", {"affix_id": String(definition.id), "slot": slot})
	var selected_tier := _weighted_tier(request, stage, tiers, trace_weights, total_weight)
	var selected_display_id := StringName(str(selected_tier.tier)) if selected_tier != null else &""
	trace.record(stage, eligible_ids, {}, trace_weights, selected_display_id)
	if selected_tier == null:
		return _failure(&"no_eligible_tier", {"affix_id": String(definition.id), "slot": slot})
	if definition.effects.is_empty():
		return _failure(&"invalid_affix_effects", {"affix_id": String(definition.id), "slot": slot})

	var instance := ItemAffixInstance.new()
	instance.definition_id = definition.id
	instance.affix_kind = definition.affix_kind
	instance.tier = selected_tier.tier
	for effect_index: int in definition.effects.size():
		var effect := definition.effects[effect_index]
		if effect == null:
			return _failure(&"invalid_affix_effects", {"affix_id": String(definition.id), "effect": effect_index, "slot": slot})
		var bounds := selected_tier.roll_bounds(effect_index)
		if not is_finite(bounds.x) or not is_finite(bounds.y) or bounds.x > bounds.y:
			return _failure(&"invalid_roll_bounds", {"affix_id": String(definition.id), "effect": effect_index, "slot": slot})
		var roll_stage := StringName("roll:%s:%s:%d" % [slot, definition.id, effect_index])
		var unit := ItemDeterministicRandom.unit(request.seed, request.generation_sequence, roll_stage, 0)
		var quality := ItemGenerationWeightPolicy.roll_quality(unit, request.charisma_value)
		var value := lerpf(bounds.x, bounds.y, quality)
		if effect.roll_step > 0.0:
			var minimum_index := ceili(bounds.x / effect.roll_step)
			var maximum_index := floori(bounds.y / effect.roll_step)
			if minimum_index > maximum_index:
				return _failure(&"invalid_roll_step_range", {
					"affix_id": String(definition.id),
					"effect": effect_index,
					"slot": slot,
					"minimum": bounds.x,
					"maximum": bounds.y,
					"roll_step": effect.roll_step,
				})
			var step_index := clampi(roundi(value / effect.roll_step), minimum_index, maximum_index)
			value = float(step_index) * effect.roll_step
		var roll := ItemModifierRoll.new()
		roll.stat_id = effect.stat_id
		roll.operation = effect.operation
		roll.value = value
		roll.required_tags = effect.required_tags.duplicate()
		instance.rolls.append(roll)

	var result := ItemAffixAssemblyResult.new()
	result.affixes = [instance]
	return result

static func _weighted_affix_id(
	request: ItemGenerationRequest,
	stage: StringName,
	ordered_ids: Array[StringName],
	weights: Dictionary,
	total_weight: float
) -> StringName:
	if ordered_ids.is_empty() or not is_finite(total_weight) or total_weight <= 0.0:
		return &""
	var target := ItemDeterministicRandom.unit(request.seed, request.generation_sequence, stage, 0) * total_weight
	var cumulative := 0.0
	for id: StringName in ordered_ids:
		cumulative += float(weights[id])
		if target < cumulative:
			return id
	return ordered_ids.back()

static func _weighted_tier(
	request: ItemGenerationRequest,
	stage: StringName,
	ordered_tiers: Array[ItemAffixTierDefinition],
	weights: Dictionary,
	total_weight: float
) -> ItemAffixTierDefinition:
	if ordered_tiers.is_empty() or not is_finite(total_weight) or total_weight <= 0.0:
		return null
	var target := ItemDeterministicRandom.unit(request.seed, request.generation_sequence, stage, 0) * total_weight
	var cumulative := 0.0
	for tier: ItemAffixTierDefinition in ordered_tiers:
		cumulative += float(weights[StringName(str(tier.tier))])
		if target < cumulative:
			return tier
	return ordered_tiers.back()

static func _affix_weight_total(ordered_ids: Array[StringName], weights: Dictionary) -> float:
	var total := 0.0
	for id: StringName in ordered_ids:
		total += float(weights[id])
		if not is_finite(total):
			return total
	return total

static func _tier_weight_total(ordered_tiers: Array[ItemAffixTierDefinition], weights: Dictionary) -> float:
	var total := 0.0
	for tier: ItemAffixTierDefinition in ordered_tiers:
		total += float(weights[StringName(str(tier.tier))])
		if not is_finite(total):
			return total
	return total

static func _block_definition(definition: ItemAffixDefinition, blocked_ids: Dictionary, blocked_families: Dictionary) -> void:
	blocked_ids[definition.id] = true
	for family_id: StringName in definition.modifier_family_ids:
		blocked_families[family_id] = true

static func _slot_count(pattern: ItemAffixPatternDefinition, kind: String) -> int:
	match kind:
		"prefix":
			return pattern.prefix_count
		"suffix":
			return pattern.suffix_count
		"special":
			return pattern.special_count
	return 0

static func _failure(code: StringName, failure_details: Dictionary) -> ItemAffixAssemblyResult:
	var result := ItemAffixAssemblyResult.new()
	result.error_code = code
	result.details = failure_details.duplicate(true)
	return result
