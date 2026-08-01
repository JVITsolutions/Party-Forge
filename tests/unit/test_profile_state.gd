extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_new_profile_defaults(failures)
	_test_round_trip_and_deep_copy(failures)
	_test_malformed_and_future_schema_fail_closed(failures)
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
