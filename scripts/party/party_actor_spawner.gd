class_name PartyActorSpawner
extends Node

const COMPANION_SCENE := preload("res://scenes/characters/companion.tscn")
const CompanionScript := preload("res://scripts/characters/companion.gd")
const SPAWN_RADIUS := 0.75
const GOLDEN_ANGLE := 2.399963

var party_manager: PartyManager
var actor_container: Node3D
var leader: PartyActor

func initialize(manager: PartyManager, container: Node3D, leader_actor: PartyActor) -> void:
    if party_manager != null and party_manager.member_added.is_connected(_on_member_added):
        party_manager.member_added.disconnect(_on_member_added)
    party_manager = manager
    actor_container = container
    leader = leader_actor
    if party_manager != null and not party_manager.member_added.is_connected(_on_member_added):
        party_manager.member_added.connect(_on_member_added)

func _on_member_added(member: PartyMemberState) -> void:
    if member == null or member.is_leader or actor_container == null:
        return
    var companion: PartyActor = COMPANION_SCENE.instantiate() as PartyActor
    companion.set("leader", leader)
    companion.position = _leader_position() + _spawn_offset(_companion_count())
    companion.configure(member)
    actor_container.add_child(companion)

func _companion_count() -> int:
    var count := 0
    if actor_container == null:
        return count
    for child: Node in actor_container.get_children():
        if child.get_script() == CompanionScript:
            count += 1
    return count

func _leader_position() -> Vector3:
    if leader == null:
        return Vector3.ZERO
    if leader.is_inside_tree() and actor_container != null and actor_container.is_inside_tree():
        return actor_container.to_local(leader.global_position)
    return leader.position

func _spawn_offset(index: int) -> Vector3:
    var angle := float(index) * GOLDEN_ANGLE
    return Vector3(cos(angle), 0.0, sin(angle)) * SPAWN_RADIUS
