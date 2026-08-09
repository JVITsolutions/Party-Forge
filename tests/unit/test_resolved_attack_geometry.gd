extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_legacy_multiplier_projection(failures)
	_test_strict_action_snapshot_projection(failures)
	_test_strict_projection_rejects_overflow_but_keeps_nonprojectiles(failures)
	return failures


func _test_legacy_multiplier_projection(failures: Array[String]) -> void:
	var attack := AttackDefinition.new()
	attack.id = &"geometry_test"
	attack.kind = AttackDefinition.Kind.MELEE_CLEAVE
	attack.range = 2.0
	attack.area_radius = 0.9
	var geometry := ResolvedAttackGeometry.from_attack(attack, 1.5, 2.0)
	TestAssertions.near(geometry.range, 3.0, 0.001, "range multiplier scales range only", failures)
	TestAssertions.near(geometry.area_radius, 1.8, 0.001, "area multiplier scales area only", failures)
	var fallback := ResolvedAttackGeometry.from_attack(attack, NAN, -4.0)
	TestAssertions.near(fallback.range, 2.0, 0.001, "invalid range multiplier falls back to one", failures)
	TestAssertions.near(fallback.area_radius, 0.0, 0.001, "negative area multiplier clamps safely", failures)


func _test_strict_action_snapshot_projection(failures: Array[String]) -> void:
	var geometry_script := load("res://scripts/combat/resolved_attack_geometry.gd") as Script
	var supports_snapshot := geometry_script != null and geometry_script.get_script_method_list().any(
		func(method: Dictionary) -> bool: return StringName(method.get("name", &"")) == &"from_snapshot"
	)
	TestAssertions.truthy(supports_snapshot, "resolved attack geometry exposes strict action-snapshot projection", failures)
	if not supports_snapshot:
		return
	var attack := AttackDefinition.new()
	attack.id = &"strict_geometry"
	attack.kind = AttackDefinition.Kind.AREA_PROJECTILE
	attack.range = 8.0
	attack.area_radius = 2.0
	attack.projectile_speed = 10.0
	var geometry := geometry_script.call("from_snapshot", attack, _snapshot({
		&"attack_range": 1.5,
		&"area_size": 2.0,
		&"projectile_speed": 3.0,
	})) as RefCounted
	TestAssertions.truthy(geometry != null and bool(geometry.call("ok")), "strict geometry accepts a finite action snapshot", failures)
	if geometry != null:
		TestAssertions.near(float(geometry.get("range")), 12.0, 0.001, "strict range uses authored units times the resolved multiplier", failures)
		TestAssertions.near(float(geometry.get("area_radius")), 4.0, 0.001, "strict area uses authored radius times the resolved multiplier", failures)
		TestAssertions.near(float(geometry.get("projectile_speed")), 30.0, 0.001, "strict projectile speed uses authored units times the resolved multiplier", failures)


func _test_strict_projection_rejects_overflow_but_keeps_nonprojectiles(failures: Array[String]) -> void:
	var geometry_script := load("res://scripts/combat/resolved_attack_geometry.gd") as Script
	var supports_snapshot := geometry_script != null and geometry_script.get_script_method_list().any(
		func(method: Dictionary) -> bool: return StringName(method.get("name", &"")) == &"from_snapshot"
	)
	if not supports_snapshot:
		return
	var projectile := AttackDefinition.new()
	projectile.id = &"overflow_geometry"
	projectile.kind = AttackDefinition.Kind.PROJECTILE
	projectile.range = 12.0
	projectile.projectile_speed = 10.0
	var overflow := geometry_script.call("from_snapshot", projectile, _snapshot({&"attack_range": 1.0e308})) as RefCounted
	TestAssertions.truthy(overflow != null and not bool(overflow.call("ok")), "strict geometry rejects finite multipliers whose authored projection overflows", failures)
	if overflow != null:
		TestAssertions.truthy("range" in String(overflow.get("error")).to_lower(), "strict overflow identifies attack range", failures)

	var heal := AttackDefinition.new()
	heal.id = &"safe_heal_geometry"
	heal.kind = AttackDefinition.Kind.HEAL
	heal.range = 9.0
	var safe_nonprojectile := geometry_script.call("from_snapshot", heal, _snapshot({&"projectile_speed": 1.0e308})) as RefCounted
	TestAssertions.truthy(safe_nonprojectile != null and bool(safe_nonprojectile.call("ok")), "nonprojectile actions ignore inapplicable projectile geometry", failures)
	if safe_nonprojectile != null:
		TestAssertions.near(float(safe_nonprojectile.get("projectile_speed")), 0.0, 0.001, "nonprojectile effective speed remains absent", failures)


func _snapshot(overrides: Dictionary) -> ResolvedStatSnapshot:
	var result := ResolvedStatSnapshot.new()
	for definition: StatDefinition in GameCatalog.STAT_CATALOG.definitions:
		result.set_resolved(definition.id, float(overrides.get(definition.id, definition.default_value)), [])
	return result
