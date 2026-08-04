extends RefCounted

class RejectingPartyManager extends PartyManager:
	var rejected_member_ids: Array[int] = []

	func replace_member_source(member_id: int, source: StatModifierSource) -> bool:
		if member_id in rejected_member_ids:
			return false
		return super.replace_member_source(member_id, source)

var _parties: Array[PartyManager] = []
var _actors: Array[Node3D] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_packet_and_tuning_validation(failures)
	_test_leader_event_radius_boundaries(failures)
	_test_follower_link_availability_and_full_award(failures)
	_test_idempotent_collection_time_resolution(failures)
	_test_slot_order_and_failure_isolation(failures)
	_test_invalid_requests_mark_no_pairs(failures)
	_cleanup()
	return failures

func _test_packet_and_tuning_validation(failures: Array[String]) -> void:
	var invalid_packet := RewardPacket.create(&"", -1, Vector3.ZERO)
	TestAssertions.equal(invalid_packet.validate(), PackedStringArray([
		"PARTY_FORGE_REWARD_ERROR field=packet_id",
		"PARTY_FORGE_REWARD_ERROR field=experience",
	]), "packet validation reports stable fields", failures)
	var tuning := load("res://data/progression/reward_distribution.tres") as RewardDistributionTuning
	TestAssertions.truthy(tuning != null, "reward tuning resource loads", failures)
	if tuning != null:
		TestAssertions.equal(tuning.validate(), PackedStringArray(), "authored reward tuning validates", failures)
		TestAssertions.near(tuning.leader_event_share_radius, 18.0, 0.001, "leader share radius is authored", failures)
		TestAssertions.near(tuning.follower_squad_link_radius, 14.0, 0.001, "follower link radius is authored", failures)
	var invalid_tuning := RewardDistributionTuning.new()
	invalid_tuning.leader_event_share_radius = 0.0
	invalid_tuning.follower_squad_link_radius = -1.0
	TestAssertions.equal(invalid_tuning.validate(), PackedStringArray([
		"PARTY_FORGE_REWARD_ERROR field=leader_event_share_radius",
		"PARTY_FORGE_REWARD_ERROR field=follower_squad_link_radius",
	]), "tuning rejects nonpositive radii", failures)
	var service := RewardDistributionService.new()
	TestAssertions.equal(service.configure(null, null), PackedStringArray([
		"PARTY_FORGE_REWARD_ERROR field=registry",
		"PARTY_FORGE_REWARD_ERROR field=tuning",
	]), "distribution configuration reports stable fields", failures)

func _test_leader_event_radius_boundaries(failures: Array[String]) -> void:
	_assert_leader_distance(17.99, &"packet_inside", &"player_inside", "profile-inside", true, failures)
	_assert_leader_distance(18.0, &"packet_boundary", &"player_boundary", "profile-boundary", true, failures)
	_assert_leader_distance(18.01, &"packet_outside", &"player_outside", "profile-outside", false, failures)

func _assert_leader_distance(
	distance: float,
	packet_id: StringName,
	run_player_id: StringName,
	profile_id: String,
	expected_eligible: bool,
	failures: Array[String],
) -> void:
	var fixture := _context_fixture(
		run_player_id,
		0,
		profile_id,
		Vector3(distance, 0.0, 0.0),
		Vector3(distance + 1.0, 0.0, 0.0),
		PartyManager.new(),
	)
	var context := fixture.context as PlayerRunContext
	var registry := RunContextRegistry.new()
	TestAssertions.truthy(registry.register_context(context).ok(), "%s context registers" % run_player_id, failures)
	var service := _configured_service(registry)
	var report := service.distribute(RewardPacket.create(packet_id, 7, Vector3.ZERO))
	var expected_awards := PackedStringArray([
		"%s:1" % run_player_id,
		"%s:2" % run_player_id,
	]) if expected_eligible else PackedStringArray()
	var expected_skips := PackedStringArray() if expected_eligible else PackedStringArray([String(run_player_id)])
	TestAssertions.equal(report.awarded_members, expected_awards, "leader %.2f award eligibility is inclusive" % distance, failures)
	TestAssertions.equal(report.skipped_contexts, expected_skips, "leader %.2f context skip is stable" % distance, failures)
	TestAssertions.equal(context.progression_for(1).experience, 7 if expected_eligible else 0, "leader %.2f receives full XP or none" % distance, failures)
	TestAssertions.equal(context.progression_for(2).experience, 7 if expected_eligible else 0, "leader gate controls nearby follower at %.2f" % distance, failures)
	TestAssertions.truthy(service.has_resolved(packet_id, run_player_id), "leader %.2f pair resolves" % distance, failures)

func _test_follower_link_availability_and_full_award(failures: Array[String]) -> void:
	var boundary_fixture := _context_fixture(
		&"player_link_boundary",
		0,
		"profile-link-boundary",
		Vector3.ZERO,
		Vector3(14.0, 0.0, 0.0),
		PartyManager.new(),
	)
	var boundary_context := boundary_fixture.context as PlayerRunContext
	var boundary_registry := RunContextRegistry.new()
	boundary_registry.register_context(boundary_context)
	var boundary_report := _configured_service(boundary_registry).distribute(
		RewardPacket.create(&"packet_link_boundary", 7, Vector3.ZERO),
	)
	TestAssertions.equal(boundary_report.awarded_members, PackedStringArray([
		"player_link_boundary:1",
		"player_link_boundary:2",
	]), "follower at exactly 14.0 is included", failures)
	TestAssertions.equal(boundary_context.progression_for(1).experience, 7, "leader receives full unsplit packet", failures)
	TestAssertions.equal(boundary_context.progression_for(2).experience, 7, "follower receives full unsplit packet", failures)

	var outside_fixture := _context_fixture(
		&"player_link_outside",
		0,
		"profile-link-outside",
		Vector3.ZERO,
		Vector3(14.01, 0.0, 0.0),
		PartyManager.new(),
	)
	var outside_context := outside_fixture.context as PlayerRunContext
	var outside_registry := RunContextRegistry.new()
	outside_registry.register_context(outside_context)
	var outside_report := _configured_service(outside_registry).distribute(
		RewardPacket.create(&"packet_link_outside", 7, Vector3.ZERO),
	)
	TestAssertions.equal(outside_report.awarded_members, PackedStringArray(["player_link_outside:1"]), "follower at 14.01 is excluded", failures)
	TestAssertions.equal(outside_context.progression_for(2).experience, 0, "separated follower gets no XP", failures)

	var state_fixture := _context_fixture(
		&"player_follower_state",
		0,
		"profile-follower-state",
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
		PartyManager.new(),
	)
	var state_context := state_fixture.context as PlayerRunContext
	var follower_health := (state_fixture.follower as Node3D).get_node("HealthComponent") as HealthComponent
	var state_registry := RunContextRegistry.new()
	state_registry.register_context(state_context)
	var state_service := _configured_service(state_registry)
	follower_health.is_downed = true
	var downed_report := state_service.distribute(RewardPacket.create(&"packet_downed", 1, Vector3.ZERO))
	TestAssertions.equal(downed_report.awarded_members, PackedStringArray(["player_follower_state:1"]), "downed follower is excluded", failures)
	follower_health.is_downed = false
	follower_health.is_dead = true
	var dead_report := state_service.distribute(RewardPacket.create(&"packet_dead", 1, Vector3.ZERO))
	TestAssertions.equal(dead_report.awarded_members, PackedStringArray(["player_follower_state:1"]), "dead follower is excluded", failures)
	follower_health.is_dead = false
	var revived_report := state_service.distribute(RewardPacket.create(&"packet_revived", 1, Vector3.ZERO))
	TestAssertions.equal(revived_report.awarded_members, PackedStringArray([
		"player_follower_state:1",
		"player_follower_state:2",
	]), "follower revived before collection is eligible", failures)
	TestAssertions.equal(state_context.progression_for(1).experience, 3, "leader receives each state packet", failures)
	TestAssertions.equal(state_context.progression_for(2).experience, 1, "follower receives only revived packet", failures)

func _test_idempotent_collection_time_resolution(failures: Array[String]) -> void:
	var eligible_fixture := _context_fixture(
		&"player_idempotent",
		0,
		"profile-idempotent",
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
		PartyManager.new(),
	)
	var eligible_context := eligible_fixture.context as PlayerRunContext
	var eligible_registry := RunContextRegistry.new()
	eligible_registry.register_context(eligible_context)
	var eligible_service := _configured_service(eligible_registry)
	var packet := RewardPacket.create(&"packet_once", 3, Vector3.ZERO)
	var first := eligible_service.distribute(packet)
	var retry := eligible_service.distribute(packet)
	TestAssertions.equal(first.awarded_members, PackedStringArray([
		"player_idempotent:1",
		"player_idempotent:2",
	]), "first packet awards both eligible members", failures)
	TestAssertions.equal(retry, _empty_report(), "retrying a resolved packet awards nothing", failures)
	TestAssertions.equal(eligible_context.progression_for(1).experience, 3, "retry leaves leader XP unchanged", failures)
	TestAssertions.equal(eligible_context.progression_for(2).experience, 3, "retry leaves follower XP unchanged", failures)

	var ineligible_fixture := _context_fixture(
		&"player_ineligible_once",
		0,
		"profile-ineligible-once",
		Vector3(18.01, 0.0, 0.0),
		Vector3(19.0, 0.0, 0.0),
		PartyManager.new(),
	)
	var ineligible_context := ineligible_fixture.context as PlayerRunContext
	var ineligible_registry := RunContextRegistry.new()
	ineligible_registry.register_context(ineligible_context)
	var ineligible_service := _configured_service(ineligible_registry)
	var missed := RewardPacket.create(&"packet_missed_once", 5, Vector3.ZERO)
	var missed_report := ineligible_service.distribute(missed)
	TestAssertions.equal(missed_report.skipped_contexts, PackedStringArray(["player_ineligible_once"]), "ineligible context is recorded as skipped", failures)
	(ineligible_fixture.leader as Node3D).position = Vector3.ZERO
	(ineligible_fixture.follower as Node3D).position = Vector3.ONE
	TestAssertions.equal(ineligible_service.distribute(missed), _empty_report(), "initially ineligible pair remains permanently resolved", failures)
	TestAssertions.equal(ineligible_context.progression_for(1).experience, 0, "movement after collection cannot grant leader XP", failures)
	TestAssertions.equal(ineligible_context.progression_for(2).experience, 0, "movement after collection cannot grant follower XP", failures)

func _test_slot_order_and_failure_isolation(failures: Array[String]) -> void:
	var rejecting_party := RejectingPartyManager.new()
	rejecting_party.rejected_member_ids = [1]
	var early_fixture := _context_fixture(
		&"player_early",
		0,
		"profile-reward-early",
		Vector3.ZERO,
		Vector3.ONE,
		rejecting_party,
	)
	var late_fixture := _context_fixture(
		&"player_late",
		1,
		"profile-reward-late",
		Vector3.ZERO,
		Vector3.ONE,
		PartyManager.new(),
	)
	var early_context := early_fixture.context as PlayerRunContext
	var late_context := late_fixture.context as PlayerRunContext
	var registry := RunContextRegistry.new()
	TestAssertions.truthy(registry.register_context(late_context).ok(), "late slot registers first", failures)
	TestAssertions.truthy(registry.register_context(early_context).ok(), "early slot registers second", failures)
	var report := _configured_service(registry).distribute(RewardPacket.create(&"packet_ordered", 20, Vector3.ZERO))
	TestAssertions.equal(report.awarded_members, PackedStringArray([
		"player_early:2",
		"player_late:1",
		"player_late:2",
	]), "awards stay in slot then member order despite one failure", failures)
	TestAssertions.equal(report.skipped_contexts, PackedStringArray(), "qualified contexts are not skipped on member failure", failures)
	TestAssertions.equal(report.errors, PackedStringArray([
		"PARTY_FORGE_PROGRESSION_ERROR member=1 reason=stat source rejected",
	]), "member failure is reported without stopping distribution", failures)
	TestAssertions.equal(early_context.progression_for(1).level, 1, "failed early leader award is atomic", failures)
	TestAssertions.equal(early_context.progression_for(2).level, 2, "early follower still receives XP after leader award failure", failures)
	TestAssertions.equal(late_context.progression_for(1).level, 2, "later context leader still receives XP", failures)
	TestAssertions.equal(late_context.progression_for(2).level, 2, "later context follower still receives XP", failures)

	var skipped_registry := RunContextRegistry.new()
	var skipped_late := _context_fixture(&"skipped_late", 3, "profile-skipped-late", Vector3(19.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), PartyManager.new())
	var skipped_early := _context_fixture(&"skipped_early", 2, "profile-skipped-early", Vector3(19.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), PartyManager.new())
	skipped_registry.register_context(skipped_late.context as PlayerRunContext)
	skipped_registry.register_context(skipped_early.context as PlayerRunContext)
	var skipped_report := _configured_service(skipped_registry).distribute(RewardPacket.create(&"packet_skipped_order", 1, Vector3.ZERO))
	TestAssertions.equal(skipped_report.skipped_contexts, PackedStringArray([
		"skipped_early",
		"skipped_late",
	]), "skipped contexts stay in registry slot order", failures)

func _test_invalid_requests_mark_no_pairs(failures: Array[String]) -> void:
	var fixture := _context_fixture(
		&"player_invalid_request",
		0,
		"profile-invalid-request",
		Vector3.ZERO,
		Vector3.ONE,
		PartyManager.new(),
	)
	var context := fixture.context as PlayerRunContext
	var registry := RunContextRegistry.new()
	registry.register_context(context)
	var service := _configured_service(registry)
	var null_report := service.distribute(null)
	TestAssertions.equal(null_report.errors, PackedStringArray(["PARTY_FORGE_REWARD_ERROR reason=invalid distribution request"]), "null packet returns stable request error", failures)
	TestAssertions.truthy(not service.has_resolved(&"null_packet", context.run_player_id), "null packet marks no pair", failures)
	var empty_report := service.distribute(RewardPacket.create(&"", 1, Vector3.ZERO))
	TestAssertions.equal(empty_report.errors, PackedStringArray(["PARTY_FORGE_REWARD_ERROR reason=invalid distribution request"]), "empty packet ID returns stable request error", failures)
	TestAssertions.truthy(not service.has_resolved(&"", context.run_player_id), "empty packet marks no pair", failures)
	var negative_report := service.distribute(RewardPacket.create(&"packet_recoverable", -1, Vector3.ZERO))
	TestAssertions.equal(negative_report.errors, PackedStringArray(["PARTY_FORGE_REWARD_ERROR reason=invalid distribution request"]), "negative packet XP returns stable request error", failures)
	TestAssertions.truthy(not service.has_resolved(&"packet_recoverable", context.run_player_id), "invalid XP packet marks no pair", failures)
	var valid_report := service.distribute(RewardPacket.create(&"packet_recoverable", 1, Vector3.ZERO))
	TestAssertions.equal(valid_report.awarded_members, PackedStringArray([
		"player_invalid_request:1",
		"player_invalid_request:2",
	]), "same packet identity can succeed after an invalid request", failures)
	TestAssertions.truthy(service.has_resolved(&"packet_recoverable", context.run_player_id), "valid retry resolves pair", failures)

func _context_fixture(
	run_player_id: StringName,
	slot: int,
	profile_id: String,
	leader_position: Vector3,
	follower_position: Vector3,
	manager: PartyManager,
) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	manager.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	manager.recruit(catalog.class_by_id(&"ranger"))
	_parties.append(manager)
	var context := PlayerRunContext.new()
	var errors := context.configure(
		run_player_id,
		slot,
		ProfileState.new_profile(profile_id, "Reward Fixture", 1000),
		1337 + slot,
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

func _configured_service(registry: RunContextRegistry) -> RewardDistributionService:
	var service := RewardDistributionService.new()
	var tuning := load("res://data/progression/reward_distribution.tres") as RewardDistributionTuning
	assert(service.configure(registry, tuning).is_empty())
	return service

func _empty_report() -> Dictionary:
	return {
		"awarded_members": PackedStringArray(),
		"skipped_contexts": PackedStringArray(),
		"errors": PackedStringArray(),
	}

func _cleanup() -> void:
	for actor: Node3D in _actors:
		actor.free()
	_actors.clear()
	for party: PartyManager in _parties:
		party.free()
	_parties.clear()
