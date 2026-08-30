class_name RunTerminalRecoveryCodec
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_RUN_TERMINAL_RECOVERY_ERROR"

static func encode(record: RunTerminalRecoveryRecord) -> Dictionary:
	return record.to_dictionary() if record != null else {}

static func decode(document: Variant) -> RunTerminalRecoveryRecordResult:
	if not document is Dictionary:
		return _failure("document", "must be a dictionary")
	var data := document as Dictionary
	var fields_error := ItemRegistry._exact_fields(data, RunTerminalRecoveryRecord.FIELDS, "terminal_resolution")
	if not fields_error.is_empty():
		return RunTerminalRecoveryRecordResult.failure(fields_error.replace("PARTY_FORGE_ITEM_REGISTRY_ERROR", ERROR_PREFIX))
	if not ItemInstanceCodec._is_json_int(data["schema_version"], 1, 1):
		return _failure("schema_version", "must equal supported schema 1")
	if not ItemInstanceCodec._is_json_int(data["stage"], RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION, RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION):
		return _failure("stage", "unknown stage")
	var snapshot_result := RunTerminalSnapshot.from_dictionary(data["snapshot"])
	if not snapshot_result.ok():
		return _failure("snapshot", snapshot_result.error)
	for field: String in ["selected_item_ids", "protected_displaced_item_ids"]:
		if not data[field] is Array:
			return _failure(field, "must be an array")
		var seen: Dictionary = {}
		for value: Variant in data[field] as Array:
			if typeof(value) != TYPE_STRING or String(value).strip_edges().is_empty() or seen.has(String(value)):
				return _failure(field, "must contain unique non-empty strings")
			seen[String(value)] = true
	for field: String in ["transaction_id", "interruption_reason", "applied_transaction_id"]:
		if typeof(data[field]) != TYPE_STRING:
			return _failure(field, "must be a string")
	if not data["accepted_extraction"] is Dictionary:
		return _failure("accepted_extraction", "must be a dictionary")
	var stage := int(data["stage"])
	var accepted: RunExtractionProjection = null
	if stage == RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION:
		if not String(data["interruption_reason"]).is_empty():
			return _failure("interruption_reason", "resolved stage must not contain an interruption")
		if String(data["transaction_id"]).strip_edges().is_empty() or String(data["applied_transaction_id"]) != String(data["transaction_id"]):
			return _failure("applied_transaction_id", "must match the resolved transaction")
		accepted = _decode_extraction(data["accepted_extraction"] as Dictionary)
		if accepted == null or not accepted.valid:
			return _failure("accepted_extraction", "must be a valid extraction projection")
		var record_selected: Array[String] = []
		for value: Variant in data["selected_item_ids"] as Array:
			record_selected.append(String(value))
		if accepted.selected_item_ids != record_selected:
			return _failure("selected_item_ids", "must match the accepted extraction")
	elif not (data["accepted_extraction"] as Dictionary).is_empty() or not String(data["applied_transaction_id"]).is_empty():
		return _failure("accepted_extraction", "pre-resolution stages must not contain resolved truth")
	elif stage == RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION:
		if not String(data["interruption_reason"]).is_empty():
			return _failure("interruption_reason", "choosing stage must not contain an interruption")
		if not (data["selected_item_ids"] as Array).is_empty() and String(data["transaction_id"]).strip_edges().is_empty():
			return _failure("transaction_id", "confirmed selection requires a transaction")
	elif stage == RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED:
		if String(data["transaction_id"]).strip_edges().is_empty():
			return _failure("transaction_id", "interrupted resolution requires the confirmed transaction")
		if String(data["interruption_reason"]).strip_edges().is_empty():
			return _failure("interruption_reason", "interrupted resolution requires a reason")
	var result := RunTerminalRecoveryRecord.new()
	result.stage = stage
	result._snapshot = snapshot_result.snapshot
	for value: Variant in data["selected_item_ids"] as Array: result._selected_item_ids.append(String(value))
	result.transaction_id = String(data["transaction_id"])
	for value: Variant in data["protected_displaced_item_ids"] as Array: result._protected_displaced_item_ids.append(String(value))
	result.interruption_reason = String(data["interruption_reason"])
	result._accepted_extraction = RunResolutionEvaluation._copy_extraction(accepted)
	result.applied_transaction_id = String(data["applied_transaction_id"])
	return RunTerminalRecoveryRecordResult.success(result)

static func _failure(field: String, reason: String) -> RunTerminalRecoveryRecordResult:
	return RunTerminalRecoveryRecordResult.failure("%s field=%s reason=%s" % [ERROR_PREFIX, field, reason])

static func _decode_extraction(document: Dictionary) -> RunExtractionProjection:
	var fields: Array[String] = ["automatic_item_ids", "eligible_items", "selected_item_ids", "lost_item_ids", "capacity", "valid", "errors"]
	if not ItemRegistry._exact_fields(document, fields, "accepted_extraction").is_empty(): return null
	if typeof(document["valid"]) != TYPE_BOOL or not bool(document["valid"]): return null
	if not ItemInstanceCodec._is_json_int(document["capacity"], 0, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX): return null
	for field: String in ["automatic_item_ids", "eligible_items", "selected_item_ids", "lost_item_ids", "errors"]:
		if not document[field] is Array: return null
	var automatic: Array[String] = []
	var selected: Array[String] = []
	var lost: Array[String] = []
	var errors: Array[String] = []
	for value: Variant in document["automatic_item_ids"] as Array:
		if typeof(value) != TYPE_STRING or String(value).is_empty(): return null
		automatic.append(String(value))
	for value: Variant in document["selected_item_ids"] as Array:
		if typeof(value) != TYPE_STRING or String(value).is_empty(): return null
		selected.append(String(value))
	for value: Variant in document["lost_item_ids"] as Array:
		if typeof(value) != TYPE_STRING or String(value).is_empty(): return null
		lost.append(String(value))
	for value: Variant in document["errors"] as Array:
		if typeof(value) != TYPE_STRING: return null
		errors.append(String(value))
	if not errors.is_empty(): return null
	var eligible: Array[ExtractionSelection] = []
	for value: Variant in document["eligible_items"] as Array:
		if not value is Dictionary: return null
		var row := value as Dictionary
		if not ItemRegistry._exact_fields(row, ["item_id", "expected_source_container_id", "expected_source_slot"], "eligible_item").is_empty(): return null
		if typeof(row["item_id"]) != TYPE_STRING or String(row["item_id"]).is_empty() or typeof(row["expected_source_container_id"]) != TYPE_STRING or String(row["expected_source_container_id"]).is_empty() or not ItemInstanceCodec._is_json_int(row["expected_source_slot"], 0, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX): return null
		eligible.append(ExtractionSelection.create(String(row["item_id"]), StringName(row["expected_source_container_id"]), int(row["expected_source_slot"])))
	return RunExtractionProjection.create(automatic, eligible, selected, lost, int(document["capacity"]), [])
