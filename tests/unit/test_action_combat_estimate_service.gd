extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_action_aware_critical_estimate(failures)
	_test_critical_chance_matches_runtime_bounds(failures)
	_test_multi_crit_expected_value_boundaries(failures)
	_test_noncritical_mixed_damage(failures)
	_test_mixed_caster_runtime_parity(failures)
	_test_actual_warlock_action_snapshot_is_caster_only(failures)
	_test_snapshot_estimate_matches_party_estimate(failures)
	_test_action_geometry_estimate_parity_and_tag_filtering(failures)
	_test_geometry_only_changes_do_not_invent_dps(failures)
	_test_geometry_only_healing_range_preserves_amount_and_hps(failures)
	_test_wisdom_only_damage_and_healing_estimates(failures)
	_test_zero_base_damage_is_unavailable(failures)
	_test_missing_attack_id_is_unavailable(failures)
	_test_invalid_damage_type_is_unavailable(failures)
	_test_estimate_invariants_are_contextual(failures)
	_test_weapon_midpoint_projection(failures)
	return failures

func _test_weapon_midpoint_projection(failures: Array[String]) -> void:
	var attack := GameCatalog.load_defaults().class_by_id(&"fighter").primary_attack.duplicate(true) as AttackDefinition
	if not _has_property(attack, &"damage_source"):
		TestAssertions.truthy(false, "weapon estimate requires attack damage source", failures)
		return
	attack.set(&"damage_source", 1)
	attack.set(&"weapon_damage_effectiveness", 1.5)
	var stats := _snapshot({&"damage": 1.2, &"melee_damage": 1.25, &"physical_damage": 1.4})
	stats.revision = 9
	var weapon := ActiveWeaponDamageSnapshot.create(1, "estimate-weapon", &"forge_vanguard_sword", [
		ItemBaseDamageComponent.create(&"physical", 4.0, 8.0),
	], 9)
	var estimate_script := load("res://scripts/ui/ledger/action_combat_estimate_service.gd") as Script
	var method := estimate_script.get_script_method_list().filter(func(row: Dictionary) -> bool: return row.get("name") == &"estimate_from_snapshot")
	if method.is_empty() or (method[0].get("args", []) as Array).size() < 4:
		TestAssertions.truthy(false, "snapshot estimate accepts an optional weapon", failures)
		return
	var estimate := estimate_script.call("estimate_from_snapshot", attack, stats, GameCatalog.DAMAGE_TYPES, weapon) as ActionCombatEstimate
	TestAssertions.truthy(estimate != null and estimate.available, "weapon midpoint estimate is available", failures)
	if estimate != null:
		TestAssertions.near(estimate.normal_hit, 18.9, 0.0001, "weapon midpoint applies effectiveness and all scaling once", failures)

func _test_actual_warlock_action_snapshot_is_caster_only(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var warlock := catalog.class_by_id(&"warlock")
	var party := PartyManager.new()
	party.initialize(warlock, catalog.traits)
	var ranged_modifier := StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.75, &"task10o_ranged_only", "Ranged Only")
	ranged_modifier.required_capability_tags = [&"ranged"]
	var caster_modifier := StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.25, &"task10o_caster_only", "Caster Only")
	caster_modifier.required_capability_tags = [&"caster"]
	var source := StatModifierSource.create(&"task10o_warlock_archetype", &"test", "Warlock Archetype", 1, [ranged_modifier, caster_modifier])
	TestAssertions.truthy(party.add_member_source(1, source), "actual Warlock archetype source applies", failures)
	var snapshot := party.stats_for_action(1, warlock.primary_attack.normalized_action_tags())
	var source_ids: Array[StringName] = []
	for row: Dictionary in snapshot.breakdown(&"damage"):
		source_ids.append(row.get("source_id", &"") as StringName)
	TestAssertions.truthy(&"task10o_caster_only" in source_ids, "actual Warlock caster modifier reaches the caster-bolt snapshot", failures)
	TestAssertions.truthy(&"task10o_ranged_only" not in source_ids, "actual Warlock ranged-required modifier cannot reach the caster-bolt snapshot", failures)
	TestAssertions.near(snapshot.value(&"damage"), 1.25, 0.0001, "actual Warlock caster-bolt snapshot applies only caster scaling", failures)
	party.free()


func _test_geometry_only_healing_range_preserves_amount_and_hps(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var healing := catalog.class_by_id(&"cleric").support_action
	var neutral := ActionCombatEstimateService.estimate_from_snapshot(healing, _snapshot({}), catalog.damage_types)
	var ranged := ActionCombatEstimateService.estimate_from_snapshot(healing, _snapshot({&"attack_range": 1.5}), catalog.damage_types)
	TestAssertions.truthy(neutral.available and ranged.available and neutral.is_healing and ranged.is_healing, "geometry-only healing comparison estimates are available", failures)
	TestAssertions.near(ranged.range, neutral.range * 1.5, 0.0001, "geometry-only healing comparison changes effective range", failures)
	TestAssertions.near(ranged.healing_amount, neutral.healing_amount, 0.0001, "geometry-only healing range does not change healing amount", failures)
	TestAssertions.near(ranged.estimated_hps, neutral.estimated_hps, 0.0001, "geometry-only healing range does not change HPS", failures)


func _test_action_geometry_estimate_parity_and_tag_filtering(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	var mage := catalog.class_by_id(&"mage").duplicate(true) as ClassDefinition
	mage.primary_attack = mage.primary_attack.duplicate(true) as AttackDefinition
	mage.primary_attack.action_tags = mage.primary_attack.action_tags.duplicate()
	mage.primary_attack.action_tags.append(&"task10j_estimate_action")
	party.initialize(mage, catalog.traits)
	var attack := mage.primary_attack
	var source := StatModifierSource.create(&"task10j_geometry_estimate", &"test", "Task 10J Geometry", 1, [
		StatModifier.create(&"attack_range", StatModifier.Operation.INCREASED, 0.25, &"task10j_global_range", "Global Range"),
		StatModifier.create(&"attack_range", StatModifier.Operation.INCREASED, 0.50, &"task10j_area_range", "Tagged Range", [&"task10j_estimate_action"]),
		StatModifier.create(&"attack_range", StatModifier.Operation.INCREASED, 4.0, &"task10j_melee_range", "Melee Range", [&"melee"]),
		StatModifier.create(&"area_size", StatModifier.Operation.INCREASED, 0.40, &"task10j_area_size", "Area Size", [&"task10j_estimate_action"]),
		StatModifier.create(&"projectile_speed", StatModifier.Operation.INCREASED, 0.30, &"task10j_projectile_speed", "Projectile Speed", [&"task10j_estimate_action"]),
	])
	TestAssertions.truthy(party.add_member_source(1, source), "geometry estimate source applies", failures)
	var estimate := ActionCombatEstimateService.estimate(attack, 1, party, catalog.damage_types)
	var supports_geometry := _has_property(estimate, &"range") and _has_property(estimate, &"area_radius") and _has_property(estimate, &"projectile_speed")
	TestAssertions.truthy(supports_geometry, "action estimate exposes effective geometry fields", failures)
	if not supports_geometry:
		party.free()
		return
	TestAssertions.truthy(estimate.available, "action-tagged geometry estimate is available", failures)
	TestAssertions.near(float(estimate.get("range")), attack.range * 1.75, 0.001, "global and matching tagged range combine once", failures)
	TestAssertions.near(float(estimate.get("area_radius")), attack.area_radius * 1.40, 0.001, "matching area tag changes effective radius", failures)
	TestAssertions.near(float(estimate.get("projectile_speed")), attack.projectile_speed * 1.30, 0.001, "matching projectile tag changes effective speed", failures)
	var exact_snapshot := party.stats_for_action(1, DamageResolver.action_tags_for(attack))
	var snapshot_estimate := ActionCombatEstimateService.estimate_from_snapshot(attack, exact_snapshot, catalog.damage_types)
	TestAssertions.near(float(snapshot_estimate.get("range")), float(estimate.get("range")), 0.001, "party and pure preview range use the same exact action snapshot", failures)
	TestAssertions.near(float(snapshot_estimate.get("area_radius")), float(estimate.get("area_radius")), 0.001, "party and pure preview area use the same exact action snapshot", failures)
	TestAssertions.near(float(snapshot_estimate.get("projectile_speed")), float(estimate.get("projectile_speed")), 0.001, "party and pure preview speed use the same exact action snapshot", failures)
	party.free()


func _test_geometry_only_changes_do_not_invent_dps(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var attack := catalog.class_by_id(&"ranger").primary_attack
	var neutral := ActionCombatEstimateService.estimate_from_snapshot(attack, _snapshot({}), catalog.damage_types)
	var geometry_only := ActionCombatEstimateService.estimate_from_snapshot(attack, _snapshot({
		&"attack_range": 1.5,
		&"projectile_speed": 2.0,
		&"area_size": 3.0,
	}), catalog.damage_types)
	var supports_geometry := _has_property(geometry_only, &"range") and _has_property(geometry_only, &"area_radius") and _has_property(geometry_only, &"projectile_speed")
	if not supports_geometry:
		return
	TestAssertions.truthy(neutral.available and geometry_only.available, "neutral and geometry-only previews are available", failures)
	TestAssertions.near(float(geometry_only.get("range")), attack.range * 1.5, 0.001, "geometry-only preview exposes effective range", failures)
	TestAssertions.near(float(geometry_only.get("projectile_speed")), attack.projectile_speed * 2.0, 0.001, "geometry-only preview exposes effective speed", failures)
	TestAssertions.near(float(geometry_only.get("area_radius")), 0.0, 0.001, "non-area action omits effective area", failures)
	TestAssertions.near(geometry_only.average_hit, neutral.average_hit, 0.001, "geometry-only changes do not alter hit projection", failures)
	TestAssertions.near(geometry_only.estimated_dps, neutral.estimated_dps, 0.001, "geometry-only changes do not invent DPS", failures)

	var overflow := ActionCombatEstimateService.estimate_from_snapshot(
		attack,
		_snapshot({&"attack_range": 1.0e308}),
		catalog.damage_types,
	)
	TestAssertions.truthy(not overflow.available, "non-finite effective runtime geometry makes the preview unavailable", failures)
	TestAssertions.truthy("range" in overflow.unavailable_reason.to_lower(), "geometry overflow preview names range", failures)

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
	TestAssertions.near(estimate.average_hit, 22.77, 0.001, "average hit weights the Ranger's total 30 percent crit chance", failures)
	TestAssertions.near(estimate.attacks_per_second, 2.0, 0.001, "attack speed divides authored cooldown", failures)
	TestAssertions.near(estimate.estimated_dps, 45.54, 0.001, "DPS uses average damage per use and attacks per second", failures)
	party.free()

func _test_multi_crit_expected_value_boundaries(failures: Array[String]) -> void:
	var attack := GameCatalog.load_defaults().class_by_id(&"ranger").primary_attack
	var cases: Array[Dictionary] = [
		{"label": "below one hundred", "chance": 0.25, "critical_instances": 0.25, "damage_instances": 1.0},
		{"label": "exactly one hundred", "chance": 1.0, "critical_instances": 1.0, "damage_instances": 1.0},
		{"label": "one hundred five", "chance": 1.05, "critical_instances": 1.05, "damage_instances": 1.05},
		{"label": "eleven hundred fifty", "chance": 11.50, "critical_instances": 11.50, "damage_instances": 11.50},
		{"label": "below processing ceiling", "chance": 9999.50, "critical_instances": 9999.50, "damage_instances": 9999.50},
		{"label": "at processing ceiling", "chance": 10000.0, "critical_instances": 10000.0, "damage_instances": 10000.0},
		{"label": "above processing ceiling", "chance": 10000.50, "critical_instances": 10000.50, "damage_instances": 10000.0},
	]
	for row: Dictionary in cases:
		var chance := float(row["chance"])
		var estimate := ActionCombatEstimateService.estimate_from_snapshot(
			attack,
			_snapshot({&"crit_chance": chance, &"crit_multiplier": 1.5}),
			GameCatalog.DAMAGE_TYPES,
		)
		var label := String(row["label"])
		TestAssertions.truthy(estimate.available, "%s estimate is available" % label, failures)
		var exposes_critical_count := _has_property(estimate, &"expected_critical_instances")
		var exposes_damage_count := _has_property(estimate, &"expected_damage_instances")
		TestAssertions.truthy(exposes_critical_count, "%s estimate exposes expected critical instances" % label, failures)
		TestAssertions.truthy(exposes_damage_count, "%s estimate exposes expected damage instances" % label, failures)
		if exposes_critical_count:
			TestAssertions.near(float(estimate.get("expected_critical_instances")), float(row["critical_instances"]), 0.0001, "%s preserves expected critical count" % label, failures)
		if exposes_damage_count:
			TestAssertions.near(float(estimate.get("expected_damage_instances")), float(row["damage_instances"]), 0.0001, "%s preserves expected damage count" % label, failures)
		var expected_average: float = (
			estimate.normal_hit * (1.0 + chance * (1.5 - 1.0))
			if chance < 1.0 else
			estimate.normal_hit * 1.5 * float(row["damage_instances"])
		)
		TestAssertions.near(estimate.average_hit, expected_average, 0.0001, "%s uses the runtime multi-crit expected-value boundary" % label, failures)
		TestAssertions.near(estimate.estimated_dps, expected_average * estimate.attacks_per_second, 0.0001, "%s DPS uses average bundle damage times uses per second" % label, failures)

func _test_critical_chance_matches_runtime_bounds(failures: Array[String]) -> void:
	var overcapped := _estimate_with_crit_modifier(2.0, &"overcapped_crit", failures)
	var exposes_critical_count := _has_property(overcapped, &"expected_critical_instances")
	TestAssertions.truthy(exposes_critical_count, "overcapped estimate exposes expected critical count", failures)
	if exposes_critical_count:
		TestAssertions.near(float(overcapped.get("expected_critical_instances")), 2.05, 0.001, "overcapped crit chance preserves two guaranteed instances plus five percent remainder", failures)
	TestAssertions.near(overcapped.average_hit, overcapped.critical_hit * 2.05, 0.001, "overcapped crit chance averages the full multi-crit bundle", failures)
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
	TestAssertions.near(estimate.normal_hit, _component_total(estimate.component_rows, "normal_hit"), 0.001, "normal total equals independently readable component rows", failures)
	TestAssertions.near(estimate.critical_hit, _component_total(estimate.component_rows, "critical_hit"), 0.001, "critical total equals independently readable component rows", failures)
	TestAssertions.near(estimate.average_hit, 15.0, 0.001, "noncritical average equals normal", failures)
	TestAssertions.near(estimate.average_hit, _component_total(estimate.component_rows, "average_hit"), 0.001, "average total equals independently readable component rows", failures)
	TestAssertions.near(estimate.estimated_dps, estimate.average_hit * estimate.attacks_per_second, 0.001, "DPS total is derived from average hit and action rate", failures)
	TestAssertions.equal(estimate.component_rows.map(func(row: Dictionary) -> StringName: return row.damage_type_id), [&"fire", &"physical"], "component order uses deterministic damage type order", failures)
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
		TestAssertions.near(packet.components[0].typed_scaled, 8.58, 0.0001, "runtime sorted cold component applies global, caster, and cold once", failures)
		TestAssertions.near(packet.components[1].typed_scaled, 21.84, 0.0001, "runtime sorted fire component applies global, caster, and fire once", failures)
		for index: int in packet.components.size():
			TestAssertions.near(packet.components[index].typed_scaled, float(estimate.component_rows[index].normal_hit), 0.0001, "runtime and ledger component %d share normal projection" % index, failures)
	party.free()


func _test_snapshot_estimate_matches_party_estimate(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var attack := catalog.class_by_id(&"fighter").primary_attack
	var action_stats := party.stats_for_action(1, DamageResolver.action_tags_for(attack))
	var party_estimate := ActionCombatEstimateService.estimate(attack, 1, party, catalog.damage_types)
	var service_script := load("res://scripts/ui/ledger/action_combat_estimate_service.gd") as Script
	var supports_snapshot := service_script.get_script_method_list().any(func(method: Dictionary) -> bool: return String(method.get("name", "")) == "estimate_from_snapshot")
	TestAssertions.truthy(supports_snapshot, "estimate service exposes pure snapshot projection", failures)
	if not supports_snapshot:
		party.free()
		return
	var snapshot_estimate := service_script.call("estimate_from_snapshot", attack, action_stats, catalog.damage_types) as ActionCombatEstimate
	TestAssertions.truthy(snapshot_estimate != null and snapshot_estimate.available, "pure snapshot estimate is available", failures)
	if snapshot_estimate != null:
		TestAssertions.near(snapshot_estimate.normal_hit, party_estimate.normal_hit, 0.0001, "snapshot and party normal hit share one path", failures)
		TestAssertions.near(snapshot_estimate.average_hit, party_estimate.average_hit, 0.0001, "snapshot and party average hit share one path", failures)
		TestAssertions.near(snapshot_estimate.estimated_dps, party_estimate.estimated_dps, 0.0001, "snapshot and party DPS share one path", failures)
	party.free()


func _test_wisdom_only_damage_and_healing_estimates(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var cleric := catalog.class_by_id(&"cleric")
	var damage_attack := cleric.primary_attack
	var healing_action := cleric.support_action
	var neutral_damage := ActionCombatEstimateService.estimate_from_snapshot(damage_attack, _snapshot({}), catalog.damage_types)
	var wisdom_damage := ActionCombatEstimateService.estimate_from_snapshot(
		damage_attack,
		_snapshot({&"cooldown_rate": 1.05, &"healing_power": 1.2}),
		catalog.damage_types,
	)
	TestAssertions.truthy(neutral_damage.available and wisdom_damage.available, "neutral and Wisdom-only damage estimates are available", failures)
	TestAssertions.near(wisdom_damage.average_hit, neutral_damage.average_hit, 0.0001, "Wisdom cooldown recovery does not alter unrelated damage per hit", failures)
	TestAssertions.near(wisdom_damage.attacks_per_second, neutral_damage.attacks_per_second * 1.05, 0.0001, "Wisdom-only cooldown recovery increases damaging action cadence", failures)

	var neutral_heal := ActionCombatEstimateService.estimate_from_snapshot(healing_action, _snapshot({}), catalog.damage_types)
	var wisdom_heal := ActionCombatEstimateService.estimate_from_snapshot(
		healing_action,
		_snapshot({&"cooldown_rate": 1.05, &"healing_power": 1.2}),
		catalog.damage_types,
	)
	TestAssertions.truthy(neutral_heal.available and wisdom_heal.available, "healing actions expose available ledger estimates without damage archetypes", failures)
	var supports_healing := _has_property(wisdom_heal, &"is_healing") and _has_property(wisdom_heal, &"healing_amount") and _has_property(wisdom_heal, &"estimated_hps")
	TestAssertions.truthy(supports_healing, "healing estimate exposes healing semantics and HPS", failures)
	if not supports_healing:
		return
	TestAssertions.truthy(bool(wisdom_heal.get("is_healing")), "healing estimate identifies its semantic kind", failures)
	TestAssertions.near(float(neutral_heal.get("healing_amount")), healing_action.power, 0.0001, "neutral healing estimate preserves authored power", failures)
	TestAssertions.near(float(wisdom_heal.get("healing_amount")), healing_action.power * 1.2, 0.0001, "Wisdom healing power changes heal amount once", failures)
	TestAssertions.near(wisdom_heal.attacks_per_second, neutral_heal.attacks_per_second * 1.05, 0.0001, "Wisdom-only cooldown recovery increases healing cadence", failures)
	TestAssertions.near(float(wisdom_heal.get("estimated_hps")), float(wisdom_heal.get("healing_amount")) * wisdom_heal.attacks_per_second, 0.0001, "healing HPS uses the shared action rate", failures)

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

func _test_estimate_invariants_are_contextual(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var fighter_attack := catalog.class_by_id(&"fighter").primary_attack.duplicate(true) as AttackDefinition
	var critical_overflow := ActionCombatEstimateService.estimate_from_snapshot(
		fighter_attack,
		_snapshot({&"crit_chance": 0.5, &"crit_multiplier": 1.0e308}),
		catalog.damage_types,
	)
	TestAssertions.truthy(not critical_overflow.available, "critical overflow is unavailable", failures)
	TestAssertions.truthy("critical" in critical_overflow.unavailable_reason.to_lower(), "critical overflow names the critical invariant", failures)

	var rate_attack := fighter_attack.duplicate(true) as AttackDefinition
	rate_attack.cooldown = 0.1
	var rate_overflow := ActionCombatEstimateService.estimate_from_snapshot(
		rate_attack,
		_snapshot({&"attack_speed": 1.0e308}),
		catalog.damage_types,
	)
	TestAssertions.truthy(not rate_overflow.available, "action-rate overflow is unavailable", failures)
	TestAssertions.truthy("action rate" in rate_overflow.unavailable_reason.to_lower(), "action-rate overflow names the rate invariant", failures)

	var recovery_overflow := ActionCombatEstimateService.estimate_from_snapshot(
		fighter_attack,
		_snapshot({&"attack_speed": 1.0e200, &"cooldown_rate": 1.0e200}),
		catalog.damage_types,
	)
	TestAssertions.truthy(not recovery_overflow.available, "combined attack-speed and cooldown-recovery overflow is unavailable", failures)
	TestAssertions.truthy("progress multiplier" in recovery_overflow.unavailable_reason.to_lower(), "combined cadence overflow names the multiplier invariant", failures)

	var dps_overflow := ActionCombatEstimateService.estimate_from_snapshot(
		fighter_attack,
		_snapshot({&"damage": 1.0e200, &"attack_speed": 1.0e200}),
		catalog.damage_types,
	)
	TestAssertions.truthy(not dps_overflow.available, "DPS overflow is unavailable", failures)
	TestAssertions.truthy("dps" in dps_overflow.unavailable_reason.to_lower(), "DPS overflow names the DPS invariant", failures)

	var mixed := fighter_attack.duplicate(true) as AttackDefinition
	mixed.id = &"mixed_total_overflow"
	mixed.damage_components = [_component(&"fire", 1.0e308), _component(&"cold", 1.0e308)]
	var mixed_overflow := ActionCombatEstimateService.estimate_from_snapshot(mixed, _snapshot({}), catalog.damage_types)
	TestAssertions.truthy(not mixed_overflow.available, "mixed-component total overflow is unavailable", failures)
	TestAssertions.truthy("normal hit total" in mixed_overflow.unavailable_reason.to_lower(), "mixed overflow names the normal-total invariant", failures)

	var negative := ActionCombatEstimateService.estimate_from_snapshot(
		fighter_attack,
		_snapshot({&"damage": -1.0}),
		catalog.damage_types,
	)
	TestAssertions.truthy(not negative.available, "negative projected component is unavailable", failures)
	TestAssertions.truthy("damage" in negative.unavailable_reason.to_lower(), "negative projection names the damage invariant", failures)

func _snapshot(overrides: Dictionary) -> ResolvedStatSnapshot:
	var snapshot := ResolvedStatSnapshot.new()
	for definition: StatDefinition in GameCatalog.STAT_CATALOG.definitions:
		var value := float(overrides.get(definition.id, definition.default_value))
		snapshot.set_resolved(definition.id, value, [])
	return snapshot

func _component(type_id: StringName, amount: float) -> AttackDamageComponent:
	var result := AttackDamageComponent.new()
	result.damage_type_id = type_id
	result.base_amount = amount
	return result

func _component_total(rows: Array[Dictionary], field: String) -> float:
	var total := 0.0
	for row: Dictionary in rows:
		total += float(row.get(field, 0.0))
	return total


func _has_property(object: Object, property_name: StringName) -> bool:
	return object != null and object.get_property_list().any(
		func(property: Dictionary) -> bool: return property.get("name") == property_name
	)

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
