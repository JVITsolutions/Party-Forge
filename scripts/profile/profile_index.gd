class_name ProfileIndex
extends RefCounted

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var active_profile_id := ""
var entries: Array[Dictionary] = []

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"active_profile_id": active_profile_id,
		"entries": entries.duplicate(true),
	}

func rebuild(profiles: Array[ProfileState]) -> void:
	entries.clear()
	for profile: ProfileState in profiles:
		entries.append({
			"profile_id": profile.profile_id,
			"display_name": profile.display_name,
			"updated_at_unix": profile.updated_at_unix,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["updated_at_unix"]) > int(b["updated_at_unix"]))
