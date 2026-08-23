class_name MultiCritRoll
extends RefCounted

const PROCESSING_CEILING := 10000
const SCRIPT_PATH := "res://scripts/combat/multi_crit_roll.gd"
const SIGNED_64_MAX := 9223372036854775807
const SIGNED_64_LIMIT_FLOAT := 9223372036854775808.0
# Keep percentage-point normalization below binary64's exact-integer product limit.
# Above this point, multiplying by 100 can invent a remainder or overflow int64.
const SAFE_PERCENT_POINT_CHANCE := 90071992547409.0

var _valid := true
var _error_reason := ""
var _crit_chance := 0.0
var _requested_instances := 1
var _processed_instances := 1
var _guaranteed_instances := 0
var _fractional_chance := 0.0
var _fractional_draw := -1.0
var _fractional_success := false
var _fractional_draw_consumed := false
var _ceiling_truncated := false
var _requested_count_overflow := false
var _critical_flags: Array[bool] = [false]
var valid: bool:
	get: return _valid
	set(_value): pass
var error_reason: String:
	get: return _error_reason
	set(_value): pass
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
var requested_count_overflow: bool:
	get: return _requested_count_overflow
	set(_value): pass
var critical_flags: Array[bool]:
	get: return _critical_flags.duplicate()
	set(_value): pass

static func create(chance_value: float, rng: CombatRng) -> RefCounted:
	var result = (load(SCRIPT_PATH) as Script).new()
	result._critical_flags.clear()
	if not is_finite(chance_value):
		result._valid = false
		result._error_reason = "PARTY_FORGE_DAMAGE_ERROR chance=%s reason=critical chance must be finite" % chance_value
		result._requested_instances = 0
		result._processed_instances = 0
		return result
	var nonnegative_chance := maxf(0.0, chance_value)
	var uses_percentage_points := nonnegative_chance <= SAFE_PERCENT_POINT_CHANCE
	result._crit_chance = expected_critical_instances(nonnegative_chance)
	var normalized_points := roundi(result._crit_chance * 100.0) if uses_percentage_points else 0
	if result._crit_chance < 1.0:
		result._requested_instances = 1
		result._fractional_chance = result._crit_chance
		var fractional := rng.roll(result._fractional_chance)
		result._fractional_draw = float(fractional["draw"])
		result._fractional_success = bool(fractional["success"])
		result._fractional_draw_consumed = bool(fractional["consumed"])
		result._critical_flags.append(result._fractional_success)
	else:
		var guaranteed_float: float = floorf(float(result._crit_chance))
		result._fractional_chance = float(normalized_points % 100) / 100.0 if uses_percentage_points else result._crit_chance - guaranteed_float
		var fractional_slot: int = 1 if result._fractional_chance > 0.0 else 0
		if guaranteed_float >= SIGNED_64_LIMIT_FLOAT:
			result._guaranteed_instances = SIGNED_64_MAX
			result._requested_instances = SIGNED_64_MAX
			result._requested_count_overflow = true
		else:
			result._guaranteed_instances = int(guaranteed_float)
			if result._guaranteed_instances > SIGNED_64_MAX - fractional_slot:
				result._requested_instances = SIGNED_64_MAX
				result._requested_count_overflow = true
			else:
				result._requested_instances = result._guaranteed_instances + fractional_slot
		var bounded_guaranteed: int = PROCESSING_CEILING if guaranteed_float >= PROCESSING_CEILING else int(guaranteed_float)
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
	result._ceiling_truncated = result._requested_count_overflow or result._requested_instances > PROCESSING_CEILING
	return result

static func expected_critical_instances(chance_value: float) -> float:
	if not is_finite(chance_value):
		return 0.0
	var nonnegative_chance := maxf(0.0, chance_value)
	if nonnegative_chance <= SAFE_PERCENT_POINT_CHANCE:
		return float(roundi(nonnegative_chance * 100.0)) / 100.0
	return nonnegative_chance

static func expected_damage_instances(chance_value: float) -> float:
	return minf(float(PROCESSING_CEILING), maxf(1.0, expected_critical_instances(chance_value)))

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
	result._valid = _valid
	result._error_reason = _error_reason
	result._crit_chance = _crit_chance
	result._requested_instances = _requested_instances
	result._processed_instances = _processed_instances
	result._guaranteed_instances = _guaranteed_instances
	result._fractional_chance = _fractional_chance
	result._fractional_draw = _fractional_draw
	result._fractional_success = _fractional_success
	result._fractional_draw_consumed = _fractional_draw_consumed
	result._ceiling_truncated = _ceiling_truncated
	result._requested_count_overflow = _requested_count_overflow
	result._critical_flags.assign(_critical_flags)
	return result
