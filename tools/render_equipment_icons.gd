extends SceneTree

const CATALOG := preload("res://data/equipment/core_equipment_catalog.tres")
const RENDERER_SCRIPT := preload("res://tools/equipment_icon_cpu_renderer.gd")

func _initialize() -> void:
	print("EQUIPMENT_ICON_RENDER_STAGE initialize")
	call_deferred(&"_render")

func _render() -> void:
	print("EQUIPMENT_ICON_RENDER_STAGE render")
	var requested_sets := _requested_sets()
	if requested_sets.is_empty():
		_fail("no registered equipment sets requested"); return
	var item_count := 0
	var renderer := RENDERER_SCRIPT.new() as RefCounted
	for set_id: StringName in requested_sets:
		if not ClassEquipmentRows.SET_FOLDERS.has(set_id):
			_fail("set generator is not registered set=%s" % set_id); return
		var folder := ClassEquipmentRows.SET_FOLDERS[set_id] as StringName
		var item_ids: Array = ClassEquipmentRows.SET_ITEM_IDS[set_id]
		for index: int in item_ids.size():
			var item_id := item_ids[index] as StringName
			var definition := CATALOG.definition(item_id)
			var slot_id := ClassEquipmentRows.slot_for(set_id, index)
			if definition == null:
				_fail("item=%s definition missing" % item_id); return
			if slot_id not in definition.compatible_slot_ids:
				_fail("item=%s registered slot=%s is incompatible" % [item_id, slot_id]); return
			var image := renderer.call(&"render", set_id, definition, slot_id, index) as Image
			if image == null or image.get_size() != Vector2i(256, 256) or not _visible_bounds(image).has_area():
				_fail("item=%s render invalid" % item_id); return
			if _save_pair(item_id, folder, image) != OK:
				_fail("item=%s save failed" % item_id); return
			item_count += 1
	print("EQUIPMENT_ICON_RENDER_OK sets=%d items=%d" % [requested_sets.size(), item_count]); quit(0)

func _requested_sets() -> Array[StringName]:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sets="):
			var requested := arg.trim_prefix("--sets=").strip_edges()
			if requested == "all":
				var all_sets: Array[StringName] = []
				for set_id: StringName in ClassEquipmentRows.SET_FOLDERS:
					all_sets.append(set_id)
				return all_sets
			var result: Array[StringName] = []
			for raw: String in requested.split(","):
				var set_id := StringName(raw.strip_edges())
				if set_id.is_empty() or not ClassEquipmentRows.SET_ITEM_IDS.has(set_id):
					return []
				result.append(set_id)
			return result
	return [&"fighter"]

func _visible_bounds(image: Image) -> Rect2i:
	var result := Rect2i(); var found := false
	for y: int in image.get_height(): for x: int in image.get_width(): if image.get_pixel(x,y).a > 0.01: result = Rect2i(x,y,1,1) if not found else result.expand(Vector2i(x,y)); found = true
	return result

func _fail(reason: String) -> void:
	push_error("EQUIPMENT_ICON_RENDER_ERROR %s" % reason); quit(1)

func _save_pair(item_id: StringName, set_id: StringName, image: Image) -> Error:
	var master_path := "res://assets/ui/equipment/master/%s/%s_256.png" % [set_id, item_id]
	var runtime_path := "res://assets/ui/equipment/runtime/%s/%s_128.png" % [set_id, item_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(master_path).get_base_dir()); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(runtime_path).get_base_dir())
	var error := image.save_png(ProjectSettings.globalize_path(master_path))
	if error != OK: return error
	var runtime := image.duplicate(); runtime.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	return runtime.save_png(ProjectSettings.globalize_path(runtime_path))
