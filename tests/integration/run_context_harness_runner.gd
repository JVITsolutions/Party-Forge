extends SceneTree

class RejectingPartyManager extends PartyManager:
	var reject_growth_source := false

	func replace_member_source(member_id: int, source: StatModifierSource) -> bool:
		if reject_growth_source:
			return false
		return super.replace_member_source(member_id, source)

var _failures: Array[String] = []
var _parties: Array[PartyManager] = []
var _actors: Array[Node3D] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var player_one_fixture := _context_fixture(
		&"player_one", 0, "profile-run-context-one", 1337,
		Vector3.ZERO, Vector3(1.0, 0.0, 0.0), PartyManager.new(),
	)
	var rejecting_party := RejectingPartyManager.new()
	var player_two_fixture := _context_fixture(
		&"player_two", 1, "profile-run-context-two", 7331,
		Vector3(30.0, 0.0, 0.0), Vector3(31.0, 0.0, 0.0), rejecting_party,
	)
	var player_one := player_one_fixture.context as PlayerRunContext
	var player_two := player_two_fixture.context as PlayerRunContext

	var registry := RunContextRegistry.new()
	_assert(registry.register_context(player_two, 1).ok(), "slot 1 context registers first")
	_assert(registry.register_context(player_one, 0).ok(), "slot 0 context registers second")
	var ordered := registry.all_contexts()
	_assert(ordered.size() == 2, "registry retains two contexts")
	if ordered.size() == 2:
		_assert(ordered[0] == player_one and ordered[1] == player_two, "registry returns slot 0 before slot 1")
	_assert(player_one.party != player_two.party, "contexts own distinct PartyManagers")
	_assert(
		not is_same(player_one.get("_progression_by_member"), player_two.get("_progression_by_member")),
		"contexts own distinct progression dictionaries",
	)

	var distributor := RewardDistributionService.new()
	var tuning := load("res://data/progression/reward_distribution.tres") as RewardDistributionTuning
	_assert(distributor.configure(registry, tuning).is_empty(), "reward distributor configures")

	var near_one := RewardPacket.create(&"task9_near_one", 5, Vector3.ZERO)
	var near_one_report := distributor.distribute(near_one)
	_assert(
		near_one_report.get("awarded_members") == PackedStringArray(["player_one:1", "player_one:2"]),
		"packet near only player one awards only player one's squad",
	)
	_assert(player_one.progression_for(1).experience == 5 and player_one.progression_for(2).experience == 5, "player one squad receives full near packet")
	_assert(player_two.progression_for(1).experience == 0 and player_two.progression_for(2).experience == 0, "player two remains unchanged by player-one packet")

	var shared := RewardPacket.create(&"task9_shared", 5, Vector3(15.0, 0.0, 0.0))
	var shared_report := distributor.distribute(shared)
	_assert(
		shared_report.get("awarded_members") == PackedStringArray([
			"player_one:1", "player_one:2", "player_two:1", "player_two:2",
		]),
		"shared-radius packet awards both eligible squads in slot order",
	)
	_assert(player_one.progression_for(1).experience == 10 and player_one.progression_for(2).experience == 10, "player one receives the full shared packet")
	_assert(player_two.progression_for(1).experience == 5 and player_two.progression_for(2).experience == 5, "player two receives the full shared packet")

	var milestone_packet := RewardPacket.create(&"task9_milestone", 146, Vector3(15.0, 0.0, 0.0))
	var milestone_report := distributor.distribute(milestone_packet)
	_assert((milestone_report.get("errors") as PackedStringArray).is_empty(), "milestone packet has no award errors")
	var player_one_state := player_one.progression_for(1)
	var player_two_state := player_two.progression_for(1)
	_assert(player_one_state.level == 5, "player one reaches milestone level five")
	_assert(player_two_state.level == 4, "player two retains its independent XP history")

	var control_fixture := _context_fixture(
		&"player_one", 0, "profile-run-context-control", 1337,
		Vector3.ZERO, Vector3.ONE, PartyManager.new(),
	)
	var control := control_fixture.context as PlayerRunContext
	_assert(control.award_experience(1, 5).ok(), "single-context control accepts first packet")
	_assert(control.award_experience(1, 5).ok(), "single-context control accepts shared packet")
	_assert(control.award_experience(1, 146).ok(), "single-context control accepts milestone packet")
	var control_state := control.progression_for(1)
	_assert(player_one_state.to_snapshot() == control_state.to_snapshot(), "player one RNG and growth match a single-context control run")

	var player_two_queue_before := player_two.pending_leader_levels()
	_assert(player_one.consume_pending_leader_level(), "player one consumes its first leader upgrade")
	_assert(player_two.pending_leader_levels() == player_two_queue_before, "player one queue consumption cannot mutate player two")

	var player_one_before_failure := player_one.progression_for(1).to_snapshot()
	var player_one_queue_before_failure := player_one.pending_leader_levels()
	var player_two_before_failure := player_two.progression_for(1).to_snapshot()
	rejecting_party.reject_growth_source = true
	var rejected := player_two.award_experience(1, 5)
	_assert(not rejected.ok() and "stat source rejected" in rejected.error, "player two forced stat-source rejection is reported")
	_assert(player_two.progression_for(1).to_snapshot() == player_two_before_failure, "rejected player two award is atomic")
	_assert(player_one.progression_for(1).to_snapshot() == player_one_before_failure, "player two rejection cannot mutate player one progression")
	_assert(player_one.pending_leader_levels() == player_one_queue_before_failure, "player two rejection cannot mutate player one queue")

	var before_retry := _context_snapshot(player_one, player_two)
	var retry_report := distributor.distribute(milestone_packet)
	_assert(retry_report == _empty_report(), "retrying one resolved packet awards neither context")
	_assert(_context_snapshot(player_one, player_two) == before_retry, "packet retry changes no progression or queues")

	_cleanup()
	if _failures.is_empty():
		print("RUN_CONTEXT_HARNESS_SUMMARY: PASS contexts=2")
		quit(0)
		return
	for failure: String in _failures:
		push_error("RUN_CONTEXT_HARNESS_FAILURE: %s" % failure)
	print("RUN_CONTEXT_HARNESS_SUMMARY: FAIL failures=%d" % _failures.size())
	quit(1)


func _context_fixture(
	run_player_id: StringName,
	slot: int,
	profile_id: String,
	run_seed: int,
	leader_position: Vector3,
	follower_position: Vector3,
	manager: PartyManager,
) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	manager.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	assert(manager.recruit(catalog.class_by_id(&"ranger")))
	_parties.append(manager)
	var context := PlayerRunContext.new()
	var errors := context.configure(
		run_player_id,
		slot,
		ProfileState.new_profile(profile_id, "Task 9 Harness", 1000 + slot),
		run_seed,
		manager,
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


func _context_snapshot(player_one: PlayerRunContext, player_two: PlayerRunContext) -> Dictionary:
	return {
		"one_leader": player_one.progression_for(1).to_snapshot(),
		"one_follower": player_one.progression_for(2).to_snapshot(),
		"one_queue": player_one.pending_leader_levels(),
		"two_leader": player_two.progression_for(1).to_snapshot(),
		"two_follower": player_two.progression_for(2).to_snapshot(),
		"two_queue": player_two.pending_leader_levels(),
	}


func _empty_report() -> Dictionary:
	return {
		"awarded_members": PackedStringArray(),
		"skipped_contexts": PackedStringArray(),
		"errors": PackedStringArray(),
	}


func _cleanup() -> void:
	for actor: Node3D in _actors:
		if is_instance_valid(actor):
			actor.free()
	_actors.clear()
	for party: PartyManager in _parties:
		if is_instance_valid(party):
			party.free()
	_parties.clear()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
