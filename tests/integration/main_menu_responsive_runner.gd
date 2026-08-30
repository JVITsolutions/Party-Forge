extends SceneTree

const LOGICAL_SIZE := Vector2i(1920, 1080)
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const SCREENSHOT_DIR := "res://.superpowers/sdd/warehouse-presentation-activation"

var _failures: Array[String] = []
var _profile_root := ""
var _settings_path := ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_profile_root = "user://tests/main_menu_responsive_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_settings_path = "%s/party_forge_settings.cfg" % _profile_root
	ProfileTestSupport.remove_tree(_profile_root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_profile_root))
	var player_settings := PartyForgeSettings.new()
	player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	player_settings.use_city_access_snapshot = true
	var settings_error := PartyForgeSettingsStore.new().save_settings(player_settings, _settings_path)
	_assert(settings_error.is_empty(), "fixture setup: Player Mode snapshot settings save to the disposable store")
	if not settings_error.is_empty():
		await _finish(null)
		return
	var screenshot_dir_absolute := ProjectSettings.globalize_path(SCREENSHOT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(screenshot_dir_absolute)
	_assert(directory_error == OK, "fixture setup: screenshot directory is available")
	if directory_error != OK:
		await _finish(null)
		return
	var main_scene := load("res://scenes/game/main.tscn") as PackedScene
	_assert(main_scene != null, "fixture setup: composed main scene loads")
	if main_scene == null:
		await _finish(null)
		return

	root.mode = Window.MODE_WINDOWED
	root.size = WINDOW_SIZES[0]
	var main := main_scene.instantiate() as PartyForgeMain
	main.profile_root = _profile_root
	main.settings_path = _settings_path
	root.add_child(main)
	await _frames(4)

	# Fixture setup only: complete the prologue so the existing City tree and the
	# no-stash Warehouse guidance are both available for production composition.
	var created := main.profile_manager.create_profile("Warehouse Activation", 1000)
	_assert(created.ok(), "fixture setup: responsive profile is created")
	if not created.ok():
		await _finish(main)
		return
	var profile_id := created.profile.profile_id
	var completion := ProfileMutationService.new(ProfileStore.new()).complete_prologue(profile_id, "warehouse-responsive-complete", _profile_root)
	_assert(completion.ok(), "fixture setup: responsive profile completes prologue")
	if not completion.ok():
		await _finish(main)
		return
	var refresh_error := main.profile_manager.refresh_profile(profile_id)
	_assert(refresh_error.is_empty(), "fixture setup: responsive profile refreshes")
	if not refresh_error.is_empty():
		await _finish(main)
		return
	_assert(not main.active_profile().permanent_feature_unlocks.has("stash"), "fixture setup: responsive profile remains no-stash")
	var profile_bytes_before := ProfileCodec.encode(main.active_profile()).to_utf8_buffer()
	main.call(&"_refresh_main_menu_projection")
	await _frames(3)

	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var locked_dialog := main.get_node("WarehouseLockedDialog") as Node
	var backdrop := menu.get_node("Backdrop") as Control
	var title := menu.get_node("Title") as Label
	var active_profile := menu.get_node("ActiveProfile") as Label
	var status := menu.get_node("Status") as Label
	var warehouse := menu.get_node("Warehouse") as Button
	var warehouse_lock := menu.get_node("Warehouse/LockBadge") as Label
	var city_warehouse := menu.get_node("CityWarehouseHotspot") as Button
	var city_warehouse_lock := menu.get_node("CityWarehouseHotspot/LockBadge") as Label
	var actions: Array[Button] = [
		menu.get_node("PrimaryAction") as Button,
		menu.get_node("CityTree") as Button,
		warehouse,
		menu.get_node("Settings") as Button,
		menu.get_node("Quit") as Button,
		city_warehouse,
	]
	_assert(menu.layer == 5, "main menu stays on layer 5")
	_assert(int(locked_dialog.get("layer")) == 47 and int(locked_dialog.get("layer")) > menu.layer, "Warehouse locked dialog layer 47 is above the main menu")
	_assert(root.content_scale_size == LOGICAL_SIZE, "root Window retains the 1920x1080 logical canvas")
	_assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "root Window uses the project canvas_items scale path")

	var baseline_action_rects: Dictionary = {}
	for window_size: Vector2i in WINDOW_SIZES:
		var failure_count_before := _failures.size()
		root.size = window_size
		await _frames(4)
		_assert(root.size == window_size, "root Window reaches %dx%d physical pixels" % [window_size.x, window_size.y])
		var effective_scale := Vector2(root.size) / Vector2(root.content_scale_size)
		var expected_scale := float(window_size.x) / float(LOGICAL_SIZE.x)
		_assert(is_equal_approx(effective_scale.x, expected_scale) and is_equal_approx(effective_scale.y, expected_scale), "effective canvas scale is %.3fx at %dx%d actual=%s" % [expected_scale, window_size.x, window_size.y, effective_scale])
		var logical_rect := Rect2(Vector2.ZERO, Vector2(LOGICAL_SIZE))
		_assert_rect(backdrop.get_global_rect(), logical_rect, "backdrop logical canvas", window_size)
		for backdrop_part_name: String in ["Sky", "HorizonGlow", "CityMass", "ForgeTower"]:
			_assert_contained(logical_rect, backdrop.get_node(backdrop_part_name) as Control, "backdrop %s" % backdrop_part_name, window_size)
		for label: Label in [title, active_profile, status]:
			_assert_contained(logical_rect, label, label.name, window_size)
			_assert(not label.text.strip_edges().is_empty(), "%s text remains readable at %dx%d" % [label.name, window_size.x, window_size.y])
			_assert_readable(label, 18, effective_scale.y, window_size)
		_assert(active_profile.text == "Active Profile: Warehouse Activation", "active-profile text is exact at %dx%d" % [window_size.x, window_size.y])
		_assert(status.text == "Ready for your next run.", "status text is exact at %dx%d" % [window_size.x, window_size.y])
		for action: Button in actions:
			_assert(action.visible and not action.disabled, "%s remains available at %dx%d" % [action.name, window_size.x, window_size.y])
			_assert_contained(logical_rect, action, action.name, window_size)
			var rect := action.get_global_rect()
			if baseline_action_rects.has(action.name):
				_assert_rect(rect, baseline_action_rects[action.name] as Rect2, "%s normalized logical geometry" % action.name, window_size)
			else:
				baseline_action_rects[action.name] = rect
			_assert(not action.text.strip_edges().is_empty(), "%s label is nonempty at %dx%d" % [action.name, window_size.x, window_size.y])
			_assert_readable(action, 16, effective_scale.y, window_size)
		_assert(warehouse.text == "Warehouse" and city_warehouse.text == "City Warehouse", "locked Warehouse actions retain approved copy at %dx%d" % [window_size.x, window_size.y])
		for lock_badge: Label in [warehouse_lock, city_warehouse_lock]:
			_assert(lock_badge.visible and lock_badge.text == "LOCKED", "%s visibly says LOCKED at %dx%d" % [lock_badge.get_parent().name, window_size.x, window_size.y])
			_assert_contained(logical_rect, lock_badge, "%s lock badge" % lock_badge.get_parent().name, window_size)
			_assert_readable(lock_badge, 14, effective_scale.y, window_size)
		_assert_lock_copy_separated(warehouse, warehouse_lock, window_size)
		_assert_lock_copy_separated(city_warehouse, city_warehouse_lock, window_size)
		_assert(not warehouse.get_global_rect().intersects(city_warehouse.get_global_rect()), "locked Warehouse origins do not overlap at %dx%d" % [window_size.x, window_size.y])

		menu.open(warehouse)
		await _frames(2)
		_assert_focus(warehouse, "locked menu deterministic Warehouse focus at %dx%d" % [window_size.x, window_size.y])
		var menu_path := SCREENSHOT_DIR.path_join("locked-menu-%dx%d.png" % [window_size.x, window_size.y])
		var menu_image := await _capture_root(menu_path, window_size, "locked main menu")
		warehouse.pressed.emit()
		await _frames(3)
		_assert(bool(locked_dialog.call("is_open")) and menu.is_open(), "locked dialog composes above the menu at %dx%d" % [window_size.x, window_size.y])
		_assert_locked_dialog_layout(locked_dialog, logical_rect, effective_scale.y, window_size)
		var dialog_path := SCREENSHOT_DIR.path_join("locked-dialog-%dx%d.png" % [window_size.x, window_size.y])
		var dialog_image := await _capture_root(dialog_path, window_size, "locked Warehouse dialog")
		_assert(menu_image != null and dialog_image != null and menu_image.get_data() != dialog_image.get_data(), "locked menu and dialog frames differ at %dx%d" % [window_size.x, window_size.y])
		locked_dialog.call("close", true)
		await _frames(2)
		_assert_focus(warehouse, "locked dialog restores Warehouse focus at %dx%d" % [window_size.x, window_size.y])
		if _failures.size() == failure_count_before:
			print("MAIN_MENU_RESPONSIVE_SIZE_PASS physical=%dx%d logical=%dx%d scale=%.3f menu=%s dialog=%s" % [window_size.x, window_size.y, LOGICAL_SIZE.x, LOGICAL_SIZE.y, expected_scale, menu_path, dialog_path])

	root.size = LOGICAL_SIZE
	var accessible_settings := player_settings.copy()
	accessible_settings.high_contrast = true
	accessible_settings.reduced_motion = true
	_assert(PartyForgeSettingsStore.new().save_settings(accessible_settings, _settings_path).is_empty(), "high-contrast/reduced-motion settings save to the existing disposable fields")
	main.call(&"_on_settings_applied", accessible_settings)
	await _frames(3)
	_assert(main.saved_settings.high_contrast and main.saved_settings.reduced_motion and main.saved_settings.use_city_access_snapshot, "1920x1080 pass composes existing high-contrast, reduced-motion, and snapshot settings")
	_assert(menu.projection().reduced_motion and backdrop.modulate == Color.WHITE, "reduced-motion menu reaches its deterministic interactive frame without transition")
	menu.open(warehouse)
	await _frames(2)
	warehouse.pressed.emit()
	await _frames(3)
	_assert_locked_dialog_layout(locked_dialog, Rect2(Vector2.ZERO, Vector2(LOGICAL_SIZE)), 1.0, LOGICAL_SIZE)
	locked_dialog.call("close", true)
	await _frames(2)
	_assert_focus(warehouse, "high-contrast/reduced-motion locked flow restores Warehouse focus")
	_assert(ProfileCodec.encode(main.active_profile()).to_utf8_buffer() == profile_bytes_before, "responsive locked-menu and dialog composition preserves exact ProfileCodec bytes")

	await _finish(main)


func _capture_root(path: String, expected_size: Vector2i, label: String) -> Image:
	await _frames(3)
	var absolute_path := ProjectSettings.globalize_path(path)
	if DisplayServer.get_name() == "headless":
		var retained := Image.load_from_file(absolute_path) if FileAccess.file_exists(path) else null
		_assert(retained != null, "%s headless validation loads the freshly rendered evidence at %dx%d" % [label, expected_size.x, expected_size.y])
		if retained == null:
			return null
		_assert(retained.get_size() == expected_size, "%s retained screenshot dimensions match %dx%d actual=%s" % [label, expected_size.x, expected_size.y, retained.get_size()])
		_assert(_image_is_nonblank(retained), "%s retained screenshot is nonblank at %dx%d" % [label, expected_size.x, expected_size.y])
		return retained
	var image := root.get_texture().get_image()
	_assert(image != null, "%s renderer provides root pixels at %dx%d" % [label, expected_size.x, expected_size.y])
	if image == null:
		return null
	_assert(image.get_size() == expected_size, "%s screenshot dimensions match %dx%d actual=%s" % [label, expected_size.x, expected_size.y, image.get_size()])
	_assert(_image_is_nonblank(image), "%s screenshot is nonblank at %dx%d" % [label, expected_size.x, expected_size.y])
	_assert(image.save_png(absolute_path) == OK, "%s screenshot saves at %dx%d" % [label, expected_size.x, expected_size.y])
	return image


func _image_is_nonblank(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var colors: Dictionary = {}
	var opaque_samples := 0
	var step_x := maxi(image.get_width() / 16, 1)
	var step_y := maxi(image.get_height() / 9, 1)
	for y: int in range(0, image.get_height(), step_y):
		for x: int in range(0, image.get_width(), step_x):
			var color := image.get_pixel(x, y)
			colors[color] = true
			if color.a > 0.9:
				opaque_samples += 1
	return colors.size() >= 3 and opaque_samples >= 12


func _assert_locked_dialog_layout(dialog: Node, logical_rect: Rect2, physical_scale: float, window_size: Vector2i) -> void:
	var overlay := dialog.get_node("Overlay") as Control
	var frame := dialog.get_node("Overlay/Frame") as Control
	var lock_insignia := dialog.get_node("Overlay/Frame/Layout/LockInsignia") as Label
	var title := dialog.get_node("Overlay/Frame/Layout/Title") as Label
	var requirement := dialog.get_node("Overlay/Frame/Layout/Requirement") as Label
	var body := dialog.get_node("Overlay/Frame/Layout/Body") as Label
	var actions := dialog.get_node("Overlay/Frame/Layout/Actions") as Control
	var view_city := dialog.get_node("Overlay/Frame/Layout/Actions/ViewCityTree") as Button
	var back := dialog.get_node("Overlay/Frame/Layout/Actions/Back") as Button
	_assert_rect(overlay.get_global_rect(), logical_rect, "locked-dialog overlay logical canvas", window_size)
	_assert_contained(logical_rect, frame, "locked-dialog frame", window_size)
	var frame_rect := frame.get_global_rect().grow(1.0)
	for control: Control in [lock_insignia, title, requirement, body, actions, view_city, back]:
		_assert_contained(frame_rect, control, "locked-dialog %s" % control.name, window_size)
	_assert(lock_insignia.text == "LOCKED" and title.text == "WAREHOUSE LOCKED", "locked-dialog hierarchy exposes exact lock and title copy at %dx%d" % [window_size.x, window_size.y])
	_assert(requirement.text == "Requires Stash Access", "locked-dialog requirement copy is exact at %dx%d" % [window_size.x, window_size.y])
	_assert(body.text == "Unlock Stash Access in the City tree to open permanent storage.", "locked-dialog guidance copy is exact at %dx%d" % [window_size.x, window_size.y])
	_assert(view_city.text == "View City Tree" and back.text == "Back", "locked-dialog actions retain approved copy at %dx%d" % [window_size.x, window_size.y])
	for control: Control in [lock_insignia, title, requirement, body, view_city, back]:
		_assert_readable(control, 18, physical_scale, window_size)
	_assert(not view_city.get_global_rect().intersects(back.get_global_rect()), "locked-dialog actions do not overlap at %dx%d" % [window_size.x, window_size.y])
	var vertical_controls: Array[Control] = [lock_insignia, title, requirement, body, actions]
	for index: int in range(vertical_controls.size() - 1):
		_assert(not vertical_controls[index].get_global_rect().intersects(vertical_controls[index + 1].get_global_rect()), "locked-dialog %s and %s do not overlap at %dx%d" % [vertical_controls[index].name, vertical_controls[index + 1].name, window_size.x, window_size.y])
	_assert_focus(view_city, "locked-dialog deterministic View City Tree focus at %dx%d" % [window_size.x, window_size.y])


func _assert_readable(control: Control, minimum_logical_size: int, physical_scale: float, window_size: Vector2i) -> void:
	var logical_font_size := control.get_theme_font_size(&"font_size")
	var text := ""
	if control is Label:
		text = (control as Label).text
	elif control is Button:
		text = (control as Button).text
	_assert(not text.strip_edges().is_empty(), "%s has readable text at %dx%d" % [control.name, window_size.x, window_size.y])
	_assert(logical_font_size >= minimum_logical_size, "%s meets minimum logical font size at %dx%d actual=%d minimum=%d" % [control.name, window_size.x, window_size.y, logical_font_size, minimum_logical_size])
	_assert(float(logical_font_size) * physical_scale >= float(minimum_logical_size) * physical_scale, "%s scales to readable physical pixels at %dx%d" % [control.name, window_size.x, window_size.y])


func _assert_focus(expected: Control, label: String) -> void:
	var actual := root.gui_get_focus_owner()
	_assert(actual == expected, "%s expected=%s actual=%s" % [label, expected.get_path(), actual.get_path() if actual != null else NodePath()])
	if actual != null:
		_assert(actual.is_visible_in_tree() and actual.focus_mode != Control.FOCUS_NONE, "%s owns visible enabled focus" % label)
		if actual is BaseButton:
			_assert(not (actual as BaseButton).disabled, "%s focus owner is not disabled" % label)


func _assert_lock_copy_separated(button: Button, badge: Label, window_size: Vector2i) -> void:
	var button_font := button.get_theme_font(&"font")
	var button_font_size := button.get_theme_font_size(&"font_size")
	var button_text_size := button_font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, button_font_size)
	var button_text_rect := Rect2(button.get_global_rect().get_center() - button_text_size * 0.5, button_text_size)
	var badge_font := badge.get_theme_font(&"font")
	var badge_font_size := badge.get_theme_font_size(&"font_size")
	var badge_text_size := badge_font.get_string_size(badge.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, badge_font_size)
	var badge_rect := badge.get_global_rect()
	var badge_text_position := Vector2(badge_rect.end.x - badge_text_size.x, badge_rect.get_center().y - badge_text_size.y * 0.5)
	var badge_text_rect := Rect2(badge_text_position, badge_text_size)
	_assert(not button_text_rect.intersects(badge_text_rect), "%s label and LOCKED badge do not overlap at %dx%d label=%s badge=%s" % [button.name, window_size.x, window_size.y, button_text_rect, badge_text_rect])


func _assert_contained(outer: Rect2, control: Control, label: String, window_size: Vector2i) -> void:
	_assert(control.is_visible_in_tree(), "%s is visible at %dx%d" % [label, window_size.x, window_size.y])
	_assert(control.size.x > 0.0 and control.size.y > 0.0, "%s has positive geometry at %dx%d" % [label, window_size.x, window_size.y])
	_assert(outer.grow(1.0).encloses(control.get_global_rect()), "%s is contained at %dx%d actual=%s" % [label, window_size.x, window_size.y, control.get_global_rect()])


func _assert_rect(actual: Rect2, expected: Rect2, label: String, window_size: Vector2i) -> void:
	_assert(actual.position.distance_to(expected.position) <= 1.0 and actual.size.distance_to(expected.size) <= 1.0, "%s matches at %dx%d expected=%s actual=%s" % [label, window_size.x, window_size.y, expected, actual])


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _finish(main: PartyForgeMain) -> void:
	paused = false
	if main != null and is_instance_valid(main):
		main.free()
	ProfileTestSupport.remove_tree(_profile_root)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_profile_root)):
		_failures.append("disposable responsive profile root was not removed")
	if _failures.is_empty():
		print("MAIN_MENU_RESPONSIVE_SUMMARY: PASS (%d root-window sizes)" % WINDOW_SIZES.size())
		quit(0)
		return
	for failure: String in _failures:
		push_error("MAIN_MENU_RESPONSIVE_FAILURE: %s" % failure)
	print("MAIN_MENU_RESPONSIVE_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
