class_name PlayerRunContext
extends RefCounted

signal progression_changed(member_id: int)
signal member_level_ready(member_id: int, level: int)

const DEFAULT_EXPERIENCE_TUNING: ExperienceTuning = preload("res://data/progression/default_experience.tres")

var _run_player_id: StringName = &""
var run_player_id: StringName:
	get:
		return _run_player_id
var _player_slot_index := -1
var player_slot_index: int:
	get:
		return _player_slot_index
var _profile_id := ""
var profile_id: String:
	get:
		return _profile_id
var _profile_snapshot: ProfileState
var profile_snapshot: ProfileState:
	get:
		return _profile_snapshot.copy() if _profile_snapshot != null else null
var _run_seed := 0
var run_seed: int:
	get:
		return _run_seed
var _experience_multiplier_percent := 100
var experience_multiplier_percent: int:
	get:
		return _experience_multiplier_percent
var party: PartyManager
var experience_tuning: ExperienceTuning = DEFAULT_EXPERIENCE_TUNING

var _progression_by_member: Dictionary = {}
var _pending_leader_levels: Array[int] = []
var _actor_by_member: Dictionary = {}

func configure(
	run_player_id_value: StringName,
	slot: int,
	profile: ProfileState,
	run_seed_value: int,
	manager: PartyManager,
	experience_multiplier: int,
) -> PackedStringArray:
	var errors := PackedStringArray()
	if run_player_id_value.is_empty():
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=run_player_id")
	if slot < 0:
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=player_slot_index")
	if profile == null or not ProfileCodec.validate_profile(profile).is_empty():
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=profile")
	if run_seed_value <= 0:
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=run_seed")
	if not _party_is_initialized(manager):
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=party")
	if experience_multiplier < 100 or experience_multiplier > 1000:
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=experience_multiplier")
	if not errors.is_empty():
		return errors

	var next_progression: Dictionary = {}
	for member: PartyMemberState in manager.members:
		var state := CharacterProgressionState.fresh(member.member_id, DEFAULT_EXPERIENCE_TUNING)
		if state == null:
			return PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=party"])
		next_progression[member.member_id] = state
	var owned_profile := profile.copy()
	if owned_profile == null:
		return PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=profile"])

	var member_added_callback := Callable(self, "_on_member_added")
	if party != null and party.member_added.is_connected(member_added_callback):
		party.member_added.disconnect(member_added_callback)
	_run_player_id = run_player_id_value
	_player_slot_index = slot
	_profile_id = owned_profile.profile_id
	_profile_snapshot = owned_profile
	_run_seed = run_seed_value
	_experience_multiplier_percent = experience_multiplier
	party = manager
	experience_tuning = DEFAULT_EXPERIENCE_TUNING
	_progression_by_member = next_progression
	_pending_leader_levels.clear()
	_actor_by_member.clear()
	if not party.member_added.is_connected(member_added_callback):
		party.member_added.connect(member_added_callback)
	return errors

func progression_for(member_id: int) -> CharacterProgressionState:
	var state := _progression_by_member.get(member_id) as CharacterProgressionState
	return state.copy() if state != null else null

func award_experience(member_id: int, amount: int) -> CharacterProgressionAward:
	var member := party.member_by_id(member_id) if party != null else null
	var current := _progression_by_member.get(member_id) as CharacterProgressionState
	if member == null or current == null or member.class_definition == null:
		return CharacterProgressionAward.failure("member=%d unavailable" % member_id)
	var award := CharacterProgressionService.preview_award(
		current,
		member.class_definition.growth_definition,
		experience_tuning,
		amount,
		experience_multiplier_percent,
		run_seed,
		run_player_id,
		member_id,
	)
	if not award.ok():
		return award
	if not award.gained_levels.is_empty():
		var source := CharacterProgressionService.source_for(member_id, award.next_state)
		if source == null or not party.replace_member_source(member_id, source):
			var failure := CharacterProgressionAward.new()
			failure.error = "PARTY_FORGE_PROGRESSION_ERROR member=%d reason=stat source rejected" % member_id
			return failure
	_progression_by_member[member_id] = award.next_state.copy()
	if member.is_leader:
		_pending_leader_levels.append_array(award.gained_levels)
	for earned_level: int in award.gained_levels:
		member_level_ready.emit(member_id, earned_level)
	progression_changed.emit(member_id)
	return award

func pending_leader_levels() -> Array[int]:
	return _pending_leader_levels.duplicate()

func current_pending_level() -> int:
	return _pending_leader_levels[0] if not _pending_leader_levels.is_empty() else 0

func consume_pending_leader_level() -> bool:
	if _pending_leader_levels.is_empty():
		return false
	_pending_leader_levels.pop_front()
	return true

func bind_actor(member_id: int, actor: Node3D) -> bool:
	if party == null or party.member_by_id(member_id) == null or actor == null:
		return false
	actor.set_meta("party_forge_run_player_id", run_player_id)
	actor.set_meta("party_forge_member_id", member_id)
	_actor_by_member[member_id] = weakref(actor)
	return true

func actor_for(member_id: int) -> Node3D:
	var reference := _actor_by_member.get(member_id) as WeakRef
	var actor := reference.get_ref() as Node3D if reference != null else null
	if actor == null:
		_actor_by_member.erase(member_id)
	return actor

func member_is_available(member_id: int) -> bool:
	var actor := actor_for(member_id)
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent if actor != null else null
	return health != null and not health.is_dead and not health.is_downed

func member_position(member_id: int) -> Dictionary:
	var actor := actor_for(member_id)
	if actor == null:
		return {"valid": false}
	return {"valid": true, "position": actor.global_position if actor.is_inside_tree() else actor.position}

func _on_member_added(member: PartyMemberState) -> void:
	if member == null or member.member_id <= 0 or _progression_by_member.has(member.member_id):
		return
	var state := CharacterProgressionState.fresh(member.member_id, experience_tuning)
	if state != null:
		_progression_by_member[member.member_id] = state

func _party_is_initialized(manager: PartyManager) -> bool:
	if manager == null or manager.members.is_empty():
		return false
	var member_ids: Dictionary = {}
	for member: PartyMemberState in manager.members:
		if member == null or member.member_id <= 0 or member.class_definition == null or member_ids.has(member.member_id):
			return false
		member_ids[member.member_id] = true
	return true
