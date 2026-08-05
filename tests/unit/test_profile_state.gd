extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_new_profile_defaults(failures)
	_test_round_trip_and_deep_copy(failures)
	_test_malformed_and_future_schema_fail_closed(failures)
	_test_current_field_types_fail_closed(failures)
	_test_exact_historical_and_current_fields_fail_closed(failures)
	_test_current_item_storage_is_strict_and_defensive(failures)
	_test_json_safe_integer_boundaries(failures)
	_test_transaction_record_shapes_fail_closed(failures)
	return failures

func _test_new_profile_defaults(failures: Array[String]) -> void:
	var profile := ProfileState.new_profile("profile-12345678", "Jacob", 1000)
	TestAssertions.equal(profile.schema_version, ProfileState.SCHEMA_VERSION, "profile uses current schema", failures)
	TestAssertions.equal(profile.prologue_state, ProfileState.PrologueState.NOT_STARTED, "prologue starts undiscovered", failures)
	TestAssertions.equal(profile.gold, 0, "gold starts at zero", failures)
	TestAssertions.equal(profile.passive_points_available, 0, "passive points start at zero", failures)
	TestAssertions.equal(profile.squad_capacity, 1, "profile starts with leader-only capacity", failures)
	TestAssertions.equal(profile.inventory_columns, 0, "inventory remains locked", failures)
	TestAssertions.equal(profile.get("item_records"), {"schema_version": 1, "items": []}, "item registry starts as a versioned empty document", failures)
	TestAssertions.equal(profile.stash_tabs, [], "stash starts empty", failures)
	TestAssertions.equal(profile.get("next_item_sequence"), 0, "item issuance sequence starts at zero", failures)
	TestAssertions.equal(profile.extraction_capacity, 0, "extraction remains locked", failures)

func _test_round_trip_and_deep_copy(failures: Array[String]) -> void:
	var profile := ProfileState.new_profile("profile-12345678", "Jacob", 1000)
	profile.permanent_feature_unlocks.append("equipment")
	profile.tree_allocations["party-forge-city-v1"] = ["city-heart"]
	var decoded := ProfileCodec.decode(ProfileCodec.encode(profile))
	TestAssertions.truthy(decoded.ok(), "valid profile decodes", failures)
	TestAssertions.equal(decoded.profile.to_dictionary(), profile.to_dictionary(), "profile round trips exactly", failures)
	var copied := profile.copy()
	(copied.tree_allocations["party-forge-city-v1"] as Array).append("shared-stash")
	TestAssertions.equal((profile.tree_allocations["party-forge-city-v1"] as Array).size(), 1, "copy isolates nested allocations", failures)

func _test_malformed_and_future_schema_fail_closed(failures: Array[String]) -> void:
	var malformed := ProfileCodec.decode("{not json")
	TestAssertions.truthy(not malformed.ok() and malformed.error.contains("PROFILE_DECODE_ERROR"), "malformed JSON reports decode error", failures)
	var profile_data := ProfileState.new_profile("profile-12345678", "Jacob", 1000).to_dictionary()
	var string_schema := profile_data.duplicate(true)
	string_schema["schema_version"] = str(ProfileState.SCHEMA_VERSION)
	var string_result := ProfileCodec.decode(JSON.stringify(string_schema))
	TestAssertions.truthy(not string_result.ok() and string_result.error.contains("unsupported schema"), "string schema fails closed", failures)
	var fractional_schema := profile_data.duplicate(true)
	fractional_schema["schema_version"] = float(ProfileState.SCHEMA_VERSION) + 0.5
	var fractional_result := ProfileCodec.decode(JSON.stringify(fractional_schema))
	TestAssertions.truthy(not fractional_result.ok() and fractional_result.error.contains("unsupported schema"), "fractional schema fails closed", failures)
	var future := profile_data.duplicate(true)
	future["schema_version"] = ProfileState.SCHEMA_VERSION + 1
	var future_result := ProfileCodec.decode(JSON.stringify(future))
	TestAssertions.truthy(not future_result.ok() and future_result.error.contains("unsupported schema"), "future schema fails closed", failures)

func _test_current_field_types_fail_closed(failures: Array[String]) -> void:
	var valid := ProfileState.new_profile("profile-12345678", "Jacob", 1000).to_dictionary()
	var cases: Array[Dictionary] = [
		{"field": "profile_id", "value": 7},
		{"field": "display_name", "value": 7},
		{"field": "created_at_unix", "value": "1000"},
		{"field": "updated_at_unix", "value": 1000.5},
		{"field": "prologue_state", "value": 9},
		{"field": "last_safe_checkpoint", "value": "checkpoint"},
		{"field": "gold", "value": "25"},
		{"field": "passive_points_available", "value": "1"},
		{"field": "passive_points_lifetime_earned", "value": -1},
		{"field": "milestones", "value": ["valid", 7]},
		{"field": "permanent_feature_unlocks", "value": {}},
		{"field": "discovered_buildings", "value": [null]},
		{"field": "discovered_trees", "value": "tree"},
		{"field": "tree_allocations", "value": {"tree": ["node", 7]}},
		{"field": "tree_visibility_progress", "value": {"tree": 1.5}},
		{"field": "owned_characters", "value": {"fighter": []}},
		{"field": "squad_capacity", "value": 0},
		{"field": "inventory_columns", "value": 9},
		{"field": "item_records", "value": {}},
		{"field": "stash_tabs", "value": [{} , "bad"]},
		{"field": "next_item_sequence", "value": -1},
		{"field": "extraction_capacity", "value": -1},
		{"field": "run_history", "value": [7]},
		{"field": "resumable_run", "value": "run"},
		{"field": "applied_transactions", "value": {"tx": 1000}},
	]
	for item: Dictionary in cases:
		var malformed := valid.duplicate(true)
		malformed[item["field"]] = item["value"]
		var result := ProfileCodec.decode(JSON.stringify(malformed))
		TestAssertions.truthy(not result.ok() and result.error.contains("field=%s" % item["field"]), "current field %s fails closed" % item["field"], failures)

func _test_exact_historical_and_current_fields_fail_closed(failures: Array[String]) -> void:
	var current := ProfileState.new_profile("profile-12345678", "Jacob", 1000).to_dictionary()
	var current_missing := current.duplicate(true)
	current_missing.erase("gold")
	TestAssertions.truthy(not _validate_current(current_missing).is_empty(), "current document rejects a missing field", failures)
	var current_extra := current.duplicate(true)
	current_extra["unexpected"] = true
	TestAssertions.truthy(not _validate_current(current_extra).is_empty(), "current document rejects an extra field", failures)
	var historical := current.duplicate(true)
	historical["schema_version"] = 1
	historical.erase("item_records")
	historical.erase("next_item_sequence")
	TestAssertions.equal(_validate_loadable(historical), "", "complete historical document remains loadable", failures)
	TestAssertions.truthy(not _validate_current(historical).is_empty(), "historical document is not current", failures)
	var historical_missing := historical.duplicate(true)
	historical_missing.erase("gold")
	TestAssertions.truthy(not _validate_loadable(historical_missing).is_empty(), "historical document rejects a missing field", failures)
	var historical_extra := historical.duplicate(true)
	historical_extra["unexpected"] = true
	TestAssertions.truthy(not _validate_loadable(historical_extra).is_empty(), "historical document rejects an extra field", failures)
	var current_snapshot := current.duplicate(true)
	current_snapshot["applied_transactions"] = {}
	var current_with_historical_snapshot := current.duplicate(true)
	var historical_snapshot := historical.duplicate(true)
	historical_snapshot["applied_transactions"] = {}
	current_with_historical_snapshot["applied_transactions"] = {"tx": _transaction_record(historical_snapshot)}
	TestAssertions.truthy(not _validate_current(current_with_historical_snapshot).is_empty(), "current transaction rejects a historical result snapshot", failures)
	var historical_with_current_snapshot := historical.duplicate(true)
	historical_with_current_snapshot["applied_transactions"] = {"tx": _transaction_record(current_snapshot)}
	TestAssertions.truthy(not _validate_loadable(historical_with_current_snapshot).is_empty(), "historical transaction rejects a current result snapshot", failures)

func _test_current_item_storage_is_strict_and_defensive(failures: Array[String]) -> void:
	var current := ProfileState.new_profile("profile-storage1", "Storage", 1000).to_dictionary()
	current["item_records"] = {"schema_version": 1, "items": [_valid_item_document()]}
	current["stash_tabs"] = [{
		"schema_version": 1,
		"container_id": "stash-0001",
		"container_kind": "profile_stash_tab",
		"owner_id": "profile-storage1",
		"capacity": 100,
		"slots": {"7": "item-profile-0001"},
	}]
	current["next_item_sequence"] = 1
	var decoded := ProfileCodec.decode_document(current)
	TestAssertions.truthy(decoded.ok(), "valid catalog-backed profile storage decodes", failures)
	current["next_item_sequence"] = 99
	((current["item_records"] as Dictionary)["items"] as Array)[0]["base_definition_id"] = "unknown_after_decode"
	((current["stash_tabs"] as Array)[0] as Dictionary)["slots"] = {}
	if decoded.profile != null:
		TestAssertions.equal(decoded.profile.get("next_item_sequence"), 1, "decoded issuance sequence is isolated", failures)
		if decoded.profile.get("item_records") is Dictionary:
			var decoded_items := (decoded.profile.get("item_records") as Dictionary)["items"] as Array
			TestAssertions.equal((decoded_items[0] as Dictionary)["base_definition_id"], "forge_vanguard_sword", "decoded item records are isolated", failures)
		if not decoded.profile.stash_tabs.is_empty():
			TestAssertions.equal((decoded.profile.stash_tabs[0] as Dictionary)["slots"], {"7": "item-profile-0001"}, "decoded stash records are isolated", failures)
	var wrong_registry_schema := ProfileState.new_profile("profile-storage1", "Storage", 1000).to_dictionary()
	wrong_registry_schema["item_records"] = {"schema_version": 2, "items": []}
	var wrong_schema_error := ProfileCodec.validate_current_document(wrong_registry_schema)
	TestAssertions.truthy(wrong_schema_error.contains("PARTY_FORGE_ITEM_REGISTRY_ERROR") and wrong_schema_error.contains("field=registry.schema_version"), "empty registry with wrong schema reaches strict ownership validation", failures)
	var extra_registry_field := ProfileState.new_profile("profile-storage1", "Storage", 1000).to_dictionary()
	extra_registry_field["item_records"] = {"schema_version": 1, "items": [], "legacy_map": {}}
	var extra_field_error := ProfileCodec.validate_current_document(extra_registry_field)
	TestAssertions.truthy(extra_field_error.contains("PARTY_FORGE_ITEM_REGISTRY_ERROR") and extra_field_error.contains("unexpected fields legacy_map"), "empty registry with extra field reaches strict ownership validation", failures)
	var invalid_item := ProfileState.new_profile("profile-storage1", "Storage", 1000).to_dictionary()
	invalid_item["item_records"] = {"schema_version": 1, "items": [_valid_item_document()]}
	((invalid_item["item_records"] as Dictionary)["items"] as Array)[0]["base_definition_id"] = "unknown-equipment"
	TestAssertions.truthy(not ProfileCodec.decode_document(invalid_item).ok(), "unknown persisted item is rejected", failures)
	var invalid_stash := ProfileState.new_profile("profile-storage1", "Storage", 1000).to_dictionary()
	invalid_stash["stash_tabs"] = [{
		"schema_version": 1,
		"container_id": "run-not-stash",
		"container_kind": "run_inventory",
		"owner_id": "profile-storage1",
		"capacity": 0,
		"slots": {},
	}]
	TestAssertions.truthy(not ProfileCodec.decode_document(invalid_stash).ok(), "non-stash persistent container is rejected", failures)
	for invalid_sequence: Variant in [-1, 9007199254740992, 1.5, "1"]:
		var invalid := ProfileState.new_profile("profile-storage1", "Storage", 1000).to_dictionary()
		invalid["next_item_sequence"] = invalid_sequence
		TestAssertions.truthy(not ProfileCodec.decode_document(invalid).ok(), "invalid item sequence %s is rejected" % str(invalid_sequence), failures)

func _test_json_safe_integer_boundaries(failures: Array[String]) -> void:
	const SAFE_MAX := 9007199254740991
	const FIRST_UNSAFE := 9007199254740992
	const ROUNDED_UNSAFE := 9007199254740993
	var valid := ProfileState.new_profile("profile-12345678", "Jacob", 1000).to_dictionary()
	valid["gold"] = SAFE_MAX
	var safe_result := ProfileCodec.decode(JSON.stringify(valid))
	TestAssertions.truthy(safe_result.ok(), "largest JSON-safe integer decodes", failures)
	TestAssertions.equal(safe_result.profile.gold if safe_result.ok() else -1, SAFE_MAX, "largest JSON-safe integer round trips exactly", failures)
	var top_level_fields: Array[String] = [
		"created_at_unix",
		"updated_at_unix",
		"gold",
		"passive_points_available",
		"passive_points_lifetime_earned",
		"squad_capacity",
		"next_item_sequence",
		"extraction_capacity",
	]
	for field: String in top_level_fields:
		for unsafe_value: int in [FIRST_UNSAFE, ROUNDED_UNSAFE]:
			var malformed := ProfileState.new_profile("profile-12345678", "Jacob", 1000).to_dictionary()
			malformed[field] = unsafe_value
			if field == "created_at_unix":
				malformed["updated_at_unix"] = unsafe_value
			elif field == "passive_points_available":
				malformed["passive_points_lifetime_earned"] = unsafe_value
			var result := ProfileCodec.decode(JSON.stringify(malformed))
			TestAssertions.truthy(not result.ok() and result.error.contains("field=%s" % field), "%s rejects unsafe JSON integer %d" % [field, unsafe_value], failures)
	var unsafe_visibility := ProfileState.new_profile("profile-12345678", "Jacob", 1000).to_dictionary()
	unsafe_visibility["tree_visibility_progress"] = {"party-forge-city-v1": FIRST_UNSAFE}
	var visibility_result := ProfileCodec.decode(JSON.stringify(unsafe_visibility))
	TestAssertions.truthy(not visibility_result.ok() and visibility_result.error.contains("field=tree_visibility_progress"), "tree visibility rejects unsafe JSON integers", failures)
	var unsafe_nested := ProfileState.new_profile("profile-12345678", "Jacob", 1000).to_dictionary()
	unsafe_nested["last_safe_checkpoint"] = {"tick": FIRST_UNSAFE}
	var nested_result := ProfileCodec.decode(JSON.stringify(unsafe_nested))
	TestAssertions.truthy(not nested_result.ok() and nested_result.error.contains("field=last_safe_checkpoint"), "nested JSON dictionaries reject unsafe integers", failures)
	var unsafe_transaction := ProfileState.new_profile("profile-12345678", "Jacob", 1000).to_dictionary()
	var snapshot := unsafe_transaction.duplicate(true)
	snapshot["updated_at_unix"] = FIRST_UNSAFE
	snapshot["applied_transactions"] = {}
	unsafe_transaction["applied_transactions"] = {
		"tx": {
			"operation": "grant_gold",
			"fingerprint": "a".repeat(64),
			"committed_at_unix": FIRST_UNSAFE,
			"result_profile": snapshot,
		},
	}
	var transaction_result := ProfileCodec.decode(JSON.stringify(unsafe_transaction))
	TestAssertions.truthy(not transaction_result.ok() and transaction_result.error.contains("field=applied_transactions"), "transaction timestamps reject unsafe JSON integers", failures)

func _test_transaction_record_shapes_fail_closed(failures: Array[String]) -> void:
	var valid := ProfileState.new_profile("profile-12345678", "Jacob", 1000).to_dictionary()
	var snapshot := valid.duplicate(true)
	snapshot["applied_transactions"] = {}
	var record := {
		"operation": "grant_gold",
		"fingerprint": "a".repeat(64),
		"committed_at_unix": 1000,
		"result_profile": snapshot,
	}
	var cases: Array[Dictionary] = []
	var missing_operation := record.duplicate(true)
	missing_operation.erase("operation")
	cases.append(missing_operation)
	var bad_fingerprint := record.duplicate(true)
	bad_fingerprint["fingerprint"] = "not-a-fingerprint"
	cases.append(bad_fingerprint)
	var fractional_timestamp := record.duplicate(true)
	fractional_timestamp["committed_at_unix"] = 1000.5
	cases.append(fractional_timestamp)
	var recursive_snapshot := record.duplicate(true)
	var recursive_profile := snapshot.duplicate(true)
	recursive_profile["applied_transactions"] = {"nested": record.duplicate(true)}
	recursive_snapshot["result_profile"] = recursive_profile
	cases.append(recursive_snapshot)
	for index: int in range(cases.size()):
		var malformed := valid.duplicate(true)
		malformed["applied_transactions"] = {"tx": cases[index]}
		var result := ProfileCodec.decode(JSON.stringify(malformed))
		TestAssertions.truthy(not result.ok() and result.error.contains("field=applied_transactions"), "transaction record shape %d fails closed" % index, failures)

func _transaction_record(snapshot: Dictionary) -> Dictionary:
	return {
		"operation": "grant_gold",
		"fingerprint": "a".repeat(64),
		"committed_at_unix": int(snapshot["updated_at_unix"]),
		"result_profile": snapshot,
	}

func _validate_current(document: Dictionary) -> String:
	var validator := Callable(ProfileCodec, "validate_current_document")
	return str(validator.call(document)) if validator.is_valid() else "missing current validator"

func _validate_loadable(document: Dictionary) -> String:
	var validator := Callable(ProfileCodec, "validate_loadable_document")
	return str(validator.call(document)) if validator.is_valid() else "missing loadable validator"

func _valid_item_document() -> Dictionary:
	return {
		"affixes": [],
		"base_definition_id": "forge_vanguard_sword",
		"instance_id": "item-profile-0001",
		"item_level": 1,
		"origin": {
			"issuer_namespace": "profile:profile-storage1",
			"seed": 4402,
			"sequence": 0,
			"source": "test_fixture",
		},
		"rarity_id": "common",
		"schema_version": 1,
	}
