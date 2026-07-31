class_name PartyForgeMain
extends Node

const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/forge_guardian.tscn")
const HEALTH_BAR_SCENE := preload("res://scenes/ui/health_bar_3d.tscn")
const HUDScript := preload("res://scripts/ui/hud.gd")
const LevelUpPanelScript := preload("res://scripts/ui/level_up_panel.gd")
const RunResultPanelScript := preload("res://scripts/ui/run_result_panel.gd")
const RUN_SEED := 1337
const CURRENT_STARTING_PARTY_SIZE := 1
const LEDGER_FEATURE_IDS: Array[StringName] = [&"stats", &"current_upgrades", &"equipment_inventory"]

var party_stats: Dictionary = {}
var trait_upgrade_ranks: Dictionary = {}
var catalog: GameCatalog
var party_manager: PartyManager
var experience_system: ExperienceSystem
var game_run: GameRun
var spawn_director: SpawnDirector
var party_actor_spawner: PartyActorSpawner
var hud: CanvasLayer
var developer_mode_badge: DeveloperModeBadge
var character_ledger: CharacterLedger
var run_pause_menu: RunPauseMenu
var leader: PartyActor
var boss: Node3D
var run_started := false
var initialized := false
var catalog_valid := false
var level_refresh_scheduled := false
var saved_settings: PartyForgeSettings
var settings_store: PartyForgeSettingsStore
var active_run_rules: RunRulesSnapshot

func _ready() -> void:
	if initialized:
		return
	initialized = true
	_cache_nodes()
	settings_store = PartyForgeSettingsStore.new()
	saved_settings = settings_store.load_settings()
	(get_node("SettingsScreen") as SettingsScreen).configure(settings_store, saved_settings)
	catalog = GameCatalog.load_defaults()
	catalog_valid = _validate_catalog(catalog)
	if not catalog_valid:
		return
	_wire_static_ui()
	print("PARTY_FORGE_BOOT_OK")
	print("PARTY_FORGE_CLASS_SELECTION_READY")

func select_leader_class(class_id: StringName) -> bool:
	if not initialized:
		_ready()
	if run_started or catalog == null or not catalog_valid:
		return false
	catalog_valid = _validate_catalog(catalog, false)
	if not catalog_valid:
		return false
	var definition := catalog.class_by_id(class_id)
	if definition == null:
		push_error(format_resource_error("res://data/classes", "unknown leader class %s" % class_id))
		return false
	active_run_rules = RunRulesSnapshot.from_settings(saved_settings)
	developer_mode_badge.configure(active_run_rules)
	party_manager.configure_capacity(active_run_rules.capacity_policy())
	if CURRENT_STARTING_PARTY_SIZE > active_run_rules.party_capacity():
		push_error("PARTY_FORGE_STARTING_PARTY_CAPACITY_ERROR selected=%d capacity=%d" % [CURRENT_STARTING_PARTY_SIZE, active_run_rules.party_capacity()])
		return false
	game_run.configure_seed(RUN_SEED)
	party_manager.configure_identity(game_run.run_seed, catalog.generic_name_pool)
	party_manager.initialize(definition, catalog.traits)
	party_manager.configure_combat(game_run.combat_rng, catalog.damage_types)
	leader = LEADER_SCENE.instantiate() as PartyActor
	get_node("Actors").add_child(leader)
	var spawn := get_node("Arena/PlayerSpawn") as Marker3D
	leader.position = spawn.position
	leader.configure(party_manager.members[0])
	var combat_policy := active_run_rules.combat_policy()
	leader.configure_combat_policy(combat_policy)
	leader.configure_combat(party_manager, get_node("Effects"))
	_attach_health_bar(leader)
	party_actor_spawner.initialize(party_manager, get_node("Actors") as Node3D, leader, get_node("Effects"), combat_policy)
	var camera_rig := get_node("LeaderCamera") as LeaderCamera
	camera_rig.target = leader
	var markers := _spawn_markers()
	var camera := camera_rig.get_node("Camera3D") as Camera3D
	spawn_director.configure(RUN_SEED, leader, experience_system, markers, camera, get_node("Enemies"), get_node("Effects"), _pickup_multiplier(), game_run.combat_rng, catalog.damage_types, active_run_rules.enemy_density_percent())
	spawn_director.process_mode = Node.PROCESS_MODE_INHERIT
	hud.call("configure", game_run, party_manager, experience_system)
	hud.call("set_leader", leader)
	var health := leader.get_node("HealthComponent") as HealthComponent
	if not health.died.is_connected(game_run.leader_defeated): health.died.connect(game_run.leader_defeated)
	if not experience_system.level_ready.is_connected(_on_level_ready): experience_system.level_ready.connect(_on_level_ready)
	if not spawn_director.enemy_spawned.is_connected(_on_enemy_spawned): spawn_director.enemy_spawned.connect(_on_enemy_spawned)
	(get_node("HUD/ClassSelection") as Control).visible = false
	run_started = true
	character_ledger.configure(game_run, party_manager, catalog, Callable(self, "_ledger_health_for_member"), [], active_run_rules.feature_policy(LEDGER_FEATURE_IDS))
	game_run.start_run()
	return true

func _apply_choice(choice: UpgradeChoice, report_error: bool = true) -> bool:
	return _apply_choice_for_member(choice, 0, report_error)

func _apply_choice_for_member(choice: UpgradeChoice, recipient_member_id: int, report_error: bool = true) -> bool:
	if not _choice_is_valid(choice):
		if report_error and choice != null:
			push_error("PARTY_FORGE_INVALID_CHOICE kind=%d target=%s member=%d" % [choice.kind, choice.target_id, recipient_member_id])
		return false
	var applied := false
	match choice.kind:
		UpgradeChoice.Kind.RECRUIT:
			applied = party_manager.recruit(catalog.class_by_id(choice.target_id))
		UpgradeChoice.Kind.CLASS_RANK:
			applied = party_manager.rank_up(choice.target_id)
		UpgradeChoice.Kind.TRAIT:
			applied = party_manager.upgrade_trait(choice.target_id)
		UpgradeChoice.Kind.PARTY_STAT:
			applied = party_manager.upgrade_party_stat(choice.target_id)
			if applied and choice.target_id == &"pickup_radius":
				_sync_pickup_radius()
		UpgradeChoice.Kind.AUTHORED:
			var definition := catalog.upgrade_by_id(choice.target_id) if catalog != null else null
			if definition == null or choice.definition != definition:
				if report_error:
					push_error("PARTY_FORGE_INVALID_CHOICE kind=%d target=%s member=%d" % [choice.kind, choice.target_id, recipient_member_id])
				return false
			var owner_member_id := recipient_member_id if definition.is_single_recipient() else 0
			if not UpgradeApplicationService.validate_application(definition, party_manager, owner_member_id).is_empty():
				if report_error:
					push_error("PARTY_FORGE_INVALID_CHOICE kind=%d target=%s member=%d" % [choice.kind, choice.target_id, recipient_member_id])
				return false
			applied = UpgradeApplicationService.apply(definition.id, catalog, party_manager, owner_member_id)
	if not applied:
		if report_error:
			push_error("PARTY_FORGE_INVALID_CHOICE kind=%d target=%s member=%d" % [choice.kind, choice.target_id, recipient_member_id])
		return false
	experience_system.consume_pending_level()
	if experience_system.pending_levels > 0:
		level_refresh_scheduled = true
		call_deferred("_present_pending_level")
	else:
		level_refresh_scheduled = false
		game_run.resume_run()
	return true

func _on_choice_confirmation_requested(choice: UpgradeChoice, recipient_member_id: int) -> void:
	var panel := get_node("HUD/LevelUpPanel") as LevelUpPanel
	if _apply_choice_for_member(choice, recipient_member_id, false):
		panel.complete_selection()
	else:
		panel.reject_selection("Selection is no longer available.")

func _health_for_member(member_id: int) -> Vector2:
	if party_manager == null or party_manager.member_by_id(member_id) == null:
		return Vector2.ZERO
	var actors := get_node_or_null("Actors")
	if actors == null:
		return Vector2.ZERO
	for child: Node in actors.get_children():
		var actor := child as PartyActor
		if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		if actor.member_state == null or actor.member_state.member_id != member_id:
			continue
		var health := actor.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			return Vector2(health.current_health, health.max_health)
		return Vector2.ZERO
	return Vector2.ZERO

func _ledger_health_for_member(member_id: int) -> Dictionary:
	var actors := get_node_or_null("Actors")
	if actors == null:
		return {}
	for child: Node in actors.get_children():
		var actor := child as PartyActor
		if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		if actor.member_state == null or actor.member_state.member_id != member_id:
			continue
		var health := actor.get_node_or_null("HealthComponent") as HealthComponent
		if health == null:
			return {}
		return {
			"current": health.current_health,
			"maximum": health.max_health,
			"is_downed": health.is_downed,
			"is_dead": health.is_dead,
			"component": health,
		}
	return {}

static func format_resource_error(path: String, reason: String) -> String:
	return "PARTY_FORGE_RESOURCE_ERROR path=%s reason=%s" % [path, reason]

func _cache_nodes() -> void:
	party_manager = get_node("PartyManager") as PartyManager
	party_stats = party_manager.party_stat_ranks
	trait_upgrade_ranks = party_manager.trait_upgrade_ranks
	experience_system = get_node("ExperienceSystem") as ExperienceSystem
	game_run = get_node("GameRun") as GameRun
	spawn_director = get_node("SpawnDirector") as SpawnDirector
	party_actor_spawner = get_node("PartyActorSpawner") as PartyActorSpawner
	hud = get_node("HUD") as CanvasLayer
	developer_mode_badge = get_node("DeveloperModeBadge") as DeveloperModeBadge
	character_ledger = get_node("CharacterLedger") as CharacterLedger
	run_pause_menu = get_node("RunPauseMenu") as RunPauseMenu

func _validate_catalog(target_catalog: GameCatalog, report_errors: bool = true) -> bool:
	var errors := target_catalog.validate()
	if report_errors:
		for reason: String in errors:
			push_error(format_resource_error("res://data", reason))
	return errors.is_empty()

func _wire_static_ui() -> void:
	var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
	selector.configure(catalog.classes)
	if not selector.class_selected.is_connected(select_leader_class):
		selector.class_selected.connect(select_leader_class)
	if not selector.settings_requested.is_connected(_open_settings):
		selector.settings_requested.connect(_open_settings)
	var settings_screen := get_node("SettingsScreen") as SettingsScreen
	if not settings_screen.settings_applied.is_connected(_on_settings_applied):
		settings_screen.settings_applied.connect(_on_settings_applied)
	var level_panel := get_node("HUD/LevelUpPanel") as LevelUpPanel
	level_panel.configure(catalog, UpgradeApplicationService.new(), Callable(self, "_health_for_member"))
	var legacy_apply := Callable(self, "_apply_choice")
	if level_panel.is_connected("choice_selected", legacy_apply):
		level_panel.disconnect("choice_selected", legacy_apply)
	var confirmation_handler := Callable(self, "_on_choice_confirmation_requested")
	if not level_panel.is_connected("confirmation_requested", confirmation_handler):
		level_panel.connect("confirmation_requested", confirmation_handler)
	var result := get_node("HUD/RunResultPanel") as Control
	if not result.is_connected("restart_requested", _restart): result.connect("restart_requested", _restart)
	if not result.is_connected("quit_requested", _quit): result.connect("quit_requested", _quit)
	var neutral_ledger_policy := RunRulesSnapshot.from_settings(PartyForgeSettings.new()).feature_policy(LEDGER_FEATURE_IDS)
	character_ledger.configure(game_run, party_manager, catalog, Callable(self, "_ledger_health_for_member"), [], neutral_ledger_policy)
	run_pause_menu.configure(game_run, Callable(character_ledger, "is_open"))
	if not run_pause_menu.quit_run_confirmed.is_connected(_return_to_front_end):
		run_pause_menu.quit_run_confirmed.connect(_return_to_front_end)
	if not game_run.boss_requested.is_connected(_spawn_boss): game_run.boss_requested.connect(_spawn_boss)
	if not game_run.victory.is_connected(_show_victory): game_run.victory.connect(_show_victory)
	if not game_run.defeat.is_connected(_show_defeat): game_run.defeat.connect(_show_defeat)

func _open_settings() -> void:
	var return_focus := get_node("HUD/ClassSelection/Content/Actions/Settings") as Control
	(get_node("SettingsScreen") as SettingsScreen).open(return_focus)

func _on_settings_applied(settings: PartyForgeSettings) -> void:
	saved_settings = settings.copy()

func _on_level_ready(_level: int) -> void:
	if not run_started:
		return
	game_run.begin_level_up()
	if game_run.current_state() != RunStateMachine.State.LEVEL_UP:
		return
	var panel := get_node("HUD/LevelUpPanel") as Control
	if panel.visible or level_refresh_scheduled:
		return
	_present_pending_level()

func _present_pending_level() -> void:
	level_refresh_scheduled = false
	if experience_system.pending_levels <= 0:
		game_run.resume_run()
		return
	if game_run.current_state() != RunStateMachine.State.LEVEL_UP:
		game_run.begin_level_up()
	if game_run.current_state() != RunStateMachine.State.LEVEL_UP:
		return
	var offer_seed := experience_system.current_pending_level() * 1009 + party_manager.members.size()
	var choices := _generate_valid_choices(offer_seed)
	get_node("HUD/LevelUpPanel").call("show_choices", choices, party_manager, _invalid_choice_keys(choices))

func _choice_is_valid(choice: UpgradeChoice) -> bool:
	if choice == null or party_manager == null or not choice.is_valid_for(party_manager):
		return false
	match choice.kind:
		UpgradeChoice.Kind.RECRUIT:
			return catalog != null and catalog.class_by_id(choice.target_id) != null
		UpgradeChoice.Kind.PARTY_STAT:
			return choice.target_id in PartyManager.PARTY_STAT_IDS and party_manager.party_stat_rank(choice.target_id) < party_manager.upgrade_tuning.party_stat_max_rank
		UpgradeChoice.Kind.AUTHORED:
			return catalog != null and catalog.upgrade_by_id(choice.target_id) == choice.definition
		_:
			return true

func _invalid_choice_keys(choices: Array[UpgradeChoice]) -> Dictionary:
	var invalid: Dictionary = {}
	for choice: UpgradeChoice in choices:
		if not _choice_is_valid(choice):
			invalid[choice.key()] = true
	return invalid

@warning_ignore("shadowed_global_identifier")
func _generate_valid_choices(seed: int) -> Array[UpgradeChoice]:
	return LevelUpChoiceService.generate(party_manager, catalog, seed)

func _spawn_boss() -> void:
	if boss != null and is_instance_valid(boss):
		return
	boss = BOSS_SCENE.instantiate() as Node3D
	get_node("Enemies").add_child(boss)
	boss.call("configure_combat", &"boss", game_run.combat_rng, catalog.damage_types)
	var markers := _spawn_markers()
	boss.position = markers[0].position if not markers.is_empty() else Vector3(12.0, 0.75, 0.0)
	boss.call("configure_boss", leader, spawn_director, get_node("Effects"))
	_attach_health_bar(boss)
	boss.connect("boss_defeated", game_run.boss_defeated)
	hud.call("set_boss", boss)
	hud.call("show_boss_banner")

func _on_enemy_spawned(_enemy_id: StringName, enemy: Node3D) -> void:
	_attach_health_bar(enemy)

func _attach_health_bar(actor: Node3D) -> void:
	if actor == null or actor.get_node_or_null("HealthBar3D") != null:
		return
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		return
	var bar := HEALTH_BAR_SCENE.instantiate() as Node3D
	actor.add_child(bar)
	bar.call("configure", health)

func _spawn_markers() -> Array[Node3D]:
	var markers: Array[Node3D] = []
	for child: Node in get_node("Arena").get_children():
		if child is Node3D and child.is_in_group("enemy_spawn_markers"):
			markers.append(child as Node3D)
	return markers

func _pickup_multiplier() -> float:
	return party_manager.party_stat_multiplier(&"pickup_radius") if party_manager != null else 1.0

func _sync_pickup_radius() -> void:
	if spawn_director != null:
		spawn_director.set_pickup_radius_multiplier(_pickup_multiplier())

func _show_victory() -> void:
	_cancel_hostile_effects()
	get_node("HUD/RunResultPanel").call("show_result", true)

func _show_defeat() -> void:
	_cancel_hostile_effects()
	get_node("HUD/RunResultPanel").call("show_result", false)

func _cancel_hostile_effects() -> void:
	if boss != null and is_instance_valid(boss) and boss.has_method("cancel_pending_effects"):
		boss.call("cancel_pending_effects")
	if is_inside_tree():
		for effect: Node in get_tree().get_nodes_in_group(&"hostile_transient_effects"):
			effect.queue_free()

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_front_end() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _quit() -> void:
	get_tree().quit()
