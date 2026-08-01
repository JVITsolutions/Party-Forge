class_name Swarmer
extends "res://scripts/enemies/enemy_actor.gd"

var contact_cooldowns: Dictionary = {}

func _physics_process(delta: float) -> void:
    advance_behavior(delta)

func advance_behavior(delta: float, candidates: Array[Node3D] = []) -> void:
    if is_dead or definition == null:
        velocity = Vector3.ZERO
        return
    _advance_contact_cooldowns(delta)
    var target := nearest_living_party_actor(candidates)
    if target == null:
        velocity = Vector3.ZERO
        return
    var origin := global_position if is_inside_tree() else position
    var target_position := target.global_position if target.is_inside_tree() else target.position
    var offset := target_position - origin
    offset.y = 0.0
    velocity = offset.normalized() * definition.move_speed if not offset.is_zero_approx() else Vector3.ZERO
    var contact_range := attack_geometry(&"swarmer_contact").range
    if contact_range > 0.0 and offset.length() <= contact_range:
        _try_contact_attack(target)
    _move_for_delta(delta)

func _try_contact_attack(target: Node3D) -> void:
    var target_id := target.get_instance_id()
    if float(contact_cooldowns.get(target_id, 0.0)) > 0.0:
        return
    if not target.has_method("get_combat_adapter"):
        return
    var packet := prepare_attack(&"swarmer_contact")
    if packet == null or not packet.valid:
        return
    var target_adapter := target.call("get_combat_adapter", packet.action_tags) as CombatantAdapter
    var result := resolve_attack(packet, target_adapter)
    if result != null and result.valid:
        var attack := definition.attack_by_id(&"swarmer_contact")
        contact_cooldowns[target_id] = attack.cooldown if attack != null else 0.0

func _advance_contact_cooldowns(delta: float) -> void:
    for target_id: Variant in contact_cooldowns.keys():
        var remaining := maxf(float(contact_cooldowns[target_id]) - maxf(delta, 0.0), 0.0)
        if remaining <= 0.0:
            contact_cooldowns.erase(target_id)
        else:
            contact_cooldowns[target_id] = remaining
