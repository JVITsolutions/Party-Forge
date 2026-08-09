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
	return error.is_empty() and _state != null and _activation != null and _activation.ok() and _resolution != null and _resolution.ok()

func state() -> ItemOwnershipState:
	return _state.copy() if _state != null else null

func activation() -> EquipmentActivationResult:
	return _activation.copy() if _activation != null else null

func resolution() -> MemberStatResolution:
	return _resolution
