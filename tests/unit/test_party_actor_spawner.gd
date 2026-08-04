extends RefCounted

class RecordingRunContext extends PlayerRunContext:
	var expected_container: Node3D
	var bind_calls: Array[int] = []
	var actor_was_in_container := false
	var reject_bind := false

	func bind_actor(member_id: int, actor: Node3D) -> bool:
		bind_calls.append(member_id)
		actor_was_in_container = actor != null and actor.get_parent() == expected_container
		if reject_bind:
			return false
		return super.bind_actor(member_id, actor)

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_spawned_follower_binds_after_entering_container(failures)
	_test_bind_failure_frees_only_new_actor(failures)
	return failures

func _test_spawned_follower_binds_after_entering_container(failures: Array[String]) -> void:
	var fixture := _fixture(false)
	var party := fixture.party as PartyManager
	var context := fixture.context as RecordingRunContext
	var container := fixture.container as Node3D
	TestAssertions.truthy(party.recruit((fixture.catalog as GameCatalog).class_by_id(&"ranger")), "follower fixture recruits", failures)
	TestAssertions.equal(context.bind_calls, [2], "spawner binds the new follower member", failures)
	TestAssertions.truthy(context.actor_was_in_container, "spawner binds only after adding actor to its container", failures)
	var follower := context.actor_for(2)
	TestAssertions.truthy(follower != null and follower.get_parent() == container, "owner context resolves the spawned follower", failures)
	if follower != null:
		TestAssertions.equal(follower.get_meta("party_forge_run_player_id"), &"player_spawner", "spawned follower receives run ownership metadata", failures)
		TestAssertions.equal(follower.get_meta("party_forge_member_id"), 2, "spawned follower receives member ownership metadata", failures)
	_cleanup_fixture(fixture)

func _test_bind_failure_frees_only_new_actor(failures: Array[String]) -> void:
	var fixture := _fixture(true)
	var party := fixture.party as PartyManager
	var container := fixture.container as Node3D
	TestAssertions.truthy(party.recruit((fixture.catalog as GameCatalog).class_by_id(&"ranger")), "rejected follower fixture recruits party state", failures)
	TestAssertions.equal(container.get_child_count(), 1, "failed actor binding frees the just-created companion", failures)
	TestAssertions.equal(
		PartyActorSpawner.format_actor_bind_error(2),
		"PARTY_FORGE_RUN_CONTEXT_ERROR member=2 reason=actor bind failed",
		"actor bind failure diagnostic is stable",
		failures,
	)
	_cleanup_fixture(fixture)

func _fixture(reject_bind: bool) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var context := RecordingRunContext.new()
	assert(context.configure(
		&"player_spawner",
		0,
		ProfileState.new_profile("profile-spawner", "Spawner Owner", 1000),
		1337,
		party,
		100,
	).is_empty())
	context.reject_bind = reject_bind
	var container := Node3D.new()
	var leader := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
	container.add_child(leader)
	leader.configure(party.members[0])
	var spawner := PartyActorSpawner.new()
	context.expected_container = container
	spawner.initialize(party, container, leader, null, null, context)
	return {
		"catalog": catalog,
		"party": party,
		"context": context,
		"container": container,
		"spawner": spawner,
	}

func _cleanup_fixture(fixture: Dictionary) -> void:
	(fixture.spawner as PartyActorSpawner).free()
	(fixture.container as Node3D).free()
	(fixture.party as PartyManager).free()
