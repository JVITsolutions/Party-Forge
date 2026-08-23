extends RefCounted

const HUMANOID_RIG_CONTRACT := preload("res://scripts/presentation/humanoid_rig_contract.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_failed_replacement_and_clear(failures)
	_test_icon_only_entry(failures)
	_test_descriptor_only_visual_equips(failures)
	_test_body_specific_scene_resolution(failures)
	_test_multi_fit_scene_installs_only_active_body_roots(failures)
	_test_multi_fit_material_cache_tracks_only_selected_roots(failures)
	_test_unknown_active_body_fails_closed(failures)
	_test_multi_socket_item(failures)
	_test_item_colors_and_wearer_accent_isolation(failures)
	_test_palette_refreshes_equipped_accent_without_leaking(failures)
	_test_root_mesh_item_colors(failures)
	_test_palette_rebases_clean_materials_during_feedback(failures)
	_test_equipment_inherits_active_feedback(failures)
	_test_repeated_swap_and_clear_release_item_material_caches(failures)
	_test_unmapped_equipment_material_inherits_and_restores_feedback(failures)
	_test_shared_skin_replace_failure_and_clear_restore_regions(failures)
	return failures

func _test_failed_replacement_and_clear(failures: Array[String]) -> void:
	var model := _model_with_sockets([&"MainHandSocket"])
	var first := _visual(&"first_sword", &"main_hand", &"MainHandSocket", _single_attachment_scene())
	var invalid := _visual(&"invalid_sword", &"main_hand", &"MainHandSocket", _mixed_socket_scene())
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", first), "first item equips", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"first_sword", "first item is recorded", failures)
	var old_node := model.get_node("MainHandSocket/SingleAttachment")
	TestAssertions.truthy(not model.apply_equipment_visual(&"main_hand", invalid), "missing socket rejects equip", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"first_sword", "failed equip preserves old item", failures)
	TestAssertions.equal(model.get_node("MainHandSocket/SingleAttachment"), old_node, "failed mixed-socket replacement preserves old installed node", failures)
	TestAssertions.truthy(model.clear_equipment_visual(&"main_hand"), "clear succeeds", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"", "clear removes item", failures)
	_free_model(model)

func _test_icon_only_entry(failures: Array[String]) -> void:
	var model := _model_with_sockets([])
	var icon_only := _visual(&"cosmetic_badge", &"belt", &"", null)
	icon_only.combat_visible = false
	TestAssertions.truthy(model.apply_equipment_visual(&"belt", icon_only), "icon-only entry equips without a scene", failures)
	TestAssertions.equal(model.equipped_item_id(&"belt"), &"cosmetic_badge", "icon-only entry is recorded", failures)
	_free_model(model)

func _test_descriptor_only_visual_equips(failures: Array[String]) -> void:
	var model := _model_with_sockets([&"MainHandSocket"])
	var scene := _named_attachment_scene(&"DescriptorOnlyAttachment")
	var visual := _visual(&"descriptor_only", &"main_hand", &"MainHandSocket", null)
	visual.body_fits = [_fit(&"shared", scene, [NodePath(".")])]
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", visual), "descriptor-only visual equips when the legacy scene is null", failures)
	TestAssertions.truthy(model.has_node("MainHandSocket/DescriptorOnlyAttachment"), "descriptor-only scene is installed through the active body resolver", failures)
	_free_model(model)

func _test_body_specific_scene_resolution(failures: Array[String]) -> void:
	var masculine_scene := _named_attachment_scene(&"MasculineAttachment")
	var feminine_scene := _named_attachment_scene(&"FeminineAttachment")
	var visual := _visual(&"body_scene_variant", &"main_hand", &"MainHandSocket", null)
	visual.fit_policy = &"variant"
	visual.body_fits = [
		_fit(&"masculine", masculine_scene, [NodePath(".")]),
		_fit(&"feminine", feminine_scene, [NodePath(".")]),
	]
	var model := _model_with_sockets([&"MainHandSocket"])
	TestAssertions.truthy(model.set_body_preset(&"feminine"), "runtime accepts the feminine active body", failures)
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", visual), "runtime equips the active body's descriptor scene", failures)
	TestAssertions.truthy(model.has_node("MainHandSocket/FeminineAttachment"), "feminine descriptor scene is installed", failures)
	TestAssertions.truthy(not model.has_node("MainHandSocket/MasculineAttachment"), "inactive masculine descriptor scene is never installed", failures)
	_free_model(model)

func _test_multi_fit_scene_installs_only_active_body_roots(failures: Array[String]) -> void:
	var scene := _multi_fit_attachment_scene()
	var visual := _visual(&"multi_fit_variant", &"main_hand", &"MainHandSocket", null)
	visual.fit_policy = &"variant"
	visual.body_fits = [
		_fit(&"masculine", scene, [NodePath("MasculineFit")]),
		_fit(&"feminine", scene, [NodePath("FeminineFit")]),
	]
	var masculine_model := _model_with_sockets([&"MainHandSocket"])
	TestAssertions.truthy(masculine_model.apply_equipment_visual(&"main_hand", visual), "masculine multi-fit item equips", failures)
	TestAssertions.truthy(masculine_model.has_node("MainHandSocket/MasculineFit"), "masculine root is installed for masculine body", failures)
	TestAssertions.truthy(not masculine_model.has_node("MainHandSocket/FeminineFit"), "feminine root is not installed for masculine body", failures)
	_free_model(masculine_model)
	var feminine_model := _model_with_sockets([&"MainHandSocket"])
	TestAssertions.truthy(feminine_model.set_body_preset(&"feminine"), "multi-fit runtime accepts feminine body", failures)
	TestAssertions.truthy(feminine_model.apply_equipment_visual(&"main_hand", visual), "feminine multi-fit item equips", failures)
	TestAssertions.truthy(feminine_model.has_node("MainHandSocket/FeminineFit"), "feminine root is installed for feminine body", failures)
	TestAssertions.truthy(not feminine_model.has_node("MainHandSocket/MasculineFit"), "masculine root is not installed for feminine body", failures)
	_free_model(feminine_model)

func _test_multi_fit_material_cache_tracks_only_selected_roots(failures: Array[String]) -> void:
	var scene := _multi_fit_colored_scene()
	var visual := _visual(&"multi_fit_colors", &"main_hand", &"MainHandSocket", null)
	visual.fit_policy = &"variant"
	visual.item_colors = {&"metal": Color(0.2, 0.6, 0.9, 1.0)}
	visual.body_fits = [
		_fit(&"masculine", scene, [NodePath("MasculineFit")]),
		_fit(&"feminine", scene, [NodePath("FeminineFit")]),
	]
	var model := _model_with_sockets([&"MainHandSocket"])
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", visual), "colored masculine multi-fit item equips", failures)
	var masculine_mesh := model.get_node_or_null("MainHandSocket/MasculineFit/MasculineMesh") as MeshInstance3D
	TestAssertions.truthy(masculine_mesh != null, "selected masculine material root is installed", failures)
	if masculine_mesh != null:
		TestAssertions.equal((masculine_mesh.material_override as StandardMaterial3D).albedo_color, visual.item_colors[&"metal"], "selected masculine root receives item color", failures)
		TestAssertions.truthy(model.base_materials.has(masculine_mesh), "selected masculine material remains cached", failures)
	_assert_material_cache(model, 2, "masculine install", failures)
	TestAssertions.truthy(model.set_body_preset(&"feminine"), "colored multi-fit runtime accepts feminine body", failures)
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", visual), "colored feminine multi-fit item replaces masculine fit", failures)
	var feminine_mesh := model.get_node_or_null("MainHandSocket/FeminineFit/FeminineMesh") as MeshInstance3D
	TestAssertions.truthy(feminine_mesh != null, "selected feminine material root is installed", failures)
	if feminine_mesh != null:
		TestAssertions.equal((feminine_mesh.material_override as StandardMaterial3D).albedo_color, visual.item_colors[&"metal"], "selected feminine root receives item color", failures)
		TestAssertions.truthy(model.base_materials.has(feminine_mesh), "selected feminine material remains cached", failures)
	_assert_material_cache(model, 2, "feminine replacement", failures)
	TestAssertions.truthy(model.clear_equipment_visual(&"main_hand"), "colored multi-fit item clears", failures)
	_assert_material_cache(model, 1, "multi-fit clear", failures)
	_free_model(model)

func _test_unknown_active_body_fails_closed(failures: Array[String]) -> void:
	var model := _model_with_sockets([&"MainHandSocket"], &"unknown_body")
	var scene := _named_attachment_scene(&"ShouldNotInstall")
	var visual := _visual(&"unknown_body_item", &"main_hand", &"MainHandSocket", scene)
	visual.body_fits = [_fit(&"shared", scene, [NodePath(".")])]
	TestAssertions.truthy(not model.apply_equipment_visual(&"main_hand", visual), "runtime rejects equipment when no known body preset is active", failures)
	TestAssertions.truthy(not model.has_node("MainHandSocket/ShouldNotInstall"), "unknown active body installs no descriptor scene", failures)
	_free_model(model)

func _test_multi_socket_item(failures: Array[String]) -> void:
	var model := _model_with_sockets([&"LeftHandSocket", &"RightHandSocket"])
	var paired := _visual(&"paired_daggers", &"main_hand", &"RightHandSocket", _paired_attachment_scene())
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", paired), "multi-socket item equips", failures)
	TestAssertions.equal(model.get_node("LeftHandSocket/LeftAttachment").name, &"LeftAttachment", "left attachment reaches left socket", failures)
	TestAssertions.equal(model.get_node("RightHandSocket/RightAttachment").name, &"RightAttachment", "right attachment reaches right socket", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"paired_daggers", "multi-socket item is recorded once", failures)
	_free_model(model)

func _test_item_colors_and_wearer_accent_isolation(failures: Array[String]) -> void:
	var scene := _colored_attachment_scene()
	var definition := _visual(&"accented_sword", &"main_hand", &"MainHandSocket", scene)
	definition.item_colors = {&"metal": Color(0.1, 0.8, 0.2, 1.0)}
	definition.wearer_accent_channel = &"accent"
	var first := _model_with_sockets([&"MainHandSocket"])
	var second := _model_with_sockets([&"MainHandSocket"])
	first.set_palette(&"red", Color(0.9, 0.1, 0.1, 1.0))
	second.set_palette(&"red", Color(0.1, 0.1, 0.9, 1.0))
	TestAssertions.truthy(first.apply_equipment_visual(&"main_hand", definition), "first colored item equips", failures)
	TestAssertions.truthy(second.apply_equipment_visual(&"main_hand", definition), "second colored item equips", failures)
	var first_metal := first.get_node("MainHandSocket/ColoredAttachment/Metal") as MeshInstance3D
	var first_accent := first.get_node("MainHandSocket/ColoredAttachment/Accent") as MeshInstance3D
	var second_accent := second.get_node("MainHandSocket/ColoredAttachment/Accent") as MeshInstance3D
	TestAssertions.equal((first_metal.material_override as StandardMaterial3D).albedo_color, definition.item_colors[&"metal"], "item-owned material color wins", failures)
	TestAssertions.equal((first_accent.material_override as StandardMaterial3D).albedo_color, Color(0.9, 0.1, 0.1, 1.0), "first wearer accent applies", failures)
	TestAssertions.equal((second_accent.material_override as StandardMaterial3D).albedo_color, Color(0.1, 0.1, 0.9, 1.0), "second wearer accent applies", failures)
	TestAssertions.truthy(first_accent.material_override != second_accent.material_override, "wearer accent materials are instance-isolated", failures)
	_free_model(first)
	_free_model(second)

func _test_palette_refreshes_equipped_accent_without_leaking(failures: Array[String]) -> void:
	var definition := _visual(&"palette_refresh_sword", &"main_hand", &"MainHandSocket", _colored_attachment_scene())
	definition.item_colors = {&"metal": Color(0.1, 0.8, 0.2, 1.0)}
	definition.wearer_accent_channel = &"accent"
	var first := _model_with_sockets([&"MainHandSocket"])
	var second := _model_with_sockets([&"MainHandSocket"])
	first.set_palette(&"red", Color(0.9, 0.1, 0.1, 1.0))
	second.set_palette(&"red", Color(0.1, 0.1, 0.9, 1.0))
	TestAssertions.truthy(first.apply_equipment_visual(&"main_hand", definition), "first palette-refresh item equips", failures)
	TestAssertions.truthy(second.apply_equipment_visual(&"main_hand", definition), "second palette-refresh item equips", failures)
	first.set_palette(&"blue", Color(0.2, 0.8, 0.9, 1.0))
	var first_body := first.get_node("BodyMesh") as MeshInstance3D
	var first_metal := first.get_node("MainHandSocket/ColoredAttachment/Metal") as MeshInstance3D
	var first_accent := first.get_node("MainHandSocket/ColoredAttachment/Accent") as MeshInstance3D
	var second_accent := second.get_node("MainHandSocket/ColoredAttachment/Accent") as MeshInstance3D
	TestAssertions.equal((first_body.material_override as StandardMaterial3D).albedo_color, Color(0.2, 0.8, 0.9, 1.0), "palette refresh recolors body primary", failures)
	TestAssertions.equal((first_accent.material_override as StandardMaterial3D).albedo_color, Color(0.2, 0.8, 0.9, 1.0), "palette refresh recolors equipped wearer accent", failures)
	TestAssertions.equal((first_metal.material_override as StandardMaterial3D).albedo_color, definition.item_colors[&"metal"], "palette refresh preserves item-owned metal", failures)
	TestAssertions.equal((second_accent.material_override as StandardMaterial3D).albedo_color, Color(0.1, 0.1, 0.9, 1.0), "palette refresh does not alter another model accent", failures)
	_free_model(first)
	_free_model(second)

func _test_root_mesh_item_colors(failures: Array[String]) -> void:
	var model := _model_with_sockets([&"MainHandSocket"])
	var definition := _visual(&"root_mesh_item", &"main_hand", &"MainHandSocket", _root_mesh_scene())
	definition.item_colors = {&"metal": Color(0.7, 0.4, 0.1, 1.0)}
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", definition), "root MeshInstance3D item equips", failures)
	var root_mesh := model.get_node("MainHandSocket/RootMesh") as MeshInstance3D
	TestAssertions.equal((root_mesh.material_override as StandardMaterial3D).albedo_color, definition.item_colors[&"metal"], "root MeshInstance3D receives item color", failures)
	_free_model(model)

func _test_palette_rebases_clean_materials_during_feedback(failures: Array[String]) -> void:
	var definition := _visual(&"feedback_palette_sword", &"main_hand", &"MainHandSocket", _colored_attachment_scene())
	definition.item_colors = {&"metal": Color(0.1, 0.8, 0.2, 1.0)}
	definition.wearer_accent_channel = &"accent"
	var model := _model_with_sockets([&"MainHandSocket"])
	model.set_palette(&"red", Color(0.9, 0.1, 0.1, 1.0))
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", definition), "feedback palette item equips", failures)
	model.set_hit_weight(1.0)
	model.set_palette(&"blue", Color(0.2, 0.8, 0.9, 1.0))
	var body := model.get_node("BodyMesh") as MeshInstance3D
	var accent := model.get_node("MainHandSocket/ColoredAttachment/Accent") as MeshInstance3D
	TestAssertions.equal((body.material_override as StandardMaterial3D).albedo_color, Color(0.2, 0.8, 0.9, 1.0).lightened(0.35), "hit feedback uses rebased body palette", failures)
	TestAssertions.equal((accent.material_override as StandardMaterial3D).albedo_color, Color(0.2, 0.8, 0.9, 1.0).lightened(0.35), "hit feedback uses rebased wearer accent", failures)
	model.set_hit_weight(0.0)
	TestAssertions.equal((body.material_override as StandardMaterial3D).albedo_color, Color(0.2, 0.8, 0.9, 1.0), "cleared hit restores clean body palette", failures)
	TestAssertions.equal((accent.material_override as StandardMaterial3D).albedo_color, Color(0.2, 0.8, 0.9, 1.0), "cleared hit restores clean wearer accent", failures)
	TestAssertions.truthy(not (body.material_override as StandardMaterial3D).emission_enabled, "cleared hit removes feedback emission from body base", failures)
	TestAssertions.truthy(not (accent.material_override as StandardMaterial3D).emission_enabled, "cleared hit removes feedback emission from accent base", failures)
	model.set_downed(true)
	model.set_palette(&"green", Color(0.2, 0.9, 0.3, 1.0))
	var downed_color := (body.material_override as StandardMaterial3D).albedo_color
	TestAssertions.near(downed_color.r, downed_color.g, 0.001, "downed palette remains grayscale after rebasing", failures)
	TestAssertions.near(downed_color.g, downed_color.b, 0.001, "downed palette keeps grayscale channels equal", failures)
	model.set_downed(false)
	TestAssertions.equal((body.material_override as StandardMaterial3D).albedo_color, Color(0.2, 0.9, 0.3, 1.0), "cleared downed restores clean rebased palette", failures)
	_free_model(model)

func _test_equipment_inherits_active_feedback(failures: Array[String]) -> void:
	var hit_item := _visual(&"hit_item", &"main_hand", &"MainHandSocket", _root_mesh_scene())
	hit_item.item_colors = {&"metal": Color(0.2, 0.7, 0.3, 1.0)}
	var downed_item := _visual(&"downed_item", &"main_hand", &"MainHandSocket", _root_mesh_scene())
	downed_item.item_colors = {&"metal": Color(0.8, 0.3, 0.2, 1.0)}
	var model := _model_with_sockets([&"MainHandSocket"])
	model.set_hit_weight(1.0)
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", hit_item), "hit-active item equips", failures)
	var hit_mesh := model.get_node("MainHandSocket/RootMesh") as MeshInstance3D
	TestAssertions.equal((hit_mesh.material_override as StandardMaterial3D).albedo_color, hit_item.item_colors[&"metal"].lightened(0.35), "hit-active item immediately receives feedback tint", failures)
	TestAssertions.truthy((hit_mesh.material_override as StandardMaterial3D).emission_enabled, "hit-active item immediately receives feedback emission", failures)
	model.set_hit_weight(0.0)
	TestAssertions.equal((hit_mesh.material_override as StandardMaterial3D).albedo_color, hit_item.item_colors[&"metal"], "cleared hit restores equipped item base color", failures)
	model.set_downed(true)
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", downed_item), "downed replacement item equips", failures)
	var downed_mesh := model.get_node("MainHandSocket/RootMesh") as MeshInstance3D
	var downed_color := (downed_mesh.material_override as StandardMaterial3D).albedo_color
	TestAssertions.near(downed_color.r, downed_color.g, 0.001, "downed replacement immediately receives grayscale", failures)
	TestAssertions.near(downed_color.g, downed_color.b, 0.001, "downed replacement grayscale channels match", failures)
	model.set_downed(false)
	TestAssertions.equal((downed_mesh.material_override as StandardMaterial3D).albedo_color, downed_item.item_colors[&"metal"], "cleared downed restores replacement base color", failures)
	_free_model(model)

func _test_repeated_swap_and_clear_release_item_material_caches(failures: Array[String]) -> void:
	var first := _visual(&"cache_first", &"main_hand", &"MainHandSocket", _root_mesh_scene())
	first.item_colors = {&"metal": Color(0.2, 0.3, 0.4, 1.0)}
	var second := _visual(&"cache_second", &"main_hand", &"MainHandSocket", _root_mesh_scene())
	second.item_colors = {&"metal": Color(0.4, 0.3, 0.2, 1.0)}
	var model := _model_with_sockets([&"MainHandSocket"])
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", first), "first cache item equips", failures)
	TestAssertions.equal(model.base_materials.size(), 2, "first item contributes one material cache entry", failures)
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", second), "second cache item replaces first", failures)
	TestAssertions.equal(model.base_materials.size(), 2, "replacement releases old item material cache", failures)
	TestAssertions.truthy(model.clear_equipment_visual(&"main_hand"), "cache item clear succeeds", failures)
	TestAssertions.equal(model.base_materials.size(), 1, "clear releases all item material cache entries", failures)
	_free_model(model)

func _test_unmapped_equipment_material_inherits_and_restores_feedback(failures: Array[String]) -> void:
	var definition := _visual(&"unmapped_feedback_item", &"main_hand", &"MainHandSocket", _unmapped_root_mesh_scene())
	var base_color := Color(0.25, 0.5, 0.75, 1.0)
	var model := _model_with_sockets([&"MainHandSocket"])
	model.set_hit_weight(1.0)
	model.set_downed(true)
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", definition), "unmapped material item equips under active feedback", failures)
	var mesh := model.get_node("MainHandSocket/UnmappedRootMesh") as MeshInstance3D
	var feedback_color := base_color.lightened(0.35)
	var grayscale := Color(feedback_color.get_luminance(), feedback_color.get_luminance(), feedback_color.get_luminance(), feedback_color.a)
	TestAssertions.equal((mesh.material_override as StandardMaterial3D).albedo_color, grayscale, "unmapped material immediately receives hit and downed feedback", failures)
	TestAssertions.truthy((mesh.material_override as StandardMaterial3D).emission_enabled, "unmapped material receives hit feedback emission", failures)
	model.set_hit_weight(0.0)
	var downed_color := base_color.get_luminance()
	TestAssertions.equal((mesh.material_override as StandardMaterial3D).albedo_color, Color(downed_color, downed_color, downed_color, 1.0), "cleared hit restores downed unmapped base", failures)
	TestAssertions.truthy(not (mesh.material_override as StandardMaterial3D).emission_enabled, "cleared hit removes unmapped feedback emission", failures)
	model.set_downed(false)
	TestAssertions.equal((mesh.material_override as StandardMaterial3D).albedo_color, base_color, "cleared downed restores clean unmapped base", failures)
	_free_model(model)

func _test_shared_skin_replace_failure_and_clear_restore_regions(failures: Array[String]) -> void:
	var definition_resource := load("res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres")
	var model := ForgeHumanoidModel.new()
	for pivot_path: NodePath in definition_resource.pivot_paths:
		_ensure_node_path(model, pivot_path)
	var body := MeshInstance3D.new()
	body.name = &"MasculineTorso"
	body.set_meta(&"body_preset", &"masculine")
	body.set_meta(&"body_region", &"torso")
	body.visible = true
	model.add_child(body)
	var skeleton := Skeleton3D.new()
	skeleton.name = &"CanonicalSkeleton"
	var role_to_index: Dictionary = {}
	for index: int in definition_resource.roles.size():
		skeleton.add_bone(definition_resource.bone_names[index])
		role_to_index[definition_resource.roles[index]] = index
	for index: int in definition_resource.roles.size():
		var parent_role: StringName = definition_resource.parent_roles[index]
		if not parent_role.is_empty():
			skeleton.set_bone_parent(index, role_to_index[parent_role])
		skeleton.set_bone_rest(index, definition_resource.canonical_rests[index])
	model.add_child(skeleton)
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	var valid_scene := _integration_shared_skin_scene(definition_resource, false)
	var valid := _integration_shared_skin_visual(&"valid_armour", valid_scene, definition_resource, false)
	TestAssertions.truthy(model.apply_equipment_visual(&"body_armour", valid), "shared-skinned equipment equips through separate binding path", failures)
	var installed := model.find_child("ArmourMesh", true, false) as MeshInstance3D
	TestAssertions.truthy(installed != null and installed.skeleton == installed.get_path_to(skeleton), "installed equipment binds to actor canonical skeleton", failures)
	TestAssertions.truthy(not body.visible, "equipped shared skin hides descriptor body region", failures)
	var invalid_scene := _integration_shared_skin_scene(definition_resource, true)
	var invalid := _integration_shared_skin_visual(&"invalid_armour", invalid_scene, definition_resource, true)
	TestAssertions.truthy(not model.apply_equipment_visual(&"body_armour", invalid), "invalid shared skin replacement rejects atomically", failures)
	TestAssertions.equal(model.equipped_item_id(&"body_armour"), &"valid_armour", "failed shared skin replacement preserves prior definition", failures)
	TestAssertions.equal(model.find_child("ArmourMesh", true, false), installed, "failed shared skin replacement preserves prior installed mesh", failures)
	TestAssertions.truthy(not body.visible, "failed shared skin replacement preserves prior hidden region", failures)
	TestAssertions.truthy(model.clear_equipment_visual(&"body_armour"), "shared-skinned equipment clear succeeds", failures)
	TestAssertions.truthy(not is_instance_valid(installed), "clear frees installed skinned mesh", failures)
	TestAssertions.truthy(body.visible, "clear restores hidden body region", failures)
	_free_model(model)

func _integration_shared_skin_visual(id: StringName, scene: PackedScene, rig: Resource, wrong_signature: bool) -> EquipmentVisualDefinition:
	var visual := _visual(id, &"body_armour", &"", scene)
	visual.attachment_mode = &"shared_skin"
	visual.fit_policy = &"variant"
	visual.body_fits = [
		_fit(&"masculine", scene, [NodePath("MasculineRoot")]),
		_fit(&"feminine", scene, [NodePath("FeminineRoot")]),
	]
	visual.body_fits[0].hide_body_regions = [&"torso"]
	visual.rig_id = rig.rig_id
	visual.skeleton_topology_signature = rig.topology_signature
	visual.canonical_rest_signature = rig.canonical_rest_signature
	visual.skin_bind_signature = "wrong" if wrong_signature else HUMANOID_RIG_CONTRACT.new().skin_bind_signature(rig, _integration_skin(rig))
	return visual

func _integration_shared_skin_scene(rig: Resource, unweighted: bool) -> PackedScene:
	var root := Node3D.new()
	root.name = &"SharedArmourSource"
	var duplicate_skeleton := Skeleton3D.new()
	duplicate_skeleton.name = &"DuplicateSkeleton"
	root.add_child(duplicate_skeleton)
	duplicate_skeleton.owner = root
	var player := AnimationPlayer.new()
	player.name = &"SourceAnimationPlayer"
	root.add_child(player)
	player.owner = root
	for root_name: StringName in [&"MasculineRoot", &"FeminineRoot"]:
		var fit_root := Node3D.new()
		fit_root.name = root_name
		root.add_child(fit_root)
		fit_root.owner = root
		var mesh := MeshInstance3D.new()
		mesh.name = &"ArmourMesh" if root_name == &"MasculineRoot" else &"InactiveArmourMesh"
		mesh.mesh = _integration_weighted_mesh(unweighted and root_name == &"MasculineRoot")
		mesh.skin = _integration_skin(rig)
		mesh.material_override = StandardMaterial3D.new()
		fit_root.add_child(mesh)
		mesh.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

func _integration_weighted_mesh(unweighted: bool) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([
		0.0 if unweighted else 1.0, 0.0, 0.0, 0.0,
		0.0 if unweighted else 1.0, 0.0, 0.0, 0.0,
		0.0 if unweighted else 1.0, 0.0, 0.0, 0.0,
	])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _integration_skin(rig: Resource) -> Skin:
	var skin := Skin.new()
	for index: int in rig.bone_names.size():
		skin.add_named_bind(rig.bone_names[index], rig.canonical_rests[index].affine_inverse())
	return skin

func _ensure_node_path(root: Node, path: NodePath) -> void:
	var cursor := root
	for component: String in String(path).split("/"):
		var child := cursor.get_node_or_null(NodePath(component))
		if child == null:
			child = Node3D.new()
			child.name = component
			cursor.add_child(child)
		cursor = child

func _model_with_sockets(socket_ids: Array[StringName], body_preset_id: StringName = &"masculine") -> ForgeHumanoidModel:
	var model := ForgeHumanoidModel.new()
	var body := MeshInstance3D.new()
	body.name = &"BodyMesh"
	body.set_meta(&"body_preset", body_preset_id)
	body.set_meta(&"palette_region", &"primary")
	body.material_override = StandardMaterial3D.new()
	model.add_child(body)
	for socket_id: StringName in socket_ids:
		var socket := Node3D.new()
		socket.name = socket_id
		model.add_child(socket)
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	return model

func _free_model(model: Node3D) -> void:
	model.free()

func _visual(id: StringName, slot: StringName, socket: StringName, scene: PackedScene) -> EquipmentVisualDefinition:
	var value := EquipmentVisualDefinition.new()
	value.id = id
	value.slot_id = slot
	value.supported_slot_ids = [slot]
	value.socket_id = socket
	value.presentation_scene = scene
	value.combat_visible = true
	value.body_preset_ids = [&"masculine", &"feminine"]
	return value

func _single_attachment_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = &"SingleAttachment"
	root.add_child(MeshInstance3D.new())
	root.get_child(0).owner = root
	return _pack_scene(root)

func _named_attachment_scene(node_name: StringName) -> PackedScene:
	var root := Node3D.new()
	root.name = node_name
	return _pack_scene(root)

func _multi_fit_attachment_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = &"MultiFitItem"
	for fit_name: StringName in [&"MasculineFit", &"FeminineFit"]:
		var fit_root := Node3D.new()
		fit_root.name = fit_name
		root.add_child(fit_root)
		fit_root.owner = root
	return _pack_scene(root)

func _multi_fit_colored_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = &"MultiFitColoredItem"
	for description: Dictionary in [
		{&"fit": &"MasculineFit", &"mesh": &"MasculineMesh"},
		{&"fit": &"FeminineFit", &"mesh": &"FeminineMesh"},
	]:
		var fit_root := Node3D.new()
		fit_root.name = description[&"fit"]
		root.add_child(fit_root)
		fit_root.owner = root
		var mesh := MeshInstance3D.new()
		mesh.name = description[&"mesh"]
		mesh.set_meta(&"palette_region", &"metal")
		mesh.material_override = StandardMaterial3D.new()
		fit_root.add_child(mesh)
		mesh.owner = root
	return _pack_scene(root)

func _assert_material_cache(model: ForgeHumanoidModel, expected_size: int, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(model.base_materials.size(), expected_size, "%s caches only body and selected fit materials" % label, failures)
	var body_mesh := model.get_node_or_null("BodyMesh") as MeshInstance3D
	TestAssertions.truthy(body_mesh != null and model.base_materials.has(body_mesh), "%s keeps the live body material cached" % label, failures)

func _fit(body_id: StringName, scene: PackedScene, roots: Array[NodePath]) -> EquipmentBodyFitDescriptor:
	var descriptor := EquipmentBodyFitDescriptor.new()
	descriptor.body_preset_id = body_id
	descriptor.presentation_scene = scene
	descriptor.mesh_root_paths = roots
	return descriptor

func _paired_attachment_scene() -> PackedScene:
	var root := Node3D.new()
	for description: Dictionary in [
		{&"name": &"LeftAttachment", &"socket": &"LeftHandSocket"},
		{&"name": &"RightAttachment", &"socket": &"RightHandSocket"},
	]:
		var attachment := Node3D.new()
		attachment.name = description[&"name"]
		attachment.set_meta(&"equipment_socket_id", description[&"socket"])
		root.add_child(attachment)
		attachment.owner = root
	return _pack_scene(root)

func _mixed_socket_scene() -> PackedScene:
	var root := Node3D.new()
	for description: Dictionary in [
		{&"name": &"ValidAttachment", &"socket": &"MainHandSocket"},
		{&"name": &"MissingAttachment", &"socket": &"MissingSocket"},
	]:
		var attachment := Node3D.new()
		attachment.name = description[&"name"]
		attachment.set_meta(&"equipment_socket_id", description[&"socket"])
		root.add_child(attachment)
		attachment.owner = root
	return _pack_scene(root)

func _colored_attachment_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = &"ColoredAttachment"
	for description: Dictionary in [
		{&"name": &"Metal", &"region": &"metal"},
		{&"name": &"Accent", &"region": &"accent"},
	]:
		var mesh := MeshInstance3D.new()
		mesh.name = description[&"name"]
		mesh.set_meta(&"palette_region", description[&"region"])
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		mesh.material_override = material
		root.add_child(mesh)
		mesh.owner = root
	return _pack_scene(root)

func _root_mesh_scene() -> PackedScene:
	var root := MeshInstance3D.new()
	root.name = &"RootMesh"
	root.set_meta(&"palette_region", &"metal")
	root.material_override = StandardMaterial3D.new()
	return _pack_scene(root)

func _unmapped_root_mesh_scene() -> PackedScene:
	var root := MeshInstance3D.new()
	root.name = &"UnmappedRootMesh"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.5, 0.75, 1.0)
	root.material_override = material
	return _pack_scene(root)

func _pack_scene(root: Node3D) -> PackedScene:
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene
