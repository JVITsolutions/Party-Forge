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
const CITY_TREE_ID := "party-forge-city-v1"
const CITY_ORIGIN_MAIN_MENU: StringName = &"main_menu"
const CITY_ORIGIN_ADDITIONAL_SETTINGS: StringName = &"additional_settings"
const CITY_UNAVAILABLE_STATUS := "City services are temporarily unavailable."
const CITY_LOCKED_STATUS := "Complete the prologue to unlock the City passive tree."
const CITY_PROFILE_REQUIRED_STATUS := "Choose a profile before opening the City passive tree."
const CITY_DEVELOPER_REQUIRED_STATUS := "Save Developer Mode before opening the Developer City Preview."
const DEVELOPER_QUICK_START_UNAVAILABLE_STATUS := "Developer Quick Start is temporarily unavailable."
const DEVELOPER_QUICK_START_PROFILE_REQUIRED_STATUS := "Choose a profile before using Developer Quick Start."
const DEVELOPER_QUICK_START_MODE_REQUIRED_STATUS := "Save Developer Mode before using Developer Quick Start."

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
var profile_root := ProfileStore.DEFAULT_ROOT
var profile_manager: ProfileManager
var profile_bootstrap_error := ""
var passive_tree_definition: PassiveTreeDefinition
var passive_tree_mutations: PassiveTreeMutationService
var passive_tree_view_model: PassiveTreeViewModel
var active_run_rules: RunRulesSnapshot
var _level_up_offer_state := LevelUpOfferState.new()
var _city_tree_origin: StringName = &""
var _city_tree_return_focus: Control

func _ready() -> void:
	if initialized:
		return
	initialized = true
	_cache_nodes()
	settings_store = PartyForgeSettingsStore.new()
	saved_settings = settings_store.load_settings()
	profile_manager = ProfileManager.new()
	profile_bootstrap_error = profile_manager.bootstrap(profile_root)
	if not profile_bootstrap_error.is_empty():
		push_error(profile_bootstrap_error)
	var settings_screen := get_node("SettingsScreen") as SettingsScreen
	settings_screen.configure(settings_store, saved_settings, profile_manager)
	_expose_profile_bootstrap_diagnostic()
	catalog = GameCatalog.load_defaults()
	catalog_valid = _validate_catalog(catalog)
	_load_passive_tree_runtime()
	_wire_static_ui()
	_present_front_end()
	print("PARTY_FORGE_BOOT_OK")
	print("PARTY_FORGE_CLASS_SELECTION_READY")

func select_leader_class(class_id: StringName) -> bool:
	if not initialized:
		_ready()
	if profile_manager == null or profile_manager.active_profile() == null:
		push_error("PARTY_FORGE_RUN_PROFILE_REQUIRED")
		_open_profiles_from_main_menu()
		return false
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
	_level_up_offer_state = LevelUpOfferState.new()
	(get_node("HUD/LevelUpPanel") as LevelUpPanel).configure_reduced_motion(active_run_rules.reduced_motion())
	experience_system.configure_multiplier(active_run_rules.experience_multiplier_percent())
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
	leader.configure_combat(party_manager, get_node("Effects"))
	leader.configure_combat_policy(combat_policy)
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
	run_started = true
	character_ledger.configure(game_run, party_manager, catalog, Callable(self, "_ledger_health_for_member"), [], active_run_rules.feature_policy(LEDGER_FEATURE_IDS))
	game_run.start_run()
	(get_node("MainMenuScreen") as MainMenuScreen).close()
	(get_node("HUD/ClassSelection") as ClassSelectionPanel).confirm_run_started()
	return true

func active_profile() -> ProfileState:
	return profile_manager.active_profile() if profile_manager != null else null

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
	if not selector.back_requested.is_connected(_on_run_setup_back_requested):
		selector.back_requested.connect(_on_run_setup_back_requested)
	var main_menu := get_node("MainMenuScreen") as MainMenuScreen
	if not main_menu.route_requested.is_connected(_on_main_menu_route_requested):
		main_menu.route_requested.connect(_on_main_menu_route_requested)
	var settings_screen := get_node("SettingsScreen") as SettingsScreen
	if not settings_screen.settings_applied.is_connected(_on_settings_applied):
		settings_screen.settings_applied.connect(_on_settings_applied)
	if not settings_screen.city_tree_requested.is_connected(_on_settings_city_tree_requested):
		settings_screen.city_tree_requested.connect(_on_settings_city_tree_requested)
	var passive_screen := get_node("PassiveTreeScreen") as PassiveTreeScreen
	if not passive_screen.tree_closed.is_connected(_on_city_passive_tree_closed):
		passive_screen.tree_closed.connect(_on_city_passive_tree_closed)
	if not profile_manager.profiles_changed.is_connected(_on_profiles_changed):
		profile_manager.profiles_changed.connect(_on_profiles_changed)
	if not profile_manager.active_profile_changed.is_connected(_on_active_profile_changed):
		profile_manager.active_profile_changed.connect(_on_active_profile_changed)
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


func _on_main_menu_route_requested(route_id: StringName) -> void:
	match route_id:
		MainMenuViewModel.ROUTE_PROFILES:
			_open_profiles_from_main_menu()
		MainMenuViewModel.ROUTE_PROLOGUE_START:
			_on_prologue_start_requested()
		MainMenuViewModel.ROUTE_PROLOGUE_RESUME:
			_on_prologue_resume_requested()
		MainMenuViewModel.ROUTE_RUN_SETUP:
			_open_run_setup()
		MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START:
			_on_developer_quick_start_requested()
		MainMenuViewModel.ROUTE_SETTINGS:
			_open_settings_from_main_menu()
		MainMenuViewModel.ROUTE_CITY_TREE:
			var menu := get_node("MainMenuScreen") as MainMenuScreen
			var developer_preview := saved_settings != null and saved_settings.mode == PartyForgeSettings.Mode.DEVELOPER_MODE
			_open_city_passive_tree(developer_preview, CITY_ORIGIN_MAIN_MENU, menu.get_node("CityTree") as Control)
		MainMenuViewModel.ROUTE_QUIT:
			_quit()


func _on_prologue_start_requested() -> void:
	_open_run_setup()


func _on_prologue_resume_requested() -> void:
	_open_run_setup()


func _on_developer_quick_start_requested() -> void:
	var denial_status := _developer_quick_start_denial()
	if not denial_status.is_empty():
		_fail_developer_quick_start(denial_status)
		return
	if not select_leader_class(&"fighter"):
		_fail_developer_quick_start(DEVELOPER_QUICK_START_UNAVAILABLE_STATUS)


func _developer_quick_start_denial() -> String:
	if saved_settings == null or saved_settings.mode != PartyForgeSettings.Mode.DEVELOPER_MODE:
		return DEVELOPER_QUICK_START_MODE_REQUIRED_STATUS
	var profile := profile_manager.active_profile() if profile_manager != null else null
	if profile == null or not ProfileCodec.validate_profile(profile).is_empty():
		return DEVELOPER_QUICK_START_PROFILE_REQUIRED_STATUS
	if catalog == null or not catalog_valid or not _validate_catalog(catalog, false) or catalog.class_by_id(&"fighter") == null:
		catalog_valid = false
		return DEVELOPER_QUICK_START_UNAVAILABLE_STATUS
	return ""


func _fail_developer_quick_start(status_text: String) -> void:
	(get_node("HUD/ClassSelection") as ClassSelectionPanel).close()
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	var quick_start := menu.get_node("DeveloperQuickStart") as Control
	menu.open(quick_start)
	(menu.get_node("Status") as Label).text = status_text
	_focus_control_if_available(quick_start)


func _open_run_setup() -> void:
	(get_node("MainMenuScreen") as MainMenuScreen).close()
	(get_node("HUD/ClassSelection") as ClassSelectionPanel).open()


func _on_run_setup_back_requested() -> void:
	var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
	selector.close()
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	menu.open(menu.get_node("PrimaryAction") as Control)


func _open_profiles_from_main_menu() -> void:
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	menu.open(menu.get_node("PrimaryAction") as Control)
	(get_node("HUD/ClassSelection") as ClassSelectionPanel).close()
	(get_node("SettingsScreen") as SettingsScreen).open_profiles(menu.get_node("PrimaryAction") as Control)


func _open_settings_from_main_menu() -> void:
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	(get_node("SettingsScreen") as SettingsScreen).open(menu.get_node("Settings") as Control)


func _present_front_end(preferred_focus: Control = null) -> void:
	run_started = false
	(get_node("HUD/Margin") as Control).visible = false
	(get_node("HUD/ClassSelection") as ClassSelectionPanel).close()
	(get_node("SettingsScreen") as SettingsScreen).close()
	_refresh_main_menu_projection()
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	menu.open(preferred_focus if preferred_focus != null else menu.get_node("PrimaryAction") as Control)


func _refresh_main_menu_projection() -> void:
	var projection := MainMenuViewModel.build(
		profile_manager.active_profile() if profile_manager != null else null,
		saved_settings,
		_city_runtime_available()
	)
	if not profile_bootstrap_error.is_empty():
		projection.status_text = "Some profile data needs attention. Open Settings > Profiles for details."
	(get_node("MainMenuScreen") as MainMenuScreen).present(projection)


func _on_profiles_changed() -> void:
	_refresh_main_menu_projection()


func _on_active_profile_changed(_profile: ProfileState) -> void:
	_refresh_main_menu_projection()
	if _city_tree_is_open():
		return
	if run_started:
		return
	var settings_screen := get_node("SettingsScreen") as SettingsScreen
	if settings_screen.is_open():
		settings_screen.close()
	var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
	selector.close()
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	menu.open(menu.get_node("PrimaryAction") as Control)


func _expose_profile_bootstrap_diagnostic() -> void:
	if profile_bootstrap_error.is_empty():
		return
	var profiles := get_node("SettingsScreen/Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	profiles.set_bootstrap_diagnostic(
		"Some profile data could not be loaded. You can create or choose another profile.",
		profile_bootstrap_error
	)


func _load_passive_tree_runtime() -> void:
	var loaded := PassiveTreeCatalog.load_defaults()
	for reason: String in loaded.errors:
		push_error(reason)
	passive_tree_definition = loaded.tree
	var effects := PassiveEffectRegistry.new()
	var requirements := PassiveRequirementRegistry.new()
	var progression := PassiveTreeProgressionService.new(effects, requirements)
	var resolver := PassiveEffectResolver.new(effects)
	passive_tree_mutations = PassiveTreeMutationService.new(ProfileMutationService.new(ProfileStore.new()), progression, resolver)
	passive_tree_view_model = PassiveTreeViewModel.new(progression, resolver, effects, requirements)


func _on_settings_city_tree_requested(developer_preview: bool) -> void:
	var button := get_node("SettingsScreen/Overlay/Frame/Layout/Tabs/Additional Settings/Layout/OpenCityPassiveTree") as Control
	_open_city_passive_tree(developer_preview, CITY_ORIGIN_ADDITIONAL_SETTINGS, button)


func _open_city_passive_tree(developer_preview: bool, origin: StringName, return_focus: Control) -> bool:
	var denial_status := _city_route_denial(developer_preview)
	if not denial_status.is_empty():
		_fail_city_route(origin, return_focus, denial_status)
		return false
	_city_tree_origin = origin
	_city_tree_return_focus = return_focus
	var screen := get_node("PassiveTreeScreen") as PassiveTreeScreen
	screen.configure(passive_tree_definition, profile_manager, passive_tree_mutations, passive_tree_view_model, developer_preview, profile_root)
	if origin == CITY_ORIGIN_MAIN_MENU:
		(get_node("MainMenuScreen") as MainMenuScreen).close()
	screen.open(return_focus)
	return true


func _city_route_denial(developer_preview: bool) -> String:
	var profile := profile_manager.active_profile() if profile_manager != null else null
	if profile == null:
		return CITY_PROFILE_REQUIRED_STATUS
	if developer_preview:
		if saved_settings == null or saved_settings.mode != PartyForgeSettings.Mode.DEVELOPER_MODE:
			return CITY_DEVELOPER_REQUIRED_STATUS
	elif profile.prologue_state != ProfileState.PrologueState.COMPLETED or CITY_TREE_ID not in profile.discovered_trees:
		return CITY_LOCKED_STATUS
	if not _city_runtime_available():
		return CITY_UNAVAILABLE_STATUS
	return ""


func _city_runtime_available() -> bool:
	return (
		passive_tree_definition != null
		and String(passive_tree_definition.id) == CITY_TREE_ID
		and profile_manager != null
		and passive_tree_mutations != null
		and passive_tree_view_model != null
	)


func _fail_city_route(origin: StringName, return_focus: Control, status_text: String) -> void:
	_city_tree_origin = &""
	_city_tree_return_focus = null
	if origin == CITY_ORIGIN_ADDITIONAL_SETTINGS:
		var settings := get_node("SettingsScreen") as SettingsScreen
		settings.open_additional(return_focus)
		settings.show_route_status(status_text, return_focus)
		return
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	menu.open(return_focus)
	(menu.get_node("Status") as Label).text = status_text
	_focus_control_if_available(return_focus)


func _focus_control_if_available(control: Control) -> void:
	if control != null and is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
		control.grab_focus()


func _city_tree_is_open() -> bool:
	var screen := get_node_or_null("PassiveTreeScreen") as PassiveTreeScreen
	return screen != null and screen.is_open()


func _on_city_passive_tree_closed() -> void:
	var origin := _city_tree_origin
	var return_focus := _city_tree_return_focus
	_city_tree_origin = &""
	_city_tree_return_focus = null
	_refresh_main_menu_projection()
	if origin == CITY_ORIGIN_ADDITIONAL_SETTINGS:
		(get_node("SettingsScreen") as SettingsScreen).open_additional(return_focus)
		return
	if origin == CITY_ORIGIN_MAIN_MENU:
		(get_node("MainMenuScreen") as MainMenuScreen).open(return_focus)

func _on_settings_applied(settings: PartyForgeSettings) -> void:
	saved_settings = settings.copy()
	_refresh_main_menu_projection()

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
	var offer_seed := _level_up_offer_state.seed_for(
		game_run.run_seed,
		experience_system.current_pending_level(),
		party_manager.members.size()
	)
	var choices := LevelUpChoiceService.generate(
		party_manager,
		catalog,
		offer_seed,
		active_run_rules.level_up_card_count(),
		_level_up_offer_state
	)
	_level_up_offer_state.offer_sequence += 1
	get_node("HUD/LevelUpPanel").call(
		"show_choices",
		choices,
		party_manager,
		_invalid_choice_keys(choices),
		experience_system.pending_levels
	)

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
