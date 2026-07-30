class_name ExperienceSystem
extends Node

signal level_ready(level: int)
const DEFAULT_TUNING: ExperienceTuning = preload("res://data/progression/default_experience.tres")
var level: int = 1
var experience: int = 0
var pending_levels: int = 0
var pending_level_numbers: Array[int] = []
var tuning: ExperienceTuning = DEFAULT_TUNING

func experience_for_next_level() -> int:
    return tuning.requirement_for_level(level)

func add_experience(amount: int) -> void:
    experience += maxi(amount, 0)
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
