class_name ItemBaseDamageComponent
extends RefCounted

var damage_type_id: StringName
var minimum_damage := 0.0
var maximum_damage := 0.0

static func create(type_id: StringName, minimum: float, maximum: float) -> ItemBaseDamageComponent:
	var result := ItemBaseDamageComponent.new()
	result.damage_type_id = type_id
	result.minimum_damage = minimum
	result.maximum_damage = maximum
	return result

func copy() -> ItemBaseDamageComponent:
	return create(damage_type_id, minimum_damage, maximum_damage)

func to_dictionary() -> Dictionary:
	return {
		"damage_type_id": String(damage_type_id),
		"minimum_damage": minimum_damage,
		"maximum_damage": maximum_damage,
	}

func validate(damage_types: DamageTypeCatalog) -> String:
	if damage_type_id.is_empty():
		return _error("damage_type_id", "must be a non-empty string")
	if damage_types == null:
		return _error("damage_type_id", "damage type catalog is missing")
	if damage_types.definition(damage_type_id) == null:
		return _error("damage_type_id", "unknown damage type %s" % damage_type_id)
	if not is_finite(minimum_damage):
		return _error("minimum_damage", "must be a finite number")
	if minimum_damage < 0.0:
		return _error("minimum_damage", "must be non-negative")
	if not is_finite(maximum_damage):
		return _error("maximum_damage", "must be a finite number")
	if maximum_damage < 0.0:
		return _error("maximum_damage", "must be non-negative")
	if minimum_damage > maximum_damage:
		return _error("minimum_damage", "must be less than or equal to maximum_damage")
	return ""

static func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_ITEM_BASE_DAMAGE_ERROR field=%s reason=%s" % [field, reason]
