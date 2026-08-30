class_name RunTerminalRecoveryRecord
extends RefCounted

enum Stage { CHOOSING_EXTRACTION, RESOLUTION_INTERRUPTED, RESOLVED_AWAITING_PROJECTION }

const SCHEMA_VERSION := 1
const FIELDS: Array[String] = [
	"schema_version", "stage", "snapshot", "selected_item_ids", "transaction_id",
	"protected_displaced_item_ids", "interruption_reason", "accepted_extraction", "applied_transaction_id",
]

var stage: Stage = Stage.CHOOSING_EXTRACTION
var _snapshot: RunTerminalSnapshot
var snapshot: RunTerminalSnapshot:
	get: return _snapshot.copy() if _snapshot != null else null
var _selected_item_ids: Array[String] = []
var selected_item_ids: Array[String]:
	get: return _selected_item_ids.duplicate()
var transaction_id := ""
var _protected_displaced_item_ids: Array[String] = []
var protected_displaced_item_ids: Array[String]:
	get: return _protected_displaced_item_ids.duplicate()
var interruption_reason := ""
var _accepted_extraction: RunExtractionProjection
var accepted_extraction: RunExtractionProjection:
	get: return RunResolutionEvaluation._copy_extraction(_accepted_extraction)
var applied_transaction_id := ""

static func create(
	stage_value: Stage,
	snapshot_value: RunTerminalSnapshot,
	selected_ids: Array[String] = [],
	transaction_id_value: String = "",
	protected_ids: Array[String] = [],
	interruption_reason_value: String = "",
	accepted_value: RunExtractionProjection = null,
	applied_transaction_id_value: String = "",
) -> RunTerminalRecoveryRecordResult:
	var record := RunTerminalRecoveryRecord.new()
	record.stage = stage_value
	record._snapshot = snapshot_value.copy() if snapshot_value != null else null
	record._selected_item_ids = selected_ids.duplicate()
	record.transaction_id = transaction_id_value
	record._protected_displaced_item_ids = protected_ids.duplicate()
	record.interruption_reason = interruption_reason_value
	record._accepted_extraction = RunResolutionEvaluation._copy_extraction(accepted_value)
	record.applied_transaction_id = applied_transaction_id_value
	var decoded := RunTerminalRecoveryCodec.decode(record.to_dictionary())
	return decoded

func copy() -> RunTerminalRecoveryRecord:
	var result := RunTerminalRecoveryRecord.new()
	result.stage = stage
	result._snapshot = _snapshot.copy() if _snapshot != null else null
	result._selected_item_ids = _selected_item_ids.duplicate()
	result.transaction_id = transaction_id
	result._protected_displaced_item_ids = _protected_displaced_item_ids.duplicate()
	result.interruption_reason = interruption_reason
	result._accepted_extraction = RunResolutionEvaluation._copy_extraction(_accepted_extraction)
	result.applied_transaction_id = applied_transaction_id
	return result

func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"stage": stage,
		"snapshot": _snapshot.to_dictionary() if _snapshot != null else {},
		"selected_item_ids": _selected_item_ids.duplicate(),
		"transaction_id": transaction_id,
		"protected_displaced_item_ids": _protected_displaced_item_ids.duplicate(),
		"interruption_reason": interruption_reason,
		"accepted_extraction": _accepted_extraction.to_dictionary() if _accepted_extraction != null else {},
		"applied_transaction_id": applied_transaction_id,
	}
