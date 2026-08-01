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
	var panel_scene := load("res://scenes/ui/level_up_panel.tscn") as PackedScene
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"fleetfoot")),
	]
	for viewport_size: Vector2i in VIEWPORT_SIZES:
		var failure_count_before := _failures.size()
		viewport.size = viewport_size
		var panel := panel_scene.instantiate() as LevelUpPanel
		viewport.add_child(panel)
		panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
		# Give the hidden modal one layout pass so the reveal controller captures
		# the same settled card positions it receives after normal HUD layout.
		panel.visible = true
		await _wait_for_layout()
		var content_panel := panel.get_node("ContentPanel") as Control
		var cards_row := panel.get_node("ContentPanel/OfferView/Content/Cards") as HBoxContainer
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
		var visible_cards: Array[UpgradeCard] = []
		for child: Node in cards_row.get_children():
			if child is UpgradeCard and child.is_visible_in_tree():
				visible_cards.append(child as UpgradeCard)
		_assert(visible_cards.size() == 5, "expected five visible cards at %dx%d, got %d" % [viewport_size.x, viewport_size.y, visible_cards.size()])
		for index: int in visible_cards.size():
			var card := visible_cards[index]
			var card_rect := card.get_global_rect()
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
			var compact := viewport_size.x < 1400
			for label_name: String in ["Eligibility", "Recipient", "Inheritance"]:
				var label := card.get_node("Content/%s" % label_name) as Label
				_assert(label.visible != compact, "Card%d %s compact visibility is wrong at %dx%d" % [index + 1, label_name, viewport_size.x, viewport_size.y])
			for label_name: String in ["Name", "Scope", "Rank", "Summary"]:
				_assert((card.get_node("Content/%s" % label_name) as Label).visible, "Card%d %s is hidden at %dx%d" % [index + 1, label_name, viewport_size.x, viewport_size.y])
		if visible_cards.size() == 5:
			for index: int in visible_cards.size():
				_assert(
					viewport.gui_get_focus_owner() == visible_cards[index],
					"Card%d receives sequential focus at %dx%d" % [index + 1, viewport_size.x, viewport_size.y]
				)
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
		await _wait_for_layout()
		_assert(not reveal.is_revealing(), "reduced motion resolves directly at %dx%d" % [viewport_size.x, viewport_size.y])
		if visible_cards.size() == 5:
			_assert(viewport.gui_get_focus_owner() == visible_cards[0], "reduced motion focuses Card1 at %dx%d" % [viewport_size.x, viewport_size.y])
			for index: int in visible_cards.size():
				_assert(not visible_cards[index].disabled, "reduced motion enables Card%d at %dx%d" % [index + 1, viewport_size.x, viewport_size.y])
				_assert(visible_cards[index].bound_choice() == choices[index], "reduced motion preserves Card%d outcome at %dx%d" % [index + 1, viewport_size.x, viewport_size.y])
		if _failures.size() == failure_count_before:
			print("LEVEL_UP_FIVE_CARD_ACCEPTANCE_SIZE_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])
		panel.free()
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


func _assert(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
