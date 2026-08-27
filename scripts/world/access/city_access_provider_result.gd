class_name CityAccessProviderResult
extends RefCounted

enum Mode { LEGACY, CANDIDATE, CANDIDATE_FAILED }

var _mode: Mode = Mode.LEGACY
var _snapshot: CityAccessSnapshot
var _diagnostic: StringName = &""

var mode: Mode:
	get: return _mode
	set(_next): pass
var snapshot: CityAccessSnapshot:
	get: return _snapshot.copy() if _snapshot != null else null
	set(_next): pass
var diagnostic: StringName:
	get: return _diagnostic
	set(_next): pass


static func legacy(diagnostic_value: StringName = &"") -> CityAccessProviderResult:
	var result := CityAccessProviderResult.new()
	result._mode = Mode.LEGACY
	result._diagnostic = diagnostic_value
	return result


static func candidate(snapshot_value: CityAccessSnapshot) -> CityAccessProviderResult:
	if snapshot_value == null:
		return candidate_failed(&"candidate_snapshot_invalid")
	var result := CityAccessProviderResult.new()
	result._mode = Mode.CANDIDATE
	result._snapshot = snapshot_value.copy()
	return result


static func candidate_failed(diagnostic_value: StringName) -> CityAccessProviderResult:
	var result := CityAccessProviderResult.new()
	result._mode = Mode.CANDIDATE_FAILED
	result._diagnostic = diagnostic_value
	return result
