class_name EquipmentAssignmentResult
extends RefCounted

var error := "PARTY_FORGE_EQUIPMENT_ASSIGNMENT_ERROR reason=invalid request"
var _state: ItemOwnershipState

static func success(state_value: ItemOwnershipState) -> EquipmentAssignmentResult:
	var result := EquipmentAssignmentResult.new()
	result.error = ""
	result._state = state_value.copy() if state_value != null else null
	return result

static func failure(error_value: String) -> EquipmentAssignmentResult:
	var result := EquipmentAssignmentResult.new()
	result.error = error_value
	return result

func ok() -> bool:
	return error.is_empty() and _state != null

func state() -> ItemOwnershipState:
	return _state.copy() if _state != null else null
