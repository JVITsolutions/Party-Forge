class_name EnemyDefinition
extends Resource

enum Behavior { SWARMER, SPITTER, FORGE_GUARDIAN }

@export var id: StringName
@export var behavior: Behavior
@export var max_health: float = 20.0
@export var move_speed: float = 3.0
@export var stat_overrides: Dictionary[StringName, float] = {}
@export var attacks: Array[AttackDefinition] = []
@export var experience: int = 1

func attack_by_id(attack_id: StringName) -> AttackDefinition:
    for attack: AttackDefinition in attacks:
        if attack != null and attack.id == attack_id: return attack
    return null

func validate(types: DamageTypeCatalog = null, stats: StatCatalog = null) -> PackedStringArray:
    var errors := PackedStringArray()
    if id.is_empty(): errors.append("enemy id is empty")
    if max_health <= 0.0: errors.append("enemy %s health must be positive" % id)
    if move_speed <= 0.0: errors.append("enemy %s speed must be positive" % id)
    var seen: Dictionary = {}
    for attack: AttackDefinition in attacks:
        if attack == null:
            errors.append("PARTY_FORGE_DAMAGE_ERROR enemy=%s attack=<null> reason=null attack" % id)
            continue
        if seen.has(attack.id): errors.append("PARTY_FORGE_DAMAGE_ERROR enemy=%s attack=%s reason=duplicate attack id" % [id, attack.id])
        seen[attack.id] = true
        errors.append_array(attack.validate(types))
    for stat_id: StringName in stat_overrides:
        var amount := float(stat_overrides[stat_id])
        if stats == null or stats.definition(stat_id) == null: errors.append("PARTY_FORGE_DAMAGE_ERROR enemy=%s stat=%s reason=unknown stat override" % [id, stat_id])
        elif not is_finite(amount): errors.append("PARTY_FORGE_DAMAGE_ERROR enemy=%s stat=%s reason=non-finite stat override" % [id, stat_id])
    var required: Array[StringName] = []
    match behavior:
        Behavior.SWARMER: required = [&"swarmer_contact"]
        Behavior.SPITTER: required = [&"spitter_projectile"]
        Behavior.FORGE_GUARDIAN: required = [&"guardian_charge", &"guardian_shockwave"]
    for required_id: StringName in required:
        if attack_by_id(required_id) == null: errors.append("PARTY_FORGE_DAMAGE_ERROR enemy=%s attack=%s reason=required behavior attack missing" % [id, required_id])
    return errors
