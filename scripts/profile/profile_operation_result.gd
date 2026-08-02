class_name ProfileOperationResult
extends RefCounted

var profile: ProfileState
var error := ""

func ok() -> bool:
	return profile != null and error.is_empty()
