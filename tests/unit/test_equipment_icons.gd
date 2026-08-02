extends RefCounted

const SET_FOLDERS := {
	&"fighter": &"forge_vanguard", &"paladin": &"dawn_bulwark", &"ranger": &"greenwood",
	&"marksman": &"siege_archer", &"rogue": &"nightstep", &"mage": &"emberweave",
	&"frost_mage": &"rime_scholar", &"cleric": &"storm_chaplain", &"warlock": &"grave_covenant",
}

func run() -> Array[String]:
	var failures: Array[String] = []
	var hashes := {256: {}, 128: {}}
	for set_id: StringName in ClassEquipmentRows.SET_ITEM_IDS:
		var folder := StringName(SET_FOLDERS[set_id])
		for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
			for size: int in [256, 128]:
				var kind := "master" if size == 256 else "runtime"
				var path := "res://assets/ui/equipment/%s/%s/%s_%d.png" % [kind, folder, item_id, size]
				var image := Image.new()
				TestAssertions.equal(image.load(ProjectSettings.globalize_path(path)), OK, "%s %s icon loads" % [item_id, kind], failures)
				if image.is_empty():
					continue
				_assert_icon(image, size, item_id, kind, failures)
				var digest := _image_digest(image)
				TestAssertions.truthy(not (hashes[size] as Dictionary).has(digest), "%s %s pixels differ from %s" % [item_id, kind, (hashes[size] as Dictionary).get(digest, &"<none>")], failures)
				(hashes[size] as Dictionary)[digest] = item_id
	return failures

func _image_digest(image: Image) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(image.get_data()) != OK:
		return ""
	return context.finish().hex_encode()

func _assert_icon(image: Image, expected_size: int, item_id: StringName, kind: String, failures: Array[String]) -> void:
	TestAssertions.equal(image.get_width(), expected_size, "%s %s icon width" % [item_id, kind], failures)
	TestAssertions.equal(image.get_height(), expected_size, "%s %s icon height" % [item_id, kind], failures)
	var bounds := _visible_bounds(image)
	TestAssertions.truthy(bounds.size.x > 0 and bounds.size.y > 0, "%s %s icon has visible pixels" % [item_id, kind], failures)
	TestAssertions.truthy(_has_transparency(image), "%s %s icon has transparency" % [item_id, kind], failures)
	if kind == "runtime" and bounds.size.x > 0 and bounds.size.y > 0:
		TestAssertions.truthy(bounds.position.x >= 8 and bounds.position.y >= 8 and bounds.end.x <= 120 and bounds.end.y <= 120, "%s runtime icon keeps eight-pixel padding" % item_id, failures)

func _visible_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				min_x = mini(min_x, x); min_y = mini(min_y, y)
				max_x = maxi(max_x, x); max_y = maxi(max_y, y)
	return Rect2i() if max_x < 0 else Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _has_transparency(image: Image) -> bool:
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < 0.99:
				return true
	return false
