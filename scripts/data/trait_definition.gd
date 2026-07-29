class_name TraitDefinition
extends Resource

const SUPPORTED_STAT_IDS: Array[StringName] = [
    &"attack_speed", &"nearby_damage_reduction", &"projectile_speed_and_range",
    &"area_size", &"cooldown_reduction", &"healing_and_revive", &"support_power"
]

@export var id: StringName
@export var display_name: String
@export var stat_id: StringName
@export var tiers: Dictionary = {2: 0.15, 4: 0.35}
@export var effect_radius: float = 0.0

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty(): errors.append("trait id is empty")
    if stat_id.is_empty(): errors.append("trait %s stat id is empty" % id)
    elif stat_id not in SUPPORTED_STAT_IDS: errors.append("trait %s unsupported stat id %s" % [id, stat_id])
    if stat_id == &"nearby_damage_reduction" and effect_radius <= 0.0:
        errors.append("trait %s effect radius must be positive" % id)
    for threshold: Variant in tiers.keys():
        if int(threshold) < 2: errors.append("trait %s threshold must be at least two" % id)
    return errors
