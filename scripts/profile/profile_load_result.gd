class_name ProfileLoadResult
extends RefCounted

var profile: ProfileState
var error := ""
var missing := false
var recovered_from_backup := false

func ok() -> bool:
	return profile != null and error.is_empty()
