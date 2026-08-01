extends RefCounted

const PROFILE_PATH := "res://data/presentation/profiles/forge_vanguard.tres"
const EQUIPMENT_PATHS: Dictionary = {
	&"main_hand": "res://data/presentation/equipment/forge_vanguard_sword.tres",
	&"off_hand": "res://data/presentation/equipment/forge_vanguard_shield.tres",
	&"helmet": "res://data/presentation/equipment/forge_vanguard_helmet.tres",
	&"body_armour": "res://data/presentation/equipment/forge_vanguard_armour.tres",
	&"gloves": "res://data/presentation/equipment/forge_vanguard_gauntlets.tres",
	&"boots": "res://data/presentation/equipment/forge_vanguard_boots.tres",
	&"belt": "res://data/presentation/equipment/forge_vanguard_belt.tres",
	&"amulet": "res://data/presentation/equipment/forge_vanguard_amulet.tres",
	&"ring_left": "res://data/presentation/equipment/forge_vanguard_ring_left.tres",
	&"ring_right": "res://data/presentation/equipment/forge_vanguard_ring_right.tres",
}

func run() -> Array[String]:
	var failures: Array[String] = []
	var profile := load(PROFILE_PATH) as CharacterVisualProfile
	TestAssertions.truthy(profile != null, "Forge Vanguard profile loads", failures)
	if profile == null or profile.presentation_scene == null:
		return failures
	TestAssertions.equal(profile.palette_colors.keys().size(), 3, "three palettes", failures)
	TestAssertions.equal(profile.validate(), PackedStringArray(), "Forge Vanguard profile validates", failures)
	var available_visuals: Variant = profile.get("available_equipment_visuals")
	TestAssertions.truthy(available_visuals is Array and (available_visuals as Array).size() == EquipmentSlotCatalog.SLOT_IDS.size(), "all equipment visuals are discoverable", failures)
	for slot_id: StringName in [&"amulet", &"ring_left", &"ring_right"]:
		TestAssertions.truthy(profile.has_method(&"get_available_equipment_visual"), "%s visual accessor exists" % slot_id, failures)
		var discovered := profile.call(&"get_available_equipment_visual", slot_id) as EquipmentVisualDefinition if profile.has_method(&"get_available_equipment_visual") else null
		TestAssertions.truthy(discovered != null, "%s visual is discoverable for sandbox toggles" % slot_id, failures)
		TestAssertions.truthy(not _default_equips_slot(profile, slot_id), "%s remains unequipped by default" % slot_id, failures)
	var model := profile.presentation_scene.instantiate() as Node3D
	TestAssertions.truthy(model != null and model.has_method(&"set_body_preset"), "model implements body API", failures)
	if model == null:
		return failures
	TestAssertions.truthy(model.call(&"set_body_preset", &"masculine"), "masculine body resolves", failures)
	TestAssertions.truthy(model.call(&"set_body_preset", &"feminine"), "feminine body resolves", failures)
	TestAssertions.truthy(model.call(&"set_body_preset", &"masculine"), "masculine body restores for pivot checks", failures)
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		TestAssertions.truthy(model.call(&"has_equipment_slot", slot_id), "model exposes %s" % slot_id, failures)
	_assert_functional_pivot_contract(model, failures)
	_assert_shield_front_readability(model, failures)
	_assert_jewelry_emission(model, failures)
	_assert_unequipped_jewelry_visibility(model, profile, failures)
	var bounds: AABB = model.call(&"visual_bounds") as AABB
	TestAssertions.truthy(bounds.size.y >= 1.6 and bounds.size.y <= 1.85, "humanoid height fits actor scale", failures)
	TestAssertions.near(bounds.position.y, 0.0, 0.05, "model feet begin at local floor", failures)
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		var definition := load(EQUIPMENT_PATHS[slot_id]) as EquipmentVisualDefinition
		TestAssertions.truthy(definition != null, "%s equipment resource loads" % slot_id, failures)
		if definition != null:
			TestAssertions.equal(definition.slot_id, slot_id, "%s equipment resource slot" % slot_id, failures)
			TestAssertions.truthy(not definition.visual_channels.is_empty(), "%s equipment resource has visual channel" % slot_id, failures)
			TestAssertions.equal(definition.validate(), PackedStringArray(), "%s equipment resource validates" % slot_id, failures)
			if slot_id in [&"amulet", &"ring_left", &"ring_right"]:
				TestAssertions.truthy(model.call(&"apply_equipment_visual", slot_id, definition), "%s equipment visual applies" % slot_id, failures)
				var equipment_root := _equipment_root(model, slot_id)
				TestAssertions.truthy(equipment_root != null and equipment_root.visible, "%s equipment root becomes visible when applied" % slot_id, failures)
	model.free()
	return failures

func _default_equips_slot(profile: CharacterVisualProfile, slot_id: StringName) -> bool:
	for definition: EquipmentVisualDefinition in profile.default_equipment_visuals:
		if definition != null and definition.slot_id == slot_id:
			return true
	return false

func _assert_functional_pivot_contract(model: Node3D, failures: Array[String]) -> void:
	var hit_pivot := model.get_node_or_null("HitPivot") as Node3D
	var body_pivot := model.get_node_or_null("HitPivot/BodyPivot") as Node3D
	var torso_pivot := model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot") as Node3D
	var right_hand := model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket") as Node3D
	var left_hand := model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket") as Node3D
	var sword := model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket/MainHandVisual/ReadableChannel") as MeshInstance3D
	var shield := model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket/OffHandVisual/ReadableChannel") as MeshInstance3D
	var arm := model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/MasculineUpperArm/ReadableChannel") as MeshInstance3D
	var torso := model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/MasculineTorso/ReadableChannel") as MeshInstance3D
	var named_nodes := {&"HitPivot": hit_pivot, &"BodyPivot": body_pivot, &"TorsoPivot": torso_pivot, &"RightHandSocket": right_hand, &"LeftHandSocket": left_hand, &"sword": sword, &"shield": shield, &"arm": arm, &"torso": torso}
	for name: StringName in named_nodes:
		TestAssertions.truthy(named_nodes[name] != null, "functional pivot contract node exists: %s" % name, failures)
	if hit_pivot == null or body_pivot == null or torso_pivot == null or right_hand == null or left_hand == null or sword == null or shield == null or arm == null or torso == null:
		return
	TestAssertions.truthy(_is_descendant(sword, right_hand), "sword follows right hand pivots", failures)
	TestAssertions.truthy(_is_descendant(shield, left_hand), "shield follows left hand pivots", failures)
	TestAssertions.truthy(_is_descendant(arm, torso_pivot), "arm geometry follows torso and shoulder pivots", failures)
	TestAssertions.truthy(_is_descendant(torso, body_pivot), "body geometry follows BodyPivot", failures)
	for mesh: MeshInstance3D in _mesh_descendants(model):
		TestAssertions.truthy(_is_descendant(mesh, hit_pivot), "HitPivot carries visual mesh %s" % mesh.name, failures)
	_assert_pivot_moves_geometry(right_hand, sword, "right hand moves sword", failures)
	_assert_pivot_moves_geometry(left_hand, shield, "left hand moves shield", failures)
	_assert_pivot_moves_geometry(torso_pivot, arm, "shoulder chain moves arm", failures)
	_assert_pivot_moves_geometry(body_pivot, torso, "BodyPivot moves torso", failures)

func _assert_jewelry_emission(model: Node3D, failures: Array[String]) -> void:
	for mesh_path: String in [
		"HitPivot/BodyPivot/HipsPivot/TorsoPivot/AmuletVisual/ReadableChannel",
		"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket/RingLeftVisual/ReadableChannel",
		"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket/RingRightVisual/ReadableChannel",
	]:
		var mesh := model.get_node_or_null(mesh_path) as MeshInstance3D
		TestAssertions.truthy(mesh != null, "jewelry mesh exists: %s" % mesh_path, failures)
		if mesh != null:
			var material := mesh.material_override as StandardMaterial3D
			TestAssertions.truthy(material != null and material.emission_enabled, "jewelry emission is enabled: %s" % mesh_path, failures)

func _assert_shield_front_readability(model: Node3D, failures: Array[String]) -> void:
	var shield := model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket/OffHandVisual/ReadableChannel") as MeshInstance3D
	TestAssertions.truthy(shield != null, "shield readable mesh exists", failures)
	if shield == null or shield.mesh == null:
		return
	var shield_bounds := shield.mesh.get_aabb()
	TestAssertions.near(shield_bounds.size.x, 0.68, 0.01, "shield front projected width is 0.68 m", failures)
	TestAssertions.near(shield_bounds.size.y, 0.68, 0.01, "shield front projected height is 0.68 m", failures)
	TestAssertions.near(shield_bounds.size.z, 0.14, 0.01, "shield depth remains thin", failures)

func _assert_unequipped_jewelry_visibility(model: Node3D, profile: CharacterVisualProfile, failures: Array[String]) -> void:
	for slot_id: StringName in [&"main_hand", &"off_hand", &"helmet", &"body_armour", &"gloves", &"boots", &"belt"]:
		var default_root := _equipment_root(model, slot_id)
		TestAssertions.truthy(default_root != null and default_root.visible, "%s default equipment root starts visible" % slot_id, failures)
	for slot_id: StringName in [&"amulet", &"ring_left", &"ring_right"]:
		var jewelry_root := _equipment_root(model, slot_id)
		TestAssertions.truthy(jewelry_root != null and not jewelry_root.visible, "%s unequipped jewelry root starts hidden" % slot_id, failures)
		TestAssertions.truthy(profile.get_available_equipment_visual(slot_id) != null, "%s jewelry visual remains available" % slot_id, failures)

func _equipment_root(model: Node3D, slot_id: StringName) -> Node3D:
	for node: Node in model.find_children("*", "Node3D", true, false):
		if StringName(node.get_meta(&"equipment_slot", &"")) == slot_id:
			return node as Node3D
	return null

func _assert_pivot_moves_geometry(pivot: Node3D, mesh: MeshInstance3D, description: String, failures: Array[String]) -> void:
	var before := _model_transform(mesh).origin
	pivot.rotation.z += 0.2
	TestAssertions.truthy(not _model_transform(mesh).origin.is_equal_approx(before), description, failures)
	pivot.rotation.z -= 0.2

func _model_transform(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result

func _mesh_descendants(root: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes

func _is_descendant(node: Node, ancestor: Node) -> bool:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor == ancestor:
			return true
		cursor = cursor.get_parent()
	return false
