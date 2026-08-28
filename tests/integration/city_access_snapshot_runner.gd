extends SceneTree

const RUNTIME_PATH := "res://design/progression/latticewright/party-forge-city-access.pstree.json"
const SNAPSHOT_PATH := "res://data/world/access/party-forge-city-access.snapshot.json"
const LEGACY_CITY_PATH := "res://data/passive_trees/city/party-forge-city.pstree.json"
const MAX_SOURCE_BYTES := 64 * 1024 * 1024

const LOCATIONS: Array[StringName] = [
	&"city.apothecary", &"city.coliseum_road", &"city.inn", &"city.merchant",
	&"city.scholars_archive", &"city.smithy", &"city.warehouse",
]

const GATED_UNLOCKS := {
	&"city.inn": &"service:hero_registry",
	&"city.merchant": &"service:city_vendors",
	&"city.smithy": &"service:equipment_upgrading",
	&"city.warehouse": &"stash",
}


func _initialize() -> void:
	var failures: Array[String] = []
	var source := StrictJsonDocumentReader.read(RUNTIME_PATH, MAX_SOURCE_BYTES)
	_assert(source.ok(), "runtime-v3 source is read and hashed", failures)
	if not source.ok():
		_finish(failures)
		return
	_assert(source.sha256 == _sha256(FileAccess.get_file_as_bytes(RUNTIME_PATH)), "runtime-v3 source hash covers exact checked-in bytes", failures)
	var translated := LatticewrightRuntimeV3CityAccessImporter.translate(source.document, source.sha256)
	_assert(translated.ok(), "production importer translates runtime-v3 source", failures)
	if not translated.ok():
		_finish(failures)
		return
	var canonical := CityAccessSnapshotCodec.encode_document(translated.candidate)
	var snapshot_bytes := FileAccess.get_file_as_bytes(SNAPSHOT_PATH)
	_assert(not canonical.is_empty(), "production importer yields canonical snapshot bytes", failures)
	_assert(canonical == snapshot_bytes, "candidate bytes equal checked-in snapshot bytes", failures)
	var loaded := CityAccessSnapshotLoader.load_bytes(snapshot_bytes)
	_assert(loaded.ok(), "production snapshot loader accepts checked-in snapshot", failures)
	if loaded.ok():
		_assert(loaded.snapshot.locations.size() == LOCATIONS.size(), "production snapshot has seven locations", failures)
		_assert_profiles(loaded.snapshot, failures)
		_assert_provider_modes(loaded.snapshot, failures)
	_assert_legacy_city_data(failures)
	_finish(failures)


func _assert_profiles(snapshot: CityAccessSnapshot, failures: Array[String]) -> void:
	for scenario: Dictionary in _scenarios():
		var profile := ProfileState.new_profile("city-access-%s" % String(scenario["name"]), "City Access", 1)
		profile.prologue_state = int(scenario["prologue"])
		var unlocks: Array[String] = []
		for unlock: String in scenario["unlocks"] as Array:
			unlocks.append(unlock)
		profile.permanent_feature_unlocks = unlocks
		var before_dictionary := profile.to_dictionary()
		var before_bytes := ProfileCodec.encode(profile).to_utf8_buffer()
		for location_id: StringName in LOCATIONS:
			var projection: Variant = CityAccessEvaluator.evaluate(snapshot, profile, location_id)
			_assert(projection != null, "%s returns %s projection" % [scenario["name"], location_id], failures)
			if projection == null:
				continue
			var expected_state := _expected_state(location_id, profile)
			_assert(projection.state == expected_state, "%s has expected %s state" % [scenario["name"], location_id], failures)
			_assert(projection.destination_id == _expected_destination(location_id, expected_state), "%s has expected %s destination" % [scenario["name"], location_id], failures)
		_assert(profile.to_dictionary() == before_dictionary, "%s evaluation preserves profile dictionary" % scenario["name"], failures)
		_assert(ProfileCodec.encode(profile).to_utf8_buffer() == before_bytes, "%s evaluation preserves ProfileCodec bytes" % scenario["name"], failures)


func _assert_provider_modes(snapshot: CityAccessSnapshot, failures: Array[String]) -> void:
	var profile := ProfileState.new_profile("city-access-provider-profile", "City Access", 1)
	var provider := CityAccessProvider.new(func(_path: String) -> CityAccessLoadResult: return CityAccessLoadResult.success(snapshot))
	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	_assert(provider.resolve(settings, profile).mode == CityAccessProviderResult.Mode.LEGACY, "flag-off resolves LEGACY", failures)
	settings.use_city_access_snapshot = true
	settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	var player_result := provider.resolve(settings, profile)
	_assert(player_result.mode == CityAccessProviderResult.Mode.LEGACY and player_result.diagnostic == &"candidate_requires_developer_mode", "Player Mode plus flag-on resolves LEGACY with developer-only diagnostic", failures)
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	var candidate_result := provider.resolve(settings, profile)
	_assert(candidate_result.mode == CityAccessProviderResult.Mode.CANDIDATE and candidate_result.snapshot != null, "Developer Mode plus flag-on resolves CANDIDATE", failures)
	var invalid_provider := CityAccessProvider.new(func(_path: String) -> CityAccessLoadResult: return CityAccessLoadResult.failure("integration invalid snapshot"))
	var failed_result := invalid_provider.resolve(settings, profile)
	_assert(failed_result.mode == CityAccessProviderResult.Mode.CANDIDATE_FAILED and failed_result.snapshot == null and failed_result.diagnostic == &"candidate_snapshot_load_failed", "invalid snapshot resolves CANDIDATE_FAILED without fallback", failures)
	settings.use_city_access_snapshot = false
	var rollback_result := provider.resolve(settings, profile)
	_assert(rollback_result.mode == CityAccessProviderResult.Mode.LEGACY and rollback_result.snapshot == null, "flag-off immediately rolls back to LEGACY", failures)


func _assert_legacy_city_data(failures: Array[String]) -> void:
	_assert(FileAccess.file_exists(LEGACY_CITY_PATH), "format-1 City data remains present", failures)
	if FileAccess.file_exists(LEGACY_CITY_PATH):
		var legacy_result := PassiveTreeLoader.new().load_path(LEGACY_CITY_PATH)
		_assert(legacy_result.ok(), "format-1 City data remains loadable by PassiveTreeLoader", failures)


func _scenarios() -> Array[Dictionary]:
	return [
		{"name": "not_started", "prologue": ProfileState.PrologueState.NOT_STARTED, "unlocks": []},
		{"name": "in_progress", "prologue": ProfileState.PrologueState.IN_PROGRESS, "unlocks": []},
		{"name": "completed", "prologue": ProfileState.PrologueState.COMPLETED, "unlocks": []},
		{"name": "hero_registry", "prologue": ProfileState.PrologueState.NOT_STARTED, "unlocks": ["service:hero_registry"]},
		{"name": "city_vendors", "prologue": ProfileState.PrologueState.NOT_STARTED, "unlocks": ["service:city_vendors"]},
		{"name": "stash", "prologue": ProfileState.PrologueState.NOT_STARTED, "unlocks": ["stash"]},
		{"name": "equipment_upgrading", "prologue": ProfileState.PrologueState.NOT_STARTED, "unlocks": ["service:equipment_upgrading"]},
	]


func _expected_state(location_id: StringName, profile: ProfileState) -> CityAccessProjection.State:
	if location_id == &"city.scholars_archive":
		return CityAccessProjection.State.AVAILABLE if profile.prologue_state == ProfileState.PrologueState.COMPLETED else CityAccessProjection.State.HIDDEN
	if GATED_UNLOCKS.has(location_id):
		return CityAccessProjection.State.AVAILABLE if profile.permanent_feature_unlocks.has(GATED_UNLOCKS[location_id]) else CityAccessProjection.State.LOCKED
	return CityAccessProjection.State.AVAILABLE


func _expected_destination(location_id: StringName, state: CityAccessProjection.State) -> StringName:
	if state != CityAccessProjection.State.AVAILABLE:
		return &""
	return {
		&"city.apothecary": &"city.apothecary.interior",
		&"city.coliseum_road": &"city.coliseum_road.route",
		&"city.inn": &"city.inn.interior",
		&"city.merchant": &"city.merchant.interior",
		&"city.scholars_archive": &"city.scholars_archive.interior",
		&"city.smithy": &"city.smithy.interior",
		&"city.warehouse": &"city.warehouse.interior",
	}[location_id]


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if not failures.is_empty():
		for failure: String in failures:
			push_error("CITY_ACCESS_SNAPSHOT_ACCEPTANCE_FAILURE %s" % failure)
		quit(1)
		return
	print("CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy")
	quit(0)
