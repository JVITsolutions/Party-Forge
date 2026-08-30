class_name WarehousePresentationReporter
extends RefCounted

var _emitter: Callable
var _last_marker := ""


func _init(emitter: Callable = Callable()) -> void:
	_emitter = emitter if emitter.is_valid() else Callable(self, "_emit_default")


func observe(settings: Variant, result: Variant) -> void:
	if (
		not settings is PartyForgeSettings
		or (settings as PartyForgeSettings).mode != PartyForgeSettings.Mode.PLAYER_SIMULATION
		or not (settings as PartyForgeSettings).use_city_access_snapshot
	):
		_last_marker = ""
		return
	if not result is WarehousePresentationResult:
		return
	var typed := result as WarehousePresentationResult
	var marker := typed.marker()
	if marker == _last_marker:
		return
	var warning := typed.outcome in [WarehousePresentationResult.Outcome.CANDIDATE_FAILED, WarehousePresentationResult.Outcome.DIVERGED]
	_emitter.call(marker, warning)
	_last_marker = marker


func _emit_default(marker: String, warning: bool) -> void:
	if warning:
		push_warning(marker)
	else:
		print(marker)
