class_name ProfileMutationResult
extends RefCounted

var profile: ProfileState
var error := ""
var duplicate := false

func ok() -> bool:
	return profile != null and error.is_empty()
