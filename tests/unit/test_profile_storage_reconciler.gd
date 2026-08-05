extends RefCounted

const PROFILE_ID := "profile-storage01"

class StubResolver extends PassiveEffectResolver:
	var _stub_resolution: PassiveEffectResolution

	func _init(resolution: PassiveEffectResolution) -> void:
		super(PassiveEffectRegistry.new())
		_stub_resolution = resolution

	func resolve(_tree: PassiveTreeDefinition, _allocated_ids: Array[StringName]) -> PassiveEffectResolution:
		return _stub_resolution

func run() -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists("res://scripts/profile/profile_storage_reconciler.gd"):
		TestAssertions.truthy(false, "profile storage reconciler implementation exists", failures)
		return failures
	var tree_result := PassiveTreeCatalog.load_defaults()
	TestAssertions.truthy(tree_result.ok(), "City tree loads for storage reconciliation", failures)
	if not tree_result.ok():
		return failures
	var tree := tree_result.tree
	_test_direct_projection_matrix(tree, failures)
	_test_idempotence_monotonicity_and_existing_placement(tree, failures)
	_test_non_profile_contracts_are_ignored(tree, failures)
	_test_failures_are_atomic(tree, failures)
	return failures

func _test_direct_projection_matrix(tree: PassiveTreeDefinition, failures: Array[String]) -> void:
	var reconciler := ProfileStorageReconciler.new()
	var empty := _profile(tree.id, [])
	TestAssertions.equal(reconciler.reconcile(empty, tree, PassiveEffectResolver.new(PassiveEffectRegistry.new())), "", "empty allocations reconcile", failures)
	TestAssertions.equal(empty.inventory_columns, 0, "empty allocations grant no columns", failures)
	TestAssertions.equal(empty.stash_tabs, [], "empty allocations grant no stash", failures)

	var field_pack := _profile(tree.id, ["field-pack", "field-pack"])
	TestAssertions.equal(reconciler.reconcile(field_pack, tree, PassiveEffectResolver.new(PassiveEffectRegistry.new())), "", "duplicate Field Pack allocations reconcile", failures)
	TestAssertions.equal(field_pack.inventory_columns, 1, "field pack grants one column", failures)
	var field_pack_run_capacity := 5 * field_pack.inventory_columns
	TestAssertions.equal(field_pack_run_capacity, 5, "one column means five run slots", failures)
	TestAssertions.equal(field_pack.stash_tabs, [], "field pack does not grant a stash tab", failures)

	var stash := _profile(tree.id, ["stash-access", "stash-access"])
	TestAssertions.equal(reconciler.reconcile(stash, tree, PassiveEffectResolver.new(PassiveEffectRegistry.new())), "", "duplicate Stash Access allocations reconcile", failures)
	TestAssertions.equal(stash.stash_tabs.size(), 1, "stash access grants one tab", failures)
	TestAssertions.equal(int(stash.stash_tabs[0]["capacity"]), 100, "stash tab has 100 slots", failures)
	TestAssertions.equal(stash.stash_tabs[0]["container_id"], "stash-tab-000", "first stash id is stable", failures)
	TestAssertions.equal(stash.stash_tabs[0], _tab_document(PROFILE_ID, "stash-tab-000"), "new stash tab uses the exact schema owner kind capacity and empty slots", failures)

	var both := _profile(tree.id, ["stash-access", "field-pack", "stash-access", "field-pack"])
	TestAssertions.equal(reconciler.reconcile(both, tree, PassiveEffectResolver.new(PassiveEffectRegistry.new())), "", "combined storage allocations reconcile", failures)
	TestAssertions.equal(both.inventory_columns, 1, "combined allocations keep one Field Pack column", failures)
	TestAssertions.equal(both.stash_tabs.size(), 1, "combined allocations keep one Stash Access tab", failures)

func _test_idempotence_monotonicity_and_existing_placement(tree: PassiveTreeDefinition, failures: Array[String]) -> void:
	var reconciler := ProfileStorageReconciler.new()
	var profile := _profile(tree.id, ["field-pack", "stash-access"])
	var item := _item("item-existing-placement", 0)
	profile.inventory_columns = 3
	profile.item_records = ItemRegistry.new([item]).to_dictionary()
	profile.stash_tabs = [_tab_document(PROFILE_ID, "stash-tab-000", {42: item.instance_id})]
	var before_item := profile.item_records.duplicate(true)
	var before_tabs := profile.stash_tabs.duplicate(true)
	TestAssertions.equal(reconciler.reconcile(profile, tree, PassiveEffectResolver.new(PassiveEffectRegistry.new())), "", "pre-existing placed item reconciles", failures)
	var once := JSON.stringify(profile.to_dictionary())
	TestAssertions.equal(profile.inventory_columns, 3, "reconciliation never shrinks existing columns", failures)
	TestAssertions.equal(profile.item_records, before_item, "reconciliation never rewrites item records", failures)
	TestAssertions.equal(profile.stash_tabs, before_tabs, "reconciliation preserves exact existing slot placement", failures)
	TestAssertions.equal(reconciler.reconcile(profile, tree, PassiveEffectResolver.new(PassiveEffectRegistry.new())), "", "repeated reconciliation succeeds", failures)
	TestAssertions.equal(JSON.stringify(profile.to_dictionary()), once, "repeated reconciliation is byte-equivalent", failures)

	profile.tree_allocations[String(tree.id)] = []
	var granted := JSON.stringify(profile.to_dictionary())
	TestAssertions.equal(reconciler.reconcile(profile, tree, PassiveEffectResolver.new(PassiveEffectRegistry.new())), "", "refunded storage allocations reconcile", failures)
	TestAssertions.equal(JSON.stringify(profile.to_dictionary()), granted, "refunded permanent storage is never removed or rewritten", failures)

func _test_non_profile_contracts_are_ignored(tree: PassiveTreeDefinition, failures: Array[String]) -> void:
	var profile := _profile(tree.id, ["city-heart"])
	var resolution := PassiveEffectResolution.new(
		{&"inventory_columns": {&"profile": 2}},
		{},
		{},
		[],
		[],
		[],
		[
			{"count": 1000, "scope": &"party", "slotsPerTab": 17},
			{"count": "malformed-but-ignored", "scope": &"personal", "slotsPerTab": null},
		]
	)
	var error := ProfileStorageReconciler.new().reconcile(profile, tree, StubResolver.new(resolution))
	TestAssertions.equal(error, "", "non-profile stash contracts are ignored", failures)
	TestAssertions.equal(profile.inventory_columns, 2, "profile inventory columns still project beside ignored contracts", failures)
	TestAssertions.equal(profile.stash_tabs, [], "ignored scopes create no profile stash", failures)

func _test_failures_are_atomic(tree: PassiveTreeDefinition, failures: Array[String]) -> void:
	var reconciler := ProfileStorageReconciler.new()
	var valid_resolver := PassiveEffectResolver.new(PassiveEffectRegistry.new())
	TestAssertions.truthy(reconciler.reconcile(null, tree, valid_resolver).begins_with("PARTY_FORGE_PROFILE_STORAGE_ERROR field=profile"), "null profile fails with a stable diagnostic", failures)
	var null_tree_profile := _profile(tree.id, ["field-pack"])
	_assert_failure_atomic(null_tree_profile, null, valid_resolver, "tree", "null tree", failures)
	var null_resolver_profile := _profile(tree.id, ["field-pack"])
	_assert_failure_atomic(null_resolver_profile, tree, null, "resolver", "null resolver", failures)

	var malformed_map := _profile(tree.id, [])
	malformed_map.tree_allocations[String(tree.id)] = "field-pack"
	_assert_failure_atomic(malformed_map, tree, valid_resolver, "tree_allocations", "non-array allocation value", failures)
	var malformed_member := _profile(tree.id, [])
	malformed_member.tree_allocations[String(tree.id)] = ["field-pack", 7]
	_assert_failure_atomic(malformed_member, tree, valid_resolver, "tree_allocations", "non-string allocation member", failures)

	var invalid_contracts: Array[Dictionary] = [
		{"label": "nonpositive count", "field": "stash_tabs", "contract": {"count": 0, "scope": &"profile", "slotsPerTab": 100}},
		{"label": "fractional count", "field": "stash_tabs", "contract": {"count": 1.5, "scope": &"profile", "slotsPerTab": 100}},
		{"label": "unsafe count", "field": "stash_tabs", "contract": {"count": ProfileCodec.JSON_SAFE_INTEGER_MAX + 1, "scope": &"profile", "slotsPerTab": 100}},
		{"label": "wrong slots per tab", "field": "stash_tabs", "contract": {"count": 1, "scope": &"profile", "slotsPerTab": 99}},
		{"label": "tab count cap", "field": "stash_tabs", "contract": {"count": 101, "scope": &"profile", "slotsPerTab": 100}},
	]
	for test_case: Dictionary in invalid_contracts:
		var profile := _profile(tree.id, ["city-heart"])
		profile.inventory_columns = 1
		var resolution := PassiveEffectResolution.new(
			{&"inventory_columns": {&"profile": 3}}, {}, {}, [], [], [], [test_case["contract"]]
		)
		_assert_failure_atomic(profile, tree, StubResolver.new(resolution), test_case["field"], test_case["label"], failures)

	var collision := _profile(tree.id, ["city-heart"])
	collision.stash_tabs = [_tab_document(PROFILE_ID, "stash-tab-001")]
	var collision_resolution := PassiveEffectResolution.new({}, {}, {}, [], [], [], [
		{"count": 2, "scope": &"profile", "slotsPerTab": 100},
	])
	_assert_failure_atomic(collision, tree, StubResolver.new(collision_resolution), "stash_tabs", "stable ID collision", failures)

	var malformed_existing := _profile(tree.id, ["city-heart"])
	malformed_existing.stash_tabs = [_tab_document("profile-other000", "stash-tab-000")]
	_assert_failure_atomic(malformed_existing, tree, valid_resolver, "stash_tabs", "invalid pre-existing ownership", failures)

	var oversized_existing := _profile(tree.id, ["city-heart"])
	for index: int in 101:
		oversized_existing.stash_tabs.append(_tab_document(PROFILE_ID, "stash-tab-%03d" % index))
	var at_cap := _profile(tree.id, ["city-heart"])
	at_cap.stash_tabs = oversized_existing.stash_tabs.slice(0, ProfileState.MAX_STASH_TABS)
	var at_cap_before := JSON.stringify(at_cap.to_dictionary())
	TestAssertions.equal(reconciler.reconcile(at_cap, tree, valid_resolver), "", "exactly 100 existing stash tabs still reconcile", failures)
	TestAssertions.equal(JSON.stringify(at_cap.to_dictionary()), at_cap_before, "100-tab reconciliation preserves exact placement and bytes", failures)
	var oversized_before := oversized_existing.to_dictionary()
	var oversized_bytes := JSON.stringify(oversized_before)
	var oversized_error := reconciler.reconcile(oversized_existing, tree, valid_resolver)
	TestAssertions.truthy(oversized_error.begins_with("PARTY_FORGE_PROFILE_STORAGE_ERROR field=stash_tabs") and oversized_error.contains("maximum 100"), "101 valid existing stash tabs fail at the reconciliation boundary", failures)
	TestAssertions.equal(oversized_existing.to_dictionary(), oversized_before, "oversized existing stash rejection preserves original profile state", failures)
	TestAssertions.equal(JSON.stringify(oversized_existing.to_dictionary()), oversized_bytes, "oversized existing stash rejection preserves exact serialized bytes", failures)

func _assert_failure_atomic(
	profile: ProfileState,
	tree: PassiveTreeDefinition,
	resolver: PassiveEffectResolver,
	expected_field: String,
	label: String,
	failures: Array[String]
) -> void:
	var before := JSON.stringify(profile.to_dictionary())
	var error := ProfileStorageReconciler.new().reconcile(profile, tree, resolver)
	TestAssertions.truthy(error.begins_with("PARTY_FORGE_PROFILE_STORAGE_ERROR field=%s" % expected_field), "%s reports a stable field diagnostic" % label, failures)
	TestAssertions.equal(JSON.stringify(profile.to_dictionary()), before, "%s leaves the input profile byte-equivalent" % label, failures)

func _profile(tree_id: StringName, allocations: Array[String]) -> ProfileState:
	var profile := ProfileState.new_profile(PROFILE_ID, "Storage Tester", 1000)
	profile.discovered_trees.append(String(tree_id))
	profile.tree_allocations[String(tree_id)] = allocations.duplicate()
	return profile

func _tab_document(owner_id: String, container_id: String, slots: Dictionary = {}) -> Dictionary:
	return ItemSlotContainer.create(
		StringName(container_id),
		ItemSlotContainer.PROFILE_STASH_TAB,
		owner_id,
		ItemSlotContainer.STASH_CAPACITY,
		slots
	).to_dictionary()

func _item(instance_id: String, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = &"forge_vanguard_sword"
	item.item_level = 28
	item.rarity_id = &"common"
	item.origin = {
		"issuer_namespace": "profile:%s" % PROFILE_ID,
		"seed": 1000 + sequence,
		"sequence": sequence,
		"source": "storage_reconciler_test",
	}
	return item
