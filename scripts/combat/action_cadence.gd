class_name ActionCadence
extends RefCounted

## Pure action-cadence projection.
## Authored cooldown and effective_cooldown are seconds. attack_speed and
## cooldown_rate are neutral-at-1.0 rate multipliers. actions_per_second is Hz.

class Result extends RefCounted:
	var error := ""
	var progress_multiplier := 0.0
	var effective_cooldown := 0.0
	var actions_per_second := 0.0

	func ok() -> bool:
		return error.is_empty()


static func resolve(authored_cooldown: float, attack_speed: float, cooldown_rate: float) -> Result:
	var result := Result.new()
	if not is_finite(authored_cooldown) or authored_cooldown <= 0.0:
		return _invalid(result, "Invalid authored cooldown.")
	if not _is_finite_nonnegative(attack_speed):
		return _invalid(result, "Invalid resolved attack speed.")
	if not _is_finite_nonnegative(cooldown_rate):
		return _invalid(result, "Invalid resolved cooldown recovery.")
	result.progress_multiplier = attack_speed * cooldown_rate
	if not _is_finite_nonnegative(result.progress_multiplier):
		return _invalid(result, "Invalid derived action progress multiplier.")
	result.actions_per_second = result.progress_multiplier / authored_cooldown
	if not _is_finite_nonnegative(result.actions_per_second):
		return _invalid(result, "Invalid derived action rate.")
	result.effective_cooldown = authored_cooldown / result.progress_multiplier
	if not is_finite(result.effective_cooldown) or result.effective_cooldown <= 0.0:
		return _invalid(result, "Invalid derived effective cooldown.")
	return result


static func _invalid(result: Result, error: String) -> Result:
	result.error = error
	return result


static func _is_finite_nonnegative(value: float) -> bool:
	return is_finite(value) and value >= 0.0
