class_name RunRecapProviderResult
extends RefCounted

enum State { SECTION, EMPTY, ERROR }

var _state := State.ERROR
var _section: RunRecapSectionProjection
var section: RunRecapSectionProjection:
	get: return _section.copy() if _section != null else null
var error := ""

static func success(section_value: RunRecapSectionProjection) -> RunRecapProviderResult:
	if section_value == null:
		return failure("provider section is unavailable")
	var result := RunRecapProviderResult.new()
	result._state = State.SECTION
	result._section = section_value.copy()
	return result

static func empty() -> RunRecapProviderResult:
	var result := RunRecapProviderResult.new()
	result._state = State.EMPTY
	return result

static func failure(error_value: String) -> RunRecapProviderResult:
	var result := RunRecapProviderResult.new()
	result._state = State.ERROR
	result.error = error_value.strip_edges()
	if result.error.is_empty():
		result.error = "provider returned an unspecified error"
	return result

func ok() -> bool:
	return _state == State.SECTION and _section != null and _section.valid() and error.is_empty()

func is_empty() -> bool:
	return _state == State.EMPTY and _section == null and error.is_empty()
