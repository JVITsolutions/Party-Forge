class_name AttributeDerivedSourceProjector
extends RefCounted

const SOURCE_TYPE := &"attribute_projection"
const SOURCE_LABEL := "Attribute Projection"

static func project(
	member_id: int,
	raw: ResolvedStatSnapshot,
	tuning: AttributeProjectionTuning,
) -> AttributeProjectionResult:
	if member_id <= 0:
		return AttributeProjectionResult.failure("PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR field=member_id reason=must be positive")
	if raw == null:
		return AttributeProjectionResult.failure("PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR field=raw reason=snapshot is missing")
	if tuning == null:
		return AttributeProjectionResult.failure("PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR field=tuning reason=resource is missing")
	var tuning_errors := tuning.validate()
	if not tuning_errors.is_empty():
		return AttributeProjectionResult.failure(tuning_errors[0])

	var attributes: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		var value := raw.value(attribute_id, NAN)
		if not is_finite(value):
			return AttributeProjectionResult.failure(
				"PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR field=%s reason=attribute must exist and be finite" % attribute_id
			)
		attributes[attribute_id] = value

	var source_id := StringName("attribute_projection_%d" % member_id)
	var modifiers: Array[StatModifier] = []
	_append_modifier(modifiers, source_id, &"melee_damage", StatModifier.Operation.INCREASED, float(attributes[&"strength"]) * tuning.melee_damage_per_strength)
	_append_modifier(modifiers, source_id, &"armor", StatModifier.Operation.FLAT, float(attributes[&"strength"]) * tuning.armor_per_strength)
	_append_modifier(modifiers, source_id, &"ranged_damage", StatModifier.Operation.INCREASED, float(attributes[&"dexterity"]) * tuning.ranged_damage_per_dexterity)
	_append_modifier(modifiers, source_id, &"attack_speed", StatModifier.Operation.INCREASED, float(attributes[&"dexterity"]) * tuning.attack_speed_per_dexterity)
	_append_modifier(modifiers, source_id, &"dodge_chance", StatModifier.Operation.FLAT, float(attributes[&"dexterity"]) * tuning.dodge_per_dexterity)
	_append_modifier(modifiers, source_id, &"max_health", StatModifier.Operation.FLAT, float(attributes[&"constitution"]) * tuning.max_health_per_constitution)
	_append_modifier(modifiers, source_id, &"health_regeneration", StatModifier.Operation.FLAT, float(attributes[&"constitution"]) * tuning.regeneration_per_constitution)
	_append_modifier(modifiers, source_id, &"caster_damage", StatModifier.Operation.INCREASED, float(attributes[&"intelligence"]) * tuning.caster_damage_per_intelligence)
	_append_modifier(modifiers, source_id, &"area_size", StatModifier.Operation.INCREASED, float(attributes[&"intelligence"]) * tuning.area_size_per_intelligence)
	_append_modifier(modifiers, source_id, &"healing_power", StatModifier.Operation.INCREASED, float(attributes[&"wisdom"]) * tuning.healing_power_per_wisdom)
	_append_modifier(modifiers, source_id, &"cooldown_rate", StatModifier.Operation.INCREASED, float(attributes[&"wisdom"]) * tuning.cooldown_rate_per_wisdom)
	_append_modifier(modifiers, source_id, &"party_influence", StatModifier.Operation.FLAT, float(attributes[&"charisma"]) * tuning.party_influence_per_charisma)

	var source := StatModifierSource.create(source_id, SOURCE_TYPE, SOURCE_LABEL, member_id, modifiers)
	var source_error := validate_source(source)
	if not source_error.is_empty():
		return AttributeProjectionResult.failure(source_error)
	return AttributeProjectionResult.success(source)

static func validate_source(source: StatModifierSource) -> String:
	if source == null:
		return "PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR field=source reason=source is missing"
	for modifier: StatModifier in source.modifiers:
		if modifier != null and modifier.stat_id in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
			return "PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR stat=%s reason=derived source cannot target a core attribute" % modifier.stat_id
	return ""

static func _append_modifier(
	modifiers: Array[StatModifier],
	source_id: StringName,
	stat_id: StringName,
	operation: StatModifier.Operation,
	value: float,
) -> void:
	modifiers.append(StatModifier.create(
		stat_id,
		operation,
		value,
		StringName("%s_%s" % [source_id, stat_id]),
		SOURCE_LABEL,
	))
