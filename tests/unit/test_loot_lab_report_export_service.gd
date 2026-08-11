extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_json_projection(failures)
	_test_markdown_projection(failures)
	_test_invalid_reports(failures)
	return failures

func _test_json_projection(failures: Array[String]) -> void:
	var report := _report(&"completed")
	var json := LootLabReportExportService.to_json(report)
	TestAssertions.truthy(json.ends_with("\n"), "JSON export has one terminal newline", failures)
	TestAssertions.truthy(json.find("\"evidence\"") < json.find("\"runtime\""), "JSON export uses canonical top-level key order", failures)
	var canonical_report: Variant = ItemGenerationTrace.canonical_json_copy(report)
	var parsed_canonical_report: Variant = JSON.parse_string(JSON.stringify(canonical_report))
	TestAssertions.equal(JSON.parse_string(json), parsed_canonical_report, "JSON export round-trips canonical report", failures)

	var changed_runtime := report.duplicate(true)
	(changed_runtime["runtime"] as Dictionary)["elapsed_seconds"] = 999.0
	TestAssertions.equal(LootLabReportExportService.deterministic_json(report), LootLabReportExportService.deterministic_json(changed_runtime), "deterministic export excludes runtime observations", failures)
	var deterministic := JSON.parse_string(LootLabReportExportService.deterministic_json(report)) as Dictionary
	TestAssertions.truthy(not deterministic.has("runtime"), "deterministic export contains evidence only", failures)
	var parsed_evidence: Variant = JSON.parse_string(JSON.stringify(ItemGenerationTrace.canonical_json_copy(report["evidence"])))
	TestAssertions.equal(deterministic, parsed_evidence, "deterministic export preserves canonical evidence", failures)

func _test_markdown_projection(failures: Array[String]) -> void:
	var completed := LootLabReportExportService.to_markdown(_report(&"completed"))
	TestAssertions.truthy(completed.begins_with("# Party Forge Loot Lab Report"), "completed Markdown has normal heading", failures)
	TestAssertions.truthy(completed.contains("Attempts: 40 / 40"), "completed Markdown includes attempted and target accounting", failures)

	var cancelled_report := _report(&"cancelled")
	(cancelled_report["evidence"]["summary"] as Dictionary)["attempted"] = 12
	var cancelled := LootLabReportExportService.to_markdown(cancelled_report)
	TestAssertions.truthy(cancelled.begins_with("CANCELLED / PARTIAL"), "cancelled Markdown begins with prominent partial label", failures)
	TestAssertions.truthy(cancelled.contains("Attempts: 12 / 40"), "partial Markdown includes attempted and target accounting", failures)
	TestAssertions.truthy(cancelled.contains("Failures: 1"), "Markdown includes failure accounting", failures)

func _test_invalid_reports(failures: Array[String]) -> void:
	TestAssertions.equal(LootLabReportExportService.to_json({"evidence": {"value": NAN}, "runtime": {}}), "", "nonfinite JSON report is rejected", failures)
	TestAssertions.equal(LootLabReportExportService.deterministic_json({}), "", "missing evidence is rejected", failures)
	TestAssertions.equal(LootLabReportExportService.to_markdown({}), "", "missing report sections are rejected", failures)

func _report(status: StringName) -> Dictionary:
	return {
		"evidence": {
			"aggregates": {"expected": {}, "observed": {}, "opportunities": {}, "rejections": {}},
			"catalog": {"affixes": 3, "bases": 1, "rarities": 1},
			"diagnostics": {"categories": {}, "encountered_unobserved": [], "reachability": {}},
			"failures": {"by_stage_code": {"rarity/no_eligible_rarity": 1}},
			"generator_version": 2,
			"request": {"generation_sequence": 700},
			"samples": [],
			"scenario_identity": "fixture",
			"schema_version": 1,
			"sequence_range": {"attempted_end": 739, "start": 700, "target_end": 739},
			"summary": {"attempted": 40, "failed": 1, "succeeded": 39, "target": 40},
		},
		"runtime": {"elapsed_seconds": 1.25, "items_per_second": 32.0, "status": String(status)},
	}
