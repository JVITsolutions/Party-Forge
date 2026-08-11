extends RefCounted

const RECORD_PATH := "res://scripts/loot/ground_item_record.gd"
const REGISTRY_PATH := "res://scripts/loot/ground_item_registry.gd"
const SERVICE_PATH := "res://scripts/loot/ground_loot_ownership_service.gd"
const INVENTORY_ID := &"run-inventory"
const GROUND_ID := &"run-ground-items"

var _record_script: Script
var _registry_script: Script
var _service_script: Script
var _parties: Array[PartyManager] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	_load_contracts(failures)
	if _record_script == null or _registry_script == null or _service_script == null:
		return failures
	_test_success_and_session_only_clear(failures)
	_test_generation_and_registry_failures_are_atomic(failures)
	_test_ground_and_registry_capacity_preflight(failures)
	for party: PartyManager in _parties:
		party.free()
	_parties.clear()
	return failures

func _load_contracts(failures: Array[String]) -> void:
	for path: String in [RECORD_PATH, REGISTRY_PATH, SERVICE_PATH]:
		TestAssertions.truthy(ResourceLoader.exists(path), "%s exists" % path.get_file(), failures)
	if ResourceLoader.exists(RECORD_PATH):
		_record_script = load(RECORD_PATH) as Script
	if ResourceLoader.exists(REGISTRY_PATH):
		_registry_script = load(REGISTRY_PATH) as Script
	if ResourceLoader.exists(SERVICE_PATH):
		_service_script = load(SERVICE_PATH) as Script

func _test_success_and_session_only_clear(failures: Array[String]) -> void:
	var context := _context(&"owner_success", "profile-success", 0, 9101)
	var registry := _registry_script.new() as RefCounted
	var result := _create_drop(context, _request(31), _identity(context, &"drop:owner_success:31", Vector3(3.0, 0.0, 4.0)), registry)
	TestAssertions.truthy(result != null and bool(result.call(&"ok")), "valid ownership request commits one generated ground item", failures)
	if result == null or not bool(result.call(&"ok")):
		return
	var record := result.get(&"record") as RefCounted
	var generated := result.get(&"generated") as ItemGenerationResult
	TestAssertions.equal(record.get(&"item_id"), generated.item.instance_id, "record references the production-generated item", failures)
	TestAssertions.equal(record.get(&"ground_slot"), 0, "record captures the authoritative ground slot", failures)
	TestAssertions.equal(record.get(&"rarity_id"), generated.item.rarity_id, "record carries generated rarity", failures)
	TestAssertions.equal((context.item_state().registry()).size(), 1, "successful ownership creates exactly one authoritative item", failures)
	TestAssertions.equal(context.ground_items().item_id_at(0), generated.item.instance_id, "successful ownership places the item in the owner ground container", failures)
	registry.call(&"clear")
	TestAssertions.equal((registry.call(&"all_records") as Array).size(), 0, "registry clear removes session ground records", failures)
	TestAssertions.equal(context.item_state().registry().size(), 1, "registry clear never deletes authoritative run ownership", failures)
	TestAssertions.equal(context.ground_items().item_id_at(0), generated.item.instance_id, "registry clear never moves or deletes the ground item", failures)

func _test_generation_and_registry_failures_are_atomic(failures: Array[String]) -> void:
	var invalid_context := _context(&"owner_invalid", "profile-invalid", 1, 9102)
	var invalid_registry := _registry_script.new() as RefCounted
	var invalid_request := _request(32)
	invalid_request.item_level = 0
	var invalid_before := invalid_context.item_state().to_dictionary()
	var invalid_result := _create_drop(invalid_context, invalid_request, _identity(invalid_context, &"drop:owner_invalid:32", Vector3.ZERO), invalid_registry)
	TestAssertions.truthy(invalid_result != null and not bool(invalid_result.call(&"ok")), "generation failure is explicit", failures)
	TestAssertions.equal(invalid_context.item_state().to_dictionary(), invalid_before, "generation failure preserves context ownership", failures)
	TestAssertions.equal((invalid_registry.call(&"all_records") as Array).size(), 0, "generation failure creates no ground record", failures)

	var duplicate_context := _context(&"owner_duplicate", "profile-duplicate", 2, 9103)
	var duplicate_registry := _registry_script.new() as RefCounted
	duplicate_registry.call(&"add", _record(&"drop:owner_duplicate:33", "reserved-item", &"owner_duplicate", 0))
	var duplicate_before := duplicate_context.item_state().to_dictionary()
	var duplicate_result := _create_drop(duplicate_context, _request(33), _identity(duplicate_context, &"drop:owner_duplicate:33", Vector3.ZERO), duplicate_registry)
	TestAssertions.truthy(duplicate_result != null and not bool(duplicate_result.call(&"ok")), "duplicate drop preflight fails", failures)
	TestAssertions.equal(duplicate_context.item_state().to_dictionary(), duplicate_before, "duplicate drop preflight creates no ground item", failures)

	var item_context := _context(&"owner_item_collision", "profile-item-collision", 3, 9104)
	var item_registry := _registry_script.new() as RefCounted
	var predicted_item_id := _predicted_item_id(item_context, 0)
	item_registry.call(&"add", _record(&"drop:reserved:1", predicted_item_id, &"reserved", 0))
	var item_before := item_context.item_state().to_dictionary()
	var item_result := _create_drop(item_context, _request(34), _identity(item_context, &"drop:owner_item_collision:34", Vector3.ZERO), item_registry)
	TestAssertions.truthy(item_result != null and not bool(item_result.call(&"ok")), "predicted issuer item collision fails before generation", failures)
	TestAssertions.equal(item_context.item_state().to_dictionary(), item_before, "item ID preflight failure preserves context ownership", failures)

func _test_ground_and_registry_capacity_preflight(failures: Array[String]) -> void:
	var capacity_context := _context(&"owner_registry_full", "profile-registry-full", 0, 9105)
	var zero_capacity_registry := _registry_script.new(0) as RefCounted
	var capacity_before := capacity_context.item_state().to_dictionary()
	var capacity_result := _create_drop(capacity_context, _request(35), _identity(capacity_context, &"drop:owner_registry_full:35", Vector3.ZERO), zero_capacity_registry)
	TestAssertions.truthy(capacity_result != null and not bool(capacity_result.call(&"ok")), "registry capacity failure is explicit", failures)
	TestAssertions.equal(capacity_context.item_state().to_dictionary(), capacity_before, "registry capacity is preflighted before generation", failures)

	var full_fixture := _full_ground_context(&"owner_ground_full", "profile-ground-full", 9106, failures)
	var full_context := full_fixture.get("context") as PlayerRunContext
	if full_context == null:
		return
	var full_registry := _registry_script.new() as RefCounted
	var full_before := full_context.item_state().to_dictionary()
	var full_result := _create_drop(full_context, _request(36), _identity(full_context, &"drop:owner_ground_full:36", Vector3.ZERO), full_registry)
	TestAssertions.truthy(full_result != null and not bool(full_result.call(&"ok")), "full owner ground capacity rejects creation", failures)
	TestAssertions.equal(full_context.item_state().to_dictionary(), full_before, "ground capacity is preflighted before generation", failures)
	TestAssertions.equal((full_registry.call(&"all_records") as Array).size(), 0, "full ground failure creates no session record", failures)

func _create_drop(context: PlayerRunContext, request: ItemGenerationRequest, identity: Dictionary, registry: RefCounted) -> RefCounted:
	return (_service_script.new() as RefCounted).call(
		&"create_drop", context, request, identity,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, registry,
	) as RefCounted

func _context(run_player_id: StringName, profile_id: String, slot: int, seed: int) -> PlayerRunContext:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var profile := ProfileState.new_profile(profile_id, "Ground Ownership", 1000)
	profile.inventory_columns = 1
	var context := PlayerRunContext.new()
	assert(context.configure(run_player_id, slot, profile, seed, party, 100).is_empty())
	return context

func _request(sequence: int) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(778899 + sequence, sequence, 28, &"ordinary_enemy", &"ordinary_drop", [&"common"] as Array[StringName])
	request.forced_base_id = &"forge_vanguard_sword"
	request.forced_rarity_id = &"common"
	return request

func _identity(context: PlayerRunContext, drop_id: StringName, position: Vector3) -> Dictionary:
	return {
		"drop_id": drop_id,
		"run_player_id": context.run_player_id,
		"profile_id": context.profile_id,
		"player_number": context.player_slot_index + 1,
		"color_id": &"red",
		"world_position": position,
		"source_id": &"ordinary_enemy",
	}

func _record(drop_id: StringName, item_id: String, owner: StringName, slot: int) -> RefCounted:
	var record := _record_script.new() as RefCounted
	record.set(&"drop_id", drop_id)
	record.set(&"item_id", item_id)
	record.set(&"run_player_id", owner)
	record.set(&"profile_id", "profile-%s" % owner)
	record.set(&"player_number", 1)
	record.set(&"color_id", &"red")
	record.set(&"world_position", Vector3.ZERO)
	record.set(&"rarity_id", &"common")
	record.set(&"source_id", &"ordinary_enemy")
	record.set(&"ground_slot", slot)
	return record

func _predicted_item_id(context: PlayerRunContext, sequence: int) -> String:
	var issuer_namespace := "run:%s:%s:%s" % [context.profile_id, context.run_seed, context.run_player_id]
	return "item-%s-%016d" % [issuer_namespace.sha256_text(), sequence]

func _full_ground_context(run_player_id: StringName, profile_id: String, seed: int, failures: Array[String]) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var items: Array[ItemInstance] = []
	var slots: Dictionary = {}
	var issuer_namespace := "run:%s:%s:%s" % [profile_id, seed, run_player_id]
	for sequence: int in ItemSlotContainer.RUN_GROUND_ITEMS_CAPACITY:
		var issued := ItemInstanceIssuer.issue(
			issuer_namespace, sequence, "full_ground_fixture", seed + sequence,
			{"affixes": [], "base_definition_id": "forge_vanguard_sword", "base_damage_components": [], "item_level": 28, "rarity_id": "common"},
			GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
		)
		if not issued.ok():
			failures.append("full ground fixture issuance %d failed: %s" % [sequence, issued.error])
			return {}
		items.append(issued.item)
		slots[sequence] = issued.item.instance_id
	var state := ItemOwnershipState.create(String(run_player_id), ItemRegistry.new(items), [
		ItemSlotContainer.create(INVENTORY_ID, ItemSlotContainer.RUN_INVENTORY, String(run_player_id), 5),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(run_player_id), EquipmentSlotIndex.capacity()),
		ItemSlotContainer.create(GROUND_ID, ItemSlotContainer.RUN_GROUND_ITEMS, String(run_player_id), ItemSlotContainer.RUN_GROUND_ITEMS_CAPACITY, slots),
	])
	var bootstrap := RunItemBootstrap.create(&"full-ground-run", seed, run_player_id, 1, state)
	var profile := ProfileState.new_profile(profile_id, "Full Ground", 1000)
	profile.inventory_columns = 1
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	var errors := context.configure(run_player_id, _parties.size() - 1, profile, seed, party, 100, bootstrap)
	TestAssertions.equal(errors, PackedStringArray(), "full ground context configures", failures)
	return {"context": context if errors.is_empty() else null}
