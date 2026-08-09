class_name AttributeProjectionResult
extends RefCounted

var error := ""
var source: StatModifierSource

static func success(projected_source: StatModifierSource) -> AttributeProjectionResult:
	var result := AttributeProjectionResult.new()
	result.source = projected_source
	return result

static func failure(message: String) -> AttributeProjectionResult:
	var result := AttributeProjectionResult.new()
	result.error = message
	return result

func ok() -> bool:
	return error.is_empty() and source != null
