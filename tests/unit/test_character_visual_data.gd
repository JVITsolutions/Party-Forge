extends RefCounted

const EXPECTED_SLOTS: Array[StringName] = [
	&"helmet", &"body_armour", &"legs", &"gloves", &"boots", &"amulet",
	&"ring_left", &"ring_right", &"belt", &"main_hand", &"off_hand",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.equal(EquipmentSlotCatalog.SLOT_IDS, EXPECTED_SLOTS, "PoE 1 visual slot order", failures)
	for slot_id: StringName in EXPECTED_SLOTS:
		TestAssertions.truthy(EquipmentSlotCatalog.is_valid(slot_id), "registered slot %s" % slot_id, failures)
	TestAssertions.truthy(not EquipmentSlotCatalog.is_valid(&"charm"), "future charm slot is rejected", failures)

	var sword := EquipmentVisualDefinition.new()
	sword.id = &"forge_vanguard_sword"
	sword.slot_id = &"main_hand"
	sword.geometry_key = &"forge_vanguard_sword"
	sword.visual_channels = [&"geometry"]
	TestAssertions.equal(sword.validate(), PackedStringArray(), "valid sword visual", failures)

	var invalid := EquipmentVisualDefinition.new()
	invalid.id = &"invalid_charm"
	invalid.slot_id = &"charm"
	TestAssertions.truthy(invalid.validate().size() >= 2, "invalid slot and empty channels are rejected", failures)
	TestAssertions.truthy(_errors_contain(invalid.validate(), "geometry key is empty"), "empty equipment geometry key is rejected", failures)

	var profile := CharacterVisualProfile.new()
	profile.id = &"forge_vanguard"
	profile.default_body_preset = &"masculine"
	profile.default_palette_id = &"red"
	profile.palette_colors = {&"red": Color("d94f4f"), &"blue": Color("4f78d9"), &"green": Color("4faf72")}
	profile.default_equipment_visuals = [sword]
	profile.available_equipment_visuals = [sword]
	profile.required_animation_names = [&"idle", &"attack_slash", &"attack_combo", &"hit_flinch"]
	profile.attack_animation_by_id = {&"fighter_cleave": &"attack_slash"}
	TestAssertions.truthy(profile.validate().has("profile forge_vanguard presentation scene is missing"), "scene is required", failures)
	_assert_walk_action_contract(failures)

	var class_definition := ClassDefinition.new()
	class_definition.id = &"test"
	class_definition.display_name = "Test"
	class_definition.traits = [&"martial"]
	class_definition.primary_attack = _valid_attack()
	class_definition.visual_profile = profile
	var has_visual_profile_error := false
	for reason: String in class_definition.validate():
		if "visual profile" in reason:
			has_visual_profile_error = true
	TestAssertions.truthy(has_visual_profile_error, "class forwards profile validation", failures)

	var hammer := EquipmentVisualDefinition.new()
	hammer.id = &"forge_vanguard_hammer"
	hammer.slot_id = &"main_hand"
	hammer.geometry_key = &"forge_vanguard_hammer"
	hammer.visual_channels = [&"geometry"]
	profile.available_equipment_visuals = [sword, hammer]
	TestAssertions.truthy(not _errors_contain(profile.validate(), "duplicate available equipment slot"), "multiple available main-hand variants are accepted", failures)
	TestAssertions.truthy(profile.has_method(&"get_available_equipment_visual_by_id"), "equipment ID lookup exists", failures)
	TestAssertions.truthy(profile.has_method(&"get_available_equipment_visuals_for_slot"), "slot variant lookup exists", failures)
	if profile.has_method(&"get_available_equipment_visual_by_id"):
		TestAssertions.equal(profile.call(&"get_available_equipment_visual_by_id", &"forge_vanguard_hammer"), hammer, "hammer resolves by equipment ID", failures)
		TestAssertions.equal(profile.call(&"get_available_equipment_visual_by_id", &"missing_item"), null, "unknown equipment ID returns null", failures)
	if profile.has_method(&"get_available_equipment_visuals_for_slot"):
		var main_hand_variants: Array = profile.call(&"get_available_equipment_visuals_for_slot", &"main_hand")
		TestAssertions.equal(main_hand_variants.size(), 2, "main hand exposes sword and hammer", failures)
		if main_hand_variants.size() >= 2:
			TestAssertions.equal(main_hand_variants[0], sword, "legacy first main-hand variant remains sword", failures)
			TestAssertions.equal(main_hand_variants[1], hammer, "second main-hand variant is hammer", failures)
		var charm_variants: Array = profile.call(&"get_available_equipment_visuals_for_slot", &"charm")
		TestAssertions.truthy(charm_variants.is_empty(), "unknown slot returns an empty variant array", failures)

	var duplicate_default := CharacterVisualProfile.new()
	duplicate_default.id = &"duplicate_default"
	duplicate_default.default_palette_id = &"red"
	duplicate_default.palette_colors = {&"red": Color.WHITE}
	duplicate_default.default_equipment_visuals = [sword, hammer]
	TestAssertions.truthy(_errors_contain(duplicate_default.validate(), "duplicate default equipment slot main_hand"), "default equipment still rejects two main-hand items", failures)

	var duplicate_id := CharacterVisualProfile.new()
	duplicate_id.id = &"duplicate_id"
	duplicate_id.default_palette_id = &"red"
	duplicate_id.palette_colors = {&"red": Color.WHITE}
	var duplicate_id_hammer := EquipmentVisualDefinition.new()
	duplicate_id_hammer.id = sword.id
	duplicate_id_hammer.slot_id = &"main_hand"
	duplicate_id_hammer.geometry_key = hammer.geometry_key
	duplicate_id_hammer.visual_channels = [&"geometry"]
	duplicate_id.available_equipment_visuals = [sword, duplicate_id_hammer]
	TestAssertions.truthy(_errors_contain(duplicate_id.validate(), "duplicate available equipment id forge_vanguard_sword"), "available equipment rejects duplicate IDs", failures)

	var duplicate_geometry := CharacterVisualProfile.new()
	duplicate_geometry.id = &"duplicate_geometry"
	duplicate_geometry.default_palette_id = &"red"
	duplicate_geometry.palette_colors = {&"red": Color.WHITE}
	var duplicate_geometry_hammer := EquipmentVisualDefinition.new()
	duplicate_geometry_hammer.id = hammer.id
	duplicate_geometry_hammer.slot_id = &"main_hand"
	duplicate_geometry_hammer.geometry_key = sword.geometry_key
	duplicate_geometry_hammer.visual_channels = [&"geometry"]
	duplicate_geometry.available_equipment_visuals = [sword, duplicate_geometry_hammer]
	TestAssertions.truthy(_errors_contain(duplicate_geometry.validate(), "duplicate available geometry key forge_vanguard_sword"), "available equipment rejects duplicate geometry keys", failures)

	var empty_available := CharacterVisualProfile.new()
	empty_available.id = &"empty_available"
	empty_available.default_palette_id = &"red"
	empty_available.palette_colors = {&"red": Color.WHITE}
	empty_available.available_equipment_visuals = []
	TestAssertions.truthy(not _errors_contain(empty_available.validate(), "available equipment"), "empty available equipment remains valid", failures)
	_assert_production_head_and_fit_contracts(failures)
	return failures

func _assert_walk_action_contract(failures: Array[String]) -> void:
	var profile := CharacterVisualProfile.new()
	profile.id = &"forge_vanguard"
	profile.presentation_scene = PackedScene.new()
	profile.default_body_preset = &"masculine"
	profile.default_palette_id = &"red"
	profile.palette_colors = {&"red": Color("d94f4f")}
	var property_names: Array[StringName] = []
	for property: Dictionary in profile.get_property_list():
		property_names.append(StringName(property[&"name"]))
	var exposes_walk := &"walk_action_id" in property_names
	TestAssertions.truthy(exposes_walk, "profile exposes a reusable walk action id", failures)
	if not exposes_walk:
		return
	profile.set(&"idle_action_id", &"idle")
	profile.set(&"walk_action_id", &"walk")
	profile.required_animation_names = [&"idle", &"walk", &"attack_slash", &"attack_combo", &"hit_flinch"]
	TestAssertions.truthy(profile.validate().is_empty(), "profile accepts required idle and walk actions", failures)
	profile.set(&"walk_action_id", &"missing_walk")
	TestAssertions.truthy(
		profile.validate().has("profile forge_vanguard walk animation missing_walk is missing"),
		"profile rejects an undeclared walk action",
		failures
	)


func _assert_production_head_and_fit_contracts(failures: Array[String]) -> void:
	var legacy_profile := _minimal_profile(&"legacy_profile")
	TestAssertions.equal(legacy_profile.validate(), PackedStringArray(), "legacy profile remains valid without class heads", failures)
	var profile_properties := _property_names(legacy_profile)
	TestAssertions.truthy(&"class_heads" in profile_properties, "profile exposes class head mappings", failures)
	TestAssertions.truthy(legacy_profile.has_method(&"head_for_body"), "profile resolves a head by body preset", failures)
	if &"class_heads" not in profile_properties or not legacy_profile.has_method(&"head_for_body"):
		return

	var masculine := _head(&"paladin_masculine_head", &"paladin", &"masculine")
	var feminine := _head(&"paladin_feminine_head", &"paladin", &"feminine")
	var profile := _minimal_profile(&"paladin")
	profile.class_heads = [masculine, feminine]
	TestAssertions.equal(profile.validate(), PackedStringArray(), "profile accepts one head for each body preset", failures)
	TestAssertions.equal(profile.call(&"head_for_body", &"masculine"), masculine, "masculine class head resolves", failures)
	TestAssertions.equal(profile.call(&"head_for_body", &"feminine"), feminine, "feminine class head resolves", failures)
	TestAssertions.equal(profile.call(&"head_for_body", &"shared"), null, "unsupported body head does not resolve", failures)

	profile.class_heads = [masculine]
	TestAssertions.truthy(_errors_contain(profile.validate(), "requires exactly one masculine and one feminine head"), "partial head mapping rejects", failures)
	profile.class_heads = [masculine, masculine]
	TestAssertions.truthy(_errors_contain(profile.validate(), "requires exactly one masculine and one feminine head"), "duplicate body head mapping rejects", failures)
	profile.class_heads = [masculine, null]
	TestAssertions.truthy(_errors_contain(profile.validate(), "has null class head"), "null head mapping rejects", failures)

	var fit := EquipmentBodyFitDescriptor.new()
	fit.body_preset_id = &"masculine"
	fit.presentation_scene = _packed_scene()
	fit.mesh_root_paths = [NodePath(".")]
	var fit_properties := _property_names(fit)
	TestAssertions.truthy(&"headwear_fit" in fit_properties, "body fit exposes headwear metadata", failures)
	TestAssertions.truthy(&"necklace_anchor_paths" in fit_properties, "body fit exposes necklace anchors", failures)
	var headwear_script := load("res://scripts/presentation/headwear_fit_descriptor.gd") as Script
	TestAssertions.truthy(headwear_script != null, "headwear contract loads", failures)
	if &"headwear_fit" not in fit_properties or &"necklace_anchor_paths" not in fit_properties or headwear_script == null:
		return
	var headwear: Resource = headwear_script.new()
	headwear.set(&"category", &"full_helmet")
	headwear.set(&"compatible_envelope_ids", Array([&"pf_head_masculine_v1"], TYPE_STRING_NAME, "", null))
	headwear.set(&"hide_head_region_ids", Array([&"scalp", &"hair", &"ears"], TYPE_STRING_NAME, "", null))
	fit.set(&"headwear_fit", headwear)
	fit.set(&"necklace_anchor_paths", Array([NodePath("Skeleton3D/NecklaceNeck"), NodePath("Skeleton3D/NecklaceSternum")], TYPE_NODE_PATH, "", null))
	TestAssertions.equal(fit.validate(), PackedStringArray(), "body fit accepts optional headwear and necklace metadata", failures)

	headwear.set(&"category", &"open_helmet")
	TestAssertions.truthy(_errors_contain(fit.validate(), "open helmet requires a helmet-safe hair id"), "body fit forwards headwear validation", failures)
	headwear.set(&"category", &"full_helmet")
	fit.set(&"necklace_anchor_paths", Array([NodePath("/AbsoluteAnchor")], TYPE_NODE_PATH, "", null))
	TestAssertions.truthy(_errors_contain(fit.validate(), "necklace anchor path must be relative"), "body fit rejects absolute necklace anchors", failures)
	fit.set(&"necklace_anchor_paths", Array([NodePath("Neck"), NodePath("Neck")], TYPE_NODE_PATH, "", null))
	TestAssertions.truthy(_errors_contain(fit.validate(), "duplicate necklace anchor path Neck"), "body fit rejects duplicate necklace anchors", failures)


func _minimal_profile(profile_id: StringName) -> CharacterVisualProfile:
	var profile := CharacterVisualProfile.new()
	profile.id = profile_id
	profile.presentation_scene = _packed_scene()
	profile.default_body_preset = &"masculine"
	profile.default_palette_id = &"red"
	profile.palette_colors = {&"red": Color.WHITE}
	profile.required_animation_names = [&"idle", &"walk"]
	return profile


func _head(head_id: StringName, class_id: StringName, body_preset_id: StringName) -> CharacterHeadVisualDefinition:
	var head := CharacterHeadVisualDefinition.new()
	head.id = head_id
	head.class_id = class_id
	head.body_preset_id = body_preset_id
	head.presentation_scene = _packed_scene()
	head.mesh_root_path = NodePath("HeadMesh")
	head.neck_interface_id = StringName("pf_neck_%s_v1" % body_preset_id)
	head.helmet_envelope_id = StringName("pf_head_%s_v1" % body_preset_id)
	head.left_ear_socket_path = NodePath("Skeleton3D/EarSocketLeft")
	head.right_ear_socket_path = NodePath("Skeleton3D/EarSocketRight")
	head.head_region_ids = [&"scalp", &"hair", &"facial_hair", &"ears"]
	var surface := CharacterSurfaceDefinition.new()
	surface.source_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	surface.uv_set_count = 1
	surface.tangent_status = &"valid"
	surface.texture_paths = {&"base_color": "res://assets/models/characters/test/head.png"}
	surface.material_family_ids = [&"skin"]
	surface.lod_triangle_counts = [1200, 600]
	head.surface = surface
	return head


func _packed_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "FixtureRoot"
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _property_names(resource: Object) -> Array[StringName]:
	var names: Array[StringName] = []
	for property: Dictionary in resource.get_property_list():
		names.append(StringName(property[&"name"]))
	return names



func _errors_contain(errors: PackedStringArray, fragment: String) -> bool:
	for reason: String in errors:
		if fragment in reason:
			return true
	return false

func _valid_attack() -> AttackDefinition:
	var component := AttackDamageComponent.new()
	component.damage_type_id = &"physical"
	component.base_amount = 1.0
	var attack := AttackDefinition.new()
	attack.id = &"test_attack"
	attack.cooldown = 1.0
	attack.range = 1.0
	attack.damage_components = [component]
	return attack
