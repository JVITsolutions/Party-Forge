class_name LootLabReportAccumulator
extends RefCounted

const REPORT_SCHEMA_VERSION := 1
const DIAGNOSTIC_EXAMPLE_LIMIT := 20

var error := ""
var _spec: LootLabBatchSpec
var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog
var _next_attempt_index := 0
var _succeeded := 0
var _failed := 0
var _sample_indexes: Dictionary = {}
var _samples: Array[Dictionary] = []
var _expected: Dictionary = {}
var _observed: Dictionary = {}
var _opportunities: Dictionary = {}
var _rejections: Dictionary = {}
var _failure_counts: Dictionary = {}
var _diagnostic_categories: Dictionary = {}
var _encountered_affix_ids: Dictionary = {}
var _reachability: Dictionary = {}
var _finalized_report: Dictionary = {}

static func create(
	spec: LootLabBatchSpec,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> LootLabReportAccumulator:
	var result := LootLabReportAccumulator.new()
	result._initialize(spec, equipment, foundation)
	return result

func record(attempt_index: int, result: ItemGenerationResult) -> String:
	if not _finalized_report.is_empty():
		return _error("state", "report already finalized")
	if not error.is_empty():
		return error
	if attempt_index != _next_attempt_index:
		return _error("attempt_index", "expected %d got %d" % [_next_attempt_index, attempt_index])
	var sequence := _starting_sequence() + attempt_index
	_next_attempt_index += 1
	var succeeded := result != null and result.ok()
	if succeeded:
		_succeeded += 1
	else:
		_failed += 1
		_record_failure(result, sequence)
	_record_trace(result.trace if result != null else null, sequence)
	if _sample_indexes.has(attempt_index):
		_samples.append(_sample_document(attempt_index, sequence, result))
	return ""

func finalize(status: StringName, runtime_metrics: Dictionary) -> Dictionary:
	if not _finalized_report.is_empty():
		return _finalized_report.duplicate(true)
	var runtime := _runtime_document(status, runtime_metrics)
	if not error.is_empty():
		runtime["error"] = error
		runtime["status"] = "failed"
		_finalized_report = {"evidence": {}, "runtime": runtime}
		return _finalized_report.duplicate(true)
	var attempted := _next_attempt_index
	var evidence := {
		"aggregates": {
			"expected": _expected,
			"observed": _observed,
			"opportunities": _opportunities,
			"rejections": _rejections,
		},
		"catalog": {
			"affixes": _foundation.affixes.size(),
			"bases": _equipment.definitions.size(),
			"rarities": _foundation.rarities.size(),
		},
		"diagnostics": {
			"categories": _diagnostic_categories,
			"encountered_unobserved": _encountered_unobserved(),
			"reachability": _reachability_diagnostics(),
			"unencountered_reachable_affixes": _unencountered_reachable_affixes(),
		},
		"failures": {"by_stage_code": _failure_counts},
		"generator_version": ItemGenerationService.GENERATOR_VERSION,
		"request": _spec.request_document(),
		"samples": _samples,
		"scenario_identity": _spec.scenario_identity(),
		"schema_version": REPORT_SCHEMA_VERSION,
		"sequence_range": {
			"attempted_end": _starting_sequence() + attempted - 1 if attempted > 0 else null,
			"start": _starting_sequence(),
			"target_end": _starting_sequence() + _spec.target_count - 1,
		},
		"summary": {
			"attempted": attempted,
			"failed": _failed,
			"succeeded": _succeeded,
			"target": _spec.target_count,
		},
	}
	_finalized_report = ItemGenerationTrace.canonical_json_copy({"evidence": evidence, "runtime": runtime}) as Dictionary
	return _finalized_report.duplicate(true)

func _initialize(
	spec: LootLabBatchSpec,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> void:
	if spec == null or not spec.ok():
		error = _error("spec", "valid batch specification is required")
		return
	if equipment == null:
		error = _error("equipment", "catalog is missing")
		return
	if foundation == null:
		error = _error("foundation", "catalog is missing")
		return
	_spec = spec
	_equipment = equipment
	_foundation = foundation
	for attempt_index: int in spec.sample_attempt_indexes():
		_sample_indexes[attempt_index] = true
	var template := spec.request_for_attempt(0)
	_reachability = ItemGenerationAnalysis.request_reachability(template, equipment, foundation)
	if not String(_reachability.get("error", "")).is_empty():
		error = _error("reachability", String(_reachability["error"]))

func _record_failure(result: ItemGenerationResult, sequence: int) -> void:
	if result == null or result.failure == null:
		_increment(_failure_counts, "result/invalid_result")
		_record_diagnostic("invalid_result", sequence)
		return
	var key := "%s/%s" % [result.failure.stage, result.failure.code]
	_increment(_failure_counts, key)
	_record_diagnostic("generation_failure:%s" % key, sequence)

func _record_trace(trace: ItemGenerationTrace, sequence: int) -> void:
	for opportunity: Dictionary in ItemGenerationAnalysis.selection_opportunities(trace):
		var stage := String(opportunity.get("stage", ""))
		_record_rejections(stage, opportunity.get("rejected", {}) as Dictionary, sequence)
		if not bool(opportunity.get("valid", false)):
			_record_diagnostic("invalid_opportunity:%s" % stage, sequence)
			continue
		_increment(_opportunities, stage)
		var expected_row := _dictionary_row(_expected, stage)
		for candidate: String in opportunity.get("expected", {}) as Dictionary:
			_add_float(expected_row, candidate, float((opportunity["expected"] as Dictionary)[candidate]))
			if stage.begins_with("affix:"):
				_encountered_affix_ids[candidate] = true
		var selected := String(opportunity.get("selected", ""))
		if not selected.is_empty():
			_increment(_dictionary_row(_observed, stage), selected)
		_record_normalized_dimensions(stage, opportunity, selected)

func _record_rejections(stage: String, rejected: Dictionary, sequence: int) -> void:
	for candidate: String in rejected:
		var reason_value: Variant = rejected[candidate]
		var reason := String(reason_value) if typeof(reason_value) in [TYPE_STRING, TYPE_STRING_NAME] else JSON.stringify(ItemGenerationTrace.canonical_json_copy(reason_value))
		var stage_row := _dictionary_row(_rejections, stage)
		var candidate_row := _dictionary_row(stage_row, candidate)
		_increment(candidate_row, reason)
		_record_diagnostic("rejection:%s:%s" % [stage, reason], sequence)
		if reason.contains("blocked") or reason.contains("duplicate") or reason.contains("conflict"):
			_record_diagnostic("conflict:%s" % reason, sequence)

func _record_normalized_dimensions(stage: String, opportunity: Dictionary, selected: String) -> void:
	var expected := opportunity.get("expected", {}) as Dictionary
	if stage.begins_with("affix:"):
		_record_mapped_dimension("affix", expected, selected, func(candidate: String) -> Array[String]: return [candidate])
		_record_mapped_dimension("affix_kind", expected, selected, func(candidate: String) -> Array[String]:
			var definition := _foundation.affix(StringName(candidate))
			return [definition.affix_kind] if definition != null else [] as Array[String]
		)
		_record_mapped_dimension("family", expected, selected, func(candidate: String) -> Array[String]:
			var definition := _foundation.affix(StringName(candidate))
			var families: Array[String] = []
			if definition != null:
				for family_id: StringName in definition.modifier_family_ids:
					families.append(String(family_id))
			return families
		)
		_record_mapped_dimension("weight_band", expected, selected, func(candidate: String) -> Array[String]:
			var definition := _foundation.affix(StringName(candidate))
			return [ItemGenerationAnalysis.weight_band_key(definition.base_weight)] if definition != null else [] as Array[String]
		)
	elif stage.begins_with("tier:"):
		_record_mapped_dimension("tier", expected, selected, func(candidate: String) -> Array[String]: return ["tier_%s" % candidate])

func _record_mapped_dimension(dimension: String, expected: Dictionary, selected: String, mapper: Callable) -> void:
	var expected_row := _dictionary_row(_expected, dimension)
	for candidate: String in expected:
		for mapped: String in mapper.call(candidate) as Array[String]:
			_add_float(expected_row, mapped, float(expected[candidate]))
	if selected.is_empty():
		return
	for mapped: String in mapper.call(selected) as Array[String]:
		_increment(_dictionary_row(_observed, dimension), mapped)

func _record_diagnostic(category: String, sequence: int) -> void:
	var row := _dictionary_row(_diagnostic_categories, category)
	row["count"] = int(row.get("count", 0)) + 1
	var examples: Array = row.get("example_sequences", []) as Array
	if examples.size() < DIAGNOSTIC_EXAMPLE_LIMIT:
		examples.append(sequence)
	row["example_sequences"] = examples

func _sample_document(
	attempt_index: int,
	sequence: int,
	result: ItemGenerationResult
) -> Dictionary:
	var trace_document: Array = result.trace.stages if result != null and result.trace != null else []
	var document := {
		"attempt_index": attempt_index,
		"generation_sequence": sequence,
		"status": "succeeded" if result != null and result.ok() else "failed",
		"trace": trace_document,
	}
	if result != null and result.ok():
		document["item"] = ItemGenerationTrace.canonical_json_copy(result.item.to_dictionary())
	else:
		document["failure"] = _failure_document(result.failure if result != null else null, sequence)
	return ItemGenerationTrace.canonical_json_copy(document) as Dictionary

func _failure_document(failure: ItemGenerationFailure, sequence: int) -> Dictionary:
	if failure == null:
		return {
			"code": "invalid_result",
			"details": {},
			"generation_sequence": sequence,
			"generator_version": ItemGenerationService.GENERATOR_VERSION,
			"seed": int(_spec.request_document().get("seed", 0)),
			"source_id": String(_spec.request_document().get("source_id", "")),
			"stage": "result",
		}
	var details := failure.details.duplicate(true)
	var details_error := ItemGenerationTrace.json_value_error(details)
	if not details_error.is_empty():
		details = {"canonicalization_error": details_error}
	return ItemGenerationTrace.canonical_json_copy({
		"code": String(failure.code),
		"details": details,
		"generation_sequence": failure.generation_sequence,
		"generator_version": failure.generator_version,
		"seed": failure.seed,
		"source_id": String(failure.source_id),
		"stage": String(failure.stage),
	}) as Dictionary

func _encountered_unobserved() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var stages: Array[String] = []
	for stage: Variant in _expected:
		stages.append(String(stage))
	stages.sort()
	for stage: String in stages:
		var expected_row := _expected[stage] as Dictionary
		var observed_row := _observed.get(stage, {}) as Dictionary
		var candidates: Array[String] = []
		for candidate: Variant in expected_row:
			candidates.append(String(candidate))
		candidates.sort()
		for candidate: String in candidates:
			if float(expected_row[candidate]) > 0.0 and int(observed_row.get(candidate, 0)) == 0:
				rows.append({"candidate": candidate, "expected_sum": expected_row[candidate], "stage": stage})
	return rows

func _unencountered_reachable_affixes() -> Array[String]:
	var result: Array[String] = []
	for id_value: Variant in _reachability.get("reachable_affixes", []) as Array:
		var id := String(id_value)
		var definition := _foundation.affix(StringName(id))
		if definition != null and definition.affix_kind != "implicit" and not _encountered_affix_ids.has(id):
			result.append(id)
	result.sort()
	return result

func _reachability_diagnostics() -> Dictionary:
	var result := _reachability.duplicate(true)
	var impossible_patterns: Array[Dictionary] = []
	for row_value: Variant in _reachability.get("pattern_rows", []) as Array:
		var row := row_value as Dictionary
		if not bool(row.get("viable", false)):
			impossible_patterns.append(row.duplicate(true))
	result["impossible_patterns"] = impossible_patterns
	var inactive_rarities: Array[Dictionary] = []
	for row_value: Variant in _reachability.get("not_applicable", []) as Array:
		var row := row_value as Dictionary
		if String(row.get("kind", "")) == "rarity":
			inactive_rarities.append(row.duplicate(true))
	result["inactive_rarities"] = inactive_rarities
	result["tier_gaps"] = _tier_gap_rows()
	return result

func _tier_gap_rows() -> Array[Dictionary]:
	var grouped: Dictionary = {}
	for row_value: Variant in _reachability.get("tier_rows", []) as Array:
		var row := row_value as Dictionary
		var key := "%s|%s" % [String(row.get("affix_id", "")), String(row.get("rarity_id", ""))]
		if not grouped.has(key):
			grouped[key] = []
		(grouped[key] as Array).append(int(row.get("tier", 0)))
	var gaps: Array[Dictionary] = []
	for key: String in grouped:
		var tiers := grouped[key] as Array
		tiers.sort()
		if tiers.size() < 2:
			continue
		for tier: int in range(int(tiers.front()), int(tiers.back()) + 1):
			if tier not in tiers:
				var parts := key.split("|", false)
				gaps.append({"affix_id": parts[0], "rarity_id": parts[1], "tier": tier})
	return gaps

func _runtime_document(status: StringName, metrics: Dictionary) -> Dictionary:
	var elapsed := _finite_nonnegative(metrics.get("elapsed_seconds", 0.0))
	var throughput := _finite_nonnegative(metrics.get("items_per_second", 0.0))
	return {
		"elapsed_seconds": elapsed,
		"items_per_second": throughput,
		"status": String(status),
	}

func _starting_sequence() -> int:
	return int(_spec.request_document().get("generation_sequence", 0)) if _spec != null else 0

func _dictionary_row(parent: Dictionary, key: String) -> Dictionary:
	if not parent.has(key) or not parent[key] is Dictionary:
		parent[key] = {}
	return parent[key] as Dictionary

func _increment(values: Dictionary, key: String) -> void:
	values[key] = int(values.get(key, 0)) + 1

func _add_float(values: Dictionary, key: String, amount: float) -> void:
	values[key] = float(values.get(key, 0.0)) + amount

func _finite_nonnegative(value: Variant) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0.0
	var number := float(value)
	return number if is_finite(number) and number >= 0.0 else 0.0

func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_LOOT_LAB_REPORT_ERROR field=%s reason=%s" % [field, reason]
