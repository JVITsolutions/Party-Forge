extends RefCounted


static func collect(root: String, directory: DirAccess) -> Dictionary:
    var paths: PackedStringArray = []
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
    var name := directory.get_next()
    while not name.is_empty():
        if not directory.current_is_dir() and name.begins_with("test_") and name.ends_with(".gd"):
            paths.append(root.path_join(name))
        name = directory.get_next()
    directory.list_dir_end()
    paths.sort()
    return {"error": "", "paths": paths}
