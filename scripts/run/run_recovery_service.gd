class_name RunRecoveryService
extends RefCounted

var _checkout: RunLoadoutCheckoutService
var _mutations: ProfileMutationService
var _store: ProfileStore

func _init(
	checkout: RunLoadoutCheckoutService = null,
	mutations: ProfileMutationService = null,
	store: ProfileStore = null,
) -> void:
	_checkout = checkout if checkout != null else RunLoadoutCheckoutService.new()
	_mutations = mutations if mutations != null else ProfileMutationService.new()
	_store = store if store != null else ProfileStore.new()

func inspect(profile: ProfileState) -> RunRecoveryResult:
	var result := RunRecoveryResult.new()
	if profile == null:
		result.error = "PARTY_FORGE_RUN_RECOVERY_ERROR field=profile reason=must not be null"
		return result
	var profile_error := ProfileCodec.validate_profile(profile)
	if not profile_error.is_empty():
		result.error = "PARTY_FORGE_RUN_RECOVERY_ERROR field=profile reason=%s" % profile_error
		return result
	var bootstrap := _checkout.bootstrap_from(profile)
	if bootstrap == null:
		result.error = "PARTY_FORGE_RUN_RECOVERY_ERROR field=resumable_run reason=strict bootstrap unavailable"
		return result
	result.profile = profile.copy()
	result.bootstrap = RunItemBootstrap.create(
		bootstrap.run_id,
		bootstrap.run_seed,
		bootstrap.run_player_id,
		bootstrap.leader_member_id,
		bootstrap.item_state(),
		bootstrap.selected_leader_class_id,
	)
	result.run_id = bootstrap.run_id
	result.can_forfeit = true
	result.selected_leader_class_id = bootstrap.selected_leader_class_id
	if bootstrap.selected_leader_class_id.is_empty():
		result.code = RunRecoveryResult.Code.CLASS_REQUIRED
		return result
	var class_error := _checkout.validate_recovered_class(bootstrap, bootstrap.selected_leader_class_id)
	if not class_error.is_empty():
		result.error = class_error
		return result
	result.code = RunRecoveryResult.Code.READY
	return result

func bind_legacy_class(
	profile_id: String,
	class_id: StringName,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> RunRecoveryResult:
	var loaded := _store.load_profile(profile_id, root)
	if not loaded.ok():
		return _persistence_failure(loaded.error if not loaded.error.is_empty() else "profile is missing")
	var before := inspect(loaded.profile)
	if before.code != RunRecoveryResult.Code.CLASS_REQUIRED or before.bootstrap == null:
		return _invalid("PARTY_FORGE_RUN_RECOVERY_ERROR field=selected_leader_class_id reason=legacy class binding is not available")
	var expected_run_id := before.bootstrap.run_id
	var transaction_id := "bind-run-class:%s:%s" % [expected_run_id, class_id]
	var mutation := _mutations.apply(
		profile_id,
		transaction_id,
		func(candidate: ProfileState) -> String:
			var current := inspect(candidate)
			if current.code != RunRecoveryResult.Code.CLASS_REQUIRED or current.bootstrap == null:
				return "PARTY_FORGE_RUN_RECOVERY_ERROR field=resumable_run reason=legacy recovery changed"
			if current.bootstrap.run_id != expected_run_id:
				return "PARTY_FORGE_RUN_RECOVERY_ERROR field=run_id reason=run identity changed"
			var class_error := _checkout.validate_recovered_class(current.bootstrap, class_id)
			if not class_error.is_empty():
				return class_error
			candidate.resumable_run["selected_leader_class_id"] = String(class_id)
			return "",
		root,
		-1,
		"bind_run_recovery_class",
		{"class_id": String(class_id), "run_id": String(expected_run_id)},
	)
	if not mutation.ok():
		return _persistence_failure(mutation.error)
	return inspect(mutation.profile)

func forfeit(
	profile_id: String,
	run_id: StringName,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> ProfileMutationResult:
	return _checkout.forfeit(profile_id, run_id, root)

func _invalid(error: String) -> RunRecoveryResult:
	var result := RunRecoveryResult.new()
	result.error = error
	return result

func _persistence_failure(error: String) -> RunRecoveryResult:
	var result := RunRecoveryResult.new()
	result.code = RunRecoveryResult.Code.PERSISTENCE_FAILED
	result.error = error
	return result
