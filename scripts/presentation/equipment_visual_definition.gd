class_name EquipmentVisualDefinition
extends Resource

@export var id: StringName
@export var slot_id: StringName
@export var geometry_key: StringName
@export var visual_channels: Array[StringName] = []

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("equipment visual id is empty")
	if not EquipmentSlotCatalog.is_valid(slot_id): errors.append("equipment visual %s slot %s is invalid" % [id, slot_id])
	if geometry_key.is_empty(): errors.append("equipment visual %s geometry key is empty" % id)
	if visual_channels.is_empty(): errors.append("equipment visual %s has no visual channels" % id)
	var seen: Dictionary = {}
	for channel: StringName in visual_channels:
		if channel.is_empty() or seen.has(channel): errors.append("equipment visual %s has an empty or duplicate channel" % id)
		seen[channel] = true
	return errors
