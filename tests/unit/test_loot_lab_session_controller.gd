extends RefCounted

var _generator_call_count := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	var fixtures := _fixtures()
	var equipment := fixtures["equipment"] as EquipmentCatalog
	var foundation := fixtures["foundation"] as ItemFoundationCatalog
	_test_report_lifecycle(equipment, foundation, failures)
	return failures

func _test_report_lifecycle(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var session := LootLabSessionController.new()
	var first_spec := LootLabBatchSpec.create(_request(700), 3, foundation)
	TestAssertions.equal(session.start(first_spec, equipment, foundation, Callable(self, &"_generator")), "", "valid session job starts", failures)
	TestAssertions.truthy(session.has_active_job(), "started session exposes active job", failures)
	TestAssertions.equal(session.advance(3, 0), 3, "session advances first job", failures)
	TestAssertions.truthy(not session.has_active_job(), "completed session clears active job", failures)
	var completed := session.selected_report()
	TestAssertions.equal(session.available_report_kinds(), [&"complete"] as Array[StringName], "completion exposes only the complete report kind", failures)
	TestAssertions.equal(((completed.get("evidence", {}) as Dictionary).get("summary", {}) as Dictionary).get("attempted", 0), 3, "completion selects completed report", failures)
	var complete_bytes := LootLabReportExportService.deterministic_json(completed)

	var before_regeneration_calls := _generator_call_count
	var regenerated := session.regenerate_sequence(701)
	TestAssertions.truthy(regenerated != null and regenerated.ok(), "selected completed sequence regenerates", failures)
	TestAssertions.equal(_generator_call_count, before_regeneration_calls + 1, "regeneration invokes generator exactly once", failures)
	if regenerated != null and regenerated.ok():
		TestAssertions.equal(regenerated.item.origin.get("sequence", -1), 701, "regeneration uses exact generation sequence as item sequence", failures)
	TestAssertions.equal(LootLabReportExportService.deterministic_json(session.selected_report()), complete_bytes, "regeneration cannot mutate completed report", failures)
	TestAssertions.equal(session.regenerate_sequence(703), null, "sequence outside attempted completed range is rejected", failures)

	var partial_spec := LootLabBatchSpec.create(_request(800), 5, foundation)
	TestAssertions.equal(session.start(partial_spec, equipment, foundation, Callable(self, &"_generator")), "", "successor job starts", failures)
	TestAssertions.equal(LootLabReportExportService.deterministic_json(session.selected_report()), complete_bytes, "active successor preserves completed selection", failures)
	TestAssertions.equal(session.advance(2, 0), 2, "successor advances partially", failures)
	session.cancel()
	var partial := session.selected_report()
	TestAssertions.equal(session.available_report_kinds(), [&"complete", &"partial"] as Array[StringName], "cancelled successor retains both report kinds", failures)
	TestAssertions.equal((partial.get("runtime", {}) as Dictionary).get("status", ""), "cancelled", "cancelled partial becomes selected", failures)
	TestAssertions.equal(((partial.get("evidence", {}) as Dictionary).get("summary", {}) as Dictionary).get("attempted", 0), 2, "partial report retains exact attempted count", failures)
	TestAssertions.equal(session.select_report(&"complete"), "", "complete remains selectable beside partial", failures)
	TestAssertions.equal(LootLabReportExportService.deterministic_json(session.selected_report()), complete_bytes, "completed report survives partial successor", failures)
	TestAssertions.equal(session.select_report(&"partial"), "", "partial remains selectable", failures)

	var replacement_spec := LootLabBatchSpec.create(_request(900), 1, foundation)
	TestAssertions.equal(session.start(replacement_spec, equipment, foundation, Callable(self, &"_generator")), "", "replacement completion starts", failures)
	TestAssertions.equal(session.advance(1, 0), 1, "replacement completion finishes", failures)
	TestAssertions.equal((session.selected_report().get("runtime", {}) as Dictionary).get("status", ""), "completed", "new completion becomes selected", failures)
	TestAssertions.truthy(not session.select_report(&"partial").is_empty(), "new completion clears stale partial report", failures)
	var replacement_bytes := LootLabReportExportService.deterministic_json(session.selected_report())
	TestAssertions.truthy(not session.start(null, equipment, foundation, Callable(self, &"_generator")).is_empty(), "invalid successor fails to start", failures)
	TestAssertions.equal(LootLabReportExportService.deterministic_json(session.selected_report()), replacement_bytes, "failed successor preserves latest completion", failures)

	session.clear()
	TestAssertions.equal(session.selected_report(), {}, "clear removes all session-only reports", failures)
	TestAssertions.truthy(not session.has_active_job(), "clear leaves no active job", failures)

func _generator(
	request: ItemGenerationRequest,
	issuer_namespace: String,
	item_sequence: int,
	_equipment: EquipmentCatalog,
	_foundation: ItemFoundationCatalog
) -> ItemGenerationResult:
	_generator_call_count += 1
	var item := ItemInstance.new()
	item.instance_id = "session-%s-%d" % [issuer_namespace.sha256_text(), item_sequence]
	item.base_definition_id = &"base"
	item.item_level = request.item_level
	item.rarity_id = &"common"
	item.origin = {"issuer_namespace": issuer_namespace, "seed": request.seed, "sequence": item_sequence, "source": "session_test"}
	var trace := ItemGenerationTrace.new()
	trace.record(&"base", [&"base"], {}, {&"base": 1.0}, &"base")
	return ItemGenerationResult.success(item, trace)

func _request(sequence: int) -> ItemGenerationRequest:
	return ItemGenerationRequest.create(456, sequence, 20, &"ordinary_enemy", &"ordinary_drop", [&"common"] as Array[StringName])

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
