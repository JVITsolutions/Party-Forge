class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal downed
signal revived
signal died

var max_health: float = 1.0
var current_health: float = 1.0
var armor: float = 0.0
var is_leader: bool = false
var is_downed: bool = false
var is_dead: bool = false
var revive_delay: float = 8.0
var revive_health_fraction: float = 0.5
var revive_remaining: float = 0.0

func configure(maximum: float, armor_value: float, leader: bool, revive_seconds: float, revive_fraction: float) -> void:
    max_health = maxf(maximum, 1.0)
    current_health = max_health
    armor = maxf(armor_value, 0.0)
    is_leader = leader
    revive_delay = maxf(revive_seconds, 0.1)
    revive_health_fraction = clampf(revive_fraction, 0.01, 1.0)
    is_downed = false
    is_dead = false

func take_damage(raw_damage: float) -> float:
    if is_dead or is_downed or raw_damage <= 0.0:
        return 0.0
    var applied: float = maxf(1.0, raw_damage - armor)
    current_health = maxf(0.0, current_health - applied)
    health_changed.emit(current_health, max_health)
    if current_health <= 0.0:
        if is_leader:
            is_dead = true
            died.emit()
        else:
            is_downed = true
            revive_remaining = revive_delay
            downed.emit()
    return applied

func heal(amount: float) -> float:
    if is_dead or is_downed or amount <= 0.0:
        return 0.0
    var previous: float = current_health
    current_health = minf(max_health, current_health + amount)
    health_changed.emit(current_health, max_health)
    return current_health - previous

func advance_time(delta: float) -> void:
    if not is_downed or delta <= 0.0:
        return
    revive_remaining = maxf(0.0, revive_remaining - delta)
    if revive_remaining <= 0.0:
        is_downed = false
        current_health = max_health * revive_health_fraction
        health_changed.emit(current_health, max_health)
        revived.emit()
