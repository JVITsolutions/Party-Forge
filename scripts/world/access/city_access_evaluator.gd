class_name CityAccessEvaluator
extends RefCounted

const AccessProjection := preload("res://scripts/world/access/city_access_projection.gd")

const REASON_VISIBLE := &"visible"
const REASON_VISIBILITY_CONDITIONS_FAILED := &"visibility_conditions_failed"
const REASON_AVAILABILITY_CONDITIONS_FAILED := &"availability_conditions_failed"
const REASON_UNKNOWN_LOCATION := &"unknown_location"
const REASON_INVALID_INPUT := &"invalid_input"


static func evaluate(snapshot: Variant, profile: Variant, location_id: Variant) -> Variant:
	var safe_location_id: StringName = location_id as StringName if typeof(location_id) == TYPE_STRING_NAME else &""
	if snapshot == null or profile == null or typeof(location_id) != TYPE_STRING_NAME or safe_location_id.is_empty() or not snapshot is CityAccessSnapshot or not profile is ProfileState:
		return AccessProjection.new(safe_location_id, AccessProjection.State.HIDDEN, REASON_INVALID_INPUT, &"", "city access evaluator received invalid input")
	var profile_state := profile as ProfileState
	if not _is_valid_prologue_state(profile_state.prologue_state):
		return AccessProjection.new(safe_location_id, AccessProjection.State.HIDDEN, REASON_INVALID_INPUT, &"", "city access evaluator received invalid profile prologue state")
	var location := _location(snapshot as CityAccessSnapshot, safe_location_id)
	if location == null:
		return AccessProjection.new(safe_location_id, AccessProjection.State.HIDDEN, REASON_UNKNOWN_LOCATION, &"", "city access location is unknown")
	var context := {
		"prologue_state": _prologue_state(profile_state.prologue_state),
		"permanent_unlocks": _id_set(profile_state.permanent_feature_unlocks),
		"discovered_buildings": _id_set(profile_state.discovered_buildings),
		"discovered_trees": _id_set(profile_state.discovered_trees),
	}
	if not _all_conditions_pass(location.visible_when, context):
		return AccessProjection.new(location.id, AccessProjection.State.HIDDEN, REASON_VISIBILITY_CONDITIONS_FAILED, &"", "city access visibility conditions failed")
	if not _all_conditions_pass(location.available_when, context):
		return AccessProjection.new(location.id, AccessProjection.State.LOCKED, REASON_AVAILABILITY_CONDITIONS_FAILED, &"", "city access availability conditions failed")
	return AccessProjection.new(location.id, AccessProjection.State.AVAILABLE, REASON_VISIBLE, location.destination_id)


static func _location(snapshot: CityAccessSnapshot, location_id: StringName) -> CityAccessLocation:
	for location: CityAccessLocation in snapshot.locations:
		if location.id == location_id:
			return location
	return null


static func _all_conditions_pass(conditions: Array[CityAccessCondition], context: Dictionary) -> bool:
	for condition: CityAccessCondition in conditions:
		if not _condition_passes(condition, context):
			return false
	return true


static func _condition_passes(condition: CityAccessCondition, context: Dictionary) -> bool:
	match condition.kind:
		&"always":
			return true
		&"prologue_state":
			return context["prologue_state"] == StringName(condition.value)
		&"permanent_unlock":
			return (context["permanent_unlocks"] as Dictionary).has(StringName(condition.value))
		&"discovered_building":
			return (context["discovered_buildings"] as Dictionary).has(StringName(condition.value))
		&"discovered_tree":
			return (context["discovered_trees"] as Dictionary).has(StringName(condition.value))
	return false


static func _prologue_state(value: int) -> StringName:
	match value:
		ProfileState.PrologueState.NOT_STARTED:
			return &"not_started"
		ProfileState.PrologueState.IN_PROGRESS:
			return &"in_progress"
		ProfileState.PrologueState.COMPLETED:
			return &"completed"
	return &""


static func _is_valid_prologue_state(value: int) -> bool:
	return value in [ProfileState.PrologueState.NOT_STARTED, ProfileState.PrologueState.IN_PROGRESS, ProfileState.PrologueState.COMPLETED]


static func _id_set(values: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for value: String in values.duplicate():
		result[StringName(value)] = true
	return result
