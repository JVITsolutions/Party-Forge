class_name CityAccessShadowComparator
extends RefCounted

const LOCATION_ID := &"city.warehouse"
const EXPECTED_DESTINATION_ID := &"city.warehouse.interior"
const ALLOWED_PROVIDER_REASONS: Array[StringName] = [
	&"candidate_snapshot_invalid",
	&"candidate_snapshot_loader_invalid",
	&"candidate_snapshot_load_failed",
]

var _provider: CityAccessProvider
var _evaluator: Callable
var _emitter: Callable
var _last_marker := ""


func _init(provider: CityAccessProvider = null, evaluator: Callable = Callable(), emitter: Callable = Callable()) -> void:
	_provider = provider if provider != null else CityAccessProvider.new()
	_evaluator = evaluator if evaluator.is_valid() else Callable(CityAccessEvaluator, "evaluate")
	_emitter = emitter if emitter.is_valid() else Callable(self, "_emit_default")


func observe(settings: Variant, profile: Variant) -> Variant:
	if not _enabled(settings):
		_last_marker = ""
		return null
	if not profile is ProfileState:
		return _publish(_unavailable(&"candidate_profile_invalid"))
	var legacy_state := WarehouseAccessPolicy.resolve(profile)
	var provider_result := _provider.resolve(settings as PartyForgeSettings, profile as ProfileState)
	if provider_result.mode != CityAccessProviderResult.Mode.CANDIDATE or provider_result.snapshot == null:
		var reason := provider_result.diagnostic if provider_result.diagnostic in ALLOWED_PROVIDER_REASONS else &"candidate_provider_unavailable"
		return _publish(_unavailable(reason, legacy_state))
	var projection: Variant = _evaluator.call(provider_result.snapshot, profile, LOCATION_ID)
	if not projection is CityAccessProjection:
		return _publish(_unavailable(&"candidate_projection_invalid", legacy_state))
	var typed_projection := projection as CityAccessProjection
	if typed_projection.location_id != LOCATION_ID or typed_projection.reason_id in [&"invalid_input", &"unknown_location"]:
		return _publish(_unavailable(&"candidate_projection_invalid", legacy_state))
	return _publish(_compare(legacy_state, typed_projection))


func _enabled(settings: Variant) -> bool:
	if not settings is PartyForgeSettings:
		return false
	var typed_settings := settings as PartyForgeSettings
	return typed_settings.mode == PartyForgeSettings.Mode.DEVELOPER_MODE and typed_settings.use_city_access_snapshot == true


func _compare(legacy_state: WarehouseAccessPolicy.State, projection: CityAccessProjection) -> CityAccessShadowComparison:
	var legacy_access := CityAccessShadowComparison.AccessState.AVAILABLE if legacy_state == WarehouseAccessPolicy.State.AVAILABLE else CityAccessShadowComparison.AccessState.BLOCKED
	var candidate_access: CityAccessShadowComparison.AccessState
	var candidate_visible := false
	match projection.state:
		CityAccessProjection.State.AVAILABLE:
			candidate_access = CityAccessShadowComparison.AccessState.AVAILABLE
			candidate_visible = true
		CityAccessProjection.State.LOCKED:
			candidate_access = CityAccessShadowComparison.AccessState.BLOCKED
			candidate_visible = true
		CityAccessProjection.State.HIDDEN:
			candidate_access = CityAccessShadowComparison.AccessState.BLOCKED
			candidate_visible = false
		_:
			return _unavailable(&"candidate_projection_invalid", legacy_state)
	var legacy_available := legacy_access == CityAccessShadowComparison.AccessState.AVAILABLE
	var access := CityAccessShadowComparison.Dimension.MATCH if legacy_access == candidate_access else CityAccessShadowComparison.Dimension.DIVERGED
	var visibility := CityAccessShadowComparison.Dimension.MATCH if legacy_available == candidate_visible else CityAccessShadowComparison.Dimension.DIVERGED
	var destination := CityAccessShadowComparison.Dimension.NOT_APPLICABLE
	if legacy_available and candidate_access == CityAccessShadowComparison.AccessState.AVAILABLE:
		destination = CityAccessShadowComparison.Dimension.MATCH if projection.destination_id == EXPECTED_DESTINATION_ID else CityAccessShadowComparison.Dimension.DIVERGED
	var outcome := CityAccessShadowComparison.Outcome.MATCH
	var reason := &"all_dimensions_match"
	if access == CityAccessShadowComparison.Dimension.DIVERGED:
		outcome = CityAccessShadowComparison.Outcome.DIVERGED
		reason = &"access_state_differs"
	elif visibility == CityAccessShadowComparison.Dimension.DIVERGED:
		outcome = CityAccessShadowComparison.Outcome.DIVERGED
		reason = &"visibility_hidden_vs_locked" if not legacy_available and candidate_visible else &"visibility_state_differs"
	elif destination == CityAccessShadowComparison.Dimension.DIVERGED:
		outcome = CityAccessShadowComparison.Outcome.DIVERGED
		reason = &"candidate_destination_unmapped"
	return CityAccessShadowComparison.new(outcome, access, visibility, destination, legacy_access, candidate_access, reason)


func _unavailable(reason: StringName, legacy_state: WarehouseAccessPolicy.State = WarehouseAccessPolicy.State.BLOCKED) -> CityAccessShadowComparison:
	var legacy_access := CityAccessShadowComparison.AccessState.AVAILABLE if legacy_state == WarehouseAccessPolicy.State.AVAILABLE else CityAccessShadowComparison.AccessState.BLOCKED
	return CityAccessShadowComparison.new(
		CityAccessShadowComparison.Outcome.UNAVAILABLE,
		CityAccessShadowComparison.Dimension.UNAVAILABLE,
		CityAccessShadowComparison.Dimension.UNAVAILABLE,
		CityAccessShadowComparison.Dimension.UNAVAILABLE,
		legacy_access,
		CityAccessShadowComparison.AccessState.UNAVAILABLE,
		reason,
	)


func _publish(comparison: CityAccessShadowComparison) -> CityAccessShadowComparison:
	var marker := comparison.marker()
	if marker != _last_marker:
		_emitter.call(marker, comparison.outcome != CityAccessShadowComparison.Outcome.MATCH)
		_last_marker = marker
	return comparison


func _emit_default(marker: String, warning: bool) -> void:
	if warning:
		push_warning(marker)
	else:
		print(marker)
