class_name PartyForgeMain
extends Node

const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/forge_guardian.tscn")
const HEALTH_BAR_SCENE := preload("res://scenes/ui/health_bar_3d.tscn")
const HUDScript := preload("res://scripts/ui/hud.gd")
const LevelUpPanelScript := preload("res://scripts/ui/level_up_panel.gd")
const RunResultPanelScript := preload("res://scripts/ui/run_result_panel.gd")
const LoadoutWarningDialogScript := preload("res://scripts/ui/loadout_warning/loadout_warning_dialog.gd")
const REWARD_DISTRIBUTION_TUNING: RewardDistributionTuning = preload("res://data/progression/reward_distribution.tres")
const PERSONAL_LOOT_TUNING: PersonalLootTuning = preload("res://data/items/personal_loot_tuning.tres")
const GROUND_ITEM_SPATIAL_INDEX := preload("res://scripts/loot/ground_item_spatial_index.gd")
const GROUND_ITEM_TARGETING_SERVICE := preload("res://scripts/loot/ground_item_targeting_service.gd")
const GROUND_ITEM_PICKUP_SERVICE := preload("res://scripts/loot/ground_item_pickup_service.gd")
const RUN_SEED := 1337
const CURRENT_STARTING_PARTY_SIZE := 1
const LEDGER_FEATURE_IDS: Array[StringName] = [&"stats", &"current_upgrades", &"equipment_inventory"]
const LEDGER_UNLOCK_IDS: Array[StringName] = [&"equipment_inventory"]
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
const ITEM_SANDBOX_DEVELOPER_REQUIRED_STATUS := "Save Developer Mode before opening the Developer Item Sandbox."

enum LoadoutOrigin { RUN_SETUP, DEVELOPER_QUICK_START }

var party_stats: Dictionary = {}
var trait_upgrade_ranks: Dictionary = {}
var catalog: GameCatalog
var party_manager: PartyManager
var combat_resolution_service: Node
var experience_system: ExperienceSystem
var run_context_registry: RunContextRegistry
var active_run_context: PlayerRunContext
var reward_distribution_service: RewardDistributionService
var reward_distribution_tuning: RewardDistributionTuning
var personal_loot_roll_service: PersonalLootRollService
var personal_loot_drop_coordinator: PersonalLootDropCoordinator
var personal_loot_tuning_source: PersonalLootTuning = PERSONAL_LOOT_TUNING
var ground_item_registry: GroundItemRegistry
var ground_item_world_controller: Node
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
var settings_path := PartyForgeSettingsStore.DEFAULT_PATH
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
var _shared_storage_projection: ProfileStorageProjection
var _profile_loadout_assignments := ProfileLoadoutAssignmentService.new()
var _profile_item_storage := ProfileItemStorageService.new()
var _storage_transaction_sequence := 0
var _storage_return_focus: Control
var _loadout_compatibility := LoadoutCompatibilityService.new()
var _loadout_transitions := LoadoutTransitionService.new()
var _loadout_checkout := RunLoadoutCheckoutService.new()
var _pending_checkout_recovery: Dictionary = {}
var _run_context_factory: Callable = func() -> PlayerRunContext: return PlayerRunContext.new()
var _pending_loadout_projection: LoadoutCompatibilityProjection
var _pending_loadout_profile_id := ""
var _pending_loadout_class_id: StringName
var _pending_loadout_origin := LoadoutOrigin.RUN_SETUP
var _loadout_transaction_sequence := 0
var _armoury_from_loadout_warning := false
var _armoury_warning_class_id: StringName
var _armoury_warning_origin: Control
var _armoury_warning_origin_mode := LoadoutOrigin.RUN_SETUP
var _ground_chest_diagnostics: Dictionary = {}

func _ready() -> void:
	if initialized:
		return
	initialized = true
	_cache_nodes()
	settings_store = PartyForgeSettingsStore.new()
	saved_settings = settings_store.load_settings(settings_path)
	profile_manager = ProfileManager.new()
	profile_bootstrap_error = profile_manager.bootstrap(profile_root)
	if not profile_bootstrap_error.is_empty():
		push_error(profile_bootstrap_error)
	var settings_screen := get_node("SettingsScreen") as SettingsScreen
	settings_screen.configure(settings_store, saved_settings, profile_manager, settings_path)
	_expose_profile_bootstrap_diagnostic()
	catalog = GameCatalog.load_defaults()
	catalog_valid = _validate_catalog(catalog)
	_load_passive_tree_runtime()
	_wire_static_ui()
	_present_front_end()
	print("PARTY_FORGE_BOOT_OK")
	print("PARTY_FORGE_CLASS_SELECTION_READY")

func select_leader_class(class_id: StringName) -> bool:
	return _select_leader_class(class_id, LoadoutOrigin.RUN_SETUP)


func _select_leader_class(class_id: StringName, origin_mode: LoadoutOrigin) -> bool:
	if not initialized:
		_ready()
	if profile_manager == null or profile_manager.active_profile() == null:
		push_error("PARTY_FORGE_RUN_PROFILE_REQUIRED")
		_open_profiles_from_main_menu()
		return false
	if run_started or catalog == null or not catalog_valid or _pending_loadout_projection != null:
		return false
	catalog_valid = _validate_catalog(catalog, false)
	if not catalog_valid:
		return false
	var definition := catalog.class_by_id(class_id)
	if definition == null:
		push_error(format_resource_error("res://data/classes", "unknown leader class %s" % class_id))
		return false
	var profile := profile_manager.active_profile()
	var refresh_error := profile_manager.refresh_profile(profile.profile_id)
	if not refresh_error.is_empty():
		_show_run_setup_error(refresh_error)
		return false
	profile = profile_manager.active_profile()
	if profile == null:
		_show_run_setup_error("PARTY_FORGE_RUN_PROFILE_REQUIRED")
		return false
	definition = catalog.class_by_id(class_id)
	if definition == null:
		return false
	if not _pending_checkout_recovery.is_empty():
		return _resume_pending_checkout(profile, definition)
	var projection := _project_loadout_compatibility(profile, class_id)
	if projection == null or not projection.valid:
		_show_run_setup_error(projection.error if projection != null else "PARTY_FORGE_LOADOUT_COMPATIBILITY_ERROR field=projection reason=unavailable")
		return false
	if not projection.incompatible_items.is_empty():
		_pending_loadout_projection = projection
		_pending_loadout_profile_id = profile.profile_id
		_pending_loadout_class_id = class_id
		_pending_loadout_origin = origin_mode
		var origin: Control
		if origin_mode == LoadoutOrigin.DEVELOPER_QUICK_START:
			origin = (get_node("MainMenuScreen") as MainMenuScreen).get_node("DeveloperQuickStart") as Control
		else:
			origin = (get_node("HUD/ClassSelection") as ClassSelectionPanel).begin_compatibility_gate(class_id)
		if not get_node("LoadoutWarningDialog").call("open", projection, origin):
			_clear_pending_loadout_warning(true)
		return false
	return _checkout_and_start_leader_class(profile, definition, origin_mode)


func _project_loadout_compatibility(profile: ProfileState, class_id: StringName) -> LoadoutCompatibilityProjection:
	var definition := catalog.class_by_id(class_id) if catalog != null else null
	return _loadout_compatibility.project(profile, definition, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)


func _checkout_and_start_leader_class(profile: ProfileState, definition: ClassDefinition, origin_mode := LoadoutOrigin.RUN_SETUP) -> bool:
	if profile == null or definition == null or profile.profile_id != active_profile().profile_id:
		_show_run_setup_error("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=profile_id reason=active profile changed")
		return false
	if not _prepare_run_start(definition):
		return false
	_loadout_transaction_sequence += 1
	var leader_member_id := party_manager.members[0].member_id
	var unique := "%d-%d" % [Time.get_ticks_usec(), _loadout_transaction_sequence]
	var run_id := StringName("run-%s-%s" % [profile.profile_id, unique])
	var request := RunLoadoutCheckoutRequest.create(
		"run-checkout-%s" % unique,
		profile.profile_id,
		run_id,
		game_run.run_seed,
		&"player_1",
		leader_member_id,
		definition.id,
		"bring_in_gear" in profile.permanent_feature_unlocks,
	)
	var result := _loadout_checkout.checkout(profile.profile_id, request, profile_root)
	if not result.ok():
		_show_loadout_origin_error(result.error, origin_mode, definition.id)
		return false
	_pending_checkout_recovery = {
		"profile_id": profile.profile_id,
		"class_id": String(definition.id),
		"run_id": String(run_id),
		"run_seed": game_run.run_seed,
		"run_player_id": String(request.run_player_id),
		"leader_member_id": leader_member_id,
		"resumable_run": result.profile.resumable_run.duplicate(true),
		"origin_mode": origin_mode,
	}
	var refresh_error := profile_manager.refresh_profile(profile.profile_id)
	if not refresh_error.is_empty():
		_show_run_setup_error(refresh_error)
		return false
	return _resume_pending_checkout(profile_manager.active_profile(), definition)


func _prepare_run_start(definition: ClassDefinition) -> bool:
	if definition == null:
		_show_run_setup_error("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=class reason=unavailable")
		return false
	active_run_rules = RunRulesSnapshot.from_settings(saved_settings)
	_level_up_offer_state = LevelUpOfferState.new()
	(get_node("HUD/LevelUpPanel") as LevelUpPanel).configure_reduced_motion(active_run_rules.reduced_motion())
	experience_system.configure_multiplier(active_run_rules.experience_multiplier_percent())
	party_manager.configure_capacity(active_run_rules.capacity_policy())
	if CURRENT_STARTING_PARTY_SIZE > active_run_rules.party_capacity():
		push_error("PARTY_FORGE_STARTING_PARTY_CAPACITY_ERROR selected=%d capacity=%d" % [CURRENT_STARTING_PARTY_SIZE, active_run_rules.party_capacity()])
		return false
	game_run.configure_seed(RUN_SEED)
	var combat_configuration_errors: PackedStringArray = combat_resolution_service.call("configure", game_run.combat_rng, catalog.damage_types) as PackedStringArray
	if not combat_configuration_errors.is_empty():
		_show_run_setup_error(combat_configuration_errors[0])
		return false
	party_manager.configure_identity(game_run.run_seed, catalog.generic_name_pool)
	party_manager.initialize(definition, catalog.traits)
	party_manager.configure_combat(game_run.combat_rng, catalog.damage_types, combat_resolution_service)
	if party_manager.members.is_empty():
		_show_run_setup_error("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=leader reason=party initialization failed")
		return false
	return true


func _resume_pending_checkout(committed_profile: ProfileState, definition: ClassDefinition) -> bool:
	if _pending_checkout_recovery.is_empty():
		return false
	var expected_profile_id := String(_pending_checkout_recovery.get("profile_id", ""))
	var expected_class_id := StringName(_pending_checkout_recovery.get("class_id", ""))
	if committed_profile == null or committed_profile.profile_id != expected_profile_id:
		_show_run_setup_error("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=profile_id reason=committed recovery profile mismatch")
		return false
	if definition == null or definition.id != expected_class_id:
		_show_run_setup_error("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=selected_leader_class_id reason=committed recovery class mismatch")
		return false
	var expected_document := _pending_checkout_recovery.get("resumable_run", {}) as Dictionary
	if expected_document.is_empty() or committed_profile.resumable_run != expected_document:
		_show_run_setup_error("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=bootstrap reason=committed bootstrap mismatch")
		return false
	var bootstrap := _loadout_checkout.bootstrap_from(committed_profile)
	if (
		bootstrap == null
		or String(bootstrap.run_id) != String(_pending_checkout_recovery.get("run_id", ""))
		or bootstrap.run_seed != int(_pending_checkout_recovery.get("run_seed", 0))
		or String(bootstrap.run_player_id) != String(_pending_checkout_recovery.get("run_player_id", ""))
		or bootstrap.leader_member_id != int(_pending_checkout_recovery.get("leader_member_id", 0))
	):
		_show_run_setup_error("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=bootstrap reason=committed bootstrap unavailable or mismatched")
		return false
	var canonical_bootstrap := ResumableRunItemCodec.encode(bootstrap)
	if canonical_bootstrap.is_empty():
		_show_run_setup_error("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=bootstrap reason=committed bootstrap canonicalization failed")
		return false
	committed_profile.resumable_run = canonical_bootstrap.duplicate(true)
	if not _prepare_run_start(definition):
		return false
	if party_manager.members.is_empty() or party_manager.members[0].member_id != bootstrap.leader_member_id:
		_show_run_setup_error("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=leader_member_id reason=committed bootstrap mismatch")
		return false
	return _start_leader_class_from_checkout(definition, committed_profile, bootstrap)


func _start_leader_class_from_checkout(definition: ClassDefinition, committed_profile: ProfileState, bootstrap: RunItemBootstrap) -> bool:
	(get_node("DeveloperItemSandbox") as DeveloperItemSandbox).cancel_and_clear()
	var settings_screen := get_node("SettingsScreen") as SettingsScreen
	if settings_screen.is_open():
		settings_screen.close()
	run_context_registry = RunContextRegistry.new()
	active_run_context = _run_context_factory.call() as PlayerRunContext
	if active_run_context == null:
		return _abort_run_start(PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=factory reason=context unavailable"]))
	var context_errors := active_run_context.configure(
		&"player_1",
		0,
		committed_profile,
		game_run.run_seed,
		party_manager,
		active_run_rules.experience_multiplier_percent(),
		bootstrap,
		active_run_rules.run_inventory_minimum_capacity(),
	)
	if not context_errors.is_empty():
		return _abort_run_start(context_errors)
	var registration := run_context_registry.register_context(active_run_context, -1)
	if not registration.ok():
		return _abort_run_start(PackedStringArray([registration.message]))
	run_context_registry.lock_arena_roster()
	party_manager = active_run_context.party
	var leader_member_id := bootstrap.leader_member_id
	experience_system.configure_context(active_run_context, leader_member_id)
	leader = LEADER_SCENE.instantiate() as PartyActor
	get_node("Actors").add_child(leader)
	var spawn := get_node("Arena/PlayerSpawn") as Marker3D
	leader.position = spawn.position
	leader.configure(party_manager.members[0])
	var combat_policy := active_run_rules.combat_policy()
	leader.configure_combat(party_manager, get_node("Effects"))
	leader.configure_combat_policy(combat_policy)
	_attach_health_bar(leader)
	if not active_run_context.bind_actor(leader_member_id, leader):
		return _abort_run_start(PackedStringArray([
			PartyActorSpawner.format_actor_bind_error(leader_member_id),
		]), leader)
	party_actor_spawner.initialize(party_manager, get_node("Actors") as Node3D, leader, get_node("Effects"), combat_policy, active_run_context)
	reward_distribution_tuning = REWARD_DISTRIBUTION_TUNING
	reward_distribution_service = RewardDistributionService.new()
	var reward_errors := reward_distribution_service.configure(run_context_registry, reward_distribution_tuning)
	if not reward_errors.is_empty():
		return _abort_run_start(reward_errors, leader)
	developer_mode_badge.configure(active_run_rules, reward_distribution_tuning)
	var personal_loot_errors := _configure_personal_loot()
	if not personal_loot_errors.is_empty():
		return _abort_run_start(personal_loot_errors, leader)
	var camera_rig := get_node("LeaderCamera") as LeaderCamera
	camera_rig.target = leader
	var markers := _spawn_markers()
	var camera := camera_rig.get_node("Camera3D") as Camera3D
	spawn_director.configure(RUN_SEED, leader, reward_distribution_service, markers, camera, get_node("Enemies"), get_node("Effects"), _pickup_multiplier(), game_run.combat_rng, catalog.damage_types, active_run_rules.enemy_density_percent(), combat_resolution_service)
	var defeat_callback := Callable(self, "_on_enemy_defeated_for_personal_loot")
	if not spawn_director.enemy_defeated.is_connected(defeat_callback):
		spawn_director.enemy_defeated.connect(defeat_callback)
	spawn_director.process_mode = Node.PROCESS_MODE_INHERIT
	hud.call("configure", game_run, party_manager, experience_system)
	hud.call("set_leader", leader)
	var health := leader.get_node("HealthComponent") as HealthComponent
	if not health.died.is_connected(game_run.leader_defeated): health.died.connect(game_run.leader_defeated)
	if not experience_system.level_ready.is_connected(_on_level_ready): experience_system.level_ready.connect(_on_level_ready)
	if not spawn_director.enemy_spawned.is_connected(_on_enemy_spawned): spawn_director.enemy_spawned.connect(_on_enemy_spawned)
	run_started = true
	character_ledger.configure(
		game_run,
		party_manager,
		catalog,
		Callable(self, "_ledger_health_for_member"),
		[],
		active_run_rules.feature_policy(LEDGER_FEATURE_IDS, LEDGER_UNLOCK_IDS, _profile_unlock_ids(active_run_context.profile_snapshot)),
		Callable(active_run_context, "progression_for"),
		active_run_context,
	)
	game_run.start_run()
	(get_node("MainMenuScreen") as MainMenuScreen).close()
	_clear_pending_loadout_warning(false)
	(get_node("HUD/ClassSelection") as ClassSelectionPanel).confirm_run_started()
	_pending_checkout_recovery = {}
	return true

func _abort_run_start(diagnostics: PackedStringArray, spawned_leader: PartyActor = null) -> bool:
	_clear_live_loot()
	if spawned_leader != null and is_instance_valid(spawned_leader):
		spawned_leader.free()
	if leader == spawned_leader:
		leader = null
	party_actor_spawner.initialize(null, null, null)
	experience_system.configure_context(null, 0)
	if active_run_context != null and active_run_context.party != null:
		var member_callback := Callable(active_run_context, "_on_member_added")
		if active_run_context.party.member_added.is_connected(member_callback):
			active_run_context.party.member_added.disconnect(member_callback)
	if run_context_registry != null:
		run_context_registry.clear()
	active_run_context = null
	reward_distribution_service = null
	reward_distribution_tuning = null
	run_started = false
	developer_mode_badge.configure(null)
	if _pending_checkout_recovery.is_empty():
		_present_front_end()
	for diagnostic: String in diagnostics:
		push_error(diagnostic)
	if not _pending_checkout_recovery.is_empty():
		_show_checkout_recovery_error(" | ".join(diagnostics))
	return false

func _configure_personal_loot() -> PackedStringArray:
	var errors := PackedStringArray()
	var identity_assignment := LocalPlayerIdentityService.new().assign(run_context_registry.all_contexts())
	if not identity_assignment.ok():
		errors.append(identity_assignment.error)
		return errors
	personal_loot_roll_service = PersonalLootRollService.new()
	var run_tuning := personal_loot_tuning_source.duplicate(true) as PersonalLootTuning if personal_loot_tuning_source != null else null
	errors.append_array(personal_loot_roll_service.configure(
		run_context_registry,
		reward_distribution_tuning,
		run_tuning,
		Callable(self, "_personal_loot_access_for"),
		active_run_rules.force_personal_drops(),
		float(active_run_rules.personal_drop_multiplier_percent()) / 100.0,
		active_run_rules.personal_drop_source_category_override(),
		active_run_rules.personal_drop_item_level_override(),
		&"normal",
		0.0,
	))
	if not errors.is_empty():
		return errors
	ground_item_registry = GroundItemRegistry.new()
	personal_loot_drop_coordinator = PersonalLootDropCoordinator.new()
	errors.append_array(personal_loot_drop_coordinator.configure(
		personal_loot_roll_service,
		run_context_registry,
		identity_assignment.identities(),
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		ground_item_registry,
		personal_loot_roll_service.difficulty_id,
		personal_loot_roll_service.heat,
	))
	if not errors.is_empty():
		return errors
	_reset_ground_chest_diagnostics()
	ground_item_registry.record_added.connect(_on_ground_record_added)
	ground_item_registry.record_removed.connect(_on_ground_record_removed)
	ground_item_registry.cleared.connect(_on_ground_registry_cleared)
	if ground_item_world_controller == null:
		errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=world_controller")
		return errors
	var camera := (get_node("LeaderCamera") as LeaderCamera).get_node("Camera3D") as Camera3D
	if not ground_item_world_controller.status_changed.is_connected(_on_ground_item_status_changed):
		ground_item_world_controller.status_changed.connect(_on_ground_item_status_changed)
	if not ground_item_world_controller.pickup_feedback.is_connected(_on_ground_item_pickup_feedback):
		ground_item_world_controller.pickup_feedback.connect(_on_ground_item_pickup_feedback)
	if not ground_item_world_controller.projection_diagnostics_changed.is_connected(_on_ground_projection_diagnostics_changed):
		ground_item_world_controller.projection_diagnostics_changed.connect(_on_ground_projection_diagnostics_changed)
	ground_item_world_controller.call(&"configure", ground_item_registry, identity_assignment.identities(), Callable(self, "_ground_item_detail"), camera, get_node("GroundItems") as Node3D, get_node("GroundItemTooltipLayer"))
	ground_item_world_controller.call(&"configure_comparisons", Callable(self, "_ground_item_comparison_entries"))
	ground_item_world_controller.call(&"configure_interaction",
		GROUND_ITEM_SPATIAL_INDEX.new(ground_item_registry),
		GROUND_ITEM_TARGETING_SERVICE.new(),
		GROUND_ITEM_PICKUP_SERVICE.new(ground_item_registry, run_context_registry, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, run_tuning.pickup_interaction_radius),
		run_context_registry,
		run_tuning.controller_target_query_radius,
		Callable(),
		Callable(self, "_gameplay_input_blocked"),
	)
	return errors

func _on_enemy_defeated_for_personal_loot(event: EnemyDefeatEvent) -> void:
	if personal_loot_drop_coordinator == null:
		return
	_record_personal_loot_report(personal_loot_drop_coordinator.resolve_defeat(event))

func _record_personal_loot_report(report: Dictionary) -> void:
	for decision: PersonalLootDecision in report.get("decisions", []) as Array:
		if decision == null:
			continue
		var source := String(decision.source_category)
		if decision.success:
			_increment_diagnostic_bucket("successes_by_source", source)
		elif decision.eligible:
			_increment_diagnostic_bucket("misses_by_source", source)
		else:
			_ground_chest_diagnostics["ineligible_total"] = int(_ground_chest_diagnostics.get("ineligible_total", 0)) + 1
			_increment_diagnostic_bucket("ineligible_by_reason", String(decision.reason))
			_increment_diagnostic_bucket("ineligible_by_source", source)
	for value: Variant in report.get("diagnostics", []) as Array:
		var diagnostic := value as Dictionary
		var stage := String(diagnostic.get("stage", &"configuration")) if diagnostic != null else "configuration"
		var code := String(diagnostic.get("code", &"legacy_untyped")) if diagnostic != null else "legacy_untyped"
		var stages := _ground_chest_diagnostics.get("diagnostics_by_stage", {}) as Dictionary
		stages[stage] = int(stages.get(stage, 0)) + 1
		_ground_chest_diagnostics["diagnostics_by_stage"] = stages
		var codes := _ground_chest_diagnostics.get("diagnostics_by_code", {}) as Dictionary
		codes[code] = int(codes.get(code, 0)) + 1
		_ground_chest_diagnostics["diagnostics_by_code"] = codes
		if stage == "generation":
			_ground_chest_diagnostics["generation_failures"] = int(_ground_chest_diagnostics.get("generation_failures", 0)) + 1
	_sync_ground_chest_diagnostics()

func _increment_diagnostic_bucket(bucket_name: String, key: String) -> void:
	var bucket := _ground_chest_diagnostics.get(bucket_name, {}) as Dictionary
	bucket[key] = int(bucket.get(key, 0)) + 1
	_ground_chest_diagnostics[bucket_name] = bucket

func _on_ground_record_added(_record: GroundItemRecord) -> void:
	var live := ground_item_registry.all_records().size() if ground_item_registry != null else 0
	_ground_chest_diagnostics["live"] = live
	_ground_chest_diagnostics["peak"] = maxi(int(_ground_chest_diagnostics.get("peak", 0)), live)
	_sync_ground_chest_diagnostics()

func _on_ground_record_removed(_record: GroundItemRecord) -> void:
	_ground_chest_diagnostics["live"] = ground_item_registry.all_records().size() if ground_item_registry != null else 0
	_sync_ground_chest_diagnostics()

func _on_ground_registry_cleared() -> void:
	_ground_chest_diagnostics["live"] = 0
	_sync_ground_chest_diagnostics()

func _on_ground_item_status_changed(status: String) -> void:
	var outcome := ""
	match status:
		"GROUND_ITEM_PICKUP_OK": outcome = "ok"
		"GROUND_ITEM_PICKUP_NOT_OWNER": outcome = "not_owner"
		"GROUND_ITEM_PICKUP_MISSING": outcome = "missing"
		"GROUND_ITEM_PICKUP_TRANSACTION_REJECTED": outcome = "transaction_rejected"
		"GROUND_ITEM_PICKUP_INVENTORY_FULL", "Inventory full": outcome = "inventory_full"
		"Move closer": outcome = "move_closer"
	if outcome.is_empty():
		return
	var outcomes := _ground_chest_diagnostics.get("collection_outcomes", {}) as Dictionary
	outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
	_ground_chest_diagnostics["collection_outcomes"] = outcomes
	_sync_ground_chest_diagnostics()

func _on_ground_item_pickup_feedback(result: GroundItemPickupResult) -> void:
	if result == null or result.message.strip_edges().is_empty() or hud == null:
		return
	hud.call(&"show_loot_status", result.message)

func _on_ground_projection_diagnostics_changed(diagnostics: Dictionary) -> void:
	if _ground_chest_diagnostics.is_empty():
		return
	var next_pending := int(diagnostics.get("pending", 0))
	var next_last := int(diagnostics.get("last_frame_work", 0))
	var next_peak := maxi(int(_ground_chest_diagnostics.get("projection_peak_work", 0)), int(diagnostics.get("peak_work", 0)))
	var next_limit := int(diagnostics.get("limit", 0))
	if (
		next_pending == int(_ground_chest_diagnostics.get("projection_pending", 0))
		and next_last == int(_ground_chest_diagnostics.get("projection_last_work", 0))
		and next_peak == int(_ground_chest_diagnostics.get("projection_peak_work", 0))
		and next_limit == int(_ground_chest_diagnostics.get("projection_limit", 0))
	):
		return
	_ground_chest_diagnostics["projection_pending"] = next_pending
	_ground_chest_diagnostics["projection_last_work"] = next_last
	_ground_chest_diagnostics["projection_peak_work"] = next_peak
	_ground_chest_diagnostics["projection_limit"] = next_limit
	_sync_ground_chest_diagnostics()

func _reset_ground_chest_diagnostics() -> void:
	_ground_chest_diagnostics = {
		"live": 0,
		"peak": 0,
		"successes_by_source": {},
		"misses_by_source": {},
		"ineligible_total": 0,
		"ineligible_by_reason": {},
		"ineligible_by_source": {},
		"generation_failures": 0,
		"diagnostics_by_stage": {},
		"diagnostics_by_code": {},
		"collection_outcomes": {},
		"projection_pending": 0,
		"projection_last_work": 0,
		"projection_peak_work": 0,
		"projection_limit": 0,
	}
	_sync_ground_chest_diagnostics()

func _sync_ground_chest_diagnostics() -> void:
	if developer_mode_badge != null:
		developer_mode_badge.update_ground_chest_diagnostics(_ground_chest_diagnostics)

func _ground_item_detail(record: GroundItemRecord) -> Dictionary:
	if record == null or run_context_registry == null:
		return {}
	var context := run_context_registry.context_for(record.run_player_id)
	var state := context.item_state() if context != null else null
	var item_registry := state.registry() if state != null else null
	var item := item_registry.item(record.item_id) if item_registry != null else null
	var class_definition: ClassDefinition
	if context != null and context.party != null and not context.party.members.is_empty():
		class_definition = context.party.members[0].class_definition
	return ItemPresentationProjector.project(item, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, class_definition)

func _ground_item_comparison_entries(record: GroundItemRecord, detail: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if record == null or run_context_registry == null:
		return result
	var context := run_context_registry.context_for(record.run_player_id)
	if context == null or context.party == null:
		return result
	var leader_id := 0
	var leader_class: ClassDefinition
	for member: PartyMemberState in context.party.members:
		if member != null and member.is_leader:
			leader_id = member.member_id
			leader_class = member.class_definition
			break
	if leader_id <= 0:
		return result
	var staged_state := _comparison_state_with_candidate_in_inventory(context, record)
	if staged_state == null:
		return result
	var current_stats := context.party.stats_for(leader_id)
	var equipment_container := context.equipment_for(leader_id)
	var registry := context.item_state().registry()
	if current_stats == null or equipment_container == null or registry == null:
		return result
	for slot_value: Variant in detail.get("compatible_slot_ids", []):
		var slot_id := StringName(slot_value)
		var slot_index := EquipmentSlotIndex.index_for(slot_id)
		if slot_index < 0:
			continue
		var equipped_item_id := equipment_container.item_id_at(slot_index)
		var equipped_item := registry.item(equipped_item_id)
		if equipped_item == null:
			continue
		var preview := EquipmentTransitionService.preview(
			staged_state,
			leader_id,
			record.item_id,
			slot_id,
			context.party,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
		)
		if not preview.ok():
			continue
		result.append({
			"slot_id": String(slot_id),
			"item": ItemPresentationProjector.project(equipped_item, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, leader_class),
			"current_stats": current_stats,
			"candidate_stats": preview.resolution().final_stats,
		})
	return result

func _comparison_state_with_candidate_in_inventory(context: PlayerRunContext, record: GroundItemRecord) -> ItemOwnershipState:
	var state := context.item_state() if context != null else null
	var ground := state.container(ItemSlotContainer.RUN_GROUND_ITEMS_ID) if state != null else null
	var inventory := state.container(&"run-inventory") if state != null else null
	if ground == null or inventory == null or ground.item_id_at(record.ground_slot) != record.item_id or inventory.capacity <= 0:
		return null
	var destination_slot := inventory.first_empty_slot()
	var operation := ItemTransactionRequest.MOVE_TO_EMPTY
	if destination_slot < 0:
		destination_slot = 0
		operation = ItemTransactionRequest.SWAP_OCCUPIED
	var request := ItemTransactionRequest.move(
		"world-comparison:%s" % record.drop_id,
		String(record.run_player_id),
		ItemSlotContainer.RUN_GROUND_ITEMS_ID,
		record.ground_slot,
		record.item_id,
		&"run-inventory",
		destination_slot,
	) if operation == ItemTransactionRequest.MOVE_TO_EMPTY else ItemTransactionRequest.swap(
		"world-comparison:%s" % record.drop_id,
		String(record.run_player_id),
		ItemSlotContainer.RUN_GROUND_ITEMS_ID,
		record.ground_slot,
		record.item_id,
		&"run-inventory",
		destination_slot,
	)
	var transaction := ItemContainerTransactionService.new().apply(state, request, ItemTransactionJournal.new(), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	return transaction.next_state if transaction.ok() else null

func _gameplay_input_blocked() -> bool:
	if not run_started or game_run == null or game_run.current_state() not in [RunStateMachine.State.RUNNING, RunStateMachine.State.BOSS]:
		return true
	if character_ledger != null and character_ledger.is_open():
		return true
	if run_pause_menu != null and run_pause_menu.is_open():
		return true
	for path: NodePath in [
		^"SettingsScreen",
		^"ArmouryScreen",
		^"WarehouseScreen",
		^"PassiveTreeScreen",
		^"DeveloperItemSandbox",
		^"LoadoutWarningDialog",
	]:
		var modal := get_node_or_null(path)
		if modal != null and modal.has_method(&"is_open") and bool(modal.call(&"is_open")):
			return true
	return false

func _ground_item_modal_open() -> bool:
	return _gameplay_input_blocked()

func _clear_live_loot() -> void:
	var defeat_callback := Callable(self, "_on_enemy_defeated_for_personal_loot")
	if spawn_director != null and spawn_director.enemy_defeated.is_connected(defeat_callback):
		spawn_director.enemy_defeated.disconnect(defeat_callback)
	if ground_item_world_controller != null:
		if ground_item_world_controller.projection_diagnostics_changed.is_connected(_on_ground_projection_diagnostics_changed):
			ground_item_world_controller.projection_diagnostics_changed.disconnect(_on_ground_projection_diagnostics_changed)
		if ground_item_world_controller.status_changed.is_connected(_on_ground_item_status_changed):
			ground_item_world_controller.status_changed.disconnect(_on_ground_item_status_changed)
		if ground_item_world_controller.pickup_feedback.is_connected(_on_ground_item_pickup_feedback):
			ground_item_world_controller.pickup_feedback.disconnect(_on_ground_item_pickup_feedback)
		ground_item_world_controller.call(&"clear_projection")
	if ground_item_registry != null:
		if ground_item_registry.record_added.is_connected(_on_ground_record_added): ground_item_registry.record_added.disconnect(_on_ground_record_added)
		if ground_item_registry.record_removed.is_connected(_on_ground_record_removed): ground_item_registry.record_removed.disconnect(_on_ground_record_removed)
		if ground_item_registry.cleared.is_connected(_on_ground_registry_cleared): ground_item_registry.cleared.disconnect(_on_ground_registry_cleared)
		ground_item_registry.clear()
	personal_loot_drop_coordinator = null
	personal_loot_roll_service = null
	ground_item_registry = null
	_ground_chest_diagnostics.clear()
	_sync_ground_chest_diagnostics()

func _personal_loot_access_for(context: PlayerRunContext) -> bool:
	if context == null or active_run_rules == null:
		return false
	var profile := context.profile_snapshot
	if profile == null:
		return false
	var inventory := context.run_inventory()
	if inventory == null or inventory.capacity <= 0:
		return false
	var policy := active_run_rules.feature_policy(
		LEDGER_FEATURE_IDS,
		LEDGER_UNLOCK_IDS,
		_profile_unlock_ids(profile),
	)
	return policy.resolve(
		&"equipment_inventory",
		FeatureAccessPolicy.State.AVAILABLE,
		&"equipment_inventory",
	) == FeatureAccessPolicy.State.AVAILABLE

func _profile_unlock_ids(profile: ProfileState) -> Array[StringName]:
	var unlocked: Array[StringName] = []
	if profile == null:
		return unlocked
	for unlock_id: String in profile.permanent_feature_unlocks:
		unlocked.append(StringName(unlock_id))
	return unlocked

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
	combat_resolution_service = get_node("CombatResolutionService")
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
	ground_item_world_controller = get_node("GroundItemWorldController") as Node

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
	if not settings_screen.item_sandbox_requested.is_connected(_open_developer_item_sandbox):
		settings_screen.item_sandbox_requested.connect(_open_developer_item_sandbox)
	var item_sandbox := get_node("DeveloperItemSandbox") as DeveloperItemSandbox
	if not item_sandbox.closed.is_connected(_on_developer_item_sandbox_closed):
		item_sandbox.closed.connect(_on_developer_item_sandbox_closed)
	var passive_screen := get_node("PassiveTreeScreen") as PassiveTreeScreen
	if not passive_screen.tree_closed.is_connected(_on_city_passive_tree_closed):
		passive_screen.tree_closed.connect(_on_city_passive_tree_closed)
	var armoury := get_node("ArmouryScreen") as ArmouryScreen
	armoury.configure_classes(catalog.classes)
	if not armoury.close_requested.is_connected(_on_armoury_closed): armoury.close_requested.connect(_on_armoury_closed)
	if not armoury.equip_requested.is_connected(_on_armoury_equip_requested): armoury.equip_requested.connect(_on_armoury_equip_requested)
	if not armoury.move_requested.is_connected(_on_armoury_move_requested): armoury.move_requested.connect(_on_armoury_move_requested)
	var warehouse := get_node("WarehouseScreen") as WarehouseScreen
	if not warehouse.close_requested.is_connected(_on_warehouse_closed): warehouse.close_requested.connect(_on_warehouse_closed)
	if not warehouse.move_requested.is_connected(_on_warehouse_move_requested): warehouse.move_requested.connect(_on_warehouse_move_requested)
	var loadout_warning := get_node("LoadoutWarningDialog")
	if not loadout_warning.go_to_armoury.is_connected(_on_loadout_go_to_armoury): loadout_warning.go_to_armoury.connect(_on_loadout_go_to_armoury)
	if not loadout_warning.choose_another_class.is_connected(_on_loadout_choose_another_class): loadout_warning.choose_another_class.connect(_on_loadout_choose_another_class)
	if not loadout_warning.continue_anyway.is_connected(_on_loadout_continue_anyway): loadout_warning.continue_anyway.connect(_on_loadout_continue_anyway)
	if not loadout_warning.destroy_confirmed.is_connected(_on_loadout_destroy_confirmed): loadout_warning.destroy_confirmed.connect(_on_loadout_destroy_confirmed)
	if not loadout_warning.cancelled.is_connected(_on_loadout_cancelled): loadout_warning.cancelled.connect(_on_loadout_cancelled)
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
	var neutral_ledger_policy := RunRulesSnapshot.from_settings(PartyForgeSettings.new()).feature_policy(LEDGER_FEATURE_IDS, LEDGER_UNLOCK_IDS, _profile_unlock_ids(active_profile()))
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
		MainMenuViewModel.ROUTE_ARMOURY:
			_open_storage_route(MainMenuViewModel.ROUTE_ARMOURY)
		MainMenuViewModel.ROUTE_WAREHOUSE:
			_open_storage_route(MainMenuViewModel.ROUTE_WAREHOUSE)
		MainMenuViewModel.ROUTE_QUIT:
			_quit()


func _on_prologue_start_requested() -> void:
	_open_run_setup()


func _on_prologue_resume_requested() -> void:
	_open_run_setup()


func _on_developer_quick_start_requested() -> void:
	if not _developer_quick_start_surface_active():
		return
	var denial_status := _developer_quick_start_denial()
	if not denial_status.is_empty():
		_fail_developer_quick_start(denial_status)
		return
	if not _select_leader_class(&"fighter", LoadoutOrigin.DEVELOPER_QUICK_START):
		if _pending_loadout_projection != null and _pending_loadout_origin == LoadoutOrigin.DEVELOPER_QUICK_START:
			return
		_fail_developer_quick_start(DEVELOPER_QUICK_START_UNAVAILABLE_STATUS)


func _developer_quick_start_surface_active() -> bool:
	return (
		(get_node("MainMenuScreen") as MainMenuScreen).is_open()
		and not run_started
		and not (get_node("HUD/ClassSelection") as ClassSelectionPanel).is_open()
		and not (get_node("SettingsScreen") as SettingsScreen).is_open()
		and not _city_tree_is_open()
	)


func _developer_quick_start_denial() -> String:
	if saved_settings == null or saved_settings.mode != PartyForgeSettings.Mode.DEVELOPER_MODE:
		return DEVELOPER_QUICK_START_MODE_REQUIRED_STATUS
	var profile := profile_manager.active_profile() if profile_manager != null else null
	if profile == null or not ProfileCodec.validate_profile(profile).is_empty():
		return DEVELOPER_QUICK_START_PROFILE_REQUIRED_STATUS
	if catalog == null or not catalog_valid:
		return DEVELOPER_QUICK_START_UNAVAILABLE_STATUS
	catalog_valid = _validate_catalog(catalog, false)
	if not catalog_valid:
		return DEVELOPER_QUICK_START_UNAVAILABLE_STATUS
	if catalog.class_by_id(&"fighter") == null:
		return DEVELOPER_QUICK_START_UNAVAILABLE_STATUS
	return ""


func _fail_developer_quick_start(status_text: String) -> void:
	(get_node("HUD/ClassSelection") as ClassSelectionPanel).close()
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	var quick_start := menu.get_node("DeveloperQuickStart") as Control
	var return_focus := quick_start if quick_start.visible and not (quick_start as Button).disabled and quick_start.focus_mode != Control.FOCUS_NONE else menu.get_node("PrimaryAction") as Control
	menu.open(return_focus)
	(menu.get_node("Status") as Label).text = status_text
	_focus_control_if_available(return_focus)


func _open_run_setup() -> void:
	(get_node("MainMenuScreen") as MainMenuScreen).close()
	var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
	selector.clear_status()
	selector.open()


func _on_loadout_choose_another_class() -> void:
	if _pending_loadout_origin == LoadoutOrigin.DEVELOPER_QUICK_START:
		_clear_pending_loadout_warning(false)
		_open_run_setup()
		return
	_clear_pending_loadout_warning(true)


func _on_loadout_cancelled() -> void:
	_clear_pending_loadout_warning(true)


func _on_loadout_go_to_armoury() -> void:
	var warning := get_node("LoadoutWarningDialog")
	if _pending_loadout_projection == null or not warning.is_open():
		return
	var profile := profile_manager.active_profile() if profile_manager != null else null
	if profile == null or profile.profile_id != _pending_loadout_profile_id or not _storage_route_allowed(MainMenuViewModel.ROUTE_ARMOURY, profile):
		_show_run_setup_error("PARTY_FORGE_LOADOUT_WARNING_ERROR field=armoury reason=route unavailable")
		return
	var projection := _profile_storage_projection(profile)
	if not projection.valid:
		_show_run_setup_error(projection.error)
		return
	var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
	var origin_mode := _pending_loadout_origin
	var origin := (
		(get_node("MainMenuScreen") as MainMenuScreen).get_node("DeveloperQuickStart") as Control
		if origin_mode == LoadoutOrigin.DEVELOPER_QUICK_START
		else selector.selection_focus(_pending_loadout_class_id)
	)
	var display_class := _pending_loadout_class_id
	_clear_pending_loadout_warning(false)
	selector.close()
	_armoury_from_loadout_warning = true
	_armoury_warning_class_id = display_class
	_armoury_warning_origin = origin
	_armoury_warning_origin_mode = origin_mode
	_shared_storage_projection = projection
	_storage_return_focus = origin
	(get_node("MainMenuScreen") as MainMenuScreen).close()
	var armoury := get_node("ArmouryScreen") as ArmouryScreen
	armoury.open(projection, origin, _developer_mode_enabled())
	armoury.set_pending_run_class(display_class)


func _on_loadout_continue_anyway() -> void:
	var warning := get_node("LoadoutWarningDialog")
	if not warning.call("is_open") or warning.call("state") != LoadoutWarningDialogScript.State.INCOMPATIBLE:
		return
	if _pending_loadout_projection == null or not _pending_loadout_projection.overflow_item_ids.is_empty():
		return
	_submit_pending_loadout_transition(_pending_loadout_projection.confirmation_token)


func _on_loadout_destroy_confirmed(confirmation_token: String) -> void:
	var warning := get_node("LoadoutWarningDialog")
	if not warning.call("is_open") or warning.call("state") != LoadoutWarningDialogScript.State.DESTRUCTIVE_CONFIRMATION:
		return
	if not warning.call("consume_destroy_authorization", confirmation_token):
		return
	if _pending_loadout_projection == null or _pending_loadout_projection.overflow_item_ids.is_empty():
		return
	_submit_pending_loadout_transition(confirmation_token)


func _submit_pending_loadout_transition(confirmation_token: String = "") -> bool:
	var warning := get_node("LoadoutWarningDialog")
	if (
		_pending_loadout_projection == null
		or _pending_loadout_profile_id.is_empty()
		or _pending_loadout_class_id.is_empty()
		or not warning.call("is_open")
		or confirmation_token != _pending_loadout_projection.confirmation_token
	):
		return false
	var active := profile_manager.active_profile() if profile_manager != null else null
	if active == null or active.profile_id != _pending_loadout_profile_id:
		_show_run_setup_error("PARTY_FORGE_LOADOUT_TRANSITION_ERROR field=profile_id reason=active profile changed")
		return false
	var refresh_error := profile_manager.refresh_profile(active.profile_id)
	if not refresh_error.is_empty():
		_show_run_setup_error(refresh_error)
		return false
	active = profile_manager.active_profile()
	if active == null or active.profile_id != _pending_loadout_profile_id:
		return false
	var fresh := _project_loadout_compatibility(active, _pending_loadout_class_id)
	if not _projection_matches_pending(fresh):
		_show_run_setup_error("PARTY_FORGE_LOADOUT_TRANSITION_ERROR field=projection reason=selection or profile state changed")
		return false
	_loadout_transaction_sequence += 1
	var request := LoadoutTransitionRequest.create(
		"loadout-transition-%d-%d" % [Time.get_ticks_usec(), _loadout_transaction_sequence],
		active.profile_id,
		_pending_loadout_class_id,
		fresh.incompatible_sources(),
		fresh.planned_stash_destinations,
		fresh.overflow_item_ids,
		true,
		false,
		fresh.confirmation_token,
		fresh.state_fingerprint,
	)
	var result := _loadout_transitions.apply(active.profile_id, request, profile_root)
	if not result.ok():
		_show_run_setup_error(result.error)
		return false
	var committed_class_id := _pending_loadout_class_id
	var committed_origin := _pending_loadout_origin
	_clear_pending_loadout_warning(true)
	refresh_error = profile_manager.refresh_profile(active.profile_id)
	if not refresh_error.is_empty():
		_show_loadout_origin_error(refresh_error, committed_origin, committed_class_id)
		return false
	var transitioned := profile_manager.active_profile()
	var definition := catalog.class_by_id(committed_class_id) if catalog != null else null
	var reprojected := _project_loadout_compatibility(transitioned, committed_class_id)
	if definition == null or reprojected == null or not reprojected.valid or not reprojected.incompatible_items.is_empty():
		_show_loadout_origin_error("PARTY_FORGE_LOADOUT_TRANSITION_ERROR field=reprojection reason=transition did not produce a compatible loadout", committed_origin, committed_class_id)
		return false
	return _checkout_and_start_leader_class(transitioned, definition, committed_origin)


func _projection_matches_pending(fresh: LoadoutCompatibilityProjection) -> bool:
	return (
		fresh != null
		and fresh.valid
		and fresh.selected_class_id == _pending_loadout_class_id
		and fresh.confirmation_token == _pending_loadout_projection.confirmation_token
		and fresh.state_fingerprint == _pending_loadout_projection.state_fingerprint
		and fresh.incompatible_sources() == _pending_loadout_projection.incompatible_sources()
		and fresh.planned_stash_destinations == _pending_loadout_projection.planned_stash_destinations
		and fresh.overflow_item_ids == _pending_loadout_projection.overflow_item_ids
	)


func _clear_pending_loadout_warning(restore_focus: bool) -> void:
	var origin_mode := _pending_loadout_origin
	var warning := get_node_or_null("LoadoutWarningDialog")
	if warning != null and warning.call("is_open"):
		warning.call("close")
	_pending_loadout_projection = null
	_pending_loadout_profile_id = ""
	_pending_loadout_class_id = &""
	_pending_loadout_origin = LoadoutOrigin.RUN_SETUP
	var selector := get_node_or_null("HUD/ClassSelection") as ClassSelectionPanel
	if selector != null and origin_mode == LoadoutOrigin.RUN_SETUP:
		selector.end_compatibility_gate(restore_focus)
	elif selector != null and origin_mode == LoadoutOrigin.DEVELOPER_QUICK_START:
		selector.close()
		if restore_focus:
			var menu := get_node("MainMenuScreen") as MainMenuScreen
			var quick_start := menu.get_node("DeveloperQuickStart") as Control
			menu.open(quick_start)
			_focus_control_if_available(quick_start)


func _show_run_setup_error(message: String) -> void:
	push_error(message)
	var warning := get_node_or_null("LoadoutWarningDialog")
	if warning != null and warning.call("is_open"):
		warning.call("show_error", message)
	if not _pending_checkout_recovery.is_empty():
		_show_checkout_recovery_error(message)
		return
	var selector := get_node_or_null("HUD/ClassSelection") as ClassSelectionPanel
	if selector != null:
		selector.show_status("Unable to start run. %s" % message)


func _show_loadout_origin_error(message: String, origin_mode: int, class_id: StringName) -> void:
	if origin_mode == LoadoutOrigin.DEVELOPER_QUICK_START:
		push_error(message)
		var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
		selector.close()
		var menu := get_node("MainMenuScreen") as MainMenuScreen
		var quick_start := menu.get_node("DeveloperQuickStart") as Control
		menu.open(quick_start)
		(menu.get_node("Status") as Label).text = "Unable to start run. %s" % message
		_focus_control_if_available(quick_start)
		return
	_show_run_setup_error(message)
	var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
	if not selector.is_open():
		selector.open()
	selector.show_status("Unable to start run. %s" % message)
	var class_focus := selector.selection_focus(class_id)
	selector.set("_pending_initial_focus", class_focus)
	_focus_control_if_available(class_focus)


func _show_checkout_recovery_error(message: String) -> void:
	var origin_mode := int(_pending_checkout_recovery.get("origin_mode", LoadoutOrigin.RUN_SETUP))
	var class_id := StringName(_pending_checkout_recovery.get("class_id", ""))
	var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	if origin_mode == LoadoutOrigin.DEVELOPER_QUICK_START:
		selector.close()
		var quick_start := menu.get_node("DeveloperQuickStart") as Control
		menu.open(quick_start)
		(menu.get_node("Status") as Label).text = "Unable to start run. %s" % message
		_focus_control_if_available(quick_start)
		return
	menu.close()
	selector.open()
	selector.show_status("Unable to start run. %s" % message)
	var class_focus := selector.selection_focus(class_id)
	selector.set("_pending_initial_focus", class_focus)
	_focus_control_if_available(class_focus)


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
	(get_node("DeveloperItemSandbox") as DeveloperItemSandbox).close()
	(get_node("SettingsScreen") as SettingsScreen).close()
	(get_node("ArmouryScreen") as ArmouryScreen).close()
	(get_node("WarehouseScreen") as WarehouseScreen).close()
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


func _open_storage_route(route_id: StringName) -> void:
	var authoritative_settings := settings_store.load_settings(settings_path) if settings_store != null else PartyForgeSettings.new()
	saved_settings = authoritative_settings.copy()
	var profile := profile_manager.active_profile() if profile_manager != null else null
	if profile == null or not _storage_route_allowed(route_id, profile):
		return
	var projection := _profile_storage_projection(profile)
	if not projection.valid:
		push_error(projection.error)
		return
	_shared_storage_projection = projection
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	if route_id == MainMenuViewModel.ROUTE_ARMOURY:
		var origin := menu.route_origin()
		if origin == null: origin = menu.get_node("Armoury") as Control
		_storage_return_focus = origin
		menu.close()
		(get_node("ArmouryScreen") as ArmouryScreen).open(projection, origin, _developer_mode_enabled())
	else:
		var origin := menu.route_origin()
		if origin == null: origin = menu.get_node("Warehouse") as Control
		_storage_return_focus = origin
		menu.close()
		(get_node("WarehouseScreen") as WarehouseScreen).open(projection, origin, _developer_mode_enabled())


func _storage_route_allowed(route_id: StringName, profile: ProfileState) -> bool:
	if route_id not in [MainMenuViewModel.ROUTE_ARMOURY, MainMenuViewModel.ROUTE_WAREHOUSE] or profile == null:
		return false
	var projection := MainMenuViewModel.build(profile, saved_settings, _city_runtime_available())
	return projection.armoury_visible and projection.armoury_enabled if route_id == MainMenuViewModel.ROUTE_ARMOURY else projection.warehouse_visible and projection.warehouse_enabled


func _on_armoury_closed() -> void:
	var screen := get_node("ArmouryScreen") as ArmouryScreen
	screen.close()
	if _armoury_from_loadout_warning:
		var class_id := _armoury_warning_class_id
		var origin := _armoury_warning_origin
		var origin_mode := _armoury_warning_origin_mode
		_armoury_from_loadout_warning = false
		_armoury_warning_class_id = &""
		_armoury_warning_origin = null
		_armoury_warning_origin_mode = LoadoutOrigin.RUN_SETUP
		_storage_return_focus = null
		_shared_storage_projection = null
		var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
		if origin_mode == LoadoutOrigin.DEVELOPER_QUICK_START:
			selector.close()
			var menu := get_node("MainMenuScreen") as MainMenuScreen
			menu.open(origin)
			_focus_control_if_available(origin)
		else:
			selector.open()
			var class_focus := selector.selection_focus(class_id)
			_focus_control_if_available(class_focus if class_focus != null else origin)
		return
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	menu.open(_storage_return_focus if _storage_return_focus != null else menu.get_node("Armoury") as Control)
	_storage_return_focus = null


func _on_warehouse_closed() -> void:
	var screen := get_node("WarehouseScreen") as WarehouseScreen
	screen.close()
	var menu := get_node("MainMenuScreen") as MainMenuScreen
	menu.open(_storage_return_focus if _storage_return_focus != null else menu.get_node("Warehouse") as Control)
	_storage_return_focus = null


func _on_armoury_equip_requested(item_id: String, slot_id: StringName, class_id: StringName) -> void:
	_apply_armoury_assignment(item_id, &"leader-loadout", EquipmentSlotIndex.index_for(slot_id), class_id)


func _on_armoury_move_requested(item_id: String, destination_container_id: StringName, destination_slot: int) -> void:
	var profile := profile_manager.active_profile() if profile_manager != null else null
	var class_id := StringName(profile.leader_loadout_class_id) if profile != null else &""
	_apply_armoury_assignment(item_id, destination_container_id, destination_slot, class_id)


func _apply_armoury_assignment(item_id: String, destination_container_id: StringName, destination_slot: int, class_id: StringName) -> void:
	var profile := profile_manager.active_profile() if profile_manager != null else null
	if not _storage_projection_matches_profile(profile): return
	var source := _storage_item_location(_shared_storage_projection, item_id)
	var expected := _storage_item_at(_shared_storage_projection, destination_container_id, destination_slot)
	if source.is_empty(): return
	_storage_transaction_sequence += 1
	var request := ProfileLoadoutAssignmentRequest.create(
		"armoury-%d-%d" % [Time.get_ticks_usec(), _storage_transaction_sequence], profile.profile_id, class_id, item_id,
		StringName(source["container_id"]), int(source["slot"]), destination_container_id, destination_slot, expected,
		ProfileLoadoutAssignmentRequest.fingerprint_for(profile),
	)
	var result := _profile_loadout_assignments.apply(profile.profile_id, request, profile_root)
	if result.ok(): _reload_storage_projection(profile.profile_id)
	else: push_error(result.error)


func _on_warehouse_move_requested(item_id: String, destination_container_id: StringName, destination_slot: int) -> void:
	var profile := profile_manager.active_profile() if profile_manager != null else null
	if not _storage_projection_matches_profile(profile): return
	var source := _storage_item_location(_shared_storage_projection, item_id)
	if source.is_empty() or String(source["container_id"]) == "leader-loadout": return
	var occupied := _storage_item_at(_shared_storage_projection, destination_container_id, destination_slot)
	_storage_transaction_sequence += 1
	var transaction_id := "warehouse-%d-%d" % [Time.get_ticks_usec(), _storage_transaction_sequence]
	var request := ItemTransactionRequest.swap(transaction_id, profile.profile_id, StringName(source["container_id"]), int(source["slot"]), item_id, destination_container_id, destination_slot) if not occupied.is_empty() else ItemTransactionRequest.move(transaction_id, profile.profile_id, StringName(source["container_id"]), int(source["slot"]), item_id, destination_container_id, destination_slot)
	var result := _profile_item_storage.apply(profile.profile_id, request, profile_root)
	if result.ok(): _reload_storage_projection(profile.profile_id)
	else: push_error(result.error)


func _reload_storage_projection(profile_id: String) -> void:
	var error := profile_manager.refresh_profile(profile_id)
	if not error.is_empty(): push_error(error); return
	var profile := profile_manager.active_profile()
	var projection := _profile_storage_projection(profile)
	if not projection.valid: push_error(projection.error); return
	_shared_storage_projection = projection
	(get_node("ArmouryScreen") as ArmouryScreen).refresh(projection)
	(get_node("WarehouseScreen") as WarehouseScreen).refresh(projection)


func _profile_storage_projection(profile: ProfileState) -> ProfileStorageProjection:
	var class_definition := catalog.class_by_id(StringName(profile.leader_loadout_class_id)) if catalog != null and profile != null else null
	return ProfileStorageProjection.from_profile(
		profile,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		GameCatalog.STAT_CATALOG,
		class_definition,
	)


func _developer_mode_enabled() -> bool:
	return saved_settings != null and saved_settings.mode == PartyForgeSettings.Mode.DEVELOPER_MODE


func _storage_item_location(storage: ProfileStorageProjection, item_id: String) -> Dictionary:
	for entry: Dictionary in storage.leader_slots:
		if entry["instance_id"] == item_id: return {"container_id": "leader-loadout", "slot": entry["slot"]}
	for tab: Dictionary in storage.stash_tabs:
		for key: Variant in (tab["slots"] as Dictionary):
			if String((tab["slots"] as Dictionary)[key]) == item_id: return {"container_id": tab["container_id"], "slot": int(key)}
	return {}


func _storage_item_at(storage: ProfileStorageProjection, container_id: StringName, slot: int) -> String:
	if container_id == &"leader-loadout":
		return String(storage.leader_slots[slot]["instance_id"]) if slot >= 0 and slot < storage.leader_slots.size() else ""
	for tab: Dictionary in storage.stash_tabs:
		if String(tab["container_id"]) == String(container_id): return String((tab["slots"] as Dictionary).get(str(slot), (tab["slots"] as Dictionary).get(slot, "")))
	return ""


func _storage_projection_matches_profile(profile: ProfileState) -> bool:
	return (
		profile != null
		and _shared_storage_projection != null
		and _shared_storage_projection.valid
		and _shared_storage_projection.profile_id == profile.profile_id
	)


func _on_profiles_changed() -> void:
	_refresh_main_menu_projection()


func _on_active_profile_changed(_profile: ProfileState) -> void:
	(get_node("DeveloperItemSandbox") as DeveloperItemSandbox).cancel_and_clear()
	var armoury := get_node("ArmouryScreen") as ArmouryScreen
	var warehouse := get_node("WarehouseScreen") as WarehouseScreen
	if armoury.is_open(): armoury.close()
	if warehouse.is_open(): warehouse.close()
	_shared_storage_projection = null
	_storage_return_focus = null
	_armoury_from_loadout_warning = false
	_armoury_warning_class_id = &""
	_armoury_warning_origin = null
	_armoury_warning_origin_mode = LoadoutOrigin.RUN_SETUP
	_clear_pending_loadout_warning(false)
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


func _open_developer_item_sandbox() -> bool:
	var modal := get_node("DeveloperItemSandbox") as DeveloperItemSandbox
	var settings := get_node("SettingsScreen") as SettingsScreen
	var button := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings/Layout/OpenDeveloperItemSandbox") as Control
	var authoritative := settings_store.load_settings(settings_path) if settings_store != null else PartyForgeSettings.new()
	if authoritative.mode != PartyForgeSettings.Mode.DEVELOPER_MODE:
		modal.cancel_and_clear()
		settings.open_additional(button)
		settings.show_route_status(ITEM_SANDBOX_DEVELOPER_REQUIRED_STATUS, button)
		return false
	saved_settings = authoritative.copy()
	if settings.is_open():
		settings.close()
	return modal.open(button)


func _on_developer_item_sandbox_closed() -> void:
	var settings := get_node("SettingsScreen") as SettingsScreen
	var button := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings/Layout/OpenDeveloperItemSandbox") as Control
	settings.open_additional(button)


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

func _on_settings_applied(_settings: PartyForgeSettings) -> void:
	var authoritative := settings_store.load_settings(settings_path) if settings_store != null else _settings
	saved_settings = authoritative.copy()
	if saved_settings.mode != PartyForgeSettings.Mode.DEVELOPER_MODE:
		(get_node("DeveloperItemSandbox") as DeveloperItemSandbox).cancel_and_clear()
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
	boss.call("configure_combat", &"boss", game_run.combat_rng, catalog.damage_types, combat_resolution_service)
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
	_clear_live_loot()
	_cancel_hostile_effects()
	get_node("HUD/RunResultPanel").call("show_result", true)

func _show_defeat() -> void:
	_clear_live_loot()
	_cancel_hostile_effects()
	get_node("HUD/RunResultPanel").call("show_result", false)

func _cancel_hostile_effects() -> void:
	if boss != null and is_instance_valid(boss) and boss.has_method("cancel_pending_effects"):
		boss.call("cancel_pending_effects")
	if is_inside_tree():
		for effect: Node in get_tree().get_nodes_in_group(&"hostile_transient_effects"):
			effect.queue_free()

func _restart() -> void:
	_clear_live_loot()
	get_tree().paused = false
	if get_tree().current_scene != null:
		get_tree().reload_current_scene()

func _return_to_front_end() -> void:
	_clear_live_loot()
	get_tree().paused = false
	if get_tree().current_scene != null:
		get_tree().reload_current_scene()

func _quit() -> void:
	_clear_live_loot()
	get_tree().quit()
