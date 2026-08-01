class_name ForgeVanguardModel
extends Node3D

const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]
const PALETTE_IDS: Array[StringName] = [&"red", &"blue", &"green"]

var body_nodes: Dictionary = {}
var palette_meshes: Dictionary = {}
var equipment_nodes: Dictionary = {}
var base_materials: Dictionary = {}
var _cache_ready := false
var _hit_weight := 0.0
var _is_downed := false

func _ready() -> void:
	_ensure_cache()

func set_body_preset(preset_id: StringName) -> bool:
	_ensure_cache()
	if preset_id not in BODY_PRESETS:
		return false
	for id: StringName in body_nodes:
		for node: Node3D in body_nodes[id]:
			node.visible = id == preset_id
	return true

func set_palette(palette_id: StringName, primary_color: Color) -> bool:
	_ensure_cache()
	if palette_id not in PALETTE_IDS:
		return false
	for mesh: MeshInstance3D in palette_meshes.get(&"primary", []):
		_assign_unique_color(mesh, primary_color)
	_apply_feedback_colors()
	return true

func apply_equipment_visual(slot_id: StringName, definition: EquipmentVisualDefinition) -> bool:
	_ensure_cache()
	if definition == null or not EquipmentSlotCatalog.is_valid(slot_id) or definition.slot_id != slot_id:
		return false
	for node: Node3D in equipment_nodes.get(slot_id, []):
		node.visible = StringName(node.get_meta(&"equipment_visual_id", &"")) == definition.geometry_key
	return equipment_nodes.has(slot_id)

func has_equipment_slot(slot_id: StringName) -> bool:
	_ensure_cache()
	return equipment_nodes.has(slot_id)

func visual_bounds() -> AABB:
	_ensure_cache()
	var bounds := AABB()
	var has_bounds := false
	for mesh: MeshInstance3D in _all_meshes():
		if not mesh.visible or mesh.mesh == null:
			continue
		var transformed := _transform_from_model(mesh) * mesh.get_aabb()
		bounds = transformed if not has_bounds else bounds.merge(transformed)
		has_bounds = true
	return bounds

func play_action(animation_id: StringName) -> bool:
	_ensure_cache()
	var player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null or not player.has_animation(animation_id):
		return false
	player.clear_queue()
	player.play(animation_id)
	if animation_id != &"idle":
		player.queue(&"idle")
	return true

func set_hit_weight(weight: float) -> void:
	_ensure_cache()
	_hit_weight = clampf(weight, 0.0, 1.0)
	_apply_feedback_colors()

func set_downed(is_downed: bool) -> void:
	_ensure_cache()
	_is_downed = is_downed
	_apply_feedback_colors()

func _ensure_cache() -> void:
	if _cache_ready:
		return
	body_nodes.clear()
	palette_meshes.clear()
	equipment_nodes.clear()
	base_materials.clear()
	for node: Node in find_children("*", "", true, false):
		if node is Node3D and node.has_meta(&"body_preset"):
			var preset_id := StringName(node.get_meta(&"body_preset"))
			if not body_nodes.has(preset_id):
				body_nodes[preset_id] = []
			(body_nodes[preset_id] as Array).append(node)
		if node is Node3D and node.has_meta(&"equipment_slot"):
			var slot_id := StringName(node.get_meta(&"equipment_slot"))
			if not equipment_nodes.has(slot_id):
				equipment_nodes[slot_id] = []
			(equipment_nodes[slot_id] as Array).append(node)
		if node is MeshInstance3D:
			var region := StringName(node.get_meta(&"palette_region", &""))
			if not region.is_empty():
				if not palette_meshes.has(region):
					palette_meshes[region] = []
				(palette_meshes[region] as Array).append(node)
				var material := node.material_override as StandardMaterial3D
				if material != null:
					base_materials[node] = material.duplicate() as StandardMaterial3D
	_cache_ready = true

func _all_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes

func _assign_unique_color(mesh: MeshInstance3D, color: Color) -> void:
	var material := mesh.material_override as StandardMaterial3D
	if material == null:
		return
	var unique_material := material.duplicate() as StandardMaterial3D
	unique_material.albedo_color = color
	mesh.material_override = unique_material
	base_materials[mesh] = unique_material.duplicate() as StandardMaterial3D

func _apply_feedback_colors() -> void:
	for mesh: MeshInstance3D in _all_meshes():
		if not base_materials.has(mesh):
			continue
		var base_material := base_materials[mesh] as StandardMaterial3D
		if base_material == null:
			continue
		var base := base_material.albedo_color
		var color := base.lerp(Color.WHITE, _hit_weight * 0.7)
		if _is_downed:
			color = Color(color.get_luminance(), color.get_luminance(), color.get_luminance(), color.a)
		var unique_material := base_material.duplicate() as StandardMaterial3D
		unique_material.albedo_color = color
		if _hit_weight > 0.0:
			unique_material.emission_enabled = true
			unique_material.emission = base.lerp(Color.WHITE, 0.85)
			unique_material.emission_energy_multiplier = maxf(unique_material.emission_energy_multiplier, _hit_weight * 0.8)
		mesh.material_override = unique_material

func _transform_from_model(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != self:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result
