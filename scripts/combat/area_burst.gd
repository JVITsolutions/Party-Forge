class_name AreaBurst
extends Node3D

const COMBAT_RESOLUTION_SERVICE := preload("res://scripts/combat/combat_resolution_service.gd")

var packet: DamagePacket
var combat_rng: CombatRng
var damage_types: DamageTypeCatalog
var radius := 0.0
var lifetime := 0.25
var elapsed := 0.0
var applied := false
var combatants: Array[Node3D] = []
var combat_resolution_service: Node

func configure(damage_packet: DamagePacket, rng: CombatRng, types: DamageTypeCatalog, area_radius: float, duration: float, actor_candidates: Array[Node3D] = [], resolution_service: Node = null) -> void:
    packet = damage_packet
    combat_rng = rng
    damage_types = types
    radius = maxf(area_radius, 0.0)
    lifetime = clampf(duration, 0.01, 10.0)
    elapsed = 0.0
    applied = false
    combatants = actor_candidates
    combat_resolution_service = resolution_service
    if combat_resolution_service == null:
        combat_resolution_service = COMBAT_RESOLUTION_SERVICE.new(rng, types) as Node
        combat_resolution_service.name = "FixtureCombatResolutionService"
        add_child(combat_resolution_service)
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
    var targets: Array[CombatantAdapter] = []
    var center: Vector3 = global_position if is_inside_tree() else position
    for actor: Node3D in candidates:
        if actor == null or seen.has(actor.get_instance_id()) or not actor.has_method("get_combat_target") or not actor.has_method("get_combat_adapter"):
            continue
        seen[actor.get_instance_id()] = true
        var target: CombatTarget = actor.call("get_combat_target") as CombatTarget
        if target == null or not target.is_available or packet == null or target.team_id == packet.source_team_id:
            continue
        if center.distance_squared_to(target.position) > radius * radius:
            continue
        var adapter := actor.call("get_combat_adapter", packet.action_tags) as CombatantAdapter
        if adapter != null and adapter.available:
            targets.append(adapter)
    targets.sort_custom(func(left: CombatantAdapter, right: CombatantAdapter) -> bool: return String(left.combatant_id) < String(right.combatant_id))
    for adapter: CombatantAdapter in targets:
        combat_resolution_service.call("resolve_bundle", packet, adapter)

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
