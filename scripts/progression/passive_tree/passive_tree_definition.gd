class_name PassiveTreeDefinition
extends RefCounted

var id: StringName
var name: String
var starting_node_ids: Array[StringName] = []
var nodes: Array[PassiveTreeNode] = []
var connections: Array[PassiveTreeConnection] = []
var metadata: Dictionary
var portals: Array[PassiveTreePortal] = []

var _nodes_by_id: Dictionary = {}
var _connections_by_id: Dictionary = {}
var _portals_by_source_node: Dictionary = {}

func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_starting_node_ids: Array[StringName] = [],
	p_nodes: Array[PassiveTreeNode] = [],
	p_connections: Array[PassiveTreeConnection] = [],
	p_metadata: Dictionary = {},
	p_portals: Array[PassiveTreePortal] = [],
) -> void:
	id = p_id
	name = p_name
	starting_node_ids.assign(p_starting_node_ids)
	nodes.assign(p_nodes)
	connections.assign(p_connections)
	metadata = p_metadata.duplicate(true)
	for portal: PassiveTreePortal in p_portals:
		if portal != null:
			portals.append(portal.copy())
	for tree_node: PassiveTreeNode in nodes:
		_nodes_by_id[tree_node.id] = tree_node
	for tree_connection: PassiveTreeConnection in connections:
		_connections_by_id[tree_connection.id] = tree_connection
	for portal: PassiveTreePortal in portals:
		_portals_by_source_node[portal.source_node_id] = portal

func node(node_id: StringName) -> PassiveTreeNode:
	return _nodes_by_id.get(node_id) as PassiveTreeNode

func connection(connection_id: StringName) -> PassiveTreeConnection:
	return _connections_by_id.get(connection_id) as PassiveTreeConnection

func portal_for_source_node(node_id: StringName) -> PassiveTreePortal:
	return _portals_by_source_node.get(node_id) as PassiveTreePortal
