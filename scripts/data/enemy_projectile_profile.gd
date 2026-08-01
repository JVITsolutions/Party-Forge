class_name EnemyProjectileProfile
extends Resource

enum Movement { LINEAR, HOMING }

@export var movement := Movement.LINEAR
@export var color := Color.RED
@export var hit_radius := 0.45
@export var max_lifetime := 3.0
@export var tell_duration := 0.35

func validate(enemy_id: StringName) -> PackedStringArray:
	var errors := PackedStringArray()
	if movement not in [Movement.LINEAR, Movement.HOMING]:
		errors.append("PARTY_FORGE_PROJECTILE_ERROR enemy=%s reason=invalid movement" % enemy_id)
	if not is_finite(hit_radius) or hit_radius <= 0.0:
		errors.append("PARTY_FORGE_PROJECTILE_ERROR enemy=%s reason=hit radius must be finite and positive" % enemy_id)
	if not is_finite(max_lifetime) or max_lifetime <= 0.0:
		errors.append("PARTY_FORGE_PROJECTILE_ERROR enemy=%s reason=lifetime must be finite and positive" % enemy_id)
	if not is_finite(tell_duration) or tell_duration < 0.0:
		errors.append("PARTY_FORGE_PROJECTILE_ERROR enemy=%s reason=tell duration must be finite and nonnegative" % enemy_id)
	return errors
