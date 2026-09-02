class_name CityTreeGeometryValidator
extends RefCounted

const NODE_WIDTH := 92.0
const NODE_HEIGHT := 34.0
const NODE_CLEARANCE := 12.0
const EDGE_CLEARANCE := 8.0
const RIGHT_ANGLE_EXCLUSION_DEGREES := 4.0
const EPSILON := 0.000000001
const ANGLE_EPSILON := 0.0001
const ERROR_PREFIX := "PARTY_FORGE_CITY_GEOMETRY_ERROR"

static func validate(nodes: Array, connections: Array) -> Array[String]:
	var errors: Array[String] = []
	var nodes_by_id: Dictionary = {}
	var ordered_nodes: Array[PassiveTreeNode] = []
	for value: Variant in nodes:
		if value is PassiveTreeNode:
			var tree_node := value as PassiveTreeNode
			nodes_by_id[tree_node.id] = tree_node
			ordered_nodes.append(tree_node)
	ordered_nodes.sort_custom(func(left: PassiveTreeNode, right: PassiveTreeNode) -> bool:
		return String(left.id) < String(right.id)
	)

	_find_node_overlaps(ordered_nodes, errors)
	_find_edge_crossings(connections, nodes_by_id, errors)
	_find_edge_node_collisions(connections, ordered_nodes, nodes_by_id, errors)
	_find_near_right_angle_junctions(connections, nodes_by_id, errors)
	errors.sort()
	return errors

static func _find_node_overlaps(nodes: Array[PassiveTreeNode], errors: Array[String]) -> void:
	for left_index: int in nodes.size():
		for right_index: int in range(left_index + 1, nodes.size()):
			var left := nodes[left_index]
			var right := nodes[right_index]
			var horizontal_gap := maxf(0.0, absf(left.position.x - right.position.x) - NODE_WIDTH)
			var vertical_gap := maxf(0.0, absf(left.position.y - right.position.y) - NODE_HEIGHT)
			if Vector2(horizontal_gap, vertical_gap).length() < NODE_CLEARANCE - EPSILON:
				errors.append("%s kind=node_clearance left=%s right=%s" % [ERROR_PREFIX, left.id, right.id])

static func _find_edge_crossings(connections: Array, nodes_by_id: Dictionary, errors: Array[String]) -> void:
	for left_index: int in connections.size():
		if not connections[left_index] is PassiveTreeConnection:
			continue
		var left := connections[left_index] as PassiveTreeConnection
		var left_start := nodes_by_id.get(left.from_id) as PassiveTreeNode
		var left_end := nodes_by_id.get(left.to_id) as PassiveTreeNode
		if left_start == null or left_end == null:
			continue
		for right_index: int in range(left_index + 1, connections.size()):
			if not connections[right_index] is PassiveTreeConnection:
				continue
			var right := connections[right_index] as PassiveTreeConnection
			if left.from_id == right.from_id or left.from_id == right.to_id \
			or left.to_id == right.from_id or left.to_id == right.to_id:
				continue
			var right_start := nodes_by_id.get(right.from_id) as PassiveTreeNode
			var right_end := nodes_by_id.get(right.to_id) as PassiveTreeNode
			if right_start != null and right_end != null \
			and _proper_segments_cross(left_start.position, left_end.position, right_start.position, right_end.position):
				errors.append("%s kind=edge_crossing left=%s right=%s" % [ERROR_PREFIX, left.id, right.id])

static func _find_edge_node_collisions(
	connections: Array,
	nodes: Array[PassiveTreeNode],
	nodes_by_id: Dictionary,
	errors: Array[String],
) -> void:
	for value: Variant in connections:
		if not value is PassiveTreeConnection:
			continue
		var edge := value as PassiveTreeConnection
		var start := nodes_by_id.get(edge.from_id) as PassiveTreeNode
		var end := nodes_by_id.get(edge.to_id) as PassiveTreeNode
		if start == null or end == null:
			continue
		for candidate: PassiveTreeNode in nodes:
			if candidate.id == edge.from_id or candidate.id == edge.to_id:
				continue
			if _segment_rectangle_distance(start.position, end.position, candidate.position) < EDGE_CLEARANCE - EPSILON:
				errors.append("%s kind=edge_node_clearance connection=%s node=%s" % [ERROR_PREFIX, edge.id, candidate.id])

static func _find_near_right_angle_junctions(connections: Array, nodes_by_id: Dictionary, errors: Array[String]) -> void:
	var ordered_ids: Array[StringName] = []
	for node_id: StringName in nodes_by_id:
		ordered_ids.append(node_id)
	ordered_ids.sort()
	for junction_id: StringName in ordered_ids:
		var junction := nodes_by_id[junction_id] as PassiveTreeNode
		var incident: Array[PassiveTreeConnection] = []
		for value: Variant in connections:
			if value is PassiveTreeConnection:
				var edge := value as PassiveTreeConnection
				if edge.from_id == junction_id or edge.to_id == junction_id:
					incident.append(edge)
		incident.sort_custom(func(left: PassiveTreeConnection, right: PassiveTreeConnection) -> bool:
			return String(left.id) < String(right.id)
		)
		for left_index: int in incident.size():
			for right_index: int in range(left_index + 1, incident.size()):
				var left := incident[left_index]
				var right := incident[right_index]
				var left_other_id := left.to_id if left.from_id == junction_id else left.from_id
				var right_other_id := right.to_id if right.from_id == junction_id else right.from_id
				var left_other := nodes_by_id.get(left_other_id) as PassiveTreeNode
				var right_other := nodes_by_id.get(right_other_id) as PassiveTreeNode
				if left_other == null or right_other == null:
					continue
				var left_vector := left_other.position - junction.position
				var right_vector := right_other.position - junction.position
				var denominator := left_vector.length() * right_vector.length()
				if denominator <= EPSILON:
					continue
				var cosine := clampf(left_vector.dot(right_vector) / denominator, -1.0, 1.0)
				var angle := rad_to_deg(acos(cosine))
				if absf(angle - 90.0) <= RIGHT_ANGLE_EXCLUSION_DEGREES + ANGLE_EPSILON:
					errors.append("%s kind=perpendicular_junction junction=%s left=%s right=%s" % [ERROR_PREFIX, junction_id, left.id, right.id])

static func _orientation(a: Vector2, b: Vector2, c: Vector2) -> float:
	return ((b.x - a.x) * (c.y - a.y)) - ((b.y - a.y) * (c.x - a.x))

static func _proper_segments_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var first_a := _orientation(a, b, c)
	var first_b := _orientation(a, b, d)
	var second_a := _orientation(c, d, a)
	var second_b := _orientation(c, d, b)
	return first_a * first_b < -EPSILON and second_a * second_b < -EPSILON

static func _point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> bool:
	return absf(_orientation(start, end, point)) <= EPSILON \
		and point.x >= minf(start.x, end.x) - EPSILON and point.x <= maxf(start.x, end.x) + EPSILON \
		and point.y >= minf(start.y, end.y) - EPSILON and point.y <= maxf(start.y, end.y) + EPSILON

static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	return _proper_segments_cross(a, b, c, d) \
		or _point_on_segment(a, c, d) or _point_on_segment(b, c, d) \
		or _point_on_segment(c, a, b) or _point_on_segment(d, a, b)

static func _point_segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	var delta := end - start
	var length_squared := delta.length_squared()
	if length_squared <= EPSILON:
		return point.distance_to(start)
	var projection := clampf((point - start).dot(delta) / length_squared, 0.0, 1.0)
	return point.distance_to(start + projection * delta)

static func _segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if _segments_intersect(a, b, c, d):
		return 0.0
	return minf(
		minf(_point_segment_distance(a, c, d), _point_segment_distance(b, c, d)),
		minf(_point_segment_distance(c, a, b), _point_segment_distance(d, a, b)),
	)

static func _segment_rectangle_distance(start: Vector2, end: Vector2, center: Vector2) -> float:
	var half_width := NODE_WIDTH / 2.0
	var half_height := NODE_HEIGHT / 2.0
	var top_left := center + Vector2(-half_width, -half_height)
	var top_right := center + Vector2(half_width, -half_height)
	var bottom_right := center + Vector2(half_width, half_height)
	var bottom_left := center + Vector2(-half_width, half_height)
	var rectangle := Rect2(top_left, Vector2(NODE_WIDTH, NODE_HEIGHT))
	if rectangle.has_point(start) or rectangle.has_point(end):
		return 0.0
	return minf(
		minf(_segment_distance(start, end, top_left, top_right), _segment_distance(start, end, top_right, bottom_right)),
		minf(_segment_distance(start, end, bottom_right, bottom_left), _segment_distance(start, end, bottom_left, top_left)),
	)
