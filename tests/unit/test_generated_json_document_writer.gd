extends RefCounted

const GeneratedWriter = preload("res://scripts/tools/generated_json_document_writer.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_writer_uses_fixed_target_and_canonical_encoder(failures)
	return failures

func _test_writer_uses_fixed_target_and_canonical_encoder(failures: Array[String]) -> void:
	var target := GeneratedWriter.TARGET
	var before_exists := FileAccess.file_exists(target)
	var before := FileAccess.get_file_as_bytes(target) if before_exists else PackedByteArray()
	var result := GeneratedWriter.new().write(_valid_document())
	TestAssertions.equal(result, "", "fixed generated writer commits a valid canonical document", failures)
	TestAssertions.truthy(FileAccess.file_exists(target), "generated writer uses its fixed Party Forge target", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), CityAccessSnapshotCodec.encode_document(_valid_document()), "generated writer promotes the codec bytes exactly", failures)
	if before_exists:
		_write_bytes(target, before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target))

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
