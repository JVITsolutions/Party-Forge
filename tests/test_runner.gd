extends SceneTree

func _initialize() -> void:
    var failures: Array[String] = []
    var suite_paths: PackedStringArray = _collect_suites("res://tests/unit")
    for suite_path: String in suite_paths:
        var suite_script: Script = load(suite_path)
        var suite: RefCounted = suite_script.new()
        var suite_failures: Array[String] = suite.run()
        for failure: String in suite_failures:
            failures.append("%s :: %s" % [suite_path, failure])
    if failures.is_empty():
        print("TEST_SUMMARY: PASS (%d suites)" % suite_paths.size())
        quit(0)
        return
    for failure: String in failures:
        push_error("TEST_FAILURE: %s" % failure)
    print("TEST_SUMMARY: FAIL (%d failures)" % failures.size())
    quit(1)

func _collect_suites(root: String) -> PackedStringArray:
    var paths: PackedStringArray = []
    var directory: DirAccess = DirAccess.open(root)
    if directory == null:
        return paths
    directory.list_dir_begin()
    var name: String = directory.get_next()
    while not name.is_empty():
        if not directory.current_is_dir() and name.begins_with("test_") and name.ends_with(".gd"):
            paths.append(root.path_join(name))
        name = directory.get_next()
    directory.list_dir_end()
    paths.sort()
    return paths
