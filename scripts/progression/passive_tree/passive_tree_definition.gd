class_name PassiveTreeDefinition
extends RefCounted

var id: StringName
var name: String
var starting_node_ids: Array[StringName] = []
var nodes: Array[PassiveTreeNode] = []
var connections: Array[PassiveTreeConnection] = []
var metadata: Dictionary

var _nodes_by_id: Dictionary = {}
var _connections_by_id: Dictionary = {}

func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_starting_node_ids: Array[StringName] = [],
	p_nodes: Array[PassiveTreeNode] = [],
	p_connections: Array[PassiveTreeConnection] = [],
	p_metadata: Dictionary = {},
) -> void:
	id = p_id
	name = p_name
	starting_node_ids.assign(p_starting_node_ids)
	nodes.assign(p_nodes)
	connections.assign(p_connections)
	metadata = p_metadata.duplicate(true)
	for tree_node: PassiveTreeNode in nodes:
		_nodes_by_id[tree_node.id] = tree_node
	for tree_connection: PassiveTreeConnection in connections:
		_connections_by_id[tree_connection.id] = tree_connection

func node(node_id: StringName) -> PassiveTreeNode:
	return _nodes_by_id.get(node_id) as PassiveTreeNode

func connection(connection_id: StringName) -> PassiveTreeConnection:
	return _connections_by_id.get(connection_id) as PassiveTreeConnection
