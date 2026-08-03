class_name PassiveTreeEffect
extends RefCounted

var effect_id: StringName
var operation: StringName
var value: Variant
var parameters: Dictionary

func _init(
	p_effect_id: StringName = &"",
	p_operation: StringName = &"",
	p_value: Variant = null,
	p_parameters: Dictionary = {},
) -> void:
	effect_id = p_effect_id
	operation = p_operation
	if p_value is Array:
		value = (p_value as Array).duplicate(true)
	elif p_value is Dictionary:
		value = (p_value as Dictionary).duplicate(true)
	else:
		value = p_value
	parameters = p_parameters.duplicate(true)
