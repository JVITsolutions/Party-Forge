extends SceneTree

const LOBBY_SCENE := preload("res://scenes/ui/run_setup/run_setup_lobby_panel.tscn")
const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(3840, 2160),
]
const MAX_WAIT_FRAMES := 30

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var viewport := root
	viewport.mode = Window.MODE_WINDOWED
	viewport.content_scale_size = Vector2i.ZERO
	viewport.size = Vector2i(1920, 1080)
	var panel := LOBBY_SCENE.instantiate() as ClassSelectionPanel
	viewport.add_child(panel)
	panel.configure(GameCatalog.load_defaults())
	await _wait_for_layout(panel, "initial lobby layout")
	await _test_initial_focus_priority(viewport, panel)
	await _test_pending_and_error_focus(viewport, panel)
	await _test_gate_restore_branches(viewport, panel)
	await _test_action_matrix_focus(viewport, panel)
	await _test_real_input_focus_graph(viewport, panel)
	await _test_real_layout(viewport, panel)
	panel.free()
	if _failures.is_empty():
		print("RUN_SETUP_LOBBY_PANEL_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("RUN_SETUP_LOBBY_PANEL_FAILURE: %s" % failure)
	print("RUN_SETUP_LOBBY_PANEL_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _test_initial_focus_priority(viewport: Window, panel: ClassSelectionPanel) -> void:
	panel.present(_projection(RunSetupLobbyProjection.State.NO_SELECTION, &"", &"mage", RunSetupClassProjection.Compatibility.UNKNOWN))
	panel.open()
	var fighter := panel.selection_focus(&"fighter")
	await _expect_focus(viewport, fighter, "no selection focuses first projected Fighter despite Mage preview")
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"mage", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
	panel.open()
	await _expect_focus(viewport, panel.selection_focus(&"mage"), "selected Mage takes initial-focus priority over Fighter preview")


func _test_pending_and_error_focus(viewport: Window, panel: ClassSelectionPanel) -> void:
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
	panel.open()
	var start := panel.action_focus(&"start") as Button
	await _give_focus(viewport, start, "Ready Start origin receives focus")
	panel.set_pending(RunSetupLobbyProjection.State.STARTING, start)
	await _expect_focus(viewport, start, "Starting retains initiating Start focus")
	_assert(not bool(start.get_meta(&"action_enabled", true)), "Starting Start is action-disabled while retaining focus context")
	panel.present(_projection(RunSetupLobbyProjection.State.ERROR, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.UNKNOWN))
	await _expect_focus(viewport, start, "ERROR restores actual GUI focus to initiating Start")
	_assert(not bool(start.get_meta(&"action_enabled", true)), "ERROR-restored Start remains action-disabled")
	var starts: Array[StringName] = []
	panel.start_requested.connect(func(class_id: StringName) -> void: starts.append(class_id))
	start.pressed.emit()
	_assert(starts.is_empty(), "ERROR-restored Start rejects activation while it owns recovery focus")
	await _send_ui_action(viewport, &"ui_focus_next")
	await _expect_focus(viewport, panel.selection_focus(&"fighter"), "Tab leaves recovered Start for the first roster card")
	await process_frame
	_assert(start.disabled and start.focus_mode == Control.FOCUS_NONE, "disabled Start leaves the focus graph after recovery focus departs")
	await _send_ui_action(viewport, &"ui_focus_prev")
	await _expect_focus(viewport, panel.action_focus(&"select"), "reverse Tab skips expired unavailable Start context")
	start.pressed.emit()
	_assert(starts.is_empty(), "expired unavailable Start cannot emit authority")
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
	panel.open()
	await _give_focus(viewport, start, "close lifecycle fixture refocuses Ready Start")
	panel.set_pending(RunSetupLobbyProjection.State.STARTING, start)
	panel.present(_projection(RunSetupLobbyProjection.State.ERROR, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.UNKNOWN))
	await _expect_focus(viewport, start, "close lifecycle fixture restores ERROR Start")
	panel.close()
	_assert(start.disabled and start.focus_mode == Control.FOCUS_NONE, "close immediately expires recovered disabled Start")
	await process_frame
	panel.open()
	await _expect_focus(viewport, panel.selection_focus(&"fighter"), "reopened ERROR lobby selects a stable actionable focus")
	_assert(start.disabled and start.focus_mode == Control.FOCUS_NONE, "close expires recovered disabled Start before reopen")
	start.pressed.emit()
	_assert(starts.is_empty(), "reopened ERROR lobby cannot emit stale Start authority")

	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
	var mage := panel.selection_focus(&"mage")
	await _give_focus(viewport, mage, "class recovery origin receives focus")
	panel.set_pending(RunSetupLobbyProjection.State.CHECKING, mage)
	await _expect_focus(viewport, mage, "Checking retains initiating class focus")
	panel.present(_projection(RunSetupLobbyProjection.State.ERROR, &"fighter", &"mage", RunSetupClassProjection.Compatibility.UNKNOWN))
	await _expect_focus(viewport, mage, "ERROR restores actual GUI focus to initiating class")


func _test_gate_restore_branches(viewport: Window, panel: ClassSelectionPanel) -> void:
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
	panel.open()
	var mage := panel.selection_focus(&"mage")
	var back := panel.action_focus(&"back")
	panel.begin_compatibility_gate(&"mage", mage)
	await _give_focus(viewport, back, "gate true fixture moves focus away from class origin")
	panel.end_compatibility_gate(true)
	await _expect_focus(viewport, mage, "end_compatibility_gate true restores actual class focus")

	panel.begin_compatibility_gate(&"mage", mage)
	await _give_focus(viewport, back, "gate false fixture moves focus away from class origin")
	panel.end_compatibility_gate(false)
	await _wait_for_layout(panel, "gate false stable layout")
	_assert(viewport.gui_get_focus_owner() == back, "end_compatibility_gate false clears pending without restoring class focus")
	_assert(not panel.compatibility_gate_active(), "both gate branches terminate compatibility state")


func _test_action_matrix_focus(viewport: Window, panel: ClassSelectionPanel) -> void:
	for state: RunSetupLobbyProjection.State in [
		RunSetupLobbyProjection.State.NO_SELECTION,
		RunSetupLobbyProjection.State.CHECKING,
		RunSetupLobbyProjection.State.READY,
		RunSetupLobbyProjection.State.NEEDS_ATTENTION,
		RunSetupLobbyProjection.State.UNAVAILABLE,
		RunSetupLobbyProjection.State.STARTING,
		RunSetupLobbyProjection.State.ERROR,
	]:
		var selected_id := &"" if state == RunSetupLobbyProjection.State.NO_SELECTION else &"fighter"
		var compatibility := _compatibility_for_state(state)
		if state in [RunSetupLobbyProjection.State.CHECKING, RunSetupLobbyProjection.State.STARTING]:
			panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
			panel.open()
			var origin := panel.selection_focus(&"mage") if state == RunSetupLobbyProjection.State.CHECKING else panel.action_focus(&"start")
			await _give_focus(viewport, origin, "%s fixture origin receives focus" % RunSetupLobbyProjection.State.keys()[state])
			panel.set_pending(state, origin)
			await _expect_focus(viewport, origin, "%s retains real focus ownership" % RunSetupLobbyProjection.State.keys()[state])
			continue
		panel.present(_projection(state, selected_id, &"mage", compatibility))
		panel.open()
		var expected := panel.selection_focus(&"fighter")
		await _expect_focus(viewport, expected, "%s owns deterministic roster focus" % RunSetupLobbyProjection.State.keys()[state])


func _test_real_input_focus_graph(viewport: Window, panel: ClassSelectionPanel) -> void:
	viewport.size = Vector2i(1920, 1080)
	panel.apply_viewport_size(Vector2(viewport.size))
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
	panel.open()
	await _wait_for_layout(panel, "desktop input focus graph")
	var fighter := panel.selection_focus(&"fighter")
	await _give_focus(viewport, fighter, "desktop directional fixture focuses Fighter")
	await _send_ui_action(viewport, &"ui_down")
	await _expect_focus(viewport, panel.selection_focus(&"cleric"), "desktop ui_down follows explicit three-column neighbor")
	await _send_ui_action(viewport, &"ui_down")
	await _expect_focus(viewport, panel.selection_focus(&"frost_mage"), "desktop repeated ui_down follows the explicit roster column")
	await _give_focus(viewport, fighter, "desktop boundary fixture refocuses Fighter")
	await _send_ui_action(viewport, &"ui_up")
	await _expect_focus(viewport, fighter, "desktop top boundary remains inside the lobby")
	await _send_ui_action(viewport, &"ui_left")
	await _expect_focus(viewport, fighter, "desktop left boundary remains inside the lobby")
	await _send_ui_action(viewport, &"ui_focus_next")
	await _expect_focus(viewport, panel.selection_focus(&"ranger"), "desktop forward Tab follows exact order")
	await _send_ui_action(viewport, &"ui_focus_prev")
	await _expect_focus(viewport, fighter, "desktop reverse Tab follows exact order")
	var start := panel.action_focus(&"start")
	await _give_focus(viewport, start, "desktop action boundary fixture focuses Start")
	await _send_ui_action(viewport, &"ui_down")
	await _expect_focus(viewport, start, "action bottom boundary remains inside the lobby")
	await _send_ui_action(viewport, &"ui_left")
	await _expect_focus(viewport, panel.action_focus(&"select"), "action ui_left follows explicit neighbor")

	viewport.size = Vector2i(1280, 720)
	panel.apply_viewport_size(Vector2(viewport.size))
	await _wait_for_layout(panel, "compact input focus graph")
	await _give_focus(viewport, fighter, "compact directional fixture focuses Fighter")
	await _send_ui_action(viewport, &"ui_down")
	await _expect_focus(viewport, panel.selection_focus(&"mage"), "compact ui_down follows explicit two-column neighbor")


func _test_real_layout(viewport: Window, panel: ClassSelectionPanel) -> void:
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
	panel.open()
	var desktop_card_size := Vector2.ZERO
	for viewport_size: Vector2i in VIEWPORT_SIZES:
		viewport.size = viewport_size
		panel.apply_viewport_size(Vector2(viewport_size))
		await _wait_for_layout(panel, "lobby %dx%d layout" % [viewport_size.x, viewport_size.y])
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		var content := panel.get_node("Content") as Control
		var margin := panel.get_node("Content/Margin") as Control
		var body := panel.get_node("Content/Margin/Layout/Body") as HBoxContainer
		var left := panel.get_node("Content/Margin/Layout/Body/LeftColumn") as Control
		var hero := panel.get_node("Content/Margin/Layout/Body/HeroStage") as Control
		var details := panel.get_node("Content/Margin/Layout/Body/Details") as Control
		var status := panel.get_node("Content/Margin/Layout/Status") as Control
		var actions := panel.get_node("Content/Margin/Layout/ActionBar") as Control
		var seats := panel.get_node("Content/Margin/Layout/Body/LeftColumn/Seats") as GridContainer
		var roster := panel.get_node("Content/Margin/Layout/Body/LeftColumn/ClassRoster/Scroll/Grid") as GridContainer
		var expected_content_width := minf(float(viewport_size.x), RunSetupResponsiveLayout.MAX_CONTENT_WIDTH)
		var expected_content := Rect2(Vector2((float(viewport_size.x) - expected_content_width) * 0.5, 0.0), Vector2(expected_content_width, float(viewport_size.y)))
		_assert_rect_near(content.get_global_rect(), expected_content, "content cap", viewport_size)
		var expected_margin := Rect2(expected_content.position + Vector2(24.0, 16.0), expected_content.size - Vector2(48.0, 32.0))
		_assert_rect_near(margin.get_global_rect(), expected_margin, "exact 24px side and 16px vertical margins", viewport_size)
		_assert_enclosed(viewport_rect, panel, "full-screen panel", viewport_size)
		_assert_enclosed(content.get_global_rect(), margin, "24px/16px content margin", viewport_size)
		_assert_enclosed(margin.get_global_rect(), body, "body within content margins", viewport_size)
		_assert_enclosed(body.get_global_rect(), left, "left lobby column", viewport_size)
		_assert_enclosed(body.get_global_rect(), hero, "hero stage", viewport_size)
		_assert_enclosed(body.get_global_rect(), details, "details column", viewport_size)
		_assert_no_horizontal_overlap(left, hero, "left and hero", viewport_size)
		_assert_no_horizontal_overlap(hero, details, "hero and details", viewport_size)
		_assert_enclosed(margin.get_global_rect(), status, "status row", viewport_size)
		_assert_enclosed(margin.get_global_rect(), actions, "fixed action footer", viewport_size)
		_assert(body.get_global_rect().end.y <= actions.get_global_rect().position.y, "body does not overlap fixed footer at %dx%d" % [viewport_size.x, viewport_size.y])
		var compact := viewport_size.x < 1600 or viewport_size.y < 900
		_assert(seats.columns == (4 if compact else 2), "seat columns match mode at %dx%d" % [viewport_size.x, viewport_size.y])
		_assert(roster.columns == (2 if compact else 3), "roster columns match mode at %dx%d" % [viewport_size.x, viewport_size.y])
		_assert_seat_mode(seats, compact, viewport_size)
		var card_size := (roster.get_child(0) as Control).get_global_rect().size
		if viewport_size == Vector2i(1920, 1080):
			desktop_card_size = card_size
		if viewport_size == Vector2i(3840, 2160):
			_assert(card_size.is_equal_approx(desktop_card_size), "4K keeps 1080p card density actual=%s expected=%s" % [card_size, desktop_card_size])


func _wait_for_layout(panel: ClassSelectionPanel, description: String) -> void:
	var prior := PackedFloat32Array()
	var stable_frames := 0
	for _frame: int in MAX_WAIT_FRAMES:
		await process_frame
		var current := _layout_signature(panel)
		if current == prior and not current.is_empty() and current[2] > 0.0 and current[3] > 0.0:
			stable_frames += 1
			if stable_frames >= 2:
				return
		else:
			stable_frames = 0
		prior = current
	_failures.append("timed out waiting for %s" % description)


func _layout_signature(panel: ClassSelectionPanel) -> PackedFloat32Array:
	var body := panel.get_node_or_null("Content/Margin/Layout/Body") as Control
	var actions := panel.get_node_or_null("Content/Margin/Layout/ActionBar") as Control
	if body == null or actions == null:
		return PackedFloat32Array()
	var body_rect := body.get_global_rect()
	var actions_rect := actions.get_global_rect()
	return PackedFloat32Array([body_rect.position.x, body_rect.position.y, body_rect.size.x, body_rect.size.y, actions_rect.position.y, actions_rect.size.x])


func _expect_focus(viewport: Window, expected: Control, label: String) -> void:
	for _frame: int in MAX_WAIT_FRAMES:
		if viewport.gui_get_focus_owner() == expected:
			return
		await process_frame
	var actual := viewport.gui_get_focus_owner()
	_failures.append("%s expected=%s actual=%s" % [label, expected.get_path() if expected != null else NodePath(), actual.get_path() if actual != null else NodePath()])


func _give_focus(viewport: Window, target: Control, label: String) -> void:
	target.grab_focus()
	await _expect_focus(viewport, target, label)
	await process_frame


func _send_ui_action(viewport: Window, action: StringName) -> void:
	var keycode := {
		&"ui_left": KEY_LEFT,
		&"ui_right": KEY_RIGHT,
		&"ui_up": KEY_UP,
		&"ui_down": KEY_DOWN,
		&"ui_focus_next": KEY_TAB,
		&"ui_focus_prev": KEY_TAB,
	}.get(action, KEY_NONE) as Key
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.shift_pressed = action == &"ui_focus_prev"
	pressed.pressed = true
	viewport.push_input(pressed)
	await process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.shift_pressed = action == &"ui_focus_prev"
	released.pressed = false
	viewport.push_input(released)
	await process_frame


func _assert_seat_mode(seats: GridContainer, compact: bool, viewport_size: Vector2i) -> void:
	var first := (seats.get_child(0) as Control).get_global_rect()
	var second := (seats.get_child(1) as Control).get_global_rect()
	var third := (seats.get_child(2) as Control).get_global_rect()
	if compact:
		_assert(is_equal_approx(first.position.y, second.position.y) and is_equal_approx(second.position.y, third.position.y), "compact seats share one horizontal strip at %dx%d" % [viewport_size.x, viewport_size.y])
	else:
		_assert(is_equal_approx(first.position.y, second.position.y) and third.position.y >= first.end.y, "desktop seats form a non-overlapping 2x2 board at %dx%d" % [viewport_size.x, viewport_size.y])


func _assert_enclosed(outer: Rect2, control: Control, label: String, viewport_size: Vector2i) -> void:
	var actual := control.get_global_rect()
	_assert(control.is_visible_in_tree(), "%s visible at %dx%d" % [label, viewport_size.x, viewport_size.y])
	_assert(actual.size.x > 0.0 and actual.size.y > 0.0, "%s positive geometry at %dx%d actual=%s" % [label, viewport_size.x, viewport_size.y, actual])
	_assert(outer.grow(0.5).encloses(actual), "%s enclosed at %dx%d outer=%s actual=%s" % [label, viewport_size.x, viewport_size.y, outer, actual])


func _assert_no_horizontal_overlap(left: Control, right: Control, label: String, viewport_size: Vector2i) -> void:
	_assert(left.get_global_rect().end.x <= right.get_global_rect().position.x, "%s do not overlap at %dx%d left=%s right=%s" % [label, viewport_size.x, viewport_size.y, left.get_global_rect(), right.get_global_rect()])


func _assert_rect_near(actual: Rect2, expected: Rect2, label: String, viewport_size: Vector2i) -> void:
	_assert(actual.position.distance_to(expected.position) <= 0.5 and actual.size.distance_to(expected.size) <= 0.5, "%s exact at %dx%d expected=%s actual=%s" % [label, viewport_size.x, viewport_size.y, expected, actual])


func _projection(
	state: RunSetupLobbyProjection.State,
	selected_id: StringName,
	previewed_id: StringName,
	selected_compatibility: RunSetupClassProjection.Compatibility,
) -> RunSetupLobbyProjection:
	var classes: Array[RunSetupClassProjection] = []
	for definition: ClassDefinition in GameCatalog.load_defaults().classes:
		classes.append(RunSetupClassProjection.create(
			definition.id, definition.display_name, ClassDefinition.Role.keys()[definition.role].capitalize(), definition.color,
			[], String(definition.primary_attack.id).capitalize(),
			selected_compatibility if definition.id == selected_id else RunSetupClassProjection.Compatibility.UNKNOWN, {},
		))
	var projection := RunSetupLobbyProjection.create(
		[RunSetupSeatProjection.active(1, "P1"), RunSetupSeatProjection.coming_soon(2), RunSetupSeatProjection.coming_soon(3), RunSetupSeatProjection.coming_soon(4)],
		classes, selected_id, previewed_id, state, "Lobby state: %s" % RunSetupLobbyProjection.State.keys()[state],
	)
	projection.set_meta(&"armoury_available", true)
	return projection


func _compatibility_for_state(state: RunSetupLobbyProjection.State) -> RunSetupClassProjection.Compatibility:
	match state:
		RunSetupLobbyProjection.State.READY:
			return RunSetupClassProjection.Compatibility.COMPATIBLE
		RunSetupLobbyProjection.State.NEEDS_ATTENTION:
			return RunSetupClassProjection.Compatibility.NEEDS_ATTENTION
		RunSetupLobbyProjection.State.UNAVAILABLE:
			return RunSetupClassProjection.Compatibility.UNAVAILABLE
		_:
			return RunSetupClassProjection.Compatibility.UNKNOWN


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
