class_name PassiveTreeLoadResult
extends RefCounted

var tree: PassiveTreeDefinition
var errors: Array[String] = []

func ok() -> bool:
	return tree != null and errors.is_empty()
