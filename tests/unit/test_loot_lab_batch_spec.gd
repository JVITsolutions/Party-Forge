extends RefCounted

const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"

func run() -> Array[String]:
	var failures: Array[String] = []
	var foundation := load(FOUNDATION_PATH) as ItemFoundationCatalog
	TestAssertions.truthy(foundation != null, "foundation fixture loads", failures)
	if foundation == null:
		return failures
	_test_validation(foundation, failures)
	_test_frozen_request(foundation, failures)
	_test_identity(foundation, failures)
	_test_sampling(foundation, failures)
	return failures

func _test_validation(foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	TestAssertions.truthy(not LootLabBatchSpec.create(null, 1, foundation).ok(), "missing request is rejected", failures)
	TestAssertions.truthy(not LootLabBatchSpec.create(_valid_request(), 1, null).ok(), "missing foundation is rejected", failures)
	TestAssertions.truthy(not LootLabBatchSpec.create(_valid_request(), 0, foundation).ok(), "zero attempts are rejected", failures)
	TestAssertions.truthy(not LootLabBatchSpec.create(_valid_request(), 100001, foundation).ok(), "attempts above the hard cap are rejected", failures)

	var invalid_request := _valid_request()
	invalid_request.item_level = 0
	var invalid_spec := LootLabBatchSpec.create(invalid_request, 1, foundation)
	TestAssertions.truthy(not invalid_spec.ok(), "invalid production request is rejected", failures)
	TestAssertions.truthy(invalid_spec.error.contains("item_level"), "production validation error is preserved", failures)

	var last_safe_request := _valid_request()
	last_safe_request.generation_sequence = ItemInstanceCodec.JSON_SAFE_INTEGER_MAX
	TestAssertions.truthy(LootLabBatchSpec.create(last_safe_request, 1, foundation).ok(), "last JSON-safe sequence is accepted", failures)
	TestAssertions.truthy(not LootLabBatchSpec.create(last_safe_request, 2, foundation).ok(), "final sequence overflow is rejected", failures)

func _test_frozen_request(foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var request := _valid_request()
	var expected_document := request.canonical_document()
	var spec := LootLabBatchSpec.create(request, 3, foundation)
	TestAssertions.truthy(spec.ok(), "valid request creates a batch", failures)
	if not spec.ok():
		return

	request.seed = 1
	request.permitted_rarity_ids[0] = &"common"
	TestAssertions.equal(spec.request_document(), expected_document, "later caller mutation cannot change frozen request", failures)
	var exposed_document := spec.request_document()
	exposed_document["seed"] = 2
	(exposed_document["permitted_rarity_ids"] as Array)[0] = "legendary"
	TestAssertions.equal(spec.request_document(), expected_document, "returned request document is defensive", failures)

	for attempt_index: int in 3:
		var attempt_request := spec.request_for_attempt(attempt_index)
		TestAssertions.truthy(attempt_request != null, "valid attempt %d returns a request" % attempt_index, failures)
		if attempt_request != null:
			var expected_attempt := expected_document.duplicate(true)
			expected_attempt["generation_sequence"] = 700 + attempt_index
			TestAssertions.equal(attempt_request.canonical_document(), expected_attempt, "attempt %d changes only sequence" % attempt_index, failures)
	TestAssertions.equal(spec.request_for_attempt(-1), null, "negative attempt index is rejected", failures)
	TestAssertions.equal(spec.request_for_attempt(3), null, "attempt index at target is rejected", failures)

	var first := spec.request_for_attempt(0)
	var second := spec.request_for_attempt(0)
	first.unlock_tags.append(&"rarity_epic_unlocked")
	TestAssertions.truthy(&"rarity_epic_unlocked" not in second.unlock_tags, "attempt requests are independent copies", failures)

func _test_identity(foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var request := _valid_request()
	var spec := LootLabBatchSpec.create(request, 100, foundation)
	var expected_identity := ItemGenerationBalanceReport.scenario_identity(request)
	TestAssertions.equal(spec.scenario_identity(), expected_identity, "batch reuses canonical production scenario identity", failures)
	TestAssertions.equal(spec.preview_issuer_namespace(), "loot-lab-preview:%s" % expected_identity.sha256_text(), "preview namespace derives from canonical scenario identity", failures)
	TestAssertions.equal(LootLabBatchSpec.create(request, 101, foundation).preview_issuer_namespace(), spec.preview_issuer_namespace(), "attempt count does not fork scenario namespace", failures)

	var sequence_variant := request.copy_with_sequence(999)
	TestAssertions.equal(LootLabBatchSpec.create(sequence_variant, 1, foundation).scenario_identity(), expected_identity, "starting sequence is normalized out of scenario identity", failures)

func _test_sampling(foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var request := _valid_request()
	TestAssertions.equal(LootLabBatchSpec.create(request, 1, foundation).sample_attempt_indexes(), [0], "single attempt samples itself", failures)

	var expected_hundred: Array[int] = []
	for index: int in 100:
		expected_hundred.append(index)
	TestAssertions.equal(LootLabBatchSpec.create(request, 100, foundation).sample_attempt_indexes(), expected_hundred, "100 attempts retain every attempt", failures)

	for attempt_count: int in [101, 100000]:
		var spec := LootLabBatchSpec.create(request, attempt_count, foundation)
		TestAssertions.truthy(spec.ok(), "%d-attempt spec is accepted" % attempt_count, failures)
		var indexes := spec.sample_attempt_indexes()
		TestAssertions.equal(indexes.size(), 100, "%d-attempt sample is capped at 100" % attempt_count, failures)
		TestAssertions.equal(indexes[0], 0, "%d-attempt sample includes first attempt" % attempt_count, failures)
		TestAssertions.equal(indexes[99], attempt_count - 1, "%d-attempt sample includes final attempt" % attempt_count, failures)
		for index: int in 100:
			TestAssertions.equal(indexes[index], index * (attempt_count - 1) / 99, "%d sample index %d uses integer formula" % [attempt_count, index], failures)

func _valid_request() -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(90210, 700, 80, &"ordinary_enemy", &"ordinary_drop", [&"rare"] as Array[StringName])
	request.forced_rarity_id = &"rare"
	request.unlock_tags = [&"rarity_rare_unlocked"]
	return request
