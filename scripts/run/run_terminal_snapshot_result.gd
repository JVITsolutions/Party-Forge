class_name RunTerminalSnapshotResult
extends RefCounted

var _snapshot: RunTerminalSnapshot
var snapshot: RunTerminalSnapshot:
	get:
		return _snapshot.copy() if _snapshot != null else null
var error := ""

static func success(snapshot_value: RunTerminalSnapshot) -> RunTerminalSnapshotResult:
	var result := RunTerminalSnapshotResult.new()
	result._snapshot = snapshot_value.copy() if snapshot_value != null else null
	if result._snapshot == null:
		result.error = "PARTY_FORGE_RUN_TERMINAL_SNAPSHOT_ERROR field=snapshot reason=must not be null"
	return result

static func failure(error_value: String) -> RunTerminalSnapshotResult:
	var result := RunTerminalSnapshotResult.new()
	result.error = error_value
	return result

func ok() -> bool:
	return _snapshot != null and error.is_empty()
