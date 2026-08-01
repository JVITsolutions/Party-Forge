extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists("res://scripts/equipment/equipment_base_definition.gd"), "equipment base contract exists", failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scripts/equipment/equipment_eligibility.gd"), "eligibility service exists", failures)
	TestAssertions.equal(ClassEquipmentRows.total_item_count(), 99, "canonical item manifest count", failures)
	var ring := ClassEquipmentRows.make_base(&"ring_of_vigil", &"ring_left")
	TestAssertions.equal(ring.compatible_slot_ids, [&"ring_left", &"ring_right"], "rings fit either ring slot", failures)
	var staff := ClassEquipmentRows.make_base(&"rime_scholar_staff", &"main_hand")
	TestAssertions.equal(staff.reserved_slot_ids, [&"off_hand"], "staff reserves offhand", failures)
	return failures
