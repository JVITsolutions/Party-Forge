class_name ItemModifierEffectDefinition
extends Resource

@export var stat_id: StringName
@export var operation := StatModifier.Operation.FLAT
@export var required_tags: Array[StringName] = []
@export var roll_step := 0.0

func validate(stats: StatCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if stat_id.is_empty() or stats == null or stats.definition(stat_id) == null:
		errors.append("unknown stat %s" % stat_id)
	if operation not in ItemAffixDefinition.VALID_OPERATIONS:
		errors.append("unsupported operation %d" % operation)
	if required_tags.any(func(tag: StringName) -> bool: return tag.is_empty()):
		errors.append("required tag is empty")
	if not is_finite(roll_step) or roll_step < 0.0:
		errors.append("roll step must be finite and nonnegative")
	return errors
