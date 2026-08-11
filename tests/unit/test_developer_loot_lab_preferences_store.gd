extends RefCounted

const EXPECTED_FIELDS: Array[String] = [
	"batch_preset",
	"charisma_value",
	"custom_batch_count",
	"difficulty_id",
	"excluded_affix_tags",
	"excluded_base_tags",
	"forced_base_id",
	"forced_rarity_id",
	"generation_domain",
	"generation_sequence",
	"heat",
	"item_level",
	"party_archetype_tags",
	"permitted_rarity_ids",
	"required_affix_tags",
	"required_base_tags",
	"schema_version",
	"seed",
	"source_id",
	"unlock_tags",
]

var _path := ""

func run() -> Array[String]:
	var failures: Array[String] = []
	_path = "user://developer_item_sandbox/test-loot-lab-preferences-%d.json" % OS.get_process_id()
	_cleanup()
	_test_defaults_and_exact_schema(failures)
	_test_canonical_save_and_load(failures)
	_test_validation_boundaries(failures)
	_test_backup_recovery(failures)
	_test_atomic_failure_preserves_generation(failures)
	_cleanup()
	return failures

func _test_defaults_and_exact_schema(failures: Array[String]) -> void:
	var store := DeveloperLootLabPreferencesStore.new(AtomicJsonStore.new(), _path)
	var document := store.defaults()
	TestAssertions.equal(_sorted_keys(document), EXPECTED_FIELDS, "preferences expose the exact schema-one field set", failures)
	TestAssertions.truthy(not document.has("report"), "preferences cannot persist a report", failures)
	TestAssertions.truthy(not document.has("samples"), "preferences cannot persist samples", failures)
	TestAssertions.truthy(not document.has("items"), "preferences cannot persist generated items", failures)
	TestAssertions.truthy(not document.has("runtime"), "preferences cannot persist runtime state", failures)
	TestAssertions.equal(store.validate(document), "", "default request preferences validate", failures)
	var missing := store.load()
	TestAssertions.truthy(missing.missing and not missing.ok(), "missing preferences remain distinguishable from defaults", failures)

func _test_canonical_save_and_load(failures: Array[String]) -> void:
	_cleanup()
	var store := DeveloperLootLabPreferencesStore.new(AtomicJsonStore.new(), _path)
	var document := store.defaults()
	document["seed"] = 90210
	document["generation_sequence"] = 700
	document["item_level"] = 80
	document["source_id"] = "ordinary_enemy"
	document["generation_domain"] = "ordinary_drop"
	document["permitted_rarity_ids"] = ["rare", "common"]
	document["party_archetype_tags"] = ["ranged", "melee"]
	document["batch_preset"] = 1000
	document["custom_batch_count"] = 4321
	TestAssertions.equal(store.save(document), "", "valid preferences save atomically", failures)
	var loaded := store.load()
	TestAssertions.truthy(loaded.ok(), "saved preferences reload", failures)
	if loaded.ok():
		TestAssertions.equal(loaded.document["permitted_rarity_ids"], ["common", "rare"], "rarity IDs persist in canonical order", failures)
		TestAssertions.equal(loaded.document["party_archetype_tags"], ["melee", "ranged"], "archetype tags persist in canonical order", failures)
		TestAssertions.equal(_sorted_keys(loaded.document), EXPECTED_FIELDS, "saved preferences retain only exact schema fields", failures)
	TestAssertions.equal(document["permitted_rarity_ids"], ["rare", "common"], "saving does not mutate the caller document", failures)

func _test_validation_boundaries(failures: Array[String]) -> void:
	_cleanup()
	var store := DeveloperLootLabPreferencesStore.new(AtomicJsonStore.new(), _path)
	var valid := store.defaults()
	for forbidden: String in ["report", "samples", "items", "runtime"]:
		var extra := valid.duplicate(true)
		extra[forbidden] = {}
		TestAssertions.truthy(not store.validate(extra).is_empty(), "unknown %s field is rejected" % forbidden, failures)

	var bad_level := valid.duplicate(true)
	bad_level["item_level"] = 0
	TestAssertions.truthy(store.validate(bad_level).contains("item_level"), "item level below production range is rejected", failures)
	var bad_sequence := valid.duplicate(true)
	bad_sequence["generation_sequence"] = -1
	TestAssertions.truthy(store.validate(bad_sequence).contains("generation_sequence"), "negative generation sequence is rejected", failures)
	var bad_batch := valid.duplicate(true)
	bad_batch["custom_batch_count"] = 100001
	TestAssertions.truthy(store.validate(bad_batch).contains("custom_batch_count"), "custom batch above hard cap is rejected", failures)
	var bad_preset := valid.duplicate(true)
	bad_preset["batch_preset"] = 17
	TestAssertions.truthy(store.validate(bad_preset).contains("batch_preset"), "unsupported batch preset is rejected", failures)
	var duplicate_names := valid.duplicate(true)
	duplicate_names["permitted_rarity_ids"] = ["common", "common"]
	TestAssertions.truthy(store.validate(duplicate_names).contains("permitted_rarity_ids"), "duplicate names are rejected", failures)
	var unsafe_json := valid.duplicate(true)
	unsafe_json["seed"] = ItemInstanceCodec.JSON_SAFE_INTEGER_MAX + 1
	TestAssertions.truthy(not store.save(unsafe_json).is_empty(), "JSON-unsafe values are rejected before persistence", failures)
	TestAssertions.truthy(not FileAccess.file_exists(_path), "validation failure creates no primary generation", failures)

func _test_backup_recovery(failures: Array[String]) -> void:
	_cleanup()
	var store := DeveloperLootLabPreferencesStore.new(AtomicJsonStore.new(), _path)
	var first := store.defaults()
	first["seed"] = 11
	var second := store.defaults()
	second["seed"] = 22
	TestAssertions.equal(store.save(first), "", "backup fixture first save succeeds", failures)
	TestAssertions.equal(store.save(second), "", "backup fixture second save succeeds", failures)
	_write_text(_path, "corrupt primary")
	var recovered := store.load()
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "corrupt primary recovers the verified backup", failures)
	TestAssertions.equal(int(recovered.document.get("seed", -1)), 11, "backup recovery exposes the prior valid preferences", failures)
	_write_text("%s.bak" % _path, "corrupt backup")
	var failed := store.load()
	TestAssertions.truthy(not failed.ok() and failed.error.contains("primary=") and failed.error.contains("backup="), "corrupt primary and backup produce an explicit load failure", failures)

func _test_atomic_failure_preserves_generation(failures: Array[String]) -> void:
	_cleanup()
	var healthy := DeveloperLootLabPreferencesStore.new(AtomicJsonStore.new(), _path)
	var original := healthy.defaults()
	original["seed"] = 31
	TestAssertions.equal(healthy.save(original), "", "atomic failure fixture saves a valid generation", failures)
	var before := FileAccess.get_file_as_bytes(_path)
	var failing_atomic := AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE)
	var failing := DeveloperLootLabPreferencesStore.new(failing_atomic, _path)
	var replacement := healthy.defaults()
	replacement["seed"] = 32
	var error := failing.save(replacement)
	TestAssertions.truthy(error.contains("stage=promote"), "injected promotion failure is reported", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(_path), before, "failed promotion preserves exact primary bytes", failures)
	var reloaded := healthy.load()
	TestAssertions.truthy(reloaded.ok(), "previous generation remains loadable after failed promotion", failures)
	TestAssertions.equal(int(reloaded.document.get("seed", -1)), 31, "failed promotion does not publish replacement preferences", failures)

func _sorted_keys(document: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in document:
		result.append(String(key))
	result.sort()
	return result

func _write_text(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(contents)
		file.close()

func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.previous"]:
		var candidate := "%s%s" % [_path, suffix]
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
