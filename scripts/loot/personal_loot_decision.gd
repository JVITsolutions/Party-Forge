class_name PersonalLootDecision
extends RefCounted

var run_player_id: StringName
var profile_id := ""
var player_slot := -1
var eligible := false
var success := false
var reason: StringName
var basis_points := 0
var roll_basis_points := 0
var generation_seed := 0
var generation_sequence := 0
var item_level := 1

var run_seed := 0
var defeat_sequence := 0
var enemy_sequence := 0
var enemy_id: StringName
var source_category: StringName
var world_position := Vector3.ZERO
var encounter_seconds := 0.0

func to_dictionary() -> Dictionary:
	return {
		"run_player_id": String(run_player_id),
		"profile_id": profile_id,
		"player_slot": player_slot,
		"eligible": eligible,
		"success": success,
		"reason": String(reason),
		"basis_points": basis_points,
		"roll_basis_points": roll_basis_points,
		"generation_seed": generation_seed,
		"generation_sequence": generation_sequence,
		"item_level": item_level,
		"run_seed": run_seed,
		"defeat_sequence": defeat_sequence,
		"enemy_sequence": enemy_sequence,
		"enemy_id": String(enemy_id),
		"source_category": String(source_category),
		"world_position": world_position,
		"encounter_seconds": encounter_seconds,
	}

func copy() -> PersonalLootDecision:
	var result := PersonalLootDecision.new()
	result.run_player_id = run_player_id
	result.profile_id = profile_id
	result.player_slot = player_slot
	result.eligible = eligible
	result.success = success
	result.reason = reason
	result.basis_points = basis_points
	result.roll_basis_points = roll_basis_points
	result.generation_seed = generation_seed
	result.generation_sequence = generation_sequence
	result.item_level = item_level
	result.run_seed = run_seed
	result.defeat_sequence = defeat_sequence
	result.enemy_sequence = enemy_sequence
	result.enemy_id = enemy_id
	result.source_category = source_category
	result.world_position = world_position
	result.encounter_seconds = encounter_seconds
	return result
