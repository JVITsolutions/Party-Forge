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
	var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
	viewport.add_child(panel)
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"deadeye")),
	]
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
	panel.show_choices(choices, party)
	await _wait_for_layout()
	var content_panel := panel.get_node("ContentPanel") as Control
	var cards_row := panel.get_node("ContentPanel/OfferView/Content/Cards") as HBoxContainer
	for viewport_size: Vector2i in VIEWPORT_SIZES:
		var failure_count_before := _failures.size()
		viewport.size = viewport_size
		await _wait_for_layout()
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		var panel_rect := content_panel.get_global_rect()
		if not ResponsiveGeometry.contains(viewport_rect, panel_rect):
			_failures.append("panel overflows at %dx%d: viewport=%s panel=%s" % [viewport_size.x, viewport_size.y, viewport_rect, panel_rect])
		var visible_cards: Array[UpgradeCard] = []
		for child: Node in cards_row.get_children():
			if child is UpgradeCard and child.is_visible_in_tree():
				visible_cards.append(child as UpgradeCard)
		if visible_cards.size() != 5:
			_failures.append("expected five visible cards at %dx%d, got %d" % [viewport_size.x, viewport_size.y, visible_cards.size()])
		for index: int in visible_cards.size():
			var card := visible_cards[index]
			var card_rect := card.get_global_rect()
			if not ResponsiveGeometry.contains(panel_rect, card_rect):
				_failures.append("Card%d overflows panel at %dx%d: panel=%s card=%s" % [index + 1, viewport_size.x, viewport_size.y, panel_rect, card_rect])
			for other_index: int in range(index + 1, visible_cards.size()):
				var other_rect := visible_cards[other_index].get_global_rect()
				if card_rect.intersects(other_rect):
					_failures.append("Card%d intersects Card%d at %dx%d: first=%s second=%s" % [index + 1, other_index + 1, viewport_size.x, viewport_size.y, card_rect, other_rect])
			var compact := viewport_size.x < 1400
			for label_name: String in ["Eligibility", "Recipient", "Inheritance"]:
				var label := card.get_node("Content/%s" % label_name) as Label
				if label.visible == compact:
					_failures.append("Card%d %s compact visibility is wrong at %dx%d" % [index + 1, label_name, viewport_size.x, viewport_size.y])
			for label_name: String in ["Name", "Scope", "Rank", "Summary"]:
				if not (card.get_node("Content/%s" % label_name) as Label).visible:
					_failures.append("Card%d %s is hidden at %dx%d" % [index + 1, label_name, viewport_size.x, viewport_size.y])
		if _failures.size() == failure_count_before:
			print("LEVEL_UP_FIVE_CARD_SIZE_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])
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
