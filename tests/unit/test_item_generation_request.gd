extends RefCounted

const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"

func run() -> Array[String]:
	var failures: Array[String] = []
	var foundation := load(FOUNDATION_PATH) as ItemFoundationCatalog
	TestAssertions.truthy(foundation != null, "foundation fixture loads", failures)
	if foundation == null:
		return failures
	_test_create_and_canonical_document(failures)
	_test_request_validation(foundation, failures)
	_test_structured_outcomes(failures)
	_test_trace_canonicalization(failures)
	_test_deterministic_random(failures)
	return failures

func _test_create_and_canonical_document(failures: Array[String]) -> void:
	var permitted: Array[StringName] = [&"uncommon", &"common"]
	var request := ItemGenerationRequest.create(991, 4, 250, &"ordinary_enemy", &"ordinary_drop", permitted)
	permitted[0] = &"rare"
	request.party_archetype_tags = [&"melee", &"caster"]
	request.charisma_value = 25.0
	request.unlock_tags = [&"rarity_rare_unlocked", &"rarity_epic_unlocked"]
	request.required_base_tags = [&"weapon", &"melee"]
	request.excluded_base_tags = [&"caster"]
	request.required_affix_tags = [&"melee", &"weapon"]
	request.excluded_affix_tags = [&"caster"]
	request.forced_base_id = &"forge_vanguard_sword"
	request.forced_rarity_id = &"common"
	var canonical := request.canonical_document()
	var expected := {
		"seed": 991,
		"generation_sequence": 4,
		"item_level": 250,
		"source_id": "ordinary_enemy",
		"generation_domain": "ordinary_drop",
		"difficulty_id": "normal",
		"heat": 0.0,
		"permitted_rarity_ids": ["common", "uncommon"],
		"party_archetype_tags": ["caster", "melee"],
		"charisma_value": 25.0,
		"unlock_tags": ["rarity_epic_unlocked", "rarity_rare_unlocked"],
		"required_base_tags": ["melee", "weapon"],
		"excluded_base_tags": ["caster"],
		"required_affix_tags": ["melee", "weapon"],
		"excluded_affix_tags": ["caster"],
		"forced_base_id": "forge_vanguard_sword",
		"forced_rarity_id": "common",
	}
	TestAssertions.equal(canonical, expected, "canonical request has exact JSON-safe sorted shape", failures)
	TestAssertions.truthy(_is_json_value(canonical), "canonical request contains only JSON value types", failures)
	TestAssertions.truthy(JSON.parse_string(JSON.stringify(canonical)) != null, "canonical request round-trips through JSON", failures)
	(canonical["permitted_rarity_ids"] as Array)[0] = "mutated"
	TestAssertions.equal(request.permitted_rarity_ids, [&"uncommon", &"common"], "create and canonical document isolate permitted rarity arrays", failures)
	TestAssertions.equal(request.party_archetype_tags, [&"melee", &"caster"], "canonical sorting does not mutate request arrays", failures)
	request.heat = NAN
	TestAssertions.equal(request.canonical_document(), {}, "nonfinite Heat has no canonical document", failures)
	request.heat = 0.0
	request.charisma_value = INF
	TestAssertions.equal(request.canonical_document(), {}, "nonfinite Charisma has no canonical document", failures)

func _test_request_validation(foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var request := _valid_request()
	TestAssertions.equal(request.validate(foundation), "", "valid request passes", failures)

	request.item_level = 0
	_expect_error(request, foundation, "item_level", "must be between 1 and 1000", "item level lower bound", failures)
	request.source_id = &"missing_source"
	_expect_error(request, foundation, "item_level", "must be between 1 and 1000", "first request error is preserved", failures)
	request = _valid_request()
	request.item_level = 1001
	_expect_error(request, foundation, "item_level", "must be between 1 and 1000", "item level upper bound", failures)

	request = _valid_request()
	request.generation_sequence = -1
	_expect_error(request, foundation, "generation_sequence", "must be nonnegative", "negative generation sequence", failures)
	request = _valid_request()
	request.source_id = &"missing_source"
	_expect_error(request, foundation, "source_id", "unknown source missing_source", "unknown source", failures)
	request = _valid_request()
	request.generation_domain = &"missing_domain"
	_expect_error(request, foundation, "generation_domain", "unknown generation domain missing_domain", "unknown domain", failures)
	request = _valid_request()
	request.difficulty_id = &"hard"
	_expect_error(request, foundation, "difficulty_id", "unsupported difficulty hard", "unsupported increment-one difficulty", failures)

	request = _valid_request()
	request.heat = -0.01
	_expect_error(request, foundation, "heat", "must be finite and nonnegative", "negative Heat", failures)
	request = _valid_request()
	request.heat = NAN
	_expect_error(request, foundation, "heat", "must be finite and nonnegative", "nonfinite Heat", failures)
	request = _valid_request()
	request.charisma_value = -0.01
	_expect_error(request, foundation, "charisma_value", "must be finite and nonnegative", "negative Charisma", failures)
	request = _valid_request()
	request.charisma_value = INF
	_expect_error(request, foundation, "charisma_value", "must be finite and nonnegative", "nonfinite Charisma", failures)

	request = _valid_request()
	request.permitted_rarity_ids = []
	_expect_error(request, foundation, "permitted_rarity_ids", "must not be empty", "empty permitted rarity list", failures)
	request = _valid_request()
	request.permitted_rarity_ids = [&"common", &"missing_rarity"]
	_expect_error(request, foundation, "permitted_rarity_ids", "unknown rarity missing_rarity", "unknown permitted rarity", failures)
	request = _valid_request()
	request.permitted_rarity_ids = [&"common", &"common"]
	_expect_error(request, foundation, "permitted_rarity_ids", "duplicate value common", "duplicate permitted rarity", failures)
	request = _valid_request()
	request.forced_rarity_id = &"missing_rarity"
	_expect_error(request, foundation, "forced_rarity_id", "unknown rarity missing_rarity", "unknown forced rarity", failures)

	request = _valid_request()
	request.unlock_tags = [&"rarity_rare_unlocked"]
	TestAssertions.equal(request.validate(foundation), "", "manifest rarity unlock tag passes", failures)
	var affix_unlock_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var unlocked_index := affix_unlock_foundation.affixes.find(affix_unlock_foundation.affix(&"stout"))
	affix_unlock_foundation.affixes[unlocked_index] = affix_unlock_foundation.affixes[unlocked_index].duplicate(true) as ItemAffixDefinition
	affix_unlock_foundation.affixes[unlocked_index].required_unlock_tags = [&"affix_stout_unlocked"]
	request.unlock_tags = [&"affix_stout_unlocked"]
	TestAssertions.equal(request.validate(affix_unlock_foundation), "", "manifest affix unlock tag passes", failures)
	TestAssertions.truthy(&"affix_stout_unlocked" in affix_unlock_foundation.generation_unlock_tags(), "foundation exposes affix unlock vocabulary", failures)
	request.unlock_tags = [&"missing_unlock"]
	_expect_error(request, affix_unlock_foundation, "unlock_tags", "unknown unlock tag missing_unlock", "unknown unlock tag", failures)
	request = _valid_request()
	request.party_archetype_tags = [&"missing_archetype"]
	_expect_error(request, foundation, "party_archetype_tags", "unknown archetype tag missing_archetype", "unknown archetype tag", failures)
	request = _valid_request()
	request.required_base_tags = [&"missing_item_tag"]
	_expect_error(request, foundation, "required_base_tags", "unknown item tag missing_item_tag", "unknown base tag", failures)
	request = _valid_request()
	request.required_affix_tags = [&"missing_item_tag"]
	_expect_error(request, foundation, "required_affix_tags", "unknown item tag missing_item_tag", "unknown affix tag", failures)

	request = _valid_request()
	request.required_base_tags = [&"ranged"]
	request.excluded_base_tags = [&"ranged"]
	_expect_error(request, foundation, "required_base_tags", "contradicts excluded tag ranged", "base tag contradiction", failures)
	request = _valid_request()
	request.required_affix_tags = [&"caster"]
	request.excluded_affix_tags = [&"caster"]
	_expect_error(request, foundation, "required_affix_tags", "contradicts excluded tag caster", "affix tag contradiction", failures)

func _test_structured_outcomes(failures: Array[String]) -> void:
	var failure := ItemGenerationFailure.new()
	failure.generator_version = 1
	failure.stage = &"rarity"
	failure.code = &"no_eligible_rarity"
	failure.source_id = &"ordinary_enemy"
	failure.seed = 991
	failure.generation_sequence = 4
	TestAssertions.equal(
		failure.message(),
		"PARTY_FORGE_ITEM_GENERATION_ERROR generator_version=1 stage=rarity code=no_eligible_rarity source=ordinary_enemy seed=991 sequence=4",
		"structured failure has stable message",
		failures
	)
	var trace := ItemGenerationTrace.new()
	var item := ItemInstance.new()
	var success := ItemGenerationResult.success(item, trace)
	TestAssertions.truthy(success != null and success.ok(), "success factory creates an ok result", failures)
	if success != null:
		TestAssertions.equal(success.item, item, "success result exposes its item", failures)
		TestAssertions.equal(success.failure, null, "success result has no failure branch", failures)
		TestAssertions.equal(success.trace, trace, "success result retains its trace", failures)
	var failed := ItemGenerationResult.failed(failure, trace)
	TestAssertions.truthy(failed != null and not failed.ok(), "failure factory creates a failed result", failures)
	if failed != null:
		TestAssertions.equal(failed.item, null, "failed result has no item branch", failures)
		TestAssertions.equal(failed.failure, failure, "failed result exposes its failure", failures)
		TestAssertions.equal(failed.trace, trace, "failed result retains its trace", failures)
	TestAssertions.equal(ItemGenerationResult.success(null, trace), null, "success factory rejects a missing item", failures)
	TestAssertions.equal(ItemGenerationResult.failed(null, trace), null, "failure factory rejects a missing failure", failures)
	var direct_both := ItemGenerationResult.new(item, failure, trace)
	TestAssertions.truthy((direct_both.item != null) != (direct_both.failure != null), "direct construction normalizes a both-branch state", failures)
	var direct_neither := ItemGenerationResult.new(null, null, trace)
	TestAssertions.truthy((direct_neither.item != null) != (direct_neither.failure != null), "direct construction normalizes a neither-branch state", failures)
	success.item = null
	success.failure = failure
	TestAssertions.truthy(success.ok() and success.item == item and success.failure == null, "result branches are read-only after construction", failures)

func _test_trace_canonicalization(failures: Array[String]) -> void:
	var trace := ItemGenerationTrace.new()
	var eligible: Array[StringName] = [&"b", &"a"]
	var rejected := {
		&"z": {"codes": [&"later", &"first"]},
		&"a": {"reason": &"filtered"},
	}
	var weights := {&"b": 1.0, &"a": 2.0}
	trace.record(&"base", eligible, rejected, weights, &"a")
	eligible[0] = &"mutated"
	(rejected[&"z"] as Dictionary)["codes"] = [&"mutated"]
	weights[&"a"] = 99.0
	var expected := {
		"stage": "base",
		"eligible": ["a", "b"],
		"rejected": {
			"a": {"reason": "filtered"},
			"z": {"codes": ["later", "first"]},
		},
		"weights": {"a": 2.0, "b": 1.0},
		"selected": "a",
	}
	TestAssertions.equal(trace.stages, [expected], "trace records canonical deep-copied stage evidence", failures)
	TestAssertions.truthy(_is_json_value(trace.stages), "trace evidence contains only JSON value types", failures)
	var exposed := trace.stages
	(exposed[0] as Dictionary)["selected"] = "mutated"
	TestAssertions.equal(trace.stages, [expected], "trace readers cannot mutate recorded evidence", failures)
	trace.record(&"invalid_weight", [&"a"], {}, {&"a": INF}, &"a")
	TestAssertions.equal(trace.stages, [expected], "trace rejects nonfinite weight evidence without mutation", failures)
	trace.record(&"invalid_detail", [&"a"], {&"a": {"score": NAN}}, {&"a": 1.0}, &"a")
	TestAssertions.equal(trace.stages, [expected], "trace rejects nested nonfinite rejection evidence without mutation", failures)

func _test_deterministic_random(failures: Array[String]) -> void:
	var repeated := ItemDeterministicRandom.unit(991, 4, &"rarity", 0)
	TestAssertions.equal(repeated, 0.66747969388961792, "unit golden vector locks SHA-256 first-15-hex seeding", failures)
	TestAssertions.equal(repeated, ItemDeterministicRandom.unit(991, 4, &"rarity", 0), "same stage roll repeats", failures)
	TestAssertions.truthy(repeated >= 0.0 and repeated < 1.0, "unit draw stays in half-open unit interval", failures)
	TestAssertions.truthy(repeated != ItemDeterministicRandom.unit(991, 4, &"base", 0), "stage salt isolates random substreams", failures)
	TestAssertions.truthy(repeated != ItemDeterministicRandom.unit(991, 4, &"rarity", 1), "draw index isolates random substreams", failures)
	var before_other_stage := ItemDeterministicRandom.unit(991, 4, &"base", 0)
	ItemDeterministicRandom.unit(991, 4, &"rarity", 0)
	TestAssertions.equal(before_other_stage, ItemDeterministicRandom.unit(991, 4, &"base", 0), "other stage draws cannot advance base stream", failures)
	TestAssertions.equal(
		ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {&"b": 1.0, &"a": 2.0}),
		ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {&"a": 2.0, &"b": 1.0}),
		"weight dictionary order is irrelevant",
		failures
	)
	TestAssertions.equal(ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {&"b": 1.0, &"a": 2.0}), &"b", "weighted selection golden vector is exact", failures)
	var lexical_weights: Dictionary = {}
	lexical_weights[StringName("c")] = 1.0
	lexical_weights[StringName("a")] = 1.0
	lexical_weights[StringName("b")] = 1.0
	var lexical_stage := StringName("tier:prefix:0:tiered")
	TestAssertions.equal(
		ItemDeterministicRandom.weighted_id(8128, 9, lexical_stage, 0, lexical_weights),
		&"a",
		"weighted selection golden vector uses lexical id order",
		failures
	)
	var intern_noise: Array[StringName] = []
	for index: int in 32:
		intern_noise.append(StringName("weighted_order_noise_%d" % index))
	var reordered_lexical_weights: Dictionary = {}
	reordered_lexical_weights["b"] = 1.0
	reordered_lexical_weights["c"] = 1.0
	reordered_lexical_weights["a"] = 1.0
	TestAssertions.equal(
		ItemDeterministicRandom.weighted_id(8128, 9, lexical_stage, 0, reordered_lexical_weights),
		&"a",
		"insertion and StringName allocation order cannot change the lexical golden choice",
		failures
	)
	var boundary_sorted: Dictionary = {}
	boundary_sorted[&"a"] = 6674796938896180
	boundary_sorted[&"b"] = 3325203061103820
	boundary_sorted[&"c"] = 1
	boundary_sorted[&"d"] = 1
	var boundary_reordered: Dictionary = {}
	boundary_reordered[&"c"] = 1
	boundary_reordered[&"d"] = 1
	boundary_reordered[&"a"] = 6674796938896180
	boundary_reordered[&"b"] = 3325203061103820
	var boundary_sorted_choice := ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, boundary_sorted)
	var boundary_reordered_choice := ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, boundary_reordered)
	TestAssertions.equal(boundary_sorted_choice, &"b", "reviewer boundary vector has an exact lexical-order base choice", failures)
	TestAssertions.equal(boundary_reordered_choice, &"b", "reviewer boundary vector base choice ignores dictionary insertion order", failures)
	TestAssertions.equal(
		ItemDeterministicRandom.weighted_id(991, 4, &"rarity", 0, boundary_sorted),
		&"a",
		"lexically accumulated boundary total has an exact rarity choice",
		failures
	)
	TestAssertions.equal(
		ItemDeterministicRandom.weighted_id(991, 4, &"rarity", 0, boundary_reordered),
		&"a",
		"boundary total accumulation ignores dictionary insertion order",
		failures
	)
	TestAssertions.equal(ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {}), &"", "empty weights are rejected", failures)
	TestAssertions.equal(ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {&"a": 0.0}), &"", "nonpositive weights are rejected", failures)
	TestAssertions.equal(ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {&"a": NAN}), &"", "nonfinite weights are rejected", failures)
	TestAssertions.equal(ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {7: 1.0}), &"", "non-string weight keys are rejected", failures)
	TestAssertions.equal(ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {&"a": true}), &"", "boolean weights are rejected", failures)
	TestAssertions.equal(ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {&"a": "1.0"}), &"", "numeric string weights are rejected", failures)
	TestAssertions.truthy(not ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {&"a": 1, &"b": 2.0}).is_empty(), "integer and float weights are accepted", failures)

func _valid_request() -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(991, 4, 250, &"ordinary_enemy", &"ordinary_drop", [&"common", &"uncommon"])
	request.party_archetype_tags = [&"melee"]
	request.charisma_value = 25.0
	return request

func _expect_error(
	request: ItemGenerationRequest,
	foundation: ItemFoundationCatalog,
	field: String,
	reason: String,
	label: String,
	failures: Array[String]
) -> void:
	TestAssertions.equal(
		request.validate(foundation),
		"PARTY_FORGE_ITEM_GENERATION_ERROR stage=request field=%s reason=%s" % [field, reason],
		label,
		failures
	)

func _is_json_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for entry: Variant in value:
				if not _is_json_value(entry):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or not _is_json_value(value[key]):
					return false
			return true
	return false
