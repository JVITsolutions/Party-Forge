class_name SpawnDirector
extends Node

signal enemy_spawned(enemy_id: StringName, enemy: Node3D)
signal enemy_defeated(event: EnemyDefeatEvent)

const SpawnScheduleScript := preload("res://scripts/game/spawn_schedule.gd")
const SWARMER_SCENE := preload("res://scenes/enemies/swarmer.tscn")
const BOLTCASTER_SCENE := preload("res://scenes/enemies/boltcaster.tscn")
const SPITTER_SCENE := preload("res://scenes/enemies/spitter.tscn")
const EXPERIENCE_ORB_SCENE := preload("res://scenes/progression/experience_orb.tscn")
const MAX_SCHEDULED_SPAWNS_PER_UPDATE := 64
const ENEMY_SCENES := {
    &"swarmer": SWARMER_SCENE,
    &"boltcaster": BOLTCASTER_SCENE,
    &"spitter": SPITTER_SCENE,
}

var elapsed_seconds := 0.0
var spawn_cooldown := 0.0
var rng := RandomNumberGenerator.new()
var run_seed := 0
var leader: Node3D
var reward_distributor: RewardDistributionService
var spawn_markers: Array[Node3D] = []
var camera: Camera3D
var enemies_parent: Node
var effects_parent: Node
var pickup_radius_multiplier := 1.0
var combat_rng: CombatRng
var damage_types: DamageTypeCatalog
var _enemy_sequence := 0
var _defeat_sequence := 0
var _reward_sequence := 0
var _enemy_density_percent := 100

func configure(seed_value: int, target_leader: Node3D, target_distributor: Variant, markers: Array[Node3D], view_camera: Camera3D, enemy_container: Node, effect_container: Node, radius_multiplier: float, shared_combat_rng: CombatRng, shared_damage_types: DamageTypeCatalog, density_percent: int = 100) -> void:
    rng.seed = seed_value
    run_seed = seed_value
    leader = target_leader
    reward_distributor = target_distributor as RewardDistributionService
    spawn_markers = markers.duplicate()
    camera = view_camera
    enemies_parent = enemy_container
    effects_parent = effect_container
    pickup_radius_multiplier = maxf(radius_multiplier, 0.0)
    combat_rng = shared_combat_rng
    damage_types = shared_damage_types
    _enemy_density_percent = clampi(density_percent, 0, 1000)
    _enemy_sequence = 0
    _defeat_sequence = 0
    _reward_sequence = 0
    elapsed_seconds = 0.0
    spawn_cooldown = 0.0

func _process(delta: float) -> void:
    advance_time(delta)

func advance_time(delta: float) -> int:
    if delta <= 0.0 or _tree_is_paused():
        return 0
    if _enemy_density_percent == 0:
        elapsed_seconds += delta
        return 0
    var scheduled_attempts := 0
    var remaining := delta
    while remaining > 0.0 and elapsed_seconds < 300.0:
        var band: RefCounted = active_band()
        if band == null:
            break
        if spawn_cooldown <= 0.0:
            spawn_enemy(sample_enemy_id(elapsed_seconds))
            scheduled_attempts += 1
            spawn_cooldown = _effective_interval(float(band.get("interval")))
            if scheduled_attempts >= MAX_SCHEDULED_SPAWNS_PER_UPDATE:
                elapsed_seconds += remaining
                return scheduled_attempts
        var step := minf(minf(remaining, spawn_cooldown), 300.0 - elapsed_seconds)
        elapsed_seconds += step
        remaining -= step
        spawn_cooldown -= step
        if step <= 0.0:
            break
    if remaining > 0.0:
        elapsed_seconds += remaining
    return scheduled_attempts

func _effective_interval(base_interval: float) -> float:
    return base_interval * 100.0 / float(_enemy_density_percent)

func active_band() -> RefCounted:
    return SpawnScheduleScript.sample(elapsed_seconds)

func sample_enemy_id(sample_time: float = -1.0) -> StringName:
    var at_time := elapsed_seconds if sample_time < 0.0 else sample_time
    var band: RefCounted = SpawnScheduleScript.sample(at_time)
    if band == null:
        return &""
    return _sample_enemy_id_from_band(band)

func _sample_enemy_id_from_band(band: RefCounted) -> StringName:
    var swarmer_weight := int(band.get("swarmer_weight"))
    var boltcaster_weight := int(band.get("boltcaster_weight"))
    var total := swarmer_weight + boltcaster_weight + int(band.get("spitter_weight"))
    if total <= 0:
        return &""
    var roll := rng.randi_range(1, total)
    if roll <= swarmer_weight:
        return &"swarmer"
    if roll <= swarmer_weight + boltcaster_weight:
        return &"boltcaster"
    return &"spitter"

func spawn_enemy(enemy_id: StringName) -> Node3D:
    if enemy_id.is_empty():
        return null
    if not ENEMY_SCENES.has(enemy_id):
        print(format_unknown_enemy_id(enemy_id))
        return null
    var marker := _choose_spawn_marker()
    if marker == null:
        return null
    var spawn_position := marker.global_position if marker.is_inside_tree() else marker.position
    var scene := ENEMY_SCENES[enemy_id] as PackedScene
    var enemy := scene.instantiate() as Node3D
    var parent := enemies_parent if enemies_parent != null and is_instance_valid(enemies_parent) else get_parent()
    if parent == null:
        enemy.free()
        return null
    parent.add_child(enemy)
    _enemy_sequence += 1
    enemy.call("configure_combat", _enemy_sequence, combat_rng, damage_types)
    if enemy.is_inside_tree():
        enemy.global_position = spawn_position
    else:
        enemy.position = spawn_position
    if enemy.has_method("configure_target"):
        enemy.call("configure_target", leader, effects_parent)
    enemy.connect("reward_dropped", _on_reward_dropped)
    var spawn_sequence := _enemy_sequence
    (enemy as EnemyActor).enemy_defeated.connect(_on_enemy_defeated.bind(spawn_sequence), CONNECT_ONE_SHOT)
    enemy_spawned.emit(enemy_id, enemy)
    return enemy

static func format_unknown_enemy_id(enemy_id: StringName) -> String:
    return "PARTY_FORGE_UNKNOWN_ENEMY_ID id=%s" % enemy_id

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
    if orb.is_inside_tree():
        orb.global_position = drop_position
    else:
        orb.position = drop_position
    _reward_sequence += 1
    var packet_id := StringName("xp_%d_%d" % [run_seed, _reward_sequence])
    orb.call("configure", experience, packet_id, leader, reward_distributor, pickup_radius_multiplier)

func _on_enemy_defeated(definition: EnemyDefinition, drop_position: Vector3, spawn_sequence: int) -> void:
    _defeat_sequence += 1
    var event := EnemyDefeatEvent.create(
        run_seed,
        _defeat_sequence,
        spawn_sequence,
        definition.id,
        definition.loot_source_category,
        drop_position,
        elapsed_seconds,
    )
    enemy_defeated.emit(event)

func _tree_is_paused() -> bool:
    var tree := Engine.get_main_loop() as SceneTree
    return tree != null and tree.paused
