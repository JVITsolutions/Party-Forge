class_name ProfileMigrationResult
extends RefCounted

var profile: ProfileState
var error := ""
var migrated := false
var source_schema_version := 0

func ok() -> bool:
	return profile != null and error.is_empty()
