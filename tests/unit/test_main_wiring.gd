extends RefCounted

const COMBAT_RESOLUTION_SERVICE := preload("res://scripts/combat/combat_resolution_service.gd")
const WAREHOUSE_LOCKED_DIALOG := preload("res://scripts/ui/warehouse/warehouse_locked_dialog.gd")
const TEST_ERROR_CAPTURE := preload("res://tests/support/test_error_capture.gd")

class WarehouseRefreshFailureManager extends ProfileManager:
    var failure_reason := "injected Warehouse refresh failure"

    func refresh_profile(profile_id: String) -> String:
        return "PROFILE_REFRESH_ERROR profile=%s error=%s" % [profile_id, failure_reason]

const REQUIRED_PATHS: PackedStringArray = [
    "res://scripts/run/run_terminal_flow.gd",
    "res://scripts/run/run_terminal_recovery_service.gd",
    "res://scripts/ui/run_setup/run_setup_restart_intent.gd",
    "res://scripts/ui/hud.gd",
    "res://scripts/ui/hud/combat_alert_tray.gd",
    "res://scripts/ui/hud/combat_member_inspect_panel.gd",
    "res://scripts/ui/class_selection_panel.gd",
    "res://scripts/ui/level_up_panel.gd",
    "res://scripts/ui/run_result_panel.gd",
    "res://scripts/ui/health_bar_3d.gd",
    "res://scripts/ui/ledger/character_ledger.gd",
    "res://scripts/ui/run_pause_menu.gd",
    "res://scripts/ui/developer_mode_badge.gd",
    "res://scripts/ui/main_menu/main_menu_screen.gd",
    "res://scripts/ui/developer_item_sandbox.gd",
    "res://scripts/ui/storage/profile_storage_projection.gd",
    "res://scripts/equipment/profile_loadout_assignment_service.gd",
    "res://scripts/run/local_run_setup_participant.gd",
    "res://scripts/run/local_run_setup_coordinator.gd",
    "res://scripts/ui/loadout_warning/loadout_warning_dialog.gd",
    "res://scenes/ui/loadout_warning/loadout_warning_dialog.tscn",
    "res://scripts/world/access/warehouse_presentation_reporter.gd",
    "res://scripts/ui/warehouse/warehouse_locked_dialog.gd",
    "res://scenes/ui/warehouse/warehouse_locked_dialog.tscn",
    "res://scripts/ui/run_recovery/run_recovery_dialog.gd",
    "res://scenes/ui/run_recovery/run_recovery_dialog.tscn",
    "res://scenes/ui/armoury/armoury_screen.tscn",
    "res://scenes/ui/warehouse/warehouse_screen.tscn",
    "res://scenes/ui/hud.tscn",
    "res://scenes/ui/hud/combat_alert_tray.tscn",
    "res://scenes/ui/hud/combat_member_inspect_panel.tscn",
    "res://scenes/ui/level_up_panel.tscn",
    "res://scenes/ui/run_result_panel.tscn",
    "res://scenes/ui/health_bar_3d.tscn",
    "res://scenes/ui/ledger/character_ledger.tscn",
    "res://scenes/ui/run_pause_menu.tscn",
    "res://scenes/ui/developer_mode_badge.tscn",
    "res://scenes/ui/main_menu/main_menu_screen.tscn",
    "res://scenes/ui/developer_item_sandbox.tscn",
    "res://scenes/game/main.tscn",
    "res://scenes/arena/arena.tscn",
    "res://scenes/characters/leader.tscn",
    "res://scenes/characters/companion.tscn",
    "res://scenes/enemies/swarmer.tscn",
    "res://scenes/enemies/spitter.tscn",
    "res://scenes/enemies/forge_guardian.tscn",
    "res://scenes/progression/experience_orb.tscn",
    "res://scenes/combat/heal_effect.tscn",
    "res://scenes/effects/danger_ring.tscn",
]

const REQUIRED_MAIN_NODES: PackedStringArray = [
    "GameRun", "PartyManager", "CombatResolutionService", "ExperienceSystem", "SpawnDirector",
    "PartyActorSpawner", "Arena", "Actors", "Enemies", "Effects", "HUD",
    "DeveloperModeBadge", "CharacterLedger", "RunPauseMenu",
    "MainMenuScreen", "SettingsScreen", "PassiveTreeScreen", "DeveloperItemSandbox", "ArmouryScreen", "WarehouseScreen", "WarehouseLockedDialog", "LoadoutWarningDialog", "RunRecoveryDialog",
]

var _profile_root := ""
var _settings_path := ""

class CountingProfileItemStorage extends ProfileItemStorageService:
    var calls := 0
    var last_request: ItemTransactionRequest

    func apply(_profile_id: String, request: ItemTransactionRequest, _root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
        calls += 1
        last_request = request
        var result := ProfileMutationResult.new()
        result.error = "intent captured"
        return result

class CountingLoadoutAssignments extends ProfileLoadoutAssignmentService:
    var calls := 0

    func apply(_profile_id: String, _request: ProfileLoadoutAssignmentRequest, _root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
        calls += 1
        var result := ProfileMutationResult.new()
        result.error = "wrong route captured"
        return result

func test_run_setup_lobby_is_the_single_typed_main_seam() -> Array[String]:
    var failures: Array[String] = []
    var source := FileAccess.get_file_as_string("res://scripts/game/main.gd")
    TestAssertions.truthy(source.contains("func _run_setup_lobby() -> ClassSelectionPanel:"), "Main exposes one typed lobby accessor", failures)
    TestAssertions.equal(source.count("get_node(\"HUD/ClassSelection\")"), 1, "only the typed accessor resolves the stable selector path", failures)
    TestAssertions.truthy(source.contains("class_preview_requested.connect(_on_lobby_class_preview_requested)"), "Main consumes lobby preview intent", failures)
    TestAssertions.truthy(source.contains("class_selection_requested.connect(_on_lobby_class_selection_requested)"), "Main consumes lobby selection intent", failures)
    TestAssertions.truthy(source.contains("start_requested.connect(_on_lobby_start_requested)"), "Main consumes separate Start intent", failures)
    TestAssertions.truthy(not source.contains("class_selected.connect(" + "select_leader_class)"), "class activation no longer starts a run", failures)
    TestAssertions.truthy(source.contains("enum LobbyReturnContext"), "lobby return authority is enum-backed", failures)
    TestAssertions.truthy(not source.contains("_armoury_from_loadout_warning"), "legacy Armoury return boolean is removed", failures)
    return failures

const CITY_TREE_ID := "party-forge-city-v1"
const CITY_UNAVAILABLE_STATUS := "City services are temporarily unavailable."
const CITY_LOCKED_STATUS := "Complete the prologue to unlock the City passive tree."
const CITY_DEVELOPER_REQUIRED_STATUS := "Save Developer Mode before opening the Developer City Preview."

func run() -> Array[String]:
    var failures: Array[String] = []
    failures.append_array(test_run_setup_lobby_is_the_single_typed_main_seam())
    var all_exist := true
    for path: String in REQUIRED_PATHS:
        var exists := ResourceLoader.exists(path)
        TestAssertions.truthy(exists, "required integrated resource loads: %s" % path, failures)
        all_exist = all_exist and exists
    if not all_exist:
        return failures
    _profile_root = "user://tests/main_wiring-profiles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    _settings_path = "user://tests/main_wiring-settings_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(_profile_root)
    _cleanup_settings_artifacts(_settings_path)
    _test_main_scene_graph(failures)
    _test_terminal_cutover_contract(failures)
    _test_run_combat_resolution_service_wiring(failures)
    _test_profile_boot_and_developer_gate(failures)
    _test_active_run_context_graph_and_failure_cleanup(failures)
    _test_personal_loot_defeat_and_guardian_wiring(failures)
    _test_invalid_personal_loot_tuning_aborts_main_start(failures)
    _test_live_loot_owner_leader_comparison_graph(failures)
    _test_gameplay_input_blocked_predicate(failures)
    _test_typed_live_loot_diagnostic_accounting(failures)
    _test_main_menu_route_composition(failures)
    _test_lobby_start_failure_routing(failures)
    _test_armoury_return_authority(failures)
    _test_profile_deletion_and_activation_separation(failures)
    _test_storage_route_policy_and_shared_projection_wiring(failures)
    _test_main_routes_real_overflow_source_only_through_storage(failures)
    _test_warehouse_shadow_observer_is_sidecar(failures)
    _test_warehouse_presentation_activation_wiring(failures)
    _test_city_return_focus_routing(failures)
    _test_loadout_warning_preflight_and_transition_wiring(failures)
    _test_passive_tree_route_composition(failures)
    _test_settings_and_next_run_snapshot_wiring(failures)
    _test_integrated_overlay_input_and_front_end_seam(failures)
    _test_hud_collapse_preference_persistence(failures)
    _test_hud_contract(failures)
    _test_class_selection_starts_run_and_applies_choices(failures)
    _test_live_member_health_provider_uses_party_membership(failures)
    _test_ledger_health_provider_is_unbounded_and_complete(failures)
    _test_fresh_new_run_seed_reaches_committed_runtime(failures)
    _test_run_offer_seed_and_snapshot_wiring(failures)
    var task6_contract := _task6_level_up_contract_available()
    TestAssertions.truthy(task6_contract, "Main and LevelUpPanel expose one unified Task 6 application seam", failures)
    if task6_contract:
        _test_exact_choice_panel(failures)
        _test_targeted_confirmation_routes_through_main(failures)
        _test_stale_target_rejects_without_consuming(failures)
        _test_lost_run_authority_rejects_before_mutation(failures)
        _test_synchronous_authority_release_is_atomic(failures)
        _test_capped_stat_is_disabled_without_hiding(failures)
        _test_queued_levels_show_fresh_production_offers(failures)
        _test_task13_validation_uses_unified_level_up_routes(failures)
    _test_boss_level_up_resumes_boss(failures)
    _test_catalog_gate_blocks_public_start(failures)
    _test_result_panel_requests_once(failures)
    _test_visual_language(failures)
    _test_catalog_error_format(failures)
    ProfileTestSupport.remove_tree(_profile_root)
    _cleanup_settings_artifacts(_settings_path)
    return failures

func _task6_level_up_contract_available() -> bool:
    var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    var available := (
        panel.has_signal(&"application_requested")
        and not panel.has_signal(&"choice_selected")
        and not panel.has_signal(&"confirmation_requested")
        and panel.has_method(&"accept_application")
        and panel.has_method(&"reject_application")
        and panel.get_node_or_null("Frame/Content/Offer/CardsScroll/Cards") != null
        and main.has_method(&"_on_level_up_application_requested")
    )
    panel.free()
    main.free()
    return available

func _test_task13_validation_uses_unified_level_up_routes(failures: Array[String]) -> void:
    for path: String in [
        "res://tools/validation/task_13_victory_acceptance.gd",
        "res://tools/validation/task_13_defeat_acceptance.gd",
    ]:
        var source := FileAccess.get_file_as_string(path)
        TestAssertions.truthy(not source.contains("get_node(\"Choices\")"), "%s removes the deleted Choices caller" % path.get_file(), failures)
        TestAssertions.truthy(source.contains("Frame/Content/Offer/CardsScroll/Cards"), "%s selects through real UpgradeCard controls" % path.get_file(), failures)
        TestAssertions.truthy(source.contains("Frame/Content/Recipient"), "%s handles recipient-confirmed offers" % path.get_file(), failures)
        TestAssertions.truthy(source.contains("Frame/Content/Confirmation"), "%s handles recruit and recipient confirmation" % path.get_file(), failures)
    var defeat_path := "res://tools/validation/task_13_defeat_acceptance.gd"
    var defeat_source := FileAccess.get_file_as_string(defeat_path)
    var bounded_iteration := defeat_source.contains("range(choices.size())")
    TestAssertions.truthy(bounded_iteration, "defeat validator iterates authoritative choices rather than retained card allocation", failures)
    if bounded_iteration:
        _test_task13_defeat_driver_sparse_and_empty_offers(failures)

func _test_task13_defeat_driver_sparse_and_empty_offers(failures: Array[String]) -> void:
    var driver: Variant = (load("res://tools/validation/task_13_defeat_acceptance.gd") as Script).new()
    var main := Node.new()
    main.name = "Task13MainFixture"
    var hud := Node.new()
    hud.name = "HUD"
    main.add_child(hud)
    var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
    hud.add_child(panel)
    (Engine.get_main_loop() as SceneTree).root.add_child(main)
    panel.call("_ready")
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    panel.configure(catalog, UpgradeApplicationService.new(), Callable())
    panel.configure_reduced_motion(true)
    var recovery_count: Array[int] = [0]
    panel.recovery_requested.connect(func() -> void: recovery_count[0] += 1)
    var allocation_offer: Array[UpgradeChoice] = [
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"max_health", "Maximum Health"),
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage"),
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"move_speed", "Move Speed"),
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"attack_speed", "Attack Speed"),
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"pickup_radius", "Pickup Radius"),
    ]
    panel.show_choices(allocation_offer, party)
    var retained_cards: Array[Node] = panel.get_node("Frame/Content/Offer/CardsScroll/Cards").get_children()
    TestAssertions.equal(retained_cards.filter(func(card: Node) -> bool: return (card as Control).visible).size(), 5, "defeat validator fixture first allocates five visible offer cards", failures)
    var unavailable := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage")
    panel.show_choices([unavailable], party, {unavailable.key(): "Unavailable for validation."})
    TestAssertions.truthy((retained_cards[0] as Control).visible, "sparse current offer keeps its one authoritative card visible", failures)
    TestAssertions.truthy(retained_cards.slice(1).all(func(card: Node) -> bool: return not (card as Control).visible), "sparse current offer hides every extra retained card before driver input", failures)
    driver.call("_handle_level_panel", main)
    TestAssertions.equal(driver.get("choice_log"), [], "defeat validator ignores hidden retained cards when the only current choice is disabled", failures)
    TestAssertions.equal(recovery_count[0], 1, "defeat validator requests recovery when no current choice is selectable", failures)
    panel.show_choices([], party, {&"__empty__": "No validation choices are available."})
    var retry := panel.get_node("Frame/Content/Offer/RetryOffers") as Button
    TestAssertions.truthy(retry.visible and not retry.disabled and panel.choices.is_empty(), "empty-offer fixture exposes enabled recovery", failures)
    TestAssertions.truthy(retry.pressed.is_connected(Callable(panel, "_on_recovery_pressed")), "empty-offer fixture wires the real recovery action", failures)
    TestAssertions.truthy(
        panel.visible
        and not (panel.get_node("Frame/Content/Pending") as Control).visible
        and not (panel.get_node("Frame/Content/Confirmation") as Control).visible
        and not (panel.get_node("Frame/Content/Recipient") as Control).visible,
        "empty-offer fixture exposes the active offer route",
        failures,
    )
    driver.call("_handle_level_panel", main)
    TestAssertions.equal(recovery_count[0], 2, "defeat validator activates empty-offer recovery exactly once", failures)
    main.free()
    driver.free()
    party.free()

func _test_run_combat_resolution_service_wiring(failures: Array[String]) -> void:
    var settings := PartyForgeSettings.new()
    settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    var main := _started_main_with_settings(settings)
    var service := main.get_node_or_null("CombatResolutionService")
    var party := main.get_node("PartyManager") as PartyManager
    var director := main.get_node("SpawnDirector") as SpawnDirector
    TestAssertions.truthy(service != null, "Main owns one run-scoped combat resolution service", failures)
    if service != null:
        TestAssertions.truthy(main.get("combat_resolution_service") == service, "Main caches the scene combat service", failures)
        TestAssertions.truthy(party.get("combat_resolution_service") == service, "PartyManager receives Main's exact combat service", failures)
        TestAssertions.truthy(director.get("combat_resolution_service") == service, "SpawnDirector receives Main's exact combat service", failures)
        var diagnostics_callback := Callable(main, "_on_combat_resolution_diagnostics_changed")
        TestAssertions.truthy(service.diagnostics_changed.is_connected(diagnostics_callback), "Main connects combat diagnostics for the active run", failures)
        TestAssertions.truthy(main.has_method("_connect_combat_resolution_diagnostics"), "Main exposes an idempotent combat diagnostics connector", failures)
        if main.has_method("_connect_combat_resolution_diagnostics"):
            main.call("_connect_combat_resolution_diagnostics")
        var callback_count: int = service.diagnostics_changed.get_connections().filter(
            func(connection: Dictionary) -> bool: return connection.get("callable") == diagnostics_callback
        ).size()
        TestAssertions.equal(callback_count, 1, "Main connects combat diagnostics exactly once per run", failures)
        service.diagnostics_changed.emit({
            "requested_instances": 12,
            "processed_instances": 12,
            "fractional_chance": 0.50,
            "fractional_draw": 0.25,
            "fractional_success": true,
            "fractional_draw_consumed": true,
            "total_overkill": 40.0,
            "ceiling_truncated": false,
        })
        var badge := main.get_node("DeveloperModeBadge") as DeveloperModeBadge
        TestAssertions.truthy("requested=12 processed=12" in badge.diagnostics_text(), "Main forwards service combat diagnostics to the developer badge", failures)
        var enemy := director.spawn_enemy(&"swarmer")
        TestAssertions.truthy(enemy != null and enemy.get("combat_resolution_service") == service, "ordinary spawned enemies receive Main's exact combat service", failures)
        main.call("_spawn_boss")
        var guardian := main.get("boss") as ForgeGuardian
        TestAssertions.truthy(guardian != null and guardian.get("combat_resolution_service") == service, "boss charge and shockwave receive Main's exact combat service", failures)
        main.call("_clear_live_loot")
        TestAssertions.truthy(not service.diagnostics_changed.is_connected(diagnostics_callback), "run teardown disconnects combat diagnostics", failures)
        TestAssertions.truthy("COMBAT DIAGNOSTICS" not in badge.diagnostics_text(), "run teardown clears combat diagnostics from the badge", failures)
    _cleanup_main(main)

func _test_storage_route_policy_and_shared_projection_wiring(failures: Array[String]) -> void:
    var root := "user://tests/main_wiring-storage-routes_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(root)
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    main.set("profile_root", root)
    main.set("settings_path", _settings_path)
    main.call("_ready")
    var manager := main.get("profile_manager") as ProfileManager
    manager.create_profile("Storage Route Tester")
    var menu := main.get_node("MainMenuScreen") as MainMenuScreen
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_ARMOURY)
    TestAssertions.truthy(menu.is_open() and not (main.get_node("ArmouryScreen") as ArmouryScreen).is_open(), "direct locked Armoury invocation rechecks access", failures)
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
    TestAssertions.truthy(menu.is_open() and not (main.get_node("WarehouseScreen") as WarehouseScreen).is_open(), "direct locked Warehouse invocation rechecks access", failures)
    var persisted_player := PartyForgeSettings.new()
    persisted_player.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
    persisted_player.unlock_all_implemented_content = false
    TestAssertions.equal(PartyForgeSettingsStore.new().save_settings(persisted_player, _settings_path), "", "route fixture persists authoritative Player Mode", failures)
    var stale_developer := PartyForgeSettings.new()
    stale_developer.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    stale_developer.unlock_all_implemented_content = true
    main.set("saved_settings", stale_developer)
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_ARMOURY)
    TestAssertions.truthy(menu.is_open() and not (main.get_node("ArmouryScreen") as ArmouryScreen).is_open(), "direct route reloads persisted Player Mode instead of trusting stale cached Developer Mode", failures)
    var profile := manager.active_profile()
    profile.permanent_feature_unlocks = ["equipment_inventory", "stash"]
    TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "route fixture persists unlocks", failures)
    TestAssertions.equal(manager.refresh_profile(profile.profile_id), "", "route fixture refreshes active profile", failures)
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_ARMOURY)
    TestAssertions.truthy((main.get_node("ArmouryScreen") as ArmouryScreen).is_open() and not menu.is_open(), "unlocked Armoury route opens separate modal", failures)
    main.call("_on_armoury_closed")
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
    TestAssertions.truthy((main.get_node("WarehouseScreen") as WarehouseScreen).is_open() and not menu.is_open(), "unlocked Warehouse route opens separate modal", failures)
    TestAssertions.truthy(main.get("_shared_storage_projection") is ProfileStorageProjection, "both routes are wired through one shared profile storage projection", failures)
    var warehouse := main.get_node("WarehouseScreen") as WarehouseScreen
    warehouse.set("_held_item_id", "stale-held")
    var old_projection := main.get("_shared_storage_projection") as ProfileStorageProjection
    var second := manager.create_profile("Second Storage Profile")
    TestAssertions.truthy(second.ok(), "profile-switch fixture creates a new active profile", failures)
    TestAssertions.truthy(not warehouse.is_open(), "active profile switch closes an open Warehouse", failures)
    TestAssertions.equal(main.get("_shared_storage_projection"), null, "active profile switch clears shared storage projection", failures)
    TestAssertions.equal(main.get("_storage_return_focus"), null, "active profile switch clears storage return focus", failures)
    TestAssertions.equal(warehouse.get("_held_item_id"), "", "active profile switch clears held Warehouse state", failures)
    TestAssertions.truthy(menu.is_open() and (menu.get_node("ActiveProfile") as Label).text.contains("Second Storage Profile"), "active profile switch presents the new profile menu", failures)
    main.set("_shared_storage_projection", old_projection)
    var sequence_before := int(main.get("_storage_transaction_sequence"))
    var current_before := manager.active_profile().to_dictionary()
    main.call("_on_armoury_equip_requested", "item-ring", &"ring_left", &"fighter")
    main.call("_on_armoury_move_requested", "item-ring", &"stash-tab-alpha", 4)
    main.call("_on_warehouse_move_requested", "item-ring", &"stash-tab-zeta", 4)
    TestAssertions.equal(main.get("_storage_transaction_sequence"), sequence_before, "all storage mutation handlers reject a stale cross-profile projection before issuing requests", failures)
    TestAssertions.equal(manager.active_profile().to_dictionary(), current_before, "stale cross-profile storage intents cannot mutate the active profile", failures)
    var armoury := main.get_node("ArmouryScreen") as ArmouryScreen
    armoury.open(old_projection, menu.get_node("Armoury") as Control)
    armoury.set("_held_item_id", "stale-armoury-held")
    main.set("_shared_storage_projection", old_projection)
    main.set("_storage_return_focus", menu.get_node("Armoury") as Control)
    var third := manager.create_profile("Third Storage Profile")
    TestAssertions.truthy(third.ok() and not armoury.is_open(), "active profile switch also closes an open Armoury", failures)
    TestAssertions.equal(armoury.get("_held_item_id"), "", "active profile switch clears held Armoury state", failures)
    TestAssertions.equal(main.get("_shared_storage_projection"), null, "Armoury profile switch clears the shared projection", failures)
    TestAssertions.equal(main.get("_storage_return_focus"), null, "Armoury profile switch clears return focus", failures)
    TestAssertions.truthy(menu.is_open() and (menu.get_node("ActiveProfile") as Label).text.contains("Third Storage Profile"), "Armoury profile switch presents the newest profile menu", failures)
    main.free()
    ProfileTestSupport.remove_tree(root)


func _test_main_routes_real_overflow_source_only_through_storage(failures: Array[String]) -> void:
    var root := "user://tests/main_wiring-overflow-route_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(root)
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    main.set("profile_root", root)
    main.set("settings_path", _settings_path)
    main.call("_ready")
    var manager := main.get("profile_manager") as ProfileManager
    TestAssertions.truthy(manager.create_profile("Overflow Route").ok(), "Main overflow routing fixture creates an active profile", failures)
    var profile := manager.active_profile()
    var item := ItemInstance.new()
    item.instance_id = "item-main-overflow"
    item.base_definition_id = &"forge_vanguard_sword"
    item.item_level = 20
    item.rarity_id = &"common"
    item.origin = {"issuer_namespace": "profile:%s" % profile.profile_id, "seed": 88, "sequence": 0, "source": "main_overflow_test"}
    profile.item_records = ItemRegistry.new([item]).to_dictionary()
    profile.inventory_columns = 1
    profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-main-overflow", ItemSlotContainer.PROFILE_STASH_TAB, profile.profile_id, 100).to_dictionary()]
    profile.terminal_recovery_overflow = ItemSlotContainer.create(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, ItemSlotContainer.PROFILE_TERMINAL_RECOVERY_OVERFLOW, profile.profile_id, EquipmentSlotIndex.capacity(), {0: item.instance_id}).to_dictionary()
    TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "Main overflow routing fixture persists populated ownership", failures)
    TestAssertions.equal(manager.refresh_profile(profile.profile_id), "", "Main overflow routing fixture refreshes durable profile", failures)
    var projection := main.call("_profile_storage_projection", manager.active_profile()) as ProfileStorageProjection
    TestAssertions.truthy(projection != null and projection.valid, "Main obtains a real populated-overflow storage projection", failures)
    if projection == null or not projection.valid:
        main.free()
        ProfileTestSupport.remove_tree(root)
        return
    main.set("_shared_storage_projection", projection)
    TestAssertions.equal(main.call("_storage_item_location", projection, item.instance_id), {"container_id": String(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID), "slot": 0}, "Main resolves the real overflow source identity", failures)
    TestAssertions.equal(main.call("_storage_item_at", projection, ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 0), item.instance_id, "Main reads exact overflow occupancy", failures)
    var storage := CountingProfileItemStorage.new()
    var assignments := CountingLoadoutAssignments.new()
    main.set("_profile_item_storage", storage)
    main.set("_profile_loadout_assignments", assignments)
    main.call("_on_armoury_move_requested", item.instance_id, &"stash-tab-main-overflow", 4)
    TestAssertions.equal(storage.calls, 1, "Main routes an overflow source through ProfileItemStorageService exactly once", failures)
    TestAssertions.equal(assignments.calls, 0, "Main never routes an overflow source through ProfileLoadoutAssignmentService", failures)
    TestAssertions.equal(storage.last_request.source_container_id if storage.last_request != null else "", String(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID), "Main preserves the projected overflow source in the storage request", failures)
    TestAssertions.equal(storage.last_request.operation if storage.last_request != null else "", ItemTransactionRequest.MOVE_TO_EMPTY, "Main emits source-only move-to-empty semantics", failures)
    main.free()
    ProfileTestSupport.remove_tree(root)


func _test_warehouse_shadow_observer_is_sidecar(failures: Array[String]) -> void:
    var root := "user://tests/main_wiring-warehouse-shadow_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    var settings_path := "user://tests/main_wiring-warehouse-shadow-settings_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(root)
    _cleanup_settings_artifacts(settings_path)
    var fixture_manager := ProfileManager.new()
    TestAssertions.equal(fixture_manager.bootstrap(root), "", "Warehouse shadow fixture bootstraps an isolated profile root", failures)
    var created := fixture_manager.create_profile("Warehouse Shadow Tester")
    TestAssertions.truthy(created.ok(), "Warehouse shadow fixture creates a no-stash profile", failures)
    var profile_before := fixture_manager.active_profile().to_dictionary()
    var developer_settings := PartyForgeSettings.new()
    developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    developer_settings.use_city_access_snapshot = true
    TestAssertions.equal(PartyForgeSettingsStore.new().save_settings(developer_settings, settings_path), "", "Warehouse shadow fixture persists Developer Mode snapshot observation", failures)
    var emissions: Array = []
    var provider := CityAccessProvider.new(func(_path: String) -> Variant:
        return CityAccessSnapshotLoader.load_path(CityAccessProvider.SNAPSHOT_PATH)
    )
    var comparator := CityAccessShadowComparator.new(provider, Callable(), func(marker: String, warning: bool) -> void:
        emissions.append([marker, warning])
    )
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    main.set("profile_root", root)
    main.set("settings_path", settings_path)
    main.set("city_access_shadow_comparator", comparator)
    main.call("_ready")
    var menu := main.get_node("MainMenuScreen") as MainMenuScreen
    var projection := menu.projection()
    TestAssertions.equal(emissions.size(), 1, "Main observes one Warehouse shadow marker after presenting the menu", failures)
    if emissions.size() == 1:
        var marker := String((emissions[0] as Array)[0])
        TestAssertions.truthy("access=MATCH" in marker, "Warehouse shadow marker reports matching access", failures)
        TestAssertions.truthy("visibility=DIVERGED" in marker, "Warehouse shadow marker reports visibility divergence", failures)
        TestAssertions.truthy("destination=NOT_APPLICABLE" in marker, "Warehouse shadow marker reports destination not applicable", failures)
    TestAssertions.truthy(projection.warehouse_visible and projection.warehouse_enabled, "Developer Mode keeps the Warehouse menu projection visible and enabled", failures)
    TestAssertions.truthy((menu.get_node("Warehouse") as Button).visible and not (menu.get_node("Warehouse") as Button).disabled, "Developer Mode keeps the Warehouse menu button visible and enabled", failures)
    TestAssertions.truthy((menu.get_node("CityWarehouseHotspot") as Button).visible and not (menu.get_node("CityWarehouseHotspot") as Button).disabled, "Developer Mode keeps the City Warehouse menu button visible and enabled", failures)
    TestAssertions.equal((main.get("profile_manager") as ProfileManager).active_profile().to_dictionary(), profile_before, "Warehouse observation leaves the active profile dictionary unchanged", failures)
    main.call("_refresh_main_menu_projection")
    TestAssertions.equal(emissions.size(), 1, "repeated main-menu projection leaves the Warehouse shadow marker deduplicated", failures)
    var player_settings := PartyForgeSettings.new()
    player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
    player_settings.use_city_access_snapshot = true
    TestAssertions.equal(PartyForgeSettingsStore.new().save_settings(player_settings, settings_path), "", "Warehouse shadow fixture persists Player Mode", failures)
    main.set("saved_settings", player_settings.copy())
    main.call("_refresh_main_menu_projection")
    TestAssertions.equal(emissions.size(), 1, "Player Mode emits no additional Warehouse shadow marker", failures)
    projection = menu.projection()
    TestAssertions.equal(projection.warehouse_presentation_state, WarehousePresentationResult.State.LOCKED, "Player Mode presents the candidate-locked Warehouse route", failures)
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
    TestAssertions.truthy(main.get_node("WarehouseLockedDialog").call("is_open") and not (main.get_node("WarehouseScreen") as WarehouseScreen).is_open(), "Player Mode keeps the direct locked Warehouse route blocked behind guidance", failures)
    main.free()
    ProfileTestSupport.remove_tree(root)
    _cleanup_settings_artifacts(settings_path)


func _test_warehouse_presentation_activation_wiring(failures: Array[String]) -> void:
    var root := "user://tests/main_wiring-warehouse-activation_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    var settings_path := "user://tests/main_wiring-warehouse-activation-settings_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(root)
    _cleanup_settings_artifacts(settings_path)
    var fixture_manager := ProfileManager.new()
    TestAssertions.equal(fixture_manager.bootstrap(root), "", "Warehouse activation fixture bootstraps an isolated profile root", failures)
    var created := fixture_manager.create_profile("Warehouse Activation Tester", 411)
    TestAssertions.truthy(created.ok(), "Warehouse activation fixture creates a profile", failures)
    var player := PartyForgeSettings.new()
    player.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
    player.use_city_access_snapshot = true
    TestAssertions.equal(PartyForgeSettingsStore.new().save_settings(player, settings_path), "", "Warehouse activation fixture persists Player Mode candidate presentation", failures)

    var report_emissions: Array = []
    var reporter_script := load("res://scripts/world/access/warehouse_presentation_reporter.gd") as Script
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
    main.profile_root = root
    main.settings_path = settings_path
    if reporter_script != null:
        main.set("warehouse_presentation_reporter", reporter_script.new(func(marker: String, warning: bool) -> void:
            var presented := (main.get_node("MainMenuScreen") as MainMenuScreen).projection().warehouse_presentation_state
            report_emissions.append([marker, warning, presented])
        ))
    (Engine.get_main_loop() as SceneTree).root.add_child(main)
    main.call("_ready")
    var manager := main.profile_manager as ProfileManager
    var menu := main.get_node("MainMenuScreen") as MainMenuScreen
    var warehouse := main.get_node("WarehouseScreen") as WarehouseScreen
    var locked_dialog: Variant = main.get_node_or_null("WarehouseLockedDialog")
    TestAssertions.truthy(locked_dialog != null, "Main composes Warehouse guidance", failures)
    if locked_dialog == null:
        main.free()
        ProfileTestSupport.remove_tree(root)
        _cleanup_settings_artifacts(settings_path)
        return
    TestAssertions.truthy(locked_dialog.city_tree_requested.is_connected(Callable(main, "_on_warehouse_locked_city_tree_requested")), "Main routes guidance CTA through one named City handler", failures)
    var projection := menu.projection()
    TestAssertions.equal(projection.warehouse_presentation_state, WarehousePresentationResult.State.LOCKED, "flag-on Player Mode presents locked Warehouse", failures)
    TestAssertions.equal(report_emissions.size(), 1, "authoritative presentation emits one activation diagnostic", failures)
    if report_emissions.size() == 1:
        TestAssertions.equal((report_emissions[0] as Array)[2], WarehousePresentationResult.State.LOCKED, "activation diagnostic runs after authoritative menu presentation", failures)

    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
    TestAssertions.truthy(locked_dialog.is_open() and not warehouse.is_open(), "blocked route opens guidance only", failures)
    TestAssertions.equal((locked_dialog.get_node("Overlay/Frame/Layout/Body") as Label).text, WAREHOUSE_LOCKED_DIALOG.PROLOGUE_BODY, "undiscovered City route selects prologue guidance", failures)
    locked_dialog.close()

    var warehouse_origin := menu.get_node("Warehouse") as Control
    menu.call("_emit_route", MainMenuViewModel.ROUTE_WAREHOUSE, warehouse_origin)
    TestAssertions.equal(locked_dialog.get("_return_focus"), warehouse_origin, "menu Warehouse origin is retained exactly", failures)
    locked_dialog.close()
    var hotspot_origin := menu.get_node("CityWarehouseHotspot") as Control
    menu.call("_emit_route", MainMenuViewModel.ROUTE_WAREHOUSE, hotspot_origin)
    TestAssertions.equal(locked_dialog.get("_return_focus"), hotspot_origin, "City Warehouse origin is retained exactly", failures)
    locked_dialog.close()

    var profile_id := manager.active_profile().profile_id
    var completed := ProfileMutationService.new(ProfileStore.new()).complete_prologue(profile_id, "warehouse-guidance-city", root)
    TestAssertions.truthy(completed.ok(), "Warehouse guidance fixture durably completes the prologue", failures)
    TestAssertions.equal(manager.refresh_profile(profile_id), "", "Warehouse guidance fixture refreshes durable City access", failures)
    main.call("_refresh_main_menu_projection")
    menu.call("_emit_route", MainMenuViewModel.ROUTE_WAREHOUSE, menu.get_node("Warehouse") as Control)
    TestAssertions.equal((locked_dialog.get_node("Overlay/Frame/Layout/Body") as Label).text, WAREHOUSE_LOCKED_DIALOG.AVAILABLE_BODY, "durable City access selects available guidance", failures)
    locked_dialog.close()
    var mutation_service := main.passive_tree_mutations
    main.passive_tree_mutations = null
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
    TestAssertions.equal((locked_dialog.get_node("Overlay/Frame/Layout/Body") as Label).text, WAREHOUSE_LOCKED_DIALOG.UNAVAILABLE_BODY, "missing City runtime selects temporary-unavailable guidance", failures)
    locked_dialog.close()
    main.passive_tree_mutations = mutation_service

    var profile := manager.active_profile()
    profile.permanent_feature_unlocks = ["stash"]
    TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "fixture persists Stash Access", failures)
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
    TestAssertions.truthy(warehouse.is_open() and not locked_dialog.is_open(), "fresh policy recheck opens newly authorized Warehouse", failures)
    main.call("_on_warehouse_closed")

    profile = manager.active_profile()
    profile.permanent_feature_unlocks = []
    TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "fixture removes Stash Access for stale-settings checks", failures)
    TestAssertions.equal(manager.refresh_profile(profile_id), "", "fixture refreshes locked profile", failures)
    var stale_developer := player.copy()
    stale_developer.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    main.saved_settings = stale_developer
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
    TestAssertions.truthy(locked_dialog.is_open() and not warehouse.is_open(), "persisted Player Mode defeats stale cached Developer authorization", failures)
    locked_dialog.close()
    var developer := player.copy()
    developer.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    TestAssertions.equal(PartyForgeSettingsStore.new().save_settings(developer, settings_path), "", "fixture persists Developer preview", failures)
    main.saved_settings = player.copy()
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
    TestAssertions.truthy(warehouse.is_open() and not locked_dialog.is_open(), "persisted Developer preview bypasses player Warehouse policy explicitly", failures)
    main.call("_on_warehouse_closed")

    TestAssertions.equal(PartyForgeSettingsStore.new().save_settings(player, settings_path), "", "fixture restores Player Mode candidate presentation", failures)
    main.saved_settings = player.copy()
    main.set("city_access_provider", CityAccessProvider.new(func(_path: String) -> Variant: return null))
    main.call("_refresh_main_menu_projection")
    TestAssertions.equal(menu.projection().warehouse_presentation_state, WarehousePresentationResult.State.HIDDEN, "failed candidate restores legacy hidden presentation", failures)
    var flag_off := player.copy()
    flag_off.use_city_access_snapshot = false
    main.saved_settings = flag_off
    main.call("_refresh_main_menu_projection")
    TestAssertions.equal(menu.projection().warehouse_presentation_state, WarehousePresentationResult.State.HIDDEN, "setting-off restores legacy hidden presentation", failures)
    main.set("city_access_provider", CityAccessProvider.new())
    main.saved_settings = player.copy()
    main.call("_refresh_main_menu_projection")
    TestAssertions.equal(menu.projection().warehouse_presentation_state, WarehousePresentationResult.State.LOCKED, "restored candidate returns locked presentation", failures)

    warehouse_origin = menu.get_node("Warehouse") as Control
    menu.call("_emit_route", MainMenuViewModel.ROUTE_WAREHOUSE, warehouse_origin)
    locked_dialog.call("_on_view_city_tree")
    var tree_screen := main.get_node("PassiveTreeScreen") as PassiveTreeScreen
    TestAssertions.truthy(tree_screen.is_open() and not menu.is_open(), "guidance CTA reuses the existing City route", failures)
    TestAssertions.equal(main.get("_city_tree_return_focus"), warehouse_origin, "City route retains the exact Warehouse origin", failures)
    profile = manager.active_profile()
    profile.permanent_feature_unlocks = ["stash"]
    TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "City allocation fixture persists Stash Access while the tree is open", failures)
    tree_screen.close()
    TestAssertions.equal(menu.projection().warehouse_presentation_state, WarehousePresentationResult.State.AVAILABLE, "City return refreshes persisted Stash Access", failures)
    TestAssertions.truthy(menu.is_open() and bool(menu.call("_is_available_action", warehouse_origin)), "City return preserves the exact still-available Warehouse origin as its return target", failures)

    profile = manager.active_profile()
    profile.permanent_feature_unlocks = []
    TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "profile-switch fixture restores locked state", failures)
    TestAssertions.equal(manager.refresh_profile(profile_id), "", "profile-switch fixture refreshes locked state", failures)
    main.call("_refresh_main_menu_projection")
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
    TestAssertions.truthy(locked_dialog.is_open(), "locked dialog opens before profile switch", failures)
    var switched := manager.create_profile("Warehouse Switch Target", 412)
    TestAssertions.truthy(switched.ok() and not locked_dialog.is_open(), "active profile switch closes Warehouse guidance", failures)

    var failing_manager := WarehouseRefreshFailureManager.new()
    TestAssertions.equal(failing_manager.bootstrap(root), "", "refresh-failure fixture bootstraps the authoritative profile bytes", failures)
    main.profile_manager = failing_manager
    main.set("_city_tree_origin", &"main_menu")
    main.set("_city_tree_return_focus", menu.get_node("Warehouse") as Control)
    main.call("_on_city_passive_tree_closed")
    var safe_status := "Some profile data needs attention. Open Settings > Profiles for details."
    TestAssertions.equal((menu.get_node("Status") as Label).text, safe_status, "City return refresh failure reports generic player-safe status", failures)
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
    TestAssertions.truthy(not warehouse.is_open() and not locked_dialog.is_open(), "next Warehouse route repeats the required refresh and fails closed", failures)
    TestAssertions.equal((menu.get_node("Status") as Label).text, safe_status, "route-local refresh failure preserves generic player-safe status", failures)

    main.free()
    ProfileTestSupport.remove_tree(root)
    _cleanup_settings_artifacts(settings_path)


func _test_city_return_focus_routing(failures: Array[String]) -> void:
    var root := "user://tests/main_wiring-warehouse-return-focus_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    var settings_path := "user://tests/main_wiring-warehouse-return-focus-settings_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(root)
    _cleanup_settings_artifacts(settings_path)
    var fixture_manager := ProfileManager.new()
    TestAssertions.equal(fixture_manager.bootstrap(root), "", "City return-focus fixture bootstraps an isolated profile root", failures)
    var created := fixture_manager.create_profile("Warehouse Return Focus Tester", 413)
    TestAssertions.truthy(created.ok(), "City return-focus fixture creates a profile", failures)
    var profile := fixture_manager.active_profile()
    profile.permanent_feature_unlocks = ["stash"]
    TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "City return-focus fixture persists available Warehouse", failures)
    TestAssertions.equal(fixture_manager.refresh_profile(profile.profile_id), "", "City return-focus fixture refreshes available Warehouse", failures)
    var player := PartyForgeSettings.new()
    player.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
    player.use_city_access_snapshot = true
    TestAssertions.equal(PartyForgeSettingsStore.new().save_settings(player, settings_path), "", "City return-focus fixture persists Player Mode candidate presentation", failures)

    var detached_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
    detached_main.profile_root = root
    detached_main.settings_path = settings_path
    detached_main.call("_ready")
    var menu := detached_main.get_node("MainMenuScreen") as MainMenuScreen
    var warehouse_origin := menu.get_node("Warehouse") as Control
    detached_main.set("_city_tree_origin", &"main_menu")
    detached_main.set("_city_tree_return_focus", warehouse_origin)
    detached_main.call("_on_city_passive_tree_closed")
    TestAssertions.equal(menu.get("_pending_preferred_focus"), warehouse_origin, "available City return passes the exact Warehouse origin to the menu", failures)

    profile = detached_main.active_profile()
    profile.permanent_feature_unlocks = []
    TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "City return-focus fixture removes Warehouse authority", failures)
    var flag_off := player.copy()
    flag_off.use_city_access_snapshot = false
    detached_main.saved_settings = flag_off
    detached_main.set("_city_tree_origin", &"main_menu")
    detached_main.set("_city_tree_return_focus", warehouse_origin)
    detached_main.call("_on_city_passive_tree_closed")
    TestAssertions.equal(menu.projection().warehouse_presentation_state, WarehousePresentationResult.State.HIDDEN, "hidden return origin stays unavailable after profile refresh", failures)
    TestAssertions.equal(menu.get("_pending_preferred_focus"), null, "hidden Warehouse origin requests no preferred menu focus", failures)
    TestAssertions.equal(menu.call("_first_available_action"), menu.get_node("PrimaryAction"), "hidden Warehouse origin falls back to the menu's first available action", failures)

    detached_main.free()
    ProfileTestSupport.remove_tree(root)
    _cleanup_settings_artifacts(settings_path)


func _test_loadout_warning_preflight_and_transition_wiring(failures: Array[String]) -> void:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
    var warning := main.get_node_or_null("LoadoutWarningDialog")
    TestAssertions.truthy(warning != null, "main composes the loadout warning above run setup", failures)
    for method_name: StringName in [&"_project_loadout_compatibility", &"_submit_pending_loadout_transition", &"_checkout_and_start_leader_class"]:
        TestAssertions.truthy(main.has_method(method_name), "main exposes %s preflight seam" % method_name, failures)
    if warning == null or not main.has_method(&"_project_loadout_compatibility"):
        main.free()
        return

    var root := "user://tests/main_wiring-loadout-warning_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(root)
    main.set("profile_root", root)
    main.set("settings_path", _settings_path)
    main.call("_ready")
    warning.call("_ready")
    var manager := main.get("profile_manager") as ProfileManager
    var created := manager.create_profile("Warning Flow Tester")
    TestAssertions.truthy(created.ok(), "warning fixture creates active profile", failures)
    var profile := manager.active_profile()
    var item := _main_loadout_item(profile.profile_id, "item-warning-sword", &"forge_vanguard_sword", 0)
    profile.item_records = ItemRegistry.new([item]).to_dictionary()
    profile.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, profile.profile_id, EquipmentSlotIndex.capacity(), {0: item.instance_id}).to_dictionary()
    profile.leader_loadout_class_id = "fighter"
    profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-alpha", ItemSlotContainer.PROFILE_STASH_TAB, profile.profile_id, ItemSlotContainer.STASH_CAPACITY).to_dictionary()]
    profile.permanent_feature_unlocks = ["bring_in_gear", "equipment_inventory", "stash"]
    TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "warning fixture persists compatible Fighter loadout", failures)
    TestAssertions.equal(manager.refresh_profile(profile.profile_id), "", "warning fixture refreshes authoritative profile", failures)
    var profile_path := ProfileStore.new().profile_path(profile.profile_id, root)
    var bytes_before := FileAccess.get_file_as_bytes(profile_path)
    main.call("_open_run_setup")
    main.call("_on_lobby_class_selection_requested", &"mage")
    main.call("_on_lobby_start_requested", &"mage")
    TestAssertions.truthy(warning.call("is_open"), "incompatible selection opens warning", failures)
    TestAssertions.truthy(not bool(main.get("run_started")) and main.get("active_run_context") == null, "warning preflight creates no run context", failures)
    TestAssertions.equal(FileAccess.get_file_as_bytes(profile_path), bytes_before, "warning preflight changes no profile bytes", failures)
    var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
    TestAssertions.truthy(selector.compatibility_gate_active(), "class selection is explicitly gated while warning is open", failures)

    (warning.get_node("Overlay/Frame/Layout/Actions/Armoury") as Button).pressed.emit()
    var armoury := main.get_node("ArmouryScreen") as ArmouryScreen
    TestAssertions.truthy(armoury.is_open() and not warning.call("is_open") and not selector.is_open(), "Go to Armoury opens the same-profile Task 9 interface", failures)
    TestAssertions.truthy((armoury.get_node("Overlay/Frame/Layout/Header/Class") as Label).text.contains("Pending Run: mage"), "Armoury shows selected class for display only", failures)
    TestAssertions.equal(FileAccess.get_file_as_bytes(profile_path), bytes_before, "Armoury redirect mutates no profile bytes", failures)
    main.call("_on_armoury_closed")
    TestAssertions.truthy(selector.is_open() and not bool(main.get("run_started")), "returning from warning Armoury requires fresh class selection", failures)
    TestAssertions.equal(main.get("_pending_loadout_projection"), null, "Armoury return cannot reuse stale approval", failures)
    TestAssertions.equal(selector.selected_class_id(), &"mage", "warning Armoury preserves the selected class", failures)
    TestAssertions.equal(main.get("_lobby_return_focus"), null, "warning Armoury consumes its return focus", failures)

    main.call("_on_lobby_start_requested", &"mage")
    TestAssertions.truthy(warning.call("is_open"), "post-Armoury Start creates another fresh projection", failures)
    (warning.get_node("Overlay/Frame/Layout/Actions/ChooseAnother") as Button).pressed.emit()
    TestAssertions.truthy(not warning.call("is_open") and selector.is_open(), "Choose Another Class returns to run setup", failures)
    TestAssertions.truthy(not selector.compatibility_gate_active(), "Choose Another Class clears the gate", failures)
    TestAssertions.equal(selector.selected_class_id(), &"mage", "Choose Another Class preserves the selected class", failures)
    TestAssertions.equal(FileAccess.get_file_as_bytes(profile_path), bytes_before, "Choose Another Class mutates no profile bytes", failures)
    main.call("_on_loadout_continue_anyway")
    TestAssertions.truthy(not bool(main.get("run_started")), "direct stale Continue signal cannot start a run", failures)
    TestAssertions.equal(FileAccess.get_file_as_bytes(profile_path), bytes_before, "direct stale Continue signal cannot mutate profile", failures)

    main.call("_on_lobby_start_requested", &"mage")
    (warning.get_node("Overlay/Frame/Layout/Actions/Cancel") as Button).pressed.emit()
    TestAssertions.truthy(not warning.call("is_open") and selector.is_open(), "warning Cancel returns to lobby", failures)
    var cancel_return := selector.action_focus(&"start")
    TestAssertions.truthy(cancel_return != null and bool(cancel_return.get_meta("action_enabled", false)), "warning Cancel restores an enabled Start action", failures)

    main.call("_on_lobby_start_requested", &"mage")
    (warning.get_node("Overlay/Frame/Layout/Actions/Continue") as Button).pressed.emit()
    TestAssertions.truthy(bool(main.get("run_started")), "confirmed nonoverflow transition starts after revalidation and checkout", failures)
    TestAssertions.truthy(main.get("active_run_context") != null, "successful transition starts from committed checkout bootstrap", failures)
    TestAssertions.truthy(not warning.call("is_open"), "successful transition closes warning", failures)
    var saved := ProfileStore.new().load_profile(profile.profile_id, root).profile
    TestAssertions.equal(saved.leader_loadout["slots"], {}, "transition removes incompatible item from active loadout", failures)
    TestAssertions.equal(saved.stash_tabs[0]["slots"], {"0": item.instance_id}, "transition uses exact deterministic first-empty stash destination", failures)
    TestAssertions.truthy(saved.resumable_run.has("item_state"), "successful warning flow durably checks out before context start", failures)
    (Engine.get_main_loop() as SceneTree).paused = false
    main.free()
    ProfileTestSupport.remove_tree(root)


func _main_loadout_item(profile_id: String, instance_id: String, base_id: StringName, sequence: int) -> ItemInstance:
    var item := ItemInstance.new()
    item.instance_id = instance_id
    item.base_definition_id = base_id
    item.item_level = 1
    item.rarity_id = &"common"
    item.origin = {
        "issuer_namespace": "profile:%s" % profile_id,
        "seed": 41010,
        "sequence": sequence,
        "source": "main_loadout_warning_test",
    }
    return item

func _test_profile_boot_and_developer_gate(failures: Array[String]) -> void:
    var profile_root := "user://tests/main_wiring-profile-gate_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(profile_root)

    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
    main.set("profile_root", profile_root)
    main.call("_ready")
    var manager := main.get("profile_manager") as ProfileManager
    var settings := main.get_node("SettingsScreen") as SettingsScreen
    var menu := main.get_node_or_null("MainMenuScreen") as MainMenuScreen
    TestAssertions.truthy(manager != null, "main exposes one ProfileManager", failures)
    TestAssertions.equal(settings.get("_profile_manager"), manager, "Settings receives the main ProfileManager", failures)
    TestAssertions.equal(manager.profiles().size(), 0, "fresh main does not auto-create a profile", failures)
    TestAssertions.truthy(menu != null and menu.is_open() and not (main.get_node("HUD/ClassSelection") as ClassSelectionPanel).is_open(), "fresh main composes menu before run setup", failures)
    var developer_settings := PartyForgeSettings.new()
    developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    developer_settings.unlock_all_implemented_content = true
    main.set("saved_settings", developer_settings)
    TestAssertions.truthy(not main.select_leader_class(&"fighter"), "Developer Mode Unlock All cannot bypass the profile requirement", failures)
    TestAssertions.equal(manager.profiles().size(), 0, "Developer Mode Unlock All grants no profile", failures)
    TestAssertions.truthy(not bool(main.get("run_started")), "profile gate leaves Developer Mode gameplay unstarted", failures)
    var created := manager.create_profile("Test Profile")
    TestAssertions.truthy(created.ok(), "main profile fixture creates through the production manager", failures)
    settings.close()
    TestAssertions.truthy(main.select_leader_class(&"fighter"), "selected profile preserves Fighter arena launch", failures)
    TestAssertions.truthy(bool(main.get("run_started")) and main.get("leader") != null, "profile-backed launch preserves current run state", failures)
    (Engine.get_main_loop() as SceneTree).paused = false
    main.free()
    ProfileTestSupport.remove_tree(profile_root)

func _test_active_run_context_graph_and_failure_cleanup(failures: Array[String]) -> void:
    var main := _started_main()
    var registry := main.get("run_context_registry") as RunContextRegistry
    var context := main.get("active_run_context") as PlayerRunContext
    var distributor := main.get("reward_distribution_service") as RewardDistributionService
    var facade := main.get_node("ExperienceSystem") as ExperienceSystem
    var spawner := main.get_node("PartyActorSpawner") as PartyActorSpawner
    var director := main.get_node("SpawnDirector") as SpawnDirector
    TestAssertions.truthy(registry != null, "main owns the single-player run context registry", failures)
    TestAssertions.truthy(context != null, "main owns the active player run context", failures)
    TestAssertions.truthy(distributor != null, "main owns the reward distribution service", failures)
    if registry != null and context != null:
        TestAssertions.equal(registry.all_contexts(), [context], "main registers exactly one active context", failures)
        TestAssertions.truthy(registry.is_arena_roster_locked(), "single-player Arena locks its context roster", failures)
        TestAssertions.equal(registry.device_for(&"player_1"), -1, "single-player context starts with unassigned device", failures)
        TestAssertions.truthy(context.party == main.party_manager and main.party_manager == main.get_node("PartyManager"), "compatibility PartyManager is the context party", failures)
        TestAssertions.equal(context.profile_id, main.active_profile().profile_id, "context derives identity from the active profile copy", failures)
        var exposed_profile: ProfileState = main.active_profile()
        exposed_profile.gold += 99
        TestAssertions.truthy(context.profile_snapshot.gold != exposed_profile.gold, "context profile remains defensively isolated", failures)
        var leader_member_id := context.party.members[0].member_id
        TestAssertions.truthy(context.actor_for(leader_member_id) == main.leader, "main binds the production leader to its context", failures)
        TestAssertions.truthy(facade.get("run_context") == context, "ExperienceSystem facade targets the active context", failures)
        TestAssertions.equal(facade.get("leader_member_id"), leader_member_id, "ExperienceSystem facade targets the leader member", failures)
        TestAssertions.truthy(spawner.get("owner_context") == context, "PartyActorSpawner owns the same context", failures)
    if distributor != null:
        TestAssertions.truthy(distributor.registry == registry, "reward service uses the active registry", failures)
        TestAssertions.truthy(distributor.tuning != null, "reward service owns loaded distance tuning", failures)
        TestAssertions.truthy(director.reward_distributor == distributor, "SpawnDirector receives the reward service rather than global XP", failures)
    _cleanup_main(main)

    var failure_root := "user://tests/main_wiring-context-failure_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    var failure_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
    failure_main.profile_root = failure_root
    ProfileTestSupport.remove_tree(failure_root)
    _prepare_main(failure_main)
    var failure_party := failure_main.party_manager
    failure_party.initialize(failure_main.catalog.class_by_id(&"fighter"), failure_main.catalog.traits)
    var failed_context := PlayerRunContext.new()
    TestAssertions.equal(failed_context.configure(&"player_1", 0, failure_main.active_profile(), 1337, failure_party, 100), PackedStringArray(), "failure fixture context configures", failures)
    failure_main.active_run_context = failed_context
    failure_main.run_context_registry = RunContextRegistry.new()
    TestAssertions.truthy(failure_main.run_context_registry.register_context(failed_context).ok(), "failure fixture context registers", failures)
    failure_main.experience_system.configure_context(failed_context, 1)
    var failed_leader := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
    failure_main.get_node("Actors").add_child(failed_leader)
    failed_leader.configure(failure_party.members[0])
    failure_main.leader = failed_leader
    var member_callback := Callable(failed_context, "_on_member_added")
    TestAssertions.truthy(failure_party.member_added.is_connected(member_callback), "configured context observes its party before abort", failures)
    TestAssertions.truthy(not failure_main.call("_abort_run_start", PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=test"]), failed_leader), "context abort returns failure", failures)
    TestAssertions.truthy(not is_instance_valid(failed_leader), "context abort frees the newly spawned leader", failures)
    TestAssertions.truthy(not failure_main.run_started, "context abort leaves run unstarted", failures)
    TestAssertions.equal(failure_main.leader, null, "context abort clears leader compatibility state", failures)
    TestAssertions.truthy((failure_main.get_node("MainMenuScreen") as MainMenuScreen).is_open(), "context abort restores the front end", failures)
    TestAssertions.truthy(failure_main.run_context_registry.all_contexts().is_empty(), "context abort leaves no partial registration", failures)
    TestAssertions.equal(failure_main.active_run_context, null, "context abort clears active context", failures)
    TestAssertions.equal(failure_main.experience_system.run_context, null, "context abort clears the facade", failures)
    TestAssertions.truthy(not failure_party.member_added.is_connected(member_callback), "context abort disconnects partial party ownership", failures)
    failure_main.free()
    ProfileTestSupport.remove_tree(failure_root)

func _test_personal_loot_defeat_and_guardian_wiring(failures: Array[String]) -> void:
    var defeat_runner_source := FileAccess.get_file_as_string("res://tests/integration/personal_loot_defeat_runner.gd")
    TestAssertions.truthy(not '.call("_ready")' in defeat_runner_source, "personal-loot defeat integration uses natural SceneTree readiness", failures)
    var player_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(player_main)
    var player_profile := player_main.active_profile() as ProfileState
    player_profile.permanent_feature_unlocks = ["equipment_inventory"]
    TestAssertions.equal(ProfileStore.new().save_profile(player_profile, String(player_main.get("profile_root"))), "", "zero-column feature fixture persists equipment access only", failures)
    TestAssertions.equal(player_main.profile_manager.refresh_profile(player_profile.profile_id), "", "zero-column feature fixture refreshes the authoritative profile", failures)
    TestAssertions.truthy(player_main.call("select_leader_class", &"fighter"), "zero-column feature fixture starts through Main", failures)
    var player_director := player_main.get_node("SpawnDirector") as SpawnDirector
    var player_roll := player_main.get("personal_loot_roll_service") as PersonalLootRollService
    var player_coordinator := player_main.get("personal_loot_drop_coordinator") as PersonalLootDropCoordinator
    var player_registry := player_main.get("ground_item_registry") as GroundItemRegistry
    TestAssertions.truthy(player_roll != null and player_coordinator != null and player_registry != null, "Player Mode run owns the personal-loot service graph", failures)
    TestAssertions.truthy(
        player_director.has_signal("enemy_defeated") and player_coordinator != null and player_director.is_connected("enemy_defeated", Callable(player_main, "_on_enemy_defeated_for_personal_loot")),
        "main wires director defeats through the diagnostic-aware coordinator boundary",
        failures,
    )
    if player_roll != null and player_coordinator != null and player_registry != null:
        player_roll.loot_tuning.drop_basis_points[&"ordinary_melee"] = 10000
        player_director.call("_on_enemy_defeated", load("res://data/enemies/swarmer.tres") as EnemyDefinition, player_main.leader.position, 1)
        TestAssertions.equal(player_main.active_run_context.run_inventory().capacity, 0, "zero-column Player Mode run has no inventory capacity", failures)
        TestAssertions.equal(player_registry.all_records().size(), 0, "feature-unlocked zero-column Player Mode context fails closed with no uncollectable drop", failures)
    _cleanup_main(player_main)

    var developer_settings := PartyForgeSettings.new()
    developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    developer_settings.unlock_all_implemented_content = true
    var developer_main := _started_main_with_settings(developer_settings)
    var developer_director := developer_main.get_node("SpawnDirector") as SpawnDirector
    var developer_roll := developer_main.get("personal_loot_roll_service") as PersonalLootRollService
    var developer_coordinator := developer_main.get("personal_loot_drop_coordinator") as PersonalLootDropCoordinator
    var developer_registry := developer_main.get("ground_item_registry") as GroundItemRegistry
    TestAssertions.truthy(developer_roll != null and developer_coordinator != null and developer_registry != null, "Developer run owns the personal-loot service graph", failures)
    if developer_roll == null or developer_coordinator == null or developer_registry == null:
        _cleanup_main(developer_main)
        return
    TestAssertions.equal(developer_main.active_run_context.run_inventory().capacity, 5, "Developer Unlock All receives one explicit run-only inventory column", failures)
    TestAssertions.equal(developer_main.active_profile().inventory_columns, 0, "Developer run-only inventory does not mutate the profile column count", failures)
    developer_roll.loot_tuning.drop_basis_points[&"ordinary_melee"] = 10000
    developer_director.call("_on_enemy_defeated", load("res://data/enemies/swarmer.tres") as EnemyDefinition, developer_main.leader.position, 1)
    TestAssertions.equal(developer_registry.all_records().size(), 1, "Developer Unlock All grants the independently evaluated personal drop", failures)
    var developer_world := developer_main.get("ground_item_world_controller") as Node
    TestAssertions.truthy(developer_world.pickup_feedback.is_connected(Callable(developer_main, "_on_ground_item_pickup_feedback")), "Main routes typed pickup feedback to the HUD", failures)
    var developer_record := developer_registry.all_records()[0] if developer_registry.all_records().size() == 1 else null
    var developer_detail := developer_main.call("_ground_item_detail", developer_record) as Dictionary if developer_record != null else {}
    if developer_record != null:
        developer_world.call("_on_chest_pickup_requested", developer_record.drop_id, developer_record.run_player_id)
    var loot_status := developer_main.get_node("HUD/LootStatus") as Label
    TestAssertions.truthy(loot_status.visible and loot_status.text.contains(String(developer_detail.get("name", ""))) and loot_status.text.contains(String(developer_detail.get("rarity_name", ""))), "successful pickup HUD feedback names the item and rarity", failures)
    TestAssertions.equal(developer_registry.all_records().size(), 0, "successful HUD pickup removes the collected chest", failures)

    var boss_event := EnemyDefeatEvent.create(1337, 2, 2, &"forge_guardian", &"boss", developer_main.leader.position, 300.0)
    developer_coordinator.resolve_defeat(boss_event)
    TestAssertions.equal(developer_registry.all_records().size(), 0, "zero boss basis points create no ground chest", failures)

    var game_run := developer_main.get_node("GameRun") as GameRun
    var victories: Array[int] = [0]
    game_run.victory.connect(func() -> void: victories[0] += 1)
    game_run.advance_run_time(300.0)
    var guardian := developer_main.get("boss") as ForgeGuardian
    TestAssertions.truthy(guardian != null, "boss phase still spawns the Forge Guardian", failures)
    if guardian != null:
        guardian.defeat()
        guardian.defeat()
    TestAssertions.equal(victories[0], 1, "Forge Guardian preserves the existing exactly-once victory behavior", failures)
    TestAssertions.equal(developer_registry.all_records().size(), 0, "Guardian victory adds no boss reward and keeps run-owned ground loot cleared", failures)
    _cleanup_main(developer_main)

    var expanded_developer_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(expanded_developer_main)
    var expanded_profile := expanded_developer_main.active_profile() as ProfileState
    expanded_profile.inventory_columns = 3
    TestAssertions.equal(ProfileStore.new().save_profile(expanded_profile, String(expanded_developer_main.get("profile_root"))), "", "expanded Developer fixture persists three profile inventory columns", failures)
    TestAssertions.equal(expanded_developer_main.profile_manager.refresh_profile(expanded_profile.profile_id), "", "expanded Developer fixture refreshes the authoritative profile", failures)
    expanded_developer_main.saved_settings = developer_settings.copy()
    TestAssertions.truthy(expanded_developer_main.select_leader_class(&"fighter"), "expanded Developer profile starts through Main", failures)
    TestAssertions.equal(expanded_developer_main.active_run_context.run_inventory().capacity, 15, "Developer five-slot grant is a minimum and never shrinks a larger profile inventory", failures)
    TestAssertions.equal(expanded_developer_main.active_profile().inventory_columns, 3, "Developer minimum capacity does not mutate a larger profile column count", failures)
    _cleanup_main(expanded_developer_main)

func _test_invalid_personal_loot_tuning_aborts_main_start(failures: Array[String]) -> void:
    var isolated_root := "user://tests/main_wiring-invalid-loot_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(isolated_root)
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    main.set("profile_root", isolated_root)
    main.set("settings_path", _settings_path)
    main.call("_ready")
    var created := main.profile_manager.create_profile("Invalid Loot Tuning") as ProfileOperationResult
    TestAssertions.truthy(created.ok(), "invalid tuning fixture creates an isolated active profile", failures)
    (main.get_node("SettingsScreen") as SettingsScreen).close()
    var invalid := PersonalLootTuning.new()
    invalid.seconds_per_item_level = 0.0
    main.set("personal_loot_tuning_source", invalid)
    TestAssertions.truthy(not main.call("select_leader_class", &"fighter"), "Main aborts run start when personal-loot tuning is invalid", failures)
    TestAssertions.truthy(not main.run_started and main.personal_loot_drop_coordinator == null and main.ground_item_registry == null, "invalid tuning leaves no active loot coordinator, registry, or run", failures)
    _cleanup_main(main)
    ProfileTestSupport.remove_tree(isolated_root)

func _test_live_loot_owner_leader_comparison_graph(failures: Array[String]) -> void:
    var settings := PartyForgeSettings.new()
    settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    settings.unlock_all_implemented_content = true
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(main)
    var profile := (main.get("profile_manager") as ProfileManager).active_profile()
    profile.inventory_columns = 1
    TestAssertions.equal(ProfileStore.new().save_profile(profile, String(main.get("profile_root"))), "", "comparison fixture persists one production inventory column", failures)
    TestAssertions.equal((main.get("profile_manager") as ProfileManager).refresh_profile(profile.profile_id), "", "comparison fixture refreshes the authoritative profile", failures)
    main.set("saved_settings", settings.copy())
    TestAssertions.truthy(main.call("select_leader_class", &"fighter"), "comparison fixture starts through Main's production run path", failures)
    var context := main.get("active_run_context") as PlayerRunContext
    var registry := main.get("ground_item_registry") as GroundItemRegistry
    var world := main.get("ground_item_world_controller") as Node
    TestAssertions.truthy(context != null and registry != null and world != null, "Main owns the complete live-loot comparison graph", failures)
    if context == null or registry == null or world == null:
        _cleanup_main(main)
        return
    var equipped_request := ItemGenerationRequest.create(82001, 0, 20, &"ordinary_enemy", &"ordinary_drop", [&"common"])
    equipped_request.forced_base_id = &"windrunner_band"
    equipped_request.forced_rarity_id = &"common"
    var equipped_generation := context.issue_ground_item(equipped_request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
    var equipped := equipped_generation.item if equipped_generation != null and equipped_generation.ok() else null
    TestAssertions.truthy(equipped != null, "comparison fixture generates the equipped item through the production issuer", failures)
    if equipped == null:
        _cleanup_main(main)
        return
    TestAssertions.truthy(context.collect_ground_item(equipped.instance_id, "main-live-collect-equipped", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).ok(), "comparison fixture collects the equipped item through the owner transaction boundary", failures)
    TestAssertions.truthy(context.assign_equipment(1, equipped.instance_id, &"ring_left", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).ok(), "comparison fixture equips the leader through the production assignment service", failures)
    var candidate_request := ItemGenerationRequest.create(82002, 1, 20, &"ordinary_enemy", &"ordinary_drop", [&"common"])
    candidate_request.forced_base_id = &"windrunner_band"
    candidate_request.forced_rarity_id = &"common"
    var candidate_generation := context.issue_ground_item(candidate_request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
    var candidate := candidate_generation.item if candidate_generation != null and candidate_generation.ok() else null
    TestAssertions.truthy(candidate != null, "comparison fixture creates the candidate in the owner ground container", failures)
    if candidate == null:
        _cleanup_main(main)
        return
    var record := GroundItemRecord.new()
    record.drop_id = &"main-live-comparison"
    record.item_id = candidate.instance_id
    record.run_player_id = context.run_player_id
    record.profile_id = context.profile_id
    record.player_number = 1
    record.color_id = &"red"
    record.world_position = main.leader.position + Vector3(1.0, 0.0, 0.0)
    record.rarity_id = candidate.rarity_id
    record.source_id = &"ordinary_enemy"
    record.ground_slot = 0
    TestAssertions.truthy(registry.add(record), "comparison fixture registers the canonical owner ground record", failures)
    var details := world.get("_detail_by_drop") as Dictionary
    TestAssertions.truthy(details.has(record.drop_id) and not (details[record.drop_id] as Dictionary).has("owner_leader_equipment"), "Main item detail has no synthetic test-only equipment field", failures)
    var chest := (world.get("_chest_by_drop") as Dictionary).get(record.drop_id) as Node3D
    TestAssertions.truthy(chest != null, "Main projects the owner candidate through its real world controller", failures)
    if chest != null:
        (chest.call(&"tooltip_anchor") as Control).mouse_entered.emit()
        var tooltip := main.get_node("GroundItemTooltipLayer/ItemTooltipPanel") as ItemTooltipPanel
        tooltip.set_compare_active(true)
        TestAssertions.equal(tooltip.card_count(), 2, "Main Alt/LT comparison presents one inspected and one applicable equipped card", failures)
        if tooltip.card_count() >= 2:
            TestAssertions.equal(String(tooltip.get_node("Layout/BodyScroll/Cards").get_child(1).call(&"displayed_instance_id")), equipped.instance_id, "Main comparison card uses the owner leader's current applicable item", failures)
    _cleanup_main(main)

func _test_gameplay_input_blocked_predicate(failures: Array[String]) -> void:
    var main := _started_main()
    TestAssertions.truthy(main.has_method(&"_gameplay_input_blocked"), "Main exposes one central production gameplay-input blocker", failures)
    if not main.has_method(&"_gameplay_input_blocked"):
        _cleanup_main(main)
        return
    TestAssertions.truthy(not bool(main.call(&"_gameplay_input_blocked")), "running gameplay accepts world interaction", failures)
    var ledger := main.get_node("CharacterLedger") as CharacterLedger
    TestAssertions.truthy(ledger.open_for_player() and bool(main.call(&"_gameplay_input_blocked")), "actual open ledger blocks gameplay input", failures)
    ledger.close()
    var pause := main.get_node("RunPauseMenu") as RunPauseMenu
    TestAssertions.truthy(pause.open() and bool(main.call(&"_gameplay_input_blocked")), "actual pause menu blocks gameplay input", failures)
    pause.close()
    var settings := main.get_node("SettingsScreen") as SettingsScreen
    settings.open()
    TestAssertions.truthy(bool(main.call(&"_gameplay_input_blocked")), "actual settings screen blocks gameplay input", failures)
    settings.close()
    var warehouse_dialog: Variant = main.get_node("WarehouseLockedDialog")
    warehouse_dialog.call("open", WAREHOUSE_LOCKED_DIALOG.Guidance.PROLOGUE_REQUIRED, null)
    TestAssertions.truthy(bool(main.call(&"_gameplay_input_blocked")), "actual Warehouse guidance blocks gameplay input", failures)
    warehouse_dialog.close()
    TestAssertions.truthy(not bool(main.call(&"_gameplay_input_blocked")), "closing Warehouse guidance restores world interaction", failures)
    var run := main.get_node("GameRun") as GameRun
    run.begin_level_up()
    TestAssertions.truthy(bool(main.call(&"_gameplay_input_blocked")), "actual upgrade-selection run state blocks gameplay input", failures)
    run.resume_run()
    TestAssertions.truthy(not bool(main.call(&"_gameplay_input_blocked")), "resumed running state restores world interaction", failures)
    _cleanup_main(main)

func _test_typed_live_loot_diagnostic_accounting(failures: Array[String]) -> void:
    var settings := PartyForgeSettings.new()
    settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    settings.unlock_all_implemented_content = true
    settings.show_ground_chest_diagnostics = true
    var main := _started_main_with_settings(settings)
    main.call(&"_record_personal_loot_report", {
        "decisions": [
            _loot_decision(true, true, &"roll_succeeded", &"ordinary_melee"),
            _loot_decision(true, false, &"roll_failed", &"ordinary_specialist"),
            _loot_decision(false, false, &"feature_locked", &"ordinary_melee"),
            _loot_decision(false, false, &"leader_out_of_range", &"ordinary_specialist"),
            _loot_decision(false, false, &"leader_unavailable", &"elite"),
        ],
        "diagnostics": [
            {"stage": &"generation", "code": &"no_candidate"},
            {"stage": &"storage", "code": &"ground_full"},
            {"stage": &"ownership", "code": &"context_missing"},
            {"stage": &"configuration", "code": &"invalid_event"},
        ],
    })
    var diagnostics := main.get("_ground_chest_diagnostics") as Dictionary
    TestAssertions.equal(int(diagnostics.get("generation_failures", -1)), 1, "generation failure count excludes storage, ownership, and configuration diagnostics", failures)
    TestAssertions.equal(diagnostics.get("diagnostics_by_stage", {}), {"configuration": 1, "generation": 1, "ownership": 1, "storage": 1}, "typed diagnostics retain separate stable stage categories", failures)
    TestAssertions.equal(diagnostics.get("diagnostics_by_code", {}), {"context_missing": 1, "ground_full": 1, "invalid_event": 1, "no_candidate": 1}, "typed diagnostics retain separate stable codes", failures)
    TestAssertions.equal(diagnostics.get("successes_by_source", {}), {"ordinary_melee": 1}, "successful eligible rolls retain their source category", failures)
    TestAssertions.equal(diagnostics.get("misses_by_source", {}), {"ordinary_specialist": 1}, "ROLL MISS counts only eligible failed rolls", failures)
    TestAssertions.equal(int(diagnostics.get("ineligible_total", -1)), 3, "ineligible decisions are counted separately from misses", failures)
    TestAssertions.equal(diagnostics.get("ineligible_by_reason", {}), {"feature_locked": 1, "leader_out_of_range": 1, "leader_unavailable": 1}, "ineligible decisions retain stable reasons", failures)
    TestAssertions.equal(diagnostics.get("ineligible_by_source", {}), {"elite": 1, "ordinary_melee": 1, "ordinary_specialist": 1}, "ineligible decisions retain source categories", failures)
    TestAssertions.truthy(int(diagnostics.get("projection_limit", 0)) > 0 and diagnostics.has("projection_pending") and diagnostics.has("projection_last_work") and diagnostics.has("projection_peak_work"), "Main consumes production runtime projection diagnostics", failures)
    TestAssertions.truthy((main.get_node("DeveloperModeBadge") as DeveloperModeBadge).diagnostics_text().contains("PROJECTION pending="), "Developer badge presents Main-consumed runtime projection diagnostics", failures)
    _cleanup_main(main)

func _loot_decision(eligible: bool, success: bool, reason: StringName, source: StringName) -> PersonalLootDecision:
    var decision := PersonalLootDecision.new()
    decision.eligible = eligible
    decision.success = success
    decision.reason = reason
    decision.source_category = source
    return decision

func _test_main_menu_route_composition(failures: Array[String]) -> void:
    var root := "user://tests/main-wiring-menu-routes_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(root)
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
    main.profile_root = root
    (Engine.get_main_loop() as SceneTree).root.add_child(main)
    main.call("_ready")
    var menu := main.get_node_or_null("MainMenuScreen") as MainMenuScreen
    var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
    var settings := main.get_node("SettingsScreen") as SettingsScreen
    var recovery := main.get_node_or_null("RunRecoveryDialog")
    TestAssertions.truthy(menu != null, "route composition owns MainMenuScreen", failures)
    if menu == null:
        main.free()
        ProfileTestSupport.remove_tree(root)
        return
    TestAssertions.truthy(menu.route_requested.is_connected(Callable(main, "_on_main_menu_route_requested")), "main owns the menu route dispatcher", failures)
    TestAssertions.truthy(recovery != null, "main composes the dedicated run recovery dialog", failures)
    if recovery != null:
        TestAssertions.truthy(recovery.resume_requested.is_connected(Callable(main, "_on_run_recovery_resume_requested")), "main owns durable resume intent", failures)
        TestAssertions.truthy(recovery.legacy_class_requested.is_connected(Callable(main, "_on_run_recovery_legacy_class_requested")), "main owns legacy class binding intent", failures)
        TestAssertions.truthy(recovery.abandon_requested.is_connected(Callable(main, "_on_run_recovery_abandon_requested")), "main owns strict abandonment intent", failures)
        TestAssertions.truthy(recovery.cancelled.is_connected(Callable(main, "_on_run_recovery_cancelled")), "main owns recovery cancellation intent", failures)
    TestAssertions.truthy(main.profile_manager.profiles_changed.is_connected(Callable(main, "_on_profiles_changed")), "profile-list changes refresh the menu projection", failures)
    TestAssertions.truthy(main.profile_manager.active_profile_changed.is_connected(Callable(main, "_on_active_profile_changed")), "active-profile changes refresh the menu projection", failures)
    TestAssertions.truthy(settings.settings_applied.is_connected(Callable(main, "_on_settings_applied")), "applied settings refresh the menu projection", failures)
    TestAssertions.truthy(main.has_method("_on_prologue_start_requested"), "main exposes a named temporary prologue-start handler", failures)
    TestAssertions.truthy(main.has_method("_on_prologue_resume_requested"), "main exposes a named temporary prologue-resume handler", failures)
    TestAssertions.truthy(main.has_method("_on_developer_quick_start_requested"), "main exposes one dedicated Developer Quick Start handler", failures)
    TestAssertions.truthy(menu.route_requested.is_connected(Callable(main, "_on_main_menu_route_requested")), "main connects menu routes exactly through composition", failures)
    TestAssertions.truthy(not menu.route_requested.is_connected(Callable(main, "_quit")), "menu route signal does not bypass the route dispatcher", failures)
    var result_panel := main.get_node("HUD/RunResultPanel") as RunResultPanel
    TestAssertions.truthy(result_panel.restart_run_requested.is_connected(Callable(main, "_on_restart_run_requested")), "result panel routes Restart Run through its distinct terminal handler", failures)
    TestAssertions.truthy(result_panel.return_to_forge_requested.is_connected(Callable(main, "_on_return_to_forge_requested")), "result panel routes Return to Forge through its distinct terminal handler", failures)
    TestAssertions.truthy(result_panel.open_armoury_requested.is_connected(Callable(main, "_on_terminal_open_armoury_requested")), "result panel routes Open Armoury through terminal recovery", failures)
    TestAssertions.truthy(result_panel.quit_application_requested.is_connected(Callable(main, "_on_quit_application_requested")), "result panel routes Quit Application through its distinct terminal handler", failures)
    TestAssertions.truthy(result_panel.retry_terminal_refresh_requested.is_connected(Callable(main, "_on_retry_terminal_refresh_requested")), "result panel routes committed initial refresh through its refresh-only handler", failures)
    var created := main.profile_manager.create_profile("Route Tester")
    TestAssertions.truthy(created.ok(), "route fixture creates an active profile", failures)
    var initial_state := main.active_profile().prologue_state
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_PROLOGUE_START)
    TestAssertions.truthy(selector.is_open() and not menu.is_open(), "prologue start opens run setup", failures)
    TestAssertions.equal(main.active_profile().prologue_state, initial_state, "prologue start leaves durable state unchanged", failures)
    selector.back_requested.emit()
    TestAssertions.truthy(menu.is_open() and not selector.is_open(), "run-setup Back returns to the main menu", failures)
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_PROLOGUE_RESUME)
    TestAssertions.truthy(selector.is_open(), "prologue resume opens the same run setup", failures)
    TestAssertions.equal(main.active_profile().prologue_state, initial_state, "prologue resume leaves durable state unchanged", failures)
    selector.back_requested.emit()
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_RUN_SETUP)
    TestAssertions.truthy(selector.is_open(), "run_setup opens the same class-selection destination", failures)
    selector.settings_requested.emit()
    TestAssertions.truthy(settings.is_open(), "run-setup Settings opens Settings", failures)
    settings.close()
    selector.back_requested.emit()
    TestAssertions.truthy(not main.run_started and main.leader == null, "front-end route traversal never starts gameplay", failures)
    main.free()
    ProfileTestSupport.remove_tree(root)


func _test_lobby_start_failure_routing(failures: Array[String]) -> void:
    var root := "user://tests/main-wiring-lobby-failure_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
    main.profile_root = root
    main.settings_path = root.path_join("party_forge_settings.cfg")
    (Engine.get_main_loop() as SceneTree).root.add_child(main)
    main.call("_ready")
    var created := main.profile_manager.create_profile("Lobby Failure")
    TestAssertions.truthy(created.ok(), "lobby failure fixture creates a profile", failures)
    main.call("_open_run_setup")
    var lobby := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
    main.call("_on_lobby_class_selection_requested", &"fighter")
    main.set("catalog_valid", false)
    main.call("_on_lobby_start_requested", &"fighter")
    var failed_projection := lobby.get("_projection") as RunSetupLobbyProjection
    TestAssertions.truthy(lobby.is_open(), "ordinary start failure keeps the lobby authoritative", failures)
    TestAssertions.equal(failed_projection.state, RunSetupLobbyProjection.State.ERROR, "ordinary start failure presents ERROR state", failures)
    TestAssertions.equal(failed_projection.status_copy, "Unable to start run.", "ordinary start failure presents safe player copy", failures)

    main.set("catalog_valid", true)
    var profile_id := main.active_profile().profile_id
    var deleted := main.profile_manager.delete_profile(profile_id)
    TestAssertions.truthy(deleted.ok(), "stale-selection fixture deletes the final active profile", failures)
    TestAssertions.equal(main.active_profile(), null, "stale-selection fixture has no active profile", failures)
    main.set("_selected_lobby_class_id", &"fighter")
    main.set("_previewed_lobby_class_id", &"fighter")
    main.call("_on_lobby_start_requested", &"fighter")
    var settings := main.get_node("SettingsScreen") as SettingsScreen
    TestAssertions.truthy(settings.is_open(), "no-profile Start reroutes to Profiles", failures)
    TestAssertions.truthy(not lobby.is_open(), "no-profile Start does not reopen stale lobby over Profiles", failures)
    main.free()
    ProfileTestSupport.remove_tree(root)


func _test_armoury_return_authority(failures: Array[String]) -> void:
    var root := "user://tests/main-wiring-armoury-return_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
    main.profile_root = root
    main.settings_path = root.path_join("party_forge_settings.cfg")
    (Engine.get_main_loop() as SceneTree).root.add_child(main)
    main.call("_ready")
    var created := main.profile_manager.create_profile("Armoury Return")
    TestAssertions.truthy(created.ok(), "Armoury return fixture creates a profile", failures)
    var completed := ProfileMutationService.new(ProfileStore.new()).complete_prologue(created.profile.profile_id, "task-8-armoury-return", root)
    TestAssertions.truthy(completed.ok(), "Armoury return fixture completes prologue", failures)
    TestAssertions.equal(main.profile_manager.refresh_profile(created.profile.profile_id), "", "Armoury return fixture refreshes profile", failures)
    var developer_settings := PartyForgeSettings.new()
    developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    TestAssertions.equal(PartyForgeSettingsStore.new().save_settings(developer_settings, main.settings_path), "", "Armoury return fixture saves developer route access", failures)
    main.call("_refresh_main_menu_projection")

    var menu := main.get_node("MainMenuScreen") as MainMenuScreen
    var menu_origin := menu.get_node("Armoury") as Control
    menu.set("_last_route_origin", menu_origin)
    main.call("_open_storage_route", MainMenuViewModel.ROUTE_ARMOURY)
    TestAssertions.equal(main.get("_storage_return_focus"), null, "Main-menu Armoury does not use Warehouse return authority", failures)
    TestAssertions.equal(main.get("_lobby_return_focus"), menu_origin, "Main-menu Armoury stores its exact enum-backed origin", failures)
    main.call("_on_armoury_closed")
    TestAssertions.truthy(menu.is_open(), "Main-menu Armoury returns to menu", failures)
    TestAssertions.equal(main.get("_lobby_return_context"), PartyForgeMain.LobbyReturnContext.MAIN_MENU, "Main-menu Armoury clears return context", failures)
    TestAssertions.equal(main.get("_lobby_return_focus"), null, "Main-menu Armoury clears return focus", failures)

    main.call("_open_run_setup")
    var lobby := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
    main.call("_on_lobby_class_selection_requested", &"fighter")
    var armoury_origin := lobby.action_focus(&"armoury")
    main.call("_on_lobby_armoury_requested", &"fighter")
    TestAssertions.equal(main.get("_storage_return_focus"), null, "Lobby Armoury does not use Warehouse return authority", failures)
    main.call("_on_armoury_closed")
    TestAssertions.truthy(lobby.is_open(), "Lobby Armoury returns to lobby", failures)
    var focus := (Engine.get_main_loop() as SceneTree).root.gui_get_focus_owner()
    if focus == null:
        focus = lobby.get("_pending_initial_focus") as Control
    TestAssertions.equal(focus, armoury_origin, "Lobby Armoury restores exact Armoury action", failures)
    TestAssertions.equal(main.get("_lobby_return_focus"), null, "Lobby Armoury clears return focus", failures)

    var selected_origin := lobby.selection_focus(&"fighter")
    main.set("_lobby_return_context", PartyForgeMain.LobbyReturnContext.LOADOUT_WARNING)
    main.set("_lobby_return_focus", selected_origin)
    main.call("_on_armoury_closed")
    focus = (Engine.get_main_loop() as SceneTree).root.gui_get_focus_owner()
    if focus == null:
        focus = lobby.get("_pending_initial_focus") as Control
    TestAssertions.equal(focus, selected_origin, "warning Armoury returns to selected card", failures)
    TestAssertions.equal(main.get("_lobby_return_focus"), null, "warning Armoury clears return focus", failures)

    var quick_start := menu.get_node("DeveloperQuickStart") as Control
    main.set("_lobby_return_context", PartyForgeMain.LobbyReturnContext.DEVELOPER_QUICK_START)
    main.set("_lobby_return_focus", quick_start)
    main.call("_on_armoury_closed")
    TestAssertions.truthy(menu.is_open() and not lobby.is_open(), "Developer Quick Start Armoury returns to menu", failures)
    TestAssertions.equal(main.get("_lobby_return_context"), PartyForgeMain.LobbyReturnContext.MAIN_MENU, "Developer Quick Start Armoury clears return context", failures)
    TestAssertions.equal(main.get("_lobby_return_focus"), null, "Developer Quick Start Armoury clears return focus", failures)
    main.free()
    ProfileTestSupport.remove_tree(root)


func _test_profile_deletion_and_activation_separation(failures: Array[String]) -> void:
    var root := "user://tests/main-wiring-profile-deletion_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    var settings_path := "user://tests/main-wiring-profile-deletion-settings_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(root)
    _cleanup_settings_artifacts(settings_path)
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
    main.profile_root = root
    main.settings_path = settings_path
    (Engine.get_main_loop() as SceneTree).root.add_child(main)
    main.call("_ready")
    var manager := main.profile_manager as ProfileManager
    TestAssertions.truthy(manager.create_profile("Deletion Alpha", 1000).ok(), "Main deletion fixture creates replacement profile", failures)
    TestAssertions.truthy(manager.create_profile("Deletion Beta", 2000).ok(), "Main deletion fixture creates active profile", failures)
    var settings := main.get_node("SettingsScreen") as SettingsScreen
    var profiles := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
    profiles.call("_ready")
    settings.call("_ready")
    var list := profiles.get_node("Layout/ProfileList") as ItemList
    var delete := profiles.get_node("Layout/DeleteProfile") as Button
    var confirmation := profiles.get_node("DeleteConfirmation") as ConfirmationDialog
    var return_focus := Button.new()
    return_focus.text = "Deletion return"
    main.add_child(return_focus)
    settings.open_profiles(return_focus)
    var beta_index := _profile_list_index(list, "Deletion Beta")
    list.select(beta_index)
    list.item_selected.emit(beta_index)
    delete.pressed.emit()
    confirmation.hide()
    confirmation.confirmed.emit()
    TestAssertions.truthy(settings.is_open(), "active profile deletion keeps Settings open", failures)
    TestAssertions.equal(manager.profiles().size(), 1, "Main deletion regression commits exactly one profile deletion", failures)
    TestAssertions.equal(manager.active_profile().display_name, "Deletion Alpha", "Main deletion regression activates the replacement profile", failures)
    TestAssertions.equal(_selected_profile_list_id(list), manager.active_profile().profile_id, "active deletion selects the authoritative replacement profile", failures)
    TestAssertions.truthy(list.focus_mode != Control.FOCUS_NONE, "active deletion retains a focusable replacement row in Main", failures)
    TestAssertions.truthy(not bool(main.get("_profile_deletion_in_progress")), "committed Main deletion clears the suppression flag", failures)
    TestAssertions.truthy(manager.create_profile("Deletion Gamma", 3000).ok(), "Main activation fixture creates another profile", failures)
    settings.open_profiles(return_focus)
    var alpha_index := _profile_list_index(list, "Deletion Alpha")
    list.select(alpha_index)
    list.item_selected.emit(alpha_index)
    (profiles.get_node("Layout/Activate") as Button).pressed.emit()
    TestAssertions.truthy(not settings.is_open(), "explicit Activate retains the existing Settings-close behavior", failures)
    TestAssertions.equal(manager.active_profile().display_name, "Deletion Alpha", "explicit Activate changes the authoritative active profile", failures)
    main.free()
    ProfileTestSupport.remove_tree(root)
    _cleanup_settings_artifacts(settings_path)


func _profile_list_index(list: ItemList, text_fragment: String) -> int:
    for index: int in range(list.item_count):
        if list.get_item_text(index).contains(text_fragment):
            return index
    return -1


func _selected_profile_list_id(list: ItemList) -> String:
    var selected := list.get_selected_items()
    return "" if selected.is_empty() else String(list.get_item_metadata(selected[0]))

func _test_passive_tree_route_composition(failures: Array[String]) -> void:
    var root := "user://tests/main_wiring-passive-tree_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(root)
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
    main.set("profile_root", root)
    (Engine.get_main_loop() as SceneTree).root.add_child(main)
    main.call("_ready")
    var settings := main.get_node("SettingsScreen") as SettingsScreen
    var menu := main.get_node("MainMenuScreen") as MainMenuScreen
    var city_button := menu.get_node("CityTree") as Button
    var menu_settings_button := menu.get_node("Settings") as Button
    var additional := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as AdditionalSettingsPage
    var open_city_button := additional.get_node("Layout/Scroll/Fields/OpenCityPassiveTree") as Button
    var mode := additional.get_node("Layout/Scroll/Fields/Mode") as OptionButton
    var tree_screen := main.get_node_or_null("PassiveTreeScreen") as PassiveTreeScreen
    TestAssertions.truthy(tree_screen != null, "main composes the reusable PassiveTreeScreen", failures)
    var has_definition := _has_property(main, &"passive_tree_definition")
    TestAssertions.truthy(has_definition, "main exposes one loaded passive tree definition", failures)
    if has_definition:
        TestAssertions.truthy(main.get("passive_tree_definition") != null, "main loads the validated City tree once at bootstrap", failures)
    TestAssertions.equal(_method_arg_count(main, &"_open_city_passive_tree"), 3, "main exposes one City route with context, origin, and return control", failures)
    TestAssertions.truthy(settings.has_method(&"open_additional"), "Settings exposes Additional-tab resume routing", failures)
    TestAssertions.truthy(settings.has_method(&"show_route_status"), "Settings exposes a player-facing child-route status contract", failures)
    TestAssertions.truthy(settings.has_signal(&"city_tree_requested"), "Settings forwards City tree requests", failures)

    var created := main.profile_manager.create_profile("City Route Tester", 1000)
    TestAssertions.truthy(created.ok(), "City route fixture creates an active profile", failures)
    var player_unlock_all := PartyForgeSettings.new()
    player_unlock_all.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
    player_unlock_all.unlock_all_implemented_content = true
    _apply_settings(main, player_unlock_all)
    settings.configure(main.settings_store, player_unlock_all, main.profile_manager)
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_CITY_TREE)
    TestAssertions.truthy(not tree_screen.is_open(), "Player Mode Unlock All cannot bypass durable City authorization", failures)
    TestAssertions.equal((menu.get_node("Status") as Label).text, CITY_LOCKED_STATUS, "normal authorization denial is player-facing at the menu", failures)

    var developer_settings := PartyForgeSettings.new()
    developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    _apply_settings(main, developer_settings)
    settings.configure(main.settings_store, developer_settings, main.profile_manager)
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_CITY_TREE)
    TestAssertions.truthy(tree_screen.is_open() and not menu.is_open(), "Developer Mode menu preview requires only an active profile and closes the menu", failures)
    TestAssertions.equal(tree_screen.get("_developer_context"), true, "Developer Mode menu route preserves preview context", failures)
    tree_screen.close()
    _apply_settings(main, player_unlock_all)
    settings.configure(main.settings_store, player_unlock_all, main.profile_manager)

    var profile_id := created.profile.profile_id if created.ok() else ""
    var profile_mutations := ProfileMutationService.new(ProfileStore.new())
    var completed := profile_mutations.complete_prologue(profile_id, "main-wiring-city-complete", root)
    TestAssertions.truthy(completed.ok(), "normal City route fixture completes the prologue durably", failures)
    TestAssertions.equal(main.profile_manager.refresh_profile(profile_id), "", "normal City route fixture refreshes discovered City state", failures)
    TestAssertions.truthy(main.active_profile().prologue_state == ProfileState.PrologueState.COMPLETED and CITY_TREE_ID in main.active_profile().discovered_trees, "normal City authorization uses completed durable profile state", failures)
    main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_CITY_TREE)
    TestAssertions.truthy(tree_screen.is_open() and not menu.is_open(), "authorized menu City route closes the menu and opens the tree", failures)
    TestAssertions.equal(tree_screen.get("_developer_context"), false, "menu City route configures production progression context", failures)
    TestAssertions.equal(tree_screen.get("_profiles"), main.profile_manager, "production City route uses the composed profile manager", failures)
    TestAssertions.truthy(tree_screen.tree_closed.is_connected(Callable(main, "_on_city_passive_tree_closed")), "main listens for City tree close exactly once", failures)
    tree_screen.close()
    TestAssertions.truthy(menu.is_open() and not settings.is_open(), "closing production City returns only to the menu", failures)

    var original_tree_id := main.passive_tree_definition.id
    main.passive_tree_definition.id = &"wrong-city-tree"
    main.call("_refresh_main_menu_projection")
    TestAssertions.truthy(menu.projection().city_tree_visible and not menu.projection().city_tree_enabled, "wrong City tree ID cannot advertise an enabled returning-menu route", failures)
    main.passive_tree_definition.id = original_tree_id
    var original_mutation_service := main.passive_tree_mutations
    main.passive_tree_mutations = null
    main.call("_refresh_main_menu_projection")
    TestAssertions.truthy(menu.projection().city_tree_visible and not menu.projection().city_tree_enabled, "partial City runtime cannot advertise an enabled returning-menu route", failures)
    main.passive_tree_mutations = original_mutation_service
    main.call("_refresh_main_menu_projection")
    TestAssertions.truthy(menu.projection().city_tree_enabled, "restored complete City runtime re-enables the durable route", failures)

    _apply_settings(main, developer_settings)
    settings.configure(main.settings_store, developer_settings, main.profile_manager)
    settings.open_additional(menu_settings_button)
    settings.call("_on_city_tree_requested", true)
    TestAssertions.truthy(tree_screen.is_open() and not settings.is_open(), "saved Developer Mode opens the City preview from Additional Settings", failures)
    TestAssertions.equal(tree_screen.get("_developer_context"), true, "Additional Settings configures developer preview context", failures)
    var menu_projection_before_refresh := menu.get("_projection") as MainMenuProjection
    main.profile_manager.profiles_changed.emit()
    TestAssertions.truthy(tree_screen.is_open(), "profile projection refresh leaves the passive-tree child open", failures)
    TestAssertions.truthy(menu.get("_projection") != menu_projection_before_refresh, "profile refresh updates the parent-menu projection while the passive-tree child remains open", failures)
    tree_screen.close()
    TestAssertions.truthy(settings.is_open(), "closing Developer City preview resumes Settings", failures)
    TestAssertions.equal((settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer).get_tab_control((settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer).current_tab), additional, "closing Developer City preview restores Additional Settings tab", failures)

    settings.close()
    _apply_settings(main, player_unlock_all)
    settings.configure(main.settings_store, player_unlock_all, main.profile_manager)
    settings.open_additional(menu_settings_button)
    mode.selected = PartyForgeSettings.Mode.DEVELOPER_MODE
    additional.call("_on_mode_changed", PartyForgeSettings.Mode.DEVELOPER_MODE)
    settings.call("_on_city_tree_requested", true)
    TestAssertions.truthy(not tree_screen.is_open() and settings.is_open(), "unsaved Developer draft cannot authorize a preview", failures)
    TestAssertions.equal((settings.get_node("Overlay/Frame/Layout/Status") as Label).text, CITY_DEVELOPER_REQUIRED_STATUS, "saved-mode denial is player-facing in Settings", failures)

    settings.close()
    _apply_settings(main, developer_settings)
    settings.configure(main.settings_store, developer_settings, main.profile_manager)
    settings.open_additional(menu_settings_button)
    var original_definition := main.passive_tree_definition
    main.passive_tree_definition = null
    settings.call("_on_city_tree_requested", true)
    TestAssertions.truthy(not tree_screen.is_open() and settings.is_open(), "unavailable City catalog never opens a half-configured preview", failures)
    TestAssertions.equal((settings.get_node("Overlay/Frame/Layout/Status") as Label).text, CITY_UNAVAILABLE_STATUS, "unavailable preview reports at Additional Settings", failures)
    main.passive_tree_definition = original_definition
    settings.close()
    main.free()
    ProfileTestSupport.remove_tree(root)

func _has_property(object: Object, property_name: StringName) -> bool:
    for property: Dictionary in object.get_property_list():
        if StringName(property.get("name", "")) == property_name:
            return true
    return false

func _method_arg_count(object: Object, method_name: StringName) -> int:
    for method: Dictionary in object.get_method_list():
        if StringName(method.get("name", "")) == method_name:
            return (method.get("args", []) as Array).size()
    return -1

func _test_settings_and_next_run_snapshot_wiring(failures: Array[String]) -> void:
    var settings_path := "user://tests/main_wiring-settings-fixture_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
    _cleanup_settings_artifacts(settings_path)
    var store := PartyForgeSettingsStore.new()
    var player_settings := PartyForgeSettings.new()
    player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
    player_settings.god_mode = true
    TestAssertions.equal(store.save_settings(player_settings, settings_path), "", "Player Simulation fixture saves", failures)
    var player_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(player_main, settings_path)
    var selector := player_main.get_node("HUD/ClassSelection") as ClassSelectionPanel
    var settings_screen := player_main.get_node("SettingsScreen") as SettingsScreen
    selector.settings_requested.emit()
    TestAssertions.truthy(settings_screen.is_open(), "front-end Settings request opens Settings", failures)
    var previous_events := InputMap.action_get_events(&"settings_previous_tab")
    var next_events := InputMap.action_get_events(&"settings_next_tab")
    TestAssertions.truthy(previous_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER), "controller left bumper maps to previous Settings tab", failures)
    TestAssertions.truthy(next_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER), "controller right bumper maps to next Settings tab", failures)
    settings_screen.close()
    TestAssertions.truthy(player_main.call("select_leader_class", &"fighter"), "Player Simulation fixture starts", failures)
    var player_rules := player_main.get("active_run_rules") as RunRulesSnapshot
    TestAssertions.truthy(player_rules != null, "main owns an active run snapshot", failures)
    if player_rules != null:
        TestAssertions.truthy(not player_rules.god_mode(), "Player Simulation cannot activate retained God Mode", failures)
        TestAssertions.equal(player_rules.party_capacity(), 4, "Player Simulation retains production capacity", failures)
    _cleanup_main(player_main)

    var developer_settings := PartyForgeSettings.new()
    developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    developer_settings.party_capacity_override = 9
    developer_settings.experience_multiplier_percent = 150
    TestAssertions.equal(store.save_settings(developer_settings, settings_path), "", "Developer Mode fixture saves", failures)
    var developer_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(developer_main, settings_path)
    TestAssertions.truthy(developer_main.call("select_leader_class", &"fighter"), "Developer Mode fixture starts", failures)
    var active_rules := developer_main.get("active_run_rules") as RunRulesSnapshot
    var saved_settings := developer_main.get("saved_settings") as PartyForgeSettings
    var experience_system := developer_main.get_node("ExperienceSystem") as ExperienceSystem
    TestAssertions.truthy(active_rules != null and saved_settings != null, "main owns saved settings and active rules separately", failures)
    if active_rules != null and saved_settings != null:
        TestAssertions.equal(active_rules.party_capacity(), 9, "run snapshot captures Developer Mode capacity", failures)
        TestAssertions.equal((developer_main.get_node("PartyManager") as PartyManager).capacity(), 9, "run start configures PartyManager capacity", failures)
        TestAssertions.equal(active_rules.experience_multiplier_percent(), 150, "run snapshot captures XP multiplier", failures)
        TestAssertions.near(experience_system.experience_multiplier, 1.5, 0.001, "run start configures ExperienceSystem from snapshot", failures)
        saved_settings.party_capacity_override = 2
        saved_settings.experience_multiplier_percent = 300
        TestAssertions.equal(active_rules.party_capacity(), 9, "active run snapshot ignores later saved-settings mutation", failures)
        TestAssertions.equal((developer_main.get_node("PartyManager") as PartyManager).capacity(), 9, "configured manager ignores later saved-settings mutation", failures)
        TestAssertions.equal(active_rules.experience_multiplier_percent(), 150, "active run XP snapshot ignores later saved-settings mutation", failures)
        TestAssertions.near(experience_system.experience_multiplier, 1.5, 0.001, "configured ExperienceSystem ignores later saved-settings mutation", failures)
    _cleanup_main(developer_main)
    _cleanup_settings_artifacts(settings_path)

func _test_main_scene_graph(failures: Array[String]) -> void:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    for node_name: String in REQUIRED_MAIN_NODES:
        TestAssertions.truthy(main.get_node_or_null(node_name) != null, "main owns %s" % node_name, failures)
    TestAssertions.equal(main.get_node_or_null("Leader"), null, "main waits for initial class selection before creating leader", failures)
    var class_selection := main.get_node_or_null("HUD/ClassSelection") as Control
    var main_menu := main.get_node_or_null("MainMenuScreen") as CanvasLayer
    TestAssertions.truthy(main_menu != null and main_menu.layer == 5, "main composes the menu at layer 5", failures)
    TestAssertions.truthy((main.get_node("SettingsScreen") as CanvasLayer).layer == 10, "Settings remains at layer 10", failures)
    TestAssertions.truthy((main.get_node("PassiveTreeScreen") as CanvasLayer).layer == 12, "passive tree remains at layer 12", failures)
    TestAssertions.truthy((main.get_node("DeveloperItemSandbox") as CanvasLayer).layer == 14, "developer item sandbox owns layer 14", failures)
    TestAssertions.equal((main.get_node("DeveloperItemSandbox") as CanvasLayer).process_mode, Node.PROCESS_MODE_ALWAYS, "developer item sandbox always processes", failures)
    TestAssertions.truthy(class_selection != null and class_selection.visible, "scene retains reusable class selection before composition boot", failures)
    var ledger := main.get_node_or_null("CharacterLedger") as CanvasLayer
    var pause_menu := main.get_node_or_null("RunPauseMenu") as CanvasLayer
    var developer_badge := main.get_node_or_null("DeveloperModeBadge") as CanvasLayer
    TestAssertions.truthy(ledger != null and not ledger.visible, "integrated CharacterLedger starts hidden", failures)
    TestAssertions.truthy(pause_menu != null and not pause_menu.visible, "integrated RunPauseMenu starts hidden", failures)
    TestAssertions.truthy(developer_badge != null and not developer_badge.visible, "integrated Developer Mode badge starts hidden", failures)
    if developer_badge != null and ledger != null and pause_menu != null:
        TestAssertions.truthy(developer_badge.layer > (main.get_node("HUD") as CanvasLayer).layer, "Developer Mode badge renders above HUD", failures)
        TestAssertions.truthy(developer_badge.layer < (main.get_node("SettingsScreen") as CanvasLayer).layer, "Developer Mode badge renders below Settings", failures)
        TestAssertions.truthy(developer_badge.layer < ledger.layer and developer_badge.layer < pause_menu.layer, "Developer Mode badge renders below run modals", failures)
        TestAssertions.truthy(main.get_node("HUD").get_index() < developer_badge.get_index(), "Developer Mode badge is layered after HUD", failures)
        TestAssertions.truthy(developer_badge.get_index() < main.get_node("SettingsScreen").get_index(), "Developer Mode badge is below Settings", failures)
        TestAssertions.truthy(developer_badge.get_index() < ledger.get_index(), "Developer Mode badge is below CharacterLedger", failures)
        TestAssertions.truthy(ledger.get_index() < pause_menu.get_index(), "RunPauseMenu is layered after CharacterLedger", failures)
    var orb := (load("res://scenes/progression/experience_orb.tscn") as PackedScene).instantiate() as ExperienceOrb
    var director := (load("res://scripts/game/spawn_director.gd") as Script).new() as SpawnDirector
    TestAssertions.equal(_method_arg_count(orb, &"configure"), 5, "orb wiring accepts packet identity and distributor", failures)
    TestAssertions.truthy(_has_property(orb, &"reward_distributor"), "orb wiring owns reward distributor", failures)
    TestAssertions.truthy(not _has_property(orb, &"experience_system"), "orb wiring has no global ExperienceSystem route", failures)
    TestAssertions.truthy(_has_property(director, &"reward_distributor"), "spawn director wiring owns reward distributor", failures)
    TestAssertions.truthy(not _has_property(director, &"experience_system"), "spawn director wiring has no global ExperienceSystem route", failures)
    orb.free()
    director.free()
    main.free()

func _test_integrated_overlay_input_and_front_end_seam(failures: Array[String]) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    tree.paused = false
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(main)
    tree.root.add_child(main)
    TestAssertions.truthy(main.call("select_leader_class", &"fighter"), "integration fixture starts an active run", failures)
    var ledger := main.get_node("CharacterLedger") as CharacterLedger
    var pause_menu := main.get_node("RunPauseMenu")
    var hud := main.get_node("HUD") as HUD
    var leader_card := hud.get_node("Margin/CombatStatus/LeaderCard") as Control
    hud.ledger_requested.emit(int(leader_card.get_meta("member_id", 0)), leader_card)
    TestAssertions.truthy(ledger.is_open() and ledger.context.selected_member_id == int(leader_card.get_meta("member_id", 0)) and ledger.context.active_page_id == &"stats", "real Main HUD signal route opens exact-member stats Ledger", failures)
    ledger.close()
    hud.inspect_requested.emit(999999, leader_card)
    var stale_feedback := hud.get_node("LootStatus") as Label
    TestAssertions.truthy(stale_feedback.visible and stale_feedback.text == "That party member is no longer available.", "real Main route reports stale-member feedback without opening a child", failures)
    TestAssertions.truthy(ledger.open_for_player(), "integrated ledger opens for the active run", failures)
    var escape := _escape_key_event()
    pause_menu.call("_unhandled_input", escape)
    ledger.call("_unhandled_input", escape)
    TestAssertions.truthy(not ledger.is_open(), "Escape closes the ledger through modal input ordering", failures)
    TestAssertions.truthy(not bool(pause_menu.visible), "same Escape does not open RunPauseMenu behind the ledger", failures)
    TestAssertions.truthy(not tree.paused, "ledger close restores the running tree exactly", failures)
    TestAssertions.truthy(main.has_method("_on_active_run_abandon_confirmed"), "main exposes the authoritative active-run Abandon seam", failures)
    TestAssertions.truthy(pause_menu.is_connected("abandon_run_confirmed", Callable(main, "_on_active_run_abandon_confirmed")), "confirmed Abandon routes through the authoritative Main handler", failures)
    var result := main.get_node("HUD/RunResultPanel") as RunResultPanel
    TestAssertions.truthy(result.quit_application_requested.is_connected(Callable(main, "_on_quit_application_requested")), "terminal Quit Application keeps its receipt-aware route", failures)
    var menu := main.get_node_or_null("MainMenuScreen") as MainMenuScreen
    TestAssertions.truthy(menu != null and menu.route_requested.is_connected(Callable(main, "_on_main_menu_route_requested")), "main-menu Quit intent remains routed through PartyForgeMain", failures)
    tree.paused = false
    main.free()

func _test_hud_collapse_preference_persistence(failures: Array[String]) -> void:
    var settings_path := "user://tests/main-wiring-hud-collapse-settings_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
    _cleanup_settings_artifacts(settings_path)
    var persisted := PartyForgeSettings.new()
    persisted.hud_party_collapsed = false
    persisted.hud_alerts_collapsed = false
    persisted.character_hud_background_opacity_percent = 73
    var fixture_store := PartyForgeSettingsStore.new()
    TestAssertions.equal(fixture_store.save_settings(persisted, settings_path), "", "HUD collapse fixture saves expanded preferences", failures)

    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(main, settings_path)
    main.saved_settings = persisted.copy()
    main.call("_wire_static_ui")
    var hud := main.get_node("HUD") as HUD
    hud.apply_collapse_preferences(true, false)
    hud.collapse_preferences_changed.emit(true, false)

    var loaded := fixture_store.load_settings(settings_path)
    TestAssertions.equal([loaded.hud_party_collapsed, loaded.hud_alerts_collapsed], [true, false], "Main persists the exact HUD collapse pair", failures)
    TestAssertions.equal([main.saved_settings.hud_party_collapsed, main.saved_settings.hud_alerts_collapsed], [true, false], "Main replaces authoritative settings after a successful HUD preference save", failures)
    TestAssertions.equal(loaded.character_hud_background_opacity_percent, 73, "HUD collapse persistence preserves unrelated opacity on disk", failures)
    TestAssertions.equal(main.saved_settings.character_hud_background_opacity_percent, 73, "HUD collapse persistence preserves unrelated authoritative opacity", failures)
    var committed_bytes := FileAccess.get_file_as_bytes(settings_path)

    var restored_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(restored_main, settings_path)
    TestAssertions.equal([restored_main.saved_settings.hud_party_collapsed, restored_main.saved_settings.hud_alerts_collapsed], [true, false], "second Main boot loads the persisted HUD collapse pair", failures)
    TestAssertions.truthy(restored_main.call("select_leader_class", &"fighter"), "second Main starts a real run from the persisted settings", failures)
    var restored_hud := restored_main.get_node("HUD") as HUD
    TestAssertions.equal([restored_hud.party_collapsed(), restored_hud.alerts_collapsed()], [true, false], "second Main restores the persisted pair into the new HUD without manual hydration", failures)
    TestAssertions.equal(int(restored_hud.get("_character_hud_background_opacity_percent")), 73, "second Main restores unrelated opacity into the new HUD", failures)
    _cleanup_main(restored_main)

    main.settings_store = PartyForgeSettingsStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE)
    hud.apply_collapse_preferences(false, true)
    var error_capture := TEST_ERROR_CAPTURE.new()
    OS.add_logger(error_capture)
    hud.collapse_preferences_changed.emit(false, true)
    OS.remove_logger(error_capture)
    var captured_errors := error_capture.drain_after_detach()
    var expected_error := "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s code=%d stage=promote" % [settings_path, ERR_CANT_CREATE]
    var captured_expected_error := false
    for message: String in captured_errors:
        captured_expected_error = captured_expected_error or expected_error in message
    TestAssertions.truthy(captured_expected_error, "failed HUD preference save publishes the exact captured diagnostic", failures)

    loaded = fixture_store.load_settings(settings_path)
    TestAssertions.equal([loaded.hud_party_collapsed, loaded.hud_alerts_collapsed], [true, false], "failed HUD preference save preserves the prior disk pair", failures)
    TestAssertions.equal(loaded.character_hud_background_opacity_percent, 73, "failed HUD preference save preserves unrelated opacity on disk", failures)
    TestAssertions.equal(FileAccess.get_file_as_bytes(settings_path), committed_bytes, "failed HUD preference save preserves the committed settings bytes", failures)
    TestAssertions.equal([main.saved_settings.hud_party_collapsed, main.saved_settings.hud_alerts_collapsed], [true, false], "failed HUD preference save preserves Main's authoritative settings", failures)
    TestAssertions.equal(main.saved_settings.character_hud_background_opacity_percent, 73, "failed HUD preference save preserves unrelated authoritative opacity", failures)
    TestAssertions.equal([hud.party_collapsed(), hud.alerts_collapsed()], [false, true], "failed HUD preference save preserves the toggled session presentation", failures)

    main.free()
    _cleanup_settings_artifacts(settings_path)

func _test_hud_contract(failures: Array[String]) -> void:
    var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
    for path: String in [
        "Margin/CombatStatus/LeaderCard", "Margin/CombatStatus/Experience", "Margin/CombatStatus/RunTime",
        "Margin/CombatStatus/PartyRegion/RichRoster",
        "Margin/CombatStatus/PartyRegion/CompactRoster/MemberWindow",
        "Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious",
        "Margin/CombatStatus/PartyRegion/CompactRoster/PageNext",
        "Margin/CombatStatus/AlertRegion/ExpandedAlerts",
        "Margin/CombatStatus/AlertRegion/Overflow",
        "Margin/CombatStatus/BossRegion", "Margin/CombatStatus/BossRegion/BossHealth", "BossBanner",
        "LootStatus",
        "CombatAlertTray", "CombatMemberInspectPanel", "LevelUpPanel", "RunResultPanel", "ClassSelection",
    ]:
        TestAssertions.truthy(hud.get_node_or_null(path) != null, "HUD exposes %s" % path, failures)
    for obsolete: String in ["Party1", "Party2", "Party3", "Party4"]:
        TestAssertions.equal(hud.find_child(obsolete, true, false), null, "fixed HUD node %s is removed" % obsolete, failures)
    TestAssertions.truthy(not (hud.get_node("Margin/CombatStatus/BossRegion") as Control).visible, "whole boss band starts hidden", failures)
    TestAssertions.truthy(not (hud.get_node("BossBanner") as Control).visible, "boss banner starts hidden", failures)
    TestAssertions.truthy(hud.has_signal("inspect_requested") and hud.has_signal("ledger_requested"), "HUD emits typed member child-route intents", failures)
    var main_source := FileAccess.get_file_as_string("res://scripts/game/main.gd")
    TestAssertions.truthy("hud.call(\"configure\", game_run, party_manager, experience_system, active_run_context, saved_settings)" in main_source, "Main uses the typed five-argument HUD composition", failures)
    TestAssertions.truthy("_on_hud_inspect_requested" in main_source and "_on_hud_ledger_requested" in main_source, "Main owns safe HUD child-route handlers", failures)
    TestAssertions.truthy("open_for_member(member_id, &\"stats\", return_focus, focus_descriptor)" in main_source, "Main opens Ledger at exact member and stats page with stable focus context", failures)
    TestAssertions.truthy("That party member is no longer available." in main_source, "vanished HUD members receive concise safe feedback", failures)
    hud.free()

func _test_exact_choice_panel(failures: Array[String]) -> void:
    var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
    var party := PartyManager.new()
    var catalog := GameCatalog.load_defaults()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var choices: Array[UpgradeChoice] = [
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage"),
        UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"mage", "Invalid Mage Rank"),
        UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger"),
    ]
    panel.call("show_choices", choices, party)
    var pending_label := panel.get_node_or_null("Frame/Content/Offer/PendingLevels") as Label
    TestAssertions.truthy(pending_label != null, "level-up panel scene exposes the pending-level indicator", failures)
    TestAssertions.truthy(panel.get_node_or_null("Choices") == null, "legacy hidden choice controls are removed", failures)
    var cards := panel.get_node("Frame/Content/Offer/CardsScroll/Cards").get_children()
    TestAssertions.equal(cards.filter(func(card: Node) -> bool: return (card as Control).visible).size(), 3, "level-up panel owns exactly three visible offer cards", failures)
    TestAssertions.equal((cards[0] as UpgradeCard).bound_choice_key(), StringName(choices[0].key()), "first card binds the stable first choice key", failures)
    TestAssertions.truthy(not (cards[0] as Button).disabled, "valid choice enabled", failures)
    TestAssertions.truthy((cards[1] as Button).disabled, "invalid choice disabled", failures)
    var selected: Array[Dictionary] = []
    panel.application_requested.connect(func(choice: UpgradeChoice, member_id: int) -> void:
        selected.append({"choice": choice, "member_id": member_id})
    )
    (cards[0] as UpgradeCard).activated.emit((cards[0] as UpgradeCard).bound_choice_key())
    (cards[0] as UpgradeCard).activated.emit((cards[0] as UpgradeCard).bound_choice_key())
    TestAssertions.equal(selected.size(), 1, "direct level-up application emits once", failures)
    TestAssertions.equal(selected[0].choice if not selected.is_empty() else null, choices[0], "panel privately resolves the exact UpgradeChoice instance", failures)
    TestAssertions.equal(selected[0].member_id if not selected.is_empty() else -1, 0, "direct level-up application invents no recipient", failures)
    TestAssertions.truthy(panel.visible and not (panel.get_node("Frame/Content/Confirmation") as Control).visible, "pending direct application stays visible and skips confirmation", failures)
    panel.free()
    party.free()

func _test_class_selection_starts_run_and_applies_choices(failures: Array[String]) -> void:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(main)
    var profile := main.call("active_profile") as ProfileState
    var prologue := ProfileMutationService.new(ProfileStore.new()).complete_prologue(profile.profile_id, "task-8-main-wiring", _profile_root)
    TestAssertions.truthy(prologue.ok(), "lobby fixture completes the profile prologue", failures)
    (main.get("profile_manager") as ProfileManager).refresh_profile(profile.profile_id)
    main.call("_open_run_setup")
    TestAssertions.equal(main.get("run_started"), false, "run timer waits at class selection", failures)
    var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
    var marksman_button := selector.selection_focus(&"marksman") as Button
    TestAssertions.truthy(marksman_button != null, "catalog selector exposes Marksman button", failures)
    if marksman_button != null:
        marksman_button.pressed.emit()
    TestAssertions.equal(main.get("run_started"), false, "class confirmation remains ephemeral", failures)
    TestAssertions.equal(selector.selected_class_id(), &"marksman", "class confirmation selects exact lobby class", failures)
    (selector.action_focus(&"start") as Button).pressed.emit()
    TestAssertions.equal(main.get("run_started"), true, "separate Start Run intent starts the run", failures)
    var game_run: Node = main.get_node("GameRun")
    TestAssertions.equal(game_run.call("current_state"), 1, "class selection starts RUNNING timer state", failures)
    var party_manager := main.get_node("PartyManager") as PartyManager
    if not party_manager.members.is_empty():
        TestAssertions.equal(party_manager.members[0].class_definition.id, &"marksman", "Marksman button starts with Marksman leader", failures)
    var spawn_director := main.get_node("SpawnDirector") as SpawnDirector
    TestAssertions.equal(game_run.get("combat_rng"), party_manager.combat_rng, "party shares the run combat RNG", failures)
    TestAssertions.equal(game_run.get("combat_rng"), spawn_director.combat_rng, "enemies share the run combat RNG", failures)
    TestAssertions.equal(spawn_director.damage_types, GameCatalog.load_defaults().damage_types, "spawn director uses the catalog damage types", failures)
    TestAssertions.truthy(main.get("leader") != null, "class selection creates configured leader", failures)

    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    _queue_leader_levels(main, 1)
    game_run.call("begin_level_up")
    var stat_choice := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"pickup_radius", "Pickup Radius")
    (main.get("party_stats") as Dictionary)[&"pickup_radius"] = 19
    main.call("_apply_choice", stat_choice)
    TestAssertions.equal(int((main.get("party_stats") as Dictionary)[&"pickup_radius"]), 20, "party stat upgrades cap at 20", failures)
    _queue_leader_levels(main, 1)
    game_run.call("begin_level_up")
    var recruit := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger")
    TestAssertions.truthy(main.call("_apply_choice", recruit), "central choice recruits valid class", failures)
    var actors := main.get_node("Actors").get_children()
    TestAssertions.equal(actors.size(), 2, "recruit choice instances one companion", failures)
    if actors.size() == 2:
        TestAssertions.equal((actors[1] as PartyActor).party_manager, main.get_node("PartyManager"), "recruited companion receives live combat manager", failures)
        TestAssertions.truthy((actors[1] as PartyActor).get_node_or_null("HealthBar3D") != null, "recruited companion receives billboard health bar", failures)
    main.free()
    (Engine.get_main_loop() as SceneTree).paused = false
    for class_id: StringName in [
        &"fighter", &"ranger", &"mage", &"cleric", &"paladin",
        &"rogue", &"frost_mage", &"warlock", &"marksman",
    ]:
        var class_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
        _prepare_main(class_main)
        TestAssertions.truthy(class_main.call("select_leader_class", class_id), "%s direct selection succeeds" % class_id, failures)
        var class_party := class_main.get_node("PartyManager") as PartyManager
        if not class_party.members.is_empty():
            TestAssertions.equal(class_party.members[0].class_definition.id, class_id, "%s direct selection uses exact leader" % class_id, failures)
        class_main.free()
        (Engine.get_main_loop() as SceneTree).paused = false

func _test_targeted_confirmation_routes_through_main(failures: Array[String]) -> void:
    var main := _started_main()
    var panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
    var handler := Callable(main, "_on_level_up_application_requested")
    TestAssertions.truthy(main.has_method("_apply_choice_for_member"), "main exposes member-targeted central apply", failures)
    TestAssertions.truthy(main.has_method("_on_level_up_application_requested"), "main exposes the unified typed application handler", failures)
    TestAssertions.truthy(panel.is_connected("application_requested", handler), "unified application request connects to central main handler", failures)
    TestAssertions.truthy(not panel.has_signal("choice_selected") and not panel.has_signal("confirmation_requested"), "legacy application signals are removed", failures)
    var health_provider: Callable = panel.get("_health_provider")
    TestAssertions.truthy(health_provider.is_valid(), "main configures live recipient health provider", failures)

    var party := main.get_node("PartyManager") as PartyManager
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    var game_run := main.get_node("GameRun") as GameRun
    _queue_leader_levels(main, 1)
    game_run.begin_level_up()
    var choice := UpgradeChoice.authored((main.get("catalog") as GameCatalog).upgrade_by_id(&"vitality"))
    var choices: Array[UpgradeChoice] = [
        choice,
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage"),
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"move_speed", "Move Speed"),
    ]
    panel.show_choices(choices, party)
    var card := panel.get_node("Frame/Content/Offer/CardsScroll/Cards/Card1") as UpgradeCard
    card.activated.emit(card.bound_choice_key())
    (panel.get_node("Frame/Content/Recipient/Content/RecipientsScroll/Rows/Member_1") as Button).pressed.emit()
    var confirm := panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button
    confirm.pressed.emit()
    confirm.pressed.emit()
    TestAssertions.equal(party.upgrade_rank(&"vitality", party.members[0].member_id), 1, "confirmation applies authored card to exact member once", failures)
    TestAssertions.equal(experience.pending_levels, 0, "successful confirmation consumes exactly one pending level", failures)
    TestAssertions.truthy(not panel.visible, "successful confirmation completes and hides selection", failures)
    TestAssertions.equal(game_run.current_state(), RunStateMachine.State.RUNNING, "successful final confirmation resumes running state", failures)
    _cleanup_main(main)

func _test_stale_target_rejects_without_consuming(failures: Array[String]) -> void:
    var main := _started_main()
    var panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
    var party := main.get_node("PartyManager") as PartyManager
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    var game_run := main.get_node("GameRun") as GameRun
    _queue_leader_levels(main, 1)
    game_run.begin_level_up()
    var choice := UpgradeChoice.authored((main.get("catalog") as GameCatalog).upgrade_by_id(&"vitality"))
    panel.show_choices([
        choice,
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage"),
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"move_speed", "Move Speed"),
    ], party)
    var card := panel.get_node("Frame/Content/Offer/CardsScroll/Cards/Card1") as UpgradeCard
    card.activated.emit(card.bound_choice_key())
    panel.call("_on_recipient_selected", choice.key(), 999)
    (panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button).pressed.emit()
    TestAssertions.equal(party.upgrade_rank(&"vitality", party.members[0].member_id), 0, "stale target applies no authored rank", failures)
    TestAssertions.equal(experience.pending_levels, 1, "stale target consumes no pending level", failures)
    TestAssertions.equal(game_run.current_state(), RunStateMachine.State.LEVEL_UP, "stale target keeps level-up paused", failures)
    TestAssertions.truthy(panel.visible, "stale target keeps selection visible", failures)
    TestAssertions.truthy(not (panel.get_node("Frame/Content/Confirmation") as Control).visible, "stale target returns to the offer view", failures)
    TestAssertions.truthy(not (panel.get_node("Frame/Content/ReadableError") as Label).text.is_empty(), "stale target displays rejection reason", failures)
    TestAssertions.equal(panel.get("_initial_focus_card"), card, "stale target rejection restores the exact initiating card", failures)
    _cleanup_main(main)

func _test_lost_run_authority_rejects_before_mutation(failures: Array[String]) -> void:
    var main := _started_main()
    var panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
    var party := main.get_node("PartyManager") as PartyManager
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    var game_run := main.get_node("GameRun") as GameRun
    _queue_leader_levels(main, 1)
    game_run.begin_level_up()
    var direct := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage")
    panel.show_choices([direct], party)
    var card := panel.get_node("Frame/Content/Offer/CardsScroll/Cards/Card1") as UpgradeCard
    var rank_before := party.party_stat_rank(&"damage")
    (main.get("active_run_context") as PlayerRunContext).release_source_refresh_coordinator()
    card.activated.emit(card.bound_choice_key())
    TestAssertions.equal(party.party_stat_rank(&"damage"), rank_before, "lost run ownership rejects before party mutation", failures)
    TestAssertions.equal(experience.pending_levels, 1, "failed pending-level authority consumes nothing", failures)
    TestAssertions.equal(game_run.current_state(), RunStateMachine.State.LEVEL_UP, "failed pending-level authority keeps LEVEL_UP", failures)
    TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused and panel.visible, "failed pending-level authority remains paused in the visible modal", failures)
    TestAssertions.truthy(not (panel.get_node("Frame/Content/ReadableError") as Label).text.is_empty(), "failed pending-level authority shows a readable rejection", failures)
    TestAssertions.equal(panel.get("_initial_focus_card"), card, "failed pending-level authority restores the initiating card", failures)
    _cleanup_main(main)

func _test_synchronous_authority_release_is_atomic(failures: Array[String]) -> void:
    var main := _started_main()
    var panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
    var party := main.get_node("PartyManager") as PartyManager
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    var game_run := main.get_node("GameRun") as GameRun
    var context := main.get("active_run_context") as PlayerRunContext
    _queue_leader_levels(main, 1)
    game_run.begin_level_up()
    var direct := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage")
    panel.show_choices([direct], party)
    var rank_before := party.party_stat_rank(&"damage")
    party.upgrades_changed.connect(func() -> void: context.release_source_refresh_coordinator(), CONNECT_ONE_SHOT)
    var card := panel.get_node("Frame/Content/Offer/CardsScroll/Cards/Card1") as UpgradeCard
    card.activated.emit(card.bound_choice_key())
    TestAssertions.equal(party.party_stat_rank(&"damage"), rank_before + 1, "synchronous authority release preserves the accepted party mutation", failures)
    TestAssertions.equal(experience.pending_levels, 0, "synchronous authority release consumes exactly one accepted pending level", failures)
    TestAssertions.equal(game_run.current_state(), RunStateMachine.State.RUNNING, "atomic accepted transaction resumes after synchronous authority release", failures)
    TestAssertions.truthy(not panel.visible, "atomic accepted transaction cannot be reported rejected after mutation", failures)
    card.activated.emit(card.bound_choice_key())
    TestAssertions.equal(party.party_stat_rank(&"damage"), rank_before + 1, "stale duplicate after synchronous release cannot mutate twice", failures)
    TestAssertions.equal(experience.pending_levels, 0, "stale duplicate after synchronous release cannot consume twice", failures)
    _cleanup_main(main)

func _test_live_member_health_provider_uses_party_membership(failures: Array[String]) -> void:
    var main := _started_main()
    TestAssertions.truthy(main.has_method("_health_for_member"), "main exposes live member health provider", failures)
    if not main.has_method("_health_for_member"):
        _cleanup_main(main)
        return
    var leader := main.get("leader") as PartyActor
    var leader_health := leader.get_node("HealthComponent") as HealthComponent
    leader_health.apply_damage(17.0)
    TestAssertions.equal(main.call("_health_for_member", 1), Vector2(leader_health.current_health, leader_health.max_health), "health provider reads live leader component", failures)

    var party := main.get("party_manager") as PartyManager
    TestAssertions.truthy(party.has_method(&"configure_capacity"), "main health provider can exercise effective party capacity", failures)
    if not party.has_method(&"configure_capacity"):
        _cleanup_main(main)
        return
    party.call("configure_capacity", PartyCapacityPolicy.new(24))
    for index: int in range(4):
        party.recruit((main.get("catalog") as GameCatalog).class_by_id(&"ranger"))

    var actors := main.get_node("Actors") as Node3D
    var catalog := main.get("catalog") as GameCatalog
    var fifth_actor: PartyActor
    for child: Node in actors.get_children():
        var actor := child as PartyActor
        if actor != null and actor.member_state != null and actor.member_state.member_id == 5:
            fifth_actor = actor
            break
    TestAssertions.truthy(fifth_actor != null, "effective-capacity fixture spawns member five", failures)
    if fifth_actor == null:
        _cleanup_main(main)
        return
    var fifth_health := fifth_actor.get_node("HealthComponent") as HealthComponent
    fifth_health.apply_damage(23.0)
    TestAssertions.equal(main.call("_health_for_member", 5), Vector2(fifth_health.current_health, fifth_health.max_health), "health provider finds a real member beyond four actors", failures)

    var stray_actor := (load("res://scenes/characters/companion.tscn") as PackedScene).instantiate() as PartyActor
    stray_actor.configure(PartyMemberState.new(99, catalog.class_by_id(&"ranger"), false, "Stray"))
    actors.add_child(stray_actor)
    actors.move_child(stray_actor, 0)
    TestAssertions.equal(main.call("_health_for_member", 99), Vector2.ZERO, "health provider rejects an actor without a PartyManager member", failures)
    TestAssertions.equal(main.call("_health_for_member", 404), Vector2.ZERO, "health provider returns zero for unknown member", failures)
    _cleanup_main(main)

func _test_ledger_health_provider_is_unbounded_and_complete(failures: Array[String]) -> void:
    var main := _started_main()
    TestAssertions.truthy(main.has_method("_ledger_health_for_member"), "main exposes ledger-specific health provider", failures)
    if not main.has_method("_ledger_health_for_member"):
        _cleanup_main(main)
        return
    var actors := main.get_node("Actors") as Node3D
    var catalog := main.get("catalog") as GameCatalog
    var exceptional_actor: PartyActor
    for member_id: int in [2, 3, 4, 99]:
        var actor := (load("res://scenes/characters/companion.tscn") as PackedScene).instantiate() as PartyActor
        actor.configure(PartyMemberState.new(member_id, catalog.class_by_id(&"ranger"), false, "Ledger %d" % member_id))
        actors.add_child(actor)
        if member_id == 99:
            exceptional_actor = actor
    var health := exceptional_actor.get_node("HealthComponent") as HealthComponent
    health.current_health = 0.0
    health.is_downed = true
    health.is_dead = true
    var row := main.call("_ledger_health_for_member", 99) as Dictionary
    TestAssertions.equal(row.get("current"), 0.0, "ledger health includes current health", failures)
    TestAssertions.equal(row.get("maximum"), health.max_health, "ledger health includes maximum health", failures)
    TestAssertions.truthy(bool(row.get("is_downed")) and bool(row.get("is_dead")), "ledger health includes downed and dead state", failures)
    TestAssertions.equal(row.get("component"), health, "ledger health includes the live component", failures)
    TestAssertions.equal(main.call("_ledger_health_for_member", 404), {}, "ledger health returns empty data for an unknown member", failures)
    _cleanup_main(main)

func _test_capped_stat_is_disabled_without_hiding(failures: Array[String]) -> void:
    var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as Control
    var method_arg_count := 0
    for method: Dictionary in panel.get_method_list():
        if method["name"] == &"show_choices":
            method_arg_count = (method["args"] as Array).size()
            break
    TestAssertions.equal(method_arg_count, 4, "choice panel accepts optional pending-level count", failures)
    var party := PartyManager.new()
    var catalog := GameCatalog.load_defaults()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var capped := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Capped Damage")
    var choices: Array[UpgradeChoice] = [
        capped,
        UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger"),
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"move_speed", "Move Speed"),
    ]
    if method_arg_count == 4:
        panel.call("show_choices", choices, party, {capped.key(): true}, 6)
        TestAssertions.equal(panel.get("_pending_level_count"), 6, "choice panel stores the pending-level count for presentation", failures)
    else:
        panel.call("show_choices", choices, party, {capped.key(): true})
    var capped_button := panel.get_node("Frame/Content/Offer/CardsScroll/Cards/Card1") as UpgradeCard
    var emitted: Array[UpgradeChoice] = []
    panel.application_requested.connect(func(choice: UpgradeChoice, _member_id: int) -> void: emitted.append(choice))
    TestAssertions.truthy(capped_button.disabled, "rank-20 party stat is invalid before selection", failures)
    capped_button.activated.emit(capped_button.bound_choice_key())
    TestAssertions.truthy(panel.visible, "invalid capped button cannot hide and strand level-up panel", failures)
    TestAssertions.equal(emitted.size(), 0, "invalid capped button cannot emit success", failures)
    var main := _started_main()
    (main.get("party_stats") as Dictionary)[&"damage"] = 20
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    _queue_leader_levels(main, 1)
    var game_run: Node = main.get_node("GameRun")
    game_run.call("begin_level_up")
    var apply_arg_count := 0
    for method: Dictionary in main.get_method_list():
        if method["name"] == &"_apply_choice":
            apply_arg_count = (method["args"] as Array).size()
            break
    TestAssertions.equal(apply_arg_count, 2, "central apply supports quiet validity regression checks", failures)
    if apply_arg_count == 2:
        TestAssertions.truthy(not main.call("_apply_choice", capped, false), "central apply reports capped stat failure", failures)
        TestAssertions.equal(experience.pending_levels, 1, "capped stat failure consumes no pending level", failures)
        TestAssertions.equal(game_run.call("current_state"), 2, "capped stat failure remains in LEVEL_UP", failures)
    var generated: Array = main.call("_generate_valid_choices", 77) as Array
    TestAssertions.equal(generated.size(), 5, "capped stat is replaced to preserve the production five-choice offer", failures)
    TestAssertions.truthy(generated.all(func(choice: UpgradeChoice) -> bool: return choice.key() != capped.key()), "generated choices exclude capped stat", failures)
    (Engine.get_main_loop() as SceneTree).paused = false
    main.free()
    panel.free(); party.free()

func _test_run_offer_seed_and_snapshot_wiring(failures: Array[String]) -> void:
    var reset_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(reset_main)
    var has_offer_state := reset_main.get_property_list().any(
        func(property: Dictionary) -> bool: return property["name"] == &"_level_up_offer_state"
    )
    TestAssertions.truthy(has_offer_state, "main owns run-local level-up offer state", failures)
    if has_offer_state:
        var prestart_state := reset_main.get("_level_up_offer_state") as LevelUpOfferState
        prestart_state.offer_sequence = 9
        prestart_state.consecutive_eligible_without_recruit = 3
        TestAssertions.truthy(reset_main.call("select_leader_class", &"fighter"), "offer-state reset fixture starts", failures)
        var run_state := reset_main.get("_level_up_offer_state") as LevelUpOfferState
        TestAssertions.truthy(run_state != prestart_state, "new run replaces pre-run offer state", failures)
        TestAssertions.equal(run_state.offer_sequence, 0, "new run resets offer sequence", failures)
        TestAssertions.equal(run_state.consecutive_eligible_without_recruit, 0, "new run resets recruit drought", failures)
    _cleanup_main(reset_main)

    var player_settings := PartyForgeSettings.new()
    player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
    player_settings.level_up_card_count = 7
    var first_main := _started_main_with_settings(player_settings)
    var first_state := LevelUpOfferState.new()
    first_state.offer_sequence = 4
    first_state.consecutive_eligible_without_recruit = 1
    first_main.set("_level_up_offer_state", first_state)
    _present_test_offer(first_main, 1771, 3)
    var first_panel := first_main.get_node("HUD/LevelUpPanel") as LevelUpPanel
    var first_keys := _choice_keys(first_panel.choices)
    TestAssertions.equal(first_panel.choices.size(), 5, "Player Simulation snapshots five level-up choices", failures)
    TestAssertions.equal(first_panel.get("_pending_level_count"), 3, "main forwards the pending-level count to the panel", failures)
    TestAssertions.equal(first_state.offer_sequence, 5, "main increments offer sequence after generation", failures)

    var repeat_main := _started_main_with_settings(player_settings)
    var repeat_state := LevelUpOfferState.new()
    repeat_state.offer_sequence = 4
    repeat_state.consecutive_eligible_without_recruit = 1
    repeat_main.set("_level_up_offer_state", repeat_state)
    _present_test_offer(repeat_main, 1771, 3)
    var repeat_keys := _choice_keys((repeat_main.get_node("HUD/LevelUpPanel") as LevelUpPanel).choices)
    TestAssertions.equal(repeat_keys, first_keys, "equivalent explicit run offer state reproduces ordered keys", failures)

    var other_seed_main := _started_main_with_settings(player_settings)
    var other_seed_state := LevelUpOfferState.new()
    other_seed_state.offer_sequence = 4
    other_seed_state.consecutive_eligible_without_recruit = 1
    other_seed_main.set("_level_up_offer_state", other_seed_state)
    _present_test_offer(other_seed_main, 7711, 3)
    var other_seed_keys := _choice_keys((other_seed_main.get_node("HUD/LevelUpPanel") as LevelUpPanel).choices)
    TestAssertions.truthy(other_seed_keys != first_keys, "different run seeds produce different ordered offer keys", failures)

    var developer_settings := PartyForgeSettings.new()
    developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
    developer_settings.level_up_card_count = 7
    var developer_main := _started_main_with_settings(developer_settings)
    _present_test_offer(developer_main, 1771)
    var developer_panel := developer_main.get_node("HUD/LevelUpPanel") as LevelUpPanel
    TestAssertions.equal(developer_panel.choices.size(), 7, "Developer Mode snapshots its seven-choice override", failures)

    _cleanup_main(first_main)
    _cleanup_main(repeat_main)
    _cleanup_main(other_seed_main)
    _cleanup_main(developer_main)


func _test_fresh_new_run_seed_reaches_committed_runtime(failures: Array[String]) -> void:
    const INJECTED_SEED := 55101
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(main)
    var seed_source: RefCounted = (load("res://scripts/run/run_seed_source.gd") as Script).new(func() -> int: return INJECTED_SEED)
    main.call(&"configure_new_run_seed_source", seed_source)
    TestAssertions.truthy(main.call("select_leader_class", &"fighter"), "normal run starts with an injected fresh seed", failures)
    TestAssertions.equal((main.get_node("GameRun") as GameRun).run_seed, INJECTED_SEED, "fresh seed reaches the active GameRun", failures)
    var profile := (main.get("profile_manager") as ProfileManager).active_profile()
    var bootstrap := ResumableRunItemCodec.decode(profile.resumable_run, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG) if profile != null else null
    TestAssertions.equal(bootstrap.run_seed if bootstrap != null else 0, INJECTED_SEED, "fresh seed is durably committed for recovery and replay", failures)
    var catalog := GameCatalog.load_defaults()
    var expected_party := PartyManager.new()
    expected_party.configure_identity(INJECTED_SEED, catalog.generic_name_pool)
    expected_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.equal((main.get("party_manager") as PartyManager).members[0].character_name, expected_party.members[0].character_name, "fresh seed reaches deterministic character naming", failures)
    expected_party.free()
    _cleanup_main(main)

func _test_queued_levels_show_fresh_production_offers(failures: Array[String]) -> void:
    var main := _started_main()
    var game_run: Node = main.get_node("GameRun")
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    var panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
    var cards := panel.get_node("Frame/Content/Offer/CardsScroll/Cards").get_children()
    TestAssertions.equal(cards.size(), 5, "production offer view owns exactly five upgrade cards", failures)
    var card_api_available := cards.size() == 5 and cards.all(
        func(card: Node) -> bool: return card is UpgradeCard and card.has_method("bound_choice_key") and not card.has_method("bound_choice")
    )
    TestAssertions.truthy(card_api_available, "production cards expose only stable typed activation keys", failures)
    if not card_api_available:
        _cleanup_main(main)
        return

    var first_requirement := experience.tuning.requirement_for_level(1)
    var second_requirement := experience.tuning.requirement_for_level(2)
    var remainder := 7
    experience.add_experience(first_requirement + second_requirement + remainder)
    TestAssertions.equal(experience.level, 3, "earned experience crosses exactly two queued levels", failures)
    TestAssertions.equal(experience.pending_levels, 2, "earned levels begin with two pending selections", failures)
    TestAssertions.equal(experience.pending_level_numbers, [2, 3], "earned-level queue preserves exact order", failures)
    TestAssertions.equal(experience.experience, remainder, "queued offers preserve excess experience", failures)
    TestAssertions.equal(game_run.call("current_state"), RunStateMachine.State.LEVEL_UP, "first earned offer pauses in LEVEL_UP", failures)
    TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "first earned offer pauses the tree", failures)

    var party := main.get_node("PartyManager") as PartyManager
    var first_offer_choices := panel.choices
    var first_offer_keys := _choice_keys(first_offer_choices)
    var first_keys := _bound_production_keys(cards)
    var first_instance_ids := _choice_instance_ids(first_offer_choices)
    TestAssertions.equal(first_offer_keys.size(), 5, "first production offer stores the snapshotted five choices", failures)
    TestAssertions.equal(first_keys, first_offer_keys.slice(0, cards.size()), "first visible cards bind stable keys in production order", failures)

    var first_card := cards[0] as UpgradeCard
    _submit_bound_offer(panel, first_card, party)
    TestAssertions.equal(experience.pending_levels, 1, "first production confirmation consumes pending 2 to 1 exactly", failures)
    TestAssertions.equal(experience.pending_level_numbers, [3], "first production confirmation leaves only earned level 3 queued", failures)
    TestAssertions.equal(experience.experience, remainder, "first production confirmation loses no excess experience", failures)
    TestAssertions.equal(game_run.call("current_state"), RunStateMachine.State.LEVEL_UP, "first production confirmation remains paused", failures)
    TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "tree remains paused between production confirmations", failures)
    TestAssertions.truthy(bool(main.get("level_refresh_scheduled")), "second queued production offer is scheduled separately", failures)

    main.call("_present_pending_level")
    var second_offer_choices := panel.choices
    var second_offer_keys := _choice_keys(second_offer_choices)
    var second_keys := _bound_production_keys(cards)
    var second_instance_ids := _choice_instance_ids(second_offer_choices)
    TestAssertions.truthy(panel.visible, "second queued production offer is visible before confirmation", failures)
    TestAssertions.equal(second_offer_keys.size(), 5, "second production offer stores the snapshotted five choices", failures)
    TestAssertions.equal(second_keys, second_offer_keys.slice(0, cards.size()), "second visible cards bind the presentation subset in order", failures)
    TestAssertions.truthy(second_offer_keys != first_offer_keys, "run offer sequence produces a fresh second ordered offer", failures)
    TestAssertions.truthy(second_instance_ids.all(func(id: int) -> bool: return id not in first_instance_ids), "second production offer binds freshly generated choice objects", failures)

    var second_card := cards[0] as UpgradeCard
    _submit_bound_offer(panel, second_card, party)
    TestAssertions.equal(experience.pending_levels, 0, "second production confirmation consumes pending 1 to 0 exactly", failures)
    TestAssertions.equal(experience.pending_level_numbers, [], "second production confirmation empties the earned-level queue", failures)
    TestAssertions.equal(experience.experience, remainder, "both production confirmations lose no excess experience", failures)
    TestAssertions.equal(game_run.call("current_state"), RunStateMachine.State.RUNNING, "run resumes only after second production confirmation", failures)
    TestAssertions.truthy(not (Engine.get_main_loop() as SceneTree).paused, "tree resumes only after final queued confirmation", failures)
    _cleanup_main(main)

func _test_boss_level_up_resumes_boss(failures: Array[String]) -> void:
    var main := _started_main()
    var game_run: Node = main.get_node("GameRun")
    var spawn_boss_callback := Callable(main, "_spawn_boss")
    if game_run.is_connected("boss_requested", spawn_boss_callback):
        game_run.disconnect("boss_requested", spawn_boss_callback)
    game_run.call("advance_run_time", 300.0)
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    _queue_leader_levels(main, 1)
    main.call("_on_level_ready", experience.level + 1)
    TestAssertions.equal(game_run.call("current_state"), 2, "boss-phase level-up enters LEVEL_UP", failures)
    TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "boss-phase level-up pauses gameplay", failures)
    main.call("_apply_choice", UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"attack_speed", "Attack Speed"))
    TestAssertions.equal(game_run.call("current_state"), 3, "boss-phase level-up resumes BOSS", failures)
    TestAssertions.truthy(not (Engine.get_main_loop() as SceneTree).paused, "boss resume unpauses gameplay", failures)
    main.free()

func _test_catalog_gate_blocks_public_start(failures: Array[String]) -> void:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(main)
    var has_gate := false
    for property: Dictionary in main.get_property_list():
        if property["name"] == &"catalog_valid":
            has_gate = true
            break
    TestAssertions.truthy(has_gate, "main persists catalog validation gate", failures)
    if has_gate:
        main.set("catalog_valid", false)
        TestAssertions.truthy(not main.call("select_leader_class", &"fighter"), "public class selection cannot bypass failed catalog gate", failures)
        TestAssertions.equal(main.get("run_started"), false, "failed catalog gate leaves timer stopped", failures)
        TestAssertions.equal(main.get("leader"), null, "failed catalog gate creates no leader", failures)
    main.free()

func _test_result_panel_requests_once(failures: Array[String]) -> void:
    var panel := (load("res://scenes/ui/run_result_panel.tscn") as PackedScene).instantiate() as RunResultPanel
    TestAssertions.truthy(panel.has_signal(&"restart_run_requested"), "result panel exposes exact Restart Run intent", failures)
    TestAssertions.truthy(panel.has_signal(&"return_to_forge_requested"), "result panel exposes exact Return to Forge intent", failures)
    TestAssertions.truthy(panel.has_signal(&"open_armoury_requested"), "result panel exposes exact Open Armoury intent", failures)
    TestAssertions.truthy(panel.has_signal(&"quit_application_requested"), "result panel exposes exact Quit Application intent", failures)
    TestAssertions.truthy(panel.has_signal(&"protect_displaced_gear_requested"), "result panel exposes exact protected-overflow intent", failures)
    TestAssertions.truthy(panel.has_signal(&"retry_projection_requested"), "result panel exposes exact Retry Results intent", failures)
    TestAssertions.truthy(panel.has_signal(&"retry_terminal_refresh_requested"), "result panel exposes exact committed terminal refresh intent", failures)
    TestAssertions.truthy(not panel.has_signal(&"restart_requested") and not panel.has_signal(&"quit_requested"), "obsolete generic result intents are removed", failures)
    panel.free()


func _test_terminal_cutover_contract(failures: Array[String]) -> void:
    var source := FileAccess.get_file_as_string("res://scripts/game/main.gd")
    var terminal_body := _function_body(source, "_on_terminal")
    var accepted_body := _function_body(source, "_on_terminal_resolution_accepted")
    TestAssertions.truthy("_terminal_flow.begin" in terminal_body and not ("_clear_live_loot" in terminal_body), "terminal entry captures and never clears", failures)
    var guard_index := terminal_body.find("if not _terminal_flow.can_begin()")
    var cancellation_index := terminal_body.find("_cancel_hostile_effects()")
    var begin_index := terminal_body.find("_terminal_flow.begin")
    TestAssertions.truthy(guard_index >= 0 and cancellation_index > guard_index and cancellation_index < begin_index, "terminal ownership cancels hostile transients after the once-only guard and before capture/presentation", failures)
    TestAssertions.truthy(not ("_cancel_hostile_effects()" in accepted_body), "accepted tail never relies on or repeats terminal-entry hostile cancellation", failures)
    TestAssertions.truthy(accepted_body.find("_build_terminal_result") >= 0 and accepted_body.find("_build_terminal_result") < accepted_body.find("_clear_live_loot"), "validated result precedes cleanup", failures)
    TestAssertions.truthy(accepted_body.find("_terminal_flow.finalize") > accepted_body.find("_build_terminal_result") and accepted_body.find("_terminal_flow.finalize") < accepted_body.find("_clear_live_loot"), "fallible finalize succeeds before cleanup", failures)
    for required: String in [
        "_terminal_flow.confirm_extraction", "profile_manager.refresh_profile", "restart_run_requested",
        "return_to_forge_requested", "open_armoury_requested", "quit_application_requested",
        "protect_displaced_gear_requested", "retry_projection_requested",
        "RunTerminalRecoveryService", "complete_terminal", "verify_terminal_safety",
    ]:
        TestAssertions.truthy(required in source, "Main terminal cutover includes %s" % required, failures)
    TestAssertions.truthy(source.find("terminal_resolution") >= 0 and source.find("terminal_resolution") < source.find("resumable_run"), "durable terminal boot recovery precedes ordinary resumable-run recovery", failures)
    TestAssertions.truthy("RunSetupRestartIntent" in source and "set_meta" in source and "remove_meta" in source, "Restart Run uses one-shot SceneTree intent metadata", failures)
    TestAssertions.truthy("_run_recovery.forfeit(active_run_context.profile_id, active_run_context.run_id, profile_root)" in source, "active-run Abandon uses the sole authoritative forfeit path", failures)
    var retry_abandon_body := _function_body(source, "_on_retry_abandon_refresh_requested")
    TestAssertions.truthy("refresh_profile" in retry_abandon_body and not ("forfeit" in retry_abandon_body), "committed Abandon retry refreshes only and never forfeits twice", failures)


func _function_body(source: String, function_name: String) -> String:
    var start := source.find("func %s(" % function_name)
    if start < 0:
        return ""
    var next := source.find("\nfunc ", start + 1)
    return source.substr(start) if next < 0 else source.substr(start, next - start)

func _test_visual_language(failures: Array[String]) -> void:
    var swarmer := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as Node3D
    var spitter := (load("res://scenes/enemies/spitter.tscn") as PackedScene).instantiate() as Node3D
    var orb := (load("res://scenes/progression/experience_orb.tscn") as PackedScene).instantiate() as Node3D
    var heal := (load("res://scenes/combat/heal_effect.tscn") as PackedScene).instantiate() as Node3D
    var danger := (load("res://scenes/effects/danger_ring.tscn") as PackedScene).instantiate() as Node3D
    swarmer.call("configure", swarmer.get("definition"))
    var swarmer_color := _mesh_color(swarmer)
    var spitter_color := _mesh_color(spitter)
    var orb_color := _mesh_color(orb)
    var heal_color := _mesh_color(heal)
    var danger_color := _mesh_color(danger)
    TestAssertions.truthy(swarmer_color.get_luminance() < 0.35, "Swarmer uses dark warm enemy language", failures)
    TestAssertions.truthy(spitter_color.r > spitter_color.g * 1.5 and spitter_color.g > spitter_color.b, "Spitter uses orange enemy language", failures)
    TestAssertions.truthy(orb_color.b > 0.7 and orb_color.g > 0.7, "experience orb is cyan", failures)
    TestAssertions.truthy(heal_color.g > heal_color.r * 2.0, "healing burst is green", failures)
    TestAssertions.truthy(danger_color.r > danger_color.g * 4.0, "danger ring is red", failures)
    (swarmer.get_node("HealthComponent") as HealthComponent).apply_damage(1.0)
    TestAssertions.equal(_mesh_color(swarmer), Color.WHITE, "enemy damage flash is white", failures)
    var health_bar := (load("res://scenes/ui/health_bar_3d.tscn") as PackedScene).instantiate() as Node3D
    TestAssertions.truthy((health_bar.get_node("Label3D") as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED, "3D health bar billboards", failures)
    TestAssertions.equal(health_bar.get("downed_color"), Color(0.45, 0.45, 0.45), "downed visual is gray", failures)
    var actor := (load("res://scenes/characters/companion.tscn") as PackedScene).instantiate() as PartyActor
    actor.configure(PartyMemberState.new(99, GameCatalog.load_defaults().class_by_id(&"ranger"), false))
    var actor_health := actor.get_node("HealthComponent") as HealthComponent
    actor_health.apply_damage(10.0)
    TestAssertions.equal(_mesh_color(actor), Color.WHITE, "party damage flash is white", failures)
    actor_health.apply_damage(9999.0)
    TestAssertions.truthy(_presentation_meshes_are_grayscale(actor), "downed actor presentation is grayscale", failures)
    swarmer.free(); spitter.free(); orb.free(); heal.free(); danger.free(); health_bar.free()
    actor.free()

func _test_catalog_error_format(failures: Array[String]) -> void:
    var main_script := load("res://scripts/game/main.gd") as Script
    TestAssertions.equal(main_script.call("format_resource_error", "res://data/test.tres", "broken"), "PARTY_FORGE_RESOURCE_ERROR path=res://data/test.tres reason=broken", "catalog error is grep-friendly", failures)

func _mesh_color(node: Node3D) -> Color:
    var mesh_instance := node.get_node_or_null("MeshInstance3D") as MeshInstance3D
    if mesh_instance == null:
        mesh_instance = node.find_child("MeshInstance3D", true, false) as MeshInstance3D
    if mesh_instance == null:
        return Color.TRANSPARENT
    var material := mesh_instance.get_active_material(0) as StandardMaterial3D
    if material != null and material.vertex_color_use_as_albedo and mesh_instance.mesh != null:
        var colors := mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
        if not colors.is_empty():
            var average := Color(0.0, 0.0, 0.0, 0.0)
            for vertex_color: Color in colors:
                average += vertex_color
            return (average / float(colors.size())) * material.albedo_color
    return material.albedo_color if material != null else Color.TRANSPARENT

func _presentation_meshes_are_grayscale(actor: PartyActor) -> bool:
    var presentation := actor.get_node_or_null("Presentation") as CharacterPresentation
    if presentation == null or presentation.active_model == null:
        return _mesh_color(actor) == Color(0.45, 0.45, 0.45)
    var checked := 0
    for node: Node in presentation.active_model.find_children("*", "MeshInstance3D", true, false):
        var mesh := node as MeshInstance3D
        if not mesh.is_visible_in_tree():
            continue
        var material := mesh.material_override as StandardMaterial3D
        if material == null:
            continue
        checked += 1
        var color := material.albedo_color
        if not is_equal_approx(color.r, color.g) or not is_equal_approx(color.g, color.b):
            return false
    return checked > 0

func _started_main() -> Node:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(main)
    main.call("select_leader_class", &"fighter")
    return main

func _started_main_with_settings(settings: PartyForgeSettings) -> Node:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    _prepare_main(main)
    main.set("saved_settings", settings.copy())
    main.call("select_leader_class", &"fighter")
    return main

func _apply_settings(main: Node, settings: PartyForgeSettings) -> void:
    var path := String(main.get("settings_path"))
    PartyForgeSettingsStore.new().save_settings(settings, path)
    main.call("_on_settings_applied", settings)

func _prepare_main(main: Node, settings_path: String = "") -> void:
    main.set("profile_root", _profile_root)
    main.set("settings_path", settings_path if not settings_path.is_empty() else _settings_path)
    main.call("_ready")
    var manager := main.get("profile_manager") as ProfileManager
    if manager.active_profile() == null:
        manager.create_profile("Test Profile")
    var profile := manager.active_profile()
    if profile != null and not profile.resumable_run.is_empty():
        profile.resumable_run = {}
        ProfileStore.new().save_profile(profile, _profile_root)
        manager.refresh_profile(profile.profile_id)
    (main.get_node("SettingsScreen") as SettingsScreen).close()

func _present_test_offer(main: Node, run_seed: int, pending_count: int = 1) -> void:
    var game_run := main.get_node("GameRun") as GameRun
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    game_run.configure_seed(run_seed)
    var level_handler := Callable(main, "_on_level_ready")
    var reconnect_level_handler := experience.level_ready.is_connected(level_handler)
    if reconnect_level_handler:
        experience.level_ready.disconnect(level_handler)
    _queue_leader_levels(main, pending_count)
    if reconnect_level_handler:
        experience.level_ready.connect(level_handler)
    game_run.begin_level_up()
    main.call("_present_pending_level")

func _queue_leader_levels(main: Node, count: int) -> void:
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    var amount := 0
    for offset: int in range(maxi(count, 0)):
        amount += experience.tuning.requirement_for_level(experience.level + offset)
    experience.add_experience(amount)

func _cleanup_main(main: Node) -> void:
    (Engine.get_main_loop() as SceneTree).paused = false
    main.free()

func _cleanup_settings_artifacts(settings_path: String) -> void:
    for path: String in [settings_path, "%s.tmp" % settings_path, "%s.bak" % settings_path]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _escape_key_event() -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = KEY_ESCAPE
    event.physical_keycode = KEY_ESCAPE
    event.pressed = true
    return event

func _bound_production_keys(cards: Array[Node]) -> Array[String]:
    var result: Array[String] = []
    for card_node: Node in cards:
        var card := card_node as UpgradeCard
        result.append(String(card.call("bound_choice_key")))
    return result

func _submit_bound_offer(panel: LevelUpPanel, card: UpgradeCard, party: PartyManager) -> void:
    var key: StringName = card.bound_choice_key()
    var choices_by_key := panel.get("_choices_by_key") as Dictionary
    var choice := choices_by_key.get(String(key)) as UpgradeChoice
    card.activated.emit(key)
    if choice == null:
        return
    if choice.application_route() == UpgradeChoice.ApplicationRoute.RECIPIENT_CONFIRMATION:
        panel.call("_on_recipient_selected", key, party.members[0].member_id)
        (panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button).pressed.emit()
    elif choice.application_route() == UpgradeChoice.ApplicationRoute.CONTEXT_CONFIRMATION:
        (panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button).pressed.emit()

func _choice_keys(source_choices: Array) -> Array[String]:
    var result: Array[String] = []
    for choice: UpgradeChoice in source_choices:
        result.append(choice.key())
    return result

func _choice_instance_ids(source_choices: Array[UpgradeChoice]) -> Array[int]:
    var result: Array[int] = []
    for choice: UpgradeChoice in source_choices:
        result.append(choice.get_instance_id())
    return result
