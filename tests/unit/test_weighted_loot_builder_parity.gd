extends RefCounted

const BUILDER_PATH := "res://tools/build_weighted_loot_content.gd"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const STATS_PATH := "res://data/stats/core_stats.tres"
const DAMAGE_TYPES_PATH := "res://data/damage_types/core_damage_types.tres"
const ROWS_PATH := "res://tools/weighted_loot_content_rows.gd"
const CLASS_ROWS := preload("res://tools/class_equipment_rows.gd")
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
	var expected_paths := _expected_paths(rows)
	var document_paths: Array[String] = []
	for path_variant: Variant in documents.keys():
		document_paths.append(String(path_variant))
	TestAssertions.equal(documents.size(), EXPECTED_DOCUMENT_COUNT, "exact generated document count", failures)
	TestAssertions.equal(document_paths, expected_paths, "documents use exact sorted canonical path order", failures)
	TestAssertions.equal(_builder_owned_disk_paths(), expected_paths, "builder-owned on-disk tres paths exactly match the canonical manifest", failures)
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
			TestAssertions.equal(FileAccess.get_file_as_bytes(path), String(document).to_utf8_buffer(), "%s checked-in bytes equal canonical generation" % path, failures)
	_assert_reordered_set_fields_are_canonical(builder, equipment, stats, damage_types, documents, failures)
	_assert_wrong_loaded_base_path_is_rejected(builder, stats, damage_types, failures)
	_assert_literal_byte_guard(failures)
	return failures

func _expected_paths(rows: Script) -> Array[String]:
	var result: Array[String] = [FOUNDATION_PATH]
	for row_variant: Variant in rows.call(&"explicit_rows"):
		result.append(String((row_variant as Dictionary)["output_path"]))
	var base_manifest := _canonical_base_manifest()
	for base_id_variant: Variant in base_manifest.keys():
		var base_id := StringName(base_id_variant)
		var path := "res://data/items/affixes/fixtures/tempered_edge.tres" if base_id == &"forge_vanguard_sword" else "res://data/items/affixes/production/implicits/%s_implicit.tres" % base_id
		if path not in result:
			result.append(path)
	for row_variant: Variant in rows.call(&"weapon_profile_rows"):
		result.append(String((row_variant as Dictionary)["output_path"]))
	for path_variant: Variant in base_manifest.values():
		result.append(String(path_variant))
	result.sort()
	return result

func _canonical_base_manifest() -> Dictionary:
	var result: Dictionary = {}
	var set_ids: Array = CLASS_ROWS.SET_ITEM_IDS.keys()
	set_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	for set_id_variant: Variant in set_ids:
		var set_id := StringName(set_id_variant)
		var folder := String(CLASS_ROWS.SET_FOLDERS[set_id])
		for base_id_variant: Variant in CLASS_ROWS.SET_ITEM_IDS[set_id]:
			var base_id := StringName(base_id_variant)
			result[base_id] = "res://data/equipment/bases/%s/%s.tres" % [folder, base_id]
	return result

func _builder_owned_disk_paths() -> Array[String]:
	var result: Array[String] = []
	for root: String in [
		"res://data/items/affixes/fixtures",
		"res://data/items/affixes/production",
		"res://data/items/weapon_profiles",
		"res://data/equipment/bases",
	]:
		_append_tres_paths(root, result)
	if FileAccess.file_exists(FOUNDATION_PATH):
		result.append(FOUNDATION_PATH)
	result.sort()
	return result

func _append_tres_paths(root: String, result: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if directory.current_is_dir():
			_append_tres_paths(path, result)
		elif entry.get_extension() == "tres":
			result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()

func _assert_reordered_set_fields_are_canonical(
	builder: Script,
	equipment: EquipmentCatalog,
	stats: StatCatalog,
	damage_types: DamageTypeCatalog,
	canonical_documents: Dictionary,
	failures: Array[String]
) -> void:
	var reordered := ResourceLoader.load(EQUIPMENT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EquipmentCatalog
	TestAssertions.truthy(reordered != null, "reordered-input catalog loads outside the resource cache", failures)
	if reordered == null:
		return
	var bow := reordered.definition(&"greenwood_recurve_bow")
	var bow_tags := bow.required_all_tags.duplicate()
	bow_tags.reverse()
	bow.required_all_tags = bow_tags
	var ring := reordered.definition(&"hawkeye_band")
	var ring_slots := ring.compatible_slot_ids.duplicate()
	ring_slots.reverse()
	ring.compatible_slot_ids = ring_slots
	var reordered_variant: Variant = builder.call(&"build_document_set", reordered, stats, damage_types)
	TestAssertions.truthy(reordered_variant is Dictionary, "reordered set-like base arrays still build", failures)
	if reordered_variant is Dictionary:
		TestAssertions.equal(reordered_variant as Dictionary, canonical_documents, "set-like base array order cannot change canonical bytes", failures)

func _assert_wrong_loaded_base_path_is_rejected(
	builder: Script,
	stats: StatCatalog,
	damage_types: DamageTypeCatalog,
	failures: Array[String]
) -> void:
	var malformed := ResourceLoader.load(EQUIPMENT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EquipmentCatalog
	TestAssertions.truthy(malformed != null, "wrong-path catalog loads outside the resource cache", failures)
	if malformed == null:
		return
	malformed.definition(&"hawkeye_band").take_over_path("res://data/equipment/bases/greenwood/not_hawkeye_band.tres")
	var malformed_variant: Variant = builder.call(&"build_document_set", malformed, stats, damage_types)
	TestAssertions.equal(malformed_variant, {}, "builder rejects a loaded base whose path differs from the independent manifest", failures)

func _assert_literal_byte_guard(failures: Array[String]) -> void:
	var path := "user://weighted_loot_literal_byte_guard.bin"
	var file := FileAccess.open(path, FileAccess.WRITE)
	TestAssertions.truthy(file != null, "literal-byte guard fixture opens", failures)
	if file == null:
		return
	file.store_buffer(PackedByteArray([0xef, 0xbb, 0xbf, 0x61]))
	file.close()
	var raw_bytes := FileAccess.get_file_as_bytes(path)
	var text_round_trip := FileAccess.get_file_as_string(path).to_utf8_buffer()
	TestAssertions.truthy(raw_bytes != text_round_trip, "literal bytes distinguish a UTF-8 BOM from a text round trip", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
