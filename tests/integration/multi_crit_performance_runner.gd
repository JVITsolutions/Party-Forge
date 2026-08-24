extends SceneTree

const EXACT_INSTANCES := 10000
const TRUNCATED_CHANCE := 10000.50
const COMBAT_RESOLUTION_SERVICE := preload("res://scripts/combat/combat_resolution_service.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var exact := _measure_case("exact", float(EXACT_INSTANCES))
	var truncated := _measure_case("truncated", TRUNCATED_CHANCE)
	var memory_after := Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_peak := Performance.get_monitor(Performance.MEMORY_STATIC_MAX)

	_assert(int(exact.get("requested", -1)) == EXACT_INSTANCES, "exact ceiling request reports 10,000 requested instances")
	_assert(int(exact.get("processed", -1)) == EXACT_INSTANCES, "exact ceiling request processes exactly 10,000 instances")
	_assert(not bool(exact.get("truncated", true)), "exact ceiling request is not marked truncated")
	_assert(int(exact.get("results", -1)) == EXACT_INSTANCES and int(exact.get("events", -1)) == EXACT_INSTANCES, "exact ceiling result and event arrays are bounded to 10,000")
	_assert(int(truncated.get("requested", -1)) == EXACT_INSTANCES + 1, "larger request reports 10,001 requested slots")
	_assert(int(truncated.get("processed", -1)) == EXACT_INSTANCES, "larger request truncates processing at exactly 10,000")
	_assert(bool(truncated.get("truncated", false)), "larger request publishes explicit ceiling truncation")
	_assert(int(truncated.get("results", -1)) == EXACT_INSTANCES and int(truncated.get("events", -1)) == EXACT_INSTANCES, "truncated result and event arrays remain bounded to 10,000")
	for report: Dictionary in [exact, truncated]:
		_assert(bool(report.get("valid", false)), "%s ceiling bundle is valid" % report.get("label", "unknown"))
		_assert(bool(report.get("finite", false)), "%s ceiling totals and remaining health are finite" % report.get("label", "unknown"))
		_assert(bool(report.get("build_unchanged", false)), "%s ceiling resolution does not mutate its attack/source/target build" % report.get("label", "unknown"))
		_assert(is_equal_approx(float(report.get("overkill", -1.0)), 0.0), "%s durable target produces no overkill" % report.get("label", "unknown"))
		_assert(float(report.get("elapsed_ms", -1.0)) >= 0.0 and is_finite(float(report.get("elapsed_ms", NAN))), "%s elapsed-time observation is finite and nonnegative" % report.get("label", "unknown"))
	_assert(is_finite(memory_before) and is_finite(memory_after) and is_finite(memory_peak), "static-memory observations are finite")
	_assert(memory_before >= 0.0 and memory_after >= 0.0 and memory_peak >= maxf(memory_before, memory_after), "static-memory observations are nonnegative with an ordered peak")

	print("MULTI_CRIT_PERFORMANCE_OBSERVATION exact_requested=%d exact_processed=%d exact_elapsed_ms=%.3f truncated_requested=%d truncated_processed=%d truncated_elapsed_ms=%.3f memory_before_bytes=%d memory_after_bytes=%d memory_peak_bytes=%d" % [
		int(exact.get("requested", 0)), int(exact.get("processed", 0)), float(exact.get("elapsed_ms", 0.0)),
		int(truncated.get("requested", 0)), int(truncated.get("processed", 0)), float(truncated.get("elapsed_ms", 0.0)),
		int(memory_before), int(memory_after), int(memory_peak),
	])
	if _failures.is_empty():
		print("MULTI_CRIT_PERFORMANCE_INTEGRATION: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MULTI_CRIT_PERFORMANCE_INTEGRATION: %s" % failure)
	quit(1)


func _measure_case(label: String, crit_chance: float) -> Dictionary:
	var fixture_root := Node3D.new()
	fixture_root.name = "MultiCritPerformance%s" % label.capitalize()
	root.add_child(fixture_root)
	var rng := CombatRng.new(823000 + label.length())
	var service := COMBAT_RESOLUTION_SERVICE.new(rng, GameCatalog.DAMAGE_TYPES) as CombatResolutionService
	service.process_mode = Node.PROCESS_MODE_DISABLED
	fixture_root.add_child(service)
	var source_actor := Node3D.new()
	source_actor.name = "Source"
	fixture_root.add_child(source_actor)
	var source_stats := _snapshot({
		&"crit_chance": crit_chance,
		&"crit_multiplier": 1.5,
		&"damage": 1.0,
		&"melee_damage": 1.0,
		&"physical_damage": 1.0,
	})
	var source := CombatantAdapter.new(source_actor, StringName("performance:%s" % label), 1, null, source_stats, true)
	var target_actor := Node3D.new()
	target_actor.name = "Target"
	target_actor.position = Vector3(3.0, 0.0, -2.0)
	fixture_root.add_child(target_actor)
	var target_health := HealthComponent.new()
	target_actor.add_child(target_health)
	target_health.configure(1000000.0, false, 1.0, 1.0, true)
	var target_stats := _snapshot({
		&"armor": 0.0,
		&"dodge_chance": 0.0,
		&"block_chance": 0.0,
		&"block_effectiveness": 0.5,
	})
	var target := CombatantAdapter.new(target_actor, StringName("performance_target:%s" % label), 2, target_health, target_stats, true)
	var attack := _attack()
	var build_before := _build_document(attack, source_stats, target_health, target_stats)
	var packet := DamageResolver.prepare(attack, source, rng, GameCatalog.DAMAGE_TYPES)
	var started_usec := Time.get_ticks_usec()
	var bundle := service.resolve_bundle(packet, target)
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var results: Array[DamageResult] = bundle.results
	var events: Array = bundle.presentation_events
	var total_damage := 0.0
	for result: DamageResult in results:
		total_damage += result.final_damage
	var diagnostics := bundle.diagnostics
	var build_after := _build_document(attack, source_stats, target_health, target_stats)
	# Current health is intentionally mutable combat state, so compare the authored build separately.
	(build_before["target"] as Dictionary).erase("current_health")
	(build_after["target"] as Dictionary).erase("current_health")
	var report := {
		"label": label,
		"valid": bundle.valid and bundle.completed,
		"requested": int(diagnostics.get("requested_instances", -1)),
		"processed": int(diagnostics.get("processed_instances", -1)),
		"truncated": bool(diagnostics.get("ceiling_truncated", false)),
		"results": results.size(),
		"events": events.size(),
		"overkill": bundle.total_overkill,
		"total_damage": total_damage,
		"remaining_health": target_health.current_health,
		"finite": is_finite(total_damage) and is_finite(target_health.current_health) and is_finite(bundle.total_overkill),
		"build_unchanged": build_before == build_after,
		"elapsed_ms": elapsed_ms,
	}
	fixture_root.free()
	return report


func _attack() -> AttackDefinition:
	var component := AttackDamageComponent.new()
	component.damage_type_id = &"physical"
	component.base_amount = 1.0
	var attack := AttackDefinition.new()
	attack.id = &"multi_crit_performance_strike"
	attack.kind = AttackDefinition.Kind.MELEE_CLEAVE
	attack.cooldown = 1.0
	attack.range = 1.0
	attack.area_radius = 0.0
	attack.damage_components = [component]
	attack.action_tags = [&"melee", &"physical"]
	attack.can_crit = true
	return attack


func _snapshot(values: Dictionary) -> ResolvedStatSnapshot:
	return StatResolver.resolve(1, GameCatalog.STAT_CATALOG, values, [], [], [], 1)


func _build_document(attack: AttackDefinition, source_stats: ResolvedStatSnapshot, target_health: HealthComponent, target_stats: ResolvedStatSnapshot) -> Dictionary:
	var components: Array[Dictionary] = []
	for component: AttackDamageComponent in attack.damage_components:
		components.append({"damage_type_id": String(component.damage_type_id), "base_amount": component.base_amount})
	return {
		"attack": {
			"id": String(attack.id),
			"kind": attack.kind,
			"cooldown": attack.cooldown,
			"range": attack.range,
			"area_radius": attack.area_radius,
			"can_crit": attack.can_crit,
			"action_tags": attack.action_tags.duplicate(),
			"components": components,
		},
		"source": {
			"crit_chance": source_stats.value(&"crit_chance"),
			"crit_multiplier": source_stats.value(&"crit_multiplier"),
			"damage": source_stats.value(&"damage"),
			"melee_damage": source_stats.value(&"melee_damage"),
			"physical_damage": source_stats.value(&"physical_damage"),
		},
		"target": {
			"max_health": target_health.max_health,
			"current_health": target_health.current_health,
			"armor": target_stats.value(&"armor"),
			"dodge_chance": target_stats.value(&"dodge_chance"),
			"block_chance": target_stats.value(&"block_chance"),
			"block_effectiveness": target_stats.value(&"block_effectiveness"),
		},
	}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
