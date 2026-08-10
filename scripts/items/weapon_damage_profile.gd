class_name WeaponDamageProfile
extends Resource

const RARITY_MULTIPLIERS := {
	&"common": 1.00, &"uncommon": 1.08, &"rare": 1.18,
	&"epic": 1.32, &"legendary": 1.50,
}

@export var id: StringName
@export_range(1, 1000, 1) var minimum_item_level := 1
@export var quality_minimum := 0.85
@export var quality_maximum := 1.00
@export var components: Array[WeaponDamageComponentCurve] = []

func rarity_multiplier(rarity_id: StringName) -> float:
	return float(RARITY_MULTIPLIERS.get(rarity_id, 0.0))

func validate(damage_types: DamageTypeCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append(_error("reason=id is empty"))
	if minimum_item_level < 1 or minimum_item_level > 1000:
		errors.append(_error("field=minimum_item_level reason=must be between 1 and 1000"))
	if quality_minimum != 0.85 or quality_maximum != 1.00:
		errors.append(_error("reason=quality bounds must be exactly 0.85..1.00"))
	if components.is_empty():
		errors.append(_error("reason=requires at least one component"))
	var seen_types: Dictionary = {}
	for index: int in components.size():
		var component := components[index]
		if component == null:
			errors.append(_error("component=%d type=<null> reason=component is missing" % index))
			continue
		var type_id := component.damage_type_id
		var component_prefix := "component=%d type=%s" % [index, type_id if not type_id.is_empty() else "<empty>"]
		if type_id.is_empty():
			errors.append(_error("%s reason=damage type id is empty" % component_prefix))
		elif seen_types.has(type_id):
			errors.append(_error("%s reason=duplicate damage type %s" % [component_prefix, type_id]))
		else:
			seen_types[type_id] = true
		if damage_types == null:
			errors.append(_error("%s reason=damage type catalog is missing" % component_prefix))
		elif not type_id.is_empty() and damage_types.definition(type_id) == null:
			errors.append(_error("%s reason=unknown damage type %s" % [component_prefix, type_id]))
		_validate_component_anchors(component, component_prefix, errors)
	return errors

func _validate_component_anchors(component: WeaponDamageComponentCurve, prefix: String, errors: PackedStringArray) -> void:
	var anchors := {
		"minimum_at_level_1": component.minimum_at_level_1,
		"maximum_at_level_1": component.maximum_at_level_1,
		"minimum_at_level_1000": component.minimum_at_level_1000,
		"maximum_at_level_1000": component.maximum_at_level_1000,
	}
	for field: String in anchors:
		var value := float(anchors[field])
		if not is_finite(value):
			errors.append(_error("%s reason=%s must be finite" % [prefix, field]))
		elif value < 0.0:
			errors.append(_error("%s reason=%s must be non-negative" % [prefix, field]))
	if not _finite_anchors(component):
		return
	if component.minimum_at_level_1 > component.maximum_at_level_1:
		errors.append(_error("%s reason=level 1 range is inverted" % prefix))
	if component.minimum_at_level_1000 > component.maximum_at_level_1000:
		errors.append(_error("%s reason=level 1000 range is inverted" % prefix))
	if component.minimum_at_level_1000 < component.minimum_at_level_1:
		errors.append(_error("%s reason=minimum anchors must be monotonic" % prefix))
	if component.maximum_at_level_1000 < component.maximum_at_level_1:
		errors.append(_error("%s reason=maximum anchors must be monotonic" % prefix))

func _finite_anchors(component: WeaponDamageComponentCurve) -> bool:
	return (
		is_finite(component.minimum_at_level_1)
		and is_finite(component.maximum_at_level_1)
		and is_finite(component.minimum_at_level_1000)
		and is_finite(component.maximum_at_level_1000)
	)

func _error(detail: String) -> String:
	return "PARTY_FORGE_WEAPON_DAMAGE_PROFILE_ERROR profile=%s %s" % [id if not id.is_empty() else "<empty>", detail]
