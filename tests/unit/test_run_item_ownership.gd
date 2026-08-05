extends RefCounted

const INVENTORY_ID := &"run-inventory"

var _parties: Array[PartyManager] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	var probe := PlayerRunContext.new()
	TestAssertions.truthy(probe.has_method(&"item_state"), "run context exposes defensive item state", failures)
	TestAssertions.truthy(probe.has_method(&"run_inventory"), "run context exposes its fixed inventory projection", failures)
	TestAssertions.truthy(probe.has_method(&"apply_item_transaction"), "run context exposes its production item transaction boundary", failures)
	if not failures.is_empty():
		return failures
	_test_exact_inventory_capacities(failures)
	_test_cross_context_state_and_profile_isolation(failures)
	_test_run_issuance_sequence_and_replay(failures)
	_test_invalid_inputs_and_operation_policy_are_atomic(failures)
	_test_recruit_adds_equipment_without_resetting_item_state(failures)
	for party: PartyManager in _parties:
		party.free()
	_parties.clear()
	return failures

func _test_recruit_adds_equipment_without_resetting_item_state(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"ranger"))
	_parties.append(party)
	var context := PlayerRunContext.new()
	var profile := _profile("profile-recruit-equipment", 2, 0)
	TestAssertions.equal(context.configure(&"recruit_equipment", 0, profile, 7301, party, 100), PackedStringArray(), "recruit continuity context configures", failures)
	var first_item := _issued_item(context, 0, "recruit-before", failures)
	if first_item == null:
		return
	var first_create := ItemTransactionRequest.create("recruit-before-create", String(context.run_player_id), INVENTORY_ID, 0, first_item)
	TestAssertions.equal(_apply(context, first_create, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).code, ItemTransactionResult.Code.OK, "pre-recruit inventory item commits", failures)
	var member_one_before := (context.call(&"equipment_for", 1) as ItemSlotContainer).to_dictionary()
	var member_two_before := (context.call(&"equipment_for", 2) as ItemSlotContainer).to_dictionary()
	var inventory_before := _run_inventory(context).to_dictionary()
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"cleric")), "post-configuration recruit joins", failures)
	var recruited := context.call(&"equipment_for", 3) as ItemSlotContainer
	TestAssertions.truthy(recruited != null, "recruit receives one equipment container", failures)
	if recruited != null:
		TestAssertions.equal(recruited.container_id, &"run-equipment-003", "recruit equipment ID is stable", failures)
		TestAssertions.equal(recruited.container_kind, ItemSlotContainer.RUN_MEMBER_EQUIPMENT, "recruit equipment has run kind", failures)
		TestAssertions.equal(recruited.owner_id, String(context.run_player_id), "recruit equipment retains run owner", failures)
		TestAssertions.equal(recruited.capacity, EquipmentSlotIndex.capacity(), "recruit equipment has eleven slots", failures)
		TestAssertions.equal(recruited.occupied_slots(), [], "recruit equipment starts empty", failures)
	TestAssertions.equal((context.call(&"equipment_for", 1) as ItemSlotContainer).to_dictionary(), member_one_before, "recruit preserves leader equipment bytes", failures)
	TestAssertions.equal((context.call(&"equipment_for", 2) as ItemSlotContainer).to_dictionary(), member_two_before, "recruit preserves follower equipment bytes", failures)
	TestAssertions.equal(_run_inventory(context).to_dictionary(), inventory_before, "recruit preserves inventory bytes", failures)
	var replay := _apply(context, first_create, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(replay.code, ItemTransactionResult.Code.TRANSACTION_REPLAY, "recruit preserves transaction journal", failures)
	var second_item := _issued_item(context, 1, "recruit-after", failures)
	if second_item != null:
		var second_create := ItemTransactionRequest.create("recruit-after-create", String(context.run_player_id), INVENTORY_ID, 1, second_item)
		TestAssertions.equal(_apply(context, second_create, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).code, ItemTransactionResult.Code.OK, "recruit preserves next issuance sequence", failures)
	party.member_added.emit(party.member_by_id(3))
	TestAssertions.equal(_item_state(context).containers().size(), 4, "repeated member-added signal creates no duplicate container", failures)

func _test_exact_inventory_capacities(failures: Array[String]) -> void:
	for test_case: Dictionary in [
		{"columns": 0, "capacity": 0, "suffix": "zero"},
		{"columns": 1, "capacity": 5, "suffix": "one"},
		{"columns": 8, "capacity": 40, "suffix": "eight"},
	]:
		var context := _context(
			StringName("capacity_%s" % test_case["suffix"]),
			"profile-capacity-%s" % test_case["suffix"],
			int(test_case["columns"]),
			1000 + int(test_case["columns"])
		)
		var inventory := _run_inventory(context)
		TestAssertions.truthy(inventory != null, "%s-column context owns a run inventory" % test_case["suffix"], failures)
		if inventory == null:
			continue
		TestAssertions.equal(inventory.container_id, INVENTORY_ID, "%s-column inventory uses the stable ID" % test_case["suffix"], failures)
		TestAssertions.equal(inventory.container_kind, ItemSlotContainer.RUN_INVENTORY, "%s-column inventory has production run kind" % test_case["suffix"], failures)
		TestAssertions.equal(inventory.owner_id, String(context.run_player_id), "%s-column inventory belongs to its context" % test_case["suffix"], failures)
		TestAssertions.equal(inventory.capacity, int(test_case["capacity"]), "%s columns derive exact capacity" % test_case["columns"], failures)

func _test_cross_context_state_and_profile_isolation(failures: Array[String]) -> void:
	var profile_a := _profile("profile-isolated-a", 1, 73)
	var profile_b := _profile("profile-isolated-b", 1, 91)
	profile_a.resumable_run = {"sentinel": {"profile": "a"}}
	profile_b.resumable_run = {"sentinel": {"profile": "b"}}
	var profile_a_before := profile_a.to_dictionary()
	var profile_b_before := profile_b.to_dictionary()
	var context_a := _context_with_profile(&"isolated_a", profile_a, 2101)
	var context_b := _context_with_profile(&"isolated_b", profile_b, 2102)
	var snapshot_a_before := context_a.profile_snapshot.to_dictionary()
	var snapshot_b_before := context_b.profile_snapshot.to_dictionary()
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var shared_transaction_id := "same-id-in-both-contexts"
	var item_a := _issued_item(context_a, 0, "isolation-a", failures)
	var item_b := _issued_item(context_b, 0, "isolation-b", failures)
	if item_a == null or item_b == null:
		return

	var wrong_owner := ItemTransactionRequest.create(shared_transaction_id, String(context_b.run_player_id), INVENTORY_ID, 0, item_b)
	var state_a_before_wrong_owner := _item_state(context_a).to_dictionary()
	var rejected := _apply(context_a, wrong_owner, equipment, foundation)
	TestAssertions.equal(rejected.code, ItemTransactionResult.Code.UNKNOWN_OWNER, "another context owner is rejected before mutation", failures)
	TestAssertions.equal(rejected.next_state, null, "wrong-owner rejection exposes no candidate", failures)
	TestAssertions.equal(_item_state(context_a).to_dictionary(), state_a_before_wrong_owner, "wrong-owner rejection preserves the complete first context", failures)

	var created_a := _apply(context_a, ItemTransactionRequest.create(shared_transaction_id, String(context_a.run_player_id), INVENTORY_ID, 0, item_a), equipment, foundation)
	var created_b := _apply(context_b, ItemTransactionRequest.create(shared_transaction_id, String(context_b.run_player_id), INVENTORY_ID, 0, item_b), equipment, foundation)
	TestAssertions.equal(created_a.code, ItemTransactionResult.Code.OK, "first context commits its transaction ID", failures)
	TestAssertions.equal(created_b.code, ItemTransactionResult.Code.OK, "second context independently commits the same transaction ID", failures)
	TestAssertions.equal(_item_state(context_a).registry().ids(), [item_a.instance_id], "first context owns only its issued item", failures)
	TestAssertions.equal(_item_state(context_b).registry().ids(), [item_b.instance_id], "second context owns only its issued item", failures)

	var exposed_state := _item_state(context_a)
	exposed_state.owner_id = "escaped-owner"
	var exposed_registry := exposed_state.registry()
	var exposed_item := exposed_registry.item(item_a.instance_id)
	exposed_item.instance_id = "escaped-item-id"
	exposed_item.origin["seed"] = "escaped-item-seed"
	var exposed_state_container := exposed_state.container(INVENTORY_ID)
	exposed_state_container.capacity = 0
	var exposed_inventory := _run_inventory(context_a)
	exposed_inventory.capacity = 0
	var exposed_result_state := created_a.next_state
	exposed_result_state.owner_id = "escaped-result-owner"
	var exposed_result_item := exposed_result_state.registry().item(item_a.instance_id)
	exposed_result_item.origin["source"] = "escaped-result-source"
	var exposed_profile := context_a.profile_snapshot
	exposed_profile.next_item_sequence = 999
	exposed_profile.resumable_run["sentinel"]["profile"] = "escaped-profile"

	TestAssertions.equal(_item_state(context_a).owner_id, String(context_a.run_player_id), "item-state accessor cannot escape its owner", failures)
	TestAssertions.equal(_item_state(context_a).registry().item(item_a.instance_id).to_dictionary(), item_a.to_dictionary(), "registry and item projections are defensive", failures)
	TestAssertions.equal(_run_inventory(context_a).capacity, 5, "run-inventory projection cannot change capacity", failures)
	TestAssertions.equal(_item_state(context_b).registry().ids(), [item_b.instance_id], "mutating first-context copies cannot affect the second context", failures)
	TestAssertions.equal(profile_a.to_dictionary(), profile_a_before, "run transactions and escaped copies never mutate source profile A", failures)
	TestAssertions.equal(profile_b.to_dictionary(), profile_b_before, "run transactions never mutate source profile B", failures)
	TestAssertions.equal(context_a.profile_snapshot.to_dictionary(), snapshot_a_before, "first defensive profile snapshot preserves persistent fields", failures)
	TestAssertions.equal(context_b.profile_snapshot.to_dictionary(), snapshot_b_before, "second defensive profile snapshot remains unchanged", failures)

func _test_run_issuance_sequence_and_replay(failures: Array[String]) -> void:
	var profile := _profile("profile-sequence", 1, 44)
	profile.resumable_run = {"existing": "profile-only"}
	var context := _context_with_profile(&"sequence_player", profile, 3303)
	var snapshot_before := context.profile_snapshot.to_dictionary()
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var expected_namespace := "run:%s:%s:%s" % [context.profile_id, context.run_seed, context.run_player_id]
	var sequence_zero := _issued_item(context, 0, "sequence-zero", failures)
	var sequence_one := _issued_item(context, 1, "sequence-one", failures)
	var sequence_two := _issued_item(context, 2, "sequence-two", failures)
	if sequence_zero == null or sequence_one == null or sequence_two == null:
		return
	TestAssertions.equal(sequence_zero.origin["issuer_namespace"], expected_namespace, "run issuance uses the complete context namespace", failures)
	TestAssertions.equal(sequence_zero.origin["sequence"], 0, "run issuance begins at sequence zero", failures)

	var wrong_namespace := sequence_zero.copy()
	wrong_namespace.origin["issuer_namespace"] = "profile:%s" % context.profile_id
	var wrong_namespace_request := ItemTransactionRequest.create("create-sequence-zero", String(context.run_player_id), INVENTORY_ID, 0, wrong_namespace)
	_assert_failure_is_atomic(context, wrong_namespace_request, equipment, foundation, ItemTransactionResult.Code.INVALID_ITEM, "wrong run namespace", failures)

	var wrong_sequence := sequence_one.copy()
	var wrong_sequence_request := ItemTransactionRequest.create("create-sequence-zero", String(context.run_player_id), INVENTORY_ID, 0, wrong_sequence)
	_assert_failure_is_atomic(context, wrong_sequence_request, equipment, foundation, ItemTransactionResult.Code.INVALID_ITEM, "future run sequence", failures)
	var fractional_sequence := sequence_zero.copy()
	fractional_sequence.origin["sequence"] = 0.5
	var fractional_sequence_request := ItemTransactionRequest.create("create-sequence-zero", String(context.run_player_id), INVENTORY_ID, 0, fractional_sequence)
	_assert_failure_is_atomic(context, fractional_sequence_request, equipment, foundation, ItemTransactionResult.Code.INVALID_ITEM, "fractional run sequence", failures)

	var create_zero := ItemTransactionRequest.create("create-sequence-zero", String(context.run_player_id), INVENTORY_ID, 0, sequence_zero)
	var created_zero := _apply(context, create_zero, equipment, foundation)
	TestAssertions.equal(created_zero.code, ItemTransactionResult.Code.OK, "valid sequence zero commits after failed retries", failures)
	TestAssertions.equal(_run_inventory(context).item_id_at(0), sequence_zero.instance_id, "sequence zero occupies its exact slot", failures)

	var replay := _apply(context, create_zero, equipment, foundation)
	TestAssertions.equal(replay.code, ItemTransactionResult.Code.TRANSACTION_REPLAY, "exact create replay is isolated in the context journal", failures)
	TestAssertions.truthy(replay.duplicate, "exact create replay is marked duplicate", failures)
	TestAssertions.equal(_item_state(context).registry().size(), 1, "create replay never duplicates an item", failures)

	var collision := ItemTransactionRequest.create("create-sequence-zero", String(context.run_player_id), INVENTORY_ID, 2, sequence_zero)
	_assert_failure_is_atomic(context, collision, equipment, foundation, ItemTransactionResult.Code.TRANSACTION_COLLISION, "same-context transaction collision", failures)

	var created_one := _apply(
		context,
		ItemTransactionRequest.create("create-sequence-one", String(context.run_player_id), INVENTORY_ID, 1, sequence_one),
		equipment,
		foundation
	)
	TestAssertions.equal(created_one.code, ItemTransactionResult.Code.OK, "successful nonduplicate create advances to sequence one", failures)
	var moved := _apply(
		context,
		ItemTransactionRequest.move("move-does-not-advance", String(context.run_player_id), INVENTORY_ID, 1, sequence_one.instance_id, INVENTORY_ID, 4),
		equipment,
		foundation
	)
	TestAssertions.equal(moved.code, ItemTransactionResult.Code.OK, "production move succeeds inside one run domain", failures)
	var created_two := _apply(
		context,
		ItemTransactionRequest.create("create-sequence-two", String(context.run_player_id), INVENTORY_ID, 2, sequence_two),
		equipment,
		foundation
	)
	TestAssertions.equal(created_two.code, ItemTransactionResult.Code.OK, "non-create operation does not consume issuance sequence two", failures)
	TestAssertions.equal(context.profile_snapshot.to_dictionary(), snapshot_before, "run issuance never changes persistent sequence or resumable-run bytes", failures)

func _test_invalid_inputs_and_operation_policy_are_atomic(failures: Array[String]) -> void:
	var context := _context(&"policy_player", "profile-policy", 1, 4404)
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var item := _issued_item(context, 0, "policy-item", failures)
	var second_item := _issued_item(context, 1, "policy-second-item", failures)
	var third_item := _issued_item(context, 2, "policy-third-item", failures)
	if item == null or second_item == null or third_item == null:
		return
	var valid_create := ItemTransactionRequest.create("policy-create", String(context.run_player_id), INVENTORY_ID, 0, item)
	_assert_failure_is_atomic(context, null, equipment, foundation, ItemTransactionResult.Code.INVALID_REQUEST, "null request", failures)
	_assert_failure_is_atomic(context, valid_create, null, foundation, ItemTransactionResult.Code.INVALID_REQUEST, "missing equipment catalog", failures)
	_assert_failure_is_atomic(context, valid_create, equipment, null, ItemTransactionResult.Code.INVALID_REQUEST, "missing foundation catalog", failures)
	var malformed_item := item.copy()
	malformed_item.origin["issuer_namespace"] = "profile:%s" % context.profile_id
	malformed_item.origin["sequence"] = 7
	var malformed := ItemTransactionRequest.create("policy-create", String(context.run_player_id), INVENTORY_ID, 0, malformed_item)
	malformed.schema_version = 99
	malformed.source_container_id = String(INVENTORY_ID)
	malformed.source_slot = 0
	_assert_failure_is_atomic(
		context,
		malformed,
		equipment,
		foundation,
		ItemTransactionResult.Code.INVALID_REQUEST,
		"malformed request precedes invalid run issuance policy",
		failures
	)
	TestAssertions.equal(_apply(context, valid_create, equipment, foundation).code, ItemTransactionResult.Code.OK, "valid create retries after invalid inputs without consumed sequence or journal", failures)

	var forbidden := ItemTransactionRequest.sandbox_remove("policy-operation-retry", String(context.run_player_id), INVENTORY_ID, 0, item.instance_id)
	_assert_failure_is_atomic(context, forbidden, equipment, foundation, ItemTransactionResult.Code.INVALID_REQUEST, "sandbox-only remove", failures)
	var retry_as_move := ItemTransactionRequest.move("policy-operation-retry", String(context.run_player_id), INVENTORY_ID, 0, item.instance_id, INVENTORY_ID, 3)
	TestAssertions.equal(_apply(context, retry_as_move, equipment, foundation).code, ItemTransactionResult.Code.OK, "rejected sandbox remove is not journaled and its ID can retry as a production move", failures)
	TestAssertions.equal(_run_inventory(context).item_id_at(3), item.instance_id, "run operation whitelist preserves and moves the item", failures)
	var second_create := ItemTransactionRequest.create("policy-create-second", String(context.run_player_id), INVENTORY_ID, 1, second_item)
	TestAssertions.equal(_apply(context, second_create, equipment, foundation).code, ItemTransactionResult.Code.OK, "sandbox rejection and move consume no create sequence", failures)
	var swap := ItemTransactionRequest.swap("policy-swap", String(context.run_player_id), INVENTORY_ID, 3, item.instance_id, INVENTORY_ID, 1)
	TestAssertions.equal(_apply(context, swap, equipment, foundation).code, ItemTransactionResult.Code.OK, "production swap is whitelisted", failures)
	TestAssertions.equal(_run_inventory(context).item_id_at(3), second_item.instance_id, "swap puts the destination item in the exact source slot", failures)
	TestAssertions.equal(_run_inventory(context).item_id_at(1), item.instance_id, "swap puts the source item in the exact destination slot", failures)
	var third_create := ItemTransactionRequest.create("policy-create-third", String(context.run_player_id), INVENTORY_ID, 2, third_item)
	TestAssertions.equal(_apply(context, third_create, equipment, foundation).code, ItemTransactionResult.Code.OK, "production swap consumes no create sequence", failures)

func _assert_failure_is_atomic(
	context: PlayerRunContext,
	request: ItemTransactionRequest,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	expected_code: int,
	label: String,
	failures: Array[String]
) -> void:
	var before := _item_state(context).to_dictionary()
	var result := _apply(context, request, equipment, foundation)
	TestAssertions.equal(result.code, expected_code, "%s has stable code" % label, failures)
	TestAssertions.equal(result.next_state, null, "%s exposes no candidate" % label, failures)
	TestAssertions.truthy(not result.duplicate, "%s is not a duplicate success" % label, failures)
	TestAssertions.equal(_item_state(context).to_dictionary(), before, "%s leaves context ownership byte-equivalent" % label, failures)

func _context(run_player_id: StringName, profile_id: String, columns: int, seed: int) -> PlayerRunContext:
	return _context_with_profile(run_player_id, _profile(profile_id, columns, 0), seed)

func _context_with_profile(run_player_id: StringName, profile: ProfileState, seed: int) -> PlayerRunContext:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var context := PlayerRunContext.new()
	var errors := context.configure(run_player_id, _parties.size() - 1, profile, seed, party, 100)
	assert(errors.is_empty())
	return context

func _profile(profile_id: String, columns: int, persistent_sequence: int) -> ProfileState:
	var profile := ProfileState.new_profile(profile_id, "Run Item Owner", 1000)
	profile.inventory_columns = columns
	profile.next_item_sequence = persistent_sequence
	return profile

func _issued_item(context: PlayerRunContext, sequence: int, source: String, failures: Array[String]) -> ItemInstance:
	var issuer_namespace := "run:%s:%s:%s" % [context.profile_id, context.run_seed, context.run_player_id]
	var issued := ItemInstanceIssuer.issue(
		issuer_namespace,
		sequence,
		source,
		context.run_seed + sequence,
		{
			"affixes": [],
			"base_definition_id": "forge_vanguard_sword",
			"item_level": 28,
			"rarity_id": "common",
		},
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	TestAssertions.truthy(issued.ok(), "%s fixture item issues successfully" % source, failures)
	if not issued.ok():
		failures.append("%s fixture issuance error: %s" % [source, issued.error])
	return issued.item

func _item_state(context: PlayerRunContext) -> ItemOwnershipState:
	return context.call(&"item_state") as ItemOwnershipState

func _run_inventory(context: PlayerRunContext) -> ItemSlotContainer:
	return context.call(&"run_inventory") as ItemSlotContainer

func _apply(
	context: PlayerRunContext,
	request: ItemTransactionRequest,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> ItemTransactionResult:
	return context.call(&"apply_item_transaction", request, equipment, foundation) as ItemTransactionResult
