class_name LootLabBatchJob
extends RefCounted

var _spec: LootLabBatchSpec
var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog
var _generator_override: Callable
var _accumulator: LootLabReportAccumulator
var _attempted := 0
var _succeeded := 0
var _failed := 0
var _cancel_requested := false
var _active := false
var _started_usec := 0
var _terminal_report: Dictionary = {}
var _startup_error := ""

static func create(
	spec: LootLabBatchSpec,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	generator_override: Callable = Callable()
) -> LootLabBatchJob:
	var result := LootLabBatchJob.new()
	result._initialize(spec, equipment, foundation, generator_override)
	return result

func advance(max_attempts: int, time_budget_usec: int) -> int:
	if not is_active() or max_attempts <= 0:
		return 0
	if _cancel_requested:
		_finalize(&"cancelled")
		return 0
	var started_usec := Time.get_ticks_usec()
	var advanced := 0
	while advanced < max_attempts and _attempted < _spec.target_count:
		if _cancel_requested:
			break
		if time_budget_usec > 0 and advanced > 0 and Time.get_ticks_usec() - started_usec >= time_budget_usec:
			break
		var result := _generate_next()
		var record_error := _accumulator.record(_attempted, result)
		if not record_error.is_empty():
			_startup_error = record_error
			_finalize(&"failed")
			break
		_attempted += 1
		advanced += 1
		if result != null and result.ok():
			_succeeded += 1
		else:
			_failed += 1
	if _cancel_requested:
		_finalize(&"cancelled")
	elif _attempted >= _spec.target_count:
		_finalize(&"completed")
	return advanced

func request_cancel() -> void:
	if not is_active():
		return
	_cancel_requested = true
	_finalize(&"cancelled")

func is_active() -> bool:
	return _active and _terminal_report.is_empty()

func progress() -> Dictionary:
	var elapsed_seconds := maxf(float(Time.get_ticks_usec() - _started_usec) / 1000000.0, 0.0) if _started_usec > 0 else 0.0
	if not _terminal_report.is_empty():
		elapsed_seconds = float((_terminal_report.get("runtime", {}) as Dictionary).get("elapsed_seconds", elapsed_seconds))
	var throughput := float(_attempted) / elapsed_seconds if elapsed_seconds > 0.0 else 0.0
	return {
		"active": is_active(),
		"attempted": _attempted,
		"cancel_requested": _cancel_requested,
		"elapsed_seconds": elapsed_seconds,
		"failed": _failed,
		"items_per_second": throughput,
		"status": "active" if is_active() else String((_terminal_report.get("runtime", {}) as Dictionary).get("status", "failed")),
		"succeeded": _succeeded,
		"target": _spec.target_count if _spec != null else 0,
	}

func terminal_report() -> Dictionary:
	return _terminal_report.duplicate(true)

func startup_error() -> String:
	return _startup_error

func _initialize(
	spec: LootLabBatchSpec,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	generator_override: Callable
) -> void:
	if spec == null or not spec.ok():
		_fail_start("valid batch specification is required")
		return
	if equipment == null:
		_fail_start("equipment catalog is missing")
		return
	if foundation == null:
		_fail_start("foundation catalog is missing")
		return
	if not generator_override.is_null() and not generator_override.is_valid():
		_fail_start("generator override is invalid")
		return
	_spec = spec
	_equipment = equipment
	_foundation = foundation
	_generator_override = generator_override
	_accumulator = LootLabReportAccumulator.create(spec, equipment, foundation)
	if not _accumulator.error.is_empty():
		_fail_start(_accumulator.error)
		return
	_started_usec = Time.get_ticks_usec()
	_active = true

func _generate_next() -> ItemGenerationResult:
	var request := _spec.request_for_attempt(_attempted)
	if request == null:
		return null
	var result_value: Variant
	if _generator_override.is_valid():
		result_value = _generator_override.call(
			request,
			_spec.preview_issuer_namespace(),
			request.generation_sequence,
			_equipment,
			_foundation
		)
	else:
		result_value = ItemGenerationService.generate(
			request,
			_spec.preview_issuer_namespace(),
			request.generation_sequence,
			_equipment,
			_foundation
		)
	return result_value as ItemGenerationResult

func _finalize(status: StringName) -> void:
	if not _terminal_report.is_empty() or _accumulator == null:
		return
	_active = false
	var elapsed_seconds := maxf(float(Time.get_ticks_usec() - _started_usec) / 1000000.0, 0.0)
	var throughput := float(_attempted) / elapsed_seconds if elapsed_seconds > 0.0 else 0.0
	_terminal_report = _accumulator.finalize(status, {
		"elapsed_seconds": elapsed_seconds,
		"items_per_second": throughput,
	})
	if not _startup_error.is_empty():
		(_terminal_report["runtime"] as Dictionary)["error"] = _startup_error

func _fail_start(reason: String) -> void:
	_startup_error = "PARTY_FORGE_LOOT_LAB_JOB_ERROR reason=%s" % reason
	_active = false
	_terminal_report = {
		"evidence": {},
		"runtime": {
			"elapsed_seconds": 0.0,
			"error": _startup_error,
			"items_per_second": 0.0,
			"status": "failed",
		},
	}
