extends RefCounted

const SIGNED_64_MAX := 9223372036854775807

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_city_numeric_aggregation_is_deterministic(failures)
	_test_stash_future_contract_projection_is_defensive(failures)
	_test_exact_unlock_ids_and_future_states(failures)
	_test_unknown_and_invalid_inputs_fail_closed(failures)
	_test_integer_overflow_fails_closed(failures)
	_test_same_key_overflow_is_independent_of_effect_order(failures)
	return failures

func _test_city_numeric_aggregation_is_deterministic(failures: Array[String]) -> void:
	var tree := _tree_with_nodes([
		_node(&"shared-lessons-1", [PassiveTreeEffect.new(&"experience_gain", &"add_percent", 2, {"scope": "all_run_experience"})]),
		_node(&"shared-lessons-2", [PassiveTreeEffect.new(&"experience_gain", &"add_percent", 2, {"scope": "all_run_experience"})]),
		_node(&"expanded-barracks", [PassiveTreeEffect.new(&"party_capacity", &"add_flat", 1, {"scope": "profile"})]),
	])
	var allocations: Array[StringName] = [
		&"expanded-barracks", &"shared-lessons-2", &"shared-lessons-1", &"shared-lessons-2",
	]
	var original_allocations := allocations.duplicate()
	var shared_lessons_effect := tree.node(&"shared-lessons-1").effects[0]
	var resolution := PassiveEffectResolver.new(PassiveEffectRegistry.new()).resolve(tree, allocations)

	TestAssertions.equal(allocations, original_allocations, "resolver does not reorder or deduplicate caller allocations", failures)
	TestAssertions.equal(resolution.percent_value(&"experience_gain", &"all_run_experience"), 4, "XP adds deterministically", failures)
	TestAssertions.equal(resolution.flat_value(&"party_capacity", &"profile"), 1, "capacity adds flat", failures)
	TestAssertions.equal(resolution.percent_value(&"experience_gain", &"profile"), 0, "percent scope is exact", failures)
	TestAssertions.equal(resolution.flat_value(&"party_capacity", &"party"), 0, "flat scope is exact", failures)
	TestAssertions.equal(shared_lessons_effect.value, 2, "resolver does not mutate source effects", failures)

	var reordered: Array[StringName] = [&"shared-lessons-1", &"expanded-barracks", &"shared-lessons-2"]
	var reordered_resolution := PassiveEffectResolver.new(PassiveEffectRegistry.new()).resolve(tree, reordered)
	TestAssertions.equal(reordered_resolution.flat_values(), resolution.flat_values(), "flat aggregation ignores allocation input order", failures)
	TestAssertions.equal(reordered_resolution.percent_values(), resolution.percent_values(), "percent aggregation ignores allocation input order", failures)

	allocations.clear()
	var returned_percent_values := resolution.percent_values()
	(returned_percent_values[&"experience_gain"] as Dictionary)[&"all_run_experience"] = 99
	TestAssertions.equal(resolution.percent_value(&"experience_gain", &"all_run_experience"), 4, "caller mutations cannot alter stored percent values", failures)

func _test_stash_future_contract_projection_is_defensive(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var stash_effect_ids: Array[StringName] = []
	for effect: PassiveTreeEffect in tree.node(&"stash-access").effects:
		stash_effect_ids.append(effect.effect_id)
	var profile := ProfileState.new()
	var resolution := PassiveEffectResolver.new(PassiveEffectRegistry.new()).resolve(tree, [&"stash-access", &"logistics-district-charter"])

	TestAssertions.equal(resolution.permanent_unlock_ids(), [&"stash"], "Stash Access grants the exact permanent unlock", failures)
	TestAssertions.equal(resolution.building_discoveries(), [&"warehouse"], "Stash Access discovers the warehouse", failures)
	TestAssertions.equal(resolution.tree_discoveries(), [&"party-forge-warehouse-v1"], "Stash Access discovers the warehouse tree", failures)
	TestAssertions.equal(resolution.set_values(&"feature_unlock"), [&"stash"], "feature unlock set is typed by canonical unlock ID", failures)
	TestAssertions.equal(
		resolution.stash_tab_contracts(),
		[{"count": 1, "scope": &"profile", "slotsPerTab": 100}],
		"Stash Access projects one future 100-slot profile tab",
		failures,
	)
	TestAssertions.equal(profile.stash_tabs, [], "resolution does not create profile stash storage", failures)
	TestAssertions.equal(stash_effect_ids, _effect_ids(tree.node(&"stash-access")), "effect sorting does not mutate the City node", failures)

	var unlocks := resolution.permanent_unlock_ids()
	unlocks.append(&"caller-injected")
	var buildings := resolution.building_discoveries()
	buildings.clear()
	var contracts := resolution.stash_tab_contracts()
	contracts[0]["count"] = 99
	TestAssertions.equal(resolution.permanent_unlock_ids(), [&"stash"], "permanent unlock accessor is defensive", failures)
	TestAssertions.equal(resolution.building_discoveries(), [&"warehouse"], "building discovery accessor is defensive", failures)
	TestAssertions.equal(resolution.stash_tab_contracts()[0]["count"], 1, "stash contract accessor is deeply defensive", failures)

func _test_exact_unlock_ids_and_future_states(failures: Array[String]) -> void:
	var tree := _tree_with_nodes([
		_node(&"north-road-charter", [PassiveTreeEffect.new(&"region_unlock", &"set", true, {"regionId": "north-road"})]),
		_node(&"artificers-hall", [PassiveTreeEffect.new(&"city_service_unlock", &"set", true, {"serviceId": "crafting"})]),
		_node(&"equipment-registry", [PassiveTreeEffect.new(&"feature_unlock", &"set", true, {"featureId": "equipment_inventory"})]),
		_node(&"arena-charter", [PassiveTreeEffect.new(&"mode_unlock", &"set", true, {"modeId": "battle"})]),
	])
	var resolution := PassiveEffectResolver.new(PassiveEffectRegistry.new()).resolve(tree, [
		&"north-road-charter", &"artificers-hall", &"equipment-registry", &"arena-charter",
	])
	var expected_unlocks: Array[StringName] = [
		&"equipment_inventory", &"mode:battle", &"region:north-road", &"service:crafting",
	]
	TestAssertions.equal(resolution.permanent_unlock_ids(), expected_unlocks, "registry prefixes remain exact and deterministic", failures)
	TestAssertions.equal(resolution.set_values(&"feature_unlock"), [&"equipment_inventory"], "feature unlock stays unprefixed", failures)
	TestAssertions.equal(resolution.set_values(&"mode_unlock"), [&"mode:battle"], "mode unlock is prefixed", failures)
	TestAssertions.equal(resolution.set_values(&"city_service_unlock"), [&"service:crafting"], "service unlock is prefixed", failures)
	TestAssertions.equal(resolution.set_values(&"region_unlock"), [&"region:north-road"], "region unlock is prefixed", failures)
	for unlock_id: StringName in expected_unlocks:
		TestAssertions.equal(resolution.feature_state(unlock_id), FeatureAccessPolicy.State.COMING_SOON, "%s preserves future-contract state" % unlock_id, failures)
	TestAssertions.equal(resolution.feature_state(&"unknown"), FeatureAccessPolicy.State.HIDDEN, "absent future-contract state fails closed", failures)
	var states := resolution.feature_states()
	states[&"equipment_inventory"] = FeatureAccessPolicy.State.AVAILABLE
	TestAssertions.equal(resolution.feature_state(&"equipment_inventory"), FeatureAccessPolicy.State.COMING_SOON, "feature state map is defensive", failures)

func _test_unknown_and_invalid_inputs_fail_closed(failures: Array[String]) -> void:
	var city_tree := _city_tree(failures)
	if city_tree == null:
		return
	var unknown_resolution := PassiveEffectResolver.new(PassiveEffectRegistry.new()).resolve(city_tree, [&"missing-node"])
	TestAssertions.equal(unknown_resolution.flat_values(), {}, "unknown allocation grants no flat values", failures)
	TestAssertions.equal(unknown_resolution.percent_values(), {}, "unknown allocation grants no percent values", failures)
	TestAssertions.equal(unknown_resolution.permanent_unlock_ids(), [], "unknown allocation grants no unlocks", failures)

	var invalid_effects: Array[PassiveTreeEffect] = [
		PassiveTreeEffect.new(&"unknown_effect", &"add_flat", 50, {"scope": "profile"}),
		PassiveTreeEffect.new(&"party_capacity", &"custom", 50, {"scope": "profile"}),
		PassiveTreeEffect.new(&"experience_gain", &"add_percent", 50, {"scope": "personal"}),
		PassiveTreeEffect.new(&"feature_unlock", &"set", false, {"featureId": "not-granted"}),
	]
	var invalid_tree := _tree_with_nodes([_node(&"invalid", invalid_effects)])
	var invalid_resolution := PassiveEffectResolver.new(PassiveEffectRegistry.new()).resolve(invalid_tree, [&"invalid"])
	TestAssertions.equal(invalid_resolution.flat_values(), {}, "unknown and invalid flat effects grant nothing", failures)
	TestAssertions.equal(invalid_resolution.percent_values(), {}, "invalid explicit scope grants nothing", failures)
	TestAssertions.equal(invalid_resolution.permanent_unlock_ids(), [], "false and invalid set effects grant nothing", failures)

func _test_integer_overflow_fails_closed(failures: Array[String]) -> void:
	var maximum := PassiveTreeEffect.new(&"party_capacity", &"add_flat", SIGNED_64_MAX, {"scope": "profile"})
	var overflow := PassiveTreeEffect.new(&"party_capacity", &"add_flat", 1, {"scope": "profile"})
	var tree := _tree_with_nodes([
		_node(&"a-maximum", [maximum]),
		_node(&"b-overflow", [overflow]),
	])
	var resolution := PassiveEffectResolver.new(PassiveEffectRegistry.new()).resolve(tree, [&"b-overflow", &"a-maximum"])
	TestAssertions.equal(resolution.flat_value(&"party_capacity", &"profile"), SIGNED_64_MAX, "overflowing contribution is ignored without integer wrap", failures)

func _test_same_key_overflow_is_independent_of_effect_order(failures: Array[String]) -> void:
	var maximum := PassiveTreeEffect.new(&"party_capacity", &"add_flat", SIGNED_64_MAX, {"scope": "profile"})
	var positive := PassiveTreeEffect.new(&"party_capacity", &"add_flat", 1, {"scope": "profile"})
	var negative := PassiveTreeEffect.new(&"party_capacity", &"add_flat", -1, {"scope": "profile"})
	var first_tree := _tree_with_nodes([_node(&"same-key", [maximum, positive, negative])])
	var second_tree := _tree_with_nodes([_node(&"same-key", [negative, positive, maximum])])
	var resolver := PassiveEffectResolver.new(PassiveEffectRegistry.new())
	var first := resolver.resolve(first_tree, [&"same-key"])
	var second := resolver.resolve(second_tree, [&"same-key"])
	TestAssertions.equal(first.flat_values(), second.flat_values(), "same-key overflow aggregation is independent of source effect order", failures)

func _city_tree(failures: Array[String]) -> PassiveTreeDefinition:
	var result := PassiveTreeCatalog.load_defaults()
	TestAssertions.truthy(result.ok(), "committed City artifact loads for effect resolution", failures)
	return result.tree

func _tree_with_nodes(nodes: Array[PassiveTreeNode]) -> PassiveTreeDefinition:
	return PassiveTreeDefinition.new(&"test-tree", "Test Tree", [], nodes)

func _node(node_id: StringName, effects: Array[PassiveTreeEffect]) -> PassiveTreeNode:
	return PassiveTreeNode.new(node_id, &"small", Vector2.ZERO, String(node_id), "", 0, [], null, effects)

func _effect_ids(tree_node: PassiveTreeNode) -> Array[StringName]:
	var result: Array[StringName] = []
	for effect: PassiveTreeEffect in tree_node.effects:
		result.append(effect.effect_id)
	return result
