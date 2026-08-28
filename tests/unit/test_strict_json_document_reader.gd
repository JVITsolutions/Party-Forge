extends RefCounted

const Reader = preload("res://scripts/tools/strict_json_document_reader.gd")

var _root := ""

func run() -> Array[String]:
	var failures: Array[String] = []
	_root = "user://tests/strict_json_reader_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_root))
	_test_file_and_size_boundaries(failures)
	_test_encoding_and_json_rejections(failures)
	_test_duplicate_keys_and_exact_hash(failures)
	_cleanup()
	return failures

func _test_file_and_size_boundaries(failures: Array[String]) -> void:
	var missing := Reader.read(_root.path_join("missing.json"), 64 * 1024 * 1024)
	TestAssertions.truthy(not missing.ok() and missing.stage == "open", "missing source rejects with sanitized open diagnostics", failures)
	var directory := _root.path_join("directory")
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(directory))
	var directory_result := Reader.read(directory, 64 * 1024 * 1024)
	TestAssertions.truthy(not directory_result.ok() and directory_result.stage == "open", "directory source rejects", failures)
	var exact_path := _root.path_join("exact.json")
	_write_bytes(exact_path, ("{}" + " ".repeat(64 * 1024 * 1024 - 2)).to_utf8_buffer())
	TestAssertions.truthy(Reader.read(exact_path, 64 * 1024 * 1024).ok(), "64 MiB source is accepted", failures)
	var plus_one_path := _root.path_join("plus-one.json")
	_write_bytes(plus_one_path, ("{}" + " ".repeat(64 * 1024 * 1024 - 1)).to_utf8_buffer())
	var plus_one := Reader.read(plus_one_path, 64 * 1024 * 1024)
	TestAssertions.truthy(not plus_one.ok() and plus_one.stage == "size", "64 MiB plus one source rejects before parse", failures)

func _test_encoding_and_json_rejections(failures: Array[String]) -> void:
	for test_case: Dictionary in [
		{"name": "invalid utf8", "bytes": PackedByteArray([0xff]), "stage": "decode"},
		{"name": "utf8 bom", "bytes": PackedByteArray([0xef, 0xbb, 0xbf, 0x7b, 0x7d]), "stage": "decode"},
		{"name": "malformed json", "bytes": "{\"broken\":".to_utf8_buffer(), "stage": "scan"},
	]:
		var path := _root.path_join("%s.json" % String(test_case["name"]).replace(" ", "-"))
		_write_bytes(path, test_case["bytes"] as PackedByteArray)
		var result := Reader.read(path, 64 * 1024 * 1024)
		TestAssertions.truthy(not result.ok() and result.stage == test_case["stage"], "%s rejects with sanitized stage" % test_case["name"], failures)
		TestAssertions.truthy(not result.reason.contains(path) and not result.reason.contains("{"), "%s reason omits path and source bytes" % test_case["name"], failures)
	var replacement_bytes := "{\"value\":\"\uFFFD\"}".to_utf8_buffer()
	var replacement_path := _root.path_join("literal-replacement-character.json")
	_write_bytes(replacement_path, replacement_bytes)
	var replacement := Reader.read(replacement_path, 64 * 1024 * 1024)
	TestAssertions.truthy(replacement.ok(), "valid literal U+FFFD JSON source is accepted", failures)
	TestAssertions.equal(replacement.bytes, replacement_bytes, "literal U+FFFD preserves exact bytes", failures)

func _test_duplicate_keys_and_exact_hash(failures: Array[String]) -> void:
	for source: String in ["{\"id\":1,\"id\":2}", "{\"nested\":{\"id\":1,\"id\":2}}"]:
		var path := _root.path_join("duplicate-%d.json" % source.length())
		_write_bytes(path, source.to_utf8_buffer())
		var duplicate := Reader.read(path, 64 * 1024 * 1024)
		TestAssertions.truthy(not duplicate.ok() and duplicate.stage == "duplicate-key", "duplicate JSON object key rejects before Godot parsing", failures)
	var bytes := "{\n  \"value\": 1\n}\n".to_utf8_buffer()
	var hash_path := _root.path_join("hash.json")
	_write_bytes(hash_path, bytes)
	var result := Reader.read(hash_path, 64 * 1024 * 1024)
	TestAssertions.truthy(result.ok(), "valid strict JSON source reads", failures)
	TestAssertions.equal(result.bytes, bytes, "reader retains exact source bytes", failures)
	TestAssertions.equal(result.sha256, _sha256(bytes), "reader hashes exact source bytes", failures)
	TestAssertions.equal(float(result.document.get("value", 0.0)), 1.0, "reader returns parsed dictionary", failures)

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()

func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _cleanup() -> void:
	var directory := DirAccess.open(_root)
	if directory != null:
		for file_name: String in directory.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_root.path_join(file_name)))
		for directory_name: String in directory.get_directories():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_root.path_join(directory_name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_root))
