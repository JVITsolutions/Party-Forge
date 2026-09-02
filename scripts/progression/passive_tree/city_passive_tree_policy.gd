class_name CityPassiveTreePolicy
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_CITY_PASSIVE_TREE_ERROR"
const IMMEDIATE_NODE_IDS: Array[StringName] = [
	&"city-heart", &"equipment-registry", &"field-pack", &"stash-access",
	&"extraction-license", &"secured-loadout", &"leader-loadout-extraction",
]
const IMMEDIATE_ROUTE: Array[Array] = [
	[&"city-heart", &"equipment-registry"],
	[&"city-heart", &"stash-access"],
	[&"equipment-registry", &"field-pack"],
	[&"field-pack", &"extraction-license"],
	[&"stash-access", &"extraction-license"],
	[&"extraction-license", &"secured-loadout"],
	[&"secured-loadout", &"leader-loadout-extraction"],
	[&"leader-loadout-extraction", &"logistics-district-charter"],
]

func validate(tree: PassiveTreeDefinition) -> Array[String]:
	var errors: Array[String] = []
	if tree == null:
		errors.append("%s reason=tree must not be null" % ERROR_PREFIX)
		return errors
	if tree.id != &"party-forge-city-v1":
		errors.append("%s field=treeId reason=City tree ID must equal party-forge-city-v1" % ERROR_PREFIX)
	if tree.starting_node_ids != [&"city-heart"]:
		errors.append("%s field=startingNodeIds reason=City tree must have exactly one starting node city-heart" % ERROR_PREFIX)
	if tree.nodes.size() != 37:
		errors.append("%s field=nodes reason=City tree must contain exactly 37 nodes" % ERROR_PREFIX)
	if tree.connections.size() != 37:
		errors.append("%s field=connections reason=City tree must contain exactly 37 connections" % ERROR_PREFIX)
	if tree.portals.size() != 6:
		errors.append("%s field=portals reason=City tree must contain exactly 6 district portals" % ERROR_PREFIX)
	var nodes_by_id: Dictionary = {}
	for tree_node: PassiveTreeNode in tree.nodes:
		nodes_by_id[tree_node.id] = tree_node
	for node_id: StringName in IMMEDIATE_NODE_IDS:
		if not nodes_by_id.has(node_id):
			errors.append("%s field=nodes reason=City tree requires immediate node %s" % [ERROR_PREFIX, node_id])
			continue
		var immediate_node: PassiveTreeNode = nodes_by_id[node_id]
		_validate_metadata(immediate_node, errors)
		_validate_immediate_cost(immediate_node, errors)
		_validate_immediate_effects(immediate_node, errors)
		if node_id != &"extraction-license" and not immediate_node.requirements.is_empty():
			errors.append("%s node=%s field=requirements reason=immediate node requires no content requirements" % [ERROR_PREFIX, node_id])
	if nodes_by_id.has(&"extraction-license"):
		_validate_extraction_requirements(nodes_by_id[&"extraction-license"], errors)
	if nodes_by_id.has(&"stash-access"):
		_validate_stash_size(nodes_by_id[&"stash-access"], errors)
	_validate_immediate_route(tree, errors)
	return errors

func _validate_immediate_cost(tree_node: PassiveTreeNode, errors: Array[String]) -> void:
	var expected := 0 if tree_node.id == &"city-heart" else 1
	if tree_node.cost != expected:
		errors.append("%s node=%s field=cost reason=cost must equal %d" % [ERROR_PREFIX, tree_node.id, expected])

func _validate_immediate_effects(tree_node: PassiveTreeNode, errors: Array[String]) -> void:
	var actual: Array[Dictionary] = []
	for effect: PassiveTreeEffect in tree_node.effects:
		actual.append({
			"effect_id": effect.effect_id,
			"operation": effect.operation,
			"value": effect.value,
			"parameters": effect.parameters.duplicate(true),
		})
	var expected := _expected_effects(tree_node.id)
	if actual != expected:
		errors.append("%s node=%s field=effects reason=effects must equal the approved live projection" % [ERROR_PREFIX, tree_node.id])

func _expected_effects(node_id: StringName) -> Array[Dictionary]:
	match node_id:
		&"city-heart":
			return []
		&"equipment-registry":
			return [_effect(&"feature_unlock", &"set", true, {"featureId": "equipment_inventory"})]
		&"field-pack":
			return [
				_effect(&"feature_unlock", &"set", true, {"featureId": "inventory"}),
				_effect(&"inventory_columns", &"add_flat", 1, {"scope": "profile"}),
			]
		&"stash-access":
			return [
				_effect(&"feature_unlock", &"set", true, {"featureId": "stash"}),
				_effect(&"stash_tabs", &"add_flat", 1, {"scope": "profile", "slotsPerTab": 100}),
				_effect(&"building_discovery", &"set", true, {"buildingId": "warehouse"}),
			]
		&"extraction-license":
			return [
				_effect(&"feature_unlock", &"set", true, {"featureId": "item_extraction"}),
				_effect(&"extraction_capacity", &"add_flat", 1, {"scope": "profile"}),
			]
		&"secured-loadout":
			return [_effect(&"feature_unlock", &"set", true, {"featureId": "bring_in_gear"})]
		&"leader-loadout-extraction":
			return [_effect(&"feature_unlock", &"set", true, {"featureId": "leader_loadout_extraction"})]
		_:
			return []

func _effect(effect_id: StringName, operation: StringName, value: Variant, parameters: Dictionary) -> Dictionary:
	return {
		"effect_id": effect_id,
		"operation": operation,
		"value": value,
		"parameters": parameters.duplicate(true),
	}

func _validate_immediate_route(tree: PassiveTreeDefinition, errors: Array[String]) -> void:
	for pair: Array in IMMEDIATE_ROUTE:
		var from_id := pair[0] as StringName
		var to_id := pair[1] as StringName
		var found := false
		for connection: PassiveTreeConnection in tree.connections:
			if connection.direction != &"bidirectional" or connection.cost != 0 or not connection.conditions.is_empty():
				continue
			if (connection.from_id == from_id and connection.to_id == to_id) or (connection.from_id == to_id and connection.to_id == from_id):
				found = true
				break
		if not found:
			errors.append("%s field=route reason=missing exact immediate edge %s--%s" % [ERROR_PREFIX, from_id, to_id])

func _validate_metadata(tree_node: PassiveTreeNode, errors: Array[String]) -> void:
	var expected := {
		"activationState": "implemented",
		"sourceContentId": String(tree_node.id),
		"sourceGraphId": "city-passive-tree",
		"sourcePlacementId": String(tree_node.id),
		"sourceProjectId": "party-forge-city",
	}
	if tree_node.metadata.size() != expected.size():
		errors.append("%s node=%s field=metadata reason=metadata must contain exactly activation and source provenance" % [ERROR_PREFIX, tree_node.id])
	for key: String in expected:
		if tree_node.metadata.get(key) != expected[key]:
			errors.append("%s node=%s field=%s reason=%s must equal %s" % [ERROR_PREFIX, tree_node.id, key, key, expected[key]])

func _validate_extraction_requirements(tree_node: PassiveTreeNode, errors: Array[String]) -> void:
	var expected := {
		"field-pack": false,
		"stash-access": false,
	}
	for requirement: PassiveTreeRequirement in tree_node.requirements:
		var value := String(requirement.value) if typeof(requirement.value) == TYPE_STRING else ""
		if requirement.requirement_id == &"allocated_node" \
			and requirement.operator == &"contains" \
			and requirement.parameters == {"treeId": "party-forge-city-v1"} \
			and expected.has(value):
			expected[value] = true
	if tree_node.requirements.size() != 2 or not expected["field-pack"] or not expected["stash-access"]:
		errors.append("%s node=extraction-license field=requirements reason=requirements must be exactly allocated_node field-pack and stash-access for party-forge-city-v1" % ERROR_PREFIX)

func _validate_stash_size(tree_node: PassiveTreeNode, errors: Array[String]) -> void:
	var stash_effects: Array[PassiveTreeEffect] = []
	for effect: PassiveTreeEffect in tree_node.effects:
		if effect.effect_id == &"stash_tabs":
			stash_effects.append(effect)
	if stash_effects.size() != 1 \
		or (typeof(stash_effects[0].parameters.get("slotsPerTab")) != TYPE_INT and typeof(stash_effects[0].parameters.get("slotsPerTab")) != TYPE_FLOAT) \
		or float(stash_effects[0].parameters.get("slotsPerTab")) != 100.0:
		errors.append("%s node=stash-access field=slotsPerTab reason=stash tab size must equal integer 100" % ERROR_PREFIX)
