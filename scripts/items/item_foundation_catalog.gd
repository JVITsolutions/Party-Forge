class_name ItemFoundationCatalog
extends Resource

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

func validate(stat_catalog: StatCatalog, equipment_catalog: EquipmentCatalog = null) -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_registry(modifier_family_ids, "modifier family", errors)
	_validate_registry(known_source_ids, "source", errors)
	_validate_registry(known_item_tags, "item tag", errors)
	var live_item_tags := _live_equipment_tags(equipment_catalog)
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
			live_item_tags if equipment_catalog != null else known_item_tags
		):
			errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=%s reason=%s" % [definition.id, reason])
		if not _has_reachable_tier(definition, &"", &"", &""):
			errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=%s reason=no tier is reachable at item level 1..1000" % definition.id)
	_validate_base_implicits(equipment_catalog, errors)
	_validate_ordinary_pattern_reachability(equipment_catalog, errors)
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
	result.sort()
	return result

func _validate_equipment_tags(equipment_catalog: EquipmentCatalog, errors: PackedStringArray) -> void:
	if equipment_catalog == null:
		return
	var expected: Dictionary = {}
	for tag: StringName in ItemGenerationVocabulary.ARCHETYPES:
		expected[tag] = true
	for definition: EquipmentBaseDefinition in equipment_catalog.definitions:
		if definition == null:
			continue
		for tag: StringName in [definition.item_type_id, definition.weight_class_id, definition.weapon_family_id]:
			if not tag.is_empty():
				expected[tag] = true
	for tag: StringName in expected:
		if tag not in known_item_tags:
			errors.append("PARTY_FORGE_ITEM_MANIFEST_ERROR reason=missing current equipment item tag %s" % tag)
	for tag: StringName in known_item_tags:
		if not expected.has(tag):
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

func _validate_ordinary_pattern_reachability(equipment_catalog: EquipmentCatalog, errors: PackedStringArray) -> void:
	if equipment_catalog == null:
		return
	for rarity_definition: ItemRarityDefinition in rarities:
		if rarity_definition == null or not rarity_definition.ordinary_generation_enabled:
			continue
		for pattern: ItemAffixPatternDefinition in rarity_definition.patterns:
			if pattern == null:
				continue
			for kind: String in ["prefix", "suffix", "special"]:
				var required_count := _pattern_kind_count(pattern, kind)
				if required_count <= 0:
					continue
				if not _pattern_kind_is_reachable(rarity_definition.id, kind, required_count, equipment_catalog):
					errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s pattern=%s kind=%s reason=no live affix can fill declared slot" % [rarity_definition.id, pattern.id, kind])

func _pattern_kind_is_reachable(
	rarity_id: StringName,
	kind: String,
	required_count: int,
	equipment_catalog: EquipmentCatalog
) -> bool:
	for base: EquipmentBaseDefinition in equipment_catalog.definitions:
		if base == null:
			continue
		var candidates: Array[ItemAffixDefinition] = []
		var base_tags := base.normalized_generation_tags()
		for definition: ItemAffixDefinition in affixes:
			if _affix_is_live_candidate(definition, kind, rarity_id, base_tags):
				candidates.append(definition)
		if _has_family_compatible_set(candidates, 0, {}, required_count):
			return true
	return false

func _affix_is_live_candidate(
	definition: ItemAffixDefinition,
	kind: String,
	rarity_id: StringName,
	base_tags: Array[StringName]
) -> bool:
	if definition == null or definition.affix_kind != kind:
		return false
	if definition.required_item_tags.any(func(tag: StringName) -> bool: return tag not in base_tags):
		return false
	if definition.excluded_item_tags.any(func(tag: StringName) -> bool: return tag in base_tags):
		return false
	if not definition.allowed_generation_domains.is_empty() and &"ordinary_drop" not in definition.allowed_generation_domains:
		return false
	if not definition.allowed_source_ids.is_empty() and &"ordinary_enemy" not in definition.allowed_source_ids:
		return false
	if not definition.allowed_rarity_ids.is_empty() and rarity_id not in definition.allowed_rarity_ids:
		return false
	return _has_reachable_tier(definition, rarity_id, &"ordinary_enemy", &"ordinary_drop")

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

func _has_family_compatible_set(
	candidates: Array[ItemAffixDefinition],
	index: int,
	blocked_families: Dictionary,
	remaining: int
) -> bool:
	if remaining <= 0:
		return true
	if index >= candidates.size() or candidates.size() - index < remaining:
		return false
	var current := candidates[index]
	if not current.modifier_family_ids.any(func(family_id: StringName) -> bool: return blocked_families.has(family_id)):
		var with_blocked := blocked_families.duplicate()
		for family_id: StringName in current.modifier_family_ids:
			with_blocked[family_id] = true
		if _has_family_compatible_set(candidates, index + 1, with_blocked, remaining - 1):
			return true
	return _has_family_compatible_set(candidates, index + 1, blocked_families, remaining)

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
