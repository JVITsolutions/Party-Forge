class_name DamageResult
extends RefCounted

var valid := false
var error_reason: String
var source_id: StringName
var attack_id: StringName
var target_id: StringName
var action_tags: Array[StringName] = []
var can_crit := false
var critical := false
var crit_draw := -1.0
var crit_multiplier := 1.0
var instance_index := -1
var target_was_alive := false
var overkill_only := false
var health_before := 0.0
var killing_blow := false
var excess_damage := 0.0
var proc_eligible := false
var dodge_chance := 0.0
var dodge_draw := -1.0
var dodged := false
var block_chance := 0.0
var block_draw := -1.0
var blocked := false
var block_effectiveness := 0.0
var component_breakdowns: Array[Dictionary] = []
var incoming_multiplier := 1.0
var incoming_prevented := 0.0
var total_post_mitigation := 0.0
var damage_before_block := 0.0
var block_prevented := 0.0
var final_damage := 0.0
var actual_health_removed := 0.0
var life_steal_rate := 0.0
var life_steal_restored := 0.0

func copy() -> DamageResult:
	var result := DamageResult.new()
	result.valid = valid
	result.error_reason = error_reason
	result.source_id = source_id
	result.attack_id = attack_id
	result.target_id = target_id
	result.action_tags.assign(action_tags)
	result.can_crit = can_crit
	result.critical = critical
	result.crit_draw = crit_draw
	result.crit_multiplier = crit_multiplier
	result.instance_index = instance_index
	result.target_was_alive = target_was_alive
	result.overkill_only = overkill_only
	result.health_before = health_before
	result.killing_blow = killing_blow
	result.excess_damage = excess_damage
	result.proc_eligible = proc_eligible
	result.dodge_chance = dodge_chance
	result.dodge_draw = dodge_draw
	result.dodged = dodged
	result.block_chance = block_chance
	result.block_draw = block_draw
	result.blocked = blocked
	result.block_effectiveness = block_effectiveness
	result.component_breakdowns.assign(component_breakdowns.duplicate(true))
	result.incoming_multiplier = incoming_multiplier
	result.incoming_prevented = incoming_prevented
	result.total_post_mitigation = total_post_mitigation
	result.damage_before_block = damage_before_block
	result.block_prevented = block_prevented
	result.final_damage = final_damage
	result.actual_health_removed = actual_health_removed
	result.life_steal_rate = life_steal_rate
	result.life_steal_restored = life_steal_restored
	return result
