class_name CityAccessLoadResult
extends RefCounted

var _snapshot: CityAccessSnapshot
var _errors: Array[String] = []

var snapshot: CityAccessSnapshot:
	get: return _snapshot.copy() if _snapshot != null else null
	set(value): _snapshot = value.copy() if value != null else null
var errors: Array[String]:
	get: return _errors.duplicate()
	set(value): _errors = value.duplicate()

static func success(snapshot_value: CityAccessSnapshot) -> CityAccessLoadResult:
	var result := CityAccessLoadResult.new()
	result.snapshot = snapshot_value
	return result

static func failure(error_value: String) -> CityAccessLoadResult:
	var result := CityAccessLoadResult.new()
	result._errors.append(error_value)
	return result

func ok() -> bool:
	return _snapshot != null and _errors.is_empty()
