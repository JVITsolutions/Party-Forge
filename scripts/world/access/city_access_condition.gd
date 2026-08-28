class_name CityAccessCondition
extends RefCounted

var _kind: StringName
var _value: String

var kind: StringName:
	get: return _kind
	set(_next): pass
var value: String:
	get: return _value
	set(_next): pass

static func create(kind_value: StringName, value_value: String) -> CityAccessCondition:
	if kind_value not in [&"always", &"prologue_state", &"permanent_unlock", &"discovered_building", &"discovered_tree"]:
		return null
	if kind_value == &"always" and not value_value.is_empty():
		return null
	if kind_value != &"always" and (not _stable(value_value) or (kind_value == &"prologue_state" and value_value not in ["not_started", "in_progress", "completed"])):
		return null
	var condition := CityAccessCondition.new()
	condition._kind = kind_value
	condition._value = value_value
	return condition

func copy() -> CityAccessCondition:
	return create(_kind, _value)

static func _stable(value: String) -> bool:
	return not value.is_empty() and value.to_utf16_buffer().size() / 2 <= 128
