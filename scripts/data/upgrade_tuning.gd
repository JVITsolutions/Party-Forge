class_name UpgradeTuning
extends Resource

@export var party_stat_max_rank: int = 20
@export var max_health_per_rank: float = 0.05
@export var damage_per_rank: float = 0.05
@export var move_speed_per_rank: float = 0.03
@export var attack_speed_per_rank: float = 0.04
@export var pickup_radius_per_rank: float = 0.20
@export var trait_upgrade_value_step: float = 0.25

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if party_stat_max_rank <= 0: errors.append("party stat max rank must be positive")
    for entry: Array in [
        ["max health", max_health_per_rank], ["damage", damage_per_rank],
        ["move speed", move_speed_per_rank], ["attack speed", attack_speed_per_rank],
        ["pickup radius", pickup_radius_per_rank], ["trait upgrade", trait_upgrade_value_step]
    ]:
        if float(entry[1]) <= 0.0: errors.append("%s step must be positive" % entry[0])
    return errors
