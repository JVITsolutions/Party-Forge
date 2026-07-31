extends RefCounted

const VIEWPORT_SIZES := [
	Vector2(1280.0, 720.0),
	Vector2(1920.0, 1080.0),
	Vector2(2560.0, 1440.0),
	Vector2(3840.0, 2160.0),
]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_project_display_contract(failures)
	_test_responsive_hud_layout(failures)
	_test_integrated_overlay_containment(failures)
	_test_settings_and_badge_containment(failures)
	return failures

func _test_project_display_contract(failures: Array[String]) -> void:
	TestAssertions.equal(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		1920,
		"logical viewport width is 1920",
		failures,
	)
	TestAssertions.equal(
		int(ProjectSettings.get_setting("display/window/size/viewport_height")),
		1080,
		"logical viewport height is 1080",
		failures,
	)
	TestAssertions.equal(
		str(ProjectSettings.get_setting("display/window/stretch/mode")),
		"canvas_items",
		"UI uses canvas_items stretch mode",
		failures,
	)
	TestAssertions.equal(
		ProjectSettings.has_setting("display/window/stretch/aspect"),
		true,
		"UI stretch aspect is available in ProjectSettings",
		failures,
	)
	TestAssertions.equal(
		str(ProjectSettings.get_setting("display/window/stretch/aspect")),
		"keep",
		"UI preserves the 16:9 aspect ratio",
		failures,
	)

func _test_responsive_hud_layout(failures: Array[String]) -> void:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	var status_margin := hud.get_node("Margin") as Control
	var boss_banner := hud.get_node("BossBanner") as Control
	var class_selection := hud.get_node("ClassSelection") as Control
	TestAssertions.truthy(class_selection.get_node_or_null("Content/Scroll/Grid") != null, "class selection exposes scroll grid", failures)
	var level_up := hud.get_node("LevelUpPanel") as Control
	var level_content := hud.get_node("LevelUpPanel/ContentPanel") as Control
	var result_root := hud.get_node("RunResultPanel") as Control
	var result_panel := hud.get_node("RunResultPanel/Panel") as Control
	_assert_full_rect(result_root, "run result overlay", failures)
	_assert_full_rect(level_up, "level-up modal root", failures)
	TestAssertions.equal(level_up.process_mode, Node.PROCESS_MODE_ALWAYS, "level-up modal always processes while paused", failures)
	TestAssertions.equal(level_up.mouse_filter, Control.MOUSE_FILTER_STOP, "level-up modal blocks pointer input behind it", failures)
	_assert_center_anchors(class_selection, "class selection", failures)
	_assert_center_anchors(level_content, "level-up content panel", failures)
	_assert_center_anchors(result_panel, "run result panel", failures)
	TestAssertions.truthy(level_up.get_node_or_null("ContentPanel/OfferView") is ScrollContainer, "offer content is scrollable", failures)
	TestAssertions.truthy(level_up.get_node_or_null("ContentPanel/RecipientView/Content/RecipientsScroll") is ScrollContainer, "recipient content is scrollable", failures)
	TestAssertions.truthy(level_up.get_node_or_null("ContentPanel/ConfirmationView") is ScrollContainer, "confirmation content is scrollable", failures)
	TestAssertions.equal(
		Vector4(boss_banner.anchor_left, boss_banner.anchor_top, boss_banner.anchor_right, boss_banner.anchor_bottom),
		Vector4(0.5, 0.0, 0.5, 0.0),
		"boss banner uses exact center-top anchors",
		failures,
	)
	_assert_size(boss_banner, Vector2(500.0, 70.0), "boss banner", failures)

	for viewport_size: Vector2 in VIEWPORT_SIZES:
		_assert_centered(class_selection, viewport_size, "class selection", failures)
		_assert_centered(level_content, viewport_size, "level-up content panel", failures)
		_assert_centered(result_panel, viewport_size, "run result panel", failures)
		_assert_size(class_selection, Vector2(760.0, 440.0), "class selection", failures)
		_assert_size(level_content, Vector2(1120.0, 680.0), "level-up content panel", failures)
		_assert_size(result_panel, Vector2(400.0, 260.0), "run result panel", failures)
		TestAssertions.near(
			_rect_center(boss_banner, viewport_size).x,
			viewport_size.x * 0.5,
			0.01,
			"boss banner is horizontally centered at %s" % viewport_size,
			failures,
		)
		TestAssertions.near(
			_rect_top_left(boss_banner, viewport_size).y,
			80.0,
			0.01,
			"boss banner retains top margin at %s" % viewport_size,
			failures,
		)
		var status_position := _rect_top_left(status_margin, viewport_size)
		TestAssertions.near(status_position.x, 16.0, 0.01, "status HUD retains left margin at %s" % viewport_size, failures)
		TestAssertions.near(status_position.y, 16.0, 0.01, "status HUD retains top margin at %s" % viewport_size, failures)

	hud.free()

func _test_integrated_overlay_containment(failures: Array[String]) -> void:
	var ledger := (load("res://scenes/ui/ledger/character_ledger.tscn") as PackedScene).instantiate() as CharacterLedger
	var pause_menu := (load("res://scenes/ui/run_pause_menu.tscn") as PackedScene).instantiate() as CanvasLayer
	var ledger_overlay := ledger.get_node("Overlay") as Control
	var ledger_frame := ledger.get_node("Overlay/Frame") as Control
	var pause_overlay := pause_menu.get_node("Overlay") as Control
	var pause_panel := pause_menu.get_node("Overlay/Panel") as Control
	var confirmation_panel := pause_menu.get_node("Overlay/QuitConfirmation/Panel") as Control
	_assert_full_rect(ledger_overlay, "ledger overlay root", failures)
	_assert_full_rect(pause_overlay, "pause overlay root", failures)
	TestAssertions.truthy(ledger.has_method("apply_viewport_size"), "ledger overlay exposes responsive containment policy", failures)
	if not ledger.has_method("apply_viewport_size"):
		ledger.free()
		pause_menu.free()
		return
	for viewport_size: Vector2 in VIEWPORT_SIZES:
		ledger.call("apply_viewport_size", viewport_size)
		_assert_contained(ledger_frame, viewport_size, "ledger frame", failures)
		_assert_contained(pause_panel, viewport_size, "pause panel", failures)
		_assert_contained(confirmation_panel, viewport_size, "pause confirmation panel", failures)
	ledger.free()
	pause_menu.free()

func _test_settings_and_badge_containment(failures: Array[String]) -> void:
	var settings := (load("res://scenes/ui/settings/settings_screen.tscn") as PackedScene).instantiate() as SettingsScreen
	var frame := settings.get_node("Overlay/Frame") as Control
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var controls_scroll := settings.get_node("Overlay/Frame/Layout/Tabs/Controls/Layout/Scroll") as ScrollContainer
	var additional := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as Control
	var reset := additional.get_node("Layout/ResetDeveloperOptions") as Button
	var apply := additional.get_node("Layout/ApplyAndReturn") as Button
	var cancel := additional.get_node("Layout/Cancel") as Button
	var notice := settings.get_node("Overlay/Frame/Layout/NextRunNotice") as Label
	var status := settings.get_node("Overlay/Frame/Layout/Status") as Label
	_assert_full_rect(settings.get_node("Overlay") as Control, "Settings overlay root", failures)
	TestAssertions.equal(controls_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "Controls disables horizontal scrolling", failures)
	TestAssertions.truthy(controls_scroll.size_flags_vertical & Control.SIZE_EXPAND != 0, "Controls scroll expands vertically", failures)
	TestAssertions.truthy(tabs.size_flags_horizontal & Control.SIZE_EXPAND != 0 and tabs.size_flags_vertical & Control.SIZE_EXPAND != 0, "Settings tabs expand inside the frame", failures)
	TestAssertions.truthy(additional.size_flags_horizontal & Control.SIZE_EXPAND != 0 and additional.size_flags_vertical & Control.SIZE_EXPAND != 0, "Additional Settings expands inside the tab body", failures)
	TestAssertions.truthy(notice.autowrap_mode != TextServer.AUTOWRAP_OFF, "next-run notice wraps inside Settings", failures)
	TestAssertions.truthy(status.autowrap_mode != TextServer.AUTOWRAP_OFF, "Settings status wraps long errors", failures)
	for viewport_size: Vector2 in VIEWPORT_SIZES:
		_assert_contained(frame, viewport_size, "Settings frame", failures)
		_assert_descendant(tabs.get_tab_bar(), frame, "Settings tab row at %s" % viewport_size, failures)
		_assert_descendant(controls_scroll, frame, "Controls scroll at %s" % viewport_size, failures)
		_assert_descendant(reset, frame, "Reset Developer Options action at %s" % viewport_size, failures)
		_assert_descendant(apply, frame, "Apply and Return action at %s" % viewport_size, failures)
		_assert_descendant(cancel, frame, "Cancel action at %s" % viewport_size, failures)
		_assert_descendant(notice, frame, "Settings tooltip/notice region at %s" % viewport_size, failures)
		_assert_descendant(status, frame, "Settings status region at %s" % viewport_size, failures)
	settings.free()

	const badge_path := "res://scenes/ui/developer_mode_badge.tscn"
	TestAssertions.truthy(ResourceLoader.exists(badge_path), "Developer Mode badge scene exists for responsive acceptance", failures)
	if not ResourceLoader.exists(badge_path):
		return
	var badge := (load(badge_path) as PackedScene).instantiate()
	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	developer_settings.unlock_all_implemented_content = true
	developer_settings.god_mode = true
	developer_settings.party_capacity_override = 12
	developer_settings.enemy_density_percent = 500
	badge.call(&"configure", RunRulesSnapshot.from_settings(developer_settings))
	var badge_anchor := badge.get_node("Anchor") as Control
	var badge_margin := badge.find_child("Margin", true, false) as Control
	var badge_label := badge.find_child("Label", true, false) as Label
	_assert_full_rect(badge_anchor, "Developer Mode badge anchor", failures)
	TestAssertions.truthy(badge.visible, "responsive badge fixture is visible", failures)
	TestAssertions.truthy(badge_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "badge summary wraps within its margin", failures)
	for viewport_size: Vector2 in VIEWPORT_SIZES:
		_assert_contained(badge_margin, viewport_size, "Developer Mode badge", failures)
		_assert_descendant(badge_label, badge_margin, "Developer Mode badge label at %s" % viewport_size, failures)
	badge.free()

func _assert_descendant(control: Control, container: Control, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(container.is_ancestor_of(control), "%s remains contained by %s" % [label, container.name], failures)

func _assert_centered(control: Control, viewport_size: Vector2, label: String, failures: Array[String]) -> void:
	var center := _rect_center(control, viewport_size)
	TestAssertions.near(center.x, viewport_size.x * 0.5, 0.01, "%s center x at %s" % [label, viewport_size], failures)
	TestAssertions.near(center.y, viewport_size.y * 0.5, 0.01, "%s center y at %s" % [label, viewport_size], failures)

func _assert_center_anchors(control: Control, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(
		Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom),
		Vector4(0.5, 0.5, 0.5, 0.5),
		"%s uses exact center anchors" % label,
		failures,
	)

func _assert_size(control: Control, expected: Vector2, label: String, failures: Array[String]) -> void:
	var logical_size := Vector2(control.offset_right - control.offset_left, control.offset_bottom - control.offset_top)
	TestAssertions.equal(logical_size, expected, "%s retains logical size" % label, failures)

func _assert_full_rect(control: Control, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(
		Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom),
		Vector4(0.0, 0.0, 1.0, 1.0),
		"%s anchors cover its parent" % label,
		failures,
	)
	TestAssertions.equal(
		Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom),
		Vector4.ZERO,
		"%s has no edge offsets" % label,
		failures,
	)

func _assert_contained(control: Control, viewport_size: Vector2, label: String, failures: Array[String]) -> void:
	var top_left := _rect_top_left(control, viewport_size)
	var bottom_right := Vector2(
		viewport_size.x * control.anchor_right + control.offset_right,
		viewport_size.y * control.anchor_bottom + control.offset_bottom,
	)
	TestAssertions.truthy(
		top_left.x >= 0.0 and top_left.y >= 0.0,
		"%s top-left remains contained at %s" % [label, viewport_size],
		failures,
	)
	TestAssertions.truthy(
		bottom_right.x <= viewport_size.x and bottom_right.y <= viewport_size.y,
		"%s bottom-right remains contained at %s" % [label, viewport_size],
		failures,
	)

func _rect_center(control: Control, viewport_size: Vector2) -> Vector2:
	var top_left := _rect_top_left(control, viewport_size)
	var bottom_right := Vector2(
		viewport_size.x * control.anchor_right + control.offset_right,
		viewport_size.y * control.anchor_bottom + control.offset_bottom,
	)
	return (top_left + bottom_right) * 0.5

func _rect_top_left(control: Control, viewport_size: Vector2) -> Vector2:
	return Vector2(
		viewport_size.x * control.anchor_left + control.offset_left,
		viewport_size.y * control.anchor_top + control.offset_top,
	)
