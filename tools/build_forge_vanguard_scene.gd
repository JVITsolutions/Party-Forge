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
	for side: int in [-1, 1]:
		var prefix := "Left" if side < 0 else "Right"
		var shoulder := _pivot(torso, StringName(prefix + "ShoulderPivot"), Vector3(0.34 * side, 0.37, 0))
		var elbow := _pivot(shoulder, StringName(prefix + "ElbowPivot"), Vector3(0.08 * side, -0.28, 0))
		_pivot(elbow, StringName(prefix + "HandSocket"), Vector3(0.03 * side, -0.22, 0))
		var hip := _pivot(hips, StringName(prefix + "HipPivot"), Vector3(0.17 * side, -0.04, 0))
		var knee := _pivot(hip, StringName(prefix + "KneePivot"), Vector3(0, -0.38, 0))
		_pivot(knee, StringName(prefix + "FootPivot"), Vector3(0, -0.36, 0.05))
	_add_body(body_pivot, &"masculine", 0.82)
	_add_body(body_pivot, &"feminine", 0.72)
	_add_equipment(model, &"main_hand", &"forge_vanguard_sword", Vector3(0.48, 1.02, 0), Vector3(0.09, 0.92, 0.07), &"metal")
	_add_equipment(model, &"off_hand", &"forge_vanguard_shield", Vector3(-0.49, 1.12, 0.02), Vector3(0.14, 0.68, 0.68), &"metal")
	_add_equipment(model, &"helmet", &"forge_vanguard_helmet", Vector3(0, 1.53, 0), Vector3(0.38, 0.34, 0.34), &"metal")
	_add_equipment(model, &"body_armour", &"forge_vanguard_armour", Vector3(0, 1.10, 0), Vector3(0.76, 0.56, 0.36), &"primary")
	_add_equipment(model, &"gloves", &"forge_vanguard_gauntlets", Vector3(0.47, 0.71, 0), Vector3(0.16, 0.17, 0.16), &"primary")
	_add_equipment(model, &"boots", &"forge_vanguard_boots", Vector3(0.18, 0.09, 0.05), Vector3(0.23, 0.18, 0.34), &"primary")
	_add_equipment(model, &"belt", &"forge_vanguard_belt", Vector3(0, 0.78, 0), Vector3(0.58, 0.11, 0.32), &"leather")
	_add_equipment(model, &"amulet", &"forge_vanguard_amulet", Vector3(0, 1.24, -0.2), Vector3(0.10, 0.10, 0.04), &"brass")
	_add_equipment(model, &"ring_left", &"forge_vanguard_ring_left", Vector3(-0.48, 0.67, 0), Vector3(0.07, 0.07, 0.07), &"brass")
	_add_equipment(model, &"ring_right", &"forge_vanguard_ring_right", Vector3(0.48, 0.67, 0), Vector3(0.07, 0.07, 0.07), &"brass")
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
	print("FORGE_VANGUARD_BUILD_OK path=%s" % SCENE_PATH)
	quit(0)

func _pivot(parent: Node3D, node_name: StringName, position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = position
	parent.add_child(pivot)
	return pivot

func _add_body(parent: Node3D, preset_id: StringName, shoulder_width: float) -> void:
	var body := Node3D.new()
	body.name = StringName("%sBody" % preset_id.capitalize())
	body.set_meta(&"body_preset", preset_id)
	parent.add_child(body)
	_mesh(body, &"Torso", Vector3(0, 1.11, 0), Vector3(shoulder_width * 0.72, 0.58, 0.30), &"metal")
	_mesh(body, &"Head", Vector3(0, 1.52, 0), Vector3(0.28, 0.33, 0.28), &"skin")
	for side: int in [-1, 1]:
		_mesh(body, StringName("Arm%d" % side), Vector3(side * shoulder_width * 0.43, 0.90, 0), Vector3(0.16, 0.54, 0.16), &"metal")
		_mesh(body, StringName("Leg%d" % side), Vector3(side * 0.17, 0.42, 0), Vector3(0.20, 0.70, 0.20), &"leather")

func _add_equipment(parent: Node3D, slot_id: StringName, visual_id: StringName, position: Vector3, size: Vector3, region: StringName) -> void:
	var equipment := Node3D.new()
	equipment.name = StringName("%sVisual" % slot_id.capitalize())
	equipment.position = position
	equipment.set_meta(&"equipment_slot", slot_id)
	equipment.set_meta(&"equipment_visual_id", visual_id)
	parent.add_child(equipment)
	_mesh(equipment, &"ReadableChannel", Vector3.ZERO, size, region)
	if slot_id == &"body_armour":
		_mesh(equipment, &"LeftShoulderPlate", Vector3(-0.42, 0.24, 0), Vector3(0.12, 0.20, 0.38), &"metal")
		_mesh(equipment, &"RightShoulderPlate", Vector3(0.42, 0.24, 0), Vector3(0.12, 0.20, 0.38), &"metal")

func _mesh(parent: Node3D, node_name: StringName, position: Vector3, size: Vector3, region: StringName) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material(region)
	mesh_instance.set_meta(&"palette_region", region)
	parent.add_child(mesh_instance)

func _material(region: StringName) -> StandardMaterial3D:
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
	return material

func _set_scene_owners(node: Node, scene_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		_set_scene_owners(child, scene_root)
