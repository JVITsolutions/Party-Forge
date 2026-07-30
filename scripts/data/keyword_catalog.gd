class_name KeywordCatalog
extends Resource

@export var definitions: Array[KeywordDefinition] = []

func definition(id: StringName) -> KeywordDefinition:
	for entry: KeywordDefinition in definitions:
		if entry != null and entry.id == id:
			return entry
	return null

func has_definition(id: StringName) -> bool:
	return definition(id) != null

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for entry: KeywordDefinition in definitions:
		if entry == null or entry.id.is_empty() or entry.display_name.is_empty() or entry.explanation.is_empty():
			errors.append("invalid keyword definition")
		elif seen.has(entry.id):
			errors.append("duplicate keyword %s" % entry.id)
		else:
			seen[entry.id] = true
	return errors
