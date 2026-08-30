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
	var runtime_bytes_before := FileAccess.get_file_as_bytes(RUNTIME_PATH)
	var snapshot_bytes_before := FileAccess.get_file_as_bytes(SNAPSHOT_PATH)
	var runtime_hash_before := _sha256(runtime_bytes_before)
	var snapshot_hash_before := _sha256(snapshot_bytes_before)
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
		_assert_warehouse_presentation_activation(loaded.snapshot, failures)
	_assert_legacy_city_data(failures)
	var runtime_bytes_after := FileAccess.get_file_as_bytes(RUNTIME_PATH)
	var snapshot_bytes_after := FileAccess.get_file_as_bytes(SNAPSHOT_PATH)
	_assert(runtime_bytes_after == runtime_bytes_before, "runtime-v3 checked-in bytes remain exact before and after activation acceptance", failures)
	_assert(snapshot_bytes_after == snapshot_bytes_before, "checked-in snapshot bytes remain exact before and after activation acceptance", failures)
	_assert(_sha256(runtime_bytes_after) == runtime_hash_before, "runtime-v3 checked-in hash remains exact before and after activation acceptance", failures)
	_assert(_sha256(snapshot_bytes_after) == snapshot_hash_before, "checked-in snapshot hash remains exact before and after activation acceptance", failures)
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
	_assert(player_result.mode == CityAccessProviderResult.Mode.CANDIDATE and player_result.snapshot != null, "Player Mode plus flag-on resolves CANDIDATE", failures)
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	var candidate_result := provider.resolve(settings, profile)
	_assert(candidate_result.mode == CityAccessProviderResult.Mode.CANDIDATE and candidate_result.snapshot != null, "Developer Mode plus flag-on resolves CANDIDATE", failures)
	var invalid_provider := CityAccessProvider.new(func(_path: String) -> CityAccessLoadResult: return CityAccessLoadResult.failure("integration invalid snapshot"))
	var failed_result := invalid_provider.resolve(settings, profile)
	_assert(failed_result.mode == CityAccessProviderResult.Mode.CANDIDATE_FAILED and failed_result.snapshot == null and failed_result.diagnostic == &"candidate_snapshot_load_failed", "invalid snapshot resolves CANDIDATE_FAILED without fallback", failures)
	settings.use_city_access_snapshot = false
	var rollback_result := provider.resolve(settings, profile)
	_assert(rollback_result.mode == CityAccessProviderResult.Mode.LEGACY and rollback_result.snapshot == null, "flag-off immediately rolls back to LEGACY", failures)


func _assert_warehouse_presentation_activation(snapshot: CityAccessSnapshot, failures: Array[String]) -> void:
	var player_settings := PartyForgeSettings.new()
	player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	player_settings.use_city_access_snapshot = true
	var provider_loads: Array[String] = []
	var player_provider := CityAccessProvider.new(func(path: String) -> CityAccessLoadResult:
		provider_loads.append(path)
		return CityAccessLoadResult.success(snapshot)
	)
	var locked_profile := ProfileState.new_profile("activation-locked", "Activation Locked", 1)
	var unlocked_profile := ProfileState.new_profile("activation-unlocked", "Activation Unlocked", 2)
	unlocked_profile.permanent_feature_unlocks = ["stash"]
	var locked_before := ProfileCodec.encode(locked_profile).to_utf8_buffer()
	var unlocked_before := ProfileCodec.encode(unlocked_profile).to_utf8_buffer()
	var locked_provider := player_provider.resolve(player_settings, locked_profile)
	var unlocked_provider := player_provider.resolve(player_settings, unlocked_profile)
	_assert(provider_loads == [CityAccessProvider.SNAPSHOT_PATH, CityAccessProvider.SNAPSHOT_PATH], "Player Mode loads only the fixed checked-in City access snapshot path", failures)
	var locked_presentation := WarehousePresentationResolver.resolve(player_settings, locked_profile, WarehouseAccessPolicy.resolve(locked_profile), locked_provider)
	var unlocked_presentation := WarehousePresentationResolver.resolve(player_settings, unlocked_profile, WarehouseAccessPolicy.resolve(unlocked_profile), unlocked_provider)
	_assert(locked_presentation.state == WarehousePresentationResult.State.LOCKED and locked_presentation.outcome == WarehousePresentationResult.Outcome.CANDIDATE and locked_presentation.reason == &"candidate_locked", "locked Player Mode resolves the Warehouse to LOCKED candidate presentation", failures)
	_assert(unlocked_presentation.state == WarehousePresentationResult.State.AVAILABLE and unlocked_presentation.outcome == WarehousePresentationResult.Outcome.CANDIDATE and unlocked_presentation.reason == &"candidate_matches_authority", "unlocked Player Mode resolves the Warehouse to AVAILABLE candidate presentation", failures)
	_assert(ProfileCodec.encode(locked_profile).to_utf8_buffer() == locked_before, "locked Player Mode Warehouse resolution preserves exact ProfileCodec bytes", failures)
	_assert(ProfileCodec.encode(unlocked_profile).to_utf8_buffer() == unlocked_before, "unlocked Player Mode Warehouse resolution preserves exact ProfileCodec bytes", failures)

	var flag_off_loads: Array[String] = []
	var flag_off_provider := CityAccessProvider.new(func(path: String) -> CityAccessLoadResult:
		flag_off_loads.append(path)
		return CityAccessLoadResult.success(snapshot)
	)
	var flag_off_settings := PartyForgeSettings.new()
	flag_off_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	var locked_legacy_provider := flag_off_provider.resolve(flag_off_settings, locked_profile)
	var unlocked_legacy_provider := flag_off_provider.resolve(flag_off_settings, unlocked_profile)
	var locked_legacy := WarehousePresentationResolver.resolve(flag_off_settings, locked_profile, WarehouseAccessPolicy.resolve(locked_profile), locked_legacy_provider)
	var unlocked_legacy := WarehousePresentationResolver.resolve(flag_off_settings, unlocked_profile, WarehouseAccessPolicy.resolve(unlocked_profile), unlocked_legacy_provider)
	_assert(flag_off_loads.is_empty(), "flag-off Player Mode returns legacy Warehouse presentation without loading", failures)
	_assert(locked_legacy.state == WarehousePresentationResult.State.HIDDEN and locked_legacy.outcome == WarehousePresentationResult.Outcome.LEGACY and locked_legacy.reason == &"legacy_gate", "flag-off locked Player Mode retains legacy hidden presentation", failures)
	_assert(unlocked_legacy.state == WarehousePresentationResult.State.AVAILABLE and unlocked_legacy.outcome == WarehousePresentationResult.Outcome.LEGACY and unlocked_legacy.reason == &"legacy_gate", "flag-off unlocked Player Mode retains legacy available presentation", failures)

	_assert_invalid_warehouse_candidates(player_settings, locked_profile, unlocked_profile, failures)
	_assert_warehouse_location_confinement(player_settings, locked_profile, unlocked_profile, failures)
	_assert_warehouse_shadow_and_developer_preview(snapshot, failures)
	_assert_production_warehouse_route_authorization(failures)


func _assert_invalid_warehouse_candidates(player_settings: PartyForgeSettings, locked_profile: ProfileState, unlocked_profile: ProfileState, failures: Array[String]) -> void:
	var malformed := CityAccessSnapshotLoader.load_bytes("{".to_utf8_buffer())
	var duplicate := CityAccessSnapshotLoader.load_bytes("{\"format\":\"party-forge-access-snapshot\",\"format\":\"party-forge-access-snapshot\"}".to_utf8_buffer())
	_assert(not malformed.ok(), "malformed snapshot fixture is rejected before presentation", failures)
	_assert(not duplicate.ok(), "duplicate-key snapshot fixture is rejected before presentation", failures)
	for row: Array in [["malformed", malformed], ["duplicate-key", duplicate]]:
		var provider := CityAccessProvider.new(func(_path: String) -> CityAccessLoadResult: return row[1] as CityAccessLoadResult)
		var provider_result := provider.resolve(player_settings, locked_profile)
		var presentation := WarehousePresentationResolver.resolve(player_settings, locked_profile, WarehouseAccessPolicy.resolve(locked_profile), provider_result)
		_assert(presentation.state == WarehousePresentationResult.State.HIDDEN and presentation.outcome == WarehousePresentationResult.Outcome.CANDIDATE_FAILED and presentation.reason == &"candidate_snapshot_load_failed", "%s candidate failure returns locked profile's legacy hidden presentation" % row[0], failures)
	var unknown_snapshot := _fixture_snapshot(&"city.other", &"city.other.interior", CityAccessProjection.State.AVAILABLE)
	var unknown := WarehousePresentationResolver.resolve(player_settings, locked_profile, WarehouseAccessPolicy.resolve(locked_profile), CityAccessProviderResult.candidate(unknown_snapshot))
	_assert(unknown.state == WarehousePresentationResult.State.HIDDEN and unknown.outcome == WarehousePresentationResult.Outcome.CANDIDATE_FAILED and unknown.reason == &"candidate_projection_invalid", "unknown-location candidate returns locked profile's legacy hidden presentation", failures)
	var hidden_profile := ProfileState.new_profile("acceptance-wrong-destination-hidden", "Hidden", 3)
	for row: Array in [
		[hidden_profile, CityAccessProjection.State.HIDDEN, WarehousePresentationResult.State.HIDDEN, "hidden"],
		[locked_profile, CityAccessProjection.State.LOCKED, WarehousePresentationResult.State.HIDDEN, "locked"],
		[unlocked_profile, CityAccessProjection.State.AVAILABLE, WarehousePresentationResult.State.AVAILABLE, "available"],
	]:
		var wrong_destination_snapshot := _fixture_snapshot(&"city.warehouse", &"city.unexpected", row[1])
		var wrong_destination := WarehousePresentationResolver.resolve(player_settings, row[0], WarehouseAccessPolicy.resolve(row[0]), CityAccessProviderResult.candidate(wrong_destination_snapshot))
		_assert(wrong_destination.state == row[2] and wrong_destination.outcome == WarehousePresentationResult.Outcome.CANDIDATE_FAILED and wrong_destination.reason == &"candidate_destination_invalid", "wrong-destination %s candidate returns the authoritative legacy presentation" % row[3], failures)


func _assert_warehouse_location_confinement(player_settings: PartyForgeSettings, locked_profile: ProfileState, unlocked_profile: ProfileState, failures: Array[String]) -> void:
	_assert(WarehousePresentationResolver.LOCATION_ID == &"city.warehouse" and WarehousePresentationResolver.EXPECTED_DESTINATION_ID == &"city.warehouse.interior", "presentation resolver is fixed to only the Warehouse City location and destination", failures)
	var locations: Array[Dictionary] = []
	for location_id: StringName in LOCATIONS:
		var state := CityAccessProjection.State.LOCKED if location_id == &"city.warehouse" else CityAccessProjection.State.AVAILABLE
		locations.append(_fixture_location(location_id, _expected_destination(location_id, CityAccessProjection.State.AVAILABLE), state))
	var confined_snapshot := _fixture_snapshot_from_locations(locations)
	var presentation := WarehousePresentationResolver.resolve(player_settings, locked_profile, WarehouseAccessPolicy.resolve(locked_profile), CityAccessProviderResult.candidate(confined_snapshot))
	_assert(presentation.state == WarehousePresentationResult.State.LOCKED and presentation.reason == &"candidate_locked", "other City location projections cannot influence the Warehouse-only evaluation", failures)

	var evaluated_location_ids: Array[StringName] = []
	var evaluated_destination_ids: Array[StringName] = []
	var observed_locations: Array[Dictionary] = []
	for location_id: StringName in LOCATIONS:
		observed_locations.append(_fixture_location(location_id, _expected_destination(location_id, CityAccessProjection.State.AVAILABLE), CityAccessProjection.State.AVAILABLE))
	var observed_snapshot := _fixture_snapshot_from_locations(observed_locations)
	var provider := CityAccessProvider.new(func(_path: String) -> CityAccessLoadResult:
		return CityAccessLoadResult.success(observed_snapshot)
	)
	var comparator := CityAccessShadowComparator.new(provider, func(candidate_snapshot: Variant, profile: Variant, location_id: Variant) -> Variant:
		evaluated_location_ids.append(location_id as StringName if typeof(location_id) == TYPE_STRING_NAME else &"")
		var projection: Variant = CityAccessEvaluator.evaluate(candidate_snapshot, profile, location_id)
		if projection is CityAccessProjection and (projection as CityAccessProjection).state == CityAccessProjection.State.AVAILABLE:
			evaluated_destination_ids.append((projection as CityAccessProjection).destination_id)
		return projection
	, func(_marker: String, _warning: bool) -> void: pass)
	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	developer_settings.use_city_access_snapshot = true
	var observed: Variant = comparator.observe(developer_settings, unlocked_profile)
	_assert(observed is CityAccessShadowComparison, "instrumented production comparator returns a Warehouse comparison", failures)
	_assert(evaluated_location_ids == [&"city.warehouse"], "instrumented production evaluator receives exactly city.warehouse and no other City location", failures)
	_assert(evaluated_destination_ids == [&"city.warehouse.interior"], "instrumented production evaluation exposes exactly the Warehouse destination", failures)


func _assert_warehouse_shadow_and_developer_preview(snapshot: CityAccessSnapshot, failures: Array[String]) -> void:
	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	settings.use_city_access_snapshot = true
	var emissions: Array = []
	var provider := CityAccessProvider.new(func(_path: String) -> CityAccessLoadResult: return CityAccessLoadResult.success(snapshot))
	var comparator := CityAccessShadowComparator.new(provider, Callable(), func(marker: String, warning: bool) -> void:
		emissions.append([marker, warning])
	)
	var locked_profile := ProfileState.new_profile("shadow-locked", "Shadow Locked", 1)
	var unlocked_profile := ProfileState.new_profile("shadow-unlocked", "Shadow Unlocked", 2)
	unlocked_profile.permanent_feature_unlocks = ["stash"]
	var locked_before := ProfileCodec.encode(locked_profile).to_utf8_buffer()
	var unlocked_before := ProfileCodec.encode(unlocked_profile).to_utf8_buffer()
	var locked: Variant = comparator.observe(settings, locked_profile)
	_assert(locked is CityAccessShadowComparison, "locked Developer Mode shadow observation returns a comparison", failures)
	if locked is CityAccessShadowComparison:
		var typed_locked := locked as CityAccessShadowComparison
		_assert(typed_locked.outcome == CityAccessShadowComparison.Outcome.DIVERGED, "locked shadow outcome diverges", failures)
		_assert(typed_locked.access == CityAccessShadowComparison.Dimension.MATCH, "locked shadow access matches", failures)
		_assert(typed_locked.visibility == CityAccessShadowComparison.Dimension.DIVERGED, "locked shadow visibility diverges", failures)
		_assert(typed_locked.destination == CityAccessShadowComparison.Dimension.NOT_APPLICABLE, "locked shadow destination is not applicable", failures)
	_assert(ProfileCodec.encode(locked_profile).to_utf8_buffer() == locked_before, "locked shadow observation preserves ProfileCodec bytes", failures)
	var unlocked: Variant = comparator.observe(settings, unlocked_profile)
	_assert(unlocked is CityAccessShadowComparison, "unlocked Developer Mode shadow observation returns a comparison", failures)
	if unlocked is CityAccessShadowComparison:
		var typed_unlocked := unlocked as CityAccessShadowComparison
		_assert(typed_unlocked.outcome == CityAccessShadowComparison.Outcome.MATCH, "unlocked shadow outcome matches", failures)
		_assert(typed_unlocked.access == CityAccessShadowComparison.Dimension.MATCH, "unlocked shadow access matches", failures)
		_assert(typed_unlocked.visibility == CityAccessShadowComparison.Dimension.MATCH, "unlocked shadow visibility matches", failures)
		_assert(typed_unlocked.destination == CityAccessShadowComparison.Dimension.MATCH, "unlocked shadow destination matches", failures)
	_assert(ProfileCodec.encode(unlocked_profile).to_utf8_buffer() == unlocked_before, "unlocked shadow observation preserves ProfileCodec bytes", failures)
	comparator.observe(settings, unlocked_profile)
	_assert(emissions.size() == 2, "locked and repeated-unlocked observations emit exactly two unique markers", failures)
	if emissions.size() == 2:
		var locked_marker := String((emissions[0] as Array)[0])
		var unlocked_marker := String((emissions[1] as Array)[0])
		_assert("outcome=DIVERGED access=MATCH visibility=DIVERGED destination=NOT_APPLICABLE" in locked_marker, "captured locked marker records the expected divergence", failures)
		_assert("outcome=MATCH access=MATCH visibility=MATCH destination=MATCH" in unlocked_marker, "captured unlocked marker records complete parity", failures)
		_assert(bool((emissions[0] as Array)[1]) and not bool((emissions[1] as Array)[1]), "injected emitter classifies locked divergence without writing warning output", failures)
	var failure_emissions: Array = []
	var failure_provider := CityAccessProvider.new(func(_path: String) -> CityAccessLoadResult: return CityAccessLoadResult.failure("raw fixture path must never escape"))
	var failure_comparator := CityAccessShadowComparator.new(failure_provider, Callable(), func(marker: String, warning: bool) -> void:
		failure_emissions.append([marker, warning])
	)
	var failure_before := ProfileCodec.encode(locked_profile).to_utf8_buffer()
	var unavailable: Variant = failure_comparator.observe(settings, locked_profile)
	_assert(unavailable is CityAccessShadowComparison and (unavailable as CityAccessShadowComparison).outcome == CityAccessShadowComparison.Outcome.UNAVAILABLE, "candidate failure returns an unavailable comparison", failures)
	_assert(ProfileCodec.encode(locked_profile).to_utf8_buffer() == failure_before, "candidate failure preserves ProfileCodec bytes", failures)
	_assert(failure_emissions.size() == 1, "candidate failure emits one captured marker", failures)
	if failure_emissions.size() == 1:
		var failure_marker := String((failure_emissions[0] as Array)[0])
		_assert("outcome=UNAVAILABLE" in failure_marker and "reason=candidate_snapshot_load_failed" in failure_marker, "captured candidate failure marker is allowlisted", failures)
		_assert(not "raw fixture" in failure_marker and not "/" in failure_marker and not "\\" in failure_marker, "captured candidate failure marker excludes raw diagnostics and paths", failures)
		_assert(bool((failure_emissions[0] as Array)[1]), "captured candidate failure is classified as a warning without printing one", failures)
	var flag_off_loads: Array[String] = []
	var flag_off_provider := CityAccessProvider.new(func(_path: String) -> CityAccessLoadResult:
		flag_off_loads.append(_path)
		return CityAccessLoadResult.success(snapshot)
	)
	var flag_off_comparator := CityAccessShadowComparator.new(flag_off_provider)
	var flag_off_settings := PartyForgeSettings.new()
	flag_off_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	_assert(flag_off_comparator.observe(flag_off_settings, locked_profile) == null and flag_off_loads.is_empty(), "flag-off uses immediate legacy-only behavior without candidate loading", failures)
	var developer_preview := MainMenuViewModel.build(locked_profile, settings, true)
	_assert(developer_preview.warehouse_visible and developer_preview.warehouse_enabled and developer_preview.warehouse_label.contains("Developer"), "Developer Mode keeps the no-stash Warehouse preview visible and enabled", failures)
	var player_settings := PartyForgeSettings.new()
	player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	player_settings.use_city_access_snapshot = true
	var player_locked := MainMenuViewModel.build(locked_profile, player_settings, true, WarehousePresentationResult.State.LOCKED)
	var player_unlocked := MainMenuViewModel.build(unlocked_profile, player_settings, true, WarehousePresentationResult.State.AVAILABLE)
	_assert(player_locked.warehouse_visible and player_locked.warehouse_enabled and player_locked.warehouse_presentation_state == WarehousePresentationResult.State.LOCKED and player_locked.warehouse_route_id == MainMenuViewModel.ROUTE_WAREHOUSE, "Player Mode presents the locked Warehouse route without granting authority", failures)
	_assert(player_unlocked.warehouse_visible and player_unlocked.warehouse_enabled and player_unlocked.warehouse_presentation_state == WarehousePresentationResult.State.AVAILABLE and player_unlocked.warehouse_route_id == MainMenuViewModel.ROUTE_WAREHOUSE, "Player Mode makes the Warehouse route available only with stash authority", failures)


func _assert_production_warehouse_route_authorization(failures: Array[String]) -> void:
	var root := "user://tests/city-access-snapshot-runner-warehouse-route_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var settings_path := "user://tests/city-access-snapshot-runner-warehouse-route-settings_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(root)
	_cleanup_settings_artifacts(settings_path)
	var settings_directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(settings_path.get_base_dir())
	)
	_assert(settings_directory_error == OK, "route fixture creates its isolated settings directory", failures)
	var player_settings := PartyForgeSettings.new()
	player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	player_settings.use_city_access_snapshot = true
	_assert(PartyForgeSettingsStore.new().save_settings(player_settings, settings_path).is_empty(), "route fixture persists Player Mode settings", failures)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
	main.set("profile_root", root)
	main.set("settings_path", settings_path)
	main.call("_ready")
	var manager := main.get("profile_manager") as ProfileManager
	var created := manager.create_profile("Warehouse Route Acceptance") if manager != null else ProfileOperationResult.new()
	_assert(created.ok(), "route fixture creates an active locked profile", failures)
	if created.ok():
		var locked_profile := manager.active_profile()
		var menu := main.get_node("MainMenuScreen") as MainMenuScreen
		var warehouse := main.get_node("WarehouseScreen") as WarehouseScreen
		var dispatched_route_ids: Array[StringName] = []
		var opened_storage_targets: Array[StringName] = []
		menu.route_requested.connect(func(route_id: StringName) -> void:
			dispatched_route_ids.append(route_id)
			if warehouse.is_open():
				opened_storage_targets.append(StringName(warehouse.name))
		)
		_assert(not bool(main.call("_storage_route_allowed", MainMenuViewModel.ROUTE_WAREHOUSE, locked_profile)), "production Warehouse authorization seam blocks Player Mode without stash", failures)
		menu.call("_emit_route", MainMenuViewModel.ROUTE_WAREHOUSE, menu.get_node("Warehouse") as Control)
		_assert(menu.is_open() and not warehouse.is_open(), "production Warehouse dispatcher rejects Player Mode without stash", failures)
		locked_profile.permanent_feature_unlocks = ["stash"]
		_assert(ProfileStore.new().save_profile(locked_profile, root).is_empty(), "route fixture persists stash unlock", failures)
		_assert(manager.refresh_profile(locked_profile.profile_id).is_empty(), "route fixture refreshes the stash-unlocked profile", failures)
		var unlocked_profile := manager.active_profile()
		_assert(bool(main.call("_storage_route_allowed", MainMenuViewModel.ROUTE_WAREHOUSE, unlocked_profile)), "production Warehouse authorization seam allows Player Mode with stash", failures)
		menu.call("_emit_route", MainMenuViewModel.ROUTE_WAREHOUSE, menu.get_node("Warehouse") as Control)
		_assert(warehouse.is_open() and not menu.is_open(), "production Warehouse dispatcher opens Player Mode with stash", failures)
		_assert(dispatched_route_ids == [MainMenuViewModel.ROUTE_WAREHOUSE, MainMenuViewModel.ROUTE_WAREHOUSE], "instrumented menu dispatches exactly the Warehouse route for locked and unlocked activation", failures)
		_assert(opened_storage_targets == [&"WarehouseScreen"], "instrumented production dispatch opens exactly the Warehouse destination and no other storage target", failures)
	main.free()
	ProfileTestSupport.remove_tree(root)
	_cleanup_settings_artifacts(settings_path)


func _cleanup_settings_artifacts(settings_path: String) -> void:
	for path: String in [settings_path, "%s.tmp" % settings_path, "%s.bak" % settings_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fixture_snapshot(location_id: StringName, destination_id: StringName, state: CityAccessProjection.State) -> CityAccessSnapshot:
	return _fixture_snapshot_from_locations([_fixture_location(location_id, destination_id, state)])


func _fixture_snapshot_from_locations(locations: Array[Dictionary]) -> CityAccessSnapshot:
	var document := {
		"format": "party-forge-access-snapshot",
		"version": 1,
		"source": {
			"adapter": "latticewright-runtime-v3-city-access",
			"format": "latticewright-progression",
			"formatVersion": 3,
			"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
		},
		"locations": locations,
	}
	var loaded := CityAccessSnapshotLoader.load_bytes(JSON.stringify(document).to_utf8_buffer())
	return loaded.snapshot if loaded.ok() else null


func _fixture_location(location_id: StringName, destination_id: StringName, state: CityAccessProjection.State) -> Dictionary:
	var visible_when: Array[Dictionary] = [{"kind": "always", "value": ""}]
	var available_when: Array[Dictionary] = [{"kind": "always", "value": ""}]
	if state == CityAccessProjection.State.HIDDEN:
		visible_when = [{"kind": "prologue_state", "value": "completed"}]
	elif state == CityAccessProjection.State.LOCKED:
		available_when = [{"kind": "permanent_unlock", "value": "stash"}]
	return {
		"id": String(location_id),
		"destinationId": String(destination_id),
		"visibleWhen": visible_when,
		"availableWhen": available_when,
	}


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
	print("WAREHOUSE_PRESENTATION_ACTIVATION_OK location=city.warehouse rollback=legacy authority=warehouse_policy")
	print("CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy")
	quit(0)
