class_name ItemAffixAssemblyResult
extends RefCounted

var affixes: Array[ItemAffixInstance] = []
var error_code: StringName
var details: Dictionary = {}

func ok() -> bool:
	return error_code.is_empty()
