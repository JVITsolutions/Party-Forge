extends RefCounted

const RENDERER_PATH := "res://tools/equipment_icon_cpu_renderer.gd"
const CATALOG := preload("res://data/equipment/core_equipment_catalog.tres")

func run() -> Array[String]:
	var failures: Array[String] = []
	var renderer_script := load(RENDERER_PATH) as Script
	TestAssertions.truthy(renderer_script != null, "equipment icon CPU renderer exists", failures)
	if renderer_script == null:
		return failures
	var renderer := renderer_script.new() as RefCounted
	TestAssertions.equal(CATALOG.size(), 99, "canonical equipment catalog size", failures)
	var seen_variants: Dictionary = {}
	var seen_hashes: Dictionary = {}
	for set_id: StringName in ClassEquipmentRows.SET_ITEM_IDS:
		seen_variants[set_id] = {}
		var item_ids: Array = ClassEquipmentRows.SET_ITEM_IDS[set_id]
		for index: int in item_ids.size():
			var item_id := item_ids[index] as StringName
			var definition := CATALOG.definition(item_id)
			var slot_id := ClassEquipmentRows.slot_for(set_id, index)
			TestAssertions.truthy(definition != null, "%s definition exists" % item_id, failures)
			if definition == null:
				continue
			var family := StringName(renderer.call(&"family_for", definition, slot_id))
			TestAssertions.truthy(not family.is_empty(), "%s resolves a visual family" % item_id, failures)
			var variant: Vector3i = renderer.call(&"identity_variant", index)
			var variant_key := "%d:%d:%d" % [variant.x, variant.y, variant.z]
			TestAssertions.truthy(not (seen_variants[set_id] as Dictionary).has(variant_key), "%s identity variant is unique within %s" % [item_id, set_id], failures)
			(seen_variants[set_id] as Dictionary)[variant_key] = item_id
			var image := renderer.call(&"render", set_id, definition, slot_id, index) as Image
			_assert_image(image, item_id, failures)
			if image != null:
				var digest := _image_digest(image)
				TestAssertions.truthy(not seen_hashes.has(digest), "%s master pixels differ from %s" % [item_id, seen_hashes.get(digest, &"<none>")], failures)
				seen_hashes[digest] = item_id
	_assert_family(renderer, &"greenwood_jerkin", &"body_armour", failures)
	_assert_family(renderer, &"siege_archer_cowl", &"helmet", failures)
	_assert_family(renderer, &"emberweave_circlet", &"helmet", failures)
	_assert_family(renderer, &"hawkeye_band", &"ring", failures)
	_assert_family(renderer, &"emberweave_rune_sash", &"belt", failures)
	_assert_family(renderer, &"storm_chaplain_reliquary", &"amulet", failures)
	return failures

func _assert_family(renderer: RefCounted, item_id: StringName, expected: StringName, failures: Array[String]) -> void:
	var definition := CATALOG.definition(item_id)
	var slot_id := definition.compatible_slot_ids[0] if definition != null else &""
	TestAssertions.equal(StringName(renderer.call(&"family_for", definition, slot_id)), expected, "%s uses declared family" % item_id, failures)

func _assert_image(image: Image, item_id: StringName, failures: Array[String]) -> void:
	TestAssertions.truthy(image != null, "%s renders" % item_id, failures)
	if image == null:
		return
	TestAssertions.equal(image.get_size(), Vector2i(256, 256), "%s master size" % item_id, failures)
	var bounds := _visible_bounds(image)
	TestAssertions.truthy(bounds.has_area(), "%s has visible pixels" % item_id, failures)
	TestAssertions.truthy(bounds.position.x >= 16 and bounds.position.y >= 16 and bounds.end.x <= 240 and bounds.end.y <= 240, "%s keeps master padding" % item_id, failures)

func _visible_bounds(image: Image) -> Rect2i:
	var result := Rect2i()
	var found := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				result = Rect2i(x, y, 1, 1) if not found else result.expand(Vector2i(x, y))
				found = true
	return result

func _image_digest(image: Image) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(image.get_data()) != OK:
		return ""
	return context.finish().hex_encode()
