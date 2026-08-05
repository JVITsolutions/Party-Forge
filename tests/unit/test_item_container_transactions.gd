extends RefCounted

const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const OWNER_ID := "profile-a"
const SOURCE_ID := &"run-inventory"
const DESTINATION_ID := &"stash-tab-000"

var _service := ItemContainerTransactionService.new()

func run() -> Array[String]:
	var failures: Array[String] = []
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var foundation := load(FOUNDATION_PATH) as ItemFoundationCatalog
	TestAssertions.truthy(equipment != null, "equipment catalog loads for transactions", failures)
	TestAssertions.truthy(foundation != null, "foundation catalog loads for transactions", failures)
	if equipment == null or foundation == null:
		return failures
	_assert_request_contract_and_defensive_copy(failures)
	_assert_success_matrix(equipment, foundation, failures)
	_assert_failure_matrix(equipment, foundation, failures)
	_assert_replay_and_collision(equipment, foundation, failures)
	_assert_failed_first_attempt_is_retryable(equipment, foundation, failures)
	_assert_result_and_journal_defensive_copies(equipment, foundation, failures)
	_assert_validation_precedence(equipment, foundation, failures)
	print("ITEM_TRANSACTION_MATRIX: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	return failures

func _assert_request_contract_and_defensive_copy(failures: Array[String]) -> void:
	var item := _make_item("item-request", 7)
	var request := ItemTransactionRequest.create("tx-request", OWNER_ID, DESTINATION_ID, 9, item)
	var expected_fields: Array = [
		"schema_version",
		"transaction_id",
		"operation",
		"owner_id",
		"source_container_id",
		"source_slot",
		"expected_instance_id",
		"destination_container_id",
		"destination_slot",
		"create_item",
	]
	var canonical := request.canonical_document()
	TestAssertions.equal(canonical.keys(), expected_fields, "request canonical fields retain exact order", failures)
	TestAssertions.equal(canonical["schema_version"], 1, "request schema is one", failures)
	TestAssertions.equal(canonical["operation"], "create_and_place", "create operation is exact", failures)
	TestAssertions.equal(canonical["source_container_id"], "", "create source container is inapplicable", failures)
	TestAssertions.equal(canonical["source_slot"], -1, "create source slot is inapplicable", failures)
	TestAssertions.equal(canonical["expected_instance_id"], "", "create expected item is inapplicable", failures)

	var same := ItemTransactionRequest.create("tx-request", OWNER_ID, DESTINATION_ID, 9, item.copy())
	TestAssertions.equal(request.fingerprint(), same.fingerprint(), "equivalent canonical requests have deterministic fingerprints", failures)
	TestAssertions.equal(request.fingerprint(), JSON.stringify(request.canonical_document()).sha256_text(), "fingerprint hashes canonical compact JSON", failures)
	item.instance_id = "mutated-original"
	item.origin["seed"] = "mutated-original"
	(canonical["create_item"] as Dictionary)["instance_id"] = "mutated-document"
	(canonical["create_item"] as Dictionary)["origin"]["seed"] = "mutated-document"
	var escaped_item := request.create_item
	escaped_item.instance_id = "mutated-accessor"
	escaped_item.origin["seed"] = "mutated-accessor"
	var fresh := request.canonical_document()
	TestAssertions.equal(fresh["create_item"]["instance_id"], "item-request", "request owns the source item", failures)
	TestAssertions.equal(fresh["create_item"]["origin"]["seed"], 1007, "request owns nested item values", failures)
	TestAssertions.equal(request.create_item.instance_id, "item-request", "request item accessor is defensive", failures)
	TestAssertions.equal(request.fingerprint(), same.fingerprint(), "escaped documents cannot change request fingerprint", failures)
	var reordered_item := _make_item("item-request", 7)
	reordered_item.origin = {"source": "transaction_test", "sequence": 7, "seed": 1007, "issuer_namespace": "profile:profile-a"}
	var reordered := ItemTransactionRequest.create("tx-request", OWNER_ID, DESTINATION_ID, 9, reordered_item)
	TestAssertions.equal(request.fingerprint(), reordered.fingerprint(), "nested dictionary insertion order cannot change fingerprint", failures)

	var move := ItemTransactionRequest.move("tx-move-shape", OWNER_ID, SOURCE_ID, 1, "item-request", DESTINATION_ID, 2).canonical_document()
	var swap := ItemTransactionRequest.swap("tx-swap-shape", OWNER_ID, SOURCE_ID, 1, "item-request", DESTINATION_ID, 2).canonical_document()
	var remove := ItemTransactionRequest.sandbox_remove("tx-remove-shape", OWNER_ID, SOURCE_ID, 1, "item-request").canonical_document()
	TestAssertions.equal(move["operation"], "move_to_empty", "move operation is exact", failures)
	TestAssertions.equal(swap["operation"], "swap_occupied", "swap operation is exact", failures)
	TestAssertions.equal(remove["operation"], "sandbox_remove", "remove operation is exact", failures)
	for document: Dictionary in [move, swap, remove]:
		TestAssertions.equal(document["create_item"], null, "%s omits create item" % document["operation"], failures)
	TestAssertions.equal(remove["destination_container_id"], "", "remove destination container is inapplicable", failures)
	TestAssertions.equal(remove["destination_slot"], -1, "remove destination slot is inapplicable", failures)

func _assert_success_matrix(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var create_item := _make_item("item-created", 10)
	var create_state := _empty_state()
	var create_before := JSON.stringify(create_state.to_dictionary())
	var created := _service.apply(create_state, ItemTransactionRequest.create("tx-create", OWNER_ID, DESTINATION_ID, 17, create_item), ItemTransactionJournal.new(), equipment, foundation)
	_assert_success(created, "create-and-place", failures)
	TestAssertions.equal(JSON.stringify(create_state.to_dictionary()), create_before, "create leaves original bytes unchanged", failures)
	TestAssertions.equal(created.next_state.container(DESTINATION_ID).item_id_at(17), create_item.instance_id, "create preserves exact destination slot", failures)
	TestAssertions.equal(created.next_state.registry().item(create_item.instance_id).to_dictionary(), create_item.to_dictionary(), "create preserves exact item record", failures)

	var move_item := _make_item("item-moved", 11)
	var move_state := _state_with_placements([move_item], {0: move_item.instance_id}, {})
	var move_before := JSON.stringify(move_state.to_dictionary())
	var moved := _service.apply(move_state, ItemTransactionRequest.move("tx-move", OWNER_ID, SOURCE_ID, 0, move_item.instance_id, DESTINATION_ID, 42), ItemTransactionJournal.new(), equipment, foundation)
	_assert_success(moved, "move-to-empty", failures)
	TestAssertions.equal(JSON.stringify(move_state.to_dictionary()), move_before, "move leaves original bytes unchanged", failures)
	TestAssertions.equal(moved.next_state.container(SOURCE_ID).item_id_at(0), "", "move clears exact source", failures)
	TestAssertions.equal(moved.next_state.container(DESTINATION_ID).item_id_at(42), move_item.instance_id, "move fills exact destination", failures)
	TestAssertions.equal(moved.next_state.registry().item(move_item.instance_id).to_dictionary(), move_item.to_dictionary(), "move preserves exact registry item", failures)

	var left := _make_item("item-left", 12)
	var right := _make_item("item-right", 13)
	var swap_state := _state_with_placements([left, right], {2: left.instance_id}, {55: right.instance_id})
	var swap_before := JSON.stringify(swap_state.to_dictionary())
	var swapped := _service.apply(swap_state, ItemTransactionRequest.swap("tx-swap", OWNER_ID, SOURCE_ID, 2, left.instance_id, DESTINATION_ID, 55), ItemTransactionJournal.new(), equipment, foundation)
	_assert_success(swapped, "swap-occupied", failures)
	TestAssertions.equal(JSON.stringify(swap_state.to_dictionary()), swap_before, "swap leaves original bytes unchanged", failures)
	TestAssertions.equal(swapped.next_state.container(SOURCE_ID).item_id_at(2), right.instance_id, "swap puts destination item in exact source", failures)
	TestAssertions.equal(swapped.next_state.container(DESTINATION_ID).item_id_at(55), left.instance_id, "swap puts source item in exact destination", failures)
	TestAssertions.equal(swapped.next_state.registry().to_dictionary(), swap_state.registry().to_dictionary(), "swap preserves registry byte values", failures)

	var removed_item := _make_item("item-removed", 14)
	var remove_state := _state_with_placements([removed_item], {4: removed_item.instance_id}, {})
	var remove_before := JSON.stringify(remove_state.to_dictionary())
	var removed := _service.apply(remove_state, ItemTransactionRequest.sandbox_remove("tx-remove", OWNER_ID, SOURCE_ID, 4, removed_item.instance_id), ItemTransactionJournal.new(), equipment, foundation)
	_assert_success(removed, "sandbox-remove", failures)
	TestAssertions.equal(JSON.stringify(remove_state.to_dictionary()), remove_before, "remove leaves original bytes unchanged", failures)
	TestAssertions.equal(removed.next_state.container(SOURCE_ID).item_id_at(4), "", "remove clears exact source", failures)
	TestAssertions.truthy(not removed.next_state.registry().has(removed_item.instance_id), "remove erases registry record atomically", failures)

func _assert_failure_matrix(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var item_a := _make_item("item-a", 21)
	var item_b := _make_item("item-b", 22)
	var valid := _state_with_placements([item_a, item_b], {0: item_a.instance_id}, {1: item_b.instance_id})
	var invalid_request := ItemTransactionRequest.move("tx-invalid", OWNER_ID, SOURCE_ID, 0, item_a.instance_id, SOURCE_ID, 0)
	var invalid_item := _make_item("item-invalid", 23)
	invalid_item.item_level = 0
	var duplicate_reference := _state_with_placements([item_a, item_b], {0: item_a.instance_id}, {1: item_b.instance_id, 2: item_a.instance_id})
	var cases: Array[Dictionary] = [
		{"label": "invalid request", "code": ItemTransactionResult.Code.INVALID_REQUEST, "state": valid, "request": invalid_request},
		{"label": "unknown owner", "code": ItemTransactionResult.Code.UNKNOWN_OWNER, "state": valid, "request": ItemTransactionRequest.move("tx-owner", "profile-b", SOURCE_ID, 0, item_a.instance_id, DESTINATION_ID, 2)},
		{"label": "unknown container", "code": ItemTransactionResult.Code.UNKNOWN_CONTAINER, "state": valid, "request": ItemTransactionRequest.move("tx-container", OWNER_ID, &"missing", 0, item_a.instance_id, DESTINATION_ID, 2)},
		{"label": "slot out of bounds", "code": ItemTransactionResult.Code.SLOT_OUT_OF_BOUNDS, "state": valid, "request": ItemTransactionRequest.move("tx-bounds", OWNER_ID, SOURCE_ID, 5, item_a.instance_id, DESTINATION_ID, 2)},
		{"label": "source mismatch", "code": ItemTransactionResult.Code.SOURCE_MISMATCH, "state": valid, "request": ItemTransactionRequest.move("tx-source", OWNER_ID, SOURCE_ID, 0, "stale-item", DESTINATION_ID, 2)},
		{"label": "destination occupied", "code": ItemTransactionResult.Code.DESTINATION_OCCUPIED, "state": valid, "request": ItemTransactionRequest.move("tx-occupied", OWNER_ID, SOURCE_ID, 0, item_a.instance_id, DESTINATION_ID, 1)},
		{"label": "duplicate instance", "code": ItemTransactionResult.Code.DUPLICATE_INSTANCE, "state": valid, "request": ItemTransactionRequest.create("tx-instance", OWNER_ID, DESTINATION_ID, 2, item_a)},
		{"label": "duplicate reference", "code": ItemTransactionResult.Code.DUPLICATE_REFERENCE, "state": duplicate_reference, "request": ItemTransactionRequest.move("tx-reference", OWNER_ID, SOURCE_ID, 0, item_a.instance_id, DESTINATION_ID, 3)},
		{"label": "invalid item", "code": ItemTransactionResult.Code.INVALID_ITEM, "state": valid, "request": ItemTransactionRequest.create("tx-item", OWNER_ID, DESTINATION_ID, 2, invalid_item)},
	]
	if OS.get_environment("PARTY_FORGE_TRANSACTION_CASE_ORDER") == "reverse":
		cases.reverse()
	for test_case: Dictionary in cases:
		_assert_failure(test_case["state"] as ItemOwnershipState, test_case["request"] as ItemTransactionRequest, int(test_case["code"]), equipment, foundation, String(test_case["label"]), failures)

func _assert_replay_and_collision(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var state := _empty_state()
	var item := _make_item("item-replay", 30)
	var request := ItemTransactionRequest.create("tx-replay", OWNER_ID, DESTINATION_ID, 7, item)
	var journal := ItemTransactionJournal.new()
	var first := _service.apply(state, request, journal, equipment, foundation)
	var first_document := first.next_state.to_dictionary()
	var original_before_replay := JSON.stringify(state.to_dictionary())
	var replay := _service.apply(state, request, journal, equipment, foundation)
	TestAssertions.equal(replay.code, ItemTransactionResult.Code.TRANSACTION_REPLAY, "successful replay has stable code", failures)
	TestAssertions.truthy(replay.duplicate, "successful replay is marked duplicate", failures)
	TestAssertions.truthy(not replay.ok(), "replay is not a new success", failures)
	TestAssertions.equal(replay.next_state.to_dictionary(), first_document, "replay returns originally recorded complete state", failures)
	TestAssertions.equal(JSON.stringify(state.to_dictionary()), original_before_replay, "replay leaves original byte-equivalent", failures)

	var collision_request := ItemTransactionRequest.create("tx-replay", OWNER_ID, DESTINATION_ID, 8, item)
	var original_before_collision := JSON.stringify(state.to_dictionary())
	var collision := _service.apply(state, collision_request, journal, equipment, foundation)
	TestAssertions.equal(collision.code, ItemTransactionResult.Code.TRANSACTION_COLLISION, "changed request has collision code", failures)
	TestAssertions.equal(collision.next_state, null, "collision exposes no state", failures)
	TestAssertions.truthy(not collision.duplicate, "collision is not a duplicate replay", failures)
	TestAssertions.equal(JSON.stringify(state.to_dictionary()), original_before_collision, "collision leaves original byte-equivalent", failures)
	var after_collision := _service.apply(state, request, journal, equipment, foundation)
	TestAssertions.equal(after_collision.next_state.to_dictionary(), first_document, "collision does not replace journal entry", failures)

func _assert_failed_first_attempt_is_retryable(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var item := _make_item("item-retry", 40)
	var request := ItemTransactionRequest.move("tx-retry", OWNER_ID, SOURCE_ID, 0, item.instance_id, DESTINATION_ID, 4)
	var journal := ItemTransactionJournal.new()
	var failed := _service.apply(_empty_state(), request, journal, equipment, foundation)
	TestAssertions.equal(failed.code, ItemTransactionResult.Code.SOURCE_MISMATCH, "failed first attempt reports source mismatch", failures)
	TestAssertions.equal(journal.size(), 0, "failed first attempt is not journaled", failures)
	var ready := _state_with_placements([item], {0: item.instance_id}, {})
	var retried := _service.apply(ready, request, journal, equipment, foundation)
	_assert_success(retried, "failed transaction retry", failures)
	TestAssertions.equal(retried.next_state.container(DESTINATION_ID).item_id_at(4), item.instance_id, "same transaction ID succeeds after preconditions change", failures)
	TestAssertions.equal(journal.size(), 1, "successful retry is journaled once", failures)

func _assert_result_and_journal_defensive_copies(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var state := _empty_state()
	var item := _make_item("item-defensive", 50)
	var request := ItemTransactionRequest.create("tx-defensive", OWNER_ID, DESTINATION_ID, 6, item)
	var journal := ItemTransactionJournal.new()
	var result := _service.apply(state, request, journal, equipment, foundation)
	var expected := result.next_state.to_dictionary()

	var escaped_result := result.next_state
	escaped_result.owner_id = "mutated-result-owner"
	var escaped_result_item := escaped_result.registry().item(item.instance_id)
	escaped_result_item.origin["seed"] = "mutated-result-item"
	TestAssertions.equal(result.next_state.to_dictionary(), expected, "result state accessor returns defensive copies", failures)

	var entry := journal.entry("tx-defensive")
	entry["fingerprint"] = "mutated-fingerprint"
	(entry["state"] as ItemOwnershipState).owner_id = "mutated-journal-owner"
	var fresh_entry := journal.entry("tx-defensive")
	TestAssertions.equal(fresh_entry["fingerprint"], request.fingerprint(), "journal entry dictionary is defensive", failures)
	TestAssertions.equal((fresh_entry["state"] as ItemOwnershipState).to_dictionary(), expected, "journal entry state is defensive", failures)
	var entries := journal.entries()
	(entries["tx-defensive"] as Dictionary)["code"] = ItemTransactionResult.Code.INVALID_ITEM
	entries.clear()
	TestAssertions.equal(journal.size(), 1, "journal entries dictionary cannot escape", failures)
	TestAssertions.equal(journal.entry("tx-defensive")["code"], ItemTransactionResult.Code.OK, "nested journal entry cannot escape", failures)
	var journal_copy := journal.copy()
	var copied_entry := journal_copy.entry("tx-defensive")
	(copied_entry["state"] as ItemOwnershipState).owner_id = "mutated-journal-copy"
	TestAssertions.equal((journal_copy.entry("tx-defensive")["state"] as ItemOwnershipState).to_dictionary(), expected, "journal copy owns nested state", failures)
	TestAssertions.equal((journal.entry("tx-defensive")["state"] as ItemOwnershipState).to_dictionary(), expected, "journal copy cannot mutate source journal", failures)

	var replay := _service.apply(state, request, journal, equipment, foundation)
	var escaped_replay := replay.next_state
	escaped_replay.owner_id = "mutated-replay-owner"
	TestAssertions.equal(_service.apply(state, request, journal, equipment, foundation).next_state.to_dictionary(), expected, "replay state cannot mutate journal snapshot", failures)

func _assert_validation_precedence(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, failures: Array[String]) -> void:
	var item := _make_item("item-precedence", 60)
	var valid := _state_with_placements([item], {0: item.instance_id}, {})
	var journal := ItemTransactionJournal.new()
	var recorded := ItemTransactionRequest.move("tx-precedence", OWNER_ID, SOURCE_ID, 0, item.instance_id, DESTINATION_ID, 2)
	_assert_success(_service.apply(valid, recorded, journal, equipment, foundation), "precedence seed", failures)
	var malformed_collision := ItemTransactionRequest.move("tx-precedence", OWNER_ID, SOURCE_ID, 0, item.instance_id, SOURCE_ID, 0)
	_assert_failure(valid, malformed_collision, ItemTransactionResult.Code.INVALID_REQUEST, equipment, foundation, "request validation precedes journal lookup", failures)
	var owner_before_container := ItemTransactionRequest.move("tx-owner-precedence", "profile-b", &"missing", 99, item.instance_id, &"also-missing", 99)
	_assert_failure(valid, owner_before_container, ItemTransactionResult.Code.UNKNOWN_OWNER, equipment, foundation, "owner precedes container and bounds", failures)
	var container_before_bounds := ItemTransactionRequest.move("tx-container-precedence", OWNER_ID, &"missing", 99, item.instance_id, DESTINATION_ID, 99)
	_assert_failure(valid, container_before_bounds, ItemTransactionResult.Code.UNKNOWN_CONTAINER, equipment, foundation, "container precedes bounds", failures)
	var source_before_destination := ItemTransactionRequest.move("tx-source-precedence", OWNER_ID, SOURCE_ID, 1, item.instance_id, DESTINATION_ID, 1)
	_assert_failure(valid, source_before_destination, ItemTransactionResult.Code.SOURCE_MISMATCH, equipment, foundation, "source identity precedes destination occupancy", failures)
	var invalid_registry_item := _make_item("item-invalid-registry", 61)
	invalid_registry_item.item_level = 0
	var invalid_registry := _state_with_placements([invalid_registry_item], {0: invalid_registry_item.instance_id}, {})
	var stale_invalid_registry := ItemTransactionRequest.move("tx-registry-precedence", OWNER_ID, SOURCE_ID, 1, "stale", DESTINATION_ID, 2)
	_assert_failure(invalid_registry, stale_invalid_registry, ItemTransactionResult.Code.INVALID_ITEM, equipment, foundation, "registry integrity precedes source identity", failures)
	var destination_bounds := ItemTransactionRequest.move("tx-destination-bounds", OWNER_ID, SOURCE_ID, 0, item.instance_id, DESTINATION_ID, 100)
	_assert_failure(valid, destination_bounds, ItemTransactionResult.Code.SLOT_OUT_OF_BOUNDS, equipment, foundation, "destination bounds map exactly", failures)
	var empty_swap := ItemTransactionRequest.swap("tx-empty-swap", OWNER_ID, SOURCE_ID, 0, item.instance_id, DESTINATION_ID, 3)
	_assert_failure(valid, empty_swap, ItemTransactionResult.Code.SOURCE_MISMATCH, equipment, foundation, "empty swap destination maps to source mismatch", failures)
	var occupied_create := ItemTransactionRequest.create("tx-occupied-create", OWNER_ID, SOURCE_ID, 0, _make_item("item-create-occupied", 62))
	_assert_failure(valid, occupied_create, ItemTransactionResult.Code.DESTINATION_OCCUPIED, equipment, foundation, "occupied create destination maps exactly", failures)
	var duplicate_item := _make_item("item-duplicate-precedence", 63)
	var duplicate_and_occupied := _state_with_placements([duplicate_item], {0: duplicate_item.instance_id}, {})
	var duplicate_create := ItemTransactionRequest.create("tx-duplicate-precedence", OWNER_ID, SOURCE_ID, 0, duplicate_item)
	_assert_failure(duplicate_and_occupied, duplicate_create, ItemTransactionResult.Code.DUPLICATE_INSTANCE, equipment, foundation, "duplicate instance precedes destination occupancy", failures)

func _assert_success(result: ItemTransactionResult, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(result.code, ItemTransactionResult.Code.OK, "%s returns OK" % label, failures)
	TestAssertions.truthy(result.ok(), "%s reports success" % label, failures)
	TestAssertions.truthy(not result.duplicate, "%s is not duplicate" % label, failures)
	TestAssertions.truthy(result.next_state != null, "%s returns candidate state" % label, failures)

func _assert_failure(
	state: ItemOwnershipState,
	request: ItemTransactionRequest,
	expected_code: int,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	label: String,
	failures: Array[String]
) -> void:
	var before := JSON.stringify(state.to_dictionary())
	var journal := ItemTransactionJournal.new()
	var result := _service.apply(state, request, journal, equipment, foundation)
	TestAssertions.equal(result.code, expected_code, "%s has stable failure code" % label, failures)
	TestAssertions.truthy(not result.ok(), "%s is not successful" % label, failures)
	TestAssertions.equal(result.next_state, null, "%s has no candidate state" % label, failures)
	TestAssertions.equal(JSON.stringify(state.to_dictionary()), before, "%s leaves original byte-equivalent" % label, failures)
	TestAssertions.equal(journal.size(), 0, "%s is not journaled" % label, failures)

func _empty_state() -> ItemOwnershipState:
	return _state_with_placements([], {}, {})

func _state_with_placements(items: Array[ItemInstance], source_slots: Dictionary, destination_slots: Dictionary) -> ItemOwnershipState:
	var registry := ItemRegistry.new(items)
	var source := ItemSlotContainer.create(SOURCE_ID, ItemSlotContainer.RUN_INVENTORY, OWNER_ID, 5, source_slots)
	var destination := ItemSlotContainer.create(DESTINATION_ID, ItemSlotContainer.PROFILE_STASH_TAB, OWNER_ID, 100, destination_slots)
	return ItemOwnershipState.create(OWNER_ID, registry, [source, destination])

func _make_item(instance_id: String, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = &"forge_vanguard_sword"
	item.item_level = 28
	item.rarity_id = &"common"
	item.affixes = []
	item.origin = {
		"issuer_namespace": "profile:profile-a",
		"seed": 1000 + sequence,
		"sequence": sequence,
		"source": "transaction_test",
	}
	return item
