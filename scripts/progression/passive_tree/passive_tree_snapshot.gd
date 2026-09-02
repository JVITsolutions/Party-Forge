class_name PassiveTreeSnapshot
extends RefCounted

var allocated: Array[StringName] = []
var unresolved: Array[StringName] = []
var implicit_start_nodes: Array[StringName] = []
var visible: Array[StringName] = []

static func build(
	tree: PassiveTreeDefinition,
	profile: ProfileState,
	developer_reveal: bool,
	graph: PassiveTreeGraph = null,
) -> PassiveTreeSnapshot:
	var snapshot := PassiveTreeSnapshot.new()
	var known_ids: Dictionary = {}
	for tree_node: PassiveTreeNode in tree.nodes:
		known_ids[tree_node.id] = true

	var saved_allocations: Variant = profile.tree_allocations.get(String(tree.id), [])
	if saved_allocations is Array:
		for saved_value: Variant in saved_allocations as Array:
			var saved_id := StringName(saved_value)
			if known_ids.has(saved_id):
				_append_unique(snapshot.allocated, saved_id)
			else:
				_append_unique(snapshot.unresolved, saved_id)
	_sort_node_ids(snapshot.allocated)
	_sort_node_ids(snapshot.unresolved)

	if String(tree.id) in profile.discovered_trees:
		for starting_id: StringName in tree.starting_node_ids:
			if starting_id not in snapshot.allocated:
				_append_unique(snapshot.implicit_start_nodes, starting_id)
	_sort_node_ids(snapshot.implicit_start_nodes)

	var discovered := String(tree.id) in profile.discovered_trees
	if developer_reveal or (discovered and tree.id == PassiveTreeActivationPolicy.CITY_TREE_ID):
		for tree_node: PassiveTreeNode in tree.nodes:
			_append_unique(snapshot.visible, tree_node.id)
		_sort_node_ids(snapshot.visible)
		return snapshot

	var visibility_sources: Array[StringName] = []
	visibility_sources.assign(snapshot.allocated)
	for starting_id: StringName in snapshot.implicit_start_nodes:
		_append_unique(visibility_sources, starting_id)
	var tree_graph := graph if graph != null else PassiveTreeGraph.new(tree)
	var distances := tree_graph.distances_from(visibility_sources)
	var visibility_bonus := maxi(0, int(profile.tree_visibility_progress.get(String(tree.id), 0)))
	var reveal_radius := 2 + visibility_bonus
	for node_id: StringName in distances:
		if int(distances[node_id]) <= reveal_radius:
			snapshot.visible.append(node_id)
	_sort_node_ids(snapshot.visible)
	return snapshot

static func _append_unique(values: Array[StringName], value: StringName) -> void:
	if value not in values:
		values.append(value)

static func _sort_node_ids(values: Array[StringName]) -> void:
	values.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
