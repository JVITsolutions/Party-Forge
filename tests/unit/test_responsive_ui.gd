extends RefCounted

const ResponsiveGeometry := preload("res://tests/support/responsive_geometry.gd")
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
	_test_level_up_card_layout_contract(failures)
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
	TestAssertions.equal(
		Vector4(level_content.anchor_left, level_content.anchor_top, level_content.anchor_right, level_content.anchor_bottom),
		Vector4(0.02, 0.06, 0.98, 0.94),
		"level-up content panel uses approved responsive edge anchors",
		failures,
	)
	TestAssertions.equal(
		Vector4(level_content.offset_left, level_content.offset_top, level_content.offset_right, level_content.offset_bottom),
		Vector4.ZERO,
		"level-up content panel uses no fixed offsets",
		failures,
	)
	_assert_center_anchors(result_panel, "run result panel", failures)
	TestAssertions.truthy(level_up.get_node_or_null("ContentPanel/OfferView") is ScrollContainer, "offer content is scrollable", failures)
	var recipients_scroll := level_up.get_node_or_null("ContentPanel/RecipientView/Content/RecipientsScroll") as ScrollContainer
	TestAssertions.truthy(recipients_scroll != null, "recipient content is scrollable", failures)
	TestAssertions.truthy(recipients_scroll != null and recipients_scroll.follow_focus, "recipient scroll follows keyboard and controller focus", failures)
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
		var level_rect := ResponsiveGeometry.control_rect(level_content, Rect2(Vector2.ZERO, viewport_size))
		var expected_level_size := viewport_size * Vector2(0.96, 0.88)
		TestAssertions.near(level_rect.size.x, expected_level_size.x, 0.01, "level-up content panel width scales at %s" % viewport_size, failures)
		TestAssertions.near(level_rect.size.y, expected_level_size.y, 0.01, "level-up content panel height scales at %s" % viewport_size, failures)
		TestAssertions.truthy(ResponsiveGeometry.contains(Rect2(Vector2.ZERO, viewport_size), level_rect), "level-up content panel remains contained at %s" % viewport_size, failures)
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

func _test_level_up_card_layout_contract(failures: Array[String]) -> void:
	var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
	var content_panel := panel.get_node("ContentPanel") as Control
	var offer_view := panel.get_node("ContentPanel/OfferView") as ScrollContainer
	var cards := panel.get_node("ContentPanel/OfferView/Content/Cards") as HBoxContainer
	TestAssertions.equal(content_panel.custom_minimum_size, Vector2(0.0, 560.0), "responsive level-up panel keeps only a vertical minimum", failures)
	TestAssertions.equal(offer_view.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "developer card counts scroll horizontally without truncation", failures)
	TestAssertions.truthy(cards.get_node_or_null("Card4") is UpgradeCard, "production scene exposes stable Card4 path", failures)
	TestAssertions.truthy(cards.get_node_or_null("Card5") is UpgradeCard, "production scene exposes stable Card5 path", failures)
	for index: int in mini(cards.get_child_count(), 5):
		var card := cards.get_child(index) as UpgradeCard
		TestAssertions.equal(card.custom_minimum_size, Vector2(168.0, 300.0), "card %d uses approved responsive minimum" % (index + 1), failures)
		TestAssertions.equal(card.size_flags_horizontal & Control.SIZE_EXPAND_FILL, Control.SIZE_EXPAND_FILL, "card %d expands and fills the row" % (index + 1), failures)
		TestAssertions.near(card.size_flags_stretch_ratio, 1.0, 0.001, "card %d uses equal stretch" % (index + 1), failures)
		var content := card.get_node("Content") as Control
		TestAssertions.equal(Vector4(content.offset_left, content.offset_top, content.offset_right, content.offset_bottom), Vector4(10.0, 16.0, -10.0, -16.0), "card %d uses reduced horizontal padding" % (index + 1), failures)
	panel.free()

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
	var overlay := settings.get_node("Overlay") as Control
	var frame := settings.get_node("Overlay/Frame") as Control
	var layout := settings.get_node("Overlay/Frame/Layout") as VBoxContainer
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var controls_page := settings.get_node("Overlay/Frame/Layout/Tabs/Controls") as Control
	var controls_layout := settings.get_node("Overlay/Frame/Layout/Tabs/Controls/Layout") as VBoxContainer
	var controls_scroll := settings.get_node("Overlay/Frame/Layout/Tabs/Controls/Layout/Scroll") as ScrollContainer
	var additional := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as Control
	var additional_layout := additional.get_node("Layout") as VBoxContainer
	var experience_row := additional.get_node("Layout/ExperienceMultiplier") as HBoxContainer
	var experience_value := additional.get_node("Layout/ExperienceMultiplier/Value") as HSlider
	var cards_row := additional.get_node("Layout/LevelUpCardCount") as HBoxContainer
	var cards_value := additional.get_node("Layout/LevelUpCardCount/Value") as HSlider
	var reset := additional.get_node("Layout/ResetDeveloperOptions") as Button
	var apply := additional.get_node("Layout/ApplyAndReturn") as Button
	var cancel := additional.get_node("Layout/Cancel") as Button
	var notice := settings.get_node("Overlay/Frame/Layout/NextRunNotice") as Label
	var status := settings.get_node("Overlay/Frame/Layout/Status") as Label
	_assert_full_rect(overlay, "Settings overlay root", failures)
	TestAssertions.equal(frame.get_parent(), overlay, "Settings frame is anchored by the full-rect overlay", failures)
	TestAssertions.equal(layout.get_parent(), frame, "Settings VBox owns frame content layout", failures)
	TestAssertions.equal(tabs.get_parent(), layout, "Settings VBox directly owns the tab container", failures)
	TestAssertions.equal(tabs.layout_mode, 2, "Settings tabs use container layout", failures)
	_assert_expand_fill(tabs, true, true, "Settings tabs", failures)
	TestAssertions.truthy(tabs.is_ancestor_of(tabs.get_tab_bar()), "Settings TabContainer owns its tab row", failures)
	TestAssertions.equal(controls_page.get_parent(), tabs, "Controls is a direct tab page", failures)
	TestAssertions.equal(controls_layout.get_parent(), controls_page, "Controls page owns its VBox layout", failures)
	TestAssertions.equal(controls_scroll.get_parent(), controls_layout, "Controls VBox directly owns its scroll region", failures)
	TestAssertions.equal(controls_scroll.layout_mode, 2, "Controls scroll uses container layout", failures)
	_assert_expand_fill(controls_scroll, true, true, "Controls scroll", failures)
	TestAssertions.equal(controls_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "Controls disables horizontal scrolling", failures)
	TestAssertions.equal(controls_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "Controls enables vertical overflow scrolling", failures)
	TestAssertions.truthy(controls_scroll.clip_contents, "Controls clips overflowing rows to its scroll viewport", failures)
	TestAssertions.equal(additional.get_parent(), tabs, "Additional Settings is a direct tab page", failures)
	TestAssertions.equal(additional_layout.get_parent(), additional, "Additional Settings page owns its VBox layout", failures)
	TestAssertions.equal(additional.layout_mode, 2, "Additional Settings uses container layout", failures)
	_assert_expand_fill(additional, true, true, "Additional Settings", failures)
	for row: HBoxContainer in [experience_row, cards_row]:
		TestAssertions.equal(row.get_parent(), additional_layout, "%s is owned by the Additional Settings VBox" % row.name, failures)
		TestAssertions.equal(row.layout_mode, 2, "%s uses container layout" % row.name, failures)
	for slider: HSlider in [experience_value, cards_value]:
		_assert_expand_fill(slider, true, false, slider.name, failures)
	for action: Button in [reset, apply, cancel]:
		TestAssertions.equal(action.get_parent(), additional_layout, "%s is owned by the Additional Settings VBox" % action.name, failures)
		TestAssertions.equal(action.layout_mode, 2, "%s uses container layout" % action.name, failures)
		TestAssertions.truthy(action.get_combined_minimum_size().x > 0.0 and action.get_combined_minimum_size().y > 0.0, "%s has a measurable minimum size" % action.name, failures)
	TestAssertions.equal(notice.get_parent(), layout, "next-run notice is owned by the Settings VBox", failures)
	TestAssertions.equal(status.get_parent(), layout, "Settings status is owned by the Settings VBox", failures)
	TestAssertions.equal(notice.layout_mode, 2, "next-run notice uses container layout", failures)
	TestAssertions.equal(status.layout_mode, 2, "Settings status uses container layout", failures)
	TestAssertions.truthy(notice.autowrap_mode != TextServer.AUTOWRAP_OFF, "next-run notice wraps inside Settings", failures)
	TestAssertions.truthy(status.autowrap_mode != TextServer.AUTOWRAP_OFF, "Settings status wraps long errors", failures)
	TestAssertions.truthy(status.custom_minimum_size.y >= 36.0, "Settings reserves a visible status region", failures)
	for viewport_size: Vector2 in VIEWPORT_SIZES:
		var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
		var overlay_rect := ResponsiveGeometry.control_rect(overlay, viewport_rect)
		var frame_rect := ResponsiveGeometry.control_rect(frame, overlay_rect)
		TestAssertions.equal(overlay_rect, viewport_rect, "Settings overlay covers %s" % viewport_size, failures)
		TestAssertions.truthy(ResponsiveGeometry.contains(overlay_rect, frame_rect), "Settings frame is geometrically contained at %s" % viewport_size, failures)
		TestAssertions.equal(frame_rect.position, Vector2(48.0, 36.0), "Settings frame preserves top-left margins at %s" % viewport_size, failures)
		TestAssertions.equal(frame_rect.end, viewport_size - Vector2(48.0, 36.0), "Settings frame preserves bottom-right margins at %s" % viewport_size, failures)
		var minimum := frame.get_combined_minimum_size()
		TestAssertions.truthy(frame_rect.size.x >= minimum.x and frame_rect.size.y >= minimum.y, "Settings frame fits its combined minimum at %s (frame=%s minimum=%s)" % [viewport_size, frame_rect.size, minimum], failures)
		for action: Button in [reset, apply, cancel]:
			TestAssertions.truthy(action.get_combined_minimum_size().x <= frame_rect.size.x, "%s minimum width fits Settings at %s" % [action.name, viewport_size], failures)
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
	TestAssertions.equal(badge_margin.get_parent(), badge_anchor, "badge anchor directly owns the top-right margin", failures)
	TestAssertions.equal(
		Vector4(badge_margin.anchor_left, badge_margin.anchor_top, badge_margin.anchor_right, badge_margin.anchor_bottom),
		Vector4(1.0, 0.0, 1.0, 0.0),
		"badge margin uses exact top-right anchors",
		failures,
	)
	TestAssertions.equal(
		Vector4(badge_margin.offset_left, badge_margin.offset_top, badge_margin.offset_right, badge_margin.offset_bottom),
		Vector4(-720.0, 16.0, -16.0, 72.0),
		"badge margin uses approved top-right offsets",
		failures,
	)
	TestAssertions.equal(badge_margin.grow_horizontal, Control.GROW_DIRECTION_BEGIN, "badge grows inward from the right edge", failures)
	TestAssertions.equal(Vector4(
		badge_margin.get_theme_constant(&"margin_left"),
		badge_margin.get_theme_constant(&"margin_top"),
		badge_margin.get_theme_constant(&"margin_right"),
		badge_margin.get_theme_constant(&"margin_bottom"),
	), Vector4(12.0, 8.0, 12.0, 8.0), "badge content margins use the approved inset", failures)
	TestAssertions.equal(badge_label.get_parent(), badge_margin, "badge margin directly owns its label", failures)
	TestAssertions.equal(badge_label.layout_mode, 2, "badge label uses container layout", failures)
	TestAssertions.equal(badge_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "badge label aligns to the right edge", failures)
	TestAssertions.equal(badge_label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER, "badge label centers vertically", failures)
	TestAssertions.truthy(badge.visible, "responsive badge fixture is visible", failures)
	TestAssertions.truthy(badge_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "badge summary wraps within its margin", failures)
	for viewport_size: Vector2 in VIEWPORT_SIZES:
		var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
		var anchor_rect := ResponsiveGeometry.control_rect(badge_anchor, viewport_rect)
		var margin_rect := ResponsiveGeometry.control_rect(badge_margin, anchor_rect)
		TestAssertions.equal(anchor_rect, viewport_rect, "badge anchor covers %s" % viewport_size, failures)
		TestAssertions.truthy(ResponsiveGeometry.contains(anchor_rect, margin_rect), "badge margin is contained at %s" % viewport_size, failures)
		TestAssertions.equal(margin_rect.position, Vector2(viewport_size.x - 720.0, 16.0), "badge starts at the approved top-right position at %s" % viewport_size, failures)
		TestAssertions.equal(margin_rect.end, Vector2(viewport_size.x - 16.0, 72.0), "badge keeps exact right and top/bottom offsets at %s" % viewport_size, failures)
		TestAssertions.equal(margin_rect.size, Vector2(704.0, 56.0), "badge keeps a stable wrapping area at %s" % viewport_size, failures)
		var content_size := margin_rect.size - Vector2(24.0, 16.0)
		var label_minimum := badge_label.get_combined_minimum_size()
		TestAssertions.truthy(label_minimum.x <= content_size.x and label_minimum.y <= content_size.y, "badge label minimum fits its inset area at %s" % viewport_size, failures)
	badge.free()

func _assert_expand_fill(control: Control, horizontal: bool, vertical: bool, label: String, failures: Array[String]) -> void:
	if horizontal:
		TestAssertions.equal(control.size_flags_horizontal & Control.SIZE_EXPAND_FILL, Control.SIZE_EXPAND_FILL, "%s expands and fills horizontally" % label, failures)
	if vertical:
		TestAssertions.equal(control.size_flags_vertical & Control.SIZE_EXPAND_FILL, Control.SIZE_EXPAND_FILL, "%s expands and fills vertically" % label, failures)

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
