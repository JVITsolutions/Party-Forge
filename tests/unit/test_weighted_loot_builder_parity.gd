extends RefCounted

const BUILDER_PATH := "res://tools/build_weighted_loot_content.gd"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const STATS_PATH := "res://data/stats/core_stats.tres"
const DAMAGE_TYPES_PATH := "res://data/damage_types/core_damage_types.tres"
const ROWS_PATH := "res://tools/weighted_loot_content_rows.gd"
const EXPECTED_DOCUMENT_COUNT := 306

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(BUILDER_PATH), "weighted loot production builder exists", failures)
	if not ResourceLoader.exists(BUILDER_PATH):
		return failures
	var builder := load(BUILDER_PATH) as Script
	var rows := load(ROWS_PATH) as Script
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var stats := load(STATS_PATH) as StatCatalog
	var damage_types := load(DAMAGE_TYPES_PATH) as DamageTypeCatalog
	TestAssertions.truthy(builder != null, "weighted loot production builder loads", failures)
	TestAssertions.truthy(rows != null, "weighted loot source rows load for parity", failures)
	TestAssertions.truthy(equipment != null and stats != null and damage_types != null, "builder input catalogs load", failures)
	if builder == null or rows == null or equipment == null or stats == null or damage_types == null:
		return failures

	var first_variant: Variant = builder.call(&"build_document_set", equipment, stats, damage_types)
	var second_variant: Variant = builder.call(&"build_document_set", equipment, stats, damage_types)
	TestAssertions.truthy(first_variant is Dictionary, "builder returns a canonical document dictionary", failures)
	TestAssertions.equal(first_variant, second_variant, "repeated in-memory builds are byte-identical", failures)
	if not first_variant is Dictionary:
		return failures
	var documents := first_variant as Dictionary
	var expected_paths := _expected_paths(rows, equipment)
	var document_paths: Array[String] = []
	for path_variant: Variant in documents.keys():
		document_paths.append(String(path_variant))
	TestAssertions.equal(documents.size(), EXPECTED_DOCUMENT_COUNT, "exact generated document count", failures)
	TestAssertions.equal(document_paths, expected_paths, "documents use exact sorted canonical path order", failures)
	for path: String in expected_paths:
		TestAssertions.truthy(documents.has(path), "%s has a canonical generated document" % path, failures)
		if not documents.has(path):
			continue
		var document: Variant = documents[path]
		TestAssertions.truthy(document is String, "%s canonical document is text" % path, failures)
		if not document is String:
			continue
		TestAssertions.truthy(FileAccess.file_exists(path), "%s checked-in resource exists" % path, failures)
		if FileAccess.file_exists(path):
			var checked_in := FileAccess.get_file_as_string(path)
			TestAssertions.equal(checked_in.to_utf8_buffer(), String(document).to_utf8_buffer(), "%s checked-in bytes equal canonical generation" % path, failures)
	return failures

func _expected_paths(rows: Script, equipment: EquipmentCatalog) -> Array[String]:
	var result: Array[String] = [FOUNDATION_PATH]
	for row_variant: Variant in rows.call(&"explicit_rows"):
		result.append(String((row_variant as Dictionary)["output_path"]))
	for row_variant: Variant in rows.call(&"implicit_rows", equipment):
		var path := String((row_variant as Dictionary)["output_path"])
		if path not in result:
			result.append(path)
	for row_variant: Variant in rows.call(&"weapon_profile_rows"):
		result.append(String((row_variant as Dictionary)["output_path"]))
	for base: EquipmentBaseDefinition in equipment.definitions:
		result.append(base.resource_path)
	result.sort()
	return result
