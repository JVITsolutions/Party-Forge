class_name DamagePacket
extends RefCounted

var valid := false
var error_reason: String
var source: CombatantAdapter
var source_id: StringName
var source_team_id := 0
var attack_id: StringName
var can_crit := false
var critical := false
var crit_draw := -1.0
var crit_multiplier := 1.0
var life_steal_rate := 0.0
var _action_tags: Array[StringName] = []
var _components: Array[PreparedDamageComponent] = []
var action_tags: Array[StringName]:
	get: return _action_tags.duplicate()
var components: Array[PreparedDamageComponent]:
	get:
		var result: Array[PreparedDamageComponent] = []
		for component: PreparedDamageComponent in _components: result.append(component.copy())
		return result

static func create(source_value: CombatantAdapter, attack_value: StringName, tags: Array[StringName], crit_allowed: bool, crit_result: bool, draw: float, multiplier: float, steal_rate: float, prepared: Array[PreparedDamageComponent]) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.valid = true
	packet.source = source_value
	packet.source_id = source_value.combatant_id
	packet.source_team_id = source_value.team_id
	packet.attack_id = attack_value
	packet.can_crit = crit_allowed
	packet.critical = crit_result
	packet.crit_draw = draw
	packet.crit_multiplier = multiplier
	packet.life_steal_rate = steal_rate
	packet._action_tags = tags.duplicate()
	for component: PreparedDamageComponent in prepared: packet._components.append(component.copy())
	return packet

static func invalid(reason: String, source_value: CombatantAdapter = null, attack_value: StringName = &"") -> DamagePacket:
	var packet := DamagePacket.new()
	packet.error_reason = reason
	packet.source = source_value
	packet.source_id = source_value.combatant_id if source_value != null else &""
	packet.source_team_id = source_value.team_id if source_value != null else 0
	packet.attack_id = attack_value
	return packet

func source_is_available_for_life_steal() -> bool:
	return source != null and source.health != null and is_instance_valid(source.health) and not source.health.is_dead and not source.health.is_downed
