extends RefCounted

const FIGHTER_IDS: Array[StringName] = [
	&"forge_vanguard_helmet", &"forge_vanguard_armour", &"forge_vanguard_greaves",
	&"forge_vanguard_gauntlets", &"forge_vanguard_boots", &"forge_vanguard_amulet",
	&"forge_vanguard_ring_left", &"forge_vanguard_ring_right", &"forge_vanguard_belt",
	&"forge_vanguard_sword", &"forge_vanguard_shield", &"forge_vanguard_hammer",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	for item_id: StringName in FIGHTER_IDS:
		var visual := load("res://data/presentation/equipment/forge_vanguard/%s.tres" % item_id) as EquipmentVisualDefinition
		TestAssertions.truthy(visual != null, "%s visual loads for icon validation" % item_id, failures)
		if visual == null:
			continue
		_assert_icon(visual.icon_master, 256, item_id, "master", failures)
		_assert_icon(visual.icon_runtime, 128, item_id, "runtime", failures)
	return failures

func _assert_icon(texture: Texture2D, expected_size: int, item_id: StringName, kind: String, failures: Array[String]) -> void:
	TestAssertions.truthy(texture != null, "%s %s icon exists" % [item_id, kind], failures)
	if texture == null:
		return
	var image := texture.get_image()
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
