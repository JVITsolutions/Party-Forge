class_name RunLoadoutCheckoutRequest
extends RefCounted

var _transaction_id := ""
var transaction_id: String:
	get:
		return _transaction_id
var _profile_id := ""
var profile_id: String:
	get:
		return _profile_id
var _run_id: StringName = &""
var run_id: StringName:
	get:
		return _run_id
var _run_seed := 0
var run_seed: int:
	get:
		return _run_seed
var _run_player_id: StringName = &""
var run_player_id: StringName:
	get:
		return _run_player_id
var _leader_member_id := 0
var leader_member_id: int:
	get:
		return _leader_member_id
var _selected_leader_class_id: StringName = &""
var selected_leader_class_id: StringName:
	get:
		return _selected_leader_class_id
var _bring_in_gear := false
var bring_in_gear: bool:
	get:
		return _bring_in_gear

static func create(
	transaction_id_value: String,
	profile_id_value: String,
	run_id_value: StringName,
	run_seed_value: int,
	run_player_id_value: StringName,
	leader_member_id_value: int,
	selected_leader_class_id_value: StringName,
	bring_in_gear_value: bool,
) -> RunLoadoutCheckoutRequest:
	var result := RunLoadoutCheckoutRequest.new()
	result._transaction_id = transaction_id_value
	result._profile_id = profile_id_value
	result._run_id = run_id_value
	result._run_seed = run_seed_value
	result._run_player_id = run_player_id_value
	result._leader_member_id = leader_member_id_value
	result._selected_leader_class_id = selected_leader_class_id_value
	result._bring_in_gear = bring_in_gear_value
	return result

func canonical_document() -> Dictionary:
	return {
		"bring_in_gear": bring_in_gear,
		"leader_member_id": leader_member_id,
		"profile_id": profile_id,
		"run_id": String(run_id),
		"run_player_id": String(run_player_id),
		"run_seed": run_seed,
		"selected_leader_class_id": String(selected_leader_class_id),
		"transaction_id": transaction_id,
	}
