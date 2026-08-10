class_name EquipmentCatalog
extends Resource

const DAMAGE_TYPES: DamageTypeCatalog = preload("res://data/damage_types/core_damage_types.tres")

@export var definitions: Array[EquipmentBaseDefinition] = []

func definition(id: StringName) -> EquipmentBaseDefinition:
	for value: EquipmentBaseDefinition in definitions:
		if value != null and value.id == id: return value
	return null

func size() -> int:
	return definitions.size()

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for value: EquipmentBaseDefinition in definitions:
		if value == null:
			errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=<null> reason=definition missing")
			continue
		if seen.has(value.id): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=duplicate id" % value.id)
		seen[value.id] = true
		for reason: String in value.validate(DAMAGE_TYPES): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=%s" % [value.id, reason])
		if value.presentation != null:
			for reason: String in value.presentation.validate(): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=%s" % [value.id, reason])
	return errors
