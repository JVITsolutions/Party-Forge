extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	_test_exact_enemy_attack_links(catalog, failures)
	_test_enemy_definition_validation(catalog, failures)
	_test_spawned_enemy_identities(catalog, failures)
	_test_enemy_physical_resolution(catalog, failures)
	_test_enemy_attack_geometry(failures)
	_test_swarmer_uses_resolved_contact_range(catalog, failures)
	_test_guardian_uses_resolved_shockwave_area(catalog, failures)
	_test_guardian_uses_resolved_charge_width(catalog, failures)
	_test_guardian_charge_sweeps_full_movement_segment(catalog, failures)
	_test_enemy_projectile_sweeps_and_resolves_area_once(catalog, failures)
	_test_enemy_projectile_near_equal_contact_is_order_independent(catalog, failures)
	_test_enemy_projectile_distinct_contact_prefers_nearer_geometry(catalog, failures)
	return failures

func _test_exact_enemy_attack_links(catalog: GameCatalog, failures: Array[String]) -> void:
	var expected: Dictionary = {
		&"swarmer": [&"swarmer_contact"],
		&"spitter": [&"spitter_projectile"],
		&"forge_guardian": [&"guardian_charge", &"guardian_shockwave"],
	}
	for enemy_id: StringName in expected:
		var definition := _enemy(catalog, enemy_id)
		TestAssertions.truthy(definition != null, "%s enemy definition loads" % enemy_id, failures)
		if definition == null:
			continue
		TestAssertions.truthy(_has_property(definition, &"stat_overrides"), "%s exposes stat overrides" % enemy_id, failures)
		TestAssertions.truthy(_has_property(definition, &"attacks"), "%s exposes typed attacks" % enemy_id, failures)
		TestAssertions.truthy(not _has_property(definition, StringName("contact" + "_damage")), "%s removes legacy contact damage" % enemy_id, failures)
		var attack_ids: Array[StringName] = []
		var attacks: Variant = definition.get("attacks")
		if attacks is Array:
			for attack: Variant in attacks:
				if attack is AttackDefinition:
					attack_ids.append((attack as AttackDefinition).id)
		TestAssertions.equal(attack_ids, expected[enemy_id], "%s exact attack links" % enemy_id, failures)
		var overrides: Variant = definition.get("stat_overrides")
		TestAssertions.equal(overrides if overrides is Dictionary else null, {}, "%s empty stat overrides" % enemy_id, failures)

func _test_enemy_definition_validation(catalog: GameCatalog, failures: Array[String]) -> void:
	var base := _enemy(catalog, &"swarmer")
	if base == null or not _method_accepts(base, &"validate", 2):
		TestAssertions.truthy(false, "enemy validation accepts damage and stat catalogs", failures)
		return
	var attack := load("res://data/attacks/swarmer_contact.tres") as AttackDefinition
	var duplicate := base.duplicate(true) as EnemyDefinition
	var duplicate_attacks: Array[AttackDefinition] = [attack, attack]
	duplicate.attacks = duplicate_attacks
	_assert_error(duplicate.call("validate", catalog.damage_types, PartyManager.STAT_CATALOG),
		"PARTY_FORGE_DAMAGE_ERROR enemy=swarmer attack=swarmer_contact reason=duplicate attack id", "duplicate attack id", failures)
	var missing := base.duplicate(true) as EnemyDefinition
	var no_attacks: Array[AttackDefinition] = []
	missing.attacks = no_attacks
	_assert_error(missing.call("validate", catalog.damage_types, PartyManager.STAT_CATALOG),
		"PARTY_FORGE_DAMAGE_ERROR enemy=swarmer attack=swarmer_contact reason=required behavior attack missing", "missing behavior attack", failures)
	var overrides := base.duplicate(true) as EnemyDefinition
	var invalid_overrides: Dictionary[StringName, float] = {&"unknown_enemy_stat": 1.0, &"armor": INF}
	overrides.stat_overrides = invalid_overrides
	var override_errors: PackedStringArray = overrides.call("validate", catalog.damage_types, PartyManager.STAT_CATALOG)
	_assert_error(override_errors,
		"PARTY_FORGE_DAMAGE_ERROR enemy=swarmer stat=unknown_enemy_stat reason=unknown stat override", "unknown stat override", failures)
	_assert_error(override_errors,
		"PARTY_FORGE_DAMAGE_ERROR enemy=swarmer stat=armor reason=non-finite stat override", "non-finite stat override", failures)
	var mismatch := base.duplicate(true) as EnemyDefinition
	mismatch.behavior = EnemyDefinition.Behavior.SPITTER
	var mismatch_attacks: Array[AttackDefinition] = [attack]
	mismatch.attacks = mismatch_attacks
	_assert_error(mismatch.call("validate", catalog.damage_types, PartyManager.STAT_CATALOG),
		"PARTY_FORGE_DAMAGE_ERROR enemy=swarmer attack=spitter_projectile reason=required behavior attack missing", "behavior capability mismatch", failures)

func _test_spawned_enemy_identities(catalog: GameCatalog, failures: Array[String]) -> void:
	var director_script := load("res://scripts/game/spawn_director.gd") as Script
	var director := director_script.new() as Node
	if not _method_accepts(director, &"configure", 10):
		TestAssertions.truthy(false, "spawn director requires shared combat dependencies", failures)
		director.free()
		return
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	root.add_child(director)
	var marker := Marker3D.new()
	root.add_child(marker)
	var markers: Array[Node3D] = [marker]
	var experience := ExperienceSystem.new()
	root.add_child(experience)
	var combat_rng := CombatRng.new(77)
	director.call("configure", 77, null, experience, markers, null, root, root, 1.0, combat_rng, catalog.damage_types)
	var first: Node3D = director.call("spawn_enemy", &"swarmer") as Node3D
	var second: Node3D = director.call("spawn_enemy", &"swarmer") as Node3D
	TestAssertions.truthy(first != null and second != null, "two valid enemies spawn", failures)
	if first != null and second != null:
		TestAssertions.equal(first.get("combatant_id"), &"enemy:1", "first enemy stable id", failures)
		TestAssertions.equal(second.get("combatant_id"), &"enemy:2", "second enemy stable id", failures)
	root.free()

func _test_enemy_physical_resolution(catalog: GameCatalog, failures: Array[String]) -> void:
	var enemy := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as Node3D
	if not _method_accepts(enemy, &"configure_combat", 3):
		TestAssertions.truthy(false, "enemy actor exposes typed combat adapter", failures)
		enemy.free()
		return
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	root.add_child(enemy)
	var combat_rng := CombatRng.new(88, [0.8, 0.2])
	enemy.call("configure_combat", 1, combat_rng, catalog.damage_types)
	var packet := enemy.call("prepare_attack", &"swarmer_contact") as DamagePacket
	TestAssertions.truthy(packet != null and packet.valid, "enemy prepares typed physical packet", failures)
	var health := HealthComponent.new()
	health.configure(100.0, false, 1.0, 1.0, true)
	var stats := ResolvedStatSnapshot.new()
	stats.set_resolved(&"armor", 100.0, [])
	stats.set_resolved(&"dodge_chance", 0.25, [])
	stats.set_resolved(&"block_chance", 0.5, [])
	stats.set_resolved(&"block_effectiveness", 0.5, [])
	var target := CombatantAdapter.new(null, &"party:test", 1, health, stats, true)
	var result := enemy.call("resolve_attack", packet, target) as DamageResult
	TestAssertions.truthy(result != null and result.valid, "enemy packet resolves through shared resolver", failures)
	if result != null:
		TestAssertions.truthy(not result.dodged, "prescribed dodge draw misses", failures)
		TestAssertions.truthy(result.blocked, "prescribed block draw succeeds", failures)
		TestAssertions.near(result.total_post_mitigation, 4.0, 0.001, "physical armor mitigation matches party path", failures)
		TestAssertions.near(result.final_damage, 2.0, 0.001, "block reduction matches party path", failures)
		TestAssertions.near(result.actual_health_removed, 2.0, 0.001, "resolved enemy damage reaches health", failures)
	health.free()
	root.free()

func _test_enemy_attack_geometry(failures: Array[String]) -> void:
	var attack := AttackDefinition.new()
	attack.id = &"test_attack"
	attack.range = 2.0
	attack.area_radius = 1.0
	var definition := EnemyDefinition.new()
	var attacks: Array[AttackDefinition] = [attack]
	definition.attacks = attacks
	var overrides: Dictionary[StringName, float] = {&"attack_range": 1.5, &"area_size": 2.0}
	definition.stat_overrides = overrides
	var enemy := EnemyActor.new()
	enemy.definition = definition
	TestAssertions.truthy(enemy.has_method("attack_geometry"), "enemy exposes resolved attack geometry", failures)
	if enemy.has_method("attack_geometry"):
		var geometry := enemy.call("attack_geometry", &"test_attack") as ResolvedAttackGeometry
		TestAssertions.near(geometry.range, 3.0, 0.001, "enemy attack_range scales range", failures)
		TestAssertions.near(geometry.area_radius, 2.0, 0.001, "enemy area_size scales area", failures)
		definition.stat_overrides = {}
		var defaults := enemy.call("attack_geometry", &"test_attack") as ResolvedAttackGeometry
		TestAssertions.near(defaults.range, 2.0, 0.001, "enemy geometry defaults attack range multiplier", failures)
		TestAssertions.near(defaults.area_radius, 1.0, 0.001, "enemy geometry defaults area multiplier", failures)
		var missing := enemy.call("attack_geometry", &"missing_attack") as ResolvedAttackGeometry
		TestAssertions.near(missing.range, 0.0, 0.001, "missing enemy attack has zero range", failures)
		TestAssertions.near(missing.area_radius, 0.0, 0.001, "missing enemy attack has zero area", failures)
	enemy.free()

func _test_swarmer_uses_resolved_contact_range(catalog: GameCatalog, failures: Array[String]) -> void:
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var leader := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
	root.add_child(leader)
	leader.position = Vector3(1.2, 0.0, 0.0)
	leader.configure(PartyMemberState.new(7101, catalog.class_by_id(&"fighter"), true))
	var enemy := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as Swarmer
	root.add_child(enemy)
	var definition := _enemy(catalog, &"swarmer").duplicate(true) as EnemyDefinition
	var overrides: Dictionary[StringName, float] = {&"attack_range": 1.5}
	definition.stat_overrides = overrides
	enemy.configure(definition)
	enemy.configure_combat(2, CombatRng.new(902), catalog.damage_types)
	var health := leader.get_node("HealthComponent") as HealthComponent
	var before := health.current_health
	var candidates: Array[Node3D] = [leader]
	enemy.advance_behavior(0.0, candidates)
	TestAssertions.truthy(health.current_health < before, "swarmer contact uses resolved attack range", failures)
	root.free()

func _test_guardian_uses_resolved_shockwave_area(catalog: GameCatalog, failures: Array[String]) -> void:
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var leader := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
	root.add_child(leader)
	leader.position = Vector3(9.0, 0.0, 0.0)
	leader.configure(PartyMemberState.new(7102, catalog.class_by_id(&"fighter"), true))
	var boss := (load("res://scenes/enemies/forge_guardian.tscn") as PackedScene).instantiate() as ForgeGuardian
	root.add_child(boss)
	var definition := _enemy(catalog, &"forge_guardian").duplicate(true) as EnemyDefinition
	var overrides: Dictionary[StringName, float] = {&"area_size": 2.0}
	definition.stat_overrides = overrides
	boss.configure(definition)
	boss.configure_combat(&"shockwave", CombatRng.new(903), catalog.damage_types)
	boss.configure_boss(leader, null, root)
	var health := leader.get_node("HealthComponent") as HealthComponent
	var before := health.current_health
	boss.call("_apply_shockwave")
	TestAssertions.truthy(health.current_health < before, "guardian shockwave uses resolved area radius", failures)
	root.free()

func _test_guardian_uses_resolved_charge_width(catalog: GameCatalog, failures: Array[String]) -> void:
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var leader := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
	root.add_child(leader)
	leader.position = Vector3(4.5, 0.0, 3.0)
	leader.configure(PartyMemberState.new(7103, catalog.class_by_id(&"fighter"), true))
	var boss := (load("res://scenes/enemies/forge_guardian.tscn") as PackedScene).instantiate() as ForgeGuardian
	root.add_child(boss)
	var definition := _enemy(catalog, &"forge_guardian").duplicate(true) as EnemyDefinition
	var overrides: Dictionary[StringName, float] = {&"attack_range": 1.5}
	definition.stat_overrides = overrides
	boss.configure(definition)
	boss.configure_combat(&"charge_width", CombatRng.new(904), catalog.damage_types)
	boss.configure_boss(leader, null, root)
	boss.set("charge_direction", Vector3.RIGHT)
	boss.set("charge_packet", boss.prepare_attack(&"guardian_charge"))
	(boss.get("charge_hit_ids") as Dictionary).clear()
	var health := leader.get_node("HealthComponent") as HealthComponent
	var before := health.current_health
	boss.call("_move_charge", 0.65)
	TestAssertions.truthy(health.current_health < before, "guardian charge uses resolved swept width", failures)
	root.free()

func _test_guardian_charge_sweeps_full_movement_segment(catalog: GameCatalog, failures: Array[String]) -> void:
	var large_step_removed := _guardian_charge_removed(catalog, [0.65])
	var sliced_step_removed := _guardian_charge_removed(catalog, [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.05])
	TestAssertions.near(large_step_removed, sliced_step_removed, 0.001, "guardian charge damage is frame-slice invariant", failures)
	TestAssertions.near(sliced_step_removed, 22.0, 0.001, "guardian charge hits once across repeated intersecting slices", failures)

func _test_enemy_projectile_sweeps_and_resolves_area_once(catalog: GameCatalog, failures: Array[String]) -> void:
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var source := (load("res://scenes/enemies/spitter.tscn") as PackedScene).instantiate() as Spitter
	root.add_child(source)
	source.configure_combat(&"projectile_source", CombatRng.new(905), catalog.damage_types)
	var packet := source.prepare_attack(&"spitter_projectile")
	var downed := _party_actor(root, catalog, 7201, Vector3(2.0, 0.0, 0.0))
	var farther := _party_actor(root, catalog, 7204, Vector3(7.0, 0.0, 0.0))
	var impact := _party_actor(root, catalog, 7202, Vector3(5.0, 0.0, 0.0))
	var splash := _party_actor(root, catalog, 7203, Vector3(6.0, 0.0, 0.0))
	var target := _party_actor(root, catalog, 7205, Vector3(20.0, 0.0, 0.0))
	var downed_health := downed.get_node("HealthComponent") as HealthComponent
	downed_health.is_downed = true
	var farther_health := farther.get_node("HealthComponent") as HealthComponent
	var impact_health := impact.get_node("HealthComponent") as HealthComponent
	var splash_health := splash.get_node("HealthComponent") as HealthComponent
	var downed_before := downed_health.current_health
	var farther_before := farther_health.current_health
	var impact_before := impact_health.current_health
	var splash_before := splash_health.current_health
	var attack := (load("res://data/attacks/spitter_projectile.tres") as AttackDefinition).duplicate(true) as AttackDefinition
	attack.projectile_speed = 20.0
	attack.range = 10.0
	attack.area_radius = 1.5
	var profile := EnemyProjectileProfile.new()
	profile.movement = EnemyProjectileProfile.Movement.LINEAR
	profile.hit_radius = 0.2
	profile.max_lifetime = 10.0
	var projectile := (load("res://scenes/enemies/enemy_projectile.tscn") as PackedScene).instantiate() as EnemyProjectile
	root.add_child(projectile)
	projectile.position = Vector3.ZERO
	projectile.configure(target, packet, source.combat_rng, catalog.damage_types, attack, profile, target.position)
	projectile.advance_projectile(0.5)
	TestAssertions.near(downed_health.current_health, downed_before, 0.001, "enemy projectile skips downed party actors", failures)
	TestAssertions.near(impact_health.current_health, impact_before - 10.0, 0.001, "enemy projectile hits first living actor across a movement segment", failures)
	TestAssertions.near(splash_health.current_health, splash_before - 10.0, 0.001, "enemy projectile area resolves each nearby available actor once", failures)
	TestAssertions.near(farther_health.current_health, farther_before, 0.001, "enemy projectile resolves the nearer swept hit before a farther actor registered first", failures)
	TestAssertions.truthy(projectile.is_queued_for_deletion(), "enemy projectile is consumed by segment impact", failures)
	root.free()

func _test_enemy_projectile_near_equal_contact_is_order_independent(catalog: GameCatalog, failures: Array[String]) -> void:
	var nearer_first := _ordered_projectile_contact_removals(catalog, true, 5.00001, 7302, 7301, 906)
	var farther_first := _ordered_projectile_contact_removals(catalog, false, 5.00001, 7302, 7301, 906)
	TestAssertions.equal(nearer_first, farther_first, "near-equal projectile contact winner is independent of party registration order", failures)
	TestAssertions.near(nearer_first[0], 0.0, 0.001, "near-equal projectile tie defers to deterministic combatant identity", failures)
	TestAssertions.near(nearer_first[1], 10.0, 0.001, "near-equal projectile tie selects the lower combatant identity", failures)

func _test_enemy_projectile_distinct_contact_prefers_nearer_geometry(catalog: GameCatalog, failures: Array[String]) -> void:
	var nearer_first := _ordered_projectile_contact_removals(catalog, true, 5.001, 7402, 7401, 907)
	var farther_first := _ordered_projectile_contact_removals(catalog, false, 5.001, 7402, 7401, 907)
	TestAssertions.equal(nearer_first, farther_first, "distinct projectile contact winner is independent of party registration order", failures)
	TestAssertions.near(nearer_first[0], 10.0, 0.001, "distinct projectile contacts select smaller geometric progression", failures)
	TestAssertions.near(nearer_first[1], 0.0, 0.001, "lower identity cannot override a geometrically nearer non-tie", failures)

func _ordered_projectile_contact_removals(catalog: GameCatalog, nearer_first: bool, farther_x: float, nearer_id: int, farther_id: int, rng_seed: int) -> Array[float]:
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var source := (load("res://scenes/enemies/spitter.tscn") as PackedScene).instantiate() as Spitter
	root.add_child(source)
	source.configure_combat(&"ordered_contact_source", CombatRng.new(rng_seed), catalog.damage_types)
	var packet := source.prepare_attack(&"spitter_projectile")
	var nearer: PartyActor
	var farther: PartyActor
	if nearer_first:
		nearer = _party_actor(root, catalog, nearer_id, Vector3(5.0, 0.0, 0.0))
		farther = _party_actor(root, catalog, farther_id, Vector3(farther_x, 0.0, 0.0))
	else:
		farther = _party_actor(root, catalog, farther_id, Vector3(farther_x, 0.0, 0.0))
		nearer = _party_actor(root, catalog, nearer_id, Vector3(5.0, 0.0, 0.0))
	var target := _party_actor(root, catalog, maxi(nearer_id, farther_id) + 1, Vector3(20.0, 0.0, 0.0))
	var nearer_health := nearer.get_node("HealthComponent") as HealthComponent
	var farther_health := farther.get_node("HealthComponent") as HealthComponent
	var nearer_before := nearer_health.current_health
	var farther_before := farther_health.current_health
	var attack := (load("res://data/attacks/spitter_projectile.tres") as AttackDefinition).duplicate(true) as AttackDefinition
	attack.projectile_speed = 20.0
	attack.range = 10.0
	attack.area_radius = 0.0
	var profile := EnemyProjectileProfile.new()
	profile.movement = EnemyProjectileProfile.Movement.LINEAR
	profile.hit_radius = 0.2
	profile.max_lifetime = 10.0
	var projectile := (load("res://scenes/enemies/enemy_projectile.tscn") as PackedScene).instantiate() as EnemyProjectile
	root.add_child(projectile)
	projectile.position = Vector3.ZERO
	projectile.configure(target, packet, source.combat_rng, catalog.damage_types, attack, profile, target.position)
	projectile.advance_projectile(0.5)
	var removed: Array[float] = [nearer_before - nearer_health.current_health, farther_before - farther_health.current_health]
	root.free()
	return removed

func _guardian_charge_removed(catalog: GameCatalog, steps: Array[float]) -> float:
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var leader := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
	root.add_child(leader)
	leader.position = Vector3(4.5, 0.0, 0.0)
	leader.configure(PartyMemberState.new(7001, catalog.class_by_id(&"fighter"), true))
	var health := leader.get_node("HealthComponent") as HealthComponent
	var before := health.current_health
	var boss := (load("res://scenes/enemies/forge_guardian.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(boss)
	boss.position = Vector3.ZERO
	boss.call("configure_combat", &"boss", CombatRng.new(901), catalog.damage_types)
	boss.call("configure_boss", leader, null, root)
	boss.set("charge_direction", Vector3.RIGHT)
	boss.set("charge_packet", boss.call("prepare_attack", &"guardian_charge"))
	(boss.get("charge_hit_ids") as Dictionary).clear()
	for step: float in steps:
		boss.call("_move_charge", step)
	var removed := before - health.current_health
	root.free()
	return removed

func _enemy(catalog: GameCatalog, enemy_id: StringName) -> EnemyDefinition:
	for definition: EnemyDefinition in catalog.enemies:
		if definition != null and definition.id == enemy_id:
			return definition
	return null

func _party_actor(parent: Node, catalog: GameCatalog, member_id: int, actor_position: Vector3) -> PartyActor:
	var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
	actor.position = actor_position
	parent.add_child(actor)
	actor.configure(PartyMemberState.new(member_id, catalog.class_by_id(&"fighter"), true))
	return actor

func _assert_error(errors: PackedStringArray, expected: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(expected in errors, label, failures)

func _has_property(object: Object, property_name: StringName) -> bool:
	for row: Dictionary in object.get_property_list():
		if StringName(row.get("name", "")) == property_name:
			return true
	return false

func _method_accepts(object: Object, method_name: StringName, argument_count: int) -> bool:
	for row: Dictionary in object.get_method_list():
		if StringName(row.get("name", "")) == method_name:
			var total_arguments := (row.get("args", []) as Array).size()
			var default_arguments := (row.get("default_args", []) as Array).size()
			return argument_count >= total_arguments - default_arguments and argument_count <= total_arguments
	return false
