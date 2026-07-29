class_name TimedEffect
extends Node3D

@export_range(0.01, 10.0, 0.01) var lifetime := 0.4
var elapsed := 0.0

func configure(duration: float) -> void:
    lifetime = clampf(duration, 0.01, 10.0)
    elapsed = 0.0

func _process(delta: float) -> void:
    elapsed += maxf(delta, 0.0)
    if elapsed >= lifetime:
        queue_free()
