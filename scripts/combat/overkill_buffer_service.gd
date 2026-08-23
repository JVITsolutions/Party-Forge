class_name OverkillBufferService
extends RefCounted

const LIFETIME_SECONDS := 2.0
const OVERKILL_RECORD := preload("res://scripts/combat/overkill_record.gd")

var _elapsed := 0.0
var _records: Dictionary = {}
var elapsed: float:
	get: return _elapsed
	set(_value): pass

func record(target_id: StringName, amount: float, metadata: Dictionary = {}) -> bool:
	if target_id.is_empty() or not is_finite(amount) or amount < 0.0:
		return false
	_normalize_elapsed()
	_records[target_id] = {
		"amount": amount,
		"metadata": metadata.duplicate(true),
		"recorded_at": _elapsed,
		"expires_at": _elapsed + LIFETIME_SECONDS,
		"remaining_seconds": LIFETIME_SECONDS,
	}
	return true

func get_record(target_id: StringName) -> OVERKILL_RECORD:
	if not _records.has(target_id):
		return null
	var row := _records[target_id] as Dictionary
	return OVERKILL_RECORD.create(
		target_id,
		float(row["amount"]),
		row["metadata"] as Dictionary,
		float(row["recorded_at"]),
		float(row["expires_at"]),
		float(row["remaining_seconds"])
	)

func advance(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0:
		return false
	_normalize_elapsed()
	_elapsed = fposmod(_elapsed + fposmod(delta, LIFETIME_SECONDS), LIFETIME_SECONDS)
	var expired: Array[StringName] = []
	for target_value: Variant in _records:
		var target_id := StringName(target_value)
		var row := _records[target_value] as Dictionary
		var remaining := float(row["remaining_seconds"])
		if delta >= remaining:
			expired.append(target_id)
		else:
			row["remaining_seconds"] = remaining - delta
	for target_id: StringName in expired:
		_records.erase(target_id)
	return true

func size() -> int:
	return _records.size()

func clear() -> void:
	_records.clear()
	_elapsed = 0.0

func _normalize_elapsed() -> void:
	_elapsed = fposmod(_elapsed, LIFETIME_SECONDS) if is_finite(_elapsed) else 0.0
