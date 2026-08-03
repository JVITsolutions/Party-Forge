extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_directional_and_undirected_indexes(failures)
	_test_distances_are_undirected_and_multi_source(failures)
	_test_allocation_reachability_and_retained_paths(failures)
	return failures

func _test_directional_and_undirected_indexes(failures: Array[String]) -> void:
	var graph := PassiveTreeGraph.new(_tree())
	TestAssertions.equal(graph.neighbors(&"field-pack", true), [&"city-heart", &"forward-gate"], "directed neighbors are sorted and include bidirectional and forward exits", failures)
	TestAssertions.equal(graph.neighbors(&"forward-gate", true), [&"depth-three"], "forward edge cannot be traversed backward for allocation", failures)
	TestAssertions.equal(graph.neighbors(&"forward-gate", false), [&"depth-three", &"field-pack"], "visibility treats forward edges as undirected", failures)
	TestAssertions.equal(graph.neighbors(&"missing", true), [], "unknown node has no directed neighbors", failures)

func _test_distances_are_undirected_and_multi_source(failures: Array[String]) -> void:
	var graph := PassiveTreeGraph.new(_tree())
	var forward_distances := graph.distances_from([&"forward-gate"])
	TestAssertions.equal(forward_distances.get(&"field-pack", -1), 1, "undirected visibility crosses a forward edge backward", failures)
	TestAssertions.equal(forward_distances.get(&"city-heart", -1), 2, "undirected distance continues through bidirectional edge", failures)

	var multi_distances := graph.distances_from([&"north-start", &"city-heart", &"missing"])
	TestAssertions.equal(multi_distances.get(&"north-leaf", -1), 1, "second start contributes visibility distances", failures)
	TestAssertions.equal(multi_distances.get(&"depth-three", -1), 3, "first start contributes visibility distances", failures)
	TestAssertions.truthy(not multi_distances.has(&"orphan-a"), "disconnected nodes have no visibility distance", failures)
	TestAssertions.equal(multi_distances.size(), 6, "multi-source distances contain only reachable known nodes", failures)

func _test_allocation_reachability_and_retained_paths(failures: Array[String]) -> void:
	var graph := PassiveTreeGraph.new(_tree())
	TestAssertions.truthy(graph.candidate_reachable([&"field-pack"], &"forward-gate"), "forward candidate is allocation-reachable", failures)
	TestAssertions.truthy(not graph.candidate_reachable([&"forward-gate"], &"field-pack"), "reverse forward candidate is not allocation-reachable", failures)
	TestAssertions.truthy(graph.candidate_reachable([], &"city-heart"), "starting node is an allocation root", failures)
	TestAssertions.truthy(not graph.candidate_reachable([&"removed-old-node"], &"orphan-a"), "unknown allocation does not connect a candidate", failures)

	TestAssertions.truthy(graph.retained_reach_start([&"north-leaf", &"north-start", &"field-pack", &"city-heart"]), "retained allocations may reach multiple starts", failures)
	TestAssertions.truthy(graph.retained_reach_start([&"city-heart", &"field-pack", &"forward-gate", &"depth-three"]), "retained forward chain reaches its start in allocation direction", failures)
	TestAssertions.truthy(not graph.retained_reach_start([&"city-heart", &"orphan-a", &"orphan-b"]), "disconnected retained set is rejected", failures)

func _tree() -> PassiveTreeDefinition:
	var nodes: Array[PassiveTreeNode] = []
	for node_id: StringName in [&"orphan-b", &"depth-three", &"north-leaf", &"city-heart", &"forward-gate", &"field-pack", &"north-start", &"orphan-a"]:
		var node_type: StringName = &"start" if node_id in [&"city-heart", &"north-start"] else &"small"
		nodes.append(PassiveTreeNode.new(node_id, node_type))
	var connections: Array[PassiveTreeConnection] = [
		PassiveTreeConnection.new(&"heart-field", &"city-heart", &"field-pack", &"bidirectional"),
		PassiveTreeConnection.new(&"field-gate", &"field-pack", &"forward-gate", &"forward"),
		PassiveTreeConnection.new(&"gate-depth", &"forward-gate", &"depth-three", &"bidirectional"),
		PassiveTreeConnection.new(&"north-branch", &"north-start", &"north-leaf", &"bidirectional"),
		PassiveTreeConnection.new(&"orphan-edge", &"orphan-a", &"orphan-b", &"bidirectional"),
	]
	var starts: Array[StringName] = [&"city-heart", &"north-start"]
	return PassiveTreeDefinition.new(&"test-tree", "Test Tree", starts, nodes, connections)
