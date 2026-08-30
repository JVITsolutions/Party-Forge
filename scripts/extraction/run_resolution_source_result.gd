class_name RunResolutionSourceResult
extends RefCounted

var _source: RunResolutionSource
var source: RunResolutionSource:
	get:
		return _source.copy() if _source != null else null

var error := ""

static func success(source_value: RunResolutionSource) -> RunResolutionSourceResult:
	var result := RunResolutionSourceResult.new()
	result._source = source_value.copy() if source_value != null else null
	return result

static func failure(error_value: String) -> RunResolutionSourceResult:
	var result := RunResolutionSourceResult.new()
	result.error = error_value
	return result

func ok() -> bool:
	return _source != null and error.is_empty()
