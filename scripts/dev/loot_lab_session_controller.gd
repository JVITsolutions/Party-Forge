class_name LootLabSessionController
extends RefCounted

var _active_job: LootLabBatchJob
var _active_spec: LootLabBatchSpec
var _active_equipment: EquipmentCatalog
var _active_foundation: ItemFoundationCatalog
var _active_generator: Callable

var _latest_completed_report: Dictionary = {}
var _latest_partial_report: Dictionary = {}
var _completed_spec: LootLabBatchSpec
var _partial_spec: LootLabBatchSpec
var _completed_equipment: EquipmentCatalog
var _partial_equipment: EquipmentCatalog
var _completed_foundation: ItemFoundationCatalog
var _partial_foundation: ItemFoundationCatalog
var _completed_generator: Callable
var _partial_generator: Callable
var _selected_report_kind: StringName

func start(
	spec: LootLabBatchSpec,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	generator_override: Callable = Callable()
) -> String:
	if has_active_job():
		return _error("state", "a batch job is already active")
	var job := LootLabBatchJob.create(spec, equipment, foundation, generator_override)
	if not job.startup_error().is_empty():
		return job.startup_error()
	_active_job = job
	_active_spec = spec
	_active_equipment = equipment
	_active_foundation = foundation
	_active_generator = generator_override
	return ""

func advance(max_attempts: int, time_budget_usec: int) -> int:
	if not has_active_job():
		return 0
	var advanced := _active_job.advance(max_attempts, time_budget_usec)
	_harvest_terminal()
	return advanced

func cancel() -> void:
	if not has_active_job():
		return
	_active_job.request_cancel()
	_harvest_terminal()

func has_active_job() -> bool:
	return _active_job != null and _active_job.is_active()

func progress() -> Dictionary:
	if _active_job != null:
		return _active_job.progress()
	var selected := selected_report()
	if selected.is_empty():
		return {}
	var summary := (selected.get("evidence", {}) as Dictionary).get("summary", {}) as Dictionary
	return summary.duplicate(true)

func select_report(kind: StringName) -> String:
	match kind:
		&"complete":
			if _latest_completed_report.is_empty():
				return _error("report", "completed report is unavailable")
		&"partial":
			if _latest_partial_report.is_empty():
				return _error("report", "partial report is unavailable")
		_:
			return _error("report", "unknown report kind %s" % kind)
	_selected_report_kind = kind
	return ""

func selected_report() -> Dictionary:
	if _selected_report_kind == &"partial" and not _latest_partial_report.is_empty():
		return _latest_partial_report.duplicate(true)
	if not _latest_completed_report.is_empty():
		return _latest_completed_report.duplicate(true)
	if not _latest_partial_report.is_empty():
		return _latest_partial_report.duplicate(true)
	return {}

func regenerate_sequence(sequence: int) -> ItemGenerationResult:
	var report := selected_report()
	if report.is_empty():
		return null
	var spec: LootLabBatchSpec
	var equipment: EquipmentCatalog
	var foundation: ItemFoundationCatalog
	var generator: Callable
	if _selected_report_kind == &"partial":
		spec = _partial_spec
		equipment = _partial_equipment
		foundation = _partial_foundation
		generator = _partial_generator
	else:
		spec = _completed_spec
		equipment = _completed_equipment
		foundation = _completed_foundation
		generator = _completed_generator
	if spec == null or equipment == null or foundation == null:
		return null
	var evidence := report.get("evidence", {}) as Dictionary
	var summary := evidence.get("summary", {}) as Dictionary
	var range := evidence.get("sequence_range", {}) as Dictionary
	var start_sequence := int(range.get("start", -1))
	var attempt_index := sequence - start_sequence
	if attempt_index < 0 or attempt_index >= int(summary.get("attempted", 0)):
		return null
	var request := spec.request_for_attempt(attempt_index)
	if request == null:
		return null
	var result_value: Variant
	if generator.is_valid():
		result_value = generator.call(request, spec.preview_issuer_namespace(), sequence, equipment, foundation)
	else:
		result_value = ItemGenerationService.generate(request, spec.preview_issuer_namespace(), sequence, equipment, foundation)
	return result_value as ItemGenerationResult

func clear() -> void:
	if has_active_job():
		_active_job.request_cancel()
	_active_job = null
	_active_spec = null
	_active_equipment = null
	_active_foundation = null
	_active_generator = Callable()
	_latest_completed_report = {}
	_latest_partial_report = {}
	_completed_spec = null
	_partial_spec = null
	_completed_equipment = null
	_partial_equipment = null
	_completed_foundation = null
	_partial_foundation = null
	_completed_generator = Callable()
	_partial_generator = Callable()
	_selected_report_kind = &""

func _harvest_terminal() -> void:
	if _active_job == null or _active_job.is_active():
		return
	var report := _active_job.terminal_report()
	var status := StringName((report.get("runtime", {}) as Dictionary).get("status", "failed"))
	if status == &"completed":
		_latest_completed_report = report
		_completed_spec = _active_spec
		_completed_equipment = _active_equipment
		_completed_foundation = _active_foundation
		_completed_generator = _active_generator
		_latest_partial_report = {}
		_partial_spec = null
		_partial_equipment = null
		_partial_foundation = null
		_partial_generator = Callable()
		_selected_report_kind = &"complete"
	elif status == &"cancelled":
		_latest_partial_report = report
		_partial_spec = _active_spec
		_partial_equipment = _active_equipment
		_partial_foundation = _active_foundation
		_partial_generator = _active_generator
		_selected_report_kind = &"partial"
	_active_job = null
	_active_spec = null
	_active_equipment = null
	_active_foundation = null
	_active_generator = Callable()

func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_LOOT_LAB_SESSION_ERROR field=%s reason=%s" % [field, reason]
