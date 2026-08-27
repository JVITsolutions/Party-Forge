extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_valid_access_snapshot_loads(failures)
	_test_structural_contract(failures)
	_test_content_and_limit_contract(failures)
	_test_bytes_paths_and_defensive_copies(failures)
	_test_codec_is_canonical(failures)
	return failures


func _test_valid_access_snapshot_loads(failures: Array[String]) -> void:
	var document := _valid_document()
	var result := CityAccessSnapshotLoader.load_bytes(JSON.stringify(document).to_utf8_buffer())
	if not result is RefCounted:
		failures.append("valid access snapshot invokes the loader")
		return
	TestAssertions.truthy(result.ok(), "valid access snapshot loads atomically", failures)
	if not result.ok():
		return
	TestAssertions.equal(result.snapshot.locations.size(), 7, "all seven locations load", failures)
	TestAssertions.equal(String(result.snapshot.locations[0].id), "city.apothecary", "locations use ordinal ID order", failures)


func _test_structural_contract(failures: Array[String]) -> void:
	for path: Array in [["extra"], ["source", "extra"], ["locations", 0, "extra"], ["locations", 0, "visibleWhen", 0, "extra"]]:
		var document := _valid_document()
		_set_path(document, path, true)
		_assert_invalid(document, "unknown key at %s rejects" % [str(path)], failures)
	for path: Array in [["format"], ["version"], ["source"], ["locations"], ["source", "adapter"], ["source", "format"], ["source", "formatVersion"], ["source", "sha256"], ["locations", 0, "id"], ["locations", 0, "destinationId"], ["locations", 0, "visibleWhen"], ["locations", 0, "availableWhen"], ["locations", 0, "visibleWhen", 0, "kind"], ["locations", 0, "visibleWhen", 0, "value"]]:
		var missing := _valid_document()
		_erase_path(missing, path)
		_assert_invalid(missing, "missing %s rejects" % [str(path)], failures)
	for replacement: Variant in ["wrong", 2, [], "wrong"]:
		var document := _valid_document()
		document["format"] = replacement
		_assert_invalid(document, "wrong root primitive rejects", failures)
	for path: Array in [["source"], ["locations"], ["locations", 0], ["locations", 0, "visibleWhen"], ["locations", 0, "visibleWhen", 0]]:
		var document := _valid_document()
		_set_path(document, path, {} if path.size() > 1 else "wrong")
		_assert_invalid(document, "wrong primitive at %s rejects" % [str(path)], failures)
	for replacement: Variant in ["wrong", 0, 1.5, true]:
		var document := _valid_document()
		document["version"] = replacement
		_assert_invalid(document, "wrong root version rejects", failures)
	var wrong_adapter := _valid_document()
	wrong_adapter["source"]["adapter"] = "other"
	_assert_invalid(wrong_adapter, "wrong source adapter rejects", failures)
	var malformed_sha := _valid_document()
	malformed_sha["source"]["sha256"] = "A".repeat(64)
	_assert_invalid(malformed_sha, "malformed source SHA rejects", failures)


func _test_content_and_limit_contract(failures: Array[String]) -> void:
	for path: Array in [["locations", 0, "id"], ["locations", 0, "destinationId"], ["locations", 0, "visibleWhen", 0, "value"]]:
		var empty := _valid_document()
		_set_path(empty, path, "")
		if path[-1] == "value":
			_set_path(empty, ["locations", 0, "visibleWhen", 0, "kind"], "permanent_unlock")
		_assert_invalid(empty, "empty stable text at %s rejects" % [str(path)], failures)
		var too_long := _valid_document()
		_set_path(too_long, path, "a".repeat(CityAccessSnapshotLoader.MAX_TEXT_UNITS + 1))
		if path[-1] == "value":
			_set_path(too_long, ["locations", 0, "visibleWhen", 0, "kind"], "permanent_unlock")
		_assert_invalid(too_long, "too-long stable text at %s rejects" % [str(path)], failures)
	var exact_text := _valid_document()
	exact_text["locations"][0]["id"] = "a".repeat(CityAccessSnapshotLoader.MAX_TEXT_UNITS)
	exact_text["locations"][0]["destinationId"] = "b".repeat(CityAccessSnapshotLoader.MAX_TEXT_UNITS)
	exact_text["locations"][0]["visibleWhen"] = [{"kind": "permanent_unlock", "value": "c".repeat(CityAccessSnapshotLoader.MAX_TEXT_UNITS)}]
	TestAssertions.truthy(CityAccessSnapshotLoader.load_bytes(JSON.stringify(exact_text).to_utf8_buffer()).ok(), "exact text limit loads", failures)
	var duplicate_location := _valid_document()
	duplicate_location["locations"].append((duplicate_location["locations"][0] as Dictionary).duplicate(true))
	_assert_invalid(duplicate_location, "duplicate location ID rejects", failures)
	var duplicate_destination := _valid_document()
	duplicate_destination["locations"][1]["destinationId"] = duplicate_destination["locations"][0]["destinationId"]
	_assert_invalid(duplicate_destination, "duplicate destination ID rejects", failures)
	for kind: String in ["unknown", "always"]:
		var invalid_condition := _valid_document()
		invalid_condition["locations"][0]["visibleWhen"] = [{"kind": kind, "value": "bad"}]
		_assert_invalid(invalid_condition, "%s condition rejects malformed value" % kind, failures)
	var mixed_always := _valid_document()
	mixed_always["locations"][0]["visibleWhen"] = [{"kind": "always", "value": ""}, {"kind": "permanent_unlock", "value": "city-heart"}]
	_assert_invalid(mixed_always, "always cannot mix with another condition", failures)
	var wrong_prologue := _valid_document()
	wrong_prologue["locations"][0]["visibleWhen"] = [{"kind": "prologue_state", "value": "done"}]
	_assert_invalid(wrong_prologue, "unknown prologue state rejects", failures)
	var exact_conditions := _valid_document()
	exact_conditions["locations"][0]["visibleWhen"] = _unlock_conditions(CityAccessSnapshotLoader.MAX_CONDITIONS)
	TestAssertions.truthy(CityAccessSnapshotLoader.load_bytes(JSON.stringify(exact_conditions).to_utf8_buffer()).ok(), "exact condition limit loads", failures)
	var too_many_conditions := _valid_document()
	too_many_conditions["locations"][0]["visibleWhen"] = _unlock_conditions(CityAccessSnapshotLoader.MAX_CONDITIONS + 1)
	_assert_invalid(too_many_conditions, "plus-one condition limit rejects", failures)
	var exact_locations := _document_with_locations(CityAccessSnapshotLoader.MAX_LOCATIONS)
	TestAssertions.truthy(CityAccessSnapshotLoader.load_bytes(JSON.stringify(exact_locations).to_utf8_buffer()).ok(), "exact location limit loads", failures)
	_assert_invalid(_document_with_locations(CityAccessSnapshotLoader.MAX_LOCATIONS + 1), "plus-one location limit rejects", failures)


func _test_bytes_paths_and_defensive_copies(failures: Array[String]) -> void:
	var valid_bytes := JSON.stringify(_valid_document()).to_utf8_buffer()
	var exact_bytes := valid_bytes.duplicate()
	exact_bytes.append_array(" ".repeat(CityAccessSnapshotLoader.MAX_BYTES - exact_bytes.size()).to_utf8_buffer())
	TestAssertions.truthy(CityAccessSnapshotLoader.load_bytes(exact_bytes).ok(), "exact byte limit loads", failures)
	var oversized := exact_bytes.duplicate()
	oversized.append(32)
	_assert_invalid_bytes(oversized, "plus-one byte limit rejects", failures)
	_assert_invalid_bytes(PackedByteArray([0xff]), "malformed UTF-8 rejects", failures)
	var bom := PackedByteArray([0xef, 0xbb, 0xbf])
	bom.append_array(valid_bytes)
	_assert_invalid_bytes(bom, "UTF-8 BOM rejects", failures)
	_assert_invalid_result(CityAccessSnapshotLoader.load_path("user://missing-city-access-snapshot.json"), "missing path rejects", failures)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path("user://city-access-directory"))
	_assert_invalid_result(CityAccessSnapshotLoader.load_path("user://city-access-directory"), "unreadable directory rejects", failures)
	var result := CityAccessSnapshotLoader.load_bytes(valid_bytes)
	TestAssertions.truthy(result.ok(), "defensive-copy fixture loads", failures)
	if not result.ok():
		return
	var locations := result.snapshot.locations
	locations.clear()
	TestAssertions.equal(result.snapshot.locations.size(), 7, "snapshot locations getter is defensive", failures)
	var conditions := result.snapshot.locations[0].visible_when
	conditions.clear()
	TestAssertions.equal(result.snapshot.locations[0].visible_when.size(), 1, "location conditions getter is defensive", failures)
	var errors := result.errors
	errors.append("escaped")
	TestAssertions.equal(result.errors, [], "load-result errors getter is defensive", failures)


func _test_codec_is_canonical(failures: Array[String]) -> void:
	var document := _valid_document()
	document["locations"].reverse()
	document["locations"][0]["visibleWhen"] = [{"kind": "permanent_unlock", "value": "z"}, {"kind": "discovered_tree", "value": "a"}]
	var first := CityAccessSnapshotCodec.encode_document(document)
	var second := CityAccessSnapshotCodec.encode_document(document)
	TestAssertions.equal(first, second, "same logical document encodes identically", failures)
	TestAssertions.truthy(first.get_string_from_utf8().ends_with("\n"), "canonical document has one final newline", failures)
	TestAssertions.truthy(first.get_string_from_utf8().find('"id": "city.apothecary"') < first.get_string_from_utf8().find('"id": "city.market"'), "codec sorts locations", failures)
	var invalid := _valid_document()
	invalid["extra"] = true
	TestAssertions.equal(CityAccessSnapshotCodec.encode_document(invalid), PackedByteArray(), "codec rejects invalid documents", failures)


func _valid_document() -> Dictionary:
	var locations: Array = []
	for location_id: String in [
		"city.market", "city.apothecary", "city.guild", "city.harbor", "city.inn", "city.library", "city.watch",
	]:
		locations.append({
			"id": location_id,
			"destinationId": "%s.destination" % location_id,
			"visibleWhen": [{"kind": "always", "value": ""}],
			"availableWhen": [{"kind": "always", "value": ""}],
		})
	return {
		"format": "party-forge-access-snapshot",
		"version": 1,
		"source": {
			"adapter": "latticewright-runtime-v3-city-access",
			"format": "latticewright-runtime",
			"formatVersion": 3,
			"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
		},
		"locations": locations,
	}


func _document_with_locations(count: int) -> Dictionary:
	var document := _valid_document()
	var locations: Array[Dictionary] = []
	for index: int in count:
		locations.append({
			"id": "city.location.%03d" % index,
			"destinationId": "city.destination.%03d" % index,
			"visibleWhen": [{"kind": "always", "value": ""}],
			"availableWhen": [{"kind": "always", "value": ""}],
		})
	document["locations"] = locations
	return document


func _unlock_conditions(count: int) -> Array[Dictionary]:
	var conditions: Array[Dictionary] = []
	for index: int in count:
		conditions.append({"kind": "permanent_unlock", "value": "unlock.%d" % index})
	return conditions


func _set_path(document: Dictionary, path: Array, value: Variant) -> void:
	var target: Variant = document
	for index: int in range(path.size() - 1):
		target = target[path[index]]
	target[path[-1]] = value


func _erase_path(document: Dictionary, path: Array) -> void:
	var target: Variant = document
	for index: int in range(path.size() - 1):
		target = target[path[index]]
	(target as Dictionary).erase(path[-1])


func _assert_invalid(document: Dictionary, label: String, failures: Array[String]) -> void:
	_assert_invalid_result(CityAccessSnapshotLoader.load_bytes(JSON.stringify(document).to_utf8_buffer()), label, failures)


func _assert_invalid_bytes(bytes: PackedByteArray, label: String, failures: Array[String]) -> void:
	_assert_invalid_result(CityAccessSnapshotLoader.load_bytes(bytes), label, failures)


func _assert_invalid_result(result: CityAccessLoadResult, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not result.ok(), label, failures)
	TestAssertions.equal(result.snapshot, null, "%s returns no partial snapshot" % label, failures)
	TestAssertions.truthy(not result.errors.is_empty(), "%s reports an error" % label, failures)
