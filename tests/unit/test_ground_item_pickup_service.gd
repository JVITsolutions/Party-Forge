extends RefCounted

const RESULT_PATH := "res://scripts/loot/ground_item_pickup_result.gd"
const SERVICE_PATH := "res://scripts/loot/ground_item_pickup_service.gd"

var _parties: Array[PartyManager] = []
var _actors: Array[Node3D] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	for path: String in [RESULT_PATH, SERVICE_PATH]:
		TestAssertions.truthy(ResourceLoader.exists(path), "%s exists" % path.get_file(), failures)
	if failures.size() > 0:
		return failures
	var result_script := load(RESULT_PATH) as Script
	var codes := result_script.get_script_constant_map()["Code"] as Dictionary
	_test_codes_and_range(codes, failures)
	_test_full_inventory(codes, failures)
	_test_success_after_transaction(codes, failures)
	_cleanup()
	return failures

func _test_codes_and_range(codes: Dictionary, failures: Array[String]) -> void:
	var fixture := _fixture(&"player_1", "profile-one", 1, Vector3.ZERO, Vector3(3.0001, 0.0, 0.0), &"drop-a", 9101)
	var service := fixture.service as RefCounted
	var registry := fixture.registry as GroundItemRegistry
	TestAssertions.equal(service.call(&"collect", &"missing", &"player_1").get(&"code"), codes["MISSING"], "missing drop has exact code", failures)
	TestAssertions.equal(service.call(&"collect", &"drop-a", &"player_2").get(&"code"), codes["NOT_OWNER"], "foreign activation has exact code", failures)
	var result := service.call(&"collect", &"drop-a", &"player_1") as RefCounted
	TestAssertions.equal(result.get(&"code"), codes["MOVE_CLOSER"], "out-of-range activation is explicit", failures)
	TestAssertions.equal(result.get(&"message"), "Move closer", "out-of-range status uses exact player wording", failures)
	TestAssertions.truthy(registry.record(&"drop-a") != null, "out-of-range chest remains", failures)
	(fixture.actor as Node3D).position = Vector3(0.0001, 0.0, 0.0)
	TestAssertions.equal(service.call(&"collect", &"drop-a", &"player_1").get(&"code"), codes["OK"], "exact three-meter boundary is accepted", failures)

func _test_full_inventory(codes: Dictionary, failures: Array[String]) -> void:
	var fixture := _fixture(&"full", "profile-full", 0, Vector3.ZERO, Vector3.ZERO, &"drop-full", 9102)
	var context := fixture.context as PlayerRunContext
	var registry := fixture.registry as GroundItemRegistry
	var before := context.item_state().to_dictionary()
	var result := (fixture.service as RefCounted).call(&"collect", &"drop-full", &"full") as RefCounted
	TestAssertions.equal(result.get(&"code"), codes["INVENTORY_FULL"], "full inventory has exact code", failures)
	TestAssertions.equal(result.get(&"message"), "Inventory full", "full inventory has explicit player wording", failures)
	TestAssertions.equal(context.item_state().to_dictionary(), before, "full inventory leaves transactional state unchanged", failures)
	TestAssertions.truthy(registry.record(&"drop-full") != null, "full inventory leaves chest registered", failures)

func _test_success_after_transaction(codes: Dictionary, failures: Array[String]) -> void:
	var fixture := _fixture(&"owner", "profile-owner", 1, Vector3.ZERO, Vector3.ZERO, &"drop-ok", 9103)
	var context := fixture.context as PlayerRunContext
	var registry := fixture.registry as GroundItemRegistry
	var item_id := (registry.record(&"drop-ok") as GroundItemRecord).item_id
	var result := (fixture.service as RefCounted).call(&"collect", &"drop-ok", &"owner") as RefCounted
	TestAssertions.equal(result.get(&"code"), codes["OK"], "accepted pickup has exact code", failures)
	TestAssertions.equal(registry.record(&"drop-ok"), null, "record is removed only after successful transaction", failures)
	TestAssertions.equal(context.run_inventory().item_id_at(0), item_id, "successful transaction moves exact item to run inventory", failures)
	var rejected := _record(&"drop-reject", "not-in-context", &"owner", Vector3.ZERO, 1)
	registry.add(rejected)
	TestAssertions.equal((fixture.service as RefCounted).call(&"collect", &"drop-reject", &"owner").get(&"code"), codes["TRANSACTION_REJECTED"], "context rejection has exact code", failures)
	TestAssertions.truthy(registry.record(&"drop-reject") != null, "transaction rejection preserves registry record", failures)

func _fixture(owner: StringName, profile_id: String, inventory_columns: int, actor_position: Vector3, drop_position: Vector3, drop_id: StringName, seed: int) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var profile := ProfileState.new_profile(profile_id, "Pickup Owner", 1000)
	profile.inventory_columns = inventory_columns
	var context := PlayerRunContext.new()
	assert(context.configure(owner, _parties.size() - 1, profile, seed, party, 100).is_empty())
	var actor := Node3D.new()
	actor.position = actor_position
	_actors.append(actor)
	assert(context.bind_actor(1, actor))
	var generated := context.issue_ground_item(_request(seed), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	assert(generated.ok())
	var ground := context.ground_items()
	var slot := ground.occupied_slots()[0]
	var registry := GroundItemRegistry.new()
	assert(registry.add(_record(drop_id, generated.item.instance_id, owner, drop_position, slot)))
	var contexts := RunContextRegistry.new()
	assert(contexts.register_context(context).ok())
	var service := (load(SERVICE_PATH) as Script).new(registry, contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.0) as RefCounted
	return {"context": context, "actor": actor, "registry": registry, "service": service}

func _request(seed: int) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(seed, 0, 10, &"ordinary_enemy", &"ordinary_drop", [&"common"] as Array[StringName])
	request.forced_base_id = &"forge_vanguard_sword"
	request.forced_rarity_id = &"common"
	return request

func _record(drop_id: StringName, item_id: String, owner: StringName, position: Vector3, slot: int) -> GroundItemRecord:
	var record := GroundItemRecord.new()
	record.drop_id = drop_id
	record.item_id = item_id
	record.run_player_id = owner
	record.profile_id = "profile-%s" % owner
	record.player_number = 1
	record.color_id = &"red"
	record.world_position = position
	record.rarity_id = &"common"
	record.source_id = &"test"
	record.ground_slot = slot
	return record

func _cleanup() -> void:
	for actor: Node3D in _actors:
		actor.free()
	for party: PartyManager in _parties:
		party.free()
	_actors.clear()
	_parties.clear()
