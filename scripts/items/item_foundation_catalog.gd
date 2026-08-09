class_name ItemFoundationCatalog
extends Resource

const DEFAULT_REACHABILITY_EXPLORATION_BUDGET := 10000

@export var modifier_family_ids: Array[StringName] = []
@export var known_source_ids: Array[StringName] = []
@export var known_item_tags: Array[StringName] = []
@export var rarities: Array[ItemRarityDefinition] = []
@export var affixes: Array[ItemAffixDefinition] = []

func rarity(id: StringName) -> ItemRarityDefinition:
	for definition: ItemRarityDefinition in rarities:
		if definition != null and definition.id == id:
			return definition
	return null

func affix(id: StringName) -> ItemAffixDefinition:
	for definition: ItemAffixDefinition in affixes:
		if definition != null and definition.id == id:
			return definition
	return null

func supported_rarity_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: ItemRarityDefinition in rarities:
		if definition != null and definition.instance_supported:
			ids.append(definition.id)
	return ids

func ordinary_rarity_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: ItemRarityDefinition in rarities:
		if definition != null and definition.ordinary_generation_enabled:
			ids.append(definition.id)
	return ids

func generation_unlock_tags() -> Array[StringName]:
	var tags: Array[StringName] = []
	for rarity_definition: ItemRarityDefinition in rarities:
		if rarity_definition == null:
			continue
		for tag: StringName in rarity_definition.required_unlock_tags:
			if not tag.is_empty() and tag not in tags:
				tags.append(tag)
	for affix_definition: ItemAffixDefinition in affixes:
		if affix_definition == null:
			continue
		for tag: StringName in affix_definition.required_unlock_tags:
			if not tag.is_empty() and tag not in tags:
				tags.append(tag)
	tags.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return tags

func validate(
	stat_catalog: StatCatalog,
	equipment_catalog: EquipmentCatalog = null,
	reachability_exploration_budget: int = DEFAULT_REACHABILITY_EXPLORATION_BUDGET
) -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_registry(modifier_family_ids, "modifier family", errors)
	_validate_registry(known_source_ids, "source", errors)
	_validate_registry(known_item_tags, "item tag", errors)
	_validate_equipment_tags(equipment_catalog, errors)

	var known_rarities: Array[StringName] = []
	for definition: ItemRarityDefinition in rarities:
		if definition != null:
			known_rarities.append(definition.id)
	var seen_rarity_ids: Dictionary = {}
	var seen_paths: Dictionary = {}
	var previous_rank := 0
	for definition: ItemRarityDefinition in rarities:
		if definition == null:
			errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=<null> reason=definition missing")
			continue
		_validate_external_path(definition, "res://data/items/rarities/", "rarity", seen_paths, errors)
		if seen_rarity_ids.has(definition.id):
			errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s reason=duplicate id" % definition.id)
		else:
			seen_rarity_ids[definition.id] = true
		if definition.rarity_rank <= previous_rank:
			errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s reason=resource order must follow ascending rarity rank" % definition.id)
		previous_rank = definition.rarity_rank
		for reason: String in definition.validate():
			errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s reason=%s" % [definition.id, reason])
		_validate_patterns(definition, seen_paths, errors)
		if definition.ordinary_generation_enabled and definition.rarity_rank > 5:
			errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s reason=ordinary generation is limited to rarity ranks 1..5" % definition.id)

	var seen_affix_ids: Dictionary = {}
	for definition: ItemAffixDefinition in affixes:
		if definition == null:
			errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=<null> reason=definition missing")
			continue
		_validate_external_path(definition, "res://data/items/affixes/", "affix", seen_paths, errors)
		if seen_affix_ids.has(definition.id):
			errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=%s reason=duplicate id" % definition.id)
		else:
			seen_affix_ids[definition.id] = true
		for reason: String in definition.validate(
			stat_catalog,
			modifier_family_ids,
			ItemGenerationVocabulary.DOMAINS,
			known_source_ids,
			known_rarities,
			known_item_tags
		):
			errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=%s reason=%s" % [definition.id, reason])
		if not _has_reachable_tier(definition, &"", &"", &""):
			errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=%s reason=no tier is reachable at item level 1..1000" % definition.id)
	_validate_base_implicits(equipment_catalog, errors)
	_validate_ordinary_pattern_reachability(equipment_catalog, reachability_exploration_budget, errors)
	return errors

func _validate_registry(values: Array[StringName], label: String, errors: PackedStringArray) -> void:
	var seen: Dictionary = {}
	for value: StringName in values:
		if value.is_empty():
			errors.append("PARTY_FORGE_ITEM_MANIFEST_ERROR reason=%s id is empty" % label)
		elif seen.has(value):
			errors.append("PARTY_FORGE_ITEM_MANIFEST_ERROR reason=duplicate %s %s" % [label, value])
		else:
			seen[value] = true

func _live_equipment_tags(equipment_catalog: EquipmentCatalog) -> Array[StringName]:
	var result: Array[StringName] = []
	if equipment_catalog == null:
		return result
	for definition: EquipmentBaseDefinition in equipment_catalog.definitions:
		if definition == null:
			continue
		for tag: StringName in definition.normalized_generation_tags():
			if not tag.is_empty() and tag not in result:
				result.append(tag)
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result

func _validate_equipment_tags(equipment_catalog: EquipmentCatalog, errors: PackedStringArray) -> void:
	if equipment_catalog == null:
		return
	var live_item_tags := _live_equipment_tags(equipment_catalog)
	for tag: StringName in live_item_tags:
		if tag not in known_item_tags:
			errors.append("PARTY_FORGE_ITEM_MANIFEST_ERROR reason=missing current equipment item tag %s" % tag)
	for tag: StringName in known_item_tags:
		if tag not in live_item_tags:
			errors.append("PARTY_FORGE_ITEM_MANIFEST_ERROR reason=unknown current equipment item tag %s" % tag)

func _validate_base_implicits(equipment_catalog: EquipmentCatalog, errors: PackedStringArray) -> void:
	if equipment_catalog == null:
		return
	for base: EquipmentBaseDefinition in equipment_catalog.definitions:
		if base == null:
			continue
		for implicit_id: StringName in base.implicit_affix_ids:
			var definition := affix(implicit_id)
			if definition == null:
				errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=%s base=%s reason=unknown implicit affix reference" % [implicit_id, base.id])
			elif definition.affix_kind != "implicit":
				errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=%s base=%s reason=base implicit references affix kind %s" % [implicit_id, base.id, definition.affix_kind])

func _validate_ordinary_pattern_reachability(
	equipment_catalog: EquipmentCatalog,
	exploration_budget: int,
	errors: PackedStringArray
) -> void:
	if equipment_catalog == null:
		return
	var available_unlock_tags := generation_unlock_tags()
	for rarity_definition: ItemRarityDefinition in rarities:
		if rarity_definition == null or not rarity_definition.ordinary_generation_enabled:
			continue
		for pattern: ItemAffixPatternDefinition in rarity_definition.patterns:
			if pattern == null:
				continue
			var state := {"remaining": maxi(exploration_budget, 0), "exhausted": false}
			if _whole_pattern_is_reachable(rarity_definition.id, pattern, equipment_catalog, available_unlock_tags, state):
				continue
			if bool(state["exhausted"]):
				errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s pattern=%s reason=reachability exploration budget exhausted" % [rarity_definition.id, pattern.id])
			else:
				errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s pattern=%s reason=no complete live generation scenario" % [rarity_definition.id, pattern.id])

func _whole_pattern_is_reachable(
	rarity_id: StringName,
	pattern: ItemAffixPatternDefinition,
	equipment_catalog: EquipmentCatalog,
	available_unlock_tags: Array[StringName],
	budget: Dictionary
) -> bool:
	var domains := pattern.allowed_generation_domains.duplicate()
	if domains.is_empty():
		domains = ItemGenerationVocabulary.DOMAINS.duplicate()
	domains.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	var sources := known_source_ids.duplicate()
	sources.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	var bases := equipment_catalog.definitions.duplicate()
	bases.sort_custom(func(left: EquipmentBaseDefinition, right: EquipmentBaseDefinition) -> bool:
		if left == null:
			return false
		if right == null:
			return true
		return String(left.id) < String(right.id)
	)
	for domain: StringName in domains:
		for source_id: StringName in sources:
			for base: EquipmentBaseDefinition in bases:
				if base == null:
					continue
				if _scenario_is_reachable(rarity_id, pattern, base, domain, source_id, available_unlock_tags, budget):
					return true
				if bool(budget["exhausted"]):
					return false
	return false

func _scenario_is_reachable(
	rarity_id: StringName,
	pattern: ItemAffixPatternDefinition,
	base: EquipmentBaseDefinition,
	domain: StringName,
	source_id: StringName,
	available_unlock_tags: Array[StringName],
	budget: Dictionary
) -> bool:
	var base_tags := base.normalized_generation_tags()
	var blocked_ids: Dictionary = {}
	var blocked_families: Dictionary = {}
	var implicit_ids := base.implicit_affix_ids.duplicate()
	implicit_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for implicit_id: StringName in implicit_ids:
		var implicit := affix(implicit_id)
		if not _affix_is_scenario_candidate(implicit, "implicit", rarity_id, base_tags, domain, source_id, available_unlock_tags):
			return false
		if blocked_ids.has(implicit.id) or implicit.modifier_family_ids.any(func(family_id: StringName) -> bool: return blocked_families.has(family_id)):
			return false
		_block_reachability_affix(implicit, blocked_ids, blocked_families)

	var slots: Array[String] = []
	for kind: String in ["prefix", "suffix", "special"]:
		for _slot: int in _pattern_kind_count(pattern, kind):
			slots.append(kind)
	var candidates_by_kind: Dictionary = {}
	for kind: String in ["prefix", "suffix", "special"]:
		var candidates: Array[ItemAffixDefinition] = []
		for definition: ItemAffixDefinition in affixes:
			if _affix_is_scenario_candidate(definition, kind, rarity_id, base_tags, domain, source_id, available_unlock_tags):
				candidates.append(definition)
		candidates.sort_custom(func(left: ItemAffixDefinition, right: ItemAffixDefinition) -> bool: return String(left.id) < String(right.id))
		candidates_by_kind[kind] = candidates
	return _fill_pattern_slots(slots, 0, candidates_by_kind, blocked_ids, blocked_families, {}, budget)

func _affix_is_scenario_candidate(
	definition: ItemAffixDefinition,
	kind: String,
	rarity_id: StringName,
	base_tags: Array[StringName],
	domain: StringName,
	source_id: StringName,
	available_unlock_tags: Array[StringName]
) -> bool:
	if definition == null or definition.affix_kind != kind:
		return false
	if definition.required_item_tags.any(func(tag: StringName) -> bool: return tag not in base_tags):
		return false
	if definition.excluded_item_tags.any(func(tag: StringName) -> bool: return tag in base_tags):
		return false
	if not definition.allowed_generation_domains.is_empty() and domain not in definition.allowed_generation_domains:
		return false
	if not definition.allowed_source_ids.is_empty() and source_id not in definition.allowed_source_ids:
		return false
	if not definition.allowed_rarity_ids.is_empty() and rarity_id not in definition.allowed_rarity_ids:
		return false
	if definition.required_unlock_tags.any(func(tag: StringName) -> bool: return tag not in available_unlock_tags):
		return false
	return _has_reachable_tier(definition, rarity_id, source_id, domain)

func _has_reachable_tier(
	definition: ItemAffixDefinition,
	rarity_id: StringName,
	source_id: StringName,
	domain: StringName
) -> bool:
	if definition == null:
		return false
	for tier: ItemAffixTierDefinition in definition.tiers:
		if tier == null or tier.minimum_item_level < 1 or tier.minimum_item_level > ItemGenerationRequest.MAX_ITEM_LEVEL:
			continue
		if not is_finite(tier.base_weight) or tier.base_weight <= 0.0:
			continue
		if not rarity_id.is_empty() and not tier.allowed_rarity_ids.is_empty() and rarity_id not in tier.allowed_rarity_ids:
			continue
		if not source_id.is_empty() and not tier.allowed_source_ids.is_empty() and source_id not in tier.allowed_source_ids:
			continue
		if not domain.is_empty() and not tier.allowed_generation_domains.is_empty() and domain not in tier.allowed_generation_domains:
			continue
		return true
	return false

func _fill_pattern_slots(
	slots: Array[String],
	slot_index: int,
	candidates_by_kind: Dictionary,
	blocked_ids: Dictionary,
	blocked_families: Dictionary,
	memo: Dictionary,
	budget: Dictionary
) -> bool:
	if slot_index >= slots.size():
		return true
	var key := _reachability_state_key(slot_index, blocked_ids, blocked_families)
	if memo.has(key):
		return bool(memo[key])
	if int(budget["remaining"]) <= 0:
		budget["exhausted"] = true
		return false
	budget["remaining"] = int(budget["remaining"]) - 1
	var kind := slots[slot_index]
	var candidates := candidates_by_kind[kind] as Array[ItemAffixDefinition]
	for candidate: ItemAffixDefinition in candidates:
		if blocked_ids.has(candidate.id):
			continue
		if candidate.modifier_family_ids.any(func(family_id: StringName) -> bool: return blocked_families.has(family_id)):
			continue
		var next_ids := blocked_ids.duplicate()
		var next_families := blocked_families.duplicate()
		_block_reachability_affix(candidate, next_ids, next_families)
		if _fill_pattern_slots(slots, slot_index + 1, candidates_by_kind, next_ids, next_families, memo, budget):
			memo[key] = true
			return true
		if bool(budget["exhausted"]):
			return false
	memo[key] = false
	return false

func _block_reachability_affix(definition: ItemAffixDefinition, blocked_ids: Dictionary, blocked_families: Dictionary) -> void:
	blocked_ids[definition.id] = true
	for family_id: StringName in definition.modifier_family_ids:
		blocked_families[family_id] = true

func _reachability_state_key(slot_index: int, blocked_ids: Dictionary, blocked_families: Dictionary) -> String:
	var ids: Array[String] = []
	for id: Variant in blocked_ids:
		ids.append(String(id))
	ids.sort()
	var families: Array[String] = []
	for family_id: Variant in blocked_families:
		families.append(String(family_id))
	families.sort()
	return "%d|%s|%s" % [slot_index, ",".join(ids), ",".join(families)]

func _pattern_kind_count(pattern: ItemAffixPatternDefinition, kind: String) -> int:
	match kind:
		"prefix":
			return pattern.prefix_count
		"suffix":
			return pattern.suffix_count
		"special":
			return pattern.special_count
	return 0

func _validate_patterns(
	rarity_definition: ItemRarityDefinition,
	seen_paths: Dictionary,
	errors: PackedStringArray
) -> void:
	var has_ordinary_pattern := false
	for pattern: ItemAffixPatternDefinition in rarity_definition.patterns:
		if pattern == null:
			continue
		_validate_external_path(pattern, "res://data/items/patterns/", "pattern", seen_paths, errors)
		for domain: StringName in pattern.allowed_generation_domains:
			if domain not in ItemGenerationVocabulary.DOMAINS:
				errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s reason=pattern %s references unknown generation domain %s" % [rarity_definition.id, pattern.id, domain])
		if pattern.allowed_generation_domains.is_empty() or &"ordinary_drop" in pattern.allowed_generation_domains:
			has_ordinary_pattern = true
	if rarity_definition.ordinary_generation_enabled and not has_ordinary_pattern:
		errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s reason=ordinary generation has no reachable pattern" % rarity_definition.id)

func _validate_external_path(
	definition: Resource,
	expected_prefix: String,
	label: String,
	seen_paths: Dictionary,
	errors: PackedStringArray
) -> void:
	var path := definition.resource_path
	if path.is_empty() or not path.begins_with(expected_prefix):
		errors.append("PARTY_FORGE_ITEM_MANIFEST_ERROR reason=%s resource must be external under %s" % [label, expected_prefix])
		return
	if seen_paths.has(path):
		errors.append("PARTY_FORGE_ITEM_MANIFEST_ERROR reason=duplicate resource path %s" % path)
	else:
		seen_paths[path] = true
