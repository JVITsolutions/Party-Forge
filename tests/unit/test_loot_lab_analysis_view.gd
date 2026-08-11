extends RefCounted

const ANALYSIS_PATH := "res://scripts/ui/loot_lab/loot_lab_analysis_view.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(ANALYSIS_PATH), "Loot Lab analysis view script exists", failures)
	if not ResourceLoader.exists(ANALYSIS_PATH):
		return failures
	var analysis: Variant = (load(ANALYSIS_PATH) as Script).new()
	analysis.call(&"set_report_availability", [&"complete", &"partial"] as Array[StringName])
	var report := _partial_report()
	analysis.call(&"present", report)
	var banner := analysis.get_node("Layout/PartialBanner") as Label
	var selector := analysis.get_node("Layout/ReportSelector") as OptionButton
	var table := analysis.get_node("Layout/Table") as Tree
	TestAssertions.truthy(banner.visible and banner.text.contains("PARTIAL"), "partial report shows a permanent warning", failures)
	TestAssertions.equal(selector.item_count, 2, "complete and partial reports remain selectable", failures)
	TestAssertions.equal(table.columns, 8, "analysis table exposes identity expected observed difference deviation and status columns", failures)
	for column: int in 8:
		TestAssertions.truthy(not table.get_column_title(column).is_empty(), "analysis column %d has a stable title" % column, failures)
	var rendered := String(analysis.call(&"rendered_text"))
	for token: String in ["base", "rarity", "pattern", "affix", "family", "tier", "weight_band", "structurally_unreachable", "not_encountered", "eligible_unobserved", "rarity/no_eligible_rarity", "conflict", "tier_gap", "impossible_pattern", "inactive_rarity"]:
		TestAssertions.truthy(rendered.contains(token), "analysis renders %s evidence" % token, failures)
	var sequences: Array[int] = []
	analysis.connect(&"sequence_requested", func(sequence: int) -> void: sequences.append(sequence))
	TestAssertions.truthy(bool(analysis.call(&"select_diagnostic", &"conflict", 701)), "diagnostic example can be selected exactly", failures)
	TestAssertions.equal(sequences, [701], "diagnostic selection emits exact sequence", failures)
	TestAssertions.truthy(not bool(analysis.call(&"select_diagnostic", &"conflict", 999)), "unknown diagnostic sequence is rejected", failures)
	analysis.free()
	return failures

func _partial_report() -> Dictionary:
	return {
		"evidence": {
			"aggregates": {
				"expected": {"base": {"base_a": 2.0}, "rarity": {"rare": 1.0}, "pattern": {"pattern_a": 1.0}, "affix:prefix:0": {"affix_a": 1.0}, "family": {"family_a": 1.0}, "tier": {"tier_8": 1.0}, "weight_band": {"low": 1.0}},
				"observed": {"base": {"base_a": 1}, "rarity": {"rare": 1}},
				"opportunities": {"base": 2},
				"rejections": {},
			},
			"diagnostics": {
				"categories": {
					"conflict": {"count": 1, "example_sequences": [701]},
					"tier_gap": {"count": 1, "example_sequences": [702]},
					"impossible_pattern": {"count": 1, "example_sequences": [703]},
					"inactive_rarity": {"count": 1, "example_sequences": [704]},
				},
				"encountered_unobserved": [{"stage": "affix:prefix:0", "candidate": "eligible_unobserved", "expected_sum": 0.5}],
				"reachability": {"structurally_unreachable_affixes": ["structurally_unreachable"], "not_applicable_affixes": [], "reachable_affixes": ["not_encountered"]},
				"unencountered_reachable_affixes": ["not_encountered"],
			},
			"failures": {"by_stage_code": {"rarity/no_eligible_rarity": 1}},
			"request": {"generation_sequence": 700},
			"samples": [],
			"summary": {"attempted": 5, "failed": 1, "succeeded": 4, "target": 10},
		},
		"runtime": {"status": "cancelled", "elapsed_seconds": 1.0, "items_per_second": 5.0},
	}
