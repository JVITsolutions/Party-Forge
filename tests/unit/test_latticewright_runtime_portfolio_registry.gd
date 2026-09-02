extends RefCounted

const PortfolioRegistry = preload("res://scripts/progression/passive_tree/latticewright_runtime_portfolio_registry.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_registration_and_exact_lookup(failures)
	_test_malformed_and_duplicate_rejections(failures)
	_test_defensive_copy_and_unregister(failures)
	_test_registry_is_inert(failures)
	return failures

func _test_registration_and_exact_lookup(failures: Array[String]) -> void:
	var registry := PortfolioRegistry.new()
	TestAssertions.equal(registry.register_runtime(_valid_runtime()), "", "valid runtime registers", failures)
	TestAssertions.truthy(registry.has_graph(&"test-project", &"test-graph"), "exact project and graph resolve", failures)
	TestAssertions.truthy(not registry.has_graph(&"TEST-PROJECT", &"test-graph"), "project lookup is exact", failures)
	TestAssertions.truthy(not registry.has_graph(&"test-project", &"TEST-GRAPH"), "graph lookup is exact", failures)
	TestAssertions.truthy(not registry.has_graph(&"missing", &"test-graph"), "unknown project stays absent", failures)

func _test_malformed_and_duplicate_rejections(failures: Array[String]) -> void:
	var registry := PortfolioRegistry.new()
	var malformed := _valid_runtime()
	malformed.erase("projectId")
	TestAssertions.truthy(not registry.register_runtime(malformed).is_empty(), "malformed runtime header rejects", failures)

	var duplicate_graph := _valid_runtime()
	(duplicate_graph["graphs"] as Array).append({"id": "test-graph"})
	TestAssertions.truthy(not registry.register_runtime(duplicate_graph).is_empty(), "duplicate graph IDs reject", failures)

	TestAssertions.equal(registry.register_runtime(_valid_runtime()), "", "first project registration succeeds", failures)
	TestAssertions.truthy(not registry.register_runtime(_valid_runtime()).is_empty(), "duplicate project registration rejects", failures)

func _test_defensive_copy_and_unregister(failures: Array[String]) -> void:
	var source := _valid_runtime()
	var registry := PortfolioRegistry.new()
	TestAssertions.equal(registry.register_runtime(source), "", "source registers before mutation", failures)
	(source["graphs"] as Array)[0]["id"] = "mutated-graph"
	(source["graphs"] as Array).append({"id": "injected-graph"})
	TestAssertions.truthy(registry.has_graph(&"test-project", &"test-graph"), "registered runtime is a defensive deep copy", failures)
	TestAssertions.truthy(not registry.has_graph(&"test-project", &"mutated-graph"), "source mutation cannot rewrite registry", failures)

	var copy := registry.copy()
	registry.unregister_runtime(&"test-project")
	TestAssertions.truthy(not registry.has_graph(&"test-project", &"test-graph"), "unregister removes exact project", failures)
	TestAssertions.truthy(copy.has_graph(&"test-project", &"test-graph"), "registry copy is independent", failures)
	registry.unregister_runtime(&"missing")
	TestAssertions.truthy(not registry.has_graph(&"test-project", &"test-graph"), "unknown unregister is inert", failures)

func _test_registry_is_inert(failures: Array[String]) -> void:
	var runtime := _valid_runtime()
	runtime["graphPortals"] = [{
		"id": "portal",
		"sourceGraphId": "test-graph",
		"sourcePlacementId": "source",
		"label": "Missing Target",
		"role": "drill-down",
		"targetProjectId": "missing-project",
		"targetGraphId": "missing-graph",
		"extensions": {},
	}]
	var registry := PortfolioRegistry.new()
	TestAssertions.equal(registry.register_runtime(runtime), "", "portal declarations do not block inert registration", failures)
	TestAssertions.truthy(not registry.has_graph(&"missing-project", &"missing-graph"), "portal declaration is not target discovery", failures)
	TestAssertions.truthy(not registry.has_graph(&"party-forge-city", &"city-passive-tree"), "registry never discovers filesystem runtimes", failures)

func _valid_runtime() -> Dictionary:
	return {
		"format": "latticewright-progression",
		"formatVersion": 3,
		"projectId": "test-project",
		"name": "Test Runtime",
		"archetype": "passive-tree",
		"vocabulary": {},
		"schemas": {},
		"content": [],
		"graphs": [{"id": "test-graph"}],
		"graphPortals": [],
		"assets": [],
		"extensions": {},
	}
