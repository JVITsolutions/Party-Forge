extends SceneTree

const SET_FOLDERS := {&"fighter": &"forge_vanguard", &"paladin": &"dawn_bulwark", &"ranger": &"greenwood", &"marksman": &"siege_archer", &"rogue": &"nightstep", &"mage": &"emberweave", &"frost_mage": &"rime_scholar", &"cleric": &"storm_chaplain", &"warlock": &"grave_covenant"}
const CAMERA_PRESETS := {
	&"weapon": {&"direction": Vector3(0.32, 0.08, 1.0), &"margin": 1.42, &"minimum": 0.60},
	&"shield": {&"direction": Vector3(0.20, 0.10, 1.0), &"margin": 1.36, &"minimum": 0.75},
	&"armour": {&"direction": Vector3(0.25, 0.10, 1.0), &"margin": 1.34, &"minimum": 0.75},
	&"jewelry": {&"direction": Vector3(0.10, 0.12, 1.0), &"margin": 1.55, &"minimum": 0.45},
	&"wearable": {&"direction": Vector3(0.22, 0.10, 1.0), &"margin": 1.38, &"minimum": 0.60},
}

func _initialize() -> void:
	print("EQUIPMENT_ICON_RENDER_STAGE initialize")
	call_deferred(&"_render")

func _render() -> void:
	print("EQUIPMENT_ICON_RENDER_STAGE render")
	var requested_sets := _requested_sets()
	if requested_sets.is_empty():
		_fail("no registered equipment sets requested"); return
	var item_count := 0
	for set_id: StringName in requested_sets:
		if not SET_FOLDERS.has(set_id): _fail("set generator is not registered set=%s" % set_id); return
		var folder := SET_FOLDERS[set_id] as StringName
		for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
			var scene := load("res://scenes/equipment/%s/%s.tscn" % [folder, item_id]) as PackedScene
			var item := scene.instantiate() as Node3D if scene != null else null
			if item == null: _fail("item=%s scene missing" % item_id); return
			var image := _render_cpu_icon(set_id, item_id)
			print("EQUIPMENT_ICON_DIAG item=%s image=%s alpha_bounds=%s" % [item_id, Vector2i(image.get_width(), image.get_height()) if image != null else Vector2i.ZERO, _visible_bounds(image) if image != null else Rect2i()])
			if image == null or image.get_width() != 256 or image.get_height() != 256 or _visible_bounds(image).size == Vector2i.ZERO: _fail("item=%s capture invalid" % item_id); return
			if _save_pair(item_id, folder, image) != OK: _fail("item=%s save failed" % item_id); return
			item.free(); item_count += 1
	print("EQUIPMENT_ICON_RENDER_OK sets=%d items=%d" % [requested_sets.size(), item_count]); quit(0)

func _render_cpu_icon(set_id: StringName, item_id: StringName) -> Image:
	var image := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var palettes := {
		&"fighter": [Color("d94f4f"), Color("303a47"), Color("4a3426"), Color("b68b3a")], &"paladin": [Color("e0b94f"), Color("d7dce2"), Color("553c28"), Color("fff0a1")],
		&"ranger": [Color("4f7a4d"), Color("59636a"), Color("5a3f28"), Color("83b86a")], &"marksman": [Color("59613b"), Color("4b5157"), Color("493b2a"), Color("a89d5b")], &"rogue": [Color("5a426e"), Color("657080"), Color("282127"), Color("a773c2")],
		&"mage": [Color("7c4d9e"), Color("61556c"), Color("4b334f"), Color("ff7043")], &"frost_mage": [Color("4f7f9e"), Color("6b8292"), Color("374e5c"), Color("8ee8ff")],
		&"cleric": [Color("d8c36a"), Color("69727a"), Color("66563d"), Color("fff08a")], &"warlock": [Color("513663"), Color("41404a"), Color("302431"), Color("8c45c9")],
	}
	var palette: Array = palettes[set_id]
	var primary: Color = palette[0]; var metal: Color = palette[1]; var leather: Color = palette[2]; var accent: Color = palette[3]
	_draw_circle(image, Vector2i(132, 140), 70, Color(0.03, 0.04, 0.06, 0.55))
	var kind := _camera_kind(item_id)
	match kind:
		&"weapon":
			if "staff" in String(item_id):
				_draw_line(image, Vector2i(91, 210), Vector2i(157, 56), leather, 12); _draw_circle(image, Vector2i(163, 51), 24, accent); _draw_circle_outline(image, Vector2i(163, 51), 31, metal, 7)
			elif "wand" in String(item_id):
				_draw_line(image, Vector2i(78, 201), Vector2i(164, 70), leather, 12); _draw_circle(image, Vector2i(174, 57), 22, accent)
			elif "sceptre" in String(item_id):
				_draw_line(image, Vector2i(85, 205), Vector2i(151, 70), metal, 14); image.fill_rect(Rect2i(124, 47, 80, 24), accent); _draw_circle(image, Vector2i(164, 42), 16, accent)
			elif "focus" in String(item_id):
				_draw_circle(image, Vector2i(128, 125), 53, accent); _draw_circle_outline(image, Vector2i(128, 125), 70, metal, 9)
			elif "tome" in String(item_id) or "grimoire" in String(item_id):
				image.fill_rect(Rect2i(67, 57, 122, 151), leather); image.fill_rect(Rect2i(78, 69, 100, 128), primary); image.fill_rect(Rect2i(119, 69, 13, 128), metal); image.fill_rect(Rect2i(95, 119, 67, 14), accent)
			elif "bow" in String(item_id):
				_draw_line(image, Vector2i(79, 190), Vector2i(79, 68), leather, 11)
				_draw_line(image, Vector2i(79, 68), Vector2i(145, 46), leather, 11)
				_draw_line(image, Vector2i(79, 190), Vector2i(145, 212), leather, 11)
				_draw_line(image, Vector2i(145, 46), Vector2i(145, 212), accent, 4)
				_draw_line(image, Vector2i(75, 129), Vector2i(199, 129), metal, 8)
			elif "hammer" in String(item_id):
				_draw_line(image, Vector2i(78, 204), Vector2i(162, 62), leather, 12)
				image.fill_rect(Rect2i(112, 42, 92, 48), metal); image.fill_rect(Rect2i(146, 48, 18, 36), accent)
			else:
				_draw_line(image, Vector2i(78, 204), Vector2i(162, 62), leather, 12)
				_draw_line(image, Vector2i(151, 84), Vector2i(194, 45), metal, 18); image.fill_rect(Rect2i(62, 188, 76, 13), accent)
		&"quiver":
			image.fill_rect(Rect2i(91, 78, 75, 126), leather); image.fill_rect(Rect2i(86, 72, 85, 20), primary)
			for x: int in [101, 128, 155]: _draw_line(image, Vector2i(x, 92), Vector2i(x, 42), metal, 5)
		&"shield":
			image.fill_rect(Rect2i(65, 49, 126, 148), metal); image.fill_rect(Rect2i(78, 61, 100, 123), primary); image.fill_rect(Rect2i(119, 66, 18, 110), accent); image.fill_rect(Rect2i(82, 111, 92, 18), accent)
		&"armour":
			image.fill_rect(Rect2i(72, 68, 112, 132), leather); image.fill_rect(Rect2i(55, 70, 45, 55), metal); image.fill_rect(Rect2i(156, 70, 45, 55), metal); image.fill_rect(Rect2i(83, 80, 90, 92), primary); image.fill_rect(Rect2i(91, 92, 74, 15), accent)
		&"jewelry":
			if "belt" in String(item_id):
				image.fill_rect(Rect2i(43, 112, 170, 37), leather); image.fill_rect(Rect2i(106, 102, 48, 57), accent); image.fill_rect(Rect2i(118, 113, 24, 35), Color(0.03, 0.04, 0.06, 1))
			elif "amulet" in String(item_id):
				_draw_circle_outline(image, Vector2i(128, 111), 62, metal, 10); _draw_circle(image, Vector2i(128, 172), 28, accent)
			else:
				_draw_circle_outline(image, Vector2i(128, 128), 58, metal, 25); _draw_circle(image, Vector2i(128, 65), 18, accent)
		_:
			if "hood" in String(item_id) or "crown" in String(item_id) or "helmet" in String(item_id):
				image.fill_rect(Rect2i(77, 63, 102, 128), leather if set_id == &"rogue" else metal); image.fill_rect(Rect2i(92, 86, 72, 68), Color(0.03, 0.04, 0.06, 1)); image.fill_rect(Rect2i(102, 57, 52, 18), accent)
			elif "glove" in String(item_id) or "gauntlet" in String(item_id):
				image.fill_rect(Rect2i(84, 82, 90, 114), metal if set_id == &"paladin" else leather); image.fill_rect(Rect2i(70, 72, 22, 77), primary); image.fill_rect(Rect2i(164, 72, 22, 77), primary)
			elif "boot" in String(item_id) or "sabaton" in String(item_id):
				image.fill_rect(Rect2i(67, 62, 50, 128), metal if set_id == &"paladin" else leather); image.fill_rect(Rect2i(139, 62, 50, 128), metal if set_id == &"paladin" else leather); image.fill_rect(Rect2i(49, 166, 68, 32), primary); image.fill_rect(Rect2i(139, 166, 68, 32), primary)
			else:
				image.fill_rect(Rect2i(76, 52, 45, 148), metal if set_id == &"paladin" else leather); image.fill_rect(Rect2i(135, 52, 45, 148), metal if set_id == &"paladin" else leather); image.fill_rect(Rect2i(76, 95, 104, 18), primary)
	return image

func _draw_line(image: Image, from: Vector2i, to: Vector2i, color: Color, width: int) -> void:
	var steps := maxi(abs(to.x - from.x), abs(to.y - from.y))
	for index: int in steps + 1:
		var point := Vector2(from).lerp(Vector2(to), float(index) / maxf(1.0, steps))
		_draw_circle(image, Vector2i(point), maxi(1, width / 2), color)

func _draw_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				var point := center + Vector2i(x, y)
				if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height(): image.set_pixelv(point, color)

func _draw_circle_outline(image: Image, center: Vector2i, radius: int, color: Color, width: int) -> void:
	var inner := maxi(0, radius - width)
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			var distance := x * x + y * y
			if distance <= radius * radius and distance >= inner * inner:
				var point := center + Vector2i(x, y)
				if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height(): image.set_pixelv(point, color)

func _requested_sets() -> Array[StringName]:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sets="):
			var result: Array[StringName] = []
			for raw: String in arg.trim_prefix("--sets=").split(","):
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
func _item_bounds(item: Node3D) -> AABB:
	var bounds := AABB(); var has_bounds := false
	for node: Node in item.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			var transformed := mesh.global_transform * mesh.get_aabb(); bounds = transformed if not has_bounds else bounds.merge(transformed); has_bounds = true
	return bounds
func _camera_kind(item_id: StringName) -> StringName:
	if "shield" in String(item_id): return &"shield"
	if "quiver" in String(item_id): return &"quiver"
	if "sword" in String(item_id) or "hammer" in String(item_id) or "dagger" in String(item_id) or "bow" in String(item_id) or "staff" in String(item_id) or "wand" in String(item_id) or "focus" in String(item_id) or "sceptre" in String(item_id) or "tome" in String(item_id) or "grimoire" in String(item_id): return &"weapon"
	if "plate" in String(item_id) or "leathers" in String(item_id) or "robe" in String(item_id) or "vestment" in String(item_id) or item_id == &"forge_vanguard_armour": return &"armour"
	if "amulet" in String(item_id) or "ring" in String(item_id) or "belt" in String(item_id) or "sash" in String(item_id) or "reliquary" in String(item_id): return &"jewelry"
	return &"wearable"
func _fail(reason: String) -> void: push_error("EQUIPMENT_ICON_RENDER_ERROR %s" % reason); quit(1)

func _save_pair(item_id: StringName, set_id: StringName, image: Image) -> Error:
	var master_path := "res://assets/ui/equipment/master/%s/%s_256.png" % [set_id, item_id]
	var runtime_path := "res://assets/ui/equipment/runtime/%s/%s_128.png" % [set_id, item_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(master_path).get_base_dir()); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(runtime_path).get_base_dir())
	var error := image.save_png(ProjectSettings.globalize_path(master_path))
	if error != OK: return error
	var runtime := image.duplicate(); runtime.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	return runtime.save_png(ProjectSettings.globalize_path(runtime_path))
