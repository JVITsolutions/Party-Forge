extends RefCounted

const GeneratedWriter = preload("res://scripts/tools/generated_json_document_writer.gd")

var _root := ""

func run() -> Array[String]:
	var failures: Array[String] = []
	_root = "user://tests/generated_json_document_writer_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_root)
	var fixed_target_bytes := FileAccess.get_file_as_bytes(GeneratedWriter.TARGET)
	TestAssertions.truthy(_tree_entries(GeneratedWriter.STAGING_ROOT).is_empty(), "fixed generated staging root starts without evidence", failures)
	var supports_isolation := _assert_isolated_path_seam(failures)
	if supports_isolation:
		_test_writer_owns_recovery_preflight(failures)
		_test_writer_uses_fixed_defaults_and_isolated_filesystem(failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(GeneratedWriter.TARGET), fixed_target_bytes, "writer tests never alter the fixed checked-in snapshot bytes", failures)
	TestAssertions.truthy(_tree_entries(GeneratedWriter.STAGING_ROOT).is_empty(), "writer tests leave no fixed staging evidence", failures)
	ProfileTestSupport.remove_tree(_root)
	return failures

func _assert_isolated_path_seam(failures: Array[String]) -> bool:
	var argument_count := -1
	var probe := GeneratedWriter.new()
	for method: Dictionary in probe.get_script().get_script_method_list():
		if StringName(method.get("name", &"")) == &"_init":
			argument_count = (method.get("args", []) as Array).size()
			break
	TestAssertions.equal(argument_count, 3, "generated writer accepts document-store, target, and staging-root dependencies", failures)
	return argument_count == 3

func _test_writer_owns_recovery_preflight(failures: Array[String]) -> void:
	var writer: Variant = _new_isolated_writer(AtomicJsonStore.new(), _root.path_join("recover-target.json"), _root.path_join("recover-staging"))
	TestAssertions.truthy(writer.has_method("recover"), "generated writer exposes recovery without restoration details", failures)
	if writer.has_method("recover"):
		TestAssertions.equal(writer.call("recover"), {"resolution": "none", "cleanupDebt": false, "stage": "recovery", "reason": ""}, "isolated writer proves no-pending recovery state", failures)

func _test_writer_uses_fixed_defaults_and_isolated_filesystem(failures: Array[String]) -> void:
	TestAssertions.equal(GeneratedWriter.TARGET, "res://data/world/access/party-forge-city-access.snapshot.json", "generated writer retains its fixed production target", failures)
	TestAssertions.equal(GeneratedWriter.STAGING_ROOT, "res://.party-forge-tools/latticewright-city-access", "generated writer retains its fixed production staging root", failures)
	var target := _root.path_join("write-target.json")
	var staging_root := _root.path_join("write-staging")
	var writer: Variant = _new_isolated_writer(AtomicJsonStore.new(), target, staging_root)
	var result: Variant = writer.call("write", _valid_document())
	TestAssertions.truthy(result is Dictionary, "isolated generated writer returns a structured outcome", failures)
	if result is Dictionary:
		TestAssertions.equal(result as Dictionary, {"ok": true, "state": "committed", "cleanupDebt": false, "stage": "verified", "reason": ""}, "isolated generated writer returns its verified structured outcome", failures)
	TestAssertions.truthy(FileAccess.file_exists(target), "generated writer uses its injected test target", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), CityAccessSnapshotCodec.encode_document(_valid_document()), "generated writer promotes codec bytes exactly", failures)
	var unchanged: Variant = writer.call("write", _valid_document())
	TestAssertions.equal(unchanged, {"ok": true, "state": "unchanged", "cleanupDebt": false, "stage": "compare", "reason": ""}, "generated writer owns exact unchanged comparison", failures)
	TestAssertions.truthy(_tree_entries(staging_root).is_empty(), "isolated writer leaves no staging evidence after success", failures)

func _new_isolated_writer(documents: AtomicJsonStore, target: String, staging_root: String) -> Variant:
	var writer := GeneratedWriter.new()
	writer.call("_init", documents, target, staging_root)
	return writer

func _valid_document() -> Dictionary:
	return {
		"format": CityAccessSnapshotLoader.FORMAT,
		"version": CityAccessSnapshotLoader.VERSION,
		"source": {"adapter": "latticewright-runtime-v3-city-access", "format": "latticewright-runtime", "formatVersion": 3, "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"},
		"locations": [{"id": "city.apothecary", "destinationId": "city.apothecary.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "always", "value": ""}]}],
	}

func _tree_entries(root: String) -> Array[String]:
	var entries: Array[String] = []
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		var directory := DirAccess.open(current)
		if directory == null:
			continue
		for file_name: String in directory.get_files():
			entries.append(current.path_join(file_name))
		for directory_name: String in directory.get_directories():
			var child := current.path_join(directory_name)
			entries.append(child)
			pending.append(child)
	entries.sort()
	return entries
