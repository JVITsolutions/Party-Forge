extends RefCounted

const REQUIRED_PATHS: PackedStringArray = [
    "res://scripts/ui/hud.gd",
    "res://scripts/ui/class_selection_panel.gd",
    "res://scripts/ui/level_up_panel.gd",
    "res://scripts/ui/run_result_panel.gd",
    "res://scripts/ui/health_bar_3d.gd",
    "res://scripts/ui/ledger/character_ledger.gd",
    "res://scripts/ui/run_pause_menu.gd",
    "res://scripts/ui/developer_mode_badge.gd",
    "res://scenes/ui/hud.tscn",
    "res://scenes/ui/level_up_panel.tscn",
    "res://scenes/ui/run_result_panel.tscn",
    "res://scenes/ui/health_bar_3d.tscn",
    "res://scenes/ui/ledger/character_ledger.tscn",
    "res://scenes/ui/run_pause_menu.tscn",
    "res://scenes/ui/developer_mode_badge.tscn",
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
    "GameRun", "PartyManager", "ExperienceSystem", "SpawnDirector",
    "PartyActorSpawner", "Arena", "Actors", "Enemies", "Effects", "HUD",
    "DeveloperModeBadge", "CharacterLedger", "RunPauseMenu",
]

func run() -> Array[String]:
    var failures: Array[String] = []
    var all_exist := true
    for path: String in REQUIRED_PATHS:
        var exists := ResourceLoader.exists(path)
        TestAssertions.truthy(exists, "required integrated resource loads: %s" % path, failures)
        all_exist = all_exist and exists
    if not all_exist:
        return failures
    _test_main_scene_graph(failures)
    _test_settings_and_next_run_snapshot_wiring(failures)
    _test_integrated_overlay_input_and_front_end_seam(failures)
    _test_hud_contract(failures)
    _test_exact_choice_panel(failures)
    _test_class_selection_starts_run_and_applies_choices(failures)
    _test_targeted_confirmation_routes_through_main(failures)
    _test_stale_target_rejects_without_consuming(failures)
    _test_live_member_health_provider_uses_party_membership(failures)
    _test_ledger_health_provider_is_unbounded_and_complete(failures)
    _test_capped_stat_is_disabled_without_hiding(failures)
    _test_run_offer_seed_and_snapshot_wiring(failures)
    _test_queued_levels_show_fresh_production_offers(failures)
    _test_boss_level_up_resumes_boss(failures)
    _test_catalog_gate_blocks_public_start(failures)
    _test_result_panel_requests_once(failures)
    _test_visual_language(failures)
    _test_catalog_error_format(failures)
    return failures

func _test_settings_and_next_run_snapshot_wiring(failures: Array[String]) -> void:
    var original_files := _backup_default_settings_artifacts()
    _cleanup_default_settings_artifacts()
    var store := PartyForgeSettingsStore.new()
    var player_settings := PartyForgeSettings.new()
    player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
    player_settings.god_mode = true
    TestAssertions.equal(store.save_settings(player_settings), "", "Player Simulation fixture saves", failures)
    var player_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    player_main.call("_ready")
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
    TestAssertions.equal(store.save_settings(developer_settings), "", "Developer Mode fixture saves", failures)
    var developer_main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    developer_main.call("_ready")
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
    _cleanup_default_settings_artifacts()
    _restore_default_settings_artifacts(original_files)

func _test_main_scene_graph(failures: Array[String]) -> void:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    for node_name: String in REQUIRED_MAIN_NODES:
        TestAssertions.truthy(main.get_node_or_null(node_name) != null, "main owns %s" % node_name, failures)
    TestAssertions.equal(main.get_node_or_null("Leader"), null, "main waits for initial class selection before creating leader", failures)
    var class_selection := main.get_node_or_null("HUD/ClassSelection") as Control
    TestAssertions.truthy(class_selection != null and class_selection.visible, "initial class selection is visible", failures)
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
    main.free()

func _test_integrated_overlay_input_and_front_end_seam(failures: Array[String]) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    tree.paused = false
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    tree.root.add_child(main)
    TestAssertions.truthy(main.call("select_leader_class", &"fighter"), "integration fixture starts an active run", failures)
    var ledger := main.get_node("CharacterLedger") as CharacterLedger
    var pause_menu := main.get_node("RunPauseMenu")
    TestAssertions.truthy(ledger.open_for_player(), "integrated ledger opens for the active run", failures)
    var escape := _escape_key_event()
    pause_menu.call("_unhandled_input", escape)
    ledger.call("_unhandled_input", escape)
    TestAssertions.truthy(not ledger.is_open(), "Escape closes the ledger through modal input ordering", failures)
    TestAssertions.truthy(not bool(pause_menu.visible), "same Escape does not open RunPauseMenu behind the ledger", failures)
    TestAssertions.truthy(not tree.paused, "ledger close restores the running tree exactly", failures)
    var front_end_callable := Callable(main, "_return_to_front_end")
    TestAssertions.truthy(main.has_method("_return_to_front_end"), "main exposes the front-end routing seam", failures)
    TestAssertions.truthy(pause_menu.is_connected("quit_run_confirmed", front_end_callable), "confirmed Quit Run routes to the front-end seam", failures)
    var result := main.get_node("HUD/RunResultPanel")
    TestAssertions.truthy(result.is_connected("quit_requested", Callable(main, "_quit")), "desktop result-panel Quit keeps its protected route", failures)
    tree.paused = false
    main.free()

func _test_hud_contract(failures: Array[String]) -> void:
    var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
    for path: String in [
        "Margin/Status/LeaderHealth", "Margin/Status/Experience", "Margin/Status/RunTime",
        "Margin/Status/PartyEntries/Party1", "Margin/Status/PartyEntries/Party2",
        "Margin/Status/PartyEntries/Party3", "Margin/Status/PartyEntries/Party4",
        "Margin/Status/ActiveTraits", "Margin/Status/BossHealth", "BossBanner",
        "LevelUpPanel", "RunResultPanel", "ClassSelection",
    ]:
        TestAssertions.truthy(hud.get_node_or_null(path) != null, "HUD exposes %s" % path, failures)
    TestAssertions.truthy(not (hud.get_node("Margin/Status/BossHealth") as Control).visible, "boss health starts hidden", failures)
    TestAssertions.truthy(not (hud.get_node("BossBanner") as Control).visible, "boss banner starts hidden", failures)
    hud.free()

func _test_exact_choice_panel(failures: Array[String]) -> void:
    var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as Control
    var party := PartyManager.new()
    var catalog := GameCatalog.load_defaults()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var choices: Array[UpgradeChoice] = [
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage"),
        UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"mage", "Invalid Mage Rank"),
        UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger"),
    ]
    panel.call("show_choices", choices, party)
    var pending_label := panel.get_node_or_null("ContentPanel/OfferView/Content/PendingLevels") as Label
    TestAssertions.truthy(pending_label != null, "level-up panel scene exposes the pending-level indicator", failures)
    var buttons := panel.get_node("Choices").get_children()
    TestAssertions.equal(buttons.size(), 3, "level-up panel owns exactly three choice buttons", failures)
    TestAssertions.equal((buttons[0] as Button).text, choices[0].label, "first button uses exact first choice", failures)
    TestAssertions.truthy(not (buttons[0] as Button).disabled, "valid choice enabled", failures)
    TestAssertions.truthy((buttons[1] as Button).disabled, "invalid choice disabled", failures)
    var selected: Array[UpgradeChoice] = []
    var hidden_before_emit: Array[bool] = []
    panel.connect("choice_selected", func(choice: UpgradeChoice) -> void:
        selected.append(choice)
        hidden_before_emit.append(not panel.visible)
    )
    (buttons[0] as Button).pressed.emit()
    (buttons[0] as Button).pressed.emit()
    TestAssertions.equal(selected.size(), 1, "level-up selection emits once", failures)
    TestAssertions.equal(selected[0] if not selected.is_empty() else null, choices[0], "level-up emits exact UpgradeChoice instance", failures)
    TestAssertions.truthy(not hidden_before_emit.is_empty() and hidden_before_emit[0], "level-up panel hides before selection signal", failures)
    panel.free()
    party.free()

func _test_class_selection_starts_run_and_applies_choices(failures: Array[String]) -> void:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    main.call("_ready")
    TestAssertions.equal(main.get("run_started"), false, "run timer waits at class selection", failures)
    var selector := main.get_node("HUD/ClassSelection")
    selector.call("configure", GameCatalog.load_defaults().classes)
    var marksman_button := selector.get_node_or_null("Content/Scroll/Grid/Class_marksman") as Button
    TestAssertions.truthy(marksman_button != null, "catalog selector exposes Marksman button", failures)
    if marksman_button != null:
        marksman_button.pressed.emit()
    TestAssertions.equal(main.get("run_started"), true, "run marked started after class selection", failures)
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
    experience.pending_levels = 1
    game_run.call("begin_level_up")
    var stat_choice := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"pickup_radius", "Pickup Radius")
    (main.get("party_stats") as Dictionary)[&"pickup_radius"] = 19
    main.call("_apply_choice", stat_choice)
    TestAssertions.equal(int((main.get("party_stats") as Dictionary)[&"pickup_radius"]), 20, "party stat upgrades cap at 20", failures)
    experience.pending_levels = 1
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
        class_main.call("_ready")
        TestAssertions.truthy(class_main.call("select_leader_class", class_id), "%s direct selection succeeds" % class_id, failures)
        var class_party := class_main.get_node("PartyManager") as PartyManager
        if not class_party.members.is_empty():
            TestAssertions.equal(class_party.members[0].class_definition.id, class_id, "%s direct selection uses exact leader" % class_id, failures)
        class_main.free()
        (Engine.get_main_loop() as SceneTree).paused = false

func _test_targeted_confirmation_routes_through_main(failures: Array[String]) -> void:
    var main := _started_main()
    var panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
    var handler := Callable(main, "_on_choice_confirmation_requested")
    TestAssertions.truthy(main.has_method("_apply_choice_for_member"), "main exposes member-targeted central apply", failures)
    TestAssertions.truthy(main.has_method("_on_choice_confirmation_requested"), "main exposes confirmation request handler", failures)
    TestAssertions.truthy(panel.is_connected("confirmation_requested", handler), "confirmation request connects to central main handler", failures)
    TestAssertions.truthy(not panel.is_connected("choice_selected", Callable(main, "_apply_choice")), "legacy choice signal is not a second main application path", failures)
    var health_provider: Callable = panel.get("_health_provider")
    TestAssertions.truthy(health_provider.is_valid(), "main configures live recipient health provider", failures)

    var party := main.get_node("PartyManager") as PartyManager
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    var game_run := main.get_node("GameRun") as GameRun
    experience.pending_levels = 1
    game_run.begin_level_up()
    var choice := UpgradeChoice.authored((main.get("catalog") as GameCatalog).upgrade_by_id(&"vitality"))
    var choices: Array[UpgradeChoice] = [
        choice,
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage"),
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"move_speed", "Move Speed"),
    ]
    panel.show_choices(choices, party)
    panel.call("_on_recipient_selected", choice, party.members[0].member_id)
    var confirm := panel.get_node("ContentPanel/ConfirmationView/Content/Actions/Confirm") as Button
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
    experience.pending_levels = 1
    game_run.begin_level_up()
    var choice := UpgradeChoice.authored((main.get("catalog") as GameCatalog).upgrade_by_id(&"vitality"))
    panel.show_choices([
        choice,
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage"),
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"move_speed", "Move Speed"),
    ], party)
    panel.call("_on_recipient_selected", choice, 999)
    (panel.get_node("ContentPanel/ConfirmationView/Content/Actions/Confirm") as Button).pressed.emit()
    TestAssertions.equal(party.upgrade_rank(&"vitality", party.members[0].member_id), 0, "stale target applies no authored rank", failures)
    TestAssertions.equal(experience.pending_levels, 1, "stale target consumes no pending level", failures)
    TestAssertions.equal(game_run.current_state(), RunStateMachine.State.LEVEL_UP, "stale target keeps level-up paused", failures)
    TestAssertions.truthy(panel.visible, "stale target keeps selection visible", failures)
    TestAssertions.truthy((panel.get_node("ContentPanel/ConfirmationView") as Control).visible, "stale target remains on confirmation view", failures)
    TestAssertions.truthy(not (panel.get_node("ContentPanel/ConfirmationView/Content/Error") as Label).text.is_empty(), "stale target displays rejection reason", failures)
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
    var capped_button := panel.get_node("Choices/Choice1") as Button
    var emitted: Array[UpgradeChoice] = []
    panel.connect("choice_selected", func(choice: UpgradeChoice) -> void: emitted.append(choice))
    TestAssertions.truthy(capped_button.disabled, "rank-20 party stat is invalid before selection", failures)
    capped_button.pressed.emit()
    TestAssertions.truthy(panel.visible, "invalid capped button cannot hide and strand level-up panel", failures)
    TestAssertions.equal(emitted.size(), 0, "invalid capped button cannot emit success", failures)
    var main := _started_main()
    (main.get("party_stats") as Dictionary)[&"damage"] = 20
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    experience.pending_levels = 1
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
    reset_main.call("_ready")
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

func _test_queued_levels_show_fresh_production_offers(failures: Array[String]) -> void:
    var main := _started_main()
    var game_run: Node = main.get_node("GameRun")
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    var panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
    var cards := panel.get_node("ContentPanel/OfferView/Content/Cards").get_children()
    TestAssertions.equal(cards.size(), 3, "production offer view owns exactly three upgrade cards", failures)
    var card_api_available := cards.size() == 3 and cards.all(
        func(card: Node) -> bool: return card is UpgradeCard and card.has_method("bound_choice")
    )
    TestAssertions.truthy(card_api_available, "production cards expose their current binding read-only", failures)
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
    var first_choices := _bound_production_choices(cards)
    var first_keys := _choice_keys(first_choices)
    var first_instance_ids := _choice_instance_ids(first_choices)
    TestAssertions.equal(first_offer_keys.size(), 5, "first production offer stores the snapshotted five choices", failures)
    TestAssertions.equal(first_keys, first_offer_keys.slice(0, cards.size()), "first visible cards bind the presentation subset in order", failures)

    var first_card := cards[0] as UpgradeCard
    first_card.activated.emit(first_choices[0])
    if first_choices[0].requires_recipient():
        panel.call("_on_recipient_selected", first_choices[0], party.members[0].member_id)
    (panel.get_node("ContentPanel/ConfirmationView/Content/Actions/Confirm") as Button).pressed.emit()
    TestAssertions.equal(experience.pending_levels, 1, "first production confirmation consumes pending 2 to 1 exactly", failures)
    TestAssertions.equal(experience.pending_level_numbers, [3], "first production confirmation leaves only earned level 3 queued", failures)
    TestAssertions.equal(experience.experience, remainder, "first production confirmation loses no excess experience", failures)
    TestAssertions.equal(game_run.call("current_state"), RunStateMachine.State.LEVEL_UP, "first production confirmation remains paused", failures)
    TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "tree remains paused between production confirmations", failures)
    TestAssertions.truthy(bool(main.get("level_refresh_scheduled")), "second queued production offer is scheduled separately", failures)

    main.call("_present_pending_level")
    var second_offer_choices := panel.choices
    var second_offer_keys := _choice_keys(second_offer_choices)
    var second_choices := _bound_production_choices(cards)
    var second_keys := _choice_keys(second_choices)
    var second_instance_ids := _choice_instance_ids(second_choices)
    TestAssertions.truthy(panel.visible, "second queued production offer is visible before confirmation", failures)
    TestAssertions.equal(second_offer_keys.size(), 5, "second production offer stores the snapshotted five choices", failures)
    TestAssertions.equal(second_keys, second_offer_keys.slice(0, cards.size()), "second visible cards bind the presentation subset in order", failures)
    TestAssertions.truthy(second_offer_keys != first_offer_keys, "run offer sequence produces a fresh second ordered offer", failures)
    TestAssertions.truthy(second_instance_ids.all(func(id: int) -> bool: return id not in first_instance_ids), "second production offer binds freshly generated choice objects", failures)

    var second_card := cards[0] as UpgradeCard
    second_card.activated.emit(second_choices[0])
    if second_choices[0].requires_recipient():
        panel.call("_on_recipient_selected", second_choices[0], party.members[0].member_id)
    (panel.get_node("ContentPanel/ConfirmationView/Content/Actions/Confirm") as Button).pressed.emit()
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
    experience.pending_levels = 1
    main.call("_on_level_ready", experience.level + 1)
    TestAssertions.equal(game_run.call("current_state"), 2, "boss-phase level-up enters LEVEL_UP", failures)
    TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "boss-phase level-up pauses gameplay", failures)
    main.call("_apply_choice", UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"attack_speed", "Attack Speed"))
    TestAssertions.equal(game_run.call("current_state"), 3, "boss-phase level-up resumes BOSS", failures)
    TestAssertions.truthy(not (Engine.get_main_loop() as SceneTree).paused, "boss resume unpauses gameplay", failures)
    main.free()

func _test_catalog_gate_blocks_public_start(failures: Array[String]) -> void:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    main.call("_ready")
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
    var panel := (load("res://scenes/ui/run_result_panel.tscn") as PackedScene).instantiate() as Control
    panel.call("_ready")
    var restart_count: Array[int] = [0]
    var quit_count: Array[int] = [0]
    panel.connect("restart_requested", func() -> void: restart_count[0] += 1)
    panel.connect("quit_requested", func() -> void: quit_count[0] += 1)
    (panel.get_node("Panel/Content/Restart") as Button).pressed.emit()
    (panel.get_node("Panel/Content/Quit") as Button).pressed.emit()
    TestAssertions.equal(restart_count[0], 1, "restart routes once", failures)
    TestAssertions.equal(quit_count[0], 1, "quit routes once", failures)
    panel.free()

func _test_visual_language(failures: Array[String]) -> void:
    var swarmer := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as Node3D
    var spitter := (load("res://scenes/enemies/spitter.tscn") as PackedScene).instantiate() as Node3D
    var orb := (load("res://scenes/progression/experience_orb.tscn") as PackedScene).instantiate() as Node3D
    var heal := (load("res://scenes/combat/heal_effect.tscn") as PackedScene).instantiate() as Node3D
    var danger := (load("res://scenes/effects/danger_ring.tscn") as PackedScene).instantiate() as Node3D
    var swarmer_color := _mesh_color(swarmer)
    var spitter_color := _mesh_color(spitter)
    var orb_color := _mesh_color(orb)
    var heal_color := _mesh_color(heal)
    var danger_color := _mesh_color(danger)
    TestAssertions.truthy(swarmer_color.get_luminance() < 0.18, "Swarmer uses black enemy language", failures)
    TestAssertions.truthy(spitter_color.r > spitter_color.g * 1.5 and spitter_color.g > spitter_color.b, "Spitter uses orange enemy language", failures)
    TestAssertions.truthy(orb_color.b > 0.7 and orb_color.g > 0.7, "experience orb is cyan", failures)
    TestAssertions.truthy(heal_color.g > heal_color.r * 2.0, "healing burst is green", failures)
    TestAssertions.truthy(danger_color.r > danger_color.g * 4.0, "danger ring is red", failures)
    swarmer.call("configure", swarmer.get("definition"))
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
    TestAssertions.equal(_mesh_color(actor), Color(0.45, 0.45, 0.45), "downed actor material is gray", failures)
    swarmer.free(); spitter.free(); orb.free(); heal.free(); danger.free(); health_bar.free()
    actor.free()

func _test_catalog_error_format(failures: Array[String]) -> void:
    var main_script := load("res://scripts/game/main.gd") as Script
    TestAssertions.equal(main_script.call("format_resource_error", "res://data/test.tres", "broken"), "PARTY_FORGE_RESOURCE_ERROR path=res://data/test.tres reason=broken", "catalog error is grep-friendly", failures)

func _mesh_color(node: Node3D) -> Color:
    var mesh_instance := node.get_node("MeshInstance3D") as MeshInstance3D
    var material := mesh_instance.material_override as StandardMaterial3D
    if material == null and mesh_instance.mesh != null:
        material = mesh_instance.mesh.material as StandardMaterial3D
    return material.albedo_color if material != null else Color.TRANSPARENT

func _started_main() -> Node:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    main.call("_ready")
    main.call("select_leader_class", &"fighter")
    return main

func _started_main_with_settings(settings: PartyForgeSettings) -> Node:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    main.call("_ready")
    main.set("saved_settings", settings.copy())
    main.call("select_leader_class", &"fighter")
    return main

func _present_test_offer(main: Node, run_seed: int, pending_count: int = 1) -> void:
    var game_run := main.get_node("GameRun") as GameRun
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    game_run.configure_seed(run_seed)
    experience.level = 1 + pending_count
    experience.pending_levels = pending_count
    experience.pending_level_numbers = []
    for pending_level: int in range(2, pending_count + 2):
        experience.pending_level_numbers.append(pending_level)
    game_run.begin_level_up()
    main.call("_present_pending_level")

func _cleanup_main(main: Node) -> void:
    (Engine.get_main_loop() as SceneTree).paused = false
    main.free()

func _cleanup_default_settings_artifacts() -> void:
    for path: String in [PartyForgeSettingsStore.DEFAULT_PATH, "%s.tmp" % PartyForgeSettingsStore.DEFAULT_PATH, "%s.bak" % PartyForgeSettingsStore.DEFAULT_PATH]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _backup_default_settings_artifacts() -> Dictionary:
    var result: Dictionary = {}
    for path: String in [PartyForgeSettingsStore.DEFAULT_PATH, "%s.tmp" % PartyForgeSettingsStore.DEFAULT_PATH, "%s.bak" % PartyForgeSettingsStore.DEFAULT_PATH]:
        if FileAccess.file_exists(path):
            result[path] = FileAccess.get_file_as_bytes(path)
    return result

func _restore_default_settings_artifacts(files: Dictionary) -> void:
    for path: String in files:
        var file := FileAccess.open(path, FileAccess.WRITE)
        if file != null:
            file.store_buffer(files[path] as PackedByteArray)

func _escape_key_event() -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = KEY_ESCAPE
    event.physical_keycode = KEY_ESCAPE
    event.pressed = true
    return event

func _bound_production_choices(cards: Array[Node]) -> Array[UpgradeChoice]:
    var result: Array[UpgradeChoice] = []
    for card_node: Node in cards:
        var card := card_node as UpgradeCard
        result.append(card.call("bound_choice") as UpgradeChoice)
    return result

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
