class_name CityAccessLocation
extends RefCounted

var _id: StringName
var _destination_id: StringName
var _visible_when: Array[CityAccessCondition] = []
var _available_when: Array[CityAccessCondition] = []

var id: StringName:
	get: return _id
	set(_next): pass
var destination_id: StringName:
	get: return _destination_id
	set(_next): pass
var visible_when: Array[CityAccessCondition]:
	get: return _condition_copies(_visible_when)
	set(_next): pass
var available_when: Array[CityAccessCondition]:
	get: return _condition_copies(_available_when)
	set(_next): pass

static func create(id_value: StringName, destination_id_value: StringName, visible_value: Array[CityAccessCondition], available_value: Array[CityAccessCondition]) -> CityAccessLocation:
	if not _stable(id_value) or not _stable(destination_id_value) or not _conditions_are_valid(visible_value) or not _conditions_are_valid(available_value):
		return null
	var location := CityAccessLocation.new()
	location._id = id_value
	location._destination_id = destination_id_value
	location._visible_when = _condition_copies(visible_value)
	location._available_when = _condition_copies(available_value)
	return location

func copy() -> CityAccessLocation:
	return create(_id, _destination_id, _visible_when, _available_when)

static func _condition_copies(source: Array[CityAccessCondition]) -> Array[CityAccessCondition]:
	var copies: Array[CityAccessCondition] = []
	for condition: CityAccessCondition in source:
		copies.append(condition.copy())
	return copies

static func _stable(value: StringName) -> bool:
	return not value.is_empty() and String(value).to_utf16_buffer().size() / 2 <= 128

static func _conditions_are_valid(values: Array[CityAccessCondition]) -> bool:
	if values.size() > 8:
		return false
	var has_always := false
	for condition: CityAccessCondition in values:
		if condition == null:
			return false
		if condition.kind == &"always":
			has_always = true
	if has_always and values.size() > 1:
		return false
	return true
