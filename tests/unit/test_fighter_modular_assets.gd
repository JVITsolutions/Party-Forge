extends RefCounted

const EXPECTED_SLOTS: Array[StringName] = [
	&"helmet", &"body_armour", &"legs", &"gloves", &"boots", &"amulet",
	&"ring_left", &"ring_right", &"belt", &"main_hand", &"off_hand",
]
const FIGHTER_IDS: Array[StringName] = [
	&"forge_vanguard_helmet", &"forge_vanguard_armour", &"forge_vanguard_greaves",
	&"forge_vanguard_gauntlets", &"forge_vanguard_boots", &"forge_vanguard_amulet",
	&"forge_vanguard_ring_left", &"forge_vanguard_ring_right", &"forge_vanguard_belt",
	&"forge_vanguard_sword", &"forge_vanguard_shield", &"forge_vanguard_hammer",
]
const SOURCE_GEOMETRY := {
	&"forge_vanguard_helmet": [{&"socket": "HelmetSocket", &"position": Vector3.ZERO, &"size": Vector3(0.38, 0.34, 0.34), &"region": &"metal"}],
	&"forge_vanguard_armour": [{&"socket": "BodyArmourSocket", &"position": Vector3(0, 0.06, 0), &"size": Vector3(0.76, 0.56, 0.36), &"region": &"primary"}],
	&"forge_vanguard_greaves": [{&"socket": "LeftHipPivot", &"position": Vector3(0, -0.28, 0), &"size": Vector3(0.24, 0.42, 0.24), &"region": &"metal"}, {&"socket": "RightHipPivot", &"position": Vector3(0, -0.28, 0), &"size": Vector3(0.24, 0.42, 0.24), &"region": &"metal"}],
	&"forge_vanguard_gauntlets": [{&"socket": "LeftHandSocket", &"position": Vector3(-0.02, -0.20, 0), &"size": Vector3(0.16, 0.17, 0.16), &"region": &"primary"}, {&"socket": "RightHandSocket", &"position": Vector3(0.02, -0.20, 0), &"size": Vector3(0.16, 0.17, 0.16), &"region": &"primary"}],
	&"forge_vanguard_boots": [{&"socket": "LeftFootPivot", &"position": Vector3(-0.01, 0.05, 0), &"size": Vector3(0.23, 0.18, 0.34), &"region": &"primary"}, {&"socket": "RightFootPivot", &"position": Vector3(0.01, 0.05, 0), &"size": Vector3(0.23, 0.18, 0.34), &"region": &"primary"}],
	&"forge_vanguard_amulet": [{&"socket": "AmuletSocket", &"position": Vector3(0, 0.20, -0.2), &"size": Vector3(0.10, 0.10, 0.04), &"region": &"brass", &"emits": true}],
	&"forge_vanguard_ring_left": [{&"socket": "LeftHandSocket", &"position": Vector3(-0.03, -0.24, 0), &"size": Vector3(0.07, 0.07, 0.07), &"region": &"brass", &"emits": true}],
	&"forge_vanguard_ring_right": [{&"socket": "RightHandSocket", &"position": Vector3(0.03, -0.24, 0), &"size": Vector3(0.07, 0.07, 0.07), &"region": &"brass", &"emits": true}],
	&"forge_vanguard_belt": [{&"socket": "BeltSocket", &"position": Vector3(0, -0.04, 0), &"size": Vector3(0.58, 0.11, 0.32), &"region": &"leather"}],
	&"forge_vanguard_sword": [{&"socket": "RightHandSocket", &"position": Vector3(0.03, -0.12, -0.10), &"size": Vector3(0.10, 0.68, 0.035), &"region": &"metal"}],
	&"forge_vanguard_shield": [{&"socket": "LeftHandSocket", &"position": Vector3(-0.10, -0.38, -0.20), &"size": Vector3(0.68, 0.68, 0.14), &"region": &"metal"}],
	&"forge_vanguard_hammer": [{&"socket": "RightHandSocket", &"position": Vector3(0.03, -0.48, -0.10), &"size": Vector3(0.09, 0.92, 0.07), &"region": &"metal"}],
}

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.equal(EquipmentSlotCatalog.SLOT_IDS, EXPECTED_SLOTS, "PoE 1 sheet slot order", failures)
	var profile := load("res://data/presentation/profiles/forge_vanguard.tres") as CharacterVisualProfile
	TestAssertions.truthy(profile != null, "Fighter profile loads", failures)
	if profile == null:
		return failures
	TestAssertions.equal(profile.default_equipment.size(), 11, "Fighter default sheet has eleven items", failures)
	if profile.default_equipment.size() == 11:
		TestAssertions.equal(profile.default_equipment[9].item.id, &"forge_vanguard_sword", "sword remains default", failures)
		TestAssertions.equal(profile.default_equipment[10].item.id, &"forge_vanguard_shield", "shield remains default", failures)
	TestAssertions.equal(profile.available_equipment.size(), 12, "hammer remains an alternative", failures)
	for item_id: StringName in FIGHTER_IDS:
		var base_path := "res://data/equipment/bases/forge_vanguard/%s.tres" % item_id
		var visual_path := "res://data/presentation/equipment/forge_vanguard/%s.tres" % item_id
		var scene_path := "res://scenes/equipment/forge_vanguard/%s.tscn" % item_id
		TestAssertions.truthy(ResourceLoader.exists(base_path), "%s base exists" % item_id, failures)
		TestAssertions.truthy(ResourceLoader.exists(visual_path), "%s visual exists" % item_id, failures)
		TestAssertions.truthy(ResourceLoader.exists(scene_path), "%s independent scene exists" % item_id, failures)
	for item: EquipmentBaseDefinition in profile.available_equipment:
		var visual := item.presentation if item != null else null
		if visual == null or not visual.has_method(&"presentation_scene_for"):
			TestAssertions.truthy(false, "%s resolves its independent scene through the body-fit API" % (item.id if item != null else &"<null>"), failures)
			continue
		TestAssertions.truthy(visual.presentation_scene_for(&"masculine") != null, "%s has an independent masculine scene" % item.id, failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scenes/characters/presentation/forge_humanoid_model.tscn"), "shared humanoid exists", failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scenes/characters/presentation/forge_vanguard_equipment_source.tscn"), "Fighter equipment source exists independently of generated item scenes", failures)
	var builder_source := FileAccess.get_file_as_string("res://tools/build_equipment_assets.gd")
	TestAssertions.truthy(builder_source.contains("forge_vanguard_equipment_source.tscn"), "equipment builder reads the dedicated baked source instead of target item scenes", failures)
	_assert_standalone_equipment_source(failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scenes/characters/presentation/forge_base_masculine.tscn"), "masculine base exists", failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scenes/characters/presentation/forge_base_feminine.tscn"), "feminine base exists", failures)
	_assert_profiles_share_walk_contract(failures)
	_assert_fail_closed_nude_models(profile, failures)
	_assert_profile_starts_guard_idle(profile, failures)
	_assert_runtime_visibility_and_socket_contract(profile, failures)
	return failures

func _assert_profiles_share_walk_contract(failures: Array[String]) -> void:
	for profile_path: String in [
		"res://data/presentation/profiles/forge_vanguard.tres",
		"res://data/presentation/profiles/forge_base_masculine.tres",
		"res://data/presentation/profiles/forge_base_feminine.tres",
	]:
		var profile := load(profile_path) as CharacterVisualProfile
		TestAssertions.truthy(profile != null, "%s loads for walk contract" % profile_path, failures)
		if profile != null:
			TestAssertions.equal(profile.get(&"walk_action_id"), &"walk", "%s uses shared walk action" % profile_path, failures)

func _assert_standalone_equipment_source(failures: Array[String]) -> void:
	var source_path := "res://scenes/characters/presentation/forge_vanguard_equipment_source.tscn"
	var serialized := FileAccess.get_file_as_string(source_path)
	TestAssertions.truthy(not serialized.contains("res://scenes/equipment/forge_vanguard/"), "equipment source has no generated target-scene references", failures)
	var source_scene := load(source_path) as PackedScene
	var source := source_scene.instantiate() as Node3D if source_scene != null else null
	TestAssertions.truthy(source != null, "standalone equipment source instantiates", failures)
	if source == null:
		return
	for item_id: StringName in FIGHTER_IDS:
		var item := source.get_node_or_null(NodePath(String(item_id))) as Node3D
		TestAssertions.truthy(item != null, "%s exists in standalone equipment source" % item_id, failures)
		if item != null:
			TestAssertions.truthy(not item.get_children().is_empty(), "%s source includes low-poly geometry" % item_id, failures)
			_assert_source_geometry(item, SOURCE_GEOMETRY[item_id] as Array, failures)
	_assert_sword_signature(source, failures)
	_assert_armour_signature(source, failures)
	source.free()

func _assert_source_geometry(item: Node3D, expected_attachments: Array, failures: Array[String]) -> void:
	var attachments: Array[Node3D] = []
	for child: Node in item.get_children():
		if child is Node3D:
			attachments.append(child as Node3D)
	TestAssertions.equal(attachments.size(), expected_attachments.size(), "%s source attachment count is pinned" % item.name, failures)
	for index: int in mini(attachments.size(), expected_attachments.size()):
		var attachment := attachments[index]
		var expected := expected_attachments[index] as Dictionary
		TestAssertions.equal(attachment.name, _expected_source_attachment_name(StringName(item.name), index), "%s attachment %d node name is pinned" % [item.name, index], failures)
		TestAssertions.truthy(String(attachment.get_meta(&"equipment_socket_id", "")).ends_with(String(expected[&"socket"])), "%s attachment %d socket tag is pinned" % [item.name, index], failures)
		TestAssertions.equal(attachment.position, expected[&"position"], "%s attachment %d position is pinned" % [item.name, index], failures)
		var mesh := attachment.get_node_or_null("ReadableChannel") as MeshInstance3D
		if mesh == null:
			mesh = attachment.get_node_or_null("Blade") as MeshInstance3D
		TestAssertions.truthy(mesh != null and mesh.mesh is BoxMesh, "%s attachment %d has pinned box mesh node" % [item.name, index], failures)
		if mesh == null or not mesh.mesh is BoxMesh:
			continue
		TestAssertions.equal((mesh.mesh as BoxMesh).size, expected[&"size"], "%s attachment %d box dimensions are pinned" % [item.name, index], failures)
		TestAssertions.equal(StringName(mesh.get_meta(&"palette_region", &"")), expected[&"region"], "%s attachment %d palette region is pinned" % [item.name, index], failures)
		var material := mesh.material_override as StandardMaterial3D
		TestAssertions.truthy(material != null and is_equal_approx(material.roughness, 0.78), "%s attachment %d material roughness is pinned" % [item.name, index], failures)
		if material != null:
			var region := expected[&"region"] as StringName
			TestAssertions.truthy(material.albedo_color.is_equal_approx(_region_color(region)), "%s attachment %d material color is pinned" % [item.name, index], failures)
			TestAssertions.near(material.metallic, _region_metallic(region), 0.0001, "%s attachment %d material metallic is pinned" % [item.name, index], failures)
		if bool(expected.get(&"emits", false)):
			TestAssertions.truthy(material != null and material.emission_enabled and material.emission.is_equal_approx(Color("ffd27a")), "%s attachment %d emission is pinned" % [item.name, index], failures)

func _assert_sword_signature(source: Node3D, failures: Array[String]) -> void:
	var sword := source.get_node_or_null("forge_vanguard_sword") as Node3D
	if sword == null or sword.get_child_count() == 0:
		return
	var attachment := sword.get_child(0) as Node3D
	for node_name: StringName in [&"Blade", &"Tip", &"Crossguard", &"Grip", &"Pommel"]:
		TestAssertions.truthy(attachment.get_node_or_null(NodePath(String(node_name))) != null, "sword retains %s geometry node" % node_name, failures)
	var tip_mesh := attachment.get_node_or_null("Tip") as MeshInstance3D
	TestAssertions.truthy(tip_mesh != null and tip_mesh.mesh is CylinderMesh, "sword tip remains a four-sided cylinder", failures)
	if tip_mesh != null and tip_mesh.mesh is CylinderMesh:
		var tip := tip_mesh.mesh as CylinderMesh
		TestAssertions.near(tip.top_radius, 0.0, 0.0001, "sword tip top radius", failures)
		TestAssertions.near(tip.bottom_radius, 0.065, 0.0001, "sword tip bottom radius", failures)
		TestAssertions.near(tip.height, 0.16, 0.0001, "sword tip height", failures)
		TestAssertions.equal(tip.radial_segments, 4, "sword tip radial segments", failures)

func _assert_armour_signature(source: Node3D, failures: Array[String]) -> void:
	var armour := source.get_node_or_null("forge_vanguard_armour") as Node3D
	if armour == null or armour.get_child_count() == 0:
		return
	var attachment := armour.get_child(0) as Node3D
	for expected: Dictionary in [{&"name": &"LeftShoulderPlate", &"position": Vector3(-0.42, 0.24, 0)}, {&"name": &"RightShoulderPlate", &"position": Vector3(0.42, 0.24, 0)}]:
		var mesh := attachment.get_node_or_null(NodePath(String(expected[&"name"]))) as MeshInstance3D
		TestAssertions.truthy(mesh != null and mesh.mesh is BoxMesh, "armour retains %s box mesh" % expected[&"name"], failures)
		if mesh != null and mesh.mesh is BoxMesh:
			TestAssertions.equal(mesh.position, expected[&"position"], "armour %s position is pinned" % expected[&"name"], failures)
			TestAssertions.equal((mesh.mesh as BoxMesh).size, Vector3(0.12, 0.20, 0.38), "armour %s dimensions are pinned" % expected[&"name"], failures)
			TestAssertions.equal(StringName(mesh.get_meta(&"palette_region", &"")), &"metal", "armour %s palette region is pinned" % expected[&"name"], failures)

func _expected_source_attachment_name(item_id: StringName, index: int) -> StringName:
	match item_id:
		&"forge_vanguard_helmet": return &"HelmetVisual"
		&"forge_vanguard_armour": return &"BodyArmourVisual"
		&"forge_vanguard_greaves": return &"LeftGreavesVisual" if index == 0 else &"RightGreavesVisual"
		&"forge_vanguard_gauntlets": return &"LeftGlovesVisual" if index == 0 else &"RightGlovesVisual"
		&"forge_vanguard_boots": return &"LeftBootsVisual" if index == 0 else &"RightBootsVisual"
		&"forge_vanguard_amulet": return &"AmuletVisual"
		&"forge_vanguard_ring_left": return &"RingLeftVisual"
		&"forge_vanguard_ring_right": return &"RingRightVisual"
		&"forge_vanguard_belt": return &"BeltVisual"
		&"forge_vanguard_sword": return &"SwordVisual"
		&"forge_vanguard_shield": return &"OffHandVisual"
		&"forge_vanguard_hammer": return &"HammerVisual"
	return &""

func _region_color(region: StringName) -> Color:
	match region:
		&"primary": return Color("d94f4f")
		&"metal": return Color("303a47")
		&"brass": return Color("b68b3a")
		&"leather": return Color("4a3426")
	return Color("d8a47f")

func _region_metallic(region: StringName) -> float:
	if region == &"metal": return 0.7
	if region == &"brass": return 0.55
	return 0.0

func _assert_runtime_visibility_and_socket_contract(profile: CharacterVisualProfile, failures: Array[String]) -> void:
	var model := profile.presentation_scene.instantiate() as ForgeHumanoidModel
	TestAssertions.truthy(model != null, "shared model instantiates for runtime equipment visibility", failures)
	if model == null:
		return
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		TestAssertions.truthy(model.has_equipment_slot(slot_id), "canonical slot %s resolves to an actual socket" % slot_id, failures)
	for item: EquipmentBaseDefinition in profile.available_equipment:
		var visual := item.presentation if item != null else null
		if visual == null or not visual.combat_visible:
			continue
		TestAssertions.truthy(model.apply_equipment_visual(visual.slot_id, visual), "%s applies for runtime visibility" % visual.id, failures)
		var installed: Array = model.equipped_nodes.get(visual.slot_id, [])
		TestAssertions.truthy(not installed.is_empty(), "%s creates an installed attachment" % visual.id, failures)
		for attachment: Node3D in installed:
			TestAssertions.truthy(attachment.visible and _has_effectively_visible_mesh(attachment), "%s runtime attachment has visible mesh geometry" % visual.id, failures)
			var socket_id := StringName(attachment.get_meta(&"equipment_socket_id", visual.socket_id))
			TestAssertions.truthy(model.get_node_or_null(NodePath(String(socket_id))) != null, "%s attachment targets an existing socket" % visual.id, failures)
		if visual.id in [&"forge_vanguard_helmet", &"forge_vanguard_armour", &"forge_vanguard_amulet", &"forge_vanguard_belt", &"forge_vanguard_sword", &"forge_vanguard_shield", &"forge_vanguard_hammer"]:
			for attachment: Node3D in installed:
				TestAssertions.equal(StringName(attachment.get_meta(&"equipment_socket_id", &"")), visual.socket_id, "%s single-root scene declares its visual socket exactly" % visual.id, failures)
		if visual.id in [&"forge_vanguard_gauntlets", &"forge_vanguard_boots", &"forge_vanguard_greaves"]:
			TestAssertions.truthy(installed.size() == 2, "%s keeps paired animated limb attachments" % visual.id, failures)
	model.clear_equipment_visual(&"main_hand")
	model.clear_equipment_visual(&"off_hand")
	model.free()

func _has_effectively_visible_mesh(root_node: Node3D) -> bool:
	for node: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).visible:
			return true
	return false

func _assert_profile_starts_guard_idle(profile: CharacterVisualProfile, failures: Array[String]) -> void:
	var presentation := CharacterPresentation.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(presentation)
	TestAssertions.truthy(presentation.apply_profile(profile, Color("d94f4f")), "applying Fighter profile succeeds", failures)
	var player := presentation.active_model.get_node_or_null("AnimationPlayer") as AnimationPlayer if presentation.active_model != null else null
	TestAssertions.truthy(player != null and player.current_animation == &"idle" and player.is_playing(), "Fighter profile starts looping idle", failures)
	if player != null and player.has_animation(&"idle"):
		var idle := player.get_animation(&"idle")
		TestAssertions.equal(idle.loop_mode, Animation.LOOP_LINEAR, "Fighter idle loops", failures)
		var non_neutral := 0
		for pivot_path: String in [
			"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot",
			"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot",
			"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot",
			"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot",
		]:
			var track := idle.find_track(NodePath("%s:rotation" % pivot_path), Animation.TYPE_ROTATION_3D)
			TestAssertions.truthy(track >= 0, "guard idle contains %s rotation track" % pivot_path, failures)
			if track >= 0:
				var rotation := idle.rotation_track_interpolate(track, 0.0)
				if rotation.angle_to(Quaternion.IDENTITY) > 0.05:
					non_neutral += 1
		TestAssertions.equal(non_neutral, 4, "guard idle keeps both shoulder and elbow joints out of neutral A-pose", failures)
	presentation.free()

func _assert_fail_closed_nude_models(profile: CharacterVisualProfile, failures: Array[String]) -> void:
	for scene_path: String in [
		"res://scenes/characters/presentation/forge_humanoid_model.tscn",
		"res://scenes/characters/presentation/forge_base_masculine.tscn",
		"res://scenes/characters/presentation/forge_base_feminine.tscn",
	]:
		var scene := load(scene_path) as PackedScene
		var model := scene.instantiate() as Node3D if scene != null else null
		TestAssertions.truthy(model != null, "%s instantiates for nude modularity check" % scene_path, failures)
		if model == null:
			continue
		for node: Node in model.find_children("*", "", true, false):
			TestAssertions.truthy(not node.has_meta(&"equipment_slot") and not node.has_meta(&"equipment_visual_id"), "%s has no embedded equipment metadata at %s" % [scene_path, node.name], failures)
			var node_name := String(node.name).to_lower()
			TestAssertions.truthy("sword" not in node_name and "shield" not in node_name and "hammer" not in node_name and "weapon" not in node_name, "%s has no baked weapon node at %s" % [scene_path, node.name], failures)
		model.free()
	var runtime_model := profile.presentation_scene.instantiate() as ForgeHumanoidModel
	TestAssertions.truthy(runtime_model != null, "shared humanoid instantiates for delayed equipment check", failures)
	if runtime_model == null:
		return
	(Engine.get_main_loop() as SceneTree).root.add_child(runtime_model)
	var right_socket := runtime_model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket") as Node3D
	var left_socket := runtime_model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket") as Node3D
	var arm_meshes := _arm_meshes(runtime_model)
	TestAssertions.truthy(right_socket != null and left_socket != null, "shared humanoid exposes exact independent hand sockets", failures)
	TestAssertions.truthy(arm_meshes.size() >= 8, "shared humanoid retains both preset arm meshes", failures)
	if right_socket == null or left_socket == null or arm_meshes.size() < 8:
		runtime_model.free()
		return
	TestAssertions.equal(runtime_model.equipped_item_id(&"main_hand"), &"", "nude shared model begins without a sword", failures)
	TestAssertions.equal(runtime_model.equipped_item_id(&"off_hand"), &"", "nude shared model begins without a shield", failures)
	var sword := _visual_by_id(profile, &"forge_vanguard_sword")
	var shield := _visual_by_id(profile, &"forge_vanguard_shield")
	TestAssertions.truthy(sword != null and shield != null, "independent sword and shield definitions exist", failures)
	if sword == null or shield == null:
		runtime_model.free()
		return
	var right_before := _children(right_socket)
	var left_before := _children(left_socket)
	TestAssertions.truthy(runtime_model.apply_equipment_visual(&"main_hand", sword), "independent sword scene equips through its exact socket", failures)
	var sword_nodes := _new_children(right_socket, right_before)
	TestAssertions.truthy(not sword_nodes.is_empty(), "sword creates independent right-hand attachment nodes", failures)
	TestAssertions.truthy(runtime_model.apply_equipment_visual(&"off_hand", shield), "independent shield scene equips through its exact socket", failures)
	var shield_nodes := _new_children(left_socket, left_before)
	TestAssertions.truthy(not shield_nodes.is_empty(), "shield creates independent left-hand attachment nodes", failures)
	_assert_independent_attachment(runtime_model, sword_nodes, arm_meshes, "sword", failures)
	_assert_independent_attachment(runtime_model, shield_nodes, arm_meshes, "shield", failures)
	TestAssertions.equal(runtime_model.equipped_item_id(&"main_hand"), &"forge_vanguard_sword", "sword appears only after scene application", failures)
	TestAssertions.equal(runtime_model.equipped_item_id(&"off_hand"), &"forge_vanguard_shield", "shield appears only after scene application", failures)
	TestAssertions.truthy(runtime_model.set_body_preset(&"masculine") and _nodes_alive(sword_nodes) and _nodes_alive(shield_nodes), "masculine body swap preserves independent equipment", failures)
	TestAssertions.truthy(runtime_model.set_body_preset(&"feminine") and _nodes_alive(sword_nodes) and _nodes_alive(shield_nodes), "feminine body swap preserves independent equipment", failures)
	TestAssertions.truthy(runtime_model.clear_equipment_visual(&"main_hand"), "clearing main hand succeeds", failures)
	TestAssertions.truthy(not _nodes_alive(sword_nodes) and _nodes_alive(shield_nodes) and _meshes_alive(arm_meshes), "clearing sword leaves shield and both arms intact", failures)
	TestAssertions.truthy(runtime_model.clear_equipment_visual(&"off_hand"), "clearing off hand succeeds", failures)
	TestAssertions.truthy(not _nodes_alive(shield_nodes) and _meshes_alive(arm_meshes), "clearing shield leaves both arms intact", failures)
	runtime_model.free()

func _visual_by_id(profile: CharacterVisualProfile, item_id: StringName) -> EquipmentVisualDefinition:
	var item := profile.available_equipment.filter(func(candidate: EquipmentBaseDefinition) -> bool: return candidate != null and candidate.id == item_id)
	return item[0].presentation as EquipmentVisualDefinition if not item.is_empty() else null

func _children(node: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child: Node in node.get_children():
		if child is Node3D:
			result.append(child as Node3D)
	return result

func _new_children(node: Node, before: Array[Node3D]) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child: Node3D in _children(node):
		if child not in before:
			result.append(child)
	return result

func _arm_meshes(model: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var ancestry := _ancestor_names(mesh)
		if "upperarm" in ancestry or "forearm" in ancestry:
			result.append(mesh)
	return result

func _ancestor_names(node: Node) -> String:
	var names := ""
	var cursor: Node = node
	while cursor != null:
		names += String(cursor.name).to_lower()
		cursor = cursor.get_parent()
	return names

func _assert_independent_attachment(model: Node3D, attachments: Array[Node3D], arms: Array[MeshInstance3D], label: String, failures: Array[String]) -> void:
	var body_nodes: Array[Node3D] = []
	for node: Node in model.find_children("*", "Node3D", true, false):
		if node.has_meta(&"body_preset") or "upperarm" in String(node.name).to_lower() or "forearm" in String(node.name).to_lower():
			body_nodes.append(node as Node3D)
	for attachment: Node3D in attachments:
		for body_node: Node3D in body_nodes:
			TestAssertions.truthy(not _is_descendant(attachment, body_node), "%s attachment is not owned by a body or arm node" % label, failures)
		for mesh: MeshInstance3D in attachment.find_children("*", "MeshInstance3D", true, false):
			for arm: MeshInstance3D in arms:
				TestAssertions.truthy(mesh != arm and mesh.mesh != arm.mesh, "%s mesh is independent from arm mesh geometry" % label, failures)

func _is_descendant(node: Node, ancestor: Node) -> bool:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor == ancestor:
			return true
		cursor = cursor.get_parent()
	return false

func _nodes_alive(nodes: Array[Node3D]) -> bool:
	for node: Node3D in nodes:
		if not is_instance_valid(node):
			return false
	return true

func _meshes_alive(meshes: Array[MeshInstance3D]) -> bool:
	for mesh: MeshInstance3D in meshes:
		if not is_instance_valid(mesh):
			return false
	return true
