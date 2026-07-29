class_name AttackExecutor
extends Node

const PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")
const HEAL_EFFECT_SCENE := preload("res://scenes/combat/heal_effect.tscn")
const CombatModifiersScript := preload("res://scripts/combat/combat_modifiers.gd")

var owner_actor: PartyActor
var party_manager: PartyManager
var effects_parent: Node
var combatants: Array[Node3D] = []

func configure(actor: PartyActor, manager: PartyManager, effect_container: Node, actor_candidates: Array[Node3D] = []) -> void:
    owner_actor = actor
    party_manager = manager
    effects_parent = effect_container
    combatants = actor_candidates

func execute(definition: AttackDefinition, target: CombatTarget) -> void:
    if owner_actor == null or definition == null or target == null:
        return
    var health: HealthComponent = owner_actor.get_node_or_null("HealthComponent") as HealthComponent
    if health != null and (health.is_downed or health.is_dead):
        return
    var modifiers: RefCounted = CombatModifiersScript.resolve(owner_actor.member_state, party_manager)
    match definition.kind:
        AttackDefinition.Kind.MELEE_CLEAVE:
            _execute_melee(definition.power * float(modifiers.get("power_multiplier")), definition.area_radius * float(modifiers.get("area_multiplier")))
        AttackDefinition.Kind.PROJECTILE, AttackDefinition.Kind.AREA_PROJECTILE:
            _spawn_projectile(definition, target, modifiers)
        AttackDefinition.Kind.HEAL:
            _execute_heal(definition, target, modifiers)

func _execute_melee(damage: float, radius: float) -> void:
    var seen: Dictionary = {}
    var origin: Vector3 = owner_actor.global_position if owner_actor.is_inside_tree() else owner_actor.position
    for actor: Node3D in _combatants():
        if actor == null or seen.has(actor.get_instance_id()) or not actor.has_method("get_combat_target"):
            continue
        seen[actor.get_instance_id()] = true
        var candidate: CombatTarget = actor.call("get_combat_target") as CombatTarget
        if candidate == null or not candidate.is_available or candidate.team_id == owner_actor.team_id:
            continue
        if origin.distance_squared_to(candidate.position) > radius * radius:
            continue
        if actor.has_method("receive_damage"):
            actor.call("receive_damage", damage)

func _spawn_projectile(definition: AttackDefinition, target: CombatTarget, modifiers: RefCounted) -> void:
    var parent := _effect_parent()
    if parent == null:
        return
    var projectile := PROJECTILE_SCENE.instantiate() as Node3D
    parent.add_child(projectile)
    if owner_actor.is_inside_tree() and projectile.is_inside_tree():
        projectile.global_position = owner_actor.global_position
    else:
        projectile.position = owner_actor.position
    var projectile_speed: float = definition.projectile_speed * float(modifiers.get("projectile_multiplier"))
    var maximum_range: float = definition.range * float(modifiers.get("range_multiplier"))
    var area_radius: float = definition.area_radius * float(modifiers.get("area_multiplier"))
    var lifetime: float = clampf(maximum_range / maxf(projectile_speed, 0.01) + 0.5, 0.1, 10.0)
    projectile.call("configure", owner_actor.team_id, definition.power * float(modifiers.get("power_multiplier")), projectile_speed, area_radius, maximum_range, lifetime, target, parent)

func _execute_heal(definition: AttackDefinition, target: CombatTarget, modifiers: RefCounted) -> void:
    if target.team_id != owner_actor.team_id or not target.is_available or target.actor == null:
        return
    var target_health: HealthComponent = target.actor.get_node_or_null("HealthComponent") as HealthComponent
    if target_health == null or target_health.is_downed or target_health.is_dead:
        return
    target_health.heal(definition.power * float(modifiers.get("power_multiplier")) * float(modifiers.get("healing_multiplier")))
    var parent := _effect_parent()
    if parent == null:
        return
    var effect := HEAL_EFFECT_SCENE.instantiate() as Node3D
    parent.add_child(effect)
    effect.global_position = target.position
    effect.call("configure", 0.4)

func _effect_parent() -> Node:
    if effects_parent != null and is_instance_valid(effects_parent):
        return effects_parent
    if owner_actor != null:
        return owner_actor.get_parent()
    return null

func _combatants() -> Array[Node3D]:
    if not combatants.is_empty():
        return combatants
    var result: Array[Node3D] = []
    if owner_actor == null or not owner_actor.is_inside_tree():
        return result
    for group_name: StringName in [&"party_actors", &"hostile_actors"]:
        for node: Node in owner_actor.get_tree().get_nodes_in_group(group_name):
            var actor := node as Node3D
            if actor != null:
                result.append(actor)
    return result
