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
	_test_healing_estimate_discovery(failures)
	_test_archetype_relevance_equipment_attribution_and_action_totals(failures)
	_test_actual_catalog_archetype_ledger_contract(failures)
	return failures

func _test_actual_catalog_archetype_ledger_contract(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var expected_by_class := {
		&"fighter": &"melee_damage",
		&"ranger": &"ranged_damage",
		&"mage": &"caster_damage",
		&"cleric": &"caster_damage",
		&"paladin": &"melee_damage",
		&"rogue": &"melee_damage",
		&"frost_mage": &"caster_damage",
		&"warlock": &"caster_damage",
		&"marksman": &"ranged_damage",
	}
	var archetype_stat_ids: Array[StringName] = [&"melee_damage", &"ranged_damage", &"caster_damage"]
	for class_id: StringName in expected_by_class:
		var definition := catalog.class_by_id(class_id)
		var expected_stat_id := expected_by_class[class_id] as StringName
		var expected_tag := StringName(String(expected_stat_id).trim_suffix("_damage"))
		var party := PartyManager.new()
		party.initialize(definition, catalog.traits)
		var capability_archetypes: Array[StringName] = []
		for tag: StringName in ActionArchetype.PRIMARY_TAGS:
			if tag in party.member_capabilities(1):
				capability_archetypes.append(tag)
		TestAssertions.equal(capability_archetypes, [expected_tag], "%s actual class/trait capability contract has one relevant archetype" % class_id, failures)
		var action_archetypes: Array[StringName] = []
		for action: AttackDefinition in definition.owned_actions():
			if action != null and not action.is_healing():
				var action_stat_id := ActionArchetype.stat_id(action)
				if not action_stat_id.is_empty() and action_stat_id not in action_archetypes:
					action_archetypes.append(action_stat_id)
		TestAssertions.equal(action_archetypes, [expected_stat_id], "%s actual action contract has the matching archetype" % class_id, failures)
		var provider := LedgerDataProvider.new()
		provider.configure(party, catalog, Callable())
		var visible_archetypes: Array[StringName] = []
		for row: Dictionary in provider.stat_rows(1):
			var stat_id := row.get("stat_id", &"") as StringName
			if stat_id in archetype_stat_ids:
				visible_archetypes.append(stat_id)
		TestAssertions.equal(visible_archetypes, [expected_stat_id], "%s ledger exposes only its actual relevant archetype row" % class_id, failures)
		provider.configure(null, null, Callable())
		party.free()

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
	TestAssertions.equal(rows.size(), 2, "owned-action enumeration preserves distinct resources even when invalid authored IDs collide", failures)
	TestAssertions.near(rows[0].normal_hit, expected_primary.normal_hit, 0.001, "duplicate action ID keeps the first authored action", failures)
	TestAssertions.truthy(rows.size() < 2 or not is_equal_approx(rows[1].normal_hit, expected_primary.normal_hit), "duplicate action ID retains the distinct second resource for consumer parity", failures)

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
	TestAssertions.equal(rows.map(func(row: ActionCombatEstimate) -> StringName: return row.action_id), [&"fighter_cleave", &"cleric_heal"], "healing-only support action is included after the damaging primary", failures)
	provider.configure(null, null, Callable())
	party.free()


func _test_healing_estimate_discovery(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"cleric"), catalog.traits)
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, Callable())
	var rows := provider.combat_estimate_rows(1)
	TestAssertions.equal(rows.map(func(row: ActionCombatEstimate) -> StringName: return row.action_id), [&"cleric_bolt", &"cleric_heal"], "ledger preserves damaging and healing action order", failures)
	var healing := rows[1] if rows.size() > 1 else null
	var supports_healing := healing != null and healing.get_property_list().any(func(property: Dictionary) -> bool: return property.get("name") == &"is_healing")
	TestAssertions.truthy(supports_healing and healing.available and bool(healing.get("is_healing")), "ledger exposes the Cleric healing estimate", failures)
	if supports_healing:
		TestAssertions.near(float(healing.get("estimated_hps")), float(healing.get("healing_amount")) * healing.attacks_per_second, 0.0001, "ledger healing HPS matches amount and cadence", failures)
	provider.configure(null, null, Callable())
	party.free()

func _test_archetype_relevance_equipment_attribution_and_action_totals(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "ledger relevance fixture recruits Ranger", failures)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"mage")), "ledger relevance fixture recruits Mage", failures)
	var attribute_sources: Array[StatModifierSource] = [
		StatModifierSource.create(&"fighter_attributes", &"class_growth", "Fighter Attributes", 1, [
			StatModifier.create(&"strength", StatModifier.Operation.FLAT, 3.0, &"fighter_strength", "Fighter Strength"),
		]),
		StatModifierSource.create(&"ranger_attributes", &"class_growth", "Ranger Attributes", 2, [
			StatModifier.create(&"dexterity", StatModifier.Operation.FLAT, 4.0, &"ranger_dexterity", "Ranger Dexterity"),
		]),
		StatModifierSource.create(&"mage_attributes", &"class_growth", "Mage Attributes", 3, [
			StatModifier.create(&"intelligence", StatModifier.Operation.FLAT, 5.0, &"mage_intelligence", "Mage Intelligence"),
		]),
	]
	for member_id: int in attribute_sources.size():
		TestAssertions.truthy(party.add_member_source(member_id + 1, attribute_sources[member_id]), "member %d attribute source applies" % (member_id + 1), failures)

	var equipment_modifier_id := &"equip_m1_smain_hand_iiron_sword_a0_tempered_edge_r0"
	var equipment_label := "Iron Sword — Tempered Edge"
	var equipment_source := StatModifierSource.create(&"equipment_member_1", &"equipment", "Equipment", 1, [
		StatModifier.create(&"melee_damage", StatModifier.Operation.INCREASED, 0.25, equipment_modifier_id, equipment_label),
		StatModifier.create(&"caster_damage", StatModifier.Operation.INCREASED, 0.0, &"equip_m1_smain_hand_iiron_sword_a1_dormant_focus_r0", "Iron Sword — Dormant Focus"),
	])
	TestAssertions.truthy(party.add_member_source(1, equipment_source), "equipment attribution fixture applies", failures)

	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, Callable())
	var expected_archetypes := {1: &"melee_damage", 2: &"ranged_damage", 3: &"caster_damage"}
	for member_id: int in expected_archetypes:
		var visible_ids := provider.stat_rows(member_id).map(func(row: Dictionary) -> StringName: return row.stat_id)
		var expected_id := expected_archetypes[member_id] as StringName
		TestAssertions.truthy(expected_id in visible_ids, "member %d shows its relevant archetype stat" % member_id, failures)
		for archetype_id: StringName in [&"melee_damage", &"ranged_damage", &"caster_damage"]:
			if archetype_id != expected_id:
				TestAssertions.truthy(archetype_id not in visible_ids, "member %d hides irrelevant %s despite zero derived rows" % [member_id, archetype_id], failures)
		TestAssertions.truthy(&"party_influence" not in visible_ids, "member %d hides default Party Influence" % member_id, failures)
		var action_rows := provider.combat_estimate_rows(member_id)
		TestAssertions.truthy(not action_rows.is_empty(), "member %d exposes a damaging action estimate" % member_id, failures)
		for estimate: ActionCombatEstimate in action_rows:
			TestAssertions.truthy(estimate.available, "member %d action estimate is available" % member_id, failures)
			TestAssertions.truthy(not estimate.component_rows.is_empty(), "member %d action exposes component rows" % member_id, failures)
			var component_normal := 0.0
			var component_critical := 0.0
			var component_average := 0.0
			for component: Dictionary in estimate.component_rows:
				TestAssertions.truthy(component.has("damage_type_id") and component.has("display_name"), "component row retains readable damage identity", failures)
				TestAssertions.truthy(component.has("normal_hit") and component.has("critical_hit") and component.has("average_hit"), "component row exposes all hit totals", failures)
				component_normal += float(component.get("normal_hit", 0.0))
				component_critical += float(component.get("critical_hit", 0.0))
				component_average += float(component.get("average_hit", 0.0))
			TestAssertions.near(estimate.normal_hit, component_normal, 0.0001, "action normal hit is the sum of components", failures)
			TestAssertions.near(estimate.critical_hit, component_critical, 0.0001, "action critical hit is the sum of components", failures)
			TestAssertions.near(estimate.average_hit, component_average, 0.0001, "action average hit is the sum of components", failures)
			TestAssertions.truthy(estimate.attacks_per_second > 0.0, "action exposes attacks per second", failures)
			TestAssertions.near(estimate.estimated_dps, estimate.average_hit * estimate.attacks_per_second, 0.0001, "action DPS uses average hit and rate", failures)

	var melee_detail := provider.stat_detail(1, &"melee_damage")
	TestAssertions.truthy(
		Array(melee_detail.get("sources", [])).any(func(source: Dictionary) -> bool: return source.get("source_id", &"") == equipment_modifier_id and String(source.get("source_label", "")) == equipment_label),
		"stat detail preserves equipment affix label and stable detailed source ID",
		failures,
	)
	var charisma_source := StatModifierSource.create(&"mage_charisma", &"class_growth", "Mage Charisma", 3, [
		StatModifier.create(&"charisma", StatModifier.Operation.FLAT, 2.0, &"mage_charisma_points", "Mage Charisma"),
	])
	TestAssertions.truthy(party.add_member_source(3, charisma_source), "non-default Party Influence fixture applies", failures)
	TestAssertions.truthy(
		provider.stat_rows(3).any(func(row: Dictionary) -> bool: return row.stat_id == &"party_influence"),
		"Party Influence appears once Charisma makes it non-default",
		failures,
	)
	provider.configure(null, null, Callable())
	party.free()
