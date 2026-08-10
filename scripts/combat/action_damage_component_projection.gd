class_name ActionDamageComponentProjection
extends RefCounted

static func resolve(attack: AttackDefinition, weapon: ActiveWeaponDamageSnapshot = null) -> Dictionary:
	if attack == null:
		return _failure("attack=<null> reason=missing attack")
	if not is_finite(attack.weapon_damage_effectiveness) or attack.weapon_damage_effectiveness < 0.0:
		return _failure("attack=%s reason=weapon damage effectiveness must be finite and nonnegative" % attack.id)
	if attack.damage_source == AttackDefinition.DamageSource.ACTIVE_WEAPON and weapon != null and not weapon.components.is_empty():
		return _weapon_components(attack, weapon)
	return _authored_components(attack, attack.damage_source == AttackDefinition.DamageSource.ACTIVE_WEAPON)

static func _weapon_components(attack: AttackDefinition, weapon: ActiveWeaponDamageSnapshot) -> Dictionary:
	var components: Array[ItemBaseDamageComponent] = []
	var seen: Dictionary = {}
	for component: ItemBaseDamageComponent in weapon.components:
		if component == null:
			return _failure("attack=%s type=<null> reason=null weapon damage component" % attack.id)
		if component.damage_type_id.is_empty():
			return _failure("attack=%s type=<empty> reason=missing weapon damage type" % attack.id)
		if seen.has(component.damage_type_id):
			return _failure("attack=%s type=%s reason=duplicate weapon damage type" % [attack.id, component.damage_type_id])
		seen[component.damage_type_id] = true
		var minimum := component.minimum_damage * attack.weapon_damage_effectiveness
		var maximum := component.maximum_damage * attack.weapon_damage_effectiveness
		if not is_finite(minimum) or not is_finite(maximum) or minimum < 0.0 or maximum < minimum:
			return _failure("attack=%s type=%s reason=invalid projected weapon damage range" % [attack.id, component.damage_type_id])
		components.append(ItemBaseDamageComponent.create(component.damage_type_id, minimum, maximum))
	components.sort_custom(func(left: ItemBaseDamageComponent, right: ItemBaseDamageComponent) -> bool:
		return String(left.damage_type_id) < String(right.damage_type_id)
	)
	return {"error": "", "used_fallback": false, "components": components}

static func _authored_components(attack: AttackDefinition, used_fallback: bool) -> Dictionary:
	var components: Array[ItemBaseDamageComponent] = []
	for component: AttackDamageComponent in attack.damage_components:
		if component == null:
			return _failure("attack=%s type=<null> reason=null authored damage component" % attack.id)
		components.append(ItemBaseDamageComponent.create(component.damage_type_id, component.base_amount, component.base_amount))
	components.sort_custom(func(left: ItemBaseDamageComponent, right: ItemBaseDamageComponent) -> bool:
		return String(left.damage_type_id) < String(right.damage_type_id)
	)
	return {"error": "", "used_fallback": used_fallback, "components": components}

static func _failure(detail: String) -> Dictionary:
	return {"error": "PARTY_FORGE_DAMAGE_ERROR %s" % detail, "used_fallback": false, "components": [] as Array[ItemBaseDamageComponent]}
