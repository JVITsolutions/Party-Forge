extends SceneTree

# This is the authoring source for the Fighter equipment bank. It deliberately
# constructs geometry in memory: generated item scenes are never read here.
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
	var source := Node3D.new()
	source.name = &"ForgeVanguardEquipmentSource"
	for index: int in IDS.size():
		var item_id := IDS[index]
		var item := _make_item(item_id, ClassEquipmentRows.slot_for(SET_ID, index))
		if item.get_child_count() == 0:
			_fail("no geometry constructed for %s" % item_id)
			return
		source.add_child(item)
	_set_owners(source, source)
	var packed := PackedScene.new()
	if packed.pack(source) != OK or ResourceSaver.save(packed, OUTPUT) != OK:
		_fail("could not save standalone equipment source")
		return
	source.free()
	if not _remove_generated_node_ids():
		_fail("could not stabilize standalone equipment source")
		return
	print("FORGE_VANGUARD_EQUIPMENT_SOURCE_BUILD_OK items=%d" % IDS.size())
	quit(0)

func _make_item(item_id: StringName, slot_id: StringName) -> Node3D:
	var item := Node3D.new()
	item.name = item_id
	match item_id:
		&"forge_vanguard_gauntlets":
			_add_attachment(item, item_id, SOCKETS[&"ring_left"], Vector3(-0.04, 0, 0), Vector3(0.18, 0.20, 0.20), &"metal")
			_add_attachment(item, item_id, SOCKETS[&"ring_right"], Vector3(0.04, 0, 0), Vector3(0.18, 0.20, 0.20), &"metal")
		&"forge_vanguard_boots":
			_add_attachment(item, item_id, "HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot/LeftFootPivot", Vector3(-0.13, -0.02, 0.05), Vector3(0.24, 0.16, 0.38), &"leather")
			_add_attachment(item, item_id, "HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot/RightFootPivot", Vector3(0.13, -0.02, 0.05), Vector3(0.24, 0.16, 0.38), &"leather")
		&"forge_vanguard_greaves":
			_add_attachment(item, item_id, "HitPivot/BodyPivot/HipsPivot/LeftHipPivot", Vector3(-0.12, -0.22, 0), Vector3(0.24, 0.42, 0.24), &"metal")
			_add_attachment(item, item_id, "HitPivot/BodyPivot/HipsPivot/RightHipPivot", Vector3(0.12, -0.22, 0), Vector3(0.24, 0.42, 0.24), &"metal")
		&"forge_vanguard_sword": _add_sword(item, item_id, SOCKETS[slot_id])
		&"forge_vanguard_hammer": _add_hammer(item, item_id, SOCKETS[slot_id])
		&"forge_vanguard_shield": _add_shield(item, item_id, SOCKETS[slot_id])
		&"forge_vanguard_amulet": _add_amulet(item, item_id, SOCKETS[slot_id])
		&"forge_vanguard_ring_left", &"forge_vanguard_ring_right": _add_ring(item, item_id, SOCKETS[slot_id])
		&"forge_vanguard_helmet": _add_helmet(item, item_id, SOCKETS[slot_id])
		&"forge_vanguard_armour": _add_armour(item, item_id, SOCKETS[slot_id])
		&"forge_vanguard_belt": _add_attachment(item, item_id, SOCKETS[slot_id], Vector3.ZERO, Vector3(0.72, 0.12, 0.34), &"leather")
		_: _add_attachment(item, item_id, SOCKETS[slot_id], Vector3.ZERO, Vector3(0.28, 0.28, 0.28), &"metal")
	return item

func _add_attachment(item: Node3D, item_id: StringName, socket_id: String, position: Vector3, size: Vector3, region: StringName) -> Node3D:
	var attachment := Node3D.new()
	attachment.name = &"Attachment"
	attachment.position = position
	attachment.visible = true
	attachment.set_meta(&"equipment_visual_id", item_id)
	attachment.set_meta(&"equipment_socket_id", socket_id)
	item.add_child(attachment)
	_add_box(attachment, &"ReadableChannel", Vector3.ZERO, size, region)
	return attachment

func _add_helmet(item: Node3D, item_id: StringName, socket_id: String) -> void:
	var attachment := _add_attachment(item, item_id, socket_id, Vector3.ZERO, Vector3(0.38, 0.30, 0.36), &"metal")
	_add_box(attachment, &"Crest", Vector3(0, 0.21, 0), Vector3(0.10, 0.18, 0.26), &"brass")

func _add_armour(item: Node3D, item_id: StringName, socket_id: String) -> void:
	var attachment := _add_attachment(item, item_id, socket_id, Vector3.ZERO, Vector3(0.72, 0.58, 0.34), &"metal")
	_add_box(attachment, &"LeftShoulderPlate", Vector3(-0.42, 0.20, 0), Vector3(0.16, 0.18, 0.40), &"metal")
	_add_box(attachment, &"RightShoulderPlate", Vector3(0.42, 0.20, 0), Vector3(0.16, 0.18, 0.40), &"metal")

func _add_sword(item: Node3D, item_id: StringName, socket_id: String) -> void:
	var attachment := _add_attachment(item, item_id, socket_id, Vector3(0, 0.34, 0), Vector3(0.10, 0.72, 0.05), &"metal")
	_add_box(attachment, &"Crossguard", Vector3(0, -0.38, 0), Vector3(0.34, 0.06, 0.10), &"brass")
	_add_box(attachment, &"Grip", Vector3(0, -0.51, 0), Vector3(0.08, 0.22, 0.08), &"leather")

func _add_hammer(item: Node3D, item_id: StringName, socket_id: String) -> void:
	var attachment := _add_attachment(item, item_id, socket_id, Vector3(0, 0.05, 0), Vector3(0.09, 0.92, 0.07), &"leather")
	_add_box(attachment, &"HammerHead", Vector3(0, 0.42, 0), Vector3(0.42, 0.20, 0.24), &"metal")

func _add_shield(item: Node3D, item_id: StringName, socket_id: String) -> void:
	var attachment := _add_attachment(item, item_id, socket_id, Vector3.ZERO, Vector3(0.68, 0.84, 0.13), &"metal")
	_add_box(attachment, &"Boss", Vector3(0, 0, 0.10), Vector3(0.22, 0.22, 0.10), &"brass")

func _add_amulet(item: Node3D, item_id: StringName, socket_id: String) -> void:
	var attachment := _add_attachment(item, item_id, socket_id, Vector3.ZERO, Vector3(0.10, 0.28, 0.08), &"brass")
	_add_box(attachment, &"Pendant", Vector3(0, -0.16, 0), Vector3(0.18, 0.18, 0.10), &"brass")

func _add_ring(item: Node3D, item_id: StringName, socket_id: String) -> void:
	var attachment := _add_attachment(item, item_id, socket_id, Vector3.ZERO, Vector3(0.20, 0.20, 0.08), &"brass")
	_add_box(attachment, &"Gem", Vector3(0, 0.12, 0), Vector3(0.10, 0.10, 0.10), &"primary")

func _add_box(parent: Node3D, node_name: StringName, position: Vector3, size: Vector3, region: StringName) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = position
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(region)
	mesh.set_meta(&"palette_region", region)
	parent.add_child(mesh)

func _material(region: StringName) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.78
	match region:
		&"metal": material.albedo_color = Color("303a47"); material.metallic = 0.7
		&"brass": material.albedo_color = Color("b68b3a"); material.metallic = 0.55
		&"leather": material.albedo_color = Color("4a3426")
		&"primary": material.albedo_color = Color("d94f4f")
	return material

func _set_owners(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_set_owners(child, root)

func _remove_generated_node_ids() -> bool:
	var file := FileAccess.open(OUTPUT, FileAccess.READ)
	if file == null: return false
	var expression := RegEx.new()
	if expression.compile(" unique_id=[0-9]+") != OK: return false
	var stable := expression.sub(file.get_as_text(), "", true)
	file = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null: return false
	file.store_string(stable)
	return file.get_error() == OK

func _fail(reason: String) -> void:
	push_error("FORGE_VANGUARD_EQUIPMENT_SOURCE_BUILD_ERROR reason=%s" % reason)
	quit(1)
