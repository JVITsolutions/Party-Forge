extends RefCounted

const SERVICE_PATH := "res://scripts/combat/combat_resolution_service.gd"

var _health_nodes: Array[HealthComponent] = []
var _actors: Array[Node3D] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	var service_exists := ResourceLoader.exists(SERVICE_PATH)
	TestAssertions.truthy(service_exists, "run-scoped combat resolution service exists", failures)
	if not service_exists:
		return failures
	var service_script := load(SERVICE_PATH) as Script
	TestAssertions.truthy(service_script != null, "combat resolution service loads", failures)
	if service_script == null:
		return failures
	var types := GameCatalog.load_defaults().damage_types
	_test_ordered_bundle_contract(service_script, types, failures)
	_test_post_death_dodge_and_block(service_script, types, failures)
	_test_mid_bundle_invalid_boundary(service_script, types, failures)
	_test_freed_health_invalid_boundary(service_script, types, failures)
	for actor: Node3D in _actors:
		actor.free()
	for health: HealthComponent in _health_nodes:
		if is_instance_valid(health):
			health.free()
	return failures

func _test_ordered_bundle_contract(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source_health := _health(100.0, 10.0)
	var source := _adapter(&"party:bundle", 1, source_health, {
		&"crit_chance": 3.0,
		&"crit_multiplier": 2.0,
		&"life_steal": 0.5,
	})
	var packet := DamageResolver.prepare(_attack(30.0), source, CombatRng.new(501), types)
	var target_health := _health(100.0, 100.0)
	var actor := Node3D.new()
	actor.position = Vector3(1.0, 2.0, 3.0)
	_actors.append(actor)
	var target := _adapter(&"enemy:bundle", 2, target_health, {}, true, actor)
	var service: Node = service_script.new(CombatRng.new(502), types)
	var hit_events: Array = []
	var crit_events: Array = []
	var life_steal_events: Array = []
	var kill_events: Array = []
	var completed_bundles: Array = []
	var diagnostics_events: Array = []
	service.connect(&"hit_proc_requested", func(event: Variant) -> void:
		hit_events.append(event)
		actor.position = Vector3(100.0, 100.0, 100.0)
	)
	service.connect(&"crit_proc_requested", func(event: Variant) -> void: crit_events.append(event))
	service.connect(&"life_steal_requested", func(event: Variant) -> void: life_steal_events.append(event))
	service.connect(&"target_killed", func(event: Variant) -> void: kill_events.append(event))
	service.connect(&"bundle_completed", func(bundle: Variant) -> void: completed_bundles.append(bundle))
	service.connect(&"diagnostics_changed", func(diagnostics: Dictionary) -> void: diagnostics_events.append(diagnostics))

	var bundle: Object = service.call(&"resolve_bundle", packet, target)
	TestAssertions.truthy(bundle != null and bool(bundle.get("valid")), "three-critical bundle resolves synchronously", failures)
	if bundle == null or not bool(bundle.get("valid")):
		service.free()
		return
	var results := bundle.get("results") as Array
	var events := bundle.get("presentation_events") as Array
	TestAssertions.equal(results.size(), 3, "all three damage results are returned", failures)
	TestAssertions.equal(results.map(func(result: Variant) -> int: return int(result.get("instance_index"))), [0, 1, 2], "damage results preserve critical-flag order", failures)
	TestAssertions.equal(results.map(func(result: Variant) -> float: return float(result.get("final_damage"))), [60.0, 60.0, 60.0], "ordered bundle retains all resolved damage", failures)
	TestAssertions.near(target_health.current_health, 0.0, 0.0001, "target health is zero before resolve_bundle returns", failures)
	TestAssertions.equal(hit_events.size(), 2, "exactly two living hit-proc requests fire", failures)
	TestAssertions.equal(crit_events.size(), 2, "exactly two living crit-proc requests fire", failures)
	TestAssertions.equal(life_steal_events.size(), 2, "exactly two living life-steal requests fire", failures)
	TestAssertions.equal(kill_events.size(), 1, "exactly one kill event fires on the live-to-dead transition", failures)
	TestAssertions.equal(completed_bundles.size(), 1, "one completed presentation bundle publishes", failures)
	TestAssertions.equal(diagnostics_events.size(), 1, "one diagnostics snapshot publishes", failures)
	TestAssertions.truthy(bool(results[1].get("killing_blow")), "second ordered instance is the killing blow", failures)
	TestAssertions.near(float(results[1].get("excess_damage")), 20.0, 0.0001, "killing instance records twenty excess", failures)
	TestAssertions.truthy(bool(results[2].get("overkill_only")) and not bool(results[2].get("proc_eligible")), "third instance is post-death overkill-only with no proc eligibility", failures)
	TestAssertions.near(float(results[2].get("actual_health_removed")), 0.0, 0.0001, "post-death instance removes no health", failures)
	TestAssertions.near(float(results[2].get("life_steal_restored")), 0.0, 0.0001, "post-death instance restores no life", failures)
	TestAssertions.near(source_health.current_health, 60.0, 0.0001, "life steal uses only the two living health removals", failures)

	TestAssertions.equal(events.size(), 3, "presentation bundle contains three damage-number events", failures)
	TestAssertions.equal(events.map(func(event: Variant) -> int: return int(event.get("instance_index"))), [0, 1, 2], "presentation event order matches resolution order", failures)
	TestAssertions.equal(events.filter(func(event: Variant) -> bool: return bool(event.get("flash_eligible"))).size(), 2, "only two living events are flash eligible", failures)
	TestAssertions.equal(events.filter(func(event: Variant) -> bool: return bool(event.get("overkill_only"))).size(), 1, "one presentation event is distinctly overkill-only", failures)
	TestAssertions.equal(events.map(func(event: Variant) -> Vector3: return event.get("target_position") as Vector3), [Vector3(1.0, 2.0, 3.0), Vector3(1.0, 2.0, 3.0), Vector3(1.0, 2.0, 3.0)], "presentation uses one captured world position even if the actor moves", failures)
	TestAssertions.near(float(bundle.get("total_overkill")), 80.0, 0.0001, "killing excess plus post-death damage totals eighty overkill", failures)
	var record: Object = service.get("overkill_buffer").call(&"get_record", &"enemy:bundle")
	TestAssertions.truthy(record != null, "completed killing bundle is readable from the run buffer", failures)
	if record != null:
		TestAssertions.near(float(record.get("amount")), 80.0, 0.0001, "buffer stores total bundle overkill", failures)

	var diagnostics := bundle.get("diagnostics") as Dictionary
	TestAssertions.equal(diagnostics.get("requested_instances"), 3, "diagnostics copy requested instances", failures)
	TestAssertions.equal(diagnostics.get("processed_instances"), 3, "diagnostics copy processed instances", failures)
	TestAssertions.equal(diagnostics.get("guaranteed_instances"), 3, "diagnostics copy guaranteed instances", failures)
	TestAssertions.equal(diagnostics.get("fractional_draw_consumed"), false, "diagnostics copy remainder consumption", failures)
	TestAssertions.equal(diagnostics.get("ceiling_truncated"), false, "diagnostics copy ceiling state", failures)
	TestAssertions.equal(diagnostics.get("requested_count_overflow"), false, "diagnostics copy count-overflow state", failures)
	TestAssertions.near(float(diagnostics.get("total_overkill")), 80.0, 0.0001, "diagnostics publish total overkill", failures)

	results[0].set("final_damage", 999.0)
	diagnostics["requested_instances"] = 999
	events[0].set("overkill_only", true)
	TestAssertions.near(float((bundle.get("results") as Array)[0].get("final_damage")), 60.0, 0.0001, "bundle defensively copies mutable damage results", failures)
	TestAssertions.equal((bundle.get("diagnostics") as Dictionary)["requested_instances"], 3, "bundle defensively copies diagnostics", failures)
	TestAssertions.truthy(not bool((bundle.get("presentation_events") as Array)[0].get("overkill_only")), "presentation events are immutable", failures)
	service.free()

func _test_post_death_dodge_and_block(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:mixed_post_death", 1, null, {&"crit_chance": 4.0, &"crit_multiplier": 2.0})
	var packet := DamageResolver.prepare(_attack(30.0), source, CombatRng.new(510), types)
	var target_health := _health(50.0, 50.0)
	var target := _adapter(&"enemy:mixed_post_death", 2, target_health, {
		&"dodge_chance": 0.5,
		&"block_chance": 0.5,
		&"block_effectiveness": 1.0,
	})
	var rng := CombatRng.new(511, [0.9, 0.9, 0.1, 0.9, 0.1, 0.9, 0.9])
	var service: Node = service_script.new(rng, types)
	var bundle: Object = service.call(&"resolve_bundle", packet, target)
	TestAssertions.truthy(bundle != null and bool(bundle.get("valid")), "mixed post-death bundle resolves", failures)
	if bundle != null and bool(bundle.get("valid")):
		var results := bundle.get("results") as Array
		TestAssertions.equal(results.size(), 4, "all four prepared flags are processed", failures)
		TestAssertions.truthy(bool(results[1].get("dodged")), "first post-death instance can dodge independently", failures)
		TestAssertions.truthy(bool(results[2].get("blocked")) and float(results[2].get("final_damage")) == 0.0, "second post-death instance can be fully prevented", failures)
		TestAssertions.near(float(results[3].get("final_damage")), 60.0, 0.0001, "successful post-death instance retains would-be damage", failures)
		TestAssertions.near(float(bundle.get("total_overkill")), 70.0, 0.0001, "only killing excess and successful post-death damage enter overkill", failures)
		TestAssertions.equal(rng.draw_count, 7, "every instance uses independent prescribed dodge and block draws", failures)
	service.free()

func _test_mid_bundle_invalid_boundary(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:invalid_boundary", 1, null, {&"crit_chance": 3.0, &"crit_multiplier": 2.0})
	var packet := DamageResolver.prepare(_attack(10.0), source, CombatRng.new(520), types)
	var target_health := _health(100.0, 100.0)
	var target := _adapter(&"enemy:invalid_boundary", 2, target_health, {})
	var service: Node = service_script.new(CombatRng.new(521), types)
	var hit_count := [0]
	var crit_count := [0]
	var kill_count := [0]
	var completed_count := [0]
	var failed_bundles: Array = []
	var failed_diagnostics: Array[Dictionary] = []
	service.connect(&"hit_proc_requested", func(_event: Variant) -> void:
		hit_count[0] += 1
		target.available = false
	)
	service.connect(&"crit_proc_requested", func(_event: Variant) -> void: crit_count[0] += 1)
	service.connect(&"target_killed", func(_event: Variant) -> void: kill_count[0] += 1)
	service.connect(&"bundle_completed", func(_bundle: Variant) -> void: completed_count[0] += 1)
	service.connect(&"bundle_failed", func(bundle: Variant) -> void: failed_bundles.append(bundle))
	service.connect(&"diagnostics_changed", func(diagnostics: Dictionary) -> void: failed_diagnostics.append(diagnostics))
	var bundle: Object = service.call(&"resolve_bundle", packet, target)
	TestAssertions.truthy(bundle != null and not bool(bundle.get("valid")), "mid-bundle invalidation fails closed", failures)
	if bundle != null:
		var results := bundle.get("results") as Array
		TestAssertions.equal(results.size(), 2, "failed bundle retains ordered evidence through the invalid boundary", failures)
		TestAssertions.truthy(bool(results[0].get("valid")) and not bool(results[1].get("valid")), "invalid boundary result is explicit and ordered", failures)
		TestAssertions.equal(int(results[1].get("instance_index")), 1, "invalid result identifies the exact stopped index", failures)
	TestAssertions.equal(hit_count[0], 1, "no hit proc publishes after invalid boundary", failures)
	TestAssertions.equal(crit_count[0], 1, "no crit proc publishes after invalid boundary", failures)
	TestAssertions.equal(kill_count[0], 0, "invalid bundle publishes no misleading kill", failures)
	TestAssertions.equal(completed_count[0], 0, "invalid bundle publishes no completed presentation", failures)
	TestAssertions.equal(failed_bundles.size(), 1, "invalid bundle publishes one failure contract", failures)
	TestAssertions.equal(failed_diagnostics.size(), 1, "invalid bundle publishes one diagnostic snapshot", failures)
	if not failed_diagnostics.is_empty():
		TestAssertions.equal(failed_diagnostics[0].get("resolution_valid"), false, "failed diagnostics are explicitly invalid", failures)
		TestAssertions.equal(failed_diagnostics[0].get("failed_instance_index"), 1, "failed diagnostics preserve the invalid boundary", failures)
		TestAssertions.truthy(_numeric_diagnostics_are_finite(failed_diagnostics[0]), "failed diagnostics publish only finite numeric evidence", failures)
	var latest := service.get("latest_diagnostics") as Dictionary
	TestAssertions.equal(latest.get("failed_instance_index"), 1, "latest diagnostics retain copied failed-boundary evidence", failures)
	TestAssertions.near(target_health.current_health, 80.0, 0.0001, "resolution stops immediately after the invalid boundary", failures)
	service.free()

func _test_freed_health_invalid_boundary(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:freed_health", 1, null, {&"crit_chance": 3.0, &"crit_multiplier": 2.0})
	var packet := DamageResolver.prepare(_attack(10.0), source, CombatRng.new(530), types)
	var target_health := _health(100.0, 100.0)
	var target := _adapter(&"enemy:freed_health", 2, target_health, {})
	var service: Node = service_script.new(CombatRng.new(531), types)
	var completed_count := [0]
	var failed_count := [0]
	service.connect(&"hit_proc_requested", func(_event: Variant) -> void:
		if is_instance_valid(target_health):
			target_health.free()
	)
	service.connect(&"bundle_completed", func(_bundle: Variant) -> void: completed_count[0] += 1)
	service.connect(&"bundle_failed", func(_bundle: Variant) -> void: failed_count[0] += 1)
	var bundle: Object = service.call(&"resolve_bundle", packet, target)
	TestAssertions.truthy(bundle != null and not bool(bundle.get("valid")), "freed captured health fails closed at the next ordered instance", failures)
	if bundle != null:
		var results := bundle.get("results") as Array
		TestAssertions.equal(results.size(), 2, "freed-health failure retains the first result and invalid boundary evidence", failures)
		TestAssertions.equal(int(results[1].get("instance_index")), 1, "freed-health failure identifies the exact stopped index", failures)
	TestAssertions.equal(completed_count[0], 0, "freed-health failure publishes no completed bundle", failures)
	TestAssertions.equal(failed_count[0], 1, "freed-health failure publishes one failure bundle", failures)
	service.free()

func _attack(base_amount: float) -> AttackDefinition:
	var attack := AttackDefinition.new()
	attack.id = &"task5_bundle"
	attack.kind = AttackDefinition.Kind.DIRECT
	attack.cooldown = 1.0
	attack.range = 1.0
	attack.can_crit = true
	var component := AttackDamageComponent.new()
	component.damage_type_id = &"physical"
	component.base_amount = base_amount
	attack.damage_components.append(component)
	return attack

func _adapter(id: StringName, team: int, health: HealthComponent, values: Dictionary, available: bool = true, actor: Node3D = null) -> CombatantAdapter:
	var snapshot := ResolvedStatSnapshot.new()
	var rows: Array[Dictionary] = []
	for stat_id: Variant in values:
		snapshot.set_resolved(StringName(stat_id), float(values[stat_id]), rows)
	return CombatantAdapter.new(actor, id, team, health, snapshot, available)

func _health(maximum: float, current: float) -> HealthComponent:
	var health := HealthComponent.new()
	health.configure(maximum, true, 8.0, 0.5, true)
	health.current_health = current
	_health_nodes.append(health)
	return health

func _numeric_diagnostics_are_finite(diagnostics: Dictionary) -> bool:
	for value: Variant in diagnostics.values():
		if value is float and not is_finite(float(value)):
			return false
	return true
