extends RefCounted

const MULTI_CRIT_ROLL := preload("res://scripts/combat/multi_crit_roll.gd")

var _health_nodes: Array[HealthComponent] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	var types := GameCatalog.load_defaults().damage_types
	_test_preparation_and_armor(types, failures)
	_test_resistance_and_mixed_damage(types, failures)
	_test_shared_crit(types, failures)
	_test_multi_crit_preparation(types, failures)
	_test_nonfinite_crit_preparation_is_rejected(types, failures)
	_test_frozen_per_instance_resolution(types, failures)
	_test_dodge_block_and_incoming(types, failures)
	_test_overkill_life_steal(types, failures)
	_test_invalid_resolution_boundaries(types, failures)
	_test_open_ended_radiant_type(types, failures)
	_test_action_tags_use_deterministic_string_order(failures)
	for health: HealthComponent in _health_nodes:
		health.free()
	return failures

func _test_preparation_and_armor(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:1", 1, null, {&"damage": 1.20, &"melee_damage": 1.30, &"physical_damage": 1.50})
	var attack := _attack([&"physical"], [100.0])
	attack.id = &"scaled_physical"
	attack.action_tags = [&"melee"]
	var packet := DamageResolver.prepare(attack, source, CombatRng.new(1), types)
	TestAssertions.truthy(packet.valid, "scaled physical packet is valid", failures)
	TestAssertions.equal(packet.action_tags, [&"melee", &"physical"], "action tags include sorted damage type", failures)
	TestAssertions.near(packet.components[0].authored_amount, 100.0, 0.001, "authored physical amount", failures)
	TestAssertions.near(packet.components[0].global_scaled, 120.0, 0.001, "global damage scaling", failures)
	TestAssertions.near(packet.components[0].typed_scaled, 234.0, 0.001, "archetype and typed physical scaling", failures)
	TestAssertions.near(packet.components[0].post_crit, 234.0, 0.001, "prepared physical amount", failures)

	var target_health := _health(250.0, 250.0)
	var target := _adapter(&"enemy:armor", 2, target_health, {&"armor": 80.0})
	var result := DamageResolver.resolve(packet, target, CombatRng.new(2), types)
	TestAssertions.truthy(result.valid, "armor result is valid", failures)
	TestAssertions.near(result.final_damage, 130.0, 0.001, "234 physical against 80 armor", failures)
	TestAssertions.near(result.actual_health_removed, 130.0, 0.001, "armor health removal", failures)
	TestAssertions.equal(result.component_breakdowns, [{
		"damage_type_id": &"physical",
		"authored_amount": 100.0,
		"global_scaled": 120.0,
		"typed_scaled": 234.0,
		"post_crit": 234.0,
		"defense_stat_id": &"armor",
		"defense_value": 80.0,
		"post_mitigation": 130.0,
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
	TestAssertions.equal(packet.components.map(func(component: PreparedDamageComponent) -> StringName: return component.damage_type_id), [&"fire", &"physical"], "authored components use deterministic type order", failures)
	TestAssertions.near(packet.components[0].post_crit, 40.0, 0.001, "crit doubles sorted fire component", failures)
	TestAssertions.near(packet.components[1].post_crit, 60.0, 0.001, "crit doubles sorted physical component", failures)
	TestAssertions.equal(rng.draw_count, 1, "one shared crit draw", failures)

func _test_multi_crit_preparation(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:multi_crit", 1, null, {&"crit_chance": 1.05, &"crit_multiplier": 2.0})
	var attack := _attack([&"physical", &"fire"], [30.0, 20.0], true)
	var rng := CombatRng.new(61, [0.04])
	var packet := DamageResolver.prepare(attack, source, rng, types)
	TestAssertions.truthy(packet.valid, "105 percent packet prepares", failures)
	var has_roll := _has_property(packet, &"multi_crit_roll")
	TestAssertions.truthy(has_roll, "packet exposes authoritative multi-crit roll", failures)
	if not packet.valid or not has_roll:
		return
	var roll: Object = packet.get("multi_crit_roll")
	TestAssertions.truthy(roll != null, "packet owns authoritative multi-crit metadata", failures)
	if roll == null:
		return
	TestAssertions.equal(roll.get("critical_flags"), [true, true], "105 percent packet records two ordered critical instances", failures)
	TestAssertions.equal(roll.get("requested_instances"), 2, "105 percent packet requests two potential instances", failures)
	TestAssertions.equal(roll.get("processed_instances"), 2, "successful 105 percent packet processes two instances", failures)
	TestAssertions.equal(roll.get("guaranteed_instances"), 1, "105 percent packet records one guaranteed instance", failures)
	TestAssertions.truthy(packet.critical, "compatibility critical accessor maps to authoritative roll", failures)
	TestAssertions.near(packet.crit_draw, 0.04, 0.001, "compatibility draw accessor maps to authoritative remainder", failures)
	TestAssertions.equal(packet.components.size(), 2, "multi-crit preparation creates one base component set", failures)
	TestAssertions.near(packet.components[0].typed_scaled, 20.0, 0.001, "multi-crit fire base is prepared once", failures)
	TestAssertions.near(packet.components[1].typed_scaled, 30.0, 0.001, "multi-crit physical base is prepared once", failures)
	TestAssertions.near(packet.components[0].post_crit, 40.0, 0.001, "compatibility fire amount uses first critical instance", failures)
	TestAssertions.near(packet.components[1].post_crit, 60.0, 0.001, "compatibility physical amount uses first critical instance", failures)
	TestAssertions.equal(rng.draw_count, 1, "105 percent preparation consumes only the fractional roll", failures)

func _test_nonfinite_crit_preparation_is_rejected(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:invalid_crit", 1, null, {&"crit_chance": INF})
	var attack := _attack([&"physical"], [30.0], true)
	var rng := CombatRng.new(62, [0.04])
	var packet := DamageResolver.prepare(attack, source, rng, types)
	TestAssertions.truthy(not packet.valid, "nonfinite critical chance cannot create a valid packet", failures)
	TestAssertions.truthy(packet.error_reason.contains("critical chance must be finite"), "nonfinite critical chance reports a stable packet diagnostic", failures)
	TestAssertions.equal(rng.draw_count, 0, "nonfinite critical chance consumes no RNG", failures)

func _test_frozen_per_instance_resolution(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var resolver_script := load("res://scripts/combat/damage_resolver.gd") as Script
	var snapshot_exists := ResourceLoader.exists("res://scripts/combat/damage_defense_snapshot.gd")
	var has_capture := resolver_script != null and resolver_script.has_method(&"capture_defense")
	var has_instance_resolution := resolver_script != null and resolver_script.has_method(&"resolve_instance")
	TestAssertions.truthy(snapshot_exists, "defended instance resolution defines an immutable defense snapshot", failures)
	TestAssertions.truthy(has_capture, "damage resolver captures target defenses once", failures)
	TestAssertions.truthy(has_instance_resolution, "damage resolver resolves one independently defended instance", failures)
	if not snapshot_exists or not has_capture or not has_instance_resolution:
		return

	_test_independent_instance_draws(resolver_script, types, failures)
	_test_frozen_snapshot_and_invalid_data(resolver_script, types, failures)
	_test_post_death_calculation(resolver_script, types, failures)
	_test_compatibility_resolve_uses_first_instance(types, failures)

func _test_independent_instance_draws(resolver_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:instance_draws", 1, null, {&"crit_chance": 3.0, &"crit_multiplier": 2.0})
	var packet := DamageResolver.prepare(_attack([&"physical"], [30.0], true), source, CombatRng.new(70), types)
	var target_health := _health(500.0, 500.0)
	var target := _adapter(&"enemy:instance_draws", 2, target_health, {
		&"dodge_chance": 0.50,
		&"block_chance": 0.50,
		&"block_effectiveness": 0.50,
	})
	var snapshot: Object = resolver_script.call("capture_defense", packet, target, types)
	TestAssertions.truthy(snapshot != null and bool(snapshot.get("valid")), "three-instance target defense snapshot is valid", failures)
	if snapshot == null or not bool(snapshot.get("valid")):
		return
	var rng := CombatRng.new(71, [0.10, 0.90, 0.10, 0.90, 0.90])
	var dodged: DamageResult = resolver_script.call("resolve_instance", packet, 0, true, snapshot, target, rng, types, true, true) as DamageResult
	var blocked: DamageResult = resolver_script.call("resolve_instance", packet, 1, true, snapshot, target, rng, types, true, true) as DamageResult
	var unblocked: DamageResult = resolver_script.call("resolve_instance", packet, 2, true, snapshot, target, rng, types, true, true) as DamageResult
	TestAssertions.truthy(dodged.valid and blocked.valid and unblocked.valid, "ordered defended critical instances are valid", failures)
	TestAssertions.equal([dodged.instance_index, blocked.instance_index, unblocked.instance_index], [0, 1, 2], "instance evidence preserves ordered indices", failures)
	TestAssertions.truthy(dodged.dodged and not blocked.dodged and not unblocked.dodged, "each instance independently rolls dodge", failures)
	TestAssertions.near(dodged.dodge_draw, 0.10, 0.001, "first instance uses first dodge draw", failures)
	TestAssertions.near(dodged.block_draw, -1.0, 0.001, "dodged instance consumes no block draw", failures)
	TestAssertions.near(blocked.dodge_draw, 0.90, 0.001, "second instance receives its own dodge draw", failures)
	TestAssertions.near(blocked.block_draw, 0.10, 0.001, "second non-dodged instance receives a block draw", failures)
	TestAssertions.truthy(blocked.blocked, "second instance is independently blocked", failures)
	TestAssertions.near(unblocked.dodge_draw, 0.90, 0.001, "third instance receives its own dodge draw", failures)
	TestAssertions.near(unblocked.block_draw, 0.90, 0.001, "third non-dodged instance receives a block draw", failures)
	TestAssertions.truthy(not unblocked.blocked, "third instance is independently unblocked", failures)
	TestAssertions.equal(rng.draw_count, 5, "dodge consumes one draw and each non-dodged instance consumes dodge plus block", failures)
	TestAssertions.near(dodged.final_damage, 0.0, 0.001, "dodged instance deals zero damage", failures)
	TestAssertions.near(blocked.final_damage, 30.0, 0.001, "blocked critical instance derives from typed base", failures)
	TestAssertions.near(unblocked.final_damage, 60.0, 0.001, "unblocked critical instance derives from typed base", failures)
	TestAssertions.truthy(not dodged.proc_eligible and blocked.proc_eligible and unblocked.proc_eligible, "only successful living-target damage is proc eligible", failures)
	TestAssertions.near(target_health.current_health, 410.0, 0.001, "only successful defended instances mutate health", failures)

	var prevented_health := _health(100.0, 100.0)
	var prevented_target := _adapter(&"enemy:fully_prevented", 2, prevented_health, {
		&"dodge_chance": 0.50,
		&"block_chance": 0.50,
		&"block_effectiveness": 1.0,
	})
	var prevented_snapshot: Object = resolver_script.call("capture_defense", packet, prevented_target, types)
	var prevented_rng := CombatRng.new(72, [0.90, 0.10])
	var prevented: DamageResult = resolver_script.call("resolve_instance", packet, 0, true, prevented_snapshot, prevented_target, prevented_rng, types, true, true) as DamageResult
	TestAssertions.truthy(prevented.valid and prevented.blocked, "fully prevented instance still resolves successfully", failures)
	TestAssertions.near(prevented.final_damage, 0.0, 0.001, "full block records zero final damage", failures)
	TestAssertions.near(prevented.actual_health_removed, 0.0, 0.001, "full block removes no health", failures)
	TestAssertions.truthy(not prevented.proc_eligible, "fully prevented damage is not proc eligible", failures)
	TestAssertions.near(prevented_health.current_health, 100.0, 0.001, "fully prevented damage preserves health", failures)
	TestAssertions.equal(prevented_rng.draw_count, 2, "fully prevented non-dodged instance consumes dodge and block draws", failures)

func _test_frozen_snapshot_and_invalid_data(resolver_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:frozen_defense", 1, null, {&"crit_chance": 1.0, &"crit_multiplier": 2.0})
	var packet := DamageResolver.prepare(_attack([&"physical"], [100.0], true), source, CombatRng.new(73), types)
	var target_health := _health(200.0, 200.0)
	var target := _adapter(&"enemy:frozen_defense", 2, target_health, {
		&"dodge_chance": 0.25,
		&"armor": 100.0,
		&"block_chance": 0.50,
		&"block_effectiveness": 0.50,
	}, true, 0.50)
	var snapshot: Object = resolver_script.call("capture_defense", packet, target, types)
	TestAssertions.truthy(snapshot != null and bool(snapshot.get("valid")), "frozen defense capture succeeds", failures)
	if snapshot == null or not bool(snapshot.get("valid")):
		return
	TestAssertions.equal(snapshot.get("target_id"), &"enemy:frozen_defense", "snapshot captures immutable target identity", failures)
	TestAssertions.near(float(snapshot.get("dodge_chance")), 0.25, 0.001, "snapshot captures dodge chance", failures)
	TestAssertions.near(float(snapshot.get("incoming_multiplier")), 0.50, 0.001, "snapshot captures packet-specific incoming multiplier", failures)
	TestAssertions.near(float(snapshot.get("block_chance")), 0.50, 0.001, "snapshot captures block chance", failures)
	TestAssertions.near(float(snapshot.get("block_effectiveness")), 0.50, 0.001, "snapshot captures block effectiveness", failures)
	var exposed_defenses: Dictionary = snapshot.get("type_defenses")
	TestAssertions.near(float((exposed_defenses[&"physical"] as Dictionary)["defense_value"]), 100.0, 0.001, "snapshot captures per-type defense", failures)
	exposed_defenses[&"physical"] = {"defense_value": 0.0, "defense_stat_id": &"armor", "mitigation_rule": DamageTypeDefinition.MitigationRule.ARMOR}
	snapshot.set("dodge_chance", 0.95)
	target.stats.set_resolved(&"dodge_chance", 0.95, [])
	target.stats.set_resolved(&"armor", 0.0, [])
	target.stats.set_resolved(&"block_chance", 0.0, [])
	target.stats.set_resolved(&"block_effectiveness", 0.0, [])
	target.incoming_provider = func(_packet: DamagePacket) -> float: return 1.0
	var rng := CombatRng.new(74, [0.90, 0.10])
	var frozen: DamageResult = resolver_script.call("resolve_instance", packet, 0, true, snapshot, target, rng, types, true, true) as DamageResult
	TestAssertions.truthy(frozen.valid and not frozen.dodged and frozen.blocked, "resolution uses frozen dodge and block values after live mutation", failures)
	TestAssertions.near(float(frozen.component_breakdowns[0]["defense_value"]), 100.0, 0.001, "resolution uses frozen per-type defense after exposed-copy and live mutation", failures)
	TestAssertions.near(frozen.total_post_mitigation, 100.0, 0.001, "critical amount is derived from typed base before frozen armor", failures)
	TestAssertions.near(frozen.incoming_multiplier, 0.50, 0.001, "resolution uses frozen incoming multiplier", failures)
	TestAssertions.near(frozen.block_effectiveness, 0.50, 0.001, "resolution uses frozen block effectiveness", failures)
	TestAssertions.near(frozen.final_damage, 25.0, 0.001, "all frozen defensive inputs determine final damage", failures)
	TestAssertions.equal(rng.draw_count, 2, "frozen partial chances consume deterministic draws", failures)
	var blank_snapshot: Object = (load("res://scripts/combat/damage_defense_snapshot.gd") as Script).new()
	var blank_rng := CombatRng.new(741, [0.10, 0.10])
	var blank_result: DamageResult = resolver_script.call("resolve_instance", packet, 0, true, blank_snapshot, target, blank_rng, types, true, true) as DamageResult
	TestAssertions.truthy(not blank_result.valid and blank_result.error_reason.contains("invalid defense snapshot"), "blank snapshot fails safely with a stable diagnostic", failures)
	TestAssertions.equal(blank_rng.draw_count, 0, "blank snapshot consumes no defender RNG", failures)

	var invalid_health := _health(100.0, 100.0)
	var invalid_target := _adapter(&"enemy:invalid_snapshot", 2, invalid_health, {&"armor": INF})
	var invalid_snapshot: Object = resolver_script.call("capture_defense", packet, invalid_target, types)
	TestAssertions.truthy(invalid_snapshot != null and not bool(invalid_snapshot.get("valid")), "non-finite defense creates structured invalid snapshot", failures)
	TestAssertions.truthy(String(invalid_snapshot.get("error_reason")).contains("defense must be finite"), "invalid snapshot reports stable defense diagnostic", failures)
	var invalid_rng := CombatRng.new(75, [0.10, 0.10])
	var invalid_result: DamageResult = resolver_script.call("resolve_instance", packet, 0, true, invalid_snapshot, invalid_target, invalid_rng, types, true, true) as DamageResult
	TestAssertions.truthy(not invalid_result.valid and invalid_result.error_reason.contains("defense must be finite"), "invalid snapshot fails resolution safely and diagnostically", failures)
	TestAssertions.equal(invalid_rng.draw_count, 0, "invalid snapshot consumes no defender RNG", failures)
	TestAssertions.near(invalid_health.current_health, 100.0, 0.001, "invalid snapshot preserves target health", failures)

func _test_post_death_calculation(resolver_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source_health := _health(100.0, 50.0)
	var source := _adapter(&"party:post_death", 1, source_health, {&"crit_chance": 3.0, &"crit_multiplier": 2.0})
	var prepared: Array[PreparedDamageComponent] = [PreparedDamageComponent.new(&"physical", 30.0, 30.0, 30.0, 30.0)]
	var roll: RefCounted = MULTI_CRIT_ROLL.create(3.0, CombatRng.new(76))
	var packet := DamagePacket.create(source, &"post_death_hit", [], true, true, -1.0, 2.0, 0.50, prepared, roll)
	var target_health := _health(100.0, 100.0)
	var target := _adapter(&"enemy:post_death", 2, target_health, {})
	var snapshot: Object = resolver_script.call("capture_defense", packet, target, types)
	var first: DamageResult = resolver_script.call("resolve_instance", packet, 0, true, snapshot, target, CombatRng.new(77), types, true, true) as DamageResult
	var killing: DamageResult = resolver_script.call("resolve_instance", packet, 1, true, snapshot, target, CombatRng.new(78), types, true, true) as DamageResult
	TestAssertions.truthy(first.target_was_alive and not first.killing_blow and first.proc_eligible, "first living instance records proc-eligible evidence", failures)
	TestAssertions.near(first.health_before, 100.0, 0.001, "first instance records health before damage", failures)
	TestAssertions.truthy(killing.target_was_alive and killing.killing_blow and not killing.overkill_only, "second instance records the single killing blow", failures)
	TestAssertions.near(killing.health_before, 40.0, 0.001, "killing instance records pre-hit health", failures)
	TestAssertions.near(killing.excess_damage, 20.0, 0.001, "killing instance records excess damage", failures)
	TestAssertions.near(target_health.current_health, 0.0, 0.001, "earlier instances kill the target", failures)
	TestAssertions.near(source_health.current_health, 100.0, 0.001, "living instances may restore life from actual health removed", failures)

	target.stats.set_resolved(&"dodge_chance", 1.0, [])
	target.stats.set_resolved(&"armor", INF, [])
	target.stats.set_resolved(&"block_chance", 1.0, [])
	target.stats.set_resolved(&"block_effectiveness", 1.0, [])
	target.incoming_provider = func(_packet: DamagePacket) -> float: return 0.0
	var post_death_rng := CombatRng.new(79)
	var post_death: DamageResult = resolver_script.call("resolve_instance", packet, 2, true, snapshot, target, post_death_rng, types, false, false) as DamageResult
	TestAssertions.truthy(post_death.valid and not post_death.dodged, "post-death calculation uses the frozen defenses", failures)
	TestAssertions.equal(post_death.instance_index, 2, "post-death evidence preserves instance order", failures)
	TestAssertions.truthy(not post_death.target_was_alive and post_death.overkill_only, "post-death instance is marked overkill-only", failures)
	TestAssertions.near(post_death.health_before, 0.0, 0.001, "post-death calculation records zero health before", failures)
	TestAssertions.near(post_death.final_damage, 60.0, 0.001, "post-death critical damage derives from the frozen typed base", failures)
	TestAssertions.near(post_death.actual_health_removed, 0.0, 0.001, "calculate-only post-death instance applies no health mutation", failures)
	TestAssertions.near(post_death.excess_damage, 60.0, 0.001, "successful post-death damage is recorded for later overkill aggregation", failures)
	TestAssertions.truthy(not post_death.killing_blow and not post_death.proc_eligible, "post-death instance emits no kill or proc eligibility", failures)
	TestAssertions.near(target_health.current_health, 0.0, 0.001, "post-death calculation leaves target health unchanged", failures)
	TestAssertions.near(source_health.current_health, 100.0, 0.001, "disabled post-death life steal leaves source health unchanged", failures)
	TestAssertions.equal(post_death_rng.draw_count, 0, "frozen zero dodge and block chances consume no post-death draws", failures)

func _test_compatibility_resolve_uses_first_instance(types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:compatibility", 1, null, {&"crit_chance": 2.0, &"crit_multiplier": 2.0})
	var packet := DamageResolver.prepare(_attack([&"physical"], [20.0], true), source, CombatRng.new(80), types)
	var target_health := _health(200.0, 200.0)
	var target := _adapter(&"enemy:compatibility", 2, target_health, {})
	var result := DamageResolver.resolve(packet, target, CombatRng.new(81), types)
	TestAssertions.truthy(result.valid and result.critical, "compatibility resolve uses first authoritative critical flag", failures)
	TestAssertions.equal(result.instance_index, 0, "compatibility resolve reports first instance index", failures)
	TestAssertions.near(result.final_damage, 40.0, 0.001, "compatibility resolve applies one critical instance", failures)
	TestAssertions.near(target_health.current_health, 160.0, 0.001, "compatibility resolve does not iterate the remaining bundle", failures)

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

func _has_property(object: Object, property_name: StringName) -> bool:
	return object.get_property_list().any(func(property: Dictionary) -> bool:
		return property.get("name") == property_name
	)
