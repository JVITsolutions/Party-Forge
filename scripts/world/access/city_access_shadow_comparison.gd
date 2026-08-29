class_name CityAccessShadowComparison
extends RefCounted

enum Outcome { MATCH, DIVERGED, UNAVAILABLE }
enum Dimension { MATCH, DIVERGED, NOT_APPLICABLE, UNAVAILABLE }
enum AccessState { AVAILABLE, BLOCKED, UNAVAILABLE }

const LOCATION_ID := &"city.warehouse"

var _outcome: Outcome
var _access: Dimension
var _visibility: Dimension
var _destination: Dimension
var _legacy_access: AccessState
var _candidate_access: AccessState
var _reason: StringName

var outcome: Outcome:
	get: return _outcome
	set(_next): pass
var access: Dimension:
	get: return _access
	set(_next): pass
var visibility: Dimension:
	get: return _visibility
	set(_next): pass
var destination: Dimension:
	get: return _destination
	set(_next): pass
var legacy_access: AccessState:
	get: return _legacy_access
	set(_next): pass
var candidate_access: AccessState:
	get: return _candidate_access
	set(_next): pass
var reason: StringName:
	get: return _reason
	set(_next): pass


func _init(
	outcome_value: Outcome,
	access_value: Dimension,
	visibility_value: Dimension,
	destination_value: Dimension,
	legacy_access_value: AccessState,
	candidate_access_value: AccessState,
	reason_value: StringName,
) -> void:
	_outcome = outcome_value
	_access = access_value
	_visibility = visibility_value
	_destination = destination_value
	_legacy_access = legacy_access_value
	_candidate_access = candidate_access_value
	_reason = reason_value


func marker() -> String:
	return "PARTY_FORGE_CITY_ACCESS_SHADOW location=%s outcome=%s access=%s visibility=%s destination=%s legacy_access=%s candidate_access=%s reason=%s" % [
		LOCATION_ID,
		Outcome.keys()[outcome],
		Dimension.keys()[access],
		Dimension.keys()[visibility],
		Dimension.keys()[destination],
		AccessState.keys()[legacy_access],
		AccessState.keys()[candidate_access],
		reason,
	]
