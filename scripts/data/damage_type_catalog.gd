class_name DamageTypeCatalog
extends Resource

@export var definitions: Array[DamageTypeDefinition] = []

func definition(type_id: StringName) -> DamageTypeDefinition:
	for entry: DamageTypeDefinition in definitions:
		if entry != null and entry.id == type_id:
			return entry
	return null

func all() -> Array[DamageTypeDefinition]:
	return definitions.duplicate()

func validate(stats: StatCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for entry: DamageTypeDefinition in definitions:
		if entry == null:
			errors.append("PARTY_FORGE_DAMAGE_ERROR type=<null> reason=resource failed to load")
			continue
		if seen.has(entry.id):
			errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s reason=duplicate id" % entry.id)
			continue
		seen[entry.id] = true
		errors.append_array(entry.validate(stats))
	return errors
