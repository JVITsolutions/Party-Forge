class_name LeaderCamera
extends Node3D

@export var target: Node3D
@export_node_path("Node3D") var target_path: NodePath
@export_range(0.1, 30.0, 0.1) var follow_speed: float = 6.0

func _ready() -> void:
    _resolve_target()

func _process(delta: float) -> void:
    if target == null:
        _resolve_target()
    if target == null:
        return
    var weight: float = 1.0 - exp(-follow_speed * maxf(delta, 0.0))
    global_position = global_position.lerp(target.global_position, weight)

func _resolve_target() -> void:
    if target == null and not target_path.is_empty():
        target = get_node_or_null(target_path) as Node3D
