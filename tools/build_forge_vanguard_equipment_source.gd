extends SceneTree

# Standalone reproduction of the approved 90519ce Fighter geometry contract.
# Hammer, amulet, and rings are the visibility exceptions: their source roots
# are visible so modular runtime scenes and isolated icon capture never install
# invisible geometry from formerly embedded alternatives.
const SET_ID := &"fighter"
const IDS: Array[StringName] = ClassEquipmentRows.SET_ITEM_IDS[SET_ID]
const OUTPUT := "res://scenes/characters/presentation/forge_vanguard_equipment_source.tscn"
const SOCKETS := {
	&"helmet": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/HeadPivot/HelmetSocket",
	&"body_armour": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/BodyArmourSocket",
	&"legs": "HitPivot/BodyPivot/HipsPivot/LegsSocket",
	&"gloves": "HitPivot/BodyPivot/HipsPivot/GlovesSocket",
	&"boots": "HitPivot/BodyPivot/HipsPivot/BootsSocket",
	&"amulet": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/AmuletSocket",
	&"belt": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/BeltSocket",
	&"ring_left": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket",
	&"ring_right": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket",
	&"main_hand": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket",
	&"off_hand": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket",
}

func _initialize() -> void:
	var source := Node3D.new(); source.name = &"ForgeVanguardEquipmentSource"
	for index: int in IDS.size(): source.add_child(_make_item(IDS[index], ClassEquipmentRows.slot_for(SET_ID, index)))
	_set_owners(source, source)
	var packed := PackedScene.new()
	if packed.pack(source) != OK or ResourceSaver.save(packed, OUTPUT) != OK: _fail("could not save standalone equipment source"); return
	source.free()
	if not _remove_generated_node_ids(): _fail("could not stabilize standalone equipment source"); return
	print("FORGE_VANGUARD_EQUIPMENT_SOURCE_BUILD_OK items=%d" % IDS.size()); quit(0)

func _make_item(item_id: StringName, slot_id: StringName) -> Node3D:
	var item := Node3D.new(); item.name = item_id
	match item_id:
		&"forge_vanguard_helmet": _equipment(item, &"HelmetVisual", item_id, SOCKETS[slot_id], Vector3.ZERO, Vector3(0.38, 0.34, 0.34), &"metal")
		&"forge_vanguard_armour":
			var armour := _equipment(item, &"BodyArmourVisual", item_id, SOCKETS[slot_id], Vector3(0, 0.06, 0), Vector3(0.76, 0.56, 0.36), &"primary")
			_box(armour, &"LeftShoulderPlate", Vector3(-0.42, 0.24, 0), Vector3(0.12, 0.20, 0.38), &"metal")
			_box(armour, &"RightShoulderPlate", Vector3(0.42, 0.24, 0), Vector3(0.12, 0.20, 0.38), &"metal")
		&"forge_vanguard_greaves":
			# Task 3 addition: paired metal greaves use the established leg proportions.
			_equipment(item, &"LeftGreavesVisual", item_id, "HitPivot/BodyPivot/HipsPivot/LeftHipPivot", Vector3(0, -0.28, 0), Vector3(0.24, 0.42, 0.24), &"metal")
			_equipment(item, &"RightGreavesVisual", item_id, "HitPivot/BodyPivot/HipsPivot/RightHipPivot", Vector3(0, -0.28, 0), Vector3(0.24, 0.42, 0.24), &"metal")
		&"forge_vanguard_gauntlets":
			_equipment(item, &"LeftGlovesVisual", item_id, SOCKETS[&"ring_left"], Vector3(-0.02, -0.20, 0), Vector3(0.16, 0.17, 0.16), &"primary")
			_equipment(item, &"RightGlovesVisual", item_id, SOCKETS[&"ring_right"], Vector3(0.02, -0.20, 0), Vector3(0.16, 0.17, 0.16), &"primary")
		&"forge_vanguard_boots":
			_equipment(item, &"LeftBootsVisual", item_id, "HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot/LeftFootPivot", Vector3(-0.01, 0.05, 0), Vector3(0.23, 0.18, 0.34), &"primary")
			_equipment(item, &"RightBootsVisual", item_id, "HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot/RightFootPivot", Vector3(0.01, 0.05, 0), Vector3(0.23, 0.18, 0.34), &"primary")
		&"forge_vanguard_amulet": _equipment(item, &"AmuletVisual", item_id, SOCKETS[slot_id], Vector3(0, 0.20, -0.2), Vector3(0.10, 0.10, 0.04), &"brass", true, true)
		&"forge_vanguard_ring_left": _equipment(item, &"RingLeftVisual", item_id, SOCKETS[slot_id], Vector3(-0.03, -0.24, 0), Vector3(0.07, 0.07, 0.07), &"brass", true, true)
		&"forge_vanguard_ring_right": _equipment(item, &"RingRightVisual", item_id, SOCKETS[slot_id], Vector3(0.03, -0.24, 0), Vector3(0.07, 0.07, 0.07), &"brass", true, true)
		&"forge_vanguard_belt": _equipment(item, &"BeltVisual", item_id, SOCKETS[slot_id], Vector3(0, -0.04, 0), Vector3(0.58, 0.11, 0.32), &"leather")
		&"forge_vanguard_sword": _sword(item, item_id, SOCKETS[slot_id])
		&"forge_vanguard_shield": _equipment(item, &"OffHandVisual", item_id, SOCKETS[slot_id], Vector3(-0.04, 0.21, 0.02), Vector3(0.68, 0.68, 0.14), &"metal")
		&"forge_vanguard_hammer": _equipment(item, &"HammerVisual", item_id, SOCKETS[slot_id], Vector3(0.03, 0.11, 0), Vector3(0.09, 0.92, 0.07), &"metal", false, true)
	return item

func _equipment(item: Node3D, node_name: StringName, item_id: StringName, socket_id: String, position: Vector3, size: Vector3, region: StringName, emits: bool = false, starts_visible: bool = true) -> Node3D:
	var attachment := Node3D.new(); attachment.name = node_name; attachment.position = position; attachment.visible = starts_visible
	attachment.set_meta(&"equipment_visual_id", item_id); attachment.set_meta(&"equipment_socket_id", socket_id)
	item.add_child(attachment); _box(attachment, &"ReadableChannel", Vector3.ZERO, size, region, emits)
	return attachment

func _sword(item: Node3D, item_id: StringName, socket_id: String) -> void:
	var sword := Node3D.new(); sword.name = &"SwordVisual"; sword.position = Vector3(0.03, 0.09, 0); sword.visible = true
	sword.set_meta(&"equipment_visual_id", item_id); sword.set_meta(&"equipment_socket_id", socket_id); item.add_child(sword)
	_box(sword, &"Blade", Vector3(0, 0.38, 0), Vector3(0.10, 0.68, 0.035), &"metal")
	var tip := MeshInstance3D.new(); tip.name = &"Tip"; tip.position = Vector3(0, 0.80, 0); var cylinder := CylinderMesh.new(); cylinder.top_radius = 0.0; cylinder.bottom_radius = 0.065; cylinder.height = 0.16; cylinder.radial_segments = 4; tip.mesh = cylinder; tip.material_override = _material(&"metal"); tip.set_meta(&"palette_region", &"metal"); sword.add_child(tip)
	_box(sword, &"Crossguard", Vector3(0, 0.02, 0), Vector3(0.30, 0.055, 0.08), &"metal")
	_box(sword, &"Grip", Vector3(0, -0.11, 0), Vector3(0.065, 0.22, 0.065), &"leather")
	_box(sword, &"Pommel", Vector3(0, -0.25, 0), Vector3(0.09, 0.08, 0.08), &"metal")

func _box(parent: Node3D, node_name: StringName, position: Vector3, size: Vector3, region: StringName, emits: bool = false) -> void:
	var mesh := MeshInstance3D.new(); mesh.name = node_name; mesh.position = position; var box := BoxMesh.new(); box.size = size; mesh.mesh = box; mesh.material_override = _material(region, emits); mesh.set_meta(&"palette_region", region); parent.add_child(mesh)

func _material(region: StringName, emits: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new(); material.roughness = 0.78; material.metallic = 0.0
	match region:
		&"primary": material.albedo_color = Color("d94f4f")
		&"metal": material.albedo_color = Color("303a47"); material.metallic = 0.7
		&"brass": material.albedo_color = Color("b68b3a"); material.metallic = 0.55
		&"leather": material.albedo_color = Color("4a3426")
		_: material.albedo_color = Color("d8a47f")
	if emits: material.emission_enabled = true; material.emission = Color("ffd27a"); material.emission_energy_multiplier = 0.7
	return material

func _set_owners(node: Node, root: Node) -> void:
	for child: Node in node.get_children(): child.owner = root; _set_owners(child, root)
func _remove_generated_node_ids() -> bool:
	var file := FileAccess.open(OUTPUT, FileAccess.READ); if file == null: return false
	var expression := RegEx.new(); if expression.compile(" unique_id=[0-9]+") != OK: return false
	var stable := expression.sub(file.get_as_text(), "", true); file = FileAccess.open(OUTPUT, FileAccess.WRITE); if file == null: return false
	file.store_string(stable); return file.get_error() == OK
func _fail(reason: String) -> void: push_error("FORGE_VANGUARD_EQUIPMENT_SOURCE_BUILD_ERROR reason=%s" % reason); quit(1)
