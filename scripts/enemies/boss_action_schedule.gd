class_name BossActionSchedule
extends RefCounted

enum Action { CHARGE, SHOCKWAVE, SUMMON }

const ACTIONS: Array[Action] = [Action.CHARGE, Action.SHOCKWAVE, Action.SUMMON]
const RECOVERY: Array[float] = [2.0, 2.5, 3.0]

var index := 0
var remaining := 0.0

func advance(delta: float) -> void:
    remaining = maxf(0.0, remaining - maxf(delta, 0.0))
    if is_zero_approx(remaining):
        remaining = 0.0

func take_next() -> int:
    if remaining > 0.0:
        return -1
    var action: Action = ACTIONS[index]
    remaining = RECOVERY[index]
    index = (index + 1) % ACTIONS.size()
    return action
