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
	_test_combat_estimate_action_discovery(failures)
	return failures

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

	var duplicate_id_attack := definition.primary_attack.duplicate(true) as AttackDefinition
	duplicate_id_attack.damage_components[0].base_amount = 999.0
	definition.support_action = duplicate_id_attack
	party.initialize(definition, catalog.traits)
	rows = provider.combat_estimate_rows(1)
	var expected_primary := ActionCombatEstimateService.estimate(definition.primary_attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(duplicate_id_attack.get_instance_id() != definition.primary_attack.get_instance_id(), "duplicate action ID fixture uses distinct resources", failures)
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
