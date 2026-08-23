class_name ModularEquipmentBackupInventory
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_MODULAR_BACKUP_INVENTORY_ERROR"
const SET_IDS := [
	"dawn_bulwark",
	"emberweave",
	"forge_vanguard",
	"grave_covenant",
	"greenwood",
	"nightstep",
	"rime_scholar",
	"siege_archer",
	"storm_chaplain",
]
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
const SHARED_CHARACTER_SCENES := [
	"scenes/characters/presentation/forge_base_feminine.tscn",
	"scenes/characters/presentation/forge_base_masculine.tscn",
	"scenes/characters/presentation/forge_humanoid_model.tscn",
]
const CONTRACT_SCRIPTS := [
	"scripts/equipment/equipment_base_definition.gd",
	"scripts/equipment/equipment_loadout_entry.gd",
	"scripts/presentation/character_visual_profile.gd",
	"scripts/presentation/equipment_visual_definition.gd",
	"scripts/presentation/forge_humanoid_model.gd",
]


func build(source_root: String) -> Dictionary:
	var normalized_root := source_root.replace("\\", "/").trim_suffix("/")
	var categories := {}
	categories["base_definitions"] = _discover_set_files(normalized_root, "data/equipment/bases", ".tres")
	categories["canonical_presentations"] = _discover_set_files(normalized_root, "data/presentation/equipment", ".tres")
	categories["contact_sheets"] = _discover_matching_files(normalized_root, "assets/ui/equipment/contact_sheets", "", "_contact_sheet.png")
	categories["contract_scripts"] = PackedStringArray(CONTRACT_SCRIPTS)
	categories["equipment_scenes"] = _discover_set_files(normalized_root, "scenes/equipment", ".tscn")
	categories["legacy_presentations"] = _discover_matching_files(normalized_root, "data/presentation/equipment", "forge_vanguard_", ".tres")
	categories["master_icons"] = _discover_set_files(normalized_root, "assets/ui/equipment/master", ".png")
	categories["presentation_profiles"] = _discover_matching_files(normalized_root, "data/presentation/profiles", "", ".tres")
	categories["runtime_icons"] = _discover_set_files(normalized_root, "assets/ui/equipment/runtime", ".png")
	categories["shared_character_scenes"] = PackedStringArray(SHARED_CHARACTER_SCENES)

	var paths := PackedStringArray()
	for category: String in categories:
		paths.append_array(categories[category] as PackedStringArray)
	paths.sort()

	var errors := PackedStringArray()
	if normalized_root.is_empty() or not normalized_root.is_absolute_path():
		errors.append("%s field=source_root reason=must be absolute" % ERROR_PREFIX)
	errors.append_array(validate_category_counts(_category_counts(categories)))
	errors.append_array(_validate_paths(paths, normalized_root))
	return {
		"categories": categories,
		"paths": paths,
		"errors": errors,
	}


func validate_category_counts(actual_counts: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for category: String in EXPECTED_CATEGORY_COUNTS:
		var expected: int = EXPECTED_CATEGORY_COUNTS[category]
		var actual := int(actual_counts.get(category, -1))
		if actual != expected:
			errors.append("%s category=%s expected=%d actual=%d" % [ERROR_PREFIX, category, expected, actual])
	var actual_categories := actual_counts.keys()
	actual_categories.sort()
	for category_value: Variant in actual_categories:
		var category := str(category_value)
		if not EXPECTED_CATEGORY_COUNTS.has(category):
			errors.append("%s category=%s reason=unexpected" % [ERROR_PREFIX, category])
	return errors


func _discover_set_files(source_root: String, relative_parent: String, suffix: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for set_id: String in SET_IDS:
		paths.append_array(_discover_matching_files(source_root, relative_parent.path_join(set_id), "", suffix))
	paths.sort()
	return paths


func _discover_matching_files(source_root: String, relative_directory: String, prefix: String, suffix: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var absolute_directory := source_root.path_join(relative_directory)
	if not DirAccess.dir_exists_absolute(absolute_directory):
		return paths
	for file_name: String in DirAccess.get_files_at(absolute_directory):
		if file_name.begins_with(prefix) and file_name.ends_with(suffix):
			paths.append(relative_directory.path_join(file_name).replace("\\", "/"))
	paths.sort()
	return paths


func _category_counts(categories: Dictionary) -> Dictionary:
	var counts := {}
	for category: String in categories:
		counts[category] = (categories[category] as PackedStringArray).size()
	return counts


func _validate_paths(paths: PackedStringArray, source_root: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for path: String in paths:
		if path.is_empty() or path.is_absolute_path() or path.begins_with("res://") or "\\" in path or "/../" in "/%s/" % path:
			errors.append("%s path=%s reason=must be normalized and repo-relative" % [ERROR_PREFIX, path])
		if seen.has(path):
			errors.append("%s path=%s reason=duplicate" % [ERROR_PREFIX, path])
		else:
			seen[path] = true
		if path.begins_with("scenes/equipment/test_equipment/") or ".godot" in path.split("/", false) or path.begins_with("docs/qa/"):
			errors.append("%s path=%s reason=excluded" % [ERROR_PREFIX, path])
		if not source_root.is_empty() and not FileAccess.file_exists(source_root.path_join(path)):
			errors.append("%s path=%s reason=missing" % [ERROR_PREFIX, path])
	return errors
