extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_state_projection_and_redaction(failures)
	_test_typed_presentation_copy_and_development_state(failures)
	_test_unsupported_connection_semantics_are_unavailable(failures)
	_test_implicit_legacy_root_is_projected_active(failures)
	_test_developer_reveal_is_view_only(failures)
	_test_committed_city_projection_is_lexical(failures)
	_test_results_are_deeply_isolated(failures)
	_test_metadata_projection_is_value_only(failures)
	_test_null_inputs_fail_closed(failures)
	return failures

func _test_state_projection_and_redaction(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _profile(tree.id)
	var result := _view_model().build(tree, profile, false)

	TestAssertions.equal(result["tree_id"], &"party-forge-view-test-v1", "tree ID is projected", failures)
	TestAssertions.equal(result["tree_name"], "View Test", "tree name is projected", failures)
	TestAssertions.equal(result["points_available"], 3, "available profile-owned points", failures)
	TestAssertions.equal(result["points_lifetime"], 11, "lifetime profile-owned points", failures)
	TestAssertions.equal(result["points_text"], "Passive Points: 3 / 11", "exact points header", failures)
	TestAssertions.equal(result["status"], "", "valid projection has no error status", failures)
	TestAssertions.equal(result["unresolved_ids"], [&"removed-alpha", &"removed-zeta"], "unresolved historical IDs are separate and lexical", failures)

	var ids: Array[StringName] = []
	for view: PassiveTreeNodeViewData in result["nodes"]:
		ids.append(view.id)
	TestAssertions.equal(ids, [&"a-start", &"b-allocatable", &"c-requirement", &"d-poor", &"e-disconnected", &"f-permanent-metadata", &"g-permanent-effect", &"h-allocated", &"i-invalid", &"x-one", &"y-two", &"z-obscured"], "node views are lexical by String text", failures)
	TestAssertions.truthy(&"removed-alpha" not in ids and &"removed-zeta" not in ids, "unresolved IDs never become node views", failures)

	var start := _node(result, &"a-start")
	TestAssertions.equal(start.state, &"allocated", "allocated start keeps allocation state", failures)
	TestAssertions.truthy(start.allocated and not start.allocatable, "allocated flags", failures)
	TestAssertions.truthy(start.permanent, "starting node is structurally permanent", failures)
	TestAssertions.equal(start.decision_code, &"already_allocated", "allocated exact decision code", failures)
	TestAssertions.equal(start.decision_message, "This passive node is already allocated.", "allocated exact decision message", failures)

	var allocatable := _node(result, &"b-allocatable")
	TestAssertions.equal(allocatable.state, &"allocatable", "visible allowed node state", failures)
	TestAssertions.truthy(not allocatable.allocated and allocatable.allocatable, "allocatable flags", failures)
	TestAssertions.equal(allocatable.display_name, "Exact Creator Name", "Creator name remains display copy", failures)
	TestAssertions.equal(allocatable.description, "Exact Creator description; it is not parsed.", "Creator description remains display copy", failures)
	TestAssertions.equal(allocatable.cost_text, "1", "visible cost text", failures)
	TestAssertions.equal(allocatable.get("refund_policy_text"), "Refundable", "visible refundable policy is typed presentation data", failures)
	TestAssertions.equal(allocatable.get("development_lines"), ["Coming Soon"], "Player projection labels future contract without Developer availability", failures)
	TestAssertions.equal(allocatable.effect_lines, ["Experience Gain: +2% (all_run_experience).", "Experience Gain: +3% (all_run_experience)."], "effect lines come from typed contracts in authored order", failures)
	TestAssertions.equal(allocatable.keyword_lines, ["Experience Gain: Increases experience earned in the named scope."], "keyword explanations are deduplicated", failures)
	TestAssertions.equal(allocatable.decision_code, &"ok", "allocatable exact decision code", failures)
	TestAssertions.equal(allocatable.decision_message, "Action is available.", "allocatable exact decision message", failures)

	var requirement := _node(result, &"c-requirement")
	TestAssertions.equal(requirement.state, &"unavailable", "visible requirement failure state", failures)
	TestAssertions.equal(requirement.requirement_lines, ["Requires allocated node: missing-prerequisite (party-forge-view-test-v1)."], "requirement line comes from typed contract", failures)
	TestAssertions.equal(requirement.keyword_lines, ["Allocated Node: Requires the named node to be allocated in the named passive tree."], "requirement keyword explanation", failures)
	TestAssertions.equal(requirement.decision_code, &"requirement_failed", "requirement exact decision code", failures)
	TestAssertions.equal(requirement.decision_message, "Meet every passive node requirement before allocating it.", "requirement exact decision message", failures)

	var poor := _node(result, &"d-poor")
	TestAssertions.equal(poor.state, &"unavailable", "insufficient points state", failures)
	TestAssertions.equal(poor.decision_code, &"insufficient_points", "insufficient points exact decision code", failures)
	TestAssertions.equal(poor.decision_message, "You do not have enough Passive Points.", "insufficient points exact decision message", failures)

	var disconnected := _node(result, &"e-disconnected")
	TestAssertions.equal(disconnected.state, &"unavailable", "directed disconnect state", failures)
	TestAssertions.equal(disconnected.decision_code, &"not_connected", "disconnected exact decision code", failures)
	TestAssertions.equal(disconnected.decision_message, "Allocate a connected path to this passive node first.", "disconnected exact decision message", failures)

	var metadata_permanent := _node(result, &"f-permanent-metadata")
	TestAssertions.equal(metadata_permanent.state, &"allocatable", "metadata permanence does not replace allocation state", failures)
	TestAssertions.truthy(metadata_permanent.permanent, "metadata permanence is projected", failures)
	TestAssertions.equal(metadata_permanent.get("refund_policy_text"), "Permanent", "permanent policy is explicit presentation data", failures)
	var effect_permanent := _node(result, &"g-permanent-effect")
	TestAssertions.equal(effect_permanent.state, &"allocatable", "effect permanence does not replace allocation state", failures)
	TestAssertions.truthy(effect_permanent.permanent, "effect permanence is projected", failures)
	var allocated := _node(result, &"h-allocated")
	TestAssertions.equal(allocated.state, &"allocated", "known saved node is allocated", failures)
	TestAssertions.truthy(not allocated.permanent, "ordinary allocation is refundable", failures)
	var invalid := _node(result, &"i-invalid")
	TestAssertions.equal(invalid.effect_lines, [], "invalid typed effect has no presentation line", failures)
	TestAssertions.equal(invalid.requirement_lines, [], "invalid typed requirement has no presentation line", failures)
	TestAssertions.equal(invalid.keyword_lines, [], "invalid typed effect has no keyword explanation", failures)

	var obscured := _node(result, &"z-obscured")
	TestAssertions.equal(obscured.state, &"obscured", "fogged node state", failures)
	TestAssertions.equal(obscured.display_name, "???", "obscured display name is redacted", failures)
	TestAssertions.equal(obscured.description, "???", "obscured description is redacted", failures)
	TestAssertions.equal(obscured.cost_text, "?", "obscured cost text is redacted", failures)
	TestAssertions.equal(obscured.effect_lines, [], "obscured effects are redacted", failures)
	TestAssertions.equal(obscured.requirement_lines, [], "obscured requirements are redacted", failures)
	TestAssertions.equal(obscured.keyword_lines, [], "obscured keywords are redacted", failures)
	TestAssertions.equal(obscured.cost, -1, "obscured numeric cost is redacted", failures)
	TestAssertions.equal(obscured.metadata, {}, "obscured metadata is redacted", failures)
	TestAssertions.equal(obscured.get("refund_policy_text"), "", "obscured refund policy is redacted", failures)
	TestAssertions.equal(obscured.get("development_lines"), [], "obscured development state is redacted", failures)
	TestAssertions.truthy(not obscured.permanent and not obscured.allocated and not obscured.allocatable, "obscured flags reveal no hidden mechanics", failures)
	TestAssertions.equal(obscured.decision_code, &"node_obscured", "obscured decision is generic", failures)
	TestAssertions.equal(obscured.decision_message, "Reveal this passive node before allocating it.", "obscured decision reveals no mechanics", failures)

func _test_typed_presentation_copy_and_development_state(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _profile(tree.id)
	var developer := _view_model().build(tree, profile, true)
	var source := _node(developer, &"b-allocatable")
	TestAssertions.equal(source.get("development_lines"), ["Coming Soon", "Developer Preview"], "Developer projection exposes both future-contract disclosures", failures)
	var copied := source.copy()
	var source_lines: Variant = source.get("development_lines")
	if source_lines is Array:
		source_lines.append("Caller Mutation")
	TestAssertions.equal(copied.get("development_lines"), ["Coming Soon", "Developer Preview"], "typed development presentation is defensively copied", failures)
	TestAssertions.equal(copied.get("refund_policy_text"), "Refundable", "typed refund presentation survives copy", failures)

func _test_unsupported_connection_semantics_are_unavailable(failures: Array[String]) -> void:
	var tree := _tree()
	tree.connections[tree.connections.size() - 1].cost = 1
	var view := _node(_view_model().build(tree, _profile(tree.id), true), &"b-allocatable")
	TestAssertions.equal(view.state, &"unavailable", "unsupported connection semantics never present a node as allocatable", failures)
	TestAssertions.equal(view.decision_code, &"unsupported_connection_semantics", "unsupported connection presentation keeps stable rejection code", failures)

func _test_implicit_legacy_root_is_projected_active(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _profile(tree.id)
	profile.tree_allocations[String(tree.id)] = [&"h-allocated"]
	var profile_before := profile.to_dictionary()
	var root := _node(_view_model().build(tree, profile, false), &"a-start")

	TestAssertions.equal(root.state, &"allocated", "implicit legacy root is projected active", failures)
	TestAssertions.truthy(root.allocated, "implicit legacy root uses the allocated flag", failures)
	TestAssertions.truthy(not root.allocatable, "implicit legacy root is never offered for allocation", failures)
	TestAssertions.truthy(root.permanent, "implicit legacy root remains structurally permanent", failures)
	TestAssertions.equal(root.decision_code, &"already_allocated", "implicit legacy root uses stable non-action code", failures)
	TestAssertions.equal(root.decision_message, "This passive node is already allocated.", "implicit legacy root uses stable non-action message", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "implicit root projection does not persist or mutate legacy profile", failures)

func _test_developer_reveal_is_view_only(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _profile(tree.id)
	var tree_before := _tree_fingerprint(tree)
	var profile_before := profile.to_dictionary()
	var view_model := _view_model()
	var normal := view_model.build(tree, profile, false)
	var preview := view_model.build(tree, profile, true)

	TestAssertions.equal(_node(normal, &"z-obscured").state, &"obscured", "normal view retains fog", failures)
	var revealed := _node(preview, &"z-obscured")
	TestAssertions.equal(revealed.state, &"unavailable", "Developer reveal exposes state without authorizing disconnected allocation", failures)
	TestAssertions.equal(revealed.display_name, "Hidden Mechanics", "Developer reveal exposes Creator copy", failures)
	TestAssertions.equal(revealed.effect_lines, ["Inventory Columns: +1 (profile)."], "Developer reveal exposes typed effect line", failures)
	TestAssertions.equal(tree_before, _tree_fingerprint(tree), "Developer reveal does not mutate tree", failures)
	TestAssertions.equal(profile_before, profile.to_dictionary(), "Developer reveal does not mutate profile or visibility progress", failures)
	TestAssertions.equal(_node(view_model.build(tree, profile, false), &"z-obscured").display_name, "???", "Developer reveal cannot affect later player builds", failures)

func _test_committed_city_projection_is_lexical(failures: Array[String]) -> void:
	var load_result := PassiveTreeCatalog.load_defaults()
	TestAssertions.truthy(load_result.ok(), "committed City tree loads for view projection", failures)
	if not load_result.ok():
		return
	var profile := _profile(load_result.tree.id)
	var result := _view_model().build(load_result.tree, profile, true)
	TestAssertions.equal(result["tree_id"], &"party-forge-city-v1", "committed City stable tree ID", failures)
	TestAssertions.equal((result["nodes"] as Array).size(), 37, "committed City projects every node", failures)
	TestAssertions.equal((result["connections"] as Array).size(), 37, "committed City projects every connection", failures)
	var node_ids: Array[String] = []
	for view: PassiveTreeNodeViewData in result["nodes"]:
		node_ids.append(String(view.id))
	var expected_node_ids := node_ids.duplicate()
	expected_node_ids.sort()
	TestAssertions.equal(node_ids, expected_node_ids, "committed City nodes are lexical", failures)
	var connection_ids: Array[String] = []
	for connection: Dictionary in result["connections"]:
		connection_ids.append(String(connection["id"]))
	var expected_connection_ids := connection_ids.duplicate()
	expected_connection_ids.sort()
	TestAssertions.equal(connection_ids, expected_connection_ids, "committed City connections are lexical", failures)

func _test_results_are_deeply_isolated(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _profile(tree.id)
	var tree_before := _tree_fingerprint(tree)
	var profile_before := profile.to_dictionary()
	var view_model := _view_model()
	var first := view_model.build(tree, profile, false)
	var first_node := _node(first, &"b-allocatable")
	var copied_node := first_node.copy()
	copied_node.effect_lines.append("copy-only")
	copied_node.metadata["nested"]["value"] = 555
	TestAssertions.truthy("copy-only" not in first_node.effect_lines, "view-data copy owns its arrays", failures)
	TestAssertions.equal(first_node.metadata["nested"]["value"], 1, "view-data copy owns nested metadata", failures)

	first_node.display_name = "mutated"
	first_node.effect_lines.append("mutated")
	first_node.keyword_lines.clear()
	first_node.metadata["nested"]["value"] = 999
	(first["connections"] as Array)[0]["metadata"]["nested"]["value"] = 999
	(first["unresolved_ids"] as Array).append(&"mutated")
	(first["nodes"] as Array).clear()
	(first["connections"] as Array).clear()

	var repeated := view_model.build(tree, profile, false)
	var repeated_node := _node(repeated, &"b-allocatable")
	TestAssertions.equal(repeated_node.display_name, "Exact Creator Name", "node scalar mutation cannot affect later build", failures)
	TestAssertions.equal(repeated_node.effect_lines, ["Experience Gain: +2% (all_run_experience).", "Experience Gain: +3% (all_run_experience)."], "node array mutation cannot affect later build", failures)
	TestAssertions.equal(repeated_node.metadata["nested"]["value"], 1, "node metadata mutation cannot affect later build", failures)
	TestAssertions.equal((repeated["connections"] as Array)[0]["metadata"]["nested"]["value"], 1, "connection metadata is deeply copied", failures)
	TestAssertions.equal(repeated["unresolved_ids"], [&"removed-alpha", &"removed-zeta"], "result arrays are isolated", failures)
	TestAssertions.equal(tree_before, _tree_fingerprint(tree), "caller mutation cannot affect source tree", failures)
	TestAssertions.equal(profile_before, profile.to_dictionary(), "caller mutation cannot affect source profile", failures)
	for view: PassiveTreeNodeViewData in repeated["nodes"]:
		TestAssertions.truthy(not _view_contains_domain_reference(view), "%s view has no domain references" % view.id, failures)
	for connection: Dictionary in repeated["connections"]:
		TestAssertions.truthy(not _contains_domain_reference(connection), "%s connection has no domain references" % connection["id"], failures)
	TestAssertions.truthy(not _contains_domain_reference(repeated["unresolved_ids"]), "unresolved projection has no domain references", failures)

func _test_metadata_projection_is_value_only(failures: Array[String]) -> void:
	var tree := _tree()
	var profile := _profile(tree.id)
	var embedded_node := PassiveTreeNode.new(&"embedded-node")
	var embedded_connection := PassiveTreeConnection.new(&"embedded-connection")
	var embedded_effect := PassiveTreeEffect.new(&"feature_unlock", &"set", true, {"featureId": "inventory"})
	var embedded_requirement := PassiveTreeRequirement.new(&"allocated_node", &"contains", "a-start", {"treeId": "party-forge-view-test-v1"})
	var embedded_profile := ProfileState.new_profile("profile-embedded", "Embedded", 1000)
	var source_node := tree.node(&"b-allocatable")
	var source_connection := tree.connection(&"b-allocatable")
	source_node.metadata = {
		"safe": {"enabled": true, "id": &"safe-id", "position": Vector2(4, 8), "values": [1, "two"]},
		"embedded_node": embedded_node,
		"nested": {"keep": "yes", "embedded_connection": embedded_connection},
		"mixed": ["first", embedded_effect, 7, embedded_requirement, embedded_profile],
	}
	source_connection.metadata = {
		"safe": [false, &"connection-id", Vector2(2, 3)],
		"embedded_effect": embedded_effect,
		"nested": {"embedded_profile": embedded_profile, "keep": 9},
	}
	var profile_before := profile.to_dictionary()
	var result := _view_model().build(tree, profile, false)
	var view := _node(result, &"b-allocatable")
	var connection := _connection(result, &"b-allocatable")

	TestAssertions.equal(view.metadata["safe"], {"enabled": true, "id": &"safe-id", "position": Vector2(4, 8), "values": [1, "two"]}, "node metadata retains allowed value types", failures)
	TestAssertions.truthy(not view.metadata.has("embedded_node"), "node metadata omits embedded node object", failures)
	TestAssertions.equal(view.metadata["nested"], {"keep": "yes"}, "nested node metadata omits embedded connection object", failures)
	TestAssertions.equal(view.metadata["mixed"], ["first", 7], "node metadata arrays omit embedded effect requirement and profile objects", failures)
	TestAssertions.equal(connection["metadata"]["safe"], [false, &"connection-id", Vector2(2, 3)], "connection metadata retains allowed value types", failures)
	TestAssertions.truthy(not connection["metadata"].has("embedded_effect"), "connection metadata omits embedded effect object", failures)
	TestAssertions.equal(connection["metadata"]["nested"], {"keep": 9}, "nested connection metadata omits embedded profile object", failures)
	TestAssertions.truthy(not _contains_domain_reference(view.metadata), "node metadata contains no Object or domain reference", failures)
	TestAssertions.truthy(not _contains_domain_reference(connection["metadata"]), "connection metadata contains no Object or domain reference", failures)

	view.metadata["late_profile"] = embedded_profile
	var copied := view.copy()
	TestAssertions.truthy(not copied.metadata.has("late_profile"), "view-data copy sanitizes caller-inserted objects", failures)
	(copied.metadata["safe"] as Dictionary)["enabled"] = false
	TestAssertions.equal((view.metadata["safe"] as Dictionary)["enabled"], true, "view-data copy remains deeply isolated", failures)
	TestAssertions.equal(source_node.metadata["embedded_node"], embedded_node, "source node metadata retains its original object", failures)
	TestAssertions.equal((source_node.metadata["nested"] as Dictionary)["embedded_connection"], embedded_connection, "source nested node metadata is unchanged", failures)
	TestAssertions.equal(source_connection.metadata["embedded_effect"], embedded_effect, "source connection metadata retains its original object", failures)
	TestAssertions.equal((source_connection.metadata["nested"] as Dictionary)["embedded_profile"], embedded_profile, "source nested connection metadata is unchanged", failures)
	TestAssertions.equal(profile.to_dictionary(), profile_before, "metadata sanitization does not mutate build profile", failures)

func _test_null_inputs_fail_closed(failures: Array[String]) -> void:
	var profile := _profile(&"party-forge-view-test-v1")
	var valid_model := _view_model()
	var missing_tree := valid_model.build(null, profile, false)
	TestAssertions.equal(missing_tree["nodes"], [], "null tree has no node views", failures)
	TestAssertions.truthy(not String(missing_tree["status"]).is_empty(), "null tree has a safe status", failures)
	var missing_profile := valid_model.build(_tree(), null, false)
	TestAssertions.equal(missing_profile["connections"], [], "null profile has no connections", failures)
	TestAssertions.truthy(not String(missing_profile["status"]).is_empty(), "null profile has a safe status", failures)
	var missing_service := PassiveTreeViewModel.new(null, PassiveEffectResolver.new(PassiveEffectRegistry.new()), PassiveEffectRegistry.new(), PassiveRequirementRegistry.new()).build(_tree(), profile, false)
	TestAssertions.equal(missing_service["nodes"], [], "null dependency fails closed", failures)
	TestAssertions.truthy(not String(missing_service["status"]).is_empty(), "null dependency has a safe status", failures)

func _view_model() -> PassiveTreeViewModel:
	var effects := PassiveEffectRegistry.new()
	var requirements := PassiveRequirementRegistry.new()
	return PassiveTreeViewModel.new(PassiveTreeProgressionService.new(effects, requirements), PassiveEffectResolver.new(effects), effects, requirements)

func _profile(tree_id: StringName) -> ProfileState:
	var profile := ProfileState.new_profile("profile-12345678", "View Tester", 1000)
	profile.discovered_trees.append(String(tree_id))
	profile.tree_allocations[String(tree_id)] = [&"removed-zeta", &"h-allocated", &"a-start", &"removed-alpha"]
	profile.tree_visibility_progress[String(tree_id)] = 0
	profile.passive_points_available = 3
	profile.passive_points_lifetime_earned = 11
	return profile

func _tree() -> PassiveTreeDefinition:
	var no_effects: Array[PassiveTreeEffect] = []
	var no_requirements: Array[PassiveTreeRequirement] = []
	var experience_effects: Array[PassiveTreeEffect] = [
		PassiveTreeEffect.new(&"experience_gain", &"add_percent", 2, {"scope": "all_run_experience"}),
		PassiveTreeEffect.new(&"experience_gain", &"add_percent", 3, {"scope": "all_run_experience"}),
	]
	var requirement: Array[PassiveTreeRequirement] = [
		PassiveTreeRequirement.new(&"allocated_node", &"contains", "missing-prerequisite", {"treeId": "party-forge-view-test-v1"}),
	]
	var permanent_effects: Array[PassiveTreeEffect] = [
		PassiveTreeEffect.new(&"feature_unlock", &"set", true, {"featureId": "inventory"}),
	]
	var hidden_effects: Array[PassiveTreeEffect] = [
		PassiveTreeEffect.new(&"inventory_columns", &"add_flat", 1, {"scope": "profile"}),
	]
	var invalid_effects: Array[PassiveTreeEffect] = [
		PassiveTreeEffect.new(&"inventory_columns", &"add_flat", 1, {"scope": "party"}),
	]
	var invalid_requirements: Array[PassiveTreeRequirement] = [
		PassiveTreeRequirement.new(&"allocated_node", &"equals", "a-start", {"treeId": "party-forge-view-test-v1"}),
	]
	var metadata := {"nested": {"value": 1}}
	var future_metadata := {"integrationStatus": "future-contract", "nested": {"value": 1}}
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"z-obscured", &"large", Vector2(300, 0), "Hidden Mechanics", "Secret description.", 7, [], null, hidden_effects, requirement, metadata),
		PassiveTreeNode.new(&"i-invalid", &"small", Vector2(0, 60), "Invalid", "Invalid copy.", 1, [], null, invalid_effects, invalid_requirements, metadata),
		PassiveTreeNode.new(&"h-allocated", &"small", Vector2(0, 50), "Allocated", "Allocated copy.", 1, [], null, no_effects, no_requirements, metadata),
		PassiveTreeNode.new(&"g-permanent-effect", &"small", Vector2(0, 40), "Effect Permanent", "Effect copy.", 1, [], null, permanent_effects, no_requirements, metadata),
		PassiveTreeNode.new(&"f-permanent-metadata", &"small", Vector2(0, 30), "Metadata Permanent", "Metadata copy.", 1, [], null, no_effects, no_requirements, {"refundPolicy": "permanent", "nested": {"value": 1}}),
		PassiveTreeNode.new(&"e-disconnected", &"small", Vector2(0, 20), "Disconnected", "Disconnected copy.", 1, [], null, no_effects, no_requirements, metadata),
		PassiveTreeNode.new(&"d-poor", &"small", Vector2(0, 10), "Expensive", "Expensive copy.", 99, [], null, no_effects, no_requirements, metadata),
		PassiveTreeNode.new(&"c-requirement", &"small", Vector2(0, 5), "Requirement", "Requirement copy.", 1, [], null, no_effects, requirement, metadata),
		PassiveTreeNode.new(&"b-allocatable", &"small", Vector2(0, 1), "Exact Creator Name", "Exact Creator description; it is not parsed.", 1, [], null, experience_effects, no_requirements, future_metadata),
		PassiveTreeNode.new(&"a-start", &"start", Vector2.ZERO, "Start", "Start copy.", 0, [], null, no_effects, no_requirements, metadata),
		PassiveTreeNode.new(&"x-one", &"small", Vector2(100, 0), "One", "One copy.", 1, [], null, no_effects, no_requirements, metadata),
		PassiveTreeNode.new(&"y-two", &"small", Vector2(200, 0), "Two", "Two copy.", 1, [], null, no_effects, no_requirements, metadata),
	]
	var connections: Array[PassiveTreeConnection] = [
		PassiveTreeConnection.new(&"z-hidden", &"y-two", &"z-obscured", &"bidirectional", 0, [], metadata),
		PassiveTreeConnection.new(&"i-invalid", &"a-start", &"i-invalid", &"bidirectional", 0, [], metadata),
		PassiveTreeConnection.new(&"y-chain", &"x-one", &"y-two", &"bidirectional", 0, [], metadata),
		PassiveTreeConnection.new(&"x-chain", &"a-start", &"x-one", &"bidirectional", 0, [], metadata),
		PassiveTreeConnection.new(&"h-allocated", &"a-start", &"h-allocated", &"bidirectional", 0, [], metadata),
		PassiveTreeConnection.new(&"g-effect", &"a-start", &"g-permanent-effect", &"bidirectional", 0, [], metadata),
		PassiveTreeConnection.new(&"f-metadata", &"a-start", &"f-permanent-metadata", &"bidirectional", 0, [], metadata),
		PassiveTreeConnection.new(&"e-reverse", &"e-disconnected", &"a-start", &"forward", 0, [], metadata),
		PassiveTreeConnection.new(&"d-poor", &"a-start", &"d-poor", &"bidirectional", 0, [], metadata),
		PassiveTreeConnection.new(&"c-requirement", &"a-start", &"c-requirement", &"bidirectional", 0, [], metadata),
		PassiveTreeConnection.new(&"b-allocatable", &"a-start", &"b-allocatable", &"bidirectional", 0, [], metadata),
	]
	var starts: Array[StringName] = [&"a-start"]
	return PassiveTreeDefinition.new(&"party-forge-view-test-v1", "View Test", starts, nodes, connections, {"nested": {"value": 1}})

func _node(result: Dictionary, node_id: StringName) -> PassiveTreeNodeViewData:
	for view: PassiveTreeNodeViewData in result["nodes"]:
		if view.id == node_id:
			return view
	return null

func _connection(result: Dictionary, connection_id: StringName) -> Dictionary:
	for connection: Dictionary in result["connections"]:
		if connection["id"] == connection_id:
			return connection
	return {}

func _view_contains_domain_reference(view: PassiveTreeNodeViewData) -> bool:
	return _contains_domain_reference(view.id) or _contains_domain_reference(view.position) \
		or _contains_domain_reference(view.type) or _contains_domain_reference(view.state) \
		or _contains_domain_reference(view.display_name) or _contains_domain_reference(view.description) \
		or _contains_domain_reference(view.effect_lines) or _contains_domain_reference(view.requirement_lines) \
		or _contains_domain_reference(view.keyword_lines) or _contains_domain_reference(view.metadata) \
		or _contains_domain_reference(view.decision_code) or _contains_domain_reference(view.decision_message)

func _contains_domain_reference(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Array:
		for item: Variant in value as Array:
			if _contains_domain_reference(item):
				return true
	elif value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			if _contains_domain_reference(key) or _contains_domain_reference((value as Dictionary)[key]):
				return true
	return false

func _tree_fingerprint(tree: PassiveTreeDefinition) -> Dictionary:
	var node_values: Array[Dictionary] = []
	for tree_node: PassiveTreeNode in tree.nodes:
		var effects: Array[Dictionary] = []
		for effect: PassiveTreeEffect in tree_node.effects:
			effects.append({"id": effect.effect_id, "operation": effect.operation, "value": effect.value, "parameters": effect.parameters.duplicate(true)})
		var requirements: Array[Dictionary] = []
		for requirement: PassiveTreeRequirement in tree_node.requirements:
			requirements.append({"id": requirement.requirement_id, "operator": requirement.operator, "value": requirement.value, "parameters": requirement.parameters.duplicate(true)})
		node_values.append({"id": tree_node.id, "type": tree_node.type, "position": tree_node.position, "name": tree_node.name, "description": tree_node.description, "cost": tree_node.cost, "effects": effects, "requirements": requirements, "metadata": tree_node.metadata.duplicate(true)})
	var connection_values: Array[Dictionary] = []
	for connection: PassiveTreeConnection in tree.connections:
		connection_values.append({"id": connection.id, "from": connection.from_id, "to": connection.to_id, "direction": connection.direction, "cost": connection.cost, "metadata": connection.metadata.duplicate(true)})
	return {"id": tree.id, "name": tree.name, "starts": tree.starting_node_ids.duplicate(), "nodes": node_values, "connections": connection_values, "metadata": tree.metadata.duplicate(true)}
