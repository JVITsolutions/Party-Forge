extends RefCounted

class RejectingPartyManager extends PartyManager:
	var reject_growth_source := false

	func replace_member_source(member_id: int, source: StatModifierSource) -> bool:
		if reject_growth_source:
			return false
		return super.replace_member_source(member_id, source)

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_configuration_validation_and_copy_ownership(failures)
	_test_atomic_progression_and_leader_queue(failures)
	_test_future_recruits_initialize_once(failures)
	_test_actor_binding_availability_and_position(failures)
	return failures

func _test_configuration_validation_and_copy_ownership(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var uninitialized_party := PartyManager.new()
	var invalid_profile := ProfileState.new()
	var invalid := PlayerRunContext.new()
	TestAssertions.equal(invalid.configure(&"", -1, invalid_profile, 0, uninitialized_party, 99), PackedStringArray([
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=run_player_id",
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=player_slot_index",
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=profile",
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=run_seed",
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=party",
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=experience_multiplier",
	]), "configuration reports stable validation fields", failures)
	TestAssertions.equal(invalid.run_player_id, &"", "failed configuration does not set run player", failures)
	TestAssertions.equal(invalid.party, null, "failed configuration does not set party", failures)
	uninitialized_party.free()

	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var original_profile := ProfileState.new_profile("profile-copy0001", "Copy Owner", 1000)
	original_profile.gold = 17
	var context := PlayerRunContext.new()
	TestAssertions.equal(context.configure(&"player_copy", 3, original_profile, 1337, party, 100), PackedStringArray(), "valid configuration succeeds", failures)
	TestAssertions.equal(context.profile_id, "profile-copy0001", "context exposes owned profile ID", failures)
	TestAssertions.equal(context.player_slot_index, 3, "context exposes player slot", failures)
	TestAssertions.equal(context.run_seed, 1337, "context exposes run seed", failures)
	TestAssertions.equal(context.experience_multiplier_percent, 100, "context exposes XP multiplier", failures)

	original_profile.gold = 99
	var exposed_profile := context.profile_snapshot
	TestAssertions.equal(exposed_profile.gold, 17, "configured profile is privately copied", failures)
	exposed_profile.gold = 123
	TestAssertions.equal(context.profile_snapshot.gold, 17, "profile getter returns a defensive copy", failures)
	var exposed_progression := context.progression_for(1)
	exposed_progression.level = 99
	exposed_progression.core_attribute_gains[&"strength"] = 99
	TestAssertions.equal(context.progression_for(1).level, 1, "progression getter isolates level", failures)
	TestAssertions.equal(context.progression_for(1).core_attribute_gains[&"strength"], 0, "progression getter isolates attributes", failures)

	var before_profile := context.profile_snapshot.to_dictionary()
	var before_progression := context.progression_for(1).to_snapshot()
	TestAssertions.equal(context.configure(&"replacement", 9, original_profile, 9999, party, 1001), PackedStringArray([
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=experience_multiplier",
	]), "out-of-range XP multiplier is rejected", failures)
	TestAssertions.equal(context.run_player_id, &"player_copy", "failed reconfiguration preserves run player", failures)
	TestAssertions.equal(context.player_slot_index, 3, "failed reconfiguration preserves slot", failures)
	TestAssertions.equal(context.profile_snapshot.to_dictionary(), before_profile, "failed reconfiguration preserves profile", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), before_progression, "failed reconfiguration preserves progression", failures)
	TestAssertions.truthy(context.party == party, "failed reconfiguration preserves party", failures)
	party.free()

func _test_atomic_progression_and_leader_queue(failures: Array[String]) -> void:
	var fixture := _configured_fixture(RejectingPartyManager.new())
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as RejectingPartyManager
	var fighter := fixture.fighter as ClassDefinition
	TestAssertions.equal(context.progression_for(1).level, 1, "leader starts at level one", failures)
	TestAssertions.equal(context.progression_for(2).level, 1, "follower starts at level one", failures)

	var events: Array[String] = []
	context.member_level_ready.connect(func(member_id: int, level: int) -> void: events.append("level:%d:%d" % [member_id, level]))
	context.progression_changed.connect(func(member_id: int) -> void: events.append("changed:%d" % member_id))
	var leader_award := context.award_experience(1, 20)
	TestAssertions.truthy(leader_award.ok(), "leader XP award succeeds", failures)
	TestAssertions.equal(context.progression_for(1).level, 2, "leader reaches level two", failures)
	TestAssertions.equal(context.progression_for(2).level, 1, "leader award leaves follower unchanged", failures)
	TestAssertions.equal(party.stats_for(1).value(&"strength"), 1.0, "fighter growth source resolves strength", failures)
	TestAssertions.equal(party.member_by_id(1).modifier_sources.size(), 1, "leader receives one cumulative growth source", failures)
	TestAssertions.equal(party.member_by_id(1).modifier_sources[0].id, &"character_growth_1", "leader growth source has stable ID", failures)
	TestAssertions.equal(context.pending_leader_levels(), [2], "leader level enters ordered queue", failures)
	TestAssertions.equal(context.current_pending_level(), 2, "current pending level is queue front", failures)
	TestAssertions.equal(events, ["level:1:2", "changed:1"], "level signal precedes one progression signal", failures)

	var exposed_queue := context.pending_leader_levels()
	exposed_queue.append(99)
	TestAssertions.equal(context.pending_leader_levels(), [2], "leader queue getter is defensive", failures)
	var follower_award := context.award_experience(2, 20)
	TestAssertions.truthy(follower_award.ok(), "follower XP award succeeds", failures)
	TestAssertions.equal(context.progression_for(2).level, 2, "follower reaches level two", failures)
	TestAssertions.equal(party.stats_for(2).value(&"dexterity"), 1.0, "Ranger follower uses Ranger growth", failures)
	TestAssertions.equal(context.pending_leader_levels(), [2], "follower does not queue an upgrade", failures)
	TestAssertions.equal(events, ["level:1:2", "changed:1", "level:2:2", "changed:2"], "follower signals remain ordered without queueing", failures)

	var stored_before := context.progression_for(1).to_snapshot()
	var queue_before := context.pending_leader_levels()
	var source_before := party.member_by_id(1).modifier_sources[0]
	var strength_before := party.stats_for(1).value(&"strength")
	var event_count_before := events.size()
	var original_growth := fighter.growth_definition
	var invalid_growth := ClassGrowthDefinition.new()
	invalid_growth.guaranteed_cycle = [&"unknown_stat"]
	invalid_growth.milestone_weights = {&"strength": 1.0}
	fighter.growth_definition = invalid_growth
	var invalid_award := context.award_experience(1, 30)
	fighter.growth_definition = original_growth
	TestAssertions.truthy(not invalid_award.ok(), "invalid class growth award fails", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), stored_before, "invalid growth preserves progression", failures)
	TestAssertions.equal(context.pending_leader_levels(), queue_before, "invalid growth preserves queue", failures)
	TestAssertions.equal(events.size(), event_count_before, "invalid growth emits no signals", failures)
	TestAssertions.equal(party.stats_for(1).value(&"strength"), strength_before, "invalid growth preserves resolved attributes", failures)
	TestAssertions.equal(party.member_by_id(1).modifier_sources[0].id, source_before.id, "invalid growth preserves source ID", failures)
	TestAssertions.equal(party.member_by_id(1).modifier_sources[0].modifiers[0].value, source_before.modifiers[0].value, "invalid growth preserves source values", failures)

	party.reject_growth_source = true
	var rejected_award := context.award_experience(1, 30)
	TestAssertions.truthy(not rejected_award.ok(), "stat-source rejection fails award", failures)
	TestAssertions.equal(rejected_award.error, "PARTY_FORGE_PROGRESSION_ERROR member=1 reason=stat source rejected", "stat-source rejection has stable diagnostic", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), stored_before, "stat-source rejection preserves progression", failures)
	TestAssertions.equal(context.pending_leader_levels(), queue_before, "stat-source rejection preserves queue", failures)
	TestAssertions.equal(events.size(), event_count_before, "stat-source rejection emits no signals", failures)
	TestAssertions.equal(party.stats_for(1).value(&"strength"), strength_before, "stat-source rejection preserves attributes", failures)

	TestAssertions.truthy(context.consume_pending_leader_level(), "queue consumption removes first level", failures)
	TestAssertions.equal(context.pending_leader_levels(), [], "leader queue is empty after consumption", failures)
	TestAssertions.equal(context.current_pending_level(), 0, "empty queue has no current level", failures)
	TestAssertions.truthy(not context.consume_pending_leader_level(), "empty queue cannot be consumed", failures)
	party.free()

func _test_future_recruits_initialize_once(failures: Array[String]) -> void:
	var fixture := _configured_fixture(PartyManager.new())
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as PartyManager
	var catalog := fixture.catalog as GameCatalog
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"cleric")), "future recruit joins party", failures)
	TestAssertions.equal(context.progression_for(3).level, 1, "future recruit receives fresh progression", failures)
	var recruit_award := context.award_experience(3, 20)
	TestAssertions.truthy(recruit_award.ok(), "future recruit progression can advance", failures)
	TestAssertions.equal(context.progression_for(3).level, 2, "future recruit reaches level two", failures)
	party.member_added.emit(party.member_by_id(3))
	TestAssertions.equal(context.progression_for(3).level, 2, "repeated member-added event cannot reset progression", failures)
	party.free()

func _test_actor_binding_availability_and_position(failures: Array[String]) -> void:
	var fixture := _configured_fixture(PartyManager.new())
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as PartyManager
	var actor := Node3D.new()
	actor.position = Vector3(3.0, 4.0, 5.0)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(100.0, true, 8.0, 0.5)
	actor.add_child(health)
	TestAssertions.truthy(not context.bind_actor(99, actor), "unknown member actor binding is rejected", failures)
	TestAssertions.truthy(context.bind_actor(1, actor), "known member actor binding succeeds", failures)
	TestAssertions.truthy(context.actor_for(1) == actor, "actor lookup returns bound actor", failures)
	TestAssertions.equal(actor.get_meta("party_forge_run_player_id"), &"player_one", "actor receives run-player ownership metadata", failures)
	TestAssertions.equal(actor.get_meta("party_forge_member_id"), 1, "actor receives member ownership metadata", failures)
	TestAssertions.truthy(context.member_is_available(1), "healthy bound member is available", failures)
	TestAssertions.equal(context.member_position(1), {"valid": true, "position": Vector3(3.0, 4.0, 5.0)}, "outside-tree member position uses local position", failures)
	health.is_downed = true
	TestAssertions.truthy(not context.member_is_available(1), "downed member is unavailable", failures)
	health.is_downed = false
	health.is_dead = true
	TestAssertions.truthy(not context.member_is_available(1), "dead member is unavailable", failures)
	TestAssertions.equal(context.member_position(99), {"valid": false}, "unknown member position is invalid", failures)

	var temporary_actor := Node3D.new()
	TestAssertions.truthy(context.bind_actor(2, temporary_actor), "follower actor binding succeeds", failures)
	temporary_actor.free()
	TestAssertions.equal(context.actor_for(2), null, "freed weak actor binding resolves null", failures)
	TestAssertions.truthy(not context.member_is_available(2), "freed actor is unavailable", failures)
	actor.free()
	party.free()

func _configured_fixture(manager: PartyManager) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var fighter := catalog.class_by_id(&"fighter")
	manager.initialize(fighter, catalog.traits)
	manager.recruit(catalog.class_by_id(&"ranger"))
	var context := PlayerRunContext.new()
	var profile := ProfileState.new_profile("profile-player01", "Player One", 1000)
	var errors := context.configure(&"player_one", 0, profile, 1337, manager, 100)
	assert(errors.is_empty())
	return {
		"catalog": catalog,
		"fighter": fighter,
		"party": manager,
		"context": context,
	}
