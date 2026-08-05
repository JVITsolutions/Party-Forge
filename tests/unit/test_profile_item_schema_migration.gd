extends RefCounted

const SCHEMA_TWO_FIELDS: Array[String] = [
	"schema_version", "profile_id", "display_name", "created_at_unix", "updated_at_unix",
	"prologue_state", "last_safe_checkpoint", "gold", "passive_points_available",
	"passive_points_lifetime_earned", "milestones", "permanent_feature_unlocks",
	"discovered_buildings", "discovered_trees", "tree_allocations", "tree_visibility_progress",
	"owned_characters", "squad_capacity", "inventory_columns", "item_records", "stash_tabs",
	"next_item_sequence", "extraction_capacity", "run_history", "resumable_run", "applied_transactions",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists("res://scripts/profile/profile_migrator.gd"):
		TestAssertions.truthy(false, "profile migrator implementation exists", failures)
		return failures
	var migrator_script := load("res://scripts/profile/profile_migrator.gd") as Script
	TestAssertions.truthy(migrator_script != null, "profile migrator implementation exists", failures)
	if migrator_script == null:
		return failures
	_test_complete_schema_one_migrates_recursively(failures)
	_test_json_parsed_schema_one_migrates_to_complete_canonical_document(failures)
	_test_schema_two_items_and_progression_migrate_losslessly(failures)
	_test_unsupported_legacy_stash_fails_without_mutation(failures)
	_test_current_schema_reports_source_metadata(failures)
	_test_normal_store_is_current_only(failures)
	return failures

func _test_complete_schema_one_migrates_recursively(failures: Array[String]) -> void:
	var original := schema_one_document("profile-migrate01", 77, 2000, true)
	var before := original.duplicate(true)
	var before_text := JSON.stringify(original, "\t", false)
	var migrated: Variant = _migrate(original)
	var migrated_profile := migrated.get("profile") as ProfileState
	TestAssertions.truthy(bool(migrated.call("ok")), "complete schema-one profile migrates", failures)
	TestAssertions.equal(migrated_profile.schema_version if migrated_profile != null else -1, 3, "profile migrates through schema two to schema three", failures)
	TestAssertions.equal(migrated_profile.gold if migrated_profile != null else -1, 77, "gold survives migration", failures)
	TestAssertions.equal(migrated_profile.tree_allocations if migrated_profile != null else {}, original["tree_allocations"], "allocations survive migration", failures)
	TestAssertions.equal(migrated_profile.get("item_records") if migrated_profile != null else {}, {"schema_version": 1, "items": []}, "migration invents no items", failures)
	TestAssertions.equal(migrated_profile.stash_tabs if migrated_profile != null else [{}], [], "migration invents no stash", failures)
	TestAssertions.equal(migrated_profile.get("next_item_sequence") if migrated_profile != null else -1, 0, "issuance starts empty", failures)
	TestAssertions.equal(migrated_profile.get("leader_loadout") if migrated_profile != null else {}, _leader_loadout("profile-migrate01"), "schema-one migration adds the exact empty leader loadout", failures)
	TestAssertions.equal(migrated_profile.get("leader_loadout_class_id") if migrated_profile != null else "missing", "", "schema-one migration adds an empty leader class ID", failures)
	TestAssertions.truthy(bool(migrated.get("migrated")) and int(migrated.get("source_schema_version")) == 1, "migration reports schema-one source", failures)
	if migrated_profile != null:
		var nested := (migrated_profile.applied_transactions["grant-001"] as Dictionary)["result_profile"] as Dictionary
		TestAssertions.equal(nested["schema_version"], 3, "nested result snapshot migrates through schema two to schema three", failures)
		TestAssertions.equal(nested["item_records"], {"schema_version": 1, "items": []}, "nested migration invents no items", failures)
		TestAssertions.equal(nested["stash_tabs"], [], "nested migration invents no stash", failures)
		TestAssertions.equal(nested["next_item_sequence"], 0, "nested issuance starts empty", failures)
		TestAssertions.equal(nested.get("leader_loadout"), _leader_loadout("profile-migrate01"), "nested migration adds the exact leader loadout", failures)
		TestAssertions.equal(nested.get("leader_loadout_class_id"), "", "nested migration adds an empty leader class ID", failures)
		TestAssertions.equal(nested["gold"], 55, "nested result values survive migration", failures)
	TestAssertions.equal(original, before, "migration leaves source dictionary unchanged", failures)
	TestAssertions.equal(JSON.stringify(original, "\t", false), before_text, "migration leaves source serialization byte-equivalent", failures)

func _test_json_parsed_schema_one_migrates_to_complete_canonical_document(failures: Array[String]) -> void:
	var literal := schema_one_document("profile-migrate08", 77, 2000, true)
	var original := JSON.parse_string(JSON.stringify(literal, "\t", false)) as Dictionary
	var before := original.duplicate(true)
	var before_text := JSON.stringify(original, "\t", false)
	var migrated: Variant = _migrate(original)
	var migrated_profile := migrated.get("profile") as ProfileState
	TestAssertions.truthy(bool(migrated.call("ok")), "JSON-parsed schema-one profile migrates", failures)
	if migrated_profile != null:
		var actual := migrated_profile.to_dictionary()
		var expected := _expected_schema_three_document(original)
		TestAssertions.equal(actual, expected, "JSON-parsed migration matches the complete canonical schema-three document", failures)
		TestAssertions.equal(Array(actual.keys()), ProfileCodec.CURRENT_FIELDS, "migrated root uses deterministic current field order", failures)
		var record := (actual["applied_transactions"] as Dictionary)["grant-001"] as Dictionary
		var nested := record["result_profile"] as Dictionary
		TestAssertions.equal(Array(nested.keys()), ProfileCodec.CURRENT_FIELDS, "migrated result snapshot uses deterministic current field order", failures)
		for field: String in ["schema_version", "created_at_unix", "updated_at_unix", "prologue_state", "gold", "passive_points_available", "passive_points_lifetime_earned", "squad_capacity", "inventory_columns", "next_item_sequence", "extraction_capacity"]:
			TestAssertions.equal(typeof(nested[field]), TYPE_INT, "migrated result snapshot field %s is an integer" % field, failures)
		TestAssertions.equal(typeof((nested["tree_visibility_progress"] as Dictionary)["party-forge-city-v1"]), TYPE_INT, "migrated result snapshot visibility is an integer", failures)
		TestAssertions.equal(typeof(record["committed_at_unix"]), TYPE_INT, "migrated transaction timestamp is an integer", failures)
	TestAssertions.equal(original, before, "JSON-parsed migration leaves source dictionary unchanged", failures)
	TestAssertions.equal(JSON.stringify(original, "\t", false), before_text, "JSON-parsed migration leaves source serialization byte-equivalent", failures)

func _test_schema_two_items_and_progression_migrate_losslessly(failures: Array[String]) -> void:
	var original := schema_two_document("profile-migrate09")
	var before := original.duplicate(true)
	var before_text := JSON.stringify(original, "\t", false)
	var migrated: Variant = _migrate(original)
	var profile := migrated.get("profile") as ProfileState
	TestAssertions.truthy(bool(migrated.call("ok")), "item-bearing schema-two profile migrates", failures)
	TestAssertions.truthy(bool(migrated.get("migrated")) and int(migrated.get("source_schema_version")) == 2, "schema-two migration reports exact source metadata", failures)
	if profile != null:
		var actual := profile.to_dictionary()
		TestAssertions.equal(actual["schema_version"], 3, "schema-two profile promotes to schema three", failures)
		TestAssertions.equal(actual.get("leader_loadout"), _leader_loadout("profile-migrate09"), "schema-two migration adds only the empty leader loadout", failures)
		TestAssertions.equal(actual.get("leader_loadout_class_id"), "", "migrated empty loadout has no selected class", failures)
		for field: String in SCHEMA_TWO_FIELDS:
			if field in ["schema_version", "applied_transactions"]:
				continue
			TestAssertions.equal(JSON.stringify(actual[field]), JSON.stringify(original[field]), "schema-two field %s survives byte-semantically" % field, failures)
		var original_record := (original["applied_transactions"] as Dictionary)["storage-001"] as Dictionary
		var actual_record := (actual["applied_transactions"] as Dictionary)["storage-001"] as Dictionary
		for field: String in ["operation", "fingerprint", "committed_at_unix"]:
			TestAssertions.equal(actual_record[field], original_record[field], "transaction field %s survives migration" % field, failures)
		var original_snapshot := original_record["result_profile"] as Dictionary
		var actual_snapshot := actual_record["result_profile"] as Dictionary
		for field: String in SCHEMA_TWO_FIELDS:
			if field in ["schema_version", "applied_transactions"]:
				continue
			TestAssertions.equal(JSON.stringify(actual_snapshot[field]), JSON.stringify(original_snapshot[field]), "transaction snapshot field %s survives migration" % field, failures)
		TestAssertions.equal(actual_snapshot.get("leader_loadout"), _leader_loadout("profile-migrate09"), "transaction snapshot gains the exact empty leader loadout", failures)
		TestAssertions.equal(actual_snapshot.get("leader_loadout_class_id"), "", "transaction snapshot gains an empty leader class ID", failures)
	TestAssertions.equal(original, before, "schema-two migration leaves source dictionary unchanged", failures)
	TestAssertions.equal(JSON.stringify(original, "\t", false), before_text, "schema-two migration leaves source serialization byte-equivalent", failures)

func _test_unsupported_legacy_stash_fails_without_mutation(failures: Array[String]) -> void:
	var original := schema_one_document("profile-migrate02", 77, 2000, true)
	original["stash_tabs"] = [{"legacy_item": "unowned-record"}]
	var before := original.duplicate(true)
	var migrated: Variant = _migrate(original)
	TestAssertions.equal(migrated.get("error"), "PARTY_FORGE_PROFILE_MIGRATION_ERROR field=stash_tabs reason=unsupported legacy storage", "legacy stash failure is exact", failures)
	TestAssertions.equal(migrated.get("profile"), null, "failed migration exposes no partial profile", failures)
	TestAssertions.equal(original, before, "failed migration leaves source unchanged", failures)

func _test_current_schema_reports_source_metadata(failures: Array[String]) -> void:
	var current := ProfileState.new_profile("profile-current02", "Current", 3000)
	var decoded := ProfileCodec.decode_document(current.to_dictionary())
	TestAssertions.truthy(decoded.ok(), "current profile decodes", failures)
	TestAssertions.truthy(not decoded.migrated, "current profile is not reported migrated", failures)
	TestAssertions.equal(decoded.source_schema_version, 3, "current profile reports schema-three source", failures)

func _test_normal_store_is_current_only(failures: Array[String]) -> void:
	var root := "user://tests/profile_schema_store_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(root)
	var store := ProfileStore.new()
	var current := ProfileState.new_profile("profile-current03", "Current", 3000)
	TestAssertions.equal(store.save_profile(current, root), "", "normal store saves current schema", failures)
	var current_bytes := FileAccess.get_file_as_bytes(store.profile_path(current.profile_id, root))
	var loaded := store.load_profile(current.profile_id, root)
	TestAssertions.truthy(loaded.ok() and not loaded.migrated, "ordinary current store load is not migrated", failures)
	TestAssertions.equal(loaded.source_schema_version, 3, "ordinary current store load reports schema-three source", failures)
	var legacy_typed_state := current.copy()
	legacy_typed_state.schema_version = 2
	var save_error := store.save_profile(legacy_typed_state, root)
	TestAssertions.truthy(not save_error.is_empty() and save_error.contains("unsupported schema"), "normal store rejects a schema-two typed state", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(store.profile_path(current.profile_id, root)), current_bytes, "rejected legacy normal save preserves current bytes", failures)
	ProfileTestSupport.remove_tree(root)

func _migrate(document: Dictionary) -> Variant:
	var migrator_script := load("res://scripts/profile/profile_migrator.gd") as Script
	return migrator_script.call("migrate_document", document)

static func _expected_schema_three_document(legacy: Dictionary) -> Dictionary:
	return _expected_schema_three_from_two(_expected_schema_two_document(legacy))

static func _expected_schema_three_from_two(schema_two: Dictionary) -> Dictionary:
	var result := schema_two.duplicate(true)
	result["schema_version"] = 3
	result["leader_loadout"] = _leader_loadout(String(schema_two["profile_id"]))
	result["leader_loadout_class_id"] = ""
	var transactions := result["applied_transactions"] as Dictionary
	for transaction_id: Variant in transactions:
		var record := transactions[transaction_id] as Dictionary
		record["result_profile"] = _expected_schema_three_from_two(record["result_profile"] as Dictionary)
	return result

static func _expected_schema_two_document(legacy: Dictionary) -> Dictionary:
	var visibility: Dictionary = {}
	for tree_id: Variant in legacy["tree_visibility_progress"] as Dictionary:
		visibility[String(tree_id)] = int((legacy["tree_visibility_progress"] as Dictionary)[tree_id])
	var transactions: Dictionary = {}
	for transaction_id: Variant in legacy["applied_transactions"] as Dictionary:
		var record := (legacy["applied_transactions"] as Dictionary)[transaction_id] as Dictionary
		transactions[String(transaction_id)] = {
			"operation": record["operation"],
			"fingerprint": record["fingerprint"],
			"committed_at_unix": int(record["committed_at_unix"]),
			"result_profile": _expected_schema_two_document(record["result_profile"] as Dictionary),
		}
	return {
		"schema_version": 2,
		"profile_id": legacy["profile_id"],
		"display_name": legacy["display_name"],
		"created_at_unix": int(legacy["created_at_unix"]),
		"updated_at_unix": int(legacy["updated_at_unix"]),
		"prologue_state": int(legacy["prologue_state"]),
		"last_safe_checkpoint": (legacy["last_safe_checkpoint"] as Dictionary).duplicate(true),
		"gold": int(legacy["gold"]),
		"passive_points_available": int(legacy["passive_points_available"]),
		"passive_points_lifetime_earned": int(legacy["passive_points_lifetime_earned"]),
		"milestones": (legacy["milestones"] as Array).duplicate(true),
		"permanent_feature_unlocks": (legacy["permanent_feature_unlocks"] as Array).duplicate(true),
		"discovered_buildings": (legacy["discovered_buildings"] as Array).duplicate(true),
		"discovered_trees": (legacy["discovered_trees"] as Array).duplicate(true),
		"tree_allocations": (legacy["tree_allocations"] as Dictionary).duplicate(true),
		"tree_visibility_progress": visibility,
		"owned_characters": (legacy["owned_characters"] as Dictionary).duplicate(true),
		"squad_capacity": int(legacy["squad_capacity"]),
		"inventory_columns": int(legacy["inventory_columns"]),
		"item_records": {"schema_version": 1, "items": []},
		"stash_tabs": [],
		"next_item_sequence": 0,
		"extraction_capacity": int(legacy["extraction_capacity"]),
		"run_history": (legacy["run_history"] as Array).duplicate(true),
		"resumable_run": (legacy["resumable_run"] as Dictionary).duplicate(true),
		"applied_transactions": transactions,
	}

static func schema_one_document(
	profile_id: String,
	gold: int,
	updated_at_unix: int,
	include_transaction: bool
) -> Dictionary:
	var document := {
		"schema_version": 1,
		"profile_id": profile_id,
		"display_name": "Legacy Hero",
		"created_at_unix": 1000,
		"updated_at_unix": updated_at_unix,
		"prologue_state": ProfileState.PrologueState.COMPLETED,
		"last_safe_checkpoint": {"arena": "forge", "wave": 4},
		"gold": gold,
		"passive_points_available": 2,
		"passive_points_lifetime_earned": 6,
		"milestones": ["first-win"],
		"permanent_feature_unlocks": ["city-heart", "field-pack"],
		"discovered_buildings": ["forge"],
		"discovered_trees": ["party-forge-city-v1"],
		"tree_allocations": {"party-forge-city-v1": ["city-heart", "field-pack"]},
		"tree_visibility_progress": {"party-forge-city-v1": 3},
		"owned_characters": {"fighter-001": {"class_id": "fighter", "level": 8}},
		"squad_capacity": 3,
		"inventory_columns": 1,
		"stash_tabs": [],
		"extraction_capacity": 2,
		"run_history": [{"outcome": "victory", "seed": 4402}],
		"resumable_run": {"run_id": "run-legacy-01"},
		"applied_transactions": {},
	}
	if include_transaction:
		var snapshot := schema_one_document(profile_id, 55, 1500, false)
		document["applied_transactions"] = {
			"grant-001": {
				"operation": "grant_gold",
				"fingerprint": "a".repeat(64),
				"committed_at_unix": 1500,
				"result_profile": snapshot,
			},
		}
	return document

static func schema_two_document(profile_id: String) -> Dictionary:
	var document := _expected_schema_two_document(schema_one_document(profile_id, 91, 2100, false))
	var sword := _item_document(profile_id, "item-migrate-sword", "forge_vanguard_sword", 0)
	var shield := _item_document(profile_id, "item-migrate-shield", "forge_vanguard_shield", 1)
	document["item_records"] = {"schema_version": 1, "items": [sword, shield]}
	document["stash_tabs"] = [
		ItemSlotContainer.create(&"stash-tab-000", ItemSlotContainer.PROFILE_STASH_TAB, profile_id, 100, {3: sword["instance_id"]}).to_dictionary(),
		ItemSlotContainer.create(&"stash-tab-001", ItemSlotContainer.PROFILE_STASH_TAB, profile_id, 100, {87: shield["instance_id"]}).to_dictionary(),
	]
	document["next_item_sequence"] = 2
	var snapshot := document.duplicate(true)
	snapshot["updated_at_unix"] = 2050
	snapshot["gold"] = 89
	snapshot["applied_transactions"] = {}
	document["applied_transactions"] = {
		"storage-001": {
			"operation": "item_storage_transaction",
			"fingerprint": "b".repeat(64),
			"committed_at_unix": 2050,
			"result_profile": snapshot,
		},
	}
	return document

static func _leader_loadout(profile_id: String) -> Dictionary:
	return {
		"schema_version": 1,
		"container_id": "leader-loadout",
		"container_kind": "profile_leader_equipment",
		"owner_id": profile_id,
		"capacity": 11,
		"slots": {},
	}

static func _item_document(profile_id: String, instance_id: String, base_id: String, sequence: int) -> Dictionary:
	return {
		"affixes": [],
		"base_definition_id": base_id,
		"instance_id": instance_id,
		"item_level": 28,
		"origin": {
			"issuer_namespace": "profile:%s" % profile_id,
			"seed": 4402,
			"sequence": sequence,
			"source": "schema_two_fixture",
		},
		"rarity_id": "common",
		"schema_version": 1,
	}
