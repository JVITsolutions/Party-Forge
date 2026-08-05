class_name PassiveTreeMutationService
extends RefCounted

var _mutations: ProfileMutationService
var _progression: PassiveTreeProgressionService
var _resolver: PassiveEffectResolver
var _storage_reconciler: ProfileStorageReconciler

func _init(
	mutations: ProfileMutationService,
	progression: PassiveTreeProgressionService,
	resolver: PassiveEffectResolver,
	storage_reconciler: ProfileStorageReconciler = null,
) -> void:
	_mutations = mutations
	_progression = progression
	_resolver = resolver
	_storage_reconciler = storage_reconciler if storage_reconciler != null else ProfileStorageReconciler.new()

func allocate(
	profile_id: String,
	transaction_id: String,
	tree: PassiveTreeDefinition,
	node_id: StringName,
	developer_context: bool,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> ProfileMutationResult:
	var request := {
		"tree_id": String(tree.id),
		"node_id": String(node_id),
		"developer_context": developer_context,
	}
	return _mutations.apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		var decision := _progression.allocation_decision(tree, profile, node_id, developer_context)
		if not decision.ok():
			return decision.message
		var point_error := _validate_point_delta(profile.passive_points_available, profile.passive_points_lifetime_earned, decision.point_delta)
		if not point_error.is_empty():
			return point_error
		profile.passive_points_available += decision.point_delta
		profile.tree_allocations[String(tree.id)] = _allocation_strings(decision.next_allocations)
		_project_permanent_effects(profile, tree, decision.next_allocations)
		var storage_error := _storage_reconciler.reconcile(profile, tree, _resolver)
		if not storage_error.is_empty():
			return storage_error
		return ""
	, root, -1, "allocate_passive_node", request)

func refund(
	profile_id: String,
	transaction_id: String,
	tree: PassiveTreeDefinition,
	node_id: StringName,
	developer_context: bool,
	has_respec_service: bool,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> ProfileMutationResult:
	var request := {
		"tree_id": String(tree.id),
		"node_id": String(node_id),
		"developer_context": developer_context,
		"has_respec_service": has_respec_service,
	}
	return _mutations.apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		var decision := _progression.refund_decision(tree, profile, node_id, developer_context, has_respec_service)
		if not decision.ok():
			return decision.message
		var point_error := _validate_point_delta(profile.passive_points_available, profile.passive_points_lifetime_earned, decision.point_delta)
		if not point_error.is_empty():
			return point_error
		profile.passive_points_available += decision.point_delta
		profile.tree_allocations[String(tree.id)] = _allocation_strings(decision.next_allocations)
		return ""
	, root, -1, "refund_passive_node", request)

func _validate_point_delta(current: int, lifetime_earned: int, delta: int) -> String:
	if delta < 0 and current < -delta:
		return "PROFILE_MUTATION_ERROR reason=passive point amount underflow"
	if delta > 0 and current > ProfileCodec.JSON_SAFE_INTEGER_MAX - delta:
		return "PROFILE_MUTATION_ERROR reason=passive point amount overflow"
	if delta > 0 and current > lifetime_earned - delta:
		return "PROFILE_MUTATION_ERROR reason=passive points exceed lifetime earned"
	return ""

func _project_permanent_effects(profile: ProfileState, tree: PassiveTreeDefinition, allocations: Array[StringName]) -> void:
	var resolution := _resolver.resolve(tree, allocations)
	profile.permanent_feature_unlocks = _merged_ids(profile.permanent_feature_unlocks, resolution.permanent_unlock_ids())
	profile.discovered_buildings = _merged_ids(profile.discovered_buildings, resolution.building_discoveries())
	profile.discovered_trees = _merged_ids(profile.discovered_trees, resolution.tree_discoveries())

func _allocation_strings(allocations: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for allocation_id: StringName in allocations:
		result.append(String(allocation_id))
	return result

func _merged_ids(existing: Array[String], additions: Array[StringName]) -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for existing_id: String in existing:
		seen[existing_id] = true
	for addition: StringName in additions:
		seen[String(addition)] = true
	for value: Variant in seen.keys():
		result.append(value as String)
	result.sort()
	return result
