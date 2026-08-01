extends SceneTree

const SCENE_PATH := "res://scenes/characters/presentation/forge_vanguard_model.tscn"
const MODEL_SCRIPT := preload("res://scripts/presentation/forge_vanguard_model.gd")

func _initialize() -> void:
	var model := MODEL_SCRIPT.new() as Node3D
	model.name = &"ForgeVanguardModel"
	var hit_pivot := _pivot(model, &"HitPivot", Vector3.ZERO)
	var body_pivot := _pivot(hit_pivot, &"BodyPivot", Vector3.ZERO)
	var hips := _pivot(body_pivot, &"HipsPivot", Vector3(0, 0.82, 0))
	var torso := _pivot(hips, &"TorsoPivot", Vector3(0, 0.22, 0))
	var head := _pivot(torso, &"HeadPivot", Vector3(0, 0.48, 0))
	var limb_pivots := _build_limb_pivots(hips, torso)
	_add_body(torso, head, limb_pivots, hips, &"masculine", 0.82)
	_add_body(torso, head, limb_pivots, hips, &"feminine", 0.72)
	_add_hammer(limb_pivots[&"right_hand"])
	_add_sword(limb_pivots[&"right_hand"])
	_add_equipment(limb_pivots[&"left_hand"], &"off_hand", &"forge_vanguard_shield", Vector3(-0.04, 0.21, 0.02), Vector3(0.68, 0.68, 0.14), &"metal")
	_add_equipment(head, &"helmet", &"forge_vanguard_helmet", Vector3.ZERO, Vector3(0.38, 0.34, 0.34), &"metal")
	_add_equipment(torso, &"body_armour", &"forge_vanguard_armour", Vector3(0, 0.06, 0), Vector3(0.76, 0.56, 0.36), &"primary")
	_add_equipment(limb_pivots[&"left_hand"], &"gloves", &"forge_vanguard_gauntlets", Vector3(-0.02, -0.20, 0), Vector3(0.16, 0.17, 0.16), &"primary")
	_add_equipment(limb_pivots[&"right_hand"], &"gloves", &"forge_vanguard_gauntlets", Vector3(0.02, -0.20, 0), Vector3(0.16, 0.17, 0.16), &"primary")
	_add_equipment(limb_pivots[&"left_foot"], &"boots", &"forge_vanguard_boots", Vector3(-0.01, 0.05, 0), Vector3(0.23, 0.18, 0.34), &"primary")
	_add_equipment(limb_pivots[&"right_foot"], &"boots", &"forge_vanguard_boots", Vector3(0.01, 0.05, 0), Vector3(0.23, 0.18, 0.34), &"primary")
	_add_equipment(hips, &"belt", &"forge_vanguard_belt", Vector3(0, -0.04, 0), Vector3(0.58, 0.11, 0.32), &"leather")
	_add_equipment(torso, &"amulet", &"forge_vanguard_amulet", Vector3(0, 0.20, -0.2), Vector3(0.10, 0.10, 0.04), &"brass", true, false)
	_add_equipment(limb_pivots[&"left_hand"], &"ring_left", &"forge_vanguard_ring_left", Vector3(-0.03, -0.24, 0), Vector3(0.07, 0.07, 0.07), &"brass", true, false)
	_add_equipment(limb_pivots[&"right_hand"], &"ring_right", &"forge_vanguard_ring_right", Vector3(0.03, -0.24, 0), Vector3(0.07, 0.07, 0.07), &"brass", true, false)
	_add_animations(model)
	_save_scene(model)

func _add_animations(model: Node3D) -> void:
	var player := AnimationPlayer.new()
	player.name = &"AnimationPlayer"
	player.root_node = NodePath("..")
	model.add_child(player)
	var library := AnimationLibrary.new()
	_add_animation(library, &"idle", 1.6, true, [
		_pose(0.00),
		_pose(0.40, {&"body": Vector3(0, 0.018, 0), &"torso": Vector3(0, 0.238, 0)}, {&"torso": Vector3(0.025, 0, 0), &"left_shoulder": Vector3(0, 0, -0.035), &"right_shoulder": Vector3(0, 0, 0.035)}),
		_pose(0.80, {&"body": Vector3(-0.025, 0.008, 0), &"torso": Vector3(0, 0.226, 0)}, {&"torso": Vector3(0, 0, -0.035), &"left_shoulder": Vector3(0, 0, -0.06), &"right_elbow": Vector3(0, 0, 0.05)}),
		_pose(1.20, {&"body": Vector3(0, -0.010, 0), &"torso": Vector3(0, 0.210, 0)}, {&"torso": Vector3(-0.018, 0, 0), &"left_elbow": Vector3(0, 0, -0.035), &"right_shoulder": Vector3(0, 0, 0.025)}),
		_pose(1.60),
	])
	_add_animation(library, &"attack_slash", 0.55, false, [
		_pose(0.00),
		_pose(0.12, {&"body": Vector3(-0.025, 0, 0.025), &"torso": Vector3(0, 0.220, 0.025)}, {&"torso": Vector3(0.08, -0.16, -0.10), &"right_shoulder": Vector3(-0.08, -0.24, -1.05), &"right_elbow": Vector3(0.10, 0, -0.45), &"left_shoulder": Vector3(0, 0, -0.10)}),
		_pose(0.28, {&"body": Vector3(0.025, 0, -0.015), &"torso": Vector3(0, 0.220, -0.012)}, {&"torso": Vector3(-0.06, 0.24, 0.12), &"right_shoulder": Vector3(0.12, 0.36, 1.18), &"right_elbow": Vector3(-0.08, 0, 0.78), &"left_elbow": Vector3(0, 0, -0.10)}),
		_pose(0.42, {&"body": Vector3(0.010, 0, 0), &"torso": Vector3(0, 0.220, 0)}, {&"torso": Vector3(0, 0.08, 0), &"right_shoulder": Vector3(0, 0.10, 0.28), &"right_elbow": Vector3(0, 0, 0.18)}),
		_pose(0.55),
	])
	_add_animation(library, &"attack_combo", 0.9, false, [
		_pose(0.00),
		_pose(0.14, {&"body": Vector3(-0.020, 0, 0.020)}, {&"torso": Vector3(0.06, -0.12, -0.08), &"right_shoulder": Vector3(-0.06, -0.22, -0.92), &"right_elbow": Vector3(0.08, 0, -0.42)}),
		_pose(0.30, {&"body": Vector3(0.022, 0, -0.012)}, {&"torso": Vector3(-0.05, 0.20, 0.10), &"right_shoulder": Vector3(0.10, 0.30, 1.05), &"right_elbow": Vector3(-0.06, 0, 0.72)}),
		_pose(0.48, {&"body": Vector3(0.008, 0, 0)}, {&"torso": Vector3(0, 0.05, 0), &"right_shoulder": Vector3(0, 0.06, 0.18), &"right_elbow": Vector3(0, 0, 0.10)}),
		_pose(0.62, {&"body": Vector3(0.018, 0, 0.012)}, {&"torso": Vector3(-0.04, -0.14, 0.08), &"left_shoulder": Vector3(-0.18, 0, 0.78), &"left_elbow": Vector3(0.10, 0, 0.42)}),
		_pose(0.74, {&"body": Vector3(-0.018, 0, -0.060), &"torso": Vector3(0, 0.220, -0.050)}, {&"torso": Vector3(0.12, 0.10, -0.08), &"left_shoulder": Vector3(0.34, 0, -0.34), &"left_elbow": Vector3(-0.18, 0, -0.28)}),
		_pose(0.90),
	])
	_add_animation(library, &"hit_flinch", 0.25, false, [
		_pose(0.00),
		_pose(0.07, {&"hit": Vector3(0, 0, 0.090), &"body": Vector3(0, 0, 0.035), &"torso": Vector3(0, 0.220, 0.025)}, {&"torso": Vector3(-0.16, 0, 0), &"right_shoulder": Vector3(-0.08, 0, 0.12), &"left_shoulder": Vector3(-0.12, 0, -0.22)}),
		_pose(0.15, {&"hit": Vector3(0, 0, 0.045), &"body": Vector3(0.012, 0, 0.018)}, {&"torso": Vector3(-0.08, 0, 0.06), &"right_shoulder": Vector3(-0.04, 0, 0.18), &"right_elbow": Vector3(0, 0, 0.12), &"left_shoulder": Vector3(-0.10, 0, -0.42), &"left_elbow": Vector3(0, 0, -0.24)}),
		_pose(0.25),
	])
	player.add_animation_library(&"", library)

func _add_animation(library: AnimationLibrary, animation_id: StringName, length: float, loops: bool, poses: Array[Dictionary]) -> void:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
	for pivot_id: StringName in _animated_pivot_ids():
		var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(position_track, NodePath("%s:position" % _pivot_animation_path(pivot_id)))
		var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(rotation_track, NodePath("%s:rotation" % _pivot_animation_path(pivot_id)))
		for pose: Dictionary in poses:
			var time := float(pose[&"time"])
			var positions := pose[&"positions"] as Dictionary
			var rotations := pose[&"rotations"] as Dictionary
			animation.position_track_insert_key(position_track, time, positions[pivot_id] as Vector3)
			animation.rotation_track_insert_key(rotation_track, time, Quaternion.from_euler(rotations[pivot_id] as Vector3))
	library.add_animation(animation_id, animation)

func _pose(time: float, position_overrides: Dictionary = {}, rotation_overrides: Dictionary = {}) -> Dictionary:
	var positions := _neutral_positions()
	var rotations := _neutral_rotations()
	for pivot_id: Variant in position_overrides:
		positions[pivot_id] = position_overrides[pivot_id]
	for pivot_id: Variant in rotation_overrides:
		rotations[pivot_id] = rotation_overrides[pivot_id]
	return {&"time": time, &"positions": positions, &"rotations": rotations}

func _animated_pivot_ids() -> Array[StringName]:
	return [&"hit", &"body", &"torso", &"left_shoulder", &"left_elbow", &"right_shoulder", &"right_elbow"]

func _neutral_positions() -> Dictionary:
	return {
		&"hit": Vector3.ZERO,
		&"body": Vector3.ZERO,
		&"torso": Vector3(0, 0.22, 0),
		&"left_shoulder": Vector3(-0.34, 0.37, 0),
		&"left_elbow": Vector3(-0.08, -0.28, 0),
		&"right_shoulder": Vector3(0.34, 0.37, 0),
		&"right_elbow": Vector3(0.08, -0.28, 0),
	}

func _neutral_rotations() -> Dictionary:
	var rotations := {}
	for pivot_id: StringName in _animated_pivot_ids():
		rotations[pivot_id] = Vector3.ZERO
	return rotations

func _pivot_animation_path(pivot_id: StringName) -> String:
	match pivot_id:
		&"hit": return "HitPivot"
		&"body": return "HitPivot/BodyPivot"
		&"torso": return "HitPivot/BodyPivot/HipsPivot/TorsoPivot"
		&"left_shoulder": return "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot"
		&"left_elbow": return "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot"
		&"right_shoulder": return "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot"
		&"right_elbow": return "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot"
	return ""

func _build_limb_pivots(hips: Node3D, torso: Node3D) -> Dictionary:
	var pivots := {}
	for side: int in [-1, 1]:
		var prefix := "Left" if side < 0 else "Right"
		var side_id := "left" if side < 0 else "right"
		var shoulder := _pivot(torso, StringName(prefix + "ShoulderPivot"), Vector3(0.34 * side, 0.37, 0))
		var elbow := _pivot(shoulder, StringName(prefix + "ElbowPivot"), Vector3(0.08 * side, -0.28, 0))
		var hand := _pivot(elbow, StringName(prefix + "HandSocket"), Vector3(0.03 * side, -0.22, 0))
		var hip := _pivot(hips, StringName(prefix + "HipPivot"), Vector3(0.17 * side, -0.04, 0))
		var knee := _pivot(hip, StringName(prefix + "KneePivot"), Vector3(0, -0.38, 0))
		var foot := _pivot(knee, StringName(prefix + "FootPivot"), Vector3(0, -0.36, 0.05))
		pivots[StringName(side_id + "_shoulder")] = shoulder
		pivots[StringName(side_id + "_elbow")] = elbow
		pivots[StringName(side_id + "_hand")] = hand
		pivots[StringName(side_id + "_hip")] = hip
		pivots[StringName(side_id + "_knee")] = knee
		pivots[StringName(side_id + "_foot")] = foot
	return pivots

func _add_body(torso: Node3D, head: Node3D, pivots: Dictionary, hips: Node3D, preset_id: StringName, shoulder_width: float) -> void:
	_body_mesh(torso, preset_id, &"Torso", Vector3(0, 0.07, 0), Vector3(shoulder_width * 0.72, 0.58, 0.30), &"metal")
	_body_mesh(head, preset_id, &"Head", Vector3.ZERO, Vector3(0.28, 0.33, 0.28), &"skin")
	for side_id: StringName in [&"left", &"right"]:
		var side := -1.0 if side_id == &"left" else 1.0
		_body_mesh(pivots[side_id + "_shoulder"], preset_id, &"UpperArm", Vector3(0.04 * side, -0.14, 0), Vector3(0.16, 0.30, 0.16), &"metal")
		_body_mesh(pivots[side_id + "_elbow"], preset_id, &"Forearm", Vector3(0.015 * side, -0.11, 0), Vector3(0.15, 0.24, 0.15), &"metal")
		_body_mesh(pivots[side_id + "_hip"], preset_id, &"Thigh", Vector3(0, -0.19, 0), Vector3(0.20, 0.40, 0.20), &"leather")
		_body_mesh(pivots[side_id + "_knee"], preset_id, &"Shin", Vector3(0, -0.18, 0), Vector3(0.19, 0.38, 0.19), &"leather")
		_body_mesh(pivots[side_id + "_foot"], preset_id, &"Foot", Vector3(0, 0.05, 0), Vector3(0.18, 0.14, 0.28), &"leather")

func _body_mesh(parent: Node3D, preset_id: StringName, part_name: StringName, position: Vector3, size: Vector3, region: StringName) -> void:
	var alternative := Node3D.new()
	alternative.name = StringName("%s%s" % [preset_id.capitalize(), part_name])
	alternative.set_meta(&"body_preset", preset_id)
	parent.add_child(alternative)
	_mesh(alternative, &"ReadableChannel", position, size, region)

func _add_equipment(parent: Node3D, slot_id: StringName, visual_id: StringName, position: Vector3, size: Vector3, region: StringName, emits: bool = false, starts_visible: bool = true) -> void:
	var equipment := _equipment_root(parent, _equipment_node_name(slot_id), slot_id, visual_id, position, starts_visible)
	_mesh(equipment, &"ReadableChannel", Vector3.ZERO, size, region, emits)
	if slot_id == &"body_armour":
		_mesh(equipment, &"LeftShoulderPlate", Vector3(-0.42, 0.24, 0), Vector3(0.12, 0.20, 0.38), &"metal")
		_mesh(equipment, &"RightShoulderPlate", Vector3(0.42, 0.24, 0), Vector3(0.12, 0.20, 0.38), &"metal")

func _equipment_root(parent: Node3D, node_name: StringName, slot_id: StringName, visual_id: StringName, position: Vector3, starts_visible: bool) -> Node3D:
	var equipment := Node3D.new()
	equipment.name = node_name
	equipment.position = position
	equipment.visible = starts_visible
	equipment.set_meta(&"equipment_slot", slot_id)
	equipment.set_meta(&"equipment_visual_id", visual_id)
	parent.add_child(equipment)
	return equipment

func _add_hammer(parent: Node3D) -> void:
	var hammer := _equipment_root(parent, &"HammerVisual", &"main_hand", &"forge_vanguard_hammer", Vector3(0.03, 0.11, 0), false)
	_mesh(hammer, &"ReadableChannel", Vector3.ZERO, Vector3(0.09, 0.92, 0.07), &"metal")

func _add_sword(parent: Node3D) -> void:
	var sword := _equipment_root(parent, &"SwordVisual", &"main_hand", &"forge_vanguard_sword", Vector3(0.03, 0.09, 0), true)
	_mesh(sword, &"Blade", Vector3(0, 0.38, 0), Vector3(0.10, 0.68, 0.035), &"metal")
	_sword_tip(sword, Vector3(0, 0.80, 0))
	_mesh(sword, &"Crossguard", Vector3(0, 0.02, 0), Vector3(0.30, 0.055, 0.08), &"metal")
	_mesh(sword, &"Grip", Vector3(0, -0.11, 0), Vector3(0.065, 0.22, 0.065), &"leather")
	_mesh(sword, &"Pommel", Vector3(0, -0.25, 0), Vector3(0.09, 0.08, 0.08), &"metal")

func _sword_tip(parent: Node3D, position: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = &"Tip"
	mesh_instance.position = position
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.065
	tip.height = 0.16
	tip.radial_segments = 4
	mesh_instance.mesh = tip
	mesh_instance.material_override = _material(&"metal")
	mesh_instance.set_meta(&"palette_region", &"metal")
	parent.add_child(mesh_instance)

func _equipment_node_name(slot_id: StringName) -> StringName:
	match slot_id:
		&"main_hand": return &"MainHandVisual"
		&"off_hand": return &"OffHandVisual"
		&"body_armour": return &"BodyArmourVisual"
		&"ring_left": return &"RingLeftVisual"
		&"ring_right": return &"RingRightVisual"
		_: return StringName("%sVisual" % slot_id.capitalize())

func _pivot(parent: Node3D, node_name: StringName, position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = position
	parent.add_child(pivot)
	return pivot

func _mesh(parent: Node3D, node_name: StringName, position: Vector3, size: Vector3, region: StringName, emits: bool = false) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material(region, emits)
	mesh_instance.set_meta(&"palette_region", region)
	parent.add_child(mesh_instance)

func _material(region: StringName, emits: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.78
	material.metallic = 0.0
	match region:
		&"primary": material.albedo_color = Color("d94f4f")
		&"metal":
			material.albedo_color = Color("303a47")
			material.metallic = 0.7
		&"brass":
			material.albedo_color = Color("b68b3a")
			material.metallic = 0.55
		&"leather": material.albedo_color = Color("4a3426")
		_: material.albedo_color = Color("d8a47f")
	if emits:
		material.emission_enabled = true
		material.emission = Color("ffd27a")
		material.emission_energy_multiplier = 0.7
	return material

func _save_scene(model: Node3D) -> void:
	_set_scene_owners(model, model)
	var scene := PackedScene.new()
	if scene.pack(model) != OK:
		push_error("FORGE_VANGUARD_BUILD_ERROR reason=pack failed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_PATH).get_base_dir())
	var result := ResourceSaver.save(scene, SCENE_PATH)
	model.free()
	if result != OK:
		push_error("FORGE_VANGUARD_BUILD_ERROR reason=save code=%d" % result)
		quit(1)
		return
	if not _remove_generated_node_ids():
		push_error("FORGE_VANGUARD_BUILD_ERROR reason=stabilize scene failed")
		quit(1)
		return
	print("FORGE_VANGUARD_BUILD_OK path=%s" % SCENE_PATH)
	quit(0)

func _remove_generated_node_ids() -> bool:
	var file := FileAccess.open(SCENE_PATH, FileAccess.READ)
	if file == null:
		return false
	var scene_text := file.get_as_text()
	var node_id_pattern := RegEx.new()
	if node_id_pattern.compile(" unique_id=[0-9]+") != OK:
		return false
	var stable_scene_text := node_id_pattern.sub(scene_text, "", true)
	if stable_scene_text == scene_text:
		return true
	file = FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(stable_scene_text)
	return file.get_error() == OK

func _set_scene_owners(node: Node, scene_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		_set_scene_owners(child, scene_root)
