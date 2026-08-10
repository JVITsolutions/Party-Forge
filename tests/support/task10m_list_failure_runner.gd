extends SceneTree

const SUITE_DISCOVERY := preload("res://tests/support/test_suite_discovery.gd")


func _initialize() -> void:
    var directory_path := ProjectSettings.globalize_path("user://task10m-list-failure-directory")
    var make_error := DirAccess.make_dir_recursive_absolute(directory_path)
    if make_error != OK:
        push_error("TASK10M_LIST_FAILURE_PROBE_ERROR: cannot create real directory code=%d" % make_error)
        quit(2)
        return
    var directory := DirAccess.open(directory_path)
    if directory == null:
        push_error("TASK10M_LIST_FAILURE_PROBE_ERROR: cannot open real directory")
        quit(2)
        return
    var remove_error := DirAccess.remove_absolute(directory_path)
    if remove_error != OK:
        push_error("TASK10M_LIST_FAILURE_PROBE_ERROR: cannot remove real directory code=%d" % remove_error)
        quit(2)
        return
    var discovery := SUITE_DISCOVERY.collect("res://tests/unit", directory)
    var diagnostic := String(discovery["error"])
    var expected_prefix := "TEST_RUNNER_DISCOVERY_ERROR: cannot list unit suite directory res://tests/unit code="
    if not diagnostic.begins_with(expected_prefix) or not (discovery["paths"] as PackedStringArray).is_empty():
        push_error("TASK10M_LIST_FAILURE_PROBE_ERROR: unexpected result %s" % JSON.stringify(discovery))
        quit(2)
        return
    push_error(diagnostic)
    quit(1)
