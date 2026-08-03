class_name PassiveTreeCatalog
extends RefCounted

const CITY_PATH := "res://data/passive_trees/city/party-forge-city.pstree.json"

static func load_defaults() -> PassiveTreeLoadResult:
	return load_path(CITY_PATH)

static func load_path(path: String) -> PassiveTreeLoadResult:
	var result := PassiveTreeLoader.new().load_path(path)
	if not result.ok():
		return result
	var effect_registry := PassiveEffectRegistry.new()
	var requirement_registry := PassiveRequirementRegistry.new()
	var semantic_errors: Array[String] = []
	for tree_node: PassiveTreeNode in result.tree.nodes:
		for effect_index: int in tree_node.effects.size():
			var effect_error := effect_registry.validate(tree_node.effects[effect_index])
			if not effect_error.is_empty():
				semantic_errors.append("%s node=%s effect_index=%d" % [effect_error, tree_node.id, effect_index])
		for requirement_index: int in tree_node.requirements.size():
			var requirement_error := requirement_registry.validate(tree_node.requirements[requirement_index])
			if not requirement_error.is_empty():
				semantic_errors.append("%s node=%s requirement_index=%d" % [requirement_error, tree_node.id, requirement_index])
	for connection: PassiveTreeConnection in result.tree.connections:
		if connection.cost != 0:
			semantic_errors.append("PARTY_FORGE_PASSIVE_TREE_ERROR semantic=unsupported_connection_cost connection=%s" % connection.id)
		if not connection.conditions.is_empty():
			semantic_errors.append("PARTY_FORGE_PASSIVE_TREE_ERROR semantic=unsupported_connection_conditions connection=%s" % connection.id)
		for condition_index: int in connection.conditions.size():
			var condition_error := requirement_registry.validate(connection.conditions[condition_index])
			if not condition_error.is_empty():
				semantic_errors.append("%s connection=%s condition_index=%d" % [condition_error, connection.id, condition_index])
	semantic_errors.append_array(CityPassiveTreePolicy.new().validate(result.tree))
	if not semantic_errors.is_empty():
		result.errors.append_array(semantic_errors)
		result.tree = null
	return result
