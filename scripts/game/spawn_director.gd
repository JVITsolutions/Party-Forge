class_name SpawnDirector
extends Node

signal enemy_spawned(enemy_id: StringName, enemy: Node3D)

const SpawnScheduleScript := preload("res://scripts/game/spawn_schedule.gd")
const SWARMER_SCENE := preload("res://scenes/enemies/swarmer.tscn")
const SPITTER_SCENE := preload("res://scenes/enemies/spitter.tscn")
const EXPERIENCE_ORB_SCENE := preload("res://scenes/progression/experience_orb.tscn")

var elapsed_seconds := 0.0
var spawn_cooldown := 0.0
var rng := RandomNumberGenerator.new()
var leader: Node3D
var experience_system: ExperienceSystem
var spawn_markers: Array[Node3D] = []
var camera: Camera3D
var enemies_parent: Node
var effects_parent: Node
var pickup_radius_multiplier := 1.0

func configure(seed_value: int, target_leader: Node3D, target_experience: ExperienceSystem, markers: Array[Node3D], view_camera: Camera3D = null, enemy_container: Node = null, effect_container: Node = null, radius_multiplier: float = 1.0) -> void:
    rng.seed = seed_value
    leader = target_leader
    experience_system = target_experience
    spawn_markers = markers.duplicate()
    camera = view_camera
    enemies_parent = enemy_container
    effects_parent = effect_container
    pickup_radius_multiplier = maxf(radius_multiplier, 0.0)
    elapsed_seconds = 0.0
    spawn_cooldown = 0.0

func _process(delta: float) -> void:
    advance_time(delta)

func advance_time(delta: float) -> void:
    if delta <= 0.0 or _tree_is_paused():
        return
    var remaining := delta
    while remaining > 0.0 and elapsed_seconds < 300.0:
        var band: RefCounted = active_band()
        if band == null:
            break
        if spawn_cooldown <= 0.0:
            spawn_enemy(sample_enemy_id(elapsed_seconds))
            spawn_cooldown = float(band.get("interval"))
        var step := minf(minf(remaining, spawn_cooldown), 300.0 - elapsed_seconds)
        elapsed_seconds += step
        remaining -= step
        spawn_cooldown -= step
        if step <= 0.0:
            break
    if remaining > 0.0:
        elapsed_seconds += remaining

func active_band() -> RefCounted:
    return SpawnScheduleScript.sample(elapsed_seconds)

func sample_enemy_id(sample_time: float = -1.0) -> StringName:
    var at_time := elapsed_seconds if sample_time < 0.0 else sample_time
    var band: RefCounted = SpawnScheduleScript.sample(at_time)
    if band == null:
        return &""
    var swarmer_weight := int(band.get("swarmer_weight"))
    var total := swarmer_weight + int(band.get("spitter_weight"))
    if total <= 0:
        return &""
    return &"swarmer" if rng.randi_range(1, total) <= swarmer_weight else &"spitter"

func spawn_enemy(enemy_id: StringName) -> Node3D:
    if enemy_id.is_empty():
        return null
    var marker := _choose_spawn_marker()
    if marker == null:
        return null
    var spawn_position := marker.global_position if marker.is_inside_tree() else marker.position
    var scene: PackedScene = SWARMER_SCENE if enemy_id == &"swarmer" else SPITTER_SCENE
    var enemy := scene.instantiate() as Node3D
    var parent := enemies_parent if enemies_parent != null and is_instance_valid(enemies_parent) else get_parent()
    if parent == null:
        enemy.free()
        return null
    parent.add_child(enemy)
    if enemy.is_inside_tree():
        enemy.global_position = spawn_position
    else:
        enemy.position = spawn_position
    if enemy.has_method("configure_target"):
        enemy.call("configure_target", leader, effects_parent)
    enemy.connect("reward_dropped", _on_reward_dropped)
    enemy_spawned.emit(enemy_id, enemy)
    return enemy

func set_pickup_radius_multiplier(multiplier: float) -> void:
    pickup_radius_multiplier = maxf(multiplier, 0.0)
    if effects_parent == null or not is_instance_valid(effects_parent):
        return
    for child: Node in effects_parent.get_children():
        if child != self and child.has_method("set_pickup_radius_multiplier"):
            child.call("set_pickup_radius_multiplier", pickup_radius_multiplier)

func _choose_spawn_marker() -> Node3D:
    var eligible: Array[Node3D] = []
    for marker: Node3D in spawn_markers:
        if marker == null or not is_instance_valid(marker):
            continue
        var marker_position := marker.global_position if marker.is_inside_tree() else marker.position
        if camera == null or not camera.is_inside_tree() or not camera.is_position_in_frustum(marker_position):
            eligible.append(marker)
    if eligible.is_empty():
        return null
    return eligible[rng.randi_range(0, eligible.size() - 1)]

func _on_reward_dropped(experience: int, drop_position: Vector3) -> void:
    var parent := effects_parent if effects_parent != null and is_instance_valid(effects_parent) else get_parent()
    if parent == null:
        return
    var orb := EXPERIENCE_ORB_SCENE.instantiate() as Node3D
    parent.add_child(orb)
    orb.global_position = drop_position
    orb.call("configure", experience, leader, experience_system, pickup_radius_multiplier)

func _tree_is_paused() -> bool:
    var tree := Engine.get_main_loop() as SceneTree
    return tree != null and tree.paused
