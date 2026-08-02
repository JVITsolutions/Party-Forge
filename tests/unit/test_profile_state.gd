extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_new_profile_defaults(failures)
	_test_round_trip_and_deep_copy(failures)
	_test_malformed_and_future_schema_fail_closed(failures)
	_test_schema_one_field_types_fail_closed(failures)
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

func _test_schema_one_field_types_fail_closed(failures: Array[String]) -> void:
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
		{"field": "stash_tabs", "value": [{} , "bad"]},
		{"field": "extraction_capacity", "value": -1},
		{"field": "run_history", "value": [7]},
		{"field": "resumable_run", "value": "run"},
		{"field": "applied_transactions", "value": {"tx": 1000}},
	]
	for item: Dictionary in cases:
		var malformed := valid.duplicate(true)
		malformed[item["field"]] = item["value"]
		var result := ProfileCodec.decode(JSON.stringify(malformed))
		TestAssertions.truthy(not result.ok() and result.error.contains("field=%s" % item["field"]), "schema-one field %s fails closed" % item["field"], failures)

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
