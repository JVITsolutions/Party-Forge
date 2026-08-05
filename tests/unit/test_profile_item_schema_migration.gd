extends RefCounted

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
	TestAssertions.equal(migrated_profile.schema_version if migrated_profile != null else -1, 2, "profile migrates to schema two", failures)
	TestAssertions.equal(migrated_profile.gold if migrated_profile != null else -1, 77, "gold survives migration", failures)
	TestAssertions.equal(migrated_profile.tree_allocations if migrated_profile != null else {}, original["tree_allocations"], "allocations survive migration", failures)
	TestAssertions.equal(migrated_profile.get("item_records") if migrated_profile != null else {}, {"schema_version": 1, "items": []}, "migration invents no items", failures)
	TestAssertions.equal(migrated_profile.stash_tabs if migrated_profile != null else [{}], [], "migration invents no stash", failures)
	TestAssertions.equal(migrated_profile.get("next_item_sequence") if migrated_profile != null else -1, 0, "issuance starts empty", failures)
	TestAssertions.truthy(bool(migrated.get("migrated")) and int(migrated.get("source_schema_version")) == 1, "migration reports schema-one source", failures)
	if migrated_profile != null:
		var nested := (migrated_profile.applied_transactions["grant-001"] as Dictionary)["result_profile"] as Dictionary
		TestAssertions.equal(nested["schema_version"], 2, "nested result snapshot migrates to schema two", failures)
		TestAssertions.equal(nested["item_records"], {"schema_version": 1, "items": []}, "nested migration invents no items", failures)
		TestAssertions.equal(nested["stash_tabs"], [], "nested migration invents no stash", failures)
		TestAssertions.equal(nested["next_item_sequence"], 0, "nested issuance starts empty", failures)
		TestAssertions.equal(nested["gold"], 55, "nested result values survive migration", failures)
	TestAssertions.equal(original, before, "migration leaves source dictionary unchanged", failures)
	TestAssertions.equal(JSON.stringify(original, "\t", false), before_text, "migration leaves source serialization byte-equivalent", failures)

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
	TestAssertions.equal(decoded.source_schema_version, 2, "current profile reports schema-two source", failures)

func _test_normal_store_is_current_only(failures: Array[String]) -> void:
	var root := "user://tests/profile_schema_store_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(root)
	var store := ProfileStore.new()
	var current := ProfileState.new_profile("profile-current03", "Current", 3000)
	TestAssertions.equal(store.save_profile(current, root), "", "normal store saves current schema", failures)
	var current_bytes := FileAccess.get_file_as_bytes(store.profile_path(current.profile_id, root))
	var loaded := store.load_profile(current.profile_id, root)
	TestAssertions.truthy(loaded.ok() and not loaded.migrated, "ordinary current store load is not migrated", failures)
	TestAssertions.equal(loaded.source_schema_version, 2, "ordinary current store load reports schema-two source", failures)
	var legacy_typed_state := current.copy()
	legacy_typed_state.schema_version = 1
	var save_error := store.save_profile(legacy_typed_state, root)
	TestAssertions.truthy(not save_error.is_empty() and save_error.contains("unsupported schema"), "normal store rejects a schema-one typed state", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(store.profile_path(current.profile_id, root)), current_bytes, "rejected legacy normal save preserves current bytes", failures)
	ProfileTestSupport.remove_tree(root)

func _migrate(document: Dictionary) -> Variant:
	var migrator_script := load("res://scripts/profile/profile_migrator.gd") as Script
	return migrator_script.call("migrate_document", document)

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
