extends SceneTree

const BODY_IDS: Array[StringName] = [&"masculine", &"feminine"]
const OUTPUT_ROOT := "res://docs/qa/character-presentation-quality"
const FRAME_SIZE := Vector2i(768, 768)
const CONTACT_COLUMNS := 5
const SAMPLE_COUNT := 19
const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const HEALTH_BAR_SCENE := preload("res://scenes/ui/health_bar_3d.tscn")
const LEFT_HAND_PATH := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket"
const RIGHT_HAND_PATH := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket"

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var overlay_nodes: Array[Node3D] = []
var manifest_rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred(&"_render_all")

func _render_all() -> void:
	_setup_stage()
	var class_count := 0
	for definition: ClassDefinition in GameCatalog.load_defaults().classes:
		for body_id: StringName in BODY_IDS:
			var rendered := await _render_combination(definition, body_id)
			if not rendered:
				return
		class_count += 1
	var output_dir := ProjectSettings.globalize_path(OUTPUT_ROOT)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var manifest := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if manifest == null:
		_fail("class=all body=all state=manifest reason=open failed")
		return
	manifest.store_string(JSON.stringify(manifest_rows, "  "))
	manifest.close()
	print("PARTY_FORGE_CHARACTER_VISUAL_QA_OK classes=%d bodies=2 views=4 state_samples=%d" % [class_count, SAMPLE_COUNT])
	quit(0)

func _setup_stage() -> void:
	viewport = SubViewport.new()
	viewport.name = "CharacterVisualQAViewport"
	viewport.size = FRAME_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.045, 0.06, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.9)
	environment.ambient_light_energy = 0.75
	world_environment.environment = environment
	stage.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_color = Color(1.0, 0.93, 0.82)
	light.light_energy = 1.25
	light.shadow_enabled = true
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	# Runtime humanoids face local -Z. Observe that axis directly so the frame
	# named "front" cannot silently become a rear-view pose regression.
	camera.position = Vector3(0.0, 3.15, -5.8)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.current = true
	stage.add_child(camera)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(7.0, 7.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.12, 0.15, 0.19, 1.0)
	floor_material.roughness = 0.92
	floor_mesh.material = floor_material
	floor.mesh = floor_mesh
	stage.add_child(floor)
	var floor_line := MeshInstance3D.new()
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(5.5, 0.018, 0.025)
	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color(0.16, 0.85, 0.95, 1.0)
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mesh.material = line_material
	floor_line.mesh = line_mesh
	floor_line.position = Vector3(0.0, 0.01, 0.55)
	stage.add_child(floor_line)

func _render_combination(definition: ClassDefinition, body_id: StringName) -> bool:
	var actor := LEADER_SCENE.instantiate() as PartyActor
	stage.add_child(actor)
	actor.configure(PartyMemberState.new(1, definition, true))
	var presentation := actor.get_node_or_null("Presentation") as CharacterPresentation
	var model := presentation.active_model as ForgeHumanoidModel if presentation != null else null
	if presentation == null or model == null or not presentation.set_body_preset(body_id):
		_fail("class=%s body=%s state=setup reason=presentation unavailable" % [definition.id, body_id])
		return false
	var bar := HEALTH_BAR_SCENE.instantiate() as HealthBar3D
	actor.add_child(bar)
	bar.configure(actor.get_node("HealthComponent") as HealthComponent)
	var output_dir := ProjectSettings.globalize_path("%s/%s/%s" % [OUTPUT_ROOT, definition.id, body_id])
	DirAccess.make_dir_recursive_absolute(output_dir)
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null:
		_fail("class=%s body=%s state=setup reason=animation player missing" % [definition.id, body_id])
		return false
	var attack_action := StringName(definition.visual_profile.attack_animation_by_id.get(definition.primary_attack.id, &""))
	if attack_action.is_empty() or not player.has_animation(attack_action):
		_fail("class=%s body=%s state=attack reason=authored primary action missing" % [definition.id, body_id])
		return false
	var samples := _samples(definition.visual_profile.idle_action_id, definition.visual_profile.walk_action_id, attack_action, player)
	if samples.size() != SAMPLE_COUNT:
		_fail("class=%s body=%s state=samples reason=expected %d got %d" % [definition.id, body_id, SAMPLE_COUNT, samples.size()])
		return false
	var equipment_snapshot := model.equipped_definitions.duplicate()
	var captured: Array[Image] = []
	for index: int in samples.size():
		var sample: Dictionary = samples[index]
		_restore_equipment(presentation, model, equipment_snapshot)
		model.set_hit_weight(0.0)
		_clear_overlays()
		presentation.rotation.y = float(sample[&"yaw"])
		presentation.target_yaw = presentation.rotation.y
		camera.size = float(sample.get(&"camera_size", 4.2))
		if bool(sample.get(&"clear_hands", false)):
			presentation.clear_equipment_visual(&"main_hand")
			presentation.clear_equipment_visual(&"off_hand")
		_seek_action(player, sample[&"action"] as StringName, float(sample[&"time"]))
		if bool(sample.get(&"hit", false)):
			model.set_hit_weight(1.0)
		if bool(sample.get(&"launch_overlay", false)):
			_add_launch_overlay(model)
		bar.refresh_presentation_anchor()
		var image := await _capture_frame()
		if not _valid_capture(image):
			_fail("class=%s body=%s state=%s reason=blank or undersized frame" % [definition.id, body_id, sample[&"name"]])
			return false
		var file_name := "%02d_%s.png" % [index + 1, sample[&"name"]]
		if image.save_png(output_dir.path_join(file_name)) != OK:
			_fail("class=%s body=%s state=%s reason=png save failed" % [definition.id, body_id, sample[&"name"]])
			return false
		captured.append(image)
		manifest_rows.append(_manifest_row(definition, body_id, model, sample, file_name))
	model.set_hit_weight(0.0)
	_restore_equipment(presentation, model, equipment_snapshot)
	_clear_overlays()
	if not _save_contact_sheet(captured, output_dir.path_join("contact_sheet.png")):
		_fail("class=%s body=%s state=contact_sheet reason=save or validation failed" % [definition.id, body_id])
		return false
	actor.free()
	return true

func _samples(idle_action: StringName, walk_action: StringName, attack_action: StringName, player: AnimationPlayer) -> Array[Dictionary]:
	var attack_length := player.get_animation(attack_action).length
	return [
		_sample(&"idle_front", idle_action, 0.0, 0.0),
		_sample(&"idle_three_quarter", idle_action, 0.0, -PI / 4.0),
		_sample(&"idle_side", idle_action, 0.0, -PI / 2.0),
		_sample(&"idle_rear", idle_action, 0.0, PI),
		_sample(&"walk_0_0", walk_action, 0.0, -PI / 4.0),
		_sample(&"walk_0_2", walk_action, 0.2, -PI / 4.0),
		_sample(&"walk_0_4", walk_action, 0.4, -PI / 4.0),
		_sample(&"walk_0_6", walk_action, 0.6, -PI / 4.0),
		_sample(&"attack_start", attack_action, 0.0, -PI / 4.0),
		_sample(&"attack_loaded", attack_action, attack_length * 0.28, -PI / 4.0),
		_sample(&"attack_release", attack_action, attack_length * 0.52, -PI / 4.0, false, false, true),
		_sample(&"attack_follow_through", attack_action, attack_length * 0.76, -PI / 4.0),
		_sample(&"attack_recovery", attack_action, maxf(0.0, attack_length - 0.001), -PI / 4.0),
		_sample(&"hit", idle_action, 0.0, -PI / 4.0, true),
		_sample(&"hands_equipped", idle_action, 0.0, -PI / 2.0),
		_sample(&"hands_cleared", idle_action, 0.0, -PI / 2.0, false, true),
		_sample(&"grounding_side", idle_action, 0.0, -PI / 2.0),
		_sample(&"hands_equipped_close", idle_action, 0.0, -PI / 4.0, false, false, false, 2.5),
		_sample(&"attack_release_close", attack_action, attack_length * 0.52, -PI / 4.0, false, false, true, 2.5),
	]

func _sample(name: StringName, action: StringName, time: float, yaw: float, hit := false, clear_hands := false, launch_overlay := false, camera_size := 4.2) -> Dictionary:
	return {&"name": name, &"action": action, &"time": time, &"yaw": yaw, &"hit": hit, &"clear_hands": clear_hands, &"launch_overlay": launch_overlay, &"camera_size": camera_size}

func _seek_action(player: AnimationPlayer, action_id: StringName, sample_time: float) -> void:
	player.play(action_id)
	player.pause()
	var animation := player.get_animation(action_id)
	player.seek(clampf(sample_time, 0.0, maxf(0.0, animation.length - 0.0001)), true)
	player.advance(0.0)

func _restore_equipment(presentation: CharacterPresentation, model: ForgeHumanoidModel, snapshot: Dictionary) -> void:
	for slot_id: StringName in [&"main_hand", &"off_hand"]:
		var definition := snapshot.get(slot_id) as EquipmentVisualDefinition
		if definition == null:
			if not model.equipped_item_id(slot_id).is_empty():
				presentation.clear_equipment_visual(slot_id)
		elif model.equipped_item_id(slot_id) != definition.id:
			presentation.apply_equipment_visual(slot_id, definition)

func _add_launch_overlay(model: ForgeHumanoidModel) -> void:
	for slot_id: StringName in [&"main_hand", &"off_hand"]:
		if &"ProjectileLaunchSocket" not in model.equipped_anchor_names(slot_id):
			continue
		var launch := model.equipment_anchor_global_transform(slot_id, &"ProjectileLaunchSocket")
		var marker := MeshInstance3D.new()
		var marker_mesh := SphereMesh.new()
		marker_mesh.radius = 0.055
		marker_mesh.height = 0.11
		marker_mesh.material = _overlay_material()
		marker.mesh = marker_mesh
		stage.add_child(marker)
		marker.global_position = launch.origin
		overlay_nodes.append(marker)
		var ray := MeshInstance3D.new()
		var ray_mesh := BoxMesh.new()
		ray_mesh.size = Vector3(0.025, 0.025, 0.5)
		ray_mesh.material = _overlay_material()
		ray.mesh = ray_mesh
		stage.add_child(ray)
		var forward := -launch.basis.z.normalized()
		ray.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), launch.origin + forward * 0.25)
		overlay_nodes.append(ray)
		return

func _overlay_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 0.95, 1.0, 1.0)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 1.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _clear_overlays() -> void:
	for node: Node3D in overlay_nodes:
		if is_instance_valid(node):
			node.free()
	overlay_nodes.clear()

func _capture_frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image != null and image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image

func _valid_capture(image: Image) -> bool:
	if image == null or image.get_size() != FRAME_SIZE:
		return false
	var bounds := _visible_bounds(image)
	return bounds.has_area() and float(bounds.get_area()) / float(FRAME_SIZE.x * FRAME_SIZE.y) >= 0.02

func _visible_bounds(image: Image) -> Rect2i:
	var bounds := Rect2i()
	var found := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a <= 0.01:
				continue
			bounds = Rect2i(x, y, 1, 1) if not found else bounds.expand(Vector2i(x, y))
			found = true
	return bounds

func _save_contact_sheet(images: Array[Image], output_path: String) -> bool:
	if images.size() != SAMPLE_COUNT:
		return false
	var rows := ceili(float(SAMPLE_COUNT) / float(CONTACT_COLUMNS))
	var sheet := Image.create(FRAME_SIZE.x * CONTACT_COLUMNS, FRAME_SIZE.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.025, 0.03, 0.04, 1.0))
	for index: int in images.size():
		var destination := Vector2i((index % CONTACT_COLUMNS) * FRAME_SIZE.x, (index / CONTACT_COLUMNS) * FRAME_SIZE.y)
		sheet.blit_rect(images[index], Rect2i(Vector2i.ZERO, FRAME_SIZE), destination)
	return _valid_contact_sheet(sheet) and sheet.save_png(output_path) == OK

func _valid_contact_sheet(sheet: Image) -> bool:
	return sheet != null and sheet.get_width() == FRAME_SIZE.x * CONTACT_COLUMNS and sheet.get_height() == FRAME_SIZE.y * ceili(float(SAMPLE_COUNT) / float(CONTACT_COLUMNS))

func _manifest_row(definition: ClassDefinition, body_id: StringName, model: ForgeHumanoidModel, sample: Dictionary, file_name: String) -> Dictionary:
	var equipment: Dictionary = {}
	var clearances: Dictionary = {}
	var equipment_arm_overlap: Dictionary = {}
	for slot_id: StringName in [&"main_hand", &"off_hand"]:
		var item_id := model.equipped_item_id(slot_id)
		equipment[String(slot_id)] = String(item_id)
		if not item_id.is_empty() and &"ReadabilityAnchor" in model.equipped_anchor_names(slot_id):
			clearances[String(slot_id)] = model.equipment_anchor_clearance(slot_id, &"ReadabilityAnchor")
			equipment_arm_overlap[String(slot_id)] = model.equipment_arm_intersection_volume(slot_id)
	var silhouette := _silhouette_metrics(model)
	return {
		"class": String(definition.id),
		"body": String(body_id),
		"state": String(sample[&"name"]),
		"action": String(sample[&"action"]),
		"sample_time": float(sample[&"time"]),
		"equipment": equipment,
		"ground_gap": model.ground_gap(),
		"clearance": clearances,
		"hand_behind_torso": silhouette[&"hand_behind_torso"],
		"arm_span_ratio": silhouette[&"arm_span_ratio"],
		"equipment_arm_overlap": equipment_arm_overlap,
		"projectile_overlay": bool(sample.get(&"launch_overlay", false)) and _has_projectile_socket(model),
		"path": "%s/%s/%s/%s" % [OUTPUT_ROOT.trim_prefix("res://"), definition.id, body_id, file_name],
	}

func _silhouette_metrics(model: ForgeHumanoidModel) -> Dictionary:
	var left_hand := model.get_node_or_null(LEFT_HAND_PATH) as Node3D
	var right_hand := model.get_node_or_null(RIGHT_HAND_PATH) as Node3D
	if left_hand == null or right_hand == null:
		return {&"hand_behind_torso": true, &"arm_span_ratio": INF}
	var left_position: Vector3 = model.call(&"_transform_from_model", left_hand).origin
	var right_position: Vector3 = model.call(&"_transform_from_model", right_hand).origin
	var mean_z := (left_position.z + right_position.z) * 0.5
	var body_width := maxf(0.001, model.visual_bounds().size.x)
	return {
		&"hand_behind_torso": mean_z > 0.10,
		&"arm_span_ratio": absf(right_position.x - left_position.x) / body_width,
	}

func _has_projectile_socket(model: ForgeHumanoidModel) -> bool:
	for slot_id: StringName in [&"main_hand", &"off_hand"]:
		if &"ProjectileLaunchSocket" in model.equipped_anchor_names(slot_id):
			return true
	return false

func _fail(detail: String) -> void:
	push_error("PARTY_FORGE_CHARACTER_VISUAL_QA_ERROR %s" % detail)
	quit(1)
