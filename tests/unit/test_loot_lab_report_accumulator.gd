extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var fixtures := _fixtures()
	var equipment := fixtures["equipment"] as EquipmentCatalog
	var foundation := fixtures["foundation"] as ItemFoundationCatalog
	_test_ordered_accounting(equipment, foundation, failures)
	_test_bounded_retention(equipment, foundation, failures)
	return failures

func _test_ordered_accounting(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var spec := LootLabBatchSpec.create(_request(), 4, foundation)
	var accumulator := LootLabReportAccumulator.create(spec, equipment, foundation)
	var success := _success_result()
	var failed := _failure_result()
	TestAssertions.equal(accumulator.record(0, success), "", "first ordered result records", failures)
	var out_of_order := accumulator.record(2, success)
	TestAssertions.equal(out_of_order, "PARTY_FORGE_LOOT_LAB_REPORT_ERROR field=attempt_index reason=expected 1 got 2", "out-of-order result is rejected exactly", failures)
	TestAssertions.equal(accumulator.record(1, failed), "", "rejected out-of-order input does not advance accounting", failures)
	TestAssertions.equal(accumulator.record(2, success), "", "third ordered result records", failures)
	TestAssertions.equal(accumulator.record(3, success), "", "fourth ordered result records", failures)

	var report := accumulator.finalize(&"completed", {"elapsed_seconds": 1.25, "items_per_second": 3.2})
	var evidence := report.get("evidence", {}) as Dictionary
	var summary := evidence.get("summary", {}) as Dictionary
	TestAssertions.equal(summary, {"attempted": 4, "failed": 1, "succeeded": 3, "target": 4}, "summary closes exact accounting", failures)
	TestAssertions.equal((report.get("runtime", {}) as Dictionary).get("status", ""), "completed", "runtime envelope records terminal status", failures)
	TestAssertions.near(float((report.get("runtime", {}) as Dictionary).get("elapsed_seconds", 0.0)), 1.25, 0.000001, "runtime envelope records elapsed time", failures)
	TestAssertions.equal((evidence.get("samples", []) as Array).size(), 4, "small batch retains every sample", failures)

	var aggregates := evidence.get("aggregates", {}) as Dictionary
	var expected := (aggregates.get("expected", {}) as Dictionary).get("affix:prefix:0", {}) as Dictionary
	TestAssertions.near(float(expected.get("a", 0.0)), 1.0, 0.000001, "expected a sum is exact across four opportunities", failures)
	TestAssertions.near(float(expected.get("b", 0.0)), 3.0, 0.000001, "expected b sum is exact across four opportunities", failures)
	var observed := (aggregates.get("observed", {}) as Dictionary).get("affix:prefix:0", {}) as Dictionary
	TestAssertions.equal(observed.get("b", 0), 4, "selected candidate count is exact", failures)
	TestAssertions.equal((aggregates.get("opportunities", {}) as Dictionary).get("affix:prefix:0", 0), 4, "opportunity denominator is exact", failures)
	TestAssertions.equal(((evidence.get("failures", {}) as Dictionary).get("by_stage_code", {}) as Dictionary).get("rarity/no_eligible_rarity", 0), 1, "failure stage/code count is exact", failures)
	var categories := (evidence.get("diagnostics", {}) as Dictionary).get("categories", {}) as Dictionary
	var failure_diagnostic := categories.get("generation_failure:rarity/no_eligible_rarity", {}) as Dictionary
	TestAssertions.equal(failure_diagnostic.get("count", 0), 1, "generation failure diagnostic count is exact", failures)
	TestAssertions.equal(failure_diagnostic.get("example_sequences", []), [701], "generation failure diagnostic stores the exact sequence", failures)
	TestAssertions.equal(accumulator.record(4, success), "PARTY_FORGE_LOOT_LAB_REPORT_ERROR field=state reason=report already finalized", "finalized accumulator rejects later records", failures)

	var exposed := report.duplicate(true)
	(exposed["evidence"]["summary"] as Dictionary)["attempted"] = 99
	TestAssertions.equal((accumulator.finalize(&"completed", {})["evidence"]["summary"] as Dictionary)["attempted"], 4, "finalized report is defensive", failures)

func _test_bounded_retention(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var spec := LootLabBatchSpec.create(_request(), 100000, foundation)
	var accumulator := LootLabReportAccumulator.create(spec, equipment, foundation)
	for attempt_index: int in 100000:
		var error := accumulator.record(attempt_index, null)
		if not error.is_empty():
			failures.append("100000-attempt accounting stopped at %d: %s" % [attempt_index, error])
			break
	var report := accumulator.finalize(&"cancelled", {"elapsed_seconds": 1.0, "items_per_second": 100000.0})
	var evidence := report.get("evidence", {}) as Dictionary
	var summary := evidence.get("summary", {}) as Dictionary
	TestAssertions.equal(summary.get("attempted", 0), 100000, "large batch accounts for every attempt", failures)
	TestAssertions.equal(summary.get("failed", 0), 100000, "invalid lightweight results count as failures", failures)
	var samples := evidence.get("samples", []) as Array
	TestAssertions.equal(samples.size(), 100, "large batch retains at most 100 samples", failures)
	var categories := (evidence.get("diagnostics", {}) as Dictionary).get("categories", {}) as Dictionary
	var invalid := categories.get("invalid_result", {}) as Dictionary
	TestAssertions.equal(invalid.get("count", 0), 100000, "diagnostic count retains the full population", failures)
	TestAssertions.equal((invalid.get("example_sequences", []) as Array).size(), 20, "diagnostic examples are capped at 20", failures)
	TestAssertions.equal((invalid.get("example_sequences", []) as Array)[0], 700, "diagnostic examples begin with first sequence", failures)
	TestAssertions.equal((invalid.get("example_sequences", []) as Array)[19], 719, "diagnostic examples preserve first twenty ordered sequences", failures)
	var expected_sample_indexes := spec.sample_attempt_indexes()
	for index: int in samples.size():
		TestAssertions.equal((samples[index] as Dictionary).get("attempt_index", -1), expected_sample_indexes[index], "sample %d uses deterministic bounded index" % index, failures)

func _success_result() -> ItemGenerationResult:
	var item := ItemInstance.new()
	item.instance_id = "item-loot-lab-test"
	item.base_definition_id = &"base"
	item.item_level = 20
	item.rarity_id = &"common"
	item.origin = {"issuer_namespace": "loot-lab-test", "seed": 77, "sequence": 0, "source": "test"}
	return ItemGenerationResult.success(item, _trace())

func _failure_result() -> ItemGenerationResult:
	var failure := ItemGenerationFailure.new()
	failure.generator_version = ItemGenerationService.GENERATOR_VERSION
	failure.stage = &"rarity"
	failure.code = &"no_eligible_rarity"
	failure.source_id = &"ordinary_enemy"
	failure.seed = 77
	failure.generation_sequence = 701
	failure.details = {"reason": "fixture"}
	return ItemGenerationResult.failed(failure, _trace())

func _trace() -> ItemGenerationTrace:
	var trace := ItemGenerationTrace.new()
	trace.record(&"affix:prefix:0", [&"a", &"b"], {}, {&"a": 1.0, &"b": 3.0}, &"b")
	return trace

func _request() -> ItemGenerationRequest:
	return ItemGenerationRequest.create(77, 700, 20, &"ordinary_enemy", &"ordinary_drop", [&"common"] as Array[StringName])

func _fixtures() -> Dictionary:
	var base := EquipmentBaseDefinition.new()
	base.id = &"base"
	base.generation_tags = [&"weapon"]
	base.generation_weight = 1.0
	var equipment := EquipmentCatalog.new()
	equipment.definitions = [base]
	var pattern := ItemAffixPatternDefinition.new()
	pattern.id = &"empty"
	pattern.weight = 1.0
	var rarity := ItemRarityDefinition.new()
	rarity.id = &"common"
	rarity.base_weight = 1.0
	rarity.patterns = [pattern]
	var foundation := ItemFoundationCatalog.new()
	foundation.known_source_ids = [&"ordinary_enemy"]
	foundation.known_item_tags = [&"accessory", &"base", &"weapon"]
	foundation.rarities = [rarity]
	return {"equipment": equipment, "foundation": foundation}
