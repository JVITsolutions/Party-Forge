class_name CharacterNamePool
extends Resource

@export var id: StringName
@export var names: PackedStringArray = []

func validate(minimum_size: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("name pool id is empty")
	if names.size() < minimum_size:
		errors.append("name pool %s requires %d names" % [id, minimum_size])
	for name: String in names:
		if name.strip_edges().is_empty():
			errors.append("name pool %s contains an empty name" % id)
			break
	return errors
