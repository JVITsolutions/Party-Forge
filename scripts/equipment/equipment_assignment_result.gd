class_name EquipmentAssignmentResult
extends RefCounted

var error := "PARTY_FORGE_EQUIPMENT_ASSIGNMENT_ERROR reason=invalid request"
var _state: ItemOwnershipState
var _newly_equipped_item_ids: Array[String] = []

static func success(state_value: ItemOwnershipState, newly_equipped_item_ids_value: Array[String] = []) -> EquipmentAssignmentResult:
	var result := EquipmentAssignmentResult.new()
	result.error = ""
	result._state = state_value.copy() if state_value != null else null
	result._newly_equipped_item_ids = newly_equipped_item_ids_value.duplicate()
	return result

static func failure(error_value: String) -> EquipmentAssignmentResult:
	var result := EquipmentAssignmentResult.new()
	result.error = error_value
	return result

func ok() -> bool:
	return error.is_empty() and _state != null

func state() -> ItemOwnershipState:
	return _state.copy() if _state != null else null

func newly_equipped_item_ids() -> Array[String]:
	return _newly_equipped_item_ids.duplicate()
