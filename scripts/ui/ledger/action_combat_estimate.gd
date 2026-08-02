class_name ActionCombatEstimate
extends RefCounted

var action_id: StringName
var display_name := ""
var available := false
var unavailable_reason := ""
var can_crit := false
var normal_hit := 0.0
var critical_hit := 0.0
var average_hit := 0.0
var attacks_per_second := 0.0
var estimated_dps := 0.0
var component_rows: Array[Dictionary] = []
