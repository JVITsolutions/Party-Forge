extends SceneTree

const LEDGER_SCENE_PATH := "res://scenes/ui/ledger/character_ledger.tscn"
const PARTY_SCROLL_PATH := ^"Overlay/Frame/Layout/Body/PartyScroll"
const MEMBER_1_PATH := ^"Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_1"
const MEMBER_24_PATH := ^"Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_24"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _exercise_viewport(Vector2i(1920, 1080), false)
	await _exercise_viewport(Vector2i(960, 540), true)
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


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
