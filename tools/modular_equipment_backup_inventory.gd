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
const EXPECTED_SET_ITEM_IDS := {
	"dawn_bulwark": [
		"dawn_bulwark_belt",
		"dawn_bulwark_crown",
		"dawn_bulwark_gauntlets",
		"dawn_bulwark_greaves",
		"dawn_bulwark_plate",
		"dawn_bulwark_sabatons",
		"dawn_bulwark_shield",
		"ring_of_mercy",
		"ring_of_vigil",
		"sun_oath_amulet",
		"sunforged_warhammer",
	],
	"emberweave": [
		"cinder_ring",
		"conflagration_ring",
		"emberheart_amulet",
		"emberweave_circlet",
		"emberweave_flame_focus",
		"emberweave_leggings",
		"emberweave_robe",
		"emberweave_rune_sash",
		"emberweave_shoes",
		"emberweave_spell_gloves",
		"emberweave_wand",
	],
	"forge_vanguard": [
		"forge_vanguard_amulet",
		"forge_vanguard_armour",
		"forge_vanguard_belt",
		"forge_vanguard_boots",
		"forge_vanguard_gauntlets",
		"forge_vanguard_greaves",
		"forge_vanguard_hammer",
		"forge_vanguard_helmet",
		"forge_vanguard_ring_left",
		"forge_vanguard_ring_right",
		"forge_vanguard_shield",
		"forge_vanguard_sword",
	],
	"grave_covenant": [
		"grave_covenant_bone_amulet",
		"grave_covenant_bone_wand",
		"grave_covenant_chained_sash",
		"grave_covenant_grimoire",
		"grave_covenant_hood",
		"grave_covenant_leggings",
		"grave_covenant_ritual_gloves",
		"grave_covenant_robe",
		"grave_covenant_wrapped_boots",
		"pact_ring",
		"withering_ring",
	],
	"greenwood": [
		"greenwood_belt",
		"greenwood_boots",
		"greenwood_gloves",
		"greenwood_hood",
		"greenwood_jerkin",
		"greenwood_leggings",
		"greenwood_light_quiver",
		"greenwood_recurve_bow",
		"hawkeye_band",
		"trailmark_amulet",
		"windrunner_band",
	],
	"nightstep": [
		"bloodstep_ring",
		"nightstep_dagger_main",
		"nightstep_dagger_off",
		"nightstep_grip_gloves",
		"nightstep_hood",
		"nightstep_leathers",
		"nightstep_leggings",
		"nightstep_soft_boots",
		"nightstep_utility_belt",
		"shadowchain_amulet",
		"silent_edge_ring",
	],
	"rime_scholar": [
		"hoarfrost_ring",
		"rime_scholar_boots",
		"rime_scholar_circlet",
		"rime_scholar_crystal_sash",
		"rime_scholar_gloves",
		"rime_scholar_leggings",
		"rime_scholar_robe",
		"rime_scholar_staff",
		"stillwater_ring",
		"winterglass_amulet",
	],
	"siege_archer": [
		"farshot_amulet",
		"long_watch_ring",
		"siege_archer_boots",
		"siege_archer_braced_leggings",
		"siege_archer_coat",
		"siege_archer_cowl",
		"siege_archer_draw_belt",
		"siege_archer_draw_glove",
		"siege_greatbow",
		"siege_heavy_quiver",
		"steady_hand_ring",
	],
	"storm_chaplain": [
		"mercy_ring",
		"storm_chaplain_belt",
		"storm_chaplain_boots",
		"storm_chaplain_holy_tome",
		"storm_chaplain_hood",
		"storm_chaplain_leggings",
		"storm_chaplain_prayer_gloves",
		"storm_chaplain_reliquary",
		"storm_chaplain_sceptre",
		"storm_chaplain_vestments",
		"storm_ring",
	],
}
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
const CONTACT_SHEETS := [
	"assets/ui/equipment/contact_sheets/dawn_bulwark_contact_sheet.png",
	"assets/ui/equipment/contact_sheets/emberweave_contact_sheet.png",
	"assets/ui/equipment/contact_sheets/forge_vanguard_contact_sheet.png",
	"assets/ui/equipment/contact_sheets/grave_covenant_contact_sheet.png",
	"assets/ui/equipment/contact_sheets/greenwood_contact_sheet.png",
	"assets/ui/equipment/contact_sheets/nightstep_contact_sheet.png",
	"assets/ui/equipment/contact_sheets/rime_scholar_contact_sheet.png",
	"assets/ui/equipment/contact_sheets/siege_archer_contact_sheet.png",
	"assets/ui/equipment/contact_sheets/storm_chaplain_contact_sheet.png",
]
const LEGACY_PRESENTATIONS := [
	"data/presentation/equipment/forge_vanguard_amulet.tres",
	"data/presentation/equipment/forge_vanguard_armour.tres",
	"data/presentation/equipment/forge_vanguard_belt.tres",
	"data/presentation/equipment/forge_vanguard_boots.tres",
	"data/presentation/equipment/forge_vanguard_gauntlets.tres",
	"data/presentation/equipment/forge_vanguard_hammer.tres",
	"data/presentation/equipment/forge_vanguard_helmet.tres",
	"data/presentation/equipment/forge_vanguard_ring_left.tres",
	"data/presentation/equipment/forge_vanguard_ring_right.tres",
	"data/presentation/equipment/forge_vanguard_shield.tres",
	"data/presentation/equipment/forge_vanguard_sword.tres",
]
const PRESENTATION_PROFILES := [
	"data/presentation/profiles/cleric.tres",
	"data/presentation/profiles/forge_base_feminine.tres",
	"data/presentation/profiles/forge_base_masculine.tres",
	"data/presentation/profiles/forge_vanguard.tres",
	"data/presentation/profiles/frost_mage.tres",
	"data/presentation/profiles/mage.tres",
	"data/presentation/profiles/marksman.tres",
	"data/presentation/profiles/paladin.tres",
	"data/presentation/profiles/ranger.tres",
	"data/presentation/profiles/rogue.tres",
	"data/presentation/profiles/warlock.tres",
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
	errors.append_array(validate_category_paths(categories))
	errors.append_array(validate_paths(paths, normalized_root))
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


func expected_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	var categories := _expected_categories()
	for category: String in categories:
		paths.append_array(categories[category] as PackedStringArray)
	paths.sort()
	return paths


func validate_category_paths(actual_categories: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var expected_categories := _expected_categories()
	for category: String in expected_categories:
		var expected := expected_categories[category] as PackedStringArray
		var actual := _packed_paths(actual_categories.get(category, PackedStringArray()))
		var actual_set := {}
		for path: String in actual:
			actual_set[path] = true
		var expected_set := {}
		for path: String in expected:
			expected_set[path] = true
			if not actual_set.has(path):
				errors.append("%s category=%s path=%s reason=missing expected path" % [ERROR_PREFIX, category, path])
		for path: String in actual:
			if not expected_set.has(path):
				errors.append("%s category=%s path=%s reason=unexpected path" % [ERROR_PREFIX, category, path])
	var actual_category_names := actual_categories.keys()
	actual_category_names.sort()
	for category_value: Variant in actual_category_names:
		var category := str(category_value)
		if expected_categories.has(category):
			continue
		for path: String in _packed_paths(actual_categories[category_value]):
			errors.append("%s category=%s path=%s reason=unexpected path" % [ERROR_PREFIX, category, path])
	return errors


func validate_paths(paths: PackedStringArray, source_root: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var sorted_paths := paths.duplicate()
	sorted_paths.sort()
	var seen := {}
	for path: String in sorted_paths:
		if not _is_normalized_repo_relative_path(path):
			errors.append("%s path=%s reason=must be normalized and repo-relative" % [ERROR_PREFIX, path])
		if seen.has(path):
			errors.append("%s path=%s reason=duplicate" % [ERROR_PREFIX, path])
		else:
			seen[path] = true
		if path.begins_with("scenes/equipment/test_equipment/") or ".godot" in path.split("/", true) or path.begins_with("docs/qa/"):
			errors.append("%s path=%s reason=excluded" % [ERROR_PREFIX, path])
		if not source_root.is_empty() and not FileAccess.file_exists(source_root.path_join(path)):
			errors.append("%s path=%s reason=missing" % [ERROR_PREFIX, path])
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


func _expected_categories() -> Dictionary:
	var categories := {}
	categories["base_definitions"] = _expected_set_paths("data/equipment/bases", ".tres")
	categories["canonical_presentations"] = _expected_set_paths("data/presentation/equipment", ".tres")
	categories["contact_sheets"] = PackedStringArray(CONTACT_SHEETS)
	categories["contract_scripts"] = PackedStringArray(CONTRACT_SCRIPTS)
	categories["equipment_scenes"] = _expected_set_paths("scenes/equipment", ".tscn")
	categories["legacy_presentations"] = PackedStringArray(LEGACY_PRESENTATIONS)
	categories["master_icons"] = _expected_set_paths("assets/ui/equipment/master", "_256.png")
	categories["presentation_profiles"] = PackedStringArray(PRESENTATION_PROFILES)
	categories["runtime_icons"] = _expected_set_paths("assets/ui/equipment/runtime", "_128.png")
	categories["shared_character_scenes"] = PackedStringArray(SHARED_CHARACTER_SCENES)
	return categories


func _expected_set_paths(relative_parent: String, suffix: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for set_id: String in SET_IDS:
		for item_id: String in EXPECTED_SET_ITEM_IDS[set_id]:
			paths.append(relative_parent.path_join(set_id).path_join(item_id + suffix))
	paths.sort()
	return paths


func _packed_paths(value: Variant) -> PackedStringArray:
	var paths := PackedStringArray()
	if value is PackedStringArray or value is Array:
		for path_value: Variant in value:
			paths.append(str(path_value))
	paths.sort()
	return paths


func _is_normalized_repo_relative_path(path: String) -> bool:
	if path.is_empty() or path.is_absolute_path() or path.begins_with("res://") or "\\" in path:
		return false
	var segments := path.split("/", true)
	return not segments.has("") and not segments.has(".") and not segments.has("..")
