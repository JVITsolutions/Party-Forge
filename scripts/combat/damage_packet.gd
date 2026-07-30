class_name DamagePacket
extends RefCounted

var _valid := false
var _error_reason: String
var _source: CombatantAdapter
var _source_id: StringName
var _source_team_id := 0
var _attack_id: StringName
var _can_crit := false
var _critical := false
var _crit_draw := -1.0
var _crit_multiplier := 1.0
var _life_steal_rate := 0.0
var _action_tags: Array[StringName] = []
var _components: Array[PreparedDamageComponent] = []
var valid: bool:
	get: return _valid
	set(_value): pass
var error_reason: String:
	get: return _error_reason
	set(_value): pass
var source: CombatantAdapter:
	get: return _source
	set(_value): pass
var source_id: StringName:
	get: return _source_id
	set(_value): pass
var source_team_id: int:
	get: return _source_team_id
	set(_value): pass
var attack_id: StringName:
	get: return _attack_id
	set(_value): pass
var can_crit: bool:
	get: return _can_crit
	set(_value): pass
var critical: bool:
	get: return _critical
	set(_value): pass
var crit_draw: float:
	get: return _crit_draw
	set(_value): pass
var crit_multiplier: float:
	get: return _crit_multiplier
	set(_value): pass
var life_steal_rate: float:
	get: return _life_steal_rate
	set(_value): pass
var action_tags: Array[StringName]:
	get: return _action_tags.duplicate()
var components: Array[PreparedDamageComponent]:
	get:
		var result: Array[PreparedDamageComponent] = []
		for component: PreparedDamageComponent in _components: result.append(component.copy())
		return result

static func create(source_value: CombatantAdapter, attack_value: StringName, tags: Array[StringName], crit_allowed: bool, crit_result: bool, draw: float, multiplier: float, steal_rate: float, prepared: Array[PreparedDamageComponent]) -> DamagePacket:
	var packet := DamagePacket.new()
	packet._valid = true
	packet._source = source_value
	packet._source_id = source_value.combatant_id
	packet._source_team_id = source_value.team_id
	packet._attack_id = attack_value
	packet._can_crit = crit_allowed
	packet._critical = crit_result
	packet._crit_draw = draw
	packet._crit_multiplier = multiplier
	packet._life_steal_rate = steal_rate
	packet._action_tags = tags.duplicate()
	for component: PreparedDamageComponent in prepared: packet._components.append(component.copy())
	return packet

static func invalid(reason: String, source_value: CombatantAdapter = null, attack_value: StringName = &"") -> DamagePacket:
	var packet := DamagePacket.new()
	packet._error_reason = reason
	packet._source = source_value
	packet._source_id = source_value.combatant_id if source_value != null else &""
	packet._source_team_id = source_value.team_id if source_value != null else 0
	packet._attack_id = attack_value
	return packet

func source_is_available_for_life_steal() -> bool:
	return _source != null and _source.health != null and is_instance_valid(_source.health) and not _source.health.is_dead and not _source.health.is_downed
