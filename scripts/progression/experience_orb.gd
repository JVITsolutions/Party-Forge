class_name ExperienceOrb
extends Node3D

const BASE_ATTRACTION_RADIUS := 5.0
const COLLECTION_RADIUS := 0.65
const ACCELERATION := 22.0
const MAX_SPEED := 12.0

var value := 1
var packet_id: StringName = &""
var leader: Node3D
var reward_distributor: RewardDistributionService
var pickup_radius_multiplier := 1.0
var velocity := Vector3.ZERO
var collected := false

func configure(experience_value: int, target_packet_or_leader: Variant, target_leader_or_system: Variant, distributor_or_radius: Variant = null, radius_multiplier: float = 1.0) -> void:
    value = maxi(experience_value, 0)
    var configured_radius := radius_multiplier
    if target_packet_or_leader is Node3D:
        packet_id = &""
        leader = target_packet_or_leader as Node3D
        reward_distributor = null
        configured_radius = float(distributor_or_radius)
    else:
        packet_id = StringName(target_packet_or_leader)
        leader = target_leader_or_system as Node3D
        reward_distributor = distributor_or_radius as RewardDistributionService
    set_pickup_radius_multiplier(configured_radius)
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
    var origin := global_position if is_inside_tree() else position
    var packet := RewardPacket.create(packet_id, value, origin)
    if reward_distributor != null and is_instance_valid(reward_distributor):
        reward_distributor.distribute(packet)
    else:
        push_error(format_distributor_unavailable(packet_id))
    queue_free()

static func format_distributor_unavailable(target_packet_id: StringName) -> String:
    return "PARTY_FORGE_REWARD_ERROR packet=%s reason=distributor unavailable" % target_packet_id
