class_name EnemyActor
extends CharacterBody3D

signal reward_dropped(experience: int, drop_position: Vector3)
signal enemy_defeated(definition: EnemyDefinition, drop_position: Vector3)

const HOSTILE_TEAM_ID := 2

@export var definition: EnemyDefinition

var current_health: float:
    get:
        var health := _health_component()
        return health.current_health if health != null else 0.0
var is_dead: bool:
    get:
        var health := _health_component()
        return health.is_dead if health != null else true
var reward_was_dropped := false
var defeat_handled := false
var base_visual_color := Color(0.05, 0.03, 0.02)
var damage_flash_remaining := 0.0
var last_visual_health := 0.0
var combatant_id: StringName
var combat_rng: CombatRng
var damage_types: DamageTypeCatalog
var recovery_controller: RecoveryController

func _ready() -> void:
    add_to_group("hostile_actors")
    if definition != null:
        configure(definition)

func configure(enemy_definition: EnemyDefinition) -> void:
    definition = enemy_definition
    if definition == null:
        return
    var health := _health_component()
    if health == null:
        push_error("PARTY_FORGE_ENEMY_HEALTH_MISSING id=%s" % definition.id)
        return
    health.configure(definition.max_health, false, 1.0, 1.0, true)
    if not health.health_changed.is_connected(_on_health_changed): health.health_changed.connect(_on_health_changed)
    if not health.died.is_connected(defeat): health.died.connect(defeat)
    reward_was_dropped = false
    defeat_handled = false
    damage_flash_remaining = 0.0
    last_visual_health = health.current_health
    base_visual_color = _current_visual_color()
    _configure_recovery()

func configure_combat(sequence_id: Variant, rng: CombatRng, types: DamageTypeCatalog) -> void:
    combatant_id = StringName("enemy:%s" % sequence_id)
    combat_rng = rng
    damage_types = types
    _configure_recovery()

func get_combat_adapter(tags: Array[StringName]) -> CombatantAdapter:
    var base_values: Dictionary = definition.stat_overrides.duplicate(true) if definition != null else {}
    if definition != null:
        base_values[&"max_health"] = definition.max_health
        base_values[&"move_speed"] = definition.move_speed
    var capabilities: Array[StringName] = []
    var sources: Array[StatModifierSource] = []
    var stats := StatResolver.resolve(0, PartyManager.STAT_CATALOG, base_values, capabilities, sources, tags, 0)
    var health := _health_component()
    return CombatantAdapter.new(self, combatant_id, HOSTILE_TEAM_ID, health, stats, health != null and not health.is_dead, Callable(self, "_incoming_damage_multiplier"))

func prepare_attack(attack_id: StringName) -> DamagePacket:
    var attack := definition.attack_by_id(attack_id) if definition != null else null
    return DamageResolver.prepare(attack, get_combat_adapter(DamageResolver.action_tags_for(attack)), combat_rng, damage_types)

func attack_geometry(attack_id: StringName) -> ResolvedAttackGeometry:
    var attack := definition.attack_by_id(attack_id) if definition != null else null
    if attack == null:
        return ResolvedAttackGeometry.new(0.0, 0.0)
    var adapter := get_combat_adapter(DamageResolver.action_tags_for(attack))
    var range_multiplier := adapter.stat_value(&"attack_range", 1.0) if adapter != null else 1.0
    var area_multiplier := adapter.stat_value(&"area_size", 1.0) if adapter != null else 1.0
    return ResolvedAttackGeometry.from_attack(attack, range_multiplier, area_multiplier)

func resolve_attack(packet: DamagePacket, target: CombatantAdapter) -> DamageResult:
    return DamageResolver.resolve(packet, target, combat_rng, damage_types)

func defeat() -> void:
    if defeat_handled:
        return
    defeat_handled = true
    velocity = Vector3.ZERO
    var health := _health_component()
    if health != null and not health.is_dead:
        health.kill()
    var drop_position := global_position if is_inside_tree() else position
    _drop_reward_once(drop_position)
    enemy_defeated.emit(definition, drop_position)
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
    var selected: Node3D = null
    var best_distance := INF
    var origin := global_position if is_inside_tree() else position
    for actor: Node3D in living_party_actors(candidates):
        var actor_position := actor.global_position if actor.is_inside_tree() else actor.position
        var distance := origin.distance_squared_to(actor_position)
        if selected == null or distance < best_distance:
            selected = actor
            best_distance = distance
    return selected

func _drop_reward_once(drop_position: Vector3) -> void:
    if reward_was_dropped:
        return
    reward_was_dropped = true
    var reward := definition.experience if definition != null else 0
    reward_dropped.emit(reward, drop_position)

func _health_component() -> HealthComponent:
    return get_node_or_null("HealthComponent") as HealthComponent

func _on_health_changed(current: float, _maximum: float) -> void:
    if current < last_visual_health:
        damage_flash_remaining = 0.1
        _set_visual_color(Color.WHITE)
    last_visual_health = current

func _move_for_delta(delta: float) -> void:
    if is_inside_tree():
        move_and_slide()
    else:
        position += velocity * maxf(delta, 0.0)

func _process(delta: float) -> void:
    if recovery_controller != null:
        recovery_controller.advance(delta)
    if damage_flash_remaining <= 0.0 or is_dead:
        return
    damage_flash_remaining = maxf(0.0, damage_flash_remaining - maxf(delta, 0.0))
    if damage_flash_remaining <= 0.0:
        _set_visual_color(base_visual_color)

func _configure_recovery() -> void:
    if recovery_controller == null:
        recovery_controller = get_node_or_null("RecoveryController") as RecoveryController
    if recovery_controller == null:
        recovery_controller = RecoveryController.new()
        recovery_controller.name = "RecoveryController"
        add_child(recovery_controller)
    recovery_controller.configure(_health_component(), Callable(self, "_health_regeneration_rate"))

func _health_regeneration_rate() -> float:
    var adapter := get_combat_adapter([])
    return adapter.stat_value(&"health_regeneration", 0.0)

func _incoming_damage_multiplier(_packet: DamagePacket) -> float:
    return 1.0

func _current_visual_color() -> Color:
    var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
    if mesh == null:
        return base_visual_color
    var material := mesh.material_override as StandardMaterial3D
    if material == null and mesh.mesh != null:
        material = mesh.mesh.material as StandardMaterial3D
    return material.albedo_color if material != null else base_visual_color

func _set_visual_color(color: Color) -> void:
    var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
    if mesh == null:
        return
    var material := mesh.material_override as StandardMaterial3D
    if material == null and mesh.mesh != null:
        material = mesh.mesh.material as StandardMaterial3D
    if material == null:
        return
    material = material.duplicate() as StandardMaterial3D
    material.albedo_color = color
    mesh.material_override = material
