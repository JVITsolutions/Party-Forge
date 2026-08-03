class_name PassiveTreeConnection
extends RefCounted

var id: StringName
var from_id: StringName
var to_id: StringName
var direction: StringName
var cost: int
var conditions: Array[PassiveTreeRequirement] = []
var metadata: Dictionary

func _init(
	p_id: StringName = &"",
	p_from_id: StringName = &"",
	p_to_id: StringName = &"",
	p_direction: StringName = &"",
	p_cost: int = 0,
	p_conditions: Array[PassiveTreeRequirement] = [],
	p_metadata: Dictionary = {},
) -> void:
	id = p_id
	from_id = p_from_id
	to_id = p_to_id
	direction = p_direction
	cost = p_cost
	conditions.assign(p_conditions)
	metadata = p_metadata.duplicate(true)
