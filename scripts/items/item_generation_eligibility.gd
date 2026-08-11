class_name ItemGenerationEligibility
extends RefCounted

static func base_rejection(base: EquipmentBaseDefinition, request: ItemGenerationRequest) -> String:
	if base == null:
		return "missing_base"
	if request == null:
		return "missing_request"
	if not request.forced_base_id.is_empty() and base.id != request.forced_base_id:
		return "forced_base_mismatch"
	var tags := base.normalized_generation_tags()
	if request.required_base_tags.any(func(tag: StringName) -> bool: return tag not in tags):
		return "missing_required_tag"
	if request.excluded_base_tags.any(func(tag: StringName) -> bool: return tag in tags):
		return "excluded_tag"
	var weight := ItemGenerationWeightPolicy.base_weight(base, request)
	if not is_finite(weight) or weight <= 0.0:
		return "invalid_weight"
	return ""

static func rarity_rejection(rarity: ItemRarityDefinition, request: ItemGenerationRequest) -> String:
	if rarity == null:
		return "missing_rarity"
	if request == null:
		return "missing_request"
	if not rarity.instance_supported:
		return "instance_unsupported"
	if rarity.id not in request.permitted_rarity_ids:
		return "not_permitted"
	if not rarity.ordinary_generation_enabled:
		return "ordinary_generation_disabled"
	if rarity.required_unlock_tags.any(func(tag: StringName) -> bool: return tag not in request.unlock_tags):
		return "missing_unlock_tag"
	if not request.forced_rarity_id.is_empty() and rarity.id != request.forced_rarity_id:
		return "forced_rarity_mismatch"
	var weight := ItemGenerationWeightPolicy.rarity_weight(rarity, request)
	if not is_finite(weight) or weight <= 0.0:
		return "invalid_weight"
	return ""

static func pattern_rejection(pattern: ItemAffixPatternDefinition, request: ItemGenerationRequest) -> String:
	if pattern == null:
		return "missing_pattern"
	if request == null:
		return "missing_request"
	if not pattern.allowed_generation_domains.is_empty() and request.generation_domain not in pattern.allowed_generation_domains:
		return "domain_not_allowed"
	if not is_finite(pattern.weight) or pattern.weight <= 0.0:
		return "invalid_weight"
	return ""

static func affix_rejection(
	definition: ItemAffixDefinition,
	request: ItemGenerationRequest,
	base_tags: Array[StringName],
	rarity_id: StringName,
	blocked_ids: Dictionary,
	blocked_families: Dictionary
) -> String:
	if definition == null:
		return "missing_affix"
	if request == null:
		return "missing_request"
	if blocked_ids.has(definition.id):
		return "duplicate_definition"
	for family_id: StringName in definition.modifier_family_ids:
		if blocked_families.has(family_id):
			return "blocked_family"
	if definition.required_item_tags.any(func(tag: StringName) -> bool: return tag not in base_tags):
		return "missing_required_item_tag"
	if definition.excluded_item_tags.any(func(tag: StringName) -> bool: return tag in base_tags):
		return "excluded_item_tag"
	if request.required_affix_tags.any(func(tag: StringName) -> bool: return tag not in base_tags):
		return "missing_required_request_tag"
	if request.excluded_affix_tags.any(func(tag: StringName) -> bool: return tag in base_tags):
		return "excluded_request_tag"
	if not definition.allowed_generation_domains.is_empty() and request.generation_domain not in definition.allowed_generation_domains:
		return "domain_not_allowed"
	if not definition.allowed_source_ids.is_empty() and request.source_id not in definition.allowed_source_ids:
		return "source_not_allowed"
	if not definition.allowed_rarity_ids.is_empty() and rarity_id not in definition.allowed_rarity_ids:
		return "rarity_not_allowed"
	if definition.required_unlock_tags.any(func(tag: StringName) -> bool: return tag not in request.unlock_tags):
		return "missing_unlock_tag"
	if eligible_tiers(definition, request, rarity_id).is_empty():
		return "no_eligible_tier"
	return ""

static func eligible_tiers(
	definition: ItemAffixDefinition,
	request: ItemGenerationRequest,
	rarity_id: StringName
) -> Array[ItemAffixTierDefinition]:
	var eligible: Array[ItemAffixTierDefinition] = []
	if definition == null or request == null:
		return eligible
	for tier: ItemAffixTierDefinition in definition.tiers:
		if tier == null:
			continue
		if request.item_level < tier.minimum_item_level:
			continue
		if not tier.allowed_rarity_ids.is_empty() and rarity_id not in tier.allowed_rarity_ids:
			continue
		if not tier.allowed_source_ids.is_empty() and request.source_id not in tier.allowed_source_ids:
			continue
		if not tier.allowed_generation_domains.is_empty() and request.generation_domain not in tier.allowed_generation_domains:
			continue
		var weight := ItemGenerationWeightPolicy.tier_weight(tier, request)
		if not is_finite(weight) or weight <= 0.0:
			continue
		eligible.append(tier)
	eligible.sort_custom(func(left: ItemAffixTierDefinition, right: ItemAffixTierDefinition) -> bool:
		return left.tier < right.tier
	)
	return eligible
