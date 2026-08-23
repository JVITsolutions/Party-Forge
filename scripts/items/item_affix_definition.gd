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
@export var affinity_tags: Array[StringName] = []
@export var allowed_generation_domains: Array[StringName] = []
@export var allowed_source_ids: Array[StringName] = []
@export var allowed_rarity_ids: Array[StringName] = []
@export var required_unlock_tags: Array[StringName] = []
@export var effects: Array[ItemModifierEffectDefinition] = []
@export var tiers: Array[ItemAffixTierDefinition] = []

func tier_definition(tier_number: int) -> ItemAffixTierDefinition:
	for value: ItemAffixTierDefinition in tiers:
		if value != null and value.tier == tier_number:
			return value
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

	_validate_families(modifier_family_ids, known_families, errors)
	_validate_references(allowed_generation_domains, known_domains, "generation domain", errors)
	_validate_references(allowed_source_ids, known_sources, "source", errors)
	_validate_references(allowed_rarity_ids, known_rarities, "rarity", errors)
	_validate_references(required_item_tags, known_item_tags, "required item tag", errors)
	_validate_references(excluded_item_tags, known_item_tags, "excluded item tag", errors)
	_validate_affinity_tags(known_item_tags, errors)
	_validate_nonempty(required_unlock_tags, "unlock tag", errors)
	for tag: StringName in required_item_tags:
		if tag in excluded_item_tags:
			errors.append("affix %s item tag %s is both required and excluded" % [id, tag])

	if effects.is_empty():
		errors.append("affix %s requires at least one effect" % id)
	for index: int in effects.size():
		var effect := effects[index]
		if effect == null:
			errors.append("affix %s effect %d is missing" % [id, index])
			continue
		for reason: String in effect.validate(stat_catalog):
			errors.append("affix %s effect %d: %s" % [id, index, reason])
		_validate_references(effect.required_tags, known_item_tags, "effect required tag", errors)

	if tiers.is_empty():
		errors.append("affix %s requires at least one tier" % id)
	_validate_tiers(tiers, effects.size(), known_domains, known_sources, known_rarities, errors)
	_validate_roll_steps(errors)
	_validate_monotonic_core_attribute_ranges(errors)
	return errors

func _validate_roll_steps(errors: PackedStringArray) -> void:
	for effect_index: int in effects.size():
		var effect := effects[effect_index]
		if effect == null or not is_finite(effect.roll_step) or effect.roll_step <= 0.0:
			continue
		for tier: ItemAffixTierDefinition in tiers:
			if tier == null or effect_index >= tier.minimum_rolls.size() or effect_index >= tier.maximum_rolls.size():
				continue
			var minimum := tier.minimum_rolls[effect_index]
			var maximum := tier.maximum_rolls[effect_index]
			if not is_finite(minimum) or not is_finite(maximum) or minimum > maximum:
				continue
			var minimum_index := ceili(minimum / effect.roll_step)
			var maximum_index := floori(maximum / effect.roll_step)
			if minimum_index > maximum_index:
				errors.append("affix %s tier %d effect %d range %s-%s contains no legal roll grid point for step %s" % [
					id, tier.tier, effect_index, str(minimum), str(maximum), str(effect.roll_step),
				])

func _validate_monotonic_core_attribute_ranges(errors: PackedStringArray) -> void:
	var seen: Dictionary = {}
	for effect_index: int in effects.size():
		var effect := effects[effect_index]
		if effect == null or effect.stat_id not in EquipmentBaseDefinition.REQUIREMENT_ATTRIBUTE_IDS:
			continue
		for tier: ItemAffixTierDefinition in tiers:
			if tier == null or effect_index >= tier.minimum_rolls.size() or effect_index >= tier.maximum_rolls.size():
				continue
			for value: float in [tier.minimum_rolls[effect_index], tier.maximum_rolls[effect_index]]:
				var reason := EquipmentBaseDefinition.monotonic_core_modifier_error(effect.stat_id, effect.operation, value)
				if reason.is_empty():
					continue
				var diagnostic := "affix %s effect=%d stat=%s operation=%s value=%s reason=%s" % [
					id,
					effect_index,
					effect.stat_id,
					EquipmentBaseDefinition.modifier_operation_name(effect.operation),
					str(value),
					reason,
				]
				if not seen.has(diagnostic):
					seen[diagnostic] = true
					errors.append(diagnostic)

func _validate_families(values: Array[StringName], known: Array[StringName], errors: PackedStringArray) -> void:
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
			if value not in known:
				errors.append("affix %s references unknown modifier family %s" % [id, value])

func _validate_references(values: Array[StringName], known: Array[StringName], label: String, errors: PackedStringArray) -> void:
	for value: StringName in values:
		if value.is_empty():
			errors.append("affix %s %s is empty" % [id, label])
		elif value not in known:
			errors.append("affix %s references unknown %s %s" % [id, label, value])

func _validate_nonempty(values: Array[StringName], label: String, errors: PackedStringArray) -> void:
	for value: StringName in values:
		if value.is_empty():
			errors.append("affix %s %s is empty" % [id, label])

func _validate_affinity_tags(known_item_tags: Array[StringName], errors: PackedStringArray) -> void:
	var previous := ""
	var seen: Dictionary = {}
	for tag: StringName in affinity_tags:
		var value := String(tag)
		if tag.is_empty():
			errors.append("affix %s affinity tag is empty" % id)
		elif seen.has(tag):
			errors.append("affix %s has duplicate affinity tag %s" % [id, tag])
		elif tag not in known_item_tags:
			errors.append("affix %s references unknown affinity tag %s" % [id, tag])
		if not previous.is_empty() and value < previous:
			errors.append("affix %s affinity tags must use ascending stable order" % id)
		seen[tag] = true
		previous = value

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
