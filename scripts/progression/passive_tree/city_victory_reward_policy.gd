class_name CityVictoryRewardPolicy
extends RefCounted

const CITY_TREE_ID := "party-forge-city-v1"
const CITY_ROOT_ID := "city-heart"
const ERROR_PREFIX := "PARTY_FORGE_CITY_VICTORY_REWARD_ERROR"

static func apply(candidate: ProfileState, outcome: RunTerminalSnapshot.Outcome) -> String:
	if candidate == null:
		return _error("profile", "must not be null")
	if outcome == RunTerminalSnapshot.Outcome.DEFEAT:
		return ""
	if outcome != RunTerminalSnapshot.Outcome.VICTORY:
		return _error("outcome", "must be victory or defeat")
	if candidate.passive_points_available < 0 or candidate.passive_points_lifetime_earned < candidate.passive_points_available:
		return _error("passive_points", "current values are invalid")
	if (
		candidate.passive_points_available >= ProfileCodec.JSON_SAFE_INTEGER_MAX
		or candidate.passive_points_lifetime_earned >= ProfileCodec.JSON_SAFE_INTEGER_MAX
	):
		return _error("passive_points", "overflow")

	var allocation_value: Variant = candidate.tree_allocations.get(CITY_TREE_ID, [])
	if not allocation_value is Array:
		return _error("tree_allocations", "City allocation must be an array")
	var city_allocations: Array[String] = []
	for value: Variant in allocation_value as Array:
		if typeof(value) != TYPE_STRING or String(value).strip_edges().is_empty():
			return _error("tree_allocations", "City allocation must contain non-empty strings")
		var node_id := String(value)
		if node_id not in city_allocations:
			city_allocations.append(node_id)
	if CITY_ROOT_ID not in city_allocations:
		city_allocations.append(CITY_ROOT_ID)
	city_allocations.sort()

	var discoveries: Array[String] = []
	for tree_id: String in candidate.discovered_trees:
		if tree_id.strip_edges().is_empty():
			return _error("discovered_trees", "must contain non-empty strings")
		if tree_id not in discoveries:
			discoveries.append(tree_id)
	if CITY_TREE_ID not in discoveries:
		discoveries.append(CITY_TREE_ID)
	discoveries.sort()

	candidate.discovered_trees = discoveries
	candidate.tree_allocations[CITY_TREE_ID] = city_allocations
	candidate.passive_points_available += 1
	candidate.passive_points_lifetime_earned += 1
	return ""

static func _error(field: String, reason: String) -> String:
	return "%s field=%s reason=%s" % [ERROR_PREFIX, field, reason]
