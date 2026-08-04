extends SceneTree

const VIEWPORT_SIZES: Array[Vector2i] = [
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
	_assert(DirAccess.make_dir_recursive_absolute(screenshot_dir_absolute) == OK, "screenshot directory is available")
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.size = VIEWPORT_SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = _profile_root
	viewport.add_child(main)
	await _frames(3)

	var created := main.profile_manager.create_profile("Responsive Task 8", 1000)
	_assert(created.ok(), "responsive profile is created")
	if not created.ok():
		await _finish(viewport)
		return
	var profile_id := created.profile.profile_id
	var completion := ProfileMutationService.new(ProfileStore.new()).complete_prologue(profile_id, "task-8-responsive-complete", _profile_root)
	_assert(completion.ok(), "responsive profile completes prologue through production mutation")
	_assert(main.profile_manager.refresh_profile(profile_id).is_empty(), "responsive profile refreshes")
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
	_assert(settings.layer == 10 and settings.layer > menu.layer, "Settings layer 10 renders above the main menu")
	_assert(passive_tree.layer == 12 and passive_tree.layer > settings.layer, "passive tree layer 12 renders above Settings and main menu")
	settings.open(actions[3])
	await _frames(2)
	_assert(settings.is_open() and menu.is_open(), "Settings is visibly composed above the open main menu")
	settings.close()
	passive_tree.configure(main.passive_tree_definition, main.profile_manager, main.passive_tree_mutations, main.passive_tree_view_model, true, _profile_root)
	passive_tree.open(actions[1])
	await _frames(2)
	_assert(passive_tree.is_open() and menu.is_open(), "passive tree is visibly composed at layer 12 above the main menu")
	passive_tree.close()
	menu.open(actions[0])
	await _frames(2)

	for viewport_size: Vector2i in VIEWPORT_SIZES:
		var failure_count_before := _failures.size()
		viewport.size = viewport_size
		await _frames(3)
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_assert_rect(backdrop.get_global_rect(), viewport_rect, "backdrop", viewport_size)
		for backdrop_part_name: String in ["Sky", "HorizonGlow", "CityMass", "ForgeTower"]:
			_assert_contained(viewport_rect, backdrop.get_node(backdrop_part_name) as Control, "backdrop %s" % backdrop_part_name, viewport_size)
		for label: Label in [title, active_profile, status]:
			_assert_contained(viewport_rect, label, label.name, viewport_size)
			_assert(not label.text.strip_edges().is_empty(), "%s text remains readable at %dx%d" % [label.name, viewport_size.x, viewport_size.y])
			_assert(label.get_theme_font_size(&"font_size") >= 18, "%s retains readable font size at %dx%d" % [label.name, viewport_size.x, viewport_size.y])
		_assert(active_profile.text == "Active Profile: Responsive Task 8", "active-profile text is exact at %dx%d" % [viewport_size.x, viewport_size.y])
		_assert(status.text == "Ready for your next run.", "status text is exact at %dx%d" % [viewport_size.x, viewport_size.y])
		for action: Button in actions:
			_assert(action.visible and not action.disabled, "%s remains an available menu action at %dx%d" % [action.name, viewport_size.x, viewport_size.y])
			_assert_contained(viewport_rect, action, action.name, viewport_size)
			_assert(not action.text.strip_edges().is_empty() and action.get_theme_font_size(&"font_size") >= 18, "%s label remains readable at %dx%d" % [action.name, viewport_size.x, viewport_size.y])
		var badge_margin := badge.get_node("Anchor/Margin") as Control
		var badge_label := badge.get_node("Anchor/Margin/Label") as Label
		_assert(badge.visible and badge_label.text.contains("DEV MODE"), "Developer badge is readable at %dx%d" % [viewport_size.x, viewport_size.y])
		_assert_contained(viewport_rect, badge_margin, "Developer badge", viewport_size)
		for action: Button in actions:
			_assert(not badge_margin.get_global_rect().intersects(action.get_global_rect()), "Developer badge does not overlap %s at %dx%d" % [action.name, viewport_size.x, viewport_size.y])
		var screenshot_path := SCREENSHOT_DIR.path_join("main-menu-%dx%d.png" % [viewport_size.x, viewport_size.y])
		await _frames(2)
		var image := viewport.get_texture().get_image()
		_assert(image != null, "renderer provides screenshot pixels at %dx%d" % [viewport_size.x, viewport_size.y])
		if image == null:
			continue
		_assert(image.get_size() == viewport_size, "screenshot dimensions match %dx%d" % [viewport_size.x, viewport_size.y])
		_assert(_image_is_nonblank(image), "screenshot is nonblank at %dx%d" % [viewport_size.x, viewport_size.y])
		_assert(image.save_png(ProjectSettings.globalize_path(screenshot_path)) == OK, "screenshot saves at %dx%d" % [viewport_size.x, viewport_size.y])
		if _failures.size() == failure_count_before:
			print("MAIN_MENU_RESPONSIVE_SIZE_PASS size=%dx%d screenshot=%s" % [viewport_size.x, viewport_size.y, screenshot_path])

	await _finish(viewport)


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


func _assert_contained(outer: Rect2, control: Control, label: String, viewport_size: Vector2i) -> void:
	_assert(control.is_visible_in_tree(), "%s is visible at %dx%d" % [label, viewport_size.x, viewport_size.y])
	_assert(control.size.x > 0.0 and control.size.y > 0.0, "%s has positive geometry at %dx%d" % [label, viewport_size.x, viewport_size.y])
	_assert(outer.grow(1.0).encloses(control.get_global_rect()), "%s is contained at %dx%d actual=%s" % [label, viewport_size.x, viewport_size.y, control.get_global_rect()])


func _assert_rect(actual: Rect2, expected: Rect2, label: String, viewport_size: Vector2i) -> void:
	_assert(actual.position.distance_to(expected.position) <= 1.0 and actual.size.distance_to(expected.size) <= 1.0, "%s matches viewport at %dx%d actual=%s" % [label, viewport_size.x, viewport_size.y, actual])


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _finish(viewport: SubViewport) -> void:
	paused = false
	if viewport != null and is_instance_valid(viewport):
		viewport.free()
	ProfileTestSupport.remove_tree(_profile_root)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_profile_root)):
		_failures.append("disposable responsive profile root was not removed")
	if _failures.is_empty():
		print("MAIN_MENU_RESPONSIVE_SUMMARY: PASS (%d sizes)" % VIEWPORT_SIZES.size())
		quit(0)
		return
	for failure: String in _failures:
		push_error("MAIN_MENU_RESPONSIVE_FAILURE: %s" % failure)
	print("MAIN_MENU_RESPONSIVE_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
