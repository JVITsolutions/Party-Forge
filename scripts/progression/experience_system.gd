class_name ExperienceSystem
extends Node

signal level_ready(level: int)
var level: int = 1
var experience: int = 0
var pending_levels: int = 0

func experience_for_next_level() -> int:
    return 20 + (level - 1) * 10

func add_experience(amount: int) -> void:
    experience += maxi(amount, 0)
    while experience >= experience_for_next_level():
        experience -= experience_for_next_level()
        level += 1
        pending_levels += 1
        level_ready.emit(level)

func consume_pending_level() -> bool:
    if pending_levels <= 0: return false
    pending_levels -= 1
    return true
