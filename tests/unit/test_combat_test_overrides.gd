extends RefCounted

const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const COMPANION_SCENE := preload("res://scenes/characters/companion.tscn")
const MAIN_SCENE := preload("res://scenes/game/main.tscn")
const SWARMER_SCENE := preload("res://scenes/enemies/swarmer.tscn")

func run() -> Array[String]:
	var failures: Array[String] = []
	var probe := COMPANION_SCENE.instantiate() as PartyActor
	var has_policy_api := probe.has_method(&"configure_combat_policy")
	TestAssertions.truthy(has_policy_api, "party actors expose combat policy injection", failures)
	probe.free()
	if not has_policy_api:
		return failures

	_test_developer_run_wires_party_only(failures)
	_test_missing_policy_resets_party_floor(failures)
	_test_invalid_party_actor_ownership_fails_closed(failures)
	_test_guardian_adds_ignore_density(failures)
	return failures

func _test_developer_run_wires_party_only(failures: Array[String]) -> void:
	var main := MAIN_SCENE.instantiate()
	main.call(&"_ready")
	var settings := main.get("saved_settings") as PartyForgeSettings
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	settings.god_mode = true
	settings.enemy_density_percent = 0
	TestAssertions.truthy(main.call(&"select_leader_class", &"fighter"), "God Mode fixture starts", failures)
	var director := main.get("spawn_director") as SpawnDirector
	TestAssertions.equal(director.call(&"advance_time", 10.0), 0, "active run density reaches scheduled spawning", failures)
	TestAssertions.near(director.elapsed_seconds, 10.0, 0.001, "zero-density active run still advances schedule time", failures)

	var leader := main.get("leader") as PartyActor
	var leader_health := leader.get_node("HealthComponent") as HealthComponent
	leader_health.apply_damage(leader_health.max_health * 2.0)
	TestAssertions.equal(leader_health.current_health, 1.0, "God Mode protects the configured leader", failures)
	TestAssertions.truthy(not leader_health.is_dead and not leader_health.is_downed, "God Mode leader remains combat-available", failures)
	leader.damage_flash_remaining = 0.0
	leader_health.apply_damage(10.0)
	TestAssertions.truthy(leader.damage_flash_remaining > 0.0, "damage at the floor still flashes the party actor", failures)

	var party := main.get_node("PartyManager") as PartyManager
	var catalog := main.get("catalog") as GameCatalog
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "God Mode fixture recruits a normal party member", failures)
	var companion: PartyActor
	for child: Node in main.get_node("Actors").get_children():
		var actor := child as PartyActor
		if actor != null and actor.member_state != null and not actor.member_state.is_leader:
			companion = actor
			break
	TestAssertions.truthy(companion != null, "recruit spawner creates the normal party member", failures)
	if companion != null:
		var companion_health := companion.get_node("HealthComponent") as HealthComponent
		companion_health.apply_damage(companion_health.max_health * 2.0)
		TestAssertions.equal(companion_health.current_health, 1.0, "God Mode protects a recruited party member", failures)
		TestAssertions.truthy(not companion_health.is_dead and not companion_health.is_downed, "God Mode recruit remains combat-available", failures)

	var enemy := SWARMER_SCENE.instantiate() as EnemyActor
	enemy.configure(load("res://data/enemies/swarmer.tres") as EnemyDefinition)
	var enemy_health := enemy.get_node("HealthComponent") as HealthComponent
	enemy_health.apply_damage(enemy_health.max_health * 2.0)
	TestAssertions.equal(enemy_health.current_health, 0.0, "God Mode does not add a floor to enemies", failures)
	TestAssertions.truthy(enemy_health.is_dead, "enemy lethal damage remains authoritative", failures)
	enemy.free()

	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()

func _test_missing_policy_resets_party_floor(failures: Array[String]) -> void:
	var actor := LEADER_SCENE.instantiate() as PartyActor
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	actor.configure(party.members[0])
	actor.configure_combat(party)
	actor.call(&"configure_combat_policy", CombatTestPolicy.new(true, 100, true, false, 4))
	var health := actor.get_node("HealthComponent") as HealthComponent
	health.apply_damage(health.max_health * 2.0)
	TestAssertions.equal(health.current_health, 1.0, "explicit God Mode policy adds the party floor", failures)
	health.heal(health.max_health)
	actor.call(&"configure_combat_policy", null)
	health.apply_damage(health.max_health * 2.0)
	TestAssertions.truthy(health.is_dead and health.current_health == 0.0, "missing combat policy explicitly restores the zero floor", failures)
	actor.free()
	party.free()

func _test_invalid_party_actor_ownership_fails_closed(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var god_mode := CombatTestPolicy.new(true, 100, true, false, 4)

	var hostile := COMPANION_SCENE.instantiate() as PartyActor
	hostile.team_id = PartyActor.PARTY_TEAM_ID + 1
	hostile.configure(party.members[0])
	hostile.configure_combat(party)
	hostile.configure_combat_policy(god_mode)
	var hostile_health := hostile.get_node("HealthComponent") as HealthComponent
	hostile_health.apply_damage(hostile_health.max_health * 2.0)
	TestAssertions.truthy(hostile_health.is_dead and hostile_health.current_health == 0.0, "hostile PartyActor cannot receive the God Mode floor", failures)
	hostile.free()

	var forged := COMPANION_SCENE.instantiate() as PartyActor
	var forged_member := PartyMemberState.new(party.members[0].member_id, catalog.class_by_id(&"ranger"), false, "Forged")
	forged.configure(forged_member)
	forged.configure_combat(party)
	forged.configure_combat_policy(god_mode)
	var forged_health := forged.get_node("HealthComponent") as HealthComponent
	forged_health.apply_damage(forged_health.max_health * 2.0)
	TestAssertions.truthy((forged_health.is_dead or forged_health.is_downed) and forged_health.current_health == 0.0, "unmanaged PartyActor member identity cannot receive the God Mode floor", failures)
	forged.free()
	party.free()

func _test_guardian_adds_ignore_density(failures: Array[String]) -> void:
	var guardian_source := FileAccess.get_file_as_string("res://scripts/enemies/forge_guardian.gd")
	TestAssertions.truthy("spawn_enemy" in guardian_source, "Forge Guardian adds use direct enemy spawning", failures)
	TestAssertions.truthy("enemy_density" not in guardian_source, "Forge Guardian add spawning does not consult density", failures)
