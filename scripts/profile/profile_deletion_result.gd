class_name ProfileDeletionResult
extends RefCounted

var committed := false
var cleanup_debt := false
var deleted_profile_id := ""
var next_active_profile_id := ""
var error := ""

func ok() -> bool:
	return committed and not cleanup_debt
