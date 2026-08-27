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
	if kind_value.is_empty():
		return null
	var condition := CityAccessCondition.new()
	condition._kind = kind_value
	condition._value = value_value
	return condition

func copy() -> CityAccessCondition:
	return create(_kind, _value)
