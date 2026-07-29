extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var sandbox := (load("res://scenes/dev/combat_sandbox.tscn") as PackedScene).instantiate()
    root.add_child(sandbox)
    current_scene = sandbox
    await process_frame
    for class_id: StringName in [&"fighter", &"ranger", &"cleric", &"mage"]:
        sandbox.call("spawn_class", class_id)
    var manager := sandbox.get_node("PartyManager") as PartyManager
    _check(manager.members.size() == 4, "public class actions enforce four-member cap")
    _check(int(manager.active_tiers.size()) >= 1, "live party composition activates traits")

    var swarmer := sandbox.call("spawn_enemy", &"swarmer") as Node3D
    var spitter := sandbox.call("spawn_enemy", &"spitter") as Node3D
    var boss := sandbox.call("spawn_boss") as Node3D
    _check(swarmer != null and swarmer.scene_file_path == "res://scenes/enemies/swarmer.tscn", "Swarmer action uses production scene")
    _check(spitter != null and spitter.scene_file_path == "res://scenes/enemies/spitter.tscn", "Spitter action uses production scene")
    _check(boss != null and boss.scene_file_path == "res://scenes/enemies/forge_guardian.tscn", "boss action uses production scene")

    var downed: bool = bool(sandbox.call("down_selected_companion"))
    var companion := sandbox.get_node("Actors").get_child(1) as PartyActor
    var health := companion.get_node("HealthComponent") as HealthComponent
    _check(downed and health.is_downed, "sandbox-only selected companion tuning action works")
    sandbox.call("clear_hostiles")
    await process_frame
    _check(sandbox.get_node("Enemies").get_child_count() == 0, "clear action removes all hostiles")

    if failures.is_empty():
        print("TASK_13_SANDBOX_SMOKE: PASS party=%d active_tiers=%d" % [manager.members.size(), manager.active_tiers.size()])
        quit(0)
        return
    for failure: String in failures:
        push_error("TASK_13_SANDBOX_FAILURE: %s" % failure)
    print("TASK_13_SANDBOX_SMOKE: FAIL (%d failures)" % failures.size())
    quit(1)

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures.append(label)
