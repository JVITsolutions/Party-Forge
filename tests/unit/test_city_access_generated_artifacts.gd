extends RefCounted

const AUTHORING_PATH := "res://design/progression/latticewright/party-forge-city-access.pstree"
const RUNTIME_PATH := "res://design/progression/latticewright/party-forge-city-access.pstree.json"
const SNAPSHOT_PATH := "res://data/world/access/party-forge-city-access.snapshot.json"
const MAX_SOURCE_BYTES := 64 * 1024 * 1024
const ACCESS_RUNTIME_PATHS := [
	"res://scripts/world/access",
	"res://scripts/tools/latticewright_runtime_v3_city_access_importer.gd",
	"res://tools/import_latticewright_access_snapshot.gd",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_checked_in_city_access_artifacts(failures)
	_test_runtime_code_has_no_city_access_pstree_reference(failures)
	return failures

func _test_checked_in_city_access_artifacts(failures: Array[String]) -> void:
	for path: String in [AUTHORING_PATH, RUNTIME_PATH, SNAPSHOT_PATH]:
		TestAssertions.truthy(FileAccess.file_exists(path), "%s is checked in" % path, failures)
	if not FileAccess.file_exists(AUTHORING_PATH) or not FileAccess.file_exists(RUNTIME_PATH) or not FileAccess.file_exists(SNAPSHOT_PATH):
		return
	var authoring := StrictJsonDocumentReader.read(AUTHORING_PATH, MAX_SOURCE_BYTES)
	var runtime := StrictJsonDocumentReader.read(RUNTIME_PATH, MAX_SOURCE_BYTES)
	TestAssertions.truthy(authoring.ok(), "authoring source passes the strict JSON reader", failures)
	TestAssertions.truthy(runtime.ok(), "runtime source passes the strict JSON reader", failures)
	if not authoring.ok() or not runtime.ok():
		return
	TestAssertions.equal(authoring.document.get("projectId", ""), "party-forge-city-access", "authoring source has the City Access identity", failures)
	TestAssertions.equal(runtime.document.get("projectId", ""), "party-forge-city-access", "runtime source has the City Access identity", failures)
	var translated := LatticewrightRuntimeV3CityAccessImporter.translate(runtime.document, runtime.sha256)
	TestAssertions.truthy(translated.ok(), "runtime source retranslates through the production importer", failures)
	if not translated.ok():
		return
	var canonical := CityAccessSnapshotCodec.encode_document(translated.candidate)
	var snapshot_bytes := FileAccess.get_file_as_bytes(SNAPSHOT_PATH)
	TestAssertions.truthy(not canonical.is_empty(), "retranslation produces canonical snapshot bytes", failures)
	TestAssertions.equal(canonical, snapshot_bytes, "checked-in snapshot bytes equal the canonical retranslation", failures)
	TestAssertions.equal(translated.candidate["source"]["sha256"], runtime.sha256, "candidate source SHA-256 hashes exact runtime bytes", failures)
	var loaded := CityAccessSnapshotLoader.load_bytes(snapshot_bytes)
	TestAssertions.truthy(loaded.ok(), "production snapshot loader accepts checked-in snapshot bytes", failures)
	if not loaded.ok():
		return
	TestAssertions.equal(loaded.snapshot.source_sha256, runtime.sha256, "loaded snapshot preserves the runtime-byte source SHA-256", failures)
	TestAssertions.equal(_location_rows(loaded.snapshot.locations), _expected_rows(), "loaded snapshot has the exact seven City access rows", failures)

func _test_runtime_code_has_no_city_access_pstree_reference(failures: Array[String]) -> void:
	for path: String in _runtime_script_paths():
		var source := FileAccess.get_file_as_string(path)
		TestAssertions.truthy(not source.contains(AUTHORING_PATH) and not source.contains(RUNTIME_PATH), "%s does not reference City Access .pstree paths" % path, failures)

func _runtime_script_paths() -> Array[String]:
	var paths: Array[String] = []
	for root: String in ACCESS_RUNTIME_PATHS:
		if root.ends_with(".gd"):
			paths.append(root)
		else:
			_collect_scripts(root, paths)
	paths.sort()
	return paths

func _collect_scripts(root: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			var path := root.path_join(name)
			if directory.current_is_dir():
				_collect_scripts(path, paths)
			elif name.ends_with(".gd"):
				paths.append(path)
		name = directory.get_next()
	directory.list_dir_end()

func _location_rows(locations: Array[CityAccessLocation]) -> Array:
	var rows: Array = []
	for location: CityAccessLocation in locations:
		rows.append({
			"id": String(location.id),
			"destinationId": String(location.destination_id),
			"visibleWhen": _condition_rows(location.visible_when),
			"availableWhen": _condition_rows(location.available_when),
		})
	return rows

func _condition_rows(conditions: Array[CityAccessCondition]) -> Array:
	var rows: Array = []
	for condition: CityAccessCondition in conditions:
		rows.append({"kind": String(condition.kind), "value": condition.value})
	return rows

func _expected_rows() -> Array:
	return [
		{"id": "city.apothecary", "destinationId": "city.apothecary.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "always", "value": ""}]},
		{"id": "city.coliseum_road", "destinationId": "city.coliseum_road.route", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "always", "value": ""}]},
		{"id": "city.inn", "destinationId": "city.inn.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "permanent_unlock", "value": "service:hero_registry"}]},
		{"id": "city.merchant", "destinationId": "city.merchant.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "permanent_unlock", "value": "service:city_vendors"}]},
		{"id": "city.scholars_archive", "destinationId": "city.scholars_archive.interior", "visibleWhen": [{"kind": "prologue_state", "value": "completed"}], "availableWhen": [{"kind": "prologue_state", "value": "completed"}]},
		{"id": "city.smithy", "destinationId": "city.smithy.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "permanent_unlock", "value": "service:equipment_upgrading"}]},
		{"id": "city.warehouse", "destinationId": "city.warehouse.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "permanent_unlock", "value": "stash"}]},
	]
