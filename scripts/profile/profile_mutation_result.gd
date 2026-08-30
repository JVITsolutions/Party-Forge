class_name ProfileMutationResult
extends RefCounted

var profile: ProfileState
var error := ""
var duplicate := false
var _receipt: Dictionary = {}
var receipt: Dictionary:
	get: return _receipt.duplicate(true)

func ok() -> bool:
	return profile != null and error.is_empty()
