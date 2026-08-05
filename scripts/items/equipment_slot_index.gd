class_name EquipmentSlotIndex
extends RefCounted

static func capacity() -> int:
	return EquipmentSlotCatalog.SLOT_IDS.size()

static func index_for(slot_id: StringName) -> int:
	return EquipmentSlotCatalog.SLOT_IDS.find(slot_id)

static func slot_for(index: int) -> StringName:
	return EquipmentSlotCatalog.SLOT_IDS[index] if index >= 0 and index < capacity() else &""
