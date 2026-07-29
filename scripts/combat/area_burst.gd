class_name AreaBurst
extends Node3D

var team_id := 0
var damage := 0.0
var radius := 0.0
var lifetime := 0.25
var elapsed := 0.0
var applied := false
var combatants: Array[Node3D] = []

func configure(own_team: int, damage_amount: float, area_radius: float, duration: float, actor_candidates: Array[Node3D] = []) -> void:
    team_id = own_team
    damage = maxf(damage_amount, 0.0)
    radius = maxf(area_radius, 0.0)
    lifetime = clampf(duration, 0.01, 10.0)
    elapsed = 0.0
    combatants = actor_candidates
    scale = Vector3.ONE * maxf(radius * 2.0, 0.01)
    _apply_damage_once()

func _process(delta: float) -> void:
    elapsed += maxf(delta, 0.0)
    if elapsed >= lifetime:
        queue_free()

func _apply_damage_once() -> void:
    if applied:
        return
    applied = true
    var candidates := _combatants()
    var seen: Dictionary = {}
    var center: Vector3 = global_position if is_inside_tree() else position
    for actor: Node3D in candidates:
        if actor == null or seen.has(actor.get_instance_id()) or not actor.has_method("get_combat_target"):
            continue
        seen[actor.get_instance_id()] = true
        var target: CombatTarget = actor.call("get_combat_target") as CombatTarget
        if target == null or not target.is_available or target.team_id == team_id:
            continue
        if center.distance_squared_to(target.position) > radius * radius:
            continue
        if actor.has_method("receive_damage"):
            actor.call("receive_damage", damage)

func _combatants() -> Array[Node3D]:
    if not combatants.is_empty():
        return combatants
    var result: Array[Node3D] = []
    if not is_inside_tree():
        return result
    for group_name: StringName in [&"party_actors", &"hostile_actors"]:
        for node: Node in get_tree().get_nodes_in_group(group_name):
            var actor := node as Node3D
            if actor != null:
                result.append(actor)
    return result
