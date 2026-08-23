extends RefCounted

const SLOT_ID: StringName = &"body_armour"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_imported_surfaces_are_isolated_colored_and_restored(failures)
	_test_unsupported_surface_material_rejects_atomically(failures)
	_test_direct_rigid_preflight_scopes_to_selected_roots(failures)
	_test_staged_rigid_preflight_scopes_to_selected_roots(failures)
	return failures

func _test_imported_surfaces_are_isolated_colored_and_restored(failures: Array[String]) -> void:
	var fixture := _imported_scene([StandardMaterial3D.new(), StandardMaterial3D.new()])
	var source_materials := fixture.materials as Array
	(source_materials[0] as StandardMaterial3D).albedo_color = Color("27354a")
	(source_materials[0] as Material).set_meta(&"palette_region", &"primary")
	(source_materials[1] as StandardMaterial3D).albedo_color = Color("72533a")
	(source_materials[1] as Material).set_meta(&"palette_region", &"trim")
	var definition := _visual(&"imported_plate", fixture.scene as PackedScene)
	definition.wearer_accent_channel = &"primary"
	definition.item_colors = {&"trim": Color("35698f")}
	var first := _model()
	var second := _model()
	var wearer_color := Color("d66a42")
	TestAssertions.truthy(first.set_palette(&"ember", wearer_color), "first imported fixture accepts palette", failures)
	TestAssertions.truthy(second.set_palette(&"ember", wearer_color), "second imported fixture accepts palette", failures)
	TestAssertions.truthy(first.apply_equipment_visual(SLOT_ID, definition), "first imported multi-surface item promotes", failures)
	TestAssertions.truthy(second.apply_equipment_visual(SLOT_ID, definition), "second imported multi-surface item promotes", failures)
	var first_mesh := first.find_child("ImportedSurfaceMesh", true, false) as MeshInstance3D
	var second_mesh := second.find_child("ImportedSurfaceMesh", true, false) as MeshInstance3D
	TestAssertions.truthy(first_mesh != null and first_mesh.material_override == null, "imported mesh retains null whole-mesh override", failures)
	if first_mesh != null and second_mesh != null:
		var first_primary := first_mesh.get_surface_override_material(0) as StandardMaterial3D
		var first_trim := first_mesh.get_surface_override_material(1) as StandardMaterial3D
		var second_primary := second_mesh.get_surface_override_material(0) as StandardMaterial3D
		var second_trim := second_mesh.get_surface_override_material(1) as StandardMaterial3D
		TestAssertions.truthy(first_primary != null and first_trim != null, "promotion installs an override for every imported surface", failures)
		TestAssertions.truthy(first_primary != source_materials[0] and first_trim != source_materials[1], "promoted surfaces do not reuse source materials", failures)
		TestAssertions.truthy(first_primary != second_primary and first_trim != second_trim, "each equipped model owns independent surface materials", failures)
		if first_primary != null and first_trim != null:
			TestAssertions.equal(first_primary.albedo_color, wearer_color, "surface material palette metadata maps wearer accent", failures)
			TestAssertions.equal(first_trim.albedo_color, Color("35698f"), "surface material palette metadata maps item color", failures)
			first.set_hit_weight(1.0)
			first_primary = first_mesh.get_surface_override_material(0) as StandardMaterial3D
			first_trim = first_mesh.get_surface_override_material(1) as StandardMaterial3D
			TestAssertions.truthy(first_primary.emission_enabled and first_trim.emission_enabled, "hit flash reaches every imported surface", failures)
			first.set_downed(true)
			first_primary = first_mesh.get_surface_override_material(0) as StandardMaterial3D
			first_trim = first_mesh.get_surface_override_material(1) as StandardMaterial3D
			TestAssertions.near(first_primary.albedo_color.r, first_primary.albedo_color.g, 0.0001, "downed feedback desaturates primary surface", failures)
			TestAssertions.near(first_trim.albedo_color.r, first_trim.albedo_color.g, 0.0001, "downed feedback desaturates trim surface", failures)
			first.set_hit_weight(0.0)
			first.set_downed(false)
			first_primary = first_mesh.get_surface_override_material(0) as StandardMaterial3D
			first_trim = first_mesh.get_surface_override_material(1) as StandardMaterial3D
			TestAssertions.equal(first_primary.albedo_color, wearer_color, "cleared feedback exactly restores primary surface", failures)
			TestAssertions.equal(first_trim.albedo_color, Color("35698f"), "cleared feedback exactly restores trim surface", failures)
			TestAssertions.truthy(not first_primary.emission_enabled and not first_trim.emission_enabled, "cleared feedback restores emission on every surface", failures)
	TestAssertions.equal((source_materials[0] as StandardMaterial3D).albedo_color, Color("27354a"), "source primary material remains unchanged", failures)
	TestAssertions.equal((source_materials[1] as StandardMaterial3D).albedo_color, Color("72533a"), "source trim material remains unchanged", failures)
	TestAssertions.truthy(second.clear_equipment_visual(SLOT_ID), "imported multi-surface item clears", failures)
	_dispose_model(first)
	_dispose_model(second)

func _test_unsupported_surface_material_rejects_atomically(failures: Array[String]) -> void:
	var valid_fixture := _imported_scene([StandardMaterial3D.new(), StandardMaterial3D.new()])
	var model := _model()
	var valid := _visual(&"valid_plate", valid_fixture.scene as PackedScene)
	TestAssertions.truthy(model.apply_equipment_visual(SLOT_ID, valid), "valid imported surface item equips before rejection", failures)
	var installed := model.find_child("ImportedSurfaceMesh", true, false) as MeshInstance3D
	var unsupported_material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial;"
	unsupported_material.shader = shader
	var unsupported_fixture := _imported_scene([StandardMaterial3D.new(), unsupported_material])
	var unsupported := _visual(&"unsupported_plate", unsupported_fixture.scene as PackedScene)
	TestAssertions.truthy(not model.apply_equipment_visual(SLOT_ID, unsupported), "unsupported imported material rejects during promotion", failures)
	TestAssertions.equal(model.equipped_item_id(SLOT_ID), &"valid_plate", "unsupported replacement preserves prior definition", failures)
	TestAssertions.equal(model.find_child("ImportedSurfaceMesh", true, false), installed, "unsupported replacement preserves prior installed mesh", failures)
	_dispose_model(model)

func _test_direct_rigid_preflight_scopes_to_selected_roots(failures: Array[String]) -> void:
	var model := _model()
	var selected_valid := _variant_visual(&"selected_valid", StandardMaterial3D.new(), _unsupported_material())
	TestAssertions.truthy(model.apply_equipment_visual(SLOT_ID, selected_valid), "direct rigid promotion ignores the unselected unsupported feminine root", failures)
	var installed := model.find_child("MasculineFit", true, false)
	var selected_unsupported := _variant_visual(&"selected_unsupported", _unsupported_material(), StandardMaterial3D.new())
	TestAssertions.truthy(not model.apply_equipment_visual(SLOT_ID, selected_unsupported), "direct rigid promotion rejects an unsupported selected masculine root", failures)
	TestAssertions.equal(model.equipped_item_id(SLOT_ID), &"selected_valid", "direct unsupported selection preserves the prior definition", failures)
	TestAssertions.equal(model.find_child("MasculineFit", true, false), installed, "direct unsupported selection preserves the prior attachment", failures)
	_dispose_model(model)

func _test_staged_rigid_preflight_scopes_to_selected_roots(failures: Array[String]) -> void:
	var model := _model()
	var scene_with_unused_unsupported := _variant_scene(StandardMaterial3D.new(), StandardMaterial3D.new(), _unsupported_material())
	var selected_valid := _variant_visual_from_scene(&"staged_selected_valid", scene_with_unused_unsupported)
	TestAssertions.truthy(model.apply_equipment_visual(SLOT_ID, selected_valid), "direct install accepts valid selected root beside unrelated unsupported scene content", failures)
	var valid_candidate := model.prepare_body_preset_change(&"feminine")
	TestAssertions.truthy(bool(valid_candidate.get(&"ok", false)), "staged rigid promotion ignores unrelated unsupported scene content", failures)
	TestAssertions.truthy(model.commit_body_preset_change(valid_candidate), "valid staged rigid candidate commits", failures)

	var target_unsupported := _variant_visual(&"staged_target_unsupported", _unsupported_material(), StandardMaterial3D.new())
	TestAssertions.truthy(model.apply_equipment_visual(SLOT_ID, target_unsupported), "current feminine selection installs before inverse staged rejection", failures)
	var installed := model.find_child("FeminineFit", true, false)
	var inverse_candidate := model.prepare_body_preset_change(&"masculine")
	TestAssertions.truthy(not bool(inverse_candidate.get(&"ok", false)), "staged rigid promotion rejects the selected unsupported masculine root", failures)
	TestAssertions.equal(model.equipped_item_id(SLOT_ID), &"staged_target_unsupported", "failed staged selection preserves the live definition", failures)
	TestAssertions.equal(model.find_child("FeminineFit", true, false), installed, "failed staged selection preserves the live attachment", failures)
	TestAssertions.equal(model._active_body_preset, &"feminine", "failed staged selection preserves the live body preset", failures)
	_dispose_model(model)

func _model() -> ForgeHumanoidModel:
	var model := ForgeHumanoidModel.new()
	for preset_id: StringName in [&"masculine", &"feminine"]:
		var body := MeshInstance3D.new()
		body.name = StringName("%sLegacyBody" % String(preset_id).capitalize())
		body.set_meta(&"body_preset", preset_id)
		body.set_meta(&"palette_region", &"primary")
		body.mesh = BoxMesh.new()
		body.material_override = StandardMaterial3D.new()
		body.visible = preset_id == &"masculine"
		model.add_child(body)
	var socket := Node3D.new()
	socket.name = &"ImportedBodySocket"
	model.add_child(socket)
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	return model

func _visual(id: StringName, scene: PackedScene) -> EquipmentVisualDefinition:
	var definition := EquipmentVisualDefinition.new()
	definition.id = id
	definition.slot_id = SLOT_ID
	definition.supported_slot_ids = [SLOT_ID]
	definition.presentation_scene = scene
	definition.socket_id = &"ImportedBodySocket"
	definition.combat_visible = true
	return definition

func _variant_visual(id: StringName, masculine_material: Material, feminine_material: Material) -> EquipmentVisualDefinition:
	return _variant_visual_from_scene(id, _variant_scene(masculine_material, feminine_material))

func _variant_visual_from_scene(id: StringName, scene: PackedScene) -> EquipmentVisualDefinition:
	var masculine := EquipmentBodyFitDescriptor.new()
	masculine.body_preset_id = &"masculine"
	masculine.presentation_scene = scene
	masculine.mesh_root_paths = [NodePath("MasculineFit")]
	var feminine := EquipmentBodyFitDescriptor.new()
	feminine.body_preset_id = &"feminine"
	feminine.presentation_scene = scene
	feminine.mesh_root_paths = [NodePath("FeminineFit")]
	var definition := EquipmentVisualDefinition.new()
	definition.id = id
	definition.slot_id = SLOT_ID
	definition.supported_slot_ids = [SLOT_ID]
	definition.socket_id = &"ImportedBodySocket"
	definition.fit_policy = &"variant"
	definition.body_fits = [masculine, feminine]
	definition.combat_visible = true
	return definition

func _variant_scene(masculine_material: Material, feminine_material: Material, unused_material: Material = null) -> PackedScene:
	var root := Node3D.new()
	root.name = &"VariantEquipment"
	for entry: Dictionary in [
		{&"name": &"MasculineFit", &"material": masculine_material},
		{&"name": &"FeminineFit", &"material": feminine_material},
	]:
		var mesh := MeshInstance3D.new()
		mesh.name = entry[&"name"] as StringName
		mesh.mesh = BoxMesh.new()
		mesh.material_override = entry[&"material"] as Material
		root.add_child(mesh)
		mesh.owner = root
	if unused_material != null:
		var unused := MeshInstance3D.new()
		unused.name = &"UnusedUnsupportedSibling"
		unused.mesh = BoxMesh.new()
		unused.material_override = unused_material
		root.add_child(unused)
		unused.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

func _unsupported_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type spatial;"
	return material

func _imported_scene(materials: Array) -> Dictionary:
	var root := Node3D.new()
	root.name = &"ImportedPlate"
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = &"ImportedSurfaceMesh"
	mesh_instance.mesh = _two_surface_mesh(materials)
	mesh_instance.material_override = null
	root.add_child(mesh_instance)
	mesh_instance.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return {&"scene": scene, &"materials": materials}

func _two_surface_mesh(materials: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface_index: int in 2:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var offset := float(surface_index)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(offset, 0, 0), Vector3(offset + 0.5, 0, 0), Vector3(offset, 0.5, 0)])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface_index, materials[surface_index] as Material)
	return mesh

func _dispose_model(model: ForgeHumanoidModel) -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface_index: int in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface_index, null)
	model.free()
