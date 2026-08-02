class_name PresentationEffect
extends Node3D

@export var effect_color := Color.WHITE
@export_range(0.01, 10.0, 0.01) var duration := 0.4

var elapsed := 0.0
var _materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	_cache_instance_materials()
	configure(effect_color)

func configure(color: Color = Color.WHITE, duration_override: float = -1.0) -> void:
	if _materials.is_empty():
		_cache_instance_materials()
	effect_color = color
	if is_finite(duration_override) and duration_override > 0.0:
		duration = clampf(duration_override, 0.01, 10.0)
	elapsed = 0.0
	scale = Vector3.ONE * 0.35
	_apply_color(1.0)

func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	var progress := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	scale = Vector3.ONE * lerpf(0.35, 1.0, progress)
	_apply_color(1.0 - progress)
	if progress >= 1.0:
		queue_free()

func _cache_instance_materials() -> void:
	_materials.clear()
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var source := mesh_instance.material_override as StandardMaterial3D
		if source == null and mesh_instance.mesh != null:
			source = mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_instance.material_override = material
		_materials.append(material)

func _apply_color(alpha_multiplier: float) -> void:
	for material: StandardMaterial3D in _materials:
		var color := effect_color
		color.a *= clampf(alpha_multiplier, 0.0, 1.0)
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = Color(effect_color.r, effect_color.g, effect_color.b, 1.0)
