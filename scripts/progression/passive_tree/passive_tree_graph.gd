class_name PassiveTreeGraph
extends RefCounted

var _node_ids: Dictionary = {}
var _starting_node_ids: Array[StringName] = []
var _directed_adjacency: Dictionary = {}
var _undirected_adjacency: Dictionary = {}

func _init(tree: PassiveTreeDefinition) -> void:
	_starting_node_ids.assign(tree.starting_node_ids)
	_sort_node_ids(_starting_node_ids)
	for tree_node: PassiveTreeNode in tree.nodes:
		_node_ids[tree_node.id] = true
		_directed_adjacency[tree_node.id] = [] as Array[StringName]
		_undirected_adjacency[tree_node.id] = [] as Array[StringName]
	for connection: PassiveTreeConnection in tree.connections:
		_add_neighbor(_directed_adjacency, connection.from_id, connection.to_id)
		if connection.direction == &"bidirectional":
			_add_neighbor(_directed_adjacency, connection.to_id, connection.from_id)
		_add_neighbor(_undirected_adjacency, connection.from_id, connection.to_id)
		_add_neighbor(_undirected_adjacency, connection.to_id, connection.from_id)
	_sort_adjacency(_directed_adjacency)
	_sort_adjacency(_undirected_adjacency)

func neighbors(node_id: StringName, directed: bool) -> Array[StringName]:
	var adjacency := _directed_adjacency if directed else _undirected_adjacency
	var result: Array[StringName] = []
	result.assign(adjacency.get(node_id, []))
	return result

func distances_from(sources: Array[StringName]) -> Dictionary:
	var distances: Dictionary = {}
	var pending: Array[StringName] = []
	for source: StringName in sources:
		if _node_ids.has(source) and not distances.has(source):
			distances[source] = 0
			pending.append(source)
	_sort_node_ids(pending)
	var cursor := 0
	while cursor < pending.size():
		var current := pending[cursor]
		cursor += 1
		for neighbor: StringName in neighbors(current, false):
			if distances.has(neighbor):
				continue
			distances[neighbor] = int(distances[current]) + 1
			pending.append(neighbor)
	var sorted_ids: Array[StringName] = []
	for node_id: StringName in distances:
		sorted_ids.append(node_id)
	_sort_node_ids(sorted_ids)
	var sorted_distances: Dictionary = {}
	for node_id: StringName in sorted_ids:
		sorted_distances[node_id] = distances[node_id]
	return sorted_distances

func candidate_reachable(allocated: Array[StringName], candidate: StringName) -> bool:
	if not _node_ids.has(candidate):
		return false
	if candidate in _starting_node_ids:
		return true
	for allocated_id: StringName in allocated:
		if not _node_ids.has(allocated_id):
			continue
		if candidate in neighbors(allocated_id, true):
			return true
	return false

func retained_reach_start(allocated: Array[StringName]) -> bool:
	var retained: Dictionary = {}
	for node_id: StringName in allocated:
		if _node_ids.has(node_id):
			retained[node_id] = true
	if retained.is_empty():
		return true

	var reached: Dictionary = {}
	var pending: Array[StringName] = []
	for starting_id: StringName in _starting_node_ids:
		reached[starting_id] = true
		pending.append(starting_id)
	var cursor := 0
	while cursor < pending.size():
		var current := pending[cursor]
		cursor += 1
		for neighbor: StringName in neighbors(current, true):
			if reached.has(neighbor) or not retained.has(neighbor):
				continue
			reached[neighbor] = true
			pending.append(neighbor)
	for retained_id: StringName in retained:
		if not reached.has(retained_id):
			return false
	return true

func _add_neighbor(adjacency: Dictionary, from_id: StringName, to_id: StringName) -> void:
	var adjacent: Array[StringName] = []
	adjacent.assign(adjacency.get(from_id, []))
	if to_id not in adjacent:
		adjacent.append(to_id)
	adjacency[from_id] = adjacent

func _sort_adjacency(adjacency: Dictionary) -> void:
	for node_id: StringName in adjacency:
		var adjacent: Array[StringName] = []
		adjacent.assign(adjacency[node_id])
		_sort_node_ids(adjacent)
		adjacency[node_id] = adjacent

func _sort_node_ids(values: Array[StringName]) -> void:
	values.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
