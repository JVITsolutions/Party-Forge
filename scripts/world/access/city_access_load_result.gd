class_name CityAccessLoadResult
extends RefCounted

var _snapshot: CityAccessSnapshot
var _errors: Array[String] = []

var snapshot: CityAccessSnapshot:
	get: return _snapshot.copy() if _snapshot != null else null
var errors: Array[String]:
	get: return _errors.duplicate()

static func success(snapshot_value: CityAccessSnapshot) -> CityAccessLoadResult:
	var result := CityAccessLoadResult.new()
	result._snapshot = snapshot_value.copy() if snapshot_value != null else null
	return result

static func failure(error_value: String) -> CityAccessLoadResult:
	var result := CityAccessLoadResult.new()
	result._errors.append(error_value)
	return result

func ok() -> bool:
	return _snapshot != null and _errors.is_empty()
