extends RefCounted

const DECISION_PATH := "res://scripts/loot/personal_loot_decision.gd"
const SERVICE_PATH := "res://scripts/loot/personal_loot_roll_service.gd"
const REWARD_TUNING_PATH := "res://data/progression/reward_distribution.tres"
const LOOT_TUNING_PATH := "res://data/items/personal_loot_tuning.tres"

class ContextAccessProvider extends RefCounted:
	var unlocked_profiles: Dictionary = {}
	var calls: Array[String] = []

	func _init(profile_ids: Array[String]) -> void:
		for profile_id: String in profile_ids:
			unlocked_profiles[profile_id] = true

	func resolve(context: PlayerRunContext) -> bool:
		calls.append(context.profile_id)
		return unlocked_profiles.has(context.profile_id)

class SyntheticRegistry extends RunContextRegistry:
	var contexts: Array[PlayerRunContext] = []

	func all_contexts() -> Array[PlayerRunContext]:
		return contexts.duplicate()

var _decision_script: Script
var _service_script: Script
var _parties: Array[PartyManager] = []
var _actors: Array[Node3D] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	_load_contract_scripts(failures)
	if _decision_script == null or _service_script == null:
		return failures
	_test_configuration_contract(failures)
	_test_per_context_eligibility_and_canonical_decisions(failures)
	_test_multiplier_clamping_and_force_success(failures)
	_test_replay_is_defensive_and_does_not_reroll(failures)
	_test_slot_then_player_id_ordering(failures)
	_cleanup()
	return failures

func _load_contract_scripts(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(DECISION_PATH), "personal loot decision script exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(SERVICE_PATH), "personal loot roll service script exists", failures)
	if ResourceLoader.exists(DECISION_PATH):
		_decision_script = load(DECISION_PATH) as Script
	if ResourceLoader.exists(SERVICE_PATH):
		_service_script = load(SERVICE_PATH) as Script
	TestAssertions.truthy(_decision_script != null, "personal loot decision script loads", failures)
	TestAssertions.truthy(_service_script != null, "personal loot roll service script loads", failures)

func _test_configuration_contract(failures: Array[String]) -> void:
	var service := _new_service()
	TestAssertions.equal(service.call(&"configure", null, null, null, Callable()), PackedStringArray([
		"PARTY_FORGE_PERSONAL_LOOT_ERROR field=registry",
		"PARTY_FORGE_PERSONAL_LOOT_ERROR field=reward_tuning",
		"PARTY_FORGE_PERSONAL_LOOT_ERROR field=loot_tuning",
		"PARTY_FORGE_PERSONAL_LOOT_ERROR field=feature_access_provider",
	]), "configuration reports every missing dependency in stable order", failures)

	var registry := RunContextRegistry.new()
	var reward_tuning := load(REWARD_TUNING_PATH) as RewardDistributionTuning
	var loot_tuning := load(LOOT_TUNING_PATH) as PersonalLootTuning
	var provider := ContextAccessProvider.new([])
	TestAssertions.equal(
		service.call(&"configure", registry, reward_tuning, loot_tuning, Callable(provider, "resolve")),
		PackedStringArray(),
		"valid personal loot dependencies configure",
		failures,
	)

func _test_per_context_eligibility_and_canonical_decisions(failures: Array[String]) -> void:
	var registry := RunContextRegistry.new()
	var p1 := _context_fixture(&"player_near", 0, "profile-near", Vector3(18.0, 0.0, 0.0), Vector3(50.0, 0.0, 0.0))
	var p2 := _context_fixture(&"player_locked", 1, "profile-locked", Vector3(18.0, 0.0, 0.0), Vector3.ZERO)
	var p3 := _context_fixture(&"player_far", 2, "profile-far", Vector3(18.01, 0.0, 0.0), Vector3.ZERO)
	var p4 := _context_fixture(&"player_unavailable", 3, "profile-unavailable", Vector3.ZERO, Vector3.ZERO)
	(p4.leader as Node3D).get_node("HealthComponent").set("is_dead", true)
	for fixture: Dictionary in [p4, p2, p3, p1]:
		TestAssertions.truthy(registry.register_context(fixture.context as PlayerRunContext).ok(), "fixture context registers", failures)

	var provider := ContextAccessProvider.new(["profile-near", "profile-far", "profile-unavailable"])
	var service := _configured_service(registry, provider)
	var event := EnemyDefeatEvent.create(7331, 41, 99, &"spitter", &"ordinary_specialist", Vector3.ZERO, 300.0)
	var decisions := service.call(&"resolve", event) as Array
	TestAssertions.equal(decisions.size(), 4, "all registered players receive one decision", failures)
	if decisions.size() != 4:
		return

	TestAssertions.equal(_run_player_ids(decisions), PackedStringArray([
		"player_near", "player_locked", "player_far", "player_unavailable",
	]), "decisions are stable in ascending player-slot order", failures)
	TestAssertions.equal(provider.calls, [
		"profile-near", "profile-locked", "profile-far", "profile-unavailable",
	], "feature access resolves separately for every context in decision order", failures)

	var near: RefCounted = decisions[0] as RefCounted
	var locked: RefCounted = decisions[1] as RefCounted
	var far: RefCounted = decisions[2] as RefCounted
	var unavailable: RefCounted = decisions[3] as RefCounted
	TestAssertions.truthy(bool(near.get(&"eligible")), "leader exactly at the shared radius is eligible", failures)
	TestAssertions.equal(String(near.get(&"reason")), "roll_failed" if not bool(near.get(&"success")) else "roll_succeeded", "eligible decision records the roll outcome", failures)
	TestAssertions.truthy(not bool(locked.get(&"eligible")), "locked profile at the same position is ineligible", failures)
	TestAssertions.equal(locked.get(&"reason"), &"feature_locked", "locked profile records feature diagnostic", failures)
	TestAssertions.truthy(not bool(far.get(&"eligible")), "far leader is ineligible even when its follower reaches the event", failures)
	TestAssertions.equal(far.get(&"reason"), &"leader_out_of_range", "far leader records distance diagnostic", failures)
	TestAssertions.truthy(not bool(unavailable.get(&"eligible")), "unavailable leader is ineligible", failures)
	TestAssertions.equal(unavailable.get(&"reason"), &"leader_unavailable", "unavailable leader records availability diagnostic", failures)

	for decision: RefCounted in decisions:
		var run_player_id := StringName(decision.get(&"run_player_id"))
		var expected_roll := floori(ItemDeterministicRandom.unit(event.run_seed, event.defeat_sequence, StringName("personal_drop:%s" % run_player_id), 0) * 10000.0)
		var expected_seed := maxi(("%d|%d|%s|item" % [event.run_seed, event.defeat_sequence, run_player_id]).sha256_text().substr(0, 13).hex_to_int(), 1)
		TestAssertions.equal(decision.get(&"basis_points"), 200, "%s uses specialist basis points" % run_player_id, failures)
		TestAssertions.equal(decision.get(&"roll_basis_points"), expected_roll, "%s draw uses its independent deterministic stage" % run_player_id, failures)
		TestAssertions.equal(decision.get(&"generation_seed"), expected_seed, "%s generation seed uses the canonical SHA-256 input" % run_player_id, failures)
		TestAssertions.equal(decision.get(&"generation_sequence"), event.defeat_sequence, "%s generation sequence equals defeat sequence" % run_player_id, failures)
		TestAssertions.equal(decision.get(&"item_level"), 27, "%s item level uses encounter policy" % run_player_id, failures)
		_assert_canonical_event_facts(decision, event, failures)
	TestAssertions.truthy(
		int(decisions[0].get(&"roll_basis_points")) != int(decisions[1].get(&"roll_basis_points")),
		"same-position players use distinct deterministic draws",
		failures,
	)

func _test_multiplier_clamping_and_force_success(failures: Array[String]) -> void:
	var registry := RunContextRegistry.new()
	var eligible := _context_fixture(&"player_multiplier", 0, "profile-multiplier", Vector3.ZERO, Vector3.ONE)
	var ineligible := _context_fixture(&"player_multiplier_locked", 1, "profile-multiplier-locked", Vector3.ZERO, Vector3.ONE)
	registry.register_context(eligible.context as PlayerRunContext)
	registry.register_context(ineligible.context as PlayerRunContext)
	var provider := ContextAccessProvider.new(["profile-multiplier"])
	var service := _configured_service(registry, provider)

	var zero_event := EnemyDefeatEvent.create(7331, 51, 101, &"swarmer", &"ordinary_melee", Vector3.ZERO, 0.0)
	var zero_decisions := service.call(&"resolve", zero_event, false, -20.0) as Array
	TestAssertions.equal(zero_decisions[0].get(&"basis_points"), 0, "negative multiplier clamps effective chance to zero", failures)
	TestAssertions.truthy(bool(zero_decisions[0].get(&"eligible")) and not bool(zero_decisions[0].get(&"success")), "zero chance remains an eligible no-drop decision", failures)
	TestAssertions.equal(zero_decisions[0].get(&"reason"), &"no_drop_chance", "zero chance records no-drop diagnostic", failures)

	var full_event := EnemyDefeatEvent.create(7331, 52, 102, &"swarmer", &"ordinary_melee", Vector3.ZERO, 0.0)
	var full_decisions := service.call(&"resolve", full_event, false, 10000.0) as Array
	TestAssertions.equal(full_decisions[0].get(&"basis_points"), 10000, "oversized multiplier clamps effective chance to 10000 basis points", failures)
	TestAssertions.truthy(bool(full_decisions[0].get(&"success")), "10000 basis points always succeeds for an eligible context", failures)
	TestAssertions.truthy(not bool(full_decisions[1].get(&"success")), "10000 basis points cannot bypass profile eligibility", failures)

	var forced_event := EnemyDefeatEvent.create(7331, 53, 103, &"guardian", &"boss", Vector3.ZERO, 0.0)
	var forced_decisions := service.call(&"resolve", forced_event, true, 0.0) as Array
	TestAssertions.equal(forced_decisions[0].get(&"basis_points"), 0, "force success does not rewrite authored zero chance", failures)
	TestAssertions.truthy(bool(forced_decisions[0].get(&"success")), "force success applies to an eligible zero-chance context", failures)
	TestAssertions.equal(forced_decisions[0].get(&"reason"), &"forced_success", "forced outcome is diagnostic", failures)
	TestAssertions.truthy(not bool(forced_decisions[1].get(&"success")), "force success never bypasses eligibility", failures)

func _test_replay_is_defensive_and_does_not_reroll(failures: Array[String]) -> void:
	var registry := RunContextRegistry.new()
	var fixture := _context_fixture(&"player_replay", 0, "profile-replay", Vector3.ZERO, Vector3.ONE)
	registry.register_context(fixture.context as PlayerRunContext)
	var provider := ContextAccessProvider.new(["profile-replay"])
	var service := _configured_service(registry, provider)
	var event := EnemyDefeatEvent.create(8128, 61, 110, &"spitter", &"ordinary_specialist", Vector3(4.0, 0.0, 2.0), 120.0)
	var first := service.call(&"resolve", event) as Array
	var first_document := (first[0] as RefCounted).call(&"to_dictionary") as Dictionary
	var first_bytes := var_to_bytes(first_document)
	(fixture.leader as Node3D).position = Vector3(100.0, 0.0, 0.0)
	provider.unlocked_profiles.clear()
	var replay := service.call(&"resolve", event, true, 10000.0) as Array
	var replay_document := (replay[0] as RefCounted).call(&"to_dictionary") as Dictionary
	TestAssertions.equal(var_to_bytes(replay_document), first_bytes, "replay returns a byte-equivalent canonical decision without rerolling", failures)
	TestAssertions.truthy(first[0] != replay[0], "replay returns a defensive decision instance", failures)
	TestAssertions.equal(provider.calls.size(), 1, "replay does not re-resolve feature access", failures)
	(replay[0] as RefCounted).set(&"reason", &"mutated_copy")
	var second_replay := service.call(&"resolve", event) as Array
	TestAssertions.equal(var_to_bytes((second_replay[0] as RefCounted).call(&"to_dictionary")), first_bytes, "mutating a replay copy cannot alter cached canonical state", failures)

func _test_slot_then_player_id_ordering(failures: Array[String]) -> void:
	var registry := SyntheticRegistry.new()
	var zeta := _context_fixture(&"zeta_player", 1, "profile-zeta", Vector3.ZERO, Vector3.ONE)
	var alpha := _context_fixture(&"alpha_player", 1, "profile-alpha", Vector3.ZERO, Vector3.ONE)
	var first := _context_fixture(&"first_player", 0, "profile-first", Vector3.ZERO, Vector3.ONE)
	registry.contexts = [zeta.context as PlayerRunContext, alpha.context as PlayerRunContext, first.context as PlayerRunContext]
	var provider := ContextAccessProvider.new(["profile-zeta", "profile-alpha", "profile-first"])
	var decisions := _configured_service(registry, provider).call(
		&"resolve",
		EnemyDefeatEvent.create(9991, 71, 120, &"swarmer", &"ordinary_melee", Vector3.ZERO, 0.0),
	) as Array
	TestAssertions.equal(_run_player_ids(decisions), PackedStringArray([
		"first_player", "alpha_player", "zeta_player",
	]), "service sorts by player slot and then run player ID", failures)

func _configured_service(registry: RunContextRegistry, provider: ContextAccessProvider) -> RefCounted:
	var service := _new_service()
	var errors := service.call(
		&"configure",
		registry,
		load(REWARD_TUNING_PATH) as RewardDistributionTuning,
		load(LOOT_TUNING_PATH) as PersonalLootTuning,
		Callable(provider, "resolve"),
	) as PackedStringArray
	assert(errors.is_empty())
	return service

func _new_service() -> RefCounted:
	return _service_script.new() as RefCounted

func _context_fixture(
	run_player_id: StringName,
	slot: int,
	profile_id: String,
	leader_position: Vector3,
	follower_position: Vector3,
) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"ranger"))
	_parties.append(party)
	var context := PlayerRunContext.new()
	var errors := context.configure(
		run_player_id,
		slot,
		ProfileState.new_profile(profile_id, "Personal Loot Fixture", 1000),
		7000 + slot,
		party,
		100,
	)
	assert(errors.is_empty())
	var leader := _actor_at(leader_position)
	var follower := _actor_at(follower_position)
	assert(context.bind_actor(1, leader))
	assert(context.bind_actor(2, follower))
	return {"context": context, "leader": leader, "follower": follower}

func _actor_at(world_position: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = world_position
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(100.0, true, 8.0, 0.5)
	actor.add_child(health)
	_actors.append(actor)
	return actor

func _run_player_ids(decisions: Array) -> PackedStringArray:
	var ids := PackedStringArray()
	for decision: RefCounted in decisions:
		ids.append(String(decision.get(&"run_player_id")))
	return ids

func _assert_canonical_event_facts(decision: RefCounted, event: EnemyDefeatEvent, failures: Array[String]) -> void:
	var document := decision.call(&"to_dictionary") as Dictionary
	TestAssertions.equal(document.get("run_player_id"), String(decision.get(&"run_player_id")), "canonical decision copies run player ID", failures)
	TestAssertions.equal(document.get("profile_id"), String(decision.get(&"profile_id")), "canonical decision copies profile ID", failures)
	TestAssertions.equal(document.get("player_slot"), int(decision.get(&"player_slot")), "canonical decision includes player slot", failures)
	TestAssertions.equal(document.get("run_seed"), event.run_seed, "canonical decision copies run seed", failures)
	TestAssertions.equal(document.get("defeat_sequence"), event.defeat_sequence, "canonical decision copies defeat sequence", failures)
	TestAssertions.equal(document.get("enemy_sequence"), event.enemy_sequence, "canonical decision copies enemy sequence", failures)
	TestAssertions.equal(document.get("enemy_id"), String(event.enemy_id), "canonical decision copies enemy ID", failures)
	TestAssertions.equal(document.get("source_category"), String(event.source_category), "canonical decision copies source category", failures)
	TestAssertions.equal(document.get("world_position"), event.world_position, "canonical decision copies world position", failures)
	TestAssertions.near(float(document.get("encounter_seconds")), event.encounter_seconds, 0.001, "canonical decision copies encounter time", failures)

func _cleanup() -> void:
	for actor: Node3D in _actors:
		actor.free()
	_actors.clear()
	for party: PartyManager in _parties:
		party.free()
	_parties.clear()
