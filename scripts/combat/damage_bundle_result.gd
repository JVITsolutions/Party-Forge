class_name DamageBundleResult
extends RefCounted

const SCRIPT_PATH := "res://scripts/combat/damage_bundle_result.gd"
const DAMAGE_EVENT := preload("res://scripts/combat/combat_damage_instance_event.gd")

var _valid := false
var _completed := false
var _error_reason := ""
var _target_id: StringName
var _target_position := Vector3.ZERO
var _results: Array[DamageResult] = []
var _presentation_events: Array[DAMAGE_EVENT] = []
var _total_overkill := 0.0
var _diagnostics: Dictionary = {}
var valid: bool:
	get: return _valid
	set(_value): pass
var completed: bool:
	get: return _completed
	set(_value): pass
var error_reason: String:
	get: return _error_reason
	set(_value): pass
var target_id: StringName:
	get: return _target_id
	set(_value): pass
var target_position: Vector3:
	get: return _target_position
	set(_value): pass
var results: Array[DamageResult]:
	get: return _copy_results(_results)
	set(_value): pass
var presentation_events: Array[DAMAGE_EVENT]:
	get: return _copy_events(_presentation_events)
	set(_value): pass
var living_instance_events: Array[DAMAGE_EVENT]:
	get:
		var living: Array[DAMAGE_EVENT] = []
		for event: DAMAGE_EVENT in _presentation_events:
			if event.target_was_alive:
				living.append(event.copy())
		return living
	set(_value): pass
var flash_events: Array[DAMAGE_EVENT]:
	get:
		var flashes: Array[DAMAGE_EVENT] = []
		for event: DAMAGE_EVENT in _presentation_events:
			if event.flash_eligible:
				flashes.append(event.copy())
		return flashes
	set(_value): pass
var total_overkill: float:
	get: return _total_overkill
	set(_value): pass
var diagnostics: Dictionary:
	get: return _diagnostics.duplicate(true)
	set(_value): pass

static func create_completed(
	target_id_value: StringName,
	position_value: Vector3,
	result_values: Array[DamageResult],
	event_values: Array[DAMAGE_EVENT],
	overkill_value: float,
	diagnostics_value: Dictionary
) -> DamageBundleResult:
	var bundle := (load(SCRIPT_PATH) as Script).new() as DamageBundleResult
	bundle._valid = true
	bundle._completed = true
	bundle._target_id = target_id_value
	bundle._target_position = position_value
	bundle._results = _copy_results(result_values)
	bundle._presentation_events = _copy_events(event_values)
	bundle._total_overkill = overkill_value
	bundle._diagnostics = diagnostics_value.duplicate(true)
	return bundle

static func create_failed(
	reason: String,
	target_id_value: StringName,
	position_value: Vector3,
	result_values: Array[DamageResult],
	diagnostics_value: Dictionary
) -> DamageBundleResult:
	var bundle := (load(SCRIPT_PATH) as Script).new() as DamageBundleResult
	bundle._error_reason = reason
	bundle._target_id = target_id_value
	bundle._target_position = position_value
	bundle._results = _copy_results(result_values)
	bundle._diagnostics = diagnostics_value.duplicate(true)
	return bundle

func copy() -> DamageBundleResult:
	if _valid:
		return create_completed(_target_id, _target_position, _results, _presentation_events, _total_overkill, _diagnostics)
	return create_failed(_error_reason, _target_id, _target_position, _results, _diagnostics)

static func _copy_results(values: Array[DamageResult]) -> Array[DamageResult]:
	var copied: Array[DamageResult] = []
	for result: DamageResult in values:
		copied.append(result.copy())
	return copied

static func _copy_events(values: Array[DAMAGE_EVENT]) -> Array[DAMAGE_EVENT]:
	var copied: Array[DAMAGE_EVENT] = []
	for event: DAMAGE_EVENT in values:
		copied.append(event.copy())
	return copied
