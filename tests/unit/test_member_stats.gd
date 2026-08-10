extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	_test_isolated_source_ownership(catalog, failures)
	_test_recruitment_invalidation_and_order(catalog, failures)
	_test_upgrade_invalidation_and_order(catalog, failures)
	_test_invalid_source_is_atomic(catalog, failures)
	_test_capabilities_and_base_projection(failures)
	_test_source_breakdown_order(catalog, failures)
	_test_action_snapshot_cache(catalog, failures)
	_test_authored_upgrade_operation_order(failures)
	return failures

func _test_action_snapshot_cache(catalog: GameCatalog, failures: Array[String]) -> void:
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
	var member_id := party.members[0].member_id
	var bow_training := StatModifierSource.create(&"bow_training", &"character", "Bow Training", member_id, [
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.50, &"bow_damage", "Bow Training", [&"projectile", &"bow"]),
	])
	TestAssertions.truthy(party.add_member_source(member_id, bow_training), "tag-required bow source registers", failures)
	TestAssertions.truthy(party.has_method("stats_for_action"), "PartyManager exposes action snapshots", failures)
	if not party.has_method("stats_for_action"):
		party.free()
		return
	var context_free := party.stats_for(member_id)
	var action_tags: Array[StringName] = [&"projectile", &"bow"]
	var reordered_tags: Array[StringName] = [&"bow", &"projectile", &"bow"]
	var action := party.call("stats_for_action", member_id, action_tags) as ResolvedStatSnapshot
	var reordered := party.call("stats_for_action", member_id, reordered_tags) as ResolvedStatSnapshot
	TestAssertions.near(context_free.value(&"damage"), 1.0, 0.001, "tag-required modifier stays out of context-free stats", failures)
	TestAssertions.near(action.value(&"damage"), 1.5, 0.001, "action tags apply required modifier", failures)
	TestAssertions.truthy(action != context_free, "action snapshot differs from context-free snapshot", failures)
	TestAssertions.equal(reordered, action, "duplicate reordered tags share normalized cache entry", failures)
	TestAssertions.truthy(party.upgrade_party_stat(&"damage"), "action-cache invalidation trigger succeeds", failures)
	var refreshed_context := party.stats_for(member_id)
	var refreshed_action := party.call("stats_for_action", member_id, action_tags) as ResolvedStatSnapshot
	TestAssertions.truthy(refreshed_context != context_free, "context-free cache invalidates", failures)
	TestAssertions.truthy(refreshed_action != action, "action cache invalidates with context-free cache", failures)
	TestAssertions.near(refreshed_action.value(&"damage"), 1.55, 0.001, "refreshed action snapshot includes party and tag modifiers", failures)
	party.free()

func _test_isolated_source_ownership(catalog: GameCatalog, failures: Array[String]) -> void:
	var ranger := catalog.class_by_id(&"ranger")
	var party := PartyManager.new()
	party.initialize(ranger, catalog.traits)
	party.recruit(ranger)
	var first_id := party.members[0].member_id
	var second_id := party.members[1].member_id
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	party.stats_for(first_id)
	party.stats_for(second_id)
	var caller := StatModifierSource.create(&"shared_training", &"character", "Shared Training", 77, [
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.25, &"personal_damage", "Shared Training", [&"martial"]),
	])
	TestAssertions.truthy(party.add_member_source(first_id, caller), "caller source registers for first member", failures)
	var first_personal := party.stats_for(first_id)
	TestAssertions.truthy(party.add_member_source(second_id, caller), "same caller source registers independently for second member", failures)
	var second_personal := party.stats_for(second_id)
	TestAssertions.equal(caller.owner_member_id, 77, "registration preserves caller ownership metadata", failures)
	TestAssertions.equal(changed, [first_id, second_id], "source registration invalidates exact recipients", failures)
	TestAssertions.near(first_personal.value(&"damage"), 1.25, 0.001, "first owned copy applies before caller mutation", failures)
	TestAssertions.near(second_personal.value(&"damage"), 1.25, 0.001, "second owned copy applies before caller mutation", failures)

	var caller_modifier := caller.modifiers[0]
	caller_modifier.value = 9.0
	caller_modifier.required_tags.append(&"blocked")
	caller.modifiers.clear()
	caller.owner_member_id = 999
	var exposed := party.member_by_id(first_id).modifier_sources
	TestAssertions.equal(exposed.size(), 1, "defensive source exposure contains owned source", failures)
	if not exposed.is_empty():
		exposed[0].owner_member_id = 999
		if not exposed[0].modifiers.is_empty():
			exposed[0].modifiers[0].value = 5.0
			exposed[0].modifiers[0].required_tags.append(&"blocked")
			exposed[0].modifiers.clear()
		exposed.clear()
	var owned_after_mutation := party.member_by_id(first_id).modifier_sources
	TestAssertions.equal(owned_after_mutation.size(), 1, "exposed array mutation cannot clear manager storage", failures)
	if not owned_after_mutation.is_empty():
		TestAssertions.equal(owned_after_mutation[0].owner_member_id, first_id, "owned copy retains first member identity", failures)
		TestAssertions.equal(owned_after_mutation[0].modifiers.size(), 1, "owned source ignores exposed modifier array mutation", failures)
		TestAssertions.equal(owned_after_mutation[0].modifiers[0].value, 0.25, "owned modifier ignores exposed and caller mutation", failures)
		TestAssertions.equal(owned_after_mutation[0].modifiers[0].required_tags, [&"martial"], "owned modifier tags are isolated", failures)
	TestAssertions.equal(changed, [first_id, second_id], "external mutations emit no synthetic stat events", failures)

	var first_revision := first_personal.revision
	var second_revision := second_personal.revision
	TestAssertions.truthy(party.rank_up(&"ranger"), "shared Ranger rank increases after external mutation", failures)
	var first_ranked := party.stats_for(first_id)
	var second_ranked := party.stats_for(second_id)
	TestAssertions.equal(changed, [first_id, second_id, first_id, second_id], "later shared invalidation has deterministic recipients", failures)
	TestAssertions.truthy(first_ranked.revision > first_revision, "later invalidation refreshes first owned copy", failures)
	TestAssertions.truthy(second_ranked.revision > second_revision, "later invalidation refreshes second owned copy", failures)
	TestAssertions.near(first_ranked.value(&"damage"), 1.45, 0.001, "first owned copy remains deterministic after invalidation", failures)
	TestAssertions.near(second_ranked.value(&"damage"), 1.45, 0.001, "second owned copy remains deterministic after invalidation", failures)

	var event_count := changed.size()
	TestAssertions.equal(party.stats_for(9999), null, "unknown member has no snapshot", failures)
	TestAssertions.truthy(not party.add_member_source(9999, caller), "unknown member rejects source", failures)
	TestAssertions.equal(changed.size(), event_count, "unknown member emits no stat event", failures)
	party.free()

func _test_recruitment_invalidation_and_order(catalog: GameCatalog, failures: Array[String]) -> void:
	var ranger := catalog.class_by_id(&"ranger")
	var unchanged := PartyManager.new()
	var unchanged_events: Array[String] = []
	unchanged.stats_changed.connect(func(member_id: int) -> void: unchanged_events.append("stats:%d" % member_id))
	unchanged.active_traits_changed.connect(func(_tiers: Dictionary) -> void: unchanged_events.append("traits"))
	unchanged.member_added.connect(func(member: PartyMemberState) -> void: unchanged_events.append("member:%d" % member.member_id))
	unchanged.initialize(ranger, [])
	var unchanged_before := unchanged.stats_for(1)
	TestAssertions.truthy(unchanged.recruit(ranger), "unchanged-tier recruit succeeds", failures)
	var unchanged_first := unchanged.stats_for(1)
	var unchanged_second := unchanged.stats_for(2)
	TestAssertions.equal(unchanged_events, ["stats:1", "member:1", "stats:1", "stats:2", "member:2"], "unchanged tiers invalidate once before member signals", failures)
	TestAssertions.equal(unchanged_first.revision, unchanged_before.revision + 1, "unchanged-tier recruit advances one revision", failures)
	TestAssertions.equal(unchanged_second.revision, unchanged_first.revision, "unchanged-tier recruit shares one revision", failures)
	unchanged.free()

	var changed := PartyManager.new()
	var changed_events: Array[String] = []
	changed.stats_changed.connect(func(member_id: int) -> void: changed_events.append("stats:%d" % member_id))
	changed.active_traits_changed.connect(func(_tiers: Dictionary) -> void: changed_events.append("traits"))
	changed.member_added.connect(func(member: PartyMemberState) -> void: changed_events.append("member:%d" % member.member_id))
	changed.initialize(ranger, catalog.traits)
	var changed_before := changed.stats_for(1)
	TestAssertions.truthy(changed.recruit(ranger), "changed-tier recruit succeeds", failures)
	var changed_first := changed.stats_for(1)
	var changed_second := changed.stats_for(2)
	TestAssertions.equal(changed_events, ["stats:1", "member:1", "stats:1", "stats:2", "traits", "member:2"], "tier change emits stats then traits then member exactly once", failures)
	TestAssertions.equal(changed_first.revision, changed_before.revision + 1, "changed-tier recruit advances one revision", failures)
	TestAssertions.equal(changed_second.revision, changed_first.revision, "changed-tier recruit shares one revision", failures)
	changed.free()

func _test_upgrade_invalidation_and_order(catalog: GameCatalog, failures: Array[String]) -> void:
	var ranger := catalog.class_by_id(&"ranger")
	var party := PartyManager.new()
	party.initialize(ranger, catalog.traits)
	party.recruit(ranger)
	var first_id := party.members[0].member_id
	var second_id := party.members[1].member_id
	var events: Array[String] = []
	var callback_snapshots: Array[ResolvedStatSnapshot] = []
	party.stats_changed.connect(func(member_id: int) -> void: events.append("stats:%d" % member_id))
	party.upgrades_changed.connect(func() -> void:
		events.append("upgrades")
		callback_snapshots.append(party.stats_for(first_id))
		callback_snapshots.append(party.stats_for(second_id))
	)

	var party_before := party.stats_for(first_id)
	party.stats_for(second_id)
	TestAssertions.truthy(party.upgrade_party_stat(&"damage"), "party damage upgrade succeeds", failures)
	TestAssertions.equal(events, ["stats:1", "stats:2", "upgrades"], "party upgrade invalidates before public signal", failures)
	TestAssertions.truthy(callback_snapshots[0].revision > party_before.revision, "party callback sees fresh first snapshot", failures)
	TestAssertions.near(callback_snapshots[0].value(&"damage"), 1.05, 0.001, "party callback sees upgraded first damage", failures)
	TestAssertions.near(callback_snapshots[1].value(&"damage"), 1.05, 0.001, "party callback sees upgraded second damage", failures)

	var trait_before := callback_snapshots[0]
	events.clear()
	TestAssertions.truthy(party.upgrade_trait(&"martial"), "active trait upgrade succeeds", failures)
	TestAssertions.equal(events, ["stats:1", "stats:2", "upgrades"], "trait upgrade invalidates before public signal", failures)
	TestAssertions.truthy(callback_snapshots[2].revision > trait_before.revision, "trait callback sees fresh first snapshot", failures)
	TestAssertions.near(callback_snapshots[2].value(&"attack_speed"), 1.19, 0.001, "trait callback sees upgraded first attack speed", failures)
	TestAssertions.near(callback_snapshots[3].value(&"attack_speed"), 1.19, 0.001, "trait callback sees upgraded second attack speed", failures)
	party.free()

func _test_invalid_source_is_atomic(catalog: GameCatalog, failures: Array[String]) -> void:
	var ranger := catalog.class_by_id(&"ranger")
	var party := PartyManager.new()
	party.initialize(ranger, catalog.traits)
	var member_id := party.members[0].member_id
	var changed: Array[int] = []
	party.stats_changed.connect(func(changed_id: int) -> void: changed.append(changed_id))
	var before := party.stats_for(member_id)
	var before_sources := party.member_by_id(member_id).modifier_sources
	var invalid := StatModifierSource.create(&"invalid", &"character", "Invalid", 44, [
		StatModifier.create(&"missing_stat", StatModifier.Operation.FLAT, 1.0, &"missing", "Missing"),
	])
	TestAssertions.truthy(not party.add_member_source(member_id, invalid), "validator-invalid known-member source is rejected", failures)
	var after := party.stats_for(member_id)
	TestAssertions.equal(invalid.owner_member_id, 44, "invalid registration preserves caller owner", failures)
	TestAssertions.equal(party.member_by_id(member_id).modifier_sources.size(), before_sources.size(), "invalid registration preserves managed sources", failures)
	TestAssertions.equal(after, before, "invalid registration preserves cached snapshot identity", failures)
	TestAssertions.equal(after.revision, before.revision, "invalid registration preserves revision", failures)
	TestAssertions.equal(changed, [], "invalid registration emits no stat event", failures)
	party.free()

func _test_capabilities_and_base_projection(failures: Array[String]) -> void:
	var definition := ClassDefinition.new()
	definition.id = &"projection"
	definition.capability_tags = [&"ranged", &"martial"]
	definition.traits = [&"martial", &"ranged", &"martial"]
	definition.max_health = 125.0
	definition.armor = 7.0
	definition.move_speed = 8.0
	definition.base_stat_overrides = {&"max_health": 150.0, &"damage": 2.0, &"nested": {"value": 1}}
	var member := PartyMemberState.new(3, definition, false)
	definition.capability_tags.append(&"caller_mutation")
	TestAssertions.equal(member.capability_tags, [&"ranged", &"martial"], "capabilities copy and trait merge deduplicate", failures)
	var values := definition.stat_base_values()
	TestAssertions.near(float(values[&"max_health"]), 150.0, 0.001, "base override wins legacy health", failures)
	TestAssertions.near(float(values[&"armor"]), 7.0, 0.001, "legacy armor projects when not overridden", failures)
	TestAssertions.near(float(values[&"move_speed"]), 8.0, 0.001, "legacy move speed projects when not overridden", failures)
	TestAssertions.near(float(values[&"damage"]), 2.0, 0.001, "custom base override is preserved", failures)
	values[&"damage"] = 99.0
	values[&"nested"]["value"] = 99
	var fresh_values := definition.stat_base_values()
	TestAssertions.near(float(fresh_values[&"damage"]), 2.0, 0.001, "base projection returns a fresh dictionary", failures)
	TestAssertions.equal(fresh_values[&"nested"]["value"], 1, "base projection deep-copies nested overrides", failures)

func _test_source_breakdown_order(catalog: GameCatalog, failures: Array[String]) -> void:
	var ranger := catalog.class_by_id(&"ranger")
	var party := PartyManager.new()
	party.initialize(ranger, catalog.traits)
	party.recruit(ranger)
	var member_id := party.members[0].member_id
	var personal := StatModifierSource.create(&"ordered_personal", &"character", "Ordered Personal", 0, [
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.10, &"personal_damage", "Personal Damage"),
		StatModifier.create(&"attack_speed", StatModifier.Operation.INCREASED, 0.10, &"personal_attack_speed", "Personal Attack Speed"),
	])
	TestAssertions.truthy(party.add_member_source(member_id, personal), "ordered member source registers", failures)
	TestAssertions.truthy(party.rank_up(&"ranger"), "ordered class rank increases", failures)
	TestAssertions.truthy(party.upgrade_party_stat(&"damage"), "ordered party damage increases", failures)
	TestAssertions.truthy(party.upgrade_party_stat(&"attack_speed"), "ordered party attack speed increases", failures)
	var snapshot := party.stats_for(member_id)
	TestAssertions.equal(_source_ids(snapshot, &"damage"), [&"base", &"class_rank_ranger", &"personal_damage", &"party_damage"], "damage breakdown orders class member party layers", failures)
	TestAssertions.equal(_source_ids(snapshot, &"attack_speed"), [&"base", &"personal_attack_speed", &"party_attack_speed", &"martial", &"attribute_projection_1_attack_speed"], "attack speed breakdown orders member party trait and derived layers", failures)
	party.free()

func _source_ids(snapshot: ResolvedStatSnapshot, stat_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for row: Dictionary in snapshot.breakdown(stat_id):
		ids.append(row["source_id"] as StringName)
	return ids

func _test_authored_upgrade_operation_order(failures: Array[String]) -> void:
	var definition := ClassDefinition.new()
	definition.id = &"operation_fixture"
	definition.base_stat_overrides = {&"damage": 100.0}
	definition.primary_attack = load("res://data/attacks/fighter_cleave.tres") as AttackDefinition
	var party := PartyManager.new()
	var no_traits: Array[TraitDefinition] = []
	party.initialize(definition, no_traits)
	var card := UpgradeDefinition.new()
	card.id = &"operation_matrix"
	card.display_name = "Operation Matrix"
	card.summary = "Fixture"
	card.description = "Fixture"
	card.tooltip_keyword_ids = [&"damage"]
	card.effects = [
		_upgrade_effect(&"damage", StatModifier.Operation.FLAT, 20.0),
		_upgrade_effect(&"damage", StatModifier.Operation.INCREASED, 0.50),
		_upgrade_effect(&"damage", StatModifier.Operation.REDUCED, 0.10),
		_upgrade_effect(&"damage", StatModifier.Operation.MORE, 0.20),
		_upgrade_effect(&"damage", StatModifier.Operation.LESS, 0.25),
	]
	var catalog := GameCatalog.load_defaults()
	catalog.upgrades.append(card)
	TestAssertions.truthy(UpgradeApplicationService.apply(card.id, catalog, party, 1), "all-operation authored upgrade applies", failures)
	var snapshot := party.stats_for(1)
	TestAssertions.near(snapshot.value(&"damage"), 151.2, 0.001, "flat increased reduced more less preserve resolver order", failures)
	var rows := snapshot.breakdown(&"damage").filter(func(row: Dictionary) -> bool: return row.get("source_id", &"") == &"upgrade:operation_matrix:member:1")
	TestAssertions.equal(rows.size(), 5, "all authored operations retain stable source id", failures)
	TestAssertions.truthy(rows.all(func(row: Dictionary) -> bool: return row.get("source_label", "") == "Operation Matrix Rank 1"), "all authored operations retain card-rank label", failures)
	party.free()

func _upgrade_effect(stat_id: StringName, operation: int, value: float) -> StatUpgradeEffect:
	var effect := StatUpgradeEffect.new()
	effect.stat_id = stat_id
	effect.operation = operation
	effect.value_per_rank = value
	return effect
