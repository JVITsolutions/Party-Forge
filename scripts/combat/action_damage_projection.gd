class_name ActionDamageProjection
extends RefCounted

static func normal_component(base_amount: float, global_multiplier: float, archetype_multiplier: float, type_multiplier: float) -> float:
	var inputs: Array[float] = [base_amount, global_multiplier, archetype_multiplier, type_multiplier]
	for value: float in inputs:
		if not is_finite(value) or value < 0.0:
			return NAN
	var result := base_amount * global_multiplier * archetype_multiplier * type_multiplier
	return result if is_finite(result) else NAN
