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
    var action_tags := DamageResolver.action_tags_for(definition)
    var source_adapter := owner_actor.get_combat_adapter(action_tags)
    var modifiers: RefCounted = CombatModifiersScript.resolve(owner_actor.member_state, party_manager)
    if definition.kind == AttackDefinition.Kind.HEAL:
        _execute_heal(definition, target, source_adapter)
        return
    var rng := party_manager.combat_rng if party_manager != null else null
    var types := party_manager.damage_types if party_manager != null else null
    var packet := DamageResolver.prepare(definition, source_adapter, rng, types)
    if not packet.valid:
        return
    var geometry := ResolvedAttackGeometry.from_attack(
        definition,
        float(modifiers.get("range_multiplier")),
        float(modifiers.get("area_multiplier"))
    )
    match definition.kind:
        AttackDefinition.Kind.MELEE_CLEAVE:
            _execute_melee(packet, target, geometry.area_radius)
        AttackDefinition.Kind.PROJECTILE, AttackDefinition.Kind.AREA_PROJECTILE:
            _spawn_projectile(definition, target, modifiers, packet, geometry)
        _:
            push_error("PARTY_FORGE_DAMAGE_ERROR attack=%s kind=%d reason=unsupported party runtime kind" % [definition.id, definition.kind])

func _execute_melee(packet: DamagePacket, primary_target: CombatTarget, radius: float) -> void:
    if primary_target == null or not primary_target.is_available or primary_target.team_id == owner_actor.team_id:
        return
    var seen: Dictionary = {}
    var targets: Array[CombatantAdapter] = []
    for actor: Node3D in _combatants():
        if actor == null or seen.has(actor.get_instance_id()) or not actor.has_method("get_combat_target") or not actor.has_method("get_combat_adapter"):
            continue
        seen[actor.get_instance_id()] = true
        var candidate: CombatTarget = actor.call("get_combat_target") as CombatTarget
        if candidate == null or not candidate.is_available or candidate.team_id == owner_actor.team_id:
            continue
        var is_primary := candidate.actor == primary_target.actor
        if not is_primary and (radius <= 0.0 or primary_target.position.distance_squared_to(candidate.position) > radius * radius):
            continue
        var adapter := actor.call("get_combat_adapter", packet.action_tags) as CombatantAdapter
        if adapter != null and adapter.available and adapter.team_id != packet.source_team_id:
            targets.append(adapter)
    targets.sort_custom(func(left: CombatantAdapter, right: CombatantAdapter) -> bool: return String(left.combatant_id) < String(right.combatant_id))
    for adapter: CombatantAdapter in targets:
        DamageResolver.resolve(packet, adapter, party_manager.combat_rng, party_manager.damage_types)

func _spawn_projectile(definition: AttackDefinition, target: CombatTarget, modifiers: RefCounted, packet: DamagePacket, geometry: ResolvedAttackGeometry) -> void:
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
    var maximum_range: float = geometry.range
    var area_radius: float = geometry.area_radius
    var lifetime: float = clampf(maximum_range / maxf(projectile_speed, 0.01) + 0.5, 0.1, 10.0)
    projectile.call("configure", packet, party_manager.combat_rng, party_manager.damage_types, projectile_speed, area_radius, maximum_range, lifetime, target, parent, _combatants())

func _execute_heal(definition: AttackDefinition, target: CombatTarget, source_adapter: CombatantAdapter) -> void:
    if target.team_id != owner_actor.team_id or not target.is_available or target.actor == null:
        return
    var target_health: HealthComponent = target.actor.get_node_or_null("HealthComponent") as HealthComponent
    if target_health == null or target_health.is_downed or target_health.is_dead:
        return
    target_health.heal(definition.power * source_adapter.stat_value(&"healing_power", 1.0))
    var parent := _effect_parent()
    if parent == null:
        return
    var effect := HEAL_EFFECT_SCENE.instantiate() as Node3D
    parent.add_child(effect)
    if effect.is_inside_tree():
        effect.global_position = target.position
    else:
        effect.position = target.position
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
