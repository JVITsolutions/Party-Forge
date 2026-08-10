extends RefCounted

const ACTION_ONLY_TAG := &"task10d_action_only"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_personal_ranks_sources_and_preview(failures)
	_test_eligibility_and_clean_rejection(failures)
	_test_matching_party_current_and_future(failures)
	_test_projectile_action_only(failures)
	_test_atomic_invalid_multi_effect(failures)
	_test_party_upgrade_reverse_collision_is_transactional(failures)
	_test_party_upgrade_aggregate_overflow_is_transactional(failures)
	_test_party_upgrade_action_overflow_is_transactional(failures)
	_test_party_upgrade_late_member_rejection_is_transactional(failures)
	_test_party_upgrade_success_is_single_observable_transition(failures)
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

func _test_party_upgrade_reverse_collision_is_transactional(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var definition := catalog.upgrade_by_id(&"vanguard_wall")
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var generated_id := &"upgrade:vanguard_wall:party"
	var collision := _source(1, generated_id, [
		StatModifier.create(&"strength", StatModifier.Operation.FLAT, 2.0, generated_id, "Reserved"),
	])
	TestAssertions.truthy(party.add_member_source(1, collision), "reverse collision reserves generated ID before party upgrade", failures)
	_assert_rejected_party_upgrade_is_transactional(party, catalog, definition, collision, "reverse generated-ID collision", failures)
	party.free()

func _test_party_upgrade_aggregate_overflow_is_transactional(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var definition := _party_upgrade(&"task10s_aggregate_overflow", 1, [
		_effect(&"damage", StatModifier.Operation.INCREASED, 1.0e308),
		_effect(&"damage", StatModifier.Operation.INCREASED, 1.0e308),
	])
	catalog.upgrades.append(definition)
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_assert_rejected_party_upgrade_is_transactional(party, catalog, definition, null, "party aggregate overflow", failures)
	party.free()

func _test_party_upgrade_action_overflow_is_transactional(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var fighter := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	fighter.primary_attack = fighter.primary_attack.duplicate(true) as AttackDefinition
	fighter.primary_attack.action_tags = fighter.primary_attack.action_tags.duplicate()
	fighter.primary_attack.action_tags.append(ACTION_ONLY_TAG)
	var effects: Array[UpgradeEffectDefinition] = []
	for _index: int in 4:
		var effect := _effect(&"cooldown_rate", StatModifier.Operation.MORE, 1.0e100)
		effect.required_action_tags = [ACTION_ONLY_TAG]
		effects.append(effect)
	var definition := _party_upgrade(&"task10s_action_overflow", 1, effects)
	catalog.upgrades.append(definition)
	var party := PartyManager.new()
	party.initialize(fighter, catalog.traits)
	_assert_rejected_party_upgrade_is_transactional(party, catalog, definition, null, "party action-only overflow", failures)
	party.free()

func _test_party_upgrade_late_member_rejection_is_transactional(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var definition := _party_upgrade(&"task10s_late_member", 1, [
		_effect(&"armor", StatModifier.Operation.FLAT, 2.0),
	])
	catalog.upgrades.append(definition)
	var fighter := catalog.class_by_id(&"fighter")
	var party := PartyManager.new()
	party.initialize(fighter, catalog.traits)
	party.recruit(fighter)
	var generated_id := &"upgrade:task10s_late_member:party"
	var collision := _source(2, generated_id, [
		StatModifier.create(&"strength", StatModifier.Operation.FLAT, 1.0, generated_id, "Late Reserved"),
	])
	TestAssertions.truthy(party.add_member_source(2, collision), "later eligible member reserves generated ID", failures)
	_assert_rejected_party_upgrade_is_transactional(party, catalog, definition, collision, "later-member batch rejection", failures)
	party.free()

func _test_party_upgrade_success_is_single_observable_transition(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var definition := _party_upgrade(&"task10s_legitimate", 2, [
		_effect(&"armor", StatModifier.Operation.FLAT, 2.0),
	])
	catalog.upgrades.append(definition)
	var fighter := catalog.class_by_id(&"fighter")
	var party := PartyManager.new()
	party.initialize(fighter, catalog.traits)
	party.recruit(fighter)
	var definition_before := _upgrade_document(definition)
	var owned_before := _all_member_source_documents(party)
	var initial_armor := party.stats_for(1).value(&"armor")
	for expected_rank: int in [1, 2]:
		var revision_before := party.stat_revision()
		var base_before: Dictionary = {}
		var action_before: Dictionary = {}
		for member: PartyMemberState in party.members:
			base_before[member.member_id] = party.stats_for(member.member_id)
			action_before[member.member_id] = party.stats_for_action(member.member_id, member.class_definition.primary_attack.action_tags)
		var stat_events: Array[int] = []
		var upgrade_events: Array[bool] = []
		party.stats_changed.connect(func(member_id: int) -> void: stat_events.append(member_id), CONNECT_ONE_SHOT if party.members.size() == 1 else 0)
		party.upgrades_changed.connect(func() -> void: upgrade_events.append(true), CONNECT_ONE_SHOT)
		TestAssertions.truthy(UpgradeApplicationService.apply(definition.id, catalog, party), "legitimate party upgrade rank %d succeeds" % expected_rank, failures)
		TestAssertions.equal(party.upgrade_rank(definition.id), expected_rank, "legitimate party upgrade stores rank %d" % expected_rank, failures)
		TestAssertions.equal(party.stat_revision(), revision_before + 1, "rank %d advances one revision" % expected_rank, failures)
		TestAssertions.equal(stat_events, [1, 2], "rank %d emits one ordered stat invalidation per member" % expected_rank, failures)
		TestAssertions.equal(upgrade_events, [true], "rank %d emits one upgrades-changed signal" % expected_rank, failures)
		for member: PartyMemberState in party.members:
			TestAssertions.truthy(not is_same(party.stats_for(member.member_id), base_before[member.member_id]), "rank %d replaces member %d base cache" % [expected_rank, member.member_id], failures)
			TestAssertions.truthy(not is_same(party.stats_for_action(member.member_id, member.class_definition.primary_attack.action_tags), action_before[member.member_id]), "rank %d replaces member %d action cache" % [expected_rank, member.member_id], failures)
		TestAssertions.near(party.stats_for(1).value(&"armor"), initial_armor + float(expected_rank * 2), 0.001, "rank %d resolves cumulative armor" % expected_rank, failures)
	TestAssertions.equal(_all_member_source_documents(party), owned_before, "legitimate party ranks leave owned member sources unchanged", failures)
	TestAssertions.equal(_upgrade_document(definition), definition_before, "legitimate party ranks preserve catalog upgrade resource", failures)
	TestAssertions.equal((party.get("_party_upgrade_sources") as Dictionary).size(), 1, "legitimate rank increase replaces one stable party source", failures)
	party.free()

func _assert_rejected_party_upgrade_is_transactional(
	party: PartyManager,
	catalog: GameCatalog,
	definition: UpgradeDefinition,
	caller_source: StatModifierSource,
	label: String,
	failures: Array[String],
) -> void:
	var party_upgrade_before := _party_upgrade_document(party)
	var owned_before := _all_member_source_documents(party)
	var definition_before := _upgrade_document(definition)
	var caller_before := _modifier_source_document(caller_source) if caller_source != null else ""
	var revision_before := party.stat_revision()
	var base_before: Dictionary = {}
	var action_before: Dictionary = {}
	var actors: Array[PartyActor] = []
	var health_before: Dictionary = {}
	for member: PartyMemberState in party.members:
		base_before[member.member_id] = party.stats_for(member.member_id)
		action_before[member.member_id] = party.stats_for_action(member.member_id, member.class_definition.primary_attack.action_tags)
		var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
		actor.configure(member)
		actor.configure_combat(party)
		var health := actor.get_node("HealthComponent") as HealthComponent
		actors.append(actor)
		health_before[member.member_id] = Vector2(health.current_health, health.max_health)
	var stat_events: Array[int] = []
	var upgrade_events: Array[bool] = []
	party.stats_changed.connect(func(member_id: int) -> void: stat_events.append(member_id))
	party.upgrades_changed.connect(func() -> void: upgrade_events.append(true))

	TestAssertions.truthy(not UpgradeApplicationService.apply(definition.id, catalog, party), "%s rejects before publication" % label, failures)
	TestAssertions.equal(_party_upgrade_document(party), party_upgrade_before, "%s preserves party-upgrade maps and source documents" % label, failures)
	TestAssertions.equal(_all_member_source_documents(party), owned_before, "%s preserves every member source document" % label, failures)
	TestAssertions.equal(_upgrade_document(definition), definition_before, "%s preserves catalog upgrade resource" % label, failures)
	if caller_source != null:
		TestAssertions.equal(_modifier_source_document(caller_source), caller_before, "%s preserves caller source document" % label, failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "%s preserves revision" % label, failures)
	for member: PartyMemberState in party.members:
		TestAssertions.truthy(is_same(party.stats_for(member.member_id), base_before[member.member_id]), "%s preserves member %d base cache identity" % [label, member.member_id], failures)
		TestAssertions.truthy(is_same(party.stats_for_action(member.member_id, member.class_definition.primary_attack.action_tags), action_before[member.member_id]), "%s preserves member %d action cache identity" % [label, member.member_id], failures)
		var health := actors[member.member_id - 1].get_node("HealthComponent") as HealthComponent
		TestAssertions.equal(Vector2(health.current_health, health.max_health), health_before[member.member_id], "%s preserves member %d actor health" % [label, member.member_id], failures)
	TestAssertions.equal(stat_events, [], "%s emits no stat signals" % label, failures)
	TestAssertions.equal(upgrade_events, [], "%s emits no upgrade signal" % label, failures)
	for actor: PartyActor in actors:
		actor.free()

func _party_upgrade(id: StringName, max_rank: int, effects: Array[UpgradeEffectDefinition]) -> UpgradeDefinition:
	var definition := UpgradeDefinition.new()
	definition.id = id
	definition.display_name = String(id).capitalize()
	definition.summary = "Task 10S fixture"
	definition.description = "Task 10S fixture"
	definition.scope = UpgradeDefinition.Scope.PARTY
	definition.max_rank = max_rank
	definition.effects = effects
	return definition

func _source(member_id: int, source_id: StringName, modifiers: Array[StatModifier]) -> StatModifierSource:
	return StatModifierSource.create(source_id, &"character_growth", "Task 10S Reserved", member_id, modifiers)

func _party_upgrade_document(party: PartyManager) -> String:
	var ranks := party.get("_party_upgrade_ranks") as Dictionary
	var definitions := party.get("_party_upgrade_definitions") as Dictionary
	var sources := party.get("_party_upgrade_sources") as Dictionary
	var ids: Array[StringName] = []
	for id_value: Variant in ranks:
		ids.append(StringName(id_value))
	ids.sort()
	var rows: Array[Dictionary] = []
	for id: StringName in ids:
		rows.append({
			"id": String(id),
			"rank": int(ranks[id]),
			"definition": _upgrade_document(definitions[id] as UpgradeDefinition),
			"source": _modifier_source_document(sources[id] as StatModifierSource),
		})
	return JSON.stringify(rows)

func _upgrade_document(definition: UpgradeDefinition) -> String:
	var effects: Array[Dictionary] = []
	for effect_value: UpgradeEffectDefinition in definition.effects:
		var effect := effect_value as StatUpgradeEffect
		if effect == null:
			effects.append({"unsupported": true})
			continue
		effects.append({
			"stat_id": String(effect.stat_id),
			"operation": effect.operation,
			"value_per_rank": effect.value_per_rank,
			"rank_values": effect.rank_values,
			"required_capability_tags": effect.required_capability_tags,
			"excluded_capability_tags": effect.excluded_capability_tags,
			"required_action_tags": effect.required_action_tags,
			"excluded_action_tags": effect.excluded_action_tags,
			"source_label": effect.source_label,
		})
	return JSON.stringify({
		"id": String(definition.id),
		"display_name": definition.display_name,
		"summary": definition.summary,
		"description": definition.description,
		"tooltip_keyword_ids": definition.tooltip_keyword_ids,
		"scope": definition.scope,
		"allowed_class_ids": definition.allowed_class_ids,
		"required_all_tags": definition.required_all_tags,
		"required_any_tags": definition.required_any_tags,
		"excluded_tags": definition.excluded_tags,
		"max_rank": definition.max_rank,
		"selection_weight": definition.selection_weight,
		"rarity": definition.rarity,
		"effects": effects,
	})

func _modifier_source_document(source: StatModifierSource) -> String:
	if source == null:
		return ""
	var modifiers: Array[Dictionary] = []
	for modifier: StatModifier in source.modifiers:
		modifiers.append({
			"stat_id": String(modifier.stat_id),
			"operation": modifier.operation,
			"value": modifier.value,
			"source_id": String(modifier.source_id),
			"source_label": modifier.source_label,
			"required_tags": modifier.required_tags,
			"excluded_tags": modifier.excluded_tags,
			"required_capability_tags": modifier.required_capability_tags,
			"excluded_capability_tags": modifier.excluded_capability_tags,
			"required_action_tags": modifier.required_action_tags,
			"excluded_action_tags": modifier.excluded_action_tags,
		})
	return JSON.stringify({
		"id": String(source.id),
		"source_type": String(source.source_type),
		"label": source.label,
		"owner_member_id": source.owner_member_id,
		"modifiers": modifiers,
	})

func _all_member_source_documents(party: PartyManager) -> String:
	var rows: Array[Dictionary] = []
	for member: PartyMemberState in party.members:
		var documents: Array[String] = []
		for source: StatModifierSource in member.modifier_sources:
			documents.append(_modifier_source_document(source))
		rows.append({"member_id": member.member_id, "sources": documents})
	return JSON.stringify(rows)

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
