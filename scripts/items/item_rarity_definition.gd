class_name ItemRarityDefinition
extends Resource

@export var id: StringName
@export var display_name: String

@export_range(1, 100, 1) var rarity_rank := 1
@export var instance_supported := true
@export var ordinary_generation_enabled := true
@export var base_weight := 1.0
@export var required_unlock_tags: Array[StringName] = []
@export var patterns: Array[ItemAffixPatternDefinition] = []
@export_range(0, 64, 1) var reserved_special_slots := 0

# TASK 1 TRANSITION BRIDGE: current inline catalog Resources still serialize these
# fields. Task 2 removes them after externalizing each rarity into the new model.
@export var functional := true
@export var minimum_affixes := 0
@export var maximum_affixes := 0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("rarity id is empty")
	if display_name.strip_edges().is_empty():
		errors.append("rarity %s display name is empty" % id)
	if rarity_rank < 1:
		errors.append("rarity %s rank must be positive" % id)
	if not is_finite(base_weight) or base_weight <= 0.0:
		errors.append("rarity %s weight must be finite and positive" % id)
	if reserved_special_slots < 0:
		errors.append("rarity %s reserved special slots is negative" % id)
	_validate_names(required_unlock_tags, "unlock tag", errors)

	var definitions := patterns
	if definitions.is_empty():
		definitions = _legacy_patterns(errors)
	var seen_patterns: Dictionary = {}
	for pattern: ItemAffixPatternDefinition in definitions:
		if pattern == null:
			errors.append("rarity %s pattern is missing" % id)
			continue
		if seen_patterns.has(pattern.id):
			errors.append("rarity %s has duplicate pattern %s" % [id, pattern.id])
		else:
			seen_patterns[pattern.id] = true
		for reason: String in pattern.validate():
			errors.append("rarity %s pattern %s: %s" % [id, pattern.id, reason])
	return errors

func _legacy_patterns(errors: PackedStringArray) -> Array[ItemAffixPatternDefinition]:
	var definitions: Array[ItemAffixPatternDefinition] = []
	if minimum_affixes < 0:
		errors.append("rarity %s minimum affixes is negative" % id)
	if maximum_affixes < 0:
		errors.append("rarity %s maximum affixes is negative" % id)
	if minimum_affixes > maximum_affixes:
		errors.append("rarity %s minimum affixes exceeds maximum" % id)
	var pattern := ItemAffixPatternDefinition.new()
	pattern.id = StringName("%s_legacy" % id)
	pattern.prefix_count = maxi(maximum_affixes, 0)
	definitions.append(pattern)
	return definitions

func _validate_names(values: Array[StringName], label: String, errors: PackedStringArray) -> void:
	var seen: Dictionary = {}
	for value: StringName in values:
		if value.is_empty():
			errors.append("rarity %s %s is empty" % [id, label])
		elif seen.has(value):
			errors.append("rarity %s has duplicate %s %s" % [id, label, value])
		else:
			seen[value] = true
