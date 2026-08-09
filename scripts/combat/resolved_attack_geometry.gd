class_name ResolvedAttackGeometry
extends RefCounted

@warning_ignore("shadowed_global_identifier")
var range: float
var area_radius: float
var projectile_speed: float
var error := ""

func _init(effective_range: float, effective_area_radius: float, effective_projectile_speed: float = 0.0, failure: String = "") -> void:
	range = maxf(effective_range, 0.0)
	area_radius = maxf(effective_area_radius, 0.0)
	projectile_speed = maxf(effective_projectile_speed, 0.0)
	error = failure


func ok() -> bool:
	return error.is_empty()

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
		definition.area_radius * safe_area_multiplier,
		definition.projectile_speed,
	)


## Strict player-action projection. Unlike the compatibility multiplier helper,
## this path never substitutes neutral values for a missing/invalid snapshot.
static func from_snapshot(definition: AttackDefinition, action_stats: ResolvedStatSnapshot) -> ResolvedAttackGeometry:
	if definition == null:
		return _failure("Invalid action geometry: missing attack definition.")
	if action_stats == null:
		return _failure("Invalid action geometry: missing resolved character stats.")
	var range_multiplier := action_stats.value(&"attack_range", 1.0)
	if not is_finite(range_multiplier) or range_multiplier < 0.0:
		return _failure("Invalid resolved attack range multiplier.")
	var effective_range := definition.range * range_multiplier
	if not is_finite(effective_range) or effective_range <= 0.0:
		return _failure("Invalid derived attack range.")
	var effective_area := 0.0
	if definition.area_radius > 0.0:
		var area_multiplier := action_stats.value(&"area_size", 1.0)
		if not is_finite(area_multiplier) or area_multiplier < 0.0:
			return _failure("Invalid resolved area size multiplier.")
		effective_area = definition.area_radius * area_multiplier
		if not is_finite(effective_area) or effective_area < 0.0:
			return _failure("Invalid derived area radius.")
	var effective_projectile_speed := 0.0
	if definition.kind in [AttackDefinition.Kind.PROJECTILE, AttackDefinition.Kind.AREA_PROJECTILE]:
		var projectile_multiplier := action_stats.value(&"projectile_speed", 1.0)
		if not is_finite(projectile_multiplier) or projectile_multiplier < 0.0:
			return _failure("Invalid resolved projectile speed multiplier.")
		effective_projectile_speed = definition.projectile_speed * projectile_multiplier
		if not is_finite(effective_projectile_speed) or effective_projectile_speed <= 0.0:
			return _failure("Invalid derived projectile speed.")
	return ResolvedAttackGeometry.new(effective_range, effective_area, effective_projectile_speed)


static func _failure(message: String) -> ResolvedAttackGeometry:
	return ResolvedAttackGeometry.new(0.0, 0.0, 0.0, message)
