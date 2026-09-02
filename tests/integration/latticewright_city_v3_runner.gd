extends SceneTree

const RUNTIME_PATH := "res://data/passive_trees/city/party-forge-city.pstree.json"
const RUNTIME_SHA256 := "0eeb487e8f30b9b1ae975b9345ca0504759de4ec417b2bb2e710e7aad85f2425"
const IMPLEMENTED_IDS: Array[StringName] = [
	&"city-heart", &"equipment-registry", &"extraction-license", &"field-pack",
	&"leader-loadout-extraction", &"secured-loadout", &"stash-access",
]
const PORTAL_CONTRACTS := {
	&"city-to-expedition-district": [&"expedition-district-charter", "Open Expedition District", &"party-forge-expedition-district", &"expedition-district-passive-tree", &"party-forge-expedition-district-v1"],
	&"city-to-forge-district": [&"forge-district-charter", "Open Forge District", &"party-forge-forge-district", &"forge-district-passive-tree", &"party-forge-forge-district-v1"],
	&"city-to-hero-district": [&"hero-district-charter", "Open Hero District", &"party-forge-hero-district", &"hero-district-passive-tree", &"party-forge-hero-district-v1"],
	&"city-to-logistics-district": [&"logistics-district-charter", "Open Logistics District", &"party-forge-building-warehouse", &"warehouse-passive-tree", &"party-forge-warehouse-v1"],
	&"city-to-market-district": [&"market-district-charter", "Open Market District", &"party-forge-market-district", &"market-district-passive-tree", &"party-forge-market-district-v1"],
	&"city-to-trials-district": [&"trials-district-charter", "Open Trials District", &"party-forge-trials-district", &"trials-district-passive-tree", &"party-forge-trials-district-v1"],
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var portfolio := LatticewrightRuntimePortfolioRegistry.new()
	var loaded := PassiveTreeCatalog.load_defaults(portfolio)
	_assert(loaded.ok(), "production catalog loads the committed City runtime-v3 document")
	_assert(loaded.source_path == RUNTIME_PATH and loaded.source_sha256 == RUNTIME_SHA256, "production reader exposes the exact committed runtime path and SHA-256")
	_assert(int(loaded.source_document.get("formatVersion", 0)) == 3, "source document is format 3")
	_assert(loaded.source_document.get("projectId", "") == "party-forge-city", "source project identity is exact")
	_assert(portfolio.has_graph(&"party-forge-city", &"city-passive-tree"), "production catalog registers the exact City graph in the runtime portfolio")
	if not loaded.ok():
		_finish()
		return

	var tree := loaded.tree
	_assert(tree.id == &"party-forge-city-v1" and tree.starting_node_ids == [&"city-heart"], "domain identity and sole starting node are exact")
	_assert(tree.nodes.size() == 37 and tree.connections.size() == 37 and tree.portals.size() == 6, "City projects exactly 37 nodes, 37 connections, and six portals")
	_assert(tree.metadata == {
		"sourceFormat": "latticewright-progression",
		"sourceFormatVersion": 3,
		"sourceGraphId": "city-passive-tree",
		"sourcePath": RUNTIME_PATH,
		"sourceProjectId": "party-forge-city",
		"sourceSha256": RUNTIME_SHA256,
	}, "adapted tree retains exact runtime-v3 provenance")

	var activation_counts := {"implemented": 0, "portal-gated": 0, "future": 0}
	var actual_implemented: Array[StringName] = []
	for tree_node: PassiveTreeNode in tree.nodes:
		var state := String(tree_node.metadata.get("activationState", ""))
		activation_counts[state] = int(activation_counts.get(state, 0)) + 1
		if state == "implemented":
			actual_implemented.append(tree_node.id)
	actual_implemented.sort()
	var expected_implemented := IMPLEMENTED_IDS.duplicate()
	expected_implemented.sort()
	_assert(activation_counts == {"implemented": 7, "portal-gated": 6, "future": 24}, "activation states are exactly seven implemented, six portal-gated, and 24 future")
	_assert(actual_implemented == expected_implemented, "only the approved seven City nodes are implemented")
	_assert(CityPassiveTreePolicy.new().validate(tree).is_empty(), "approved live effects, requirements, costs, and route validate")
	_assert(CityTreeGeometryValidator.validate(tree.nodes, tree.connections).is_empty(), "runtime graph has no overlap, crossing, edge-node collision, or perpendicular junction")

	var seen_portals: Array[StringName] = []
	for portal: PassiveTreePortal in tree.portals:
		seen_portals.append(portal.id)
		var contract := PORTAL_CONTRACTS.get(portal.id, []) as Array
		_assert(contract.size() == 5, "portal %s is approved" % portal.id)
		if contract.size() != 5:
			continue
		_assert([
			portal.source_node_id, portal.label, portal.target_project_id,
			portal.target_graph_id, portal.discovered_tree_id,
		] == contract, "portal %s matches its exact charter and destination" % portal.id)
		var charter := tree.node(portal.source_node_id)
		_assert(charter != null and charter.metadata.get("activationState") == "portal-gated", "portal %s source is portal-gated" % portal.id)
		_assert(charter != null and charter.effects.size() == 1 and charter.effects[0].effect_id == &"tree_discovery" and charter.effects[0].parameters.get("treeId") == String(portal.discovered_tree_id), "portal %s charter discovers only its district tree" % portal.id)
	seen_portals.sort()
	var expected_portals: Array[StringName] = []
	for portal_id: StringName in PORTAL_CONTRACTS:
		expected_portals.append(portal_id)
	expected_portals.sort()
	_assert(seen_portals == expected_portals, "all and only the six approved district portals project")

	var registry := LatticewrightRuntimeAdapterRegistry.new()
	_assert(registry.register_adapter(3, Callable(LatticewrightRuntimeV3CityAdapter, "translate")), "runtime-v3 adapter registers")
	var obsolete := loaded.source_document.duplicate(true)
	obsolete["formatVersion"] = 1
	var rejected := registry.load_document(obsolete, "memory://obsolete-city-v1", "obsolete")
	_assert(not rejected.ok() and rejected.tree == null and rejected.errors.size() == 1 and rejected.errors[0].contains("format_version=1") and rejected.errors[0].contains("adapter unavailable"), "obsolete format 1 has no fallback path")
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("LATTICEWRIGHT_CITY_V3_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LATTICEWRIGHT_CITY_V3_FAILURE: %s" % failure)
	print("LATTICEWRIGHT_CITY_V3_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
