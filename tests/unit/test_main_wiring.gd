extends RefCounted

const REQUIRED_PATHS: PackedStringArray = [
    "res://scripts/ui/hud.gd",
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
    _test_capped_stat_is_disabled_without_hiding(failures)
    _test_stacked_levels_stay_paused(failures)
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
    TestAssertions.truthy(main.call("select_leader_class", &"fighter"), "valid class selection starts run", failures)
    TestAssertions.equal(main.get("run_started"), true, "run marked started after class selection", failures)
    var game_run: Node = main.get_node("GameRun")
    TestAssertions.equal(game_run.call("current_state"), 1, "class selection starts RUNNING timer state", failures)
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

func _test_stacked_levels_stay_paused(failures: Array[String]) -> void:
    var main := _started_main()
    var game_run: Node = main.get_node("GameRun")
    var experience := main.get_node("ExperienceSystem") as ExperienceSystem
    experience.pending_levels = 2
    game_run.call("begin_level_up")
    var choice := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage")
    TestAssertions.truthy(main.call("_apply_choice", choice), "first stacked choice applies", failures)
    TestAssertions.equal(experience.pending_levels, 1, "first stacked choice consumes one pending level", failures)
    TestAssertions.equal(game_run.call("current_state"), 2, "remaining pending level keeps LEVEL_UP paused", failures)
    TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "remaining pending level keeps tree paused", failures)
    var has_refresh_state := main.has_method("_present_pending_level")
    TestAssertions.truthy(has_refresh_state, "main exposes deferred pending-level presenter", failures)
    if has_refresh_state:
        TestAssertions.truthy(bool(main.get("level_refresh_scheduled")), "fresh panel is deferred after synchronous selection signal", failures)
        main.call("_present_pending_level")
        var panel := main.get_node("HUD/LevelUpPanel") as Control
        TestAssertions.truthy(panel.visible and panel.get_node("Choices").get_child_count() == 3, "remaining level shows fresh exact-three panel", failures)
    main.call("_apply_choice", UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"move_speed", "Move Speed"))
    TestAssertions.equal(experience.pending_levels, 0, "final stacked choice consumes last pending level", failures)
    TestAssertions.equal(game_run.call("current_state"), 1, "final stacked choice resumes prior RUNNING state", failures)
    (Engine.get_main_loop() as SceneTree).paused = false
    main.free()

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
    swarmer.call("receive_damage", 1.0)
    TestAssertions.equal(_mesh_color(swarmer), Color.WHITE, "enemy damage flash is white", failures)
    var health_bar := (load("res://scenes/ui/health_bar_3d.tscn") as PackedScene).instantiate() as Node3D
    TestAssertions.truthy((health_bar.get_node("Label3D") as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED, "3D health bar billboards", failures)
    TestAssertions.equal(health_bar.get("downed_color"), Color(0.45, 0.45, 0.45), "downed visual is gray", failures)
    var actor := (load("res://scenes/characters/companion.tscn") as PackedScene).instantiate() as PartyActor
    actor.configure(PartyMemberState.new(99, GameCatalog.load_defaults().class_by_id(&"ranger"), false))
    actor.receive_damage(10.0)
    TestAssertions.equal(_mesh_color(actor), Color.WHITE, "party damage flash is white", failures)
    actor.receive_damage(9999.0)
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
