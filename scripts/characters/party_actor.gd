class_name PartyActor
extends CharacterBody3D

const AttackExecutorScript := preload("res://scripts/combat/attack_executor.gd")
const HealingSelectorScript := preload("res://scripts/combat/healing_selector.gd")
const CombatModifiersScript := preload("res://scripts/combat/combat_modifiers.gd")

const PARTY_TEAM_ID := 1
const REVIVE_DELAY := 8.0
const REVIVE_HEALTH_FRACTION := 0.5

@export var team_id: int = PARTY_TEAM_ID
@export var move_speed: float = 6.0

var member_state: PartyMemberState
var party_manager: PartyManager
var combat_effects_parent: Node
var attack_executor: Node
var support_controller: AttackController

func _ready() -> void:
    _refresh_team_group()
    _ensure_combat_runtime()

func configure(member_state: PartyMemberState) -> void:
    self.member_state = member_state
    if member_state == null or member_state.class_definition == null:
        return
    var definition: ClassDefinition = member_state.class_definition
    move_speed = definition.move_speed
    var health: HealthComponent = _health_component()
    if health != null:
        health.configure(definition.max_health, definition.armor, member_state.is_leader, REVIVE_DELAY, REVIVE_HEALTH_FRACTION)
    var attack: AttackController = _attack_controller()
    if attack != null:
        attack.configure(definition.primary_attack, team_id)
    _configure_support_controller(definition.support_action)
    var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
    if mesh != null:
        var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
        if material != null:
            material = material.duplicate() as StandardMaterial3D
            material.albedo_color = definition.color
            mesh.material_override = material
    _refresh_team_group()
    _ensure_combat_runtime()

func configure_combat(manager: PartyManager, effect_container: Node = null) -> void:
    party_manager = manager
    combat_effects_parent = effect_container
    _ensure_combat_runtime()

func _process(delta: float) -> void:
    if member_state == null or member_state.class_definition == null or not is_inside_tree() or get_tree().paused:
        return
    advance_combat(delta, _collect_combat_targets())

func advance_combat(delta: float, candidates: Array[CombatTarget]) -> void:
    if member_state == null or member_state.class_definition == null:
        return
    var health: HealthComponent = _health_component()
    if health != null and (health.is_downed or health.is_dead):
        return
    _ensure_combat_runtime()
    var modifiers: RefCounted = CombatModifiersScript.resolve(member_state, party_manager)
    var cooldown_delta: float = maxf(delta, 0.0) * float(modifiers.get("cooldown_rate_multiplier"))
    var primary := _attack_controller()
    if primary != null:
        primary.advance(cooldown_delta)
    if support_controller != null:
        support_controller.advance(cooldown_delta)

    var combat_origin: Vector3 = global_position if is_inside_tree() else position
    if support_controller != null and support_controller.definition != null and support_controller.cooldown_remaining <= 0.0:
        var allies: Array[CombatTarget] = []
        for candidate: CombatTarget in candidates:
            if candidate.team_id == team_id:
                allies.append(candidate)
        var heal_range: float = support_controller.definition.range * float(modifiers.get("range_multiplier"))
        var heal_target: CombatTarget = HealingSelectorScript.most_injured(allies, heal_range, combat_origin)
        if heal_target != null:
            support_controller.cooldown_remaining = support_controller.definition.cooldown
            support_controller.attack_ready.emit(support_controller.definition, heal_target)
    _try_primary_attack(primary, candidates, float(modifiers.get("range_multiplier")))

func receive_damage(amount: float) -> float:
    var health: HealthComponent = _health_component()
    if health == null:
        return 0.0
    return health.take_damage(amount)

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

func _ensure_combat_runtime() -> void:
    if attack_executor == null:
        attack_executor = get_node_or_null("AttackExecutor")
    if attack_executor == null:
        attack_executor = AttackExecutorScript.new() as Node
        attack_executor.name = "AttackExecutor"
        add_child(attack_executor)
    attack_executor.call("configure", self, party_manager, combat_effects_parent)
    var primary := _attack_controller()
    var execute_callable := Callable(attack_executor, "execute")
    if primary != null and not primary.attack_ready.is_connected(execute_callable):
        primary.attack_ready.connect(execute_callable)
    if support_controller != null and not support_controller.attack_ready.is_connected(execute_callable):
        support_controller.attack_ready.connect(execute_callable)

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

func _try_primary_attack(controller: AttackController, candidates: Array[CombatTarget], range_multiplier: float) -> void:
    if controller == null or controller.definition == null or controller.cooldown_remaining > 0.0:
        return
    var origin: Vector3 = global_position if is_inside_tree() else position
    var target: CombatTarget = TargetSelector.nearest(origin, candidates, controller.definition.range * range_multiplier, team_id)
    if target == null:
        return
    controller.cooldown_remaining = controller.definition.cooldown
    controller.attack_ready.emit(controller.definition, target)

func _refresh_team_group() -> void:
    remove_from_group("party_actors")
    remove_from_group("hostile_actors")
    add_to_group("party_actors" if team_id == PARTY_TEAM_ID else "hostile_actors")
