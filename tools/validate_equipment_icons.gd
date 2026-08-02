extends SceneTree

const SET_FOLDERS := {&"fighter": &"forge_vanguard", &"paladin": &"dawn_bulwark", &"ranger": &"greenwood", &"marksman": &"siege_archer", &"rogue": &"nightstep", &"mage": &"emberweave", &"frost_mage": &"rime_scholar", &"cleric": &"storm_chaplain", &"warlock": &"grave_covenant"}
func _initialize() -> void:
	var requested_sets := _requested_sets()
	if requested_sets.is_empty(): push_error("EQUIPMENT_ICON_VALIDATION_ERROR no registered sets requested"); quit(1); return
	var item_count := 0
	for set_id: StringName in requested_sets:
		if not SET_FOLDERS.has(set_id): push_error("EQUIPMENT_ICON_VALIDATION_ERROR set=%s is not registered" % set_id); quit(1); return
		for id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
			if not _validate(id, SET_FOLDERS[set_id]): quit(1); return
			item_count += 1
	print("EQUIPMENT_ICON_VALIDATION_OK sets=%d items=%d" % [requested_sets.size(), item_count]); quit(0)
func _requested_sets() -> Array[StringName]:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sets="):
			var result: Array[StringName] = []
			for raw: String in arg.trim_prefix("--sets=").split(","):
				var set_id := StringName(raw.strip_edges())
				if set_id.is_empty() or not ClassEquipmentRows.SET_ITEM_IDS.has(set_id): return []
				result.append(set_id)
			return result
	return [&"fighter"]
func _validate(id: StringName, folder: StringName) -> bool:
	for size: int in [256, 128]:
		var image := Image.new(); var path := ProjectSettings.globalize_path("res://assets/ui/equipment/%s/%s/%s_%d.png" % ["master" if size == 256 else "runtime", folder, id, size])
		if image.load(path) != OK or image.get_width() != size or image.get_height() != size: push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s size=%d" % [id,size]); return false
		var bounds := Rect2i(); var found := false; var transparent := false
		for y: int in image.get_height(): for x: int in image.get_width():
			var pixel := image.get_pixel(x,y); transparent = transparent or pixel.a < 0.99
			if pixel.a > 0.01: bounds = Rect2i(x,y,1,1) if not found else bounds.expand(Vector2i(x,y)); found = true
		if not found or not transparent or (size == 128 and (bounds.position.x < 8 or bounds.position.y < 8 or bounds.end.x > 120 or bounds.end.y > 120)): push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s bounds" % id); return false
	return true
