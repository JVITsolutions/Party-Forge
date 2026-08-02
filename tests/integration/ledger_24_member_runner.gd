extends SceneTree

const LEDGER_SCENE_PATH := "res://scenes/ui/ledger/character_ledger.tscn"
const PARTY_SCROLL_PATH := ^"Overlay/Frame/Layout/Body/PartyColumn/PartyScroll"
const PARTY_COUNT_PATH := ^"Overlay/Frame/Layout/Body/PartyColumn/PartyCount"
const MEMBER_1_PATH := ^"Overlay/Frame/Layout/Body/PartyColumn/PartyScroll/PartyEntries/Member_1"
const MEMBER_24_PATH := ^"Overlay/Frame/Layout/Body/PartyColumn/PartyScroll/PartyEntries/Member_24"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _exercise_viewport(Vector2i(1920, 1080), false)
	await _exercise_viewport(Vector2i(960, 540), true)
	await _exercise_provider_refresh_focus_lifecycle()
	if _failures.is_empty():
		print("LEDGER_24_MEMBER_SUMMARY: PASS (2 viewports)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LEDGER_24_MEMBER_FAILURE: %s" % failure)
	print("LEDGER_24_MEMBER_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _exercise_viewport(viewport_size: Vector2i, compact: bool) -> void:
	var mode := "compact" if compact else "desktop"
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for _index: int in 23:
		_assert(party.recruit(catalog.class_by_id(&"fighter")), "%s fixture recruits all 24 members" % mode)
	var member_state_24 := party.member_by_id(24)
	_assert(member_state_24 != null, "%s fixture includes member 24" % mode)
	if member_state_24 != null:
		member_state_24.character_name = "Twenty Four"

	var run := GameRun.new()
	run.start_run()
	var context := LedgerPlayerContext.new(0)
	context.selected_member_id = 1
	context.active_page_id = &"stats"
	var ledger := (load(LEDGER_SCENE_PATH) as PackedScene).instantiate() as CharacterLedger
	viewport.add_child(ledger)
	ledger.configure(run, party, catalog, Callable(), [context])
	ledger.apply_viewport_size(Vector2(viewport_size))
	_assert(ledger.open_for_player(), "%s ledger opens" % mode)
	_assert_label_text(ledger, PARTY_COUNT_PATH, "Party Members: 24 / 24", "%s count reports all developer members" % mode)
	await _wait_for_layout()

	var expected_frame := Rect2(
		Vector2(16.0, 12.0) if compact else Vector2(48.0, 36.0),
		Vector2(viewport_size) - (Vector2(32.0, 24.0) if compact else Vector2(96.0, 72.0)),
	)
	_assert_rect_near(ledger.get_node("Overlay/Frame").get_global_rect(), expected_frame, "%s uses the real viewport layout frame" % mode)
	var scroll := ledger.get_node(PARTY_SCROLL_PATH) as ScrollContainer
	var member_1 := ledger.get_node(MEMBER_1_PATH) as Button
	var member_24 := ledger.get_node(MEMBER_24_PATH) as Button
	var minimum_scroll := int(scroll.get_v_scroll_bar().min_value)

	member_24.grab_focus()
	await _wait_for_layout()
	_assert(scroll.scroll_vertical > minimum_scroll, "%s native focus scrolls member 24 into view" % mode)
	_assert(_rects_intersect(scroll, member_24), "%s directly focused member 24 intersects the roster viewport" % mode)
	member_24.pressed.emit()
	_assert(context.selected_member_id == 24, "%s direct press selects member 24" % mode)

	member_1.grab_focus()
	await _wait_for_layout()
	member_1.pressed.emit()
	await _wait_for_layout()
	_assert(context.selected_member_id == 1, "%s reset press selects member 1" % mode)
	_assert(scroll.scroll_vertical <= minimum_scroll + 1, "%s focusing member 1 returns roster scroll to its minimum" % mode)

	if compact:
		for _step: int in 7:
			await _push_action(viewport, &"ui_down")
		for _step: int in 2:
			await _push_action(viewport, &"ui_right")
	else:
		for _step: int in 23:
			await _push_action(viewport, &"ui_down")
	var directional_focus := viewport.gui_get_focus_owner() as Button
	_assert(directional_focus == member_24, "%s directional input reaches Member_24" % mode)
	_assert(scroll.scroll_vertical > minimum_scroll, "%s directional focus scrolls member 24 into view" % mode)
	_assert(_rects_intersect(scroll, member_24), "%s directionally focused member 24 intersects the roster viewport" % mode)
	if directional_focus != null:
		directional_focus.pressed.emit()
	_assert(context.selected_member_id == 24, "%s directional selection updates context to member 24" % mode)

	ledger.close()
	paused = false
	viewport.free()
	run.free()
	party.free()


func _exercise_provider_refresh_focus_lifecycle() -> void:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.members.append(PartyMemberState.new(24, catalog.class_by_id(&"fighter"), false, "Twenty Four"))
	var run := GameRun.new()
	run.start_run()
	var context := LedgerPlayerContext.new(0)
	var ledger := (load(LEDGER_SCENE_PATH) as PackedScene).instantiate() as CharacterLedger
	viewport.add_child(ledger)
	ledger.configure(run, party, catalog, Callable(), [context])
	ledger.apply_viewport_size(Vector2(viewport.size))
	_assert(ledger.open_for_player(), "refresh-focus ledger opens")
	_assert_label_text(ledger, PARTY_COUNT_PATH, "Party Members: 2 / 24", "refresh fixture count reports initial members")
	await _wait_for_layout()

	var scroll := ledger.get_node(PARTY_SCROLL_PATH) as ScrollContainer
	var member_24 := ledger.get_node(MEMBER_24_PATH) as Button
	member_24.grab_focus()
	_assert(viewport.gui_get_focus_owner() == member_24, "refresh fixture starts with actual member 24 focus")
	_assert(party.recruit(catalog.class_by_id(&"fighter")), "recruit triggers provider party refresh")
	_assert_label_text(ledger, PARTY_COUNT_PATH, "Party Members: 3 / 24", "refresh fixture count reports recruited member")
	await _wait_for_layout()
	var rebuilt_member_24 := ledger.get_node(MEMBER_24_PATH) as Button
	_assert(viewport.gui_get_focus_owner() == rebuilt_member_24, "provider refresh restores actual member 24 focus")
	_assert(_rects_intersect(scroll, rebuilt_member_24), "provider refresh keeps focused member 24 in the roster viewport")

	var stats_page := ledger.get_node("Overlay/Frame/Layout/Body/PageHost/StatsLedgerPage") as StatsLedgerPage
	var damage_button := stats_page.get_node("Layout/Content/StatSide/StatScroll/Groups/Group_offense/Stat_damage") as Button
	damage_button.grab_focus()
	_assert(viewport.gui_get_focus_owner() == damage_button, "Stats refresh fixture starts with actual stat-button focus")
	stats_page.refresh()
	await _wait_for_layout()
	var rebuilt_damage_button := stats_page.get_node("Layout/Content/StatSide/StatScroll/Groups/Group_offense/Stat_damage") as Button
	_assert(rebuilt_damage_button != damage_button, "Stats refresh replaces the focused stat button")
	_assert(rebuilt_damage_button.get_meta("stat_id") == &"damage", "Stats replacement preserves the focused stat ID")
	_assert(viewport.gui_get_focus_owner() == rebuilt_damage_button, "Stats refresh restores actual focus to the replacement stat button")

	var show_all := stats_page.get_node("Layout/Content/StatSide/ShowAll") as CheckButton
	show_all.grab_focus()
	stats_page.refresh()
	await _wait_for_layout()
	_assert(viewport.gui_get_focus_owner() == show_all, "Stats refresh does not steal focus from a non-stat control")
	ledger.refresh()
	await _wait_for_layout()
	_assert(viewport.gui_get_focus_owner() == show_all, "roster refresh does not steal active-page focus")

	_assert(ledger.select_member(24), "removal fixture selects member 24")
	rebuilt_member_24 = ledger.get_node(MEMBER_24_PATH) as Button
	rebuilt_member_24.grab_focus()
	party.members.erase(party.member_by_id(24))
	ledger.refresh()
	await _wait_for_layout()
	var fallback_member := ledger.get_node(MEMBER_1_PATH) as Button
	_assert(context.selected_member_id == 1, "removed focused selection falls back to member 1")
	_assert(viewport.gui_get_focus_owner() == fallback_member, "removed focused selection restores actual fallback member 1 focus")
	_assert(_rects_intersect(scroll, fallback_member), "removed focused selection keeps fallback member 1 in the roster viewport")

	ledger.close()
	paused = false
	viewport.free()
	run.free()
	party.free()


func _push_action(viewport: SubViewport, action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	viewport.push_input(press)
	var release := press.duplicate() as InputEventAction
	release.pressed = false
	viewport.push_input(release)
	await _wait_for_layout()


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _rects_intersect(scroll: ScrollContainer, member: Button) -> bool:
	return member.is_visible_in_tree() and scroll.get_global_rect().intersects(member.get_global_rect())


func _assert_rect_near(actual: Rect2, expected: Rect2, message: String) -> void:
	_assert(actual.position.is_equal_approx(expected.position) and actual.size.is_equal_approx(expected.size), "%s: expected=%s actual=%s" % [message, expected, actual])


func _assert_label_text(parent: Node, path: NodePath, expected: String, message: String) -> void:
	var node := parent.get_node_or_null(path)
	if node == null:
		_assert(false, "%s: missing Label at %s" % [message, path])
		return
	var label := node as Label
	if label == null:
		_assert(false, "%s: expected Label at %s, got %s" % [message, path, node.get_class()])
		return
	_assert(label.text == expected, "%s: expected=%s actual=%s" % [message, expected, label.text])


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
