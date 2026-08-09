class_name ItemAffixTierDefinition
extends Resource

@export_range(1, 1000, 1) var tier := 1
@export_range(1, 1000, 1) var minimum_item_level := 1
@export var base_weight := 1.0
@export var minimum_rolls: Array[float] = []
@export var maximum_rolls: Array[float] = []
@export var allowed_rarity_ids: Array[StringName] = []
@export var allowed_source_ids: Array[StringName] = []
@export var allowed_generation_domains: Array[StringName] = []

func roll_bounds(effect_index: int) -> Vector2:
	if effect_index < 0 or effect_index >= minimum_rolls.size() or effect_index >= maximum_rolls.size():
		return Vector2(INF, -INF)
	return Vector2(minimum_rolls[effect_index], maximum_rolls[effect_index])

func validate(effect_count: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if tier < 1:
		errors.append("tier must be positive")
	if minimum_item_level < 1:
		errors.append("minimum item level must be positive")
	if not is_finite(base_weight) or base_weight <= 0.0:
		errors.append("tier %d weight must be finite and positive" % tier)
	if minimum_rolls.size() != effect_count or maximum_rolls.size() != effect_count:
		errors.append("tier %d requires one range per effect" % tier)
	for index: int in mini(minimum_rolls.size(), maximum_rolls.size()):
		if not is_finite(minimum_rolls[index]) or not is_finite(maximum_rolls[index]) or minimum_rolls[index] > maximum_rolls[index]:
			errors.append("tier %d effect %d range is invalid" % [tier, index])
	return errors
