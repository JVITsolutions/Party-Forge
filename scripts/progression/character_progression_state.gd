class_name CharacterProgressionState
extends RefCounted

const SNAPSHOT_VERSION := 1
const SNAPSHOT_KEYS: Array[String] = [
	"version",
	"member_id",
	"level",
	"experience",
	"experience_required",
	"fractional_experience",
	"core_attribute_gains",
	"guaranteed_growth_history",
	"milestone_outcomes",
]

var member_id := 0
var level := 1
var experience := 0
var experience_required := 1
var fractional_experience := 0.0
var core_attribute_gains: Dictionary = {}
var guaranteed_growth_history: Array[StringName] = []
var milestone_outcomes: Dictionary = {}

static func fresh(id: int, tuning: ExperienceTuning) -> CharacterProgressionState:
	if id <= 0 or tuning == null or not tuning.validate().is_empty():
		return null
	var state := CharacterProgressionState.new()
	state.member_id = id
	state.experience_required = tuning.requirement_for_level(1)
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		state.core_attribute_gains[attribute_id] = 0
	return state

func copy() -> CharacterProgressionState:
	var result := CharacterProgressionState.new()
	result.member_id = member_id
	result.level = level
	result.experience = experience
	result.experience_required = experience_required
	result.fractional_experience = fractional_experience
	result.core_attribute_gains = core_attribute_gains.duplicate(true)
	result.guaranteed_growth_history = guaranteed_growth_history.duplicate()
	result.milestone_outcomes = milestone_outcomes.duplicate(true)
	return result

func to_snapshot() -> Dictionary:
	var history: Array[String] = []
	for attribute_id: StringName in guaranteed_growth_history:
		history.append(String(attribute_id))
	var milestones: Dictionary = {}
	for milestone_level: Variant in milestone_outcomes:
		milestones[str(int(milestone_level))] = String(milestone_outcomes[milestone_level])
	var attributes: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		attributes[String(attribute_id)] = int(core_attribute_gains.get(attribute_id, 0))
	return {
		"version": SNAPSHOT_VERSION,
		"member_id": member_id,
		"level": level,
		"experience": experience,
		"experience_required": experience_required,
		"fractional_experience": fractional_experience,
		"core_attribute_gains": attributes,
		"guaranteed_growth_history": history,
		"milestone_outcomes": milestones,
	}

static func from_snapshot(snapshot: Dictionary, tuning: ExperienceTuning) -> CharacterProgressionState:
	if tuning == null or not tuning.validate().is_empty() or snapshot.size() != SNAPSHOT_KEYS.size():
		return null
	for key: String in SNAPSHOT_KEYS:
		if not snapshot.has(key):
			return null
	if (
		typeof(snapshot["version"]) != TYPE_INT
		or typeof(snapshot["member_id"]) != TYPE_INT
		or typeof(snapshot["level"]) != TYPE_INT
		or typeof(snapshot["experience"]) != TYPE_INT
		or typeof(snapshot["experience_required"]) != TYPE_INT
		or typeof(snapshot["fractional_experience"]) != TYPE_FLOAT
		or typeof(snapshot["core_attribute_gains"]) != TYPE_DICTIONARY
		or typeof(snapshot["guaranteed_growth_history"]) != TYPE_ARRAY
		or typeof(snapshot["milestone_outcomes"]) != TYPE_DICTIONARY
	):
		return null
	if int(snapshot["version"]) != SNAPSHOT_VERSION or int(snapshot["member_id"]) <= 0:
		return null
	var stored_level := int(snapshot["level"])
	if stored_level < 1:
		return null
	var required := tuning.requirement_for_level(stored_level)
	var stored_experience := int(snapshot["experience"])
	if stored_experience < 0 or stored_experience >= required or int(snapshot["experience_required"]) != required:
		return null
	var stored_fraction := float(snapshot["fractional_experience"])
	if not is_finite(stored_fraction) or stored_fraction < 0.0 or stored_fraction >= 1.0:
		return null

	var attributes := snapshot["core_attribute_gains"] as Dictionary
	if attributes.size() != ClassGrowthDefinition.CORE_ATTRIBUTE_IDS.size():
		return null
	var restored_attributes: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		var key := String(attribute_id)
		if not attributes.has(key) or typeof(attributes[key]) != TYPE_INT or int(attributes[key]) < 0:
			return null
		restored_attributes[attribute_id] = int(attributes[key])
	for key: Variant in attributes:
		if typeof(key) != TYPE_STRING or StringName(key) not in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
			return null

	var restored_history: Array[StringName] = []
	for value: Variant in snapshot["guaranteed_growth_history"] as Array:
		if typeof(value) != TYPE_STRING:
			return null
		var attribute_id := StringName(value)
		if attribute_id not in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
			return null
		restored_history.append(attribute_id)

	var restored_milestones: Dictionary = {}
	for key: Variant in snapshot["milestone_outcomes"] as Dictionary:
		if typeof(key) != TYPE_STRING or not String(key).is_valid_int():
			return null
		var milestone_level := int(String(key))
		if milestone_level <= 0 or milestone_level % 5 != 0 or str(milestone_level) != String(key):
			return null
		var value: Variant = snapshot["milestone_outcomes"][key]
		if typeof(value) != TYPE_STRING:
			return null
		var attribute_id := StringName(value)
		if attribute_id not in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
			return null
		restored_milestones[milestone_level] = attribute_id

	var result := CharacterProgressionState.new()
	result.member_id = int(snapshot["member_id"])
	result.level = stored_level
	result.experience = stored_experience
	result.experience_required = required
	result.fractional_experience = stored_fraction
	result.core_attribute_gains = restored_attributes
	result.guaranteed_growth_history = restored_history
	result.milestone_outcomes = restored_milestones
	return result
