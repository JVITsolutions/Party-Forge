class_name RunContextRegistry
extends RefCounted

var _by_run_player: Dictionary = {}
var _by_profile: Dictionary = {}
var _by_slot: Dictionary = {}
var _by_device: Dictionary = {}
var _by_party: Dictionary = {}
var _device_by_run_player: Dictionary = {}
var _arena_roster_locked := false

func register_context(context: PlayerRunContext, device_id: int = -1) -> RunContextRegistrationResult:
	if context == null:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.INVALID_CONTEXT, "context is null")
	var run_player_id := context.run_player_id
	var profile_id := context.profile_id
	var slot := context.player_slot_index
	if run_player_id.is_empty() or profile_id.is_empty() or slot < 0:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.INVALID_CONTEXT, "identity fields are invalid")
	if _arena_roster_locked:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.ARENA_RUN_LOCKED, "Arena roster is locked")
	if _by_run_player.has(run_player_id):
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_RUN_PLAYER, "run player %s already registered" % run_player_id)
	if _by_profile.has(profile_id):
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_PROFILE, "profile %s already registered" % profile_id)
	if _by_slot.has(slot):
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_SLOT, "slot %d already registered" % slot)
	if _by_party.has(context.party):
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_PARTY, "party already registered")
	if device_id >= 0 and _by_device.has(device_id):
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_DEVICE, "device %d already assigned" % device_id)
	_by_run_player[run_player_id] = context
	_by_profile[profile_id] = context
	_by_slot[slot] = context
	_by_party[context.party] = context
	if device_id >= 0:
		_by_device[device_id] = context
		_device_by_run_player[run_player_id] = device_id
	return RunContextRegistrationResult.success()

func context_for(run_player_id: StringName) -> PlayerRunContext:
	return _by_run_player.get(run_player_id) as PlayerRunContext

func all_contexts() -> Array[PlayerRunContext]:
	var result: Array[PlayerRunContext] = []
	for value: Variant in _by_run_player.values():
		result.append(value as PlayerRunContext)
	result.sort_custom(func(left: PlayerRunContext, right: PlayerRunContext) -> bool:
		return left.player_slot_index < right.player_slot_index)
	return result

func lock_arena_roster() -> void:
	_arena_roster_locked = true

func is_arena_roster_locked() -> bool:
	return _arena_roster_locked

func reassign_device(run_player_id: StringName, device_id: int) -> RunContextRegistrationResult:
	if _arena_roster_locked:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.ARENA_RUN_LOCKED, "Arena roster is locked")
	if not _by_run_player.has(run_player_id) or device_id < 0:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.INVALID_CONTEXT, "device reassignment is invalid")
	if _by_device.has(device_id) and _by_device[device_id] != _by_run_player[run_player_id]:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_DEVICE, "device %d already assigned" % device_id)
	var previous_device := int(_device_by_run_player.get(run_player_id, -1))
	if previous_device >= 0:
		_by_device.erase(previous_device)
	_by_device[device_id] = _by_run_player[run_player_id]
	_device_by_run_player[run_player_id] = device_id
	return RunContextRegistrationResult.success()

func device_for(run_player_id: StringName) -> int:
	return int(_device_by_run_player.get(run_player_id, -1))

func clear() -> void:
	_by_run_player.clear()
	_by_profile.clear()
	_by_slot.clear()
	_by_device.clear()
	_by_party.clear()
	_device_by_run_player.clear()
	_arena_roster_locked = false
