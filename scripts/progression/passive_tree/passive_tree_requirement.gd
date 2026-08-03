class_name PassiveTreeRequirement
extends RefCounted

var requirement_id: StringName
var operator: StringName
var value: Variant
var parameters: Dictionary

func _init(
	p_requirement_id: StringName = &"",
	p_operator: StringName = &"",
	p_value: Variant = null,
	p_parameters: Dictionary = {},
) -> void:
	requirement_id = p_requirement_id
	operator = p_operator
	if p_value is Array:
		value = (p_value as Array).duplicate(true)
	elif p_value is Dictionary:
		value = (p_value as Dictionary).duplicate(true)
	else:
		value = p_value
	parameters = p_parameters.duplicate(true)
