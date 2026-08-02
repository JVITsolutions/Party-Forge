class_name EquipmentSlotCatalog
extends RefCounted

const SLOT_IDS: Array[StringName] = [
	&"helmet", &"body_armour", &"legs", &"gloves", &"boots", &"amulet",
	&"ring_left", &"ring_right", &"belt", &"main_hand", &"off_hand",
]

const SHEET_SLOT_IDS: Array[StringName] = [
	&"helmet", &"body_armour", &"legs", &"gloves", &"boots", &"amulet",
	&"ring_left", &"ring_right", &"belt", &"main_hand", &"off_hand",
]

static func is_valid(slot_id: StringName) -> bool:
	return slot_id in SLOT_IDS
