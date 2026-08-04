extends SceneTree

const LOGICAL_SIZE := Vector2i(1920, 1080)
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const SCREENSHOT_DIR := "res://.superpowers/sdd/task-8-screenshots"

var _failures: Array[String] = []
var _profile_root := ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_profile_root = "user://tests/main_menu_responsive_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_profile_root)
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
	root.add_child(main)
	await _frames(4)

	# Fixture setup only: durable completed profile plus saved-mode projection make
	# every production menu action visible without testing mutations in this runner.
	var created := main.profile_manager.create_profile("Responsive Task 8", 1000)
	_assert(created.ok(), "fixture setup: responsive profile is created")
	if not created.ok():
		await _finish(main)
		return
	var profile_id := created.profile.profile_id
	var completion := ProfileMutationService.new(ProfileStore.new()).complete_prologue(profile_id, "task-8-responsive-complete", _profile_root)
	_assert(completion.ok(), "fixture setup: responsive profile completes prologue")
	if not completion.ok():
		await _finish(main)
		return
	var refresh_error := main.profile_manager.refresh_profile(profile_id)
	_assert(refresh_error.is_empty(), "fixture setup: responsive profile refreshes")
	if not refresh_error.is_empty():
		await _finish(main)
		return
	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	main.call(&"_on_settings_applied", developer_settings)
	main.developer_mode_badge.configure(RunRulesSnapshot.from_settings(developer_settings))
	await _frames(3)

	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	var passive_tree := main.get_node("PassiveTreeScreen") as PassiveTreeScreen
	var badge := main.get_node("DeveloperModeBadge") as DeveloperModeBadge
	var backdrop := menu.get_node("Backdrop") as Control
	var title := menu.get_node("Title") as Label
	var active_profile := menu.get_node("ActiveProfile") as Label
	var status := menu.get_node("Status") as Label
	var actions: Array[Button] = [
		menu.get_node("PrimaryAction") as Button,
		menu.get_node("CityTree") as Button,
		menu.get_node("DeveloperQuickStart") as Button,
		menu.get_node("Settings") as Button,
		menu.get_node("Quit") as Button,
	]
	_assert(menu.layer == 5, "main menu stays on layer 5")
	_assert(settings.layer == 10 and settings.layer > menu.layer, "Settings layer 10 is above the main menu")
	_assert(passive_tree.layer == 12 and passive_tree.layer > settings.layer, "passive tree layer 12 is above Settings and main menu")
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
			var physical_font_size := float(label.get_theme_font_size(&"font_size")) * effective_scale.y
			_assert(physical_font_size >= 18.0 * expected_scale, "%s scales to readable physical pixels at %dx%d actual=%.1f" % [label.name, window_size.x, window_size.y, physical_font_size])
		_assert(active_profile.text == "Active Profile: Responsive Task 8", "active-profile text is exact at %dx%d" % [window_size.x, window_size.y])
		_assert(status.text == "Ready for your next run.", "status text is exact at %dx%d" % [window_size.x, window_size.y])
		for action: Button in actions:
			_assert(action.visible and not action.disabled, "%s remains available at %dx%d" % [action.name, window_size.x, window_size.y])
			_assert_contained(logical_rect, action, action.name, window_size)
			var rect := action.get_global_rect()
			if baseline_action_rects.has(action.name):
				_assert_rect(rect, baseline_action_rects[action.name] as Rect2, "%s normalized logical geometry" % action.name, window_size)
			else:
				baseline_action_rects[action.name] = rect
			var physical_font_size := float(action.get_theme_font_size(&"font_size")) * effective_scale.y
			_assert(not action.text.strip_edges().is_empty() and physical_font_size >= 18.0 * expected_scale, "%s label scales to readable physical pixels at %dx%d" % [action.name, window_size.x, window_size.y])
		var badge_margin := badge.get_node("Anchor/Margin") as Control
		var badge_label := badge.get_node("Anchor/Margin/Label") as Label
		_assert(badge.visible and badge_label.text.contains("DEV MODE"), "Developer badge is readable at %dx%d" % [window_size.x, window_size.y])
		_assert_contained(logical_rect, badge_margin, "Developer badge", window_size)
		for action: Button in actions:
			_assert(not badge_margin.get_global_rect().intersects(action.get_global_rect()), "Developer badge does not overlap %s at %dx%d" % [action.name, window_size.x, window_size.y])

		menu.open(actions[0])
		var screenshot_path := SCREENSHOT_DIR.path_join("main-menu-%dx%d.png" % [window_size.x, window_size.y])
		var menu_image := await _capture_root(screenshot_path, window_size, "main menu")
		if window_size == LOGICAL_SIZE and menu_image != null:
			settings.open(actions[3])
			await _frames(3)
			_assert(settings.is_open() and menu.is_open(), "Settings is visibly composed above the menu")
			_assert_rect((settings.get_node("Overlay") as Control).get_global_rect(), logical_rect, "Settings overlay logical canvas", window_size)
			var settings_image := await _capture_root(SCREENSHOT_DIR.path_join("settings-1920x1080.png"), window_size, "Settings layer")
			_assert(settings_image != null and settings_image.get_data() != menu_image.get_data(), "rendered Settings frame differs from the menu frame")
			settings.close()
			passive_tree.configure(main.passive_tree_definition, main.profile_manager, main.passive_tree_mutations, main.passive_tree_view_model, true, _profile_root)
			passive_tree.open(actions[1])
			await _frames(3)
			_assert(passive_tree.is_open() and menu.is_open(), "passive tree is visibly composed above the menu")
			_assert_rect((passive_tree.get_node("Overlay") as Control).get_global_rect(), logical_rect, "passive-tree overlay logical canvas", window_size)
			var city_image := await _capture_root(SCREENSHOT_DIR.path_join("city-1920x1080.png"), window_size, "passive-tree layer")
			_assert(city_image != null and city_image.get_data() != menu_image.get_data(), "rendered passive-tree frame differs from the menu frame")
			passive_tree.close()
			menu.open(actions[0])
		if _failures.size() == failure_count_before:
			print("MAIN_MENU_RESPONSIVE_SIZE_PASS physical=%dx%d logical=%dx%d scale=%.3f screenshot=%s" % [window_size.x, window_size.y, LOGICAL_SIZE.x, LOGICAL_SIZE.y, expected_scale, screenshot_path])

	await _finish(main)


func _capture_root(path: String, expected_size: Vector2i, label: String) -> Image:
	await _frames(3)
	var image := root.get_texture().get_image()
	_assert(image != null, "%s renderer provides root pixels at %dx%d" % [label, expected_size.x, expected_size.y])
	if image == null:
		return null
	_assert(image.get_size() == expected_size, "%s screenshot dimensions match %dx%d actual=%s" % [label, expected_size.x, expected_size.y, image.get_size()])
	_assert(_image_is_nonblank(image), "%s screenshot is nonblank at %dx%d" % [label, expected_size.x, expected_size.y])
	_assert(image.save_png(ProjectSettings.globalize_path(path)) == OK, "%s screenshot saves at %dx%d" % [label, expected_size.x, expected_size.y])
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
