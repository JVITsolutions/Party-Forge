class_name ActionCombatEstimate
extends RefCounted

var action_id: StringName
var display_name := ""
var available := false
var unavailable_reason := ""
var can_crit := false
var is_healing := false
var healing_amount := 0.0
var estimated_hps := 0.0
var normal_hit := 0.0
var critical_hit := 0.0
var average_hit := 0.0
var expected_critical_instances := 0.0
var expected_damage_instances := 1.0
var attacks_per_second := 0.0
var estimated_dps := 0.0
@warning_ignore("shadowed_global_identifier")
var range := 0.0
var area_radius := 0.0
var projectile_speed := 0.0
var component_rows: Array[Dictionary] = []
