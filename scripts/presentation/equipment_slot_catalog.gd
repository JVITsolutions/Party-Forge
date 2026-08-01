class_name EquipmentSlotCatalog
extends RefCounted

const SLOT_IDS: Array[StringName] = [
	&"main_hand", &"off_hand", &"helmet", &"body_armour", &"gloves",
	&"boots", &"belt", &"amulet", &"ring_left", &"ring_right",
]

static func is_valid(slot_id: StringName) -> bool:
	return slot_id in SLOT_IDS
