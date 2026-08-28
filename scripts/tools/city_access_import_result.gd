class_name CityAccessImportResult
extends RefCounted

var candidate: Dictionary = {}
var stage := ""
var reason := ""

func ok() -> bool:
	return stage.is_empty()

static func success(value: Dictionary) -> CityAccessImportResult:
	var result := CityAccessImportResult.new()
	result.candidate = value.duplicate(true)
	return result

static func failure(value_stage: String, value_reason: String) -> CityAccessImportResult:
	var result := CityAccessImportResult.new()
	result.stage = value_stage
	result.reason = value_reason
	return result
