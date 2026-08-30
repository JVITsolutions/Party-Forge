class_name RunResolutionSourceResult
extends RefCounted

enum FailureKind { NONE, IDENTITY_MISMATCH, OWNERSHIP_VERIFICATION, INVALID_SOURCE }

var _source: RunResolutionSource
var source: RunResolutionSource:
	get:
		return _source.copy() if _source != null else null

var error := ""
var failure_kind := FailureKind.NONE

static func success(source_value: RunResolutionSource) -> RunResolutionSourceResult:
	var result := RunResolutionSourceResult.new()
	result._source = source_value.copy() if source_value != null else null
	return result

static func failure(error_value: String, failure_kind_value: FailureKind = FailureKind.INVALID_SOURCE) -> RunResolutionSourceResult:
	var result := RunResolutionSourceResult.new()
	result.error = error_value
	result.failure_kind = failure_kind_value
	return result

func ok() -> bool:
	return _source != null and error.is_empty()
