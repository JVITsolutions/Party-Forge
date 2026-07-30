extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_personal_ranks_sources_and_preview(failures)
	_test_eligibility_and_clean_rejection(failures)
	_test_matching_party_current_and_future(failures)
	_test_projectile_action_only(failures)
	_test_atomic_invalid_multi_effect(failures)
	return failures

func _test_personal_ranks_sources_and_preview(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var fighter := catalog.class_by_id(&"fighter")
	var party := PartyManager.new()
	party.initialize(fighter, catalog.traits)
	party.recruit(fighter)
	var first_id := party.members[0].member_id
	var second_id := party.members[1].member_id
	var vitality := catalog.upgrade_by_id(&"vitality")

	var preview := UpgradeApplicationService.preview_values(vitality, party, first_id)
	var health_preview := _preview_row(preview, &"max_health")
	TestAssertions.near(float(health_preview.get("before", 0.0)), 260.0, 0.001, "preview starts from live fighter health", failures)
	TestAssertions.near(float(health_preview.get("after", 0.0)), 281.0, 0.001, "preview resolves prospective vitality rank", failures)
	TestAssertions.equal(party.upgrade_rank(&"vitality", first_id), 0, "preview does not mutate personal rank", failures)
	TestAssertions.equal(party.members[0].modifier_sources.size(), 0, "preview does not mutate personal sources", failures)

	TestAssertions.truthy(UpgradeApplicationService.apply(&"vitality", catalog, party, first_id), "first fighter takes vitality rank one", failures)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"vitality", catalog, party, first_id), "first fighter takes vitality rank two", failures)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"vitality", catalog, party, second_id), "second fighter takes independent vitality rank one", failures)
	TestAssertions.equal(party.upgrade_rank(&"vitality", first_id), 2, "first duplicate fighter owns rank two", failures)
	TestAssertions.equal(party.upgrade_rank(&"vitality", second_id), 1, "second duplicate fighter owns rank one", failures)
	TestAssertions.near(party.stats_for(first_id).value(&"max_health"), 302.0, 0.001, "first fighter resolves cumulative vitality", failures)
	TestAssertions.near(party.stats_for(second_id).value(&"max_health"), 281.0, 0.001, "second fighter resolves its own vitality", failures)
	TestAssertions.equal(_upgrade_source_count(party.members[0], &"upgrade:vitality:member:1"), 1, "repeated rank replaces one stable personal source", failures)
	var vitality_row := _breakdown_row(party.stats_for(first_id), &"max_health", &"upgrade:vitality:member:1")
	TestAssertions.equal(vitality_row.get("source_label", ""), "Vitality Rank 2", "breakdown label names exact card and rank", failures)

	for expected_rank: int in range(3, 6):
		TestAssertions.truthy(UpgradeApplicationService.apply(&"vitality", catalog, party, first_id), "vitality reaches rank %d" % expected_rank, failures)
	TestAssertions.truthy(not UpgradeApplicationService.apply(&"vitality", catalog, party, first_id), "vitality rejects rank above cap", failures)
	TestAssertions.equal(party.upgrade_rank(&"vitality", first_id), 5, "failed cap application preserves max rank", failures)
	TestAssertions.equal(_upgrade_source_count(party.members[0], &"upgrade:vitality:member:1"), 1, "cap rejection preserves one cumulative source", failures)
	party.free()

func _test_eligibility_and_clean_rejection(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"marksman"))
	var deadeye := catalog.upgrade_by_id(&"deadeye")
	TestAssertions.equal(UpgradeApplicationService.eligible_member_ids(deadeye, party), [2], "Deadeye only lists the Marksman", failures)
	TestAssertions.truthy(not UpgradeApplicationService.eligibility_reason(deadeye, party, 1).is_empty(), "fighter receives an ineligibility reason", failures)
	TestAssertions.equal(UpgradeApplicationService.eligibility_reason(deadeye, party, 2), "", "marksman is eligible without a rejection reason", failures)
	TestAssertions.truthy(not UpgradeApplicationService.apply(&"deadeye", catalog, party, 1), "Deadeye rejects Fighter", failures)
	TestAssertions.equal(party.upgrade_rank(&"deadeye", 1), 0, "ineligible Fighter rank stays unchanged", failures)
	TestAssertions.equal(party.members[0].modifier_sources.size(), 0, "ineligible Fighter sources stay unchanged", failures)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"deadeye", catalog, party, 2), "Deadeye applies to Marksman", failures)
	TestAssertions.near(party.stats_for(2).value(&"physical_damage"), 1.3, 0.001, "Deadeye resolves thirty percent more physical damage", failures)
	TestAssertions.truthy(not UpgradeApplicationService.apply(&"missing_upgrade", catalog, party, 2), "unknown upgrade id rejects cleanly", failures)
	TestAssertions.truthy(not UpgradeApplicationService.apply(&"vitality", catalog, party, 999), "stale recipient rejects cleanly", failures)
	TestAssertions.truthy(not UpgradeApplicationService.eligibility_reason(catalog.upgrade_by_id(&"vitality"), party, 999).is_empty(), "stale recipient has a reason", failures)
	party.free()

func _test_matching_party_current_and_future(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"ranger"))
	TestAssertions.truthy(UpgradeApplicationService.apply(&"vanguard_wall", catalog, party), "Vanguard Wall applies to the party", failures)
	TestAssertions.equal(party.upgrade_rank(&"vanguard_wall"), 1, "matching-party rank is owned once", failures)
	TestAssertions.near(party.stats_for(1).value(&"armor"), 13.0, 0.001, "current Vanguard gains armor", failures)
	TestAssertions.near(party.stats_for(1).value(&"max_health"), 286.0, 0.001, "current Vanguard gains health", failures)
	TestAssertions.near(party.stats_for(2).value(&"armor"), 1.0, 0.001, "ineligible current Ranger is unchanged", failures)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"paladin")), "future Vanguard recruit succeeds", failures)
	TestAssertions.near(party.stats_for(3).value(&"armor"), 21.0, 0.001, "future Vanguard inherits party source", failures)
	TestAssertions.near(party.stats_for(3).value(&"max_health"), 242.0, 0.001, "future Vanguard inherits health effect", failures)
	var wall_row := _breakdown_row(party.stats_for(3), &"armor", &"upgrade:vanguard_wall:party")
	TestAssertions.equal(wall_row.get("source_label", ""), "Vanguard Wall Rank 1", "party breakdown has stable card-rank label", failures)
	TestAssertions.truthy(not UpgradeApplicationService.apply(&"vanguard_wall", catalog, party), "one-time matching-party card enforces cap", failures)
	party.free()

func _test_projectile_action_only(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
	var member_id := party.members[0].member_id
	var definition := catalog.upgrade_by_id(&"projectile_mastery")
	var before_snapshot := party.stats_for(member_id)
	var preview := UpgradeApplicationService.preview_values(definition, party, member_id)
	TestAssertions.near(float(_preview_row(preview, &"projectile_speed").get("after", 0.0)), 1.12, 0.001, "preview includes unrestricted projectile speed", failures)
	TestAssertions.near(float(_preview_row(preview, &"damage").get("after", 0.0)), 1.08, 0.001, "preview resolves damage in required projectile context", failures)
	TestAssertions.equal(party.stats_for(member_id), before_snapshot, "preview preserves cached live snapshot", failures)
	TestAssertions.equal(party.upgrade_rank(&"projectile_mastery", member_id), 0, "preview preserves projectile rank", failures)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"projectile_mastery", catalog, party, member_id), "Projectile Mastery applies to Ranger", failures)
	TestAssertions.near(party.stats_for(member_id).value(&"projectile_speed"), 1.12, 0.001, "projectile speed applies without action context", failures)
	TestAssertions.near(party.stats_for(member_id).value(&"damage"), 1.0, 0.001, "action-only damage stays out of context-free stats", failures)
	TestAssertions.near(party.stats_for_action(member_id, [&"projectile"]).value(&"damage"), 1.08, 0.001, "projectile action receives action-only damage", failures)
	TestAssertions.near(party.stats_for_action(member_id, [&"melee"]).value(&"damage"), 1.0, 0.001, "nonprojectile action excludes action-only damage", failures)
	party.free()

func _test_atomic_invalid_multi_effect(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var invalid := UpgradeDefinition.new()
	invalid.id = &"invalid_multi"
	invalid.display_name = "Invalid Multi"
	invalid.summary = "Fixture"
	invalid.description = "Fixture"
	invalid.tooltip_keyword_ids = [&"armor"]
	invalid.max_rank = 2
	invalid.effects = [_effect(&"armor", StatModifier.Operation.FLAT, 2.0), _effect(&"missing_stat", StatModifier.Operation.INCREASED, 0.5)]
	catalog.upgrades.append(invalid)
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var before := party.stats_for(1)
	var before_sources := party.members[0].modifier_sources
	TestAssertions.truthy(not UpgradeApplicationService.apply(&"invalid_multi", catalog, party, 1), "invalid multi-effect application rejects", failures)
	TestAssertions.equal(party.upgrade_rank(&"invalid_multi", 1), 0, "invalid multi-effect preserves rank", failures)
	TestAssertions.equal(party.members[0].modifier_sources, before_sources, "invalid multi-effect preserves sources", failures)
	TestAssertions.equal(party.stats_for(1), before, "invalid multi-effect preserves cached snapshot", failures)
	party.free()

func _effect(stat_id: StringName, operation: int, value: float) -> StatUpgradeEffect:
	var effect := StatUpgradeEffect.new()
	effect.stat_id = stat_id
	effect.operation = operation
	effect.value_per_rank = value
	effect.source_label = "Fixture"
	return effect

func _preview_row(rows: Array[Dictionary], stat_id: StringName) -> Dictionary:
	for row: Dictionary in rows:
		if row.get("stat_id", &"") == stat_id:
			return row
	return {}

func _breakdown_row(snapshot: ResolvedStatSnapshot, stat_id: StringName, source_id: StringName) -> Dictionary:
	for row: Dictionary in snapshot.breakdown(stat_id):
		if row.get("source_id", &"") == source_id:
			return row
	return {}

func _upgrade_source_count(member: PartyMemberState, source_id: StringName) -> int:
	return member.modifier_sources.filter(func(source: StatModifierSource) -> bool: return source.id == source_id).size()
