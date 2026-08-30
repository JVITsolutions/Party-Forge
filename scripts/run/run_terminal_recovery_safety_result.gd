class_name RunTerminalRecoverySafetyResult
extends RefCounted

var safe := false
var error := ""
var _record: RunTerminalRecoveryRecord
var record: RunTerminalRecoveryRecord:
	get: return _record.copy() if _record != null else null

static func success(record_value: RunTerminalRecoveryRecord) -> RunTerminalRecoverySafetyResult:
	var result := RunTerminalRecoverySafetyResult.new()
	result.safe = true
	result._record = record_value.copy() if record_value != null else null
	return result

static func failure(reason: String) -> RunTerminalRecoverySafetyResult:
	var result := RunTerminalRecoverySafetyResult.new()
	result.error = reason
	return result

func ok() -> bool: return safe and _record != null and error.is_empty()
