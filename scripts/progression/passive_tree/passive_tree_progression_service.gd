class_name PassiveTreeProgressionService
extends RefCounted

const MESSAGES := {
	&"ok": "Action is available.",
	&"tree_not_discovered": "Discover this passive tree before changing it.",
	&"unknown_node": "This passive node is no longer available.",
	&"already_allocated": "This passive node is already allocated.",
	&"node_obscured": "Reveal this passive node before allocating it.",
	&"requirement_failed": "Meet every passive node requirement before allocating it.",
	&"not_connected": "Allocate a connected path to this passive node first.",
	&"insufficient_points": "You do not have enough Passive Points.",
	&"not_allocated": "This passive node is not allocated.",
	&"permanent_node": "This passive node grants permanent progression and cannot be refunded.",
	&"respec_service_required": "Unlock the Passive Respec service before refunding nodes.",
	&"retained_path_disconnected": "Refunding this node would disconnect an allocated path.",
	&"retained_requirement_failed": "Refunding this node would break another allocated node's requirements.",
}

var _effect_registry: PassiveEffectRegistry
var _requirement_registry: PassiveRequirementRegistry

func _init(effect_registry: PassiveEffectRegistry, requirement_registry: PassiveRequirementRegistry) -> void:
	_effect_registry = effect_registry
	_requirement_registry = requirement_registry

func allocation_decision(
	tree: PassiveTreeDefinition,
	profile: ProfileState,
	node_id: StringName,
	developer_context: bool,
) -> PassiveTreeActionDecision:
	var graph := PassiveTreeGraph.new(tree)
	var snapshot := PassiveTreeSnapshot.build(tree, profile, developer_context, graph)
	var current := _combined_ids(snapshot.allocated, snapshot.unresolved)
	if String(tree.id) not in profile.discovered_trees:
		return _decision(&"tree_not_discovered", false, 0, current, snapshot.implicit_start_nodes)
	var tree_node := tree.node(node_id)
	if tree_node == null:
		return _decision(&"unknown_node", false, 0, current, snapshot.implicit_start_nodes)
	if node_id in snapshot.allocated:
		return _decision(&"already_allocated", false, 0, current, snapshot.implicit_start_nodes)
	if node_id not in snapshot.visible:
		return _decision(&"node_obscured", false, 0, current, snapshot.implicit_start_nodes)
	var validation_allocations := _combined_ids(snapshot.allocated, snapshot.implicit_start_nodes)
	if not _requirements_pass(tree, profile, tree_node, validation_allocations):
		return _decision(&"requirement_failed", false, 0, current, snapshot.implicit_start_nodes)
	if profile.passive_points_available < tree_node.cost:
		return _decision(&"insufficient_points", false, 0, current, snapshot.implicit_start_nodes)
	if not graph.candidate_reachable(validation_allocations, node_id):
		return _decision(&"not_connected", false, 0, current, snapshot.implicit_start_nodes)
	var projected := _combined_ids(current, snapshot.implicit_start_nodes)
	projected = _combined_ids(projected, [node_id])
	return _decision(&"ok", true, -tree_node.cost, projected, snapshot.implicit_start_nodes)

func refund_decision(
	tree: PassiveTreeDefinition,
	profile: ProfileState,
	node_id: StringName,
	developer_context: bool,
	has_respec_service: bool,
) -> PassiveTreeActionDecision:
	var graph := PassiveTreeGraph.new(tree)
	var snapshot := PassiveTreeSnapshot.build(tree, profile, false, graph)
	var current := _combined_ids(snapshot.allocated, snapshot.unresolved)
	if String(tree.id) not in profile.discovered_trees:
		return _decision(&"tree_not_discovered", false, 0, current, snapshot.implicit_start_nodes)
	var tree_node := tree.node(node_id)
	if tree_node == null:
		return _decision(&"unknown_node", false, 0, current, snapshot.implicit_start_nodes)
	if node_id not in snapshot.allocated:
		return _decision(&"not_allocated", false, 0, current, snapshot.implicit_start_nodes)
	if node_id in tree.starting_node_ids or _is_permanent(tree_node):
		return _decision(&"permanent_node", false, 0, current, snapshot.implicit_start_nodes)
	if not developer_context and not has_respec_service:
		return _decision(&"respec_service_required", false, 0, current, snapshot.implicit_start_nodes)

	var retained_known: Array[StringName] = []
	for allocated_id: StringName in snapshot.allocated:
		if allocated_id != node_id:
			retained_known.append(allocated_id)
	if not graph.retained_reach_start(retained_known):
		return _decision(&"retained_path_disconnected", false, 0, current, snapshot.implicit_start_nodes)

	var final_implicit_roots := _missing_start_nodes(tree, retained_known)
	var validation_allocations := _combined_ids(retained_known, final_implicit_roots)
	var projected := _combined_ids(retained_known, snapshot.unresolved)
	projected = _combined_ids(projected, final_implicit_roots)
	for retained_id: StringName in retained_known:
		var retained_node := tree.node(retained_id)
		if retained_node != null and not _requirements_pass(tree, profile, retained_node, validation_allocations):
			return _decision(&"retained_requirement_failed", false, 0, current, snapshot.implicit_start_nodes)
	return _decision(&"ok", true, tree_node.cost, projected, final_implicit_roots)

func _requirements_pass(
	tree: PassiveTreeDefinition,
	profile: ProfileState,
	tree_node: PassiveTreeNode,
	current_tree_allocations: Array[StringName],
) -> bool:
	for requirement: PassiveTreeRequirement in tree_node.requirements:
		if not _requirement_registry.validate(requirement).is_empty():
			return false
		if requirement.requirement_id != &"allocated_node":
			return false
		var required_tree_id := String(requirement.parameters["treeId"])
		var allocations: Array[StringName] = []
		if required_tree_id == String(tree.id):
			allocations.assign(current_tree_allocations)
		else:
			var saved: Variant = profile.tree_allocations.get(required_tree_id, [])
			if saved is Array:
				for saved_id: Variant in saved as Array:
					var allocation_id := StringName(saved_id)
					if allocation_id not in allocations:
						allocations.append(allocation_id)
		if StringName(requirement.value) not in allocations:
			return false
	return true

func _is_permanent(tree_node: PassiveTreeNode) -> bool:
	if tree_node.metadata.get("refundPolicy", "") == "permanent":
		return true
	for effect: PassiveTreeEffect in tree_node.effects:
		if _effect_registry.is_permanent(effect):
			return true
	return false

func _missing_start_nodes(tree: PassiveTreeDefinition, allocations: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for start_id: StringName in tree.starting_node_ids:
		if start_id not in allocations:
			result.append(start_id)
	return result

func _combined_ids(left: Array[StringName], right: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(left)
	for value: StringName in right:
		if value not in result:
			result.append(value)
	result.sort_custom(func(left_id: StringName, right_id: StringName) -> bool: return String(left_id) < String(right_id))
	return result

func _decision(
	code: StringName,
	allowed: bool,
	point_delta: int,
	next_allocations: Array[StringName],
	implicit_start_nodes: Array[StringName],
) -> PassiveTreeActionDecision:
	return PassiveTreeActionDecision.new(allowed, code, MESSAGES[code], point_delta, next_allocations, implicit_start_nodes)
