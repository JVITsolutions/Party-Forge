class_name GroundItemTargetingService
extends RefCounted

func ordered_for_owner(
	index: RefCounted,
	run_player_id: StringName,
	leader_position: Vector3,
	query_radius: float = INF,
	visibility_filter: Callable = Callable(),
) -> Array[GroundItemRecord]:
	var result: Array[GroundItemRecord] = []
	if index == null or run_player_id.is_empty() or query_radius < 0.0:
		return result
	var bounded_radius := query_radius if is_finite(query_radius) else 1000000.0
	var radius_squared := bounded_radius * bounded_radius
	for record: GroundItemRecord in index.call(&"query", run_player_id, leader_position, bounded_radius):
		if record.world_position.distance_squared_to(leader_position) > radius_squared:
			continue
		if visibility_filter.is_valid() and not bool(visibility_filter.call(record.copy())):
			continue
		result.append(record.copy())
	result.sort_custom(func(left: GroundItemRecord, right: GroundItemRecord) -> bool:
		var left_distance := left.world_position.distance_squared_to(leader_position)
		var right_distance := right.world_position.distance_squared_to(leader_position)
		if left_distance != right_distance:
			return left_distance < right_distance
		return String(left.drop_id) < String(right.drop_id)
	)
	return result

func cycle(
	current_drop_id: StringName,
	direction: int,
	index: RefCounted,
	run_player_id: StringName,
	leader_position: Vector3,
	query_radius: float = INF,
	visibility_filter: Callable = Callable(),
) -> StringName:
	var ordered := ordered_for_owner(index, run_player_id, leader_position, query_radius, visibility_filter)
	if ordered.is_empty():
		return &""
	var current_index := -1
	for index_value: int in ordered.size():
		if ordered[index_value].drop_id == current_drop_id:
			current_index = index_value
			break
	if current_index < 0:
		return ordered[0].drop_id if direction >= 0 else ordered[-1].drop_id
	var step := 1 if direction >= 0 else -1
	return ordered[posmod(current_index + step, ordered.size())].drop_id
