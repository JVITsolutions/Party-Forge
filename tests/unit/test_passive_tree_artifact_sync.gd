extends RefCounted

const SOURCE := "res://data/passive_trees/city/party-forge-city.pstree"
const RUNTIME := "res://data/passive_trees/city/party-forge-city.pstree.json"
const SOURCE_SHA256 := "5358b5f93784b19de63ef26d7565325f80629d809bac33e79a966993f62be176"
const RUNTIME_SHA256 := "0c592cbfe053d8f2dde805f0677a989814ed41bafb12a0e384ff740e50581543"

func run() -> Array[String]:
	var failures: Array[String] = []
	var source_exists := FileAccess.file_exists(SOURCE)
	var runtime_exists := FileAccess.file_exists(RUNTIME)
	TestAssertions.truthy(source_exists, "exact LatticeWright City source is committed", failures)
	TestAssertions.truthy(runtime_exists, "exact LatticeWright City runtime is committed", failures)
	if not source_exists or not runtime_exists:
		return failures

	TestAssertions.equal(_sha256(SOURCE), SOURCE_SHA256, "City source matches canonical LF-normalized LatticeWright content", failures)
	TestAssertions.equal(_sha256(RUNTIME), RUNTIME_SHA256, "City runtime matches exact LatticeWright commit blob", failures)
	var source_document := JSON.parse_string(FileAccess.get_file_as_string(SOURCE)) as Dictionary
	var runtime_document := JSON.parse_string(FileAccess.get_file_as_string(RUNTIME)) as Dictionary
	TestAssertions.equal(source_document.get("projectFormat"), "latticewright-project", "source format is LatticeWright project v3", failures)
	TestAssertions.equal(source_document.get("projectVersion"), 3, "source version is 3", failures)
	TestAssertions.equal(runtime_document.get("format"), "latticewright-progression", "runtime format is LatticeWright progression", failures)
	TestAssertions.equal(runtime_document.get("formatVersion"), 3, "runtime version is 3", failures)
	TestAssertions.equal(runtime_document.get("projectId"), "party-forge-city", "runtime project identity", failures)
	TestAssertions.equal((runtime_document.get("content") as Array).size(), 37, "City content count", failures)
	TestAssertions.equal(((runtime_document.get("graphs") as Array)[0]["placements"] as Array).size(), 37, "City placement count", failures)
	TestAssertions.equal(((runtime_document.get("graphs") as Array)[0]["connections"] as Array).size(), 37, "City connection count", failures)
	TestAssertions.equal((runtime_document.get("graphPortals") as Array).size(), 6, "City portal count", failures)
	TestAssertions.equal(runtime_document.get("assets"), [], "City has no runtime assets", failures)
	return failures

func _sha256(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()
