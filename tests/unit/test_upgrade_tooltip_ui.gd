extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_card_renders_typed_projection_and_emits_key(failures)
	_test_card_hierarchy_tags_icons_and_accessibility(failures)
	_test_hover_focus_share_detail_state(failures)
	_test_disabled_to_enabled_card_reconciles_active_detail(failures)
	_test_tooltip_renders_dictionary(failures)
	_test_interactive_pin_shell_and_inputs(failures)
	_test_input_configurator_preserves_existing_action(failures)
	_test_tooltip_surface_is_opaque_and_readable(failures)
	_test_clamped_placement(failures)
	_test_long_content_scene_stays_inside_viewports(failures)
	return failures

func _test_card_renders_typed_projection_and_emits_key(failures: Array[String]) -> void:
	var scene := load("res://scenes/ui/upgrade_card.tscn") as PackedScene
	TestAssertions.truthy(scene != null, "upgrade card scene loads", failures)
	if scene == null:
		return
	var card := scene.instantiate() as UpgradeCard
	card.call("_ready")
	var projection := _card_projection("4:deadeye", "Deadeye")
	projection.scope_text = "Marksman Signature"
	projection.rank_text = "Rank 0 / 1"
	projection.effect_text = "Trade attack speed for devastating long-range physical shots."
	projection.eligibility_text = "Eligible class: Marksman."
	card.present(projection)
	TestAssertions.equal((card.get_node("Content/Name") as Label).text, "Deadeye", "card renders typed name", failures)
	TestAssertions.equal((card.get_node("Content/DetailsScroll/Body/Scope") as Label).text, "Marksman Signature", "card renders typed scope", failures)
	TestAssertions.equal((card.get_node("Content/Footer/Rank") as Label).text, "Rank 0 / 1", "card renders typed rank", failures)
	TestAssertions.equal((card.get_node("Content/DetailsScroll/Body/Summary") as Label).text, projection.effect_text, "card renders typed effect", failures)
	var activated: Array[StringName] = []
	card.activated.connect(func(emitted: StringName) -> void: activated.append(emitted))
	card.pressed.emit()
	TestAssertions.equal(activated, [&"4:deadeye"], "card activation emits stable bound key", failures)
	card.free()

func _test_card_hierarchy_tags_icons_and_accessibility(failures: Array[String]) -> void:
	var card := (load("res://scenes/ui/upgrade_card.tscn") as PackedScene).instantiate() as UpgradeCard
	card.call("_ready")
	var content := card.get_node("Content") as VBoxContainer
	var semantic_order := PackedStringArray()
	for child: Node in content.get_children():
		semantic_order.append(String(child.name))
	TestAssertions.equal(
		semantic_order,
		PackedStringArray(["Identity", "Name", "Rarity", "DetailsScroll", "Footer"]),
		"card semantic order keeps identity above bounded details and a pinned footer",
		failures,
	)
	var details := card.get_node_or_null("Content/DetailsScroll") as ScrollContainer
	var footer := card.get_node_or_null("Content/Footer") as Control
	var tags := card.get_node_or_null("Content/DetailsScroll/Body/Tags") as Control
	var icon := card.get_node_or_null("Content/Identity/Icon") as TextureRect
	var fallback := card.get_node_or_null("Content/Identity/FallbackIcon") as Label
	TestAssertions.truthy(tags != null, "card exposes recipient and class tag content", failures)
	TestAssertions.truthy(details != null and details.clip_contents, "card bounds variable details in a clipped scroll viewport", failures)
	TestAssertions.truthy(footer != null, "card pins rank and action in a dedicated footer", failures)
	TestAssertions.truthy(icon != null and fallback != null, "card exposes semantic texture plus neutral fallback", failures)
	if tags == null or icon == null or fallback == null:
		card.free()
		return
	var projection := _card_projection("4:shielded", "Shielded")
	projection.icon_id = &"shield"
	projection.rarity_label = "Rare"
	projection.recipient_tags = [&"vanguard", &"martial"]
	projection.class_tags = [&"fighter"]
	card.present(projection)
	card.set_action_hint("Choose Recipient")
	TestAssertions.truthy(icon.texture != null and icon.texture.resource_path.ends_with("/shield.svg"), "known normalized semantic icon resolves the reviewed shield texture", failures)
	TestAssertions.truthy(not fallback.visible, "known icon hides the neutral forge fallback", failures)
	TestAssertions.equal((card.get_node("Content/DetailsScroll/Body/Tags/RecipientTags") as Label).text, "Traits: Vanguard, Martial", "recipient tags render as semantic names", failures)
	TestAssertions.equal((card.get_node("Content/DetailsScroll/Body/Tags/ClassTags") as Label).text, "Classes: Fighter", "class tags render as semantic names", failures)
	for expected: String in ["Rare", "Vanguard", "Martial", "Fighter", "Choose Recipient"]:
		TestAssertions.truthy(expected in card.accessibility_name, "accessibility name includes %s" % expected, failures)
	projection.icon_id = &"unknown-semantic-icon"
	card.present(projection)
	TestAssertions.truthy(icon.texture == null and fallback.visible, "unknown icon uses the neutral forge fallback without invented identity", failures)
	card.free()

func _test_hover_focus_share_detail_state(failures: Array[String]) -> void:
	var card := (load("res://scenes/ui/upgrade_card.tscn") as PackedScene).instantiate() as UpgradeCard
	card.call("_ready")
	var projection := _card_projection("4:vitality", "Vitality")
	card.present(projection)
	var requested: Array[StringName] = []
	var dismissed: Array[StringName] = []
	card.detail_requested.connect(func(emitted: StringName, _anchor: Control) -> void: requested.append(emitted))
	card.detail_dismissed.connect(func(emitted: StringName) -> void: dismissed.append(emitted))
	card.mouse_entered.emit()
	card.focus_entered.emit()
	card.mouse_exited.emit()
	TestAssertions.equal(requested, [&"4:vitality"], "hover and focus share one detail request", failures)
	TestAssertions.equal(dismissed, [], "mouse exit preserves focused detail", failures)
	card.focus_exited.emit()
	TestAssertions.equal(dismissed, [&"4:vitality"], "detail dismisses after hover and focus both end", failures)
	card.focus_entered.emit()
	card.focus_exited.emit()
	TestAssertions.equal(requested, [&"4:vitality", &"4:vitality"], "keyboard focus requests identical bound key", failures)
	TestAssertions.equal(dismissed, [&"4:vitality", &"4:vitality"], "keyboard focus dismissal matches hover behavior", failures)
	card.free()

func _test_disabled_to_enabled_card_reconciles_active_detail(failures: Array[String]) -> void:
	var card := (load("res://scenes/ui/upgrade_card.tscn") as PackedScene).instantiate() as UpgradeCard
	card.call("_ready")
	var projection := _card_projection("4:vitality", "Vitality")
	projection.disabled_reason = "Revealing."
	card.present(projection)
	var requested: Array[StringName] = []
	var dismissed: Array[StringName] = []
	card.detail_requested.connect(func(emitted: StringName, _anchor: Control) -> void: requested.append(emitted))
	card.detail_dismissed.connect(func(emitted: StringName) -> void: dismissed.append(emitted))
	card.mouse_entered.emit()
	TestAssertions.equal(requested, [], "disabled card hover conceals its bound final detail", failures)
	projection.disabled_reason = ""
	card.present(projection)
	TestAssertions.equal(requested, [&"4:vitality"], "disabled-to-enabled card restores an already-hovered detail exactly once", failures)
	card.present(projection.copy())
	TestAssertions.equal(requested, [&"4:vitality"], "unchanged enabled refresh does not duplicate an active detail request", failures)

	var rebound := _card_projection("4:ranged_calibration", "Ranged Calibration")
	card.present(rebound)
	TestAssertions.equal(dismissed, [&"4:vitality"], "active rebind dismisses the prior detail source", failures)
	TestAssertions.equal(requested, [&"4:vitality", &"4:ranged_calibration"], "active rebind requests the new detail source exactly once", failures)
	card.mouse_exited.emit()
	TestAssertions.equal(dismissed, [&"4:vitality", &"4:ranged_calibration"], "hover exit dismisses the rebound detail source", failures)

	var focused_disabled := _card_projection("4:precision", "Precision")
	focused_disabled.disabled_reason = "Revealing."
	card.present(focused_disabled)
	card.focus_entered.emit()
	TestAssertions.equal(requested.size(), 2, "disabled keyboard/controller focus does not request detail", failures)
	focused_disabled.disabled_reason = ""
	card.present(focused_disabled)
	TestAssertions.equal(requested, [&"4:vitality", &"4:ranged_calibration", &"4:precision"], "disabled-to-enabled focused card requests its current detail exactly once", failures)
	card.present(focused_disabled.copy())
	TestAssertions.equal(requested.size(), 3, "unchanged focused refresh does not duplicate its detail request", failures)
	card.focus_exited.emit()
	TestAssertions.equal(dismissed, [&"4:vitality", &"4:ranged_calibration", &"4:precision"], "focus exit dismisses the current focused detail source", failures)
	card.free()

func _card_projection(key: String, display_name: String) -> UpgradeOfferProjection:
	var projection := UpgradeOfferProjection.new()
	projection.choice_key = key
	projection.display_name = display_name
	projection.category_id = &"authored"
	projection.effect_text = "Typed effect"
	projection.scope_text = "Personal"
	projection.rank_text = "Rank 1"
	projection.eligibility_text = "Eligible"
	return projection

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

func _test_input_configurator_preserves_existing_action(failures: Array[String]) -> void:
	var setting_path := "input/tooltip_hold"
	var original_setting: Variant = ProjectSettings.get_setting(setting_path)
	var additional_event := InputEventKey.new()
	additional_event.keycode = KEY_SHIFT
	var seeded_events: Array[InputEvent] = [additional_event]
	ProjectSettings.set_setting(
		setting_path,
		{"deadzone": 0.73, "events": seeded_events},
	)
	var configurator_script := load("res://tools/configure_tooltip_inputs.gd") as GDScript
	var configurator: SceneTree = configurator_script.new()
	configurator.call("_set_key_action", &"tooltip_hold", KEY_ALT)
	configurator.call("_set_key_action", &"tooltip_hold", KEY_ALT)
	var configured := ProjectSettings.get_setting(setting_path) as Dictionary
	var configured_events := configured.get("events", []) as Array
	var alt_count := 0
	for event: InputEvent in configured_events:
		if event is InputEventKey and event.keycode == KEY_ALT:
			alt_count += 1
	TestAssertions.equal(configured.get("deadzone"), 0.73, "tooltip input merge preserves custom deadzone", failures)
	TestAssertions.truthy(configured_events.has(additional_event), "tooltip input merge preserves unrelated event", failures)
	TestAssertions.equal(alt_count, 1, "tooltip input merge adds required event exactly once", failures)
	configurator.free()
	ProjectSettings.set_setting(setting_path, original_setting)

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
