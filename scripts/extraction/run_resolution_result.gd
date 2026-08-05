class_name RunResolutionResult
extends RefCounted

var _profile: ProfileState
var profile: ProfileState:
	get:
		return _profile.copy() if _profile != null else null

var error := ""
var duplicate := false

static func success(profile_value: ProfileState, duplicate_value: bool) -> RunResolutionResult:
	var result := RunResolutionResult.new()
	result._profile = profile_value.copy() if profile_value != null else null
	result.duplicate = duplicate_value
	return result

static func failure(error_value: String) -> RunResolutionResult:
	var result := RunResolutionResult.new()
	result.error = error_value
	return result

func ok() -> bool:
	return _profile != null and error.is_empty()
