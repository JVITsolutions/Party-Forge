class_name WeaponBaseDamageRoller
extends RefCounted

static func roll(
	request: ItemGenerationRequest,
	base: EquipmentBaseDefinition,
	rarity: ItemRarityDefinition,
	trace: ItemGenerationTrace
) -> WeaponBaseDamageRollResult:
	if request == null:
		return WeaponBaseDamageRollResult.failed("PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage field=request reason=missing")
	if base == null:
		return WeaponBaseDamageRollResult.failed("PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage field=base reason=missing")
	if rarity == null:
		return WeaponBaseDamageRollResult.failed("PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage field=rarity reason=missing")
	var profile := base.weapon_damage_profile
	var rarity_scale := 0.0
	if profile != null:
		rarity_scale = profile.rarity_multiplier(rarity.id)
	else:
		rarity_scale = float(WeaponDamageProfile.RARITY_MULTIPLIERS.get(rarity.id, 0.0))
	if profile == null:
		var no_profile_provenance := {
			"profile_id": "",
			"item_level": request.item_level,
			"rarity_multiplier": rarity_scale,
			"components": [],
			"outcome": "no_profile",
		}
		if trace != null:
			trace.record(&"base_damage", [], {}, {}, &"", no_profile_provenance)
		return WeaponBaseDamageRollResult.success([], {}, no_profile_provenance)
	if request.item_level < profile.minimum_item_level:
		var level_error := "PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage profile=%s field=item_level value=%d reason=below minimum %d" % [
			profile.id, request.item_level, profile.minimum_item_level,
		]
		if trace != null:
			trace.record(
				&"base_damage",
				[],
				{profile.id: "item_level_below_minimum"},
				{},
				&"",
				{"profile_id": String(profile.id), "item_level": request.item_level, "minimum_item_level": profile.minimum_item_level, "outcome": "rejected"}
			)
		return WeaponBaseDamageRollResult.failed(level_error)
	if not is_finite(rarity_scale) or rarity_scale <= 0.0:
		var rarity_error := "PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage profile=%s field=rarity_id value=%s reason=unsupported rarity" % [profile.id, rarity.id]
		if trace != null:
			trace.record(&"base_damage", [], {profile.id: "unsupported_rarity"}, {}, &"", {
				"profile_id": String(profile.id), "item_level": request.item_level, "rarity_id": String(rarity.id), "outcome": "rejected",
			})
		return WeaponBaseDamageRollResult.failed(rarity_error)

	var curves := profile.components.duplicate()
	curves.sort_custom(func(left: WeaponDamageComponentCurve, right: WeaponDamageComponentCurve) -> bool:
		if left == null:
			return right != null
		if right == null:
			return false
		return String(left.damage_type_id) < String(right.damage_type_id)
	)
	var components: Array[Dictionary] = []
	var quality_by_type: Dictionary = {}
	var component_provenance: Array[Dictionary] = []
	var eligible: Array[StringName] = []
	for curve: WeaponDamageComponentCurve in curves:
		if curve == null:
			return WeaponBaseDamageRollResult.failed("PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage profile=%s field=components reason=contains missing curve" % profile.id)
		var bounds := curve.range_at(request.item_level)
		var unit := ItemDeterministicRandom.unit(
			request.seed,
			request.generation_sequence,
			StringName("base_damage:%s" % curve.damage_type_id),
			0
		)
		var quality := lerpf(profile.quality_minimum, profile.quality_maximum, unit)
		var minimum := snappedf(bounds.x * quality * rarity_scale, 0.01)
		var maximum := snappedf(bounds.y * quality * rarity_scale, 0.01)
		var type_id := String(curve.damage_type_id)
		eligible.append(curve.damage_type_id)
		quality_by_type[type_id] = quality
		components.append({
			"damage_type_id": type_id,
			"minimum_damage": minimum,
			"maximum_damage": maximum,
		})
		component_provenance.append({
			"damage_type_id": type_id,
			"bounds": {"minimum": bounds.x, "maximum": bounds.y},
			"unit": unit,
			"quality": quality,
			"range": {"minimum": minimum, "maximum": maximum},
		})
	var provenance := {
		"profile_id": String(profile.id),
		"item_level": request.item_level,
		"rarity_multiplier": rarity_scale,
		"components": component_provenance,
	}
	if trace != null:
		trace.record(&"base_damage", eligible, {}, {}, profile.id, provenance)
	return WeaponBaseDamageRollResult.success(components, quality_by_type, provenance)
