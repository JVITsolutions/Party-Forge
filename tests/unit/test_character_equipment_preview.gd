extends RefCounted

const PREVIEW_SCENE_PATH := "res://scenes/ui/ledger/character_equipment_preview.tscn"
const LEADER_SCENE_PATH := "res://scenes/characters/leader.tscn"
const FIXTURE_SCENE_PATH := "res://tests/fixtures/fake_character_model.tscn"
const FIGHTER_DEFINITION := preload("res://data/classes/fighter.tres") as ClassDefinition
const RANGER_DEFINITION := preload("res://data/classes/ranger.tres") as ClassDefinition
const FORGE_HUMANOID_MODEL_SCRIPT := preload("res://scripts/presentation/forge_humanoid_model.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(PREVIEW_SCENE_PATH), "character equipment preview scene exists", failures)
	if not ResourceLoader.exists(PREVIEW_SCENE_PATH):
		return failures
	_test_member_identity_and_reusable_host(failures)
	_test_clear_suspends_rendering_and_show_reenables(failures)
	_test_exact_color_change_replaces_preview(failures)
	_test_same_id_profile_scene_change_replaces_preview(failures)
	_test_same_id_visual_geometry_change_replaces_preview(failures)
	_test_preview_rotation_and_live_actor_isolation(failures)
	_test_visual_resolution_keeps_disabled_items_and_falls_back_once(failures)
	_test_class_preview_uses_production_profile_defaults(failures)
	_test_class_and_member_mode_signatures_cannot_collide(failures)
	_test_class_defaults_do_not_inherit_explicit_member_equipment(failures)
	_test_class_fallback_is_neutral_and_safe(failures)
	_test_class_preview_lifecycle_and_reduced_motion(failures)
	_test_all_class_previews_share_centered_frame_and_action_rotation(failures)
	return failures


func _test_member_identity_and_reusable_host(failures: Array[String]) -> void:
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	_attach_preview(preview)
	var first := _member(1, &"feminine", &"blue", Color("3588d4"))
	var second := _member(2, &"masculine", &"gold", Color("d6a437"))
	TestAssertions.truthy(bool(preview.call(&"show_member", first, [] as Array[Dictionary])), "first member creates a presentation-only preview", failures)
	var active: CharacterPresentation = preview.get("active_preview") as CharacterPresentation
	var first_model := active.active_model as FakeCharacterModel if active != null else null
	TestAssertions.truthy(active != null and active.active_profile == first.class_definition.visual_profile, "preview uses the selected member class profile", failures)
	if first_model != null:
		TestAssertions.equal(first_model.body_preset, &"feminine", "preview uses the selected member body preset", failures)
		TestAssertions.equal(first_model.palette_id, &"blue", "preview uses the selected member palette", failures)
		TestAssertions.equal(first_model.primary_color, first.class_definition.color, "preview uses the selected member class color", failures)
	var first_instance_id := active.get_instance_id() if active != null else 0
	TestAssertions.truthy(bool(preview.call(&"show_member", first, [] as Array[Dictionary])), "unchanged member preview request remains valid", failures)
	TestAssertions.equal((preview.get("active_preview") as CharacterPresentation).get_instance_id(), first_instance_id, "unchanged member and equipment reuse the current presentation copy", failures)
	TestAssertions.truthy(bool(preview.call(&"show_member", second, [] as Array[Dictionary])), "second member replaces the presentation model", failures)
	var replacement: CharacterPresentation = preview.get("active_preview") as CharacterPresentation
	var host := preview.get_node("SubViewport/World/PreviewRoot")
	TestAssertions.equal(host.get_child_count(), 1, "member switching reuses one preview host with one model", failures)
	TestAssertions.truthy(replacement != null and replacement.get_instance_id() != first_instance_id, "member switching replaces the presentation copy", failures)
	TestAssertions.truthy(not is_instance_id_valid(first_instance_id), "replaced preview model is freed immediately", failures)
	preview.free()


func _test_clear_suspends_rendering_and_show_reenables(failures: Array[String]) -> void:
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	_attach_preview(preview)
	var subviewport := preview.get_node("SubViewport") as SubViewport
	var member := _member(8, &"feminine", &"blue", Color("3588d4"))
	TestAssertions.truthy(bool(preview.call(&"show_member", member, [] as Array[Dictionary])), "preview member renders before suspension", failures)
	TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "detached successful member preview keeps rendering suspended", failures)
	preview.call(&"clear")
	TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "clear suspends preview rendering", failures)
	TestAssertions.truthy(preview.get("active_preview") == null, "clear releases the active presentation while suspended", failures)
	TestAssertions.truthy(bool(preview.call(&"show_member", member, [] as Array[Dictionary])), "preview member rebuild succeeds after suspension", failures)
	TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "detached successful member rebuild keeps rendering suspended", failures)
	preview.free()


func _test_exact_color_change_replaces_preview(failures: Array[String]) -> void:
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	_attach_preview(preview)
	var first_color := Color(0.50001, 0.25, 0.75, 1.0)
	var second_color := Color(0.50002, 0.25, 0.75, 1.0)
	TestAssertions.equal(first_color.to_html(true), second_color.to_html(true), "exact-color fixture collides after HTML quantization", failures)
	TestAssertions.truthy(first_color != second_color, "exact-color fixture retains distinct typed values", failures)
	var member := _member(5, &"masculine", &"violet", first_color)
	TestAssertions.truthy(bool(preview.call(&"show_member", member, [] as Array[Dictionary])), "first exact member color renders", failures)
	var first_id := _active_preview_id(preview)
	member.class_definition.color = second_color
	TestAssertions.truthy(bool(preview.call(&"show_member", member, [] as Array[Dictionary])), "second exact member color renders", failures)
	TestAssertions.truthy(_active_preview_id(preview) != first_id, "distinct exact colors replace the preview even when HTML values collide", failures)
	preview.free()


func _test_same_id_profile_scene_change_replaces_preview(failures: Array[String]) -> void:
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	_attach_preview(preview)
	var first := _member(6, &"masculine", &"red", Color("d94f4f"))
	var second := _member(6, &"masculine", &"red", Color("d94f4f"))
	second.class_definition.visual_profile.presentation_scene = _packed_fake_model(failures)
	TestAssertions.equal(first.class_definition.visual_profile.id, second.class_definition.visual_profile.id, "profile-scene fixture preserves the same profile ID", failures)
	TestAssertions.truthy(first.class_definition.visual_profile != second.class_definition.visual_profile, "profile-scene fixture uses distinct profile resources", failures)
	TestAssertions.truthy(first.class_definition.visual_profile.presentation_scene != second.class_definition.visual_profile.presentation_scene, "profile-scene fixture changes the presentation scene resource", failures)
	TestAssertions.truthy(bool(preview.call(&"show_member", first, [] as Array[Dictionary])), "first same-ID profile renders", failures)
	var first_id := _active_preview_id(preview)
	TestAssertions.truthy(bool(preview.call(&"show_member", second, [] as Array[Dictionary])), "second same-ID profile renders", failures)
	TestAssertions.truthy(_active_preview_id(preview) != first_id, "same-ID profile with a different presentation scene replaces the preview", failures)
	preview.free()


func _test_same_id_visual_geometry_change_replaces_preview(failures: Array[String]) -> void:
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	_attach_preview(preview)
	var member := _member(7, &"masculine", &"red", Color("d94f4f"))
	var first_visual := _visual(&"same_visual", &"helmet")
	var second_visual := _visual(&"same_visual", &"helmet")
	second_visual.geometry_key = &"changed_geometry"
	var first_base := EquipmentBaseDefinition.new()
	first_base.id = &"same_base"
	first_base.presentation = first_visual
	var second_base := EquipmentBaseDefinition.new()
	second_base.id = &"same_base"
	second_base.presentation = second_visual
	var first_rows: Array[Dictionary] = [{"slot_id": &"helmet", "item_id": "same-item", "base_definition": first_base}]
	var second_rows: Array[Dictionary] = [{"slot_id": &"helmet", "item_id": "same-item", "base_definition": second_base}]
	TestAssertions.truthy(bool(preview.call(&"show_member", member, first_rows)), "first same-ID visual renders", failures)
	var first_id := _active_preview_id(preview)
	TestAssertions.truthy(bool(preview.call(&"show_member", member, second_rows)), "second same-ID visual renders", failures)
	TestAssertions.truthy(_active_preview_id(preview) != first_id, "same-ID visual with changed geometry replaces the preview", failures)
	preview.free()


func _test_preview_rotation_and_live_actor_isolation(failures: Array[String]) -> void:
	var arena_viewport := SubViewport.new()
	arena_viewport.own_world_3d = true
	arena_viewport.world_3d = World3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(arena_viewport)
	var root := Node3D.new()
	root.name = "CharacterEquipmentPreviewIsolation"
	arena_viewport.add_child(root)
	var member := _member(3, &"masculine", &"red", Color("d94f4f"))
	var leader := (load(LEADER_SCENE_PATH) as PackedScene).instantiate() as PartyActor
	root.add_child(leader)
	leader.configure(member)
	leader.position = Vector3(3.0, 0.0, -2.0)
	var health := leader.get_node("HealthComponent") as HealthComponent
	health.current_health = 37.0
	var live_parent := leader.get_parent()
	var live_transform := leader.transform
	var live_health := health.current_health
	var live_presentation := leader.get_node("Presentation") as CharacterPresentation
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	_attach_preview(preview)
	var subviewport := preview.get_node("SubViewport") as SubViewport
	TestAssertions.truthy(subviewport.own_world_3d, "equipment preview owns an isolated World3D", failures)
	TestAssertions.truthy(bool(preview.call(&"show_member", member, [] as Array[Dictionary])), "live member can be shown without using the actor node", failures)
	var preview_presentation := preview.get("active_preview") as CharacterPresentation
	TestAssertions.truthy(preview_presentation != live_presentation and preview_presentation.active_model != live_presentation.active_model, "preview creates only presentation copies", failures)
	TestAssertions.truthy(subviewport.world_3d != arena_viewport.world_3d, "preview viewport does not reuse the arena viewport world", failures)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	(preview.get_node("DragSurface") as Control).gui_input.emit(press)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(100000.0, 4000.0)
	(preview.get_node("DragSurface") as Control).gui_input.emit(drag)
	var mount := preview.get_node("SubViewport/World/PreviewRoot") as Node3D
	TestAssertions.truthy(mount.rotation.y >= -PI and mount.rotation.y <= PI, "preview drag stays within one full horizontal turn", failures)
	TestAssertions.near(mount.rotation.x, deg_to_rad(-8.0), 0.0001, "preview vertical angle remains fixed and safe", failures)
	TestAssertions.equal(preview.mouse_filter, Control.MOUSE_FILTER_STOP, "only pointer events over the preview enter its drag surface", failures)
	TestAssertions.equal(leader.get_parent(), live_parent, "preview never reparents the live actor", failures)
	TestAssertions.equal(leader.transform, live_transform, "preview rotation never changes the live actor transform", failures)
	TestAssertions.near(health.current_health, live_health, 0.001, "preview never changes live actor health", failures)
	preview.free()
	root.free()
	arena_viewport.free()


func _test_visual_resolution_keeps_disabled_items_and_falls_back_once(failures: Array[String]) -> void:
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	_attach_preview(preview)
	var member := _member(4, &"masculine", &"red", Color("d94f4f"))
	var helmet_visual := _visual(&"equipped_helmet", &"helmet")
	var helmet_base := EquipmentBaseDefinition.new()
	helmet_base.id = &"equipped_helmet"
	helmet_base.presentation = helmet_visual
	var rows: Array[Dictionary] = [
		{"slot_id": &"helmet", "item_id": "disabled-helmet", "detail": {"is_disabled": true}, "base_definition": helmet_base},
		{"slot_id": &"boots", "item_id": "missing-boots", "detail": {"base_definition_id": "missing_boots"}},
	]
	TestAssertions.truthy(bool(preview.call(&"show_member", member, rows)), "occupied preview rows render with fallback diagnostics", failures)
	var active := preview.get("active_preview") as CharacterPresentation
	var model := active.active_model as FakeCharacterModel if active != null else null
	if model != null:
		TestAssertions.equal(model.equipped.get(&"helmet"), &"equipped_helmet", "disabled equipment remains visually worn", failures)
		TestAssertions.truthy(not model.equipped.has(&"boots"), "missing boots visual retains the boots body fallback", failures)
	var diagnostics: PackedStringArray = preview.get("diagnostics")
	TestAssertions.equal(diagnostics, PackedStringArray(["PARTY_FORGE_PRESENTATION_FALLBACK slot=boots reason=missing_visual_definition fallback=body"]), "one deterministic diagnostic describes the missing slot visual", failures)
	preview.free()


func _test_class_preview_uses_production_profile_defaults(failures: Array[String]) -> void:
	var preview := _new_preview()
	var subviewport := preview.get_node("SubViewport") as SubViewport
	TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "new preview suspends rendering until a valid presentation is requested", failures)
	TestAssertions.truthy(_show_class(preview, FIGHTER_DEFINITION, failures), "real Fighter class builds a preview", failures)
	var active := preview.get("active_preview") as CharacterPresentation
	TestAssertions.truthy(active != null and active.active_profile == FIGHTER_DEFINITION.visual_profile, "class preview applies the production Fighter visual profile", failures)
	var model := _assert_exact_fighter_defaults(active, "class preview", failures)
	TestAssertions.equal(model.get("_primary_color") if model != null else Color.TRANSPARENT, FIGHTER_DEFINITION.color, "class preview applies the exact class color", failures)
	TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "detached valid class preview keeps rendering suspended", failures)
	var first_id := _active_preview_id(preview)
	TestAssertions.truthy(_show_class(preview, FIGHTER_DEFINITION, failures), "unchanged class request remains valid", failures)
	TestAssertions.equal(_active_preview_id(preview), first_id, "unchanged class request reuses its presentation", failures)
	preview.free()


func _test_class_and_member_mode_signatures_cannot_collide(failures: Array[String]) -> void:
	var preview := _new_preview()
	TestAssertions.truthy(_show_class(preview, FIGHTER_DEFINITION, failures), "class mode renders before a member request", failures)
	var class_id := _active_preview_id(preview)
	var class_active := preview.get("active_preview") as CharacterPresentation
	var class_model_id := class_active.active_model.get_instance_id() if class_active != null and class_active.active_model != null else 0
	TestAssertions.truthy(class_id != 0 and class_model_id != 0, "collision fixture has a class presentation and model before switching modes", failures)
	var member := PartyMemberState.new(0, FIGHTER_DEFINITION, false, "Signature Fixture")
	TestAssertions.truthy(bool(preview.call(&"show_member", member, [] as Array[Dictionary])), "member mode accepts the same Fighter definition with empty visuals", failures)
	var member_id := _active_preview_id(preview)
	TestAssertions.truthy(member_id != class_id, "mode prevents a same-Fighter member signature from reusing class presentation", failures)
	TestAssertions.truthy(not is_instance_id_valid(class_id) and not is_instance_id_valid(class_model_id), "mode switch frees the previous class presentation and model", failures)
	TestAssertions.truthy(_show_class(preview, FIGHTER_DEFINITION, failures), "class mode restores after member mode", failures)
	TestAssertions.truthy(_active_preview_id(preview) != member_id, "switching back to class mode replaces the member presentation", failures)
	preview.free()


func _test_class_defaults_do_not_inherit_explicit_member_equipment(failures: Array[String]) -> void:
	var preview := _new_preview()
	var member := PartyMemberState.new(12, FIGHTER_DEFINITION, false, "Explicit Equipment Fixture")
	var helmet := FIGHTER_DEFINITION.visual_profile.default_equipment[0].item as EquipmentBaseDefinition
	var member_rows: Array[Dictionary] = [{"slot_id": &"helmet", "item_id": "explicit-helmet", "base_definition": helmet}]
	TestAssertions.truthy(bool(preview.call(&"show_member", member, member_rows)), "member mode accepts explicit Fighter equipment", failures)
	_assert_exact_fighter_member_equipment(preview.get("active_preview") as CharacterPresentation, helmet, failures)
	TestAssertions.truthy(_show_class(preview, FIGHTER_DEFINITION, failures), "class mode restores after explicit member equipment", failures)
	_assert_exact_fighter_defaults(preview.get("active_preview") as CharacterPresentation, "restored class preview", failures)
	preview.free()


func _test_class_fallback_is_neutral_and_safe(failures: Array[String]) -> void:
	var preview := _new_preview()
	TestAssertions.truthy(_show_class(preview, RANGER_DEFINITION, failures), "valid class preview exists before an invalid request", failures)
	var previous_id := _active_preview_id(preview)
	var invalid_definition := ClassDefinition.new()
	invalid_definition.id = &"invalid_preview_fixture"
	invalid_definition.display_name = "Broken Preview"
	invalid_definition.visual_profile = CharacterVisualProfile.new()
	invalid_definition.visual_profile.id = &"invalid_preview_profile"
	TestAssertions.truthy(not _show_class(preview, invalid_definition, failures), "invalid class profile refuses to build a class presentation", failures)
	var fallback := preview.get_node_or_null("Fallback") as Control
	var silhouette := preview.get_node_or_null("Fallback/NeutralSilhouette") as TextureRect
	var detail := preview.get_node_or_null("Fallback/UnavailableDetail") as Label
	TestAssertions.truthy(preview.get("active_preview") == null, "invalid class never substitutes another class presentation", failures)
	TestAssertions.truthy(not is_instance_id_valid(previous_id), "invalid class releases the prior class presentation instead of substituting it", failures)
	TestAssertions.truthy(fallback != null and fallback.visible and silhouette != null and silhouette.visible, "invalid class displays the neutral silhouette", failures)
	TestAssertions.equal(detail.text if detail != null else "", "Preview unavailable.", "invalid class displays nontechnical unavailable copy", failures)
	TestAssertions.truthy(not (detail.text if detail != null else "").contains("invalid_preview_profile"), "fallback copy does not expose profile internals", failures)
	TestAssertions.truthy(_show_fallback(preview, &"not_available", "Class preview is unavailable.", failures), "fallback interface is available for safe presentation failures", failures)
	TestAssertions.equal(detail.text if detail != null else "", "Class preview is unavailable.", "safe fallback reason is shown as supplied", failures)
	preview.free()


func _test_class_preview_lifecycle_and_reduced_motion(failures: Array[String]) -> void:
	var preview := _new_preview()
	var subviewport := preview.get_node("SubViewport") as SubViewport
	TestAssertions.truthy(_show_class(preview, FIGHTER_DEFINITION, failures), "first class preview is valid", failures)
	var fighter_id := _active_preview_id(preview)
	var fighter := preview.get("active_preview") as CharacterPresentation
	var fighter_model_id := fighter.active_model.get_instance_id() if fighter != null and fighter.active_model != null else 0
	TestAssertions.truthy(fighter_id != 0 and fighter_model_id != 0, "class lifecycle fixture has a presentation and model before class replacement", failures)
	TestAssertions.truthy(_show_class(preview, RANGER_DEFINITION, failures), "second production class preview is valid", failures)
	TestAssertions.truthy(_active_preview_id(preview) != fighter_id, "changing class replaces the active presentation", failures)
	TestAssertions.truthy(not is_instance_id_valid(fighter_id) and not is_instance_id_valid(fighter_model_id), "class replacement frees the prior presentation and model", failures)
	TestAssertions.truthy(_set_reduced_motion(preview, true, failures), "reduced-motion interface is available", failures)
	TestAssertions.truthy(preview.get("_reduced_motion") == true, "reduced-motion state is retained", failures)
	TestAssertions.truthy(preview.get_node_or_null("PreviewTransition") == null, "reduced motion avoids ornamental preview transitions", failures)
	var active_before_clear := preview.get("active_preview") as CharacterPresentation
	var active_before_clear_id := active_before_clear.get_instance_id() if active_before_clear != null else 0
	var model_before_clear_id := active_before_clear.active_model.get_instance_id() if active_before_clear != null and active_before_clear.active_model != null else 0
	TestAssertions.truthy(active_before_clear_id != 0 and model_before_clear_id != 0, "clear lifecycle fixture has a presentation and model before clearing", failures)
	preview.call(&"clear")
	TestAssertions.truthy(preview.get("active_preview") == null, "clear removes a class presentation", failures)
	TestAssertions.truthy(not is_instance_id_valid(active_before_clear_id) and not is_instance_id_valid(model_before_clear_id), "clear frees the active class presentation and model", failures)
	TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "clear disables class preview rendering", failures)
	preview.free()


func _test_all_class_previews_share_centered_frame_and_action_rotation(failures: Array[String]) -> void:
	var preview := _new_preview()
	var expected_center_y := NAN
	for definition: ClassDefinition in GameCatalog.load_defaults().classes:
		TestAssertions.truthy(_show_class(preview, definition, failures), "%s class preview renders for framing" % definition.id, failures)
		var active := preview.get("active_preview") as CharacterPresentation
		var bounds := active.visual_bounds() if active != null else AABB()
		var framed_center := bounds.get_center() + (active.position if active != null else Vector3.ZERO)
		if is_nan(expected_center_y):
			expected_center_y = framed_center.y
		TestAssertions.near(framed_center.x, 0.0, 0.001, "%s preview is horizontally centered" % definition.id, failures)
		TestAssertions.near(framed_center.z, 0.0, 0.001, "%s preview rotation pivot is depth-centered" % definition.id, failures)
		TestAssertions.near(framed_center.y, expected_center_y, 0.001, "%s preview shares the canonical vertical framing center" % definition.id, failures)
	TestAssertions.equal(preview.focus_mode, Control.FOCUS_ALL, "class preview is keyboard/controller focusable", failures)
	var mount := preview.get_node("SubViewport/World/PreviewRoot") as Node3D
	var before := mount.rotation.y
	preview.call(&"_rotate_from_action", 1.0)
	TestAssertions.truthy(not is_equal_approx(mount.rotation.y, before), "class preview exposes deterministic directional rotation", failures)
	preview.free()


func _member(member_id: int, body_id: StringName, palette_id: StringName, color: Color) -> PartyMemberState:
	var profile := CharacterVisualProfile.new()
	profile.id = StringName("preview_profile_%d" % member_id)
	profile.presentation_scene = load(FIXTURE_SCENE_PATH) as PackedScene
	profile.default_body_preset = body_id
	profile.default_palette_id = palette_id
	profile.palette_colors = {palette_id: color}
	profile.required_animation_names = [&"idle", &"walk"]
	var definition := ClassDefinition.new()
	definition.id = StringName("preview_class_%d" % member_id)
	definition.display_name = "Preview Class %d" % member_id
	definition.color = color
	definition.visual_profile = profile
	return PartyMemberState.new(member_id, definition, member_id == 1, "Preview %d" % member_id)


func _visual(visual_id: StringName, slot_id: StringName) -> EquipmentVisualDefinition:
	var definition := EquipmentVisualDefinition.new()
	definition.id = visual_id
	definition.slot_id = slot_id
	definition.geometry_key = visual_id
	definition.visual_channels = [&"geometry"]
	return definition


func _packed_fake_model(failures: Array[String]) -> PackedScene:
	var scene := PackedScene.new()
	var model := FakeCharacterModel.new()
	TestAssertions.equal(scene.pack(model), OK, "distinct profile presentation scene packs", failures)
	model.free()
	return scene


func _active_preview_id(preview: Control) -> int:
	var active := preview.get("active_preview") as CharacterPresentation
	return active.get_instance_id() if active != null else 0


func _new_preview() -> Control:
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	_attach_preview(preview)
	return preview


func _attach_preview(preview: Control) -> void:
	(Engine.get_main_loop() as SceneTree).root.add_child(preview)


func _assert_exact_fighter_defaults(active: CharacterPresentation, label: String, failures: Array[String]) -> ForgeHumanoidModel:
	var model := _assert_production_fighter_model(active, label, failures)
	TestAssertions.equal(model.equipped_definitions.size() if model != null else -1, FIGHTER_DEFINITION.visual_profile.default_equipment.size(), "%s has every Fighter default equipment definition" % label, failures)
	for entry: EquipmentLoadoutEntry in FIGHTER_DEFINITION.visual_profile.default_equipment:
		var actual: EquipmentVisualDefinition = model.equipped_definitions.get(entry.slot_id) as EquipmentVisualDefinition if model != null else null
		TestAssertions.equal(actual, entry.item.presentation, "%s retains exact Fighter default %s" % [label, entry.slot_id], failures)
	return model


func _assert_exact_fighter_member_equipment(active: CharacterPresentation, helmet: EquipmentBaseDefinition, failures: Array[String]) -> ForgeHumanoidModel:
	var model := _assert_production_fighter_model(active, "explicit member preview", failures)
	TestAssertions.equal(model.equipped_definitions.size() if model != null else -1, 1, "explicit member preview has exactly one equipment definition", failures)
	TestAssertions.equal(model.equipped_definitions.get(&"helmet") if model != null else null, helmet.presentation, "explicit member preview retains the exact requested helmet definition", failures)
	return model


func _assert_production_fighter_model(active: CharacterPresentation, label: String, failures: Array[String]) -> ForgeHumanoidModel:
	var active_model := active.active_model if active != null else null
	TestAssertions.truthy(active != null and active_model != null, "%s creates an active production model", failures)
	TestAssertions.equal(active_model.get_script() if active_model != null else null, FORGE_HUMANOID_MODEL_SCRIPT, "%s uses the exact ForgeHumanoidModel script", failures)
	return active_model as ForgeHumanoidModel


func _show_class(preview: Control, definition: ClassDefinition, failures: Array[String]) -> bool:
	TestAssertions.truthy(preview.has_method(&"show_class"), "character preview exposes isolated class mode", failures)
	return bool(preview.call(&"show_class", definition)) if preview.has_method(&"show_class") else false


func _show_fallback(preview: Control, class_id: StringName, safe_reason: String, failures: Array[String]) -> bool:
	TestAssertions.truthy(preview.has_method(&"show_fallback"), "character preview exposes safe fallback mode", failures)
	if not preview.has_method(&"show_fallback"):
		return false
	preview.call(&"show_fallback", class_id, safe_reason)
	return true


func _set_reduced_motion(preview: Control, enabled: bool, failures: Array[String]) -> bool:
	TestAssertions.truthy(preview.has_method(&"set_reduced_motion"), "character preview exposes reduced-motion configuration", failures)
	if not preview.has_method(&"set_reduced_motion"):
		return false
	preview.call(&"set_reduced_motion", enabled)
	return true
