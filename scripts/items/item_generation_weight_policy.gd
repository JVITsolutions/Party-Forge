class_name ItemGenerationWeightPolicy
extends RefCounted

const PARTY_MATCH_MULTIPLIER := 3.0
const ACCESSORY_AFFINITY_MULTIPLIER := 1.35
const MAX_ITEM_LEVEL := 1000

static func progress(item_level: int) -> float:
	return clampf(float(item_level - 1) / float(MAX_ITEM_LEVEL - 1), 0.0, 1.0)

static func diminishing_charisma(charisma: float) -> float:
	var value := maxf(charisma, 0.0)
	return value / (value + 100.0) if value > 0.0 else 0.0

static func base_weight(base: EquipmentBaseDefinition, request: ItemGenerationRequest) -> float:
	var weight := base.generation_weight
	var tags := base.normalized_generation_tags()
	if request.party_archetype_tags.any(func(tag: StringName) -> bool: return tag in tags):
		weight *= PARTY_MATCH_MULTIPLIER
	return weight

static func rarity_weight(rarity: ItemRarityDefinition, request: ItemGenerationRequest) -> float:
	return rarity.base_weight * (1.0 + progress(request.item_level) * float(rarity.rarity_rank - 1) * 0.15) * (1.0 + maxf(request.heat, 0.0) * float(rarity.rarity_rank - 1) * 0.01)

static func affix_weight(
	affix: ItemAffixDefinition,
	request: ItemGenerationRequest,
	base_tags: Array[StringName] = []
) -> float:
	var scarcity := clampf((1000.0 - minf(affix.base_weight, 1000.0)) / 1000.0, 0.0, 1.0)
	var weight := affix.base_weight * (1.0 + progress(request.item_level) * 0.75 * scarcity) * (1.0 + diminishing_charisma(request.charisma_value) * 0.25 * scarcity)
	if &"accessory" in base_tags and affix.affinity_tags.any(func(tag: StringName) -> bool: return tag in base_tags):
		weight *= ACCESSORY_AFFINITY_MULTIPLIER
	return weight

static func tier_weight(tier: ItemAffixTierDefinition, request: ItemGenerationRequest) -> float:
	return tier.base_weight * (1.0 + progress(request.item_level) * float(tier.tier - 1) * 0.20)

static func roll_quality(base_unit: float, charisma: float) -> float:
	return 1.0 - pow(1.0 - clampf(base_unit, 0.0, 1.0), 1.0 + 0.25 * diminishing_charisma(charisma))
