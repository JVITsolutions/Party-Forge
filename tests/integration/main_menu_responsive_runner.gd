extends SceneTree

const LOGICAL_SIZE := Vector2i(1920, 1080)
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const SCREENSHOT_DIR := "res://.superpowers/sdd/warehouse-presentation-activation"
const MANIFEST_PATH := SCREENSHOT_DIR + "/manifest.json"
const MANIFEST_SCHEMA := "party-forge-main-menu-responsive-evidence"
const MANIFEST_VERSION := 1

var _failures: Array[String] = []
var _profile_root := ""
var _settings_path := ""
var _implementation_commit := ""
var _manifest_entries_by_path: Dictionary = {}
var _capture_evidence: Array[Dictionary] = []
var _validated_manifest_paths: Dictionary = {}


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
	_prepare_evidence_provenance()
	if not _failures.is_empty():
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
	_assert_high_contrast_dialog_style(locked_dialog)
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
		_assert(retained != null, "%s headless validation loads exact-tip manifested evidence at %dx%d" % [label, expected_size.x, expected_size.y])
		if retained == null:
			return null
		_assert(retained.get_size() == expected_size, "%s retained screenshot dimensions match %dx%d actual=%s" % [label, expected_size.x, expected_size.y, retained.get_size()])
		_assert(_image_is_nonblank(retained), "%s retained screenshot is nonblank at %dx%d" % [label, expected_size.x, expected_size.y])
		var entry: Dictionary = _manifest_entries_by_path.get(path, {}) as Dictionary
		_assert(not entry.is_empty(), "%s has an exact manifest entry" % label)
		if not entry.is_empty():
			var actual_sha := _sha256(FileAccess.get_file_as_bytes(path))
			_assert(entry["width"] == expected_size.x and entry["height"] == expected_size.y, "%s manifested dimensions match %dx%d" % [label, expected_size.x, expected_size.y])
			_assert(entry["sha256"] == actual_sha, "%s exact screenshot SHA-256 matches manifest expected=%s actual=%s" % [label, entry["sha256"], actual_sha])
			_validated_manifest_paths[path] = true
		return retained
	var image := root.get_texture().get_image()
	_assert(image != null, "%s renderer provides root pixels at %dx%d" % [label, expected_size.x, expected_size.y])
	if image == null:
		return null
	_assert(image.get_size() == expected_size, "%s screenshot dimensions match %dx%d actual=%s" % [label, expected_size.x, expected_size.y, image.get_size()])
	_assert(_image_is_nonblank(image), "%s screenshot is nonblank at %dx%d" % [label, expected_size.x, expected_size.y])
	_assert(image.save_png(absolute_path) == OK, "%s screenshot saves at %dx%d" % [label, expected_size.x, expected_size.y])
	if FileAccess.file_exists(path):
		_capture_evidence.append({
			"path": path,
			"width": expected_size.x,
			"height": expected_size.y,
			"sha256": _sha256(FileAccess.get_file_as_bytes(path)),
		})
	return image


func _prepare_evidence_provenance() -> void:
	_implementation_commit = _current_git_commit()
	_assert(_implementation_commit.length() == 40 and _is_lower_hex(_implementation_commit), "responsive evidence resolves the current exact Git commit")
	_assert(_tracked_worktree_is_clean(), "responsive evidence runs from a clean tracked exact-tip worktree")
	if _implementation_commit.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		_load_manifest()
		return
	for path: String in _expected_capture_paths() + [MANIFEST_PATH, MANIFEST_PATH + ".tmp"]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			var remove_error := DirAccess.remove_absolute(absolute_path)
			_assert(remove_error == OK, "windowed evidence removes the prior artifact before generation: %s" % path)
	for path: String in _expected_capture_paths():
		_assert(not FileAccess.file_exists(path), "windowed evidence starts without a retained capture: %s" % path)
	_assert(not FileAccess.file_exists(MANIFEST_PATH), "windowed evidence starts without a retained manifest")


func _load_manifest() -> void:
	_assert(FileAccess.file_exists(MANIFEST_PATH), "headless evidence requires an ignored exact-tip manifest")
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_assert(parsed is Dictionary, "responsive evidence manifest decodes to an object")
	if not parsed is Dictionary:
		return
	var manifest := parsed as Dictionary
	_assert(_has_exact_keys(manifest, ["schema", "version", "implementationCommit", "captures"]), "responsive evidence manifest has the exact schema keys")
	_assert(manifest.get("schema") == MANIFEST_SCHEMA and manifest.get("version") == MANIFEST_VERSION, "responsive evidence manifest schema and version are supported")
	_assert(manifest.get("implementationCommit") == _implementation_commit, "responsive evidence manifest implementation commit equals current exact tested tip expected=%s actual=%s" % [_implementation_commit, manifest.get("implementationCommit", "")])
	var captures: Variant = manifest.get("captures")
	_assert(captures is Array and (captures as Array).size() == _expected_capture_paths().size(), "responsive evidence manifest contains exactly six captures")
	if not captures is Array:
		return
	var expected_dimensions := _expected_capture_dimensions()
	for item: Variant in captures as Array:
		_assert(item is Dictionary, "responsive evidence manifest capture is an object")
		if not item is Dictionary:
			continue
		var entry := item as Dictionary
		_assert(_has_exact_keys(entry, ["path", "width", "height", "sha256"]), "responsive evidence manifest capture has exact keys")
		var path: Variant = entry.get("path")
		_assert(path is String and expected_dimensions.has(path), "responsive evidence manifest capture path is exact and expected")
		if not path is String or not expected_dimensions.has(path):
			continue
		var expected_size := expected_dimensions[path] as Vector2i
		_assert(_is_exact_integer(entry.get("width"), expected_size.x) and _is_exact_integer(entry.get("height"), expected_size.y), "responsive evidence manifest dimensions match path %s" % path)
		var sha: Variant = entry.get("sha256")
		_assert(sha is String and (sha as String).length() == 64 and _is_lower_hex(sha as String), "responsive evidence manifest SHA-256 is lowercase hex for %s" % path)
		_assert(not _manifest_entries_by_path.has(path), "responsive evidence manifest path is unique: %s" % path)
		_manifest_entries_by_path[path] = entry
	for path: String in _expected_capture_paths():
		_assert(_manifest_entries_by_path.has(path), "responsive evidence manifest includes expected path: %s" % path)


func _write_manifest() -> void:
	var expected_paths := _expected_capture_paths()
	_assert(_capture_evidence.size() == expected_paths.size(), "windowed evidence generated exactly six captures before manifest publication")
	var captured_paths: Dictionary = {}
	for entry: Dictionary in _capture_evidence:
		captured_paths[entry["path"]] = true
	for path: String in expected_paths:
		_assert(captured_paths.has(path), "windowed evidence generated expected capture before manifest publication: %s" % path)
	if not _failures.is_empty():
		return
	var document := {
		"schema": MANIFEST_SCHEMA,
		"version": MANIFEST_VERSION,
		"implementationCommit": _implementation_commit,
		"captures": _capture_evidence,
	}
	var temporary_path := MANIFEST_PATH + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	_assert(file != null, "responsive evidence opens a temporary manifest for atomic publication")
	if file == null:
		return
	file.store_string(JSON.stringify(document, "  ", false) + "\n")
	file.flush()
	file = null
	_assert(FileAccess.file_exists(temporary_path) and not FileAccess.get_file_as_bytes(temporary_path).is_empty(), "responsive evidence temporary manifest is nonempty")
	if not _failures.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(MANIFEST_PATH))
	_assert(rename_error == OK, "responsive evidence atomically publishes manifest after successful generation")
	if rename_error == OK:
		print("MAIN_MENU_RESPONSIVE_MANIFEST_OK implementation_commit=%s captures=%d path=%s" % [_implementation_commit, _capture_evidence.size(), MANIFEST_PATH])


func _current_git_commit() -> String:
	var output: Array = []
	var project_root := ProjectSettings.globalize_path("res://")
	var exit_code := OS.execute("git", ["-C", project_root, "rev-parse", "HEAD"], output, true)
	if exit_code != 0 or output.is_empty():
		return ""
	return String(output[0]).strip_edges()


func _tracked_worktree_is_clean() -> bool:
	var output: Array = []
	var project_root := ProjectSettings.globalize_path("res://")
	var exit_code := OS.execute("git", ["-C", project_root, "status", "--porcelain=v1", "--untracked-files=no"], output, true)
	if exit_code != 0:
		return false
	var combined := ""
	for line: Variant in output:
		combined += String(line)
	return combined.strip_edges().is_empty()


func _expected_capture_paths() -> Array[String]:
	var paths: Array[String] = []
	for size: Vector2i in WINDOW_SIZES:
		paths.append(SCREENSHOT_DIR.path_join("locked-menu-%dx%d.png" % [size.x, size.y]))
		paths.append(SCREENSHOT_DIR.path_join("locked-dialog-%dx%d.png" % [size.x, size.y]))
	return paths


func _expected_capture_dimensions() -> Dictionary:
	var dimensions: Dictionary = {}
	for size: Vector2i in WINDOW_SIZES:
		dimensions[SCREENSHOT_DIR.path_join("locked-menu-%dx%d.png" % [size.x, size.y])] = size
		dimensions[SCREENSHOT_DIR.path_join("locked-dialog-%dx%d.png" % [size.x, size.y])] = size
	return dimensions


func _has_exact_keys(dictionary: Dictionary, expected: Array[String]) -> bool:
	if dictionary.size() != expected.size():
		return false
	for key: String in expected:
		if not dictionary.has(key):
			return false
	return true


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _is_lower_hex(value: String) -> bool:
	for character: String in value:
		if not (character >= "0" and character <= "9") and not (character >= "a" and character <= "f"):
			return false
	return not value.is_empty()


func _is_exact_integer(value: Variant, expected: int) -> bool:
	if typeof(value) == TYPE_INT:
		return value == expected
	if typeof(value) == TYPE_FLOAT:
		var numeric := value as float
		return is_finite(numeric) and numeric == float(expected) and floorf(numeric) == numeric
	return false


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


func _assert_high_contrast_dialog_style(dialog: Node) -> void:
	var frame := dialog.get_node("Overlay/Frame") as PanelContainer
	var title := dialog.get_node("Overlay/Frame/Layout/Title") as Label
	var body := dialog.get_node("Overlay/Frame/Layout/Body") as Label
	var view_city := dialog.get_node("Overlay/Frame/Layout/Actions/ViewCityTree") as Button
	var frame_style := frame.get_theme_stylebox(&"panel")
	var button_style := view_city.get_theme_stylebox(&"normal")
	_assert(frame_style is StyleBoxFlat, "high-contrast dialog resolves a concrete frame background style")
	_assert(button_style is StyleBoxFlat, "high-contrast dialog resolves a concrete primary-action background style")
	if frame_style is StyleBoxFlat:
		var frame_background := (frame_style as StyleBoxFlat).bg_color
		_assert(_contrast_ratio(title.get_theme_color(&"font_color"), frame_background) >= 7.0, "high-contrast dialog title has at least 7:1 resolved style contrast")
		_assert(_contrast_ratio(body.get_theme_color(&"font_color"), frame_background) >= 7.0, "high-contrast dialog body has at least 7:1 resolved style contrast")
	if button_style is StyleBoxFlat:
		var button_background := (button_style as StyleBoxFlat).bg_color
		_assert(_contrast_ratio(view_city.get_theme_color(&"font_color"), button_background) >= 7.0, "high-contrast dialog primary action has at least 7:1 resolved style contrast")


func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	return (maxf(first_luminance, second_luminance) + 0.05) / (minf(first_luminance, second_luminance) + 0.05)


func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) + 0.7152 * _linear_channel(color.g) + 0.0722 * _linear_channel(color.b)


func _linear_channel(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)


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
		if DisplayServer.get_name() == "headless":
			_assert(_validated_manifest_paths.size() == _expected_capture_paths().size(), "headless evidence validates all six manifested captures")
			if _failures.is_empty():
				print("MAIN_MENU_RESPONSIVE_MANIFEST_OK implementation_commit=%s captures=%d path=%s" % [_implementation_commit, _validated_manifest_paths.size(), MANIFEST_PATH])
		else:
			_write_manifest()
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
