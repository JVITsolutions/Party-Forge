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
