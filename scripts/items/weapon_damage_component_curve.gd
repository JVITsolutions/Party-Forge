class_name WeaponDamageComponentCurve
extends Resource

@export var damage_type_id: StringName
@export var minimum_at_level_1 := 0.0
@export var maximum_at_level_1 := 0.0
@export var minimum_at_level_1000 := 0.0
@export var maximum_at_level_1000 := 0.0

func range_at(item_level: int) -> Vector2:
	var progress := clampf(float(item_level - 1) / 999.0, 0.0, 1.0)
	return Vector2(
		lerpf(minimum_at_level_1, minimum_at_level_1000, progress),
		lerpf(maximum_at_level_1, maximum_at_level_1000, progress),
	)
