extends RefCounted

const PANEL_SCENE := "res://scenes/ui/run_result_panel.tscn"
const FIXTURE_PATH := "res://tests/unit/test_run_recap_projection.gd"
const VIEW_MODEL_PATH := "res://scripts/ui/run_result/run_result_view_model.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var packed := load(PANEL_SCENE) as PackedScene
	var fixture_type := load(FIXTURE_PATH) as Script
	var view_model_type := load(VIEW_MODEL_PATH) as Script
	TestAssertions.truthy(packed != null, "Living Forge run result panel scene exists", failures)
	TestAssertions.truthy(view_model_type != null, "run result panel receives typed projections", failures)
	if packed == null or fixture_type == null or view_model_type == null:
		return failures
	var panel := packed.instantiate() as Control
	TestAssertions.truthy(panel != null, "run result panel instantiates", failures)
	if panel == null:
		return failures
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(panel)
	var fixture_helper: Variant = fixture_type.new()
	var fixture: Dictionary = fixture_helper.call(&"_fixture", 24, 24, RunTerminalSnapshot.Outcome.VICTORY)
	var view_model: Variant = view_model_type.new()
	TestAssertions.truthy(panel.has_method(&"present") and not panel.has_method(&"show_result"), "present(projection) is the only result presentation entry point", failures)
	_test_exact_labels_and_states(panel, view_model, fixture, failures)
	_test_finalized_truth_scroll_and_accessibility(panel, view_model, fixture, failures)
	_test_action_signals_pending_and_focus(panel, view_model, fixture, failures)
	panel.get_parent().remove_child(panel)
	panel.free()
	return failures

func _test_exact_labels_and_states(panel: Control, view_model: Variant, fixture: Dictionary, failures: Array[String]) -> void:
	var labels := {
		"RetryTerminalSave": "Retry Terminal Save",
		"RetryTerminalRefresh": "Retry Terminal Recovery",
		"RetryResolution": "Retry Resolution",
		"RetryProjection": "Retry Results",
		"ProtectDisplacedGear": "Protect Displaced Gear",
		"OpenArmoury": "Open Armoury",
		"RestartRun": "Restart Run",
		"ReturnToForge": "Return to Forge",
		"QuitApplication": "Quit Application",
	}
	for node_name: String in labels:
		var button := _button(panel, node_name)
		TestAssertions.truthy(button != null, "%s action exists" % labels[node_name], failures)
		if button != null:
			TestAssertions.equal(button.text, labels[node_name], "%s uses exact consequence label" % node_name, failures)
			TestAssertions.truthy(button.custom_minimum_size.x >= 48.0 and button.custom_minimum_size.y >= 48.0, "%s target is at least 48 px" % node_name, failures)
			TestAssertions.truthy(not button.accessibility_name.strip_edges().is_empty(), "%s has an explicit accessible name" % node_name, failures)

	panel.call(&"present", view_model.call(&"pending", fixture.snapshot).get("projection"))
	TestAssertions.equal(_state_text(panel), "SAVING TERMINAL TRUTH", "pending state is visibly distinct", failures)
	TestAssertions.truthy(not _headline(panel).text.contains("Victory") and not _headline(panel).text.contains("Defeat"), "pending hierarchy exposes no unverified outcome headline", failures)
	TestAssertions.truthy(_visible_actions(panel).is_empty(), "pending projection exposes no actions", failures)
	TestAssertions.truthy(not _body(panel).visible, "pending projection exposes no partial recap", failures)
	var projection_source := FileAccess.get_file_as_string("res://scripts/ui/run_result/run_result_projection.gd")
	var has_typed_pending := "enum PendingKind" in projection_source and "pending_kind" in projection_source
	TestAssertions.truthy(has_typed_pending, "pending presentation receives a typed operation kind", failures)
	if has_typed_pending:
		var expected_pending_copy: Array[String] = ["SAVING TERMINAL TRUTH", "REFRESHING TERMINAL RECOVERY", "RESOLVING TERMINAL RUN", "REBUILDING RESULTS", "PROTECTING DISPLACED GEAR", "COMPLETING TERMINAL RECORD"]
		var expected_progress_copy: Array[String] = ["SECURING TERMINAL TRUTH", "REFRESHING TERMINAL RECOVERY", "RESOLVING TERMINAL RUN", "REBUILDING RESULT PRESENTATION", "PROTECTING DISPLACED GEAR", "COMPLETING TERMINAL RECORD"]
		for pending_kind: int in expected_pending_copy.size():
			panel.call(&"present", view_model.call(&"pending", fixture.snapshot, pending_kind).get("projection"))
			TestAssertions.equal(_state_text(panel), expected_pending_copy[pending_kind], "pending kind %d uses operation-accurate copy" % pending_kind, failures)
			var progress := panel.get_node_or_null("Frame/Content/PendingProgress") as Control
			var step := panel.get_node_or_null("Frame/Content/PendingProgress/Content/Step") as Label
			var status := panel.get_node_or_null("Frame/Content/PendingProgress/Content/Status") as Label
			TestAssertions.truthy(progress != null and progress.visible, "pending kind %d shows a compact static operation indicator" % pending_kind, failures)
			TestAssertions.truthy(step != null and step.text == "ACTIVE TERMINAL OPERATION", "pending kind %d uses a non-sequential active-operation indicator" % pending_kind, failures)
			TestAssertions.truthy(status != null and status.text == "%s · IN PROGRESS · NOT YET FINAL" % expected_progress_copy[pending_kind], "pending kind %d uses truthful non-final progress copy" % pending_kind, failures)
			TestAssertions.truthy(progress != null and not progress.accessibility_name.strip_edges().is_empty(), "pending kind %d has explicit accessible progress copy" % pending_kind, failures)
			TestAssertions.truthy(_visible_actions(panel).is_empty() and not _body(panel).visible, "pending kind %d exposes neither actions nor a partial recap" % pending_kind, failures)
		var reduced_settings := PartyForgeSettings.new()
		reduced_settings.reduced_motion = true
		var reduced_pending: RunResultProjection = view_model.call(&"pending", fixture.snapshot, RunResultProjection.PendingKind.PROJECTION).get("projection").with_visual_settings(reduced_settings)
		panel.call(&"present", reduced_pending)
		var reduced_progress := panel.get_node("Frame/Content/PendingProgress") as Control
		TestAssertions.truthy(reduced_progress.visible and (reduced_progress.get_node("Content/Status") as Label).text.ends_with("IN PROGRESS · NOT YET FINAL"), "reduced-motion pending state keeps the same truthful static indicator", failures)
		TestAssertions.truthy(reduced_progress.find_children("*", "AnimationPlayer", true, false).is_empty(), "pending progress uses no motion-dependent animation", failures)

	panel.call(&"present", view_model.call(&"terminal_save_interrupted", fixture.snapshot, "Terminal record could not be saved.").get("projection"))
	TestAssertions.equal(_state_text(panel), "TERMINAL SAVE INTERRUPTED", "terminal-save interruption is visibly distinct", failures)
	TestAssertions.equal(_visible_action_names(panel), ["RetryTerminalSave"], "terminal-save interruption exposes one exact retry", failures)
	TestAssertions.equal(_reason(panel).text, "Terminal record could not be saved.", "save interruption presents readable reason", failures)
	if panel.is_inside_tree(): TestAssertions.truthy(_button(panel, "RetryTerminalSave").has_focus(), "Retry Terminal Save owns safe initial focus", failures)
	panel.call(&"present", view_model.call(&"terminal_refresh_interrupted", fixture.snapshot, "Terminal state was saved, but recovery could not refresh.").get("projection"))
	TestAssertions.equal(_state_text(panel), "TERMINAL REFRESH INTERRUPTED", "post-save refresh interruption is visibly distinct", failures)
	TestAssertions.equal(_visible_action_names(panel), ["RetryTerminalRefresh"], "post-save refresh interruption exposes one exact refresh-only retry", failures)
	if panel.is_inside_tree(): TestAssertions.truthy(_button(panel, "RetryTerminalRefresh").has_focus(), "Retry Terminal Recovery owns safe initial focus", failures)

	panel.call(&"present", view_model.call(&"resolution_interrupted", fixture.snapshot, "Resolution was interrupted.", null).get("projection"))
	TestAssertions.equal(_state_text(panel), "RESOLUTION INTERRUPTED", "resolution interruption is visibly distinct", failures)
	TestAssertions.equal(_visible_action_names(panel), ["RetryResolution"], "resolution interruption exposes one exact retry when unsafe", failures)
	if panel.is_inside_tree(): TestAssertions.truthy(_button(panel, "RetryResolution").has_focus(), "Retry Resolution owns safe initial focus", failures)
	TestAssertions.truthy(not _button(panel, "RestartRun").visible, "Restart is absent from interrupted truth", failures)

	panel.call(&"present", view_model.call(&"projection_interrupted", fixture.snapshot, fixture.resolution, "Results could not be built.").get("projection"))
	TestAssertions.equal(_state_text(panel), "RESULTS INTERRUPTED", "projection interruption is visibly distinct", failures)
	TestAssertions.equal(_visible_action_names(panel), ["RetryProjection"], "projection interruption exposes Retry Results only", failures)
	if panel.is_inside_tree():
		TestAssertions.truthy(_button(panel, "RetryProjection").has_focus(), "Retry Results is sole initial default focus", failures)

	var finalized: Variant = view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, []).get("projection")
	panel.call(&"present", finalized)
	TestAssertions.equal(_state_text(panel), "RUN FINALIZED", "finalized state is visibly distinct", failures)
	TestAssertions.equal(_headline(panel).text, "VICTORY · 01:30", "finalized hierarchy leads with verified outcome and duration", failures)
	TestAssertions.equal(_visible_action_names(panel), ["RestartRun", "ReturnToForge", "QuitApplication"], "finalized exposes the exact terminal action set only", failures)
	for guarded_only: String in ["RetryTerminalSave", "RetryTerminalRefresh", "RetryResolution", "RetryProjection", "ProtectDisplacedGear", "OpenArmoury"]:
		TestAssertions.truthy(not _button(panel, guarded_only).visible, "%s is absent from finalized truth" % guarded_only, failures)
	TestAssertions.truthy(panel.find_child("AbandonRun", true, false) == null, "terminal results never expose Abandon Run", failures)
	TestAssertions.truthy(not _button(panel, "QuitApplication").has_focus() and not _button(panel, "RestartRun").has_focus(), "destructive/consequence actions never receive default focus", failures)
	var has_action_error: bool = view_model.has_method(&"finalized_action_interrupted")
	TestAssertions.truthy(has_action_error, "panel receives a typed finalized action-rejection projection", failures)
	if has_action_error:
		var action_error: Variant = view_model.call(&"finalized_action_interrupted", finalized, "Terminal record could not be cleared. Retry Restart Run.").get("projection")
		panel.call(&"present", action_error, &"RestartRun")
		TestAssertions.truthy(_reason(panel).visible and _reason(panel).text == "Terminal record could not be cleared. Retry Restart Run.", "finalized receipt-clear failure is readable and non-claiming", failures)
		TestAssertions.equal(_visible_action_names(panel), ["RestartRun", "ReturnToForge", "QuitApplication"], "receipt-clear failure restores exact finalized actions", failures)
		if panel.is_inside_tree(): TestAssertions.truthy(_button(panel, "RestartRun").has_focus(), "receipt-clear failure restores exact initiating action focus", failures)

func _test_finalized_truth_scroll_and_accessibility(panel: Control, view_model: Variant, fixture: Dictionary, failures: Array[String]) -> void:
	var built: Variant = view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, [])
	TestAssertions.truthy(bool(built.call(&"ok")), "24-member/item panel fixture builds", failures)
	if not bool(built.call(&"ok")):
		return
	var settings := PartyForgeSettings.new()
	settings.high_contrast = true
	settings.reduced_motion = true
	settings.ui_scale_percent = 150
	settings.text_scale_percent = 150
	var projection: Variant = built.get("projection").call(&"with_visual_settings", settings)
	panel.call(&"present", projection)
	var body := _body(panel)
	TestAssertions.truthy(body.visible and body is ScrollContainer, "finalized truth uses one bounded scroll region", failures)
	var party_rows := _entry_rows(panel, &"party")
	var loot_rows := _entry_rows(panel, &"loot")
	TestAssertions.equal(party_rows.size(), 24, "all 24 final party members are reachable", failures)
	TestAssertions.equal(loot_rows.size(), 30, "two automatic, two selected, 24 lost, and two protected items are all reachable", failures)
	if party_rows.size() == 24:
		TestAssertions.equal(String(party_rows[23].get_meta(&"recap_entry_label", "")), "Member 24", "final party member retains stable order", failures)
	for row: Button in party_rows + loot_rows:
		TestAssertions.truthy(row.custom_minimum_size.y >= 48.0, "%s recap row remains a 48 px target" % row.name, failures)
		TestAssertions.truthy(not row.accessibility_name.strip_edges().is_empty(), "%s recap row has an explicit accessible name" % row.name, failures)
	if not loot_rows.is_empty():
		var expandable := loot_rows[0] as Button
		expandable.pressed.emit()
		var detail := expandable.get_node_or_null("Detail") as Label
		TestAssertions.truthy(detail != null and detail.visible and not detail.text.strip_edges().is_empty(), "bounded row expands authoritative detail without tiny filler", failures)
	var frame := panel.get_node("Frame") as PanelContainer
	TestAssertions.equal(frame.theme_type_variation, &"LivingForgePanel", "result frame uses forged Living Forge surface", failures)
	TestAssertions.truthy(panel.theme == LivingForgeThemeCatalog.resolve(true, 150, 150), "panel applies projection-carried high-contrast/scaled Living Forge theme", failures)
	TestAssertions.truthy(frame.custom_minimum_size.x <= 900.0 and body.custom_minimum_size.y <= 520.0, "150% high-contrast layout remains bounded for a 720p viewport", failures)
	TestAssertions.truthy(not panel.has_method(&"_process"), "result presentation does not rebuild providers from a frame loop", failures)

func _test_action_signals_pending_and_focus(panel: Control, view_model: Variant, fixture: Dictionary, failures: Array[String]) -> void:
	var observed := {"retry_results": 0, "retry_save": 0, "retry_refresh": 0, "retry_resolution": 0, "protection_emissions": 0, "protection_focus": null, "armoury_focus": null}
	panel.retry_projection_requested.connect(func() -> void: observed.retry_results = int(observed.retry_results) + 1)
	panel.retry_terminal_save_requested.connect(func() -> void: observed.retry_save = int(observed.retry_save) + 1)
	panel.retry_terminal_refresh_requested.connect(func() -> void: observed.retry_refresh = int(observed.retry_refresh) + 1)
	panel.retry_resolution_requested.connect(func() -> void: observed.retry_resolution = int(observed.retry_resolution) + 1)
	panel.protect_displaced_gear_requested.connect(func(return_focus: Control) -> void:
		observed.protection_emissions = int(observed.protection_emissions) + 1
		observed.protection_focus = return_focus
	)
	panel.open_armoury_requested.connect(func(return_focus: Control) -> void: observed.armoury_focus = return_focus)

	var projection_failed: Variant = view_model.call(&"projection_interrupted", fixture.snapshot, fixture.resolution, "Results could not be built.").get("projection")
	panel.call(&"present", projection_failed)
	_button(panel, "RetryProjection").pressed.emit()
	_button(panel, "RetryProjection").pressed.emit()
	TestAssertions.equal(int(observed.retry_results), 1, "duplicate pending Retry Results activation is suppressed", failures)
	TestAssertions.truthy(_button(panel, "RetryProjection").disabled, "retry enters disabled pending state immediately", failures)
	panel.call(&"present", projection_failed)
	_button(panel, "RetryProjection").pressed.emit()
	TestAssertions.equal(int(observed.retry_results), 2, "fresh typed projection explicitly clears local pending gate", failures)

	var save_failed: Variant = view_model.call(&"terminal_save_interrupted", fixture.snapshot, "save failed").get("projection")
	panel.call(&"present", save_failed)
	_button(panel, "RetryTerminalSave").pressed.emit()
	_button(panel, "RetryTerminalSave").pressed.emit()
	TestAssertions.equal(int(observed.retry_save), 1, "initial-save retry suppresses duplicate pending activation", failures)
	var refresh_failed: Variant = view_model.call(&"terminal_refresh_interrupted", fixture.snapshot, "refresh failed").get("projection")
	panel.call(&"present", refresh_failed)
	_button(panel, "RetryTerminalRefresh").pressed.emit()
	_button(panel, "RetryTerminalRefresh").pressed.emit()
	TestAssertions.equal(int(observed.retry_refresh), 1, "post-save refresh retry suppresses duplicate pending activation", failures)
	var resolution_failed: Variant = view_model.call(&"resolution_interrupted", fixture.snapshot, "resolution failed", null).get("projection")
	panel.call(&"present", resolution_failed)
	_button(panel, "RetryResolution").pressed.emit()
	_button(panel, "RetryResolution").pressed.emit()
	TestAssertions.equal(int(observed.retry_resolution), 1, "resolution retry suppresses duplicate pending activation", failures)

	var automatic_evaluation := RunResolutionEvaluation.create(fixture.resolution.accepted_extraction, 2, 0, 0, "automatic-only blocked", RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, "Automatic retained items need more destination space.")
	var preflight := RunResolutionPreflightResult.from_evaluation(automatic_evaluation)
	var durable := _durable_safety(fixture.snapshot, [])
	var guarded: Variant = view_model.call(&"resolution_interrupted", fixture.snapshot, preflight.player_reason, durable, preflight).get("projection")
	panel.call(&"present", guarded)
	TestAssertions.equal(_visible_action_names(panel), ["RetryResolution", "ProtectDisplacedGear", "OpenArmoury", "ReturnToForge", "QuitApplication"], "guarded interruption exposes the exact authorized action set", failures)
	if panel.is_inside_tree(): TestAssertions.truthy(_button(panel, "ProtectDisplacedGear").has_focus(), "automatic-only interruption defaults to Protect Displaced Gear", failures)
	TestAssertions.truthy(not _button(panel, "RestartRun").visible, "guarded interruption never exposes Restart", failures)
	var synthetic_recap_row := Button.new()
	synthetic_recap_row.name = "SyntheticBackgroundRecapRow"
	synthetic_recap_row.focus_mode = Control.FOCUS_ALL
	(panel.get_node("Frame/Content/Body/Recap") as VBoxContainer).add_child(synthetic_recap_row)
	var protect := _button(panel, "ProtectDisplacedGear")
	protect.pressed.emit()
	TestAssertions.truthy(_confirmation(panel).visible, "Protect Displaced Gear opens explicit confirmation", failures)
	TestAssertions.equal((_confirmation(panel).get_node("Content/Copy") as Label).text, "Move 2 current leader items to Recovery Overflow so automatic extraction can continue.", "protection confirmation uses exact copy and typed count", failures)
	var cancel := _confirmation(panel).get_node("Content/Actions/Cancel") as Button
	var confirm := _confirmation(panel).get_node("Content/Actions/Confirm") as Button
	TestAssertions.equal(confirm.theme_type_variation, &"LivingForgePrimaryButton", "protection confirmation uses a primary warning treatment rather than destructive styling", failures)
	for footer_action: Button in _visible_actions(panel):
		TestAssertions.truthy(footer_action.disabled and footer_action.focus_mode == Control.FOCUS_NONE, "protection confirmation isolates footer action %s" % footer_action.name, failures)
	TestAssertions.truthy(synthetic_recap_row.disabled and synthetic_recap_row.focus_mode == Control.FOCUS_NONE and synthetic_recap_row.mouse_filter == Control.MOUSE_FILTER_IGNORE, "protection confirmation isolates recap/background controls", failures)
	TestAssertions.equal(cancel.focus_next, cancel.get_path_to(confirm), "Tab stays inside confirmation from Cancel to Confirm", failures)
	TestAssertions.equal(confirm.focus_next, confirm.get_path_to(cancel), "Tab wraps inside confirmation from Confirm to Cancel", failures)
	TestAssertions.equal(cancel.focus_previous, cancel.get_path_to(confirm), "Shift-Tab stays inside confirmation", failures)
	if panel.is_inside_tree():
		TestAssertions.truthy(cancel.has_focus(), "safe Cancel is the protection confirmation default", failures)
		TestAssertions.truthy(not confirm.has_focus(), "irreversible protection Confirm is never default-focused", failures)
	cancel.pressed.emit()
	TestAssertions.truthy(not _confirmation(panel).visible, "protection cancel closes the confirmation", failures)
	if panel.is_inside_tree():
		TestAssertions.truthy(protect.has_focus(), "protection cancel restores exact initiating focus", failures)
	protect.pressed.emit()
	confirm.pressed.emit()
	confirm.pressed.emit()
	TestAssertions.equal(int(observed.protection_emissions), 1, "Protect confirmation double-press emits exactly one signal", failures)
	TestAssertions.truthy(confirm.disabled and protect.disabled, "confirmed protection enters disabled pending state", failures)
	TestAssertions.truthy(observed.protection_focus == protect, "protection signal carries the exact return-focus control", failures)

	panel.call(&"present", guarded)
	var armoury := _button(panel, "OpenArmoury")
	armoury.pressed.emit()
	TestAssertions.truthy(observed.armoury_focus == armoury, "Open Armoury signal carries exact initiating focus", failures)

func _button(panel: Control, name_value: String) -> Button:
	return panel.get_node_or_null("Frame/Content/Footer/Actions/%s" % name_value) as Button

func _visible_actions(panel: Control) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in panel.get_node("Frame/Content/Footer/Actions").get_children():
		if child is Button and (child as Button).visible:
			result.append(child as Button)
	return result

func _visible_action_names(panel: Control) -> Array[String]:
	var result: Array[String] = []
	for button: Button in _visible_actions(panel):
		result.append(button.name)
	return result

func _entry_rows(panel: Control, section_id: StringName) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in panel.find_children("*", "Button", true, false):
		if node.get_meta(&"recap_section_id", &"") == section_id:
			result.append(node as Button)
	return result

func _state_text(panel: Control) -> String:
	return (panel.get_node("Frame/Content/Header/State") as Label).text

func _reason(panel: Control) -> Label:
	return panel.get_node("Frame/Content/Header/ReadableReason") as Label

func _headline(panel: Control) -> Label:
	return panel.get_node("Frame/Content/Header/OutcomeHeadline") as Label

func _body(panel: Control) -> ScrollContainer:
	return panel.get_node("Frame/Content/Body") as ScrollContainer

func _confirmation(panel: Control) -> PanelContainer:
	return panel.get_node("Frame/Content/Confirmation") as PanelContainer

func _durable_safety(snapshot: RunTerminalSnapshot, displaced_ids: Array[String]) -> RunTerminalRecoverySafetyResult:
	var empty: Array[String] = []
	var record_result := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION, snapshot,
		empty, "", displaced_ids, "", null, "",
	)
	return RunTerminalRecoverySafetyResult.success(record_result.record) if record_result.ok() else RunTerminalRecoverySafetyResult.failure(record_result.error)
