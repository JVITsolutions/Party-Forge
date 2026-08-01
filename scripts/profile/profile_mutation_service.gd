class_name ProfileMutationService
extends RefCounted

const MAX_INT := 0x7fffffffffffffff

var _store: ProfileStore

func _init(store: ProfileStore = null) -> void:
	_store = store if store != null else ProfileStore.new()

func apply(profile_id: String, transaction_id: String, mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1) -> ProfileMutationResult:
	var result := ProfileMutationResult.new()
	if transaction_id.strip_edges().is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s reason=transaction id is required" % profile_id
		return result
	if not mutate.is_valid():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=mutation is missing" % [profile_id, transaction_id]
		return result
	var loaded := _store.load_profile(profile_id, root)
	if not loaded.ok():
		if not loaded.error.is_empty():
			result.error = loaded.error
		elif loaded.missing:
			result.error = "PROFILE_MUTATION_ERROR profile=%s reason=profile is missing" % profile_id
		else:
			result.error = "PROFILE_MUTATION_ERROR profile=%s reason=profile load failed" % profile_id
		return result
	if loaded.profile.applied_transactions.has(transaction_id):
		result.profile = loaded.profile.copy()
		result.duplicate = true
		return result
	var working := loaded.profile.copy()
	var protected_schema_version := working.schema_version
	var protected_profile_id := working.profile_id
	var protected_created_at_unix := working.created_at_unix
	var protected_updated_at_unix := working.updated_at_unix
	var protected_applied_transactions := working.applied_transactions.duplicate(true)
	var mutation_result: Variant = mutate.call(working)
	if typeof(mutation_result) != TYPE_STRING:
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=mutation must return String" % [profile_id, transaction_id]
		return result
	var mutation_error := mutation_result as String
	if not mutation_error.is_empty():
		result.error = mutation_error
		return result
	var protected_field := ""
	if working.schema_version != protected_schema_version:
		protected_field = "schema_version"
	elif working.profile_id != protected_profile_id:
		protected_field = "profile_id"
	elif working.created_at_unix != protected_created_at_unix:
		protected_field = "created_at_unix"
	elif working.updated_at_unix != protected_updated_at_unix:
		protected_field = "updated_at_unix"
	elif working.applied_transactions != protected_applied_transactions:
		protected_field = "applied_transactions"
	if not protected_field.is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=protected field changed field=%s" % [profile_id, transaction_id, protected_field]
		return result
	working.normalize()
	var validation := ProfileCodec.validate_profile(working)
	if not validation.is_empty():
		result.error = validation
		return result
	var requested_timestamp := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var committed_timestamp := maxi(loaded.profile.updated_at_unix, maxi(working.created_at_unix, requested_timestamp))
	working.applied_transactions[transaction_id] = committed_timestamp
	working.updated_at_unix = committed_timestamp
	var save_error := _store.save_profile(working, root)
	if not save_error.is_empty():
		result.error = save_error
		return result
	result.profile = working.copy()
	return result

func grant_gold(profile_id: String, transaction_id: String, amount: int, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	return apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		if amount <= 0:
			return "PROFILE_MUTATION_ERROR reason=gold amount must be positive"
		if profile.gold > MAX_INT - amount:
			return "PROFILE_MUTATION_ERROR reason=gold amount overflow"
		profile.gold += amount
		return ""
	, root)

func grant_passive_points(profile_id: String, transaction_id: String, amount: int, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	return apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		if amount <= 0:
			return "PROFILE_MUTATION_ERROR reason=passive point amount must be positive"
		if profile.passive_points_available > MAX_INT - amount or profile.passive_points_lifetime_earned > MAX_INT - amount:
			return "PROFILE_MUTATION_ERROR reason=passive point amount overflow"
		profile.passive_points_available += amount
		profile.passive_points_lifetime_earned += amount
		return ""
	, root)

func complete_prologue(profile_id: String, transaction_id: String, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	return apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		if profile.prologue_state == ProfileState.PrologueState.COMPLETED:
			return "PROFILE_MUTATION_ERROR reason=prologue already completed with different transaction"
		if profile.passive_points_available == MAX_INT or profile.passive_points_lifetime_earned == MAX_INT:
			return "PROFILE_MUTATION_ERROR reason=passive point amount overflow"
		profile.prologue_state = ProfileState.PrologueState.COMPLETED
		profile.passive_points_available += 1
		profile.passive_points_lifetime_earned += 1
		if "city-heart" not in profile.permanent_feature_unlocks:
			profile.permanent_feature_unlocks.append("city-heart")
		if "party-forge-city-v1" not in profile.discovered_trees:
			profile.discovered_trees.append("party-forge-city-v1")
		return ""
	, root)
