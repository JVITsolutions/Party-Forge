extends SceneTree

const SOURCE_PATH := "res://scenes/characters/presentation/forge_vanguard_model.tscn"
const IDS: Array[StringName] = [&"forge_vanguard_helmet", &"forge_vanguard_armour", &"forge_vanguard_greaves", &"forge_vanguard_gauntlets", &"forge_vanguard_boots", &"forge_vanguard_amulet", &"forge_vanguard_ring_left", &"forge_vanguard_ring_right", &"forge_vanguard_belt", &"forge_vanguard_sword", &"forge_vanguard_shield", &"forge_vanguard_hammer"]
const SLOTS: Array[StringName] = [&"helmet", &"body_armour", &"legs", &"gloves", &"boots", &"amulet", &"ring_left", &"ring_right", &"belt", &"main_hand", &"off_hand", &"main_hand"]
const SOCKETS := {&"helmet": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/HeadPivot/HelmetSocket", &"body_armour": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/BodyArmourSocket", &"legs": "HitPivot/BodyPivot/HipsPivot/LegsSocket", &"gloves": "HitPivot/BodyPivot/HipsPivot/GlovesSocket", &"boots": "HitPivot/BodyPivot/HipsPivot/BootsSocket", &"amulet": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/AmuletSocket", &"belt": "HitPivot/BodyPivot/HipsPivot/BeltSocket", &"ring_left": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket", &"ring_right": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket", &"main_hand": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket", &"off_hand": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket"}

func _initialize() -> void:
	_trace("initialize_entry")
	var requested_sets := _sets()
	_trace("sets_return=%s" % requested_sets)
	if &"fighter" not in requested_sets: _fail("fighter set was not requested"); return
	var source_scene := load(SOURCE_PATH) as PackedScene
	_trace("source_load=%s" % (source_scene != null))
	var source := source_scene.instantiate() as Node3D if source_scene != null else null
	_trace("source_instantiate=%s" % (source != null))
	if source == null: _fail("source instantiate failed"); return
	for index: int in IDS.size():
		_trace("item_begin=%s" % IDS[index])
		if not _write_item(source, IDS[index], SLOTS[index]): source.free(); return
	source.free()
	_trace("profile_write_begin")
	_write_profiles()
	_trace("profile_write_done")
	print("EQUIPMENT_ASSET_BUILD_OK sets=1 items=12")
	quit(0)

func _sets() -> Array[StringName]:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sets="):
			var result: Array[StringName] = []
			for set_id: String in arg.trim_prefix("--sets=").split(","):
				result.append(StringName(set_id))
			return result
	return [&"fighter"]

func _write_item(source: Node3D, id: StringName, slot: StringName) -> bool:
	var root := Node3D.new(); root.name = id
	var matches: Array[Node3D] = []
	for node: Node in source.find_children("*", "Node3D", true, false):
		if StringName(node.get_meta(&"equipment_visual_id", &"")) == id: matches.append(node as Node3D)
	_trace("matches_complete item=%s count=%d" % [id, matches.size()])
	if id == &"forge_vanguard_greaves": _add_greaves(root)
	else:
		for original: Node3D in matches:
			_trace("duplicate_begin item=%s node=%s" % [id, original.name])
			var attachment := original.duplicate() as Node3D
			_trace("duplicate_done item=%s node=%s" % [id, original.name])
			attachment.name = &"Attachment"
			attachment.set_meta(&"equipment_socket_id", String(source.get_path_to(original.get_parent())))
			_trace("meta_done item=%s node=%s" % [id, original.name])
			root.add_child(attachment)
			_trace("attach_done item=%s node=%s" % [id, original.name])
	if root.get_child_count() == 0: _fail("missing source geometry item=%s" % id); return false
	_set_owners(root, root)
	var packed := PackedScene.new()
	var scene_path := "res://scenes/equipment/forge_vanguard/%s.tscn" % id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scene_path).get_base_dir())
	_trace("pack_begin item=%s" % id)
	if packed.pack(root) != OK: _fail("pack item=%s" % id); return false
	_trace("pack_done item=%s" % id)
	if ResourceSaver.save(packed, scene_path) != OK: _fail("scene save item=%s" % id); return false
	_trace("scene_save_done item=%s" % id)
	root.free()
	var visual_path := "res://data/presentation/equipment/forge_vanguard/%s.tres" % id
	var base_path := "res://data/equipment/bases/forge_vanguard/%s.tres" % id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(visual_path).get_base_dir()); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_path).get_base_dir())
	var combat_visible := "false" if slot in [&"ring_left", &"ring_right"] else "true"
	var supported := "[&\"ring_left\", &\"ring_right\"]" if slot in [&"ring_left", &"ring_right"] else "[&\"%s\"]" % slot
	var colors := "{&\"primary\": Color(0.8509804, 0.30980393, 0.30980393, 1), &\"metal\": Color(0.1882353, 0.227451, 0.278431, 1), &\"leather\": Color(0.290196, 0.203922, 0.14902, 1), &\"brass\": Color(0.713725, 0.545098, 0.227451, 1)}"
	var visual := "[gd_resource type=\"Resource\" script_class=\"EquipmentVisualDefinition\" load_steps=5 format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/presentation/equipment_visual_definition.gd\" id=\"1\"]\n[ext_resource type=\"PackedScene\" path=\"%s\" id=\"2\"]\n[ext_resource type=\"Texture2D\" path=\"res://assets/ui/equipment/master/forge_vanguard/%s_256.png\" id=\"3\"]\n[ext_resource type=\"Texture2D\" path=\"res://assets/ui/equipment/runtime/forge_vanguard/%s_128.png\" id=\"4\"]\n\n[resource]\nscript = ExtResource(\"1\")\nid = &\"%s\"\nslot_id = &\"%s\"\ngeometry_key = &\"%s\"\nvisual_channels = [&\"geometry\", &\"silhouette\"]\nsupported_slot_ids = %s\npresentation_scene = ExtResource(\"2\")\nicon_master = ExtResource(\"3\")\nicon_runtime = ExtResource(\"4\")\nsocket_id = &\"%s\"\nbody_preset_ids = [&\"masculine\", &\"feminine\"]\ncombat_visible = %s\nitem_colors = %s\nwearer_accent_channel = &\"primary\"\nweapon_animation_family_id = &\"sword_shield\"\nreadability_channels = [&\"silhouette\"]\n" % [scene_path, id, id, id, slot, id, supported, SOCKETS[slot], combat_visible, colors]
	_trace("visual_write_begin item=%s" % id)
	FileAccess.open(ProjectSettings.globalize_path(visual_path), FileAccess.WRITE).store_string(visual)
	_trace("visual_write_done item=%s" % id)
	var item_type := "ring" if slot in [&"ring_left", &"ring_right"] else String(slot)
	var base := "[gd_resource type=\"Resource\" script_class=\"EquipmentBaseDefinition\" load_steps=3 format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/equipment/equipment_base_definition.gd\" id=\"1\"]\n[ext_resource type=\"Resource\" path=\"%s\" id=\"2\"]\n\n[resource]\nscript = ExtResource(\"1\")\nid = &\"%s\"\ndisplay_name = \"%s\"\nitem_type_id = &\"%s\"\ncompatible_slot_ids = %s\nweight_class_id = &\"%s\"\nhandedness_id = &\"%s\"\nweapon_family_id = &\"%s\"\nimplicit_family_id = &\"forge_vanguard\"\npresentation = ExtResource(\"2\")\n" % [visual_path, id, String(id).replace("_", " ").capitalize(), item_type, supported, "weapon" if slot in [&"main_hand", &"off_hand"] else "accessory", "one_hand" if slot in [&"main_hand", &"off_hand"] else "none", "sword_shield" if slot in [&"main_hand", &"off_hand"] else ""]
	_trace("base_write_begin item=%s" % id)
	FileAccess.open(ProjectSettings.globalize_path(base_path), FileAccess.WRITE).store_string(base)
	_trace("base_write_done item=%s" % id)
	return true

func _add_greaves(root: Node3D) -> void:
	for side: String in ["Left", "Right"]:
		var attachment := Node3D.new(); attachment.name = &"Attachment"; attachment.set_meta(&"equipment_socket_id", "HitPivot/BodyPivot/HipsPivot/%sHipPivot" % side); attachment.position = Vector3(0, -0.28, 0)
		var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(0.24, 0.42, 0.24); mesh.mesh = box; mesh.set_meta(&"palette_region", &"metal"); var material := StandardMaterial3D.new(); material.albedo_color = Color("303a47"); material.metallic = 0.7; material.roughness = 0.78; mesh.material_override = material; attachment.add_child(mesh); root.add_child(attachment)

func _write_profiles() -> void:
	var base_dir := "res://data/equipment/bases/forge_vanguard/"
	var refs := ""; for index: int in IDS.size(): refs += "[ext_resource type=\"Resource\" path=\"%s%s.tres\" id=\"%d\"]\n" % [base_dir, IDS[index], index + 3]
	var entries := ""; for index: int in 11: entries += "SubResource(\"Entry%d\"), " % index
	var subresources := ""; for index: int in 11: subresources += "[sub_resource type=\"Resource\" id=\"Entry%d\"]\nscript = ExtResource(\"2\")\nslot_id = &\"%s\"\nitem = ExtResource(\"%d\")\n\n" % [index, SLOTS[index], index + 3]
	var available := ""; for index: int in IDS.size(): available += "ExtResource(\"%d\"), " % (index + 3)
	var common := "[gd_resource type=\"Resource\" script_class=\"CharacterVisualProfile\" load_steps=15 format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/presentation/character_visual_profile.gd\" id=\"1\"]\n[ext_resource type=\"Script\" path=\"res://scripts/equipment/equipment_loadout_entry.gd\" id=\"2\"]\n[ext_resource type=\"PackedScene\" path=\"res://scenes/characters/presentation/forge_humanoid_model.tscn\" id=\"20\"]\n%s\n%s[resource]\nscript = ExtResource(\"1\")\nid = &\"forge_vanguard\"\npresentation_scene = ExtResource(\"20\")\ndefault_body_preset = &\"masculine\"\ndefault_palette_id = &\"red\"\npalette_colors = {&\"red\": Color(0.8509804, 0.30980393, 0.30980393, 1), &\"blue\": Color(0.30980393, 0.47058824, 0.8509804, 1), &\"green\": Color(0.30980393, 0.6862745, 0.44705883, 1)}\ndefault_equipment = [%s]\navailable_equipment = [%s]\nrequired_animation_names = [&\"idle\", &\"attack_slash\", &\"attack_combo\", &\"hit_flinch\"]\nattack_animation_by_id = {&\"fighter_cleave\": &\"attack_slash\"}\n" % [refs, subresources, entries.trim_suffix(", "), available.trim_suffix(", ")]
	FileAccess.open(ProjectSettings.globalize_path("res://data/presentation/profiles/forge_vanguard.tres"), FileAccess.WRITE).store_string(common)
	for preset: StringName in [&"masculine", &"feminine"]:
		var text := common.replace("id = &\"forge_vanguard\"", "id = &\"forge_base_%s\"" % preset).replace("default_body_preset = &\"masculine\"", "default_body_preset = &\"%s\"" % preset).replace("default_equipment = [%s]" % entries.trim_suffix(", "), "default_equipment = []")
		FileAccess.open(ProjectSettings.globalize_path("res://data/presentation/profiles/forge_base_%s.tres" % preset), FileAccess.WRITE).store_string(text)

func _set_owners(node: Node, root: Node) -> void: for child: Node in node.get_children(): child.owner = root; _set_owners(child, root)
func _fail(reason: String) -> void: push_error("EQUIPMENT_ASSET_BUILD_ERROR reason=%s" % reason); quit(1)
func _trace(message: String) -> void:
	print("EQUIPMENT_ASSET_TRACE %s" % message)
