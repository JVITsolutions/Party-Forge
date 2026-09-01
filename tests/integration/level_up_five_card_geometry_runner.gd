extends SceneTree

const ResponsiveGeometry := preload("res://tests/support/responsive_geometry.gd")
const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const SUPPORTED_OFFER_COUNTS: Array[int] = [1, 5, 7, 8]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = VIEWPORT_SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var panel_scene := load("res://scenes/ui/level_up_panel.tscn") as PackedScene
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"ranger"))
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(catalog.upgrade_by_id(&"ranged_calibration")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"fleetfoot")),
	]
	var probe := panel_scene.instantiate() as LevelUpPanel
	var card_probe := UpgradeCard.new()
	var typed_contract := probe.get_node_or_null("Frame/Content/Offer/CardsScroll/Cards") != null and card_probe.has_method(&"bound_choice_key")
	card_probe.free()
	probe.free()
	if not typed_contract:
		_failures.append("Living Forge bounded typed offer geometry is not implemented")
		viewport.free()
		party.free()
		for failure: String in _failures:
			push_error("LEVEL_UP_FIVE_CARD_FAILURE: %s" % failure)
		print("LEVEL_UP_FIVE_CARD_SUMMARY: FAIL (%d failures)" % _failures.size())
		quit(1)
		return
	for viewport_size: Vector2i in VIEWPORT_SIZES:
		var failure_count_before := _failures.size()
		viewport.size = viewport_size
		var panel := panel_scene.instantiate() as LevelUpPanel
		viewport.add_child(panel)
		panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
		var content_panel := panel.get_node("Frame") as Control
		var cards_scroll := panel.get_node("Frame/Content/Offer/CardsScroll") as ScrollContainer
		var cards_row := panel.get_node("Frame/Content/Offer/CardsScroll/Cards") as HBoxContainer
		var reveal := panel.get_node("RevealController") as LevelUpRevealController
		var tooltip := panel.get_node("TooltipPanel") as UpgradeTooltipPanel
		panel.configure_reduced_motion(false)
		panel.show_choices(choices, party)
		await _wait_for_layout()
		_assert(reveal.is_revealing(), "animated reveal starts at %dx%d" % [viewport_size.x, viewport_size.y])
		await _push_action(viewport, &"ui_cancel")
		_assert(not reveal.is_revealing(), "reveal skip resolves at %dx%d" % [viewport_size.x, viewport_size.y])
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		var panel_rect := content_panel.get_global_rect()
		_assert(
			ResponsiveGeometry.contains(viewport_rect, panel_rect),
			"panel overflows at %dx%d: viewport=%s panel=%s" % [viewport_size.x, viewport_size.y, viewport_rect, panel_rect]
		)
		_assert(panel_rect.size.x <= 1800.0, "stylized modal remains bounded at %dx%d: width=%s" % [viewport_size.x, viewport_size.y, panel_rect.size.x])
		_assert(absf(panel_rect.get_center().x - viewport_rect.get_center().x) <= 2.0, "stylized modal stays horizontally centered at %dx%d" % [viewport_size.x, viewport_size.y])
		var visible_cards: Array[UpgradeCard] = []
		for child: Node in cards_row.get_children():
			if child is UpgradeCard and child.is_visible_in_tree():
				visible_cards.append(child as UpgradeCard)
		_assert(visible_cards.size() == 5, "expected five visible cards at %dx%d, got %d" % [viewport_size.x, viewport_size.y, visible_cards.size()])
		for index: int in visible_cards.size():
			var card := visible_cards[index]
			var card_rect := card.get_global_rect()
			_assert(card_rect.size.x >= 168.0 and card_rect.size.y >= 300.0, "Card%d respects readable minimum geometry at %dx%d" % [index + 1, viewport_size.x, viewport_size.y])
			_assert(card.custom_minimum_size.y >= 300.0, "Card%d keeps a stable minimum height at %dx%d" % [index + 1, viewport_size.x, viewport_size.y])
			_assert(
				ResponsiveGeometry.contains(panel_rect, card_rect),
				"Card%d overflows panel at %dx%d: panel=%s card=%s" % [index + 1, viewport_size.x, viewport_size.y, panel_rect, card_rect]
			)
			for other_index: int in range(index + 1, visible_cards.size()):
				var other_rect := visible_cards[other_index].get_global_rect()
				_assert(
					not card_rect.intersects(other_rect),
					"Card%d intersects Card%d at %dx%d: first=%s second=%s" % [index + 1, other_index + 1, viewport_size.x, viewport_size.y, card_rect, other_rect]
				)
			for label_name: String in ["Eligibility", "Scope", "Rank", "Summary"]:
				var label := card.find_child(label_name, true, false) as Label
				_assert(label.visible, "Card%d semantic %s is hidden at %dx%d" % [index + 1, label_name, viewport_size.x, viewport_size.y])
			_assert_offer_card_vertical_bounds(card, cards_scroll, choices[index], index, viewport_size)
			_assert(not card.accessibility_name.is_empty(), "Card%d exposes a semantic accessibility name at %dx%d" % [index + 1, viewport_size.x, viewport_size.y])
			if index > 0:
				_assert(absf(card_rect.size.x - visible_cards[0].get_global_rect().size.x) <= 2.0, "Card%d matches equal-card width at %dx%d" % [index + 1, viewport_size.x, viewport_size.y])
		if visible_cards.size() == 5:
			if viewport_size == VIEWPORT_SIZES[0]:
				await _assert_authentic_tooltip_input_parity(viewport, panel, tooltip, visible_cards[0], choices[0])
				await _assert_disabled_to_enabled_ranged_detail(viewport, panel, tooltip, visible_cards[0], choices[0])
				await _assert_first_slot_ranged_calibration_detail(viewport, tooltip, cards_scroll, visible_cards[0], choices[0])
			for index: int in visible_cards.size():
				_assert(
					viewport.gui_get_focus_owner() == visible_cards[index],
					"Card%d receives sequential focus at %dx%d" % [index + 1, viewport_size.x, viewport_size.y]
				)
				_assert_focused_offer_card_and_cta_visible(cards_scroll, visible_cards[index], index, viewport_size)
				await _assert_full_tooltip(tooltip, choices[index], viewport_size)
				if index + 1 < visible_cards.size():
					await _push_action(viewport, &"ui_right")
			for index: int in range(visible_cards.size() - 2, -1, -1):
				await _push_action(viewport, &"ui_left")
				_assert(
					viewport.gui_get_focus_owner() == visible_cards[index],
					"Card%d receives reverse focus at %dx%d" % [index + 1, viewport_size.x, viewport_size.y]
				)
		panel.configure_reduced_motion(true)
		panel.show_choices(choices, party)
		_assert(not reveal.is_revealing(), "reduced motion resolves directly at %dx%d" % [viewport_size.x, viewport_size.y])
		await _wait_for_layout()
		if visible_cards.size() == 5:
			_assert(viewport.gui_get_focus_owner() == visible_cards[0], "reduced motion focuses Card1 at %dx%d" % [viewport_size.x, viewport_size.y])
			if viewport_size == VIEWPORT_SIZES[0]:
				_assert_ranged_calibration_tooltip_identity(tooltip, choices[0], "reduced-motion focus")
			for index: int in visible_cards.size():
				_assert(not visible_cards[index].disabled, "reduced motion enables Card%d at %dx%d" % [index + 1, viewport_size.x, viewport_size.y])
				_assert(visible_cards[index].bound_choice_key() == StringName(choices[index].key()), "reduced motion preserves Card%d activation identity at %dx%d" % [index + 1, viewport_size.x, viewport_size.y])
		if _failures.size() == failure_count_before:
			print("LEVEL_UP_FIVE_CARD_ACCEPTANCE_SIZE_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])
		panel.free()
	await _assert_pooled_card_details_scroll_reset(viewport)
	await _assert_supported_offer_count_and_scale_geometry(viewport, panel_scene, catalog, party)
	viewport.free()
	party.free()
	if _failures.is_empty():
		print("LEVEL_UP_FIVE_CARD_SUMMARY: PASS (%d sizes)" % VIEWPORT_SIZES.size())
		quit(0)
		return
	for failure: String in _failures:
		push_error("LEVEL_UP_FIVE_CARD_FAILURE: %s" % failure)
	print("LEVEL_UP_FIVE_CARD_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _assert_pooled_card_details_scroll_reset(viewport: SubViewport) -> void:
	viewport.size = Vector2i(1280, 720)
	var card := (load("res://scenes/ui/upgrade_card.tscn") as PackedScene).instantiate() as UpgradeCard
	card.position = Vector2(60.0, 60.0)
	card.size = Vector2(220.0, 340.0)
	viewport.add_child(card)
	var first := UpgradeOfferProjection.new()
	first.choice_key = "pooled:first"
	first.display_name = "First Pooled Offer"
	first.effect_text = ("First offer detail remains overflowable after a same-choice refresh. ").repeat(24)
	first.scope_text = "Party"
	first.rank_text = "Rank 1"
	first.eligibility_text = "Eligible"
	card.present(first)
	await _wait_for_layout()
	var details := card.get_node("Content/DetailsScroll") as ScrollContainer
	_assert(details.get_v_scroll_bar().max_value > details.get_v_scroll_bar().page, "pooled card fixture exposes real inner detail overflow")
	details.scroll_vertical = int(details.get_v_scroll_bar().max_value)
	await _wait_for_layout()
	var retained_offset := details.scroll_vertical
	_assert(retained_offset > int(details.get_v_scroll_bar().min_value), "pooled card fixture starts below the detail origin")
	card.present(first.copy())
	await _wait_for_layout()
	_assert(details.scroll_vertical == retained_offset, "same-choice card refresh preserves the reader's detail position")
	var second := first.copy()
	second.choice_key = "pooled:second"
	second.display_name = "Second Pooled Offer"
	second.effect_text = ("Second offer summary must begin at the first visible detail line after rebinding. ").repeat(24)
	card.present(second)
	await _wait_for_layout()
	var origin := int(details.get_v_scroll_bar().min_value)
	var summary := card.get_node("Content/DetailsScroll/Body/Summary") as Label
	var details_rect := details.get_global_rect()
	var summary_rect := summary.get_global_rect()
	_assert(details.scroll_vertical == origin, "changed pooled choice resets its detail scroll to the minimum origin")
	_assert(summary_rect.intersects(details_rect) and summary_rect.position.y >= details_rect.position.y - 1.0, "changed pooled choice exposes its summary as the first visible detail content: details=%s summary=%s" % [details_rect, summary_rect])
	card.free()
	await process_frame


func _assert_offer_card_vertical_bounds(
	card: UpgradeCard,
	cards_scroll: ScrollContainer,
	choice: UpgradeChoice,
	index: int,
	viewport_size: Vector2i,
) -> void:
	var details_scroll := card.get_node_or_null("Content/DetailsScroll") as ScrollContainer
	var footer := card.get_node_or_null("Content/Footer") as Control
	var action := card.find_child("Action", true, false) as Label
	var context := "Card%d at %dx%d" % [index + 1, viewport_size.x, viewport_size.y]
	_assert(details_scroll != null, "%s owns a bounded details viewport" % context)
	_assert(footer != null, "%s owns a pinned footer" % context)
	_assert(action != null, "%s exposes an action CTA" % context)
	if details_scroll == null or footer == null or action == null:
		return
	var card_rect := card.get_global_rect()
	var scroll_rect := cards_scroll.get_global_rect()
	var details_rect := details_scroll.get_global_rect()
	var footer_rect := footer.get_global_rect()
	var action_rect := action.get_global_rect()
	_assert(details_scroll.clip_contents, "%s clips variable body copy inside its details viewport" % context)
	_assert(ResponsiveGeometry.contains(card_rect, details_rect), "%s details viewport stays inside the card: card=%s details=%s" % [context, card_rect, details_rect])
	_assert(ResponsiveGeometry.contains(card_rect, footer_rect), "%s pinned footer stays inside the card: card=%s footer=%s" % [context, card_rect, footer_rect])
	_assert(ResponsiveGeometry.contains(card_rect, action_rect), "%s CTA stays inside the card: card=%s action=%s" % [context, card_rect, action_rect])
	_assert(details_rect.end.y <= footer_rect.position.y + 1.0, "%s body viewport does not overlap the pinned footer: details=%s footer=%s" % [context, details_rect, footer_rect])
	_assert(action_rect.position.y >= details_rect.end.y - 1.0, "%s CTA remains below variable body copy: details=%s action=%s" % [context, details_rect, action_rect])
	_assert(card_rect.position.y >= scroll_rect.position.y - 1.0 and card_rect.end.y <= scroll_rect.end.y + 1.0, "%s full card height stays visible in the offer viewport: offer=%s card=%s" % [context, scroll_rect, card_rect])
	var expected_action := "Apply" if choice.application_route() == UpgradeChoice.ApplicationRoute.DIRECT else "Choose Recipient"
	_assert(action.text == expected_action, "%s shows the expected %s CTA (actual=%s)" % [context, expected_action, action.text])


func _assert_focused_offer_card_and_cta_visible(
	cards_scroll: ScrollContainer,
	card: UpgradeCard,
	index: int,
	viewport_size: Vector2i,
) -> void:
	var action := card.find_child("Action", true, false) as Label
	var context := "focused Card%d at %dx%d" % [index + 1, viewport_size.x, viewport_size.y]
	_assert(ResponsiveGeometry.contains(cards_scroll.get_global_rect(), card.get_global_rect()), "%s is fully visible in the offer viewport: offer=%s card=%s" % [context, cards_scroll.get_global_rect(), card.get_global_rect()])
	if action != null:
		_assert(ResponsiveGeometry.contains(cards_scroll.get_global_rect(), action.get_global_rect()), "%s CTA is fully visible in the offer viewport: offer=%s action=%s" % [context, cards_scroll.get_global_rect(), action.get_global_rect()])


func _push_action(viewport: SubViewport, action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	viewport.push_input(press)
	await process_frame
	var release := press.duplicate() as InputEventAction
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _assert_full_tooltip(tooltip: UpgradeTooltipPanel, choice: UpgradeChoice, viewport_size: Vector2i) -> void:
	await _wait_for_layout()
	var context := "%s at %dx%d" % [choice.label, viewport_size.x, viewport_size.y]
	_assert(tooltip.visible, "full tooltip opens for %s" % context)
	_assert(not (tooltip.get_node("Content/Header/Title") as Label).text.is_empty(), "tooltip title renders for %s" % context)
	_assert(not (tooltip.get_node("Content/Rank") as Label).text.is_empty(), "tooltip rank renders for %s" % context)
	_assert(not (tooltip.get_node("Content/BodyScroll/Body/Description") as Label).text.is_empty(), "tooltip description renders for %s" % context)
	_assert(not (tooltip.get_node("Content/BodyScroll/Body/Effects") as Label).text.is_empty(), "tooltip effects render for %s" % context)
	_assert(not (tooltip.get_node("Content/BodyScroll/Body/Eligibility") as Label).text.is_empty(), "tooltip eligibility renders for %s" % context)
	_assert(not (tooltip.get_node("Content/BodyScroll/Body/Keywords") as Label).text.is_empty(), "tooltip keywords render for %s" % context)


func _assert_first_slot_ranged_calibration_detail(
	viewport: SubViewport,
	tooltip: UpgradeTooltipPanel,
	cards_scroll: ScrollContainer,
	card: UpgradeCard,
	choice: UpgradeChoice,
) -> void:
	card.grab_focus()
	await _wait_for_layout()
	var effects := (tooltip.get_node("Content/BodyScroll/Body/Effects") as Label).text
	var body_scroll := tooltip.get_node("Content/BodyScroll") as ScrollContainer
	_assert(card.bound_choice_key() == StringName(choice.key()), "first slot remains bound to Ranged Calibration")
	_assert(viewport.gui_get_focus_owner() == card, "Ranged Calibration detail retains focus on its source card")
	_assert(ResponsiveGeometry.contains(cards_scroll.get_global_rect(), card.get_global_rect()), "Ranged Calibration source remains visible in the offer scroll")
	_assert_ranged_calibration_tooltip_identity(tooltip, choice, "first-slot focus")
	_assert("10% increased Attack Range." in effects, "Ranged Calibration detail shows its +10% Attack Range effect")
	_assert("10% increased Projectile Speed." in effects, "Ranged Calibration detail shows its +10% Projectile Speed effect")
	_assert(body_scroll.scroll_vertical == int(body_scroll.get_v_scroll_bar().min_value), "Ranged Calibration detail opens at its scroll origin")


func _assert_disabled_to_enabled_ranged_detail(
	viewport: SubViewport,
	panel: LevelUpPanel,
	tooltip: UpgradeTooltipPanel,
	card: UpgradeCard,
	choice: UpgradeChoice,
) -> void:
	var sink := Button.new()
	sink.name = "DisabledTransitionSink"
	sink.position = Vector2(8.0, 8.0)
	sink.size = Vector2(48.0, 48.0)
	panel.add_child(sink)
	await _push_mouse_motion(viewport, Vector2(2.0, 2.0))
	sink.grab_focus()
	await _wait_for_layout()
	tooltip.force_dismiss()

	var enabled_projection := (card.get("_projection") as UpgradeOfferProjection).copy()
	var disabled_projection := enabled_projection.copy()
	disabled_projection.disabled_reason = "Revealing."
	card.present(disabled_projection)
	await _wait_for_layout()
	var requests: Array[StringName] = []
	card.detail_requested.connect(func(choice_key: StringName, _anchor: Control) -> void: requests.append(choice_key))
	await _push_mouse_motion(viewport, card.get_global_rect().get_center())
	_assert(bool(card.get("_mouse_inside")), "Ranged Calibration pointer remains inside while the card is disabled")
	_assert(not tooltip.visible, "disabled Ranged Calibration card conceals its tooltip")
	card.present(enabled_projection)
	await _wait_for_layout()
	_assert(requests == [StringName(choice.key())], "disabled-to-enabled hovered Ranged Calibration emits exactly one current detail request")
	_assert_ranged_calibration_tooltip_identity(tooltip, choice, "disabled-to-enabled hover")
	card.present(enabled_projection.copy())
	await _wait_for_layout()
	_assert(requests.size() == 1, "unchanged enabled Ranged Calibration refresh does not duplicate its detail request")
	await _push_mouse_motion(viewport, Vector2(2.0, 2.0))
	_assert(not tooltip.visible, "normal pointer navigation dismisses the reconciled Ranged Calibration tooltip")
	sink.queue_free()
	await process_frame


func _assert_authentic_tooltip_input_parity(
	viewport: SubViewport,
	panel: LevelUpPanel,
	tooltip: UpgradeTooltipPanel,
	card: UpgradeCard,
	choice: UpgradeChoice,
) -> void:
	var sink := Button.new()
	sink.name = "TooltipInputSink"
	sink.position = Vector2(8.0, 8.0)
	sink.size = Vector2(48.0, 48.0)
	panel.add_child(sink)
	sink.focus_next = sink.get_path_to(card)
	sink.grab_focus()
	await _push_mouse_motion(viewport, card.get_global_rect().get_center())
	_assert(card.get("_mouse_inside"), "real mouse motion enters UpgradeCard")
	_assert(tooltip.visible, "real mouse hover opens the shared tooltip")
	_assert_ranged_calibration_tooltip_identity(tooltip, choice, "real mouse hover")
	var mouse_content := _tooltip_content_signature(tooltip)
	await _push_mouse_motion(viewport, Vector2(2.0, 2.0))
	_assert(not tooltip.visible, "real mouse motion outside dismisses the shared tooltip")

	sink.grab_focus()
	await _push_key(viewport, KEY_TAB)
	_assert(card.has_focus(), "real keyboard focus reaches UpgradeCard")
	_assert(tooltip.visible and _tooltip_content_signature(tooltip) == mouse_content, "keyboard focus opens identical tooltip content")
	_assert_ranged_calibration_tooltip_identity(tooltip, choice, "real keyboard focus")
	sink.grab_focus()
	await process_frame
	_assert(not tooltip.visible, "keyboard focus exit dismisses the tooltip")

	card.focus_neighbor_left = card.get_path_to(card)
	card.grab_focus()
	sink.grab_focus()
	sink.focus_neighbor_left = sink.get_path_to(card)
	await _push_joypad_button(viewport, JOY_BUTTON_DPAD_LEFT)
	_assert(card.has_focus(), "real controller focus reaches UpgradeCard")
	_assert(tooltip.visible and _tooltip_content_signature(tooltip) == mouse_content, "controller focus opens identical tooltip content")
	_assert_ranged_calibration_tooltip_identity(tooltip, choice, "real controller focus")
	sink.grab_focus()
	await process_frame
	_assert(not tooltip.visible, "controller focus exit dismisses the tooltip")
	sink.queue_free()
	await process_frame
	card.grab_focus()
	await process_frame


func _assert_ranged_calibration_tooltip_identity(
	tooltip: UpgradeTooltipPanel,
	choice: UpgradeChoice,
	input_context: String,
) -> void:
	var expected_source := StringName(choice.key())
	var title := (tooltip.get_node("Content/Header/Title") as Label).text
	var effects := (tooltip.get_node("Content/BodyScroll/Body/Effects") as Label).text
	_assert(tooltip.visible, "%s opens the Ranged Calibration detail popup" % input_context)
	_assert(tooltip.current_source_id() == expected_source, "%s retains the exact Ranged Calibration source key" % input_context)
	_assert(title == "Ranged Calibration", "%s renders the exact Ranged Calibration title" % input_context)
	_assert(effects == "10% increased Attack Range.\n10% increased Projectile Speed.", "%s renders only the authoritative rank-one Ranged Calibration effects" % input_context)


func _tooltip_content_signature(tooltip: UpgradeTooltipPanel) -> PackedStringArray:
	return PackedStringArray([
		(tooltip.get_node("Content/Header/Title") as Label).text,
		(tooltip.get_node("Content/Rank") as Label).text,
		(tooltip.get_node("Content/BodyScroll/Body/Description") as Label).text,
		(tooltip.get_node("Content/BodyScroll/Body/Effects") as Label).text,
		(tooltip.get_node("Content/BodyScroll/Body/Eligibility") as Label).text,
		(tooltip.get_node("Content/BodyScroll/Body/Keywords") as Label).text,
	])


func _push_mouse_motion(viewport: SubViewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion)
	await process_frame
	await process_frame


func _push_key(viewport: SubViewport, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	viewport.push_input(press)
	await process_frame
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _push_joypad_button(viewport: SubViewport, button: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button
	press.pressed = true
	viewport.push_input(press)
	await process_frame
	var release := press.duplicate() as InputEventJoypadButton
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _assert_supported_offer_count_and_scale_geometry(
	viewport: SubViewport,
	panel_scene: PackedScene,
	catalog: GameCatalog,
	party: PartyManager,
) -> void:
	viewport.size = Vector2i(1280, 720)
	var all_choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"fleetfoot")),
		UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage"),
		UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"move_speed", "Move Speed"),
		UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"pickup_radius", "Pickup Radius"),
	]
	for scale_pair: Vector2i in [Vector2i(150, 150), Vector2i(80, 150)]:
		for offer_count: int in SUPPORTED_OFFER_COUNTS:
			var panel := panel_scene.instantiate() as LevelUpPanel
			viewport.add_child(panel)
			panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
			var settings := PartyForgeSettings.new()
			settings.ui_scale_percent = scale_pair.x
			settings.text_scale_percent = scale_pair.y
			settings.reduced_motion = true
			panel.configure_visual_settings(settings)
			var choices: Array[UpgradeChoice] = []
			choices.assign(all_choices.slice(0, offer_count))
			panel.show_choices(choices, party)
			await _wait_for_layout()
			var frame := panel.get_node("Frame") as Control
			var scroll := panel.get_node("Frame/Content/Offer/CardsScroll") as ScrollContainer
			var cards := panel.get_node("Frame/Content/Offer/CardsScroll/Cards") as HBoxContainer
			var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport.size))
			_assert(ResponsiveGeometry.contains(viewport_rect, frame.get_global_rect()), "frame contained for %d offers at ui%d/text%d" % [offer_count, scale_pair.x, scale_pair.y])
			_assert(ResponsiveGeometry.contains(frame.get_global_rect(), scroll.get_global_rect()), "offer scroll contained for %d offers at ui%d/text%d" % [offer_count, scale_pair.x, scale_pair.y])
			var visible_cards: Array[UpgradeCard] = []
			for child: Node in cards.get_children():
				if child is UpgradeCard and child.visible:
					visible_cards.append(child as UpgradeCard)
			_assert(visible_cards.size() == offer_count, "all %d offers render at ui%d/text%d" % [offer_count, scale_pair.x, scale_pair.y])
			for card: UpgradeCard in visible_cards:
				card.grab_focus()
				await _wait_for_layout()
				_assert(card.has_focus(), "%s remains keyboard/controller reachable at ui%d/text%d" % [card.name, scale_pair.x, scale_pair.y])
				var visible_slice := scroll.get_global_rect().intersection(card.get_global_rect())
				_assert(visible_slice.size.x > 0.0 and visible_slice.size.y > 0.0, "%s focus scrolls meaningful content into the bounded offer viewport at ui%d/text%d scroll=%s card=%s h=%d/%s" % [card.name, scale_pair.x, scale_pair.y, scroll.get_global_rect(), card.get_global_rect(), scroll.scroll_horizontal, scroll.get_h_scroll_bar().max_value])
				scroll.scroll_vertical = int(scroll.get_v_scroll_bar().min_value)
				await _wait_for_layout()
				_assert(card.get_global_rect().position.y >= scroll.get_global_rect().position.y - 1.0, "%s top remains reachable at ui%d/text%d" % [card.name, scale_pair.x, scale_pair.y])
				scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
				await _wait_for_layout()
				_assert(card.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1.0, "%s bottom remains reachable at ui%d/text%d" % [card.name, scale_pair.x, scale_pair.y])
			if offer_count >= 7:
				var horizontal := scroll.get_h_scroll_bar()
				_assert(horizontal.max_value > horizontal.page and scroll.scroll_horizontal > 0, "%d offers expose and traverse horizontal overflow at ui%d/text%d" % [offer_count, scale_pair.x, scale_pair.y])
			if offer_count == 1:
				await _assert_scaled_confirmation_containment(panel, choices[0], scale_pair)
			panel.free()


func _assert_scaled_confirmation_containment(panel: LevelUpPanel, choice: UpgradeChoice, scale_pair: Vector2i) -> void:
	if choice.application_route() == UpgradeChoice.ApplicationRoute.DIRECT:
		return
	var card := panel.get_node("Frame/Content/Offer/CardsScroll/Cards").get_child(0) as UpgradeCard
	card.activated.emit(card.bound_choice_key())
	if choice.application_route() == UpgradeChoice.ApplicationRoute.RECIPIENT_CONFIRMATION:
		(panel.get_node("Frame/Content/Recipient/Content/RecipientsScroll/Rows/Member_1") as Button).pressed.emit()
	var confirmation := panel.get_node("Frame/Content/Confirmation/BodyScroll") as ScrollContainer
	var effect := panel.get_node("Frame/Content/Confirmation/BodyScroll/Body/Effect") as Label
	effect.text = (effect.text + " Long semantic consequence remains readable.").repeat(30)
	var confirm := panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button
	confirm.grab_focus()
	await _wait_for_layout()
	_assert(ResponsiveGeometry.contains((panel.get_node("Frame") as Control).get_global_rect(), confirmation.get_global_rect()), "scaled confirmation remains frame-contained at ui%d/text%d" % [scale_pair.x, scale_pair.y])
	_assert(ResponsiveGeometry.contains((panel.get_node("Frame") as Control).get_global_rect(), confirm.get_global_rect()), "scaled confirmation action remains fixed and reachable at ui%d/text%d" % [scale_pair.x, scale_pair.y])
	_assert(confirmation.get_v_scroll_bar().max_value > confirmation.get_v_scroll_bar().page, "long scaled confirmation exposes vertical overflow at ui%d/text%d" % [scale_pair.x, scale_pair.y])


func _assert(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
