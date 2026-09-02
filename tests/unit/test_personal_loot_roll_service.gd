extends RefCounted

const DECISION_PATH := "res://scripts/loot/personal_loot_decision.gd"
const SERVICE_PATH := "res://scripts/loot/personal_loot_roll_service.gd"
const ACCESS_POLICY_PATH := "res://scripts/loot/player_item_drop_access_policy.gd"
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

class PolicyAccessProvider extends RefCounted:
	var policy_script: Script
	var calls: Array[String] = []

	func _init(script: Script) -> void:
		policy_script = script

	func resolve(context: PlayerRunContext) -> bool:
		calls.append(context.profile_id)
		var profile := context.profile_snapshot
		var known: Array[StringName] = [&"equipment_inventory", &"inventory"]
		var unlocked: Array[StringName] = []
		for value: String in profile.permanent_feature_unlocks:
			unlocked.append(StringName(value))
		var feature_policy := FeatureAccessPolicy.new(false, false, known, known, unlocked)
		return bool(policy_script.call(&"allows", profile, context.run_inventory(), feature_policy))

class SyntheticRegistry extends RunContextRegistry:
	var contexts: Array[PlayerRunContext] = []

	func all_contexts() -> Array[PlayerRunContext]:
		return contexts.duplicate()

var _decision_script: Script
var _service_script: Script
var _access_policy_script: Script
var _parties: Array[PartyManager] = []
var _actors: Array[Node3D] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	_load_contract_scripts(failures)
	if _decision_script == null or _service_script == null:
		return failures
	_test_configuration_contract(failures)
	_test_tuning_validation_fails_closed(failures)
	_test_unknown_difficulty_fails_closed(failures)
	_test_player_item_drop_access_policy_matrix(failures)
	_test_feature_gate_precedes_random_derivation(failures)
	_test_per_context_eligibility_and_canonical_decisions(failures)
	_test_multiplier_clamping_and_force_success(failures)
	_test_replay_is_defensive_and_does_not_reroll(failures)
	_test_slot_then_player_id_ordering(failures)
	_cleanup()
	return failures

func _load_contract_scripts(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(DECISION_PATH), "personal loot decision script exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(SERVICE_PATH), "personal loot roll service script exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(ACCESS_POLICY_PATH), "Player item-drop access policy script exists", failures)
	if ResourceLoader.exists(DECISION_PATH):
		_decision_script = load(DECISION_PATH) as Script
	if ResourceLoader.exists(SERVICE_PATH):
		_service_script = load(SERVICE_PATH) as Script
	if ResourceLoader.exists(ACCESS_POLICY_PATH):
		_access_policy_script = load(ACCESS_POLICY_PATH) as Script
	TestAssertions.truthy(_decision_script != null, "personal loot decision script loads", failures)
	TestAssertions.truthy(_service_script != null, "personal loot roll service script loads", failures)
	TestAssertions.truthy(_access_policy_script != null, "Player item-drop access policy script loads", failures)

func _test_player_item_drop_access_policy_matrix(failures: Array[String]) -> void:
	if _access_policy_script == null:
		return
	var known: Array[StringName] = [&"equipment_inventory", &"inventory"]
	for mask: int in 8:
		var profile := ProfileState.new_profile("drop-policy-%d" % mask, "Drop Policy", 1000)
		var unlocked: Array[StringName] = []
		if mask & 1:
			profile.permanent_feature_unlocks.append("equipment_inventory")
			unlocked.append(&"equipment_inventory")
		if mask & 2:
			profile.permanent_feature_unlocks.append("inventory")
			unlocked.append(&"inventory")
		var inventory := ItemSlotContainer.create(&"drop-policy-inventory", ItemSlotContainer.RUN_INVENTORY, profile.profile_id, 5 if mask & 4 else 0)
		var feature_policy := FeatureAccessPolicy.new(false, false, known, known, unlocked)
		TestAssertions.equal(
			bool(_access_policy_script.call(&"allows", profile, inventory, feature_policy)),
			mask == 7,
			"item-drop access matrix mask %d passes only both unlocks plus positive owner capacity" % mask,
			failures,
		)
	var valid_profile := ProfileState.new_profile("drop-policy-null", "Drop Policy Null", 1000)
	valid_profile.permanent_feature_unlocks = ["equipment_inventory", "inventory"]
	var valid_inventory := ItemSlotContainer.create(&"drop-policy-null-inventory", ItemSlotContainer.RUN_INVENTORY, valid_profile.profile_id, 5)
	var valid_policy := FeatureAccessPolicy.new(false, false, known, known, known)
	TestAssertions.truthy(not bool(_access_policy_script.call(&"allows", null, valid_inventory, valid_policy)), "missing profile fails item-drop access closed", failures)
	TestAssertions.truthy(not bool(_access_policy_script.call(&"allows", valid_profile, null, valid_policy)), "missing run inventory fails item-drop access closed", failures)
	TestAssertions.truthy(not bool(_access_policy_script.call(&"allows", valid_profile, valid_inventory, null)), "missing feature policy fails item-drop access closed", failures)

func _test_feature_gate_precedes_random_derivation(failures: Array[String]) -> void:
	if _access_policy_script == null:
		return
	for mask: int in 8:
		var registry := RunContextRegistry.new()
		var unlocks: Array[String] = []
		if mask & 1:
			unlocks.append("equipment_inventory")
		if mask & 2:
			unlocks.append("inventory")
		var fixture := _context_fixture(
			StringName("player_gate_%d" % mask),
			0,
			"profile-gate-%d" % mask,
			Vector3.ZERO,
			Vector3.ONE,
			unlocks,
			1 if mask & 4 else 0,
		)
		TestAssertions.truthy(registry.register_context(fixture.context as PlayerRunContext).ok(), "drop-gate matrix context %d registers" % mask, failures)
		var provider := PolicyAccessProvider.new(_access_policy_script)
		var service := _new_service()
		var errors := service.call(
			&"configure",
			registry,
			load(REWARD_TUNING_PATH) as RewardDistributionTuning,
			load(LOOT_TUNING_PATH) as PersonalLootTuning,
			Callable(provider, "resolve"),
			false,
			1.0,
			&"ordinary_specialist",
			25,
		) as PackedStringArray
		TestAssertions.equal(errors, PackedStringArray(), "drop-gate matrix service %d configures" % mask, failures)
		var event := EnemyDefeatEvent.create(9042, 100 + mask, 200 + mask, &"swarmer", &"ordinary_melee", Vector3.ZERO, 90.0)
		var decisions := service.call(&"resolve", event, true, 10000.0) as Array
		TestAssertions.equal(decisions.size(), 1, "drop-gate matrix mask %d yields one owner decision" % mask, failures)
		if decisions.size() != 1:
			continue
		var decision := decisions[0] as PersonalLootDecision
		TestAssertions.equal(provider.calls, ["profile-gate-%d" % mask], "drop-gate matrix mask %d evaluates access exactly once" % mask, failures)
		if mask == 7:
			TestAssertions.truthy(decision.eligible and decision.success, "all item-drop access conditions authorize the normal roll pipeline", failures)
			TestAssertions.truthy(decision.basis_points > 0 and decision.generation_seed > 0 and decision.generation_sequence == event.defeat_sequence and decision.item_level > 0, "authorized item drop derives chance and generation facts", failures)
		else:
			TestAssertions.equal(decision.reason, &"feature_locked", "denied drop-gate mask %d reports stable feature_locked" % mask, failures)
			TestAssertions.truthy(not decision.eligible and not decision.success, "denied drop-gate mask %d is neither eligible nor successful" % mask, failures)
			TestAssertions.equal(
				[decision.basis_points, decision.roll_basis_points, decision.generation_seed, decision.generation_sequence, decision.item_level],
				[0, 0, 0, 0, 0],
				"denied drop-gate mask %d derives no chance random or generation facts" % mask,
				failures,
			)

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

func _test_tuning_validation_fails_closed(failures: Array[String]) -> void:
	var invalid := PersonalLootTuning.new()
	invalid.drop_basis_points = {&"ordinary_melee": -1, &"ordinary_specialist": 10001, &"elite": 0, &"boss": 0}
	invalid.seconds_per_item_level = NAN
	invalid.specialist_item_level_bonus = 1001
	invalid.difficulty_item_level_bonus = {&"": 0}
	invalid.heat_item_levels_per_point = -0.25
	invalid.pickup_interaction_radius = 0.0
	invalid.controller_target_query_radius = -1.0
	var provider := ContextAccessProvider.new([])
	var service := _new_service()
	TestAssertions.equal(service.call(&"configure", RunContextRegistry.new(), load(REWARD_TUNING_PATH) as RewardDistributionTuning, PersonalLootTuning.new(), Callable(provider, "resolve")), PackedStringArray(), "fixture service first configures valid tuning", failures)
	var errors := service.call(
		&"configure", RunContextRegistry.new(), load(REWARD_TUNING_PATH) as RewardDistributionTuning,
		invalid, Callable(provider, "resolve"),
	) as PackedStringArray
	TestAssertions.equal(errors, PackedStringArray([
		"PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=drop_basis_points.ordinary_melee reason=must be an integer from 0 to 10000",
		"PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=drop_basis_points.ordinary_specialist reason=must be an integer from 0 to 10000",
		"PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=seconds_per_item_level reason=must be finite and greater than zero",
		"PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=specialist_item_level_bonus reason=must be an integer from -1000 to 1000",
		"PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=difficulty_item_level_bonus reason=normal is required",
		"PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=difficulty_item_level_bonus.<empty> reason=key must not be empty",
		"PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=heat_item_levels_per_point reason=must be finite and nonnegative",
		"PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=pickup_interaction_radius reason=must be finite and greater than zero",
		"PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=controller_target_query_radius reason=must be finite and at least pickup_interaction_radius",
	]), "invalid personal-loot tuning reports stable typed diagnostics", failures)
	TestAssertions.equal(service.call(&"resolve", EnemyDefeatEvent.create(1, 1, 1, &"swarmer", &"ordinary_melee", Vector3.ZERO, 0.0)), [], "invalid tuning leaves the roll service unavailable with no side effects", failures)

func _test_unknown_difficulty_fails_closed(failures: Array[String]) -> void:
	var registry := RunContextRegistry.new()
	var fixture := _context_fixture(&"player_challenge", 0, "profile-challenge", Vector3.ZERO, Vector3.ONE)
	registry.register_context(fixture.context as PlayerRunContext)
	var tuning := PersonalLootTuning.new()
	tuning.drop_basis_points = {&"ordinary_melee": 10000, &"ordinary_specialist": 10000, &"elite": 0, &"boss": 0}
	var provider := ContextAccessProvider.new(["profile-challenge"])
	var service := _new_service()
	var errors := service.call(
		&"configure", registry, load(REWARD_TUNING_PATH) as RewardDistributionTuning,
		tuning, Callable(provider, "resolve"), false, 1.0, &"", 0, &"test_challenge", 6.0,
	) as PackedStringArray
	TestAssertions.equal(errors, PackedStringArray([
		"PARTY_FORGE_PERSONAL_LOOT_ERROR field=difficulty_id reason=unsupported difficulty test_challenge",
	]), "unknown production difficulty fails closed with a stable typed diagnostic", failures)
	TestAssertions.equal(service.call(&"resolve", EnemyDefeatEvent.create(7331, 44, 100, &"swarmer", &"ordinary_melee", Vector3.ZERO, 120.0)), [], "unknown difficulty leaves the roll service unavailable with no roll side effects", failures)

	var authored_unknown := PersonalLootTuning.new()
	authored_unknown.difficulty_item_level_bonus = {&"normal": 0, &"future_challenge": 7}
	TestAssertions.equal(authored_unknown.validate(), PackedStringArray([
		"PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=difficulty_item_level_bonus.future_challenge reason=unsupported difficulty",
	]), "tuning fails closed on a difficulty not supported by item generation vocabulary", failures)

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
		if decision.get(&"reason") == &"feature_locked":
			TestAssertions.equal(
				[decision.get(&"basis_points"), decision.get(&"roll_basis_points"), decision.get(&"generation_seed"), decision.get(&"generation_sequence"), decision.get(&"item_level")],
				[0, 0, 0, 0, 0],
				"%s feature denial precedes every chance and generation fact" % run_player_id,
				failures,
			)
			_assert_canonical_event_facts(decision, event, failures)
			continue
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
	permanent_unlocks: Array[String] = [],
	inventory_columns: int = 0,
) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"ranger"))
	_parties.append(party)
	var context := PlayerRunContext.new()
	var profile := ProfileState.new_profile(profile_id, "Personal Loot Fixture", 1000)
	profile.permanent_feature_unlocks = permanent_unlocks.duplicate()
	profile.inventory_columns = inventory_columns
	var errors := context.configure(
		run_player_id,
		slot,
		profile,
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
