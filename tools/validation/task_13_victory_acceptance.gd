extends SceneTree

const SOURCE_COMMIT := "66fd17aeaedb782ec491607035e07ce5ae974c14"
const SCREENSHOT_PATH := "res://docs/validation/screenshots/boss-victory.png"
const EVIDENCE_PATH := "res://docs/validation/evidence/victory-acceptance.json"
const MAX_WALL_SECONDS := 450.0

var failures: Array[String] = []
var down_events: Array[Dictionary] = []
var revive_events: Array[Dictionary] = []
var companion_damage_events: Array[Dictionary] = []
var swarmer_seen := false
var swarmer_pursuit_seen := false
var spitter_seen := false
var spitter_projectile_seen := false
var boss_trigger_game_time := -1.0
var boss_trigger_wall_time := -1.0
var last_boss_action := -99
var boss_retreat_until := -1.0
var boss_shockwaves_observed := 0
var observed_health_ids: Dictionary = {}
var last_companion_health: Dictionary = {}
var choice_log: Array[String] = []
var started_ticks := 0
var next_progress_second := 30.0

func _initialize() -> void:
    if "--task13-parse-only" in OS.get_cmdline_user_args():
        print("TASK_13_VICTORY_DRIVER_PARSE: PASS")
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
    (main.get_node("HUD/ClassSelection/Content/Scroll/Grid/Class_fighter") as Button).pressed.emit()

    while _wall_seconds() <= MAX_WALL_SECONDS:
        await process_frame
        if main == null or not is_instance_valid(main):
            failures.append("main scene became invalid")
            break
        _handle_level_panel(main)
        _wire_companion_health(main)
        _observe_enemy_behavior(main)
        _drive_leader_input(main, game_run.current_state())
        var game_seconds := game_run.elapsed_time()
        if game_seconds >= next_progress_second:
            var leader_health := (main.get("leader") as PartyActor).get_node("HealthComponent") as HealthComponent
            print("TASK_13_VICTORY_PROGRESS game=%.1f wall=%.1f party=%d state=%d leader_health=%.1f companion_health=%s hostiles=%d downs=%d revives=%d" % [game_seconds, _wall_seconds(), (main.get_node("PartyManager") as PartyManager).members.size(), game_run.current_state(), leader_health.current_health, _companion_health_text(main), get_nodes_in_group("hostile_actors").size(), down_events.size(), revive_events.size()])
            next_progress_second += 30.0
        if game_run.current_state() == RunStateMachine.State.BOSS and boss_trigger_game_time < 0.0:
            boss_trigger_game_time = game_seconds
            boss_trigger_wall_time = _wall_seconds()
            print("TASK_13_BOSS_TRIGGER game=%.3f wall=%.3f" % [boss_trigger_game_time, boss_trigger_wall_time])
        if game_run.current_state() == RunStateMachine.State.VICTORY:
            _release_input()
            await process_frame
            await process_frame
            await process_frame
            await _finish_victory(main, game_run)
            return
        if game_run.current_state() == RunStateMachine.State.DEFEAT:
            failures.append("leader died before boss victory")
            break

    _release_input()
    if game_run.current_state() != RunStateMachine.State.DEFEAT:
        failures.append("victory was not reached within %.1f wall seconds" % MAX_WALL_SECONDS)
    _write_evidence(main, game_run, false, "")
    _finish_failure()

func _handle_level_panel(main: Node) -> void:
    var panel := main.get_node("HUD/LevelUpPanel") as Control
    if not panel.visible:
        return
    var pending := panel.get_node("Frame/Content/Pending") as Control
    if pending.visible:
        return
    var confirmation := panel.get_node("Frame/Content/Confirmation") as Control
    if confirmation.visible:
        var confirm := confirmation.get_node("Actions/Confirm") as Button
        if not confirm.disabled:
            confirm.pressed.emit()
        return
    var recipient := panel.get_node("Frame/Content/Recipient") as Control
    if recipient.visible:
        for row: Node in recipient.get_node("Content/RecipientsScroll/Rows").get_children():
            var recipient_button := row as Button
            if recipient_button != null and not recipient_button.disabled:
                recipient_button.pressed.emit()
                return
        (recipient.get_node("Content/Cancel") as Button).pressed.emit()
        return
    var choices: Array = panel.get("choices") as Array
    var buttons: Array[Node] = panel.get_node("Frame/Content/Offer/CardsScroll/Cards").get_children()
    var selected := -1
    for index: int in range(choices.size()):
        var choice := choices[index] as UpgradeChoice
        if choice != null and choice.kind == UpgradeChoice.Kind.RECRUIT and _desired_recruit_needed(main, choice.target_id) and not (buttons[index] as Button).disabled:
            selected = index
            break
    if selected < 0:
        for preferred_stat: StringName in [&"pickup_radius", &"move_speed", &"max_health"]:
            for index: int in range(choices.size()):
                var choice := choices[index] as UpgradeChoice
                if choice != null and choice.kind == UpgradeChoice.Kind.PARTY_STAT and choice.target_id == preferred_stat and not (buttons[index] as Button).disabled:
                    selected = index
                    break
            if selected >= 0:
                break
    if selected < 0:
        for index: int in range(choices.size()):
            var choice := choices[index] as UpgradeChoice
            if choice != null and choice.kind == UpgradeChoice.Kind.TRAIT and choice.target_id == &"ranged" and not (buttons[index] as Button).disabled:
                selected = index
                break
    if selected < 0:
        for index: int in range(choices.size()):
            var choice := choices[index] as UpgradeChoice
            if choice != null and choice.kind == UpgradeChoice.Kind.CLASS_RANK and choice.target_id == &"fighter" and not (buttons[index] as Button).disabled:
                selected = index
                break
    if selected < 0:
        for index: int in range(choices.size()):
            var choice := choices[index] as UpgradeChoice
            if choice != null and choice.kind == UpgradeChoice.Kind.TRAIT and choice.target_id == &"martial" and not (buttons[index] as Button).disabled:
                selected = index
                break
    if selected < 0:
        for index: int in range(choices.size()):
            var choice := choices[index] as UpgradeChoice
            if choice != null and choice.kind == UpgradeChoice.Kind.PARTY_STAT and not (buttons[index] as Button).disabled:
                selected = index
                break
    if selected < 0:
        for index: int in range(choices.size()):
            var choice := choices[index] as UpgradeChoice
            if choice != null and choice.kind != UpgradeChoice.Kind.RECRUIT and not (buttons[index] as Button).disabled:
                selected = index
                break
    if selected < 0:
        for index: int in range(buttons.size()):
            if not (buttons[index] as Button).disabled:
                selected = index
                break
    if selected >= 0:
        var selected_choice := choices[selected] as UpgradeChoice
        choice_log.append(selected_choice.label)
        (buttons[selected] as UpgradeCard).pressed.emit()

func _desired_recruit_needed(main: Node, class_id: StringName) -> bool:
    var desired: Dictionary = {&"ranger": 2, &"mage": 1}
    if not desired.has(class_id):
        return false
    var counts := _class_counts(main.get_node("PartyManager") as PartyManager)
    return int(counts.get(class_id, 0)) < int(desired[class_id])

func _companion_health_text(main: Node) -> String:
    var entries: PackedStringArray = []
    for child: Node in main.get_node("Actors").get_children():
        var actor := child as PartyActor
        if actor == null or actor == main.get("leader"):
            continue
        var health := actor.get_node("HealthComponent") as HealthComponent
        entries.append("%d:%s:%.1f%s" % [actor.member_state.member_id, actor.member_state.class_definition.id, health.current_health, ":down" if health.is_downed else ""])
    return "|".join(entries)

func _wire_companion_health(main: Node) -> void:
    for child: Node in main.get_node("Actors").get_children():
        var actor := child as PartyActor
        if actor == null or actor == main.get("leader"):
            continue
        var health := actor.get_node("HealthComponent") as HealthComponent
        var instance_id := health.get_instance_id()
        if observed_health_ids.has(instance_id):
            continue
        observed_health_ids[instance_id] = true
        last_companion_health[instance_id] = health.current_health
        health.health_changed.connect(func(current: float, maximum: float) -> void:
            var previous := float(last_companion_health.get(instance_id, maximum))
            last_companion_health[instance_id] = current
            if current < previous:
                companion_damage_events.append({
                    "member_id": actor.member_state.member_id,
                    "class_id": String(actor.member_state.class_definition.id),
                    "from_health": previous,
                    "to_health": current,
                    "wall_seconds": _wall_seconds(),
                    "game_seconds": (current_scene.get_node("GameRun") as GameRun).elapsed_time(),
                })
        )
        health.downed.connect(func() -> void:
            var event := _companion_event(actor, health)
            down_events.append(event)
            print("TASK_13_NATURAL_COMPANION_DOWN member=%d class=%s wall=%.3f game=%.3f" % [event["member_id"], event["class_id"], event["wall_seconds"], event["game_seconds"]])
        )
        health.revived.connect(func() -> void:
            var event := _companion_event(actor, health)
            revive_events.append(event)
            print("TASK_13_AUTOMATIC_COMPANION_REVIVE member=%d class=%s wall=%.3f game=%.3f health=%.1f" % [event["member_id"], event["class_id"], event["wall_seconds"], event["game_seconds"], event["health"]])
        )

func _companion_event(actor: PartyActor, health: HealthComponent) -> Dictionary:
    return {
        "member_id": actor.member_state.member_id,
        "class_id": String(actor.member_state.class_definition.id),
        "wall_seconds": _wall_seconds(),
        "game_seconds": (current_scene.get_node("GameRun") as GameRun).elapsed_time(),
        "health": health.current_health,
    }

func _matching_natural_revival_observed() -> bool:
    for down_event: Dictionary in down_events:
        for revive_event: Dictionary in revive_events:
            if int(down_event["member_id"]) == int(revive_event["member_id"]) and float(revive_event["wall_seconds"]) > float(down_event["wall_seconds"]):
                return true
    return false

func _observe_enemy_behavior(main: Node) -> void:
    for node: Node in get_nodes_in_group("hostile_actors"):
        var enemy := node as CharacterBody3D
        if enemy == null:
            continue
        if enemy.scene_file_path == "res://scenes/enemies/swarmer.tscn":
            swarmer_seen = true
            if enemy.velocity.length() > 0.1:
                swarmer_pursuit_seen = true
        elif enemy.scene_file_path == "res://scenes/enemies/spitter.tscn":
            spitter_seen = true
    for child: Node in main.get_node("Effects").get_children():
        if child.scene_file_path == "res://scenes/enemies/enemy_projectile.tscn" or String(child.name).begins_with("EnemyProjectile"):
            spitter_projectile_seen = true

func _drive_leader_input(main: Node, state: int) -> void:
    if state not in [RunStateMachine.State.RUNNING, RunStateMachine.State.BOSS]:
        _release_input()
        return
    var actions: PackedStringArray = ["move_right", "move_back", "move_left", "move_forward"]
    if state == RunStateMachine.State.RUNNING:
        var collection_phase := int(_wall_seconds()) % actions.size()
        _press_only(actions[collection_phase])
        return
    if _matching_natural_revival_observed():
        var victory_phase := int(_wall_seconds()) % actions.size()
        _press_only(actions[victory_phase])
        return
    var leader := main.get("leader") as PartyActor
    var boss := main.get("boss") as Node3D
    if boss == null or not is_instance_valid(boss):
        _release_input()
        return
    var boss_offset := boss.global_position - leader.global_position
    var active_action := int(boss.get("active_action"))
    var schedule := boss.get("schedule") as RefCounted
    var approaching_shockwave := active_action == BossActionSchedule.Action.SHOCKWAVE
    if schedule != null:
        approaching_shockwave = approaching_shockwave or (active_action < 0 and int(schedule.get("index")) == 1 and float(schedule.get("remaining")) <= 0.8)
    if active_action == BossActionSchedule.Action.SHOCKWAVE and last_boss_action != BossActionSchedule.Action.SHOCKWAVE:
        boss_shockwaves_observed += 1
    if last_boss_action == BossActionSchedule.Action.SHOCKWAVE and active_action != BossActionSchedule.Action.SHOCKWAVE:
        boss_retreat_until = _wall_seconds() + 4.5
    last_boss_action = active_action
    if not down_events.is_empty():
        _press_cardinal(-boss_offset)
        return
    if active_action == BossActionSchedule.Action.CHARGE:
        _release_input()
        return
    if approaching_shockwave:
        _press_cardinal(boss_offset)
    elif _wall_seconds() < boss_retreat_until:
        _press_cardinal(-boss_offset)
    elif boss_offset.length() < 17.0:
        _press_cardinal(-boss_offset)
    elif boss_offset.length() > 18.5:
        _press_cardinal(boss_offset)
    else:
        _release_input()

func _press_cardinal(direction: Vector3) -> void:
    if absf(direction.x) >= absf(direction.z):
        _press_only(&"move_right" if direction.x >= 0.0 else &"move_left")
    else:
        _press_only(&"move_back" if direction.z >= 0.0 else &"move_forward")

func _press_only(selected_action: StringName) -> void:
    for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
        if action == selected_action:
            Input.action_press(action)
        else:
            Input.action_release(action)

func _release_input() -> void:
    for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
        Input.action_release(action)

func _finish_victory(main: Node, game_run: GameRun) -> void:
    var manager := main.get_node("PartyManager") as PartyManager
    var counts := _class_counts(manager)
    var duplicate_seen := false
    for count: Variant in counts.values():
        if int(count) >= 2:
            duplicate_seen = true
    _check(_wall_seconds() >= 300.0, "ordinary wall duration reached five minutes")
    _check(is_equal_approx(game_run.elapsed_time(), 300.0), "boss triggered at 300 unpaused game seconds")
    _check(manager.members.size() == 4, "victory party has four members")
    _check(duplicate_seen, "victory party contains a duplicate class")
    _check(manager.active_tiers.size() >= 2, "victory party has at least two active overlapping traits")
    _check(_matching_natural_revival_observed(), "the same naturally downed companion automatically revived")
    _check(swarmer_seen and swarmer_pursuit_seen, "Swarmer pursuit behavior was observed")
    _check(spitter_seen and spitter_projectile_seen, "Spitter ranged projectile behavior was observed")
    _check(is_equal_approx(boss_trigger_game_time, 300.0), "recorded boss trigger equals 300 seconds")
    _check((main.get_node("HUD/RunResultPanel") as Control).visible, "victory result panel is visible")
    var screenshot_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))
    _check(screenshot_error == OK, "boss victory viewport screenshot saved")
    _write_evidence(main, game_run, failures.is_empty(), SCREENSHOT_PATH)
    if failures.is_empty():
        print("TASK_13_VICTORY_ACCEPTANCE: PASS wall=%.3f game=%.3f party=%s tiers=%s" % [_wall_seconds(), game_run.elapsed_time(), _composition_text(manager), _active_tier_text(manager)])
        quit(0)
        return
    _finish_failure()

func _write_evidence(main: Node, game_run: GameRun, passed: bool, screenshot: String) -> void:
    var manager := main.get_node("PartyManager") as PartyManager
    var evidence := {
        "source_commit": SOURCE_COMMIT,
        "status": "PASS" if passed else "FAIL",
        "run_kind": "automated ordinary-speed public-input acceptance",
        "automated_ordinary_speed": true,
        "direct_damage_injection": false,
        "wall_seconds": _wall_seconds(),
        "game_seconds": game_run.elapsed_time(),
        "debug_time_scale": game_run.debug_time_scale,
        "party_composition": _composition_text(manager),
        "class_counts": _class_counts(manager),
        "active_traits": _active_tier_text(manager),
        "natural_down_events": down_events,
        "automatic_revive_events": revive_events,
        "companion_damage_events": companion_damage_events,
        "matching_natural_revival_observed": _matching_natural_revival_observed(),
        "input_strategy": "UI choices plus square mapped movement to game 300; mapped boss hover, shockwave approach, and post-shock retreat; flee after natural down; square movement after automatic revive",
        "swarmer_seen": swarmer_seen,
        "swarmer_pursuit_seen": swarmer_pursuit_seen,
        "spitter_seen": spitter_seen,
        "spitter_projectile_seen": spitter_projectile_seen,
        "boss_trigger_game_time": boss_trigger_game_time,
        "boss_trigger_wall_time": boss_trigger_wall_time,
        "boss_shockwaves_observed": boss_shockwaves_observed,
        "terminal_state": game_run.current_state(),
        "result_title": (main.get_node("HUD/RunResultPanel/Panel/Content/Title") as Label).text,
        "screenshot": screenshot,
        "choices": choice_log,
        "failures": failures,
    }
    var file := FileAccess.open(ProjectSettings.globalize_path(EVIDENCE_PATH), FileAccess.WRITE)
    file.store_string(JSON.stringify(evidence, "  "))

func _class_counts(manager: PartyManager) -> Dictionary:
    var counts: Dictionary = {}
    for member: PartyMemberState in manager.members:
        counts[member.class_definition.id] = int(counts.get(member.class_definition.id, 0)) + 1
    return counts

func _composition_text(manager: PartyManager) -> String:
    var names: PackedStringArray = []
    for member: PartyMemberState in manager.members:
        names.append(member.class_definition.display_name)
    return " + ".join(names)

func _active_tier_text(manager: PartyManager) -> String:
    var entries: PackedStringArray = []
    var ids: Array = manager.active_tiers.keys()
    ids.sort()
    for trait_id: StringName in ids:
        entries.append("%s:%d" % [trait_id, manager.active_tier(trait_id)])
    return ", ".join(entries)

func _wall_seconds() -> float:
    return float(Time.get_ticks_msec() - started_ticks) / 1000.0 if started_ticks > 0 else 0.0

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures.append(label)

func _finish_failure() -> void:
    for failure: String in failures:
        push_error("TASK_13_VICTORY_FAILURE: %s" % failure)
    print("TASK_13_VICTORY_ACCEPTANCE: FAIL (%d failures)" % failures.size())
    quit(1)
