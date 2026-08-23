class_name MultiCritRoll
extends RefCounted

const PROCESSING_CEILING := 10000
const SCRIPT_PATH := "res://scripts/combat/multi_crit_roll.gd"

var _crit_chance := 0.0
var _requested_instances := 1
var _processed_instances := 1
var _guaranteed_instances := 0
var _fractional_chance := 0.0
var _fractional_draw := -1.0
var _fractional_success := false
var _fractional_draw_consumed := false
var _ceiling_truncated := false
var _critical_flags: Array[bool] = [false]
var crit_chance: float:
	get: return _crit_chance
	set(_value): pass
var requested_instances: int:
	get: return _requested_instances
	set(_value): pass
var processed_instances: int:
	get: return _processed_instances
	set(_value): pass
var guaranteed_instances: int:
	get: return _guaranteed_instances
	set(_value): pass
var fractional_chance: float:
	get: return _fractional_chance
	set(_value): pass
var fractional_draw: float:
	get: return _fractional_draw
	set(_value): pass
var fractional_success: bool:
	get: return _fractional_success
	set(_value): pass
var fractional_draw_consumed: bool:
	get: return _fractional_draw_consumed
	set(_value): pass
var ceiling_truncated: bool:
	get: return _ceiling_truncated
	set(_value): pass
var critical_flags: Array[bool]:
	get: return _critical_flags.duplicate()
	set(_value): pass

static func create(chance_value: float, rng: CombatRng) -> RefCounted:
	var result = (load(SCRIPT_PATH) as Script).new()
	var normalized_points := roundi(maxf(0.0, chance_value) * 100.0) if is_finite(chance_value) else 0
	result._crit_chance = float(normalized_points) / 100.0
	result._critical_flags.clear()
	if result._crit_chance < 1.0:
		result._requested_instances = 1
		result._fractional_chance = result._crit_chance
		var fractional := rng.roll(result._fractional_chance)
		result._fractional_draw = float(fractional["draw"])
		result._fractional_success = bool(fractional["success"])
		result._fractional_draw_consumed = bool(fractional["consumed"])
		result._critical_flags.append(result._fractional_success)
	else:
		result._guaranteed_instances = floori(float(normalized_points) / 100.0)
		result._fractional_chance = float(normalized_points % 100) / 100.0
		result._requested_instances = result._guaranteed_instances + (1 if result._fractional_chance > 0.0 else 0)
		var bounded_guaranteed := mini(result._guaranteed_instances, PROCESSING_CEILING)
		result._critical_flags.resize(bounded_guaranteed)
		result._critical_flags.fill(true)
		if result._fractional_chance > 0.0 and result._critical_flags.size() < PROCESSING_CEILING:
			var fractional := rng.roll(result._fractional_chance)
			result._fractional_draw = float(fractional["draw"])
			result._fractional_success = bool(fractional["success"])
			result._fractional_draw_consumed = bool(fractional["consumed"])
			if result._fractional_success:
				result._critical_flags.append(true)
	result._processed_instances = result._critical_flags.size()
	result._ceiling_truncated = result._requested_instances > PROCESSING_CEILING
	return result

static func from_compatibility(critical_value: bool, draw: float) -> RefCounted:
	var result = (load(SCRIPT_PATH) as Script).new()
	result._crit_chance = 1.0 if critical_value else 0.0
	result._requested_instances = 1
	result._processed_instances = 1
	result._guaranteed_instances = 1 if critical_value and draw < 0.0 else 0
	result._fractional_draw = draw
	result._fractional_success = critical_value if draw >= 0.0 else false
	result._fractional_draw_consumed = draw >= 0.0
	result._critical_flags.assign([critical_value])
	return result

func primary_critical() -> bool:
	return not _critical_flags.is_empty() and _critical_flags[0]

func copy() -> RefCounted:
	var result = (load(SCRIPT_PATH) as Script).new()
	result._crit_chance = _crit_chance
	result._requested_instances = _requested_instances
	result._processed_instances = _processed_instances
	result._guaranteed_instances = _guaranteed_instances
	result._fractional_chance = _fractional_chance
	result._fractional_draw = _fractional_draw
	result._fractional_success = _fractional_success
	result._fractional_draw_consumed = _fractional_draw_consumed
	result._ceiling_truncated = _ceiling_truncated
	result._critical_flags.assign(_critical_flags)
	return result
