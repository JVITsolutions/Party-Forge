class_name WeaponBaseDamageRollResult
extends RefCounted

var components: Array[Dictionary] = []
var quality_by_type: Dictionary = {}
var provenance: Dictionary = {}
var error: String

func ok() -> bool:
	return error.is_empty()

static func success(
	component_values: Array[Dictionary],
	quality_values: Dictionary,
	provenance_value: Dictionary
) -> WeaponBaseDamageRollResult:
	var result := WeaponBaseDamageRollResult.new()
	result.components = component_values.duplicate(true)
	result.quality_by_type = quality_values.duplicate(true)
	result.provenance = provenance_value.duplicate(true)
	return result

static func failed(error_value: String) -> WeaponBaseDamageRollResult:
	var result := WeaponBaseDamageRollResult.new()
	result.error = error_value
	return result
