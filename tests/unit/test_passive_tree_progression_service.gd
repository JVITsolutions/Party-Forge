extends RefCounted

const MESSAGES := {
	&"ok": "Action is available.",
	&"tree_not_discovered": "Discover this passive tree before changing it.",
	&"unknown_node": "This passive node is no longer available.",
	&"already_allocated": "This passive node is already allocated.",
	&"node_obscured": "Reveal this passive node before allocating it.",
	&"requirement_failed": "Meet every passive node requirement before allocating it.",
	&"not_connected": "Allocate a connected path to this passive node first.",
	&"insufficient_points": "You do not have enough Passive Points.",
	&"not_allocated": "This passive node is not allocated.",
	&"permanent_node": "This passive node grants permanent progression and cannot be refunded.",
	&"respec_service_required": "Unlock the Passive Respec service before refunding nodes.",
	&"retained_path_disconnected": "Refunding this node would disconnect an allocated path.",
	&"retained_requirement_failed": "Refunding this node would break another allocated node's requirements.",
	&"unsupported_connection_semantics": "This passive tree uses unsupported connection rules.",
}

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_allocation_rejections_are_stable(failures)
	_test_extraction_license_requires_both_prerequisites(failures)
	_test_leader_loadout_extraction_requires_secured_path(failures)
	_test_directed_connectivity_and_implicit_roots(failures)
	_test_unresolved_same_tree_ids_do_not_satisfy_requirements(failures)
	_test_cross_tree_saved_ids_fail_closed_without_authoritative_definition(failures)
	_test_unsupported_connection_semantics_fail_closed(failures)
	_test_allocation_success_is_sorted_defensive_and_pure(failures)
	_test_refund_rejections_and_precedence(failures)
	_test_refund_retained_path_and_requirements(failures)
	_test_refund_success_preserves_unresolved_ids(failures)
	return failures

func _test_allocation_rejections_are_stable(failures: Array[String]) -> void:
	var tree := _tree()
	var tree_before := _tree_fingerprint(tree)
	var service := _service()

	var undiscovered := _profile(tree.id, false, [], 99)
	var unknown := _profile(tree.id, true, [], 99)
	var allocated := _profile(tree.id, true, [&"field-pack"], 99)
	var obscured := _profile(tree.id, true, [], 99)
	var missing_requirement := _profile(tree.id, true, [&"field-pack"], 99)
	var disconnected := _profile(tree.id, true, [&"directed-child"], 99)
	var poor := _profile(tree.id, true, [&"city-heart", &"field-pack", &"stash-access"], 2)
	var rejection_profiles: Array[ProfileState] = [undiscovered, unknown, allocated, obscured, missing_requirement, disconnected, poor]
	var rejection_profiles_before: Array[Dictionary] = []
	for profile: ProfileState in rejection_profiles:
		rejection_profiles_before.append(profile.to_dictionary())
	var developer_reveal := PassiveTreeSnapshot.build(tree, obscured, true)
	TestAssertions.truthy(&"obscured" in developer_reveal.visible, "Developer reveal exposes the hidden fixture node for inspection", failures)

	var cases: Array[Dictionary] = [
		{"label": "undiscovered precedes an unknown node", "decision": service.allocation_decision(tree, undiscovered, &"missing", false), "code": &"tree_not_discovered"},
		{"label": "unknown node", "decision": service.allocation_decision(tree, unknown, &"missing", false), "code": &"unknown_node"},
		{"label": "already allocated", "decision": service.allocation_decision(tree, allocated, &"field-pack", false), "code": &"already_allocated"},
		{"label": "player operation cannot use Developer reveal", "decision": service.allocation_decision(tree, obscured, &"obscured", false), "code": &"node_obscured"},
		{"label": "typed requirements", "decision": service.allocation_decision(tree, missing_requirement, &"extraction-license", false), "code": &"requirement_failed"},
		{"label": "reverse traversal of a forward edge", "decision": service.allocation_decision(tree, disconnected, &"directed-parent", false), "code": &"not_connected"},
		{"label": "exact available point balance", "decision": service.allocation_decision(tree, poor, &"extraction-license", false), "code": &"insufficient_points"},
	]
	for test_case: Dictionary in cases:
		_assert_decision(test_case["decision"] as PassiveTreeActionDecision, test_case["code"], false, test_case["label"], failures)

	var developer_next_gate := service.allocation_decision(tree, obscured, &"obscured", true)
	_assert_decision(developer_next_gate, &"not_connected", false, "Developer operation bypasses fog but not connectivity", failures)
	for index: int in rejection_profiles.size():
		TestAssertions.equal(rejection_profiles[index].to_dictionary(), rejection_profiles_before[index], "allocation rejection %d does not mutate profile input" % index, failures)
	TestAssertions.equal(_tree_fingerprint(tree), tree_before, "allocation rejections do not mutate tree input", failures)
	var rejected := service.allocation_decision(tree, allocated, &"field-pack", false)
	rejected.next_allocations.clear()
	rejected.implicit_start_nodes.append(&"mutated")
	TestAssertions.equal(allocated.to_dictionary(), rejection_profiles_before[2], "rejected decision arrays are defensive from profile input", failures)

func _test_extraction_license_requires_both_prerequisites(failures: Array[String]) -> void:
	var tree := _tree()
	var service := _service()
	var field_only := _profile(tree.id, true, [&"city-heart", &"field-pack"], 10)
	var stash_only := _profile(tree.id, true, [&"city-heart", &"stash-access"], 10)
	var both := _profile(tree.id, true, [&"stash-access", &"city-heart", &"field-pack"], 10)

	_assert_decision(service.allocation_decision(tree, field_only, &"extraction-license", false), &"requirement_failed", false, "Extraction License still needs Stash Access", failures)
	_assert_decision(service.allocation_decision(tree, stash_only, &"extraction-license", false), &"requirement_failed", false, "Extraction License still needs Field Pack", failures)
	var accepted := service.allocation_decision(tree, both, &"extraction-license", false)
	_assert_decision(accepted, &"ok", true, "Extraction License accepts both prerequisites", failures)
	TestAssertions.equal(accepted.point_delta, -3, "Extraction License spends its exact cost", failures)

func _test_leader_loadout_extraction_requires_secured_path(failures: Array[String]) -> void:
	var result := PassiveTreeLoader.new().load_path("res://data/passive_trees/city/party-forge-city.pstree.json")
	TestAssertions.truthy(result.ok(), "committed City artifact loads for leader extraction allocation", failures)
	if not result.ok():
		return
	var service := _service()
	var incomplete := _profile(result.tree.id, true, [&"city-heart", &"field-pack", &"stash-access", &"extraction-license"], 10)
	_assert_decision(service.allocation_decision(result.tree, incomplete, &"leader-loadout-extraction", false), &"not_connected", false, "Leader Loadout Extraction requires Secured Loadout on its allocated path", failures)
	var ready := _profile(result.tree.id, true, [&"city-heart", &"field-pack", &"stash-access", &"extraction-license", &"secured-loadout"], 1)
	var accepted := service.allocation_decision(result.tree, ready, &"leader-loadout-extraction", false)
	_assert_decision(accepted, &"ok", true, "Leader Loadout Extraction allocates after Secured Loadout", failures)
	TestAssertions.equal(accepted.point_delta, -1, "Leader Loadout Extraction spends one Passive Point", failures)
	TestAssertions.equal(accepted.next_allocations, [&"city-heart", &"extraction-license", &"field-pack", &"leader-loadout-extraction", &"secured-loadout", &"stash-access"], "Leader Loadout Extraction persists the complete path", failures)

func _test_directed_connectivity_and_implicit_roots(failures: Array[String]) -> void:
	var tree := _tree()
	var service := _service()
	var older_profile := _profile(tree.id, true, [], 10)
	var rooted := service.allocation_decision(tree, older_profile, &"field-pack", false)
	_assert_decision(rooted, &"ok", true, "implicit start supplies directed allocation root", failures)
	TestAssertions.equal(rooted.implicit_start_nodes, [&"city-heart"], "missing saved start is returned for persistence", failures)
	TestAssertions.equal(rooted.next_allocations, [&"city-heart", &"field-pack"], "successful mutation projection persists the implicit root", failures)

	var forward_profile := _profile(tree.id, true, [&"directed-parent"], 10)
	var forward := service.allocation_decision(tree, forward_profile, &"directed-child", true)
	_assert_decision(forward, &"ok", true, "forward edge allocates from authored from endpoint", failures)

	var reverse_profile := _profile(tree.id, true, [&"directed-child"], 10)
	var reverse := service.allocation_decision(tree, reverse_profile, &"directed-parent", true)
	_assert_decision(reverse, &"not_connected", false, "forward edge cannot allocate in reverse", failures)

func _test_unresolved_same_tree_ids_do_not_satisfy_requirements(failures: Array[String]) -> void:
	var tree := _tree()
	var service := _service()
	var allocation_profile := _profile(tree.id, true, [&"city-heart", &"removed-prerequisite"], 10)
	var allocation_before := allocation_profile.to_dictionary()
	var allocation := service.allocation_decision(tree, allocation_profile, &"unresolved-dependent", false)
	_assert_decision(allocation, &"requirement_failed", false, "unresolved saved ID cannot authorize allocation requirement", failures)
	TestAssertions.equal(allocation.next_allocations, [&"city-heart", &"removed-prerequisite"], "allocation rejection preserves unresolved ID in persistence projection", failures)
	TestAssertions.equal(allocation_profile.to_dictionary(), allocation_before, "unresolved allocation requirement check does not mutate profile", failures)

	var refund_profile := _profile(tree.id, true, [&"city-heart", &"field-pack", &"leaf", &"removed-prerequisite", &"unresolved-dependent"], 0)
	var refund_before := refund_profile.to_dictionary()
	var refund := service.refund_decision(tree, refund_profile, &"leaf", false, true)
	_assert_decision(refund, &"retained_requirement_failed", false, "unresolved saved ID cannot authorize retained requirement", failures)
	TestAssertions.equal(refund.next_allocations, [&"city-heart", &"field-pack", &"leaf", &"removed-prerequisite", &"unresolved-dependent"], "refund rejection preserves unresolved ID in persistence projection", failures)
	TestAssertions.equal(refund_profile.to_dictionary(), refund_before, "unresolved refund requirement check does not mutate profile", failures)

func _test_cross_tree_saved_ids_fail_closed_without_authoritative_definition(failures: Array[String]) -> void:
	var tree := _tree()
	var cross_requirement: Array[PassiveTreeRequirement] = [
		PassiveTreeRequirement.new(&"allocated_node", &"contains", "removed-warehouse-node", {"treeId": "party-forge-warehouse-v1"}),
	]
	var target := tree.node(&"unresolved-dependent")
	target.requirements.assign(cross_requirement)
	var profile := _profile(tree.id, true, [&"city-heart"], 10)
	profile.tree_allocations["party-forge-warehouse-v1"] = ["removed-warehouse-node"]
	var decision := _service().allocation_decision(tree, profile, target.id, true)
	_assert_decision(decision, &"requirement_failed", false, "raw cross-tree saved IDs cannot authorize a requirement", failures)

func _test_unsupported_connection_semantics_fail_closed(failures: Array[String]) -> void:
	var cost_tree := _tree()
	cost_tree.connections[0].cost = 1
	var profile := _profile(cost_tree.id, true, [&"city-heart"], 10)
	_assert_decision(_service().allocation_decision(cost_tree, profile, &"field-pack", true), &"unsupported_connection_semantics", false, "connection point costs fail closed before allocation", failures)

	var condition_tree := _tree()
	condition_tree.connections[0].conditions.append(_requirement(&"city-heart"))
	var refund_profile := _profile(condition_tree.id, true, [&"city-heart", &"field-pack", &"leaf"], 0)
	_assert_decision(_service().refund_decision(condition_tree, refund_profile, &"leaf", true, true), &"unsupported_connection_semantics", false, "connection conditions fail closed before refund", failures)

func _test_allocation_success_is_sorted_defensive_and_pure(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _profile(tree.id, true, [&"task7-zeta-removed", &"stash-access", &"city-heart", &"stash-access", &"field-pack", &"task7-alpha-removed"], 3)
	var profile_before := profile.to_dictionary()
	var tree_before := _tree_fingerprint(tree)
	var service := _service()
	var decision := service.allocation_decision(tree, profile, &"extraction-license", false)

	_assert_decision(decision, &"ok", true, "allocation success", failures)
	TestAssertions.equal(decision.point_delta, -3, "allocation projects exact point cost", failures)
	TestAssertions.equal(decision.next_allocations, [&"city-heart", &"extraction-license", &"field-pack", &"stash-access", &"task7-alpha-removed", &"task7-zeta-removed"], "allocation projection is unique and lexical by StringName text", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "allocation does not mutate the profile", failures)
	TestAssertions.equal(_tree_fingerprint(tree), tree_before, "allocation does not mutate the tree", failures)

	decision.next_allocations.clear()
	decision.implicit_start_nodes.append(&"mutated")
	TestAssertions.equal(profile.to_dictionary(), profile_before, "decision arrays are defensive from saved profile arrays", failures)
	var repeated := service.allocation_decision(tree, profile, &"extraction-license", false)
	TestAssertions.equal(repeated.next_allocations, [&"city-heart", &"extraction-license", &"field-pack", &"stash-access", &"task7-alpha-removed", &"task7-zeta-removed"], "mutating one result cannot affect later decisions", failures)

func _test_refund_rejections_and_precedence(failures: Array[String]) -> void:
	var tree := _tree()
	var service := _service()
	var profile := _profile(tree.id, true, [&"city-heart", &"field-pack", &"permanent-metadata", &"permanent-effect"], 0)
	var profile_before := profile.to_dictionary()
	var tree_before := _tree_fingerprint(tree)
	var cases: Array[Dictionary] = [
		{"label": "unknown refund node", "decision": service.refund_decision(tree, profile, &"missing", false, false), "code": &"unknown_node"},
		{"label": "known node not allocated", "decision": service.refund_decision(tree, profile, &"stash-access", false, false), "code": &"not_allocated"},
		{"label": "starting roots are structurally permanent", "decision": service.refund_decision(tree, profile, &"city-heart", true, false), "code": &"permanent_node"},
		{"label": "permanent metadata precedes missing service", "decision": service.refund_decision(tree, profile, &"permanent-metadata", false, false), "code": &"permanent_node"},
		{"label": "permanent effect precedes missing service", "decision": service.refund_decision(tree, profile, &"permanent-effect", false, false), "code": &"permanent_node"},
		{"label": "player refund requires service", "decision": service.refund_decision(tree, profile, &"field-pack", false, false), "code": &"respec_service_required"},
	]
	for test_case: Dictionary in cases:
		_assert_decision(test_case["decision"] as PassiveTreeActionDecision, test_case["code"], false, test_case["label"], failures)

	_assert_decision(service.refund_decision(tree, profile, &"permanent-metadata", true, false), &"permanent_node", false, "Developer operation cannot refund permanent metadata", failures)
	_assert_decision(service.refund_decision(tree, profile, &"permanent-effect", true, false), &"permanent_node", false, "Developer operation cannot refund permanent effects", failures)
	var developer_free := service.refund_decision(tree, profile, &"field-pack", true, false)
	_assert_decision(developer_free, &"ok", true, "Developer operation bypasses only the service gate", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "refund rejections and Developer success do not mutate profile input", failures)
	TestAssertions.equal(_tree_fingerprint(tree), tree_before, "refund rejections do not mutate tree input", failures)
	var rejected := service.refund_decision(tree, profile, &"permanent-effect", false, false)
	rejected.next_allocations.clear()
	rejected.implicit_start_nodes.append(&"mutated")
	TestAssertions.equal(profile.to_dictionary(), profile_before, "rejected refund arrays are defensive from profile input", failures)

	var city_result := PassiveTreeLoader.new().load_path("res://data/passive_trees/city/party-forge-city.pstree.json")
	TestAssertions.truthy(city_result.ok(), "City root refund test loads the committed artifact", failures)
	if city_result.ok():
		var city_profile := _profile(city_result.tree.id, true, [&"city-heart"], 0)
		_assert_decision(service.refund_decision(city_result.tree, city_profile, &"city-heart", true, false), &"permanent_node", false, "actual City Heart remains persisted despite empty authored permanence metadata and effects", failures)

func _test_refund_retained_path_and_requirements(failures: Array[String]) -> void:
	var tree := _tree()
	var service := _service()
	var disconnected := _profile(tree.id, true, [&"city-heart", &"field-pack", &"extraction-license"], 0)
	var path_decision := service.refund_decision(tree, disconnected, &"field-pack", false, true)
	_assert_decision(path_decision, &"retained_path_disconnected", false, "retained known allocations must reach a start", failures)

	var requirement_profile := _profile(tree.id, true, [&"city-heart", &"field-pack", &"dependent"], 0)
	var requirement_decision := service.refund_decision(tree, requirement_profile, &"field-pack", false, true)
	_assert_decision(requirement_decision, &"retained_requirement_failed", false, "retained typed requirements are re-evaluated", failures)

func _test_refund_success_preserves_unresolved_ids(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _profile(tree.id, true, [&"task7-zeta-removed", &"city-heart", &"field-pack", &"leaf", &"task7-alpha-removed", &"task7-zeta-removed"], 0)
	var profile_before := profile.to_dictionary()
	var tree_before := _tree_fingerprint(tree)
	var service := _service()
	var decision := service.refund_decision(tree, profile, &"leaf", false, true)

	_assert_decision(decision, &"ok", true, "refund success", failures)
	TestAssertions.equal(decision.point_delta, 2, "refund projects the exact node cost", failures)
	TestAssertions.equal(decision.next_allocations, [&"city-heart", &"field-pack", &"task7-alpha-removed", &"task7-zeta-removed"], "refund retains unresolved IDs in unique lexical order", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "refund does not mutate the profile", failures)
	TestAssertions.equal(_tree_fingerprint(tree), tree_before, "refund does not mutate the tree", failures)

	decision.next_allocations.append(&"mutated")
	decision.implicit_start_nodes.clear()
	TestAssertions.equal(profile.to_dictionary(), profile_before, "refund result arrays are defensive", failures)
	var repeated := service.refund_decision(tree, profile, &"leaf", false, true)
	TestAssertions.equal(repeated.next_allocations, [&"city-heart", &"field-pack", &"task7-alpha-removed", &"task7-zeta-removed"], "refund result mutation cannot affect later decisions", failures)

func _assert_decision(decision: PassiveTreeActionDecision, expected_code: StringName, expected_allowed: bool, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(decision.code, expected_code, "%s code" % label, failures)
	TestAssertions.equal(decision.message, MESSAGES[expected_code], "%s exact stable message" % label, failures)
	TestAssertions.truthy(not decision.message.is_empty(), "%s message is player-facing" % label, failures)
	TestAssertions.equal(decision.allowed, expected_allowed, "%s allowed" % label, failures)
	TestAssertions.equal(decision.ok(), expected_allowed and expected_code == &"ok", "%s ok helper" % label, failures)
	if not expected_allowed:
		TestAssertions.equal(decision.point_delta, 0, "%s rejection has no point delta" % label, failures)

func _service() -> PassiveTreeProgressionService:
	return PassiveTreeProgressionService.new(PassiveEffectRegistry.new(), PassiveRequirementRegistry.new())

func _profile(tree_id: StringName, discovered: bool, allocations: Array[StringName], points: int) -> ProfileState:
	var profile := ProfileState.new_profile("profile-12345678", "Progression Tester", 1000)
	if discovered:
		profile.discovered_trees.append(String(tree_id))
	if not allocations.is_empty():
		profile.tree_allocations[String(tree_id)] = allocations.duplicate()
	profile.passive_points_available = points
	profile.passive_points_lifetime_earned = points
	return profile

func _tree() -> PassiveTreeDefinition:
	var no_effects: Array[PassiveTreeEffect] = []
	var no_requirements: Array[PassiveTreeRequirement] = []
	var extraction_requirements: Array[PassiveTreeRequirement] = [
		_requirement(&"field-pack"),
		_requirement(&"stash-access"),
	]
	var dependent_requirements: Array[PassiveTreeRequirement] = [_requirement(&"field-pack")]
	var unresolved_requirements: Array[PassiveTreeRequirement] = [_requirement(&"removed-prerequisite")]
	var permanent_effects: Array[PassiveTreeEffect] = [
		PassiveTreeEffect.new(&"feature_unlock", &"set", true, {"featureId": "inventory"}),
	]
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"task7-zeta", &"small", Vector2.ZERO, "Zeta", "", 1),
		PassiveTreeNode.new(&"city-heart", &"start", Vector2.ZERO, "City Heart", "", 0),
		PassiveTreeNode.new(&"field-pack", &"small", Vector2.ZERO, "Field Pack", "", 1),
		PassiveTreeNode.new(&"stash-access", &"small", Vector2.ZERO, "Stash Access", "", 1),
		PassiveTreeNode.new(&"extraction-license", &"large", Vector2.ZERO, "Extraction License", "", 3, [], null, no_effects, extraction_requirements),
		PassiveTreeNode.new(&"leaf", &"small", Vector2.ZERO, "Leaf", "", 2),
		PassiveTreeNode.new(&"dependent", &"small", Vector2.ZERO, "Dependent", "", 1, [], null, no_effects, dependent_requirements),
		PassiveTreeNode.new(&"unresolved-dependent", &"small", Vector2.ZERO, "Unresolved Dependent", "", 1, [], null, no_effects, unresolved_requirements),
		PassiveTreeNode.new(&"deep-one", &"small", Vector2.ZERO, "Deep One", "", 1),
		PassiveTreeNode.new(&"deep-two", &"small", Vector2.ZERO, "Deep Two", "", 1),
		PassiveTreeNode.new(&"obscured", &"small", Vector2.ZERO, "Obscured", "", 1),
		PassiveTreeNode.new(&"directed-parent", &"small", Vector2.ZERO, "Directed Parent", "", 1),
		PassiveTreeNode.new(&"directed-child", &"small", Vector2.ZERO, "Directed Child", "", 1),
		PassiveTreeNode.new(&"permanent-metadata", &"small", Vector2.ZERO, "Permanent Metadata", "", 2, [], null, no_effects, no_requirements, {"refundPolicy": "permanent"}),
		PassiveTreeNode.new(&"permanent-effect", &"small", Vector2.ZERO, "Permanent Effect", "", 2, [], null, permanent_effects),
		PassiveTreeNode.new(&"task7-alpha", &"small", Vector2.ZERO, "Alpha", "", 1),
	]
	var connections: Array[PassiveTreeConnection] = [
		PassiveTreeConnection.new(&"heart-field", &"city-heart", &"field-pack", &"bidirectional"),
		PassiveTreeConnection.new(&"heart-stash", &"city-heart", &"stash-access", &"bidirectional"),
		PassiveTreeConnection.new(&"field-extraction", &"field-pack", &"extraction-license", &"bidirectional"),
		PassiveTreeConnection.new(&"stash-extraction", &"stash-access", &"extraction-license", &"bidirectional"),
		PassiveTreeConnection.new(&"field-leaf", &"field-pack", &"leaf", &"bidirectional"),
		PassiveTreeConnection.new(&"heart-dependent", &"city-heart", &"dependent", &"bidirectional"),
		PassiveTreeConnection.new(&"heart-unresolved-dependent", &"city-heart", &"unresolved-dependent", &"bidirectional"),
		PassiveTreeConnection.new(&"heart-deep-one", &"city-heart", &"deep-one", &"bidirectional"),
		PassiveTreeConnection.new(&"deep-one-two", &"deep-one", &"deep-two", &"bidirectional"),
		PassiveTreeConnection.new(&"deep-two-obscured", &"deep-two", &"obscured", &"bidirectional"),
		PassiveTreeConnection.new(&"directed-edge", &"directed-parent", &"directed-child", &"forward"),
		PassiveTreeConnection.new(&"heart-permanent-metadata", &"city-heart", &"permanent-metadata", &"bidirectional"),
		PassiveTreeConnection.new(&"heart-permanent-effect", &"city-heart", &"permanent-effect", &"bidirectional"),
	]
	var starts: Array[StringName] = [&"city-heart"]
	return PassiveTreeDefinition.new(&"party-forge-city-v1", "Test City", starts, nodes, connections)

func _requirement(node_id: StringName) -> PassiveTreeRequirement:
	return PassiveTreeRequirement.new(&"allocated_node", &"contains", String(node_id), {"treeId": "party-forge-city-v1"})

func _tree_fingerprint(tree: PassiveTreeDefinition) -> Dictionary:
	var node_values: Array[Dictionary] = []
	for tree_node: PassiveTreeNode in tree.nodes:
		var effects: Array[Dictionary] = []
		for effect: PassiveTreeEffect in tree_node.effects:
			effects.append({"id": effect.effect_id, "operation": effect.operation, "value": effect.value, "parameters": effect.parameters.duplicate(true)})
		var requirements: Array[Dictionary] = []
		for requirement: PassiveTreeRequirement in tree_node.requirements:
			requirements.append({"id": requirement.requirement_id, "operator": requirement.operator, "value": requirement.value, "parameters": requirement.parameters.duplicate(true)})
		node_values.append({"id": tree_node.id, "cost": tree_node.cost, "effects": effects, "requirements": requirements, "metadata": tree_node.metadata.duplicate(true)})
	var connection_values: Array[Array] = []
	for connection: PassiveTreeConnection in tree.connections:
		connection_values.append([connection.id, connection.from_id, connection.to_id, connection.direction])
	return {"id": tree.id, "starts": tree.starting_node_ids.duplicate(), "nodes": node_values, "connections": connection_values, "metadata": tree.metadata.duplicate(true)}
