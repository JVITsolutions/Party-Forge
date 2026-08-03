extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_reconciles_known_and_unknown_without_mutation(failures)
	_test_implicit_start_and_visibility_radius(failures)
	_test_developer_reveal_is_view_only(failures)
	return failures

func _test_reconciles_known_and_unknown_without_mutation(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _discovered_profile(tree.id)
	profile.tree_allocations[String(tree.id)] = [&"removed-old-node", &"field-pack", &"city-heart"]
	var profile_before := profile.to_dictionary()
	var node_order_before := _node_ids(tree)
	var connection_order_before := _connection_ids(tree)
	var starts_before := tree.starting_node_ids.duplicate()

	var snapshot := PassiveTreeSnapshot.build(tree, profile, false)
	TestAssertions.equal(snapshot.allocated, [&"city-heart", &"field-pack"], "known allocation projection", failures)
	TestAssertions.equal(snapshot.unresolved, [&"removed-old-node"], "unknown saved IDs remain unresolved", failures)
	TestAssertions.truthy(&"removed-old-node" in profile.tree_allocations[tree.id], "snapshot does not mutate profile", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "snapshot preserves every profile field", failures)
	TestAssertions.equal(_node_ids(tree), node_order_before, "snapshot preserves tree node order", failures)
	TestAssertions.equal(_connection_ids(tree), connection_order_before, "snapshot preserves tree connection order", failures)
	TestAssertions.equal(tree.starting_node_ids, starts_before, "snapshot preserves tree start order", failures)

	snapshot.allocated.append(&"third-ring")
	snapshot.visible.clear()
	TestAssertions.equal(profile.to_dictionary(), profile_before, "mutating snapshot arrays cannot mutate profile", failures)
	TestAssertions.equal(_node_ids(tree), node_order_before, "mutating snapshot arrays cannot mutate tree", failures)

func _test_implicit_start_and_visibility_radius(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _discovered_profile(tree.id)
	var base_snapshot := PassiveTreeSnapshot.build(tree, profile, false)
	TestAssertions.equal(base_snapshot.implicit_start_nodes, [&"city-heart"], "discovered tree projects its missing start implicitly", failures)
	TestAssertions.equal(base_snapshot.visible, [&"city-heart", &"field-pack", &"market"], "base visibility radius is exactly two", failures)
	TestAssertions.truthy(PassiveTreeGraph.new(tree).candidate_reachable(base_snapshot.implicit_start_nodes, &"field-pack"), "implicit start acts as allocation root", failures)
	TestAssertions.equal(profile.tree_allocations, {}, "implicit start projection is not persisted", failures)

	profile.tree_visibility_progress[String(tree.id)] = 1
	var bonus_snapshot := PassiveTreeSnapshot.build(tree, profile, false)
	TestAssertions.equal(bonus_snapshot.visible, [&"city-heart", &"field-pack", &"market", &"third-ring"], "visibility progress adds to radius", failures)

	profile.tree_visibility_progress[String(tree.id)] = -10
	var clamped_snapshot := PassiveTreeSnapshot.build(tree, profile, false)
	TestAssertions.equal(clamped_snapshot.visible, [&"city-heart", &"field-pack", &"market"], "negative visibility progress cannot reduce the base radius", failures)

func _test_developer_reveal_is_view_only(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _discovered_profile(tree.id)
	profile.tree_visibility_progress[String(tree.id)] = 0
	var profile_before := profile.to_dictionary()
	var snapshot := PassiveTreeSnapshot.build(tree, profile, true)
	TestAssertions.equal(snapshot.visible, [&"city-heart", &"field-pack", &"fourth-ring", &"market", &"third-ring"], "Developer reveal exposes every node in sorted order", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "Developer reveal never persists visibility or allocations", failures)
	TestAssertions.equal(profile.tree_visibility_progress[String(tree.id)], 0, "Developer reveal leaves visibility progress unchanged", failures)

func _discovered_profile(tree_id: StringName) -> ProfileState:
	var profile := ProfileState.new_profile("profile-12345678", "Graph Tester", 1000)
	profile.discovered_trees.append(String(tree_id))
	return profile

func _tree() -> PassiveTreeDefinition:
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"fourth-ring", &"small"),
		PassiveTreeNode.new(&"market", &"small"),
		PassiveTreeNode.new(&"city-heart", &"start"),
		PassiveTreeNode.new(&"third-ring", &"small"),
		PassiveTreeNode.new(&"field-pack", &"small"),
	]
	var connections: Array[PassiveTreeConnection] = [
		PassiveTreeConnection.new(&"heart-field", &"city-heart", &"field-pack", &"bidirectional"),
		PassiveTreeConnection.new(&"field-market", &"field-pack", &"market", &"forward"),
		PassiveTreeConnection.new(&"market-third", &"market", &"third-ring", &"bidirectional"),
		PassiveTreeConnection.new(&"third-fourth", &"third-ring", &"fourth-ring", &"bidirectional"),
	]
	var starts: Array[StringName] = [&"city-heart"]
	return PassiveTreeDefinition.new(&"test-tree", "Test Tree", starts, nodes, connections)

func _node_ids(tree: PassiveTreeDefinition) -> Array[StringName]:
	var ids: Array[StringName] = []
	for tree_node: PassiveTreeNode in tree.nodes:
		ids.append(tree_node.id)
	return ids

func _connection_ids(tree: PassiveTreeDefinition) -> Array[StringName]:
	var ids: Array[StringName] = []
	for connection: PassiveTreeConnection in tree.connections:
		ids.append(connection.id)
	return ids
