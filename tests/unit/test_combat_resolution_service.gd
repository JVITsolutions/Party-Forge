extends RefCounted

const SERVICE_PATH := "res://scripts/combat/combat_resolution_service.gd"
const MULTI_CRIT_ROLL := preload("res://scripts/combat/multi_crit_roll.gd")

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
	_test_capture_callback_health_invalidation_fails_before_preflight(service_script, types, failures)
	_test_post_kill_callbacks_cannot_abort_prepared_flags(service_script, types, failures)
	_test_later_critical_overflow_fails_preflight(service_script, types, failures)
	_test_aggregate_overkill_overflow_fails_preflight(service_script, types, failures)
	_test_same_service_reentrancy_is_rejected_without_publication(service_script, types, failures)
	_test_nonfinite_target_position_fails_before_resolution(service_script, types, failures)
	_test_zero_damage_ceiling_bundle_is_structurally_bounded(service_script, types, failures)
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

func _test_capture_callback_health_invalidation_fails_before_preflight(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:capture_invalid", 1, null, {&"crit_chance": 1.0, &"crit_multiplier": 2.0})
	var packet := DamageResolver.prepare(_attack(30.0), source, CombatRng.new(535), types)
	var target_health := _health(100.0, 100.0)
	var health_cell: Array = [target_health]
	var target := _adapter(&"enemy:capture_invalid", 2, target_health, {&"dodge_chance": 0.5, &"block_chance": 0.5})
	target.incoming_provider = func(_packet: DamagePacket) -> float:
		var live_health := health_cell[0] as HealthComponent
		if is_instance_valid(live_health):
			live_health.free()
		health_cell[0] = null
		target.health = null
		return 1.0
	var rng := CombatRng.new(536, [0.9, 0.9])
	var service: Node = service_script.new(rng, types)
	var publications := _publication_counts(service)
	var bundle: Object = service.call(&"resolve_bundle", packet, target)
	TestAssertions.truthy(bundle != null and not bool(bundle.get("valid")), "capture callback health invalidation returns a failed bundle", failures)
	if bundle != null:
		var diagnostics := bundle.get("diagnostics") as Dictionary
		TestAssertions.equal((bundle.get("results") as Array).size(), 0, "capture callback invalidation fails before runtime results", failures)
		TestAssertions.equal(diagnostics.get("failed_instance_index", 99), -1, "capture callback invalidation is attributed before instance preflight", failures)
		TestAssertions.equal(diagnostics.get("capture_failed", false), true, "capture callback invalidation is explicitly diagnosed at capture boundary", failures)
		TestAssertions.truthy(String(bundle.get("error_reason")).contains("health became unavailable during defense capture"), "capture callback invalidation has stable contextual failure text", failures)
		TestAssertions.truthy(_numeric_diagnostics_are_finite(diagnostics), "capture callback invalidation diagnostics remain finite", failures)
	TestAssertions.equal(rng.draw_count, 0, "capture callback invalidation consumes no defender RNG", failures)
	TestAssertions.equal(publications["hit"][0], 0, "capture callback invalidation emits no hit proc", failures)
	TestAssertions.equal(publications["crit"][0], 0, "capture callback invalidation emits no crit proc", failures)
	TestAssertions.equal(publications["kill"][0], 0, "capture callback invalidation emits no kill", failures)
	TestAssertions.equal(publications["completed"][0], 0, "capture callback invalidation emits no completed bundle", failures)
	TestAssertions.equal(publications["failed"][0], 1, "capture callback invalidation emits one failed contract", failures)
	TestAssertions.equal(publications["diagnostics"][0], 1, "capture callback invalidation emits one diagnostics snapshot", failures)
	TestAssertions.equal(service.get("overkill_buffer").call(&"size"), 0, "capture callback invalidation leaves overkill buffer untouched", failures)
	service.free()

func _test_post_kill_callbacks_cannot_abort_prepared_flags(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	for freeing_signal: String in ["hit", "crit", "kill"]:
		var source := _adapter(StringName("party:post_kill_%s" % freeing_signal), 1, null, {&"crit_chance": 3.0, &"crit_multiplier": 2.0})
		var packet := DamageResolver.prepare(_attack(30.0), source, CombatRng.new(540), types)
		var target_health := _health(100.0, 100.0)
		var health_cell: Array = [target_health]
		var target_id := StringName("enemy:post_kill_%s" % freeing_signal)
		var target := _adapter(target_id, 2, target_health, {})
		var service: Node = service_script.new(CombatRng.new(541), types)
		var hit_count := [0]
		var crit_count := [0]
		var kill_count := [0]
		var completed_count := [0]
		service.connect(&"hit_proc_requested", func(event: Variant) -> void:
			hit_count[0] += 1
			if freeing_signal == "hit" and int(event.get("instance_index")) == 1:
				var live_health := health_cell[0] as HealthComponent
				if is_instance_valid(live_health):
					live_health.free()
				health_cell[0] = null
		)
		service.connect(&"crit_proc_requested", func(event: Variant) -> void:
			crit_count[0] += 1
			if freeing_signal == "crit" and int(event.get("instance_index")) == 1:
				var live_health := health_cell[0] as HealthComponent
				if is_instance_valid(live_health):
					live_health.free()
				health_cell[0] = null
		)
		service.connect(&"target_killed", func(_event: Variant) -> void:
			kill_count[0] += 1
			if freeing_signal == "kill":
				var live_health := health_cell[0] as HealthComponent
				if is_instance_valid(live_health):
					live_health.free()
				health_cell[0] = null
		)
		service.connect(&"bundle_completed", func(_bundle: Variant) -> void: completed_count[0] += 1)
		var bundle: Object = service.call(&"resolve_bundle", packet, target)
		TestAssertions.truthy(bundle != null and bool(bundle.get("valid")), "%s callback cannot abort already-prepared post-death flags" % freeing_signal, failures)
		if bundle != null and bool(bundle.get("valid")):
			TestAssertions.equal((bundle.get("results") as Array).size(), 3, "%s callback retains all ordered results" % freeing_signal, failures)
			TestAssertions.near(float(bundle.get("total_overkill")), 80.0, 0.0001, "%s callback retains exact total overkill" % freeing_signal, failures)
			var record: Object = service.get("overkill_buffer").call(&"get_record", target_id)
			TestAssertions.truthy(record != null, "%s callback still records overkill" % freeing_signal, failures)
			if record != null:
				TestAssertions.near(float(record.get("amount")), 80.0, 0.0001, "%s callback buffers exact overkill" % freeing_signal, failures)
		TestAssertions.equal(hit_count[0], 2, "%s callback preserves living hit count" % freeing_signal, failures)
		TestAssertions.equal(crit_count[0], 2, "%s callback preserves living crit count" % freeing_signal, failures)
		TestAssertions.equal(kill_count[0], 1, "%s callback preserves one kill" % freeing_signal, failures)
		TestAssertions.equal(completed_count[0], 1, "%s callback preserves one completion" % freeing_signal, failures)
		service.free()

func _test_later_critical_overflow_fails_preflight(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:late_overflow", 1, null, {})
	var packet := _direct_packet(source, 9.0e307, 2.0, [false, true])
	var target_health := _health(1.0e308, 1.0e308)
	var target := _adapter(&"enemy:late_overflow", 2, target_health, {&"dodge_chance": 0.5, &"block_chance": 0.5})
	var rng := CombatRng.new(550, [0.9, 0.9])
	var service: Node = service_script.new(rng, types)
	var publications := _publication_counts(service)
	var bundle: Object = service.call(&"resolve_bundle", packet, target)
	_assert_preflight_failure(bundle, target_health, 1.0e308, rng, publications, 1, "later critical overflow", failures)
	service.free()

func _test_aggregate_overkill_overflow_fails_preflight(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:aggregate_overflow", 1, null, {})
	var packet := _direct_packet(source, 9.0e307, 1.0, [true, true])
	var target_health := _health(1.0, 1.0)
	var target := _adapter(&"enemy:aggregate_overflow", 2, target_health, {&"dodge_chance": 0.5, &"block_chance": 0.5})
	var rng := CombatRng.new(551, [0.9, 0.9])
	var service: Node = service_script.new(rng, types)
	var publications := _publication_counts(service)
	var bundle: Object = service.call(&"resolve_bundle", packet, target)
	_assert_preflight_failure(bundle, target_health, 1.0, rng, publications, 1, "aggregate overkill overflow", failures)
	if bundle != null:
		TestAssertions.truthy(is_finite(float(bundle.get("total_overkill"))), "failed aggregate never publishes infinite overkill", failures)
	TestAssertions.equal(service.get("overkill_buffer").call(&"get_record", &"enemy:aggregate_overflow"), null, "failed aggregate never reaches the overkill buffer", failures)
	service.free()

func _test_same_service_reentrancy_is_rejected_without_publication(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:reentrant", 1, null, {&"crit_chance": 3.0, &"crit_multiplier": 2.0})
	var packet := DamageResolver.prepare(_attack(30.0), source, CombatRng.new(560), types)
	var target_health := _health(200.0, 200.0)
	var target := _adapter(&"enemy:reentrant", 2, target_health, {})
	var service: Node = service_script.new(CombatRng.new(561), types)
	var hit_count := [0]
	var crit_count := [0]
	var kill_count := [0]
	var completed_count := [0]
	var failed_signal_count := [0]
	var diagnostics_count := [0]
	var reentrant_results: Array = []
	service.connect(&"hit_proc_requested", func(_event: Variant) -> void:
		hit_count[0] += 1
		if hit_count[0] == 1:
			reentrant_results.append(service.call(&"resolve_bundle", packet, target))
	)
	service.connect(&"crit_proc_requested", func(_event: Variant) -> void: crit_count[0] += 1)
	service.connect(&"target_killed", func(_event: Variant) -> void: kill_count[0] += 1)
	service.connect(&"bundle_completed", func(_bundle: Variant) -> void: completed_count[0] += 1)
	service.connect(&"bundle_failed", func(_bundle: Variant) -> void: failed_signal_count[0] += 1)
	service.connect(&"diagnostics_changed", func(_diagnostics: Dictionary) -> void:
		diagnostics_count[0] += 1
		if diagnostics_count[0] == 1:
			reentrant_results.append(service.call(&"resolve_bundle", packet, target))
	)
	var outer: Object = service.call(&"resolve_bundle", packet, target)
	TestAssertions.truthy(outer != null and bool(outer.get("valid")), "outer bundle remains authoritative during reentry attempts", failures)
	TestAssertions.equal(reentrant_results.size(), 2, "hit and diagnostics callbacks each receive a reentry result", failures)
	for result: Object in reentrant_results:
		TestAssertions.truthy(result != null and result.get("valid") == false and String(result.get("error_reason")).contains("reentrant"), "same-service reentry returns a stable failed result", failures)
	TestAssertions.equal(hit_count[0], 3, "reentry emits no recursive hit signals", failures)
	TestAssertions.equal(crit_count[0], 3, "reentry emits no recursive crit signals", failures)
	TestAssertions.equal(kill_count[0], 0, "non-killing outer bundle emits no kill", failures)
	TestAssertions.equal(completed_count[0], 1, "only outer bundle completes", failures)
	TestAssertions.equal(failed_signal_count[0], 0, "reentry failure emits no recursive failure signal", failures)
	TestAssertions.equal(diagnostics_count[0], 1, "reentry emits no recursive diagnostics", failures)
	TestAssertions.equal((service.get("latest_diagnostics") as Dictionary).get("resolution_valid"), true, "outer diagnostics remain latest after diagnostics-callback reentry", failures)
	TestAssertions.near(target_health.current_health, 20.0, 0.0001, "reentry cannot mutate outer target beyond three instances", failures)
	TestAssertions.equal(service.get("overkill_buffer").call(&"size"), 0, "reentry cannot mutate the outer buffer", failures)
	service.free()

func _test_nonfinite_target_position_fails_before_resolution(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:bad_position", 1, null, {&"crit_chance": 1.0, &"crit_multiplier": 2.0})
	var packet := DamageResolver.prepare(_attack(30.0), source, CombatRng.new(570), types)
	var target_health := _health(100.0, 100.0)
	var actor := Node3D.new()
	actor.position = Vector3(NAN, 2.0, 3.0)
	_actors.append(actor)
	var target := _adapter(&"enemy:bad_position", 2, target_health, {&"dodge_chance": 0.5}, true, actor)
	var rng := CombatRng.new(571, [0.9])
	var service: Node = service_script.new(rng, types)
	var publications := _publication_counts(service)
	var bundle: Object = service.call(&"resolve_bundle", packet, target)
	TestAssertions.truthy(bundle != null and not bool(bundle.get("valid")) and String(bundle.get("error_reason")).contains("position"), "non-finite captured position returns structured failure", failures)
	TestAssertions.near(target_health.current_health, 100.0, 0.0001, "non-finite position fails before health mutation", failures)
	TestAssertions.equal(rng.draw_count, 0, "non-finite position fails before defender RNG", failures)
	TestAssertions.equal(publications["hit"][0], 0, "non-finite position emits no hit", failures)
	TestAssertions.equal(publications["completed"][0], 0, "non-finite position emits no completed presentation", failures)
	TestAssertions.equal(publications["failed"][0], 1, "non-finite position emits one failed contract", failures)
	TestAssertions.equal(service.get("overkill_buffer").call(&"size"), 0, "non-finite position publishes no buffer metadata", failures)
	service.free()

func _test_zero_damage_ceiling_bundle_is_structurally_bounded(service_script: Script, types: DamageTypeCatalog, failures: Array[String]) -> void:
	var source := _adapter(&"party:ceiling_zero", 1, null, {})
	var flags: Array[bool] = []
	flags.resize(10000)
	flags.fill(true)
	var packet := _direct_packet(source, 0.0, 1.0, flags)
	var target_health := _health(100.0, 100.0)
	var target := _adapter(&"enemy:ceiling_zero", 2, target_health, {})
	var rng := CombatRng.new(581)
	var service: Node = service_script.new(rng, types)
	var publications := _publication_counts(service)
	var bundle: Object = service.call(&"resolve_bundle", packet, target)
	TestAssertions.truthy(bundle != null and bool(bundle.get("valid")), "ten-thousand zero-damage flags resolve structurally", failures)
	if bundle != null and not bool(bundle.get("valid")):
		failures.append("ten-thousand zero-damage diagnostic: %s" % bundle.get("error_reason"))
	if bundle != null and bool(bundle.get("valid")):
		TestAssertions.equal((bundle.get("results") as Array).size(), 10000, "service result array is bounded at ten thousand", failures)
		TestAssertions.equal((bundle.get("presentation_events") as Array).size(), 10000, "presentation contract is bounded at ten thousand", failures)
		TestAssertions.equal((bundle.get("diagnostics") as Dictionary).get("processed_instances"), 10000, "service diagnostics preserve ceiling count", failures)
		TestAssertions.near(float(bundle.get("total_overkill")), 0.0, 0.0001, "zero-damage ceiling bundle records no overkill", failures)
	TestAssertions.near(target_health.current_health, 100.0, 0.0001, "zero-damage ceiling bundle never changes health", failures)
	TestAssertions.equal(rng.draw_count, 0, "zero-damage ceiling bundle consumes no zero-chance defender draws", failures)
	TestAssertions.equal(publications["hit"][0], 0, "zero-damage ceiling bundle emits no hit proc", failures)
	TestAssertions.equal(publications["crit"][0], 0, "zero-damage ceiling bundle emits no crit proc", failures)
	TestAssertions.equal(publications["kill"][0], 0, "zero-damage ceiling bundle emits no kill", failures)
	TestAssertions.equal(publications["completed"][0], 1, "zero-damage ceiling bundle completes exactly once", failures)
	TestAssertions.equal(service.get("overkill_buffer").call(&"size"), 0, "no-kill ceiling bundle creates no overkill record", failures)
	service.free()

func _publication_counts(service: Node) -> Dictionary:
	var counts := {
		"hit": [0],
		"crit": [0],
		"kill": [0],
		"completed": [0],
		"failed": [0],
		"diagnostics": [0],
	}
	service.connect(&"hit_proc_requested", func(_event: Variant) -> void: counts["hit"][0] += 1)
	service.connect(&"crit_proc_requested", func(_event: Variant) -> void: counts["crit"][0] += 1)
	service.connect(&"target_killed", func(_event: Variant) -> void: counts["kill"][0] += 1)
	service.connect(&"bundle_completed", func(_bundle: Variant) -> void: counts["completed"][0] += 1)
	service.connect(&"bundle_failed", func(_bundle: Variant) -> void: counts["failed"][0] += 1)
	service.connect(&"diagnostics_changed", func(_diagnostics: Dictionary) -> void: counts["diagnostics"][0] += 1)
	return counts

func _assert_preflight_failure(bundle: Object, health: HealthComponent, expected_health: float, rng: CombatRng, publications: Dictionary, failed_index: int, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(bundle != null and not bool(bundle.get("valid")), "%s returns failed bundle" % label, failures)
	if bundle != null:
		TestAssertions.equal((bundle.get("results") as Array).size(), 0, "%s fails before runtime results" % label, failures)
		TestAssertions.equal((bundle.get("diagnostics") as Dictionary).get("failed_instance_index"), failed_index, "%s identifies preflight index" % label, failures)
		TestAssertions.truthy(_numeric_diagnostics_are_finite(bundle.get("diagnostics") as Dictionary), "%s diagnostics remain finite" % label, failures)
	TestAssertions.near(health.current_health, expected_health, 0.0, "%s fails before health mutation" % label, failures)
	TestAssertions.equal(rng.draw_count, 0, "%s fails before defender RNG" % label, failures)
	TestAssertions.equal(publications["hit"][0], 0, "%s emits no hit proc" % label, failures)
	TestAssertions.equal(publications["crit"][0], 0, "%s emits no crit proc" % label, failures)
	TestAssertions.equal(publications["kill"][0], 0, "%s emits no kill" % label, failures)
	TestAssertions.equal(publications["completed"][0], 0, "%s emits no completed bundle" % label, failures)
	TestAssertions.equal(publications["failed"][0], 1, "%s emits one failed contract" % label, failures)

func _direct_packet(source: CombatantAdapter, typed_amount: float, multiplier: float, flags: Array[bool]) -> DamagePacket:
	var roll: RefCounted = MULTI_CRIT_ROLL.new()
	roll.set("_crit_chance", float(flags.size()))
	roll.set("_requested_instances", flags.size())
	roll.set("_processed_instances", flags.size())
	roll.set("_guaranteed_instances", flags.count(true))
	roll.set("_critical_flags", flags.duplicate())
	var prepared: Array[PreparedDamageComponent] = [PreparedDamageComponent.new(&"physical", typed_amount, typed_amount, typed_amount, typed_amount)]
	return DamagePacket.create(source, &"task5_preflight", [], true, flags[0], -1.0, multiplier, 0.0, prepared, roll)

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
