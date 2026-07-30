extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	_test_exact_enemy_attack_links(catalog, failures)
	_test_enemy_definition_validation(catalog, failures)
	_test_spawned_enemy_identities(catalog, failures)
	_test_enemy_physical_resolution(catalog, failures)
	_test_guardian_charge_sweeps_full_movement_segment(catalog, failures)
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

func _test_guardian_charge_sweeps_full_movement_segment(catalog: GameCatalog, failures: Array[String]) -> void:
	var large_step_removed := _guardian_charge_removed(catalog, [0.65])
	var sliced_step_removed := _guardian_charge_removed(catalog, [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.05])
	TestAssertions.near(large_step_removed, sliced_step_removed, 0.001, "guardian charge damage is frame-slice invariant", failures)
	TestAssertions.near(sliced_step_removed, 22.0, 0.001, "guardian charge hits once across repeated intersecting slices", failures)

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
			return (row.get("args", []) as Array).size() == argument_count
	return false
