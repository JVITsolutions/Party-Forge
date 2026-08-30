extends RefCounted

const RESULT_PATH := "res://scripts/world/access/warehouse_presentation_result.gd"
const RESOLVER_PATH := "res://scripts/world/access/warehouse_presentation_resolver.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_activation_matrix(failures)
	_test_candidate_cannot_grant_or_remove_authority(failures)
	_test_candidate_failure_is_sanitized_legacy(failures)
	_test_inputs_are_not_mutated(failures)
	_test_marker_fails_closed_after_public_mutation(failures)
	return failures


func _test_activation_matrix(failures: Array[String]) -> void:
	var scripts := _scripts(failures)
	if scripts.is_empty():
		return
	var locked := ProfileState.new_profile("presentation-locked", "Locked", 1)
	var player := _settings(PartyForgeSettings.Mode.PLAYER_SIMULATION, false)
	_assert_resolution(scripts["resolver"].resolve(player, locked, WarehouseAccessPolicy.State.BLOCKED, CityAccessProviderResult.legacy()), scripts["result"], 0, 0, &"legacy_gate", "flag-off locked profile uses legacy hidden state", failures)
	player.use_city_access_snapshot = true
	for row: Array in [
		[CityAccessProjection.State.HIDDEN, 0, 1, &"candidate_hidden"],
		[CityAccessProjection.State.LOCKED, 1, 1, &"candidate_locked"],
		[CityAccessProjection.State.AVAILABLE, 1, 3, &"candidate_cannot_grant_authority"],
	]:
		var candidate := CityAccessProviderResult.candidate(_snapshot(&"city.warehouse", &"city.warehouse.interior", row[0]))
		_assert_resolution(scripts["resolver"].resolve(player, locked, WarehouseAccessPolicy.State.BLOCKED, candidate), scripts["result"], row[1], row[2], row[3], "locked candidate %s" % CityAccessProjection.State.keys()[row[0]], failures)
	var developer := _settings(PartyForgeSettings.Mode.DEVELOPER_MODE, true)
	_assert_resolution(scripts["resolver"].resolve(developer, locked, WarehouseAccessPolicy.State.BLOCKED, CityAccessProviderResult.candidate(_snapshot(&"city.warehouse", &"city.warehouse.interior", CityAccessProjection.State.LOCKED))), scripts["result"], 0, 0, &"consumer_not_player_mode", "Developer Mode bypasses presentation candidate", failures)


func _test_candidate_cannot_grant_or_remove_authority(failures: Array[String]) -> void:
	var scripts := _scripts(failures)
	if scripts.is_empty():
		return
	var player := _settings(PartyForgeSettings.Mode.PLAYER_SIMULATION, true)
	var locked := ProfileState.new_profile("presentation-authority-locked", "Locked", 1)
	var unlocked := ProfileState.new_profile("presentation-authority-unlocked", "Unlocked", 2)
	unlocked.permanent_feature_unlocks = ["stash"]
	_assert_resolution(scripts["resolver"].resolve(player, locked, WarehouseAccessPolicy.State.BLOCKED, CityAccessProviderResult.candidate(_snapshot(&"city.warehouse", &"city.warehouse.interior", CityAccessProjection.State.AVAILABLE))), scripts["result"], 1, 3, &"candidate_cannot_grant_authority", "candidate cannot grant locked profile authority", failures)
	_assert_resolution(scripts["resolver"].resolve(player, unlocked, WarehouseAccessPolicy.State.AVAILABLE, CityAccessProviderResult.candidate(_snapshot(&"city.warehouse", &"city.warehouse.interior", CityAccessProjection.State.HIDDEN))), scripts["result"], 2, 3, &"candidate_cannot_reduce_authority", "hidden candidate cannot reduce unlocked profile authority", failures)
	_assert_resolution(scripts["resolver"].resolve(player, unlocked, WarehouseAccessPolicy.State.AVAILABLE, CityAccessProviderResult.candidate(_snapshot(&"city.warehouse", &"city.warehouse.interior", CityAccessProjection.State.LOCKED, &"other_unlock"))), scripts["result"], 2, 3, &"candidate_cannot_reduce_authority", "locked candidate cannot reduce unlocked profile authority", failures)
	_assert_resolution(scripts["resolver"].resolve(player, unlocked, WarehouseAccessPolicy.State.AVAILABLE, CityAccessProviderResult.candidate(_snapshot(&"city.warehouse", &"city.warehouse.interior", CityAccessProjection.State.AVAILABLE))), scripts["result"], 2, 1, &"candidate_matches_authority", "available candidate matches unlocked authority", failures)
	_assert_resolution(scripts["resolver"].resolve(player, locked, WarehouseAccessPolicy.State.BLOCKED, CityAccessProviderResult.candidate(_snapshot(&"city.other", &"city.other.interior", CityAccessProjection.State.AVAILABLE))), scripts["result"], 0, 2, &"candidate_projection_invalid", "wrong location fails to sanitized legacy presentation", failures)
	_assert_resolution(scripts["resolver"].resolve(player, unlocked, WarehouseAccessPolicy.State.AVAILABLE, CityAccessProviderResult.candidate(_snapshot(&"city.warehouse", &"city.unexpected", CityAccessProjection.State.AVAILABLE))), scripts["result"], 2, 2, &"candidate_destination_invalid", "wrong available destination fails to sanitized legacy presentation", failures)


func _test_candidate_failure_is_sanitized_legacy(failures: Array[String]) -> void:
	var scripts := _scripts(failures)
	if scripts.is_empty():
		return
	var player := _settings(PartyForgeSettings.Mode.PLAYER_SIMULATION, true)
	var locked := ProfileState.new_profile("presentation-failure", "Failure", 1)
	_assert_resolution(scripts["resolver"].resolve(player, locked, WarehouseAccessPolicy.State.BLOCKED, CityAccessProviderResult.candidate_failed(&"candidate_snapshot_load_failed")), scripts["result"], 0, 2, &"candidate_snapshot_load_failed", "allowlisted provider failure is retained", failures)
	_assert_resolution(scripts["resolver"].resolve(player, locked, WarehouseAccessPolicy.State.BLOCKED, CityAccessProviderResult.legacy(&"raw_provider_message")), scripts["result"], 0, 2, &"candidate_provider_unavailable", "unexpected provider mode fails closed to sanitized diagnostic", failures)
	_assert_resolution(scripts["resolver"].resolve(player, locked, WarehouseAccessPolicy.State.BLOCKED, null), scripts["result"], 0, 2, &"candidate_provider_unavailable", "missing provider result fails closed", failures)
	_assert_resolution(scripts["resolver"].resolve(null, locked, WarehouseAccessPolicy.State.BLOCKED, CityAccessProviderResult.legacy()), scripts["result"], 0, 0, &"invalid_input", "invalid settings retains legacy state", failures)


func _test_inputs_are_not_mutated(failures: Array[String]) -> void:
	var scripts := _scripts(failures)
	if scripts.is_empty():
		return
	var profile := ProfileState.new_profile("presentation-immutable", "Immutable", 1)
	var settings := _settings(PartyForgeSettings.Mode.PLAYER_SIMULATION, true)
	var snapshot := _snapshot(&"city.warehouse", &"city.warehouse.interior", CityAccessProjection.State.LOCKED)
	var provider := CityAccessProviderResult.candidate(snapshot)
	var profile_before := profile.to_dictionary()
	var settings_before := _settings_values(settings)
	var snapshot_before := _snapshot_values(snapshot)
	var provider_before := [provider.mode, provider.diagnostic, _snapshot_values(provider.snapshot)]
	var result = scripts["resolver"].resolve(settings, profile, WarehouseAccessPolicy.resolve(profile), provider)
	TestAssertions.truthy(result != null, "immutable input resolution returns a result", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "resolver does not mutate profile", failures)
	TestAssertions.equal(_settings_values(settings), settings_before, "resolver does not mutate settings", failures)
	TestAssertions.equal(_snapshot_values(snapshot), snapshot_before, "resolver does not mutate caller snapshot", failures)
	TestAssertions.equal([provider.mode, provider.diagnostic, _snapshot_values(provider.snapshot)], provider_before, "resolver does not mutate provider result", failures)


func _test_marker_fails_closed_after_public_mutation(failures: Array[String]) -> void:
	var scripts := _scripts(failures)
	if scripts.is_empty():
		return
	var result = scripts["result"].new(1, 1, &"candidate_locked")
	result.state = 99
	result.outcome = 99
	result.reason = &"raw fixture path must never escape"
	TestAssertions.equal(result.marker(), "PARTY_FORGE_WAREHOUSE_PRESENTATION outcome=CANDIDATE_FAILED state=HIDDEN reason=invalid_reason", "marker rejects invalid public fields and raw text", failures)


func _scripts(failures: Array[String]) -> Dictionary:
	TestAssertions.truthy(FileAccess.file_exists(RESULT_PATH), "Warehouse presentation result script exists", failures)
	TestAssertions.truthy(FileAccess.file_exists(RESOLVER_PATH), "Warehouse presentation resolver script exists", failures)
	if not FileAccess.file_exists(RESULT_PATH) or not FileAccess.file_exists(RESOLVER_PATH):
		return {}
	var result: Variant = load(RESULT_PATH)
	var resolver: Variant = load(RESOLVER_PATH)
	TestAssertions.truthy(result != null, "Warehouse presentation result script loads", failures)
	TestAssertions.truthy(resolver != null, "Warehouse presentation resolver script loads", failures)
	return {"result": result, "resolver": resolver} if result != null and resolver != null else {}


func _settings(mode: PartyForgeSettings.Mode, enabled: bool) -> PartyForgeSettings:
	var settings := PartyForgeSettings.new()
	settings.mode = mode
	settings.use_city_access_snapshot = enabled
	return settings


func _snapshot(location_id: StringName, destination_id: StringName, state: CityAccessProjection.State, availability_unlock: StringName = &"stash") -> CityAccessSnapshot:
	var visible_when := [{"kind": "always", "value": ""}]
	var available_when := [{"kind": "always", "value": ""}]
	if state == CityAccessProjection.State.HIDDEN:
		visible_when = [{"kind": "prologue_state", "value": "completed"}]
	elif state == CityAccessProjection.State.LOCKED:
		available_when = [{"kind": "permanent_unlock", "value": String(availability_unlock)}]
	var document := {
		"format": "party-forge-access-snapshot",
		"version": 1,
		"source": {"adapter": "latticewright-runtime-v3-city-access", "format": "latticewright-progression", "formatVersion": 3, "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"},
		"locations": [{"id": String(location_id), "destinationId": String(destination_id), "visibleWhen": visible_when, "availableWhen": available_when}],
	}
	var loaded := CityAccessSnapshotLoader.load_bytes(JSON.stringify(document).to_utf8_buffer())
	return loaded.snapshot if loaded.ok() else null


func _assert_resolution(actual: Variant, result_script: Variant, expected_state: int, expected_outcome: int, expected_reason: StringName, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(actual != null, "%s returns a presentation result" % label, failures)
	if actual == null:
		return
	TestAssertions.equal(actual.state, expected_state, "%s state" % label, failures)
	TestAssertions.equal(actual.outcome, expected_outcome, "%s outcome" % label, failures)
	TestAssertions.equal(actual.reason, expected_reason, "%s reason" % label, failures)
	TestAssertions.truthy(actual.marker().begins_with("PARTY_FORGE_WAREHOUSE_PRESENTATION"), "%s has a presentation marker" % label, failures)


func _settings_values(settings: PartyForgeSettings) -> Array:
	return [settings.schema_version, settings.mode, settings.unlock_all_implemented_content, settings.god_mode, settings.party_capacity_override, settings.enemy_density_percent, settings.experience_multiplier_percent, settings.level_up_card_count, settings.reduced_motion, settings.personal_drop_multiplier_percent, settings.force_personal_drops, settings.personal_drop_source_category_override, settings.personal_drop_item_level_override, settings.show_ground_chest_diagnostics, settings.use_city_access_snapshot]


func _snapshot_values(snapshot: CityAccessSnapshot) -> Array:
	if snapshot == null:
		return []
	var locations: Array = []
	for location: CityAccessLocation in snapshot.locations:
		var visible: Array = []
		var available: Array = []
		for condition: CityAccessCondition in location.visible_when:
			visible.append([condition.kind, condition.value])
		for condition: CityAccessCondition in location.available_when:
			available.append([condition.kind, condition.value])
		locations.append([location.id, location.destination_id, visible, available])
	return [snapshot.adapter, snapshot.source_format, snapshot.source_format_version, snapshot.source_sha256, locations]
