extends RefCounted

const Adapter = preload("res://scripts/progression/passive_tree/latticewright_runtime_v3_city_adapter.gd")
const Geometry = preload("res://scripts/progression/passive_tree/city_tree_geometry_validator.gd")
const RUNTIME_PATH := "res://data/passive_trees/city/party-forge-city.pstree.json"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_exact_projection(failures)
	_test_root_and_schema_contract(failures)
	_test_graph_identity_and_shape_contract(failures)
	_test_content_placement_and_activation_contract(failures)
	_test_effect_requirement_and_portal_contract(failures)
	_test_geometry_invariants_and_boundaries(failures)
	_test_catalog_dispatch_and_portfolio(failures)
	return failures

func _test_exact_projection(failures: Array[String]) -> void:
	var document := _runtime()
	var result := Adapter.translate(document, RUNTIME_PATH, "runtime-sha")
	TestAssertions.truthy(result.ok(), "exact committed runtime-v3 City document translates", failures)
	TestAssertions.equal(result.errors, [], "exact City translation errors", failures)
	if not result.ok():
		return
	TestAssertions.equal(result.tree.id, &"party-forge-city-v1", "stable domain tree ID", failures)
	TestAssertions.equal(result.tree.name, "Party Forge City", "stable domain tree name", failures)
	TestAssertions.equal(result.tree.starting_node_ids, [&"city-heart"], "stable starting node", failures)
	TestAssertions.equal(result.tree.nodes.size(), 37, "all City nodes project", failures)
	TestAssertions.equal(result.tree.connections.size(), 37, "all City connections project", failures)
	TestAssertions.equal(result.tree.portals.size(), 6, "only district portals project", failures)
	TestAssertions.equal(result.tree.node(&"field-pack").metadata, {
		"activationState": "implemented",
		"sourceContentId": "field-pack",
		"sourceGraphId": "city-passive-tree",
		"sourcePlacementId": "field-pack",
		"sourceProjectId": "party-forge-city",
	}, "node readiness and provenance project exactly", failures)
	TestAssertions.equal(result.tree.node(&"field-pack").effects.size(), 2, "Field Pack effects project", failures)
	TestAssertions.equal(result.tree.node(&"field-pack").effects[0].effect_id, &"feature_unlock", "feature definition maps", failures)
	TestAssertions.equal(result.tree.node(&"field-pack").effects[0].parameters, {"featureId": "inventory"}, "feature values map", failures)
	TestAssertions.equal(result.tree.node(&"field-pack").effects[1].effect_id, &"inventory_columns", "numeric definition maps", failures)
	TestAssertions.equal(result.tree.node(&"field-pack").effects[1].value, 1, "integral numeric value maps as int", failures)
	TestAssertions.equal(result.tree.node(&"extraction-license").requirements.size(), 2, "Extraction License requirements project", failures)
	var portal := result.tree.portal_for_source_node(&"logistics-district-charter")
	TestAssertions.truthy(portal != null, "Logistics district portal projects", failures)
	if portal != null:
		TestAssertions.equal(portal.target_project_id, &"party-forge-building-warehouse", "portal target project", failures)
		TestAssertions.equal(portal.target_graph_id, &"warehouse-passive-tree", "portal target graph", failures)
		TestAssertions.equal(portal.discovered_tree_id, &"party-forge-warehouse-v1", "portal discovery effect target", failures)
	TestAssertions.equal(result.tree.metadata, {
		"sourceFormat": "latticewright-progression",
		"sourceFormatVersion": 3,
		"sourceGraphId": "city-passive-tree",
		"sourcePath": RUNTIME_PATH,
		"sourceProjectId": "party-forge-city",
		"sourceSha256": "runtime-sha",
	}, "tree source provenance projects exactly", failures)

	document["projectId"] = "mutated"
	(document["content"] as Array).clear()
	TestAssertions.equal(result.tree.metadata["sourceProjectId"], "party-forge-city", "translation is isolated from source mutation", failures)
	TestAssertions.equal(result.tree.nodes.size(), 37, "source mutation cannot rewrite projected nodes", failures)

func _test_root_and_schema_contract(failures: Array[String]) -> void:
	_assert_invalid_change(["projectId"], "wrong-city", "root identity is exact", "projectId", failures)
	_assert_invalid_change(["name"], "Other City", "root name is exact", "name", failures)
	_assert_invalid_change(["archetype"], "other", "root archetype is exact", "archetype", failures)
	var extra_extension := _runtime()
	(extra_extension["extensions"] as Dictionary)["extra"] = true
	_assert_invalid(extra_extension, "unexpected root extension rejects", "extensions", failures)
	_assert_invalid_change(["extensions", "partyForgeStatus"], "authoring-design-data", "root status is exact", "extensions", failures)
	var asset := _runtime()
	(asset["assets"] as Array).append({"id": "unexpected"})
	_assert_invalid(asset, "City runtime assets must stay empty", "assets", failures)

	_assert_invalid_change(["schemas", "fields", 0, "id"], "wrong-field", "field definitions are exact", "schemas", failures)
	_assert_invalid_change(["schemas", "placementTypes", 0, "shape"], "custom", "placement definitions are exact", "schemas", failures)
	_assert_invalid_change(["schemas", "effects", 0, "id"], "unknown-effect", "effect definitions are exact", "schemas", failures)
	_assert_invalid_change(["schemas", "requirements", 0, "id"], "unknown-requirement", "requirement definitions are exact", "schemas", failures)
	var extra_schema_key := _runtime()
	(extra_schema_key["schemas"] as Dictionary)["extra"] = []
	_assert_invalid(extra_schema_key, "unexpected schema section rejects", "schemas", failures)

func _test_graph_identity_and_shape_contract(failures: Array[String]) -> void:
	var extra_graph := _runtime()
	(extra_graph["graphs"] as Array).append((extra_graph["graphs"] as Array)[0].duplicate(true))
	_assert_invalid(extra_graph, "City has exactly one graph", "graphs", failures)
	_assert_invalid_change(["graphs", 0, "id"], "wrong-graph", "City graph ID is exact", "graph.id", failures)
	_assert_invalid_change(["graphs", 0, "name"], "Other Tree", "City graph name is exact", "graph.name", failures)
	_assert_invalid_change(["graphs", 0, "startingPlacementIds", 0], "field-pack", "City start is exact", "startingPlacementIds", failures)
	var extra_start := _runtime()
	(extra_start["graphs"] as Array)[0]["startingPlacementIds"].append("field-pack")
	_assert_invalid(extra_start, "City has one start", "startingPlacementIds", failures)
	var missing_content := _runtime()
	(missing_content["content"] as Array).remove_at(0)
	_assert_invalid(missing_content, "City content count is exact", "37 content", failures)
	var missing_placement := _runtime()
	((missing_placement["graphs"] as Array)[0]["placements"] as Array).remove_at(0)
	_assert_invalid(missing_placement, "City placement count is exact", "37 placements", failures)
	var missing_connection := _runtime()
	((missing_connection["graphs"] as Array)[0]["connections"] as Array).remove_at(0)
	_assert_invalid(missing_connection, "City connection count is exact", "37 connections", failures)

func _test_content_placement_and_activation_contract(failures: Array[String]) -> void:
	var duplicate_content := _runtime()
	(duplicate_content["content"] as Array)[1]["id"] = (duplicate_content["content"] as Array)[0]["id"]
	_assert_invalid(duplicate_content, "duplicate content IDs reject", "duplicate content", failures)
	var duplicate_placement := _runtime()
	var placements := (duplicate_placement["graphs"] as Array)[0]["placements"] as Array
	placements[1]["id"] = placements[0]["id"]
	_assert_invalid(duplicate_placement, "duplicate placement IDs reject", "duplicate placement", failures)
	var duplicate_connection := _runtime()
	var connections := (duplicate_connection["graphs"] as Array)[0]["connections"] as Array
	connections[1]["id"] = connections[0]["id"]
	_assert_invalid(duplicate_connection, "duplicate connection IDs reject", "duplicate connection", failures)

	var wrong_content_link := _runtime()
	((wrong_content_link["graphs"] as Array)[0]["placements"] as Array)[0]["contentId"] = "city-heart"
	_assert_invalid(wrong_content_link, "content placement mapping is one-to-one", "contentId", failures)
	var fractional_cost := _runtime()
	((fractional_cost["graphs"] as Array)[0]["placements"] as Array)[0]["fieldValues"]["node-cost"] = 1.5
	_assert_invalid(fractional_cost, "fractional point cost rejects", "node-cost", failures)
	var negative_cost := _runtime()
	((negative_cost["graphs"] as Array)[0]["placements"] as Array)[0]["fieldValues"]["node-cost"] = -1
	_assert_invalid(negative_cost, "negative point cost rejects", "node-cost", failures)
	var non_finite_position := _runtime()
	((non_finite_position["graphs"] as Array)[0]["placements"] as Array)[0]["position"]["x"] = INF
	_assert_invalid(non_finite_position, "non-finite coordinate rejects", "position.x", failures)
	var unsupported_shape := _runtime()
	((unsupported_shape["graphs"] as Array)[0]["placements"] as Array)[0]["typeId"] = "custom-node"
	_assert_invalid(unsupported_shape, "unsupported placement shape rejects", "typeId", failures)

	var unknown_activation := _runtime()
	_find_content(unknown_activation, "field-pack")["fieldValues"]["party-forge-activation-state"] = "available"
	_assert_invalid(unknown_activation, "unknown activation state rejects", "activationState", failures)
	var wrong_activation := _runtime()
	_find_content(wrong_activation, "field-pack")["fieldValues"]["party-forge-activation-state"] = "future"
	_assert_invalid(wrong_activation, "authored activation assignment is exact", "field-pack", failures)

func _test_effect_requirement_and_portal_contract(failures: Array[String]) -> void:
	var unknown_effect := _runtime()
	(_find_content(unknown_effect, "field-pack")["effects"] as Array)[0]["definitionId"] = "unknown-effect"
	_assert_invalid(unknown_effect, "unknown effect definition rejects", "unknown effect", failures)
	var missing_effect_value := _runtime()
	(_find_content(missing_effect_value, "field-pack")["effects"] as Array)[1]["values"].erase("amount")
	_assert_invalid(missing_effect_value, "missing effect value rejects", "values", failures)
	var extra_effect_value := _runtime()
	(_find_content(extra_effect_value, "field-pack")["effects"] as Array)[1]["values"]["extra"] = true
	_assert_invalid(extra_effect_value, "extra effect value rejects", "values", failures)
	var fractional_effect := _runtime()
	(_find_content(fractional_effect, "field-pack")["effects"] as Array)[1]["values"]["amount"] = 1.5
	_assert_invalid(fractional_effect, "fractional domain amount rejects", "integer", failures)
	var wrong_scope := _runtime()
	(_find_content(wrong_scope, "field-pack")["effects"] as Array)[1]["values"]["scope"] = "party"
	_assert_invalid(wrong_scope, "invalid effect scope rejects", "scope", failures)
	var invalid_feature_id := _runtime()
	(_find_content(invalid_feature_id, "field-pack")["effects"] as Array)[0]["values"]["feature-id"] = "Bad Feature"
	_assert_invalid(invalid_feature_id, "invalid stable feature ID rejects", "feature-id", failures)

	var unknown_requirement := _runtime()
	(_find_content(unknown_requirement, "extraction-license")["requirements"] as Array)[0]["definitionId"] = "unknown-requirement"
	_assert_invalid(unknown_requirement, "unknown requirement definition rejects", "unknown requirement", failures)
	var missing_requirement_value := _runtime()
	(_find_content(missing_requirement_value, "extraction-license")["requirements"] as Array)[0]["values"].erase("node-id")
	_assert_invalid(missing_requirement_value, "missing requirement value rejects", "values", failures)
	var extra_requirement_value := _runtime()
	(_find_content(extra_requirement_value, "extraction-license")["requirements"] as Array)[0]["values"]["extra"] = true
	_assert_invalid(extra_requirement_value, "extra requirement value rejects", "values", failures)
	var one_extraction_requirement := _runtime()
	(_find_content(one_extraction_requirement, "extraction-license")["requirements"] as Array).remove_at(0)
	_assert_invalid(one_extraction_requirement, "Extraction License keeps two exact requirements", "extraction-license", failures)

	var missing_portal := _runtime()
	(missing_portal["graphPortals"] as Array).remove_at(0)
	_assert_invalid(missing_portal, "all six district portals are required", "6 portals", failures)
	var extra_portal := _runtime()
	(extra_portal["graphPortals"] as Array).append((extra_portal["graphPortals"] as Array)[0].duplicate(true))
	_assert_invalid(extra_portal, "extra district portal rejects", "6 portals", failures)
	var wrong_portal_target := _runtime()
	(wrong_portal_target["graphPortals"] as Array)[0]["targetProjectId"] = "wrong-project"
	_assert_invalid(wrong_portal_target, "district portal target is exact", "portal", failures)
	var portal_effect_mismatch := _runtime()
	(_find_content(portal_effect_mismatch, "logistics-district-charter")["effects"] as Array)[0]["values"]["tree-id"] = "wrong-tree"
	_assert_invalid(portal_effect_mismatch, "charter effect matches portal discovery", "portal/effect", failures)

func _test_geometry_invariants_and_boundaries(failures: Array[String]) -> void:
	_assert_geometry_valid(
		[_node("a", Vector2.ZERO), _node("b", Vector2(104.0, 0.0))],
		[],
		"exact 12-pixel node clearance is valid",
		failures,
	)
	_assert_geometry_invalid(
		[_node("a", Vector2.ZERO), _node("b", Vector2(103.999, 0.0))],
		[],
		"node_clearance",
		"just-under node clearance rejects",
		failures,
	)

	var edge_nodes := [_node("a", Vector2(-200.0, 0.0)), _node("b", Vector2(200.0, 0.0)), _node("c", Vector2(0.0, 25.0))]
	_assert_geometry_valid(edge_nodes, [_connection("edge", "a", "b")], "exact 8-pixel protected corridor is valid", failures)
	edge_nodes[2] = _node("c", Vector2(0.0, 24.999))
	_assert_geometry_invalid(edge_nodes, [_connection("edge", "a", "b")], "edge_node_clearance", "just-under edge clearance rejects", failures)

	var crossing_nodes := [
		_node("a", Vector2(-100.0, -100.0)), _node("b", Vector2(100.0, 100.0)),
		_node("c", Vector2(-100.0, 100.0)), _node("d", Vector2(100.0, -100.0)),
	]
	_assert_geometry_invalid(crossing_nodes, [_connection("first", "a", "b"), _connection("second", "c", "d")], "edge_crossing", "proper edge crossing rejects", failures)

	var exact_angle := deg_to_rad(86.0)
	var exact_nodes := [_node("j", Vector2.ZERO), _node("a", Vector2(200.0, 0.0)), _node("b", Vector2(200.0 * cos(exact_angle), 200.0 * sin(exact_angle)))]
	_assert_geometry_invalid(exact_nodes, [_connection("first", "j", "a"), _connection("second", "j", "b")], "perpendicular_junction", "exact four-degree exclusion boundary rejects", failures)
	var outside_angle := deg_to_rad(85.999)
	var outside_nodes := [_node("j", Vector2.ZERO), _node("a", Vector2(200.0, 0.0)), _node("b", Vector2(200.0 * cos(outside_angle), 200.0 * sin(outside_angle)))]
	_assert_geometry_valid(outside_nodes, [_connection("first", "j", "a"), _connection("second", "j", "b")], "just outside perpendicular exclusion is valid", failures)

func _test_catalog_dispatch_and_portfolio(failures: Array[String]) -> void:
	var portfolio := LatticewrightRuntimePortfolioRegistry.new()
	var first := PassiveTreeCatalog.load_defaults(portfolio)
	TestAssertions.truthy(first.ok(), "default catalog loads only through runtime-v3 adapter", failures)
	TestAssertions.truthy(portfolio.has_graph(&"party-forge-city", &"city-passive-tree"), "catalog separately registers raw runtime in portfolio", failures)
	if first.ok():
		first.tree.nodes.clear()
	var second := PassiveTreeCatalog.load_defaults()
	TestAssertions.truthy(second.ok(), "catalog reload is independent after caller mutation", failures)
	if second.ok():
		TestAssertions.equal(second.tree.nodes.size(), 37, "catalog caches no partial tree", failures)
		TestAssertions.truthy(first.tree != second.tree, "catalog returns independent definitions", failures)

	var legacy_path := "user://legacy-format-one-passive-tree.json"
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"format": "passive-skill-tree",
		"formatVersion": 1,
		"treeId": "legacy-tree",
		"name": "Legacy Tree",
		"startingNodeIds": ["root"],
		"nodes": [{
			"id": "root", "type": "start", "position": {"x": 0, "y": 0},
			"name": "Root", "description": "Legacy.", "cost": 0, "tags": [],
			"icon": null, "effects": [], "requirements": [], "metadata": {},
		}],
		"connections": [],
		"metadata": {},
	}))
	file.close()
	var legacy := PassiveTreeCatalog.load_path(legacy_path)
	TestAssertions.truthy(not legacy.ok(), "catalog rejects an otherwise valid format-1 document", failures)
	TestAssertions.equal(legacy.tree, null, "legacy document is fail-closed", failures)
	TestAssertions.truthy(legacy.errors.any(func(error: String) -> bool: return "HEADER_ERROR" in error), "legacy rejection occurs at versioned header boundary", failures)

	var semantic_failure_document := _runtime()
	(((semantic_failure_document["graphs"] as Array)[0]["connections"] as Array)[0] as Dictionary)["cost"] = 1
	var semantic_failure_path := "user://semantic-failure-city-runtime.json"
	var semantic_file := FileAccess.open(semantic_failure_path, FileAccess.WRITE)
	semantic_file.store_string(JSON.stringify(semantic_failure_document))
	semantic_file.close()
	var failed_portfolio := LatticewrightRuntimePortfolioRegistry.new()
	var semantic_failure := PassiveTreeCatalog.load_path(semantic_failure_path, failed_portfolio)
	TestAssertions.truthy(not semantic_failure.ok(), "catalog semantic failure remains fail-closed", failures)
	TestAssertions.truthy(not failed_portfolio.has_graph(&"party-forge-city", &"city-passive-tree"), "failed catalog load does not mutate portfolio availability", failures)

	var conflicting_runtime := _runtime()
	(conflicting_runtime["graphs"] as Array)[0]["id"] = "conflicting-graph"
	var conflicting_portfolio := LatticewrightRuntimePortfolioRegistry.new()
	TestAssertions.equal(conflicting_portfolio.register_runtime(conflicting_runtime), "", "conflicting project fixture registers", failures)
	var registration_failure := PassiveTreeCatalog.load_defaults(conflicting_portfolio)
	TestAssertions.truthy(not registration_failure.ok(), "portfolio registration rejection fails catalog load", failures)
	TestAssertions.equal(registration_failure.tree, null, "registration rejection exposes no partial tree", failures)
	TestAssertions.truthy(registration_failure.errors.any(func(error: String) -> bool: return "PORTFOLIO_REGISTRATION_ERROR" in error), "registration rejection is diagnostic", failures)
	TestAssertions.truthy(not conflicting_portfolio.has_graph(&"party-forge-city", &"city-passive-tree"), "conflicting portfolio remains unchanged", failures)

func _runtime() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(RUNTIME_PATH)) as Dictionary

func _find_content(document: Dictionary, content_id: String) -> Dictionary:
	for value: Variant in document.get("content", []):
		if value is Dictionary and (value as Dictionary).get("id") == content_id:
			return value as Dictionary
	return {}

func _assert_invalid_change(path: Array, replacement: Variant, label: String, fragment: String, failures: Array[String]) -> void:
	var document := _runtime()
	var target: Variant = document
	for index: int in range(path.size() - 1):
		target = target[path[index]]
	target[path[-1]] = replacement
	_assert_invalid(document, label, fragment, failures)

func _assert_invalid(document: Dictionary, label: String, fragment: String, failures: Array[String]) -> void:
	var result := Adapter.translate(document, "memory://invalid", "hash")
	TestAssertions.truthy(not result.ok(), label, failures)
	TestAssertions.equal(result.tree, null, "%s is fail-closed" % label, failures)
	TestAssertions.truthy(result.errors.any(func(error: String) -> bool: return fragment in error), "%s reports %s" % [label, fragment], failures)

func _node(id: String, position: Vector2) -> PassiveTreeNode:
	return PassiveTreeNode.new(StringName(id), &"small", position)

func _connection(id: String, from_id: String, to_id: String) -> PassiveTreeConnection:
	return PassiveTreeConnection.new(StringName(id), StringName(from_id), StringName(to_id), &"bidirectional")

func _assert_geometry_valid(nodes: Array, connections: Array, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(Geometry.validate(nodes, connections), [], label, failures)

func _assert_geometry_invalid(nodes: Array, connections: Array, fragment: String, label: String, failures: Array[String]) -> void:
	var errors: Array[String] = Geometry.validate(nodes, connections)
	TestAssertions.truthy(not errors.is_empty(), label, failures)
	TestAssertions.truthy(errors.any(func(error: String) -> bool: return fragment in error), "%s reports %s" % [label, fragment], failures)
