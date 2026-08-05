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
	_test_configuration_rejects_invalid_member_growth_atomically(failures)
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
	TestAssertions.truthy(invalid.has_method(&"item_state"), "run context exposes item state after Task 7", failures)
	TestAssertions.truthy(invalid.has_method(&"run_inventory"), "run context exposes run inventory after Task 7", failures)
	TestAssertions.truthy(invalid.has_method(&"apply_item_transaction"), "run context exposes item transactions after Task 7", failures)
	if invalid.has_method(&"item_state"):
		TestAssertions.equal(invalid.call(&"item_state"), null, "failed configuration commits no item state", failures)
	if invalid.has_method(&"run_inventory"):
		TestAssertions.equal(invalid.call(&"run_inventory"), null, "failed configuration commits no run inventory", failures)
	var retry_issue := ItemInstanceIssuer.issue(
		"run:profile-retry001:4004:retry_player",
		0,
		"configuration_retry_test",
		4004,
		{
			"affixes": [],
			"base_definition_id": "forge_vanguard_sword",
			"item_level": 1,
			"rarity_id": "common",
		},
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(retry_issue.ok(), "configuration retry item fixture issues", failures)
	var retry_request := ItemTransactionRequest.create(
		"configuration-retry-create",
		"retry_player",
		&"run-inventory",
		0,
		retry_issue.item,
	)
	if invalid.has_method(&"apply_item_transaction"):
		var unconfigured_result := invalid.call(
			&"apply_item_transaction",
			retry_request,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
		) as ItemTransactionResult
		TestAssertions.equal(unconfigured_result.code, ItemTransactionResult.Code.INVALID_REQUEST, "failed configuration has no usable transaction journal", failures)
	uninitialized_party.free()
	var retry_party := PartyManager.new()
	retry_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var retry_profile := ProfileState.new_profile("profile-retry001", "Retry Owner", 1000)
	retry_profile.inventory_columns = 1
	TestAssertions.equal(
		invalid.configure(&"retry_player", 4, retry_profile, 4004, retry_party, 100),
		PackedStringArray(),
		"failed initial configuration remains retryable",
		failures,
	)
	if invalid.has_method(&"item_state") and invalid.has_method(&"run_inventory"):
		var retry_state := invalid.call(&"item_state") as ItemOwnershipState
		var retry_inventory := invalid.call(&"run_inventory") as ItemSlotContainer
		TestAssertions.truthy(retry_state != null, "valid retry creates one item ownership state", failures)
		TestAssertions.equal(retry_state.registry().size(), 0, "valid retry creates one empty run registry", failures)
		TestAssertions.equal(retry_state.containers().size(), 1, "valid retry creates exactly one run container", failures)
		TestAssertions.equal(retry_inventory.capacity, 5, "valid retry derives its unlocked five-slot inventory", failures)
		var retry_created := invalid.call(
			&"apply_item_transaction",
			retry_request,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
		) as ItemTransactionResult
		var retry_replayed := invalid.call(
			&"apply_item_transaction",
			retry_request,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
		) as ItemTransactionResult
		TestAssertions.equal(retry_created.code, ItemTransactionResult.Code.OK, "valid configuration retry creates the item exactly once", failures)
		TestAssertions.equal(retry_replayed.code, ItemTransactionResult.Code.TRANSACTION_REPLAY, "valid configuration retry owns one replay journal entry", failures)
		TestAssertions.equal((invalid.call(&"item_state") as ItemOwnershipState).registry().size(), 1, "configuration retry journal cannot duplicate the item", failures)
	retry_party.free()

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
	var actor := Node3D.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(100.0, true, 8.0, 0.5)
	actor.add_child(health)
	TestAssertions.truthy(context.bind_actor(1, actor), "configured context binds its leader actor", failures)
	TestAssertions.truthy(context.award_experience(1, 20).ok(), "configured context can establish progression and queue state", failures)
	var registry := RunContextRegistry.new()
	TestAssertions.truthy(registry.register_context(context).ok(), "configured context registers before immutability checks", failures)
	var distributor := RewardDistributionService.new()
	TestAssertions.equal(
		distributor.configure(registry, load("res://data/progression/reward_distribution.tres") as RewardDistributionTuning),
		PackedStringArray(),
		"reward distributor configures for identity immutability",
		failures,
	)
	var identity_packet := RewardPacket.create(&"identity_immutable_packet", 1, Vector3.ZERO)
	TestAssertions.equal(
		distributor.distribute(identity_packet).awarded_members,
		PackedStringArray(["player_copy:1"]),
		"identity packet resolves under the configured run-player ID",
		failures,
	)

	var before_profile := context.profile_snapshot.to_dictionary()
	var before_progression := context.progression_for(1).to_snapshot()
	var before_queue := context.pending_leader_levels()
	TestAssertions.equal(context.configure(&"replacement", 9, original_profile, 9999, party, 1001), PackedStringArray([
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=configuration reason=already configured",
	]), "invalid reconfiguration is rejected by the single-configuration invariant", failures)
	TestAssertions.equal(context.run_player_id, &"player_copy", "failed reconfiguration preserves run player", failures)
	TestAssertions.equal(context.player_slot_index, 3, "failed reconfiguration preserves slot", failures)
	TestAssertions.equal(context.profile_snapshot.to_dictionary(), before_profile, "failed reconfiguration preserves profile", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), before_progression, "failed reconfiguration preserves progression", failures)
	TestAssertions.equal(context.pending_leader_levels(), before_queue, "failed reconfiguration preserves leader queue", failures)
	TestAssertions.truthy(context.actor_for(1) == actor, "failed reconfiguration preserves actor bindings", failures)
	TestAssertions.truthy(context.party == party, "failed reconfiguration preserves party", failures)

	var replacement_party := PartyManager.new()
	replacement_party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
	var replacement_profile := ProfileState.new_profile("profile-replacement", "Replacement", 2000)
	TestAssertions.equal(context.configure(&"replacement", 9, replacement_profile, 9999, replacement_party, 250), PackedStringArray([
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=configuration reason=already configured",
	]), "valid reconfiguration is rejected by the single-configuration invariant", failures)
	TestAssertions.equal(context.run_player_id, &"player_copy", "valid reconfiguration cannot mutate run player", failures)
	TestAssertions.equal(context.player_slot_index, 3, "valid reconfiguration cannot mutate slot", failures)
	TestAssertions.equal(context.profile_snapshot.to_dictionary(), before_profile, "valid reconfiguration cannot mutate profile", failures)
	TestAssertions.equal(context.run_seed, 1337, "valid reconfiguration cannot mutate run seed", failures)
	TestAssertions.equal(context.experience_multiplier_percent, 100, "valid reconfiguration cannot mutate XP multiplier", failures)
	TestAssertions.truthy(context.party == party, "valid reconfiguration cannot replace the owned party", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), before_progression, "valid reconfiguration cannot reset progression", failures)
	TestAssertions.equal(context.pending_leader_levels(), before_queue, "valid reconfiguration cannot clear leader queue", failures)
	TestAssertions.truthy(context.actor_for(1) == actor, "valid reconfiguration cannot clear actor bindings", failures)
	TestAssertions.truthy(registry.context_for(&"player_copy") == context, "registry lookup remains coherent under the original identity", failures)
	TestAssertions.equal(registry.context_for(&"replacement"), null, "registry gains no lookup for a rejected identity", failures)
	TestAssertions.truthy(distributor.has_resolved(&"identity_immutable_packet", &"player_copy"), "reward idempotency retains the original identity key", failures)
	TestAssertions.truthy(not distributor.has_resolved(&"identity_immutable_packet", &"replacement"), "reward idempotency gains no drifted identity key", failures)
	TestAssertions.equal(distributor.distribute(identity_packet), {
		"awarded_members": PackedStringArray(),
		"skipped_contexts": PackedStringArray(),
		"errors": PackedStringArray(),
	}, "same packet remains idempotent after rejected reconfiguration", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), before_progression, "idempotent retry leaves progression unchanged", failures)
	replacement_party.free()
	actor.free()
	party.free()

func _test_configuration_rejects_invalid_member_growth_atomically(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var missing_party := PartyManager.new()
	missing_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var missing_growth_class := catalog.class_by_id(&"ranger").duplicate(true) as ClassDefinition
	missing_growth_class.growth_definition = null
	TestAssertions.truthy(missing_party.recruit(missing_growth_class), "missing-growth follower joins the fixture party", failures)
	var missing_context := PlayerRunContext.new()
	var missing_signals: Array[String] = []
	missing_context.member_level_ready.connect(func(member_id: int, level: int) -> void: missing_signals.append("level:%d:%d" % [member_id, level]))
	missing_context.progression_changed.connect(func(member_id: int) -> void: missing_signals.append("changed:%d" % member_id))
	TestAssertions.equal(
		missing_context.configure(
			&"missing_growth_player",
			2,
			ProfileState.new_profile("profile-missing-growth", "Missing Growth", 3000),
			3003,
			missing_party,
			100,
		),
		PackedStringArray([
			"PARTY_FORGE_RUN_CONTEXT_ERROR field=party member=2 reason=growth definition missing",
		]),
		"a missing member growth definition prevents context configuration",
		failures,
	)
	_assert_unconfigured_context(missing_context, missing_signals, "missing growth", failures)
	TestAssertions.truthy(missing_party.recruit(catalog.class_by_id(&"cleric")), "missing-growth party can change after rejection", failures)
	TestAssertions.equal(missing_context.progression_for(3), null, "missing-growth rejection connects no member-added callback", failures)
	missing_party.free()

	var malformed_party := PartyManager.new()
	malformed_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var malformed_class := catalog.class_by_id(&"ranger").duplicate(true) as ClassDefinition
	var malformed_growth := ClassGrowthDefinition.new()
	malformed_growth.guaranteed_cycle = [&"damage"]
	malformed_growth.milestone_weights = {&"strength": 0.0}
	malformed_class.growth_definition = malformed_growth
	TestAssertions.truthy(malformed_party.recruit(malformed_class), "malformed-growth follower joins the fixture party", failures)
	var malformed_context := PlayerRunContext.new()
	var malformed_signals: Array[String] = []
	malformed_context.member_level_ready.connect(func(member_id: int, level: int) -> void: malformed_signals.append("level:%d:%d" % [member_id, level]))
	malformed_context.progression_changed.connect(func(member_id: int) -> void: malformed_signals.append("changed:%d" % member_id))
	TestAssertions.equal(
		malformed_context.configure(
			&"malformed_growth_player",
			3,
			ProfileState.new_profile("profile-malformed-growth", "Malformed Growth", 4000),
			4004,
			malformed_party,
			100,
		),
		PackedStringArray([
			"PARTY_FORGE_RUN_CONTEXT_ERROR field=party member=2 reason=PARTY_FORGE_GROWTH_ERROR field=guaranteed_cycle value=damage reason=unknown core attribute",
			"PARTY_FORGE_RUN_CONTEXT_ERROR field=party member=2 reason=PARTY_FORGE_GROWTH_ERROR field=milestone_weights reason=no positive weights",
		]),
		"malformed member growth prevents context configuration with stable reasons",
		failures,
	)
	_assert_unconfigured_context(malformed_context, malformed_signals, "malformed growth", failures)
	TestAssertions.truthy(malformed_party.recruit(catalog.class_by_id(&"cleric")), "malformed-growth party can change after rejection", failures)
	TestAssertions.equal(malformed_context.progression_for(3), null, "malformed-growth rejection connects no member-added callback", failures)
	malformed_party.free()

func _assert_unconfigured_context(context: PlayerRunContext, signals: Array[String], label: String, failures: Array[String]) -> void:
	TestAssertions.equal(context.run_player_id, &"", "%s rejection preserves empty run player" % label, failures)
	TestAssertions.equal(context.player_slot_index, -1, "%s rejection preserves empty slot" % label, failures)
	TestAssertions.equal(context.profile_id, "", "%s rejection preserves empty profile ID" % label, failures)
	TestAssertions.equal(context.profile_snapshot, null, "%s rejection preserves empty profile snapshot" % label, failures)
	TestAssertions.equal(context.run_seed, 0, "%s rejection preserves empty run seed" % label, failures)
	TestAssertions.equal(context.experience_multiplier_percent, 100, "%s rejection preserves default multiplier" % label, failures)
	TestAssertions.equal(context.party, null, "%s rejection preserves empty party" % label, failures)
	TestAssertions.equal(context.progression_for(1), null, "%s rejection creates no leader progression" % label, failures)
	TestAssertions.equal(context.progression_for(2), null, "%s rejection creates no follower progression" % label, failures)
	TestAssertions.equal(context.pending_leader_levels(), [], "%s rejection creates no upgrade queue" % label, failures)
	TestAssertions.equal(signals, [], "%s rejection emits no signals" % label, failures)
	if context.has_method(&"item_state"):
		TestAssertions.equal(context.call(&"item_state"), null, "%s rejection commits no item state" % label, failures)
	if context.has_method(&"run_inventory"):
		TestAssertions.equal(context.call(&"run_inventory"), null, "%s rejection commits no run inventory" % label, failures)

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
