extends RefCounted

const AdapterRegistry = preload("res://scripts/progression/passive_tree/latticewright_runtime_adapter_registry.gd")

var _root := ""
var _adapter_calls := 0
var _fallback_calls := 0
var _last_source_path := ""
var _last_source_sha256 := ""

func run() -> Array[String]:
	var failures: Array[String] = []
	_root = "user://tests/latticewright_adapter_registry_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_root))
	_test_strict_path_reader_boundaries(failures)
	_test_root_envelope_rejections(failures)
	_test_version_dispatch_and_failure_propagation(failures)
	_cleanup()
	return failures

func _test_strict_path_reader_boundaries(failures: Array[String]) -> void:
	var registry := AdapterRegistry.new()
	TestAssertions.truthy(registry.register_adapter(3, Callable(self, "_recording_adapter")), "format 3 adapter registers", failures)
	var source := JSON.stringify(_valid_runtime())
	var exact_bytes := (source + " ".repeat(AdapterRegistry.MAX_RUNTIME_JSON_BYTES - source.to_utf8_buffer().size())).to_utf8_buffer()
	var exact_path := _root.path_join("exact.json")
	_write_bytes(exact_path, exact_bytes)
	_adapter_calls = 0
	var exact := registry.load_path(exact_path)
	TestAssertions.equal(_adapter_calls, 1, "exact 64 MiB source reaches the registered adapter", failures)
	_assert_failure_contains(exact, "adapter sentinel", "exact-size adapter result propagates", failures)
	TestAssertions.equal(_last_source_path, exact_path, "adapter receives exact source path", failures)
	TestAssertions.truthy(not _last_source_sha256.is_empty(), "adapter receives exact source hash", failures)

	var plus_one_path := _root.path_join("plus-one.json")
	_write_bytes(plus_one_path, PackedByteArray(exact_bytes) + PackedByteArray([0x20]))
	var plus_one := registry.load_path(plus_one_path)
	TestAssertions.equal(_adapter_calls, 1, "oversize source rejects before adapter dispatch", failures)
	_assert_failure_contains(plus_one, "size", "64 MiB plus one rejects", failures)

	for test_case: Dictionary in [
		{"name": "invalid-utf8", "bytes": PackedByteArray([0xff]), "fragment": "decode"},
		{"name": "bom", "bytes": PackedByteArray([0xef, 0xbb, 0xbf, 0x7b, 0x7d]), "fragment": "decode"},
		{"name": "duplicate", "bytes": "{\"format\":1,\"format\":2}".to_utf8_buffer(), "fragment": "duplicate-key"},
		{"name": "malformed", "bytes": "{\"format\":".to_utf8_buffer(), "fragment": "scan"},
		{"name": "array-root", "bytes": "[]".to_utf8_buffer(), "fragment": "parse"},
	]:
		var path := _root.path_join("%s.json" % String(test_case["name"]))
		_write_bytes(path, test_case["bytes"] as PackedByteArray)
		_assert_failure_contains(registry.load_path(path), String(test_case["fragment"]), "%s rejects" % test_case["name"], failures)
	TestAssertions.equal(_adapter_calls, 1, "invalid source shapes never reach an adapter", failures)

func _test_root_envelope_rejections(failures: Array[String]) -> void:
	var registry := AdapterRegistry.new()
	registry.register_adapter(3, Callable(self, "_recording_adapter"))
	for key: String in _valid_runtime().keys():
		var missing := _valid_runtime()
		missing.erase(key)
		_assert_failure_contains(registry.load_document(missing, "memory://missing-%s" % key, "hash"), key, "missing root key %s rejects" % key, failures)
	var unexpected := _valid_runtime()
	unexpected["unexpected"] = true
	_assert_failure_contains(registry.load_document(unexpected, "memory://unexpected", "hash"), "unexpected", "unexpected root key rejects", failures)

	for test_case: Dictionary in [
		{"name": "wrong-format", "key": "format", "value": "other", "fragment": "format"},
		{"name": "fractional-version", "key": "formatVersion", "value": 3.5, "fragment": "integer"},
		{"name": "zero-version", "key": "formatVersion", "value": 0, "fragment": "version"},
		{"name": "negative-version", "key": "formatVersion", "value": -1, "fragment": "version"},
	]:
		var document := _valid_runtime()
		document[test_case["key"]] = test_case["value"]
		_assert_failure_contains(registry.load_document(document, "memory://%s" % test_case["name"], "hash"), String(test_case["fragment"]), "%s rejects" % test_case["name"], failures)

func _test_version_dispatch_and_failure_propagation(failures: Array[String]) -> void:
	var registry := AdapterRegistry.new()
	TestAssertions.truthy(not registry.register_adapter(0, Callable(self, "_recording_adapter")), "nonpositive adapter version rejects", failures)
	TestAssertions.truthy(not registry.register_adapter(3, Callable()), "invalid adapter callable rejects", failures)
	TestAssertions.truthy(registry.register_adapter(3, Callable(self, "_recording_adapter")), "format 3 adapter registers", failures)
	TestAssertions.truthy(not registry.register_adapter(3, Callable(self, "_recording_adapter")), "duplicate adapter version rejects", failures)

	_adapter_calls = 0
	var selected := registry.load_document(_valid_runtime(), "memory://selected", "selected-hash")
	TestAssertions.equal(_adapter_calls, 1, "format 3 selects only its adapter", failures)
	TestAssertions.equal(_last_source_path, "memory://selected", "source path propagates", failures)
	TestAssertions.equal(_last_source_sha256, "selected-hash", "source hash propagates", failures)
	_assert_failure_contains(selected, "adapter sentinel", "adapter failure propagates unchanged", failures)

	var format_four := _valid_runtime()
	format_four["formatVersion"] = 4
	_assert_failure_contains(registry.load_document(format_four, "memory://format-four", "hash"), "adapter unavailable", "format 4 without adapter fails closed", failures)

	var no_fallback := AdapterRegistry.new()
	no_fallback.register_adapter(1, Callable(self, "_fallback_adapter"))
	_fallback_calls = 0
	_assert_failure_contains(no_fallback.load_document(_valid_runtime(), "memory://no-fallback", "hash"), "adapter unavailable", "format 3 never falls back to version 1", failures)
	TestAssertions.equal(_fallback_calls, 0, "version 1 fallback is never invoked", failures)

	var empty_result_registry := AdapterRegistry.new()
	empty_result_registry.register_adapter(3, Callable(self, "_empty_result_adapter"))
	_assert_failure_contains(
		empty_result_registry.load_document(_valid_runtime(), "memory://empty-result", "hash"),
		"inconsistent result",
		"adapter result without tree or errors fails closed",
		failures,
	)

	var partial_result_registry := AdapterRegistry.new()
	partial_result_registry.register_adapter(3, Callable(self, "_partial_result_adapter"))
	var partial := partial_result_registry.load_document(_valid_runtime(), "memory://partial-result", "hash")
	_assert_failure_contains(partial, "inconsistent result", "adapter result with tree and errors fails closed", failures)
	TestAssertions.equal(partial.tree, null, "inconsistent adapter result never exposes a partial tree", failures)

func _recording_adapter(_document: Dictionary, source_path: String, source_sha256: String) -> PassiveTreeLoadResult:
	_adapter_calls += 1
	_last_source_path = source_path
	_last_source_sha256 = source_sha256
	return PassiveTreeLoadResult.failure("adapter sentinel")

func _fallback_adapter(_document: Dictionary, _source_path: String, _source_sha256: String) -> PassiveTreeLoadResult:
	_fallback_calls += 1
	return PassiveTreeLoadResult.failure("fallback sentinel")

func _empty_result_adapter(_document: Dictionary, _source_path: String, _source_sha256: String) -> PassiveTreeLoadResult:
	return PassiveTreeLoadResult.new()

func _partial_result_adapter(_document: Dictionary, _source_path: String, _source_sha256: String) -> PassiveTreeLoadResult:
	var result := PassiveTreeLoadResult.failure("partial sentinel")
	result.tree = PassiveTreeDefinition.new()
	return result

func _valid_runtime() -> Dictionary:
	return {
		"format": "latticewright-progression",
		"formatVersion": 3,
		"projectId": "test-project",
		"name": "Test Runtime",
		"archetype": "passive-tree",
		"vocabulary": {},
		"schemas": {},
		"content": [],
		"graphs": [{"id": "test-graph"}],
		"graphPortals": [],
		"assets": [],
		"extensions": {},
	}

func _assert_failure_contains(result: PassiveTreeLoadResult, fragment: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not result.ok(), label, failures)
	TestAssertions.truthy(result.errors.any(func(error: String) -> bool: return fragment in error), "%s reports %s" % [label, fragment], failures)

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()

func _cleanup() -> void:
	var directory := DirAccess.open(_root)
	if directory != null:
		for file_name: String in directory.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_root.path_join(file_name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_root))
