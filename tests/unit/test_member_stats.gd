extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	var ranger := catalog.class_by_id(&"ranger")
	var party := PartyManager.new()
	party.initialize(ranger, catalog.traits)
	party.recruit(ranger)
	var first_id := party.members[0].member_id
	var second_id := party.members[1].member_id
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	var first_before := party.stats_for(first_id)
	var second_before := party.stats_for(second_id)
	var personal := StatModifierSource.create(&"member_2_damage", &"character", "Personal Training", second_id, [
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.25, &"personal_damage", "Personal Training"),
	])
	TestAssertions.truthy(party.add_member_source(second_id, personal), "member source is accepted", failures)
	var first_personal := party.stats_for(first_id)
	var second_personal := party.stats_for(second_id)
	TestAssertions.near(first_personal.value(&"damage"), 1.0, 0.001, "first duplicate excludes second member source", failures)
	TestAssertions.near(second_personal.value(&"damage"), 1.25, 0.001, "second duplicate owns personal source", failures)
	TestAssertions.equal(first_personal.revision, first_before.revision, "unrelated member cache remains valid", failures)
	TestAssertions.truthy(second_personal.revision > second_before.revision, "owned source invalidates target member", failures)

	var first_revision := first_personal.revision
	var second_revision := second_personal.revision
	TestAssertions.truthy(party.rank_up(&"ranger"), "shared Ranger rank increases", failures)
	var first_ranked := party.stats_for(first_id)
	var second_ranked := party.stats_for(second_id)
	TestAssertions.truthy(first_ranked.revision > first_revision, "class rank invalidates first duplicate", failures)
	TestAssertions.truthy(second_ranked.revision > second_revision, "class rank invalidates second duplicate", failures)
	TestAssertions.near(first_ranked.value(&"damage"), 1.2, 0.001, "shared class rank affects first duplicate", failures)
	TestAssertions.near(second_ranked.value(&"damage"), 1.45, 0.001, "shared and personal increased damage add", failures)
	TestAssertions.truthy(_has_source(first_ranked, &"damage", &"class_rank_ranger"), "first breakdown names class rank", failures)
	TestAssertions.truthy(_has_source(second_ranked, &"damage", &"personal_damage"), "second breakdown names personal source", failures)

	var event_count := changed.size()
	TestAssertions.equal(party.stats_for(9999), null, "unknown member has no snapshot", failures)
	TestAssertions.truthy(not party.add_member_source(9999, personal), "unknown member rejects source", failures)
	TestAssertions.equal(changed.size(), event_count, "unknown member emits no stat event", failures)
	party.free()
	return failures

func _has_source(snapshot: ResolvedStatSnapshot, stat_id: StringName, source_id: StringName) -> bool:
	for row: Dictionary in snapshot.breakdown(stat_id):
		if row["source_id"] == source_id:
			return true
	return false
