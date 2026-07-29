class_name EnemyDefinition
extends Resource

enum Behavior { SWARMER, SPITTER, FORGE_GUARDIAN }

@export var id: StringName
@export var behavior: Behavior
@export var max_health: float = 20.0
@export var move_speed: float = 3.0
@export var contact_damage: float = 5.0
@export var experience: int = 1

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty(): errors.append("enemy id is empty")
    if max_health <= 0.0: errors.append("enemy %s health must be positive" % id)
    if move_speed <= 0.0: errors.append("enemy %s speed must be positive" % id)
    return errors
