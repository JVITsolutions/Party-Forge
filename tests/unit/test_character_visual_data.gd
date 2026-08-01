extends RefCounted

const EXPECTED_SLOTS: Array[StringName] = [
	&"main_hand", &"off_hand", &"helmet", &"body_armour", &"gloves",
	&"boots", &"belt", &"amulet", &"ring_left", &"ring_right",
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
	return failures

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
