class_name ItemModifierRoll
extends RefCounted

var stat_id: StringName
var operation: int = StatModifier.Operation.FLAT
var value: float = 0.0
var required_tags: Array[StringName] = []

func copy() -> ItemModifierRoll:
	var result := ItemModifierRoll.new()
	result.stat_id = stat_id
	result.operation = operation
	result.value = value
	result.required_tags = required_tags.duplicate()
	return result

func to_dictionary() -> Dictionary:
	var tags: Array[String] = []
	for tag: StringName in required_tags:
		tags.append(String(tag))
	return {
		"operation": operation,
		"required_tags": tags,
		"stat_id": String(stat_id),
		"value": value,
	}
