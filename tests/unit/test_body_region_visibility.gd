extends RefCounted

const CATALOG_PATH := "res://scripts/presentation/body_region_catalog.gd"
const EXPECTED_IDS: Array[StringName] = [
	&"head", &"hair", &"neck", &"torso", &"upper_arm_left", &"upper_arm_right",
	&"forearm_left", &"forearm_right", &"hand_left", &"hand_right", &"hips",
	&"thigh_left", &"thigh_right", &"shin_left", &"shin_right", &"foot_left", &"foot_right",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_catalog_contract(failures)
	_test_runtime_visibility_transaction(failures)
	return failures

func _test_catalog_contract(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(CATALOG_PATH), "body-region catalog implementation exists", failures)
	if not ResourceLoader.exists(CATALOG_PATH):
		return
	var catalog: RefCounted = (load(CATALOG_PATH) as Script).new()
	TestAssertions.equal(catalog.call(&"canonical_region_ids"), EXPECTED_IDS, "catalog exposes the exact ordered seventeen design IDs", failures)
	var valid := _body_root()
	TestAssertions.equal(catalog.call(&"validate_body_root", valid), PackedStringArray(), "exact imported body-region contract validates", failures)
	var missing := _body_root()
	missing.get_node("BodyRegion__foot_right").free()
	TestAssertions.truthy(_has_error_fragment(catalog.call(&"validate_body_root", missing), "foot_right is missing"), "missing canonical region rejects for the exact reason", failures)
	var duplicate := _body_root()
	var nested := Node3D.new()
	nested.name = &"NestedRegions"
	duplicate.add_child(nested)
	var duplicate_region := duplicate.get_node("BodyRegion__foot_right")
	duplicate.remove_child(duplicate_region)
	nested.add_child(duplicate_region)
	duplicate_region.name = &"BodyRegion__foot_left"
	TestAssertions.truthy(_has_error_fragment(catalog.call(&"validate_body_root", duplicate), "foot_left is duplicated"), "duplicate canonical region rejects for the exact reason", failures)
	var unknown := _body_root()
	unknown.get_node("BodyRegion__foot_right").name = &"BodyRegion__tail"
	TestAssertions.truthy(_has_error_fragment(catalog.call(&"validate_body_root", unknown), "unknown region ID tail"), "unknown canonical region rejects for the exact reason", failures)
	var too_many_materials := _body_root(true)
	TestAssertions.truthy(not (catalog.call(&"validate_body_root", too_many_materials) as PackedStringArray).is_empty(), "more than four source body materials rejects", failures)
	valid.free()
	missing.free()
	duplicate.free()
	unknown.free()
	too_many_materials.free()

func _test_runtime_visibility_transaction(failures: Array[String]) -> void:
	var model := ForgeHumanoidModel.new()
	var body := _body_root()
	model.add_child(body)
	var socket := Node3D.new()
	socket.name = &"ImportedBodySocket"
	model.add_child(socket)
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	var hair := body.get_node("BodyRegion__hair") as MeshInstance3D
	hair.visible = false
	TestAssertions.truthy(model.set_body_preset(&"masculine"), "valid imported body contract promotes", failures)
	var first := _visual(&"torso_cover", [&"torso", &"hair"])
	TestAssertions.truthy(model.apply_equipment_visual(&"body_armour", first), "fit with canonical hidden regions equips", failures)
	TestAssertions.truthy(not (body.get_node("BodyRegion__torso") as MeshInstance3D).visible, "fit hides exact torso region", failures)
	TestAssertions.truthy(not hair.visible, "fit leaves authored-hidden hair hidden", failures)
	var replacement := _visual(&"head_cover", [&"head"])
	TestAssertions.truthy(model.apply_equipment_visual(&"body_armour", replacement), "replacement fit equips", failures)
	TestAssertions.truthy((body.get_node("BodyRegion__torso") as MeshInstance3D).visible, "replacement exactly restores no-longer-hidden torso", failures)
	TestAssertions.truthy(not hair.visible, "replacement restores authored-hidden hair exactly", failures)
	TestAssertions.truthy(not (body.get_node("BodyRegion__head") as MeshInstance3D).visible, "replacement hides its own head region", failures)
	var installed := model.get_node("ImportedBodySocket/RegionCover")
	var invalid := _visual(&"invalid_cover", [&"tail"])
	TestAssertions.truthy(not model.apply_equipment_visual(&"body_armour", invalid), "unknown hidden region rejects before replacement", failures)
	TestAssertions.equal(model.get_node("ImportedBodySocket/RegionCover"), installed, "failed replacement preserves installed equipment", failures)
	TestAssertions.truthy(not (body.get_node("BodyRegion__head") as MeshInstance3D).visible, "failed replacement preserves current hidden region", failures)
	TestAssertions.truthy((body.get_node("BodyRegion__torso") as MeshInstance3D).visible and not hair.visible, "failed replacement preserves exact restored visibility", failures)
	TestAssertions.truthy(model.clear_equipment_visual(&"body_armour"), "clearing region fit succeeds", failures)
	TestAssertions.truthy((body.get_node("BodyRegion__head") as MeshInstance3D).visible, "clear restores authored-visible head", failures)
	TestAssertions.truthy(not hair.visible, "clear preserves authored-hidden hair", failures)
	model.free()

func _body_root(unique_materials: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = &"MasculineImportedBody"
	root.set_meta(&"body_preset", &"masculine")
	root.visible = true
	var shared_materials: Array[StandardMaterial3D] = []
	for index: int in 4:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.from_hsv(float(index) / 4.0, 0.5, 0.7)
		shared_materials.append(material)
	for index: int in EXPECTED_IDS.size():
		var mesh := MeshInstance3D.new()
		mesh.name = StringName("BodyRegion__%s" % EXPECTED_IDS[index])
		mesh.mesh = BoxMesh.new()
		mesh.skin = Skin.new()
		mesh.set_meta(&"palette_region", &"primary")
		var material := StandardMaterial3D.new() if unique_materials else shared_materials[index % shared_materials.size()]
		(mesh.mesh as BoxMesh).material = material
		root.add_child(mesh)
	return root

func _visual(id: StringName, hidden_regions: Array[StringName]) -> EquipmentVisualDefinition:
	var root := MeshInstance3D.new()
	root.name = &"RegionCover"
	root.mesh = BoxMesh.new()
	root.material_override = StandardMaterial3D.new()
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var descriptor := EquipmentBodyFitDescriptor.new()
	descriptor.body_preset_id = &"shared"
	descriptor.presentation_scene = scene
	descriptor.mesh_root_paths = [NodePath(".")]
	descriptor.hide_body_regions = hidden_regions
	var definition := EquipmentVisualDefinition.new()
	definition.id = id
	definition.slot_id = &"body_armour"
	definition.supported_slot_ids = [&"body_armour"]
	definition.socket_id = &"ImportedBodySocket"
	definition.fit_policy = &"shared"
	definition.body_fits = [descriptor]
	definition.combat_visible = true
	return definition

func _has_error_fragment(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false
