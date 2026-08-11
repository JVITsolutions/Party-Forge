class_name ItemGenerationAnalysis
extends RefCounted

const REQUEST_SCOPE_REJECTIONS: Array[String] = [
	"domain_not_allowed",
	"excluded_item_tag",
	"excluded_request_tag",
	"excluded_tag",
	"forced_base_mismatch",
	"forced_rarity_mismatch",
	"missing_required_item_tag",
	"missing_required_request_tag",
	"missing_required_tag",
	"not_permitted",
	"rarity_not_allowed",
	"source_not_allowed",
]

static func selection_opportunities(trace: ItemGenerationTrace) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if trace == null:
		return result
	for stage_value: Variant in trace.stages:
		var stage := stage_value as Dictionary
		var weights := (stage.get("weights", {}) as Dictionary).duplicate(true)
		var expected := _expected(weights)
		var row: Dictionary = {
			"details": ItemGenerationTrace.canonical_json_copy(stage.get("details", {})),
			"eligible": ItemGenerationTrace.canonical_json_copy(stage.get("eligible", [])),
			"expected": expected,
			"rejected": ItemGenerationTrace.canonical_json_copy(stage.get("rejected", {})),
			"selected": String(stage.get("selected", "")),
			"stage": String(stage.get("stage", "")),
			"valid": not expected.is_empty(),
			"weights": weights,
		}
		if expected.is_empty():
			row["invalid_reason"] = "no_positive_finite_weight"
		result.append(row)
	return result

static func request_reachability(
	request: ItemGenerationRequest,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> Dictionary:
	if request == null:
		return _empty_reachability("request is missing")
	if equipment == null:
		return _empty_reachability("equipment catalog is missing")
	if foundation == null:
		return _empty_reachability("foundation catalog is missing")
	var validation_error := request.validate(foundation)
	if not validation_error.is_empty():
		return _empty_reachability(validation_error)

	var structurally_unreachable: Array[Dictionary] = []
	var not_applicable: Array[Dictionary] = []
	var eligible_bases: Array[EquipmentBaseDefinition] = []
	for base: EquipmentBaseDefinition in _sorted_bases(equipment.definitions):
		var rejection := ItemGenerationEligibility.base_rejection(base, request)
		if rejection.is_empty():
			eligible_bases.append(base)
		else:
			_append_diagnostic(not_applicable if rejection in REQUEST_SCOPE_REJECTIONS else structurally_unreachable, "base", String(base.id), rejection)
	if not request.forced_base_id.is_empty() and equipment.definition(request.forced_base_id) == null:
		_append_diagnostic(structurally_unreachable, "base", String(request.forced_base_id), "unknown_forced_base")

	var eligible_rarities: Array[ItemRarityDefinition] = []
	for rarity: ItemRarityDefinition in _sorted_rarities(foundation.rarities):
		var rejection := ItemGenerationEligibility.rarity_rejection(rarity, request)
		if rejection.is_empty():
			eligible_rarities.append(rarity)
		else:
			_append_diagnostic(not_applicable if rejection in REQUEST_SCOPE_REJECTIONS else structurally_unreachable, "rarity", String(rarity.id), rejection)

	var pattern_rows := _pattern_rows(request, eligible_bases, eligible_rarities, foundation, not_applicable)
	var tier_rows := _tier_rows(request, eligible_rarities, foundation)
	var reachable_affixes: Array[String] = []
	for definition: ItemAffixDefinition in _sorted_affixes(foundation.affixes):
		var path := _affix_path(definition, request, eligible_bases, eligible_rarities, foundation)
		if bool(path.get("reachable", false)):
			reachable_affixes.append(String(definition.id))
			continue
		var first_rejection := String(path.get("first_rejection", ""))
		if first_rejection in REQUEST_SCOPE_REJECTIONS:
			_append_diagnostic(not_applicable, "affix", String(definition.id), first_rejection)
		else:
			_append_diagnostic(structurally_unreachable, "affix", String(definition.id), "no_generation_path")

	var eligible_base_ids: Array[String] = []
	for base: EquipmentBaseDefinition in eligible_bases:
		eligible_base_ids.append(String(base.id))
	var eligible_rarity_ids: Array[String] = []
	for rarity: ItemRarityDefinition in eligible_rarities:
		eligible_rarity_ids.append(String(rarity.id))
	return ItemGenerationTrace.canonical_json_copy({
		"eligible_base_ids": eligible_base_ids,
		"eligible_rarity_ids": eligible_rarity_ids,
		"error": "",
		"not_applicable": not_applicable,
		"pattern_rows": pattern_rows,
		"reachable_affixes": reachable_affixes,
		"structurally_unreachable": structurally_unreachable,
		"tier_rows": tier_rows,
	}) as Dictionary

static func _expected(weights: Dictionary) -> Dictionary:
	var total := 0.0
	for value: Variant in weights.values():
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		var weight := float(value)
		if is_finite(weight) and weight > 0.0:
			total += weight
	var result: Dictionary = {}
	if total <= 0.0 or not is_finite(total):
		return result
	var keys: Array[String] = []
	for key: Variant in weights:
		keys.append(String(key))
	keys.sort()
	for key: String in keys:
		var value: Variant = weights[key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		var weight := float(value)
		if is_finite(weight) and weight > 0.0:
			result[key] = weight / total
	return result

static func _pattern_rows(
	request: ItemGenerationRequest,
	bases: Array[EquipmentBaseDefinition],
	rarities: Array[ItemRarityDefinition],
	foundation: ItemFoundationCatalog,
	not_applicable: Array[Dictionary]
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for base: EquipmentBaseDefinition in bases:
		var blocks := _implicit_blocks(base, foundation)
		var blocked_ids := blocks["ids"] as Dictionary
		var blocked_families := blocks["families"] as Dictionary
		var base_tags := base.normalized_generation_tags()
		for rarity: ItemRarityDefinition in rarities:
			for pattern: ItemAffixPatternDefinition in _sorted_patterns(rarity.patterns):
				var pattern_rejection := ItemGenerationEligibility.pattern_rejection(pattern, request)
				var counts := {"prefix": 0, "special": 0, "suffix": 0}
				var reasons: Array[String] = []
				if not pattern_rejection.is_empty():
					reasons.append(pattern_rejection)
					_append_diagnostic(not_applicable, "pattern", String(pattern.id), pattern_rejection)
				else:
					for definition: ItemAffixDefinition in _sorted_affixes(foundation.affixes):
						if definition.affix_kind not in ["prefix", "suffix", "special"]:
							continue
						var rejection := ItemGenerationEligibility.affix_rejection(definition, request, base_tags, rarity.id, blocked_ids, blocked_families)
						if not rejection.is_empty():
							continue
						var weight := ItemGenerationWeightPolicy.affix_weight(definition, request, base_tags)
						if not is_finite(weight) or weight <= 0.0:
							continue
						counts[definition.affix_kind] = int(counts[definition.affix_kind]) + 1
					for kind: String in ["prefix", "suffix", "special"]:
						if int(counts[kind]) < _pattern_count(pattern, kind):
							reasons.append("insufficient_%s_candidates" % kind)
				rows.append({
					"base_id": String(base.id),
					"eligible_candidate_counts": counts,
					"pattern_id": String(pattern.id),
					"rarity_id": String(rarity.id),
					"reasons": reasons,
					"required_counts": {
						"prefix": pattern.prefix_count,
						"special": pattern.special_count,
						"suffix": pattern.suffix_count,
					},
					"viable": reasons.is_empty(),
				})
	return rows

static func _tier_rows(
	request: ItemGenerationRequest,
	rarities: Array[ItemRarityDefinition],
	foundation: ItemFoundationCatalog
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for definition: ItemAffixDefinition in _sorted_affixes(foundation.affixes):
		var tiers := definition.tiers.duplicate()
		tiers.sort_custom(func(left: ItemAffixTierDefinition, right: ItemAffixTierDefinition) -> bool:
			if left == null:
				return false
			if right == null:
				return true
			return left.tier < right.tier
		)
		for rarity: ItemRarityDefinition in rarities:
			var eligible := ItemGenerationEligibility.eligible_tiers(definition, request, rarity.id)
			for tier: ItemAffixTierDefinition in tiers:
				if tier == null:
					continue
				var is_eligible := tier in eligible
				rows.append({
					"affix_id": String(definition.id),
					"eligible": is_eligible,
					"minimum_item_level": tier.minimum_item_level,
					"rarity_id": String(rarity.id),
					"rejection": "" if is_eligible else "tier_gate",
					"tier": tier.tier,
					"weight": ItemGenerationWeightPolicy.tier_weight(tier, request),
				})
	return rows

static func _affix_path(
	definition: ItemAffixDefinition,
	request: ItemGenerationRequest,
	bases: Array[EquipmentBaseDefinition],
	rarities: Array[ItemRarityDefinition],
	foundation: ItemFoundationCatalog
) -> Dictionary:
	var first_rejection := ""
	for base: EquipmentBaseDefinition in bases:
		var base_tags := base.normalized_generation_tags()
		var blocks := _implicit_blocks(base, foundation)
		var blocked_ids := blocks["ids"] as Dictionary
		var blocked_families := blocks["families"] as Dictionary
		for rarity: ItemRarityDefinition in rarities:
			var reason := ItemGenerationEligibility.affix_rejection(
				definition,
				request,
				base_tags,
				rarity.id,
				{} if definition.affix_kind == "implicit" else blocked_ids,
				{} if definition.affix_kind == "implicit" else blocked_families
			)
			if not reason.is_empty():
				if first_rejection.is_empty():
					first_rejection = reason
				continue
			if definition.affix_kind == "implicit":
				if definition.id in base.implicit_affix_ids:
					return {"reachable": true}
				continue
			var weight := ItemGenerationWeightPolicy.affix_weight(definition, request, base_tags)
			if not is_finite(weight) or weight <= 0.0:
				if first_rejection.is_empty():
					first_rejection = "invalid_weight"
				continue
			for pattern: ItemAffixPatternDefinition in _sorted_patterns(rarity.patterns):
				if not ItemGenerationEligibility.pattern_rejection(pattern, request).is_empty():
					continue
				if _pattern_count(pattern, definition.affix_kind) > 0:
					return {"reachable": true}
	return {"first_rejection": first_rejection, "reachable": false}

static func _implicit_blocks(base: EquipmentBaseDefinition, foundation: ItemFoundationCatalog) -> Dictionary:
	var ids: Dictionary = {}
	var families: Dictionary = {}
	for implicit_id: StringName in base.implicit_affix_ids:
		var definition := foundation.affix(implicit_id)
		if definition == null:
			continue
		ids[definition.id] = true
		for family_id: StringName in definition.modifier_family_ids:
			families[family_id] = true
	return {"families": families, "ids": ids}

static func _pattern_count(pattern: ItemAffixPatternDefinition, kind: String) -> int:
	match kind:
		"prefix": return pattern.prefix_count
		"suffix": return pattern.suffix_count
		"special": return pattern.special_count
	return 0

static func _append_diagnostic(rows: Array[Dictionary], kind: String, id: String, reason: String) -> void:
	var candidate := {"id": id, "kind": kind, "reason": reason}
	if candidate not in rows:
		rows.append(candidate)

static func _empty_reachability(error: String) -> Dictionary:
	return {
		"eligible_base_ids": [],
		"eligible_rarity_ids": [],
		"error": error,
		"not_applicable": [],
		"pattern_rows": [],
		"reachable_affixes": [],
		"structurally_unreachable": [],
		"tier_rows": [],
	}

static func _sorted_bases(values: Array[EquipmentBaseDefinition]) -> Array[EquipmentBaseDefinition]:
	var result := values.duplicate()
	result.sort_custom(func(left: EquipmentBaseDefinition, right: EquipmentBaseDefinition) -> bool:
		if left == null:
			return false
		if right == null:
			return true
		return String(left.id) < String(right.id)
	)
	return result

static func _sorted_rarities(values: Array[ItemRarityDefinition]) -> Array[ItemRarityDefinition]:
	var result := values.duplicate()
	result.sort_custom(func(left: ItemRarityDefinition, right: ItemRarityDefinition) -> bool:
		if left == null:
			return false
		if right == null:
			return true
		return String(left.id) < String(right.id)
	)
	return result

static func _sorted_patterns(values: Array[ItemAffixPatternDefinition]) -> Array[ItemAffixPatternDefinition]:
	var result := values.duplicate()
	result.sort_custom(func(left: ItemAffixPatternDefinition, right: ItemAffixPatternDefinition) -> bool:
		if left == null:
			return false
		if right == null:
			return true
		return String(left.id) < String(right.id)
	)
	return result

static func _sorted_affixes(values: Array[ItemAffixDefinition]) -> Array[ItemAffixDefinition]:
	var result := values.duplicate()
	result.sort_custom(func(left: ItemAffixDefinition, right: ItemAffixDefinition) -> bool:
		if left == null:
			return false
		if right == null:
			return true
		return String(left.id) < String(right.id)
	)
	return result
