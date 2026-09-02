class_name PassiveTreeViewModel
extends RefCounted

const OBSCURED_NAME := "???"
const OBSCURED_DESCRIPTION := "???"
const OBSCURED_COST_TEXT := "?"

var _progression: PassiveTreeProgressionService
var _resolver: PassiveEffectResolver
var _effects: PassiveEffectRegistry
var _requirements: PassiveRequirementRegistry

func _init(
	progression: PassiveTreeProgressionService,
	resolver: PassiveEffectResolver,
	effects: PassiveEffectRegistry,
	requirements: PassiveRequirementRegistry,
) -> void:
	_progression = progression
	_resolver = resolver
	_effects = effects
	_requirements = requirements

func build(tree: PassiveTreeDefinition, profile: ProfileState, developer_reveal: bool) -> Dictionary:
	if tree == null:
		return _empty_result("Passive tree unavailable.")
	if profile == null:
		return _empty_result("Profile unavailable.", tree)
	if _progression == null or _resolver == null or _effects == null or _requirements == null:
		return _empty_result("Passive tree services unavailable.", tree, profile)

	var snapshot := PassiveTreeSnapshot.build(tree, profile, developer_reveal)
	var node_views: Array[PassiveTreeNodeViewData] = []
	var sorted_nodes: Array[PassiveTreeNode] = []
	sorted_nodes.assign(tree.nodes)
	sorted_nodes.sort_custom(func(left: PassiveTreeNode, right: PassiveTreeNode) -> bool:
		return String(left.id) < String(right.id)
	)
	for tree_node: PassiveTreeNode in sorted_nodes:
		node_views.append(_project_node(tree, profile, snapshot, tree_node, developer_reveal))

	var connections: Array[Dictionary] = []
	var sorted_connections: Array[PassiveTreeConnection] = []
	sorted_connections.assign(tree.connections)
	sorted_connections.sort_custom(func(left: PassiveTreeConnection, right: PassiveTreeConnection) -> bool:
		return String(left.id) < String(right.id)
	)
	for connection: PassiveTreeConnection in sorted_connections:
		connections.append({
			"id": connection.id,
			"from_id": connection.from_id,
			"to_id": connection.to_id,
			"direction": connection.direction,
			"cost": connection.cost,
			"metadata": PassiveTreeNodeViewData.value_only_copy(connection.metadata),
		})

	var unresolved_ids: Array[StringName] = []
	unresolved_ids.assign(snapshot.unresolved)
	return {
		"tree_id": tree.id,
		"tree_name": tree.name,
		"points_available": profile.passive_points_available,
		"points_lifetime": profile.passive_points_lifetime_earned,
		"points_text": "Passive Points: %d / %d" % [profile.passive_points_available, profile.passive_points_lifetime_earned],
		"nodes": node_views,
		"connections": connections,
		"unresolved_ids": unresolved_ids,
		"status": "",
	}

func _project_node(
	tree: PassiveTreeDefinition,
	profile: ProfileState,
	snapshot: PassiveTreeSnapshot,
	tree_node: PassiveTreeNode,
	developer_reveal: bool,
) -> PassiveTreeNodeViewData:
	var is_visible := tree_node.id in snapshot.visible
	if not is_visible:
		return PassiveTreeNodeViewData.new(
			tree_node.id,
			tree_node.position,
			tree_node.type,
			&"obscured",
			OBSCURED_NAME,
			OBSCURED_DESCRIPTION,
			-1,
			OBSCURED_COST_TEXT,
			[],
			[],
			[],
			{},
			false,
			false,
			false,
			&"node_obscured",
			PassiveTreeProgressionService.MESSAGES[&"node_obscured"],
		)

	var is_allocated := tree_node.id in snapshot.allocated or tree_node.id in snapshot.implicit_start_nodes
	var activation := _progression.activation_decision(tree, tree_node)
	var decision_code: StringName = &"already_allocated"
	var decision_message := String(PassiveTreeProgressionService.MESSAGES[decision_code])
	var is_allocatable := false
	if not is_allocated:
		var decision := _progression.allocation_decision(tree, profile, tree_node.id, developer_reveal)
		decision_code = decision.code
		decision_message = decision.message
		is_allocatable = decision.ok()
	var state: StringName = &"allocated" if is_allocated else (&"allocatable" if is_allocatable else &"unavailable")
	var effect_lines: Array[String] = []
	var requirement_lines: Array[String] = []
	var keyword_members: Dictionary = {}
	for effect: PassiveTreeEffect in tree_node.effects:
		var effect_line := _effects.describe(effect)
		if not effect_line.is_empty():
			effect_lines.append(effect_line)
			var effect_keyword := _effects.keyword_explanation(effect.effect_id)
			if not effect_keyword.is_empty():
				keyword_members[effect_keyword] = true
	for requirement: PassiveTreeRequirement in tree_node.requirements:
		var requirement_line := _requirements.describe(requirement)
		if not requirement_line.is_empty():
			requirement_lines.append(requirement_line)
			var requirement_keyword := _requirements.keyword_explanation(requirement.requirement_id)
			if not requirement_keyword.is_empty():
				keyword_members[requirement_keyword] = true
	var keyword_lines: Array[String] = []
	for keyword: Variant in keyword_members.keys():
		keyword_lines.append(String(keyword))
	keyword_lines.sort()
	var permanent := _is_permanent(tree, tree_node)
	var development_lines: Array[String] = []
	match activation.code:
		&"future_node", &"district_target_missing":
			development_lines.append(activation.message)
	if developer_reveal and activation.code in [&"future_node", &"district_target_missing"]:
		development_lines.append("Developer Preview")

	return PassiveTreeNodeViewData.new(
		tree_node.id,
		tree_node.position,
		tree_node.type,
		state,
		tree_node.name,
		tree_node.description,
		tree_node.cost,
		str(tree_node.cost),
		effect_lines,
		requirement_lines,
		keyword_lines,
		tree_node.metadata,
		permanent,
		is_allocated,
		is_allocatable,
		decision_code,
		decision_message,
		"Permanent" if permanent else "Refundable",
		development_lines,
		StringName(tree_node.metadata.get("activationState", "")),
		activation.ok(),
	)

func _is_permanent(tree: PassiveTreeDefinition, tree_node: PassiveTreeNode) -> bool:
	if tree_node.id in tree.starting_node_ids or tree_node.metadata.get("refundPolicy", "") == "permanent":
		return true
	for effect: PassiveTreeEffect in tree_node.effects:
		if _effects.is_permanent(effect):
			return true
	return false

func _empty_result(status: String, tree: PassiveTreeDefinition = null, profile: ProfileState = null) -> Dictionary:
	var points_available := profile.passive_points_available if profile != null else 0
	var points_lifetime := profile.passive_points_lifetime_earned if profile != null else 0
	return {
		"tree_id": tree.id if tree != null else &"",
		"tree_name": tree.name if tree != null else "",
		"points_available": points_available,
		"points_lifetime": points_lifetime,
		"points_text": "Passive Points: %d / %d" % [points_available, points_lifetime],
		"nodes": [],
		"connections": [],
		"unresolved_ids": [],
		"status": status,
	}
