extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_PASSIVE_TREE_ERROR path="

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_record_constructors_copy_variant_collections(failures)
	_test_valid_dictionary_builds_typed_copies(failures)
	_test_production_city_artifact(failures)
	_test_root_contract(failures)
	_test_node_contract(failures)
	_test_effect_and_requirement_shapes(failures)
	_test_connection_contract(failures)
	_test_load_path_shapes(failures)
	_test_collects_all_errors_and_fails_closed(failures)
	return failures

func _test_record_constructors_copy_variant_collections(failures: Array[String]) -> void:
	var effect_value := [1, {"nested": true}]
	var effect_parameters := {"scope": ["profile"]}
	var effect := PassiveTreeEffect.new(&"effect", &"custom", effect_value, effect_parameters)
	effect_value.append(2)
	(effect_parameters["scope"] as Array).append("mutated")
	TestAssertions.equal(effect.value, [1, {"nested": true}], "effect copies collection value", failures)
	TestAssertions.equal(effect.parameters, {"scope": ["profile"]}, "effect copies nested parameters", failures)

	var requirement_value := {"allocated": ["root"]}
	var requirement := PassiveTreeRequirement.new(&"requirement", &"contains", requirement_value, {})
	(requirement_value["allocated"] as Array).append("mutated")
	TestAssertions.equal(requirement.value, {"allocated": ["root"]}, "requirement copies collection value", failures)

func _test_valid_dictionary_builds_typed_copies(failures: Array[String]) -> void:
	var document := _valid_document()
	var result := PassiveTreeLoader.new().load_dictionary(document, "memory://valid")
	TestAssertions.truthy(result.ok(), "valid version-1 dictionary loads", failures)
	if not result.ok():
		return
	TestAssertions.equal(result.tree.id, &"test-tree", "typed tree ID", failures)
	TestAssertions.equal(result.tree.starting_node_ids, [&"root"], "typed starting IDs", failures)
	TestAssertions.equal(result.tree.node(&"leaf").position, Vector2(12.5, -7.0), "typed node position", failures)
	TestAssertions.equal(result.tree.node(&"leaf").effects[0].effect_id, &"test_effect", "typed effect ID", failures)
	TestAssertions.equal(result.tree.node(&"leaf").requirements[0].requirement_id, &"allocated_node", "typed requirement ID", failures)
	TestAssertions.equal(result.tree.connection(&"edge").from_id, &"root", "typed connection endpoint", failures)
	TestAssertions.equal(result.tree.node(&"missing"), null, "unknown node lookup", failures)
	TestAssertions.equal(result.tree.connection(&"missing"), null, "unknown connection lookup", failures)

	(document["startingNodeIds"] as Array).append("leaf")
	(document["nodes"] as Array)[1]["tags"].append("mutated")
	(document["nodes"] as Array)[1]["effects"][0]["parameters"]["scope"] = "mutated"
	(document["metadata"] as Dictionary)["owner"] = "mutated"
	TestAssertions.equal(result.tree.starting_node_ids, [&"root"], "tree copies starting IDs", failures)
	TestAssertions.equal(result.tree.node(&"leaf").tags, [&"test"], "node copies tags", failures)
	TestAssertions.equal(result.tree.node(&"leaf").effects[0].parameters.get("scope"), "profile", "effect copies parameters", failures)
	TestAssertions.equal(result.tree.metadata.get("owner"), "fixture", "tree copies metadata", failures)

func _test_production_city_artifact(failures: Array[String]) -> void:
	var result := PassiveTreeLoader.new().load_path("res://data/passive_trees/city/party-forge-city.pstree.json")
	TestAssertions.truthy(result.ok(), "City runtime loads structurally", failures)
	TestAssertions.equal(result.errors, [], "City structural errors", failures)
	if not result.ok():
		return
	TestAssertions.equal(result.tree.id, &"party-forge-city-v1", "tree ID", failures)
	TestAssertions.equal(result.tree.nodes.size(), 30, "node count", failures)
	TestAssertions.equal(result.tree.connections.size(), 30, "connection count", failures)

func _test_root_contract(failures: Array[String]) -> void:
	_assert_invalid_change(["format"], "other", "format must be exact", "format", failures)
	_assert_invalid_change(["formatVersion"], 2, "version must be exact", "formatVersion", failures)
	_assert_invalid_change(["formatVersion"], 1.5, "version must be an exact integer value", "formatVersion", failures)
	_assert_invalid_change(["treeId"], "", "tree ID must be non-empty", "treeId", failures)
	_assert_invalid_change(["name"], "  ", "tree name must be non-empty", "name", failures)
	_assert_invalid_change(["startingNodeIds"], {}, "starting IDs must be an array", "startingNodeIds", failures)
	_assert_invalid_change(["nodes"], {}, "nodes must be an array", "nodes", failures)
	_assert_invalid_change(["connections"], {}, "connections must be an array", "connections", failures)
	_assert_invalid_change(["metadata"], [], "tree metadata must be an object", "metadata", failures)
	_assert_invalid_change(["startingNodeIds", 0], "missing", "starting endpoint must exist", "startingNodeIds[0]", failures)
	_assert_invalid_change(["startingNodeIds", 0], "leaf", "starting node must have start type", "type=start", failures)

func _test_node_contract(failures: Array[String]) -> void:
	_assert_invalid_change(["nodes", 0, "id"], "", "node ID must be non-empty", "nodes[0].id", failures)
	_assert_invalid_change(["nodes", 0, "name"], "", "node name must be non-empty", "nodes[0].name", failures)
	_assert_invalid_change(["nodes", 0, "type"], "", "node type must be non-empty", "nodes[0].type", failures)
	_assert_invalid_change(["nodes", 0, "position"], [], "position must be an object", "nodes[0].position", failures)
	_assert_invalid_change(["nodes", 0, "position", "x"], NAN, "position must be finite", "position.x", failures)
	_assert_invalid_change(["nodes", 0, "position", "y"], INF, "position infinity rejected", "position.y", failures)
	_assert_invalid_change(["nodes", 0, "cost"], -1, "node cost must be non-negative", "nodes[0].cost", failures)
	_assert_invalid_change(["nodes", 0, "cost"], 1.5, "node cost must be integer", "nodes[0].cost", failures)
	_assert_invalid_change(["nodes", 0, "tags"], {}, "tags must be an array", "nodes[0].tags", failures)
	_assert_invalid_change(["nodes", 0, "metadata"], [], "node metadata must be an object", "nodes[0].metadata", failures)

	var duplicate := _valid_document()
	(duplicate["nodes"] as Array)[1]["id"] = "root"
	_assert_invalid(duplicate, "duplicate node IDs rejected", "duplicate node id", failures)

func _test_effect_and_requirement_shapes(failures: Array[String]) -> void:
	_assert_invalid_change(["nodes", 1, "effects"], {}, "effects must be an array", "effects", failures)
	_assert_invalid_change(["nodes", 1, "effects", 0], [], "effect must be an object", "effects[0]", failures)
	_assert_invalid_change(["nodes", 1, "effects", 0, "effectId"], "", "effect ID must be non-empty", "effectId", failures)
	_assert_invalid_change(["nodes", 1, "effects", 0, "operation"], "subtract", "unsupported operation rejected", "operation", failures)
	_assert_invalid_change(["nodes", 1, "effects", 0, "parameters"], [], "effect parameters must be an object", "parameters", failures)
	_assert_invalid_change(["nodes", 1, "requirements"], {}, "requirements must be an array", "requirements", failures)
	_assert_invalid_change(["nodes", 1, "requirements", 0], [], "requirement must be an object", "requirements[0]", failures)
	_assert_invalid_change(["nodes", 1, "requirements", 0, "requirementId"], "", "requirement ID must be non-empty", "requirementId", failures)
	_assert_invalid_change(["nodes", 1, "requirements", 0, "operator"], "", "requirement operator must be non-empty", "operator", failures)
	_assert_invalid_change(["nodes", 1, "requirements", 0, "parameters"], [], "requirement parameters must be an object", "parameters", failures)

	for operation: String in ["add_flat", "add_percent", "multiply", "set", "custom"]:
		var document := _valid_document()
		(document["nodes"] as Array)[1]["effects"][0]["operation"] = operation
		TestAssertions.truthy(PassiveTreeLoader.new().load_dictionary(document, "memory://%s" % operation).ok(), "%s operation is structurally accepted" % operation, failures)

func _test_connection_contract(failures: Array[String]) -> void:
	_assert_invalid_change(["connections", 0, "id"], "", "connection ID must be non-empty", "connections[0].id", failures)
	_assert_invalid_change(["connections", 0, "from"], "missing", "from endpoint must exist", ".from", failures)
	_assert_invalid_change(["connections", 0, "to"], "missing", "to endpoint must exist", ".to", failures)
	_assert_invalid_change(["connections", 0, "to"], "root", "self-edge rejected", "self-edge", failures)
	_assert_invalid_change(["connections", 0, "direction"], "backward", "invalid direction rejected", "direction", failures)
	_assert_invalid_change(["connections", 0, "cost"], -1, "connection cost must be non-negative", "connections[0].cost", failures)
	_assert_invalid_change(["connections", 0, "cost"], 0.5, "connection cost must be integer", "connections[0].cost", failures)
	_assert_invalid_change(["connections", 0, "conditions"], {}, "conditions must be an array", "conditions", failures)
	_assert_invalid_change(["connections", 0, "metadata"], [], "connection metadata must be an object", "metadata", failures)

	var duplicate_id := _valid_document()
	(duplicate_id["connections"] as Array).append((duplicate_id["connections"] as Array)[0].duplicate(true))
	_assert_invalid(duplicate_id, "duplicate connection IDs rejected", "duplicate connection id", failures)

	var duplicate_endpoints := _valid_document()
	var reverse: Dictionary = (duplicate_endpoints["connections"] as Array)[0].duplicate(true)
	reverse["id"] = "reverse-edge"
	reverse["from"] = "leaf"
	reverse["to"] = "root"
	(duplicate_endpoints["connections"] as Array).append(reverse)
	_assert_invalid(duplicate_endpoints, "duplicate unordered endpoints rejected", "duplicate endpoint pair", failures)

	for direction: String in ["bidirectional", "forward"]:
		var document := _valid_document()
		(document["connections"] as Array)[0]["direction"] = direction
		TestAssertions.truthy(PassiveTreeLoader.new().load_dictionary(document, "memory://%s" % direction).ok(), "%s direction is accepted" % direction, failures)

func _test_load_path_shapes(failures: Array[String]) -> void:
	var array_path := "user://passive-tree-array.json"
	var malformed_path := "user://passive-tree-malformed.json"
	_write_text(array_path, "[]")
	_write_text(malformed_path, "{")
	_assert_result_invalid(PassiveTreeLoader.new().load_path(array_path), "JSON root array rejected", "JSON object", failures)
	_assert_result_invalid(PassiveTreeLoader.new().load_path(malformed_path), "malformed JSON rejected", "valid JSON", failures)
	_assert_result_invalid(PassiveTreeLoader.new().load_path("user://missing-passive-tree.json"), "missing path rejected", "read", failures)

func _test_collects_all_errors_and_fails_closed(failures: Array[String]) -> void:
	var document := _valid_document()
	document["format"] = "wrong"
	document["treeId"] = ""
	(document["nodes"] as Array)[0]["cost"] = -1
	(document["connections"] as Array)[0]["direction"] = "wrong"
	var result := PassiveTreeLoader.new().load_dictionary(document, "memory://many")
	TestAssertions.truthy(not result.ok(), "invalid document does not report ok", failures)
	TestAssertions.equal(result.tree, null, "any structural error suppresses the partial tree", failures)
	TestAssertions.truthy(result.errors.size() >= 4, "all independent structural errors are collected", failures)
	for error: String in result.errors:
		TestAssertions.truthy(error.begins_with("%smemory://many" % ERROR_PREFIX), "every error has the stable source prefix", failures)

func _valid_document() -> Dictionary:
	return {
		"format": "passive-skill-tree",
		"formatVersion": 1,
		"treeId": "test-tree",
		"name": "Test Tree",
		"startingNodeIds": ["root"],
		"nodes": [
			{
				"id": "root", "type": "start", "position": {"x": 0, "y": 0},
				"name": "Root", "description": "Start here.", "cost": 0,
				"tags": ["test", "start"], "icon": null, "effects": [], "requirements": [],
				"metadata": {"kind": "fixture"},
			},
			{
				"id": "leaf", "type": "small", "position": {"x": 12.5, "y": -7},
				"name": "Leaf", "description": "Continue here.", "cost": 1,
				"tags": ["test"], "icon": null,
				"effects": [{"effectId": "test_effect", "operation": "custom", "value": 3, "parameters": {"scope": "profile"}}],
				"requirements": [{"requirementId": "allocated_node", "operator": "contains", "value": "root", "parameters": {"treeId": "test-tree"}}],
				"metadata": {"kind": "fixture"},
			},
		],
		"connections": [{
			"id": "edge", "from": "root", "to": "leaf", "direction": "bidirectional", "cost": 0,
			"conditions": [], "metadata": {"kind": "fixture"},
		}],
		"metadata": {"owner": "fixture"},
	}

func _assert_invalid_change(path: Array, replacement: Variant, label: String, fragment: String, failures: Array[String]) -> void:
	var document := _valid_document()
	var target: Variant = document
	for index: int in range(path.size() - 1):
		target = target[path[index]]
	target[path[-1]] = replacement
	_assert_invalid(document, label, fragment, failures)

func _assert_invalid(document: Dictionary, label: String, fragment: String, failures: Array[String]) -> void:
	_assert_result_invalid(PassiveTreeLoader.new().load_dictionary(document, "memory://invalid"), label, fragment, failures)

func _assert_result_invalid(result: PassiveTreeLoadResult, label: String, fragment: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not result.ok(), label, failures)
	TestAssertions.equal(result.tree, null, "%s is fail-closed" % label, failures)
	TestAssertions.truthy(result.errors.any(func(error: String) -> bool: return fragment in error), "%s reports %s" % [label, fragment], failures)

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
