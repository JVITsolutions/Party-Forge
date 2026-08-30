class_name ProfileMutationService
extends RefCounted

var _store: ProfileStore

func _init(store: ProfileStore = null) -> void:
	_store = store if store != null else ProfileStore.new()

func load_current_profile(profile_id: String, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileLoadResult:
	return _store.load_profile(profile_id, root)

func apply(profile_id: String, transaction_id: String, mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1, operation: String = "", request: Dictionary = {}) -> ProfileMutationResult:
	return _apply_internal(profile_id, transaction_id, mutate, root, now_unix, operation, request, false, [], "", {}, false)

func apply_irreversible(profile_id: String, transaction_id: String, mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1, operation: String = "", request: Dictionary = {}, removed_instance_ids: Array[String] = []) -> ProfileMutationResult:
	return _apply_internal(profile_id, transaction_id, mutate, root, now_unix, operation, request, true, removed_instance_ids.duplicate(), "", {}, false)

func apply_irreversible_terminal_completion(
	profile_id: String,
	transaction_id: String,
	terminal_run_id: StringName,
	terminal_instance_ids: Array[String],
	mutate: Callable,
	root: String = ProfileStore.DEFAULT_ROOT,
	now_unix: int = -1,
	operation: String = "",
	request: Dictionary = {},
) -> ProfileMutationResult:
	var result := ProfileMutationResult.new()
	if transaction_id.strip_edges().is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s reason=transaction id is required" % profile_id
		return result
	var clean_run_id := String(terminal_run_id).strip_edges()
	if clean_run_id.is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=terminal run id is required" % [profile_id, transaction_id]
		return result
	var seen_instance_ids: Dictionary = {}
	for instance_id: String in terminal_instance_ids:
		if instance_id.strip_edges().is_empty():
			result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=terminal instance ids must be non-empty" % [profile_id, transaction_id]
			return result
		if seen_instance_ids.has(instance_id):
			result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=terminal instance ids must be unique" % [profile_id, transaction_id]
			return result
		seen_instance_ids[instance_id] = true
	if not mutate.is_valid():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=mutation is missing" % [profile_id, transaction_id]
		return result
	if operation.strip_edges().is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=operation is required" % [profile_id, transaction_id]
		return result
	var request_error := _validate_request_value(request)
	if not request_error.is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=invalid request %s" % [profile_id, transaction_id, request_error]
		return result
	return _apply_internal(
		profile_id, transaction_id, mutate, root, now_unix, operation, request,
		true, terminal_instance_ids.duplicate(), clean_run_id, {}, true,
	)

func apply_with_resumable_run_revocation(
	profile_id: String,
	transaction_id: String,
	revoked_run_id: StringName,
	mutate: Callable,
	root: String = ProfileStore.DEFAULT_ROOT,
	now_unix: int = -1,
	operation: String = "",
	request: Dictionary = {},
	receipt: Dictionary = {},
) -> ProfileMutationResult:
	if String(revoked_run_id).strip_edges().is_empty():
		var result := ProfileMutationResult.new()
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=revoked run id is required" % [profile_id, transaction_id]
		return result
	return _apply_internal(profile_id, transaction_id, mutate, root, now_unix, operation, request, true, [], String(revoked_run_id), receipt, false)

func _apply_internal(
	profile_id: String,
	transaction_id: String,
	mutate: Callable,
	root: String,
	now_unix: int,
	operation: String,
	request: Dictionary,
	irreversible: bool,
	removed_instance_ids: Array[String],
	revoked_run_id: String,
	receipt: Dictionary,
	strict_terminal_completion: bool,
) -> ProfileMutationResult:
	var result := ProfileMutationResult.new()
	if transaction_id.strip_edges().is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s reason=transaction id is required" % profile_id
		return result
	if not mutate.is_valid():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=mutation is missing" % [profile_id, transaction_id]
		return result
	var clean_operation := operation.strip_edges()
	if clean_operation.is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=operation is required" % [profile_id, transaction_id]
		return result
	var request_error := _validate_request_value(request)
	if not request_error.is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=invalid request %s" % [profile_id, transaction_id, request_error]
		return result
	var fingerprint := _fingerprint(clean_operation, request)
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
		var record := loaded.profile.applied_transactions[transaction_id] as Dictionary
		if record["operation"] != clean_operation or record["fingerprint"] != fingerprint:
			result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=transaction id conflict" % [profile_id, transaction_id]
			return result
		if strict_terminal_completion:
			_sanitize_historical_transaction_snapshots(loaded.profile, revoked_run_id, removed_instance_ids, true)
			var duplicate_validation := ProfileCodec.validate_profile(loaded.profile)
			if not duplicate_validation.is_empty():
				result.error = duplicate_validation
				return result
			var duplicate_save_error := _store.save_profile_irreversible(loaded.profile, root)
			if not duplicate_save_error.is_empty():
				result.error = duplicate_save_error
				return result
			record = loaded.profile.applied_transactions[transaction_id] as Dictionary
			var committed_projection := loaded.profile.copy()
			committed_projection.applied_transactions = {}
			result.profile = committed_projection
			result.duplicate = true
			result._receipt = (record.get("receipt", {}) as Dictionary).duplicate(true)
			return result
		var snapshot := ProfileCodec.decode(JSON.stringify(record["result_profile"]))
		if not snapshot.ok():
			result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=stored result is invalid error=%s" % [profile_id, transaction_id, snapshot.error]
			return result
		result.profile = snapshot.profile
		result.duplicate = true
		result._receipt = (record.get("receipt", {}) as Dictionary).duplicate(true)
		return result
	var working := loaded.profile.copy()
	var revoked_instance_ids: Array[String] = []
	if not revoked_run_id.is_empty():
		revoked_instance_ids = _strict_run_instance_ids(working.resumable_run, revoked_run_id)
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
	var receipt_error := _validate_request_value(receipt)
	if not receipt_error.is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=invalid receipt %s" % [profile_id, transaction_id, receipt_error]
		return result
	var committed_receipt := JSON.parse_string(JSON.stringify(receipt)) as Dictionary
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
	if not revoked_run_id.is_empty() or not removed_instance_ids.is_empty():
		var forbidden_instance_ids := removed_instance_ids.duplicate()
		for instance_id: String in revoked_instance_ids:
			if instance_id not in forbidden_instance_ids:
				forbidden_instance_ids.append(instance_id)
		_sanitize_historical_transaction_snapshots(working, revoked_run_id, forbidden_instance_ids, strict_terminal_completion)
	working.normalize()
	var validation := ProfileCodec.validate_profile(working)
	if not validation.is_empty():
		result.error = validation
		return result
	var requested_timestamp := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var committed_timestamp := maxi(loaded.profile.updated_at_unix, maxi(working.created_at_unix, requested_timestamp))
	working.updated_at_unix = committed_timestamp
	var result_profile := _terminal_sanitized_result_profile(working, revoked_run_id, removed_instance_ids) if strict_terminal_completion else working.to_dictionary()
	result_profile["applied_transactions"] = {}
	var transaction_record := {
		"operation": clean_operation,
		"fingerprint": fingerprint,
		"committed_at_unix": committed_timestamp,
		"result_profile": result_profile,
	}
	if not committed_receipt.is_empty():
		transaction_record["receipt"] = committed_receipt.duplicate(true)
	working.applied_transactions[transaction_id] = transaction_record
	var save_error := _store.save_profile_irreversible(working, root) if irreversible else _store.save_profile(working, root)
	if not save_error.is_empty():
		result.error = save_error
		return result
	var committed_projection := working.copy()
	committed_projection.applied_transactions = {}
	result.profile = committed_projection
	result._receipt = committed_receipt.duplicate(true)
	return result

static func _strict_run_instance_ids(resumable_run: Dictionary, revoked_run_id: String) -> Array[String]:
	var result: Array[String] = []
	if not resumable_run.has("item_state") or String(resumable_run.get("run_id", "")) != revoked_run_id:
		return result
	var item_state := resumable_run.get("item_state", {}) as Dictionary
	var registry := item_state.get("registry", {}) as Dictionary
	var items := registry.get("items", []) as Array
	for item: Variant in items:
		if item is Dictionary:
			var instance_id := String((item as Dictionary).get("instance_id", ""))
			if not instance_id.is_empty() and instance_id not in result:
				result.append(instance_id)
	result.sort()
	return result

static func _sanitize_historical_transaction_snapshots(
	profile: ProfileState,
	revoked_run_id: String,
	forbidden_instance_ids: Array[String],
	strip_terminal_instances: bool = false,
) -> void:
	var sanitized := profile.to_dictionary()
	sanitized["applied_transactions"] = {}
	if strip_terminal_instances:
		sanitized = _terminal_sanitized_document(sanitized, revoked_run_id, forbidden_instance_ids)
	for transaction_id: Variant in profile.applied_transactions:
		var record := (profile.applied_transactions[transaction_id] as Dictionary).duplicate(true)
		var snapshot := record["result_profile"] as Dictionary
		var resumable := snapshot["resumable_run"] as Dictionary
		var owns_revoked_run := resumable.has("item_state") and String(resumable.get("run_id", "")) == revoked_run_id
		var terminal := snapshot.get("terminal_resolution", {}) as Dictionary
		var terminal_snapshot := terminal.get("snapshot", {}) as Dictionary
		var owns_terminal_run := not revoked_run_id.is_empty() and String(terminal_snapshot.get("run_id", "")) == revoked_run_id
		if owns_revoked_run or owns_terminal_run or _contains_any_string(snapshot, forbidden_instance_ids):
			var replacement := sanitized.duplicate(true)
			replacement["updated_at_unix"] = record["committed_at_unix"]
			record["result_profile"] = replacement
			profile.applied_transactions[transaction_id] = record

static func _terminal_sanitized_result_profile(profile: ProfileState, terminal_run_id: String, terminal_instance_ids: Array[String]) -> Dictionary:
	return _terminal_sanitized_document(profile.to_dictionary(), terminal_run_id, terminal_instance_ids)

static func _terminal_sanitized_document(document: Dictionary, terminal_run_id: String, terminal_instance_ids: Array[String]) -> Dictionary:
	var result := document.duplicate(true)
	result["applied_transactions"] = {}
	var terminal := result.get("terminal_resolution", {}) as Dictionary
	var terminal_snapshot := terminal.get("snapshot", {}) as Dictionary
	if terminal.is_empty() or terminal_run_id.is_empty() or String(terminal_snapshot.get("run_id", "")) == terminal_run_id:
		result["terminal_resolution"] = {}
	var resumable := result.get("resumable_run", {}) as Dictionary
	if not terminal_run_id.is_empty() and String(resumable.get("run_id", "")) == terminal_run_id:
		result["resumable_run"] = {}
	if terminal_instance_ids.is_empty():
		return result
	var records := result.get("item_records", {}) as Dictionary
	var kept_items: Array = []
	for item: Variant in records.get("items", []) as Array:
		if not item is Dictionary or String((item as Dictionary).get("instance_id", "")) not in terminal_instance_ids:
			kept_items.append((item as Dictionary).duplicate(true) if item is Dictionary else item)
	records["items"] = kept_items
	result["item_records"] = records
	_sanitize_container_slots(result.get("leader_loadout", {}) as Dictionary, terminal_instance_ids)
	_sanitize_container_slots(result.get("terminal_recovery_overflow", {}) as Dictionary, terminal_instance_ids)
	for stash: Variant in result.get("stash_tabs", []) as Array:
		if stash is Dictionary:
			_sanitize_container_slots(stash as Dictionary, terminal_instance_ids)
	return result

static func _sanitize_container_slots(container: Dictionary, terminal_instance_ids: Array[String]) -> void:
	if container.is_empty() or not container.get("slots", {}) is Dictionary:
		return
	var slots := container.get("slots", {}) as Dictionary
	for slot: Variant in slots.keys():
		if String(slots[slot]) in terminal_instance_ids:
			slots.erase(slot)
	container["slots"] = slots

static func _contains_any_string(value: Variant, needles: Array[String]) -> bool:
	if needles.is_empty():
		return false
	if value is String or value is StringName:
		return String(value) in needles
	if value is Array:
		for child: Variant in value as Array:
			if _contains_any_string(child, needles):
				return true
		return false
	if value is Dictionary:
		for key: Variant in value as Dictionary:
			if _contains_any_string(key, needles) or _contains_any_string((value as Dictionary)[key], needles):
				return true
	return false

func grant_gold(profile_id: String, transaction_id: String, amount: int, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	return apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		if amount <= 0:
			return "PROFILE_MUTATION_ERROR reason=gold amount must be positive"
		if amount > ProfileCodec.JSON_SAFE_INTEGER_MAX or profile.gold > ProfileCodec.JSON_SAFE_INTEGER_MAX - amount:
			return "PROFILE_MUTATION_ERROR reason=gold amount overflow"
		profile.gold += amount
		return ""
	, root, -1, "grant_gold", {"amount": amount})

func grant_passive_points(profile_id: String, transaction_id: String, amount: int, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	return apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		if amount <= 0:
			return "PROFILE_MUTATION_ERROR reason=passive point amount must be positive"
		if amount > ProfileCodec.JSON_SAFE_INTEGER_MAX or profile.passive_points_available > ProfileCodec.JSON_SAFE_INTEGER_MAX - amount or profile.passive_points_lifetime_earned > ProfileCodec.JSON_SAFE_INTEGER_MAX - amount:
			return "PROFILE_MUTATION_ERROR reason=passive point amount overflow"
		profile.passive_points_available += amount
		profile.passive_points_lifetime_earned += amount
		return ""
	, root, -1, "grant_passive_points", {"amount": amount})

func complete_prologue(profile_id: String, transaction_id: String, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	return apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		if profile.prologue_state == ProfileState.PrologueState.COMPLETED:
			return "PROFILE_MUTATION_ERROR reason=prologue already completed with different transaction"
		if profile.passive_points_available == ProfileCodec.JSON_SAFE_INTEGER_MAX or profile.passive_points_lifetime_earned == ProfileCodec.JSON_SAFE_INTEGER_MAX:
			return "PROFILE_MUTATION_ERROR reason=passive point amount overflow"
		profile.prologue_state = ProfileState.PrologueState.COMPLETED
		profile.passive_points_available += 1
		profile.passive_points_lifetime_earned += 1
		profile.permanent_feature_unlocks = _canonical_strings(profile.permanent_feature_unlocks, "city-heart")
		profile.discovered_trees = _canonical_strings(profile.discovered_trees, "party-forge-city-v1")
		profile.tree_allocations["party-forge-city-v1"] = _canonical_strings(profile.tree_allocations.get("party-forge-city-v1", []), "city-heart")
		return ""
	, root, -1, "complete_prologue", {})

static func _canonical_strings(values: Variant, required: String) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value: Variant in values as Array:
			var text := String(value)
			if text not in result:
				result.append(text)
	if required not in result:
		result.append(required)
	result.sort()
	return result

static func _fingerprint(operation: String, request: Dictionary) -> String:
	return ("%s\n%s" % [operation, JSON.stringify(_canonicalize(request))]).sha256_text()

static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key: Variant in source:
			keys.append(key as String)
		keys.sort()
		var result: Dictionary = {}
		for key: String in keys:
			result[key] = _canonicalize(source[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value as Array:
			result.append(_canonicalize(item))
		return result
	return value

static func _validate_request_value(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return ""
		TYPE_INT:
			var integer := int(value)
			return "" if integer >= -ProfileCodec.JSON_SAFE_INTEGER_MAX and integer <= ProfileCodec.JSON_SAFE_INTEGER_MAX else "contains integer outside JSON-safe integer range"
		TYPE_FLOAT:
			var number := float(value)
			if not is_finite(number):
				return "contains non-finite number"
			return "" if number != floor(number) or (number >= -float(ProfileCodec.JSON_SAFE_INTEGER_MAX) and number <= float(ProfileCodec.JSON_SAFE_INTEGER_MAX)) else "contains integer outside JSON-safe integer range"
		TYPE_ARRAY:
			for item: Variant in value as Array:
				var item_error := _validate_request_value(item)
				if not item_error.is_empty():
					return item_error
			return ""
		TYPE_DICTIONARY:
			for key: Variant in value as Dictionary:
				if typeof(key) != TYPE_STRING:
					return "contains non-string dictionary key"
				var value_error := _validate_request_value((value as Dictionary)[key])
				if not value_error.is_empty():
					return value_error
			return ""
		_:
			return "contains non-JSON value"
