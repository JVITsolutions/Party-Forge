class_name EquipmentTransitionResult
extends RefCounted

var error := "PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR reason=invalid request"
var _state: ItemOwnershipState
var _activation: EquipmentActivationResult
var _resolution: MemberStatResolution

static func success(
	state_value: ItemOwnershipState,
	activation_value: EquipmentActivationResult,
	resolution_value: MemberStatResolution,
) -> EquipmentTransitionResult:
	var result := EquipmentTransitionResult.new()
	result.error = ""
	result._state = state_value.copy() if state_value != null else null
	result._activation = activation_value.copy() if activation_value != null else null
	result._resolution = resolution_value
	return result

static func failure(message: String) -> EquipmentTransitionResult:
	var result := EquipmentTransitionResult.new()
	result.error = message
	return result

func ok() -> bool:
	if not error.is_empty() or _state == null or _activation == null or not _activation.ok() or _resolution == null or not _resolution.ok():
		return false
	var weapon := _activation.weapon_snapshot()
	return weapon == null or weapon.revision == _resolution.final_stats.revision

func state() -> ItemOwnershipState:
	return _state.copy() if _state != null else null

func activation() -> EquipmentActivationResult:
	return _activation.copy() if _activation != null else null

func resolution() -> MemberStatResolution:
	return _resolution
