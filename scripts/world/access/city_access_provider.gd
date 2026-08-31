class_name CityAccessProvider
extends RefCounted

const SNAPSHOT_PATH := "res://data/world/access/party-forge-city-access.snapshot.json"

var _snapshot_loader: Callable


func _init(snapshot_loader: Callable = Callable()) -> void:
	_snapshot_loader = snapshot_loader if snapshot_loader.is_valid() else _load_snapshot


func resolve(settings: PartyForgeSettings, _profile: ProfileState) -> CityAccessProviderResult:
	if settings == null:
		return CityAccessProviderResult.legacy(&"invalid_settings")
	if not settings.use_city_access_snapshot:
		return CityAccessProviderResult.legacy()
	var load_result: Variant = _snapshot_loader.call(SNAPSHOT_PATH)
	if not load_result is CityAccessLoadResult:
		return CityAccessProviderResult.candidate_failed(&"candidate_snapshot_loader_invalid")
	var typed_load_result := load_result as CityAccessLoadResult
	if not typed_load_result.ok() or typed_load_result.snapshot == null:
		return CityAccessProviderResult.candidate_failed(&"candidate_snapshot_load_failed")
	return CityAccessProviderResult.candidate(typed_load_result.snapshot)


func _load_snapshot(path: String) -> CityAccessLoadResult:
	return CityAccessSnapshotLoader.load_path(path)
