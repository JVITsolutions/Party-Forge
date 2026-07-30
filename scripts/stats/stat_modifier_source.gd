class_name StatModifierSource
extends Resource

@export var id: StringName
@export var source_type: StringName
@export var label: String
@export var owner_member_id := 0
@export var modifiers: Array[StatModifier] = []

static func create(source_id: StringName, type_id: StringName, display_label: String, member_id: int, entries: Array[StatModifier]) -> StatModifierSource:
	var source := StatModifierSource.new()
	source.id = source_id
	source.source_type = type_id
	source.label = display_label
	source.owner_member_id = member_id
	source.modifiers = entries.duplicate()
	return source
