class_name EquipmentLoadoutEntry
extends Resource

@export var slot_id: StringName
@export var item: EquipmentBaseDefinition

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not EquipmentSlotCatalog.is_valid(slot_id): errors.append("loadout slot %s is invalid" % slot_id)
	if item == null: errors.append("loadout slot %s item is missing" % slot_id)
	elif slot_id not in item.compatible_slot_ids: errors.append("loadout item %s does not support slot %s" % [item.id, slot_id])
	return errors
