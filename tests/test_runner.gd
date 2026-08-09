extends SceneTree

const SCRIPT_ERROR_CAPTURE := preload("res://tests/support/test_script_error_capture.gd")

func _initialize() -> void:
    var failures: Array[String] = []
    var script_errors := SCRIPT_ERROR_CAPTURE.new()
    OS.add_logger(script_errors)
    var discovery := _collect_suites("res://tests/unit")
    var suite_paths := discovery["paths"] as PackedStringArray
    var discovery_error := String(discovery["error"])
    if not discovery_error.is_empty():
        failures.append(discovery_error)
    elif suite_paths.is_empty():
        failures.append("TEST_RUNNER_DISCOVERY_ERROR: zero unit suites discovered in res://tests/unit")
    for suite_path: String in suite_paths:
        var suite_script: Script = load(suite_path)
        if suite_script == null:
            failures.append("%s :: suite failed to load" % suite_path)
            continue
        var suite: RefCounted = suite_script.new()
        var suite_result: Variant = suite.call(&"run")
        if not suite_result is Array:
            failures.append("%s :: suite did not return a failure array" % suite_path)
            continue
        var suite_failures: Array = suite_result as Array
        for failure: String in suite_failures:
            failures.append("%s :: %s" % [suite_path, failure])
    OS.remove_logger(script_errors)
    for script_error: String in script_errors.drain_after_detach():
        failures.append("SCRIPT ERROR :: %s" % script_error)
    if failures.is_empty():
        print("TEST_SUMMARY: PASS (%d suites)" % suite_paths.size())
        quit(0)
        return
    for failure: String in failures:
        push_error("TEST_FAILURE: %s" % failure)
    print("TEST_SUMMARY: FAIL (%d failures)" % failures.size())
    quit(1)

func _collect_suites(root: String) -> Dictionary:
    var paths: PackedStringArray = []
    var directory: DirAccess = DirAccess.open(root)
    if directory == null:
        return {
            "error": "TEST_RUNNER_DISCOVERY_ERROR: cannot open unit suite directory %s" % root,
            "paths": paths,
        }
    var list_error := directory.list_dir_begin()
    if list_error != OK:
        return {
            "error": "TEST_RUNNER_DISCOVERY_ERROR: cannot list unit suite directory %s code=%d" % [root, list_error],
            "paths": paths,
        }
    var name: String = directory.get_next()
    while not name.is_empty():
        if not directory.current_is_dir() and name.begins_with("test_") and name.ends_with(".gd"):
            paths.append(root.path_join(name))
        name = directory.get_next()
    directory.list_dir_end()
    paths.sort()
    return {"error": "", "paths": paths}
