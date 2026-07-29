class_name ExperienceOrb
extends Node3D

const BASE_ATTRACTION_RADIUS := 5.0
const COLLECTION_RADIUS := 0.65
const ACCELERATION := 22.0
const MAX_SPEED := 12.0

var value := 1
var leader: Node3D
var experience_system: ExperienceSystem
var pickup_radius_multiplier := 1.0
var velocity := Vector3.ZERO
var collected := false

func configure(experience_value: int, target_leader: Node3D, target_system: ExperienceSystem, radius_multiplier: float = 1.0) -> void:
    value = maxi(experience_value, 0)
    leader = target_leader
    experience_system = target_system
    set_pickup_radius_multiplier(radius_multiplier)
    velocity = Vector3.ZERO
    collected = false

func set_pickup_radius_multiplier(multiplier: float) -> void:
    pickup_radius_multiplier = maxf(multiplier, 0.0)

func _physics_process(delta: float) -> void:
    advance_collection(delta)

func advance_collection(delta: float) -> void:
    if collected or leader == null or not is_instance_valid(leader):
        return
    var origin := global_position if is_inside_tree() else position
    var target_position := leader.global_position if leader.is_inside_tree() else leader.position
    var offset := target_position - origin
    var distance := offset.length()
    if distance <= COLLECTION_RADIUS:
        _collect()
        return
    if distance > BASE_ATTRACTION_RADIUS * pickup_radius_multiplier:
        velocity = Vector3.ZERO
        return
    velocity = velocity.move_toward(offset.normalized() * MAX_SPEED, ACCELERATION * maxf(delta, 0.0))
    var step := minf(velocity.length() * maxf(delta, 0.0), distance)
    var next_position := origin + velocity.normalized() * step if not velocity.is_zero_approx() else origin
    if is_inside_tree():
        global_position = next_position
    else:
        position = next_position

func _collect() -> void:
    if collected:
        return
    collected = true
    if experience_system != null and is_instance_valid(experience_system):
        experience_system.add_experience(value)
    queue_free()
