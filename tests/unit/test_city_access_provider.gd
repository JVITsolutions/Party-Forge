extends RefCounted

const PROVIDER_PATH := "res://scripts/world/access/city_access_provider.gd"
const RESULT_PATH := "res://scripts/world/access/city_access_provider_result.gd"
const LEGACY := 0
const CANDIDATE := 1
const CANDIDATE_FAILED := 2
const SNAPSHOT_PATH := "res://data/world/access/party-forge-city-access.snapshot.json"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_provider_selection(failures)
	_test_provider_result_is_immutable(failures)
	_test_provider_result_storage_is_opaque_and_released(failures)
	return failures


func _test_provider_selection(failures: Array[String]) -> void:
	TestAssertions.truthy(FileAccess.file_exists(PROVIDER_PATH), "City access provider script exists", failures)
	if not FileAccess.file_exists(PROVIDER_PATH):
		return
	var provider_script := load(PROVIDER_PATH)
	TestAssertions.truthy(provider_script != null, "City access provider script loads", failures)
	if provider_script == null:
		return
	var snapshot := _fixture_snapshot(failures)
	if snapshot == null:
		return
	var profile := ProfileState.new_profile("city-access-provider-profile", "Provider", 1)

	var disabled_calls: Array[String] = []
	var disabled_provider = provider_script.new(func(path: String) -> CityAccessLoadResult:
		disabled_calls.append(path)
		return CityAccessLoadResult.success(snapshot)
	)
	var disabled_settings := PartyForgeSettings.new()
	disabled_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	var disabled_result = disabled_provider.resolve(disabled_settings, profile)
	_assert_result(disabled_result, LEGACY, null, &"", "flag-off developer result remains legacy", failures)
	TestAssertions.equal(disabled_calls, [], "flag-off result does not load a candidate snapshot", failures)

	var candidate_calls: Array[String] = []
	var candidate_provider = provider_script.new(func(path: String) -> CityAccessLoadResult:
		candidate_calls.append(path)
		return CityAccessLoadResult.success(snapshot)
	)
	var candidate_settings := PartyForgeSettings.new()
	candidate_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	candidate_settings.use_city_access_snapshot = true
	var candidate_result = candidate_provider.resolve(candidate_settings, profile)
	TestAssertions.equal(candidate_result.get("mode"), CANDIDATE, "Developer Mode and flag-on select candidate snapshot", failures)
	TestAssertions.truthy(candidate_result.get("snapshot") is CityAccessSnapshot, "candidate result exposes a validated snapshot", failures)
	TestAssertions.equal(candidate_result.get("diagnostic"), &"", "candidate result has no diagnostic", failures)
	TestAssertions.equal(candidate_calls, [SNAPSHOT_PATH], "candidate provider invokes its fixed snapshot path", failures)

	var missing_calls: Array[String] = []
	var missing_provider = provider_script.new(func(path: String) -> CityAccessLoadResult:
		missing_calls.append(path)
		return CityAccessLoadResult.failure("fixture snapshot missing")
	)
	var missing_result = missing_provider.resolve(candidate_settings, profile)
	_assert_result(missing_result, CANDIDATE_FAILED, null, &"candidate_snapshot_load_failed", "missing candidate snapshot fails closed without fallback", failures)
	TestAssertions.equal(missing_calls, [SNAPSHOT_PATH], "missing candidate provider invokes its fixed snapshot path", failures)

	var invalid_provider = provider_script.new(func(_path: String) -> Variant: return null)
	var invalid_result = invalid_provider.resolve(candidate_settings, profile)
	_assert_result(invalid_result, CANDIDATE_FAILED, null, &"candidate_snapshot_loader_invalid", "invalid injected loader fails closed without fallback", failures)

	var player_calls: Array[String] = []
	var player_provider = provider_script.new(func(path: String) -> CityAccessLoadResult:
		player_calls.append(path)
		return CityAccessLoadResult.success(snapshot)
	)
	var player_settings := PartyForgeSettings.new()
	player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	player_settings.use_city_access_snapshot = true
	var player_result = player_provider.resolve(player_settings, profile)
	_assert_result(player_result, LEGACY, null, &"candidate_requires_developer_mode", "Player Simulation rejects candidate selection", failures)
	TestAssertions.equal(player_calls, [], "Player Simulation does not load candidate snapshot", failures)

	var source := FileAccess.get_file_as_string(PROVIDER_PATH).to_lower()
	for forbidden: String in [".pstree", "latticewright", "passive_tree", "profile_store", "router", "scene"]:
		TestAssertions.truthy(not source.contains(forbidden), "provider has no %s dependency" % forbidden, failures)


func _test_provider_result_is_immutable(failures: Array[String]) -> void:
	TestAssertions.truthy(FileAccess.file_exists(RESULT_PATH), "City access provider result script exists", failures)
	if not FileAccess.file_exists(RESULT_PATH):
		return
	var result_script := load(RESULT_PATH)
	TestAssertions.truthy(result_script != null, "City access provider result script loads", failures)
	if result_script == null:
		return
	var snapshot := _fixture_snapshot(failures)
	if snapshot == null:
		return
	var result = result_script.call("candidate", snapshot)
	var before := [result.get("mode"), result.get("diagnostic"), result.get("snapshot")]
	_assert_result_rejects_public_and_backing_writes(result, CANDIDATE, &"", "candidate provider result", failures)
	TestAssertions.truthy(result.get("snapshot") is CityAccessSnapshot, "candidate provider result retains its snapshot", failures)
	TestAssertions.truthy(result.get("snapshot") != before[2], "provider result returns defensive snapshot copies", failures)
	var legacy = result_script.call("legacy", &"legacy_diagnostic")
	_assert_result_rejects_public_and_backing_writes(legacy, LEGACY, &"legacy_diagnostic", "legacy provider result", failures)
	var failed = result_script.call("candidate_failed", &"candidate_snapshot_load_failed")
	_assert_result_rejects_public_and_backing_writes(failed, CANDIDATE_FAILED, &"candidate_snapshot_load_failed", "failed provider result", failures)
	_assert_result(failed, CANDIDATE_FAILED, null, &"candidate_snapshot_load_failed", "failed result never exposes a partial snapshot", failures)


func _test_provider_result_storage_is_opaque_and_released(failures: Array[String]) -> void:
	if not FileAccess.file_exists(RESULT_PATH):
		return
	var result_script := load(RESULT_PATH)
	if result_script == null:
		return
	var snapshot := _fixture_snapshot(failures)
	if snapshot == null:
		return
	var result = result_script.call("candidate", snapshot)
	var property_names: Array[String] = []
	for property: Dictionary in result.get_property_list():
		property_names.append(property.get("name", ""))
	for backing_name: String in ["_mode", "_snapshot", "_diagnostic"]:
		TestAssertions.truthy(not property_names.has(backing_name), "provider result does not expose %s backing state" % backing_name, failures)
	TestAssertions.truthy(result_script.has_method(&"_has_state"), "provider result storage supports deterministic release cleanup", failures)
	if not result_script.has_method(&"_has_state"):
		return
	TestAssertions.truthy(result_script.call("_has_state", result), "provider result registers opaque state while alive", failures)
	result = null
	var survivor = result_script.call("legacy")
	TestAssertions.truthy(result_script.call("_has_state", survivor), "provider result cleans released opaque state before serving a live result", failures)


func _fixture_snapshot(failures: Array[String]) -> CityAccessSnapshot:
	var document := {
		"format": "party-forge-access-snapshot",
		"version": 1,
		"source": {
			"adapter": "latticewright-runtime-v3-city-access",
			"format": "latticewright-progression",
			"formatVersion": 3,
			"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
		},
		"locations": [{
			"id": "city.provider_fixture",
			"destinationId": "city.provider_fixture.destination",
			"visibleWhen": [{"kind": "always", "value": ""}],
			"availableWhen": [{"kind": "always", "value": ""}],
		}],
	}
	var result := CityAccessSnapshotLoader.load_bytes(JSON.stringify(document).to_utf8_buffer())
	TestAssertions.truthy(result.ok(), "provider fixture snapshot loads", failures)
	return result.snapshot if result.ok() else null


func _assert_result(result: Variant, expected_mode: int, expected_snapshot: Variant, expected_diagnostic: StringName, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(result != null, "%s returns a provider result" % label, failures)
	if result == null:
		return
	TestAssertions.equal(result.get("mode"), expected_mode, "%s mode" % label, failures)
	TestAssertions.equal(result.get("snapshot"), expected_snapshot, "%s snapshot" % label, failures)
	TestAssertions.equal(result.get("diagnostic"), expected_diagnostic, "%s diagnostic" % label, failures)


func _assert_result_rejects_public_and_backing_writes(result: Variant, expected_mode: int, expected_diagnostic: StringName, label: String, failures: Array[String]) -> void:
	var expected_snapshot: Variant = result.get("snapshot")
	result.mode = LEGACY
	result.snapshot = null
	result.diagnostic = &"public_mutation"
	result.set("mode", LEGACY)
	result.set("snapshot", null)
	result.set("diagnostic", &"dynamic_public_mutation")
	result._mode = LEGACY
	result._snapshot = null
	result._diagnostic = &"underscore_mutation"
	result.set("_mode", LEGACY)
	result.set("_snapshot", null)
	result.set("_diagnostic", &"dynamic_underscore_mutation")
	TestAssertions.equal(result.get("mode"), expected_mode, "%s rejects public and backing mode writes" % label, failures)
	TestAssertions.equal(result.get("diagnostic"), expected_diagnostic, "%s rejects public and backing diagnostic writes" % label, failures)
	TestAssertions.equal(result.get("snapshot") != null, expected_snapshot != null, "%s rejects public and backing snapshot writes" % label, failures)
	var actual_snapshot: Variant = result.get("snapshot")
	if expected_snapshot != null and actual_snapshot != null:
		TestAssertions.equal(_snapshot_values(actual_snapshot as CityAccessSnapshot), _snapshot_values(expected_snapshot as CityAccessSnapshot), "%s retains defensive snapshot value" % label, failures)


func _snapshot_values(snapshot: CityAccessSnapshot) -> Array:
	var locations: Array = []
	for location: CityAccessLocation in snapshot.locations:
		locations.append([location.id, location.destination_id])
	return [snapshot.adapter, snapshot.source_format, snapshot.source_format_version, snapshot.source_sha256, locations]
