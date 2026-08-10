class_name WeaponBaseDamageRoller
extends RefCounted

static func roll(
	request: ItemGenerationRequest,
	base: EquipmentBaseDefinition,
	rarity: ItemRarityDefinition,
	trace: ItemGenerationTrace
) -> WeaponBaseDamageRollResult:
	if request == null:
		return _reject_input(trace, "request")
	if base == null:
		return _reject_input(trace, "base")
	if rarity == null:
		return _reject_input(trace, "rarity")
	if trace == null:
		return WeaponBaseDamageRollResult.failed("PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage field=trace reason=missing")

	var profile := base.weapon_damage_profile
	if profile != null:
		var profile_problem := _profile_error(profile)
		if not profile_problem.is_empty():
			return _reject(
				trace,
				_profile_label(profile),
				"invalid_profile",
				String(profile.id),
				String(profile_problem["field"]),
				String(profile_problem["reason"]),
				{},
				true
			)

	var rarity_scale := float(WeaponDamageProfile.RARITY_MULTIPLIERS.get(rarity.id, 0.0))
	if not is_finite(rarity_scale) or rarity_scale <= 0.0:
		return _reject(
			trace,
			_profile_label(profile) if profile != null else "<none>",
			"unsupported_rarity",
			String(profile.id) if profile != null else "",
			"rarity_id",
			"unsupported rarity",
			{"value": String(rarity.id)},
			profile != null
		)

	if profile == null:
		var no_profile_provenance := ItemGenerationTrace.canonical_json_copy({
			"profile_id": "",
			"item_level": request.item_level,
			"rarity_multiplier": rarity_scale,
			"components": [],
			"outcome": "no_profile",
		}) as Dictionary
		trace.record(&"base_damage", [], {}, {}, &"", no_profile_provenance)
		return WeaponBaseDamageRollResult.success([], {}, no_profile_provenance)

	if request.item_level < profile.minimum_item_level:
		var level_error := "PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage profile=%s field=item_level value=%d reason=below minimum %d" % [
			profile.id, request.item_level, profile.minimum_item_level,
		]
		trace.record(
			&"base_damage",
			[],
			{profile.id: "item_level_below_minimum"},
			{},
			&"",
			{"profile_id": String(profile.id), "item_level": request.item_level, "minimum_item_level": profile.minimum_item_level, "outcome": "rejected"}
		)
		return WeaponBaseDamageRollResult.failed(level_error)

	var curves := profile.components.duplicate()
	curves.sort_custom(func(left: WeaponDamageComponentCurve, right: WeaponDamageComponentCurve) -> bool:
		return String(left.damage_type_id) < String(right.damage_type_id)
	)
	var components: Array[Dictionary] = []
	var quality_by_type: Dictionary = {}
	var component_provenance: Array[Dictionary] = []
	var eligible: Array[StringName] = []
	for curve: WeaponDamageComponentCurve in curves:
		var type_id := String(curve.damage_type_id)
		var bounds := curve.range_at(request.item_level)
		if not _valid_range(bounds.x, bounds.y):
			return _reject_roll(trace, profile, "components.%s.bounds" % type_id)
		var unit := ItemDeterministicRandom.unit(
			request.seed,
			request.generation_sequence,
			StringName("base_damage:%s" % curve.damage_type_id),
			0
		)
		if not is_finite(unit) or unit < 0.0 or unit >= 1.0:
			return _reject_roll(trace, profile, "components.%s.unit" % type_id)
		var quality := lerpf(profile.quality_minimum, profile.quality_maximum, unit)
		if not is_finite(quality) or quality < profile.quality_minimum or quality > profile.quality_maximum:
			return _reject_roll(trace, profile, "components.%s.quality" % type_id)
		var minimum := snappedf(bounds.x * quality * rarity_scale, 0.01)
		var maximum := snappedf(bounds.y * quality * rarity_scale, 0.01)
		if not _valid_range(minimum, maximum):
			return _reject_roll(trace, profile, "components.%s.final_range" % type_id)
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
	var provenance_source := {
		"profile_id": String(profile.id),
		"item_level": request.item_level,
		"rarity_multiplier": rarity_scale,
		"components": component_provenance,
	}
	if not ItemGenerationTrace.json_value_error(provenance_source).is_empty():
		return _reject_roll(trace, profile, "provenance", "must be JSON-safe")
	var provenance := ItemGenerationTrace.canonical_json_copy(provenance_source) as Dictionary
	trace.record(&"base_damage", eligible, {}, {}, profile.id, provenance)
	return WeaponBaseDamageRollResult.success(components, quality_by_type, provenance)

static func _profile_error(profile: WeaponDamageProfile) -> Dictionary:
	if profile.id.is_empty():
		return {"field": "profile.id", "reason": "must be non-empty"}
	if profile.minimum_item_level < 1 or profile.minimum_item_level > 1000:
		return {"field": "minimum_item_level", "reason": "must be between 1 and 1000"}
	if (
		not is_finite(profile.quality_minimum)
		or not is_finite(profile.quality_maximum)
		or profile.quality_minimum != 0.85
		or profile.quality_maximum != 1.00
	):
		return {"field": "quality_bounds", "reason": "must equal 0.85..1.00"}
	if profile.components.is_empty():
		return {"field": "components", "reason": "requires at least one component"}
	var seen_types: Dictionary = {}
	for index: int in profile.components.size():
		var curve := profile.components[index]
		if curve == null:
			return {"field": "components[%d]" % index, "reason": "curve is missing"}
		var type_id := curve.damage_type_id
		var type_field := "components[%d].damage_type_id" % index
		if type_id.is_empty():
			return {"field": type_field, "reason": "must be non-empty"}
		if seen_types.has(type_id):
			return {"field": type_field, "reason": "duplicate damage type %s" % type_id}
		seen_types[type_id] = true
		if GameCatalog.DAMAGE_TYPES.definition(type_id) == null:
			return {"field": type_field, "reason": "unknown damage type %s" % type_id}
		var anchors := [
			{"field": "minimum_at_level_1", "value": curve.minimum_at_level_1},
			{"field": "maximum_at_level_1", "value": curve.maximum_at_level_1},
			{"field": "minimum_at_level_1000", "value": curve.minimum_at_level_1000},
			{"field": "maximum_at_level_1000", "value": curve.maximum_at_level_1000},
		]
		for anchor: Dictionary in anchors:
			var anchor_field := "components[%d].%s" % [index, anchor["field"]]
			var anchor_value := float(anchor["value"])
			if not is_finite(anchor_value):
				return {"field": anchor_field, "reason": "must be finite"}
			if anchor_value < 0.0:
				return {"field": anchor_field, "reason": "must be nonnegative"}
		if curve.minimum_at_level_1 > curve.maximum_at_level_1:
			return {"field": "components[%d].maximum_at_level_1" % index, "reason": "level 1 range is inverted"}
		if curve.minimum_at_level_1000 > curve.maximum_at_level_1000:
			return {"field": "components[%d].maximum_at_level_1000" % index, "reason": "level 1000 range is inverted"}
		if curve.minimum_at_level_1000 < curve.minimum_at_level_1:
			return {"field": "components[%d].minimum_at_level_1000" % index, "reason": "minimum anchors must be monotonic"}
		if curve.maximum_at_level_1000 < curve.maximum_at_level_1:
			return {"field": "components[%d].maximum_at_level_1000" % index, "reason": "maximum anchors must be monotonic"}
	return {}

static func _valid_range(minimum: float, maximum: float) -> bool:
	return is_finite(minimum) and is_finite(maximum) and minimum >= 0.0 and maximum >= minimum

static func _profile_label(profile: WeaponDamageProfile) -> String:
	return String(profile.id) if not profile.id.is_empty() else "<empty>"

static func _reject_input(trace: ItemGenerationTrace, field: String) -> WeaponBaseDamageRollResult:
	if trace != null:
		trace.record(&"base_damage", [], {"<%s>" % field: "missing_%s" % field}, {}, &"", {
			"field": field, "outcome": "rejected", "profile_id": "", "reason": "missing",
		})
	return WeaponBaseDamageRollResult.failed("PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage field=%s reason=missing" % field)

static func _reject_roll(
	trace: ItemGenerationTrace,
	profile: WeaponDamageProfile,
	field: String,
	reason: String = "must be finite nonnegative and ordered"
) -> WeaponBaseDamageRollResult:
	return _reject(trace, _profile_label(profile), "invalid_roll", String(profile.id), field, reason, {}, true)

static func _reject(
	trace: ItemGenerationTrace,
	rejected_id: String,
	rejected_code: String,
	profile_id: String,
	field: String,
	reason: String,
	extra_details: Dictionary,
	include_profile_in_error: bool
) -> WeaponBaseDamageRollResult:
	var details := {"field": field, "outcome": "rejected", "profile_id": profile_id, "reason": reason}
	for key: Variant in extra_details:
		details[key] = extra_details[key]
	trace.record(&"base_damage", [], {rejected_id: rejected_code}, {}, &"", details)
	var profile_fragment := " profile=%s" % rejected_id if include_profile_in_error else ""
	var value_fragment := " value=%s" % extra_details["value"] if extra_details.has("value") else ""
	return WeaponBaseDamageRollResult.failed(
		"PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage%s field=%s%s reason=%s" % [profile_fragment, field, value_fragment, reason]
	)
