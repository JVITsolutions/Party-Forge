class_name PartyActor
extends CharacterBody3D

const AttackExecutorScript := preload("res://scripts/combat/attack_executor.gd")
const AttackSequenceControllerScript := preload("res://scripts/combat/attack_sequence_controller.gd")
const HealingSelectorScript := preload("res://scripts/combat/healing_selector.gd")
const CombatModifiersScript := preload("res://scripts/combat/combat_modifiers.gd")

const PARTY_TEAM_ID := 1
const DEFAULT_COMBAT_POLICY := preload("res://scripts/game/combat_test_policy.gd")
@export var team_id: int = PARTY_TEAM_ID
@export var move_speed: float = 6.0

var member_state: PartyMemberState
var party_manager: PartyManager
var combat_effects_parent: Node
var attack_executor: Node
var attack_sequence_controller: AttackSequenceController
var recovery_controller: RecoveryController
var support_controller: AttackController
var base_visual_color := Color.WHITE
var damage_flash_remaining := 0.0
var last_visual_health := 0.0
var _runtime_stats_initialized := false
var combat_policy: CombatTestPolicy = DEFAULT_COMBAT_POLICY.new(false, 100, false, false, 4)

func _ready() -> void:
    _refresh_team_group()
    _ensure_combat_runtime()

@warning_ignore("shadowed_variable")
func configure(member_state: PartyMemberState) -> void:
    self.member_state = member_state
    if member_state == null or member_state.class_definition == null:
        return
    var definition: ClassDefinition = member_state.class_definition
    move_speed = definition.move_speed
    var health: HealthComponent = _health_component()
    if health != null:
        health.configure(definition.max_health, member_state.is_leader, definition.revive_delay, definition.revive_health_fraction)
        _runtime_stats_initialized = false
        last_visual_health = health.current_health
        if not health.health_changed.is_connected(_on_visual_health_changed): health.health_changed.connect(_on_visual_health_changed)
        if not health.downed.is_connected(_on_visual_downed): health.downed.connect(_on_visual_downed)
        if not health.revived.is_connected(_on_visual_revived): health.revived.connect(_on_visual_revived)
    var attack: AttackController = _attack_controller()
    if attack != null:
        attack.configure(definition.primary_attack, team_id)
    _configure_support_controller(definition.support_action)
    base_visual_color = definition.color
    var presentation := _presentation()
    if presentation == null or not presentation.apply_profile(definition.visual_profile, base_visual_color):
        _set_visual_color(base_visual_color)
    _refresh_team_group()
    _ensure_combat_runtime()
    _apply_combat_policy()

func configure_combat_policy(policy: CombatTestPolicy) -> void:
    combat_policy = policy if policy != null else DEFAULT_COMBAT_POLICY.new(false, 100, false, false, 4)
    _apply_combat_policy()

func _apply_combat_policy() -> void:
    var health := _health_component()
    if health == null:
        return
    health.configure_damage_floor(0.0)
    if not health.damage_received.is_connected(_on_visual_damage_received):
        health.damage_received.connect(_on_visual_damage_received)
    var minimum_health := combat_policy.minimum_party_health()
    if minimum_health <= 0.0:
        return
    var ownership_error := _party_ownership_error()
    if not ownership_error.is_empty():
        var member_id := member_state.member_id if member_state != null else -1
        push_error("PARTY_FORGE_GOD_MODE_OWNERSHIP_ERROR team=%d member=%d reason=%s" % [team_id, member_id, ownership_error])
        return
    health.configure_damage_floor(minimum_health)

func _party_ownership_error() -> String:
    if team_id != PARTY_TEAM_ID:
        return "actor team is not party-owned"
    if member_state == null:
        return "member state is missing"
    if party_manager == null:
        return "party manager is missing"
    var managed_member := party_manager.member_by_id(member_state.member_id)
    if managed_member == null:
        return "member is not registered with party manager"
    if not is_same(managed_member, member_state):
        return "member state does not match party manager"
    return ""

func configure_combat(manager: PartyManager, effect_container: Node = null) -> void:
    if is_instance_valid(party_manager) and party_manager.upgrades_changed.is_connected(_refresh_runtime_stats):
        party_manager.upgrades_changed.disconnect(_refresh_runtime_stats)
    if is_instance_valid(party_manager) and party_manager.active_traits_changed.is_connected(_on_active_traits_changed):
        party_manager.active_traits_changed.disconnect(_on_active_traits_changed)
    if is_instance_valid(party_manager) and party_manager.stats_changed.is_connected(_on_stats_changed):
        party_manager.stats_changed.disconnect(_on_stats_changed)
    party_manager = manager
    combat_effects_parent = effect_container
    if is_instance_valid(party_manager):
        if not party_manager.upgrades_changed.is_connected(_refresh_runtime_stats): party_manager.upgrades_changed.connect(_refresh_runtime_stats)
        if not party_manager.active_traits_changed.is_connected(_on_active_traits_changed): party_manager.active_traits_changed.connect(_on_active_traits_changed)
        if not party_manager.stats_changed.is_connected(_on_stats_changed): party_manager.stats_changed.connect(_on_stats_changed)
    _refresh_runtime_stats()
    _configure_recovery()
    _ensure_combat_runtime()
    _apply_combat_policy()

func _process(delta: float) -> void:
    _advance_visual_feedback(delta)
    if member_state == null or member_state.class_definition == null or not is_inside_tree() or get_tree().paused:
        return
    if recovery_controller != null:
        recovery_controller.advance(delta)
    advance_combat(delta, _collect_combat_targets())

func advance_combat(delta: float, candidates: Array[CombatTarget]) -> void:
    if member_state == null or member_state.class_definition == null:
        return
    var health: HealthComponent = _health_component()
    if health != null and (health.is_downed or health.is_dead):
        if attack_sequence_controller != null and attack_sequence_controller.is_busy():
            attack_sequence_controller.cancel_for_owner_downed()
        return
    _ensure_combat_runtime()
    var combatants: Array[Node3D] = []
    for candidate: CombatTarget in candidates:
        if candidate != null and candidate.actor != null and is_instance_valid(candidate.actor):
            combatants.append(candidate.actor)
    attack_executor.call("configure", self, party_manager, combat_effects_parent, combatants)
    var modifiers: RefCounted = CombatModifiersScript.resolve(member_state, party_manager)
    var primary := _attack_controller()
    _advance_action_cooldown(primary, delta)
    _advance_action_cooldown(support_controller, delta)
    if attack_sequence_controller != null:
        attack_sequence_controller.advance(maxf(delta, 0.0))

    var combat_origin: Vector3 = global_position if is_inside_tree() else position
    if support_controller != null and support_controller.definition != null and support_controller.cooldown_remaining <= 0.0 and not attack_sequence_controller.is_busy():
        var allies: Array[CombatTarget] = []
        for candidate: CombatTarget in candidates:
            if candidate != null and candidate.team_id == team_id:
                allies.append(candidate)
        var support_geometry := ResolvedAttackGeometry.from_attack(
            support_controller.definition,
            float(modifiers.get("range_multiplier")),
            float(modifiers.get("area_multiplier"))
        )
        var heal_target: CombatTarget = HealingSelectorScript.most_injured(allies, support_geometry.range, combat_origin)
        if heal_target != null:
            support_controller.cooldown_remaining = support_controller.definition.cooldown
            support_controller.attack_ready.emit(support_controller.definition, heal_target)
    _try_primary_attack(primary, candidates, float(modifiers.get("range_multiplier")), float(modifiers.get("area_multiplier")))

func get_combat_adapter(tags: Array[StringName]) -> CombatantAdapter:
    var health := _health_component()
    var identity := StringName("party:%d" % member_state.member_id) if member_state != null else &""
    var stats := party_manager.stats_for_action(member_state.member_id, tags) if party_manager != null and member_state != null else null
    var available := member_state != null and health != null and not health.is_downed and not health.is_dead
    return CombatantAdapter.new(self, identity, team_id, health, stats, available, Callable(self, "_incoming_damage_multiplier"))

func get_combat_target() -> CombatTarget:
    var target_position: Vector3 = global_position if is_inside_tree() else position
    var target := CombatTarget.new(self, target_position, team_id)
    var health: HealthComponent = _health_component()
    target.is_available = health == null or (not health.is_downed and not health.is_dead)
    return target

func _health_component() -> HealthComponent:
    return get_node_or_null("HealthComponent") as HealthComponent

func _attack_controller() -> AttackController:
    return get_node_or_null("AttackController") as AttackController

func _presentation() -> CharacterPresentation:
    return get_node_or_null("Presentation") as CharacterPresentation

func update_presentation_locomotion() -> void:
    var presentation := _presentation()
    if presentation != null and presentation.active_profile != null:
        presentation.update_locomotion(velocity)

func _configure_support_controller(definition: AttackDefinition) -> void:
    if definition == null:
        if support_controller != null:
            support_controller.configure(null, team_id)
        return
    if support_controller == null:
        support_controller = get_node_or_null("SupportController") as AttackController
    if support_controller == null:
        support_controller = AttackController.new()
        support_controller.name = "SupportController"
        add_child(support_controller)
    support_controller.configure(definition, team_id)

func _configure_recovery() -> void:
    if recovery_controller == null:
        recovery_controller = get_node_or_null("RecoveryController") as RecoveryController
    if recovery_controller == null:
        recovery_controller = RecoveryController.new()
        recovery_controller.name = "RecoveryController"
        add_child(recovery_controller)
    recovery_controller.configure(_health_component(), Callable(self, "_health_regeneration_rate"))

func _health_regeneration_rate() -> float:
    if party_manager == null or member_state == null:
        return 0.0
    var stats := party_manager.stats_for(member_state.member_id)
    return stats.value(&"health_regeneration", 0.0) if stats != null else 0.0

func _incoming_damage_multiplier(_packet: DamagePacket) -> float:
    return party_manager.incoming_damage_multiplier(self) if party_manager != null else 1.0

func _ensure_combat_runtime() -> void:
    if attack_executor == null:
        attack_executor = get_node_or_null("AttackExecutor")
    if attack_executor == null:
        attack_executor = AttackExecutorScript.new() as Node
        attack_executor.name = "AttackExecutor"
        add_child(attack_executor)
    attack_executor.call("configure", self, party_manager, combat_effects_parent)
    if attack_sequence_controller == null:
        attack_sequence_controller = get_node_or_null("AttackSequenceController") as AttackSequenceController
    if attack_sequence_controller == null:
        attack_sequence_controller = AttackSequenceControllerScript.new() as AttackSequenceController
        attack_sequence_controller.name = "AttackSequenceController"
        add_child(attack_sequence_controller)
    attack_sequence_controller.configure(self, _presentation(), attack_executor)
    var primary := _attack_controller()
    var execute_callable := Callable(attack_executor, "execute")
    var sequence_callable := Callable(self, "_on_attack_requested")
    for controller: AttackController in [primary, support_controller]:
        if controller == null:
            continue
        if controller.attack_ready.is_connected(execute_callable):
            controller.attack_ready.disconnect(execute_callable)
        if not controller.attack_ready.is_connected(sequence_callable):
            controller.attack_ready.connect(sequence_callable)

func _on_attack_requested(definition: AttackDefinition, target: CombatTarget) -> void:
    var presentation := _presentation()
    var attack_visual := presentation.resolve_attack_presentation(definition) if presentation != null else null
    if attack_visual == null:
        push_error("PARTY_FORGE_ATTACK_SEQUENCE_ERROR attack=%s action=<missing> token=0 reason=presentation missing" % definition.id)
        return
    var modifiers := CombatModifiersScript.resolve(member_state, party_manager)
    var cadence := CombatModifiersScript.action_cadence(member_state, party_manager, definition)
    if not bool(cadence.call("ok")):
        return
    attack_sequence_controller.request(definition, target, attack_visual, float(cadence.get("progress_multiplier")), float(modifiers.get("range_multiplier")))

func _advance_action_cooldown(controller: AttackController, delta: float) -> void:
    if controller == null or controller.definition == null:
        return
    var cadence := CombatModifiersScript.action_cadence(member_state, party_manager, controller.definition)
    if not bool(cadence.call("ok")):
        return
    controller.advance(maxf(delta, 0.0) * float(cadence.get("progress_multiplier")))

func _collect_combat_targets() -> Array[CombatTarget]:
    var targets: Array[CombatTarget] = []
    if not is_inside_tree():
        return targets
    var seen: Dictionary = {}
    for group_name: StringName in [&"party_actors", &"hostile_actors"]:
        for node: Node in get_tree().get_nodes_in_group(group_name):
            if seen.has(node.get_instance_id()) or not node.has_method("get_combat_target"):
                continue
            seen[node.get_instance_id()] = true
            var target: CombatTarget = node.call("get_combat_target") as CombatTarget
            if target != null:
                targets.append(target)
    return targets

func _try_primary_attack(controller: AttackController, candidates: Array[CombatTarget], range_multiplier: float, area_multiplier: float) -> void:
    if controller == null or controller.definition == null or controller.cooldown_remaining > 0.0 or (attack_sequence_controller != null and attack_sequence_controller.is_busy()):
        return
    var origin: Vector3 = global_position if is_inside_tree() else position
    var geometry := ResolvedAttackGeometry.from_attack(controller.definition, range_multiplier, area_multiplier)
    var target: CombatTarget = TargetSelector.nearest(origin, candidates, geometry.range, team_id)
    if target == null:
        return
    controller.cooldown_remaining = controller.definition.cooldown
    controller.attack_ready.emit(controller.definition, target)

func _refresh_team_group() -> void:
    remove_from_group("party_actors")
    remove_from_group("hostile_actors")
    add_to_group("party_actors" if team_id == PARTY_TEAM_ID else "hostile_actors")

func _on_visual_health_changed(current: float, _maximum: float) -> void:
    if current < last_visual_health:
        damage_flash_remaining = 0.1
        var presentation := _presentation()
        if presentation == null or presentation.active_profile == null:
            _set_visual_color(Color.WHITE)
    last_visual_health = current

func _on_visual_damage_received(_attempted_damage: float, _health_removed: float) -> void:
    damage_flash_remaining = 0.1
    var presentation := _presentation()
    if presentation != null and presentation.active_profile != null:
        presentation.flash_hit()
    else:
        _set_visual_color(Color.WHITE)

func _on_visual_downed() -> void:
    damage_flash_remaining = 0.0
    if attack_sequence_controller != null and attack_sequence_controller.is_busy():
        attack_sequence_controller.cancel_for_owner_downed()
    var presentation := _presentation()
    if presentation != null and presentation.active_profile != null:
        presentation.set_downed(true)
    else:
        _set_visual_color(Color(0.45, 0.45, 0.45))

func _on_visual_revived() -> void:
    damage_flash_remaining = 0.0
    var presentation := _presentation()
    if presentation != null and presentation.active_profile != null:
        presentation.set_downed(false)
    else:
        _set_visual_color(base_visual_color)

func _advance_visual_feedback(delta: float) -> void:
    var presentation := _presentation()
    if presentation != null:
        presentation.advance_visual(delta)
        presentation.advance_feedback(delta)
    if damage_flash_remaining <= 0.0:
        return
    damage_flash_remaining = maxf(0.0, damage_flash_remaining - maxf(delta, 0.0))
    if damage_flash_remaining <= 0.0:
        var health := _health_component()
        if health == null or not health.is_downed:
            if presentation == null or presentation.active_profile == null:
                _set_visual_color(base_visual_color)

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

func _on_active_traits_changed(_tiers: Dictionary) -> void:
    _refresh_runtime_stats()

func _on_stats_changed(member_id: int) -> void:
    if member_state != null and member_state.member_id == member_id:
        _refresh_runtime_stats()

func _refresh_runtime_stats() -> void:
    if member_state == null or member_state.class_definition == null:
        return
    var definition := member_state.class_definition
    var stats := party_manager.stats_for(member_state.member_id) if party_manager != null else null
    move_speed = stats.value(&"move_speed", definition.move_speed) if stats != null else definition.move_speed
    var health := _health_component()
    if health != null:
        var initialize_full_health := not _runtime_stats_initialized
        health.set_max_health(stats.value(&"max_health", health.max_health) if stats != null else definition.max_health, false)
        if initialize_full_health and not health.is_dead and not health.is_downed:
            health.current_health = health.max_health
            health.health_changed.emit(health.current_health, health.max_health)
        health.revive_delay = definition.revive_delay * (party_manager.revive_delay_multiplier() if party_manager != null else 1.0)
        health.revive_health_fraction = definition.revive_health_fraction
        _runtime_stats_initialized = true
