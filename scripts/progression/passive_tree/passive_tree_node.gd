class_name PassiveTreeNode
extends RefCounted

var id: StringName
var type: StringName
var position: Vector2
var name: String
var description: String
var cost: int
var tags: Array[StringName] = []
var icon: Variant
var effects: Array[PassiveTreeEffect] = []
var requirements: Array[PassiveTreeRequirement] = []
var metadata: Dictionary

func _init(
	p_id: StringName = &"",
	p_type: StringName = &"",
	p_position: Vector2 = Vector2.ZERO,
	p_name: String = "",
	p_description: String = "",
	p_cost: int = 0,
	p_tags: Array[StringName] = [],
	p_icon: Variant = null,
	p_effects: Array[PassiveTreeEffect] = [],
	p_requirements: Array[PassiveTreeRequirement] = [],
	p_metadata: Dictionary = {},
) -> void:
	id = p_id
	type = p_type
	position = p_position
	name = p_name
	description = p_description
	cost = p_cost
	tags.assign(p_tags)
	icon = p_icon
	effects.assign(p_effects)
	requirements.assign(p_requirements)
	metadata = p_metadata.duplicate(true)
