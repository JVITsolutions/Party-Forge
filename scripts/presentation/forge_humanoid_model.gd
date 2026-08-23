class_name ForgeHumanoidModel
extends Node3D

signal action_event(action_id: StringName, event_name: StringName)
signal action_finished(action_id: StringName)

const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]
const HumanoidRigContractScript := preload("res://scripts/presentation/humanoid_rig_contract.gd")
const CANONICAL_RIG := preload("res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres")
const SLOT_SOCKET_PATHS := {
	&"helmet": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/HeadPivot/HelmetSocket",
	&"body_armour": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/BodyArmourSocket",
	&"legs": "HitPivot/BodyPivot/HipsPivot/LegsSocket",
	&"gloves": "HitPivot/BodyPivot/HipsPivot/GlovesSocket",
	&"boots": "HitPivot/BodyPivot/HipsPivot/BootsSocket",
	&"amulet": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/AmuletSocket",
	&"ring_left": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket",
	&"ring_right": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket",
	&"belt": "HitPivot/BodyPivot/HipsPivot/BeltSocket",
	&"main_hand": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket",
	&"off_hand": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket",
}
const SEMANTIC_SOCKET_ROOT_NAME: StringName = &"SemanticSockets"
const SEMANTIC_SOCKET_BONES := {
	&"helmet": &"Head",
	&"body_armour": &"Chest",
	&"legs": &"Hips",
	&"gloves": &"Hand.R",
	&"boots": &"Foot.R",
	&"amulet": &"Neck",
	&"ring_left": &"Hand.L",
	&"ring_right": &"Hand.R",
	&"belt": &"Hips",
	&"main_hand": &"Hand.R",
	&"off_hand": &"Hand.L",
}
const LEGACY_SOCKET_SLOT_BY_NAME := {
	&"HelmetSocket": &"helmet",
	&"BodyArmourSocket": &"body_armour",
	&"LegsSocket": &"legs",
	&"GlovesSocket": &"gloves",
	&"BootsSocket": &"boots",
	&"AmuletSocket": &"amulet",
	&"BeltSocket": &"belt",
	&"RightHandSocket": &"main_hand",
	&"LeftHandSocket": &"off_hand",
}
const GENERATED_SEMANTIC_ROOT_META: StringName = &"forge_generated_legacy_semantic_root"
const FALLBACK_SOCKET_PATH_META: StringName = &"fallback_socket_path"

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
var _active_body_preset: StringName

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
	_active_body_preset = preset_id
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
	var presentation_scene := definition.presentation_scene_for(_active_body_preset)
	var selected_root_paths := definition.mesh_root_paths_for(_active_body_preset)
	if presentation_scene == null or selected_root_paths.is_empty():
		return false
	var candidate_root := presentation_scene.instantiate() as Node3D
	if candidate_root == null:
		return false
	var staged: Array[Dictionary] = []
	var attachment_nodes: Array[Node3D] = []
	for root_path: NodePath in selected_root_paths:
		var selected_root := candidate_root.get_node_or_null(root_path) as Node3D
		if selected_root == null:
			candidate_root.free()
			return false
		var selected_attachments: Array[Node3D] = []
		if selected_root.has_meta(&"equipment_socket_id"):
			selected_attachments.append(selected_root)
		for node: Node in selected_root.find_children("*", "Node3D", true, false):
			if node.has_meta(&"equipment_socket_id"):
				selected_attachments.append(node as Node3D)
		if selected_attachments.is_empty():
			selected_attachments.append(selected_root)
		for attachment: Node3D in selected_attachments:
			if attachment not in attachment_nodes:
				attachment_nodes.append(attachment)
	for attachment: Node3D in attachment_nodes:
		var socket_id := StringName(attachment.get_meta(&"equipment_socket_id", definition.socket_id))
		var socket := _resolve_socket(socket_id, slot_id, false, attachment.has_meta(&"equipment_socket_id"))
		if socket == null:
			candidate_root.free()
			return false
		staged.append({&"node": attachment, &"socket": socket})
	for attachment: Node3D in attachment_nodes:
		_apply_item_colors(attachment, definition)
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
	var socket := _resolve_socket(socket_id)
	if socket != null and socket.is_inside_tree():
		return socket.global_transform
	if socket != null:
		return _transform_without_tree(socket)
	return global_transform if is_inside_tree() else _transform_without_tree(self)

func has_equipment_slot(slot_id: StringName) -> bool:
	return EquipmentSlotCatalog.is_valid(slot_id) and _resolve_socket(slot_id, slot_id, false) != null

func equipped_anchor_names(slot_id: StringName) -> Array[StringName]:
	var names: Array[StringName] = []
	for attachment: Node3D in equipped_nodes.get(slot_id, []):
		for node: Node in attachment.find_children("*", "Node3D", true, false):
			var node_name := StringName(node.name)
			if node_name in [&"ReadabilityAnchor", &"ActionOriginSocket", &"ProjectileLaunchSocket"] and node_name not in names:
				names.append(node_name)
	return names

func equipment_anchor_global_transform(slot_id: StringName, anchor_name: StringName) -> Transform3D:
	var anchor := _resolve_socket(anchor_name, slot_id)
	if anchor == null:
		return global_transform if is_inside_tree() else _transform_without_tree(self)
	return anchor.global_transform if anchor.is_inside_tree() else _transform_without_tree(anchor)

func equipment_anchor_clearance(slot_id: StringName, anchor_name: StringName) -> float:
	var anchor := _resolve_socket(anchor_name, slot_id)
	var arm_bounds := _body_arm_bounds()
	if anchor == null or arm_bounds.is_empty():
		return -1.0
	var clearance := INF
	var anchor_position := _transform_from_model(anchor).origin
	for bounds: AABB in arm_bounds:
		clearance = minf(clearance, _distance_to_aabb(anchor_position, bounds))
	return clearance

func equipment_visible_extent(slot_id: StringName) -> float:
	var bounds := _equipment_bounds(slot_id)
	if bounds.size == Vector3.ZERO:
		return -1.0
	return maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))

func equipment_arm_intersection_volume(slot_id: StringName) -> float:
	var arm_bounds := _body_arm_bounds()
	if arm_bounds.is_empty():
		return -1.0
	var total_volume := 0.0
	for attachment: Node3D in equipped_nodes.get(slot_id, []):
		for mesh: MeshInstance3D in _meshes_including_root(attachment):
			if not _is_effectively_visible(mesh) or mesh.mesh == null:
				continue
			var equipment_bounds := _transform_from_model(mesh) * mesh.get_aabb()
			for body_bounds: AABB in arm_bounds:
				var overlap := equipment_bounds.intersection(body_bounds)
				if overlap.size.x <= 0.0 or overlap.size.y <= 0.0 or overlap.size.z <= 0.0:
					continue
				total_volume += overlap.size.x * overlap.size.y * overlap.size.z
	return total_volume

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

func refresh_grounding() -> bool:
	position.y = 0.0
	var bounds := visual_bounds()
	if bounds.size == Vector3.ZERO or not bounds.position.is_finite() or not bounds.size.is_finite():
		return false
	position.y = -bounds.position.y
	return absf(ground_gap()) <= 0.001

func ground_gap() -> float:
	var bounds := visual_bounds()
	if bounds.size == Vector3.ZERO or not bounds.position.is_finite():
		return INF
	return position.y + bounds.position.y

func play_action(animation_id: StringName, playback_rate: float = 1.0) -> bool:
	if _is_downed or not is_finite(playback_rate) or playback_rate <= 0.0:
		return false
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(animation_id):
		return false
	active_action_id = animation_id
	player.clear_queue()
	player.speed_scale = playback_rate
	player.play(animation_id)
	return true

func play_feedback(animation_id: StringName) -> bool:
	if _is_downed:
		return false
	var player := find_child("FeedbackAnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(animation_id):
		return false
	player.stop(true)
	player.play(animation_id)
	return true

func emit_action_event(event_name: StringName) -> void:
	action_event.emit(active_action_id, event_name)

func set_hit_weight(weight: float) -> void:
	_hit_weight = clampf(weight, 0.0, 1.0)
	_apply_feedback_colors()

func set_downed(is_downed: bool) -> void:
	_is_downed = is_downed
	if is_downed:
		var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null:
			player.stop(true)
			player.clear_queue()
		active_action_id = &""
		var feedback_player := find_child("FeedbackAnimationPlayer", true, false) as AnimationPlayer
		if feedback_player != null:
			feedback_player.stop(true)
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
	_ensure_semantic_socket_root()
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
	_active_body_preset = &""
	for body_preset: StringName in BODY_PRESETS:
		for body_node: Node3D in body_nodes.get(body_preset, []):
			if body_node.visible:
				_active_body_preset = body_preset
				break
		if not _active_body_preset.is_empty():
			break
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

func _equipped_node_named(slot_id: StringName, node_name: StringName) -> Node3D:
	for attachment: Node3D in equipped_nodes.get(slot_id, []):
		if StringName(attachment.name) == node_name:
			return attachment
		var found := attachment.find_child(String(node_name), true, false) as Node3D
		if found != null:
			return found
	return null

func _resolve_socket(socket_id: StringName, slot_id: StringName = &"", include_equipped_anchors: bool = true, allow_owned_hand_pair: bool = false) -> Node3D:
	if include_equipped_anchors and not String(socket_id).contains("/"):
		var equipped_slots: Array[StringName] = []
		if not slot_id.is_empty():
			equipped_slots.append(slot_id)
		else:
			equipped_slots.assign([&"main_hand", &"off_hand"])
		for equipped_slot: StringName in equipped_slots:
			var equipped_socket := _equipped_node_named(equipped_slot, socket_id)
			if equipped_socket != null:
				return equipped_socket
	var semantic_slot := &"" if allow_owned_hand_pair and _is_owned_legacy_hand_pair_socket(socket_id) else _semantic_slot_for(socket_id, slot_id)
	if not semantic_slot.is_empty():
		var semantic_root := _ensure_semantic_socket_root()
		if semantic_root == null:
			return null
		var semantic_socket := semantic_root.get_node_or_null(NodePath(String(semantic_slot))) as Node3D
		if semantic_socket is BoneAttachment3D:
			return semantic_socket if _is_valid_rig_socket(semantic_slot, semantic_socket as BoneAttachment3D) else null
		if semantic_socket == null or not semantic_root.has_meta(GENERATED_SEMANTIC_ROOT_META):
			return null
		var fallback_path := String(semantic_socket.get_meta(FALLBACK_SOCKET_PATH_META, ""))
		if fallback_path != String(SLOT_SOCKET_PATHS.get(semantic_slot, "")):
			return null
		var semantic_fallback := get_node_or_null(NodePath(fallback_path)) as Node3D
		return semantic_fallback
	var exact_fallback := get_node_or_null(NodePath(String(socket_id))) as Node3D
	if exact_fallback != null:
		return exact_fallback
	return null

func _semantic_slot_for(socket_id: StringName, slot_id: StringName) -> StringName:
	var socket_text := String(socket_id)
	var leaf_name := StringName(socket_text.get_file())
	if SLOT_SOCKET_PATHS.has(slot_id):
		var slot_path := String(SLOT_SOCKET_PATHS[slot_id])
		if socket_id == slot_id or socket_text == slot_path or leaf_name == StringName(slot_path.get_file()):
			return slot_id
	if SLOT_SOCKET_PATHS.has(socket_id):
		return socket_id
	return LEGACY_SOCKET_SLOT_BY_NAME.get(leaf_name, &"")

func _is_owned_legacy_hand_pair_socket(socket_id: StringName) -> bool:
	if String(socket_id).contains("/") or socket_id not in [&"LeftHandSocket", &"RightHandSocket"]:
		return false
	var left_socket := get_node_or_null(NodePath("LeftHandSocket")) as Node3D
	var right_socket := get_node_or_null(NodePath("RightHandSocket")) as Node3D
	return left_socket != null and right_socket != null and left_socket.get_parent() == self and right_socket.get_parent() == self

func _ensure_semantic_socket_root() -> Node3D:
	var existing := get_node_or_null(NodePath(String(SEMANTIC_SOCKET_ROOT_NAME)))
	if existing != null:
		return existing as Node3D
	var semantic_root := Node3D.new()
	semantic_root.name = SEMANTIC_SOCKET_ROOT_NAME
	semantic_root.set_meta(GENERATED_SEMANTIC_ROOT_META, true)
	add_child(semantic_root)
	for slot_id: StringName in SLOT_SOCKET_PATHS:
		var descriptor := Node3D.new()
		descriptor.name = slot_id
		descriptor.set_meta(FALLBACK_SOCKET_PATH_META, SLOT_SOCKET_PATHS[slot_id])
		semantic_root.add_child(descriptor)
	return semantic_root

func _is_valid_rig_socket(slot_id: StringName, attachment: BoneAttachment3D) -> bool:
	var expected_bone: StringName = SEMANTIC_SOCKET_BONES.get(slot_id, &"")
	if expected_bone.is_empty() or attachment.bone_name != expected_bone:
		return false
	var skeleton: Skeleton3D
	if attachment.use_external_skeleton:
		skeleton = attachment.get_node_or_null(attachment.external_skeleton) as Skeleton3D
	else:
		var cursor := attachment.get_parent()
		while cursor != null and cursor != self:
			if cursor is Skeleton3D:
				skeleton = cursor as Skeleton3D
				break
			cursor = cursor.get_parent()
	if skeleton == null:
		return false
	if not is_ancestor_of(skeleton):
		return false
	var contract := HumanoidRigContractScript.new() as RefCounted
	return (contract.call(&"validate_rig", CANONICAL_RIG, skeleton, self) as PackedStringArray).is_empty()

func _equipment_bounds(slot_id: StringName) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for attachment: Node3D in equipped_nodes.get(slot_id, []):
		for mesh: MeshInstance3D in _meshes_including_root(attachment):
			if not _is_effectively_visible(mesh) or mesh.mesh == null:
				continue
			var transformed := _transform_from_model(mesh) * mesh.get_aabb()
			bounds = transformed if not has_bounds else bounds.merge(transformed)
			has_bounds = true
	return bounds

func _body_arm_bounds() -> Array[AABB]:
	var bounds: Array[AABB] = []
	for mesh: MeshInstance3D in _all_meshes():
		if not _is_effectively_visible(mesh) or mesh.mesh == null or not _is_body_arm_mesh(mesh):
			continue
		bounds.append(_transform_from_model(mesh) * mesh.get_aabb())
	return bounds

func _is_body_arm_mesh(mesh: MeshInstance3D) -> bool:
	var path := String(get_path_to(mesh))
	if "ShoulderPivot" not in path and "ElbowPivot" not in path:
		return false
	var cursor: Node = mesh
	while cursor != null and cursor != self:
		if cursor is Node3D and cursor.has_meta(&"body_preset"):
			return true
		cursor = cursor.get_parent()
	return false

func _distance_to_aabb(point: Vector3, bounds: AABB) -> float:
	var closest := Vector3(
		clampf(point.x, bounds.position.x, bounds.position.x + bounds.size.x),
		clampf(point.y, bounds.position.y, bounds.position.y + bounds.size.y),
		clampf(point.z, bounds.position.z, bounds.position.z + bounds.size.z)
	)
	return point.distance_to(closest)

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
		var color := _hit_flash_color(base, _hit_weight)
		if _is_downed:
			color = Color(color.get_luminance(), color.get_luminance(), color.get_luminance(), color.a)
		var unique_material := base_material.duplicate() as StandardMaterial3D
		unique_material.albedo_color = color
		if _hit_weight > 0.0:
			unique_material.emission_enabled = true
			unique_material.emission = _hit_flash_color(base, _hit_weight)
			unique_material.emission_energy_multiplier = minf(0.45, maxf(unique_material.emission_energy_multiplier, _hit_weight * 0.45))
		mesh.material_override = unique_material

func _hit_flash_color(base: Color, weight: float) -> Color:
	var color := base.lightened(clampf(weight, 0.0, 1.0) * 0.35)
	if base.s > 0.10 and color.s <= 0.10:
		color = Color.from_hsv(base.h, minf(base.s, maxf(0.11, base.s * 0.65)), color.v, base.a)
	return color

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

func _transform_without_tree(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result

func _on_animation_finished(animation_id: StringName) -> void:
	if animation_id == active_action_id:
		var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null:
			player.speed_scale = 1.0
		action_finished.emit(animation_id)
