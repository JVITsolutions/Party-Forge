extends RefCounted

const SOURCE := "res://data/passive_trees/city/party-forge-city.pstree"
const RUNTIME := "res://data/passive_trees/city/party-forge-city.pstree.json"

func run() -> Array[String]:
    var failures: Array[String] = []
    var source_exists := FileAccess.file_exists(SOURCE)
    var runtime_exists := FileAccess.file_exists(RUNTIME)
    TestAssertions.truthy(source_exists, "editable City source is committed", failures)
    TestAssertions.truthy(runtime_exists, "runtime City export is committed", failures)
    if not source_exists or not runtime_exists:
        return failures

    var source_document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    var runtime_document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUNTIME))
    TestAssertions.equal(source_document.get("projectFormat"), "passive-tree-project", "source format", failures)
    TestAssertions.equal(runtime_document.get("format"), "passive-skill-tree", "runtime format", failures)
    TestAssertions.equal(_canonical_runtime(source_document.get("tree")), runtime_document, "source tree matches runtime export semantically", failures)
    TestAssertions.equal((runtime_document.get("nodes") as Array).size(), 30, "City node count", failures)
    TestAssertions.equal((runtime_document.get("connections") as Array).size(), 30, "City connection count", failures)
    return failures

func _canonical_runtime(source_tree: Dictionary) -> Dictionary:
    var runtime := source_tree.duplicate(true)
    (runtime.get("nodes") as Array).sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return String(left.get("id")) < String(right.get("id"))
    )
    (runtime.get("connections") as Array).sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return String(left.get("id")) < String(right.get("id"))
    )
    if (runtime.get("groups") as Array).is_empty():
        runtime.erase("groups")
    if (runtime.get("decorations") as Array).is_empty():
        runtime.erase("decorations")
    return runtime
