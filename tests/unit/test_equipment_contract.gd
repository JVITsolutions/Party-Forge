extends RefCounted

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
	return failures
