extends SceneTree

const PROFILE_ROOT := "user://tests/multi_crit_combat_profiles"
const SETTINGS_PATH := "user://tests/multi_crit_combat_settings.cfg"
const COMBAT_RESOLUTION_SERVICE := preload("res://scripts/combat/combat_resolution_service.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _verify_105_percent_projectile_boundaries()
	await _verify_1150_percent_melee_is_synchronous()
	await _verify_independent_defense_draws()
	await _verify_lethal_bundle_lifecycle()
	_finish()


func _verify_105_percent_projectile_boundaries() -> void:
	for row: Dictionary in [
		{"draw": 0.99, "instances": 1, "label": "failed remainder"},
		{"draw": 0.01, "instances": 2, "label": "successful remainder"},
	]:
		var fixture := _party_fixture(&"ranger", 1.05, [float(row["draw"])], "Projectile_%s" % String(row["label"]))
		var owner := fixture["owner"] as PartyActor
		var target := fixture["target"] as PartyActor
		var effects := fixture["effects"] as Node3D
		var service := fixture["service"] as CombatResolutionService
		var completed: Array[RefCounted] = []
		service.bundle_completed.connect(func(bundle: RefCounted) -> void: completed.append(bundle))
		owner.attack_executor.configure(owner, fixture["party"], effects, [target] as Array[Node3D], service)
		owner.attack_executor.execute(owner.member_state.class_definition.primary_attack, target.get_combat_target())
		_assert(_count_projectiles(effects) == 1, "105%% %s launches exactly one projectile" % row["label"])
		await _wait_for_bundle(completed)
		_assert(completed.size() == 1, "105%% %s produces exactly one delivered bundle" % row["label"])
		if completed.size() == 1:
			_assert(completed[0].results.size() == int(row["instances"]), "105%% %s produces %d prescribed damage instances" % [row["label"], row["instances"]])
		(fixture["root"] as Node).free()
		await process_frame


func _verify_1150_percent_melee_is_synchronous() -> void:
	var fixture := _party_fixture(&"fighter", 11.50, [0.49], "SynchronousMelee")
	var owner := fixture["owner"] as PartyActor
	var target := fixture["target"] as PartyActor
	var party := fixture["party"] as PartyManager
	var service := fixture["service"] as CombatResolutionService
	var completed: Array[RefCounted] = []
	service.bundle_completed.connect(func(bundle: RefCounted) -> void: completed.append(bundle))
	var health := target.get_node("HealthComponent") as HealthComponent
	health.configure(10000.0, false, 1.0, 1.0, true)
	var before := health.current_health
	owner.attack_executor.configure(owner, party, fixture["effects"], [target] as Array[Node3D], service)
	owner.attack_executor.execute(owner.member_state.class_definition.primary_attack, target.get_combat_target())
	_assert(completed.size() == 1, "1150% melee completes one bundle synchronously in the execute call")
	_assert(health.current_health < before, "1150% melee applies gameplay damage before the next frame")
	if completed.size() == 1:
		_assert(completed[0].results.size() == 12, "1150% melee processes eleven guaranteed and one successful remainder instance")
		_assert(_sum_damage(completed[0].results) > 0.0, "1150% synchronous melee bundle records finite positive damage")
	var health_before_frame := health.current_health
	await process_frame
	_assert(is_equal_approx(health.current_health, health_before_frame), "next frame adds no delayed gameplay damage for the melee bundle")
	(fixture["root"] as Node).free()
	await process_frame


func _verify_independent_defense_draws() -> void:
	var fixture := _party_fixture(&"fighter", 2.0, [0.10, 0.90, 0.10], "IndependentDefense")
	var party := fixture["party"] as PartyManager
	var target := fixture["target"] as PartyActor
	var target_id := target.member_state.member_id
	var defense_source := StatModifierSource.create(&"integration_defense", &"test", "Integration Defense", target_id, [
		StatModifier.create(&"dodge_chance", StatModifier.Operation.FLAT, 0.50, &"integration_dodge", "Integration Dodge"),
		StatModifier.create(&"block_chance", StatModifier.Operation.FLAT, 0.50, &"integration_block", "Integration Block"),
	])
	_assert(party.add_member_source(target_id, defense_source), "independent-defense fixture registers target defenses")
	var service := fixture["service"] as CombatResolutionService
	var completed: Array[RefCounted] = []
	service.bundle_completed.connect(func(bundle: RefCounted) -> void: completed.append(bundle))
	var owner := fixture["owner"] as PartyActor
	owner.attack_executor.configure(owner, party, fixture["effects"], [target] as Array[Node3D], service)
	owner.attack_executor.execute(owner.member_state.class_definition.primary_attack, target.get_combat_target())
	_assert(completed.size() == 1, "independent-defense fixture resolves one bundle")
	if completed.size() == 1:
		var results: Array[DamageResult] = completed[0].results
		_assert(results.size() == 2, "200% critical chance produces two defense-bearing instances")
		if results.size() == 2:
			_assert(results[0].instance_index == 0 and results[0].dodged and not results[0].blocked, "instance zero independently consumes the prescribed successful dodge")
			_assert(is_equal_approx(results[0].dodge_draw, 0.10) and results[0].block_draw < 0.0, "dodged instance preserves its own draw evidence and skips block")
			_assert(results[1].instance_index == 1 and not results[1].dodged and results[1].blocked, "instance one independently consumes failed dodge then successful block")
			_assert(is_equal_approx(results[1].dodge_draw, 0.90) and is_equal_approx(results[1].block_draw, 0.10), "blocked instance preserves both of its own draws")
	_assert((fixture["rng"] as CombatRng).draw_count == 3, "two instances consume exactly three independent defense draws")
	(fixture["root"] as Node).free()
	await process_frame


func _verify_lethal_bundle_lifecycle() -> void:
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	settings.unlock_all_implemented_content = true
	settings.set("force_personal_drops", true)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = PROFILE_ROOT
	main.settings_path = SETTINGS_PATH
	root.add_child(main)
	await process_frame
	if main.profile_manager.active_profile() == null:
		main.profile_manager.create_profile("Multi Crit Integration")
	main.saved_settings = settings.copy()
	_assert(main.select_leader_class(&"fighter"), "live Main starts a Fighter run for lethal multi-crit")
	if not main.run_started:
		main.free()
		ProfileTestSupport.remove_tree(PROFILE_ROOT)
		_cleanup_settings()
		return

	var service := main.combat_resolution_service as CombatResolutionService
	service.process_mode = Node.PROCESS_MODE_DISABLED
	main.game_run.combat_rng.reseed(80823, [0.49])
	var member_id := main.party_manager.members[0].member_id
	var base_crit := main.party_manager.stats_for(member_id).value(&"crit_chance")
	var crit_source := StatModifierSource.create(&"integration_lethal_1150", &"test", "Integration Lethal 1150", member_id, [
		StatModifier.create(&"crit_chance", StatModifier.Operation.FLAT, 11.50 - base_crit, &"integration_lethal_1150", "Integration Lethal 1150"),
	])
	_assert(main.party_manager.add_member_source(member_id, crit_source), "live Main registers exact 1150% critical chance")
	main.leader.process_mode = Node.PROCESS_MODE_DISABLED
	var director := main.get_node("SpawnDirector") as SpawnDirector
	var marker := Marker3D.new()
	marker.position = main.leader.position
	main.get_node("Arena").add_child(marker)
	director.spawn_markers = [marker]
	director.camera = null
	var roll_service := main.personal_loot_roll_service as PersonalLootRollService
	roll_service.loot_tuning.drop_basis_points[&"ordinary_specialist"] = 10000
	var registry := main.ground_item_registry as GroundItemRegistry
	var effects := main.get_node("Effects") as Node3D
	var orbs_before := _experience_orb_count(effects)
	var loot_before := registry.all_records().size()
	var enemy := director.spawn_enemy(&"boltcaster") as EnemyActor
	_assert(enemy != null, "live SpawnDirector creates the lethal target")
	if enemy == null:
		main.free()
		ProfileTestSupport.remove_tree(PROFILE_ROOT)
		_cleanup_settings()
		return
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.position = main.leader.position
	var enemy_id := enemy.combatant_id
	var enemy_position := enemy.global_position
	var enemy_health := enemy.get_node("HealthComponent") as HealthComponent
	enemy_health.current_health = 1.0
	var rewards := [0]
	var defeats := [0]
	enemy.reward_dropped.connect(func(_experience: int, _position: Vector3) -> void: rewards[0] += 1)
	enemy.enemy_defeated.connect(func(_definition: EnemyDefinition, _position: Vector3) -> void: defeats[0] += 1)
	var completed: Array[RefCounted] = []
	service.bundle_completed.connect(func(bundle: RefCounted) -> void: completed.append(bundle))
	main.leader.attack_executor.configure(main.leader, main.party_manager, effects, [enemy] as Array[Node3D], service)
	main.leader.attack_executor.execute(main.party_manager.members[0].class_definition.primary_attack, enemy.get_combat_target())
	_assert(completed.size() == 1, "lethal multi-crit resolves exactly one bundle")
	_assert(rewards[0] == 1 and defeats[0] == 1, "lethal bundle emits enemy reward and defeat exactly once")
	_assert(_experience_orb_count(effects) == orbs_before + 1, "lethal bundle creates exactly one XP reward")
	_assert(registry.all_records().size() == loot_before + 1, "lethal bundle performs exactly one personal-loot drop")
	var lethal_bundle := completed[0] if completed.size() == 1 else null
	if lethal_bundle != null:
		_assert(lethal_bundle.results.size() == 12, "lethal 1150% bundle retains all twelve instance results")
		_assert(lethal_bundle.total_overkill > 0.0, "later successful instances contribute positive overkill")
		_assert(lethal_bundle.results.slice(1).all(func(result: DamageResult) -> bool: return result.overkill_only), "all successful post-death instances are marked overkill-only")
	var record := service.overkill_buffer.get_record(enemy_id)
	_assert(record != null and record.amount > 0.0, "overkill is buffered before queued deletion")
	_assert(enemy.is_queued_for_deletion(), "lethal resolution queues the enemy for natural deletion")
	for _frame: int in 8:
		if not is_instance_valid(enemy):
			break
		await process_frame
	_assert(not is_instance_valid(enemy), "natural frame processing frees the queued enemy")
	if lethal_bundle != null:
		var events: Array = lethal_bundle.presentation_events
		_assert(events.size() == 12, "presentation evidence remains available after target deletion")
		for index: int in events.size():
			var event: CombatDamageInstanceEvent = events[index]
			_assert(event.instance_index == index and event.instance_count == 12, "presentation event %d keeps stable bundle index/count after deletion" % index)
			_assert(event.target_id == enemy_id and event.target_position.is_equal_approx(enemy_position), "presentation event %d keeps target identity/position after deletion" % index)
	record = service.overkill_buffer.get_record(enemy_id)
	_assert(record != null and is_equal_approx(record.amount, lethal_bundle.total_overkill if lethal_bundle != null else 0.0), "overkill remains readable after the enemy node is freed")
	_assert(service.advance(1.999), "overkill clock accepts deterministic 1.999-second advancement")
	_assert(service.overkill_buffer.get_record(enemy_id) != null, "overkill remains readable through 1.999 seconds")
	_assert(service.advance(0.001), "overkill clock accepts the final deterministic millisecond")
	_assert(service.overkill_buffer.get_record(enemy_id) == null, "overkill expires at deterministic two-second advancement")
	paused = false
	main.free()
	await process_frame
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()


func _party_fixture(class_id: StringName, exact_crit: float, draws: Array[float], label: String) -> Dictionary:
	var fixture_root := Node3D.new()
	fixture_root.name = "MultiCrit%s" % label.replace(" ", "")
	root.add_child(fixture_root)
	var catalog := GameCatalog.load_defaults()
	var rng := CombatRng.new(80823, draws)
	var service := COMBAT_RESOLUTION_SERVICE.new(rng, catalog.damage_types) as CombatResolutionService
	service.name = "CombatResolutionService"
	fixture_root.add_child(service)
	var party := PartyManager.new()
	fixture_root.add_child(party)
	var definition := catalog.class_by_id(class_id)
	party.initialize(definition, catalog.traits)
	party.configure_combat(rng, catalog.damage_types, service)
	var target_definition := _target_definition(StringName("%s_target" % class_id))
	_assert(party.recruit(target_definition), "%s fixture recruits its durable target" % label)
	var member_id := party.members[0].member_id
	var base_crit := party.stats_for(member_id).value(&"crit_chance")
	var source := StatModifierSource.create(StringName("integration_crit_%s" % label.to_snake_case()), &"test", "Integration Exact Crit", member_id, [
		StatModifier.create(&"crit_chance", StatModifier.Operation.FLAT, exact_crit - base_crit, StringName("integration_crit_%s" % label.to_snake_case()), "Integration Exact Crit"),
	])
	_assert(party.add_member_source(member_id, source), "%s fixture registers exact critical chance" % label)
	var effects := Node3D.new()
	effects.name = "Effects"
	fixture_root.add_child(effects)
	var owner := _member_actor(fixture_root, party, party.members[0], 1, Vector3.ZERO)
	var target := _member_actor(fixture_root, party, party.members[1], 2, Vector3(0.25, 0.0, 0.0))
	owner.process_mode = Node.PROCESS_MODE_DISABLED
	target.process_mode = Node.PROCESS_MODE_DISABLED
	var health := target.get_node("HealthComponent") as HealthComponent
	health.configure(10000.0, false, 1.0, 1.0, true)
	return {
		"root": fixture_root,
		"catalog": catalog,
		"rng": rng,
		"service": service,
		"party": party,
		"effects": effects,
		"owner": owner,
		"target": target,
	}


func _member_actor(parent: Node, party: PartyManager, member: PartyMemberState, team: int, actor_position: Vector3) -> PartyActor:
	var scene_path := "res://scenes/characters/leader.tscn" if member.is_leader else "res://scenes/characters/companion.tscn"
	var actor := (load(scene_path) as PackedScene).instantiate() as PartyActor
	actor.team_id = team
	actor.position = actor_position
	actor.configure(member)
	parent.add_child(actor)
	actor.configure_combat(party, parent)
	return actor


func _target_definition(id: StringName) -> ClassDefinition:
	var definition := ClassDefinition.new()
	definition.id = id
	definition.display_name = String(id).capitalize()
	definition.max_health = 10000.0
	definition.armor = 0.0
	definition.move_speed = 1.0
	definition.primary_attack = load("res://data/attacks/fighter_cleave.tres") as AttackDefinition
	return definition


func _wait_for_bundle(completed: Array[RefCounted]) -> void:
	for _frame: int in 120:
		if not completed.is_empty():
			return
		await process_frame


func _count_projectiles(parent: Node) -> int:
	var count := 0
	for child: Node in parent.get_children():
		if child is PartyProjectile:
			count += 1
	return count


func _sum_damage(results: Array[DamageResult]) -> float:
	var total := 0.0
	for result: DamageResult in results:
		total += result.final_damage
	return total


func _experience_orb_count(parent: Node) -> int:
	var count := 0
	for child: Node in parent.get_children():
		if child.scene_file_path == "res://scenes/progression/experience_orb.tscn":
			count += 1
	return count


func _cleanup_settings() -> void:
	for path: String in [SETTINGS_PATH, "%s.tmp" % SETTINGS_PATH, "%s.bak" % SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	if _failures.is_empty():
		print("MULTI_CRIT_COMBAT_INTEGRATION: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MULTI_CRIT_COMBAT_INTEGRATION: %s" % failure)
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
