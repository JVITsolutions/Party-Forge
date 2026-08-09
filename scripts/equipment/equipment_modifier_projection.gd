class_name EquipmentModifierProjection
extends RefCounted

var error: String
var source: StatModifierSource

static func success(source_value: StatModifierSource) -> EquipmentModifierProjection:
	var result := EquipmentModifierProjection.new()
	result.source = source_value
	return result

static func failure(error_value: String) -> EquipmentModifierProjection:
	var result := EquipmentModifierProjection.new()
	result.error = error_value
	return result

func ok() -> bool:
	return error.is_empty() and source != null
