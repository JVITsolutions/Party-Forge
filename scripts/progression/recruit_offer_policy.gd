class_name RecruitOfferPolicy
extends RefCounted

const DROUGHT_LIMIT := 3

static func count_for_roll(roll: float, drought_streak: int) -> int:
	var safe_roll := clampf(roll if is_finite(roll) else 0.0, 0.0, 0.999999)
	var count := 0
	if safe_roll >= 0.97:
		count = 3
	elif safe_roll >= 0.85:
		count = 2
	elif safe_roll >= 0.45:
		count = 1
	if drought_streak >= DROUGHT_LIMIT:
		count = maxi(count, 1)
	return count
