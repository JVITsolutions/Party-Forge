class_name ItemAffixPatternDefinition
extends Resource

@export var id: StringName
@export_range(0, 64, 1) var prefix_count := 0
@export_range(0, 64, 1) var suffix_count := 0
@export_range(0, 64, 1) var special_count := 0
@export var weight := 1.0
@export var allowed_generation_domains: Array[StringName] = []

func explicit_count() -> int:
	return prefix_count + suffix_count

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("pattern id is empty")
	if prefix_count < 0 or suffix_count < 0 or special_count < 0:
		errors.append("pattern %s has a negative count" % id)
	if not is_finite(weight) or weight <= 0.0:
		errors.append("pattern %s weight must be finite and positive" % id)
	return errors
