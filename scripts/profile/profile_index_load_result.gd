class_name ProfileIndexLoadResult
extends RefCounted

var index: ProfileIndex
var error := ""
var missing := false

func ok() -> bool:
	return index != null and error.is_empty()
