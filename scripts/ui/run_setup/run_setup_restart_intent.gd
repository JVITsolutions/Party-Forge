class_name RunSetupRestartIntent
extends RefCounted

const META_KEY: StringName = &"party_forge_run_setup_restart_intent"

var _profile_id := ""
var profile_id: String:
	get: return _profile_id
var _class_id: StringName = &""
var class_id: StringName:
	get: return _class_id
var _reason := ""
var reason: String:
	get: return _reason

static func create(profile_id_value: String, class_id_value: StringName, reason_value: String = "") -> RunSetupRestartIntent:
	var result := new()
	result._profile_id = profile_id_value.strip_edges()
	result._class_id = class_id_value
	result._reason = reason_value.strip_edges()
	return result

func copy() -> RunSetupRestartIntent:
	return create(_profile_id, _class_id, _reason)

func valid() -> bool:
	return not _profile_id.is_empty() and not _class_id.is_empty()
