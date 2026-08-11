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
	return "\n".join(lines)

static func _valid_report(report: Dictionary) -> bool:
	if not report.has("evidence") or not report["evidence"] is Dictionary:
		return false
	if not report.has("runtime") or not report["runtime"] is Dictionary:
		return false
	return ItemGenerationTrace.json_value_error(report).is_empty()
