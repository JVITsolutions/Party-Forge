class_name DamageDefenseSnapshot
extends RefCounted

const SCRIPT_PATH := "res://scripts/combat/damage_defense_snapshot.gd"

var _valid := false
var _error_reason := ""
var _packet: DamagePacket
var _target_id: StringName
var _target_team_id := 0
var _dodge_chance := 0.0
var _type_defenses: Dictionary = {}
var _incoming_multiplier := 1.0
var _block_chance := 0.0
var _block_effectiveness := 0.0
var valid: bool:
	get: return _valid
	set(_value): pass
var error_reason: String:
	get: return _error_reason
	set(_value): pass
var packet_instance_id: int:
	get: return _packet.get_instance_id() if _packet != null else 0
	set(_value): pass
var target_id: StringName:
	get: return _target_id
	set(_value): pass
var target_team_id: int:
	get: return _target_team_id
	set(_value): pass
var dodge_chance: float:
	get: return _dodge_chance
	set(_value): pass
var type_defenses: Dictionary:
	get: return _type_defenses.duplicate(true)
	set(_value): pass
var incoming_multiplier: float:
	get: return _incoming_multiplier
	set(_value): pass
var block_chance: float:
	get: return _block_chance
	set(_value): pass
var block_effectiveness: float:
	get: return _block_effectiveness
	set(_value): pass

static func create(
	packet_value: DamagePacket,
	target_id_value: StringName,
	target_team_value: int,
	dodge_value: float,
	defenses_value: Dictionary,
	incoming_value: float,
	block_chance_value: float,
	block_effectiveness_value: float
) -> RefCounted:
	var snapshot = (load(SCRIPT_PATH) as Script).new()
	var error := _validation_error(
		packet_value,
		target_id_value,
		dodge_value,
		defenses_value,
		incoming_value,
		block_chance_value,
		block_effectiveness_value
	)
	if not error.is_empty():
		snapshot._error_reason = error
		return snapshot
	snapshot._valid = true
	snapshot._packet = packet_value
	snapshot._target_id = target_id_value
	snapshot._target_team_id = target_team_value
	snapshot._dodge_chance = dodge_value
	snapshot._type_defenses = defenses_value.duplicate(true)
	snapshot._incoming_multiplier = incoming_value
	snapshot._block_chance = block_chance_value
	snapshot._block_effectiveness = block_effectiveness_value
	return snapshot

static func invalid(reason: String) -> RefCounted:
	var snapshot = (load(SCRIPT_PATH) as Script).new()
	snapshot._error_reason = reason
	return snapshot

static func _validation_error(
	packet_value: DamagePacket,
	target_id_value: StringName,
	dodge_value: float,
	defenses_value: Dictionary,
	incoming_value: float,
	block_chance_value: float,
	block_effectiveness_value: float
) -> String:
	if packet_value == null:
		return "PARTY_FORGE_DAMAGE_ERROR target=%s reason=missing snapshot packet identity" % target_id_value
	if target_id_value.is_empty():
		return "PARTY_FORGE_DAMAGE_ERROR target=<empty> reason=missing snapshot target identity"
	if not is_finite(dodge_value):
		return "PARTY_FORGE_DAMAGE_ERROR target=%s reason=dodge chance must be finite" % target_id_value
	if dodge_value < 0.0:
		return "PARTY_FORGE_DAMAGE_ERROR target=%s reason=dodge chance must be nonnegative" % target_id_value
	if not is_finite(incoming_value):
		return "PARTY_FORGE_DAMAGE_ERROR target=%s reason=incoming multiplier must be finite" % target_id_value
	if incoming_value < 0.0:
		return "PARTY_FORGE_DAMAGE_ERROR target=%s reason=incoming multiplier must be nonnegative" % target_id_value
	if not is_finite(block_chance_value):
		return "PARTY_FORGE_DAMAGE_ERROR target=%s reason=block chance must be finite" % target_id_value
	if block_chance_value < 0.0:
		return "PARTY_FORGE_DAMAGE_ERROR target=%s reason=block chance must be nonnegative" % target_id_value
	if not is_finite(block_effectiveness_value):
		return "PARTY_FORGE_DAMAGE_ERROR target=%s reason=block effectiveness must be finite" % target_id_value
	if block_effectiveness_value < 0.0:
		return "PARTY_FORGE_DAMAGE_ERROR target=%s reason=block effectiveness must be nonnegative" % target_id_value
	if defenses_value.is_empty():
		return "PARTY_FORGE_DAMAGE_ERROR target=%s reason=missing per-type defenses" % target_id_value
	for type_value: Variant in defenses_value:
		var type_id := StringName(type_value)
		var row: Variant = defenses_value[type_value]
		if type_id.is_empty() or not row is Dictionary:
			return "PARTY_FORGE_DAMAGE_ERROR target=%s type=%s reason=invalid per-type defense" % [target_id_value, type_id]
		var defense_row := row as Dictionary
		var defense_stat_id := StringName(defense_row.get("defense_stat_id", &""))
		var defense_value := float(defense_row.get("defense_value", NAN))
		var mitigation_rule := int(defense_row.get("mitigation_rule", -1))
		if defense_stat_id.is_empty():
			return "PARTY_FORGE_DAMAGE_ERROR target=%s type=%s reason=missing defense stat" % [target_id_value, type_id]
		if not is_finite(defense_value):
			return "PARTY_FORGE_DAMAGE_ERROR target=%s type=%s stat=%s reason=defense must be finite" % [target_id_value, type_id, defense_stat_id]
		if mitigation_rule not in [DamageTypeDefinition.MitigationRule.ARMOR, DamageTypeDefinition.MitigationRule.RESISTANCE]:
			return "PARTY_FORGE_DAMAGE_ERROR target=%s type=%s rule=%d reason=unsupported mitigation rule" % [target_id_value, type_id, mitigation_rule]
	return ""

func matches_packet(candidate: DamagePacket) -> bool:
	return _valid and _packet != null and _packet == candidate

func copy() -> RefCounted:
	if not _valid:
		return invalid(_error_reason)
	return create(
		_packet,
		_target_id,
		_target_team_id,
		_dodge_chance,
		_type_defenses,
		_incoming_multiplier,
		_block_chance,
		_block_effectiveness
	)
