extends RefCounted

var _generator_calls: Array[int] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	var fixtures := _fixtures()
	var equipment := fixtures["equipment"] as EquipmentCatalog
	var foundation := fixtures["foundation"] as ItemFoundationCatalog
	_test_chunk_equivalence(equipment, foundation, failures)
	_test_cancellation(equipment, foundation, failures)
	return failures

func _test_chunk_equivalence(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var spec := LootLabBatchSpec.create(_request(700), 40, foundation)
	var chunked := LootLabBatchJob.create(spec, equipment, foundation, Callable(self, &"_generator"))
	TestAssertions.truthy(chunked.is_active(), "valid job begins active", failures)
	TestAssertions.equal(chunked.advance(0, 0), 0, "zero attempt budget advances nothing", failures)
	TestAssertions.equal(chunked.advance(1, 0), 1, "first deterministic chunk advances one attempt", failures)
	var live_progress := chunked.progress()
	TestAssertions.truthy(live_progress.has("elapsed_seconds") and float(live_progress.get("elapsed_seconds", -1.0)) >= 0.0, "active progress exposes elapsed time", failures)
	TestAssertions.truthy(live_progress.has("items_per_second") and float(live_progress.get("items_per_second", -1.0)) >= 0.0, "active progress exposes live throughput", failures)
	TestAssertions.equal(chunked.advance(7, 0), 7, "second deterministic chunk advances seven attempts", failures)
	TestAssertions.equal(chunked.advance(32, 0), 32, "final deterministic chunk advances remaining attempts", failures)
	TestAssertions.truthy(not chunked.is_active(), "target completion makes job terminal", failures)
	var chunked_report := chunked.terminal_report()
	TestAssertions.equal((chunked_report.get("runtime", {}) as Dictionary).get("status", ""), "completed", "completed job reports completed", failures)
	TestAssertions.equal((chunked.progress().get("attempted", 0)), 40, "progress reports exact attempted count", failures)

	var single := LootLabBatchJob.create(spec, equipment, foundation, Callable(self, &"_generator"))
	TestAssertions.equal(single.advance(40, 0), 40, "single chunk advances exact target", failures)
	TestAssertions.equal(
		LootLabReportExportService.deterministic_json(chunked_report),
		LootLabReportExportService.deterministic_json(single.terminal_report()),
		"chunk partitions cannot change deterministic evidence",
		failures
	)

func _test_cancellation(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	_generator_calls.clear()
	var spec := LootLabBatchSpec.create(_request(900), 40, foundation)
	var job := LootLabBatchJob.create(spec, equipment, foundation, Callable(self, &"_generator"))
	TestAssertions.equal(job.advance(7, 0), 7, "first deterministic chunk advances seven attempts", failures)
	job.request_cancel()
	TestAssertions.equal(job.advance(7, 0), 0, "cancelled job advances no later attempt", failures)
	TestAssertions.equal(_generator_calls.size(), 7, "cancellation prevents an eighth generator call", failures)
	var report := job.terminal_report()
	TestAssertions.equal((report.get("runtime", {}) as Dictionary).get("status", ""), "cancelled", "cancel produces partial terminal report", failures)
	TestAssertions.equal(((report.get("evidence", {}) as Dictionary).get("summary", {}) as Dictionary).get("attempted", 0), 7, "cancelled report closes exact partial accounting", failures)
	TestAssertions.equal(job.advance(40, 0), 0, "terminal cancellation remains inert", failures)

func _generator(
	request: ItemGenerationRequest,
	issuer_namespace: String,
	item_sequence: int,
	_equipment: EquipmentCatalog,
	_foundation: ItemFoundationCatalog
) -> ItemGenerationResult:
	_generator_calls.append(request.generation_sequence)
	var item := ItemInstance.new()
	item.instance_id = "job-%s-%d" % [issuer_namespace.sha256_text(), item_sequence]
	item.base_definition_id = &"base"
	item.item_level = request.item_level
	item.rarity_id = &"common"
	item.origin = {"issuer_namespace": issuer_namespace, "seed": request.seed, "sequence": item_sequence, "source": "job_test"}
	var trace := ItemGenerationTrace.new()
	trace.record(&"base", [&"base"], {}, {&"base": 1.0}, &"base")
	return ItemGenerationResult.success(item, trace)

func _request(sequence: int) -> ItemGenerationRequest:
	return ItemGenerationRequest.create(123, sequence, 20, &"ordinary_enemy", &"ordinary_drop", [&"common"] as Array[StringName])

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
