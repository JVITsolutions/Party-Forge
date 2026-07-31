extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_card_renders_dictionary_and_emits(failures)
	_test_hover_focus_share_detail_state(failures)
	_test_tooltip_renders_dictionary(failures)
	_test_interactive_pin_shell_and_inputs(failures)
	_test_tooltip_surface_is_opaque_and_readable(failures)
	_test_clamped_placement(failures)
	_test_long_content_scene_stays_inside_viewports(failures)
	return failures

func _test_card_renders_dictionary_and_emits(failures: Array[String]) -> void:
	var scene := load("res://scenes/ui/upgrade_card.tscn") as PackedScene
	TestAssertions.truthy(scene != null, "upgrade card scene loads", failures)
	if scene == null:
		return
	var card := scene.instantiate() as UpgradeCard
	card.call("_ready")
	var choice := UpgradeChoice.authored(GameCatalog.load_defaults().upgrade_by_id(&"deadeye"))
	var presentation := {
		"name": "Deadeye",
		"scope_badge": "Marksman Signature",
		"rank_text": "Rank 0 / 1",
		"summary": "Trade attack speed for devastating long-range physical shots.",
		"eligibility_text": "Eligible class: Marksman.",
		"recipient_text": "Choose one eligible character.",
		"inheritance_text": "",
	}
	card.bind_choice(choice, presentation, "")
	TestAssertions.equal((card.get_node("Content/Name") as Label).text, "Deadeye", "card renders dictionary name", failures)
	TestAssertions.equal((card.get_node("Content/Scope") as Label).text, "Marksman Signature", "card renders dictionary scope", failures)
	TestAssertions.equal((card.get_node("Content/Rank") as Label).text, "Rank 0 / 1", "card renders dictionary rank", failures)
	TestAssertions.equal((card.get_node("Content/Summary") as Label).text, presentation["summary"], "card renders dictionary summary", failures)
	var activated: Array[UpgradeChoice] = []
	card.activated.connect(func(emitted: UpgradeChoice) -> void: activated.append(emitted))
	card.pressed.emit()
	TestAssertions.equal(activated, [choice], "card activation emits bound choice", failures)
	card.free()

func _test_hover_focus_share_detail_state(failures: Array[String]) -> void:
	var card := (load("res://scenes/ui/upgrade_card.tscn") as PackedScene).instantiate() as UpgradeCard
	card.call("_ready")
	var choice := UpgradeChoice.authored(GameCatalog.load_defaults().upgrade_by_id(&"vitality"))
	card.bind_choice(choice, {"name": "Vitality"})
	var requested: Array[UpgradeChoice] = []
	var dismissed: Array[UpgradeChoice] = []
	card.detail_requested.connect(func(emitted: UpgradeChoice, _anchor: Control) -> void: requested.append(emitted))
	card.detail_dismissed.connect(func(emitted: UpgradeChoice) -> void: dismissed.append(emitted))
	card.mouse_entered.emit()
	card.focus_entered.emit()
	card.mouse_exited.emit()
	TestAssertions.equal(requested, [choice], "hover and focus share one detail request", failures)
	TestAssertions.equal(dismissed, [], "mouse exit preserves focused detail", failures)
	card.focus_exited.emit()
	TestAssertions.equal(dismissed, [choice], "detail dismisses after hover and focus both end", failures)
	card.focus_entered.emit()
	card.focus_exited.emit()
	TestAssertions.equal(requested, [choice, choice], "keyboard focus requests identical bound choice", failures)
	TestAssertions.equal(dismissed, [choice, choice], "keyboard focus dismissal matches hover behavior", failures)
	card.free()

func _test_tooltip_renders_dictionary(failures: Array[String]) -> void:
	var scene := load("res://scenes/ui/upgrade_tooltip_panel.tscn") as PackedScene
	TestAssertions.truthy(scene != null, "upgrade tooltip scene loads", failures)
	if scene == null:
		return
	var tooltip := scene.instantiate() as UpgradeTooltipPanel
	tooltip.call("_ready")
	var anchor := Button.new()
	anchor.position = Vector2(100.0, 100.0)
	anchor.size = Vector2(200.0, 100.0)
	var content := {
		"title": "Deadeye",
		"rank_text": "Offered rank 1 / 1",
		"description": "Trade speed for power.",
		"effect_lines": ["30% more Physical Damage.", "15% less Attack Speed."],
		"eligibility_text": "Eligible class: Marksman.",
		"inheritance_text": "",
		"keyword_lines": ["More: Multiplicative power."],
	}
	TestAssertions.truthy(tooltip.show_content(content, anchor, &"fixture"), "first tooltip source is accepted", failures)
	TestAssertions.equal((tooltip.get_node("Content/Header/Title") as Label).text, "Deadeye", "tooltip renders dictionary title", failures)
	TestAssertions.equal((tooltip.get_node("Content/BodyScroll/Body/Effects") as Label).text, "30% more Physical Damage.\n15% less Attack Speed.", "tooltip renders dictionary effect lines", failures)
	TestAssertions.equal((tooltip.get_node("Content/BodyScroll/Body/Keywords") as Label).text, "More: Multiplicative power.", "tooltip renders dictionary keyword lines", failures)
	TestAssertions.truthy(tooltip.visible, "show content reveals tooltip", failures)
	tooltip.hide_content()
	TestAssertions.truthy(not tooltip.visible, "hide content conceals tooltip", failures)
	anchor.free()
	tooltip.free()

func _test_interactive_pin_shell_and_inputs(failures: Array[String]) -> void:
	var tooltip := (load("res://scenes/ui/upgrade_tooltip_panel.tscn") as PackedScene).instantiate() as UpgradeTooltipPanel
	tooltip.call("_ready")
	TestAssertions.truthy(tooltip is TemporaryHoverPopup, "upgrade tooltip uses reusable temporary popup", failures)
	TestAssertions.equal(tooltip.mouse_filter, Control.MOUSE_FILTER_STOP, "tooltip accepts pointer input", failures)
	var pin := tooltip.get_node_or_null("Content/Header/Pin") as Button
	TestAssertions.truthy(pin != null, "tooltip header owns top-right pin button", failures)
	if pin != null:
		TestAssertions.truthy(pin.toggle_mode, "pin exposes pressed and unpressed structure", failures)
		TestAssertions.truthy(pin.icon != null, "pin uses project vector icon", failures)
		TestAssertions.equal(pin.tooltip_text, "Pin details", "unpinned action is explained", failures)
	TestAssertions.equal(tooltip.scroll_target_path, ^"Content/BodyScroll", "tooltip exports controller scroll target", failures)
	TestAssertions.equal(tooltip.pin_button_path, ^"Content/Header/Pin", "tooltip exports pin target", failures)

	for action: StringName in [&"tooltip_hold", &"tooltip_pin", &"tooltip_scroll_up", &"tooltip_scroll_down"]:
		TestAssertions.truthy(InputMap.has_action(action), "InputMap exposes %s" % action, failures)
	var hold_events := InputMap.action_get_events(&"tooltip_hold")
	TestAssertions.truthy(hold_events.any(func(event: InputEvent) -> bool: return event is InputEventKey and event.keycode == KEY_ALT), "either Alt maps to tooltip hold", failures)
	var pin_events := InputMap.action_get_events(&"tooltip_pin")
	TestAssertions.truthy(pin_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y), "Y/Triangle maps to tooltip pin", failures)
	var up_events := InputMap.action_get_events(&"tooltip_scroll_up")
	var down_events := InputMap.action_get_events(&"tooltip_scroll_down")
	TestAssertions.truthy(up_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y and event.axis_value < 0.0), "right stick up maps to popup scroll up", failures)
	TestAssertions.truthy(down_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y and event.axis_value > 0.0), "right stick down maps to popup scroll down", failures)
	tooltip.free()

func _test_tooltip_surface_is_opaque_and_readable(failures: Array[String]) -> void:
	var tooltip_scene := load("res://scenes/ui/upgrade_tooltip_panel.tscn") as PackedScene
	var tooltip := tooltip_scene.instantiate() as UpgradeTooltipPanel
	TestAssertions.truthy(
		tooltip.has_theme_stylebox_override("panel"),
		"tooltip owns its panel surface instead of inheriting the HUD theme",
		failures,
	)
	var surface := tooltip.get_theme_stylebox("panel") as StyleBoxFlat
	TestAssertions.truthy(surface != null, "tooltip resolves a flat panel surface", failures)
	if surface != null:
		TestAssertions.truthy(surface.bg_color.a >= 0.95, "tooltip surface is effectively opaque", failures)
		var title := tooltip.get_node("Content/Header/Title") as Label
		var contrast_ratio := _contrast_ratio(surface.bg_color, title.get_theme_color("font_color"))
		TestAssertions.truthy(contrast_ratio >= 4.5, "tooltip text has accessible surface contrast", failures)
		TestAssertions.truthy(
			min(
				min(surface.border_width_left, surface.border_width_top),
				min(surface.border_width_right, surface.border_width_bottom),
			) >= 2,
			"tooltip surface has a readable border",
			failures,
		)
		TestAssertions.truthy(surface.border_color.a >= 0.95, "tooltip border is effectively opaque", failures)
		TestAssertions.truthy(
			minf(
				minf(surface.content_margin_left, surface.content_margin_top),
				minf(surface.content_margin_right, surface.content_margin_bottom),
			) >= 16.0,
			"tooltip surface pads text away from its border",
			failures,
		)
	TestAssertions.equal(tooltip.mouse_filter, Control.MOUSE_FILTER_STOP, "tooltip surface accepts pointer input", failures)
	tooltip.free()

	var level_up_scene := load("res://scenes/ui/level_up_panel.tscn") as PackedScene
	var level_up_panel := level_up_scene.instantiate() as LevelUpPanel
	var composed_tooltip := level_up_panel.get_node("TooltipPanel") as UpgradeTooltipPanel
	TestAssertions.equal(composed_tooltip.z_index, 100, "composed tooltip remains above level-up content", failures)
	TestAssertions.equal(composed_tooltip.mouse_filter, Control.MOUSE_FILTER_STOP, "composed tooltip accepts pointer input", failures)
	level_up_panel.free()

func _contrast_ratio(first: Color, second: Color) -> float:
	var lighter := maxf(first.get_luminance(), second.get_luminance())
	var darker := minf(first.get_luminance(), second.get_luminance())
	return (lighter + 0.05) / (darker + 0.05)

func _test_clamped_placement(failures: Array[String]) -> void:
	var viewport := Vector2(1920.0, 1080.0)
	var popup := Vector2(420.0, 360.0)
	TestAssertions.equal(
		UpgradeTooltipPanel.clamped_position(Rect2(100.0, 100.0, 300.0, 200.0), popup, viewport),
		Vector2(416.0, 100.0),
		"tooltip prefers right of card",
		failures,
	)
	TestAssertions.equal(
		UpgradeTooltipPanel.clamped_position(Rect2(1600.0, 100.0, 250.0, 200.0), popup, viewport),
		Vector2(1164.0, 100.0),
		"tooltip falls back left of right-edge card",
		failures,
	)
	TestAssertions.equal(
		UpgradeTooltipPanel.clamped_position(Rect2(10.0, -20.0, 1880.0, 1200.0), popup, viewport),
		Vector2(1484.0, 16.0),
		"oversized anchor clamps tooltip within top and right edges",
		failures,
	)
	TestAssertions.equal(
		UpgradeTooltipPanel.clamped_position(Rect2(1700.0, 1000.0, 200.0, 100.0), popup, viewport),
		Vector2(1264.0, 704.0),
		"bottom-right placement clamps both axes",
		failures,
	)
	TestAssertions.equal(
		UpgradeTooltipPanel.clamped_position(Rect2(-500.0, 100.0, 100.0, 100.0), popup, viewport),
		Vector2(16.0, 100.0),
		"anchor wholly left of viewport clamps to left margin",
		failures,
	)
	TestAssertions.equal(
		UpgradeTooltipPanel.clamped_position(Rect2(2100.0, 100.0, 100.0, 100.0), popup, viewport),
		Vector2(1484.0, 100.0),
		"anchor wholly right of viewport clamps to right margin",
		failures,
	)

func _test_long_content_scene_stays_inside_viewports(failures: Array[String]) -> void:
	var effects: Array[String] = []
	var keywords: Array[String] = []
	for index: int in 32:
		effects.append("%d%% increased Area Size from a production-like authored effect." % (index + 1))
	for index: int in 64:
		keywords.append("Keyword %d: A long production-like explanation that remains readable without growing beyond the viewport." % (index + 1))
	var content := {
		"title": "Expanding Power",
		"rank_text": "Offered rank 1 / 3",
		"description": "A keyword-rich authored upgrade used to exercise the production tooltip body.",
		"effect_lines": effects,
		"eligibility_text": "Requires all traits or capabilities: Area",
		"inheritance_text": "",
		"keyword_lines": keywords,
	}
	for viewport_size: Vector2 in [Vector2(1920.0, 1080.0), Vector2(3840.0, 2160.0)]:
		var host := Control.new()
		host.size = viewport_size
		var anchor := Button.new()
		anchor.position = Vector2(viewport_size.x * 0.5 - 160.0, 100.0)
		anchor.size = Vector2(320.0, 240.0)
		host.add_child(anchor)
		var tooltip := (load("res://scenes/ui/upgrade_tooltip_panel.tscn") as PackedScene).instantiate() as UpgradeTooltipPanel
		host.add_child(tooltip)
		tooltip.call("_ready")
		TestAssertions.truthy(tooltip.show_content(content, anchor, &"fixture"), "long tooltip source is accepted at %s" % viewport_size, failures)
		var scroll := tooltip.get_node_or_null("Content/BodyScroll") as ScrollContainer
		TestAssertions.truthy(scroll != null, "long tooltip exposes vertical scroll body at %s" % viewport_size, failures)
		if scroll != null:
			TestAssertions.truthy(scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "long tooltip vertical scrolling stays enabled at %s" % viewport_size, failures)
		var rect := tooltip.get_global_rect()
		var body := tooltip.get_node("Content/BodyScroll/Body") as Control
		TestAssertions.equal(rect.size.x, 420.0, "long tooltip preserves fixed width at %s" % viewport_size, failures)
		TestAssertions.truthy(rect.size.y <= minf(680.0, viewport_size.y - 32.0), "long tooltip height respects responsive cap at %s" % viewport_size, failures)
		TestAssertions.truthy(body.get_combined_minimum_size().y > rect.size.y, "long tooltip content overflows into scroll body at %s" % viewport_size, failures)
		TestAssertions.truthy(rect.position.x >= 16.0 and rect.position.y >= 16.0, "long tooltip starts inside viewport margins at %s" % viewport_size, failures)
		TestAssertions.truthy(rect.end.x <= viewport_size.x - 16.0 and rect.end.y <= viewport_size.y - 16.0, "long tooltip ends inside viewport margins at %s" % viewport_size, failures)
		host.free()
