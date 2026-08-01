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
	_add_equipment(limb_pivots[&"right_hand"], &"main_hand", &"forge_vanguard_sword", Vector3(0.03, 0.11, 0), Vector3(0.09, 0.92, 0.07), &"metal")
	_add_equipment(limb_pivots[&"left_hand"], &"off_hand", &"forge_vanguard_shield", Vector3(-0.04, 0.21, 0.02), Vector3(0.14, 0.68, 0.68), &"metal")
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
	_save_scene(model)

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
	var equipment := Node3D.new()
	equipment.name = _equipment_node_name(slot_id)
	equipment.position = position
	equipment.visible = starts_visible
	equipment.set_meta(&"equipment_slot", slot_id)
	equipment.set_meta(&"equipment_visual_id", visual_id)
	parent.add_child(equipment)
	_mesh(equipment, &"ReadableChannel", Vector3.ZERO, size, region, emits)
	if slot_id == &"body_armour":
		_mesh(equipment, &"LeftShoulderPlate", Vector3(-0.42, 0.24, 0), Vector3(0.12, 0.20, 0.38), &"metal")
		_mesh(equipment, &"RightShoulderPlate", Vector3(0.42, 0.24, 0), Vector3(0.12, 0.20, 0.38), &"metal")

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
