class_name ItemAffixDefinition
extends Resource

const VALID_AFFIX_KINDS: PackedStringArray = ["implicit", "prefix", "suffix", "special"]
const VALID_OPERATIONS: Array[int] = [
	StatModifier.Operation.FLAT,
	StatModifier.Operation.INCREASED,
	StatModifier.Operation.REDUCED,
	StatModifier.Operation.MORE,
	StatModifier.Operation.LESS,
]

@export var id: StringName
@export var display_name: String
@export_enum("implicit", "prefix", "suffix", "special") var affix_kind := "prefix"

@export var base_weight := 1.0
@export var modifier_family_ids: Array[StringName] = []
@export var required_item_tags: Array[StringName] = []
@export var excluded_item_tags: Array[StringName] = []
@export var allowed_generation_domains: Array[StringName] = []
@export var allowed_source_ids: Array[StringName] = []
@export var allowed_rarity_ids: Array[StringName] = []
@export var required_unlock_tags: Array[StringName] = []
@export var effects: Array[ItemModifierEffectDefinition] = []
@export var tiers: Array[ItemAffixTierDefinition] = []

# TASK 1 TRANSITION BRIDGE: current inline catalog Resources and their consumers
# still use these fields. Task 2 migrates the data and removes this marked seam.
@export_range(1, 100, 1) var minimum_tier := 1
@export_range(1, 100, 1) var maximum_tier := 1
@export var stat_id: StringName
@export var operation := StatModifier.Operation.FLAT
@export var minimum_roll_by_tier: Array[float] = []
@export var maximum_roll_by_tier: Array[float] = []
@export var required_tags: Array[StringName] = []

func tier_definition(tier_number: int) -> ItemAffixTierDefinition:
	for value: ItemAffixTierDefinition in tiers:
		if value != null and value.tier == tier_number:
			return value
	if _uses_legacy_tier_bridge():
		return _legacy_tier_definition(tier_number)
	return null

func roll_bounds(tier_number: int, effect_index: int = 0) -> Vector2:
	var value := tier_definition(tier_number)
	return value.roll_bounds(effect_index) if value != null else Vector2(INF, -INF)

func validate(
	stat_catalog: StatCatalog,
	known_families: Array[StringName] = [],
	known_domains: Array[StringName] = [],
	known_sources: Array[StringName] = [],
	known_rarities: Array[StringName] = [],
	known_item_tags: Array[StringName] = []
) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("affix id is empty")
	if display_name.strip_edges().is_empty():
		errors.append("affix %s display name is empty" % id)
	if affix_kind not in VALID_AFFIX_KINDS:
		errors.append("affix %s kind %s is unsupported" % [id, affix_kind])
	if not is_finite(base_weight) or base_weight <= 0.0:
		errors.append("affix %s weight must be finite and positive" % id)

	var legacy_effect_bridge := _uses_legacy_effect_bridge()
	var legacy_tier_bridge := _uses_legacy_tier_bridge()
	var validated_effects := _effective_effects()
	var validated_tiers := _effective_tiers()
	var validated_families := modifier_family_ids.duplicate()
	var synthesized_legacy_family := validated_families.is_empty() and legacy_effect_bridge
	if synthesized_legacy_family:
		validated_families.append(StringName("legacy_%s" % id))
	if legacy_tier_bridge:
		_validate_legacy_tier_bridge(errors)

	_validate_families(validated_families, known_families, synthesized_legacy_family, errors)
	_validate_references(allowed_generation_domains, known_domains, "generation domain", errors)
	_validate_references(allowed_source_ids, known_sources, "source", errors)
	_validate_references(allowed_rarity_ids, known_rarities, "rarity", errors)
	_validate_references(required_item_tags, known_item_tags, "required item tag", errors)
	_validate_references(excluded_item_tags, known_item_tags, "excluded item tag", errors)
	_validate_nonempty(required_unlock_tags, "unlock tag", errors)
	for tag: StringName in required_item_tags:
		if tag in excluded_item_tags:
			errors.append("affix %s item tag %s is both required and excluded" % [id, tag])

	if validated_effects.is_empty():
		errors.append("affix %s requires at least one effect" % id)
	for index: int in validated_effects.size():
		var effect := validated_effects[index]
		if effect == null:
			errors.append("affix %s effect %d is missing" % [id, index])
			continue
		for reason: String in effect.validate(stat_catalog):
			errors.append("affix %s effect %d: %s" % [id, index, reason])
		_validate_references(effect.required_tags, known_item_tags, "effect required tag", errors)

	if validated_tiers.is_empty():
		errors.append("affix %s requires at least one tier" % id)
	_validate_tiers(validated_tiers, validated_effects.size(), known_domains, known_sources, known_rarities, errors)
	return errors

func _validate_families(values: Array[StringName], known: Array[StringName], synthesized_legacy_family: bool, errors: PackedStringArray) -> void:
	if values.is_empty():
		errors.append("affix %s requires at least one modifier family" % id)
		return
	var seen: Dictionary = {}
	for value: StringName in values:
		if value.is_empty():
			errors.append("affix %s modifier family is empty" % id)
		elif seen.has(value):
			errors.append("affix %s has duplicate modifier family %s" % [id, value])
		else:
			seen[value] = true
			if not synthesized_legacy_family and not known.is_empty() and value not in known:
				errors.append("affix %s references unknown modifier family %s" % [id, value])

func _validate_references(values: Array[StringName], known: Array[StringName], label: String, errors: PackedStringArray) -> void:
	for value: StringName in values:
		if value.is_empty():
			errors.append("affix %s %s is empty" % [id, label])
		elif not known.is_empty() and value not in known:
			errors.append("affix %s references unknown %s %s" % [id, label, value])

func _validate_nonempty(values: Array[StringName], label: String, errors: PackedStringArray) -> void:
	for value: StringName in values:
		if value.is_empty():
			errors.append("affix %s %s is empty" % [id, label])

func _validate_tiers(
	values: Array[ItemAffixTierDefinition],
	effect_count: int,
	known_domains: Array[StringName],
	known_sources: Array[StringName],
	known_rarities: Array[StringName],
	errors: PackedStringArray
) -> void:
	var seen_tiers: Dictionary = {}
	var previous: ItemAffixTierDefinition = null
	for index: int in values.size():
		var value := values[index]
		if value == null:
			errors.append("affix %s tier %d is missing" % [id, index])
			continue
		if seen_tiers.has(value.tier):
			errors.append("affix %s has duplicate tier %d" % [id, value.tier])
		else:
			seen_tiers[value.tier] = true
		if previous != null:
			if value.tier <= previous.tier:
				errors.append("affix %s tier numbers must ascend" % id)
			if value.minimum_item_level <= previous.minimum_item_level:
				errors.append("affix %s tier minimum item levels must ascend" % id)
			var comparable_effects := mini(effect_count, mini(previous.maximum_rolls.size(), value.maximum_rolls.size()))
			for effect_index: int in comparable_effects:
				if value.maximum_rolls[effect_index] < previous.maximum_rolls[effect_index]:
					errors.append("affix %s tier %d effect %d maximum descends" % [id, value.tier, effect_index])
		for reason: String in value.validate(effect_count):
			errors.append("affix %s tier %d: %s" % [id, value.tier, reason])
		_validate_references(value.allowed_generation_domains, known_domains, "tier generation domain", errors)
		_validate_references(value.allowed_source_ids, known_sources, "tier source", errors)
		_validate_references(value.allowed_rarity_ids, known_rarities, "tier rarity", errors)
		previous = value

func _uses_legacy_effect_bridge() -> bool:
	return effects.is_empty() and not stat_id.is_empty()

func _uses_legacy_tier_bridge() -> bool:
	return tiers.is_empty() and (not minimum_roll_by_tier.is_empty() or not maximum_roll_by_tier.is_empty())

func _effective_effects() -> Array[ItemModifierEffectDefinition]:
	if not effects.is_empty() or stat_id.is_empty():
		return effects
	var legacy_effect := ItemModifierEffectDefinition.new()
	legacy_effect.stat_id = stat_id
	legacy_effect.operation = operation
	legacy_effect.required_tags = required_tags.duplicate()
	return [legacy_effect]

func _effective_tiers() -> Array[ItemAffixTierDefinition]:
	if not tiers.is_empty():
		return tiers
	var values: Array[ItemAffixTierDefinition] = []
	var tier_count := maxi(maximum_tier - minimum_tier + 1, 0)
	for index: int in tier_count:
		var value := _legacy_tier_definition(minimum_tier + index)
		if value != null:
			values.append(value)
	return values

func _legacy_tier_definition(tier_number: int) -> ItemAffixTierDefinition:
	if tier_number < minimum_tier or tier_number > maximum_tier:
		return null
	var index := tier_number - minimum_tier
	if index < 0 or index >= minimum_roll_by_tier.size() or index >= maximum_roll_by_tier.size():
		return null
	var value := ItemAffixTierDefinition.new()
	value.tier = tier_number
	value.minimum_item_level = index + 1
	value.minimum_rolls = [minimum_roll_by_tier[index]]
	value.maximum_rolls = [maximum_roll_by_tier[index]]
	return value

func _validate_legacy_tier_bridge(errors: PackedStringArray) -> void:
	if minimum_tier < 1 or maximum_tier < 1:
		errors.append("affix %s tier range must begin at one or above" % id)
	if minimum_tier > maximum_tier:
		errors.append("affix %s minimum tier exceeds maximum" % id)
	var tier_count := maxi(maximum_tier - minimum_tier + 1, 0)
	if minimum_roll_by_tier.size() != tier_count:
		errors.append("affix %s requires one minimum roll per tier" % id)
	if maximum_roll_by_tier.size() != tier_count:
		errors.append("affix %s requires one maximum roll per tier" % id)
