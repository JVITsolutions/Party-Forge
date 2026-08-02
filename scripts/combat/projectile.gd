class_name PartyProjectile
extends Node3D

const AREA_BURST_SCENE := preload("res://scenes/combat/area_burst.tscn")

var packet: DamagePacket
var combat_rng: CombatRng
var damage_types: DamageTypeCatalog
var speed := 0.0
var area_radius := 0.0
var maximum_range := 0.0
var lifetime := 0.1
var elapsed := 0.0
var distance_travelled := 0.0
var target: CombatTarget
var effects_parent: Node
var combatants: Array[Node3D] = []
var direction := Vector3.FORWARD
var impact_scene: PackedScene
var impact_color := Color.WHITE
var visual_scale := Vector3.ONE

func configure(damage_packet: DamagePacket, rng: CombatRng, types: DamageTypeCatalog, projectile_speed: float, impact_radius: float, range_limit: float, duration: float, combat_target: CombatTarget, effect_container: Node, actor_candidates: Array[Node3D] = [], presentation_impact_scene: PackedScene = null, presentation_impact_color: Color = Color.WHITE, presentation_scale: Vector3 = Vector3.ONE) -> void:
    packet = damage_packet
    combat_rng = rng
    damage_types = types
    speed = maxf(projectile_speed, 0.01)
    area_radius = maxf(impact_radius, 0.0)
    maximum_range = maxf(range_limit, 0.01)
    lifetime = clampf(duration, 0.01, 10.0)
    target = combat_target
    effects_parent = effect_container
    combatants = actor_candidates
    impact_scene = presentation_impact_scene
    impact_color = presentation_impact_color
    visual_scale = presentation_scale if presentation_scale.is_finite() else Vector3.ONE
    scale = visual_scale
    elapsed = 0.0
    distance_travelled = 0.0
    _refresh_direction()

func _process(delta: float) -> void:
    var step_delta := maxf(delta, 0.0)
    elapsed += step_delta
    if elapsed >= lifetime or distance_travelled >= maximum_range:
        _spawn_impact_presentation()
        queue_free()
        return
    if target != null and target.actor != null:
        if not is_instance_valid(target.actor):
            queue_free()
            return
        target.position = target.actor.global_position if target.actor.is_inside_tree() else target.actor.position
        if target.actor.has_method("get_combat_target"):
            var refreshed: CombatTarget = target.actor.call("get_combat_target") as CombatTarget
            if refreshed == null or not refreshed.is_available or packet == null or refreshed.team_id == packet.source_team_id:
                queue_free()
                return
            target = refreshed
    _refresh_direction()
    var step: float = minf(speed * step_delta, maximum_range - distance_travelled)
    var current_position := _current_position()
    var target_distance: float = current_position.distance_to(target.position) if target != null else INF
    if target != null and target_distance <= step:
        distance_travelled += target_distance
        _set_current_position(target.position)
        _impact()
        return
    _set_current_position(current_position + direction * step)
    distance_travelled += step
    if distance_travelled >= maximum_range:
        _spawn_impact_presentation()
        queue_free()

func _refresh_direction() -> void:
    if target == null:
        return
    var current_position := _current_position()
    var next_direction: Vector3 = (target.position - current_position).normalized()
    if not next_direction.is_zero_approx():
        direction = next_direction

func _impact() -> void:
    _spawn_impact_presentation()
    if area_radius > 0.0:
        var burst := AREA_BURST_SCENE.instantiate() as Node3D
        var parent := _effect_parent()
        if parent != null:
            parent.add_child(burst)
            if is_inside_tree() and burst.is_inside_tree():
                burst.global_position = global_position
            else:
                burst.position = position
            burst.call("configure", packet, combat_rng, damage_types, area_radius, 0.25, combatants)
    elif packet != null and target != null and target.team_id != packet.source_team_id and target.is_available and target.actor != null and target.actor.has_method("get_combat_adapter"):
        var adapter := target.actor.call("get_combat_adapter", packet.action_tags) as CombatantAdapter
        if adapter != null:
            DamageResolver.resolve(packet, adapter, combat_rng, damage_types)
    queue_free()

func _spawn_impact_presentation() -> void:
    if impact_scene == null:
        return
    var candidate := impact_scene.instantiate()
    var effect := candidate as Node3D
    if effect == null:
        if candidate != null:
            candidate.free()
        return
    var parent := _effect_parent()
    if parent == null:
        effect.free()
        return
    parent.add_child(effect)
    if is_inside_tree() and effect.is_inside_tree():
        effect.global_position = global_position
    else:
        effect.position = position
    if effect.has_method(&"configure"):
        effect.call(&"configure", impact_color)

func _effect_parent() -> Node:
    if effects_parent != null and is_instance_valid(effects_parent):
        return effects_parent
    return get_parent()

func _current_position() -> Vector3:
    return global_position if is_inside_tree() else position

func _set_current_position(value: Vector3) -> void:
    if is_inside_tree():
        global_position = value
    else:
        position = value
