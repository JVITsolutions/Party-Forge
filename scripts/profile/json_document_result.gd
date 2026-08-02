class_name JsonDocumentResult
extends RefCounted

var document: Dictionary = {}
var error := ""
var missing := false
var recovered_from_backup := false
var recovery_detail := ""

func ok() -> bool:
	return error.is_empty() and not missing
