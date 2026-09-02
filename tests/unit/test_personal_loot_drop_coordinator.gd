extends RefCounted

const RECORD_PATH := "res://scripts/loot/ground_item_record.gd"
const REGISTRY_PATH := "res://scripts/loot/ground_item_registry.gd"
const COORDINATOR_PATH := "res://scripts/loot/personal_loot_drop_coordinator.gd"

var _record_script: Script
var _registry_script: Script
var _coordinator_script: Script
var _parties: Array[PartyManager] = []
var _actors: Array[Node3D] = []

class SyntheticIneligibleSuccessRollService extends PersonalLootRollService:
	var decision: PersonalLootDecision

	func resolve(
		_event: EnemyDefeatEvent,
		_force_success_override: bool = false,
		_drop_multiplier_override: float = NAN,
	) -> Array[PersonalLootDecision]:
		return [decision.copy()]

func run() -> Array[String]:
	var failures: Array[String] = []
	_load_contracts(failures)
	if _record_script == null or _registry_script == null or _coordinator_script == null:
		return failures
	_test_two_successes_use_exact_independent_production_requests(failures)
	_test_one_owner_failure_does_not_block_another(failures)
	_test_heat_context_matches_decision_request_and_provenance(failures)
	_test_ineligible_success_flag_never_reaches_generation(failures)
	_cleanup()
	return failures

func _load_contracts(failures: Array[String]) -> void:
	for path: String in [RECORD_PATH, REGISTRY_PATH, COORDINATOR_PATH]:
		TestAssertions.truthy(ResourceLoader.exists(path), "%s exists" % path.get_file(), failures)
	if ResourceLoader.exists(RECORD_PATH):
		_record_script = load(RECORD_PATH) as Script
	if ResourceLoader.exists(REGISTRY_PATH):
		_registry_script = load(REGISTRY_PATH) as Script
	if ResourceLoader.exists(COORDINATOR_PATH):
		_coordinator_script = load(COORDINATOR_PATH) as Script

func _test_two_successes_use_exact_independent_production_requests(failures: Array[String]) -> void:
	var fixture := _coordinator_fixture(false)
	var coordinator := fixture.coordinator as RefCounted
	var contexts := fixture.contexts as RunContextRegistry
	var registry := fixture.ground_registry as RefCounted
	var event := EnemyDefeatEvent.create(54001, 81, 810, &"swarmer", &"ordinary_melee", Vector3(4.0, 0.0, 2.0), 144.0)
	var report := coordinator.call(&"resolve_defeat", event) as Dictionary
	var decisions := report.get("decisions", []) as Array
	var spawned := report.get("spawned_drop_ids", []) as Array
	TestAssertions.equal(decisions.size(), 2, "coordinator returns both independent personal decisions", failures)
	TestAssertions.equal(spawned, [&"drop:player_1:81", &"drop:player_2:81"], "successful owners receive stable tuple drop IDs in decision order", failures)
	TestAssertions.equal(report.get("diagnostics", []), [], "two valid owners produce no diagnostics", failures)
	if decisions.size() != 2 or spawned.size() != 2:
		return

	var documents: Array[PackedByteArray] = []
	for index: int in spawned.size():
		var drop_id := spawned[index] as StringName
		var record := registry.call(&"record", drop_id) as RefCounted
		var context := contexts.context_for(record.get(&"run_player_id") as StringName)
		var state := context.item_state()
		var item := state.registry().item(String(record.get(&"item_id")))
		TestAssertions.truthy(item != null, "record references authoritative owner item", failures)
		TestAssertions.equal(state.registry().size(), 1, "each successful decision issues exactly one owner item", failures)
		TestAssertions.equal(context.ground_items().occupied_slots(), [0], "each successful decision occupies exactly one owner ground slot", failures)
		TestAssertions.equal(record.get(&"player_number"), context.player_slot_index + 1, "record uses session player number", failures)
		TestAssertions.equal(record.get(&"color_id"), &"red" if context.player_slot_index == 0 else &"blue", "record uses session color identity", failures)
		TestAssertions.equal(record.get(&"world_position"), event.world_position, "record preserves event world position", failures)
		TestAssertions.equal(record.get(&"source_id"), &"ordinary_enemy", "record preserves production source identity", failures)
		TestAssertions.equal(item.origin["source"]["generation"]["source_id"], "ordinary_enemy", "item provenance uses production ordinary-enemy source", failures)
		TestAssertions.equal(item.origin["source"]["generation"]["domain"], "ordinary_drop", "item provenance uses production ordinary-drop domain", failures)
		TestAssertions.equal(item.origin["source"]["generation"]["request_sequence"], event.defeat_sequence, "item provenance uses defeat generation sequence", failures)
		TestAssertions.equal(item.item_level, int((decisions[index] as RefCounted).get(&"item_level")), "item level matches the event decision", failures)
		_assert_matches_exact_request(item, context, decisions[index] as RefCounted, failures)
		documents.append(var_to_bytes(item.to_dictionary()))
	TestAssertions.truthy(documents[0] != documents[1], "otherwise-identical owners receive byte-distinct generated payload streams", failures)
	TestAssertions.truthy(int((decisions[0] as RefCounted).get(&"generation_seed")) != int((decisions[1] as RefCounted).get(&"generation_seed")), "owner generation streams use distinct deterministic seeds", failures)

func _test_one_owner_failure_does_not_block_another(failures: Array[String]) -> void:
	var fixture := _coordinator_fixture(true)
	var coordinator := fixture.coordinator as RefCounted
	var contexts := fixture.contexts as RunContextRegistry
	var registry := fixture.ground_registry as RefCounted
	var event := EnemyDefeatEvent.create(54002, 82, 820, &"swarmer", &"ordinary_melee", Vector3.ZERO, 10.0)
	registry.call(&"add", _record(&"drop:player_1:82", "reserved-registry-item", &"player_1"))
	var first_before := contexts.context_for(&"player_1").item_state().to_dictionary()
	var report := coordinator.call(&"resolve_defeat", event) as Dictionary
	TestAssertions.equal(report.get("spawned_drop_ids", []), [&"drop:player_2:82"], "one owner preflight failure does not block another owner success", failures)
	TestAssertions.equal((report.get("diagnostics", []) as Array).size(), 1, "failed owner contributes one diagnostic without replacing decisions", failures)
	if (report.get("diagnostics", []) as Array).size() == 1:
		var diagnostic: Variant = (report.get("diagnostics", []) as Array)[0]
		TestAssertions.truthy(diagnostic is Dictionary, "coordinator diagnostics are typed records rather than parsed strings", failures)
		if diagnostic is Dictionary:
			TestAssertions.equal(StringName(diagnostic.get("stage", &"")), &"storage", "duplicate ground identity is classified as a storage diagnostic", failures)
			TestAssertions.equal(StringName(diagnostic.get("code", &"")), &"ground_record_conflict", "duplicate ground identity exposes a stable diagnostic code", failures)
	TestAssertions.equal(contexts.context_for(&"player_1").item_state().to_dictionary(), first_before, "failed owner remains byte-equivalent", failures)
	TestAssertions.equal(contexts.context_for(&"player_2").item_state().registry().size(), 1, "independent successful owner still receives exactly one item", failures)

func _test_heat_context_matches_decision_request_and_provenance(failures: Array[String]) -> void:
	var contexts := RunContextRegistry.new()
	var context := _context(&"heat_player", "profile-heat", 0, &"red", 54100)
	assert(contexts.register_context(context).ok())
	var identities := LocalPlayerIdentityService.new().assign(contexts.all_contexts())
	var tuning := PersonalLootTuning.new()
	tuning.drop_basis_points = {&"ordinary_melee": 10000, &"ordinary_specialist": 10000, &"elite": 0, &"boss": 0}
	tuning.heat_item_levels_per_point = 0.5
	var roll := PersonalLootRollService.new()
	assert(roll.configure(contexts, RewardDistributionTuning.new(), tuning, func(_context: PlayerRunContext) -> bool: return true, true, 1.0, &"", 0, &"normal", 8.0).is_empty())
	var registry := GroundItemRegistry.new()
	var coordinator := PersonalLootDropCoordinator.new()
	var unknown_registry := GroundItemRegistry.new()
	var unknown_coordinator := PersonalLootDropCoordinator.new()
	TestAssertions.equal(unknown_coordinator.configure(roll, contexts, identities.identities(), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, unknown_registry, &"test_challenge", 8.0), PackedStringArray([
		"PARTY_FORGE_PERSONAL_LOOT_COORDINATOR_ERROR field=item_level_context reason=roll and generation difficulty/Heat must match",
		"PARTY_FORGE_PERSONAL_LOOT_COORDINATOR_ERROR field=difficulty_id reason=unsupported difficulty test_challenge",
	]), "coordinator reports stable typed diagnostics for an unsupported difficulty", failures)
	var rejected_report := unknown_coordinator.resolve_defeat(EnemyDefeatEvent.create(54100, 82, 820, &"swarmer", &"ordinary_melee", Vector3.ZERO, 120.0))
	TestAssertions.equal(rejected_report.get("spawned_drop_ids", []), [], "unsupported difficulty produces no generated ground item", failures)
	TestAssertions.equal(unknown_registry.all_records().size(), 0, "unsupported difficulty leaves the ground registry unchanged", failures)
	TestAssertions.equal(coordinator.configure(roll, contexts, identities.identities(), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, registry, &"normal", 8.0000001), PackedStringArray([
		"PARTY_FORGE_PERSONAL_LOOT_COORDINATOR_ERROR field=item_level_context reason=roll and generation difficulty/Heat must match",
	]), "coordinator rejects near-but-different Heat instead of approximately matching", failures)
	TestAssertions.equal(coordinator.configure(roll, contexts, identities.identities(), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, registry, &"normal", 7.0), PackedStringArray([
		"PARTY_FORGE_PERSONAL_LOOT_COORDINATOR_ERROR field=item_level_context reason=roll and generation difficulty/Heat must match",
	]), "coordinator rejects divergent roll and generation item-level context", failures)
	assert(coordinator.configure(roll, contexts, identities.identities(), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, registry, &"normal", 8.0).is_empty())
	var event := EnemyDefeatEvent.create(54100, 83, 830, &"swarmer", &"ordinary_melee", Vector3.ZERO, 120.0)
	var report := coordinator.resolve_defeat(event)
	var decisions := report.get("decisions", []) as Array
	TestAssertions.equal(decisions.size(), 1, "Heat consistency fixture resolves one decision", failures)
	var record := registry.record(&"drop:heat_player:83")
	var item := context.item_state().registry().item(record.item_id) if record != null else null
	TestAssertions.truthy(item != null, "Heat consistency fixture generates one item", failures)
	if decisions.size() == 1 and item != null:
		TestAssertions.equal(decisions[0].item_level, 15, "decision includes the exact non-default Heat contribution", failures)
		TestAssertions.equal(item.item_level, decisions[0].item_level, "generated request uses the decision item level", failures)
		var generation := item.origin["source"]["generation"] as Dictionary
		TestAssertions.equal(generation["item_level"], decisions[0].item_level, "generation provenance records the exact request item level", failures)
		TestAssertions.equal(float(generation["heat"]), 8.0, "generation request and provenance record exact nonzero Heat", failures)
		TestAssertions.equal(generation["difficulty_id"], "normal", "generation request and provenance remain on the supported normal difficulty", failures)

func _test_ineligible_success_flag_never_reaches_generation(failures: Array[String]) -> void:
	var contexts := RunContextRegistry.new()
	var context := _context(&"feature_locked_player", "profile-feature-locked", 0, &"red", 54101)
	assert(contexts.register_context(context).ok())
	var identities := LocalPlayerIdentityService.new().assign(contexts.all_contexts())
	var malicious := PersonalLootDecision.new()
	malicious.run_player_id = context.run_player_id
	malicious.profile_id = context.profile_id
	malicious.player_slot = context.player_slot_index
	malicious.eligible = false
	malicious.success = true
	malicious.reason = &"feature_locked"
	malicious.generation_seed = 12345
	malicious.generation_sequence = 84
	malicious.item_level = 10
	var roll := SyntheticIneligibleSuccessRollService.new()
	roll.decision = malicious
	roll.difficulty_id = &"normal"
	roll.heat = 0.0
	var registry := GroundItemRegistry.new()
	var coordinator := PersonalLootDropCoordinator.new()
	assert(coordinator.configure(roll, contexts, identities.identities(), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, registry).is_empty())
	var before := context.item_state().to_dictionary()
	var report := coordinator.resolve_defeat(EnemyDefeatEvent.create(54101, 84, 840, &"swarmer", &"ordinary_melee", Vector3.ZERO, 10.0))
	TestAssertions.equal(report.get("spawned_drop_ids", []), [], "ineligible decision cannot generate even when success is corrupted true", failures)
	TestAssertions.equal(report.get("diagnostics", []), [], "defensive ineligible rejection requires no generation diagnostic", failures)
	TestAssertions.equal(context.item_state().to_dictionary(), before, "ineligible success flag creates no item or owner-ground container mutation", failures)
	TestAssertions.equal(context.ground_items().occupied_slots(), [], "ineligible success flag occupies no owner-ground slot", failures)
	TestAssertions.equal(registry.all_records().size(), 0, "ineligible success flag creates no registry record", failures)

func _coordinator_fixture(reverse_registration: bool) -> Dictionary:
	var contexts := RunContextRegistry.new()
	var p1 := _context(&"player_1", "profile-player-1", 0, &"red", 54001)
	var p2 := _context(&"player_2", "profile-player-2", 1, &"blue", 54002)
	for context: PlayerRunContext in ([p2, p1] if reverse_registration else [p1, p2]):
		assert(contexts.register_context(context).ok())
	var identities := LocalPlayerIdentityService.new().assign(contexts.all_contexts())
	assert(identities.ok())
	var roll_service := PersonalLootRollService.new()
	var loot_tuning := PersonalLootTuning.new()
	loot_tuning.drop_basis_points = {&"ordinary_melee": 10000, &"ordinary_specialist": 10000, &"elite": 10000, &"boss": 10000}
	assert(roll_service.configure(contexts, RewardDistributionTuning.new(), loot_tuning, func(_context: PlayerRunContext) -> bool: return true).is_empty())
	var ground_registry := _registry_script.new() as RefCounted
	var coordinator := _coordinator_script.new() as RefCounted
	var errors := coordinator.call(
		&"configure", roll_service, contexts, identities.identities(),
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
		ground_registry, &"normal", 0.0,
	) as PackedStringArray
	assert(errors.is_empty())
	return {"coordinator": coordinator, "contexts": contexts, "ground_registry": ground_registry}

func _context(run_player_id: StringName, profile_id: String, slot: int, color_id: StringName, seed: int) -> PlayerRunContext:
	var catalog := GameCatalog.load_defaults()
	var fighter := (catalog.class_by_id(&"fighter") as Resource).duplicate(true) as ClassDefinition
	fighter.base_stat_overrides = fighter.base_stat_overrides.duplicate(true)
	fighter.base_stat_overrides[&"charisma"] = 17.0
	var party := PartyManager.new()
	party.initialize(fighter, catalog.traits)
	assert(party.recruit(catalog.class_by_id(&"ranger")))
	var caster := (catalog.class_by_id(&"mage") as Resource).duplicate(true) as ClassDefinition
	caster.capability_tags = caster.capability_tags.duplicate()
	caster.capability_tags.append(&"caster")
	assert(party.recruit(caster))
	_parties.append(party)
	var profile := ProfileState.new_profile(profile_id, "Coordinator Owner", 1000, color_id)
	profile.inventory_columns = 1
	profile.permanent_feature_unlocks = ["not-a-generation-unlock", "rarity_rare_unlocked"]
	var context := PlayerRunContext.new()
	assert(context.configure(run_player_id, slot, profile, seed, party, 100).is_empty())
	var leader := _actor(Vector3.ZERO)
	assert(context.bind_actor(1, leader))
	return context

func _assert_matches_exact_request(item: ItemInstance, context: PlayerRunContext, decision: RefCounted, failures: Array[String]) -> void:
	var request := ItemGenerationRequest.create(
		int(decision.get(&"generation_seed")), int(decision.get(&"generation_sequence")), int(decision.get(&"item_level")),
		&"ordinary_enemy", &"ordinary_drop", _ordinary_rarity_ids(),
	)
	request.difficulty_id = &"normal"
	request.heat = 0.0
	request.party_archetype_tags = [&"caster", &"melee", &"ranged"]
	request.charisma_value = context.party.stats_for(1).value(&"charisma")
	request.unlock_tags = [&"rarity_rare_unlocked"]
	var expected := ItemGenerationService.generate(
		request,
		"run:%s:%s:%s" % [context.profile_id, context.run_seed, context.run_player_id],
		0,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(expected != null and expected.ok(), "exact production comparison request generates", failures)
	if expected != null and expected.ok():
		TestAssertions.equal(var_to_bytes(item.to_dictionary()), var_to_bytes(expected.item.to_dictionary()), "coordinator delegates the exact party/Charisma/unlock request to production generation", failures)

func _ordinary_rarity_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for rarity: ItemRarityDefinition in GameCatalog.ITEM_FOUNDATION_CATALOG.rarities:
		if rarity != null and rarity.instance_supported and rarity.ordinary_generation_enabled:
			ids.append(rarity.id)
	ids.sort()
	return ids

func _record(drop_id: StringName, item_id: String, owner: StringName) -> RefCounted:
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
	record.set(&"ground_slot", 0)
	return record

func _actor(position: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = position
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(100.0, true, 8.0, 0.5)
	actor.add_child(health)
	_actors.append(actor)
	return actor

func _cleanup() -> void:
	for actor: Node3D in _actors:
		actor.free()
	_actors.clear()
	for party: PartyManager in _parties:
		party.free()
	_parties.clear()
