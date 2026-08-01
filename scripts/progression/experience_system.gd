class_name ExperienceSystem
extends Node

signal level_ready(level: int)
const DEFAULT_TUNING: ExperienceTuning = preload("res://data/progression/default_experience.tres")
var level: int = 1
var experience: int = 0
var pending_levels: int = 0
var pending_level_numbers: Array[int] = []
var tuning: ExperienceTuning = DEFAULT_TUNING
var experience_multiplier := 1.0
var fractional_experience := 0.0

func configure_multiplier(percent: int) -> void:
    experience_multiplier = float(clampi(percent, 100, 1000)) / 100.0
    fractional_experience = 0.0

func experience_for_next_level() -> int:
    return tuning.requirement_for_level(level)

func add_experience(amount: int) -> void:
    var scaled := float(maxi(amount, 0)) * experience_multiplier + fractional_experience
    var whole_experience := floori(scaled)
    fractional_experience = scaled - float(whole_experience)
    experience += whole_experience
    while experience >= experience_for_next_level():
        experience -= experience_for_next_level()
        level += 1
        pending_levels += 1
        pending_level_numbers.append(level)
        level_ready.emit(level)

func current_pending_level() -> int:
    return pending_level_numbers[0] if not pending_level_numbers.is_empty() else level

func consume_pending_level() -> bool:
    if pending_levels <= 0: return false
    pending_levels -= 1
    if not pending_level_numbers.is_empty():
        pending_level_numbers.pop_front()
    return true
