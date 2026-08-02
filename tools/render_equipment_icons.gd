extends SceneTree

const IDS: Array[StringName] = [&"forge_vanguard_helmet", &"forge_vanguard_armour", &"forge_vanguard_greaves", &"forge_vanguard_gauntlets", &"forge_vanguard_boots", &"forge_vanguard_amulet", &"forge_vanguard_ring_left", &"forge_vanguard_ring_right", &"forge_vanguard_belt", &"forge_vanguard_sword", &"forge_vanguard_shield", &"forge_vanguard_hammer"]

func _initialize() -> void:
	call_deferred(&"_render")

func _render() -> void:
	var viewport := SubViewport.new(); viewport.transparent_bg = true; viewport.size = Vector2i(256, 256); viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var world := World3D.new(); viewport.world_3d = world
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; viewport.add_child(camera)
	for entry: Dictionary in [{&"position": Vector3(2, 3, 3), &"color": Color.WHITE}, {&"position": Vector3(-2, 1, 2), &"color": Color(0.7, 0.8, 1.0)}, {&"position": Vector3(0, -2, 2), &"color": Color(1.0, 0.8, 0.55)}]:
		var light := DirectionalLight3D.new(); light.look_at_from_position(entry[&"position"], Vector3.ZERO); light.light_color = entry[&"color"]; viewport.add_child(light)
	root.add_child(viewport)
	for item_id: StringName in IDS:
		var scene := load("res://scenes/equipment/forge_vanguard/%s.tscn" % item_id) as PackedScene
		var item := scene.instantiate() as Node3D if scene != null else null
		if item == null: _fail("item=%s scene missing" % item_id); return
		for node: Node in item.find_children("*", "Node3D", true, false): (node as Node3D).visible = true
		viewport.add_child(item)
		var bounds := _item_bounds(item)
		var target := bounds.get_center()
		# Square orthographic framing with a fixed world-space margin keeps every
		# equipment class readable while guaranteeing icon-safe transparent padding.
		camera.size = maxf(maxf(bounds.size.x, bounds.size.y) * 1.30 + 0.20, 0.60)
		camera.look_at_from_position(target + Vector3(0, 0, 3), target)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		print("EQUIPMENT_ICON_DIAG item=%s image=%s alpha_bounds=%s" % [item_id, Vector2i(image.get_width(), image.get_height()) if image != null else Vector2i.ZERO, _visible_bounds(image) if image != null else Rect2i()])
		if image == null or image.get_width() != 256 or image.get_height() != 256 or _visible_bounds(image).size == Vector2i.ZERO: _fail("item=%s capture invalid" % item_id); return
		if _save_pair(item_id, &"forge_vanguard", image) != OK: _fail("item=%s save failed" % item_id); return
		item.free()
	viewport.free(); print("EQUIPMENT_ICON_RENDER_OK items=12"); quit(0)

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
func _fail(reason: String) -> void: push_error("EQUIPMENT_ICON_RENDER_ERROR %s" % reason); quit(1)

func _save_pair(item_id: StringName, set_id: StringName, image: Image) -> Error:
	var master_path := "res://assets/ui/equipment/master/%s/%s_256.png" % [set_id, item_id]
	var runtime_path := "res://assets/ui/equipment/runtime/%s/%s_128.png" % [set_id, item_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(master_path).get_base_dir()); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(runtime_path).get_base_dir())
	var error := image.save_png(ProjectSettings.globalize_path(master_path))
	if error != OK: return error
	var runtime := image.duplicate(); runtime.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	return runtime.save_png(ProjectSettings.globalize_path(runtime_path))
