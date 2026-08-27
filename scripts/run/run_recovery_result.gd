class_name RunRecoveryResult
extends RefCounted

enum Code { READY, CLASS_REQUIRED, INVALID, PERSISTENCE_FAILED }

var code := Code.INVALID
var profile: ProfileState
var bootstrap: RunItemBootstrap
var selected_leader_class_id: StringName = &""
var run_id: StringName = &""
var can_forfeit := false
var error := ""

func ready() -> bool:
	return code == Code.READY and profile != null and bootstrap != null and error.is_empty()
