class_name ItemGenerationRequest
extends RefCounted

const MIN_ITEM_LEVEL := 1
const MAX_ITEM_LEVEL := 1000

var seed := 0
var generation_sequence := 0
var item_level := 1
var source_id: StringName
var generation_domain: StringName
var difficulty_id: StringName = &"normal"
var heat := 0.0
var permitted_rarity_ids: Array[StringName] = []
var party_archetype_tags: Array[StringName] = []
var charisma_value := 0.0
var unlock_tags: Array[StringName] = []
var required_base_tags: Array[StringName] = []
var excluded_base_tags: Array[StringName] = []
var required_affix_tags: Array[StringName] = []
var excluded_affix_tags: Array[StringName] = []
var forced_base_id: StringName
var forced_rarity_id: StringName

static func create(
	seed_value: int,
	generation_sequence_value: int,
	item_level_value: int,
	source_id_value: StringName,
	domain_value: StringName,
	permitted_rarities: Array[StringName]
) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.new()
	request.seed = seed_value
	request.generation_sequence = generation_sequence_value
	request.item_level = item_level_value
	request.source_id = source_id_value
	request.generation_domain = domain_value
	request.permitted_rarity_ids = permitted_rarities.duplicate()
	return request

func copy_with_sequence(value: int) -> ItemGenerationRequest:
	var result := ItemGenerationRequest.new()
	for property_name: StringName in [
		&"seed", &"item_level", &"source_id", &"generation_domain", &"difficulty_id",
		&"heat", &"charisma_value", &"forced_base_id", &"forced_rarity_id",
	]:
		result.set(property_name, get(property_name))
	for property_name: StringName in [
		&"permitted_rarity_ids", &"party_archetype_tags", &"unlock_tags",
		&"required_base_tags", &"excluded_base_tags", &"required_affix_tags", &"excluded_affix_tags",
	]:
		result.set(property_name, (get(property_name) as Array).duplicate())
	result.generation_sequence = value
	return result

func validate(foundation: ItemFoundationCatalog) -> String:
	if foundation == null:
		return _error("foundation", "manifest missing")
	if generation_sequence < 0:
		return _error("generation_sequence", "must be nonnegative")
	if item_level < MIN_ITEM_LEVEL or item_level > MAX_ITEM_LEVEL:
		return _error("item_level", "must be between %d and %d" % [MIN_ITEM_LEVEL, MAX_ITEM_LEVEL])
	if source_id not in foundation.known_source_ids:
		return _error("source_id", "unknown source %s" % source_id)
	if generation_domain not in ItemGenerationVocabulary.DOMAINS:
		return _error("generation_domain", "unknown generation domain %s" % generation_domain)
	if difficulty_id not in ItemGenerationVocabulary.DIFFICULTIES:
		return _error("difficulty_id", "unsupported difficulty %s" % difficulty_id)
	if not is_finite(heat) or heat < 0.0:
		return _error("heat", "must be finite and nonnegative")

	var known_rarities := foundation.supported_rarity_ids()
	var rarity_error := _validate_names(permitted_rarity_ids, known_rarities, "permitted_rarity_ids", "rarity", true)
	if not rarity_error.is_empty():
		return rarity_error
	var archetype_error := _validate_names(party_archetype_tags, ItemGenerationVocabulary.ARCHETYPES, "party_archetype_tags", "archetype tag")
	if not archetype_error.is_empty():
		return archetype_error
	if not is_finite(charisma_value) or charisma_value < 0.0:
		return _error("charisma_value", "must be finite and nonnegative")

	var unlock_error := _validate_names(unlock_tags, foundation.generation_unlock_tags(), "unlock_tags", "unlock tag")
	if not unlock_error.is_empty():
		return unlock_error
	var required_base_error := _validate_names(required_base_tags, foundation.known_item_tags, "required_base_tags", "item tag")
	if not required_base_error.is_empty():
		return required_base_error
	var excluded_base_error := _validate_names(excluded_base_tags, foundation.known_item_tags, "excluded_base_tags", "item tag")
	if not excluded_base_error.is_empty():
		return excluded_base_error
	var base_contradiction := _contradiction(required_base_tags, excluded_base_tags, "required_base_tags")
	if not base_contradiction.is_empty():
		return base_contradiction
	var required_affix_error := _validate_names(required_affix_tags, foundation.known_item_tags, "required_affix_tags", "item tag")
	if not required_affix_error.is_empty():
		return required_affix_error
	var excluded_affix_error := _validate_names(excluded_affix_tags, foundation.known_item_tags, "excluded_affix_tags", "item tag")
	if not excluded_affix_error.is_empty():
		return excluded_affix_error
	var affix_contradiction := _contradiction(required_affix_tags, excluded_affix_tags, "required_affix_tags")
	if not affix_contradiction.is_empty():
		return affix_contradiction
	if not forced_rarity_id.is_empty() and forced_rarity_id not in known_rarities:
		return _error("forced_rarity_id", "unknown rarity %s" % forced_rarity_id)
	return ""

func canonical_document() -> Dictionary:
	if not is_finite(heat) or not is_finite(charisma_value):
		return {}
	return {
		"seed": seed,
		"generation_sequence": generation_sequence,
		"item_level": item_level,
		"source_id": String(source_id),
		"generation_domain": String(generation_domain),
		"difficulty_id": String(difficulty_id),
		"heat": heat,
		"permitted_rarity_ids": _canonical_names(permitted_rarity_ids),
		"party_archetype_tags": _canonical_names(party_archetype_tags),
		"charisma_value": charisma_value,
		"unlock_tags": _canonical_names(unlock_tags),
		"required_base_tags": _canonical_names(required_base_tags),
		"excluded_base_tags": _canonical_names(excluded_base_tags),
		"required_affix_tags": _canonical_names(required_affix_tags),
		"excluded_affix_tags": _canonical_names(excluded_affix_tags),
		"forced_base_id": String(forced_base_id),
		"forced_rarity_id": String(forced_rarity_id),
	}

func _validate_names(
	values: Array[StringName],
	known: Array[StringName],
	field: String,
	label: String,
	require_nonempty := false
) -> String:
	if require_nonempty and values.is_empty():
		return _error(field, "must not be empty")
	var seen: Dictionary = {}
	for value: StringName in values:
		if value.is_empty():
			return _error(field, "value must not be empty")
		if seen.has(value):
			return _error(field, "duplicate value %s" % value)
		seen[value] = true
		if value not in known:
			return _error(field, "unknown %s %s" % [label, value])
	return ""

func _contradiction(required: Array[StringName], excluded: Array[StringName], field: String) -> String:
	var sorted_required := required.duplicate()
	sorted_required.sort()
	for value: StringName in sorted_required:
		if value in excluded:
			return _error(field, "contradicts excluded tag %s" % value)
	return ""

func _canonical_names(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	result.sort()
	return result

func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_ITEM_GENERATION_ERROR stage=request field=%s reason=%s" % [field, reason]
