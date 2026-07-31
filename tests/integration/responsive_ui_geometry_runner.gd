extends SceneTree

const ResponsiveGeometry := preload("res://tests/support/responsive_geometry.gd")
const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = VIEWPORT_SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var settings := (load("res://scenes/ui/settings/settings_screen.tscn") as PackedScene).instantiate() as SettingsScreen
	settings.custom_viewport = viewport
	viewport.add_child(settings)
	settings.visible = true
	var badge := (load("res://scenes/ui/developer_mode_badge.tscn") as PackedScene).instantiate() as DeveloperModeBadge
	badge.custom_viewport = viewport
	viewport.add_child(badge)
	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	developer_settings.unlock_all_implemented_content = true
	developer_settings.god_mode = true
	developer_settings.party_capacity_override = 12
	developer_settings.enemy_density_percent = 500
	badge.configure(RunRulesSnapshot.from_settings(developer_settings))
	await _wait_for_layout()

	var overlay := settings.get_node("Overlay") as Control
	var frame := settings.get_node("Overlay/Frame") as Control
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var controls_scroll := settings.get_node("Overlay/Frame/Layout/Tabs/Controls/Layout/Scroll") as ScrollContainer
	var additional := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as Control
	var reset := additional.get_node("Layout/ResetDeveloperOptions") as Button
	var apply := additional.get_node("Layout/ApplyAndReturn") as Button
	var cancel := additional.get_node("Layout/Cancel") as Button
	var notice := settings.get_node("Overlay/Frame/Layout/NextRunNotice") as Label
	var status := settings.get_node("Overlay/Frame/Layout/Status") as Label
	var badge_anchor := badge.get_node("Anchor") as Control
	var badge_margin := badge.get_node("Anchor/Margin") as MarginContainer
	var badge_label := badge.get_node("Anchor/Margin/Label") as Label

	for viewport_size: Vector2i in VIEWPORT_SIZES:
		var failure_count_before := _failures.size()
		viewport.size = viewport_size
		await _wait_for_layout()
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_assert_rect_near(overlay.get_global_rect(), viewport_rect, "Settings overlay", viewport_size)
		var expected_frame := Rect2(Vector2(48.0, 36.0), Vector2(viewport_size) - Vector2(96.0, 72.0))
		_assert_rect_near(frame.get_global_rect(), expected_frame, "Settings frame", viewport_size)

		tabs.current_tab = 1
		await _wait_for_layout()
		_assert_visible_contained(tabs.get_tab_bar(), expected_frame, "Settings tab row", viewport_size)
		_assert_visible_contained(controls_scroll, expected_frame, "Controls scroll", viewport_size)

		tabs.current_tab = 4
		await _wait_for_layout()
		for action: Button in [reset, apply, cancel]:
			_assert_visible_contained(action, expected_frame, "Additional Settings %s" % action.name, viewport_size)
		_assert_visible_contained(notice, expected_frame, "Settings notice", viewport_size)
		_assert_visible_contained(status, expected_frame, "Settings status", viewport_size)

		_assert_rect_near(badge_anchor.get_global_rect(), viewport_rect, "badge anchor", viewport_size)
		var expected_badge := Rect2(Vector2(float(viewport_size.x) - 720.0, 16.0), Vector2(704.0, 56.0))
		_assert_rect_near(badge_margin.get_global_rect(), expected_badge, "badge margin", viewport_size)
		_assert_visible_contained(badge_label, expected_badge, "badge label", viewport_size)
		if _failures.size() == failure_count_before:
			print("RESPONSIVE_GEOMETRY_SIZE_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])

	viewport.free()
	if _failures.is_empty():
		print("RESPONSIVE_GEOMETRY_SUMMARY: PASS (%d sizes)" % VIEWPORT_SIZES.size())
		quit(0)
		return
	for failure: String in _failures:
		push_error("RESPONSIVE_GEOMETRY_FAILURE: %s" % failure)
	print("RESPONSIVE_GEOMETRY_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _assert_visible_contained(control: Control, outer: Rect2, label: String, viewport_size: Vector2i) -> void:
	var rect := control.get_global_rect()
	if not control.is_visible_in_tree():
		_failures.append("%s is not visible at %dx%d" % [label, viewport_size.x, viewport_size.y])
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_failures.append("%s has non-positive post-layout size at %dx%d: %s" % [label, viewport_size.x, viewport_size.y, rect])
	if not ResponsiveGeometry.contains(outer, rect):
		_failures.append("%s overflows at %dx%d: outer=%s actual=%s" % [label, viewport_size.x, viewport_size.y, outer, rect])


func _assert_rect_near(actual: Rect2, expected: Rect2, label: String, viewport_size: Vector2i) -> void:
	if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
		_failures.append("%s geometry differs at %dx%d: expected=%s actual=%s" % [label, viewport_size.x, viewport_size.y, expected, actual])
