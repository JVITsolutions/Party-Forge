class_name ExperienceSystem
extends Node

signal level_ready(level: int)

const DEFAULT_TUNING: ExperienceTuning = preload("res://data/progression/default_experience.tres")

var run_context: PlayerRunContext
var leader_member_id := 0
var tuning: ExperienceTuning = DEFAULT_TUNING
var _configured_multiplier_percent := 100

var level: int:
	get:
		var state := _leader_progression()
		return state.level if state != null else 1
var experience: int:
	get:
		var state := _leader_progression()
		return state.experience if state != null else 0
var pending_levels: int:
	get:
		return run_context.pending_leader_levels().size() if run_context != null else 0
var pending_level_numbers: Array[int]:
	get:
		return run_context.pending_leader_levels() if run_context != null else []
var configured_multiplier_percent: int:
	get:
		return run_context.experience_multiplier_percent if run_context != null else _configured_multiplier_percent
var experience_multiplier: float:
	get:
		return float(configured_multiplier_percent) / 100.0
var fractional_experience: float:
	get:
		var state := _leader_progression()
		return state.fractional_experience if state != null else 0.0

func configure_multiplier(percent: int) -> void:
	if run_context == null:
		_configured_multiplier_percent = clampi(percent, 100, 1000)

func configure_context(context: PlayerRunContext, member_id: int) -> void:
	var callback := Callable(self, "_on_member_level_ready")
	if run_context != null and run_context.member_level_ready.is_connected(callback):
		run_context.member_level_ready.disconnect(callback)
	run_context = null
	leader_member_id = 0
	_configured_multiplier_percent = 100
	var member := context.party.member_by_id(member_id) if context != null and context.party != null and member_id > 0 else null
	if member == null or not member.is_leader or context.progression_for(member_id) == null:
		return
	run_context = context
	leader_member_id = member_id
	if not run_context.member_level_ready.is_connected(callback):
		run_context.member_level_ready.connect(callback)

func experience_for_next_level() -> int:
	var state := _leader_progression()
	return state.experience_required if state != null else tuning.requirement_for_level(1)

func add_experience(amount: int) -> void:
	if run_context != null and leader_member_id > 0:
		run_context.award_experience(leader_member_id, amount)

func current_pending_level() -> int:
	return run_context.current_pending_level() if run_context != null else 0

func consume_pending_level() -> bool:
	return run_context.consume_pending_leader_level() if run_context != null else false

func _leader_progression() -> CharacterProgressionState:
	return run_context.progression_for(leader_member_id) if run_context != null and leader_member_id > 0 else null

func _on_member_level_ready(member_id: int, earned_level: int) -> void:
	if member_id == leader_member_id:
		level_ready.emit(earned_level)
