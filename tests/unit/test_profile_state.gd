extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_new_profile_defaults(failures)
	_test_round_trip_and_deep_copy(failures)
	_test_malformed_and_future_schema_fail_closed(failures)
	_test_current_field_types_fail_closed(failures)
	_test_exact_historical_and_current_fields_fail_closed(failures)
	_test_current_item_storage_is_strict_and_defensive(failures)
	_test_current_stash_tab_cap(failures)
	_test_json_safe_integer_boundaries(failures)
	_test_transaction_record_shapes_fail_closed(failures)
	return failures

func _test_new_profile_defaults(failures: Array[String]) -> void:
	var profile := ProfileState.new_profile("profile-12345678", "Jacob", 1000)
	TestAssertions.equal(ProfileState.SCHEMA_VERSION, 4, "profile schema version is four", failures)
	TestAssertions.equal(profile.schema_version, ProfileState.SCHEMA_VERSION, "profile uses current schema", failures)
	TestAssertions.equal(profile.prologue_state, ProfileState.PrologueState.NOT_STARTED, "prologue starts undiscovered", failures)
	TestAssertions.equal(profile.gold, 0, "gold starts at zero", failures)
	TestAssertions.equal(profile.passive_points_available, 0, "passive points start at zero", failures)
	TestAssertions.equal(profile.squad_capacity, 1, "profile starts with leader-only capacity", failures)
	TestAssertions.equal(profile.inventory_columns, 0, "inventory remains locked", failures)
	TestAssertions.equal(profile.get("item_records"), {"schema_version": 1, "items": []}, "item registry starts as a versioned empty document", failures)
	TestAssertions.equal(profile.get("leader_loadout"), _leader_loadout_document(profile.profile_id, {}), "leader loadout starts as the exact fixed equipment container", failures)
	TestAssertions.equal(profile.get("leader_loadout_class_id"), "", "leader loadout starts without a selected class", failures)
	TestAssertions.equal(profile.stash_tabs, [], "stash starts empty", failures)
	TestAssertions.equal(profile.get("next_item_sequence"), 0, "item issuance sequence starts at zero", failures)
	TestAssertions.equal(profile.extraction_capacity, 0, "extraction remains locked", failures)

func _test_round_trip_and_deep_copy(failures: Array[String]) -> void:
	var profile := ProfileState.new_profile("profile-storage1", "Jacob", 1000)
	profile.permanent_feature_unlocks.append("equipment")
	profile.tree_allocations["party-forge-city-v1"] = ["city-heart"]
	profile.set("leader_loadout_class_id", "fighter")
	var decoded := ProfileCodec.decode(ProfileCodec.encode(profile))
	TestAssertions.truthy(decoded.ok(), "valid profile decodes", failures)
	TestAssertions.equal(decoded.profile.to_dictionary(), profile.to_dictionary(), "profile round trips exactly", failures)
	TestAssertions.equal(decoded.profile.get("leader_loadout_class_id") if decoded.profile != null else "missing", "fighter", "nonempty leader class ID round trips exactly", failures)
	var copied := profile.copy()
	(copied.tree_allocations["party-forge-city-v1"] as Array).append("shared-stash")
	TestAssertions.equal((profile.tree_allocations["party-forge-city-v1"] as Array).size(), 1, "copy isolates nested allocations", failures)
	if copied.get("leader_loadout") is Dictionary:
		(copied.get("leader_loadout") as Dictionary)["slots"] = {"9": "escaped-copy"}
	TestAssertions.equal(profile.get("leader_loadout"), _leader_loadout_document(profile.profile_id, {}), "copy isolates the nested leader loadout", failures)

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
		{"field": "leader_loadout", "value": []},
		{"field": "leader_loadout_class_id", "value": 7},
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
	historical.erase("preferred_player_color_id")
	historical.erase("item_records")
	historical.erase("leader_loadout")
	historical.erase("leader_loadout_class_id")
	historical.erase("next_item_sequence")
	TestAssertions.equal(_validate_loadable(historical), "", "complete historical document remains loadable", failures)
	TestAssertions.truthy(not _validate_current(historical).is_empty(), "historical document is not current", failures)
	var historical_missing := historical.duplicate(true)
	historical_missing.erase("gold")
	TestAssertions.truthy(not _validate_loadable(historical_missing).is_empty(), "historical document rejects a missing field", failures)
	var historical_extra := historical.duplicate(true)
	historical_extra["unexpected"] = true
	TestAssertions.truthy(not _validate_loadable(historical_extra).is_empty(), "historical document rejects an extra field", failures)
	var schema_two := current.duplicate(true)
	schema_two["schema_version"] = 2
	schema_two.erase("preferred_player_color_id")
	schema_two.erase("leader_loadout")
	schema_two.erase("leader_loadout_class_id")
	TestAssertions.equal(_validate_loadable(schema_two), "", "complete schema-two document remains loadable for migration", failures)
	var schema_two_extra := schema_two.duplicate(true)
	schema_two_extra["leader_loadout"] = _leader_loadout_document("profile-12345678", {})
	TestAssertions.truthy(not _validate_loadable(schema_two_extra).is_empty(), "schema-two document rejects schema-three fields", failures)
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
	var sword := _valid_item_document("item-profile-sword", "forge_vanguard_sword", 0)
	var shield := _valid_item_document("item-profile-shield", "forge_vanguard_shield", 1)
	var armour := _valid_item_document("item-profile-armour", "forge_vanguard_armour", 2)
	current["item_records"] = {"schema_version": 1, "items": [armour, shield, sword]}
	current["leader_loadout"] = _leader_loadout_document("profile-storage1", {
		"9": "item-profile-sword",
		"10": "item-profile-shield",
	})
	current["leader_loadout_class_id"] = "fighter"
	current["stash_tabs"] = [{
		"schema_version": 1,
		"container_id": "stash-0001",
		"container_kind": "profile_stash_tab",
		"owner_id": "profile-storage1",
		"capacity": 100,
		"slots": {"7": "item-profile-armour"},
	}]
	current["next_item_sequence"] = 3
	var decoded := ProfileCodec.decode_document(current)
	TestAssertions.truthy(decoded.ok(), "valid catalog-backed loadout and stash decode as one ownership domain", failures)
	current["next_item_sequence"] = 99
	((current["item_records"] as Dictionary)["items"] as Array)[0]["base_definition_id"] = "unknown_after_decode"
	(current["leader_loadout"] as Dictionary)["slots"] = {}
	current["leader_loadout_class_id"] = "mutated_after_decode"
	((current["stash_tabs"] as Array)[0] as Dictionary)["slots"] = {}
	if decoded.profile != null:
		TestAssertions.equal(decoded.profile.get("next_item_sequence"), 3, "decoded issuance sequence is isolated", failures)
		TestAssertions.equal(decoded.profile.get("leader_loadout_class_id"), "fighter", "decoded leader class ID is isolated", failures)
		TestAssertions.equal((decoded.profile.get("leader_loadout") as Dictionary)["slots"], {"9": "item-profile-sword", "10": "item-profile-shield"}, "decoded leader slot placement is exact and isolated", failures)
		if decoded.profile.get("item_records") is Dictionary:
			var decoded_items := (decoded.profile.get("item_records") as Dictionary)["items"] as Array
			TestAssertions.equal((decoded_items[0] as Dictionary)["base_definition_id"], "forge_vanguard_armour", "decoded item records are isolated", failures)
		if not decoded.profile.stash_tabs.is_empty():
			TestAssertions.equal((decoded.profile.stash_tabs[0] as Dictionary)["slots"], {"7": "item-profile-armour"}, "decoded stash records are isolated", failures)
		var copied := decoded.profile.copy()
		(copied.get("leader_loadout") as Dictionary)["slots"] = {}
		TestAssertions.equal((decoded.profile.get("leader_loadout") as Dictionary)["slots"], {"9": "item-profile-sword", "10": "item-profile-shield"}, "returned profile copies isolate leader placement", failures)
	var valid_leader := ProfileState.new_profile("profile-storage1", "Storage", 1000).to_dictionary()
	valid_leader["item_records"] = {"schema_version": 1, "items": [shield, sword]}
	valid_leader["leader_loadout"] = _leader_loadout_document("profile-storage1", {"9": "item-profile-sword", "10": "item-profile-shield"})
	valid_leader["next_item_sequence"] = 2
	var leader_cases: Array[Dictionary] = [
		{"label": "wrong owner", "field": "owner_id", "value": "profile-other001"},
		{"label": "wrong kind", "field": "container_kind", "value": "profile_stash_tab"},
		{"label": "wrong capacity", "field": "capacity", "value": 10},
	]
	for test_case: Dictionary in leader_cases:
		var malformed := valid_leader.duplicate(true)
		(malformed["leader_loadout"] as Dictionary)[test_case["field"]] = test_case["value"]
		var result := ProfileCodec.decode_document(malformed)
		TestAssertions.truthy(not result.ok() and result.error.contains("field=leader_loadout"), "leader loadout rejects %s" % test_case["label"], failures)
	var orphan := valid_leader.duplicate(true)
	(orphan["leader_loadout"] as Dictionary)["slots"] = {"9": "item-profile-missing", "10": "item-profile-shield"}
	var orphan_result := ProfileCodec.decode_document(orphan)
	TestAssertions.truthy(not orphan_result.ok() and orphan_result.error.contains("field=leader_loadout"), "leader loadout rejects orphan item placement", failures)
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

func _test_current_stash_tab_cap(failures: Array[String]) -> void:
	TestAssertions.equal(ProfileState.MAX_STASH_TABS, 100, "profile schema exposes the shared 100-tab invariant", failures)
	var oversized := ProfileState.new_profile("profile-stashcap1", "Stash Cap", 1000).to_dictionary()
	var tabs: Array[Dictionary] = []
	for index: int in 101:
		tabs.append(ItemSlotContainer.create(
			StringName("stash-tab-%03d" % index),
			ItemSlotContainer.PROFILE_STASH_TAB,
			"profile-stashcap1",
			ItemSlotContainer.STASH_CAPACITY
		).to_dictionary())
	var at_cap := oversized.duplicate(true)
	at_cap["stash_tabs"] = tabs.slice(0, ProfileState.MAX_STASH_TABS)
	TestAssertions.equal(ProfileCodec.validate_current_document(at_cap), "", "current schema preserves exactly 100 valid unique stash tabs", failures)
	TestAssertions.truthy(ProfileCodec.decode_document(at_cap).ok(), "codec loads exactly 100 valid unique stash tabs", failures)
	oversized["stash_tabs"] = tabs
	var current_error := ProfileCodec.validate_current_document(oversized)
	var loadable_error := ProfileCodec.validate_loadable_document(oversized)
	var decoded := ProfileCodec.decode_document(oversized)
	TestAssertions.truthy(current_error.contains("field=stash_tabs") and current_error.contains("maximum 100"), "current schema rejects 101 valid unique stash tabs", failures)
	TestAssertions.truthy(loadable_error.contains("field=stash_tabs") and loadable_error.contains("maximum 100"), "load validator rejects 101 valid unique stash tabs", failures)
	TestAssertions.truthy(not decoded.ok() and decoded.profile == null and decoded.error.contains("field=stash_tabs"), "codec exposes no profile for 101 otherwise-valid stash tabs", failures)

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

func _leader_loadout_document(owner_id: String, slots: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"container_id": "leader-loadout",
		"container_kind": "profile_leader_equipment",
		"owner_id": owner_id,
		"capacity": 11,
		"slots": slots.duplicate(true),
	}

func _valid_item_document(
	instance_id: String = "item-profile-0001",
	base_definition_id: String = "forge_vanguard_sword",
	sequence: int = 0
) -> Dictionary:
	return {
		"affixes": [],
		"base_definition_id": base_definition_id,
		"instance_id": instance_id,
		"item_level": 1,
		"origin": {
			"issuer_namespace": "profile:profile-storage1",
			"seed": 4402,
			"sequence": sequence,
			"source": "test_fixture",
		},
		"rarity_id": "common",
		"schema_version": 1,
	}
