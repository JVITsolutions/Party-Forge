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
	_records[target_id] = {
		"amount": amount,
		"metadata": metadata.duplicate(true),
		"recorded_at": _elapsed,
		"expires_at": _elapsed + LIFETIME_SECONDS,
	}
	return true

func get_record(target_id: StringName) -> OVERKILL_RECORD:
	_expire_due_records()
	if not _records.has(target_id):
		return null
	var row := _records[target_id] as Dictionary
	var expires_at := float(row["expires_at"])
	return OVERKILL_RECORD.create(
		target_id,
		float(row["amount"]),
		row["metadata"] as Dictionary,
		float(row["recorded_at"]),
		expires_at,
		maxf(0.0, expires_at - _elapsed)
	)

func advance(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0:
		return false
	_elapsed += delta
	_expire_due_records()
	return true

func size() -> int:
	_expire_due_records()
	return _records.size()

func clear() -> void:
	_records.clear()
	_elapsed = 0.0

func _expire_due_records() -> void:
	var expired: Array[StringName] = []
	for target_value: Variant in _records:
		var target_id := StringName(target_value)
		var row := _records[target_value] as Dictionary
		if _elapsed >= float(row["expires_at"]):
			expired.append(target_id)
	for target_id: StringName in expired:
		_records.erase(target_id)
	# Absolute run time is not part of the contract. Rebase whenever no live
	# record depends on the clock so repeated huge finite deltas cannot overflow.
	if _records.is_empty():
		_elapsed = 0.0
