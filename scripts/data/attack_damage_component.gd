class_name AttackDamageComponent
extends Resource

@export var damage_type_id: StringName
@export var base_amount := 0.0

func validate(attack_id: StringName, types: DamageTypeCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if damage_type_id.is_empty():
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s type=<empty> reason=missing component type" % attack_id)
	elif types == null or types.definition(damage_type_id) == null:
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s type=%s reason=unknown component type" % [attack_id, damage_type_id])
	if not is_finite(base_amount) or base_amount <= 0.0:
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s type=%s reason=component amount must be finite and positive" % [attack_id, damage_type_id])
	return errors
