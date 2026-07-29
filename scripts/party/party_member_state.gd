class_name PartyMemberState
extends RefCounted

var member_id: int
var class_definition: ClassDefinition
var is_leader: bool

func _init(id_value: int, definition: ClassDefinition, leader: bool) -> void:
    member_id = id_value
    class_definition = definition
    is_leader = leader
