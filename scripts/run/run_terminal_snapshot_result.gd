class_name RunTerminalSnapshotResult
extends RefCounted

enum FailureCategory {
	NONE,
	INVALID_CONTEXT,
	INVALID_OUTCOME,
	INVALID_DURATION,
	IDENTITY_MISMATCH,
	INVALID_PARTY,
	INVALID_MEMBER,
	PROGRESSION_UNAVAILABLE,
	OWNERSHIP_VERIFICATION,
	INVALID_SOURCE,
	INVALID_DOCUMENT,
	UNSUPPORTED_SCHEMA,
}

var _snapshot: RunTerminalSnapshot
var snapshot: RunTerminalSnapshot:
	get:
		return _snapshot.copy() if _snapshot != null else null
var error := ""
var failure_category := FailureCategory.NONE
var player_reason := ""

static func success(snapshot_value: RunTerminalSnapshot) -> RunTerminalSnapshotResult:
	var result := RunTerminalSnapshotResult.new()
	result._snapshot = snapshot_value.copy() if snapshot_value != null else null
	if result._snapshot == null:
		return failure(
			"PARTY_FORGE_RUN_TERMINAL_SNAPSHOT_ERROR field=snapshot reason=must not be null",
			FailureCategory.INVALID_SOURCE,
		)
	return result

static func failure(
	error_value: String,
	failure_category_value: FailureCategory = FailureCategory.INVALID_SOURCE,
	player_reason_value: String = "",
) -> RunTerminalSnapshotResult:
	var result := RunTerminalSnapshotResult.new()
	result.error = error_value
	result.failure_category = failure_category_value
	result.player_reason = player_reason_value if not player_reason_value.strip_edges().is_empty() else _player_reason_for(failure_category_value)
	return result

func ok() -> bool:
	return _snapshot != null and error.is_empty() and failure_category == FailureCategory.NONE and player_reason.is_empty()

static func _player_reason_for(category: FailureCategory) -> String:
	match category:
		FailureCategory.INVALID_CONTEXT:
			return "The completed run is no longer available. Return to the Forge and start the run again."
		FailureCategory.INVALID_OUTCOME:
			return "The run result is invalid. Return to the Forge and try the run again."
		FailureCategory.INVALID_DURATION:
			return "The run duration is invalid. Return to the Forge and try the run again."
		FailureCategory.IDENTITY_MISMATCH:
			return "The completed run does not match the saved run. Return to the Forge and resume or restart it."
		FailureCategory.INVALID_PARTY, FailureCategory.INVALID_MEMBER, FailureCategory.PROGRESSION_UNAVAILABLE:
			return "The completed party data is incomplete. Return to the Forge and resume or restart the run."
		FailureCategory.OWNERSHIP_VERIFICATION:
			return "The completed run inventory could not be verified. Nothing was moved. Return to the Forge and resume the run."
		FailureCategory.INVALID_SOURCE:
			return "The completed run data could not be verified. Nothing was moved. Return to the Forge and resume the run."
		FailureCategory.INVALID_DOCUMENT:
			return "The terminal run record is invalid. Return to the Forge and resume or restart the run."
		FailureCategory.UNSUPPORTED_SCHEMA:
			return "This terminal run record uses an unsupported version. Return to the Forge and resume or restart the run."
		_:
			return ""
