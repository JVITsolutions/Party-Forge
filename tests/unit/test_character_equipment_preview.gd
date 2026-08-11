extends RefCounted

const PREVIEW_SCENE_PATH := "res://scenes/ui/ledger/character_equipment_preview.tscn"
const LEADER_SCENE_PATH := "res://scenes/characters/leader.tscn"
const FIXTURE_SCENE_PATH := "res://tests/fixtures/fake_character_model.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(PREVIEW_SCENE_PATH), "character equipment preview scene exists", failures)
	if not ResourceLoader.exists(PREVIEW_SCENE_PATH):
		return failures
	_test_member_identity_and_reusable_host(failures)
	_test_preview_rotation_and_live_actor_isolation(failures)
	_test_visual_resolution_keeps_disabled_items_and_falls_back_once(failures)
	return failures


func _test_member_identity_and_reusable_host(failures: Array[String]) -> void:
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(preview)
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


func _test_preview_rotation_and_live_actor_isolation(failures: Array[String]) -> void:
	var root := Node3D.new()
	root.name = "CharacterEquipmentPreviewIsolation"
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
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
	(Engine.get_main_loop() as SceneTree).root.add_child(preview)
	TestAssertions.truthy(bool(preview.call(&"show_member", member, [] as Array[Dictionary])), "live member can be shown without using the actor node", failures)
	var preview_presentation := preview.get("active_preview") as CharacterPresentation
	TestAssertions.truthy(preview_presentation != live_presentation and preview_presentation.active_model != live_presentation.active_model, "preview creates only presentation copies", failures)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	preview.call(&"_gui_input", press)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(100000.0, 4000.0)
	preview.call(&"_gui_input", drag)
	var mount := preview.get_node("SubViewport/World/PreviewRoot") as Node3D
	TestAssertions.truthy(mount.rotation.y >= -PI and mount.rotation.y <= PI, "preview drag stays within one full horizontal turn", failures)
	TestAssertions.near(mount.rotation.x, deg_to_rad(-8.0), 0.0001, "preview vertical angle remains fixed and safe", failures)
	TestAssertions.equal(preview.mouse_filter, Control.MOUSE_FILTER_STOP, "only pointer events over the preview enter its drag surface", failures)
	TestAssertions.equal(leader.get_parent(), live_parent, "preview never reparents the live actor", failures)
	TestAssertions.equal(leader.transform, live_transform, "preview rotation never changes the live actor transform", failures)
	TestAssertions.near(health.current_health, live_health, 0.001, "preview never changes live actor health", failures)
	preview.free()
	root.free()


func _test_visual_resolution_keeps_disabled_items_and_falls_back_once(failures: Array[String]) -> void:
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(preview)
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
