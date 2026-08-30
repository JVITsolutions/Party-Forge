class_name RunResultProjectionResult
extends RefCounted

var _projection: RunResultProjection
var projection: RunResultProjection:
	get: return _projection.copy() if _projection != null else null
var error := ""

static func success(projection_value: RunResultProjection) -> RunResultProjectionResult:
	if projection_value == null or not projection_value.valid():
		return failure("run result projection is invalid")
	var result := RunResultProjectionResult.new()
	result._projection = projection_value.copy()
	return result

static func failure(error_value: String) -> RunResultProjectionResult:
	var result := RunResultProjectionResult.new()
	result.error = error_value.strip_edges()
	if result.error.is_empty():
		result.error = "run result projection is unavailable"
	return result

func ok() -> bool:
	return _projection != null and _projection.valid() and error.is_empty()
