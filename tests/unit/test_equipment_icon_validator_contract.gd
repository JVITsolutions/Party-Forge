extends RefCounted

const POLICY_PATH := "res://tools/equipment_icon_validation_policy.gd"
const CATALOG := preload("res://data/equipment/core_equipment_catalog.tres")
const CANONICAL_FOLDERS := {
	&"fighter": &"forge_vanguard", &"paladin": &"dawn_bulwark", &"ranger": &"greenwood",
	&"marksman": &"siege_archer", &"rogue": &"nightstep", &"mage": &"emberweave",
	&"frost_mage": &"rime_scholar", &"cleric": &"storm_chaplain", &"warlock": &"grave_covenant",
}

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(POLICY_PATH), "pure equipment icon validation policy exists", failures)
	if not ResourceLoader.exists(POLICY_PATH):
		return failures
	var policy_script := load(POLICY_PATH) as Script
	TestAssertions.truthy(policy_script != null, "pure equipment icon validation policy loads", failures)
	if policy_script == null:
		return failures
	var policy := policy_script.new() as RefCounted
	_assert_registry_and_catalog_policy(policy, failures)
	_assert_cli_policy(policy, failures)
	_assert_geometry_policy(policy, failures)
	_assert_validator_wiring(failures)
	return failures

func _assert_registry_and_catalog_policy(policy: RefCounted, failures: Array[String]) -> void:
	var folders: Dictionary = CANONICAL_FOLDERS.duplicate(true)
	var manifest := ClassEquipmentRows.SET_ITEM_IDS.duplicate(true)
	var valid := policy.call(&"validate_registries_and_catalog", folders, manifest, _catalog_copy()) as Dictionary
	TestAssertions.equal(String(valid.get("error", "missing")), "", "canonical registries and catalog validate", failures)
	TestAssertions.equal(valid.get("complete_count", -1), 99, "canonical complete count is catalog-wide", failures)
	TestAssertions.equal(valid.get("registered_sets", []), [&"cleric", &"fighter", &"frost_mage", &"mage", &"marksman", &"paladin", &"ranger", &"rogue", &"warlock"], "registered sets are deterministic", failures)

	var missing_manifest := manifest.duplicate(true)
	missing_manifest.erase(&"fighter")
	_assert_policy_error(policy, folders, missing_manifest, _catalog_copy(), "missing manifest", "folder-to-manifest drift is rejected", failures)
	var missing_folder := folders.duplicate(true)
	missing_folder.erase(&"fighter")
	_assert_policy_error(policy, missing_folder, manifest, _catalog_copy(), "missing folder mapping", "manifest-to-folder drift is rejected", failures)

	var duplicate_manifest := manifest.duplicate(true)
	(duplicate_manifest[&"paladin"] as Array).append((duplicate_manifest[&"fighter"] as Array)[0])
	_assert_policy_error(policy, folders, duplicate_manifest, _catalog_copy(), "duplicate manifest id=forge_vanguard_helmet", "duplicate manifest occurrence is rejected globally", failures)
	var manifest_only := manifest.duplicate(true)
	(manifest_only[&"fighter"] as Array).append(&"manifest_only_item")
	_assert_policy_error(policy, folders, manifest_only, _catalog_copy(), "manifest id=manifest_only_item missing catalog definition", "manifest-only ID is rejected", failures)
	var catalog_only := manifest.duplicate(true)
	(catalog_only[&"fighter"] as Array).erase(&"forge_vanguard_helmet")
	_assert_policy_error(policy, folders, catalog_only, _catalog_copy(), "catalog id=forge_vanguard_helmet missing manifest occurrence", "catalog-only ID is rejected", failures)

	var invalid_catalog := _catalog_copy()
	var invalid_definition := invalid_catalog.definitions[0].duplicate(true) as EquipmentBaseDefinition
	invalid_definition.display_name = ""
	invalid_catalog.definitions[0] = invalid_definition
	_assert_policy_error(policy, folders, manifest, invalid_catalog, "catalog validation failed", "catalog validate error is rejected", failures)
	var null_catalog := _catalog_copy()
	null_catalog.definitions.append(null)
	_assert_policy_error(policy, folders, manifest, null_catalog, "null catalog definition", "null catalog definition is rejected", failures)
	var empty_catalog := _catalog_copy()
	empty_catalog.definitions.append(EquipmentBaseDefinition.new())
	_assert_policy_error(policy, folders, manifest, empty_catalog, "empty catalog id", "empty catalog ID is rejected", failures)
	var duplicate_catalog := _catalog_copy()
	duplicate_catalog.definitions.append(duplicate_catalog.definitions[0])
	_assert_policy_error(policy, folders, manifest, duplicate_catalog, "duplicate catalog id=", "duplicate catalog ID is rejected", failures)

func _assert_cli_policy(policy: RefCounted, failures: Array[String]) -> void:
	var registered: Array[StringName] = [&"cleric", &"fighter", &"frost_mage", &"mage", &"marksman", &"paladin", &"ranger", &"rogue", &"warlock"]
	_assert_requested_sets(policy, [], registered, [&"fighter"], "default request remains Fighter", failures)
	_assert_requested_sets(policy, ["--sets= all "], registered, registered, "trimmed exact all returns every sorted set", failures)
	_assert_requested_sets(policy, ["--sets=rogue,fighter"], registered, [&"rogue", &"fighter"], "valid subset preserves explicit order", failures)
	var invalid_cases := {
		"all,unknown": ["--sets=all,unknown"],
		"fighter,all": ["--sets=fighter,all"],
		"duplicate sets": ["--sets=fighter,fighter"],
		"empty token": ["--sets=fighter,,rogue"],
		"unknown set": ["--sets=fighter,unknown"],
		"multiple --sets arguments": ["--sets=fighter", "--sets=rogue"],
	}
	for label: String in invalid_cases:
		var result := policy.call(&"requested_sets", invalid_cases[label], registered) as Dictionary
		TestAssertions.truthy(not String(result.get("error", "")).is_empty(), "%s is rejected" % label, failures)
		TestAssertions.equal(result.get("sets", []), [], "%s returns no requested sets" % label, failures)

func _assert_geometry_policy(policy: RefCounted, failures: Array[String]) -> void:
	TestAssertions.equal(String(policy.call(&"image_error", _padded_image(256, 16), 256, &"padded_master", "master")), "", "padded 256px master is accepted", failures)
	TestAssertions.equal(String(policy.call(&"image_error", _padded_image(128, 8), 128, &"padded_runtime", "runtime")), "", "padded 128px runtime icon is accepted", failures)
	var master_error := String(policy.call(&"image_error", _padded_image(256, 15), 256, &"edge_master", "master"))
	TestAssertions.truthy("item=edge_master" in master_error and "kind=master" in master_error and "size=256" in master_error and "padding" in master_error, "edge-touching 256px master reports item kind size and padding", failures)
	var runtime_error := String(policy.call(&"image_error", _padded_image(128, 7), 128, &"edge_runtime", "runtime"))
	TestAssertions.truthy("item=edge_runtime" in runtime_error and "kind=runtime" in runtime_error and "size=128" in runtime_error and "padding" in runtime_error, "edge-touching 128px runtime reports item kind size and padding", failures)

func _assert_validator_wiring(failures: Array[String]) -> void:
	var rows_script := load("res://tools/class_equipment_rows.gd") as Script
	TestAssertions.equal((rows_script.get_script_constant_map() as Dictionary).get("SET_FOLDERS", {}), CANONICAL_FOLDERS, "class equipment rows owns the canonical folder registry", failures)
	var validator_source := FileAccess.get_file_as_string("res://tools/validate_equipment_icons.gd")
	var asset_test_source := FileAccess.get_file_as_string("res://tests/unit/test_equipment_icons.gd")
	TestAssertions.truthy("equipment_icon_validation_policy.gd" in validator_source and "validate_registries_and_catalog" in validator_source and "image_error" in validator_source, "standalone validator calls the pure policy", failures)
	TestAssertions.truthy("equipment_icon_validation_policy.gd" in asset_test_source and "image_error" in asset_test_source, "asset tests call the shared geometry policy", failures)
	for path: String in ["res://tools/render_equipment_icons.gd", "res://tools/validate_equipment_icons.gd", "res://tools/build_equipment_contact_sheets.gd", "res://tests/unit/test_equipment_icons.gd"]:
		var source := FileAccess.get_file_as_string(path)
		TestAssertions.truthy("ClassEquipmentRows.SET_FOLDERS" in source and "const SET_FOLDERS" not in source, "%s consumes only the canonical folder registry" % path, failures)

func _assert_policy_error(policy: RefCounted, folders: Dictionary, manifest: Dictionary, catalog: EquipmentCatalog, fragment: String, label: String, failures: Array[String]) -> void:
	var result := policy.call(&"validate_registries_and_catalog", folders, manifest, catalog) as Dictionary
	TestAssertions.truthy(fragment in String(result.get("error", "")), label, failures)

func _assert_requested_sets(policy: RefCounted, args: Array, registered: Array[StringName], expected: Array, label: String, failures: Array[String]) -> void:
	var result := policy.call(&"requested_sets", args, registered) as Dictionary
	TestAssertions.equal(String(result.get("error", "missing")), "", "%s has no error" % label, failures)
	TestAssertions.equal(result.get("sets", []), expected, label, failures)

func _catalog_copy() -> EquipmentCatalog:
	var catalog := EquipmentCatalog.new()
	catalog.definitions = CATALOG.definitions.duplicate()
	return catalog

func _padded_image(size: int, padding: int) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(padding, padding, size - padding * 2, size - padding * 2), Color.WHITE)
	return image
