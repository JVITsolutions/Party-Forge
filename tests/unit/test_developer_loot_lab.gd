extends RefCounted

const LAB_SCENE := "res://scenes/ui/developer_loot_lab.tscn"

func run() -> Array[String]:
	var failures: Array[String] = []
	var packed := load(LAB_SCENE) as PackedScene
	TestAssertions.truthy(packed != null, "Loot Lab scene loads", failures)
	if packed == null:
		return failures
	var lab := packed.instantiate() as DeveloperLootLab
	var tree := Engine.get_main_loop() as SceneTree
	var tooltip := (load("res://scenes/ui/storage/item_tooltip_panel.tscn") as PackedScene).instantiate() as ItemTooltipPanel
	var state := DeveloperItemSandboxState.new()
	var session := LootLabSessionController.new()
	TestAssertions.equal(state.reset(), "", "Loot Lab fixture resets isolated sandbox", failures)
	tree.root.add_child(tooltip)
	tree.root.add_child(lab)
	lab.configure(session, state, tooltip)
	TestAssertions.truthy(lab.configured(), "Loot Lab receives only bounded sandbox dependencies", failures)
	for path: NodePath in [^"Layout/Workbench/RequestScroll/RequestForm", ^"Layout/Workbench/Results/OutcomeSummary", ^"Layout/Workbench/Results/SampleScroll/SampleGrid", ^"Layout/Workbench/InspectorScroll/TraceInspector", ^"Layout/Analysis", ^"ReportExportDialog", ^"BatchConfirmation", ^"CancelCloseConfirmation"]:
		TestAssertions.truthy(lab.get_node_or_null(path) != null, "Workbench exposes %s" % path, failures)

	var form := lab.get_node("Layout/Workbench/RequestScroll/RequestForm") as LootLabRequestForm
	var one := form.preferences_document()
	one["batch_preset"] = 1
	TestAssertions.equal(form.apply_preferences(one), "", "one-item preset applies", failures)
	var spec := form.build_batch_spec()
	TestAssertions.truthy(spec != null and spec.ok(), "one-item Workbench spec builds", failures)
	lab.call(&"_on_batch_requested", spec)
	for _index: int in 20:
		lab.call(&"_process", 0.016)
		if not bool(lab.call(&"has_active_job")):
			break
	var summary := lab.get_node("Layout/Workbench/Results/OutcomeSummary") as Label
	TestAssertions.truthy(summary.text.contains("Attempted: 1"), "one-item batch presents terminal accounting", failures)
	var gallery := lab.get_node("Layout/Workbench/Results/SampleScroll/SampleGrid") as LootLabSampleGallery
	TestAssertions.equal(gallery.get_child_count(), 1, "one-item report presents one deterministic sample", failures)
	if gallery.get_child_count() == 1:
		TestAssertions.truthy(not gallery.get_child(0).has_meta("drop_target"), "preview tile is not a storage drag source", failures)
		(gallery.get_child(0) as Button).pressed.emit()
		TestAssertions.truthy((lab.get_node("Layout/Workbench/InspectorScroll/TraceInspector") as LootLabTraceInspector).result() != null, "sample selection regenerates its exact sequence into the inspector", failures)
	var issued_events := [0]
	lab.sandbox_item_issued.connect(func() -> void: issued_events[0] += 1)
	(lab.get_node("Layout/Workbench/InspectorScroll/TraceInspector/Issue") as Button).pressed.emit()
	TestAssertions.equal(issued_events[0], 1, "explicit Issue to Sandbox emits one refresh event", failures)
	TestAssertions.equal(state.registry().size(), 100, "explicit issuance adds one durable item beside 99 fixtures", failures)
	var report_before_export := LootLabReportExportService.to_json(session.selected_report())
	var export_root := "user://loot_lab_task11_test"
	var json_path := "%s.json" % export_root
	var markdown_path := "%s.md" % export_root
	TestAssertions.equal(lab.call(&"_export_selected_report", json_path, &"json"), "", "selected report exports as JSON", failures)
	TestAssertions.equal(_read_text(json_path), report_before_export, "JSON export bytes match the pure export service", failures)
	TestAssertions.equal(lab.call(&"_export_selected_report", markdown_path, &"markdown"), "", "selected report exports as Markdown", failures)
	TestAssertions.equal(_read_text(markdown_path), LootLabReportExportService.to_markdown(session.selected_report()), "Markdown export bytes match the pure export service", failures)
	TestAssertions.equal(LootLabReportExportService.to_json(session.selected_report()), report_before_export, "export cannot mutate the selected report", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(json_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(markdown_path))
	lab.call(&"_show_analysis")
	TestAssertions.truthy((lab.get_node("Layout/Analysis") as Control).visible, "analysis toggle replaces the workbench view", failures)
	lab.call(&"_show_workbench")

	var max_document := form.preferences_document()
	max_document["batch_preset"] = 100000
	TestAssertions.equal(form.apply_preferences(max_document), "", "maximum preset applies", failures)
	lab.call(&"_on_batch_requested", form.build_batch_spec())
	TestAssertions.truthy((lab.get_node("BatchConfirmation") as ConfirmationDialog).visible, "100000-attempt request requires confirmation", failures)
	TestAssertions.truthy(not bool(lab.call(&"has_active_job")), "warning dismissal boundary starts no hidden job", failures)

	var cancellable := form.preferences_document()
	cancellable["batch_preset"] = 1000
	form.apply_preferences(cancellable)
	lab.call(&"_on_batch_requested", form.build_batch_spec())
	TestAssertions.truthy(bool(lab.call(&"has_active_job")), "ordinary batch starts immediately", failures)
	TestAssertions.truthy(not bool(lab.call(&"request_parent_close")), "active job blocks immediate parent close", failures)
	TestAssertions.truthy((lab.get_node("CancelCloseConfirmation") as ConfirmationDialog).visible, "active close request opens cancellation confirmation", failures)
	TestAssertions.truthy(bool(lab.call(&"has_active_job")), "dismissing close confirmation leaves the job running", failures)
	lab.call(&"_process", 0.016)
	lab.call(&"_on_cancel_active")
	var report_selector := lab.get_node("Layout/Analysis/Layout/ReportSelector") as OptionButton
	TestAssertions.equal(report_selector.item_count, 2, "completed and cancelled partial reports remain independently selectable", failures)
	TestAssertions.truthy((lab.get_node("Layout/Analysis/Layout/PartialBanner") as Label).visible, "cancelled selection retains a permanent partial warning", failures)
	lab.call(&"_on_batch_requested", form.build_batch_spec())
	lab.call(&"cancel_and_clear")
	TestAssertions.truthy(not bool(lab.call(&"has_active_job")), "explicit cancel clears the active job", failures)

	lab.free()
	tooltip.free()
	return failures

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var contents := file.get_as_text()
	file.close()
	return contents
