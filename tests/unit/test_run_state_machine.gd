extends RefCounted

const REQUIRED_PATHS: PackedStringArray = [
    "res://scripts/game/run_state_machine.gd",
    "res://scripts/game/game_run.gd",
]

func run() -> Array[String]:
    var failures: Array[String] = []
    for path: String in REQUIRED_PATHS:
        TestAssertions.truthy(ResourceLoader.exists(path), "Task 11 resource exists: %s" % path, failures)
    if not failures.is_empty():
        return failures
    _test_clock_and_boss_boundary(failures)
    _test_level_up_pauses_clock(failures)
    _test_terminal_states_lock(failures)
    _test_boss_level_up_resume_state(failures)
    _test_game_run_pause_adapter_and_debug_gate(failures)
    return failures

func _test_clock_and_boss_boundary(failures: Array[String]) -> void:
    var machine := _new_machine()
    var boss_requests: Array[int] = [0]
    machine.connect("boss_requested", func() -> void: boss_requests[0] += 1)
    machine.call("start")
    machine.call("advance_run_time", 299.99)
    TestAssertions.equal(int(machine.get("state")), 1, "299.99 seconds remains RUNNING", failures)
    TestAssertions.near(float(machine.get("elapsed")), 299.99, 0.001, "run clock reaches 299.99", failures)
    machine.call("advance_run_time", 0.01)
    TestAssertions.equal(int(machine.get("state")), 3, "300 seconds enters BOSS", failures)
    TestAssertions.near(float(machine.get("elapsed")), 300.0, 0.001, "run clock clamps at 300", failures)
    TestAssertions.equal(boss_requests[0], 1, "boss requested exactly at 300 seconds", failures)
    machine.call("advance_run_time", 100.0)
    TestAssertions.equal(boss_requests[0], 1, "boss request emits exactly once", failures)

func _test_level_up_pauses_clock(failures: Array[String]) -> void:
    var machine := _new_machine()
    machine.call("start")
    machine.call("advance_run_time", 12.0)
    machine.call("begin_level_up")
    TestAssertions.equal(int(machine.get("state")), 2, "begin level-up enters LEVEL_UP", failures)
    machine.call("advance_run_time", 30.0)
    TestAssertions.near(float(machine.get("elapsed")), 12.0, 0.001, "LEVEL_UP does not advance run clock", failures)
    machine.call("resume_run")
    machine.call("advance_run_time", 1.0)
    TestAssertions.near(float(machine.get("elapsed")), 13.0, 0.001, "resumed run advances clock", failures)

func _test_terminal_states_lock(failures: Array[String]) -> void:
    var defeat_machine := _new_machine()
    var defeat_count: Array[int] = [0]
    var victory_count: Array[int] = [0]
    defeat_machine.connect("defeat", func() -> void: defeat_count[0] += 1)
    defeat_machine.connect("victory", func() -> void: victory_count[0] += 1)
    defeat_machine.call("start")
    defeat_machine.call("leader_defeated")
    defeat_machine.call("boss_defeated")
    defeat_machine.call("leader_defeated")
    defeat_machine.call("start")
    TestAssertions.equal(int(defeat_machine.get("state")), 5, "leader defeat locks DEFEAT", failures)
    TestAssertions.equal(defeat_count[0], 1, "defeat signal emits once", failures)
    TestAssertions.equal(victory_count[0], 0, "victory cannot overwrite defeat", failures)

    var victory_machine := _new_machine()
    defeat_count = [0]
    victory_count = [0]
    victory_machine.connect("defeat", func() -> void: defeat_count[0] += 1)
    victory_machine.connect("victory", func() -> void: victory_count[0] += 1)
    victory_machine.call("start")
    victory_machine.call("advance_run_time", 300.0)
    victory_machine.call("boss_defeated")
    victory_machine.call("leader_defeated")
    victory_machine.call("boss_defeated")
    victory_machine.call("start")
    TestAssertions.equal(int(victory_machine.get("state")), 4, "boss defeat locks VICTORY", failures)
    TestAssertions.equal(victory_count[0], 1, "victory signal emits once", failures)
    TestAssertions.equal(defeat_count[0], 0, "defeat cannot overwrite victory", failures)

func _test_game_run_pause_adapter_and_debug_gate(failures: Array[String]) -> void:
    var script := load("res://scripts/game/game_run.gd") as Script
    var run := script.new() as Node
    TestAssertions.equal(run.process_mode, Node.PROCESS_MODE_ALWAYS, "GameRun processes while tree is paused", failures)
    var tree := Engine.get_main_loop() as SceneTree
    tree.paused = false
    run.call("start_run")
    TestAssertions.truthy(not tree.paused, "RUNNING does not pause scene tree", failures)
    run.call("begin_level_up")
    TestAssertions.truthy(tree.paused, "LEVEL_UP pauses scene tree", failures)
    run.call("resume_run")
    TestAssertions.truthy(not tree.paused, "resume unpauses scene tree", failures)
    run.call("leader_defeated")
    TestAssertions.truthy(tree.paused, "DEFEAT pauses scene tree", failures)
    tree.paused = false
    TestAssertions.near(float(script.call("debug_scale_from_arguments", PackedStringArray(), true)), 1.0, 0.001, "ordinary timing is committed default", failures)
    TestAssertions.near(float(script.call("debug_scale_from_arguments", PackedStringArray(["--party-forge-debug-acceleration=60"]), false)), 1.0, 0.001, "release build ignores debug acceleration", failures)
    TestAssertions.near(float(script.call("debug_scale_from_arguments", PackedStringArray(["--party-forge-debug-acceleration=60"]), true)), 60.0, 0.001, "debug command-line flag enables acceleration", failures)
    run.free()

func _test_boss_level_up_resume_state(failures: Array[String]) -> void:
    var machine := _new_machine()
    machine.call("start")
    machine.call("advance_run_time", 300.0)
    machine.call("begin_level_up")
    TestAssertions.equal(int(machine.get("state")), 2, "BOSS can enter LEVEL_UP", failures)
    machine.call("resume_run")
    TestAssertions.equal(int(machine.get("state")), 3, "boss level-up resumes remembered BOSS state", failures)

func _new_machine() -> RefCounted:
    return (load("res://scripts/game/run_state_machine.gd") as Script).new() as RefCounted
