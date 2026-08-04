extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var health := HealthComponent.new()
	health.current_health = 200.0
	health.max_health = 260.0
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, func(_member_id: int) -> Dictionary:
		return {
			"current": health.current_health,
			"maximum": health.max_health,
			"is_downed": health.is_downed,
			"is_dead": health.is_dead,
			"component": health,
		}
	)

	var members := provider.member_rows()
	TestAssertions.equal(members.size(), 1, "provider returns only current members", failures)
	TestAssertions.equal(members[0].health_current, 200.0, "provider uses runtime health", failures)
	TestAssertions.truthy(not members[0].is_downed and not members[0].is_dead, "provider exposes current runtime health state", failures)
	TestAssertions.equal(members[0].get("character_level"), 1, "neutral provider defaults members to level one", failures)
	TestAssertions.equal(members[0].get("experience"), 0, "neutral provider defaults members to zero XP", failures)
	TestAssertions.equal(members[0].get("experience_required"), ExperienceSystem.DEFAULT_TUNING.requirement_for_level(1), "neutral provider uses the default level-one XP requirement", failures)
	TestAssertions.near(float(members[0].get("experience_fraction", -1.0)), 0.0, 0.0001, "neutral provider defaults XP fraction to zero", failures)
	TestAssertions.equal(members[0].get("guaranteed_growth_count"), 0, "neutral provider defaults guaranteed growth count to zero", failures)
	TestAssertions.equal(members[0].get("milestone_count"), 0, "neutral provider defaults milestone count to zero", failures)
	var health_changes: Array[int] = []
	var on_data_changed := func(member_id: int) -> void: health_changes.append(member_id)
	provider.data_changed.connect(on_data_changed)
	health.health_changed.emit(190.0, 260.0)
	TestAssertions.equal(health_changes, [1], "runtime health signals refresh the affected member", failures)
	health.is_downed = true
	TestAssertions.truthy(provider.member_rows()[0].is_downed, "provider reads updated runtime downed state", failures)
	health.is_downed = false

	var normal_rows := provider.stat_rows(1)
	var normal_ids := normal_rows.map(func(row: Dictionary) -> StringName: return row.stat_id)
	TestAssertions.truthy(&"physical_damage" in normal_ids, "fighter shows physical damage", failures)
	TestAssertions.truthy(&"fire_damage" not in normal_ids, "fighter hides irrelevant fire damage", failures)
	var normal_sort_keys := normal_rows.map(func(row: Dictionary) -> String: return row.sort_key)
	var expected_sort_keys := normal_sort_keys.duplicate()
	expected_sort_keys.sort()
	TestAssertions.equal(normal_sort_keys, expected_sort_keys, "stat rows sort deterministically", failures)
	var fire_source := StatModifierSource.create(
		&"test_fire",
		&"test",
		"Test Fire",
		1,
		[StatModifier.create(&"fire_damage", StatModifier.Operation.INCREASED, 0.25, &"test_fire", "Test Fire")],
	)
	party.add_member_source(1, fire_source)
	var modified_ids := provider.stat_rows(1).map(func(row: Dictionary) -> StringName: return row.stat_id)
	TestAssertions.truthy(&"fire_damage" in modified_ids, "modifier-caused specialized stat remains visible", failures)
	TestAssertions.truthy(&"lightning_damage" in provider.stat_rows(1, true).map(func(row: Dictionary) -> StringName: return row.stat_id), "Show All exposes complete registry", failures)
	var detail := provider.stat_detail(1, &"fire_damage")
	TestAssertions.equal(detail.sources.size(), 2, "detail contains base and named source", failures)

	UpgradeApplicationService.apply(&"vitality", catalog, party, 1)
	party.upgrade_party_stat(&"damage")
	party.recruit(catalog.class_by_id(&"fighter"))
	UpgradeApplicationService.apply(&"vanguard_wall", catalog, party)
	var upgrades := provider.upgrade_rows(1)
	TestAssertions.truthy(upgrades.any(func(row: Dictionary) -> bool: return row.id == &"vitality" and row.ownership == "Personal"), "personal authored upgrade is listed", failures)
	TestAssertions.truthy(upgrades.any(func(row: Dictionary) -> bool: return row.id == &"party_damage" and row.ownership == "Party"), "foundational party rank is listed", failures)
	TestAssertions.truthy(upgrades.any(func(row: Dictionary) -> bool: return row.id == &"vanguard_wall" and row.ownership == "Trait"), "applicable authored trait upgrade is listed", failures)
	TestAssertions.truthy(upgrades.any(func(row: Dictionary) -> bool: return row.id == &"active_trait_vanguard" and row.ownership == "Trait"), "active composition trait is listed", failures)
	var party_damage_row: Dictionary = upgrades.filter(func(row: Dictionary) -> bool: return row.id == &"party_damage")[0]
	TestAssertions.equal(party_damage_row.effect_lines, ["5% increased Damage."], "party upgrade effect text formats deterministically", failures)
	var active_trait_row: Dictionary = upgrades.filter(func(row: Dictionary) -> bool: return row.id == &"active_trait_vanguard")[0]
	TestAssertions.equal(active_trait_row.effect_lines, ["Current value: 0.12"], "active trait effect text formats deterministically", failures)
	var upgrade_sort_keys := upgrades.map(func(row: Dictionary) -> String: return row.sort_key)
	var expected_upgrade_sort_keys := upgrade_sort_keys.duplicate()
	expected_upgrade_sort_keys.sort()
	TestAssertions.equal(upgrade_sort_keys, expected_upgrade_sort_keys, "upgrade rows sort deterministically", failures)
	var vitality_row: Dictionary = upgrades.filter(func(row: Dictionary) -> bool: return row.id == &"vitality")[0]
	var owned_detail := provider.upgrade_detail(vitality_row)
	TestAssertions.equal(owned_detail.rank_text, "Rank 1 / 5", "owned tooltip uses current rank wording", failures)
	TestAssertions.equal(owned_detail.ownership, "Personal", "owned tooltip retains ownership", failures)
	var offered := UpgradePresentationService.tooltip(catalog.upgrade_by_id(&"vitality"), 2, PartyManager.STAT_CATALOG, catalog.keywords)
	TestAssertions.equal(offered.rank_text, "Offered rank 2 / 5", "offer tooltip wording remains unchanged", failures)

	provider.configure(null, null, Callable())
	var changes_after_disconnect := health_changes.size()
	health.health_changed.emit(180.0, 260.0)
	party.stats_changed.emit(1)
	TestAssertions.equal(health_changes.size(), changes_after_disconnect, "provider disconnects runtime and party signals symmetrically", failures)
	if provider.data_changed.is_connected(on_data_changed):
		provider.data_changed.disconnect(on_data_changed)
	health.free()
	party.free()
	_test_independent_progression_projection_and_core_attributes(failures)
	_test_combat_estimate_action_discovery(failures)
	return failures

func _test_independent_progression_projection_and_core_attributes(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "progression fixture recruits an independent follower", failures)
	var context := PlayerRunContext.new()
	TestAssertions.equal(
		context.configure(
			&"ledger_player",
			0,
			ProfileState.new_profile("profile-ledger01", "Ledger Player", 1000),
			1337,
			party,
			100,
		),
		PackedStringArray(),
		"ledger progression context configures",
		failures,
	)
	TestAssertions.truthy(context.award_experience(1, 57).ok(), "member one reaches level three with overflow XP", failures)
	TestAssertions.truthy(context.award_experience(2, 20).ok(), "member two reaches level two independently", failures)

	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, Callable(), Callable(context, "progression_for"), context)
	var rows_by_id: Dictionary = {}
	for row: Dictionary in provider.member_rows():
		rows_by_id[int(row.member_id)] = row
	var first := rows_by_id.get(1, {}) as Dictionary
	var second := rows_by_id.get(2, {}) as Dictionary
	TestAssertions.equal(first.get("character_level"), 3, "member one projects its own level", failures)
	TestAssertions.equal(first.get("experience"), 7, "member one projects its own overflow XP", failures)
	TestAssertions.equal(first.get("experience_required"), 44, "member one projects its current requirement", failures)
	TestAssertions.near(float(first.get("experience_fraction", -1.0)), 7.0 / 44.0, 0.0001, "member one projects its XP fraction", failures)
	TestAssertions.equal(first.get("guaranteed_growth_count"), 2, "member one projects guaranteed growth history", failures)
	TestAssertions.equal(first.get("milestone_count"), 0, "member one projects milestone count", failures)
	TestAssertions.equal(second.get("character_level"), 2, "member two does not mirror member one's level", failures)
	TestAssertions.equal(second.get("experience"), 0, "member two does not mirror member one's XP", failures)
	TestAssertions.equal(second.get("experience_required"), 30, "member two projects its own current requirement", failures)
	TestAssertions.equal(second.get("guaranteed_growth_count"), 1, "member two projects its own growth history", failures)

	var visible_attribute_ids := provider.stat_rows(1).map(func(row: Dictionary) -> StringName: return row.stat_id)
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		TestAssertions.truthy(attribute_id in visible_attribute_ids, "%s core attribute is visible without Show All" % attribute_id, failures)
		var detail := provider.stat_detail(1, attribute_id)
		TestAssertions.truthy(
			Array(detail.get("sources", [])).any(func(source: Dictionary) -> bool: return String(source.get("source_label", "")) == "Class Growth"),
			"%s detail includes the resolver-backed Class Growth source" % attribute_id,
			failures,
		)
		TestAssertions.truthy(not String(detail.get("description", "")).is_empty() and not String(detail.get("description", "")).begins_with("Missing definition:"), "%s retains its keyword explanation" % attribute_id, failures)

	var progression_events: Array[int] = []
	var on_progression_data_changed := func(member_id: int) -> void: progression_events.append(member_id)
	provider.data_changed.connect(on_progression_data_changed)
	TestAssertions.truthy(context.award_experience(1, 1).ok(), "progression change fixture accepts another award", failures)
	TestAssertions.equal(progression_events, [1], "context progression changes refresh only the affected member", failures)
	provider.configure(null, null, Callable())
	TestAssertions.truthy(context.award_experience(2, 1).ok(), "disconnected context can continue progressing", failures)
	TestAssertions.equal(progression_events, [1], "provider disconnects progression context during reconfiguration", failures)
	if provider.data_changed.is_connected(on_progression_data_changed):
		provider.data_changed.disconnect(on_progression_data_changed)
	party.free()

func _test_combat_estimate_action_discovery(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var definition := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	definition.id = &"estimate_fixture"
	definition.primary_attack = catalog.class_by_id(&"fighter").primary_attack
	definition.support_action = catalog.class_by_id(&"ranger").primary_attack
	var party := PartyManager.new()
	party.initialize(definition, catalog.traits)
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, Callable())
	var rows := provider.combat_estimate_rows(1)
	TestAssertions.equal(rows.map(func(row: ActionCombatEstimate) -> StringName: return row.action_id), [&"fighter_cleave", &"ranger_shot"], "provider preserves authored action-slot order", failures)

	definition.support_action = definition.primary_attack
	party.initialize(definition, catalog.traits)
	rows = provider.combat_estimate_rows(1)
	TestAssertions.equal(rows.size(), 1, "duplicate action ID/resource appears once", failures)

	var expected_primary := ActionCombatEstimateService.estimate(definition.primary_attack, 1, party, catalog.damage_types)
	var original_primary_component := definition.primary_attack.damage_components[0]
	var original_primary_base_amount := original_primary_component.base_amount
	var duplicate_id_attack := definition.primary_attack.duplicate(true) as AttackDefinition
	var duplicate_component := original_primary_component.duplicate(true) as AttackDamageComponent
	duplicate_component.base_amount = 999.0
	duplicate_id_attack.damage_components = [duplicate_component]
	definition.support_action = duplicate_id_attack
	party.initialize(definition, catalog.traits)
	rows = provider.combat_estimate_rows(1)
	TestAssertions.equal(duplicate_id_attack.id, definition.primary_attack.id, "duplicate resource retains the same non-empty action ID", failures)
	TestAssertions.truthy(duplicate_id_attack.get_instance_id() != definition.primary_attack.get_instance_id(), "duplicate action ID fixture uses distinct resources", failures)
	TestAssertions.truthy(duplicate_component.get_instance_id() != original_primary_component.get_instance_id(), "duplicate action fixture uses a distinct damage component resource", failures)
	TestAssertions.near(definition.primary_attack.damage_components[0].base_amount, original_primary_base_amount, 0.001, "configuring duplicate action leaves original component unchanged", failures)
	TestAssertions.truthy(not is_equal_approx(duplicate_component.base_amount, original_primary_base_amount), "duplicate action damage differs from original", failures)
	TestAssertions.equal(rows.size(), 1, "duplicate action ID across resources appears once", failures)
	TestAssertions.near(rows[0].normal_hit, expected_primary.normal_hit, 0.001, "duplicate action ID keeps the first authored action", failures)

	definition.primary_attack = null
	definition.support_action = catalog.class_by_id(&"ranger").primary_attack
	party.initialize(definition, catalog.traits)
	rows = provider.combat_estimate_rows(1)
	TestAssertions.equal(rows.map(func(row: ActionCombatEstimate) -> StringName: return row.action_id), [&"ranger_shot"], "null current slot is omitted safely", failures)

	definition.primary_attack = catalog.class_by_id(&"fighter").primary_attack
	var componentless_attack := catalog.class_by_id(&"ranger").primary_attack.duplicate(true) as AttackDefinition
	componentless_attack.damage_components = []
	TestAssertions.truthy(not componentless_attack.is_healing() and componentless_attack.damage_components.is_empty(), "componentless fixture remains non-healing", failures)
	definition.support_action = componentless_attack
	party.initialize(definition, catalog.traits)
	rows = provider.combat_estimate_rows(1)
	TestAssertions.equal(rows.map(func(row: ActionCombatEstimate) -> StringName: return row.action_id), [&"fighter_cleave"], "non-healing componentless action is excluded", failures)

	definition.support_action = catalog.class_by_id(&"cleric").support_action
	party.initialize(definition, catalog.traits)
	rows = provider.combat_estimate_rows(1)
	TestAssertions.equal(rows.size(), 1, "healing-only support action is excluded", failures)
	provider.configure(null, null, Callable())
	party.free()
