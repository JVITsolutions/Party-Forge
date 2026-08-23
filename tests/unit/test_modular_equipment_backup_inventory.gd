extends RefCounted

const INVENTORY_PATH := "res://tools/modular_equipment_backup_inventory.gd"
const EXPECTED_CATEGORY_COUNTS := {
	"base_definitions": 99,
	"canonical_presentations": 99,
	"contact_sheets": 9,
	"contract_scripts": 5,
	"equipment_scenes": 99,
	"legacy_presentations": 11,
	"master_icons": 99,
	"presentation_profiles": 11,
	"runtime_icons": 99,
	"shared_character_scenes": 3,
}
const EXPECTED_SHARED_SCENES := [
	"scenes/characters/presentation/forge_base_feminine.tscn",
	"scenes/characters/presentation/forge_base_masculine.tscn",
	"scenes/characters/presentation/forge_humanoid_model.tscn",
]
const EXPECTED_TOTAL_PATHS := 534


func run() -> Array[String]:
	var failures: Array[String] = []
	if not FileAccess.file_exists(ProjectSettings.globalize_path(INVENTORY_PATH)):
		failures.append("inventory implementation exists: expected %s" % INVENTORY_PATH)
		return failures

	var inventory_script := load(INVENTORY_PATH) as Script
	TestAssertions.truthy(inventory_script != null, "inventory implementation loads", failures)
	if inventory_script == null:
		return failures
	var inventory := inventory_script.new() as RefCounted
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var result: Dictionary = inventory.call(&"build", project_root)
	var categories := result.get("categories", {}) as Dictionary
	var paths := result.get("paths", PackedStringArray()) as PackedStringArray
	var errors := result.get("errors", PackedStringArray()) as PackedStringArray

	TestAssertions.equal(errors, PackedStringArray(), "current legacy inventory has no drift", failures)
	TestAssertions.equal(categories.keys(), EXPECTED_CATEGORY_COUNTS.keys(), "inventory category names are exact and sorted", failures)
	for category: String in EXPECTED_CATEGORY_COUNTS:
		var category_paths := categories.get(category, PackedStringArray()) as PackedStringArray
		TestAssertions.equal(category_paths.size(), EXPECTED_CATEGORY_COUNTS[category], "%s count is locked" % category, failures)
		_assert_sorted(category_paths, "%s paths are sorted" % category, failures)

	TestAssertions.equal(
		(categories.get("canonical_presentations", PackedStringArray()) as PackedStringArray).size()
			+ (categories.get("legacy_presentations", PackedStringArray()) as PackedStringArray).size(),
		110,
		"canonical and tracked top-level legacy presentation resources total 110",
		failures,
	)
	TestAssertions.equal(categories.get("shared_character_scenes", PackedStringArray()), PackedStringArray(EXPECTED_SHARED_SCENES), "shared rig and body scenes are exact", failures)
	TestAssertions.equal(paths.size(), EXPECTED_TOTAL_PATHS, "complete inventory count is locked", failures)
	_assert_sorted(paths, "complete inventory paths are sorted ordinally", failures)
	_assert_path_contract(paths, project_root, failures)

	var repeated: Dictionary = inventory.call(&"build", project_root)
	TestAssertions.equal(repeated, result, "inventory discovery is deterministic", failures)
	var drifted_counts := EXPECTED_CATEGORY_COUNTS.duplicate()
	drifted_counts["equipment_scenes"] = 98
	var drift_errors := inventory.call(&"validate_category_counts", drifted_counts) as PackedStringArray
	TestAssertions.equal(
		drift_errors,
		PackedStringArray(["PARTY_FORGE_MODULAR_BACKUP_INVENTORY_ERROR category=equipment_scenes expected=99 actual=98"]),
		"category count drift fails closed",
		failures,
	)
	return failures


func _assert_sorted(paths: PackedStringArray, label: String, failures: Array[String]) -> void:
	var sorted_paths := paths.duplicate()
	sorted_paths.sort()
	TestAssertions.equal(paths, sorted_paths, label, failures)


func _assert_path_contract(paths: PackedStringArray, project_root: String, failures: Array[String]) -> void:
	var seen := {}
	for path: String in paths:
		TestAssertions.truthy(not path.is_empty(), "inventory path is non-empty", failures)
		TestAssertions.truthy(not path.is_absolute_path() and not path.begins_with("res://"), "%s is repo-relative" % path, failures)
		TestAssertions.truthy("\\" not in path and "/../" not in "/%s/" % path, "%s is normalized" % path, failures)
		TestAssertions.truthy(not seen.has(path), "%s appears once" % path, failures)
		seen[path] = true
		TestAssertions.truthy(FileAccess.file_exists(project_root.path_join(path)), "%s exists" % path, failures)
		TestAssertions.truthy(not path.begins_with("scenes/equipment/test_equipment/"), "%s excludes the user experiment" % path, failures)
		TestAssertions.truthy(".godot" not in path.split("/", false), "%s excludes Godot cache files" % path, failures)
		TestAssertions.truthy(not path.begins_with("docs/qa/"), "%s excludes generated QA captures" % path, failures)
		TestAssertions.truthy(_is_allowed_inventory_path(path), "%s excludes unrelated gameplay files" % path, failures)


func _is_allowed_inventory_path(path: String) -> bool:
	return (
		path.begins_with("assets/ui/equipment/")
		or path.begins_with("data/equipment/bases/")
		or path.begins_with("data/presentation/equipment/")
		or path.begins_with("data/presentation/profiles/")
		or path.begins_with("scenes/equipment/")
		or path in EXPECTED_SHARED_SCENES
		or path in PackedStringArray([
			"scripts/equipment/equipment_base_definition.gd",
			"scripts/equipment/equipment_loadout_entry.gd",
			"scripts/presentation/character_visual_profile.gd",
			"scripts/presentation/equipment_visual_definition.gd",
			"scripts/presentation/forge_humanoid_model.gd",
		])
	)
