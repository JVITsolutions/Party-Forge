class_name StatModifier
extends Resource

enum Operation { FLAT, INCREASED, REDUCED, MORE, LESS }

@export var stat_id: StringName
@export var operation := Operation.FLAT
@export var value := 0.0
@export var source_id: StringName
@export var source_label: String
@export var required_tags: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []
@export var required_capability_tags: Array[StringName] = []
@export var excluded_capability_tags: Array[StringName] = []
@export var required_action_tags: Array[StringName] = []
@export var excluded_action_tags: Array[StringName] = []

static func create(target: StringName, op: Operation, amount: float, source: StringName, label: String, required: Array[StringName] = [], excluded: Array[StringName] = []) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat_id = target
	modifier.operation = op
	modifier.value = amount
	modifier.source_id = source
	modifier.source_label = label
	modifier.required_tags = required.duplicate()
	modifier.excluded_tags = excluded.duplicate()
	return modifier

func applies_to(capabilities: Array[StringName], action_tags: Array[StringName]) -> bool:
	var tags := capabilities.duplicate()
	for tag: StringName in action_tags:
		if tag not in tags:
			tags.append(tag)
	for tag: StringName in required_tags:
		if tag not in tags:
			return false
	for tag: StringName in excluded_tags:
		if tag in tags:
			return false
	for tag: StringName in required_capability_tags:
		if tag not in capabilities:
			return false
	for tag: StringName in excluded_capability_tags:
		if tag in capabilities:
			return false
	for tag: StringName in required_action_tags:
		if tag not in action_tags:
			return false
	for tag: StringName in excluded_action_tags:
		if tag in action_tags:
			return false
	return true
