class_name ResolvedAttackGeometry
extends RefCounted

@warning_ignore("shadowed_global_identifier")
var range: float
var area_radius: float

func _init(effective_range: float, effective_area_radius: float) -> void:
	range = maxf(effective_range, 0.0)
	area_radius = maxf(effective_area_radius, 0.0)

static func from_attack(
	definition: AttackDefinition,
	range_multiplier: float = 1.0,
	area_multiplier: float = 1.0
) -> ResolvedAttackGeometry:
	if definition == null:
		return ResolvedAttackGeometry.new(0.0, 0.0)
	var safe_range_multiplier := range_multiplier if is_finite(range_multiplier) and range_multiplier >= 0.0 else 1.0
	var safe_area_multiplier := area_multiplier if is_finite(area_multiplier) and area_multiplier >= 0.0 else 0.0
	return ResolvedAttackGeometry.new(
		definition.range * safe_range_multiplier,
		definition.area_radius * safe_area_multiplier
	)
