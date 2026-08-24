class_name CombatDamageInstanceEvent
extends RefCounted

const SCRIPT_PATH := "res://scripts/combat/combat_damage_instance_event.gd"

var _source_id: StringName
var _attack_id: StringName
var _target_id: StringName
var _target_position := Vector3.ZERO
var _instance_index := -1
var _instance_count := 0
var _damage := 0.0
var _critical := false
var _target_was_alive := false
var _overkill_only := false
var _flash_eligible := false
var _dodged := false
var _blocked := false
var source_id: StringName:
	get: return _source_id
	set(_value): pass
var attack_id: StringName:
	get: return _attack_id
	set(_value): pass
var target_id: StringName:
	get: return _target_id
	set(_value): pass
var target_position: Vector3:
	get: return _target_position
	set(_value): pass
var instance_index: int:
	get: return _instance_index
	set(_value): pass
var instance_count: int:
	get: return _instance_count
	set(_value): pass
var damage: float:
	get: return _damage
	set(_value): pass
var final_damage: float:
	get: return _damage
	set(_value): pass
var value: float:
	get: return _damage
	set(_value): pass
var critical: bool:
	get: return _critical
	set(_value): pass
var target_was_alive: bool:
	get: return _target_was_alive
	set(_value): pass
var living_target: bool:
	get: return _target_was_alive
	set(_value): pass
var overkill_only: bool:
	get: return _overkill_only
	set(_value): pass
var flash_eligible: bool:
	get: return _flash_eligible
	set(_value): pass
var dodged: bool:
	get: return _dodged
	set(_value): pass
var blocked: bool:
	get: return _blocked
	set(_value): pass

static func create(result: DamageResult, position_value: Vector3, count_value: int) -> CombatDamageInstanceEvent:
	var event := (load(SCRIPT_PATH) as Script).new() as CombatDamageInstanceEvent
	event._source_id = result.source_id
	event._attack_id = result.attack_id
	event._target_id = result.target_id
	event._target_position = position_value
	event._instance_index = result.instance_index
	event._instance_count = count_value
	event._damage = result.final_damage
	event._critical = result.critical
	event._target_was_alive = result.target_was_alive
	event._overkill_only = result.overkill_only
	event._flash_eligible = result.proc_eligible
	event._dodged = result.dodged
	event._blocked = result.blocked
	return event

func copy() -> CombatDamageInstanceEvent:
	var event := (load(SCRIPT_PATH) as Script).new() as CombatDamageInstanceEvent
	event._source_id = _source_id
	event._attack_id = _attack_id
	event._target_id = _target_id
	event._target_position = _target_position
	event._instance_index = _instance_index
	event._instance_count = _instance_count
	event._damage = _damage
	event._critical = _critical
	event._target_was_alive = _target_was_alive
	event._overkill_only = _overkill_only
	event._flash_eligible = _flash_eligible
	event._dodged = _dodged
	event._blocked = _blocked
	return event
