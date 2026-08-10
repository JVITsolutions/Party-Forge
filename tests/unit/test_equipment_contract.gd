extends RefCounted

const CURVE_PATH := "res://scripts/items/weapon_damage_component_curve.gd"
const PROFILE_PATH := "res://scripts/items/weapon_damage_profile.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists("res://scripts/equipment/equipment_base_definition.gd"), "equipment base contract exists", failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scripts/equipment/equipment_eligibility.gd"), "eligibility service exists", failures)
	TestAssertions.equal(ClassEquipmentRows.total_item_count(), 99, "canonical item manifest count", failures)
	var expected_sheet_slots: Array[StringName] = [&"helmet", &"body_armour", &"legs", &"gloves", &"boots", &"amulet", &"ring_left", &"ring_right", &"belt", &"main_hand", &"off_hand"]
	TestAssertions.equal(EquipmentSlotCatalog.SHEET_SLOT_IDS, expected_sheet_slots, "sheet slots retain the canonical eleven-slot order", failures)
	for set_id: StringName in ClassEquipmentRows.SET_ITEM_IDS:
		var item_ids: Array = ClassEquipmentRows.SET_ITEM_IDS[set_id]
		for index: int in item_ids.size():
			var expected_slot := &"main_hand" if set_id == &"fighter" and index == 11 else expected_sheet_slots[index]
			TestAssertions.equal(ClassEquipmentRows.slot_for(set_id, index), expected_slot, "%s row %d maps to its canonical sheet slot" % [set_id, index], failures)
	var ring := ClassEquipmentRows.make_base(&"ring_of_vigil", &"ring_left")
	TestAssertions.equal(ring.compatible_slot_ids, [&"ring_left", &"ring_right"], "rings fit either ring slot", failures)
	var staff := ClassEquipmentRows.make_base(&"rime_scholar_staff", &"main_hand")
	TestAssertions.equal(staff.reserved_slot_ids, [&"off_hand"], "staff reserves offhand", failures)
	var legs := ClassEquipmentRows.make_base(&"dawn_bulwark_greaves", &"legs")
	legs.implicit_family_id = &"armour"
	var legs_visual := EquipmentVisualDefinition.new()
	legs_visual.id = legs.id
	legs_visual.slot_id = &"legs"
	legs_visual.geometry_key = &"legs"
	var legs_channels: Array[StringName] = []
	legs_channels.append(&"armour")
	legs_visual.visual_channels = legs_channels
	legs.presentation = legs_visual
	TestAssertions.equal(legs.validate(), PackedStringArray(), "legs base validates against the sheet slot contract", failures)
	_test_explicit_weapon_damage_profiles(failures)
	return failures

func _test_explicit_weapon_damage_profiles(failures: Array[String]) -> void:
	var probe := EquipmentBaseDefinition.new()
	var has_profile_link := probe.get_property_list().any(func(property: Dictionary) -> bool: return property["name"] == "weapon_damage_profile")
	TestAssertions.truthy(has_profile_link, "equipment base exposes an optional weapon damage profile", failures)
	if not has_profile_link or not ResourceLoader.exists(CURVE_PATH) or not ResourceLoader.exists(PROFILE_PATH):
		return
	var catalog := EquipmentCatalog.new()
	var definitions: Array[EquipmentBaseDefinition] = []
	for index: int in 11:
		var damage_base := _valid_base(StringName("damage_base_%02d" % index))
		damage_base.set(&"weapon_damage_profile", _valid_profile(StringName("damage_profile_%02d" % index)))
		definitions.append(damage_base)
	for index: int in 7:
		var support_base := _valid_base(StringName("support_base_%02d" % index))
		support_base.weight_class_id = &"weapon"
		support_base.weapon_family_id = &"support_weapon_family"
		TestAssertions.equal(support_base.get(&"weapon_damage_profile"), null, "support base %d has no inferred profile" % index, failures)
		definitions.append(support_base)
	catalog.definitions = definitions
	TestAssertions.equal(catalog.validate(), PackedStringArray(), "eleven explicit damage bases and seven null-profile support bases validate", failures)

	var malformed_base := definitions[0]
	var malformed_profile := malformed_base.get(&"weapon_damage_profile") as Resource
	((malformed_profile.get(&"components") as Array)[0] as Resource).set(&"maximum_at_level_1", 5.0)
	var errors := catalog.validate()
	TestAssertions.truthy(_contains(errors, "item=damage_base_00"), "catalog error prefixes the base id", failures)
	TestAssertions.truthy(_contains(errors, "profile=damage_profile_00"), "catalog error prefixes the profile id", failures)
	TestAssertions.truthy(_contains(errors, "level 1 range is inverted"), "catalog explicitly rejects the malformed authored profile", failures)

func _valid_base(base_id: StringName) -> EquipmentBaseDefinition:
	var base := EquipmentBaseDefinition.new()
	base.id = base_id
	base.display_name = String(base_id)
	base.item_type_id = &"weapon"
	base.compatible_slot_ids = [&"main_hand"]
	base.weight_class_id = &"weapon"
	base.handedness_id = &"one_hand"
	base.weapon_family_id = &"test_weapon_family"
	base.implicit_family_id = &"test_implicit_family"
	var visual := EquipmentVisualDefinition.new()
	visual.id = base_id
	visual.slot_id = &"main_hand"
	visual.geometry_key = base_id
	visual.visual_channels = [&"weapon"]
	base.presentation = visual
	return base

func _valid_profile(profile_id: StringName) -> Resource:
	var profile := (load(PROFILE_PATH) as Script).new() as Resource
	profile.set(&"id", profile_id)
	var curve := (load(CURVE_PATH) as Script).new() as Resource
	curve.set(&"damage_type_id", &"physical")
	curve.set(&"minimum_at_level_1", 10.0)
	curve.set(&"maximum_at_level_1", 20.0)
	curve.set(&"minimum_at_level_1000", 100.0)
	curve.set(&"maximum_at_level_1000", 200.0)
	(profile.get(&"components") as Array).append(curve)
	return profile

func _contains(errors: PackedStringArray, fragment: String) -> bool:
	return Array(errors).any(func(error: String) -> bool: return fragment in error)
