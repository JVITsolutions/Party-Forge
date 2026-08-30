extends RefCounted


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_direct_class_trait_and_party_stat_matrix(failures)
	_test_targeted_member_matrix_and_readable_reasons(failures)
	_test_recruitment_matrix(failures)
	_test_authored_identity_and_cap_matrix(failures)
	_test_null_authority_matrix(failures)
	return failures


func _test_direct_class_trait_and_party_stat_matrix(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := _active_vanguard_party(catalog)
	var policy := LevelUpApplicationPolicy.new()
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"fighter", "Train Fighter"), party, catalog, 0, "valid class rank", failures), true, "", "valid class rank", failures)
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"ranger", "Train Ranger"), party, catalog, 0, "unrepresented class rank", failures), false, "no longer represented", "unrepresented class rank", failures)
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"missing_class", "Missing Class"), party, catalog, 0, "missing class rank", failures), false, "no longer available", "missing class rank", failures)
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, &"vanguard", "Vanguard"), party, catalog, 0, "valid active trait", failures), true, "", "valid active trait", failures)
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, &"arcane", "Arcane"), party, catalog, 0, "inactive trait", failures), false, "no longer active", "inactive trait", failures)
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, &"missing_trait", "Missing Trait"), party, catalog, 0, "missing trait", failures), false, "no longer available", "missing trait", failures)
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage"), party, catalog, 0, "valid party stat", failures), true, "", "valid party stat", failures)
	for _rank: int in range(party.upgrade_tuning.party_stat_max_rank):
		party.upgrade_party_stat(&"damage")
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage"), party, catalog, 0, "capped party stat", failures), false, "maximum rank", "capped party stat", failures)
	party.free()


func _test_targeted_member_matrix_and_readable_reasons(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"marksman"))
	var policy := LevelUpApplicationPolicy.new()
	var deadeye := UpgradeChoice.authored(catalog.upgrade_by_id(&"deadeye"))
	_assert_result(_evaluate_pure(policy, deadeye, party, catalog, 0, "missing recipient", failures), false, "Choose an eligible party member.", "missing recipient", failures)
	_assert_result(_evaluate_pure(policy, deadeye, party, catalog, 999, "vanished recipient", failures), false, "That party member is no longer available.", "vanished recipient", failures)
	_assert_result(_evaluate_pure(policy, deadeye, party, catalog, 1, "wrong recipient class", failures), false, "Choose a party member from an eligible class.", "wrong recipient class", failures)
	var accepted := _evaluate_pure(policy, deadeye, party, catalog, 2, "valid recipient", failures)
	_assert_result(accepted, true, "", "valid recipient", failures)
	TestAssertions.equal(accepted.recipient_member_id, 2, "valid recipient keeps stable member identity", failures)
	party.free()


func _test_recruitment_matrix(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var policy := LevelUpApplicationPolicy.new()
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger"), party, catalog, 0, "valid recruit", failures), true, "", "valid recruit", failures)
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"missing_class", "Missing Recruit"), party, catalog, 0, "missing recruit", failures), false, "no longer available", "missing recruit", failures)
	party.configure_capacity(PartyCapacityPolicy.new(1))
	_assert_result(_evaluate_pure(policy, UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger"), party, catalog, 0, "full recruit", failures), false, "The party is full.", "full recruit", failures)
	party.free()


func _test_authored_identity_and_cap_matrix(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"marksman"))
	var policy := LevelUpApplicationPolicy.new()
	var current := catalog.upgrade_by_id(&"deadeye")
	var same_id_stale := current.duplicate(true) as UpgradeDefinition
	var stale_result := _evaluate_pure(policy, UpgradeChoice.authored(same_id_stale), party, catalog, 2, "same-id stale authored", failures)
	_assert_result(stale_result, false, "This offer is no longer available.", "same-id stale authored", failures)
	var missing_definition := UpgradeChoice.new(UpgradeChoice.Kind.AUTHORED, current.id, current.display_name)
	_assert_result(_evaluate_pure(policy, missing_definition, party, catalog, 2, "null authored definition", failures), false, "This offer is no longer available.", "null authored definition", failures)

	var wall := catalog.upgrade_by_id(&"vanguard_wall")
	UpgradeApplicationService.apply(wall.id, catalog, party)
	_assert_result(_evaluate_pure(policy, UpgradeChoice.authored(wall), party, catalog, 0, "capped authored", failures), false, "maximum rank", "capped authored", failures)
	party.free()


func _test_null_authority_matrix(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var policy := LevelUpApplicationPolicy.new()
	var direct := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage")
	_assert_result(_evaluate_pure(policy, null, party, catalog, 0, "null choice", failures), false, "no longer available", "null choice", failures)
	_assert_result(policy.evaluate(direct, null, catalog, 0), false, "party is no longer available", "null party", failures)
	_assert_result(_evaluate_pure(policy, direct, party, null, 0, "null catalog", failures), false, "information is no longer available", "null catalog", failures)
	party.free()


func _evaluate_pure(
	policy: LevelUpApplicationPolicy,
	choice: UpgradeChoice,
	party: PartyManager,
	catalog: GameCatalog,
	member_id: int,
	context: String,
	failures: Array[String],
) -> LevelUpApplicationResult:
	var before := _party_snapshot(party)
	var signal_counts := _observe_signals(party)
	var result := policy.evaluate(choice, party, catalog, member_id)
	TestAssertions.equal(_party_snapshot(party), before, "%s does not mutate the full party document or revisions" % context, failures)
	TestAssertions.equal(signal_counts, {"member_added": 0, "class_rank_changed": 0, "active_traits_changed": 0, "upgrades_changed": 0, "stats_changed": 0}, "%s emits no mutation signals" % context, failures)
	return result


func _assert_result(result: LevelUpApplicationResult, expected_ok: bool, reason_fragment: String, context: String, failures: Array[String]) -> void:
	TestAssertions.equal(result.ok(), expected_ok, "%s acceptance" % context, failures)
	if expected_ok:
		TestAssertions.equal(result.reason, "", "%s accepted result has no rejection reason" % context, failures)
		return
	TestAssertions.truthy(not result.reason.is_empty() and result.reason.ends_with("."), "%s rejection is one complete sentence" % context, failures)
	TestAssertions.truthy(reason_fragment in result.reason, "%s rejection contains readable reason '%s'" % [context, reason_fragment], failures)
	TestAssertions.truthy("PARTY_FORGE_" not in result.reason and "_" not in result.reason, "%s rejection hides diagnostics and raw ids" % context, failures)


func _observe_signals(party: PartyManager) -> Dictionary:
	var counts := {"member_added": 0, "class_rank_changed": 0, "active_traits_changed": 0, "upgrades_changed": 0, "stats_changed": 0}
	party.member_added.connect(func(_member: PartyMemberState) -> void: counts["member_added"] += 1)
	party.class_rank_changed.connect(func(_class_id: StringName, _rank: int) -> void: counts["class_rank_changed"] += 1)
	party.active_traits_changed.connect(func(_tiers: Dictionary) -> void: counts["active_traits_changed"] += 1)
	party.upgrades_changed.connect(func() -> void: counts["upgrades_changed"] += 1)
	party.stats_changed.connect(func(_member_id: int) -> void: counts["stats_changed"] += 1)
	return counts


func _party_snapshot(party: PartyManager) -> Dictionary:
	var member_rows: Array[Dictionary] = []
	for member: PartyMemberState in party.members:
		var source_rows: Array[Dictionary] = []
		for source: StatModifierSource in member.modifier_sources:
			var modifier_rows: Array[Dictionary] = []
			for modifier: StatModifier in source.modifiers:
				modifier_rows.append({
					"stat_id": modifier.stat_id, "operation": modifier.operation, "value": modifier.value,
					"source_id": modifier.source_id, "source_label": modifier.source_label,
					"required_tags": modifier.required_tags.duplicate(), "excluded_tags": modifier.excluded_tags.duplicate(),
					"required_capability_tags": modifier.required_capability_tags.duplicate(), "excluded_capability_tags": modifier.excluded_capability_tags.duplicate(),
					"required_action_tags": modifier.required_action_tags.duplicate(), "excluded_action_tags": modifier.excluded_action_tags.duplicate(),
				})
			source_rows.append({"id": source.id, "source_type": source.source_type, "label": source.label, "owner_member_id": source.owner_member_id, "modifiers": modifier_rows})
		member_rows.append({
			"member_id": member.member_id, "character_name": member.character_name,
			"class_id": member.class_definition.id, "is_leader": member.is_leader,
			"capability_tags": member.capability_tags.duplicate(), "upgrade_ranks": member.upgrade_ranks,
			"modifier_sources": source_rows,
		})
	return {
		"capacity": party.capacity(), "members": member_rows,
		"class_ranks": party.class_ranks.duplicate(true), "active_tiers": party.active_tiers.duplicate(true),
		"party_stat_ranks": party.party_stat_ranks.duplicate(true), "trait_upgrade_ranks": party.trait_upgrade_ranks.duplicate(true),
		"party_upgrade_ranks": party.party_upgrade_ranks, "stat_revision": party.get("_stat_revision"),
		"member_stat_revision": (party.get("_member_stat_revision") as Dictionary).duplicate(true),
		"stat_cache_keys": (party.get("_stat_cache") as Dictionary).keys(),
		"action_stat_cache_keys": (party.get("_action_stat_cache") as Dictionary).keys(),
	}


func _active_vanguard_party(catalog: GameCatalog) -> PartyManager:
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"fighter"))
	return party
