class_name AttackController
extends Node

signal attack_ready(definition: AttackDefinition, target: CombatTarget)
var definition: AttackDefinition
var team_id: int
var cooldown_remaining: float = 0.0

func configure(attack: AttackDefinition, own_team: int) -> void:
    definition = attack; team_id = own_team; cooldown_remaining = 0.0

func advance(delta: float) -> void:
    cooldown_remaining = maxf(0.0, cooldown_remaining - maxf(delta, 0.0))

func try_attack(origin: Vector3, candidates: Array[CombatTarget]) -> CombatTarget:
    if definition == null or cooldown_remaining > 0.0: return null
    var target := TargetSelector.nearest(origin, candidates, definition.range, team_id)
    if target == null: return null
    cooldown_remaining = definition.cooldown
    attack_ready.emit(definition, target)
    return target
