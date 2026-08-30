class_name WarehousePresentationResolver
extends RefCounted

const LOCATION_ID := &"city.warehouse"
const EXPECTED_DESTINATION_ID := &"city.warehouse.interior"
const ALLOWED_PROVIDER_FAILURES: Array[StringName] = [
	&"candidate_snapshot_invalid",
	&"candidate_snapshot_loader_invalid",
	&"candidate_snapshot_load_failed",
]


static func resolve(
	settings: Variant,
	profile: Variant,
	legacy_state: WarehouseAccessPolicy.State,
	provider_result: Variant,
) -> WarehousePresentationResult:
	var legacy := _legacy(legacy_state, &"legacy_gate")
	if not settings is PartyForgeSettings or not profile is ProfileState:
		return _legacy(legacy_state, &"invalid_input")
	var typed_settings := settings as PartyForgeSettings
	if typed_settings.mode != PartyForgeSettings.Mode.PLAYER_SIMULATION:
		return _legacy(legacy_state, &"consumer_not_player_mode")
	if not typed_settings.use_city_access_snapshot:
		return legacy
	if not provider_result is CityAccessProviderResult:
		return _failed(legacy_state, &"candidate_provider_unavailable")
	var provider := provider_result as CityAccessProviderResult
	if provider.mode != CityAccessProviderResult.Mode.CANDIDATE or provider.snapshot == null:
		var provider_reason := provider.diagnostic if provider.diagnostic in ALLOWED_PROVIDER_FAILURES else &"candidate_provider_unavailable"
		return _failed(legacy_state, provider_reason)
	var warehouse_location := _warehouse_location(provider.snapshot)
	if warehouse_location == null:
		return _failed(legacy_state, &"candidate_projection_invalid")
	if warehouse_location.destination_id != EXPECTED_DESTINATION_ID:
		return _failed(legacy_state, &"candidate_destination_invalid")
	var projection: Variant = CityAccessEvaluator.evaluate(provider.snapshot, profile, LOCATION_ID)
	if not projection is CityAccessProjection:
		return _failed(legacy_state, &"candidate_projection_invalid")
	var typed := projection as CityAccessProjection
	if typed.location_id != LOCATION_ID or typed.reason_id in [&"invalid_input", &"unknown_location"]:
		return _failed(legacy_state, &"candidate_projection_invalid")
	if typed.state == CityAccessProjection.State.AVAILABLE and typed.destination_id != EXPECTED_DESTINATION_ID:
		return _failed(legacy_state, &"candidate_destination_invalid")
	if legacy_state == WarehouseAccessPolicy.State.AVAILABLE:
		return WarehousePresentationResult.new(
			WarehousePresentationResult.State.AVAILABLE,
			WarehousePresentationResult.Outcome.CANDIDATE if typed.state == CityAccessProjection.State.AVAILABLE else WarehousePresentationResult.Outcome.DIVERGED,
			&"candidate_matches_authority" if typed.state == CityAccessProjection.State.AVAILABLE else &"candidate_cannot_reduce_authority",
		)
	match typed.state:
		CityAccessProjection.State.HIDDEN:
			return WarehousePresentationResult.new(WarehousePresentationResult.State.HIDDEN, WarehousePresentationResult.Outcome.CANDIDATE, &"candidate_hidden")
		CityAccessProjection.State.LOCKED:
			return WarehousePresentationResult.new(WarehousePresentationResult.State.LOCKED, WarehousePresentationResult.Outcome.CANDIDATE, &"candidate_locked")
		CityAccessProjection.State.AVAILABLE:
			return WarehousePresentationResult.new(WarehousePresentationResult.State.LOCKED, WarehousePresentationResult.Outcome.DIVERGED, &"candidate_cannot_grant_authority")
	return _failed(legacy_state, &"candidate_projection_invalid")


static func _warehouse_location(snapshot: CityAccessSnapshot) -> CityAccessLocation:
	for location: CityAccessLocation in snapshot.locations:
		if location.id == LOCATION_ID:
			return location
	return null


static func _legacy(legacy_state: WarehouseAccessPolicy.State, reason: StringName) -> WarehousePresentationResult:
	var state := WarehousePresentationResult.State.AVAILABLE if legacy_state == WarehouseAccessPolicy.State.AVAILABLE else WarehousePresentationResult.State.HIDDEN
	return WarehousePresentationResult.new(state, WarehousePresentationResult.Outcome.LEGACY, reason)


static func _failed(legacy_state: WarehouseAccessPolicy.State, reason: StringName) -> WarehousePresentationResult:
	var result := _legacy(legacy_state, reason)
	result.outcome = WarehousePresentationResult.Outcome.CANDIDATE_FAILED
	return result
