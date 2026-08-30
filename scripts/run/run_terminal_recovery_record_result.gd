class_name RunTerminalRecoveryRecordResult
extends RefCounted

var _record: RunTerminalRecoveryRecord
var record: RunTerminalRecoveryRecord:
	get: return _record.copy() if _record != null else null
var error := ""

static func success(value: RunTerminalRecoveryRecord) -> RunTerminalRecoveryRecordResult:
	var result := RunTerminalRecoveryRecordResult.new()
	result._record = value.copy() if value != null else null
	if result._record == null:
		result.error = "PARTY_FORGE_RUN_TERMINAL_RECOVERY_ERROR field=record reason=must not be null"
	return result

static func failure(reason: String) -> RunTerminalRecoveryRecordResult:
	var result := RunTerminalRecoveryRecordResult.new()
	result.error = reason
	return result

func ok() -> bool:
	return _record != null and error.is_empty()
