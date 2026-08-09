extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_action_aware_critical_estimate(failures)
	_test_critical_chance_matches_runtime_bounds(failures)
	_test_noncritical_mixed_damage(failures)
	_test_mixed_caster_runtime_parity(failures)
	_test_zero_base_damage_is_unavailable(failures)
	_test_missing_attack_id_is_unavailable(failures)
	_test_invalid_damage_type_is_unavailable(failures)
	return failures

func _test_action_aware_critical_estimate(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
	var source := StatModifierSource.create(&"estimate_fixture", &"test", "Estimate Fixture", 1, [
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.50, &"projectile_damage", "Projectile Damage", [&"projectile"]),
		StatModifier.create(&"physical_damage", StatModifier.Operation.INCREASED, 0.20, &"physical_damage", "Physical Damage", [&"physical"]),
		StatModifier.create(&"crit_chance", StatModifier.Operation.FLAT, 0.25, &"crit_chance", "Critical Chance"),
		StatModifier.create(&"attack_speed", StatModifier.Operation.INCREASED, 0.10, &"attack_speed", "Attack Speed"),
	])
	TestAssertions.truthy(party.add_member_source(1, source), "estimate fixture source applies", failures)
	var estimate := ActionCombatEstimateService.estimate(catalog.class_by_id(&"ranger").primary_attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(estimate.available, "valid Ranger estimate is available", failures)
	TestAssertions.near(estimate.normal_hit, 19.8, 0.001, "normal hit uses global and physical action modifiers", failures)
	TestAssertions.near(estimate.critical_hit, 29.7, 0.001, "critical hit uses 1.5 multiplier", failures)
	TestAssertions.near(estimate.average_hit, 22.275, 0.001, "average hit weights 25 percent crit chance", failures)
	TestAssertions.near(estimate.attacks_per_second, 2.0, 0.001, "attack speed divides authored cooldown", failures)
	TestAssertions.near(estimate.estimated_dps, 44.55, 0.001, "DPS uses average hit and attacks per second", failures)
	party.free()

func _test_critical_chance_matches_runtime_bounds(failures: Array[String]) -> void:
	var overcapped := _estimate_with_crit_modifier(2.0, &"overcapped_crit", failures)
	TestAssertions.near(overcapped.average_hit, overcapped.critical_hit, 0.001, "overcapped crit chance averages at a certain critical hit", failures)
	var negative := _estimate_with_crit_modifier(-1.0, &"negative_crit", failures)
	TestAssertions.near(negative.average_hit, negative.normal_hit, 0.001, "negative crit chance averages at a normal hit", failures)
	_test_nonfinite_modifier_is_rejected_atomically(failures)

func _test_nonfinite_modifier_is_rejected_atomically(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
	var baseline := party.stats_for(1)
	var source := StatModifierSource.create(&"nonfinite_crit", &"test", "Critical Chance Boundary", 1, [
		StatModifier.create(&"crit_chance", StatModifier.Operation.FLAT, NAN, &"nonfinite_crit", "Critical Chance Boundary"),
	])
	TestAssertions.truthy(not party.add_member_source(1, source), "non-finite crit source is rejected", failures)
	TestAssertions.truthy(party.members[0].modifier_sources.is_empty(), "rejected non-finite source leaves member sources unchanged", failures)
	TestAssertions.truthy(is_same(baseline, party.stats_for(1)), "rejected non-finite source preserves the cached snapshot", failures)
	party.free()

func _test_noncritical_mixed_damage(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var attack := AttackDefinition.new()
	attack.id = &"mixed_test"
	attack.kind = AttackDefinition.Kind.MELEE_CLEAVE
	attack.cooldown = 2.0
	attack.range = 2.0
	attack.can_crit = false
	attack.action_tags = [&"melee"]
	attack.damage_components = [_component(&"physical", 10.0), _component(&"fire", 5.0)]
	var estimate := ActionCombatEstimateService.estimate(attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(estimate.available and not estimate.can_crit, "mixed noncritical estimate is available", failures)
	TestAssertions.near(estimate.normal_hit, 15.0, 0.001, "mixed components sum into one hit", failures)
	TestAssertions.near(estimate.average_hit, 15.0, 0.001, "noncritical average equals normal", failures)
	TestAssertions.equal(estimate.component_rows.map(func(row: Dictionary) -> StringName: return row.damage_type_id), [&"physical", &"fire"], "component order stays authored", failures)
	party.free()

func _test_mixed_caster_runtime_parity(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"mage"), catalog.traits)
	var source := StatModifierSource.create(&"caster_parity", &"test", "Caster Parity", 1, [
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.20, &"caster_global", "Global Damage"),
		StatModifier.create(&"caster_damage", StatModifier.Operation.INCREASED, 0.30, &"caster_archetype", "Caster Damage"),
		StatModifier.create(&"fire_damage", StatModifier.Operation.INCREASED, 0.40, &"caster_fire", "Fire Damage"),
		StatModifier.create(&"cold_damage", StatModifier.Operation.INCREASED, 0.10, &"caster_cold", "Cold Damage"),
	])
	TestAssertions.truthy(party.add_member_source(1, source), "caster parity source applies", failures)
	var attack := AttackDefinition.new()
	attack.id = &"mixed_caster"
	attack.kind = AttackDefinition.Kind.AREA_PROJECTILE
	attack.cooldown = 2.0
	attack.range = 8.0
	attack.projectile_speed = 10.0
	attack.area_radius = 2.0
	attack.action_tags = [&"area", &"caster", &"projectile"]
	attack.damage_components = [_component(&"fire", 10.0), _component(&"cold", 5.0)]
	var action_stats := party.stats_for_action(1, DamageResolver.action_tags_for(attack))
	var adapter := CombatantAdapter.new(null, &"party:caster", 1, null, action_stats)
	var packet := DamageResolver.prepare(attack, adapter, CombatRng.new(2048), catalog.damage_types)
	var estimate := ActionCombatEstimateService.estimate(attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(packet.valid and estimate.available, "mixed caster runtime and estimate are available", failures)
	if packet.valid and estimate.available:
		TestAssertions.near(packet.components[0].typed_scaled, 21.84, 0.0001, "runtime fire component applies global, caster, and fire once", failures)
		TestAssertions.near(packet.components[1].typed_scaled, 8.58, 0.0001, "runtime cold component applies global, caster, and cold once", failures)
		for index: int in packet.components.size():
			TestAssertions.near(packet.components[index].typed_scaled, float(estimate.component_rows[index].normal_hit), 0.0001, "runtime and ledger component %d share normal projection" % index, failures)
	party.free()

func _test_zero_base_damage_is_unavailable(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var attack := catalog.class_by_id(&"fighter").primary_attack.duplicate(true) as AttackDefinition
	attack.damage_components[0].base_amount = 0.0
	var estimate := ActionCombatEstimateService.estimate(attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(not estimate.available, "runtime-invalid zero-base damage is unavailable", failures)
	TestAssertions.truthy("component amount" in estimate.unavailable_reason.to_lower(), "zero-base reason names the invalid damage amount", failures)
	party.free()

func _test_missing_attack_id_is_unavailable(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var attack := catalog.class_by_id(&"fighter").primary_attack.duplicate(true) as AttackDefinition
	attack.id = &""
	var estimate := ActionCombatEstimateService.estimate(attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(not estimate.available, "runtime-invalid missing attack ID is unavailable", failures)
	TestAssertions.truthy("missing id" in estimate.unavailable_reason.to_lower(), "missing-ID reason names the invalid identity boundary", failures)
	party.free()

func _test_invalid_damage_type_is_unavailable(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var attack := catalog.class_by_id(&"fighter").primary_attack.duplicate(true) as AttackDefinition
	attack.damage_components = [_component(&"void", 10.0)]
	var estimate := ActionCombatEstimateService.estimate(attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(not estimate.available, "unknown type cannot produce invented numbers", failures)
	var reason := estimate.unavailable_reason.to_lower()
	TestAssertions.truthy("unknown" in reason and "type" in reason, "unavailable reason names the invalid type boundary", failures)
	party.free()

func _component(type_id: StringName, amount: float) -> AttackDamageComponent:
	var result := AttackDamageComponent.new()
	result.damage_type_id = type_id
	result.base_amount = amount
	return result

func _estimate_with_crit_modifier(value: float, source_id: StringName, failures: Array[String]) -> ActionCombatEstimate:
	var definition := PartyManager.STAT_CATALOG.definition(&"crit_chance")
	var had_minimum := definition.has_minimum
	var had_maximum := definition.has_maximum
	definition.has_minimum = false
	definition.has_maximum = false
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
	var source := StatModifierSource.create(source_id, &"test", "Critical Chance Boundary", 1, [
		StatModifier.create(&"crit_chance", StatModifier.Operation.FLAT, value, source_id, "Critical Chance Boundary"),
	])
	TestAssertions.truthy(party.add_member_source(1, source), "%s source applies" % source_id, failures)
	var estimate := ActionCombatEstimateService.estimate(catalog.class_by_id(&"ranger").primary_attack, 1, party, catalog.damage_types)
	party.free()
	definition.has_minimum = had_minimum
	definition.has_maximum = had_maximum
	return estimate
