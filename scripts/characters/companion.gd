class_name Companion
extends PartyActor

const FormationMathScript := preload("res://scripts/formation/formation_math.gd")

@export var leader: PartyActor
@export_range(0.1, 5.0, 0.1) var separation_radius: float = 1.5

func _physics_process(_delta: float) -> void:
    var health: HealthComponent = _health_component()
    if leader == null or member_state == null or member_state.class_definition == null:
        velocity = Vector3.ZERO
        return
    if (is_inside_tree() and get_tree().paused) or (health != null and (health.is_downed or health.is_dead)):
        velocity = Vector3.ZERO
        return

    var definition: ClassDefinition = member_state.class_definition
    var target: CombatTarget = _nearest_hostile()
    var threat_position: Vector3 = target.position if target != null else leader.global_position
    velocity = FormationMathScript.desired_velocity(
        definition.role,
        global_position,
        leader.global_position,
        threat_position,
        definition.preferred_distance,
        definition.tether_distance,
        _party_separation(),
        move_speed
    )
    move_and_slide()

func _nearest_hostile() -> CombatTarget:
    if not is_inside_tree():
        return null
    var candidates: Array[CombatTarget] = []
    for node: Node in get_tree().get_nodes_in_group("hostile_actors"):
        if not node.has_method("get_combat_target"):
            continue
        var candidate: CombatTarget = node.call("get_combat_target") as CombatTarget
        if candidate != null:
            candidates.append(candidate)
    return TargetSelector.nearest(global_position, candidates, INF, team_id)

func _party_separation() -> Vector3:
    if not is_inside_tree():
        return Vector3.ZERO
    var result := Vector3.ZERO
    var radius_squared: float = separation_radius * separation_radius
    for node: Node in get_tree().get_nodes_in_group("party_actors"):
        var other := node as Node3D
        if other == null or other == self:
            continue
        var offset := global_position - other.global_position
        offset.y = 0.0
        var distance_squared := offset.length_squared()
        if distance_squared > radius_squared:
            continue
        if distance_squared < 0.0001:
            var angle := deg_to_rad(float((get_instance_id() * 137) % 360))
            result += Vector3(cos(angle), 0.0, sin(angle))
            continue
        var distance := sqrt(distance_squared)
        result += offset / distance * (1.0 - distance / separation_radius)
    return result
