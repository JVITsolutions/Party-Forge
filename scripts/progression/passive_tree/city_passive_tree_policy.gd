class_name CityPassiveTreePolicy
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_CITY_PASSIVE_TREE_ERROR"
const LOGISTICS_IDS: Array[StringName] = [
	&"field-pack", &"stash-access", &"extraction-license", &"secured-loadout",
	&"leader-loadout-extraction",
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
	if tree.nodes.size() != 31:
		errors.append("%s field=nodes reason=City tree must contain exactly 31 nodes" % ERROR_PREFIX)
	if tree.connections.size() != 31:
		errors.append("%s field=connections reason=City tree must contain exactly 31 connections" % ERROR_PREFIX)
	var nodes_by_id: Dictionary = {}
	for tree_node: PassiveTreeNode in tree.nodes:
		nodes_by_id[tree_node.id] = tree_node
	for node_id: StringName in LOGISTICS_IDS:
		if not nodes_by_id.has(node_id):
			errors.append("%s field=nodes reason=City tree requires logistics node %s" % [ERROR_PREFIX, node_id])
			continue
		var logistics_node: PassiveTreeNode = nodes_by_id[node_id]
		_validate_metadata(logistics_node, errors)
	if nodes_by_id.has(&"extraction-license"):
		_validate_extraction_requirements(nodes_by_id[&"extraction-license"], errors)
	if nodes_by_id.has(&"stash-access"):
		_validate_stash_size(nodes_by_id[&"stash-access"], errors)
	return errors

func _validate_metadata(tree_node: PassiveTreeNode, errors: Array[String]) -> void:
	var expected := {
		"integrationStatus": "future-contract",
		"developmentState": "coming-soon",
		"refundPolicy": "permanent",
	}
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
