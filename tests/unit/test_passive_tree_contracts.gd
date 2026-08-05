extends RefCounted

const CITY_PATH := "res://data/passive_trees/city/party-forge-city.pstree.json"

const EFFECT_CONTRACTS := [
	[&"city_service_unlock", &"set", true, {"serviceId": "city_vendors"}],
	[&"experience_gain", &"add_percent", 2, {"scope": "all_run_experience"}],
	[&"feature_unlock", &"set", true, {"featureId": "equipment_inventory"}],
	[&"mode_unlock", &"set", true, {"modeId": "practice"}],
	[&"party_capacity", &"add_flat", 1, {"scope": "profile"}],
	[&"region_unlock", &"set", true, {"regionId": "north-road"}],
	[&"vendor_inventory_slots", &"add_flat", 1, {"scope": "profile"}],
	[&"vendor_reroll_count", &"add_flat", 1, {"scope": "profile"}],
	[&"building_discovery", &"set", true, {"buildingId": "warehouse"}],
	[&"extraction_capacity", &"add_flat", 1, {"scope": "profile"}],
	[&"inventory_columns", &"add_flat", 1, {"scope": "profile"}],
	[&"stash_tabs", &"add_flat", 1, {"scope": "profile", "slotsPerTab": 100}],
	[&"tree_discovery", &"set", true, {"treeId": "party-forge-warehouse-v1"}],
]

const PERMANENT_EFFECT_IDS: Array[StringName] = [
	&"city_service_unlock", &"feature_unlock", &"mode_unlock", &"region_unlock",
	&"building_discovery", &"extraction_capacity", &"inventory_columns",
	&"stash_tabs", &"tree_discovery",
]

const EFFECT_PRESENTATION := {
	&"city_service_unlock": ["City Service", "Unlock City Service: city_vendors.", "City Service: Permanently unlocks access to a named City service."],
	&"experience_gain": ["Experience Gain", "Experience Gain: +2% (all_run_experience).", "Experience Gain: Increases experience earned in the named scope."],
	&"feature_unlock": ["Feature", "Unlock Feature: equipment_inventory.", "Feature: Permanently unlocks access to a named profile feature."],
	&"mode_unlock": ["Mode", "Unlock Mode: practice.", "Mode: Permanently unlocks access to a named game mode."],
	&"party_capacity": ["Party Capacity", "Party Capacity: +1 (profile).", "Party Capacity: Increases the number of characters the profile can field."],
	&"region_unlock": ["Region", "Unlock Region: north-road.", "Region: Permanently unlocks access to a named world region."],
	&"vendor_inventory_slots": ["Vendor Inventory Slots", "Vendor Inventory Slots: +1 (profile).", "Vendor Inventory Slots: Adds choices to vendor inventories for the profile."],
	&"vendor_reroll_count": ["Vendor Rerolls", "Vendor Rerolls: +1 (profile).", "Vendor Rerolls: Adds vendor inventory refreshes for the profile."],
	&"building_discovery": ["Building Discovery", "Discover Building: warehouse.", "Building Discovery: Permanently discovers a named City building."],
	&"extraction_capacity": ["Extraction Capacity", "Extraction Capacity: +1 (profile).", "Extraction Capacity: Increases how many items the profile can extract."],
	&"inventory_columns": ["Inventory Columns", "Inventory Columns: +1 (profile).", "Inventory Columns: Adds inventory space for the profile."],
	&"stash_tabs": ["Stash Tabs", "Stash Tabs: +1 x 100 slots (profile).", "Stash Tabs: Adds profile stash tabs with the stated slots per tab."],
	&"tree_discovery": ["Passive Tree Discovery", "Discover Passive Tree: party-forge-warehouse-v1.", "Passive Tree Discovery: Permanently discovers a named passive tree."],
}

const LOGISTICS_IDS: Array[StringName] = [
	&"field-pack", &"stash-access", &"extraction-license", &"secured-loadout",
	&"leader-loadout-extraction",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_all_registered_effect_contracts(failures)
	_test_effect_contracts_fail_closed(failures)
	_test_development_permanence_and_unlock_projection(failures)
	_test_effect_presentation_contracts(failures)
	_test_requirement_contract(failures)
	_test_requirement_presentation_contract(failures)
	_test_leader_loadout_extraction_contract(failures)
	_test_city_policy(failures)
	_test_default_catalog(failures)
	_test_catalog_semantic_fail_closed(failures)
	return failures

func _test_all_registered_effect_contracts(failures: Array[String]) -> void:
	var registry := PassiveEffectRegistry.new()
	var expected_ids: Array[StringName] = []
	for contract: Array in EFFECT_CONTRACTS:
		var effect := _effect(contract)
		expected_ids.append(effect.effect_id)
		TestAssertions.equal(registry.validate(effect), "", "%s exact contract validates" % effect.effect_id, failures)

	var city_result := PassiveTreeLoader.new().load_path(CITY_PATH)
	TestAssertions.truthy(city_result.ok(), "City fixture is structurally available to contract tests", failures)
	if not city_result.ok():
		return
	var city_ids: Array[StringName] = []
	for tree_node: PassiveTreeNode in city_result.tree.nodes:
		for effect: PassiveTreeEffect in tree_node.effects:
			TestAssertions.equal(registry.validate(effect), "", "City %s effect validates" % tree_node.id, failures)
			if effect.effect_id not in city_ids:
				city_ids.append(effect.effect_id)
	expected_ids.sort()
	city_ids.sort()
	TestAssertions.equal(city_ids, expected_ids, "City uses exactly every registered Task 5 effect ID", failures)

func _test_effect_contracts_fail_closed(failures: Array[String]) -> void:
	var registry := PassiveEffectRegistry.new()
	_assert_effect_invalid(registry, PassiveTreeEffect.new(&"unknown_effect", &"set", true, {"featureId": "known"}), "unknown effect ID", "unknown", failures)
	_assert_effect_invalid(registry, null, "null effect", "null", failures)
	for contract: Array in EFFECT_CONTRACTS:
		var valid := _effect(contract)
		var wrong_operation := _copy_effect(valid)
		wrong_operation.operation = &"custom"
		_assert_effect_invalid(registry, wrong_operation, "%s rejects wrong operation" % valid.effect_id, "operation", failures)

		var wrong_value := _copy_effect(valid)
		wrong_value.value = 1 if typeof(valid.value) == TYPE_BOOL else 1.5
		_assert_effect_invalid(registry, wrong_value, "%s rejects wrong value type" % valid.effect_id, "value", failures)

		var missing_parameter := _copy_effect(valid)
		missing_parameter.parameters.erase(missing_parameter.parameters.keys()[0])
		_assert_effect_invalid(registry, missing_parameter, "%s rejects a missing parameter" % valid.effect_id, "parameters", failures)

		var extra_parameter := _copy_effect(valid)
		extra_parameter.parameters["extra"] = true
		_assert_effect_invalid(registry, extra_parameter, "%s rejects an extra parameter" % valid.effect_id, "parameters", failures)

	var missing_scope := PassiveTreeEffect.new(&"party_capacity", &"add_flat", 1, {})
	_assert_effect_invalid(registry, missing_scope, "scoped effect requires scope", "scope", failures)
	var invalid_profile_scope := PassiveTreeEffect.new(&"inventory_columns", &"add_flat", 1, {"scope": "party"})
	_assert_effect_invalid(registry, invalid_profile_scope, "profile effect rejects another scope", "scope", failures)
	var invalid_experience_scope := PassiveTreeEffect.new(&"experience_gain", &"add_percent", 2, {"scope": "profile"})
	_assert_effect_invalid(registry, invalid_experience_scope, "experience effect rejects profile scope", "scope", failures)
	var fractional_additive := PassiveTreeEffect.new(&"stash_tabs", &"add_flat", 1.5, {"scope": "profile", "slotsPerTab": 100})
	_assert_effect_invalid(registry, fractional_additive, "fractional additive value is not an integer", "integer", failures)
	var fractional_slots := PassiveTreeEffect.new(&"stash_tabs", &"add_flat", 1, {"scope": "profile", "slotsPerTab": 100.5})
	_assert_effect_invalid(registry, fractional_slots, "stash tab size must be integer-valued", "slotsPerTab", failures)
	var string_additive := PassiveTreeEffect.new(&"party_capacity", &"add_flat", "1", {"scope": "profile"})
	_assert_effect_invalid(registry, string_additive, "additive value rejects numeric string", "integer", failures)
	var bool_additive := PassiveTreeEffect.new(&"inventory_columns", &"add_flat", true, {"scope": "profile"})
	_assert_effect_invalid(registry, bool_additive, "additive value rejects boolean", "integer", failures)
	var string_set := PassiveTreeEffect.new(&"feature_unlock", &"set", "true", {"featureId": "inventory"})
	_assert_effect_invalid(registry, string_set, "set value rejects boolean string", "boolean", failures)
	for invalid_number: float in [NAN, INF, -INF, 1e300, -1e300]:
		var invalid_numeric_effect := PassiveTreeEffect.new(&"experience_gain", &"add_percent", invalid_number, {"scope": "all_run_experience"})
		_assert_effect_invalid(registry, invalid_numeric_effect, "integer contract rejects non-finite or out-of-range %s" % invalid_number, "integer", failures)
	var out_of_range_slots := PassiveTreeEffect.new(&"stash_tabs", &"add_flat", 1, {"scope": "profile", "slotsPerTab": 1e300})
	_assert_effect_invalid(registry, out_of_range_slots, "stash tab size rejects out-of-range integer", "slotsPerTab", failures)
	var empty_identifier := PassiveTreeEffect.new(&"feature_unlock", &"set", true, {"featureId": ""})
	_assert_effect_invalid(registry, empty_identifier, "set contract rejects empty identifier", "featureId", failures)
	var malformed_identifier := PassiveTreeEffect.new(&"tree_discovery", &"set", true, {"treeId": "Bad Tree"})
	_assert_effect_invalid(registry, malformed_identifier, "future contract rejects malformed identifier", "treeId", failures)

func _test_development_permanence_and_unlock_projection(failures: Array[String]) -> void:
	var registry := PassiveEffectRegistry.new()
	for contract: Array in EFFECT_CONTRACTS:
		var effect := _effect(contract)
		TestAssertions.equal(registry.development_state(effect.effect_id), FeatureAccessPolicy.State.COMING_SOON, "%s is Coming Soon" % effect.effect_id, failures)
		TestAssertions.equal(registry.is_permanent(effect), effect.effect_id in PERMANENT_EFFECT_IDS, "%s permanence is explicit" % effect.effect_id, failures)
	TestAssertions.equal(registry.development_state(&"unknown_effect"), FeatureAccessPolicy.State.HIDDEN, "unknown effect development state fails closed", failures)
	TestAssertions.truthy(not registry.is_permanent(PassiveTreeEffect.new(&"feature_unlock", &"custom", true, {"featureId": "inventory"})), "malformed permanent contract is not trusted", failures)
	TestAssertions.equal(registry.unlock_id(PassiveTreeEffect.new(&"feature_unlock", &"set", true, {"featureId": "equipment_inventory"})), &"equipment_inventory", "feature unlock ID", failures)
	TestAssertions.equal(registry.unlock_id(PassiveTreeEffect.new(&"mode_unlock", &"set", true, {"modeId": "practice"})), &"mode:practice", "mode unlock ID", failures)
	TestAssertions.equal(registry.unlock_id(PassiveTreeEffect.new(&"city_service_unlock", &"set", true, {"serviceId": "city_vendors"})), &"service:city_vendors", "service unlock ID", failures)
	TestAssertions.equal(registry.unlock_id(PassiveTreeEffect.new(&"region_unlock", &"set", true, {"regionId": "north-road"})), &"region:north-road", "region unlock ID", failures)
	TestAssertions.equal(registry.unlock_id(PassiveTreeEffect.new(&"experience_gain", &"add_percent", 2, {"scope": "all_run_experience"})), &"", "numeric effect has no unlock ID", failures)
	TestAssertions.equal(registry.unlock_id(PassiveTreeEffect.new(&"mode_unlock", &"custom", true, {"modeId": "practice"})), &"", "malformed unlock contract fails closed", failures)

func _test_effect_presentation_contracts(failures: Array[String]) -> void:
	var registry := PassiveEffectRegistry.new()
	for contract: Array in EFFECT_CONTRACTS:
		var effect := _effect(contract)
		var expected := EFFECT_PRESENTATION[effect.effect_id] as Array
		TestAssertions.equal(registry.display_name(effect.effect_id), expected[0], "%s stable display name" % effect.effect_id, failures)
		TestAssertions.equal(registry.describe(effect), expected[1], "%s structured description" % effect.effect_id, failures)
		TestAssertions.equal(registry.keyword_explanation(effect.effect_id), expected[2], "%s keyword explanation" % effect.effect_id, failures)
	var malformed := PassiveTreeEffect.new(&"stash_tabs", &"add_flat", 1, {"scope": "profile", "slotsPerTab": 0})
	TestAssertions.equal(registry.describe(malformed), "", "malformed effect has no presentation description", failures)
	TestAssertions.equal(registry.display_name(&"unknown_effect"), "", "unknown effect has no display name", failures)
	TestAssertions.equal(registry.keyword_explanation(&"unknown_effect"), "", "unknown effect has no keyword explanation", failures)

func _test_requirement_contract(failures: Array[String]) -> void:
	var registry := PassiveRequirementRegistry.new()
	var valid := PassiveTreeRequirement.new(&"allocated_node", &"contains", "field-pack", {"treeId": "party-forge-city-v1"})
	TestAssertions.equal(registry.validate(valid), "", "allocated_node exact contract validates", failures)
	_assert_requirement_invalid(registry, null, "null requirement", "null", failures)
	_assert_requirement_invalid(registry, PassiveTreeRequirement.new(&"unknown", &"contains", "field-pack", {"treeId": "party-forge-city-v1"}), "unknown requirement ID", "unknown", failures)
	_assert_requirement_invalid(registry, PassiveTreeRequirement.new(&"allocated_node", &"equals", "field-pack", {"treeId": "party-forge-city-v1"}), "allocated_node rejects operator", "operator", failures)
	_assert_requirement_invalid(registry, PassiveTreeRequirement.new(&"allocated_node", &"contains", "", {"treeId": "party-forge-city-v1"}), "allocated_node rejects empty node ID", "value", failures)
	_assert_requirement_invalid(registry, PassiveTreeRequirement.new(&"allocated_node", &"contains", "Field Pack", {"treeId": "party-forge-city-v1"}), "allocated_node requires kebab-case node ID", "value", failures)
	_assert_requirement_invalid(registry, PassiveTreeRequirement.new(&"allocated_node", &"contains", 7, {"treeId": "party-forge-city-v1"}), "allocated_node rejects non-string node ID", "value", failures)
	_assert_requirement_invalid(registry, PassiveTreeRequirement.new(&"allocated_node", &"contains", "field-pack", {}), "allocated_node requires treeId", "treeId", failures)
	_assert_requirement_invalid(registry, PassiveTreeRequirement.new(&"allocated_node", &"contains", "field-pack", {"treeId": "party-forge-city-v1", "extra": true}), "allocated_node rejects extra parameter", "parameters", failures)
	_assert_requirement_invalid(registry, PassiveTreeRequirement.new(&"allocated_node", &"contains", "field-pack", {"treeId": "bad tree"}), "allocated_node requires kebab-case treeId", "treeId", failures)

func _test_requirement_presentation_contract(failures: Array[String]) -> void:
	var registry := PassiveRequirementRegistry.new()
	var requirement := PassiveTreeRequirement.new(&"allocated_node", &"contains", "field-pack", {"treeId": "party-forge-city-v1"})
	TestAssertions.equal(registry.display_name(requirement.requirement_id), "Allocated Node", "requirement stable display name", failures)
	TestAssertions.equal(registry.describe(requirement), "Requires allocated node: field-pack (party-forge-city-v1).", "requirement structured description", failures)
	TestAssertions.equal(registry.keyword_explanation(requirement.requirement_id), "Allocated Node: Requires the named node to be allocated in the named passive tree.", "requirement keyword explanation", failures)
	TestAssertions.equal(registry.describe(PassiveTreeRequirement.new(&"allocated_node", &"equals", "field-pack", {"treeId": "party-forge-city-v1"})), "", "malformed requirement has no presentation description", failures)
	TestAssertions.equal(registry.display_name(&"unknown_requirement"), "", "unknown requirement has no display name", failures)
	TestAssertions.equal(registry.keyword_explanation(&"unknown_requirement"), "", "unknown requirement has no keyword explanation", failures)

func _test_leader_loadout_extraction_contract(failures: Array[String]) -> void:
	var document := _city_document()
	var extraction_node := _document_node(document, "leader-loadout-extraction")
	TestAssertions.truthy(not extraction_node.is_empty(), "City contains Leader Loadout Extraction", failures)
	if extraction_node.is_empty():
		return
	TestAssertions.equal(extraction_node.get("name"), "Leader Loadout Extraction", "leader extraction name", failures)
	TestAssertions.equal(extraction_node.get("type"), "large", "leader extraction is large", failures)
	TestAssertions.equal(extraction_node.get("cost"), 1, "leader extraction costs one Passive Point", failures)
	TestAssertions.equal(extraction_node.get("effects"), [{
		"effectId": "feature_unlock",
		"operation": "set",
		"value": true,
		"parameters": {"featureId": "leader_loadout_extraction"},
	}], "leader extraction exact feature unlock", failures)
	TestAssertions.equal(extraction_node.get("metadata", {}).get("developmentState"), "coming-soon", "leader extraction development state", failures)
	TestAssertions.equal(extraction_node.get("metadata", {}).get("refundPolicy"), "permanent", "leader extraction cannot be refunded", failures)
	var adjacent := false
	for connection_value: Variant in document.get("connections", []):
		var connection := connection_value as Dictionary
		if (connection.get("from") == "secured-loadout" and connection.get("to") == "leader-loadout-extraction") \
		or (connection.get("from") == "leader-loadout-extraction" and connection.get("to") == "secured-loadout"):
			adjacent = connection.get("direction") == "bidirectional" and connection.get("cost") == 0
	TestAssertions.truthy(adjacent, "Leader Loadout Extraction is adjacent to Secured Loadout by one bidirectional zero-cost edge", failures)

func _test_city_policy(failures: Array[String]) -> void:
	var policy := CityPassiveTreePolicy.new()
	var valid_tree := _load_city_tree(failures)
	if valid_tree == null:
		return
	TestAssertions.equal(policy.validate(valid_tree), [], "production City fixture satisfies City policy", failures)
	var wrong_tree_id := _load_city_tree(failures)
	wrong_tree_id.id = &"wrong-city"
	_assert_policy_invalid(policy, wrong_tree_id, "City policy requires exact tree ID", "party-forge-city-v1", failures)
	var wrong_start := _load_city_tree(failures)
	wrong_start.starting_node_ids.assign([&"field-pack"])
	_assert_policy_invalid(policy, wrong_start, "City policy requires city-heart start", "city-heart", failures)
	var extra_start := _load_city_tree(failures)
	extra_start.starting_node_ids.assign([&"city-heart", &"field-pack"])
	_assert_policy_invalid(policy, extra_start, "City policy rejects extra starting node", "city-heart", failures)

	var missing_node_tree := _load_city_tree(failures)
	missing_node_tree.nodes.remove_at(0)
	_assert_policy_invalid(policy, missing_node_tree, "City requires exactly 31 nodes", "31 nodes", failures)
	var missing_connection_tree := _load_city_tree(failures)
	missing_connection_tree.connections.remove_at(0)
	_assert_policy_invalid(policy, missing_connection_tree, "City requires exactly 31 connections", "31 connections", failures)

	for logistics_id: StringName in LOGISTICS_IDS:
		var missing_logistics_tree := _load_city_tree(failures)
		_remove_node(missing_logistics_tree, logistics_id)
		_assert_policy_invalid(policy, missing_logistics_tree, "City requires %s" % logistics_id, String(logistics_id), failures)

	var missing_requirement_tree := _load_city_tree(failures)
	missing_requirement_tree.node(&"extraction-license").requirements.remove_at(0)
	_assert_policy_invalid(policy, missing_requirement_tree, "Extraction License requires both prerequisites", "requirements", failures)
	var wrong_requirement_tree := _load_city_tree(failures)
	wrong_requirement_tree.node(&"extraction-license").requirements[0].value = "wrong-node"
	_assert_policy_invalid(policy, wrong_requirement_tree, "Extraction License prerequisites are exact", "field-pack", failures)

	for logistics_id: StringName in LOGISTICS_IDS:
		for metadata_key: String in ["integrationStatus", "developmentState", "refundPolicy"]:
			var wrong_metadata_tree := _load_city_tree(failures)
			if wrong_metadata_tree.node(logistics_id) == null:
				continue
			wrong_metadata_tree.node(logistics_id).metadata[metadata_key] = "wrong"
			_assert_policy_invalid(policy, wrong_metadata_tree, "%s requires exact %s metadata" % [logistics_id, metadata_key], metadata_key, failures)

	var wrong_stash_size_tree := _load_city_tree(failures)
	var stash_effect := _find_effect(wrong_stash_size_tree.node(&"stash-access"), &"stash_tabs")
	stash_effect.parameters["slotsPerTab"] = 99
	_assert_policy_invalid(policy, wrong_stash_size_tree, "City stash tab size is exactly 100", "100", failures)

func _test_default_catalog(failures: Array[String]) -> void:
	var first := PassiveTreeCatalog.load_defaults()
	TestAssertions.truthy(first.ok(), "default catalog loads validated City tree", failures)
	TestAssertions.equal(first.errors, [], "default catalog has no semantic errors", failures)
	if not first.ok():
		return
	first.tree.nodes.clear()
	var second := PassiveTreeCatalog.load_defaults()
	TestAssertions.truthy(second.ok(), "default catalog reloads after caller mutation", failures)
	if second.ok():
		TestAssertions.equal(second.tree.nodes.size(), 31, "default catalog does not cache a partial or mutable tree", failures)
		TestAssertions.truthy(first.tree != second.tree, "default catalog returns independent tree definitions", failures)

func _test_catalog_semantic_fail_closed(failures: Array[String]) -> void:
	var unknown_effect_document := _city_document()
	var arena_charter := _document_node(unknown_effect_document, "arena-charter")
	(arena_charter["effects"] as Array)[0]["effectId"] = "unknown_effect"
	_assert_catalog_invalid(unknown_effect_document, "user://task-5-unknown-effect.json", "unknown effect is rejected at catalog boundary", "unknown effect", failures)

	var unknown_requirement_document := _city_document()
	var extraction_license := _document_node(unknown_requirement_document, "extraction-license")
	(extraction_license["requirements"] as Array)[0]["requirementId"] = "unknown_requirement"
	_assert_catalog_invalid(unknown_requirement_document, "user://task-5-unknown-requirement.json", "unknown requirement is rejected at catalog boundary", "unknown requirement", failures)

	var wrong_city_document := _city_document()
	wrong_city_document["treeId"] = "wrong-city"
	_assert_catalog_invalid(wrong_city_document, "user://task-5-wrong-city-policy.json", "City policy violation is rejected at catalog boundary", "party-forge-city-v1", failures)

	var connection_cost_document := _city_document()
	(connection_cost_document["connections"] as Array)[0]["cost"] = 1
	_assert_catalog_invalid(connection_cost_document, "user://task-review-connection-cost.json", "unsupported connection cost is rejected at catalog boundary", "PARTY_FORGE_PASSIVE_TREE_ERROR semantic=unsupported_connection_cost", failures)

	var connection_condition_document := _city_document()
	(connection_condition_document["connections"] as Array)[0]["conditions"] = [{"requirementId": "allocated_node", "operator": "contains", "value": "city-heart", "parameters": {"treeId": "party-forge-city-v1"}}]
	_assert_catalog_invalid(connection_condition_document, "user://task-review-connection-condition.json", "unsupported connection conditions are rejected at catalog boundary", "PARTY_FORGE_PASSIVE_TREE_ERROR semantic=unsupported_connection_conditions", failures)

	var default_after_errors := PassiveTreeCatalog.load_defaults()
	TestAssertions.truthy(default_after_errors.ok(), "semantic errors do not poison the default catalog", failures)
	if default_after_errors.ok():
		TestAssertions.equal(default_after_errors.tree.nodes.size(), 31, "catalog caches no partial tree after semantic errors", failures)

func _effect(contract: Array) -> PassiveTreeEffect:
	return PassiveTreeEffect.new(contract[0], contract[1], contract[2], contract[3])

func _copy_effect(effect: PassiveTreeEffect) -> PassiveTreeEffect:
	return PassiveTreeEffect.new(effect.effect_id, effect.operation, effect.value, effect.parameters)

func _assert_effect_invalid(registry: PassiveEffectRegistry, effect: PassiveTreeEffect, label: String, fragment: String, failures: Array[String]) -> void:
	var error := registry.validate(effect)
	TestAssertions.truthy(not error.is_empty(), label, failures)
	TestAssertions.truthy(fragment in error, "%s reports %s" % [label, fragment], failures)

func _assert_requirement_invalid(registry: PassiveRequirementRegistry, requirement: PassiveTreeRequirement, label: String, fragment: String, failures: Array[String]) -> void:
	var error := registry.validate(requirement)
	TestAssertions.truthy(not error.is_empty(), label, failures)
	TestAssertions.truthy(fragment in error, "%s reports %s" % [label, fragment], failures)

func _load_city_tree(failures: Array[String]) -> PassiveTreeDefinition:
	var result := PassiveTreeLoader.new().load_path(CITY_PATH)
	TestAssertions.truthy(result.ok(), "City fixture loads for policy mutation", failures)
	return result.tree

func _remove_node(tree: PassiveTreeDefinition, node_id: StringName) -> void:
	for index: int in tree.nodes.size():
		if tree.nodes[index].id == node_id:
			tree.nodes.remove_at(index)
			return

func _find_effect(tree_node: PassiveTreeNode, effect_id: StringName) -> PassiveTreeEffect:
	for effect: PassiveTreeEffect in tree_node.effects:
		if effect.effect_id == effect_id:
			return effect
	return null

func _assert_policy_invalid(policy: CityPassiveTreePolicy, tree: PassiveTreeDefinition, label: String, fragment: String, failures: Array[String]) -> void:
	var errors := policy.validate(tree)
	TestAssertions.truthy(not errors.is_empty(), label, failures)
	TestAssertions.truthy(errors.any(func(error: String) -> bool: return fragment in error), "%s reports %s" % [label, fragment], failures)

func _city_document() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CITY_PATH)) as Dictionary

func _document_node(document: Dictionary, node_id: String) -> Dictionary:
	for node_value: Variant in document["nodes"]:
		var node_document := node_value as Dictionary
		if node_document.get("id") == node_id:
			return node_document
	return {}

func _assert_catalog_invalid(document: Dictionary, path: String, label: String, fragment: String, failures: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()
	var result := PassiveTreeCatalog.load_path(path)
	TestAssertions.truthy(not result.errors.is_empty(), label, failures)
	TestAssertions.equal(result.tree, null, "%s returns no partial tree" % label, failures)
	TestAssertions.truthy(result.errors.any(func(error: String) -> bool: return fragment in error), "%s reports %s" % [label, fragment], failures)
