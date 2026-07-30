class_name PartyMemberState
extends RefCounted

var member_id: int
var class_definition: ClassDefinition
var is_leader: bool
var capability_tags: Array[StringName] = []
var modifier_sources: Array[StatModifierSource] = []

func _init(id_value: int, definition: ClassDefinition, leader: bool) -> void:
    member_id = id_value
    class_definition = definition
    is_leader = leader
    capability_tags = definition.capability_tags.duplicate()
    for trait_id: StringName in definition.traits:
        if trait_id not in capability_tags:
            capability_tags.append(trait_id)
