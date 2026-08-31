class_name WarehousePresentationResult
extends RefCounted

enum State { HIDDEN, LOCKED, AVAILABLE }
enum Outcome { LEGACY, CANDIDATE, CANDIDATE_FAILED, DIVERGED }

const STATE_NAMES := [&"HIDDEN", &"LOCKED", &"AVAILABLE"]
const OUTCOME_NAMES := [&"LEGACY", &"CANDIDATE", &"CANDIDATE_FAILED", &"DIVERGED"]
const ALLOWED_REASONS: Array[StringName] = [
	&"legacy_gate", &"invalid_input", &"consumer_not_player_mode",
	&"candidate_provider_unavailable", &"candidate_snapshot_invalid",
	&"candidate_snapshot_loader_invalid", &"candidate_snapshot_load_failed",
	&"candidate_projection_invalid", &"candidate_destination_invalid",
	&"candidate_matches_authority", &"candidate_cannot_reduce_authority",
	&"candidate_hidden", &"candidate_locked", &"candidate_cannot_grant_authority",
	&"invalid_reason",
]

var state: State
var outcome: Outcome
var reason: StringName


func _init(state_value: State, outcome_value: Outcome, reason_value: StringName) -> void:
	state = state_value
	outcome = outcome_value
	reason = reason_value if reason_value in ALLOWED_REASONS else &"invalid_reason"


func copy() -> WarehousePresentationResult:
	return WarehousePresentationResult.new(state, outcome, reason)


func marker() -> String:
	var state_index := int(state) if int(state) >= 0 and int(state) < STATE_NAMES.size() else int(State.HIDDEN)
	var outcome_index := int(outcome) if int(outcome) >= 0 and int(outcome) < OUTCOME_NAMES.size() else int(Outcome.CANDIDATE_FAILED)
	var safe_reason := reason if reason in ALLOWED_REASONS else &"invalid_reason"
	return "PARTY_FORGE_WAREHOUSE_PRESENTATION outcome=%s state=%s reason=%s" % [
		OUTCOME_NAMES[outcome_index], STATE_NAMES[state_index], String(safe_reason),
	]
