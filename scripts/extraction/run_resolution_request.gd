class_name RunResolutionRequest
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

var _ordinary_selections: Array[ExtractionSelection] = []
var ordinary_selections: Array[ExtractionSelection]:
	get:
		return _copy_selections(_ordinary_selections)

static func create(
	transaction_id_value: String,
	profile_id_value: String,
	run_id_value: StringName,
	run_seed_value: int,
	run_player_id_value: StringName,
	leader_member_id_value: int,
	ordinary_selection_values: Array[ExtractionSelection],
) -> RunResolutionRequest:
	var result := RunResolutionRequest.new()
	result._transaction_id = transaction_id_value
	result._profile_id = profile_id_value
	result._run_id = run_id_value
	result._run_seed = run_seed_value
	result._run_player_id = run_player_id_value
	result._leader_member_id = leader_member_id_value
	result._ordinary_selections = _copy_selections(ordinary_selection_values)
	return result

func canonical_document() -> Dictionary:
	var selection_documents: Array[Dictionary] = []
	for selection: ExtractionSelection in _ordinary_selections:
		selection_documents.append(selection.to_dictionary() if selection != null else {})
	return {
		"leader_member_id": _leader_member_id,
		"ordinary_selections": selection_documents,
		"profile_id": _profile_id,
		"run_id": String(_run_id),
		"run_player_id": String(_run_player_id),
		"run_seed": _run_seed,
		"transaction_id": _transaction_id,
	}

static func _copy_selections(values: Array[ExtractionSelection]) -> Array[ExtractionSelection]:
	var result: Array[ExtractionSelection] = []
	for value: ExtractionSelection in values:
		result.append(value.copy() if value != null else null)
	return result
