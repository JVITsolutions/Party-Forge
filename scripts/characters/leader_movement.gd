class_name LeaderMovement
extends RefCounted

static func velocity(input_vector: Vector2, speed: float) -> Vector3:
    var limited := input_vector.limit_length(1.0)
    return Vector3(limited.x, 0.0, limited.y) * speed
