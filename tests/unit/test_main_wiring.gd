extends RefCounted

const REQUIRED_PATHS: PackedStringArray = [
    "res://scripts/ui/hud.gd",
    "res://scripts/ui/class_selection_panel.gd",
    "res://scripts/ui/level_up_panel.gd",
    "res://scripts/ui/run_result_panel.gd",
    "res://scripts/ui/health_bar_3d.gd",
    "res://scenes/ui/hud.tscn",
    "res://scenes/ui/level_up_panel.tscn",
    "res://scenes/ui/run_result_panel.tscn",
    "res://scenes/ui/health_bar_3d.tscn",
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
    _test_hud_contract(failures)
    _test_exact_choice_panel(failures)
    _test_class_selection_starts_run_and_applies_choices(failures)
    _test_targeted_confirmation_routes_through_main(failures)
    _test_stale_target_rejects_without_consuming(failures)
    _test_live_member_health_provider_is_bounded(failures)
    _test_capped_stat_is_disabled_without_hiding(failures)
    _test_queued_levels_show_fresh_production_offers(failures)
    _test_boss_level_up_resumes_boss(failures)
    _test_catalog_gate_blocks_public_start(failures)
    _test_result_panel_requests_once(failures)
    _test_visual_language(failures)
    _test_catalog_error_format(failures)
    return failures

func _test_main_scene_graph(failures: Array[String]) -> void:
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    for node_name: String in REQUIRED_MAIN_NODES:
        TestAssertions.truthy(main.get_node_or_null(node_name) != null, "main owns %s" % node_name, failures)
    TestAssertions.equal(main.get_node_or_null("Leader"), null, "main waits for initial class selection before creating leader", failures)
    var class_selection := main.get_node_or_null("HUD/ClassSelection") as Control
    TestAssertions.truthy(class_selection != null and class_selection.visible, "initial class selection is visible", failures)
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

func _test_live_member_health_provider_is_bounded(failures: Array[String]) -> void:
    var main := _started_main()
    TestAssertions.truthy(main.has_method("_health_for_member"), "main exposes live member health provider", failures)
    if not main.has_method("_health_for_member"):
        _cleanup_main(main)
        return
    var leader := main.get("leader") as PartyActor
    var leader_health := leader.get_node("HealthComponent") as HealthComponent
    leader_health.apply_damage(17.0)
    TestAssertions.equal(main.call("_health_for_member", 1), Vector2(leader_health.current_health, leader_health.max_health), "health provider reads live leader component", failures)

    var actors := main.get_node("Actors") as Node3D
    var catalog := main.get("catalog") as GameCatalog
    for member_id: int in [2, 3, 4, 99]:
        var actor := (load("res://scenes/characters/companion.tscn") as PackedScene).instantiate() as PartyActor
        actor.configure(PartyMemberState.new(member_id, catalog.class_by_id(&"ranger"), false, "Test %d" % member_id))
        actors.add_child(actor)
    TestAssertions.equal(main.call("_health_for_member", 99), Vector2.ZERO, "health provider inspects at most four live party actors", failures)
    TestAssertions.equal(main.call("_health_for_member", 404), Vector2.ZERO, "health provider returns zero for unknown member", failures)
    _cleanup_main(main)

func _test_capped_stat_is_disabled_without_hiding(failures: Array[String]) -> void:
    var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as Control
    var method_arg_count := 0
    for method: Dictionary in panel.get_method_list():
        if method["name"] == &"show_choices":
            method_arg_count = (method["args"] as Array).size()
            break
    TestAssertions.equal(method_arg_count, 3, "choice panel accepts explicit invalid-choice keys", failures)
    if method_arg_count != 3:
        panel.free()
        return
    var party := PartyManager.new()
    var catalog := GameCatalog.load_defaults()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var capped := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Capped Damage")
    var choices: Array[UpgradeChoice] = [
        capped,
        UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger"),
        UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"move_speed", "Move Speed"),
    ]
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
    TestAssertions.equal(generated.size(), 3, "capped stat is replaced to preserve exact-three choices", failures)
    TestAssertions.truthy(generated.all(func(choice: UpgradeChoice) -> bool: return choice.key() != capped.key()), "generated choices exclude capped stat", failures)
    (Engine.get_main_loop() as SceneTree).paused = false
    main.free()
    panel.free(); party.free()

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
    var first_seed := 2 * 1009 + party.members.size()
    var expected_first_keys := _choice_keys(main.call("_generate_valid_choices", first_seed) as Array)
    var first_choices := _bound_production_choices(cards)
    var first_keys := _choice_keys(first_choices)
    var first_instance_ids := _choice_instance_ids(first_choices)
    TestAssertions.equal(first_keys, expected_first_keys, "first visible production offer uses queued level 2 seed", failures)
    TestAssertions.equal(first_keys.size(), 3, "first visible production offer records exact ordered three keys", failures)

    var first_card := cards[0] as UpgradeCard
    TestAssertions.truthy(not first_choices[0].requires_recipient(), "first queued offer exposes a direct-confirm production choice", failures)
    first_card.activated.emit(first_choices[0])
    (panel.get_node("ContentPanel/ConfirmationView/Content/Actions/Confirm") as Button).pressed.emit()
    TestAssertions.equal(experience.pending_levels, 1, "first production confirmation consumes pending 2 to 1 exactly", failures)
    TestAssertions.equal(experience.pending_level_numbers, [3], "first production confirmation leaves only earned level 3 queued", failures)
    TestAssertions.equal(experience.experience, remainder, "first production confirmation loses no excess experience", failures)
    TestAssertions.equal(game_run.call("current_state"), RunStateMachine.State.LEVEL_UP, "first production confirmation remains paused", failures)
    TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "tree remains paused between production confirmations", failures)
    TestAssertions.truthy(bool(main.get("level_refresh_scheduled")), "second queued production offer is scheduled separately", failures)

    var second_seed := 3 * 1009 + party.members.size()
    var expected_second_keys := _choice_keys(main.call("_generate_valid_choices", second_seed) as Array)
    main.call("_present_pending_level")
    var second_choices := _bound_production_choices(cards)
    var second_keys := _choice_keys(second_choices)
    var second_instance_ids := _choice_instance_ids(second_choices)
    TestAssertions.truthy(panel.visible, "second queued production offer is visible before confirmation", failures)
    TestAssertions.equal(second_keys, expected_second_keys, "second visible production offer uses queued level 3 seed and updated party", failures)
    TestAssertions.equal(second_keys.size(), 3, "second visible production offer records exact ordered three keys", failures)
    TestAssertions.truthy(second_instance_ids.all(func(id: int) -> bool: return id not in first_instance_ids), "second production offer binds freshly generated choice objects", failures)

    var second_card := cards[0] as UpgradeCard
    TestAssertions.truthy(not second_choices[0].requires_recipient(), "second queued offer exposes a direct-confirm production choice", failures)
    second_card.activated.emit(second_choices[0])
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

func _cleanup_main(main: Node) -> void:
    (Engine.get_main_loop() as SceneTree).paused = false
    main.free()

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
