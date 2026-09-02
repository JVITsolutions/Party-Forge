class_name PassiveTreePortal
extends RefCounted

var id: StringName
var source_node_id: StringName
var label: String
var role: StringName
var target_project_id: StringName
var target_graph_id: StringName
var discovered_tree_id: StringName

func _init(
	p_id: StringName = &"",
	p_source_node_id: StringName = &"",
	p_label: String = "",
	p_role: StringName = &"",
	p_target_project_id: StringName = &"",
	p_target_graph_id: StringName = &"",
	p_discovered_tree_id: StringName = &"",
) -> void:
	id = p_id
	source_node_id = p_source_node_id
	label = p_label
	role = p_role
	target_project_id = p_target_project_id
	target_graph_id = p_target_graph_id
	discovered_tree_id = p_discovered_tree_id

func copy() -> PassiveTreePortal:
	return PassiveTreePortal.new(
		id,
		source_node_id,
		label,
		role,
		target_project_id,
		target_graph_id,
		discovered_tree_id,
	)
