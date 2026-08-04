extends RefCounted

class RecordingRewardDistributor extends RewardDistributionService:
	var packets: Array[RewardPacket] = []

	func distribute(packet: RewardPacket) -> Dictionary:
		packets.append(packet)
		return super.distribute(packet)

var _actors: Array[Node3D] = []
var _parties: Array[PartyManager] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_configure_and_attraction_contract(failures)
	_test_legacy_radius_configuration_is_non_awarding(failures)
	_test_collection_routes_one_packet_at_current_position(failures)
	_test_invalid_distributor_consumes_once_without_global_fallback(failures)
	_cleanup()
	return failures

func _test_configure_and_attraction_contract(failures: Array[String]) -> void:
	var root := _new_root("ExperienceOrbAttractionTest")
	var leader := _actor_at(root, Vector3.ZERO)
	var distributor := RewardDistributionService.new()
	var orb := _new_orb(root)
	TestAssertions.equal(_method_arg_count(orb, &"configure"), 5, "orb configure accepts packet identity and distributor", failures)
	orb.call("configure", 7, &"xp_1337_1", leader, distributor, 1.0)
	TestAssertions.equal(orb.get("value"), 7, "orb stores integer experience", failures)
	TestAssertions.equal(orb.get("packet_id"), &"xp_1337_1", "orb stores packet identity", failures)
	TestAssertions.truthy(orb.get("leader") == leader, "orb stores attraction leader", failures)
	TestAssertions.truthy(orb.get("reward_distributor") == distributor, "orb stores reward distributor", failures)

	orb.position = Vector3(6.0, 0.0, 0.0)
	orb.call("advance_collection", 0.1)
	TestAssertions.equal(orb.position, Vector3(6.0, 0.0, 0.0), "orb does not move outside attraction radius", failures)
	TestAssertions.near((orb.get("velocity") as Vector3).length(), 0.0, 0.001, "orb velocity stays zero outside attraction radius", failures)
	orb.call("set_pickup_radius_multiplier", 2.0)
	orb.call("advance_collection", 0.1)
	TestAssertions.near((orb.get("velocity") as Vector3).length(), 2.2, 0.001, "orb accelerates toward leader inside attraction radius", failures)
	TestAssertions.truthy(float((orb.get("velocity") as Vector3).x) < 0.0, "orb moves toward current leader", failures)
	TestAssertions.truthy(orb.position.x < 6.0, "orb advances after acceleration", failures)

	var zero_radius_orb := _new_orb(root)
	zero_radius_orb.call("configure", 1, &"xp_1337_2", leader, distributor, 0.0)
	zero_radius_orb.position = Vector3(1.0, 0.0, 0.0)
	zero_radius_orb.call("advance_collection", 0.1)
	TestAssertions.equal(zero_radius_orb.position, Vector3(1.0, 0.0, 0.0), "zero pickup multiplier disables attraction", failures)
	root.free()

func _test_legacy_radius_configuration_is_non_awarding(failures: Array[String]) -> void:
	var root := _new_root("ExperienceOrbLegacyRadiusTest")
	var leader := _actor_at(root, Vector3.ZERO)
	var legacy_experience := ExperienceSystem.new()
	root.add_child(legacy_experience)
	var orb := _new_orb(root)
	orb.call("configure", 1, leader, legacy_experience, 1.5)
	TestAssertions.near(float(orb.get("pickup_radius_multiplier")), 1.5, 0.001, "legacy radius call remains compatible during Task 6", failures)
	TestAssertions.equal(orb.get("reward_distributor"), null, "legacy radius call cannot become a reward distributor", failures)
	TestAssertions.truthy(not _has_property(orb, &"experience_system"), "legacy radius call stores no global ExperienceSystem", failures)
	root.free()

func _test_collection_routes_one_packet_at_current_position(failures: Array[String]) -> void:
	var root := _new_root("ExperienceOrbCollectionTest")
	var fixture := _distribution_fixture(root)
	var context := fixture.context as PlayerRunContext
	var leader := fixture.leader as Node3D
	var distributor := fixture.distributor as RecordingRewardDistributor
	var orb := _new_orb(root)
	orb.call("configure", 20, &"xp_1337_1", leader, distributor, 1.0)
	orb.position = Vector3(0.651, 0.0, 0.0)
	orb.call("advance_collection", 0.0)
	TestAssertions.truthy(not bool(orb.get("collected")), "orb does not collect outside collection radius", failures)
	orb.position = Vector3(0.65, 0.0, 0.0)
	orb.call("advance_collection", 0.016)
	TestAssertions.truthy(bool(orb.get("collected")), "orb marks itself collected at the collection boundary", failures)
	TestAssertions.truthy(orb.is_queued_for_deletion(), "collected orb queues itself for deletion", failures)
	TestAssertions.equal(distributor.packets.size(), 1, "collected orb calls distributor once", failures)
	if distributor.packets.size() == 1:
		TestAssertions.equal(distributor.packets[0].packet_id, &"xp_1337_1", "collected packet preserves deterministic identity", failures)
		TestAssertions.equal(distributor.packets[0].experience, 20, "collected packet preserves experience", failures)
		TestAssertions.equal(distributor.packets[0].world_position, Vector3(0.65, 0.0, 0.0), "collected packet uses current orb position", failures)
	TestAssertions.equal(context.progression_for(1).level, 2, "collected orb routes through context", failures)
	TestAssertions.truthy(distributor.has_resolved(&"xp_1337_1", &"player_one"), "packet/context is recorded", failures)
	orb.call("advance_collection", 0.016)
	TestAssertions.equal(distributor.packets.size(), 1, "collected orb cannot call distributor twice", failures)
	TestAssertions.equal(context.progression_for(1).level, 2, "collected orb cannot award twice", failures)
	root.free()

func _test_invalid_distributor_consumes_once_without_global_fallback(failures: Array[String]) -> void:
	var root := _new_root("ExperienceOrbInvalidDistributorTest")
	var leader := _actor_at(root, Vector3.ZERO)
	var legacy_experience := ExperienceSystem.new()
	root.add_child(legacy_experience)
	var orb := _new_orb(root)
	orb.call("configure", 20, &"xp_1337_99", leader, null, 1.0)
	orb.position = leader.position
	orb.call("advance_collection", 0.016)
	orb.call("advance_collection", 0.016)
	TestAssertions.truthy(bool(orb.get("collected")), "missing distributor still consumes physical orb", failures)
	TestAssertions.truthy(orb.is_queued_for_deletion(), "missing distributor still queues orb deletion", failures)
	TestAssertions.equal(legacy_experience.experience, 0, "missing distributor never falls back to global experience", failures)
	TestAssertions.truthy(not _has_property(orb, &"experience_system"), "orb exposes no global ExperienceSystem dependency", failures)
	TestAssertions.equal(orb.call("format_distributor_unavailable", &"xp_1337_99"), "PARTY_FORGE_REWARD_ERROR packet=xp_1337_99 reason=distributor unavailable", "missing distributor diagnostic is stable", failures)
	root.free()

func _distribution_fixture(root: Node) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var context := PlayerRunContext.new()
	var errors := context.configure(
		&"player_one",
		0,
		ProfileState.new_profile("profile-orb-route", "Orb Route", 1000),
		1337,
		party,
		100,
	)
	assert(errors.is_empty())
	var leader := _actor_at(root, Vector3.ZERO)
	assert(context.bind_actor(1, leader))
	var registry := RunContextRegistry.new()
	assert(registry.register_context(context).ok())
	var distributor := RecordingRewardDistributor.new()
	var tuning := load("res://data/progression/reward_distribution.tres") as RewardDistributionTuning
	assert(distributor.configure(registry, tuning).is_empty())
	return {"context": context, "leader": leader, "distributor": distributor}

func _new_orb(parent: Node) -> Node3D:
	var orb := (load("res://scenes/progression/experience_orb.tscn") as PackedScene).instantiate() as Node3D
	parent.add_child(orb)
	return orb

func _new_root(root_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root

func _actor_at(parent: Node, world_position: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = world_position
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(100.0, true, 8.0, 0.5)
	actor.add_child(health)
	parent.add_child(actor)
	_actors.append(actor)
	return actor

func _method_arg_count(object: Object, method_name: StringName) -> int:
	for method: Dictionary in object.get_method_list():
		if StringName(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return -1

func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false

func _cleanup() -> void:
	for actor: Node3D in _actors:
		if is_instance_valid(actor):
			actor.free()
	_actors.clear()
	for party: PartyManager in _parties:
		if is_instance_valid(party):
			party.free()
	_parties.clear()
