class_name PassiveTreeLoadResult
extends RefCounted

var tree: PassiveTreeDefinition
var errors: Array[String] = []
var source_document: Dictionary = {}
var source_path := ""
var source_sha256 := ""

static func failure(error: String) -> PassiveTreeLoadResult:
	var result := PassiveTreeLoadResult.new()
	result.errors.append(error)
	return result

func ok() -> bool:
	return tree != null and errors.is_empty()
