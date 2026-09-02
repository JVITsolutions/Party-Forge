extends SceneTree

const TREE_ID := "party-forge-city-v1"
const ROOT_NODE_ID := "city-heart"
const PAID_ROUTE: Array[StringName] = [
	&"equipment-registry", &"field-pack", &"stash-access", &"extraction-license",
	&"secured-loadout", &"leader-loadout-extraction",
]
const EXPECTED_UNLOCKS: Array[String] = [
	"bring_in_gear", "equipment_inventory", "inventory", "item_extraction",
	"leader_loadout_extraction", "stash",
]

var _failures: Array[String] = []
var _profile_root := ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_profile_root = "user://tests/passive_tree_profile_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_profile_root)

	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return "passive-tree-profile")
	_assert(manager.bootstrap(_profile_root).is_empty(), "fresh profile manager bootstraps")
	var created := manager.create_profile("Passive Tree Profile", 1000)
	_assert(created.ok(), "profile creation succeeds through ProfileManager")
	var profile_id := created.profile.profile_id if created.ok() else ""
	_assert(not profile_id.is_empty(), "created profile has a stable ID")
	_assert(manager.select_profile(profile_id).is_empty(), "created profile can be explicitly selected")

	var portfolio := LatticewrightRuntimePortfolioRegistry.new()
	var tree_result := PassiveTreeCatalog.load_defaults(portfolio)
	_assert(tree_result.ok(), "committed City tree loads through PassiveTreeCatalog")
	_assert(portfolio.has_graph(&"party-forge-city", &"city-passive-tree"), "exact City runtime registers in the shared portfolio")
	if not tree_result.ok() or profile_id.is_empty():
		_finish()
		return
	var tree := tree_result.tree
	var store := ProfileStore.new()
	var profile_mutations := ProfileMutationService.new(store)
	var services := _passive_services(profile_mutations, portfolio)
	var passive_mutations := services["mutations"] as PassiveTreeMutationService

	var victory := ProfileTestSupport.commit_city_victory(profile_id, "profile-runner-first-victory", _profile_root)
	_assert(victory.ok(), "first-victory fixture commits City discovery and its first point")
	_assert(victory.profile.prologue_state == ProfileState.PrologueState.NOT_STARTED, "first victory leaves the separate prologue lifecycle unchanged")
	_assert(TREE_ID in victory.profile.discovered_trees, "City tree discovery is persisted")
	_assert(ROOT_NODE_ID in victory.profile.tree_allocations.get(TREE_ID, []), "City starting node is persisted")
	_assert(manager.refresh_profile(profile_id).is_empty(), "manager refreshes after City discovery")

	var grant := profile_mutations.grant_passive_points(profile_id, "profile-runner-grant-points", 5, _profile_root)
	_assert(grant.ok(), "additional Passive Points are granted only through grant_passive_points")
	_assert(grant.profile.passive_points_available == 6, "first-victory reward plus granted points fund the exact paid route")
	_assert(grant.profile.passive_points_lifetime_earned == 6, "lifetime Passive Points track the production grants")
	_assert(manager.refresh_profile(profile_id).is_empty(), "manager refreshes after the point grant")

	var latest := grant
	for index: int in PAID_ROUTE.size():
		var node_id := PAID_ROUTE[index]
		latest = passive_mutations.allocate(profile_id, "profile-runner-allocate-%s" % node_id, tree, node_id, false, _profile_root)
		_assert(latest.ok() and not latest.duplicate, "%s allocates through Player Mode authority" % node_id)
		_assert(latest.profile.passive_points_available == PAID_ROUTE.size() - index - 1, "%s spends exactly one point" % node_id)
		_assert(node_id in latest.profile.tree_allocations.get(TREE_ID, []), "%s persists in the City allocation" % node_id)

	_assert(latest.profile.permanent_feature_unlocks == EXPECTED_UNLOCKS, "complete paid route projects the exact six live feature unlocks")
	_assert(latest.profile.inventory_columns == 1, "Field Pack durably creates one inventory column")
	_assert(latest.profile.stash_tabs.size() == 1 and int(latest.profile.stash_tabs[0].get("capacity", 0)) == 100, "Stash Access durably creates one 100-slot tab")
	_assert(latest.profile.discovered_buildings == ["warehouse"], "Stash Access discovers the Warehouse building")
	_assert(latest.profile.discovered_trees == [TREE_ID], "Stash Access does not discover the Warehouse passive tree")
	_assert(latest.profile.extraction_capacity == 1, "Extraction License durably creates one extraction slot")
	_assert(latest.profile.passive_points_available == 0 and latest.profile.passive_points_lifetime_earned == 6, "complete paid route spends six of six lifetime points")

	var restarted_manager := ProfileManager.new()
	_assert(restarted_manager.bootstrap(_profile_root).is_empty(), "restarted ProfileManager bootstraps the same root")
	var restarted := restarted_manager.active_profile()
	_assert(restarted != null and restarted.profile_id == profile_id, "active profile selection survives restart")
	if restarted != null:
		_assert(restarted.passive_points_available == 0 and restarted.passive_points_lifetime_earned == 6, "point balances survive restart")
		for node_id: StringName in PAID_ROUTE:
			_assert(node_id in restarted.tree_allocations.get(TREE_ID, []), "%s allocation survives restart" % node_id)
		_assert(restarted.permanent_feature_unlocks == EXPECTED_UNLOCKS, "permanent projections survive restart")
		_assert([restarted.inventory_columns, restarted.stash_tabs.size(), restarted.extraction_capacity] == [1, 1, 1], "storage and extraction projections survive restart")
		_assert(restarted.discovered_trees == [TREE_ID], "restart retains no invented Warehouse tree discovery")

	var restarted_store := ProfileStore.new()
	var restarted_profile_mutations := ProfileMutationService.new(restarted_store)
	var restarted_services := _passive_services(restarted_profile_mutations, portfolio)
	var restarted_passive_mutations := restarted_services["mutations"] as PassiveTreeMutationService
	var replayed := restarted_passive_mutations.allocate(profile_id, "profile-runner-allocate-leader-loadout-extraction", tree, &"leader-loadout-extraction", false, _profile_root)
	_assert(replayed.ok() and replayed.duplicate, "exact transaction replay is idempotent")
	_assert(replayed.profile.passive_points_available == 0, "idempotent replay does not spend another point")
	_assert(_count_value(replayed.profile.tree_allocations.get(TREE_ID, []), "leader-loadout-extraction") == 1, "idempotent replay does not duplicate the allocation")

	var conflict := restarted_passive_mutations.allocate(profile_id, "profile-runner-allocate-leader-loadout-extraction", tree, &"open-market", false, _profile_root)
	_assert(not conflict.ok() and conflict.error.contains("transaction id conflict"), "same transaction ID with a different request fails safely")
	var unknown := restarted_passive_mutations.allocate(profile_id, "profile-runner-unknown-node", tree, &"missing-node", false, _profile_root)
	_assert(not unknown.ok() and unknown.error == PassiveTreeProgressionService.MESSAGES[&"unknown_node"], "unknown allocation fails with the stable decision message")
	var final_load := restarted_store.load_profile(profile_id, _profile_root)
	_assert(final_load.ok(), "profile remains readable after rejected mutations")
	if final_load.ok():
		_assert(final_load.profile.passive_points_available == 0, "rejected mutations do not change the point balance")
		_assert(_count_value(final_load.profile.tree_allocations.get(TREE_ID, []), "leader-loadout-extraction") == 1, "rejected mutations do not change allocations")

	_finish()


func _passive_services(profile_mutations: ProfileMutationService, portfolio: LatticewrightRuntimePortfolioRegistry) -> Dictionary:
	var effects := PassiveEffectRegistry.new()
	var requirements := PassiveRequirementRegistry.new()
	var progression := PassiveTreeProgressionService.new(effects, requirements, null, portfolio)
	var resolver := PassiveEffectResolver.new(effects)
	return {
		"mutations": PassiveTreeMutationService.new(profile_mutations, progression, resolver),
		"view_model": PassiveTreeViewModel.new(progression, resolver, effects, requirements),
	}


func _count_value(values: Variant, expected: String) -> int:
	var count := 0
	if values is Array:
		for value: Variant in values as Array:
			if String(value) == expected:
				count += 1
	return count


func _finish() -> void:
	ProfileTestSupport.remove_tree(_profile_root)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_profile_root)):
		_failures.append("disposable profile root was not removed")
	if _failures.is_empty():
		print("PASSIVE_TREE_PROFILE_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PASSIVE_TREE_PROFILE_FAILURE: %s" % failure)
	print("PASSIVE_TREE_PROFILE_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
