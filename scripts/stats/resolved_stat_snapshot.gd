class_name ResolvedStatSnapshot
extends RefCounted

var revision := 0
var _capabilities: Array[StringName] = []
var capabilities: Array[StringName]:
	get:
		return _capabilities.duplicate()
	set(value):
		_capabilities = value.duplicate()
var _values: Dictionary = {}
var _breakdowns: Dictionary = {}

func value(stat_id: StringName, fallback: float = 0.0) -> float:
	return float(_values.get(stat_id, fallback))

func breakdown(stat_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in _breakdowns.get(stat_id, []):
		result.append(row.duplicate(true))
	return result

func set_resolved(stat_id: StringName, amount: float, rows: Array[Dictionary]) -> void:
	_values[stat_id] = amount
	_breakdowns[stat_id] = rows.duplicate(true)
