extends RefCounted

const COMPARISON_PATH := "res://scripts/world/access/city_access_shadow_comparison.gd"
const COMPARATOR_PATH := "res://scripts/world/access/city_access_shadow_comparator.gd"
const PROFILE_STATE := preload("res://scripts/profile/profile_state.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_inactive_gates_and_reset(failures)
	_test_locked_and_unlocked_dimensions(failures)
	_test_failure_and_destination_sanitization(failures)
	_test_deduplication_and_input_immutability(failures)
	return failures


func _test_inactive_gates_and_reset(failures: Array[String]) -> void:
	var scripts := _scripts(failures)
	if scripts.is_empty():
		return
	var loader_calls := 0
	var emissions: Array = []
	var provider := CityAccessProvider.new(func(_path: String) -> Variant:
		loader_calls += 1
		return CityAccessSnapshotLoader.load_path(CityAccessProvider.SNAPSHOT_PATH)
	)
	var comparator: Variant = scripts["comparator"].new(provider, Callable(), func(marker: String, warning: bool) -> void:
		emissions.append([marker, warning])
	)
	var profile: Variant = _profile(false)
	var disabled := _settings(false, PartyForgeSettings.Mode.DEVELOPER_MODE)
	_assert_observe_immutable(comparator, disabled, profile, null, "flag-off gate", failures)
	var player_mode := _settings(true, PartyForgeSettings.Mode.PLAYER_SIMULATION)
	_assert_observe_immutable(comparator, player_mode, profile, null, "Player Mode gate", failures)
	TestAssertions.equal(loader_calls, 0, "inactive gates do not call the provider", failures)
	TestAssertions.equal(emissions.size(), 0, "inactive gates do not emit", failures)
	var enabled := _settings(true, PartyForgeSettings.Mode.DEVELOPER_MODE)
	_assert_observe_immutable(comparator, enabled, profile, scripts["comparison"], "active observation", failures)
	TestAssertions.equal(emissions.size(), 1, "active observation emits once", failures)
	_assert_observe_immutable(comparator, disabled, profile, null, "disable resets comparator", failures)
	_assert_observe_immutable(comparator, enabled, profile, scripts["comparison"], "re-enabled observation", failures)
	TestAssertions.equal(emissions.size(), 2, "re-enabling resets marker deduplication", failures)


func _test_locked_and_unlocked_dimensions(failures: Array[String]) -> void:
	var scripts := _scripts(failures)
	if scripts.is_empty():
		return
	var emissions: Array = []
	var comparator: Variant = _comparator_with_real_snapshot(scripts["comparator"], emissions)
	var settings := _settings(true, PartyForgeSettings.Mode.DEVELOPER_MODE)
	var locked: Variant = _observe_immutable(comparator, settings, _profile(false), "locked comparison", failures)
	_assert_comparison(locked, scripts["comparison"], {
		"outcome": scripts["comparison"].Outcome.DIVERGED,
		"access": scripts["comparison"].Dimension.MATCH,
		"visibility": scripts["comparison"].Dimension.DIVERGED,
		"destination": scripts["comparison"].Dimension.NOT_APPLICABLE,
		"reason": &"visibility_hidden_vs_locked",
	}, "no stash", failures)
	var unlocked: Variant = _observe_immutable(comparator, settings, _profile(true), "unlocked comparison", failures)
	_assert_comparison(unlocked, scripts["comparison"], {
		"outcome": scripts["comparison"].Outcome.MATCH,
		"access": scripts["comparison"].Dimension.MATCH,
		"visibility": scripts["comparison"].Dimension.MATCH,
		"destination": scripts["comparison"].Dimension.MATCH,
		"reason": &"all_dimensions_match",
	}, "stash present", failures)
	TestAssertions.equal(emissions.size(), 2, "locked and unlocked states each emit a comparison", failures)


func _test_failure_and_destination_sanitization(failures: Array[String]) -> void:
	var scripts := _scripts(failures)
	if scripts.is_empty():
		return
	var failure_emissions: Array = []
	var failure_provider := CityAccessProvider.new(func(_path: String) -> Variant:
		return CityAccessLoadResult.failure("raw fixture path must never escape")
	)
	var failure_comparator: Variant = scripts["comparator"].new(failure_provider, Callable(), func(marker: String, warning: bool) -> void:
		failure_emissions.append([marker, warning])
	)
	var unavailable: Variant = _observe_immutable(failure_comparator, _settings(true, PartyForgeSettings.Mode.DEVELOPER_MODE), _profile(false), "candidate failure", failures)
	_assert_comparison(unavailable, scripts["comparison"], {
		"outcome": scripts["comparison"].Outcome.UNAVAILABLE,
		"access": scripts["comparison"].Dimension.UNAVAILABLE,
		"visibility": scripts["comparison"].Dimension.UNAVAILABLE,
		"destination": scripts["comparison"].Dimension.UNAVAILABLE,
		"reason": &"candidate_snapshot_load_failed",
	}, "candidate load failure", failures)
	TestAssertions.equal(failure_emissions.size(), 1, "candidate failure emits one sanitized marker", failures)
	if failure_emissions.size() == 1:
		var marker := String((failure_emissions[0] as Array)[0])
		TestAssertions.truthy("candidate_snapshot_load_failed" in marker, "failure marker exposes allowlisted reason", failures)
		TestAssertions.truthy(not "raw fixture" in marker and not "/" in marker and not "\\" in marker, "failure marker excludes raw parser text and paths", failures)
	var destination_emissions: Array = []
	var destination_comparator: Variant = scripts["comparator"].new(_provider_with_real_snapshot(), func(_snapshot: Variant, _profile: Variant, _location_id: Variant) -> Variant:
		return CityAccessProjection.new(&"city.warehouse", CityAccessProjection.State.AVAILABLE, &"visible", &"city.unexpected")
	, func(marker: String, warning: bool) -> void:
		destination_emissions.append([marker, warning])
	)
	var destination_comparison: Variant = _observe_immutable(destination_comparator, _settings(true, PartyForgeSettings.Mode.DEVELOPER_MODE), _profile(true), "destination mismatch", failures)
	_assert_comparison(destination_comparison, scripts["comparison"], {
		"outcome": scripts["comparison"].Outcome.DIVERGED,
		"access": scripts["comparison"].Dimension.MATCH,
		"visibility": scripts["comparison"].Dimension.MATCH,
		"destination": scripts["comparison"].Dimension.DIVERGED,
		"reason": &"candidate_destination_unmapped",
	}, "candidate destination mismatch", failures)


func _test_deduplication_and_input_immutability(failures: Array[String]) -> void:
	var scripts := _scripts(failures)
	if scripts.is_empty():
		return
	var emissions: Array = []
	var comparator: Variant = _comparator_with_real_snapshot(scripts["comparator"], emissions)
	var settings := _settings(true, PartyForgeSettings.Mode.DEVELOPER_MODE)
	var profile: Variant = _profile(false)
	_assert_observe_immutable(comparator, settings, profile, scripts["comparison"], "first tuple", failures)
	_assert_observe_immutable(comparator, settings, profile, scripts["comparison"], "repeated tuple", failures)
	TestAssertions.equal(emissions.size(), 1, "same active tuple is emitted once", failures)
	profile.permanent_feature_unlocks.append("stash")
	_assert_observe_immutable(comparator, settings, profile, scripts["comparison"], "changed stash state", failures)
	TestAssertions.equal(emissions.size(), 2, "changed profile stash state emits a new comparison", failures)
	var disabled := _settings(false, PartyForgeSettings.Mode.DEVELOPER_MODE)
	_assert_observe_immutable(comparator, disabled, profile, null, "disable after changed tuple", failures)
	_assert_observe_immutable(comparator, settings, profile, scripts["comparison"], "re-enable changed tuple", failures)
	TestAssertions.equal(emissions.size(), 3, "re-enabled current tuple emits again", failures)


func _scripts(failures: Array[String]) -> Dictionary:
	TestAssertions.truthy(FileAccess.file_exists(COMPARISON_PATH), "City access shadow comparison script exists", failures)
	TestAssertions.truthy(FileAccess.file_exists(COMPARATOR_PATH), "City access shadow comparator script exists", failures)
	if not FileAccess.file_exists(COMPARISON_PATH) or not FileAccess.file_exists(COMPARATOR_PATH):
		return {}
	var comparison: Variant = load(COMPARISON_PATH)
	var comparator: Variant = load(COMPARATOR_PATH)
	TestAssertions.truthy(comparison != null, "City access shadow comparison script loads", failures)
	TestAssertions.truthy(comparator != null, "City access shadow comparator script loads", failures)
	return {"comparison": comparison, "comparator": comparator} if comparison != null and comparator != null else {}


func _comparator_with_real_snapshot(comparator_script: Variant, emissions: Array) -> Variant:
	return comparator_script.new(_provider_with_real_snapshot(), Callable(), func(marker: String, warning: bool) -> void:
		emissions.append([marker, warning])
	)


func _provider_with_real_snapshot() -> CityAccessProvider:
	return CityAccessProvider.new(func(_path: String) -> Variant:
		return CityAccessSnapshotLoader.load_path(CityAccessProvider.SNAPSHOT_PATH)
	)


func _settings(enabled: bool, mode: PartyForgeSettings.Mode) -> PartyForgeSettings:
	var settings := PartyForgeSettings.new()
	settings.mode = mode
	settings.use_city_access_snapshot = enabled
	return settings


func _profile(has_stash: bool) -> Variant:
	var profile: Variant = PROFILE_STATE.new()
	profile.profile_id = "city-access-shadow"
	profile.display_name = "City Access Shadow"
	profile.created_at_unix = 1
	profile.updated_at_unix = 1
	var unlocks: Array[String] = []
	if has_stash:
		unlocks.append("stash")
	profile.permanent_feature_unlocks = unlocks
	return profile


func _observe_immutable(comparator: Variant, settings: PartyForgeSettings, profile: Variant, label: String, failures: Array[String]) -> Variant:
	var before_profile: Variant = profile.to_dictionary()
	var before_settings := _settings_values(settings.copy())
	var result: Variant = comparator.observe(settings, profile)
	TestAssertions.equal(profile.to_dictionary(), before_profile, "%s leaves profile unchanged" % label, failures)
	TestAssertions.equal(_settings_values(settings), before_settings, "%s leaves settings unchanged" % label, failures)
	return result


func _assert_observe_immutable(comparator: Variant, settings: PartyForgeSettings, profile: Variant, expected: Variant, label: String, failures: Array[String]) -> void:
	var result: Variant = _observe_immutable(comparator, settings, profile, label, failures)
	if expected == null:
		TestAssertions.equal(result, null, "%s returns null", failures)
	else:
		TestAssertions.truthy(result != null, "%s returns a comparison", failures)


func _assert_comparison(comparison: Variant, comparison_script: Variant, expected: Dictionary, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(comparison != null, "%s returns a comparison", failures)
	if comparison == null:
		return
	TestAssertions.equal(comparison.outcome, expected["outcome"], "%s outcome", failures)
	TestAssertions.equal(comparison.access, expected["access"], "%s access dimension", failures)
	TestAssertions.equal(comparison.visibility, expected["visibility"], "%s visibility dimension", failures)
	TestAssertions.equal(comparison.destination, expected["destination"], "%s destination dimension", failures)
	TestAssertions.equal(comparison.reason, expected["reason"], "%s reason", failures)
	var before := [comparison.outcome, comparison.access, comparison.visibility, comparison.destination, comparison.legacy_access, comparison.candidate_access, comparison.reason]
	comparison.outcome = comparison_script.Outcome.MATCH
	comparison.access = comparison_script.Dimension.MATCH
	comparison.visibility = comparison_script.Dimension.MATCH
	comparison.destination = comparison_script.Dimension.MATCH
	comparison.reason = &"mutated"
	TestAssertions.equal([comparison.outcome, comparison.access, comparison.visibility, comparison.destination, comparison.legacy_access, comparison.candidate_access, comparison.reason], before, "%s comparison is read only", failures)


func _settings_values(settings: PartyForgeSettings) -> Array:
	return [settings.schema_version, settings.mode, settings.unlock_all_implemented_content, settings.god_mode, settings.party_capacity_override, settings.enemy_density_percent, settings.experience_multiplier_percent, settings.level_up_card_count, settings.reduced_motion, settings.personal_drop_multiplier_percent, settings.force_personal_drops, settings.personal_drop_source_category_override, settings.personal_drop_item_level_override, settings.show_ground_chest_diagnostics, settings.use_city_access_snapshot]
