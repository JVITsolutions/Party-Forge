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

func verify_terminal_safety(
	profile: ProfileState,
	snapshot: RunTerminalSnapshot,
) -> RunTerminalRecoverySafetyResult:
	if profile == null or snapshot == null:
		return _terminal_unsafe("profile", "profile and terminal snapshot are required")
	var profile_error := ProfileCodec.validate_profile(profile)
	if not profile_error.is_empty():
		return _terminal_unsafe("profile", profile_error)
	var inspected := RunTerminalRecoveryService.new(null, _store).inspect(profile)
	if not inspected.ok():
		return _terminal_unsafe("terminal_resolution", inspected.error)
	var record := inspected.record
	if record.snapshot.to_dictionary() != snapshot.to_dictionary():
		return _terminal_unsafe("snapshot", "durable terminal snapshot must match the supplied snapshot exactly")
	if record.stage != RunTerminalRecoveryRecord.Stage.RESOLVED_AWAITING_PROJECTION:
		if profile.resumable_run.is_empty():
			return _terminal_unsafe("resumable_run", "pre-resolution safety requires the strict bootstrap")
		if not record.transaction_id.is_empty():
			var base := RunExtractionPolicy.project_source(snapshot.resolution_source, profile, [])
			if base == null or not base.valid:
				return _terminal_unsafe("transaction_id", "selection source is unavailable")
			var wanted: Dictionary = {}
			for item_id: String in record.selected_item_ids: wanted[item_id] = true
			var reconstructed_ids: Array[String] = []
			var selection_documents: Array[Dictionary] = []
			for selection: ExtractionSelection in base.eligible_items:
				if wanted.has(selection.item_id):
					reconstructed_ids.append(selection.item_id)
					selection_documents.append(selection.to_dictionary())
			if reconstructed_ids.size() != record.selected_item_ids.size():
				return _terminal_unsafe("selected_item_ids", "persisted selection count does not match canonical policy truth")
			if reconstructed_ids != record.selected_item_ids:
				return _terminal_unsafe("selected_item_ids", "persisted selection order does not match canonical policy truth")
			var expected_transaction := "terminal-resolution:%s:%s" % [snapshot.run_id, JSON.stringify(selection_documents).sha256_text()]
			if record.transaction_id != expected_transaction:
				return _terminal_unsafe("transaction_id", "persisted transaction does not match the canonical selection")
		return RunTerminalRecoverySafetyResult.success(record)
	if not profile.resumable_run.is_empty():
		return _terminal_unsafe("resumable_run", "resolved terminal safety requires run revocation")
	if record.applied_transaction_id.is_empty() or not profile.applied_transactions.has(record.applied_transaction_id):
		return _terminal_unsafe("applied_transaction_id", "resolved transaction is missing")
	var applied_record := profile.applied_transactions[record.applied_transaction_id] as Dictionary
	var selections: Array[ExtractionSelection] = []
	var wanted: Dictionary = {}
	for item_id: String in record.selected_item_ids:
		wanted[item_id] = true
	for selection: ExtractionSelection in record.accepted_extraction.eligible_items:
		if wanted.has(selection.item_id):
			selections.append(selection)
	if selections.size() != record.selected_item_ids.size():
		return _terminal_unsafe("accepted_extraction", "resolved selections cannot rebuild the canonical request")
	var request := RunResolutionRequest.create(
		record.transaction_id,
		snapshot.profile_id,
		snapshot.run_id,
		snapshot.run_seed,
		snapshot.run_player_id,
		snapshot.leader_member_id,
		selections,
	)
	if String(applied_record.get("operation", "")) != "run_resolution":
		return _terminal_unsafe("applied_transaction_id", "resolved transaction operation must equal run_resolution")
	if String(applied_record.get("fingerprint", "")) != ProfileMutationService._fingerprint("run_resolution", request.canonical_document()):
		return _terminal_unsafe("applied_transaction_id", "resolved transaction fingerprint does not match the canonical request")
	var receipt := applied_record.get("receipt", {}) as Dictionary
	var expected_receipt := {
		"schema_version": 1,
		"source_fingerprint": JSON.stringify(snapshot.resolution_source.to_dictionary(), "", true, true).sha256_text(),
		"request_fingerprint": JSON.stringify(request.canonical_document(), "", true, true).sha256_text(),
	}
	if (
		receipt.size() != 3
		or not (receipt.get("schema_version") is int or receipt.get("schema_version") is float)
		or float(receipt.get("schema_version")) != floor(float(receipt.get("schema_version")))
		or int(receipt.get("schema_version")) != 1
		or String(receipt.get("source_fingerprint", "")) != String(expected_receipt.source_fingerprint)
		or String(receipt.get("request_fingerprint", "")) != String(expected_receipt.request_fingerprint)
	):
		return _terminal_unsafe("applied_transaction_id", "resolved transaction receipt does not match durable source and request truth expected=%s actual=%s" % [JSON.stringify(expected_receipt), JSON.stringify(receipt)])
	var committed_profile := applied_record.get("result_profile", {}) as Dictionary
	var committed_decoded := ProfileCodec.decode_document(committed_profile)
	if not committed_decoded.ok():
		return _terminal_unsafe("applied_transaction_id", "resolved transaction snapshot is invalid")
	var canonical_committed := committed_decoded.profile.to_dictionary()
	for field: String in ["item_records", "leader_loadout", "stash_tabs", "terminal_recovery_overflow", "terminal_resolution"]:
		if canonical_committed.get(field) != profile.to_dictionary().get(field):
			return _terminal_unsafe(field, "durable resolved truth diverges from the applied resolution receipt")
	var accepted := record.accepted_extraction
	if accepted == null or not accepted.valid:
		return _terminal_unsafe("accepted_extraction", "resolved extraction is invalid")
	var retained_ids: Array[String] = accepted.automatic_item_ids
	for item_id: String in accepted.selected_item_ids:
		if item_id not in retained_ids: retained_ids.append(item_id)
	retained_ids.sort()
	var source_registry := snapshot.resolution_source.item_state.registry()
	var durable_registry_result := ItemRegistry._decode(profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if durable_registry_result.error != "":
		return _terminal_unsafe("item_records", durable_registry_result.error)
	var durable_registry := durable_registry_result.value as ItemRegistry
	var locations: Dictionary = {}
	for document: Dictionary in _profile_container_documents(profile):
		var decoded := ItemSlotContainer._decode(document, "profile_container")
		if decoded.error != "": return _terminal_unsafe("profile_container", decoded.error)
		var container := decoded.value as ItemSlotContainer
		for slot: int in container.occupied_slots():
			var item_id := container.item_id_at(slot)
			locations[item_id] = int(locations.get(item_id, 0)) + 1
	for item_id: String in retained_ids:
		if not source_registry.has(item_id) or not durable_registry.has(item_id):
			return _terminal_unsafe("item_records", "retained source item %s is missing" % item_id)
		if source_registry.item(item_id).to_dictionary() != durable_registry.item(item_id).to_dictionary():
			return _terminal_unsafe("item_records", "retained source item %s changed" % item_id)
		if int(locations.get(item_id, 0)) != 1:
			return _terminal_unsafe("placement", "retained source item %s must have exactly one profile placement" % item_id)
	for item_id: String in accepted.lost_item_ids:
		if durable_registry.has(item_id) or int(locations.get(item_id, 0)) != 0:
			return _terminal_unsafe("lost_item_ids", "lost source item %s remains durable" % item_id)
	return RunTerminalRecoverySafetyResult.success(record)

func _profile_container_documents(profile: ProfileState) -> Array[Dictionary]:
	var result: Array[Dictionary] = [profile.leader_loadout.duplicate(true)]
	for tab: Dictionary in profile.stash_tabs: result.append(tab.duplicate(true))
	result.append(profile.terminal_recovery_overflow.duplicate(true))
	return result

func _terminal_unsafe(field: String, reason: String) -> RunTerminalRecoverySafetyResult:
	return RunTerminalRecoverySafetyResult.failure("PARTY_FORGE_RUN_RECOVERY_ERROR field=%s reason=%s" % [field, reason])

func _invalid(error: String) -> RunRecoveryResult:
	var result := RunRecoveryResult.new()
	result.error = error
	return result

func _persistence_failure(error: String) -> RunRecoveryResult:
	var result := RunRecoveryResult.new()
	result.code = RunRecoveryResult.Code.PERSISTENCE_FAILED
	result.error = error
	return result
