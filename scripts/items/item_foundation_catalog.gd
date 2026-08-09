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
