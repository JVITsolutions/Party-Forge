class_name RunTerminalBeginResult
extends RefCounted

enum Code { READY, CAPTURE_FAILED, PERSISTENCE_FAILED }

var code := Code.CAPTURE_FAILED
var _snapshot: RunTerminalSnapshot
var snapshot: RunTerminalSnapshot:
	get: return _snapshot.copy() if _snapshot != null else null
var error := ""

static func ready(value: RunTerminalSnapshot) -> RunTerminalBeginResult:
	var result := RunTerminalBeginResult.new()
	result.code = Code.READY
	result._snapshot = value.copy() if value != null else null
	return result

static func failure(code_value: Code, reason: String, value: RunTerminalSnapshot = null) -> RunTerminalBeginResult:
	var result := RunTerminalBeginResult.new()
	result.code = code_value
	result.error = reason
	result._snapshot = value.copy() if value != null else null
	return result

func ok() -> bool: return code == Code.READY and _snapshot != null and error.is_empty()
