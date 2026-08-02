extends RefCounted

const ADAPTER_SCENE_PATH := "res://scenes/characters/presentation/character_presentation.tscn"
const FIXTURE_SCENE_PATH := "res://tests/fixtures/fake_character_model.tscn"

class MissingHitWeightModel extends Node3D:
	func set_body_preset(_value: StringName) -> bool: return true
	func set_palette(_value: StringName, _color: Color) -> bool: return true
	func apply_equipment_visual(_slot_id: StringName, _definition: EquipmentVisualDefinition) -> bool: return true
	func clear_equipment_visual(_slot_id: StringName) -> bool: return true
	func play_action(_animation_id: StringName) -> bool: return true
	func set_downed(_value: bool) -> void: pass

class MissingDownedModel extends Node3D:
	func set_body_preset(_value: StringName) -> bool: return true
	func set_palette(_value: StringName, _color: Color) -> bool: return true
	func apply_equipment_visual(_slot_id: StringName, _definition: EquipmentVisualDefinition) -> bool: return true
	func clear_equipment_visual(_slot_id: StringName) -> bool: return true
	func play_action(_animation_id: StringName) -> bool: return true
	func set_hit_weight(_value: float) -> void: pass

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(ADAPTER_SCENE_PATH), "character presentation scene exists", failures)
	if not ResourceLoader.exists(ADAPTER_SCENE_PATH):
		return failures
	_test_profile_application_and_feedback(failures)
	_test_invalid_equipment_slot_is_not_forwarded(failures)
	_test_invalid_profile_keeps_fallback_visible(failures)
	_test_incomplete_feedback_api_keeps_fallback_visible(failures)
	_test_instances_keep_model_state_independent(failures)
	_test_loadout_entry_owns_supported_ring_side(failures)
	_test_item_base_presentations_validate_in_each_profile_array(failures)
	_test_default_item_base_validates_its_own_contract(failures)
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

func _test_incomplete_feedback_api_keeps_fallback_visible(failures: Array[String]) -> void:
	var fixture_cases := [
		{&"name": "MissingHitWeight", &"model": MissingHitWeightModel.new(), &"method": &"set_hit_weight"},
		{&"name": "MissingDowned", &"model": MissingDownedModel.new(), &"method": &"set_downed"},
	]
	for fixture: Dictionary in fixture_cases:
		var root := _new_root("CharacterPresentation%sTest" % fixture[&"name"])
		var presentation := _new_presentation(root)
		var packed_scene := PackedScene.new()
		var model := fixture[&"model"] as Node3D
		TestAssertions.equal(packed_scene.pack(model), OK, "%s fixture packs" % fixture[&"name"], failures)
		model.free()
		var profile := _profile_for_scene(packed_scene, StringName("test_%s" % String(fixture[&"name"]).to_snake_case()))
		TestAssertions.truthy(not presentation.apply_profile(profile, Color.WHITE), "%s model is rejected during activation" % fixture[&"name"], failures)
		var fallback := root.get_node("Fallback") as MeshInstance3D
		TestAssertions.truthy(fallback.visible, "%s model keeps fallback visible" % fixture[&"name"], failures)
		TestAssertions.equal(presentation.active_model, null, "%s model is cleared after rejected activation" % fixture[&"name"], failures)
		TestAssertions.truthy(presentation.logged_errors.has(StringName("missing_%s" % fixture[&"method"])), "%s failure uses bounded presentation diagnostic" % fixture[&"name"], failures)
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

func _test_loadout_entry_owns_supported_ring_side(failures: Array[String]) -> void:
	var root := _new_root("CharacterPresentationRingLoadoutTest")
	var presentation := _new_presentation(root)
	var ring := _item_base(&"test_ring", [&"ring_left", &"ring_right"])
	var entry := EquipmentLoadoutEntry.new()
	entry.slot_id = &"ring_right"
	entry.item = ring
	var profile := _profile_for_scene(load(FIXTURE_SCENE_PATH) as PackedScene, &"ring_loadout")
	profile.default_equipment = [entry]
	TestAssertions.truthy(presentation.apply_profile(profile, Color.WHITE), "loadout applies a ring to its selected supported side", failures)
	TestAssertions.truthy(presentation.apply_equipment_visual(&"ring_right", ring.presentation), "runtime ring selection accepts a supported non-primary side", failures)
	var model := presentation.active_model as FakeCharacterModel
	TestAssertions.equal(model.equipped.get(&"ring_right") if model != null else &"", &"test_ring", "ring base does not own the selected side", failures)
	root.free()

func _test_item_base_presentations_validate_in_each_profile_array(failures: Array[String]) -> void:
	var default_profile := _profile_for_scene(load(FIXTURE_SCENE_PATH) as PackedScene, &"invalid_default_item_presentation")
	var default_item := _item_base(&"default_invalid", [&"main_hand"])
	default_item.presentation.icon_master = null
	var entry := EquipmentLoadoutEntry.new()
	entry.slot_id = &"main_hand"
	entry.item = default_item
	default_profile.default_equipment = [entry]
	TestAssertions.truthy(_errors_contain(default_profile.validate(), "icon pair is incomplete"), "default item presentation validates full visual contract", failures)
	var available_profile := _profile_for_scene(load(FIXTURE_SCENE_PATH) as PackedScene, &"invalid_available_item_presentation")
	var available_item := _item_base(&"available_invalid", [&"main_hand"])
	available_item.presentation.readability_channels = []
	available_profile.available_equipment = [available_item]
	TestAssertions.truthy(_errors_contain(available_profile.validate(), "readability channels are empty"), "available item presentation validates full visual contract", failures)

func _test_default_item_base_validates_its_own_contract(failures: Array[String]) -> void:
	var profile := _profile_for_scene(load(FIXTURE_SCENE_PATH) as PackedScene, &"invalid_default_item_base")
	var item := _item_base(&"invalid_default_base", [&"main_hand"])
	item.display_name = ""
	var entry := EquipmentLoadoutEntry.new()
	entry.slot_id = &"main_hand"
	entry.item = item
	profile.default_equipment = [entry]
	TestAssertions.truthy(_errors_contain(profile.validate(), "display name is empty"), "default item validates base contract in addition to loadout and visual contracts", failures)

func _item_base(item_id: StringName, supported_slots: Array[StringName]) -> EquipmentBaseDefinition:
	var visual := EquipmentVisualDefinition.new()
	visual.id = item_id
	visual.slot_id = supported_slots[0]
	visual.supported_slot_ids = supported_slots
	visual.body_preset_ids = [&"masculine", &"feminine"]
	visual.icon_master = _icon()
	visual.icon_runtime = _icon()
	visual.combat_visible = false
	visual.readability_channels = [&"silhouette"]
	var item := EquipmentBaseDefinition.new()
	item.id = item_id
	item.display_name = "Test Item"
	item.item_type_id = &"test"
	item.compatible_slot_ids = supported_slots
	item.implicit_family_id = &"test"
	item.presentation = visual
	return item

func _icon() -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func _errors_contain(errors: PackedStringArray, expected: String) -> bool:
	for error: String in errors:
		if expected in error:
			return true
	return false

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
	profile.required_animation_names = [&"idle", &"walk", &"attack_slash", &"hit_flinch"]
	profile.attack_animation_by_id = {&"fighter_cleave": &"attack_slash"}
	return profile

func _profile_for_scene(scene: PackedScene, profile_id: StringName) -> CharacterVisualProfile:
	var profile := CharacterVisualProfile.new()
	profile.id = profile_id
	profile.presentation_scene = scene
	profile.default_body_preset = &"masculine"
	profile.default_palette_id = &"red"
	profile.palette_colors = {&"red": Color.WHITE}
	profile.required_animation_names = [&"idle", &"walk"]
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
