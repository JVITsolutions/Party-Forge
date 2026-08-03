extends SceneTree

const TREE_ID := "party-forge-city-v1"
const ROOT_NODE_ID := "city-heart"
const ALLOCATION_NODE_ID := "equipment-registry"
const EXPECTED_UNLOCK := "equipment_inventory"

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

	var tree_result := PassiveTreeCatalog.load_defaults()
	_assert(tree_result.ok(), "committed City tree loads through PassiveTreeCatalog")
	if not tree_result.ok() or profile_id.is_empty():
		_finish()
		return
	var tree := tree_result.tree
	var store := ProfileStore.new()
	var profile_mutations := ProfileMutationService.new(store)
	var services := _passive_services(profile_mutations)
	var passive_mutations := services["mutations"] as PassiveTreeMutationService

	var prologue := profile_mutations.complete_prologue(profile_id, "profile-runner-discover-city", _profile_root)
	_assert(prologue.ok(), "prologue transaction discovers the City tree")
	_assert(TREE_ID in prologue.profile.discovered_trees, "City tree discovery is persisted")
	_assert(ROOT_NODE_ID in prologue.profile.tree_allocations.get(TREE_ID, []), "City starting node is persisted")
	_assert(manager.refresh_profile(profile_id).is_empty(), "manager refreshes after City discovery")

	var grant := profile_mutations.grant_passive_points(profile_id, "profile-runner-grant-points", 2, _profile_root)
	_assert(grant.ok(), "additional Passive Points are granted only through grant_passive_points")
	_assert(grant.profile.passive_points_available == 3, "prologue reward plus granted points produce the expected balance")
	_assert(grant.profile.passive_points_lifetime_earned == 3, "lifetime Passive Points track the production grants")
	_assert(manager.refresh_profile(profile_id).is_empty(), "manager refreshes after the point grant")

	var transaction_id := "profile-runner-allocate-equipment"
	var allocated := passive_mutations.allocate(profile_id, transaction_id, tree, &"equipment-registry", false, _profile_root)
	_assert(allocated.ok(), "allocation succeeds through PassiveTreeMutationService")
	_assert(not allocated.duplicate, "first allocation transaction is not a duplicate")
	_assert(allocated.profile.passive_points_available == 2, "allocation deducts the exact one-point cost")
	_assert(ALLOCATION_NODE_ID in allocated.profile.tree_allocations.get(TREE_ID, []), "allocation is stored in the City tree")
	_assert(EXPECTED_UNLOCK in allocated.profile.permanent_feature_unlocks, "permanent feature projection is stored")

	var restarted_manager := ProfileManager.new()
	_assert(restarted_manager.bootstrap(_profile_root).is_empty(), "restarted ProfileManager bootstraps the same root")
	var restarted := restarted_manager.active_profile()
	_assert(restarted != null and restarted.profile_id == profile_id, "active profile selection survives restart")
	if restarted != null:
		_assert(restarted.passive_points_available == 2 and restarted.passive_points_lifetime_earned == 3, "point balances survive restart")
		_assert(ALLOCATION_NODE_ID in restarted.tree_allocations.get(TREE_ID, []), "allocation survives restart")
		_assert(EXPECTED_UNLOCK in restarted.permanent_feature_unlocks, "permanent projection survives restart")

	var restarted_store := ProfileStore.new()
	var restarted_profile_mutations := ProfileMutationService.new(restarted_store)
	var restarted_services := _passive_services(restarted_profile_mutations)
	var restarted_passive_mutations := restarted_services["mutations"] as PassiveTreeMutationService
	var replayed := restarted_passive_mutations.allocate(profile_id, transaction_id, tree, &"equipment-registry", false, _profile_root)
	_assert(replayed.ok() and replayed.duplicate, "exact transaction replay is idempotent")
	_assert(replayed.profile.passive_points_available == 2, "idempotent replay does not spend another point")
	_assert(_count_value(replayed.profile.tree_allocations.get(TREE_ID, []), ALLOCATION_NODE_ID) == 1, "idempotent replay does not duplicate the allocation")

	var conflict := restarted_passive_mutations.allocate(profile_id, transaction_id, tree, &"open-market", false, _profile_root)
	_assert(not conflict.ok() and conflict.error.contains("transaction id conflict"), "same transaction ID with a different request fails safely")
	var unknown := restarted_passive_mutations.allocate(profile_id, "profile-runner-unknown-node", tree, &"missing-node", false, _profile_root)
	_assert(not unknown.ok() and unknown.error == PassiveTreeProgressionService.MESSAGES[&"unknown_node"], "unknown allocation fails with the stable decision message")
	var final_load := restarted_store.load_profile(profile_id, _profile_root)
	_assert(final_load.ok(), "profile remains readable after rejected mutations")
	if final_load.ok():
		_assert(final_load.profile.passive_points_available == 2, "rejected mutations do not change the point balance")
		_assert(_count_value(final_load.profile.tree_allocations.get(TREE_ID, []), ALLOCATION_NODE_ID) == 1, "rejected mutations do not change allocations")

	_finish()


func _passive_services(profile_mutations: ProfileMutationService) -> Dictionary:
	var effects := PassiveEffectRegistry.new()
	var requirements := PassiveRequirementRegistry.new()
	var progression := PassiveTreeProgressionService.new(effects, requirements)
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
