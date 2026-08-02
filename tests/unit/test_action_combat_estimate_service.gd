extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_action_aware_critical_estimate(failures)
	_test_noncritical_mixed_damage(failures)
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

func _test_invalid_damage_type_is_unavailable(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var attack := catalog.class_by_id(&"fighter").primary_attack.duplicate(true) as AttackDefinition
	attack.damage_components = [_component(&"void", 10.0)]
	var estimate := ActionCombatEstimateService.estimate(attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(not estimate.available, "unknown type cannot produce invented numbers", failures)
	TestAssertions.truthy("Unknown damage type" in estimate.unavailable_reason, "unavailable reason names the invalid boundary", failures)
	party.free()

func _component(type_id: StringName, amount: float) -> AttackDamageComponent:
	var result := AttackDamageComponent.new()
	result.damage_type_id = type_id
	result.base_amount = amount
	return result
