class_name LootLabAnalysisView
extends Control

signal report_kind_selected(kind: StringName)
signal sequence_requested(sequence: int)
signal export_requested(format: StringName)

const COLUMN_TITLES := [
	"Category", "Stage", "Candidate", "Expected", "Observed", "Difference", "Deviation", "Status",
]
const EXAMPLE_LIMIT := 20

var _rendered_lines: Array[String] = []
var _diagnostic_sequences: Dictionary = {}
var _updating_selector := false

func _init() -> void:
	_build_view()

func set_report_availability(kinds: Array[StringName]) -> void:
	var selector := _selector()
	var previous := ""
	if selector.selected >= 0:
		previous = str(selector.get_item_metadata(selector.selected))
	_updating_selector = true
	selector.clear()
	for kind: StringName in kinds:
		selector.add_item(str(kind).capitalize())
		selector.set_item_metadata(selector.item_count - 1, str(kind))
		if str(kind) == previous:
			selector.select(selector.item_count - 1)
	if selector.item_count > 0 and selector.selected < 0:
		selector.select(0)
	_updating_selector = false

func select_report_kind(kind: StringName) -> void:
	var selector := _selector()
	for index: int in selector.item_count:
		if StringName(selector.get_item_metadata(index)) == kind:
			_updating_selector = true
			selector.select(index)
			_updating_selector = false
			return

func present(report: Dictionary) -> void:
	_rendered_lines.clear()
	_diagnostic_sequences.clear()
	var tree := _table()
	tree.clear()
	var root := tree.create_item()
	if report.is_empty():
		_partial_banner().visible = false
		_add_row(root, "report", "", "", 0.0, 0, 0.0, "n/a", "NO_REPORT")
		return
	var evidence := report.get("evidence", {}) as Dictionary
	var runtime := report.get("runtime", {}) as Dictionary
	var summary := evidence.get("summary", {}) as Dictionary
	var attempted := int(summary.get("attempted", 0))
	var target := int(summary.get("target", 0))
	var is_partial := str(runtime.get("status", "")) != "completed" or attempted < target
	_partial_banner().visible = is_partial
	_partial_banner().text = "CANCELLED / PARTIAL REPORT — %d of %d attempts retained" % [attempted, target]
	_present_aggregates(root, evidence.get("aggregates", {}) as Dictionary)
	_present_diagnostics(root, evidence.get("diagnostics", {}) as Dictionary)
	_present_failures(root, evidence.get("failures", {}) as Dictionary)

func select_diagnostic(category: StringName, sequence: int) -> bool:
	var key := "%s:%d" % [category, sequence]
	if not _diagnostic_sequences.has(key):
		return false
	sequence_requested.emit(sequence)
	return true

func rendered_text() -> String:
	return "\n".join(_rendered_lines)

func focus_controls() -> Array[Control]:
	return [_selector(), _table(), _json_button(), _markdown_button()]

func _build_view() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	var banner := Label.new()
	banner.name = "PartialBanner"
	banner.visible = false
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_color_override("font_color", Color("ffcf66"))
	layout.add_child(banner)
	var toolbar := HBoxContainer.new()
	toolbar.name = "Toolbar"
	layout.add_child(toolbar)
	var selector := OptionButton.new()
	selector.name = "ReportSelector"
	selector.custom_minimum_size = Vector2(160, 40)
	selector.focus_mode = Control.FOCUS_ALL
	selector.item_selected.connect(_on_report_selected)
	layout.add_child(selector)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	var json_button := Button.new()
	json_button.name = "ExportJson"
	json_button.text = "Export JSON"
	json_button.focus_mode = Control.FOCUS_ALL
	json_button.pressed.connect(func() -> void: export_requested.emit(&"json"))
	toolbar.add_child(json_button)
	var markdown_button := Button.new()
	markdown_button.name = "ExportMarkdown"
	markdown_button.text = "Export Markdown"
	markdown_button.focus_mode = Control.FOCUS_ALL
	markdown_button.pressed.connect(func() -> void: export_requested.emit(&"markdown"))
	toolbar.add_child(markdown_button)
	var table := Tree.new()
	table.name = "Table"
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.focus_mode = Control.FOCUS_ALL
	table.hide_root = true
	table.column_titles_visible = true
	table.columns = COLUMN_TITLES.size()
	for column: int in COLUMN_TITLES.size():
		table.set_column_title(column, COLUMN_TITLES[column])
		table.set_column_expand(column, true)
	table.item_activated.connect(_on_item_activated)
	layout.add_child(table)

func _present_aggregates(root: TreeItem, aggregates: Dictionary) -> void:
	var expected := aggregates.get("expected", {}) as Dictionary
	var observed := aggregates.get("observed", {}) as Dictionary
	var stages := _sorted_keys(expected)
	for observed_stage: String in _sorted_keys(observed):
		if not stages.has(observed_stage):
			stages.append(observed_stage)
	stages.sort()
	for stage: String in stages:
		var expected_row := expected.get(stage, {}) as Dictionary
		var observed_row := observed.get(stage, {}) as Dictionary
		var candidates := _sorted_keys(expected_row)
		for observed_candidate: String in _sorted_keys(observed_row):
			if not candidates.has(observed_candidate):
				candidates.append(observed_candidate)
		candidates.sort()
		for candidate: String in candidates:
			var expected_value := float(expected_row.get(candidate, 0.0))
			var observed_value := int(observed_row.get(candidate, 0))
			var difference := float(observed_value) - expected_value
			var deviation := "n/a" if is_zero_approx(expected_value) else "%.2f%%" % (difference / expected_value * 100.0)
			var status := "eligible_unobserved" if expected_value > 0.0 and observed_value == 0 else "observed"
			_add_row(root, _stage_category(stage), stage, candidate, expected_value, observed_value, difference, deviation, status)

func _present_diagnostics(root: TreeItem, diagnostics: Dictionary) -> void:
	var reachability := diagnostics.get("reachability", {}) as Dictionary
	for reachability_kind: String in _sorted_keys(reachability):
		var values: Variant = reachability[reachability_kind]
		if values is Array:
			for candidate: Variant in values:
				_add_text_row(root, "reachability", reachability_kind, str(candidate), reachability_kind)
	for candidate: Variant in diagnostics.get("unencountered_reachable_affixes", []) as Array:
		_add_text_row(root, "reachability", "not_encountered", str(candidate), "not_encountered")
	for row_value: Variant in diagnostics.get("encountered_unobserved", []) as Array:
		if row_value is Dictionary:
			var row := row_value as Dictionary
			_add_row(root, "diagnostic", str(row.get("stage", "")), str(row.get("candidate", "")), float(row.get("expected_sum", 0.0)), 0, -float(row.get("expected_sum", 0.0)), "-100.00%", "eligible_unobserved")
	var categories := diagnostics.get("categories", {}) as Dictionary
	for category: String in _sorted_keys(categories):
		var category_row := categories.get(category, {}) as Dictionary
		_add_text_row(root, "diagnostic", category, "count=%d" % int(category_row.get("count", 0)), category)
		var examples := category_row.get("example_sequences", []) as Array
		for index: int in mini(examples.size(), EXAMPLE_LIMIT):
			var sequence := int(examples[index])
			var item := _add_text_row(root, "example", category, str(sequence), "select_sequence")
			item.set_metadata(0, {"category": category, "sequence": sequence})
			_diagnostic_sequences["%s:%d" % [category, sequence]] = true

func _present_failures(root: TreeItem, failures: Dictionary) -> void:
	var counts := failures.get("by_stage_code", {}) as Dictionary
	for stage_code: String in _sorted_keys(counts):
		_add_text_row(root, "failure", stage_code, "count=%d" % int(counts[stage_code]), stage_code)

func _add_row(
	root: TreeItem,
	category: String,
	stage: String,
	candidate: String,
	expected: float,
	observed: int,
	difference: float,
	deviation: String,
	status: String
) -> TreeItem:
	var values := [category, stage, candidate, "%.4f" % expected, str(observed), "%.4f" % difference, deviation, status]
	return _append_row(root, values)

func _add_text_row(root: TreeItem, category: String, stage: String, candidate: String, status: String) -> TreeItem:
	return _append_row(root, [category, stage, candidate, "", "", "", "", status])

func _append_row(root: TreeItem, values: Array) -> TreeItem:
	var item := _table().create_item(root)
	var rendered: Array[String] = []
	for column: int in COLUMN_TITLES.size():
		var value := str(values[column])
		item.set_text(column, value)
		rendered.append(value)
	_rendered_lines.append("\t".join(rendered))
	return item

func _stage_category(stage: String) -> String:
	if stage.begins_with("affix:"):
		return "affix"
	if stage in ["base", "rarity", "pattern", "family", "tier", "weight_band"]:
		return stage
	return "selection"

func _sorted_keys(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in values:
		result.append(str(key))
	result.sort()
	return result

func _on_report_selected(index: int) -> void:
	if _updating_selector or index < 0 or index >= _selector().item_count:
		return
	report_kind_selected.emit(StringName(_selector().get_item_metadata(index)))

func _on_item_activated() -> void:
	var selected := _table().get_selected()
	if selected == null:
		return
	var metadata: Variant = selected.get_metadata(0)
	if metadata is Dictionary:
		select_diagnostic(StringName((metadata as Dictionary).get("category", "")), int((metadata as Dictionary).get("sequence", -1)))

func _partial_banner() -> Label:
	return get_node("Layout/PartialBanner") as Label

func _selector() -> OptionButton:
	return get_node("Layout/ReportSelector") as OptionButton

func _table() -> Tree:
	return get_node("Layout/Table") as Tree

func _json_button() -> Button:
	return get_node("Layout/Toolbar/ExportJson") as Button

func _markdown_button() -> Button:
	return get_node("Layout/Toolbar/ExportMarkdown") as Button
