extends SceneTree

const SOURCE_COMMIT := "66fd17aeaedb782ec491607035e07ce5ae974c14"
const SCREENSHOT_PATH := "res://docs/validation/screenshots/leader-defeat.png"
const EVIDENCE_PATH := "res://docs/validation/evidence/defeat-acceptance.json"
const MAX_WALL_SECONDS := 300.0

var failures: Array[String] = []
var started_ticks := 0
var choice_log: Array[String] = []

func _initialize() -> void:
    if "--task13-parse-only" in OS.get_cmdline_user_args():
        print("TASK_13_DEFEAT_DRIVER_PARSE: PASS")
        quit(0)
        return
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(1280, 720))
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    root.add_child(main)
    current_scene = main
    await process_frame
    await process_frame
    var game_run := main.get_node("GameRun") as GameRun
    _check(is_equal_approx(game_run.debug_time_scale, 1.0), "production clock scale is exactly 1.0")
    started_ticks = Time.get_ticks_msec()
    (main.get_node("HUD/ClassSelection/Content/Scroll/Grid/Class_mage") as Button).pressed.emit()
    var leader := main.get("leader") as PartyActor
    var health := leader.get_node("HealthComponent") as HealthComponent

    while _wall_seconds() <= MAX_WALL_SECONDS and game_run.current_state() != RunStateMachine.State.DEFEAT:
        await process_frame
        _handle_level_panel(main)
        _release_input()

    _release_input()
    var defeat_wall_seconds := _wall_seconds()
    var defeat_game_seconds := game_run.elapsed_time()
    _check(game_run.current_state() == RunStateMachine.State.DEFEAT, "enemies naturally kill the leader and enter DEFEAT")
    _check(health.is_dead and is_zero_approx(health.current_health), "leader reached zero health through production enemy behavior")
    _check(paused, "natural leader defeat pauses the tree")
    var result := main.get_node("HUD/RunResultPanel") as Control
    _check(result.visible, "defeat result panel is visible")
    _check((result.get_node("Panel/Content/Title") as Label).text == "DEFEAT", "result panel is labeled DEFEAT")

    # The run is already terminal. This public call is made only to prove the terminal lock.
    game_run.boss_defeated()
    await process_frame
    _check(game_run.current_state() == RunStateMachine.State.DEFEAT, "victory cannot overwrite terminal DEFEAT")
    _check((result.get_node("Panel/Content/Title") as Label).text == "DEFEAT", "terminal label remains DEFEAT")
    await process_frame
    await process_frame
    var screenshot_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))
    _check(screenshot_error == OK, "leader defeat viewport screenshot saved")
    var evidence := {
        "source_commit": SOURCE_COMMIT,
        "status": "PASS" if failures.is_empty() else "FAIL",
        "run_kind": "automated ordinary-speed natural-enemy-defeat acceptance",
        "automated_ordinary_speed": true,
        "direct_damage_injection": false,
        "debug_time_scale": game_run.debug_time_scale,
        "leader_class": "mage",
        "defeat_wall_seconds": defeat_wall_seconds,
        "defeat_game_seconds": defeat_game_seconds,
        "leader_health_at_defeat": health.current_health,
        "leader_is_dead": health.is_dead,
        "terminal_state_before_lock_probe": RunStateMachine.State.DEFEAT,
        "post_defeat_lock_probe": "GameRun.boss_defeated() called only after natural DEFEAT",
        "terminal_state_after_lock_probe": game_run.current_state(),
        "paused": paused,
        "result_title": (result.get_node("Panel/Content/Title") as Label).text,
        "choices": choice_log,
        "screenshot": SCREENSHOT_PATH,
        "failures": failures,
    }
    var file := FileAccess.open(ProjectSettings.globalize_path(EVIDENCE_PATH), FileAccess.WRITE)
    file.store_string(JSON.stringify(evidence, "  "))
    if failures.is_empty():
        print("TASK_13_DEFEAT_ACCEPTANCE: PASS wall=%.3f game=%.3f health=%.1f state=%d title=%s" % [defeat_wall_seconds, defeat_game_seconds, health.current_health, game_run.current_state(), evidence["result_title"]])
        quit(0)
        return
    for failure: String in failures:
        push_error("TASK_13_DEFEAT_FAILURE: %s" % failure)
    print("TASK_13_DEFEAT_ACCEPTANCE: FAIL (%d failures)" % failures.size())
    quit(1)

func _handle_level_panel(main: Node) -> void:
    var panel := main.get_node("HUD/LevelUpPanel") as Control
    if not panel.visible:
        return
    var choices: Array = panel.get("choices") as Array
    var buttons: Array[Node] = panel.get_node("Choices").get_children()
    for index: int in range(buttons.size()):
        if not (buttons[index] as Button).disabled:
            choice_log.append((choices[index] as UpgradeChoice).label)
            (buttons[index] as Button).pressed.emit()
            return

func _release_input() -> void:
    for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
        Input.action_release(action)

func _wall_seconds() -> float:
    return float(Time.get_ticks_msec() - started_ticks) / 1000.0 if started_ticks > 0 else 0.0

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures.append(label)
