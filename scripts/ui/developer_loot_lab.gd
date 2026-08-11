class_name DeveloperLootLab
extends Control

signal sandbox_item_issued
signal close_requested
signal active_job_changed(active: bool)
signal focus_controls_changed

const ATTEMPTS_PER_FRAME := 256
const TIME_BUDGET_USEC := 4000

var _session: LootLabSessionController
var _sandbox_state: DeveloperItemSandboxState
var _tooltip: ItemTooltipPanel
var _presentation_projection: Callable
var _preferences_store := DeveloperLootLabPreferencesStore.new()
var _pending_large_spec: LootLabBatchSpec
var _pending_export_format: StringName
var _wired := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_initialized()

func configure(
	session: LootLabSessionController,
	sandbox_state: DeveloperItemSandboxState,
	tooltip: ItemTooltipPanel,
	presentation_projection: Callable = Callable()
) -> void:
	_session = session if session != null else LootLabSessionController.new()
	_sandbox_state = sandbox_state
	_tooltip = tooltip
	_presentation_projection = presentation_projection
	_ensure_initialized()

func configured() -> bool:
	return _session != null and _sandbox_state != null and _tooltip != null

func has_active_job() -> bool:
	return _session != null and _session.has_active_job()

func request_parent_close() -> bool:
	if not has_active_job():
		return true
	_show_dialog(get_node("CancelCloseConfirmation") as ConfirmationDialog)
	return false

func cancel_and_clear() -> void:
	if _session != null:
		_session.cancel()
		_session.clear()
	_pending_large_spec = null
	(get_node("BatchConfirmation") as ConfirmationDialog).hide()
	(get_node("CancelCloseConfirmation") as ConfirmationDialog).hide()
	_progress().value = 0
	_cancel_button().disabled = true
	active_job_changed.emit(false)
	_set_status("CANCELLED_AND_CLEARED")

func focus_controls() -> Array[Control]:
	_ensure_initialized()
	var result: Array[Control] = [
		get_node("Layout/Header/WorkbenchFocusAnchor") as Control,
		get_node("Layout/Header/AnalysisFocusAnchor") as Control,
	]
	if _workbench().visible:
		for control: Control in _form().focus_controls():
			result.append(control)
		for control: Control in _gallery().focus_controls():
			result.append(control)
		for control: Control in _inspector().focus_controls():
			result.append(control)
		result.append(_cancel_button())
	else:
		for control: Control in _analysis().focus_controls():
			result.append(control)
	return result

func _process(_delta: float) -> void:
	if _session == null or not _session.has_active_job():
		return
	_session.advance(ATTEMPTS_PER_FRAME, TIME_BUDGET_USEC)
	_present_progress()
	if not _session.has_active_job():
		_cancel_button().disabled = true
		active_job_changed.emit(false)
		_present_selected_report()

func _ensure_initialized() -> void:
	if _session == null:
		_session = LootLabSessionController.new()
	_form().configure(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, _preferences_store)
	_gallery().configure(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if _wired:
		return
	_wired = true
	_form().batch_requested.connect(_on_batch_requested)
	_gallery().sequence_selected.connect(_on_sequence_selected)
	_gallery().inspection_started.connect(_on_preview_inspection_started)
	_gallery().inspection_ended.connect(_on_preview_inspection_ended)
	_inspector().regenerate_requested.connect(_on_sequence_selected)
	_inspector().issue_requested.connect(_on_issue_requested)
	_analysis().report_kind_selected.connect(_on_report_kind_selected)
	_analysis().sequence_requested.connect(_on_analysis_sequence_requested)
	_analysis().export_requested.connect(_on_export_requested)
	(get_node("Layout/Header/WorkbenchFocusAnchor") as Button).pressed.connect(_show_workbench)
	(get_node("Layout/Header/AnalysisFocusAnchor") as Button).pressed.connect(_show_analysis)
	_cancel_button().pressed.connect(_on_cancel_active)
	(get_node("BatchConfirmation") as ConfirmationDialog).confirmed.connect(_on_large_batch_confirmed)
	(get_node("CancelCloseConfirmation") as ConfirmationDialog).confirmed.connect(_on_cancel_close_confirmed)
	(get_node("ReportExportDialog") as FileDialog).file_selected.connect(_on_export_file_selected)
	_cancel_button().disabled = true
	_set_view(false)

func _on_batch_requested(spec: LootLabBatchSpec) -> void:
	if spec == null or not spec.ok():
		_set_status("INVALID_BATCH")
		return
	if spec.target_count == LootLabBatchSpec.MAX_ATTEMPTS:
		_pending_large_spec = spec
		_show_dialog(get_node("BatchConfirmation") as ConfirmationDialog)
		return
	_start_batch(spec)

func _on_large_batch_confirmed() -> void:
	var spec := _pending_large_spec
	_pending_large_spec = null
	if spec != null:
		_start_batch(spec)

func _start_batch(spec: LootLabBatchSpec) -> void:
	var error := _session.start(spec, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not error.is_empty():
		_set_status(error)
		return
	var preference_error := _preferences_store.save(_form().preferences_document())
	_cancel_button().disabled = false
	_progress().max_value = spec.target_count
	_progress().value = 0
	active_job_changed.emit(true)
	_set_status("RUNNING" if preference_error.is_empty() else preference_error)

func _on_cancel_active() -> void:
	if not has_active_job():
		return
	_session.cancel()
	_cancel_button().disabled = true
	active_job_changed.emit(false)
	_present_selected_report()

func _on_cancel_close_confirmed() -> void:
	cancel_and_clear()
	close_requested.emit()

func _present_progress() -> void:
	var progress := _session.progress()
	_progress().max_value = maxi(int(progress.get("target", 1)), 1)
	_progress().value = int(progress.get("attempted", 0))
	_outcome().text = "Attempted: %d / %d\nSucceeded: %d\nFailed: %d" % [
		int(progress.get("attempted", 0)), int(progress.get("target", 0)),
		int(progress.get("succeeded", 0)), int(progress.get("failed", 0)),
	]

func _present_selected_report() -> void:
	var report := _session.selected_report()
	if report.is_empty():
		_set_status("NO_REPORT")
		return
	var evidence := report.get("evidence", {}) as Dictionary
	var summary := evidence.get("summary", {}) as Dictionary
	var runtime := report.get("runtime", {}) as Dictionary
	_outcome().text = "Attempted: %d / %d\nSucceeded: %d\nFailed: %d\nStatus: %s" % [
		int(summary.get("attempted", 0)), int(summary.get("target", 0)),
		int(summary.get("succeeded", 0)), int(summary.get("failed", 0)),
		String(runtime.get("status", "unknown")).to_upper(),
	]
	_progress().max_value = maxi(int(summary.get("target", 1)), 1)
	_progress().value = int(summary.get("attempted", 0))
	_gallery().present(report)
	_analysis().set_report_availability(_session.available_report_kinds())
	_analysis().select_report_kind(_session.selected_report_kind())
	_analysis().present(report)
	var samples := evidence.get("samples", []) as Array
	if not samples.is_empty():
		_on_sequence_selected(int((samples[0] as Dictionary).get("generation_sequence", -1)))
	_set_status("REPORT_%s" % String(runtime.get("status", "UNKNOWN")).to_upper())

func _on_sequence_selected(sequence: int) -> void:
	var result := _session.regenerate_sequence(sequence)
	if result == null:
		_set_status("SEQUENCE_UNAVAILABLE")
		return
	var report := _session.selected_report()
	var request := ((report.get("evidence", {}) as Dictionary).get("request", {}) as Dictionary).duplicate(true)
	request["generation_sequence"] = sequence
	_inspector().present_result(result, request)

func _on_analysis_sequence_requested(sequence: int) -> void:
	_on_sequence_selected(sequence)
	_show_workbench()

func _on_report_kind_selected(kind: StringName) -> void:
	var error := _session.select_report(kind)
	if not error.is_empty():
		_set_status(error)
		return
	_present_selected_report()

func _show_workbench() -> void:
	_set_view(false)

func _show_analysis() -> void:
	_set_view(true)
	if not _session.selected_report().is_empty():
		_analysis().present(_session.selected_report())

func _set_view(show_analysis: bool) -> void:
	_workbench().visible = not show_analysis
	_analysis().visible = show_analysis
	for control: Control in _all_local_focus_controls():
		control.focus_mode = Control.FOCUS_NONE
	focus_controls_changed.emit()

func _all_local_focus_controls() -> Array[Control]:
	var result: Array[Control] = [
		get_node("Layout/Header/WorkbenchFocusAnchor") as Control,
		get_node("Layout/Header/AnalysisFocusAnchor") as Control,
		_cancel_button(),
	]
	for control: Control in _form().focus_controls():
		result.append(control)
	for control: Control in _gallery().focus_controls():
		result.append(control)
	for control: Control in _inspector().focus_controls():
		result.append(control)
	for control: Control in _analysis().focus_controls():
		result.append(control)
	return result

func _on_export_requested(format: StringName) -> void:
	if _session.selected_report().is_empty():
		_set_status("EXPORT_FAILED no report")
		return
	_pending_export_format = format
	var dialog := get_node("ReportExportDialog") as FileDialog
	dialog.filters = PackedStringArray(["*.json ; JSON report"] if format == &"json" else ["*.md ; Markdown report"])
	dialog.current_file = "party-forge-loot-lab.%s" % ("json" if format == &"json" else "md")
	if dialog.is_inside_tree():
		dialog.popup_centered_ratio(0.8)
	else:
		dialog.visible = true

func _on_export_file_selected(path: String) -> void:
	_export_selected_report(path, _pending_export_format)

func _export_selected_report(path: String, format: StringName) -> String:
	var report := _session.selected_report() if _session != null else {}
	if report.is_empty():
		return _export_error("report unavailable")
	var contents := ""
	match format:
		&"json":
			contents = LootLabReportExportService.to_json(report)
		&"markdown":
			contents = LootLabReportExportService.to_markdown(report)
		_:
			return _export_error("unknown format %s" % format)
	if contents.is_empty():
		return _export_error("report serialization failed")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _export_error("open failed %s" % error_string(FileAccess.get_open_error()))
	file.store_string(contents)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _export_error("write failed %s" % error_string(write_error))
	_set_status("EXPORTED_%s" % String(format).to_upper())
	return ""

func _export_error(reason: String) -> String:
	var error := "PARTY_FORGE_LOOT_LAB_EXPORT_ERROR reason=%s" % reason
	_set_status(error)
	return error

func _on_issue_requested(item: ItemInstance) -> void:
	if _sandbox_state == null:
		_set_status("ISSUE_FAILED state unavailable")
		return
	var error := _sandbox_state.issue_generated_item(item, DeveloperItemSandboxState.STASH_ID)
	if not error.is_empty():
		_set_status(error)
		return
	sandbox_item_issued.emit()
	_set_status("ISSUED_TO_SANDBOX")

func _on_preview_inspection_started(detail: Dictionary, source: StorageSlotButton) -> void:
	if _tooltip != null and not detail.is_empty():
		_tooltip.show_item(detail, [], source, source.source_id(), true)

func _on_preview_inspection_ended(source_id: String) -> void:
	if _tooltip != null:
		_tooltip.release_item(source_id)

func _set_status(value: String) -> void:
	_status().text = value
	_status().tooltip_text = value

func _show_dialog(dialog: ConfirmationDialog) -> void:
	if dialog.is_inside_tree():
		dialog.popup_centered()
	else:
		dialog.visible = true

func _form() -> LootLabRequestForm:
	return get_node("Layout/Workbench/RequestScroll/RequestForm") as LootLabRequestForm

func _gallery() -> LootLabSampleGallery:
	return get_node("Layout/Workbench/Results/SampleScroll/SampleGrid") as LootLabSampleGallery

func _inspector() -> LootLabTraceInspector:
	return get_node("Layout/Workbench/InspectorScroll/TraceInspector") as LootLabTraceInspector

func _analysis() -> Variant:
	return get_node("Layout/Analysis")

func _workbench() -> Control:
	return get_node("Layout/Workbench") as Control

func _outcome() -> Label:
	return get_node("Layout/Workbench/Results/OutcomeSummary") as Label

func _progress() -> ProgressBar:
	return get_node("Layout/Workbench/Results/Progress") as ProgressBar

func _cancel_button() -> Button:
	return get_node("Layout/Workbench/Results/Cancel") as Button

func _status() -> Label:
	return get_node("Layout/FooterStatus") as Label
