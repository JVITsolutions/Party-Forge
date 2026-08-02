extends SceneTree

const IDS: Array[StringName] = [&"forge_vanguard_helmet", &"forge_vanguard_armour", &"forge_vanguard_greaves", &"forge_vanguard_gauntlets", &"forge_vanguard_boots", &"forge_vanguard_amulet", &"forge_vanguard_ring_left", &"forge_vanguard_ring_right", &"forge_vanguard_belt", &"forge_vanguard_sword", &"forge_vanguard_shield", &"forge_vanguard_hammer"]
func _initialize() -> void:
	for id: StringName in IDS:
		if not _validate(id): quit(1); return
	print("EQUIPMENT_ICON_VALIDATION_OK items=12"); quit(0)
func _validate(id: StringName) -> bool:
	for size: int in [256, 128]:
		var image := Image.new(); var path := ProjectSettings.globalize_path("res://assets/ui/equipment/%s/forge_vanguard/%s_%d.png" % ["master" if size == 256 else "runtime", id, size])
		if image.load(path) != OK or image.get_width() != size or image.get_height() != size: push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s size=%d" % [id,size]); return false
		var bounds := Rect2i(); var found := false; var transparent := false
		for y: int in image.get_height(): for x: int in image.get_width():
			var pixel := image.get_pixel(x,y); transparent = transparent or pixel.a < 0.99
			if pixel.a > 0.01: bounds = Rect2i(x,y,1,1) if not found else bounds.expand(Vector2i(x,y)); found = true
		if not found or not transparent or (size == 128 and (bounds.position.x < 8 or bounds.position.y < 8 or bounds.end.x > 120 or bounds.end.y > 120)): push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s bounds" % id); return false
	return true
