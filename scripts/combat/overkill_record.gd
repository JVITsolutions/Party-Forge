class_name OverkillRecord
extends RefCounted

const SCRIPT_PATH := "res://scripts/combat/overkill_record.gd"

var _target_id: StringName
var _amount := 0.0
var _metadata: Dictionary = {}
var _recorded_at := 0.0
var _expires_at := 0.0
var _remaining_seconds := 0.0
var target_id: StringName:
	get: return _target_id
	set(_value): pass
var stable_target_identity: StringName:
	get: return _target_id
	set(_value): pass
var amount: float:
	get: return _amount
	set(_value): pass
var metadata: Dictionary:
	get: return _metadata.duplicate(true)
	set(_value): pass
var recorded_at: float:
	get: return _recorded_at
	set(_value): pass
var expires_at: float:
	get: return _expires_at
	set(_value): pass
var remaining_seconds: float:
	get: return _remaining_seconds
	set(_value): pass

static func create(target_value: StringName, amount_value: float, metadata_value: Dictionary, recorded_value: float, expires_value: float, remaining_value: float) -> OverkillRecord:
	var record_value := (load(SCRIPT_PATH) as Script).new() as OverkillRecord
	record_value._target_id = target_value
	record_value._amount = amount_value
	record_value._metadata = metadata_value.duplicate(true)
	record_value._recorded_at = recorded_value
	record_value._expires_at = expires_value
	record_value._remaining_seconds = remaining_value
	return record_value

func copy() -> OverkillRecord:
	return create(_target_id, _amount, _metadata, _recorded_at, _expires_at, _remaining_seconds)
