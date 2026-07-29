class_name AttackDefinition
extends Resource

enum Kind { MELEE_CLEAVE, PROJECTILE, AREA_PROJECTILE, HEAL }

@export var id: StringName
@export var kind: Kind
@export var power: float = 1.0
@export var cooldown: float = 1.0
@export var range: float = 1.0
@export var projectile_speed: float = 0.0
@export var area_radius: float = 0.0

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty(): errors.append("attack id is empty")
    if power <= 0.0: errors.append("attack %s power must be positive" % id)
    if cooldown <= 0.0: errors.append("attack %s cooldown must be positive" % id)
    if range <= 0.0: errors.append("attack %s range must be positive" % id)
    if kind in [Kind.PROJECTILE, Kind.AREA_PROJECTILE] and projectile_speed <= 0.0:
        errors.append("attack %s projectile speed must be positive" % id)
    return errors
