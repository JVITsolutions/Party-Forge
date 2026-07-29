class_name EnemyActor
extends CharacterBody3D

signal reward_dropped(experience: int, drop_position: Vector3)

const HOSTILE_TEAM_ID := 2

@export var definition: EnemyDefinition

var current_health := 1.0
var is_dead := false
var reward_was_dropped := false

func _ready() -> void:
    add_to_group("hostile_actors")
    if definition != null:
        configure(definition)

func configure(enemy_definition: EnemyDefinition) -> void:
    definition = enemy_definition
    if definition == null:
        return
    current_health = maxf(definition.max_health, 1.0)
    is_dead = false
    reward_was_dropped = false

func receive_damage(amount: float) -> float:
    if is_dead or amount <= 0.0:
        return 0.0
    var applied := minf(amount, current_health)
    current_health = maxf(current_health - amount, 0.0)
    if current_health <= 0.0:
        defeat()
    return applied

func defeat() -> void:
    if is_dead:
        return
    is_dead = true
    velocity = Vector3.ZERO
    _drop_reward_once()
    queue_free()

func get_combat_target() -> CombatTarget:
    var actor_position := global_position if is_inside_tree() else position
    var target := CombatTarget.new(self, actor_position, HOSTILE_TEAM_ID)
    target.is_available = not is_dead
    return target

func living_party_actors(candidates: Array[Node3D] = []) -> Array[Node3D]:
    var source: Array[Node3D] = candidates
    if source.is_empty() and is_inside_tree():
        for node: Node in get_tree().get_nodes_in_group("party_actors"):
            if node is Node3D:
                source.append(node as Node3D)
    var living: Array[Node3D] = []
    for actor: Node3D in source:
        if actor == null or not is_instance_valid(actor):
            continue
        if actor.has_method("get_combat_target"):
            var target: CombatTarget = actor.call("get_combat_target") as CombatTarget
            if target == null or not target.is_available or target.team_id == HOSTILE_TEAM_ID:
                continue
        living.append(actor)
    return living

func nearest_living_party_actor(candidates: Array[Node3D] = []) -> Node3D:
    var selected: Node3D
    var best_distance := INF
    var origin := global_position if is_inside_tree() else position
    for actor: Node3D in living_party_actors(candidates):
        var actor_position := actor.global_position if actor.is_inside_tree() else actor.position
        var distance := origin.distance_squared_to(actor_position)
        if selected == null or distance < best_distance:
            selected = actor
            best_distance = distance
    return selected

func _drop_reward_once() -> void:
    if reward_was_dropped:
        return
    reward_was_dropped = true
    var reward := definition.experience if definition != null else 0
    var drop_position := global_position if is_inside_tree() else position
    reward_dropped.emit(reward, drop_position)

func _move_for_delta(delta: float) -> void:
    if is_inside_tree():
        move_and_slide()
    else:
        position += velocity * maxf(delta, 0.0)
