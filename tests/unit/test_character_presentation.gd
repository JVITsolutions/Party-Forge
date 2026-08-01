extends RefCounted

const ADAPTER_SCENE_PATH := "res://scenes/characters/presentation/character_presentation.tscn"
const FIXTURE_SCENE_PATH := "res://tests/fixtures/fake_character_model.tscn"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(ADAPTER_SCENE_PATH), "character presentation scene exists", failures)
	if not ResourceLoader.exists(ADAPTER_SCENE_PATH):
		return failures
	_test_profile_application_and_feedback(failures)
	_test_invalid_equipment_slot_is_not_forwarded(failures)
	_test_invalid_profile_keeps_fallback_visible(failures)
	_test_instances_keep_model_state_independent(failures)
	return failures

func _test_profile_application_and_feedback(failures: Array[String]) -> void:
	var root := _new_root("CharacterPresentationTest")
	var presentation := _new_presentation(root)
	var profile := _valid_profile()
	var primary_color := Color("d94f4f")
	TestAssertions.truthy(presentation.apply_profile(profile, primary_color), "valid profile applies", failures)
	var model := presentation.active_model as FakeCharacterModel
	TestAssertions.truthy(model != null, "profile instantiates fake model", failures)
	if model != null:
		TestAssertions.equal(model.body_preset, &"masculine", "profile forwards body preset", failures)
		TestAssertions.equal(model.palette_id, &"red", "profile forwards palette id", failures)
		TestAssertions.equal(model.primary_color, primary_color, "profile forwards primary color", failures)
		TestAssertions.equal(model.equipped.get(&"main_hand"), &"test_sword", "profile equips default visual", failures)
		presentation.play_attack(_fighter_cleave())
		TestAssertions.equal(model.played.back(), &"attack_slash", "fighter cleave maps to attack slash", failures)
		presentation.flash_hit()
		TestAssertions.near(model.hit_weight, 1.0, 0.001, "flash hit sets model hit weight", failures)
		presentation.advance_feedback(0.11)
		TestAssertions.near(model.hit_weight, 0.0, 0.001, "feedback restores hit weight after duration", failures)
		presentation.set_downed(true)
		TestAssertions.truthy(model.downed, "downed state forwards to model", failures)
	root.free()

func _test_invalid_equipment_slot_is_not_forwarded(failures: Array[String]) -> void:
	var root := _new_root("CharacterPresentationInvalidSlotTest")
	var presentation := _new_presentation(root)
	TestAssertions.truthy(presentation.apply_profile(_valid_profile(), Color.WHITE), "profile applies before equipment customization", failures)
	var model := presentation.active_model as FakeCharacterModel
	var charm := EquipmentVisualDefinition.new()
	charm.id = &"test_charm"
	charm.slot_id = &"charm"
	charm.geometry_key = &"test_charm"
	charm.visual_channels = [&"geometry"]
	TestAssertions.truthy(not presentation.apply_equipment_visual(&"charm", charm), "invalid equipment slot is rejected", failures)
	if model != null:
		TestAssertions.truthy(not model.equipped.has(&"charm"), "invalid equipment slot is not forwarded to model", failures)
	root.free()

func _test_invalid_profile_keeps_fallback_visible(failures: Array[String]) -> void:
	var root := _new_root("CharacterPresentationFallbackTest")
	var presentation := _new_presentation(root)
	var invalid_profile := CharacterVisualProfile.new()
	invalid_profile.id = &"invalid"
	TestAssertions.truthy(not presentation.apply_profile(invalid_profile, Color.WHITE), "invalid profile is rejected", failures)
	var fallback := root.get_node("Fallback") as MeshInstance3D
	TestAssertions.truthy(fallback.visible, "invalid profile leaves fallback visible", failures)
	root.free()

func _test_instances_keep_model_state_independent(failures: Array[String]) -> void:
	var root := _new_root("CharacterPresentationIsolationTest")
	var first := _new_presentation(root)
	var second := _new_presentation(root)
	var profile := _valid_profile()
	TestAssertions.truthy(first.apply_profile(profile, Color.RED), "first adapter applies profile", failures)
	TestAssertions.truthy(second.apply_profile(profile, Color.BLUE), "second adapter applies profile", failures)
	var first_model := first.active_model as FakeCharacterModel
	var second_model := second.active_model as FakeCharacterModel
	TestAssertions.truthy(first_model != second_model, "adapter instances own independent models", failures)
	if first_model != null and second_model != null:
		TestAssertions.truthy(first_model.primary_color != second_model.primary_color, "adapter instances keep palette material state independent", failures)
	root.free()

func _valid_profile() -> CharacterVisualProfile:
	var sword := EquipmentVisualDefinition.new()
	sword.id = &"test_sword"
	sword.slot_id = &"main_hand"
	sword.geometry_key = &"test_sword"
	sword.visual_channels = [&"geometry"]
	var profile := CharacterVisualProfile.new()
	profile.id = &"test_profile"
	profile.presentation_scene = load(FIXTURE_SCENE_PATH) as PackedScene
	profile.default_body_preset = &"masculine"
	profile.default_palette_id = &"red"
	profile.palette_colors = {&"red": Color("d94f4f")}
	profile.default_equipment_visuals = [sword]
	profile.required_animation_names = [&"idle", &"attack_slash", &"hit_flinch"]
	profile.attack_animation_by_id = {&"fighter_cleave": &"attack_slash"}
	return profile

func _fighter_cleave() -> AttackDefinition:
	var attack := AttackDefinition.new()
	attack.id = &"fighter_cleave"
	return attack

func _new_presentation(root: Node3D) -> CharacterPresentation:
	var fallback := MeshInstance3D.new()
	fallback.name = &"Fallback"
	root.add_child(fallback)
	var presentation := (load(ADAPTER_SCENE_PATH) as PackedScene).instantiate() as CharacterPresentation
	presentation.fallback_mesh_path = NodePath("../Fallback")
	root.add_child(presentation)
	return presentation

func _new_root(root_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root
