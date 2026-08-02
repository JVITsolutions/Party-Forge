extends SceneTree

const IDS: Array[StringName] = ClassEquipmentRows.SET_ITEM_IDS[&"fighter"]
const SOURCE_PATH := "res://scenes/characters/presentation/forge_vanguard_equipment_source.tscn"
const SET_FOLDERS := {&"fighter": &"forge_vanguard", &"paladin": &"dawn_bulwark", &"rogue": &"nightstep"}
const SET_STYLES := {
	&"paladin": {&"primary": Color("e0b94f"), &"metal": Color("d7dce2"), &"leather": Color("553c28"), &"accent": Color("fff0a1")},
	&"rogue": {&"primary": Color("5a426e"), &"metal": Color("4b5360"), &"leather": Color("282127"), &"accent": Color("8b5aa5")},
}
const SOCKETS := {&"helmet": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/HeadPivot/HelmetSocket", &"body_armour": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/BodyArmourSocket", &"legs": "HitPivot/BodyPivot/HipsPivot/LegsSocket", &"gloves": "HitPivot/BodyPivot/HipsPivot/GlovesSocket", &"boots": "HitPivot/BodyPivot/HipsPivot/BootsSocket", &"amulet": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/AmuletSocket", &"belt": "HitPivot/BodyPivot/HipsPivot/BeltSocket", &"ring_left": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket", &"ring_right": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket", &"main_hand": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket", &"off_hand": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket"}

func _initialize() -> void:
	_trace("initialize_entry")
	var requested_sets := _sets()
	_trace("sets_return=%s" % [requested_sets])
	if requested_sets.is_empty(): _fail("no registered equipment sets requested"); return
	var item_count := 0
	for set_id: StringName in requested_sets:
		if not SET_FOLDERS.has(set_id): _fail("set generator is not registered set=%s" % set_id); return
		var set_ids: Array = ClassEquipmentRows.SET_ITEM_IDS[set_id]
		for index: int in set_ids.size():
			var item_id := set_ids[index] as StringName
			_trace("item_begin=%s" % item_id)
			var success := _write_item(item_id, ClassEquipmentRows.slot_for(set_id, index)) if set_id == &"fighter" else _write_procedural_item(set_id, item_id, ClassEquipmentRows.slot_for(set_id, index))
			if not success: return
			item_count += 1
	if &"fighter" in requested_sets:
		_trace("profile_write_begin")
		if not _write_profiles(): _fail("profile write failed"); return
		_trace("profile_write_done")
	if not _write_catalog(): _fail("catalog write failed"); return
	print("EQUIPMENT_ASSET_BUILD_OK sets=%d items=%d" % [requested_sets.size(), item_count])
	quit(0)

func _sets() -> Array[StringName]:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sets="):
			var result: Array[StringName] = []
			for set_id: String in arg.trim_prefix("--sets=").split(","):
				if set_id.strip_edges().is_empty() or not ClassEquipmentRows.SET_ITEM_IDS.has(StringName(set_id)):
					return []
				result.append(StringName(set_id))
			return result
	return [&"fighter"]

func _write_procedural_item(set_id: StringName, item_id: StringName, slot: StringName) -> bool:
	var root := Node3D.new()
	root.name = item_id
	if slot in [&"legs", &"gloves", &"boots"]:
		for side: String in ["Left", "Right"]:
			var attachment := _new_attachment(item_id, _paired_socket(slot, side))
			_add_wearable_geometry(attachment, set_id, item_id, slot, side)
			root.add_child(attachment)
	else:
		var attachment := _new_attachment(item_id, String(SOCKETS[slot]))
		_add_wearable_geometry(attachment, set_id, item_id, slot, "")
		root.add_child(attachment)
	_set_owners(root, root)
	var folder := String(SET_FOLDERS[set_id])
	var scene_path := "res://scenes/equipment/%s/%s.tscn" % [folder, item_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scene_path).get_base_dir())
	var packed := PackedScene.new()
	if packed.pack(root) != OK or ResourceSaver.save(packed, scene_path) != OK:
		root.free(); _fail("procedural scene save item=%s" % item_id); return false
	root.free()
	if not _remove_generated_node_ids(scene_path): _fail("scene stabilize item=%s" % item_id); return false
	return _write_procedural_resources(set_id, item_id, slot, scene_path)

func _new_attachment(item_id: StringName, socket_path: String) -> Node3D:
	var attachment := Node3D.new()
	attachment.name = &"Attachment"
	attachment.set_meta(&"equipment_visual_id", item_id)
	attachment.set_meta(&"equipment_socket_id", socket_path)
	return attachment

func _add_wearable_geometry(root: Node3D, set_id: StringName, item_id: StringName, slot: StringName, side: String) -> void:
	var heavy := set_id == &"paladin"
	match slot:
		&"helmet":
			_add_box(root, Vector3(0.42 if heavy else 0.36, 0.30, 0.38), Vector3(0, 0.02, 0), &"metal" if heavy else &"leather", set_id)
			_add_box(root, Vector3(0.08, 0.18, 0.08), Vector3(0, 0.24, 0), &"accent", set_id)
		&"body_armour":
			_add_box(root, Vector3(0.82 if heavy else 0.64, 0.72, 0.38 if heavy else 0.28), Vector3(0, -0.02, 0), &"metal" if heavy else &"leather", set_id)
			_add_box(root, Vector3(0.92 if heavy else 0.68, 0.12, 0.44 if heavy else 0.30), Vector3(0, 0.22, 0), &"primary", set_id)
		&"legs":
			_add_box(root, Vector3(0.25, 0.44, 0.28), Vector3(0, -0.23, 0), &"metal" if heavy else &"leather", set_id)
		&"gloves":
			_add_box(root, Vector3(0.22, 0.22, 0.24), Vector3.ZERO, &"metal" if heavy else &"leather", set_id)
		&"boots":
			_add_box(root, Vector3(0.27, 0.30, 0.38), Vector3(0, 0.13, -0.04), &"metal" if heavy else &"leather", set_id)
		&"amulet":
			_add_cylinder(root, 0.11, 0.05, Vector3(0, -0.12, -0.20), &"accent", set_id, Vector3(PI * 0.5, 0, 0))
		&"ring_left", &"ring_right":
			_add_cylinder(root, 0.08, 0.05, Vector3.ZERO, &"accent", set_id, Vector3(0, 0, PI * 0.5))
		&"belt":
			_add_box(root, Vector3(0.70, 0.12, 0.34), Vector3.ZERO, &"leather", set_id)
			_add_box(root, Vector3(0.16, 0.16, 0.04), Vector3(0, 0, -0.20), &"accent", set_id)
		&"main_hand", &"off_hand":
			if item_id == &"sunforged_warhammer":
				_add_cylinder(root, 0.045, 0.82, Vector3(0, 0.34, 0), &"leather", set_id)
				_add_box(root, Vector3(0.42, 0.20, 0.22), Vector3(0, 0.77, 0), &"metal", set_id)
				_add_box(root, Vector3(0.12, 0.25, 0.13), Vector3(0, 0.77, 0), &"accent", set_id)
			elif item_id == &"dawn_bulwark_shield":
				_add_box(root, Vector3(0.68, 0.78, 0.12), Vector3(0, 0.18, 0.12), &"metal", set_id)
				_add_box(root, Vector3(0.12, 0.62, 0.15), Vector3(0, 0.18, 0.04), &"primary", set_id)
			else:
				_add_box(root, Vector3(0.10, 0.74, 0.06), Vector3(0, 0.34, 0), &"metal", set_id, Vector3(0, 0, -0.12 if side == "Right" else 0.12))
				_add_box(root, Vector3(0.26, 0.06, 0.12), Vector3(0, -0.04, 0), &"accent", set_id)

func _add_box(parent: Node3D, size: Vector3, position: Vector3, region: StringName, set_id: StringName, rotation := Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = size; mesh.mesh = box
	mesh.position = position; mesh.rotation = rotation
	_configure_mesh(mesh, region, set_id)
	parent.add_child(mesh)

func _add_cylinder(parent: Node3D, radius: float, height: float, position: Vector3, region: StringName, set_id: StringName, rotation := Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new(); cylinder.top_radius = radius; cylinder.bottom_radius = radius; cylinder.height = height; cylinder.radial_segments = 10; mesh.mesh = cylinder
	mesh.position = position; mesh.rotation = rotation
	_configure_mesh(mesh, region, set_id)
	parent.add_child(mesh)

func _configure_mesh(mesh: MeshInstance3D, region: StringName, set_id: StringName) -> void:
	mesh.set_meta(&"palette_region", region)
	var material := StandardMaterial3D.new()
	material.albedo_color = SET_STYLES[set_id].get(region, Color.WHITE)
	material.metallic = 0.72 if region == &"metal" else 0.05
	material.roughness = 0.42 if region == &"metal" else 0.78
	mesh.material_override = material

func _paired_socket(slot: StringName, side: String) -> String:
	match slot:
		&"legs": return "HitPivot/BodyPivot/HipsPivot/%sHipPivot" % side
		&"gloves": return "HitPivot/BodyPivot/HipsPivot/TorsoPivot/%sShoulderPivot/%sElbowPivot/%sHandSocket" % [side, side, side]
		&"boots": return "HitPivot/BodyPivot/HipsPivot/%sHipPivot/%sKneePivot/%sFootPivot" % [side, side, side]
	return String(SOCKETS[slot])

func _write_procedural_resources(set_id: StringName, item_id: StringName, slot: StringName, scene_path: String) -> bool:
	var folder := String(SET_FOLDERS[set_id])
	var visual_path := "res://data/presentation/equipment/%s/%s.tres" % [folder, item_id]
	var base_path := "res://data/equipment/bases/%s/%s.tres" % [folder, item_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(visual_path).get_base_dir()); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_path).get_base_dir())
	var supported := "[&\"ring_left\", &\"ring_right\"]" if slot in [&"ring_left", &"ring_right"] else "[&\"%s\"]" % slot
	var family := _weapon_family(item_id)
	var colors := SET_STYLES[set_id] as Dictionary
	var color_text := "{&\"primary\": %s, &\"metal\": %s, &\"leather\": %s, &\"accent\": %s}" % [_color_literal(colors[&"primary"]), _color_literal(colors[&"metal"]), _color_literal(colors[&"leather"]), _color_literal(colors[&"accent"])]
	var visual := "[gd_resource type=\"Resource\" script_class=\"EquipmentVisualDefinition\" load_steps=5 format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/presentation/equipment_visual_definition.gd\" id=\"1\"]\n[ext_resource type=\"PackedScene\" path=\"%s\" id=\"2\"]\n[ext_resource type=\"Texture2D\" path=\"res://assets/ui/equipment/master/%s/%s_256.png\" id=\"3\"]\n[ext_resource type=\"Texture2D\" path=\"res://assets/ui/equipment/runtime/%s/%s_128.png\" id=\"4\"]\n\n[resource]\nscript = ExtResource(\"1\")\nid = &\"%s\"\nslot_id = &\"%s\"\ngeometry_key = &\"%s\"\nvisual_channels = [&\"geometry\", &\"silhouette\"]\nsupported_slot_ids = %s\npresentation_scene = ExtResource(\"2\")\nicon_master = ExtResource(\"3\")\nicon_runtime = ExtResource(\"4\")\nsocket_id = &\"%s\"\nbody_preset_ids = [&\"masculine\", &\"feminine\"]\ncombat_visible = true\nitem_colors = %s\nwearer_accent_channel = &\"primary\"\nweapon_animation_family_id = &\"%s\"\nreadability_channels = [&\"silhouette\"]\n" % [scene_path, folder, item_id, folder, item_id, item_id, slot, item_id, supported, SOCKETS[slot], color_text, family]
	if not _write_text(visual_path, visual): return false
	var armour_slot := slot in [&"helmet", &"body_armour", &"legs", &"gloves", &"boots"]
	var weapon := slot in [&"main_hand", &"off_hand"]
	var tags := _required_tags(set_id, item_id, armour_slot)
	var base := "[gd_resource type=\"Resource\" script_class=\"EquipmentBaseDefinition\" load_steps=3 format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/equipment/equipment_base_definition.gd\" id=\"1\"]\n[ext_resource type=\"Resource\" path=\"%s\" id=\"2\"]\n\n[resource]\nscript = ExtResource(\"1\")\nid = &\"%s\"\ndisplay_name = \"%s\"\nitem_type_id = &\"%s\"\ncompatible_slot_ids = %s\nweight_class_id = &\"%s\"\nrequired_all_tags = %s\nhandedness_id = &\"%s\"\nweapon_family_id = &\"%s\"\nimplicit_family_id = &\"%s\"\npresentation = ExtResource(\"2\")\n" % [visual_path, item_id, String(item_id).replace("_", " ").capitalize(), _item_type(item_id, slot), supported, "weapon" if weapon else ("heavy" if set_id == &"paladin" and armour_slot else ("light" if armour_slot else "accessory")), _string_name_array(tags), "one_hand" if weapon else "none", family, folder]
	return _write_text(base_path, base)

func _weapon_family(item_id: StringName) -> StringName:
	if item_id == &"sunforged_warhammer": return &"one_hand_hammer"
	if item_id == &"dawn_bulwark_shield": return &"shield"
	if item_id in [&"nightstep_dagger_main", &"nightstep_dagger_off"]: return &"dual_daggers"
	return &""

func _item_type(item_id: StringName, slot: StringName) -> StringName:
	if item_id == &"sunforged_warhammer": return &"warhammer"
	if item_id == &"dawn_bulwark_shield": return &"shield"
	if item_id in [&"nightstep_dagger_main", &"nightstep_dagger_off"]: return &"dagger"
	if slot in [&"ring_left", &"ring_right"]: return &"ring"
	return slot

func _required_tags(set_id: StringName, item_id: StringName, armour_slot: bool) -> Array:
	if item_id == &"sunforged_warhammer": return [&"martial", &"one_hand_hammer"]
	if item_id == &"dawn_bulwark_shield": return [&"martial", &"shield"]
	if item_id in [&"nightstep_dagger_main", &"nightstep_dagger_off"]: return [&"dagger", &"dual_wield"]
	if armour_slot: return [&"martial", &"vanguard"] if set_id == &"paladin" else [&"martial", &"skirmisher"]
	return []

func _string_name_array(values: Array) -> String:
	var parts: PackedStringArray = []
	for value: Variant in values: parts.append("&\"%s\"" % StringName(value))
	return "[%s]" % ", ".join(parts)

func _color_literal(color: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [color.r, color.g, color.b, color.a]

func _write_catalog() -> bool:
	var paths: PackedStringArray = []
	for set_id: StringName in ClassEquipmentRows.SET_ITEM_IDS:
		if not SET_FOLDERS.has(set_id): continue
		var folder := String(SET_FOLDERS[set_id])
		for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
			var path := "res://data/equipment/bases/%s/%s.tres" % [folder, item_id]
			if FileAccess.file_exists(ProjectSettings.globalize_path(path)): paths.append(path)
	var refs := ""
	var values: PackedStringArray = []
	for index: int in paths.size():
		refs += "[ext_resource type=\"Resource\" path=\"%s\" id=\"%d\"]\n" % [paths[index], index + 2]
		values.append("ExtResource(\"%d\")" % (index + 2))
	var text := "[gd_resource type=\"Resource\" script_class=\"EquipmentCatalog\" load_steps=%d format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/equipment/equipment_catalog.gd\" id=\"1\"]\n%s\n[resource]\nscript = ExtResource(\"1\")\ndefinitions = [%s]\n" % [paths.size() + 2, refs, ", ".join(values)]
	return _write_text("res://data/equipment/core_equipment_catalog.tres", text)

func _write_item(id: StringName, slot: StringName) -> bool:
	var root := Node3D.new(); root.name = id
	var matches: Array[Node3D] = []
	var source_scene := load(SOURCE_PATH) as PackedScene
	var source := source_scene.instantiate() as Node3D if source_scene != null else null
	var item_source := source.get_node_or_null(NodePath(String(id))) as Node3D if source != null else null
	var expected_attachment_count := 2 if id in [&"forge_vanguard_gauntlets", &"forge_vanguard_boots"] else 1
	if item_source != null:
		for node: Node in item_source.get_children():
			if node is Node3D and StringName(node.get_meta(&"equipment_visual_id", &"")) == id:
				matches.append(node as Node3D)
				if matches.size() == expected_attachment_count:
					break
	_trace("matches_complete item=%s count=%d" % [id, matches.size()])
	if id == &"forge_vanguard_greaves": _add_greaves(root)
	else:
		for original: Node3D in matches:
			_trace("duplicate_begin item=%s node=%s" % [id, original.name])
			var attachment := original.duplicate() as Node3D
			_trace("duplicate_done item=%s node=%s" % [id, original.name])
			attachment.name = &"Attachment"
			# Hammer, amulet, and rings depart from hidden embedded alternatives so
			# modular runtime attachments and isolated icon capture remain visible.
			attachment.visible = original.visible or id in [&"forge_vanguard_hammer", &"forge_vanguard_amulet", &"forge_vanguard_ring_left", &"forge_vanguard_ring_right"]
			attachment.set_meta(&"equipment_socket_id", _attachment_socket(id, slot, source, original))
			_trace("meta_done item=%s node=%s" % [id, original.name])
			root.add_child(attachment)
			_trace("attach_done item=%s node=%s" % [id, original.name])
	if root.get_child_count() == 0: _fail("missing source geometry item=%s" % id); return false
	if source != null: source.free()
	_set_owners(root, root)
	var packed := PackedScene.new()
	var scene_path := "res://scenes/equipment/forge_vanguard/%s.tscn" % id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scene_path).get_base_dir())
	_trace("pack_begin item=%s" % id)
	if packed.pack(root) != OK: _fail("pack item=%s" % id); return false
	_trace("pack_done item=%s" % id)
	if ResourceSaver.save(packed, scene_path) != OK: _fail("scene save item=%s" % id); return false
	if not _remove_generated_node_ids(scene_path): _fail("scene stabilize item=%s" % id); return false
	_trace("scene_save_done item=%s" % id)
	root.free()
	var visual_path := "res://data/presentation/equipment/forge_vanguard/%s.tres" % id
	var base_path := "res://data/equipment/bases/forge_vanguard/%s.tres" % id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(visual_path).get_base_dir()); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_path).get_base_dir())
	var combat_visible := "false" if slot in [&"ring_left", &"ring_right"] else "true"
	var supported := "[&\"ring_left\", &\"ring_right\"]" if slot in [&"ring_left", &"ring_right"] else "[&\"%s\"]" % slot
	var colors := "{&\"primary\": Color(0.8509804, 0.30980393, 0.30980393, 1), &\"metal\": Color(0.1882353, 0.227451, 0.278431, 1), &\"leather\": Color(0.290196, 0.203922, 0.14902, 1), &\"brass\": Color(0.713725, 0.545098, 0.227451, 1)}"
	var visual_family := "one_hand_sword" if id == &"forge_vanguard_sword" else "sword_shield"
	var base_family := visual_family if slot in [&"main_hand", &"off_hand"] else ""
	var visual := "[gd_resource type=\"Resource\" script_class=\"EquipmentVisualDefinition\" load_steps=5 format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/presentation/equipment_visual_definition.gd\" id=\"1\"]\n[ext_resource type=\"PackedScene\" path=\"%s\" id=\"2\"]\n[ext_resource type=\"Texture2D\" path=\"res://assets/ui/equipment/master/forge_vanguard/%s_256.png\" id=\"3\"]\n[ext_resource type=\"Texture2D\" path=\"res://assets/ui/equipment/runtime/forge_vanguard/%s_128.png\" id=\"4\"]\n\n[resource]\nscript = ExtResource(\"1\")\nid = &\"%s\"\nslot_id = &\"%s\"\ngeometry_key = &\"%s\"\nvisual_channels = [&\"geometry\", &\"silhouette\"]\nsupported_slot_ids = %s\npresentation_scene = ExtResource(\"2\")\nicon_master = ExtResource(\"3\")\nicon_runtime = ExtResource(\"4\")\nsocket_id = &\"%s\"\nbody_preset_ids = [&\"masculine\", &\"feminine\"]\ncombat_visible = %s\nitem_colors = %s\nwearer_accent_channel = &\"primary\"\nweapon_animation_family_id = &\"%s\"\nreadability_channels = [&\"silhouette\"]\n" % [scene_path, id, id, id, slot, id, supported, SOCKETS[slot], combat_visible, colors, visual_family]
	_trace("visual_write_begin item=%s" % id)
	if not _write_text(visual_path, visual): _fail("visual write item=%s" % id); return false
	_trace("visual_write_done item=%s" % id)
	var item_type := "ring" if slot in [&"ring_left", &"ring_right"] else String(slot)
	var base := "[gd_resource type=\"Resource\" script_class=\"EquipmentBaseDefinition\" load_steps=3 format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/equipment/equipment_base_definition.gd\" id=\"1\"]\n[ext_resource type=\"Resource\" path=\"%s\" id=\"2\"]\n\n[resource]\nscript = ExtResource(\"1\")\nid = &\"%s\"\ndisplay_name = \"%s\"\nitem_type_id = &\"%s\"\ncompatible_slot_ids = %s\nweight_class_id = &\"%s\"\nhandedness_id = &\"%s\"\nweapon_family_id = &\"%s\"\nimplicit_family_id = &\"forge_vanguard\"\npresentation = ExtResource(\"2\")\n" % [visual_path, id, String(id).replace("_", " ").capitalize(), item_type, supported, "weapon" if slot in [&"main_hand", &"off_hand"] else "accessory", "one_hand" if slot in [&"main_hand", &"off_hand"] else "none", base_family]
	_trace("base_write_begin item=%s" % id)
	if not _write_text(base_path, base): _fail("base write item=%s" % id); return false
	_trace("base_write_done item=%s" % id)
	return true

func _attachment_socket(item_id: StringName, slot: StringName, source: Node3D, original: Node3D) -> String:
	# Gloves, boots, and greaves deliberately retain their animated left/right limb
	# sockets. Every single-root item instead uses its visual definition socket.
	if item_id in [&"forge_vanguard_gauntlets", &"forge_vanguard_boots"]:
		return String(original.get_meta(&"equipment_socket_id", source.get_path_to(original.get_parent())))
	return String(SOCKETS[slot])

func _add_greaves(root: Node3D) -> void:
	for side: String in ["Left", "Right"]:
		var attachment := Node3D.new(); attachment.name = &"Attachment"; attachment.set_meta(&"equipment_socket_id", "HitPivot/BodyPivot/HipsPivot/%sHipPivot" % side); attachment.position = Vector3(0, -0.28, 0)
		var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(0.24, 0.42, 0.24); mesh.mesh = box; mesh.set_meta(&"palette_region", &"metal"); var material := StandardMaterial3D.new(); material.albedo_color = Color("303a47"); material.metallic = 0.7; material.roughness = 0.78; mesh.material_override = material; attachment.add_child(mesh); root.add_child(attachment)

func _write_profiles() -> bool:
	var base_dir := "res://data/equipment/bases/forge_vanguard/"
	var refs := ""; for index: int in IDS.size(): refs += "[ext_resource type=\"Resource\" path=\"%s%s.tres\" id=\"%d\"]\n" % [base_dir, IDS[index], index + 3]
	var entries := ""; for index: int in 11: entries += "SubResource(\"Entry%d\"), " % index
	var subresources := ""; for index: int in 11: subresources += "[sub_resource type=\"Resource\" id=\"Entry%d\"]\nscript = ExtResource(\"2\")\nslot_id = &\"%s\"\nitem = ExtResource(\"%d\")\n\n" % [index, ClassEquipmentRows.slot_for(&"fighter", index), index + 3]
	var available := ""; for index: int in IDS.size(): available += "ExtResource(\"%d\"), " % (index + 3)
	var common := "[gd_resource type=\"Resource\" script_class=\"CharacterVisualProfile\" load_steps=16 format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/presentation/character_visual_profile.gd\" id=\"1\"]\n[ext_resource type=\"Script\" path=\"res://scripts/equipment/equipment_loadout_entry.gd\" id=\"2\"]\n[ext_resource type=\"PackedScene\" path=\"res://scenes/characters/presentation/forge_humanoid_model.tscn\" id=\"20\"]\n%s[ext_resource type=\"Resource\" path=\"res://data/presentation/attacks/fighter_cleave.tres\" id=\"15\"]\n\n%s[resource]\nscript = ExtResource(\"1\")\nid = &\"forge_vanguard\"\npresentation_scene = ExtResource(\"20\")\ndefault_body_preset = &\"masculine\"\ndefault_palette_id = &\"red\"\npalette_colors = {&\"red\": Color(0.8509804, 0.30980393, 0.30980393, 1), &\"blue\": Color(0.30980393, 0.47058824, 0.8509804, 1), &\"green\": Color(0.30980393, 0.6862745, 0.44705883, 1)}\ndefault_equipment = [%s]\navailable_equipment = [%s]\nidle_action_id = &\"idle\"\nwalk_action_id = &\"walk\"\nrequired_animation_names = [&\"idle\", &\"walk\", &\"attack_slash\", &\"attack_combo\", &\"hit_flinch\"]\nattack_animation_by_id = {&\"fighter_cleave\": &\"attack_slash\"}\nattack_presentations = [ExtResource(\"15\")]\n" % [refs, subresources, entries.trim_suffix(", "), available.trim_suffix(", ")]
	if not _write_text("res://data/presentation/profiles/forge_vanguard.tres", common): return false
	for preset: StringName in [&"masculine", &"feminine"]:
		var text := common.replace("id = &\"forge_vanguard\"", "id = &\"forge_base_%s\"" % preset).replace("default_body_preset = &\"masculine\"", "default_body_preset = &\"%s\"" % preset).replace("default_equipment = [%s]" % entries.trim_suffix(", "), "default_equipment = []")
		text = text.replace("load_steps=16", "load_steps=15").replace("[ext_resource type=\"Resource\" path=\"res://data/presentation/attacks/fighter_cleave.tres\" id=\"15\"]\n", "").replace("attack_presentations = [ExtResource(\"15\")]\n", "")
		if not _write_text("res://data/presentation/profiles/forge_base_%s.tres" % preset, text): return false
	return true

func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return file.get_error() == OK

func _remove_generated_node_ids(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var expression := RegEx.new()
	if expression.compile(" unique_id=[0-9]+") != OK: return false
	var stable := expression.sub(file.get_as_text(), "", true)
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(stable)
	return file.get_error() == OK

func _set_owners(node: Node, root: Node) -> void: for child: Node in node.get_children(): child.owner = root; _set_owners(child, root)
func _fail(reason: String) -> void: push_error("EQUIPMENT_ASSET_BUILD_ERROR reason=%s" % reason); quit(1)
func _trace(message: String) -> void:
	print("EQUIPMENT_ASSET_TRACE %s" % message)
