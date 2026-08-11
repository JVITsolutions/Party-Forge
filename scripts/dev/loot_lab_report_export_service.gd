class_name LootLabReportExportService
extends RefCounted

static func to_json(report: Dictionary) -> String:
	if not _valid_report(report):
		return ""
	return JSON.stringify(ItemGenerationTrace.canonical_json_copy(report), "  ", false) + "\n"

static func deterministic_json(report: Dictionary) -> String:
	if not _valid_report(report):
		return ""
	return JSON.stringify(ItemGenerationTrace.canonical_json_copy(report["evidence"]), "  ", false) + "\n"

static func to_markdown(report: Dictionary) -> String:
	if not _valid_report(report):
		return ""
	var evidence := report["evidence"] as Dictionary
	var runtime := report["runtime"] as Dictionary
	var summary := evidence.get("summary", {}) as Dictionary
	var attempted := int(summary.get("attempted", 0))
	var target := int(summary.get("target", 0))
	var status := String(runtime.get("status", ""))
	var partial := status != "completed" or attempted < target
	var lines: Array[String] = []
	if partial:
		lines.append("CANCELLED / PARTIAL")
		lines.append("")
	lines.append("# Party Forge Loot Lab Report")
	lines.append("")
	lines.append("- Status: %s" % status)
	lines.append("- Scenario: %s" % String(evidence.get("scenario_identity", "")))
	lines.append("- Attempts: %d / %d" % [attempted, target])
	lines.append("- Successes: %d" % int(summary.get("succeeded", 0)))
	lines.append("- Failures: %d" % int(summary.get("failed", 0)))
	lines.append("- Elapsed seconds: %s" % str(runtime.get("elapsed_seconds", 0.0)))
	lines.append("- Items per second: %s" % str(runtime.get("items_per_second", 0.0)))
	lines.append("")
	lines.append("## Expected and observed")
	lines.append("")
	var aggregates := evidence.get("aggregates", {}) as Dictionary
	var expected := aggregates.get("expected", {}) as Dictionary
	var observed := aggregates.get("observed", {}) as Dictionary
	var stages := _sorted_union(expected, observed)
	if stages.is_empty():
		lines.append("- None")
	else:
		for stage: String in stages:
			var expected_row := expected.get(stage, {}) as Dictionary
			var observed_row := observed.get(stage, {}) as Dictionary
			for candidate: String in _sorted_union(expected_row, observed_row):
				lines.append("- %s / %s: expected=%s observed=%d" % [stage, candidate, str(expected_row.get(candidate, 0.0)), int(observed_row.get(candidate, 0))])
	lines.append("")
	lines.append("## Rejections")
	lines.append("")
	_append_nested_rows(lines, aggregates.get("rejections", {}) as Dictionary)
	lines.append("")
	lines.append("## Reachability")
	lines.append("")
	var diagnostics := evidence.get("diagnostics", {}) as Dictionary
	_append_nested_rows(lines, diagnostics.get("reachability", {}) as Dictionary)
	lines.append("")
	lines.append("## Diagnostics")
	lines.append("")
	_append_nested_rows(lines, diagnostics.get("categories", {}) as Dictionary)
	for row: Variant in diagnostics.get("encountered_unobserved", []) as Array:
		lines.append("- encountered_unobserved: %s" % JSON.stringify(ItemGenerationTrace.canonical_json_copy(row)))
	for candidate: Variant in diagnostics.get("unencountered_reachable_affixes", []) as Array:
		lines.append("- unencountered_reachable_affix: %s" % str(candidate))
	lines.append("")
	lines.append("## Failure counts")
	lines.append("")
	var failure_counts := (evidence.get("failures", {}) as Dictionary).get("by_stage_code", {}) as Dictionary
	if failure_counts.is_empty():
		lines.append("- None")
	else:
		var keys: Array[String] = []
		for key: Variant in failure_counts:
			keys.append(String(key))
		keys.sort()
		for key: String in keys:
			lines.append("- %s: %d" % [key, int(failure_counts[key])])
	lines.append("")
	lines.append("## Retained evidence")
	lines.append("")
	lines.append("- Samples: %d" % (evidence.get("samples", []) as Array).size())
	lines.append("- Diagnostic categories: %d" % (((evidence.get("diagnostics", {}) as Dictionary).get("categories", {}) as Dictionary).size()))
	lines.append("")
	lines.append("## Samples")
	lines.append("")
	var samples := evidence.get("samples", []) as Array
	if samples.is_empty():
		lines.append("- None")
	else:
		for sample: Variant in samples:
			lines.append("- %s" % JSON.stringify(ItemGenerationTrace.canonical_json_copy(sample)))
	lines.append("")
	return "\n".join(lines)

static func _append_nested_rows(lines: Array[String], values: Dictionary) -> void:
	if values.is_empty():
		lines.append("- None")
		return
	for key: String in _sorted_keys(values):
		lines.append("- %s: %s" % [key, JSON.stringify(ItemGenerationTrace.canonical_json_copy(values[key]))])

static func _sorted_union(left: Dictionary, right: Dictionary) -> Array[String]:
	var result := _sorted_keys(left)
	for key: String in _sorted_keys(right):
		if key not in result:
			result.append(key)
	result.sort()
	return result

static func _sorted_keys(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in values:
		result.append(String(key))
	result.sort()
	return result

static func _valid_report(report: Dictionary) -> bool:
	if not report.has("evidence") or not report["evidence"] is Dictionary:
		return false
	if not report.has("runtime") or not report["runtime"] is Dictionary:
		return false
	return ItemGenerationTrace.json_value_error(report).is_empty()
