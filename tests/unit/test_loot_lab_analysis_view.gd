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
	var production_report := _production_report()
	analysis.call(&"present", production_report)
	var production_rendered := String(analysis.call(&"rendered_text"))
	for dimension: String in ["base", "rarity", "pattern", "affix", "affix_kind", "family", "tier", "weight_band"]:
		TestAssertions.truthy(production_rendered.contains(dimension), "Analysis renders %s from a finalized production report" % dimension, failures)
	analysis.call(&"apply_viewport_size", Vector2i(960, 540))
	TestAssertions.truthy(int(analysis.call(&"column_minimum_width", 0)) > 0 and int(analysis.call(&"column_minimum_width", 7)) > 0, "compact Analysis preserves bounded identity and status columns", failures)
	analysis.free()
	return failures

func _production_report() -> Dictionary:
	var request := ItemGenerationRequest.create(445566, 900, 800, &"ordinary_enemy", &"ordinary_drop", [&"rare"] as Array[StringName])
	request.difficulty_id = &"normal"
	request.unlock_tags = [&"rarity_rare_unlocked"]
	var spec := LootLabBatchSpec.create(request, 20, GameCatalog.ITEM_FOUNDATION_CATALOG)
	var accumulator := LootLabReportAccumulator.create(spec, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	for attempt: int in 20:
		var attempt_request := spec.request_for_attempt(attempt)
		accumulator.record(attempt, ItemGenerationService.generate(attempt_request, "loot-lab-analysis-test", attempt_request.generation_sequence, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG))
	return accumulator.finalize(&"completed", {"elapsed_seconds": 1.0, "items_per_second": 20.0})

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
