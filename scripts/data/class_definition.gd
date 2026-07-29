class_name ClassDefinition
extends Resource

enum Role { FRONTLINE, MIDLINE, BACKLINE, SUPPORT }

@export var id: StringName
@export var display_name: String
@export var role: Role
@export var color: Color = Color.WHITE
@export var traits: Array[StringName] = []
@export var max_health: float = 100.0
@export var armor: float = 0.0
@export var move_speed: float = 6.0
@export var preferred_distance: float = 2.0
@export var engagement_distance: float = 8.0
@export var tether_distance: float = 10.0
@export var primary_attack: AttackDefinition
@export var support_action: AttackDefinition

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty(): errors.append("class id is empty")
    if display_name.is_empty(): errors.append("class %s display name is empty" % id)
    if traits.is_empty(): errors.append("class %s has no traits" % id)
    if max_health <= 0.0: errors.append("class %s health must be positive" % id)
    if primary_attack == null: errors.append("class %s primary attack is missing" % id)
    if primary_attack != null:
        for reason: String in primary_attack.validate(): errors.append("class %s primary %s" % [id, reason])
    if support_action != null:
        for reason: String in support_action.validate(): errors.append("class %s support %s" % [id, reason])
    return errors
