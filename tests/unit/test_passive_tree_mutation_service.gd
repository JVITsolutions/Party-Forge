extends RefCounted

const ID := "profile-12345678"

var _root_counter := 0

class RejectingStorageReconciler extends ProfileStorageReconciler:
	func reconcile(_profile: ProfileState, _tree: PassiveTreeDefinition, _resolver: PassiveEffectResolver) -> String:
		return "PARTY_FORGE_PROFILE_STORAGE_ERROR field=stash_tabs reason=injected reconciliation failure"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_allocation_persists_exact_projection(failures)
	_test_allocation_persists_missing_implicit_root(failures)
	_test_duplicate_replays_identical_result(failures)
	_test_request_fingerprint_conflicts_are_atomic(failures)
	_test_allocation_rejections_are_atomic(failures)
	_test_activation_rejections_are_atomic_and_live(failures)
	_test_failed_save_is_atomic(failures)
	_test_stash_projects_permanent_discoveries_and_storage(failures)
	_test_reconciliation_failure_aborts_permanent_allocation(failures)
	_test_unresolved_allocations_round_trip_without_effects(failures)
	_test_refund_exact_delta_and_service_authority(failures)
	_test_refund_cannot_exceed_lifetime_earned(failures)
	_test_refund_overflow_is_atomic(failures)
	_test_permanent_and_start_nodes_never_refund(failures)
	_test_retained_failures_leave_every_projection_unchanged(failures)
	return failures

func _test_allocation_persists_exact_projection(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var root := _case_root("allocation_exact")
	var store := ProfileStore.new()
	var profile := _profile(tree.id, ["city-heart", "city-heart"], 3)
	profile.tree_allocations["other-tree"] = ["other-root", "unknown-old-node"]
	_save_fixture(store, profile, root, "exact allocation fixture", failures)

	var result := _service(store).allocate(ID, "allocate-equipment-registry", tree, &"equipment-registry", false, root)
	var saved := store.load_profile(ID, root).profile
	TestAssertions.truthy(result.ok() and not result.duplicate, "allocation commits once", failures)
	TestAssertions.equal(saved.passive_points_available, 2, "allocation deducts the exact node cost", failures)
	TestAssertions.equal(saved.passive_points_lifetime_earned, 3, "allocation does not change lifetime earned points", failures)
	TestAssertions.equal(saved.tree_allocations["party-forge-city-v1"], ["city-heart", "equipment-registry"], "allocation is unique and lexical", failures)
	TestAssertions.equal(saved.tree_allocations["other-tree"], ["other-root", "unknown-old-node"], "allocation replaces only the requested tree projection", failures)
	TestAssertions.equal(saved.permanent_feature_unlocks, ["equipment_inventory"], "allocation projects the exact registered permanent effect", failures)
	TestAssertions.truthy(saved.applied_transactions.has("allocate-equipment-registry"), "successful allocation records its transaction", failures)
	ProfileTestSupport.remove_tree(root)

func _test_allocation_persists_missing_implicit_root(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var root := _case_root("implicit_root")
	var store := ProfileStore.new()
	_save_fixture(store, _profile(tree.id, [], 2), root, "implicit root fixture", failures)

	var result := _service(store).allocate(ID, "allocate-older-equipment-registry", tree, &"equipment-registry", false, root)
	var saved := store.load_profile(ID, root).profile
	TestAssertions.truthy(result.ok(), "older discovered profile allocates from its implicit root", failures)
	TestAssertions.equal(saved.tree_allocations.get("party-forge-city-v1", []), ["city-heart", "equipment-registry"], "successful allocation persists the implicit City root", failures)
	TestAssertions.equal(saved.passive_points_available, 1, "implicit-root allocation charges only the selected node", failures)
	ProfileTestSupport.remove_tree(root)

func _test_duplicate_replays_identical_result(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var root := _case_root("duplicate")
	var store := ProfileStore.new()
	_save_fixture(store, _profile(tree.id, ["city-heart"], 3), root, "duplicate fixture", failures)
	var service := _service(store)
	var first := service.allocate(ID, "allocate-equipment-once", tree, &"equipment-registry", false, root)
	var intervening := ProfileMutationService.new(store).grant_gold(ID, "intervening-gold", 7, root)
	var retry := service.allocate(ID, "allocate-equipment-once", tree, &"equipment-registry", false, root)
	var saved := store.load_profile(ID, root).profile

	TestAssertions.truthy(first.ok() and intervening.ok(), "duplicate fixture commits allocation and intervening mutation", failures)
	TestAssertions.truthy(retry.ok() and retry.duplicate, "identical allocation transaction replays as duplicate", failures)
	if first.ok() and retry.ok():
		TestAssertions.equal(retry.profile.to_dictionary(), first.profile.to_dictionary(), "duplicate returns the identical historical committed profile projection", failures)
	TestAssertions.equal(saved.passive_points_available, 2, "duplicate allocation does not charge points again", failures)
	TestAssertions.equal(saved.tree_allocations["party-forge-city-v1"], ["city-heart", "equipment-registry"], "duplicate allocation does not append the node again", failures)
	TestAssertions.equal(saved.permanent_feature_unlocks, ["equipment_inventory"], "duplicate allocation does not append projected effects again", failures)
	TestAssertions.equal(saved.applied_transactions.size(), 2, "duplicate allocation records no additional transaction", failures)
	ProfileTestSupport.remove_tree(root)

func _test_request_fingerprint_conflicts_are_atomic(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var root := _case_root("fingerprint_conflict")
	var store := ProfileStore.new()
	_save_fixture(store, _profile(tree.id, ["city-heart"], 5), root, "fingerprint conflict fixture", failures)
	var service := _service(store)
	var first := service.allocate(ID, "shared-transaction", tree, &"equipment-registry", false, root)
	TestAssertions.truthy(first.ok(), "fingerprint fixture commits the original request", failures)
	var before := store.load_profile(ID, root).profile.to_dictionary()
	var renamed_tree := PassiveTreeDefinition.new(&"different-tree", tree.name, tree.starting_node_ids, tree.nodes, tree.connections, tree.metadata)
	var conflicts: Array[ProfileMutationResult] = [
		service.allocate(ID, "shared-transaction", tree, &"open-market", false, root),
		service.allocate(ID, "shared-transaction", tree, &"equipment-registry", true, root),
		service.allocate(ID, "shared-transaction", renamed_tree, &"equipment-registry", false, root),
	]
	for conflict: ProfileMutationResult in conflicts:
		TestAssertions.truthy(not conflict.ok() and conflict.error.contains("transaction id conflict"), "changed tree node or Developer context conflicts by fingerprint", failures)
	TestAssertions.equal(store.load_profile(ID, root).profile.to_dictionary(), before, "all fingerprint conflicts leave disk unchanged", failures)
	ProfileTestSupport.remove_tree(root)

func _test_allocation_rejections_are_atomic(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var cases: Array[Dictionary] = [
		{"label": "insufficient", "transaction": "no-points", "node": &"equipment-registry", "points": 0, "expected": PassiveTreeProgressionService.MESSAGES[&"insufficient_points"]},
		{"label": "invalid-decision", "transaction": "unknown-node", "node": &"removed-node", "points": 3, "expected": PassiveTreeProgressionService.MESSAGES[&"unknown_node"]},
		{"label": "blank-transaction", "transaction": "   ", "node": &"equipment-registry", "points": 3, "expected": "transaction id is required"},
	]
	for test_case: Dictionary in cases:
		var root := _case_root(test_case["label"])
		var store := ProfileStore.new()
		_save_fixture(store, _profile(tree.id, ["city-heart"], int(test_case["points"])), root, "%s fixture" % test_case["label"], failures)
		var before := store.load_profile(ID, root).profile.to_dictionary()
		var rejected := _service(store).allocate(ID, test_case["transaction"], tree, test_case["node"], false, root)
		TestAssertions.truthy(not rejected.ok() and rejected.error.contains(test_case["expected"]), "%s surfaces its stable rejection" % test_case["label"], failures)
		var after := store.load_profile(ID, root).profile
		TestAssertions.equal(after.to_dictionary(), before, "%s leaves the reloaded disk profile unchanged" % test_case["label"], failures)
		if not String(test_case["transaction"]).strip_edges().is_empty():
			TestAssertions.truthy(not after.applied_transactions.has(test_case["transaction"]), "%s records no transaction" % test_case["label"], failures)
		ProfileTestSupport.remove_tree(root)

func _test_activation_rejections_are_atomic_and_live(failures: Array[String]) -> void:
	var future_tree := _activation_tree(&"future")
	var future_root := _case_root("future_activation")
	var future_store := ProfileStore.new()
	_save_fixture(future_store, _profile(future_tree.id, ["city-heart"], 1), future_root, "future activation fixture", failures)
	var future_path := future_store.profile_path(ID, future_root)
	var future_bytes := FileAccess.get_file_as_bytes(future_path)
	var future_before := future_store.load_profile(ID, future_root).profile.to_dictionary()
	var future_service := _service(future_store)
	for developer_context: bool in [false, true]:
		var suffix := "developer" if developer_context else "player"
		var rejected := future_service.allocate(ID, "future-%s" % suffix, future_tree, &"district-charter", developer_context, future_root)
		TestAssertions.equal(rejected.error, PassiveTreeProgressionService.MESSAGES[&"future_node"], "%s allocation surfaces authored future state" % suffix, failures)
		TestAssertions.equal(future_store.load_profile(ID, future_root).profile.to_dictionary(), future_before, "%s future rejection preserves points allocations timestamps and transaction ledger" % suffix, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(future_path), future_bytes, "%s future rejection preserves exact profile bytes" % suffix, failures)
	ProfileTestSupport.remove_tree(future_root)

	var missing_tree := _activation_tree(&"portal-gated")
	var missing_root := _case_root("portal_missing")
	var missing_store := ProfileStore.new()
	_save_fixture(missing_store, _profile(missing_tree.id, ["city-heart"], 1), missing_root, "missing portal fixture", failures)
	var missing_before := missing_store.load_profile(ID, missing_root).profile.to_dictionary()
	var missing := _service(missing_store).allocate(ID, "portal-missing", missing_tree, &"district-charter", false, missing_root)
	TestAssertions.equal(missing.error, PassiveTreeProgressionService.MESSAGES[&"district_target_missing"], "missing portal target rejects at commit time", failures)
	TestAssertions.equal(missing_store.load_profile(ID, missing_root).profile.to_dictionary(), missing_before, "missing portal rejection is atomic", failures)
	ProfileTestSupport.remove_tree(missing_root)

	var exact_portfolio := LatticewrightRuntimePortfolioRegistry.new()
	TestAssertions.equal(exact_portfolio.register_runtime(_runtime(&"district-project", &"district-graph")), "", "exact mutation portal fixture registers", failures)
	var exact_root := _case_root("portal_exact")
	var exact_store := ProfileStore.new()
	_save_fixture(exact_store, _profile(missing_tree.id, ["city-heart"], 1), exact_root, "exact portal fixture", failures)
	var exact := _service(exact_store, null, exact_portfolio).allocate(ID, "portal-exact", missing_tree, &"district-charter", false, exact_root)
	var exact_saved := exact_store.load_profile(ID, exact_root).profile
	TestAssertions.truthy(exact.ok(), "exact live portal target authorizes commit", failures)
	TestAssertions.equal(exact_saved.passive_points_available, 0, "exact portal allocation spends one point", failures)
	TestAssertions.equal(exact_saved.tree_allocations[String(missing_tree.id)], ["city-heart", "district-charter"], "exact portal allocation persists canonically", failures)
	ProfileTestSupport.remove_tree(exact_root)

	var live_portfolio := LatticewrightRuntimePortfolioRegistry.new()
	TestAssertions.equal(live_portfolio.register_runtime(_runtime(&"district-project", &"district-graph")), "", "live unregister fixture registers", failures)
	var live_root := _case_root("portal_unregister")
	var live_store := ProfileStore.new()
	_save_fixture(live_store, _profile(missing_tree.id, ["city-heart"], 1), live_root, "live unregister fixture", failures)
	var progression := PassiveTreeProgressionService.new(PassiveEffectRegistry.new(), PassiveRequirementRegistry.new(), PassiveTreeActivationPolicy.new(), live_portfolio)
	var mutation := PassiveTreeMutationService.new(ProfileMutationService.new(live_store), progression, PassiveEffectResolver.new(PassiveEffectRegistry.new()))
	TestAssertions.truthy(progression.allocation_decision(missing_tree, live_store.load_profile(ID, live_root).profile, &"district-charter", false).ok(), "portal is ready during view-time preflight", failures)
	var live_before := live_store.load_profile(ID, live_root).profile.to_dictionary()
	live_portfolio.unregister_runtime(&"district-project")
	var unregistered := mutation.allocate(ID, "portal-unregistered", missing_tree, &"district-charter", false, live_root)
	TestAssertions.equal(unregistered.error, PassiveTreeProgressionService.MESSAGES[&"district_target_missing"], "commit rechecks target after view-time unregister", failures)
	TestAssertions.equal(live_store.load_profile(ID, live_root).profile.to_dictionary(), live_before, "target unregister rejection preserves the complete profile", failures)
	ProfileTestSupport.remove_tree(live_root)

func _test_failed_save_is_atomic(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var root := _case_root("failed_save")
	var good_store := ProfileStore.new()
	_save_fixture(good_store, _profile(tree.id, ["city-heart"], 3), root, "failed save fixture", failures)
	var before := good_store.load_profile(ID, root).profile.to_dictionary()
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var failed := _service(failing_store).allocate(ID, "allocation-save-fails", tree, &"equipment-registry", false, root)
	var after := good_store.load_profile(ID, root).profile
	TestAssertions.truthy(not failed.ok() and failed.error.contains("JSON_STORE_SAVE_ERROR") and failed.error.contains("stage=promote"), "allocation save failure reports atomic promote diagnostics", failures)
	TestAssertions.equal(after.to_dictionary(), before, "allocation save failure leaves the original disk profile unchanged", failures)
	TestAssertions.truthy(not after.applied_transactions.has("allocation-save-fails"), "allocation save failure records no transaction", failures)
	ProfileTestSupport.remove_tree(root)

func _test_stash_projects_permanent_discoveries_and_storage(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var root := _case_root("stash_projection")
	var store := ProfileStore.new()
	var profile := _profile(tree.id, ["city-heart", "civic-archive"], 5)
	profile.permanent_feature_unlocks = ["legacy", "legacy", "stash"]
	profile.discovered_buildings = ["warehouse", "forge", "forge"]
	profile.discovered_trees = ["zeta-tree", "party-forge-city-v1", "party-forge-city-v1"]
	profile.stash_tabs = []
	_save_fixture(store, profile, root, "stash projection fixture", failures)

	var result := _service(store).allocate(ID, "allocate-stash-access", tree, &"stash-access", false, root)
	var saved := store.load_profile(ID, root).profile
	TestAssertions.truthy(result.ok(), "Stash Access allocation commits", failures)
	TestAssertions.equal(saved.passive_points_available, 4, "Stash Access charges its exact cost", failures)
	TestAssertions.equal(saved.permanent_feature_unlocks, ["legacy", "stash"], "permanent unlocks merge monotonically in unique lexical form", failures)
	TestAssertions.equal(saved.discovered_buildings, ["forge", "warehouse"], "building discoveries merge monotonically in unique lexical form", failures)
	TestAssertions.equal(saved.discovered_trees, ["party-forge-city-v1", "zeta-tree"], "Stash Access no longer invents Warehouse tree discovery", failures)
	TestAssertions.equal(saved.stash_tabs.size(), 1, "Stash Access materializes one persistent stash tab", failures)
	TestAssertions.equal(saved.stash_tabs[0], ItemSlotContainer.create(&"stash-tab-000", ItemSlotContainer.PROFILE_STASH_TAB, ID, 100).to_dictionary(), "permanent allocation materializes the exact stash tab contract", failures)
	ProfileTestSupport.remove_tree(root)

func _test_reconciliation_failure_aborts_permanent_allocation(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var root := _case_root("storage_abort")
	var store := ProfileStore.new()
	_save_fixture(store, _profile(tree.id, ["city-heart", "civic-archive"], 5), root, "storage abort fixture", failures)
	var path := store.profile_path(ID, root)
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var rejected := _service(store, RejectingStorageReconciler.new()).allocate(ID, "allocate-stash-storage-aborts", tree, &"stash-access", false, root)
	TestAssertions.equal(rejected.error, "PARTY_FORGE_PROFILE_STORAGE_ERROR field=stash_tabs reason=injected reconciliation failure", "reconciliation failure is surfaced unchanged", failures)
	TestAssertions.equal(rejected.profile, null, "reconciliation failure exposes no partial profile", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "reconciliation failure preserves exact profile bytes", failures)
	var saved := store.load_profile(ID, root).profile
	TestAssertions.equal(saved.passive_points_available, 5, "reconciliation failure spends no Passive Points", failures)
	TestAssertions.equal(saved.tree_allocations[String(tree.id)], ["city-heart", "civic-archive"], "reconciliation failure persists no allocation", failures)
	TestAssertions.truthy("stash" not in saved.permanent_feature_unlocks, "reconciliation failure persists no permanent unlock", failures)
	TestAssertions.equal(saved.stash_tabs, [], "reconciliation failure persists no storage", failures)
	TestAssertions.truthy(not saved.applied_transactions.has("allocate-stash-storage-aborts"), "reconciliation failure records no outer transaction", failures)
	ProfileTestSupport.remove_tree(root)

func _test_unresolved_allocations_round_trip_without_effects(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var root := _case_root("unresolved")
	var store := ProfileStore.new()
	_save_fixture(store, _profile(tree.id, ["removed-passive", "city-heart", "removed-passive"], 2), root, "unresolved fixture", failures)

	var result := _service(store).allocate(ID, "allocate-with-unresolved", tree, &"equipment-registry", false, root)
	var saved := store.load_profile(ID, root).profile
	TestAssertions.truthy(result.ok(), "known allocation commits beside unresolved saved IDs", failures)
	TestAssertions.equal(saved.tree_allocations["party-forge-city-v1"], ["city-heart", "equipment-registry", "removed-passive"], "unresolved IDs remain in the pure decision projection", failures)
	TestAssertions.equal(saved.permanent_feature_unlocks, ["equipment_inventory"], "only the known implemented allocation grants its permanent effect", failures)
	TestAssertions.equal(saved.discovered_buildings, [], "unresolved IDs never grant building effects", failures)
	TestAssertions.equal(saved.discovered_trees, ["party-forge-city-v1"], "unresolved IDs never grant tree effects", failures)
	ProfileTestSupport.remove_tree(root)

func _test_refund_exact_delta_and_service_authority(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var rejected_root := _case_root("refund_service")
	var rejected_store := ProfileStore.new()
	var rejected_profile := _profile(tree.id, ["city-heart", "shared-lessons-1"], 2)
	rejected_profile.passive_points_lifetime_earned = 5
	rejected_profile.permanent_feature_unlocks = ["legacy-unlock"]
	rejected_profile.discovered_buildings = ["legacy-building"]
	rejected_profile.discovered_trees.append("legacy-tree")
	_save_fixture(rejected_store, rejected_profile, rejected_root, "refund service fixture", failures)
	var before := rejected_store.load_profile(ID, rejected_root).profile.to_dictionary()
	var rejected := _service(rejected_store).refund(ID, "refund-without-service", tree, &"shared-lessons-1", false, false, rejected_root)
	TestAssertions.equal(rejected.error, PassiveTreeProgressionService.MESSAGES[&"respec_service_required"], "Player refund requires the respec service", failures)
	TestAssertions.equal(rejected_store.load_profile(ID, rejected_root).profile.to_dictionary(), before, "service-gated refund leaves disk unchanged", failures)
	ProfileTestSupport.remove_tree(rejected_root)

	var developer_root := _case_root("refund_developer")
	var developer_store := ProfileStore.new()
	_save_fixture(developer_store, rejected_profile, developer_root, "Developer refund fixture", failures)
	var developer := _service(developer_store).refund(ID, "developer-refund", tree, &"shared-lessons-1", true, false, developer_root)
	var saved := developer_store.load_profile(ID, developer_root).profile
	TestAssertions.truthy(developer.ok(), "Developer context bypasses only the respec-service gate", failures)
	TestAssertions.equal(saved.passive_points_available, 3, "refund returns the exact node cost", failures)
	TestAssertions.equal(saved.passive_points_lifetime_earned, 5, "refund does not reduce lifetime earned points", failures)
	TestAssertions.equal(saved.tree_allocations["party-forge-city-v1"], ["city-heart"], "refund replaces the saved allocation projection", failures)
	TestAssertions.equal(saved.permanent_feature_unlocks, ["legacy-unlock"], "refund never revokes permanent unlocks", failures)
	TestAssertions.equal(saved.discovered_buildings, ["legacy-building"], "refund never revokes building discoveries", failures)
	TestAssertions.equal(saved.discovered_trees, ["party-forge-city-v1", "legacy-tree"], "refund never revokes tree discoveries", failures)
	ProfileTestSupport.remove_tree(developer_root)

func _test_refund_cannot_exceed_lifetime_earned(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var root := _case_root("refund_lifetime")
	var store := ProfileStore.new()
	_save_fixture(store, _profile(tree.id, ["city-heart", "shared-lessons-1"], 2), root, "refund lifetime fixture", failures)
	var before := store.load_profile(ID, root).profile.to_dictionary()
	var rejected := _service(store).refund(ID, "refund-exceeds-lifetime", tree, &"shared-lessons-1", true, false, root)
	TestAssertions.truthy(not rejected.ok() and rejected.error.contains("passive points exceed lifetime earned"), "refund rejects an available-point total above lifetime earned", failures)
	TestAssertions.equal(store.load_profile(ID, root).profile.to_dictionary(), before, "lifetime ceiling rejection occurs before normalize and leaves disk unchanged", failures)
	ProfileTestSupport.remove_tree(root)

func _test_refund_overflow_is_atomic(failures: Array[String]) -> void:
	var tree := _city_tree(failures)
	if tree == null:
		return
	var root := _case_root("refund_overflow")
	var store := ProfileStore.new()
	var profile := _profile(tree.id, ["city-heart", "shared-lessons-1"], ProfileCodec.JSON_SAFE_INTEGER_MAX)
	_save_fixture(store, profile, root, "refund overflow fixture", failures)
	var before := store.load_profile(ID, root).profile.to_dictionary()
	var rejected := _service(store).refund(ID, "refund-overflow", tree, &"shared-lessons-1", true, false, root)
	TestAssertions.truthy(not rejected.ok() and rejected.error.contains("passive point amount overflow"), "refund rejects JSON-safe integer overflow", failures)
	TestAssertions.equal(store.load_profile(ID, root).profile.to_dictionary(), before, "refund overflow leaves disk unchanged", failures)
	ProfileTestSupport.remove_tree(root)

func _test_permanent_and_start_nodes_never_refund(failures: Array[String]) -> void:
	var tree := _permanence_tree()
	for node_id: StringName in [&"city-heart", &"permanent-metadata", &"permanent-effect"]:
		var root := _case_root("permanent_%s" % node_id)
		var store := ProfileStore.new()
		_save_fixture(store, _profile(tree.id, ["city-heart", "permanent-metadata", "permanent-effect"], 1), root, "%s refund fixture" % node_id, failures)
		var before := store.load_profile(ID, root).profile.to_dictionary()
		var rejected := _service(store).refund(ID, "refund-%s" % node_id, tree, node_id, true, false, root)
		TestAssertions.equal(rejected.error, PassiveTreeProgressionService.MESSAGES[&"permanent_node"], "%s remains nonrefundable in Developer context" % node_id, failures)
		TestAssertions.equal(store.load_profile(ID, root).profile.to_dictionary(), before, "%s rejection leaves disk unchanged" % node_id, failures)
		ProfileTestSupport.remove_tree(root)

func _test_retained_failures_leave_every_projection_unchanged(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"label": "retained_path", "tree": _retained_path_tree(), "node": &"bridge", "code": &"retained_path_disconnected"},
		{"label": "retained_requirement", "tree": _retained_requirement_tree(), "node": &"source", "code": &"retained_requirement_failed"},
	]
	for test_case: Dictionary in cases:
		var tree := test_case["tree"] as PassiveTreeDefinition
		var root := _case_root(test_case["label"])
		var store := ProfileStore.new()
		var profile := _profile(tree.id, ["city-heart", String(test_case["node"]), "dependent" if test_case["label"] == "retained_requirement" else "leaf"], 4)
		profile.permanent_feature_unlocks = ["kept-unlock"]
		profile.discovered_buildings = ["kept-building"]
		profile.discovered_trees.append("kept-tree")
		_save_fixture(store, profile, root, "%s fixture" % test_case["label"], failures)
		var before := store.load_profile(ID, root).profile.to_dictionary()
		var rejected := _service(store).refund(ID, "refund-%s" % test_case["label"], tree, test_case["node"], true, false, root)
		TestAssertions.equal(rejected.error, PassiveTreeProgressionService.MESSAGES[test_case["code"]], "%s surfaces the pure retained-decision message" % test_case["label"], failures)
		var after := store.load_profile(ID, root).profile
		TestAssertions.equal(after.to_dictionary(), before, "%s leaves points allocations unlocks and ledger unchanged" % test_case["label"], failures)
		TestAssertions.truthy(not after.applied_transactions.has("refund-%s" % test_case["label"]), "%s records no transaction" % test_case["label"], failures)
		ProfileTestSupport.remove_tree(root)

func _service(
	store: ProfileStore,
	reconciler: ProfileStorageReconciler = null,
	portfolio: LatticewrightRuntimePortfolioRegistry = null,
) -> PassiveTreeMutationService:
	var mutations := ProfileMutationService.new(store)
	var progression := PassiveTreeProgressionService.new(PassiveEffectRegistry.new(), PassiveRequirementRegistry.new(), PassiveTreeActivationPolicy.new(), portfolio)
	var resolver := PassiveEffectResolver.new(PassiveEffectRegistry.new())
	if reconciler == null:
		return PassiveTreeMutationService.new(mutations, progression, resolver)
	return PassiveTreeMutationService.new(mutations, progression, resolver, reconciler)

func _profile(tree_id: StringName, allocations: Array[String], points: int) -> ProfileState:
	var profile := ProfileState.new_profile(ID, "Mutation Tester", 1000)
	profile.discovered_trees.append(String(tree_id))
	if not allocations.is_empty():
		profile.tree_allocations[String(tree_id)] = allocations.duplicate()
	profile.passive_points_available = points
	profile.passive_points_lifetime_earned = points
	return profile

func _city_tree(failures: Array[String]) -> PassiveTreeDefinition:
	var result := PassiveTreeCatalog.load_defaults()
	TestAssertions.truthy(result.ok(), "committed City artifact loads for mutation tests", failures)
	return result.tree

func _save_fixture(store: ProfileStore, profile: ProfileState, root: String, label: String, failures: Array[String]) -> void:
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "%s saves" % label, failures)

func _case_root(label: String) -> String:
	_root_counter += 1
	return "user://tests/profile_passive_mutation_%s_%d_%d_%d" % [label, OS.get_process_id(), Time.get_ticks_usec(), _root_counter]

func _permanence_tree() -> PassiveTreeDefinition:
	var no_effects: Array[PassiveTreeEffect] = []
	var no_requirements: Array[PassiveTreeRequirement] = []
	var permanent_effects: Array[PassiveTreeEffect] = [
		PassiveTreeEffect.new(&"feature_unlock", &"set", true, {"featureId": "permanent-test"}),
	]
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"city-heart", &"start", Vector2.ZERO, "City Heart", "", 0),
		PassiveTreeNode.new(&"permanent-metadata", &"small", Vector2.ZERO, "Permanent Metadata", "", 1, [], null, no_effects, no_requirements, {"refundPolicy": "permanent"}),
		PassiveTreeNode.new(&"permanent-effect", &"small", Vector2.ZERO, "Permanent Effect", "", 1, [], null, permanent_effects),
	]
	var connections: Array[PassiveTreeConnection] = [
		PassiveTreeConnection.new(&"root-meta", &"city-heart", &"permanent-metadata", &"bidirectional"),
		PassiveTreeConnection.new(&"root-effect", &"city-heart", &"permanent-effect", &"bidirectional"),
	]
	var starts: Array[StringName] = [&"city-heart"]
	return PassiveTreeDefinition.new(&"task9-permanence-tree", "Permanence", starts, nodes, connections)

func _retained_path_tree() -> PassiveTreeDefinition:
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"city-heart", &"start", Vector2.ZERO, "Root", "", 0),
		PassiveTreeNode.new(&"bridge", &"small", Vector2.ZERO, "Bridge", "", 1),
		PassiveTreeNode.new(&"leaf", &"small", Vector2.ZERO, "Leaf", "", 1),
	]
	var connections: Array[PassiveTreeConnection] = [
		PassiveTreeConnection.new(&"root-bridge", &"city-heart", &"bridge", &"bidirectional"),
		PassiveTreeConnection.new(&"bridge-leaf", &"bridge", &"leaf", &"bidirectional"),
	]
	var starts: Array[StringName] = [&"city-heart"]
	return PassiveTreeDefinition.new(&"task9-retained-path", "Retained Path", starts, nodes, connections)

func _retained_requirement_tree() -> PassiveTreeDefinition:
	var no_effects: Array[PassiveTreeEffect] = []
	var requirement_list: Array[PassiveTreeRequirement] = [
		PassiveTreeRequirement.new(&"allocated_node", &"contains", "source", {"treeId": "task9-retained-requirement"}),
	]
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"city-heart", &"start", Vector2.ZERO, "Root", "", 0),
		PassiveTreeNode.new(&"source", &"small", Vector2.ZERO, "Source", "", 1),
		PassiveTreeNode.new(&"dependent", &"small", Vector2.ZERO, "Dependent", "", 1, [], null, no_effects, requirement_list),
	]
	var connections: Array[PassiveTreeConnection] = [
		PassiveTreeConnection.new(&"root-source", &"city-heart", &"source", &"bidirectional"),
		PassiveTreeConnection.new(&"root-dependent", &"city-heart", &"dependent", &"bidirectional"),
	]
	var starts: Array[StringName] = [&"city-heart"]
	return PassiveTreeDefinition.new(&"task9-retained-requirement", "Retained Requirement", starts, nodes, connections)

func _activation_tree(state: StringName) -> PassiveTreeDefinition:
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"city-heart", &"start", Vector2.ZERO, "City Heart", "", 0, [], null, [], [], {"activationState": "implemented"}),
		PassiveTreeNode.new(&"district-charter", &"small", Vector2(100, 0), "District Charter", "", 1, [], null, [], [], {"activationState": String(state)}),
	]
	var connections: Array[PassiveTreeConnection] = [PassiveTreeConnection.new(&"heart-charter", &"city-heart", &"district-charter", &"bidirectional")]
	var portals: Array[PassiveTreePortal] = []
	if state == &"portal-gated":
		portals.append(PassiveTreePortal.new(&"city-to-district", &"district-charter", "District", &"drill-down", &"district-project", &"district-graph", &"district-tree"))
	return PassiveTreeDefinition.new(&"party-forge-city-v1", "Activation Test City", [&"city-heart"], nodes, connections, {}, portals)

func _runtime(project_id: StringName, graph_id: StringName) -> Dictionary:
	return {
		"format": "latticewright-progression",
		"formatVersion": 3,
		"projectId": String(project_id),
		"name": "District Runtime",
		"archetype": "passive-tree",
		"vocabulary": {},
		"schemas": {},
		"content": [],
		"graphs": [{"id": String(graph_id)}],
		"graphPortals": [],
		"assets": [],
		"extensions": {},
	}
