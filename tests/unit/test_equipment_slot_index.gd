extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.equal(EquipmentSlotIndex.capacity(), 11, "equipment sheet has eleven canonical positions", failures)
	for index: int in EquipmentSlotCatalog.SLOT_IDS.size():
		var slot_id := EquipmentSlotCatalog.SLOT_IDS[index]
		TestAssertions.equal(EquipmentSlotIndex.index_for(slot_id), index, "slot maps to canonical index", failures)
		TestAssertions.equal(EquipmentSlotIndex.slot_for(index), slot_id, "index maps to canonical slot", failures)
	TestAssertions.equal(EquipmentSlotIndex.index_for(&"unknown"), -1, "unknown slot is rejected", failures)
	TestAssertions.equal(EquipmentSlotIndex.slot_for(11), &"", "out-of-range index is rejected", failures)
	return failures
