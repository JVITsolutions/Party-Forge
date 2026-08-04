class_name ClassGrowthDefinition
extends Resource

const CORE_ATTRIBUTE_IDS: Array[StringName] = [
	&"strength", &"dexterity", &"constitution",
	&"intelligence", &"wisdom", &"charisma",
]

@export var guaranteed_cycle: Array[StringName] = []
@export var milestone_weights: Dictionary = {}

func guaranteed_attribute_for_level(level: int) -> StringName:
	if guaranteed_cycle.is_empty() or level < 2:
		return &""
	return guaranteed_cycle[(level - 2) % guaranteed_cycle.size()]

func milestone_attribute_for_roll(unit_roll: float) -> StringName:
	var ids: Array[StringName] = []
	var total := 0.0
	for attribute_id: StringName in CORE_ATTRIBUTE_IDS:
		var weight := maxf(float(milestone_weights.get(attribute_id, 0.0)), 0.0)
		if weight <= 0.0:
			continue
		ids.append(attribute_id)
		total += weight
	if total <= 0.0:
		return &""
	var cursor := clampf(unit_roll, 0.0, 0.999999999) * total
	for attribute_id: StringName in ids:
		cursor -= float(milestone_weights[attribute_id])
		if cursor < 0.0:
			return attribute_id
	return ids.back()

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if guaranteed_cycle.is_empty():
		errors.append("PARTY_FORGE_GROWTH_ERROR field=guaranteed_cycle reason=empty")
	for attribute_id: StringName in guaranteed_cycle:
		if attribute_id not in CORE_ATTRIBUTE_IDS:
			errors.append("PARTY_FORGE_GROWTH_ERROR field=guaranteed_cycle value=%s reason=unknown core attribute" % attribute_id)
	var positive_weight_count := 0
	for key: Variant in milestone_weights:
		var attribute_id := StringName(key)
		var weight := float(milestone_weights[key])
		if attribute_id not in CORE_ATTRIBUTE_IDS:
			errors.append("PARTY_FORGE_GROWTH_ERROR field=milestone_weights value=%s reason=unknown core attribute" % attribute_id)
		elif not is_finite(weight) or weight < 0.0:
			errors.append("PARTY_FORGE_GROWTH_ERROR field=milestone_weights value=%s reason=invalid weight" % attribute_id)
		elif weight > 0.0:
			positive_weight_count += 1
	if positive_weight_count == 0:
		errors.append("PARTY_FORGE_GROWTH_ERROR field=milestone_weights reason=no positive weights")
	return errors
