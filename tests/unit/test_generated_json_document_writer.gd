extends RefCounted

const GeneratedWriter = preload("res://scripts/tools/generated_json_document_writer.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_writer_owns_recovery_preflight(failures)
	_test_writer_uses_fixed_target_and_canonical_encoder(failures)
	return failures

func _test_writer_owns_recovery_preflight(failures: Array[String]) -> void:
	var writer := GeneratedWriter.new()
	TestAssertions.truthy(writer.has_method("recover"), "fixed generated writer exposes recovery without target restoration details", failures)
	if writer.has_method("recover"):
		TestAssertions.equal(writer.call("recover"), {"ok": true, "state": "unchanged", "cleanupDebt": false, "stage": "recovery", "reason": ""}, "fixed writer proves no-pending recovery state", failures)

func _test_writer_uses_fixed_target_and_canonical_encoder(failures: Array[String]) -> void:
	var target := GeneratedWriter.TARGET
	var access_directory := target.get_base_dir()
	var world_directory := access_directory.get_base_dir()
	var access_directory_existed := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(access_directory))
	var world_directory_existed := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(world_directory))
	var before_exists := FileAccess.file_exists(target)
	var before := FileAccess.get_file_as_bytes(target) if before_exists else PackedByteArray()
	var result: Variant = GeneratedWriter.new().write(_valid_document())
	TestAssertions.truthy(result is Dictionary, "fixed generated writer returns a structured outcome", failures)
	if result is Dictionary:
		TestAssertions.equal(result as Dictionary, {"ok": true, "state": "committed", "cleanupDebt": false, "stage": "verified", "reason": ""}, "fixed generated writer returns its verified structured outcome", failures)
	TestAssertions.truthy(FileAccess.file_exists(target), "generated writer uses its fixed Party Forge target", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), CityAccessSnapshotCodec.encode_document(_valid_document()), "generated writer promotes the codec bytes exactly", failures)
	var unchanged: Variant = GeneratedWriter.new().write(_valid_document())
	TestAssertions.equal(unchanged, {"ok": true, "state": "unchanged", "cleanupDebt": false, "stage": "compare", "reason": ""}, "fixed generated writer owns exact unchanged comparison", failures)
	_restore_target(target, before_exists, before, access_directory, access_directory_existed, world_directory, world_directory_existed)
	TestAssertions.equal(FileAccess.file_exists(target), before_exists, "generated writer restores its fixed target existence", failures)
	if before_exists:
		TestAssertions.equal(FileAccess.get_file_as_bytes(target), before, "generated writer restores the fixed target bytes", failures)
	TestAssertions.equal(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(access_directory)), access_directory_existed, "generated writer restores the fixed target directory", failures)
	TestAssertions.equal(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(world_directory)), world_directory_existed, "generated writer restores the fixed target parent directory", failures)

func _valid_document() -> Dictionary:
	return {
		"format": CityAccessSnapshotLoader.FORMAT,
		"version": CityAccessSnapshotLoader.VERSION,
		"source": {"adapter": "latticewright-runtime-v3-city-access", "format": "latticewright-runtime", "formatVersion": 3, "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"},
		"locations": [{"id": "city.apothecary", "destinationId": "city.apothecary.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "always", "value": ""}]}],
	}

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()

func _restore_target(target: String, existed: bool, bytes: PackedByteArray, access_directory: String, access_directory_existed: bool, world_directory: String, world_directory_existed: bool) -> void:
	if existed:
		_write_bytes(target, bytes)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	if not access_directory_existed and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(access_directory)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(access_directory))
	if not world_directory_existed and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(world_directory)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(world_directory))
