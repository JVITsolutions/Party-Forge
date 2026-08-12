extends RefCounted

const INVENTORY_ID := &"run-inventory"
const GROUND_ID := &"run-ground-items"

var _parties: Array[PartyManager] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	var probe := PlayerRunContext.new()
	TestAssertions.truthy(probe.has_method(&"item_state"), "run context exposes defensive item state", failures)
	TestAssertions.truthy(probe.has_method(&"run_inventory"), "run context exposes its fixed inventory projection", failures)
	TestAssertions.truthy(probe.has_method(&"ground_items"), "run context exposes its defensive ground-item projection", failures)
	TestAssertions.truthy(probe.has_method(&"issue_ground_item"), "run context exposes authoritative ground issuance", failures)
	TestAssertions.truthy(probe.has_method(&"collect_ground_item"), "run context exposes authoritative ground collection", failures)
	TestAssertions.truthy(probe.has_method(&"apply_item_transaction"), "run context exposes its production item transaction boundary", failures)
	if not failures.is_empty():
		return failures
	_test_exact_inventory_capacities(failures)
	_test_cross_context_state_and_profile_isolation(failures)
	_test_run_issuance_sequence_and_replay(failures)
	_test_ground_item_issue_collection_and_failures(failures)
	_test_ground_storage_failure_preserves_sequence(failures)
	_test_resumable_attribute_and_typed_damage_records(failures)
	_test_invalid_inputs_and_operation_policy_are_atomic(failures)
	_test_generic_transactions_cannot_cross_equipment_boundary(failures)
	_test_recruit_adds_equipment_without_resetting_item_state(failures)
	for party: PartyManager in _parties:
		party.free()
	_parties.clear()
	return failures

func _test_ground_item_issue_collection_and_failures(failures: Array[String]) -> void:
	var context := _context(&"ground_owner", "profile-ground-owner", 1, 8101)
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var ground := _ground_items(context)
	TestAssertions.truthy(ground != null, "fresh run owns a ground container", failures)
	if ground == null:
		return
	TestAssertions.equal(ground.container_id, GROUND_ID, "ground container ID is stable", failures)
	TestAssertions.equal(ground.container_kind, &"run_ground_items", "ground container kind is stable", failures)
	TestAssertions.equal(ground.owner_id, String(context.run_player_id), "ground container belongs to the run owner", failures)
	TestAssertions.equal(ground.capacity, 2048, "ground container reserves 2048 outstanding slots", failures)
	TestAssertions.equal(ground.occupied_slots(), [], "fresh run ground starts empty", failures)
	ground.capacity = 0
	TestAssertions.equal(_ground_items(context).capacity, 2048, "ground projection is defensive", failures)

	var invalid_request := _generation_request(0)
	invalid_request.item_level = 0
	var failed_generation := context.call(&"issue_ground_item", invalid_request, equipment, foundation) as ItemGenerationResult
	TestAssertions.truthy(failed_generation != null and not failed_generation.ok(), "invalid ground generation fails", failures)
	if failed_generation != null and failed_generation.failure != null:
		TestAssertions.equal(failed_generation.failure.stage, &"request", "generation failure preserves generator stage", failures)
	TestAssertions.equal(_ground_items(context).occupied_slots(), [], "failed generation creates no ground reference", failures)

	var request := _generation_request(0)
	var first := context.call(&"issue_ground_item", request, equipment, foundation) as ItemGenerationResult
	TestAssertions.truthy(first != null and first.ok(), "first ground item issues", failures)
	if first == null or not first.ok():
		return
	TestAssertions.equal(first.item.origin["sequence"], 0, "failed generation consumes no run issuance sequence", failures)
	TestAssertions.equal(_ground_items(context).item_id_at(0), first.item.instance_id, "first ground item occupies the first slot", failures)
	_assert_valid_item_state(context, "first ground issue", failures)

	var second := context.call(&"issue_ground_item", request.copy_with_sequence(2), equipment, foundation) as ItemGenerationResult
	TestAssertions.truthy(second != null and second.ok(), "second outstanding ground item issues", failures)
	if second == null or not second.ok():
		return
	TestAssertions.equal(second.item.origin["sequence"], 1, "successful storage consumes exactly one run issuance sequence", failures)
	TestAssertions.truthy(first.item.instance_id != second.item.instance_id, "outstanding drops reserve unique IDs", failures)
	TestAssertions.equal(_ground_items(context).item_id_at(1), second.item.instance_id, "second outstanding item uses the next ground slot", failures)
	_assert_valid_item_state(context, "second ground issue", failures)

	var wrong_owner_request := ItemTransactionRequest.move(
		"pickup-wrong-owner",
		"another-run-owner",
		GROUND_ID,
		1,
		second.item.instance_id,
		INVENTORY_ID,
		0
	)
	_assert_failure_is_atomic(context, wrong_owner_request, equipment, foundation, ItemTransactionResult.Code.UNKNOWN_OWNER, "wrong-owner ground pickup", failures)
	var before_unknown := _ownership_bytes(context)
	var unknown := context.call(&"collect_ground_item", "unknown-ground-item", "pickup-unknown", equipment, foundation) as ItemTransactionResult
	TestAssertions.equal(unknown.code, ItemTransactionResult.Code.SOURCE_MISMATCH, "unknown ground item fails deterministically", failures)
	TestAssertions.equal(_ownership_bytes(context), before_unknown, "unknown ground item preserves ownership", failures)

	var collected := context.call(&"collect_ground_item", first.item.instance_id, "pickup-001", equipment, foundation) as ItemTransactionResult
	TestAssertions.truthy(collected.ok(), "ground item moves into inventory", failures)
	TestAssertions.equal(_ground_items(context).item_id_at(0), "", "ground slot clears", failures)
	TestAssertions.equal(_run_inventory(context).item_id_at(0), first.item.instance_id, "first empty inventory slot receives the authoritative item", failures)
	TestAssertions.equal(_item_state(context).registry().size(), 2, "pickup moves rather than copies the item record", failures)
	_assert_valid_item_state(context, "ground collection", failures)
	var collected_bytes := _ownership_bytes(context)
	var replay := context.call(&"collect_ground_item", first.item.instance_id, "pickup-001", equipment, foundation) as ItemTransactionResult
	TestAssertions.equal(replay.code, ItemTransactionResult.Code.TRANSACTION_REPLAY, "exact pickup replay is idempotent", failures)
	TestAssertions.truthy(replay.duplicate, "exact pickup replay is marked duplicate", failures)
	TestAssertions.equal(_ownership_bytes(context), collected_bytes, "pickup replay preserves current ownership", failures)
	var collision := context.call(&"collect_ground_item", second.item.instance_id, "pickup-001", equipment, foundation) as ItemTransactionResult
	TestAssertions.equal(collision.code, ItemTransactionResult.Code.TRANSACTION_COLLISION, "pickup transaction ID collision is rejected", failures)
	TestAssertions.equal(_ownership_bytes(context), collected_bytes, "pickup collision preserves ownership", failures)

	var full_inventory := _context(&"full_inventory_owner", "profile-full-inventory", 0, 8102)
	var grounded := full_inventory.call(&"issue_ground_item", _generation_request(0), equipment, foundation) as ItemGenerationResult
	TestAssertions.truthy(grounded != null and grounded.ok(), "zero-capacity inventory can still own a ground item", failures)
	if grounded != null and grounded.ok():
		var full_before := _ownership_bytes(full_inventory)
		var rejected := full_inventory.call(&"collect_ground_item", grounded.item.instance_id, "pickup-full", equipment, foundation) as ItemTransactionResult
		TestAssertions.equal(rejected.code, ItemTransactionResult.Code.DESTINATION_OCCUPIED, "full inventory rejects pickup", failures)
		TestAssertions.equal(_ownership_bytes(full_inventory), full_before, "full inventory preserves the ground item exactly", failures)
		TestAssertions.equal(_ground_items(full_inventory).item_id_at(0), grounded.item.instance_id, "full inventory leaves authoritative ground placement", failures)
		_assert_valid_item_state(full_inventory, "full inventory rejection", failures)

func _test_ground_storage_failure_preserves_sequence(failures: Array[String]) -> void:
	var fixture := _full_ground_context(&"full_ground_owner", "profile-full-ground", 8201, failures)
	var context := fixture.get("context") as PlayerRunContext
	if context == null:
		return
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var before := _ownership_bytes(context)
	var failed := context.call(&"issue_ground_item", _generation_request(0), equipment, foundation) as ItemGenerationResult
	TestAssertions.truthy(failed != null and not failed.ok(), "full ground storage rejects issuance", failures)
	if failed != null and failed.failure != null:
		TestAssertions.equal(failed.failure.stage, &"ground_storage", "storage failure exposes ground_storage stage", failures)
	TestAssertions.equal(_ownership_bytes(context), before, "failed ground storage preserves ownership", failures)
	var displaced_id := _ground_items(context).item_id_at(0)
	var collected := context.call(&"collect_ground_item", displaced_id, "make-ground-space", equipment, foundation) as ItemTransactionResult
	TestAssertions.truthy(collected.ok(), "fixture can free one ground slot", failures)
	var retry := context.call(&"issue_ground_item", _generation_request(0), equipment, foundation) as ItemGenerationResult
	TestAssertions.truthy(retry != null and retry.ok(), "ground issuance retries after storage space opens", failures)
	if retry != null and retry.ok():
		TestAssertions.equal(retry.item.origin["sequence"], 2048, "failed storage consumes no run issuance sequence", failures)
		TestAssertions.equal(_ground_items(context).item_id_at(0), retry.item.instance_id, "retry resolves the first ground slot at call time", failures)
	_assert_valid_item_state(context, "ground storage retry", failures)

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
	TestAssertions.equal(_item_state(context).containers().size(), 5, "repeated member-added signal creates no duplicate container", failures)

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


func _test_resumable_attribute_and_typed_damage_records(failures: Array[String]) -> void:
	var context := _context(&"task9_codec_player", "task9-codec-profile", 1, 9909)
	var attribute_item := _issued_item_data(context, 0, "task9-attribute", {
		"affixes": [{
			"definition_id": "stout",
			"affix_kind": "prefix",
			"tier": 1,
			"rolls": [{
				"stat_id": "constitution",
				"operation": StatModifier.Operation.FLAT,
				"value": 3.0,
				"required_tags": [],
			}],
		}],
		"base_definition_id": "emberweave_circlet",
		"base_damage_components": [],
		"item_level": 1,
		"rarity_id": "common",
	}, failures)
	var typed_damage_item := _issued_item_data(context, 1, "task9-fire", {
		"affixes": [{
			"definition_id": "of_embers",
			"affix_kind": "suffix",
			"tier": 1,
			"rolls": [{
				"stat_id": "fire_damage",
				"operation": StatModifier.Operation.INCREASED,
				"value": 0.1,
				"required_tags": [],
			}],
		}],
		"base_definition_id": "emberweave_wand",
		"base_damage_components": [],
		"item_level": 1,
		"rarity_id": "common",
	}, failures)
	if attribute_item == null or typed_damage_item == null:
		return
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var attribute_create := ItemTransactionRequest.create(
		"task9-attribute-create",
		String(context.run_player_id),
		INVENTORY_ID,
		0,
		attribute_item,
	)
	var damage_create := ItemTransactionRequest.create(
		"task9-fire-create",
		String(context.run_player_id),
		INVENTORY_ID,
		1,
		typed_damage_item,
	)
	TestAssertions.equal(_apply(context, attribute_create, equipment, foundation).code, ItemTransactionResult.Code.OK, "Task 9 attribute item enters run ownership", failures)
	TestAssertions.equal(_apply(context, damage_create, equipment, foundation).code, ItemTransactionResult.Code.OK, "Task 9 typed-damage item enters run ownership", failures)
	var state := _item_state(context)
	var state_bytes := JSON.stringify(state.to_dictionary())
	var item_bytes: Dictionary = {}
	item_bytes[attribute_item.instance_id] = JSON.stringify(attribute_item.to_dictionary())
	item_bytes[typed_damage_item.instance_id] = JSON.stringify(typed_damage_item.to_dictionary())
	var bootstrap := RunItemBootstrap.create(&"task9-codec-run", context.run_seed, context.run_player_id, 1, state)
	var encoded := ResumableRunItemCodec.encode(bootstrap)
	TestAssertions.equal(JSON.stringify(encoded["item_state"]), state_bytes, "resumable encoding preserves exact item ownership bytes", failures)
	var decoded := ResumableRunItemCodec.decode(encoded, equipment, foundation)
	TestAssertions.truthy(decoded != null, "resumable attribute and typed-damage state decodes", failures)
	if decoded == null:
		return
	var decoded_state := decoded.item_state()
	TestAssertions.equal(JSON.stringify(decoded_state.to_dictionary()), state_bytes, "resumable item ownership round trips byte-equivalently", failures)
	var decoded_registry := decoded_state.registry()
	for item_id: Variant in item_bytes:
		TestAssertions.equal(
			JSON.stringify(decoded_registry.item(String(item_id)).to_dictionary()),
			item_bytes[item_id],
			"resumable round trip preserves item %s byte-equivalently" % item_id,
			failures,
		)
	TestAssertions.equal(JSON.stringify(attribute_item.to_dictionary()), item_bytes[attribute_item.instance_id], "resumable codec leaves caller attribute item immutable", failures)
	TestAssertions.equal(JSON.stringify(typed_damage_item.to_dictionary()), item_bytes[typed_damage_item.instance_id], "resumable codec leaves caller typed-damage item immutable", failures)


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

func _test_generic_transactions_cannot_cross_equipment_boundary(failures: Array[String]) -> void:
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var main_hand_slot := EquipmentSlotIndex.index_for(&"main_hand")
	var member_one_equipment := &"run-equipment-001"
	var member_two_equipment := &"run-equipment-002"

	var create_context := _context(&"equipment_boundary_create", "profile-equipment-boundary-create", 2, 4501)
	var direct_item := _issued_item(create_context, 0, "equipment-boundary-direct-create", failures)
	if direct_item != null:
		var direct_create := ItemTransactionRequest.create(
			"equipment-boundary-create",
			String(create_context.run_player_id),
			member_one_equipment,
			main_hand_slot,
			direct_item
		)
		_assert_equipment_transaction_rejected(create_context, direct_create, equipment, foundation, "direct create to equipment", failures)
		var valid_retry := ItemTransactionRequest.create(
			"equipment-boundary-create",
			String(create_context.run_player_id),
			INVENTORY_ID,
			0,
			direct_item
		)
		TestAssertions.equal(_apply(create_context, valid_retry, equipment, foundation).code, ItemTransactionResult.Code.OK, "rejected equipment create leaves its transaction ID and issuance sequence available", failures)
		var after_valid_create := _ownership_bytes(create_context)
		var replay := _apply(create_context, valid_retry, equipment, foundation)
		TestAssertions.equal(replay.code, ItemTransactionResult.Code.TRANSACTION_REPLAY, "valid inventory retry retains ordinary replay behavior", failures)
		TestAssertions.truthy(replay.duplicate, "valid inventory retry replay is marked duplicate", failures)
		TestAssertions.equal(_ownership_bytes(create_context), after_valid_create, "valid inventory replay preserves ownership bytes", failures)
		var next_item := _issued_item(create_context, 1, "equipment-boundary-next-sequence", failures)
		if next_item != null:
			var next_create := ItemTransactionRequest.create("equipment-boundary-next-create", String(create_context.run_player_id), INVENTORY_ID, 1, next_item)
			TestAssertions.equal(_apply(create_context, next_create, equipment, foundation).code, ItemTransactionResult.Code.OK, "rejected equipment create does not advance the next issuance sequence", failures)

	var inventory_to_equipment := _context(&"equipment_boundary_in", "profile-equipment-boundary-in", 2, 4502)
	var inbound_item := _issued_item(inventory_to_equipment, 0, "equipment-boundary-inbound", failures)
	if inbound_item != null:
		TestAssertions.equal(_apply(inventory_to_equipment, ItemTransactionRequest.create("equipment-boundary-inbound-create", String(inventory_to_equipment.run_player_id), INVENTORY_ID, 0, inbound_item), equipment, foundation).code, ItemTransactionResult.Code.OK, "inventory-to-equipment fixture enters inventory", failures)
		var move_into_equipment := ItemTransactionRequest.move("equipment-boundary-inbound-move", String(inventory_to_equipment.run_player_id), INVENTORY_ID, 0, inbound_item.instance_id, member_one_equipment, main_hand_slot)
		_assert_equipment_transaction_rejected(inventory_to_equipment, move_into_equipment, equipment, foundation, "inventory-to-equipment move", failures)

	var equipment_to_inventory := _context(&"equipment_boundary_out", "profile-equipment-boundary-out", 2, 4503)
	var outbound_item := _issued_item(equipment_to_inventory, 0, "equipment-boundary-outbound", failures)
	if outbound_item != null:
		TestAssertions.equal(_apply(equipment_to_inventory, ItemTransactionRequest.create("equipment-boundary-outbound-create", String(equipment_to_inventory.run_player_id), INVENTORY_ID, 0, outbound_item), equipment, foundation).code, ItemTransactionResult.Code.OK, "equipment-to-inventory fixture enters inventory", failures)
		TestAssertions.truthy(equipment_to_inventory.assign_equipment(1, outbound_item.instance_id, &"main_hand", equipment, foundation).ok(), "equipment-to-inventory fixture equips through the assignment boundary", failures)
		var move_out_of_equipment := ItemTransactionRequest.move("equipment-boundary-outbound-move", String(equipment_to_inventory.run_player_id), member_one_equipment, main_hand_slot, outbound_item.instance_id, INVENTORY_ID, 1)
		_assert_equipment_transaction_rejected(equipment_to_inventory, move_out_of_equipment, equipment, foundation, "equipment-to-inventory move", failures)

	var occupied_swap_context := _context(&"equipment_boundary_swap", "profile-equipment-boundary-swap", 2, 4504)
	var equipped_swap_item := _issued_item(occupied_swap_context, 0, "equipment-boundary-equipped-swap", failures)
	var inventory_swap_item := _issued_item(occupied_swap_context, 1, "equipment-boundary-inventory-swap", failures)
	if equipped_swap_item != null and inventory_swap_item != null:
		TestAssertions.equal(_apply(occupied_swap_context, ItemTransactionRequest.create("equipment-boundary-equipped-swap-create", String(occupied_swap_context.run_player_id), INVENTORY_ID, 0, equipped_swap_item), equipment, foundation).code, ItemTransactionResult.Code.OK, "occupied equipment swap fixture creates equipped item", failures)
		TestAssertions.equal(_apply(occupied_swap_context, ItemTransactionRequest.create("equipment-boundary-inventory-swap-create", String(occupied_swap_context.run_player_id), INVENTORY_ID, 1, inventory_swap_item), equipment, foundation).code, ItemTransactionResult.Code.OK, "occupied equipment swap fixture creates inventory item", failures)
		TestAssertions.truthy(occupied_swap_context.assign_equipment(1, equipped_swap_item.instance_id, &"main_hand", equipment, foundation).ok(), "occupied equipment swap fixture equips through the assignment boundary", failures)
		var occupied_equipment_swap := ItemTransactionRequest.swap("equipment-boundary-occupied-swap", String(occupied_swap_context.run_player_id), INVENTORY_ID, 1, inventory_swap_item.instance_id, member_one_equipment, main_hand_slot)
		_assert_equipment_transaction_rejected(occupied_swap_context, occupied_equipment_swap, equipment, foundation, "occupied equipment swap", failures)

	var cross_member_move_context := _two_member_context(&"equipment_boundary_member_move", "profile-equipment-boundary-member-move", 2, 4505)
	var cross_move_item := _issued_item(cross_member_move_context, 0, "equipment-boundary-member-move", failures)
	if cross_move_item != null:
		TestAssertions.equal(_apply(cross_member_move_context, ItemTransactionRequest.create("equipment-boundary-member-move-create", String(cross_member_move_context.run_player_id), INVENTORY_ID, 0, cross_move_item), equipment, foundation).code, ItemTransactionResult.Code.OK, "cross-member move fixture creates item", failures)
		TestAssertions.truthy(cross_member_move_context.assign_equipment(1, cross_move_item.instance_id, &"main_hand", equipment, foundation).ok(), "cross-member move fixture equips through the assignment boundary", failures)
		var cross_member_move := ItemTransactionRequest.move("equipment-boundary-member-move", String(cross_member_move_context.run_player_id), member_one_equipment, main_hand_slot, cross_move_item.instance_id, member_two_equipment, main_hand_slot)
		_assert_equipment_transaction_rejected(cross_member_move_context, cross_member_move, equipment, foundation, "cross-member equipment move", failures)

	var cross_member_swap_context := _two_member_context(&"equipment_boundary_member_swap", "profile-equipment-boundary-member-swap", 2, 4506)
	var member_one_item := _issued_item(cross_member_swap_context, 0, "equipment-boundary-member-one", failures)
	var member_two_item := _issued_item(cross_member_swap_context, 1, "equipment-boundary-member-two", failures)
	if member_one_item != null and member_two_item != null:
		TestAssertions.equal(_apply(cross_member_swap_context, ItemTransactionRequest.create("equipment-boundary-member-one-create", String(cross_member_swap_context.run_player_id), INVENTORY_ID, 0, member_one_item), equipment, foundation).code, ItemTransactionResult.Code.OK, "cross-member swap fixture creates member-one item", failures)
		TestAssertions.equal(_apply(cross_member_swap_context, ItemTransactionRequest.create("equipment-boundary-member-two-create", String(cross_member_swap_context.run_player_id), INVENTORY_ID, 1, member_two_item), equipment, foundation).code, ItemTransactionResult.Code.OK, "cross-member swap fixture creates member-two item", failures)
		TestAssertions.truthy(cross_member_swap_context.assign_equipment(1, member_one_item.instance_id, &"main_hand", equipment, foundation).ok(), "cross-member swap fixture equips member one through the assignment boundary", failures)
		TestAssertions.truthy(cross_member_swap_context.assign_equipment(2, member_two_item.instance_id, &"main_hand", equipment, foundation).ok(), "cross-member swap fixture equips member two through the assignment boundary", failures)
		var cross_member_swap := ItemTransactionRequest.swap("equipment-boundary-member-swap", String(cross_member_swap_context.run_player_id), member_one_equipment, main_hand_slot, member_one_item.instance_id, member_two_equipment, main_hand_slot)
		_assert_equipment_transaction_rejected(cross_member_swap_context, cross_member_swap, equipment, foundation, "cross-member equipment swap", failures)

func _assert_equipment_transaction_rejected(
	context: PlayerRunContext,
	request: ItemTransactionRequest,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	label: String,
	failures: Array[String]
) -> void:
	var before := _ownership_bytes(context)
	var result := _apply(context, request, equipment, foundation)
	TestAssertions.equal(result.code, ItemTransactionResult.Code.INVALID_REQUEST, "%s is rejected at the ordinary transaction boundary" % label, failures)
	TestAssertions.equal(result.next_state, null, "%s exposes no candidate state" % label, failures)
	TestAssertions.truthy(not result.duplicate, "%s is not a duplicate success" % label, failures)
	TestAssertions.equal(_ownership_bytes(context), before, "%s preserves ownership bytes" % label, failures)
	var retry := _apply(context, request, equipment, foundation)
	TestAssertions.equal(retry.code, ItemTransactionResult.Code.INVALID_REQUEST, "%s is not journaled into replay" % label, failures)
	TestAssertions.truthy(not retry.duplicate, "%s retry remains a nonduplicate rejection" % label, failures)
	TestAssertions.equal(_ownership_bytes(context), before, "%s retry preserves ownership bytes" % label, failures)

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

func _two_member_context(run_player_id: StringName, profile_id: String, columns: int, seed: int) -> PlayerRunContext:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	assert(party.recruit(catalog.class_by_id(&"fighter")))
	_parties.append(party)
	var context := PlayerRunContext.new()
	var errors := context.configure(run_player_id, _parties.size() - 1, _profile(profile_id, columns, 0), seed, party, 100)
	assert(errors.is_empty())
	return context

func _profile(profile_id: String, columns: int, persistent_sequence: int) -> ProfileState:
	var profile := ProfileState.new_profile(profile_id, "Run Item Owner", 1000)
	profile.inventory_columns = columns
	profile.next_item_sequence = persistent_sequence
	return profile

func _generation_request(sequence: int) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(778899, sequence, 28, &"ordinary_enemy", &"ordinary_drop", [&"common"] as Array[StringName])
	request.forced_base_id = &"forge_vanguard_sword"
	request.forced_rarity_id = &"common"
	return request

func _full_ground_context(run_player_id: StringName, profile_id: String, seed: int, failures: Array[String]) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var items: Array[ItemInstance] = []
	var slots: Dictionary = {}
	var issuer_namespace := "run:%s:%s:%s" % [profile_id, seed, run_player_id]
	for sequence: int in 2048:
		var issued := ItemInstanceIssuer.issue(
			issuer_namespace,
			sequence,
			"full_ground_fixture",
			seed + sequence,
			{
				"affixes": [],
				"base_definition_id": "forge_vanguard_sword",
				"base_damage_components": [],
				"item_level": 28,
				"rarity_id": "common",
			},
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG
		)
		if not issued.ok():
			failures.append("full ground fixture issuance %d failed: %s" % [sequence, issued.error])
			return {}
		items.append(issued.item)
		slots[sequence] = issued.item.instance_id
	var state := ItemOwnershipState.create(String(run_player_id), ItemRegistry.new(items), [
		ItemSlotContainer.create(INVENTORY_ID, ItemSlotContainer.RUN_INVENTORY, String(run_player_id), 5),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(run_player_id), EquipmentSlotIndex.capacity()),
		ItemSlotContainer.create(GROUND_ID, &"run_ground_items", String(run_player_id), 2048, slots),
	])
	var bootstrap := RunItemBootstrap.create(&"full-ground-run", seed, run_player_id, 1, state)
	var profile := _profile(profile_id, 1, 0)
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	var errors := context.configure(run_player_id, _parties.size() - 1, profile, seed, party, 100, bootstrap)
	TestAssertions.equal(errors, PackedStringArray(), "full ground context configures", failures)
	return {"context": context if errors.is_empty() else null}

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
			"base_damage_components": [],
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


func _issued_item_data(
	context: PlayerRunContext,
	sequence: int,
	source: String,
	item_data: Dictionary,
	failures: Array[String],
) -> ItemInstance:
	var issuer_namespace := "run:%s:%s:%s" % [context.profile_id, context.run_seed, context.run_player_id]
	var issued := ItemInstanceIssuer.issue(
		issuer_namespace,
		sequence,
		source,
		context.run_seed + sequence,
		item_data,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(issued.ok(), "%s Task 9 item issues successfully" % source, failures)
	if not issued.ok():
		failures.append("%s Task 9 issuance error: %s" % [source, issued.error])
	return issued.item

func _item_state(context: PlayerRunContext) -> ItemOwnershipState:
	return context.call(&"item_state") as ItemOwnershipState

func _run_inventory(context: PlayerRunContext) -> ItemSlotContainer:
	return context.call(&"run_inventory") as ItemSlotContainer

func _ground_items(context: PlayerRunContext) -> ItemSlotContainer:
	return context.call(&"ground_items") as ItemSlotContainer

func _assert_valid_item_state(context: PlayerRunContext, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(
		_item_state(context).validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG),
		"",
		"%s leaves strict item ownership valid" % label,
		failures
	)

func _ownership_bytes(context: PlayerRunContext) -> String:
	return JSON.stringify(_item_state(context).to_dictionary())

func _apply(
	context: PlayerRunContext,
	request: ItemTransactionRequest,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> ItemTransactionResult:
	return context.call(&"apply_item_transaction", request, equipment, foundation) as ItemTransactionResult
