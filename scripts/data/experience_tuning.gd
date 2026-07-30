class_name ExperienceTuning
extends Resource

const SAFE_BASE := 20.0
const SAFE_LINEAR := 8.0
const SAFE_ACCELERATION := 2.0

@export var base_cost := SAFE_BASE
@export var linear_growth := SAFE_LINEAR
@export var acceleration := SAFE_ACCELERATION

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(base_cost) or base_cost < 0.0:
		errors.append("PARTY_FORGE_XP_ERROR field=base_cost")
	if not is_finite(linear_growth) or linear_growth < 0.0:
		errors.append("PARTY_FORGE_XP_ERROR field=linear_growth")
	if not is_finite(acceleration) or acceleration < 0.0:
		errors.append("PARTY_FORGE_XP_ERROR field=acceleration")
	return errors

func requirement_for_level(current_level: int) -> int:
	var n := float(maxi(current_level, 1) - 1)
	var base := base_cost if is_finite(base_cost) and base_cost >= 0.0 else SAFE_BASE
	var linear := linear_growth if is_finite(linear_growth) and linear_growth >= 0.0 else SAFE_LINEAR
	var curve := acceleration if is_finite(acceleration) and acceleration >= 0.0 else SAFE_ACCELERATION
	return maxi(ceili(base + linear * n + curve * n * n), 1)
