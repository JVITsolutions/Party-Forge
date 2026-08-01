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

	var duplicate_available := CharacterVisualProfile.new()
	duplicate_available.id = &"duplicate_available"
	duplicate_available.default_palette_id = &"red"
	duplicate_available.palette_colors = {&"red": Color.WHITE}
	duplicate_available.available_equipment_visuals = [sword, sword]
	TestAssertions.truthy(_errors_contain(duplicate_available.validate(), "duplicate available equipment slot"), "duplicate available equipment slots are rejected", failures)

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
