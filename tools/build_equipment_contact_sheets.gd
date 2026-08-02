extends SceneTree

func _initialize() -> void:
	var output_dir := ProjectSettings.globalize_path("res://assets/ui/equipment/contact_sheets")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for class_id: StringName in ClassEquipmentRows.SET_FOLDERS:
		var sheet := Image.create(512, 384, false, Image.FORMAT_RGBA8)
		sheet.fill(Color.TRANSPARENT)
		var folder := StringName(ClassEquipmentRows.SET_FOLDERS[class_id])
		var item_ids: Array = ClassEquipmentRows.SET_ITEM_IDS[class_id]
		for index: int in item_ids.size():
			var icon := Image.new()
			var path := ProjectSettings.globalize_path("res://assets/ui/equipment/runtime/%s/%s_128.png" % [folder, item_ids[index]])
			if icon.load(path) != OK or icon.get_size() != Vector2i(128, 128):
				_fail("class=%s item=%s icon=%s" % [class_id, item_ids[index], path])
				return
			sheet.blit_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i((index % 4) * 128, (index / 4) * 128))
		var output := output_dir.path_join("%s_contact_sheet.png" % folder)
		if sheet.save_png(output) != OK:
			_fail("class=%s output=%s" % [class_id, output])
			return
	print("EQUIPMENT_CONTACT_SHEET_BUILD_OK sets=%d items=%d" % [ClassEquipmentRows.SET_FOLDERS.size(), ClassEquipmentRows.total_item_count()])
	quit(0)

func _fail(reason: String) -> void:
	push_error("EQUIPMENT_CONTACT_SHEET_BUILD_ERROR %s" % reason)
	quit(1)
