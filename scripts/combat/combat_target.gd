class_name CombatTarget
extends RefCounted

var actor: Node3D
var position: Vector3
var team_id: int
var is_available: bool = true

func _init(actor_value: Node3D, position_value: Vector3, team: int) -> void:
    actor = actor_value; position = position_value; team_id = team
