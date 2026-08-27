class_name CityAccessProjection
extends RefCounted

enum State { HIDDEN, LOCKED, AVAILABLE }

var _location_id: StringName
var _state: State = State.HIDDEN
var _reason_id: StringName
var _destination_id: StringName
var _diagnostic := ""

var location_id: StringName:
	get: return _location_id
	set(_next): pass
var state: State:
	get: return _state
	set(_next): pass
var reason_id: StringName:
	get: return _reason_id
	set(_next): pass
var destination_id: StringName:
	get: return _destination_id
	set(_next): pass
var diagnostic: String:
	get: return _diagnostic
	set(_next): pass


func _init(location_id_value: StringName, state_value: State, reason_id_value: StringName, destination_id_value: StringName = &"", diagnostic_value: String = "") -> void:
	_location_id = location_id_value
	_state = state_value
	_reason_id = reason_id_value
	_destination_id = destination_id_value if state_value == State.AVAILABLE else &""
	_diagnostic = diagnostic_value
