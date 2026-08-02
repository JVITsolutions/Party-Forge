class_name ForgeHumanoidModel
extends Node3D

signal action_event(action_id: StringName, event_name: StringName)
signal action_finished(action_id: StringName)

const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]

var body_nodes: Dictionary = {}
var palette_meshes: Dictionary = {}
var equipped_nodes: Dictionary = {}
var equipped_definitions: Dictionary = {}
var base_materials: Dictionary = {}
var active_action_id: StringName
var _primary_color := Color.WHITE
var _hit_weight := 0.0
var _is_downed := false
var _cache_ready := false

func _ready() -> void:
	_ensure_cache()
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and not player.animation_finished.is_connected(_on_animation_finished):
		player.animation_finished.connect(_on_animation_finished)

func set_body_preset(preset_id: StringName) -> bool:
	_ensure_cache()
	if preset_id not in BODY_PRESETS:
		return false
	for body_id: StringName in body_nodes:
		for node: Node3D in body_nodes[body_id]:
			node.visible = body_id == preset_id
	return true

func set_palette(palette_id: StringName, primary_color: Color) -> bool:
	_ensure_cache()
	if palette_id.is_empty():
		return false
	_primary_color = primary_color
	for mesh: MeshInstance3D in palette_meshes.get(&"primary", []):
		_assign_unique_color(mesh, primary_color)
	_refresh_equipped_wearer_accents()
	_apply_feedback_colors()
	return true

func apply_equipment_visual(slot_id: StringName, definition: EquipmentVisualDefinition) -> bool:
	_ensure_cache()
	if definition == null or slot_id not in definition.supported_slot_ids or not EquipmentSlotCatalog.is_valid(slot_id):
		return false
	if not definition.combat_visible:
		_clear_equipped_node(slot_id)
		equipped_definitions[slot_id] = definition
		return true
	if definition.presentation_scene == null:
		return false
	var candidate_root := definition.presentation_scene.instantiate() as Node3D
	if candidate_root == null:
		return false
	var staged: Array[Dictionary] = []
	var attachment_nodes: Array[Node3D] = []
	for node: Node in candidate_root.find_children("*", "Node3D", true, false):
		if node.has_meta(&"equipment_socket_id"):
			attachment_nodes.append(node as Node3D)
	if attachment_nodes.is_empty():
		attachment_nodes.append(candidate_root)
	for attachment: Node3D in attachment_nodes:
		var socket_id := StringName(attachment.get_meta(&"equipment_socket_id", definition.socket_id))
		var socket := get_node_or_null(NodePath(String(socket_id))) as Node3D
		if socket == null:
			candidate_root.free()
			return false
		staged.append({&"node": attachment, &"socket": socket})
	_apply_item_colors(candidate_root, definition)
	_clear_equipped_node(slot_id)
	var installed: Array[Node3D] = []
	for part: Dictionary in staged:
		var attachment := part[&"node"] as Node3D
		var socket := part[&"socket"] as Node3D
		attachment.owner = null
		if attachment != candidate_root:
			attachment.reparent(socket, false)
		else:
			socket.add_child(attachment)
		installed.append(attachment)
	if candidate_root not in installed:
		candidate_root.free()
	equipped_nodes[slot_id] = installed
	equipped_definitions[slot_id] = definition
	_apply_feedback_colors()
	return true

func clear_equipment_visual(slot_id: StringName) -> bool:
	if not EquipmentSlotCatalog.is_valid(slot_id):
		return false
	_clear_equipped_node(slot_id)
	equipped_definitions.erase(slot_id)
	return true

func equipped_item_id(slot_id: StringName) -> StringName:
	var definition := equipped_definitions.get(slot_id) as EquipmentVisualDefinition
	return definition.id if definition != null else &""

func equipped_weapon_family() -> StringName:
	var main := equipped_definitions.get(&"main_hand") as EquipmentVisualDefinition
	return main.weapon_animation_family_id if main != null and not main.weapon_animation_family_id.is_empty() else &"unarmed"

func socket_global_transform(socket_id: StringName) -> Transform3D:
	var socket := get_node_or_null(NodePath(String(socket_id))) as Node3D
	return socket.global_transform if socket != null else global_transform

func has_equipment_slot(slot_id: StringName) -> bool:
	return EquipmentSlotCatalog.is_valid(slot_id)

func visual_bounds() -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for mesh: MeshInstance3D in _all_meshes():
		if not _is_effectively_visible(mesh) or mesh.mesh == null:
			continue
		var transformed := _transform_from_model(mesh) * mesh.get_aabb()
		bounds = transformed if not has_bounds else bounds.merge(transformed)
		has_bounds = true
	return bounds

func play_action(animation_id: StringName) -> bool:
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(animation_id):
		return false
	active_action_id = animation_id
	player.clear_queue()
	player.play(animation_id)
	if animation_id != &"idle" and player.has_animation(&"idle"):
		player.queue(&"idle")
	return true

func emit_action_event(event_name: StringName) -> void:
	action_event.emit(active_action_id, event_name)

func set_hit_weight(weight: float) -> void:
	_hit_weight = clampf(weight, 0.0, 1.0)
	_apply_feedback_colors()

func set_downed(is_downed: bool) -> void:
	_is_downed = is_downed
	_apply_feedback_colors()

func _clear_equipped_node(slot_id: StringName) -> void:
	var old_nodes: Array = equipped_nodes.get(slot_id, [])
	var erased_meshes: Dictionary = {}
	for old: Variant in old_nodes:
		if not (old is Node3D and is_instance_valid(old)):
			continue
		for mesh: MeshInstance3D in _meshes_including_root(old as Node3D):
			if erased_meshes.has(mesh):
				continue
			erased_meshes[mesh] = true
			base_materials.erase(mesh)
		(old as Node3D).free()
	equipped_nodes.erase(slot_id)

func _ensure_cache() -> void:
	if _cache_ready:
		return
	body_nodes.clear()
	palette_meshes.clear()
	base_materials.clear()
	for node: Node in find_children("*", "", true, false):
		if node is Node3D and node.has_meta(&"body_preset"):
			var preset_id := StringName(node.get_meta(&"body_preset"))
			if not body_nodes.has(preset_id):
				body_nodes[preset_id] = []
			(body_nodes[preset_id] as Array).append(node)
		if node is MeshInstance3D:
			var region := StringName(node.get_meta(&"palette_region", &""))
			if region.is_empty():
				continue
			if not palette_meshes.has(region):
				palette_meshes[region] = []
			(palette_meshes[region] as Array).append(node)
			var material := (node as MeshInstance3D).material_override as StandardMaterial3D
			if material != null:
				base_materials[node] = material.duplicate() as StandardMaterial3D
	_cache_ready = true

func _apply_item_colors(root: Node3D, definition: EquipmentVisualDefinition) -> void:
	for mesh: MeshInstance3D in _meshes_including_root(root):
		var region := StringName(mesh.get_meta(&"palette_region", &""))
		var material := mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		var color: Variant = null
		if not definition.wearer_accent_channel.is_empty() and region == definition.wearer_accent_channel:
			color = _primary_color
		elif definition.item_colors.has(region):
			color = definition.item_colors[region]
		var unique_material := material.duplicate() as StandardMaterial3D
		if typeof(color) == TYPE_COLOR:
			unique_material.albedo_color = color as Color
		mesh.material_override = unique_material
		base_materials[mesh] = unique_material.duplicate() as StandardMaterial3D

func _refresh_equipped_wearer_accents() -> void:
	for slot_id: StringName in equipped_definitions:
		var definition := equipped_definitions[slot_id] as EquipmentVisualDefinition
		if definition == null or definition.wearer_accent_channel.is_empty():
			continue
		for attachment: Node3D in equipped_nodes.get(slot_id, []):
			for mesh: MeshInstance3D in _meshes_including_root(attachment):
				if StringName(mesh.get_meta(&"palette_region", &"")) != definition.wearer_accent_channel:
					continue
				var material := base_materials.get(mesh, mesh.material_override) as StandardMaterial3D
				if material == null:
					continue
				var unique_material := material.duplicate() as StandardMaterial3D
				unique_material.albedo_color = _primary_color
				mesh.material_override = unique_material
				base_materials[mesh] = unique_material.duplicate() as StandardMaterial3D

func _meshes_including_root(root: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root as MeshInstance3D)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes

func _all_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes

func _assign_unique_color(mesh: MeshInstance3D, color: Color) -> void:
	var material := base_materials.get(mesh, mesh.material_override) as StandardMaterial3D
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

func _is_effectively_visible(node: Node3D) -> bool:
	var cursor: Node = node
	while cursor != null:
		if cursor is Node3D and not (cursor as Node3D).visible:
			return false
		if cursor == self:
			return true
		cursor = cursor.get_parent()
	return true

func _transform_from_model(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != self:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result

func _on_animation_finished(animation_id: StringName) -> void:
	if animation_id == active_action_id:
		action_finished.emit(animation_id)
