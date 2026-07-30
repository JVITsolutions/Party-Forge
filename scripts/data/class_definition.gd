class_name ClassDefinition
extends Resource

enum Role { FRONTLINE, MIDLINE, BACKLINE, SUPPORT }

@export var id: StringName
@export var display_name: String
@export var role: Role
@export var color: Color = Color.WHITE
@export var traits: Array[StringName] = []
@export var capability_tags: Array[StringName] = []
@export var base_stat_overrides: Dictionary = {}
@export var max_health: float = 100.0
@export var armor: float = 0.0
@export var move_speed: float = 6.0
@export var class_rank_power_step: float = 0.2
@export var revive_delay: float = 8.0
@export var revive_health_fraction: float = 0.5
@export var preferred_distance: float = 2.0
@export var engagement_distance: float = 8.0
@export var tether_distance: float = 10.0
@export var primary_attack: AttackDefinition
@export var support_action: AttackDefinition

func stat_base_values() -> Dictionary:
	var values := base_stat_overrides.duplicate(true)
	values[&"max_health"] = float(values.get(&"max_health", max_health))
	values[&"armor"] = float(values.get(&"armor", armor))
	values[&"move_speed"] = float(values.get(&"move_speed", move_speed))
	return values

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty(): errors.append("class id is empty")
    if display_name.is_empty(): errors.append("class %s display name is empty" % id)
    if traits.is_empty(): errors.append("class %s has no traits" % id)
    if max_health <= 0.0: errors.append("class %s health must be positive" % id)
    if class_rank_power_step < 0.0: errors.append("class %s rank power step cannot be negative" % id)
    if revive_delay <= 0.0: errors.append("class %s revive delay must be positive" % id)
    if revive_health_fraction <= 0.0 or revive_health_fraction > 1.0: errors.append("class %s revive health fraction must be between zero and one" % id)
    if primary_attack == null: errors.append("class %s primary attack is missing" % id)
    if primary_attack != null:
        for reason: String in primary_attack.validate(): errors.append("class %s primary %s" % [id, reason])
    if support_action != null:
        for reason: String in support_action.validate(): errors.append("class %s support %s" % [id, reason])
    return errors
