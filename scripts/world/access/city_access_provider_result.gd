class_name CityAccessProviderResult
extends RefCounted

enum Mode { LEGACY, CANDIDATE, CANDIDATE_FAILED }

static var _state_entries: Array[Dictionary] = []

var mode: Mode:
	get: return int(_state_value(self, &"mode", Mode.LEGACY)) as Mode
	set(_next): pass
var snapshot: CityAccessSnapshot:
	get:
		var value: Variant = _state_value(self, &"snapshot", null)
		return (value as CityAccessSnapshot).copy() if value is CityAccessSnapshot else null
	set(_next): pass
var diagnostic: StringName:
	get: return _state_value(self, &"diagnostic", &"") as StringName
	set(_next): pass


static func legacy(diagnostic_value: StringName = &"") -> CityAccessProviderResult:
	return _create(Mode.LEGACY, null, diagnostic_value)


static func candidate(snapshot_value: CityAccessSnapshot) -> CityAccessProviderResult:
	if snapshot_value == null:
		return candidate_failed(&"candidate_snapshot_invalid")
	return _create(Mode.CANDIDATE, snapshot_value, &"")


static func candidate_failed(diagnostic_value: StringName) -> CityAccessProviderResult:
	return _create(Mode.CANDIDATE_FAILED, null, diagnostic_value)


static func _create(mode_value: Mode, snapshot_value: CityAccessSnapshot, diagnostic_value: StringName) -> CityAccessProviderResult:
	_discard_released_state()
	var result := CityAccessProviderResult.new()
	_state_entries.append({
		&"owner": weakref(result),
		&"mode": mode_value,
		&"snapshot": snapshot_value.copy() if snapshot_value != null else null,
		&"diagnostic": diagnostic_value,
	})
	return result


static func _state_value(result_value: Variant, key: StringName, fallback: Variant) -> Variant:
	var index := _state_index(result_value)
	if index < 0:
		return fallback
	return _state_entries[index].get(key, fallback)


static func _state_index(result_value: Variant) -> int:
	_discard_released_state()
	for index: int in range(_state_entries.size()):
		var owner: Variant = _state_entries[index].get(&"owner")
		if owner is WeakRef and (owner as WeakRef).get_ref() == result_value:
			return index
	return -1


static func _discard_released_state() -> void:
	for index: int in range(_state_entries.size() - 1, -1, -1):
		var owner: Variant = _state_entries[index].get(&"owner")
		if not owner is WeakRef or (owner as WeakRef).get_ref() == null:
			_state_entries.remove_at(index)


func _set(_property: StringName, _value: Variant) -> bool:
	return true
