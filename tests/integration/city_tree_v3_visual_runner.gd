extends SceneTree

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const SCREENSHOT_PATH := "user://tests/city-tree-v3-visual.png"
const CONNECTION_COLOR := Color(0.38, 0.48, 0.68, 0.9)
const CONNECTION_PIXEL_TOLERANCE := 0.22
const CONNECTION_MIN_MATCH_RATIO := 0.95
const CONNECTION_MAX_INTERNAL_GAP := 2
const LABEL_PIXEL_TOLERANCE := 0.18
const CHARTER_IDS: Array[StringName] = [
	&"expedition-district-charter", &"forge-district-charter", &"hero-district-charter",
	&"logistics-district-charter", &"market-district-charter", &"trials-district-charter",
]

var _failures: Array[String] = []
var _profile_root := ""
var _absolute_screenshot_path := ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_profile_root = "user://tests/city_tree_v3_visual_profile_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_profile_root)
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return "city-tree-v3-visual")
	_assert(manager.bootstrap(_profile_root).is_empty(), "visual profile manager bootstraps")
	var created := manager.create_profile("City Tree v3 Visual", 1000)
	_assert(created.ok(), "visual profile is created")
	if not created.ok():
		_finish(null, null)
		return
	var profile_id := created.profile.profile_id
	_assert(ProfileTestSupport.commit_city_victory(profile_id, "city-tree-v3-visual-first-victory", _profile_root).ok(), "first victory reveals the visual City fixture")
	_assert(manager.refresh_profile(profile_id).is_empty(), "visual profile refreshes after City discovery")

	var portfolio := LatticewrightRuntimePortfolioRegistry.new()
	var loaded := PassiveTreeCatalog.load_defaults(portfolio)
	_assert(loaded.ok() and portfolio.has_graph(&"party-forge-city", &"city-passive-tree"), "visual runner loads the production runtime-v3 City graph")
	if not loaded.ok():
		_finish(null, null)
		return

	var effects := PassiveEffectRegistry.new()
	var requirements := PassiveRequirementRegistry.new()
	var progression := PassiveTreeProgressionService.new(effects, requirements, null, portfolio)
	var resolver := PassiveEffectResolver.new(effects)
	var mutations := PassiveTreeMutationService.new(ProfileMutationService.new(ProfileStore.new()), progression, resolver)
	var view_model := PassiveTreeViewModel.new(progression, resolver, effects, requirements)

	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen := (load("res://scenes/ui/passive_tree/passive_tree_screen.tscn") as PackedScene).instantiate() as PassiveTreeScreen
	viewport.add_child(screen)
	await _frames(2)
	screen.configure(loaded.tree, manager, mutations, view_model, false, _profile_root)
	screen.open()
	await _frames(3)

	var canvas := screen.get_node("Overlay/Frame/Layout/Body/Canvas") as PassiveTreeCanvas
	_assert(canvas.node_ids().size() == 37 and canvas.connection_views().size() == 37, "real City screen renders all 37 nodes and 37 connections")
	_assert(CityTreeGeometryValidator.validate(loaded.tree.nodes, loaded.tree.connections).is_empty(), "serialized geometry remains free of prohibited intersections")
	for charter_id: StringName in CHARTER_IDS:
		var charter := canvas.node_control(charter_id)
		_assert(charter != null and charter.text.contains("District"), "%s renders its district label" % charter_id)

	await _frames(5)
	var canvas_rect := canvas.get_global_rect()
	_assert(is_finite(canvas.zoom_value()) and canvas.zoom_value() >= PassiveTreeCanvas.MIN_ZOOM and canvas.zoom_value() <= PassiveTreeCanvas.MAX_ZOOM, "production screen applies a finite clamped content fit")
	_assert(is_finite(canvas.pan_value().x) and is_finite(canvas.pan_value().y), "production screen applies a finite content-fit pan")
	for node_id: StringName in canvas.node_ids():
		var control := canvas.node_control(node_id)
		_assert(control != null and control.visible and control.is_visible_in_tree(), "%s is visible before capture" % node_id)
		if control != null:
			_assert(_encloses(canvas_rect, control.get_global_rect()), "%s is contained in the fitted City canvas" % node_id)
	var control_overlaps := _control_overlap_pairs(canvas)
	var zoom_feasibility := _zoom_feasibility(canvas)
	_assert(control_overlaps.is_empty(), "all 37 production node controls remain nonoverlapping after fit: fitted_zoom=%.3f minimum_nonoverlap_zoom=%.3f maximum_containment_zoom=%.3f canvas=%.1fx%.1f overlaps=%s" % [canvas.zoom_value(), float(zoom_feasibility.get("minimum_nonoverlap_zoom", INF)), float(zoom_feasibility.get("maximum_containment_zoom", -INF)), canvas.size.x, canvas.size.y, ",".join(control_overlaps)])
	var connection_image := await _capture_connections_only(viewport, canvas)
	_assert(connection_image != null and not connection_image.is_empty(), "visual runner captures the unobscured production connection layer")
	var image := viewport.get_texture().get_image()
	_assert(image != null and not image.is_empty(), "visual runner captures rendered pixels")
	if image != null and not image.is_empty() and connection_image != null and not connection_image.is_empty():
		_assert(image.get_size() == VIEWPORT_SIZE, "visual capture is exactly 1920x1080")
		_assert(_image_is_nonblank(image), "visual capture is nonblank")
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))
		for connection: Dictionary in canvas.connection_views():
			var connection_id := StringName(connection.get("id", ""))
			var from_id := StringName(connection.get("from_id", ""))
			var to_id := StringName(connection.get("to_id", ""))
			var from_control := canvas.node_control(from_id)
			var to_control := canvas.node_control(to_id)
			_assert(not connection_id.is_empty() and from_control != null and to_control != null, "%s resolves both rendered endpoint controls" % connection_id)
			if from_control == null or to_control == null:
				continue
			var from_center := from_control.get_global_rect().get_center()
			var to_center := to_control.get_global_rect().get_center()
			_assert(viewport_rect.has_point(from_center) and viewport_rect.has_point(to_center), "%s path endpoints remain inside the capture viewport" % connection_id)
			var path_evidence := _connection_path_evidence(connection_image, from_center, to_center)
			_assert(float(path_evidence.get("match_ratio", 0.0)) >= CONNECTION_MIN_MATCH_RATIO, "%s unobscured centerline pixel match ratio is %.3f, below %.2f" % [connection_id, float(path_evidence.get("match_ratio", 0.0)), CONNECTION_MIN_MATCH_RATIO])
			_assert(int(path_evidence.get("maximum_gap", 999999)) <= CONNECTION_MAX_INTERNAL_GAP, "%s unobscured centerline maximum pixel gap is %d, above %d" % [connection_id, int(path_evidence.get("maximum_gap", 999999)), CONNECTION_MAX_INTERNAL_GAP])
		for charter_id: StringName in CHARTER_IDS:
			var charter := canvas.node_control(charter_id)
			if charter == null:
				continue
			var charter_rect := charter.get_global_rect()
			var renderability := _full_label_renderability(canvas, charter_id)
			var text_size := renderability.get("text_size", Vector2.ZERO) as Vector2
			var available_rect := renderability.get("available_rect", Rect2()) as Rect2
			var full_text_rect := renderability.get("full_text_rect", Rect2()) as Rect2
			var word_regions := renderability.get("word_regions", []) as Array
			var overlaps := renderability.get("overlaps", []) as Array
			_assert(_encloses(viewport_rect, charter_rect), "%s district label remains inside the capture viewport" % charter_id)
			_assert(bool(renderability.get("fits", false)), "%s full label '%s' does not fit unellipsized: text=%.1fx%.1f available=%.1fx%.1f" % [charter_id, charter.text, text_size.x, text_size.y, available_rect.size.x, available_rect.size.y])
			_assert(overlaps.is_empty(), "%s full label '%s' is obstructed by controls: %s" % [charter_id, charter.text, ",".join(overlaps)])
			_assert(_label_avoids_all_other_controls(canvas, charter_id, full_text_rect), "%s full label bounds are unobscured by every other node control" % charter_id)
			_assert(_label_has_rendered_text(image, charter, word_regions), "%s full wrapped label has substantial rendered foreground pixels in every word region" % charter_id)
		_assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests")) == OK, "visual evidence directory exists")
		_absolute_screenshot_path = ProjectSettings.globalize_path(SCREENSHOT_PATH)
		_assert(image.save_png(_absolute_screenshot_path) == OK, "visual capture saves outside the repository")
		_assert(FileAccess.file_exists(_absolute_screenshot_path), "visual capture exists at the reported path")
	_finish(screen, viewport)


func _encloses(outer: Rect2, inner: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)


func _control_overlap_pairs(canvas: PassiveTreeCanvas) -> Array[String]:
	var overlaps: Array[String] = []
	var ids := canvas.node_ids()
	for left_index: int in range(ids.size()):
		var left := canvas.node_control(ids[left_index])
		if left == null:
			overlaps.append("missing:%s" % ids[left_index])
			continue
		for right_index: int in range(left_index + 1, ids.size()):
			var right := canvas.node_control(ids[right_index])
			if right == null:
				overlaps.append("missing:%s" % ids[right_index])
			elif left.get_global_rect().intersects(right.get_global_rect()):
				overlaps.append("%s/%s" % [ids[left_index], ids[right_index]])
	return overlaps


func _zoom_feasibility(canvas: PassiveTreeCanvas) -> Dictionary:
	var ids := canvas.node_ids()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var maximum_control_size := Vector2.ZERO
	var minimum_nonoverlap_zoom := 0.0
	for left_index: int in range(ids.size()):
		var left_view := canvas.node_view(ids[left_index])
		var left_control := canvas.node_control(ids[left_index])
		if left_view == null or left_control == null:
			return {"minimum_nonoverlap_zoom": INF, "maximum_containment_zoom": -INF}
		minimum.x = minf(minimum.x, left_view.position.x)
		minimum.y = minf(minimum.y, left_view.position.y)
		maximum.x = maxf(maximum.x, left_view.position.x)
		maximum.y = maxf(maximum.y, left_view.position.y)
		maximum_control_size.x = maxf(maximum_control_size.x, left_control.size.x)
		maximum_control_size.y = maxf(maximum_control_size.y, left_control.size.y)
		for right_index: int in range(left_index + 1, ids.size()):
			var right_view := canvas.node_view(ids[right_index])
			var right_control := canvas.node_control(ids[right_index])
			if right_view == null or right_control == null:
				return {"minimum_nonoverlap_zoom": INF, "maximum_containment_zoom": -INF}
			var separation := (right_view.position - left_view.position).abs()
			var required_x := (left_control.size.x + right_control.size.x) * 0.5 / separation.x if separation.x > 0.0 else INF
			var required_y := (left_control.size.y + right_control.size.y) * 0.5 / separation.y if separation.y > 0.0 else INF
			minimum_nonoverlap_zoom = maxf(minimum_nonoverlap_zoom, minf(required_x, required_y))
	var available := canvas.size - maximum_control_size - Vector2(48.0, 48.0)
	var extent := maximum - minimum
	var maximum_containment_zoom := minf(available.x / extent.x, available.y / extent.y)
	return {
		"minimum_nonoverlap_zoom": minimum_nonoverlap_zoom,
		"maximum_containment_zoom": maximum_containment_zoom,
	}


func _capture_connections_only(viewport: SubViewport, canvas: PassiveTreeCanvas) -> Image:
	var visibility: Dictionary = {}
	for node_id: StringName in canvas.node_ids():
		var control := canvas.node_control(node_id)
		if control != null:
			visibility[node_id] = control.visible
			control.visible = false
	await _frames(2)
	var image := viewport.get_texture().get_image()
	for node_id: StringName in visibility:
		var control := canvas.node_control(node_id)
		if control != null:
			control.visible = bool(visibility[node_id])
	await _frames(2)
	return image


func _connection_path_evidence(image: Image, from_center: Vector2, to_center: Vector2) -> Dictionary:
	var sample_count := maxi(16, ceili(from_center.distance_to(to_center)))
	var matched_samples := 0
	var current_gap := 0
	var maximum_gap := 0
	for sample_index: int in range(sample_count + 1):
		var weight := float(sample_index) / float(sample_count)
		var point := from_center.lerp(to_center, weight)
		if _patch_contains_color(image, point, CONNECTION_COLOR, CONNECTION_PIXEL_TOLERANCE, 2):
			matched_samples += 1
			current_gap = 0
		else:
			current_gap += 1
			maximum_gap = maxi(maximum_gap, current_gap)
	var total_samples := sample_count + 1
	return {
		"match_ratio": float(matched_samples) / float(total_samples),
		"matched_samples": matched_samples,
		"maximum_gap": maximum_gap,
		"total_samples": total_samples,
	}


func _full_label_renderability(canvas: PassiveTreeCanvas, charter_id: StringName) -> Dictionary:
	var control := canvas.node_control(charter_id)
	if control == null:
		return {"fits": false, "overlaps": ["missing_control"]}
	var font := control.get_theme_font(&"font")
	var font_size := control.get_theme_font_size(&"font_size")
	var available_rect := control.get_global_rect()
	var stylebox := control.get_theme_stylebox(&"normal")
	if stylebox != null:
		var left_margin := stylebox.get_content_margin(SIDE_LEFT)
		var top_margin := stylebox.get_content_margin(SIDE_TOP)
		var right_margin := stylebox.get_content_margin(SIDE_RIGHT)
		var bottom_margin := stylebox.get_content_margin(SIDE_BOTTOM)
		available_rect.position += Vector2(left_margin, top_margin)
		available_rect.size -= Vector2(left_margin + right_margin, top_margin + bottom_margin)
	var wrapped_layout := _wrapped_text_layout(control.text, font, font_size, available_rect)
	var full_text_rect := wrapped_layout.get("bounds", Rect2()) as Rect2
	var text_size := full_text_rect.size
	var overlaps: Array[String] = []
	for node_id: StringName in canvas.node_ids():
		if node_id == charter_id:
			continue
		var other := canvas.node_control(node_id)
		if other == null or full_text_rect.intersects(other.get_global_rect()):
			overlaps.append(String(node_id))
	return {
		"available_rect": available_rect,
		"fits": _rect_contains_rect(available_rect, full_text_rect),
		"font": font,
		"font_size": font_size,
		"full_text_rect": full_text_rect,
		"overlaps": overlaps,
		"text_size": text_size,
		"word_regions": wrapped_layout.get("word_regions", []) as Array,
	}


func _wrapped_text_layout(text: String, font: Font, font_size: int, available_rect: Rect2) -> Dictionary:
	var lines: Array = []
	var current_words: Array[String] = []
	for word: String in text.split(" ", false):
		var candidate_words := current_words.duplicate()
		candidate_words.append(word)
		var candidate := " ".join(candidate_words)
		if not current_words.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > available_rect.size.x:
			lines.append(current_words)
			current_words = [word]
		else:
			current_words = candidate_words
	if not current_words.is_empty():
		lines.append(current_words)
	var line_height := font.get_height(font_size)
	var total_height := line_height * float(lines.size())
	var line_y := available_rect.get_center().y - total_height * 0.5
	var bounds := Rect2()
	var has_bounds := false
	var word_regions: Array[Dictionary] = []
	for line_words_value: Variant in lines:
		var line_words := line_words_value as Array
		var line_text := " ".join(line_words)
		var line_width := font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var line_x := available_rect.get_center().x - line_width * 0.5
		var line_rect := Rect2(Vector2(line_x, line_y), Vector2(line_width, line_height))
		bounds = line_rect if not has_bounds else bounds.merge(line_rect)
		has_bounds = true
		var prefix := ""
		for word_value: Variant in line_words:
			var word := String(word_value)
			var prefix_width := font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			var word_width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			word_regions.append({"rect": Rect2(Vector2(line_x + prefix_width, line_y), Vector2(word_width, line_height)), "word": word})
			prefix += "%s " % word
		line_y += line_height
	return {"bounds": bounds, "word_regions": word_regions}


func _label_avoids_all_other_controls(canvas: PassiveTreeCanvas, charter_id: StringName, full_text_rect: Rect2) -> bool:
	for node_id: StringName in canvas.node_ids():
		if node_id == charter_id:
			continue
		var other := canvas.node_control(node_id)
		if other == null or full_text_rect.intersects(other.get_global_rect()):
			return false
	return true


func _rect_contains_rect(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.5 and inner.position.y >= outer.position.y - 0.5 and inner.end.x <= outer.end.x + 0.5 and inner.end.y <= outer.end.y + 0.5


func _label_has_rendered_text(image: Image, control: PassiveTreeNodeControl, word_regions: Array) -> bool:
	var font_color := control.get_theme_color(&"font_color")
	var outline_color := control.get_theme_color(&"font_outline_color")
	for region_value: Variant in word_regions:
		var region := region_value as Dictionary
		var word := String(region.get("word", ""))
		var word_rect := region.get("rect", Rect2()) as Rect2
		if word.is_empty() or _rect_theme_pixel_count(image, word_rect, font_color, outline_color) < maxi(8, word.length() * 2):
			return false
	return not word_regions.is_empty()


func _rect_theme_pixel_count(image: Image, rect: Rect2, font_color: Color, outline_color: Color) -> int:
	var count := 0
	var start_x := maxi(0, floori(rect.position.x))
	var end_x := mini(image.get_width(), ceili(rect.end.x))
	var start_y := maxi(0, floori(rect.position.y))
	var end_y := mini(image.get_height(), ceili(rect.end.y))
	for y: int in range(start_y, end_y):
		for x: int in range(start_x, end_x):
			var pixel := image.get_pixel(x, y)
			if _color_distance(pixel, font_color) <= LABEL_PIXEL_TOLERANCE or _color_distance(pixel, outline_color) <= LABEL_PIXEL_TOLERANCE:
				count += 1
	return count


func _patch_contains_color(image: Image, center: Vector2, target: Color, tolerance: float, radius: int) -> bool:
	var center_x := roundi(center.x)
	var center_y := roundi(center.y)
	for y: int in range(maxi(0, center_y - radius), mini(image.get_height(), center_y + radius + 1)):
		for x: int in range(maxi(0, center_x - radius), mini(image.get_width(), center_x + radius + 1)):
			if _color_distance(image.get_pixel(x, y), target) <= tolerance:
				return true
	return false


func _color_distance(left: Color, right: Color) -> float:
	return absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b)


func _image_is_nonblank(image: Image) -> bool:
	var first := image.get_pixel(0, 0)
	for y: int in range(0, image.get_height(), 24):
		for x: int in range(0, image.get_width(), 24):
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - first.r) + absf(pixel.g - first.g) + absf(pixel.b - first.b) + absf(pixel.a - first.a) > 0.03:
				return true
	return false


func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _finish(screen: PassiveTreeScreen, viewport: SubViewport) -> void:
	if screen != null and is_instance_valid(screen):
		screen.close()
	if viewport != null and is_instance_valid(viewport):
		viewport.free()
	ProfileTestSupport.remove_tree(_profile_root)
	if _failures.is_empty():
		print("CITY_TREE_V3_VISUAL_PATH: %s" % _absolute_screenshot_path)
		print("CITY_TREE_V3_VISUAL_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("CITY_TREE_V3_VISUAL_FAILURE: %s" % failure)
	print("CITY_TREE_V3_VISUAL_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
