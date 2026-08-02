extends RefCounted

var _health_nodes: Array[HealthComponent] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	var types := GameCatalog.load_defaults().damage_types
	_test_preparation_and_armor(types, failures)
	_test_resistance_and_mixed_damage(types, failures)
	_test_shared_crit(types, failures)
	_test_dodge_block_and_incoming(types, failures)
	_test_overkill_life_steal(types, failures)
	_test_invalid_resolution_boundaries(types, failures)
	_test_open_ended_radiant_type(types, failures)
	_test_action_tags_use_deterministic_string_order(failures)
	for health: HealthComponent in _health_nodes:
		health.free()
	return failures

func _test_preparation_and_armor(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:1", 1, null, {&"damage": 1.20, &"physical_damage": 1.50})
	var attack := _attack([&"physical"], [100.0])
	attack.id = &"scaled_physical"
	attack.action_tags = [&"melee"]
	var packet := DamageResolver.prepare(attack, source, CombatRng.new(1), types)
	TestAssertions.truthy(packet.valid, "scaled physical packet is valid", failures)
	TestAssertions.equal(packet.action_tags, [&"melee", &"physical"], "action tags include sorted damage type", failures)
	TestAssertions.near(packet.components[0].authored_amount, 100.0, 0.001, "authored physical amount", failures)
	TestAssertions.near(packet.components[0].global_scaled, 120.0, 0.001, "global damage scaling", failures)
	TestAssertions.near(packet.components[0].typed_scaled, 180.0, 0.001, "typed physical scaling", failures)
	TestAssertions.near(packet.components[0].post_crit, 180.0, 0.001, "prepared physical amount", failures)

	var target_health := _health(250.0, 250.0)
	var target := _adapter(&"enemy:armor", 2, target_health, {&"armor": 80.0})
	var result := DamageResolver.resolve(packet, target, CombatRng.new(2), types)
	TestAssertions.truthy(result.valid, "armor result is valid", failures)
	TestAssertions.near(result.final_damage, 100.0, 0.001, "180 physical against 80 armor", failures)
	TestAssertions.near(result.actual_health_removed, 100.0, 0.001, "armor health removal", failures)
	TestAssertions.equal(result.component_breakdowns, [{
		"damage_type_id": &"physical",
		"authored_amount": 100.0,
		"global_scaled": 120.0,
		"typed_scaled": 180.0,
		"post_crit": 180.0,
		"defense_stat_id": &"armor",
		"defense_value": 80.0,
		"post_mitigation": 100.0,
	}], "physical calculation evidence", failures)

func _test_resistance_and_mixed_damage(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:1", 1, null, {})
	var fire_packet := _packet(source, [&"fire"], [100.0])
	var capped_health := _health(250.0, 250.0)
	var capped := _adapter(&"enemy:fire_cap", 2, capped_health, {&"fire_resistance": 0.75})
	var capped_result := DamageResolver.resolve(fire_packet, capped, CombatRng.new(3), types)
	TestAssertions.near(capped_result.final_damage, 25.0, 0.001, "fire against positive resistance", failures)

	var negative_health := _health(250.0, 250.0)
	var negative := _adapter(&"enemy:fire_negative", 2, negative_health, {&"fire_resistance": -1.0})
	var negative_result := DamageResolver.resolve(fire_packet, negative, CombatRng.new(4), types)
	TestAssertions.near(negative_result.final_damage, 200.0, 0.001, "fire against negative resistance", failures)

	var mixed_health := _health(250.0, 250.0)
	var mixed_target := _adapter(&"enemy:mixed", 2, mixed_health, {&"armor": 50.0, &"fire_resistance": 0.25})
	var mixed_packet := _packet(source, [&"physical", &"fire"], [60.0, 40.0])
	var mixed := DamageResolver.resolve(mixed_packet, mixed_target, CombatRng.new(5), types)
	TestAssertions.near(float(mixed.component_breakdowns[0]["post_mitigation"]), 40.0, 0.001, "mixed physical mitigation", failures)
	TestAssertions.near(float(mixed.component_breakdowns[1]["post_mitigation"]), 30.0, 0.001, "mixed fire mitigation", failures)
	TestAssertions.near(mixed.total_post_mitigation, 70.0, 0.001, "mixed total after mitigation", failures)
	TestAssertions.near(mixed.final_damage, 70.0, 0.001, "mixed final damage", failures)

func _test_shared_crit(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:crit", 1, null, {&"crit_chance": 0.50, &"crit_multiplier": 2.0})
	var attack := _attack([&"physical", &"fire"], [30.0, 20.0], true)
	var rng := CombatRng.new(6, [0.20])
	var packet := DamageResolver.prepare(attack, source, rng, types)
	TestAssertions.truthy(packet.valid and packet.critical, "prescribed crit succeeds", failures)
	TestAssertions.near(packet.crit_draw, 0.20, 0.001, "crit draw evidence", failures)
	TestAssertions.near(packet.crit_multiplier, 2.0, 0.001, "crit multiplier evidence", failures)
	TestAssertions.near(packet.components[0].post_crit, 60.0, 0.001, "crit doubles physical component", failures)
	TestAssertions.near(packet.components[1].post_crit, 40.0, 0.001, "crit doubles fire component", failures)
	TestAssertions.equal(rng.draw_count, 1, "one shared crit draw", failures)

func _test_dodge_block_and_incoming(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:1", 1, null, {})
	var packet := _packet(source, [&"physical"], [100.0])
	var dodge_health := _health(200.0, 200.0)
	var dodge_target := _adapter(&"enemy:dodge", 2, dodge_health, {&"dodge_chance": 0.25, &"block_chance": 0.50})
	var dodge_rng := CombatRng.new(7, [0.10, 0.20])
	var dodged := DamageResolver.resolve(packet, dodge_target, dodge_rng, types)
	TestAssertions.truthy(dodged.valid and dodged.dodged, "prescribed dodge succeeds", failures)
	TestAssertions.near(dodged.final_damage, 0.0, 0.001, "dodge deals zero", failures)
	TestAssertions.near(dodge_health.current_health, 200.0, 0.001, "dodge preserves health", failures)
	TestAssertions.equal(dodge_rng.draw_count, 1, "dodge skips block draw", failures)
	TestAssertions.near(dodged.block_draw, -1.0, 0.001, "dodge has no block draw evidence", failures)

	var block_health := _health(200.0, 200.0)
	var block_target := _adapter(&"enemy:block", 2, block_health, {&"block_chance": 0.50, &"block_effectiveness": 0.60})
	var blocked := DamageResolver.resolve(packet, block_target, CombatRng.new(8, [0.20]), types)
	TestAssertions.truthy(blocked.blocked, "prescribed block succeeds", failures)
	TestAssertions.near(blocked.damage_before_block, 100.0, 0.001, "block occurs after mitigation", failures)
	TestAssertions.near(blocked.block_prevented, 60.0, 0.001, "block prevention evidence", failures)
	TestAssertions.near(blocked.final_damage, 40.0, 0.001, "60 percent block leaves 40 percent", failures)

	var vanguard_health := _health(200.0, 200.0)
	var vanguard_target := _adapter(&"party:vanguard", 2, vanguard_health, {}, true, 0.88)
	var vanguard := DamageResolver.resolve(packet, vanguard_target, CombatRng.new(9), types)
	TestAssertions.near(vanguard.total_post_mitigation, 100.0, 0.001, "vanguard starts after mitigation", failures)
	TestAssertions.near(vanguard.incoming_multiplier, 0.88, 0.001, "vanguard incoming multiplier", failures)
	TestAssertions.near(vanguard.incoming_prevented, 12.0, 0.001, "vanguard prevention evidence", failures)
	TestAssertions.near(vanguard.damage_before_block, 88.0, 0.001, "vanguard applies before block", failures)
	TestAssertions.near(vanguard.final_damage, 88.0, 0.001, "vanguard final damage", failures)

func _test_overkill_life_steal(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source_health := _health(100.0, 99.0)
	var source := _adapter(&"party:leech", 1, source_health, {})
	var target_health := _health(10.0, 10.0)
	var target := _adapter(&"enemy:overkill", 2, target_health, {})
	var packet := _packet(source, [&"physical"], [30.0], 0.20)
	var result := DamageResolver.resolve(packet, target, CombatRng.new(10), types)
	TestAssertions.near(result.final_damage, 30.0, 0.001, "overkill resolved damage", failures)
	TestAssertions.near(result.actual_health_removed, 10.0, 0.001, "overkill uses actual removal", failures)
	TestAssertions.near(result.actual_health_removed * result.life_steal_rate, 2.0, 0.001, "life steal requested from actual removal", failures)
	TestAssertions.near(result.life_steal_restored, 1.0, 0.001, "life steal reports clamped restoration", failures)
	TestAssertions.near(source_health.current_health, 100.0, 0.001, "life steal clamps at source maximum", failures)

func _test_invalid_resolution_boundaries(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:1", 1, null, {})
	var valid_packet := _packet(source, [&"physical"], [10.0])
	var target_health := _health(100.0, 100.0)
	var target := _adapter(&"enemy:invalid", 2, target_health, {})
	var rng := CombatRng.new(11, [0.10, 0.20])

	var unknown := DamageResolver.resolve(_packet(source, [&"void"], [10.0]), target, rng, types)
	TestAssertions.equal(unknown.error_reason, "PARTY_FORGE_DAMAGE_ERROR attack=test_hit source=party:1 target=enemy:invalid type=void reason=unknown runtime type", "unknown runtime type diagnostic", failures)

	var unavailable_health := _health(100.0, 100.0)
	var unavailable_target := _adapter(&"enemy:unavailable", 2, unavailable_health, {}, false)
	var unavailable := DamageResolver.resolve(valid_packet, unavailable_target, rng, types)
	TestAssertions.equal(unavailable.error_reason, "PARTY_FORGE_DAMAGE_ERROR attack=test_hit source=party:1 target=enemy:unavailable reason=target unavailable", "unavailable target diagnostic", failures)

	var same_team_health := _health(100.0, 100.0)
	var same_team_target := _adapter(&"party:ally", 1, same_team_health, {})
	var same_team := DamageResolver.resolve(valid_packet, same_team_target, rng, types)
	TestAssertions.equal(same_team.error_reason, "PARTY_FORGE_DAMAGE_ERROR attack=test_hit source=party:1 target=party:ally reason=team-invalid target", "same-team diagnostic", failures)

	var non_finite := DamageResolver.resolve(_packet(source, [&"physical"], [INF]), target, rng, types)
	TestAssertions.equal(non_finite.error_reason, "PARTY_FORGE_DAMAGE_ERROR attack=test_hit source=party:1 target=enemy:invalid type=physical reason=invalid runtime amount", "non-finite runtime diagnostic", failures)
	TestAssertions.near(target_health.current_health, 100.0, 0.001, "invalid packets preserve target health", failures)
	TestAssertions.near(unavailable_health.current_health, 100.0, 0.001, "unavailable target health unchanged", failures)
	TestAssertions.near(same_team_health.current_health, 100.0, 0.001, "same-team target health unchanged", failures)
	TestAssertions.equal(rng.draw_count, 0, "invalid packets consume no defender RNG", failures)

func _test_open_ended_radiant_type(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var radiant := DamageTypeDefinition.new()
	radiant.id = &"radiant"
	radiant.display_name = "Radiant"
	radiant.keyword_id = &"radiant"
	radiant.offense_stat_id = &"radiant_damage"
	radiant.defense_stat_id = &"radiant_resistance"
	radiant.mitigation_rule = DamageTypeDefinition.MitigationRule.RESISTANCE
	var custom_types := DamageTypeCatalog.new()
	custom_types.definitions = types.all()
	custom_types.definitions.append(radiant)
	var source := _adapter(&"party:radiant", 1, null, {})
	var packet := DamageResolver.prepare(_attack([&"radiant"], [100.0]), source, CombatRng.new(12), custom_types)
	var target_health := _health(150.0, 150.0)
	var target := _adapter(&"enemy:radiant", 2, target_health, {&"radiant_resistance": 0.25})
	var result := DamageResolver.resolve(packet, target, CombatRng.new(13), custom_types)
	TestAssertions.truthy(packet.valid and result.valid, "custom radiant type resolves", failures)
	TestAssertions.near(result.final_damage, 75.0, 0.001, "custom resistance rule needs no resolver branch", failures)

func _test_action_tags_use_deterministic_string_order(failures: Array[String]) -> void:
	var attack := _attack([&"physical", &"fire"], [1.0, 1.0])
	attack.action_tags = [&"zeta", &"alpha"]
	TestAssertions.equal(DamageResolver.action_tags_for(attack), [&"alpha", &"fire", &"physical", &"zeta"], "StringName action and damage tags sort by deterministic string value", failures)

func _attack(type_ids: Array[StringName], amounts: Array[float], can_crit: bool = false) -> AttackDefinition:
	var attack := AttackDefinition.new()
	attack.id = &"test_hit"
	attack.kind = AttackDefinition.Kind.DIRECT
	attack.cooldown = 1.0
	attack.range = 1.0
	attack.can_crit = can_crit
	for index: int in mini(type_ids.size(), amounts.size()):
		var component := AttackDamageComponent.new()
		component.damage_type_id = type_ids[index]
		component.base_amount = amounts[index]
		attack.damage_components.append(component)
	return attack

func _packet(source: CombatantAdapter, type_ids: Array[StringName], amounts: Array[float], life_steal: float = 0.0) -> DamagePacket:
	var prepared: Array[PreparedDamageComponent] = []
	for index: int in mini(type_ids.size(), amounts.size()):
		prepared.append(PreparedDamageComponent.new(type_ids[index], amounts[index], amounts[index], amounts[index], amounts[index]))
	return DamagePacket.create(source, &"test_hit", [], false, false, -1.0, 1.0, life_steal, prepared)

func _adapter(id: StringName, team: int, health: HealthComponent, values: Dictionary, available: bool = true, incoming_multiplier: float = 1.0) -> CombatantAdapter:
	var snapshot := ResolvedStatSnapshot.new()
	var rows: Array[Dictionary] = []
	for stat_id: Variant in values:
		snapshot.set_resolved(StringName(stat_id), float(values[stat_id]), rows)
	var incoming := func(_packet: DamagePacket) -> float: return incoming_multiplier
	return CombatantAdapter.new(null, id, team, health, snapshot, available, incoming)

func _health(maximum: float, current: float) -> HealthComponent:
	var health := HealthComponent.new()
	health.configure(maximum, true, 8.0, 0.5, true)
	health.current_health = current
	_health_nodes.append(health)
	return health
