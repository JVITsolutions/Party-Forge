class_name StatCatalog
extends Resource

@export var definitions: Array[StatDefinition] = []
var _by_id: Dictionary = {}

func definition(id: StringName) -> StatDefinition:
	_rebuild_index()
	return _by_id.get(id) as StatDefinition

func all() -> Array[StatDefinition]:
	return definitions.duplicate()

func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen: Dictionary = {}
	for entry: StatDefinition in definitions:
		if entry == null:
			errors.append("PARTY_FORGE_STAT_ERROR id=<null> reason=resource failed to load")
			continue
		if seen.has(entry.id):
			errors.append("PARTY_FORGE_STAT_ERROR id=%s reason=duplicate id" % entry.id)
		else:
			seen[entry.id] = true
		for reason: String in entry.validate():
			errors.append("PARTY_FORGE_STAT_ERROR id=%s reason=%s" % [entry.id, reason])
	return errors

func _rebuild_index() -> void:
	_by_id.clear()
	for entry: StatDefinition in definitions:
		if entry != null and not _by_id.has(entry.id):
			_by_id[entry.id] = entry
