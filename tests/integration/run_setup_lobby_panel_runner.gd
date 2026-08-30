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
	_test_nested_scroll_ancestor_resolution(viewport, panel)
	await _test_pending_and_error_focus(viewport, panel)
	await _test_gate_restore_branches(viewport, panel)
	await _test_action_matrix_focus(viewport, panel)
	await _test_real_input_focus_graph(viewport, panel)
	await _test_prompt_device_switching(viewport, panel)
	await _test_real_layout(viewport, panel)
	panel.free()
	if _restart_intent_runtime_contract_available():
		await _test_restart_intent_boot_routing()
	else:
		_failures.append("Task 12 RunSetupRestartIntent boot routing is unavailable")
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


func _test_nested_scroll_ancestor_resolution(viewport: Window, panel: ClassSelectionPanel) -> void:
	_assert(panel.has_method(&"_nearest_scroll_container"), "focus settlement exposes a nearest-scroll-ancestor resolver")
	if not panel.has_method(&"_nearest_scroll_container"):
		return
	var scroll := ScrollContainer.new()
	var intermediate := MarginContainer.new()
	var nested := Control.new()
	viewport.add_child(scroll)
	scroll.add_child(intermediate)
	intermediate.add_child(nested)
	_assert(panel.call(&"_nearest_scroll_container", nested) == scroll, "focus settlement resolves ScrollContainer through an intermediate layout ancestor")
	scroll.free()


func _restart_intent_runtime_contract_available() -> bool:
	var main_source := FileAccess.get_file_as_string("res://scripts/game/main.gd")
	return (
		ResourceLoader.exists("res://scripts/ui/run_setup/run_setup_restart_intent.gd")
		and "RunSetupRestartIntent" in main_source
		and "func _open_run_setup_from_restart(" in main_source
		and "set_meta" in main_source
		and "remove_meta" in main_source
	)


func _test_restart_intent_boot_routing() -> void:
	const INTENT_PATH := "res://scripts/ui/run_setup/run_setup_restart_intent.gd"
	const META_KEY := &"party_forge_run_setup_restart_intent"
	var fixture_root := "user://tests/run_setup_lobby_restart/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var profile_root := fixture_root.path_join("profiles")
	var settings_path := fixture_root.path_join("settings.json")
	ProfileTestSupport.remove_tree(fixture_root)
	var profiles := ProfileManager.new()
	_assert(profiles.bootstrap(profile_root).is_empty(), "restart-intent fixture bootstraps its profile root")
	var intended := profiles.create_profile("Restart Intended")
	var fallback := profiles.create_profile("Restart Fallback")
	_assert(intended.ok() and fallback.ok(), "restart-intent fixture creates exact intended and fallback profiles")
	if not intended.ok() or not fallback.ok():
		ProfileTestSupport.remove_tree(fixture_root)
		return
	_assert(profiles.select_profile(fallback.profile.profile_id).is_empty(), "restart-intent fixture makes a different profile active before boot")
	_assert(ResourceLoader.exists(INTENT_PATH), "RunSetupRestartIntent resource exists for boot routing")
	if not ResourceLoader.exists(INTENT_PATH):
		ProfileTestSupport.remove_tree(fixture_root)
		return
	var intent_script := load(INTENT_PATH) as GDScript
	var valid_intent: Variant = intent_script.call(&"create", intended.profile.profile_id, &"mage", "")
	_assert(valid_intent != null and bool(valid_intent.call(&"valid")), "valid restart intent retains exact profile and class")
	set_meta(META_KEY, valid_intent)
	var main := await _new_main(profile_root, settings_path)
	var lobby := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var start := lobby.action_focus(&"start") as Button
	_assert(not has_meta(META_KEY), "Main consumes restart metadata exactly once at boot")
	_assert(main.active_profile() != null and main.active_profile().profile_id == intended.profile.profile_id, "restart boot activates the exact intended profile")
	_assert(lobby.is_open() and lobby.selected_class_id() == &"mage" and lobby.previewed_class_id() == &"mage", "restart boot opens the lobby with the exact prior class preselected")
	_assert(not main.run_started and main.active_run_context == null and (main.active_profile() == null or main.active_profile().resumable_run.is_empty()), "restart boot never checks out or auto-starts the selected run")
	_assert(start != null and not start.disabled, "valid restart intent leaves Start Run available but uninvoked")
	main.free()
	await process_frame
	var ordinary_boot := await _new_main(profile_root, settings_path)
	_assert(not (ordinary_boot.get_node("HUD/ClassSelection") as ClassSelectionPanel).is_open() and not ordinary_boot.run_started, "consumed restart metadata cannot replay on an ordinary subsequent boot")
	ordinary_boot.free()
	await process_frame

	await _assert_invalid_restart_intent(intent_script, profile_root, settings_path, "missing-profile", &"fighter", "Previous profile is unavailable.")
	await _assert_invalid_restart_intent(intent_script, profile_root, settings_path, intended.profile.profile_id, &"missing_class", "Previous class is unavailable.")

	# A durable terminal record is the authoritative boot truth even when a stale
	# restart intent is present. The terminal pipeline creates the record from a
	# real run; this verifies precedence at the actual Main boot boundary.
	var terminal_main := await _new_main(profile_root, settings_path)
	terminal_main.profile_manager.select_profile(intended.profile.profile_id)
	if terminal_main.select_leader_class(&"fighter"):
		set_meta(META_KEY, intent_script.call(&"create", intended.profile.profile_id, &"mage", ""))
		terminal_main.call(&"_show_victory")
		await process_frame
		await process_frame
		terminal_main.free()
		await process_frame
		var cold_terminal := await _new_main(profile_root, settings_path)
		var terminal_panel := cold_terminal.get_node_or_null("HUD/TerminalExtraction") as Control
		_assert(not has_meta(META_KEY), "terminal-precedence boot consumes overlapping restart metadata")
		_assert(terminal_panel != null and terminal_panel.visible and not (cold_terminal.get_node("HUD/ClassSelection") as ClassSelectionPanel).is_open(), "durable terminal record wins boot precedence over restart-lobby metadata")
		cold_terminal.free()
	else:
		_assert(false, "terminal-precedence fixture starts a real run before writing terminal truth")
	if has_meta(META_KEY):
		remove_meta(META_KEY)
	ProfileTestSupport.remove_tree(fixture_root)


func _assert_invalid_restart_intent(intent_script: GDScript, profile_root: String, settings_path: String, profile_id: String, class_id: StringName, reason: String) -> void:
	const META_KEY := &"party_forge_run_setup_restart_intent"
	set_meta(META_KEY, intent_script.call(&"create", profile_id, class_id, reason))
	var main := await _new_main(profile_root, settings_path)
	var lobby := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var start := lobby.action_focus(&"start") as Button
	var status := lobby.get_node("Content/Margin/Layout/Status") as Label
	_assert(not has_meta(META_KEY), "%s restart intent is consumed even when unresolved" % reason)
	_assert(lobby.is_open() and lobby.selected_class_id().is_empty() and start != null and start.disabled, "%s leaves an explicit unresolved lobby with Start disabled" % reason)
	_assert(status.text == reason, "%s is shown as the explicit unresolved-selection reason" % reason)
	_assert(not main.run_started and main.active_run_context == null, "%s cannot check out or auto-start a run" % reason)
	var fighter := lobby.selection_focus(&"fighter")
	await _expect_focus(root, fighter, "%s unresolved restart settles focus on Fighter" % reason)
	await _wait_for_layout(lobby, "%s unresolved restart card layout" % reason)
	_assert(fighter != null and fighter.clip_contents, "%s focused Fighter clips all card-relative presentation" % reason)
	if fighter != null:
		var card_rect := fighter.get_global_rect()
		for node: Node in fighter.find_children("*", "Label", true, false):
			var label := node as Label
			if label.visible and label.is_visible_in_tree():
				_assert(card_rect.grow(0.5).encloses(label.get_global_rect()), "%s visible Fighter label %s stays inside the focused card" % [reason, label.name])
	main.free()
	await process_frame
	if has_meta(META_KEY):
		remove_meta(META_KEY)


func _new_main(profile_root: String, settings_path: String) -> PartyForgeMain:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = profile_root
	main.settings_path = settings_path
	root.add_child(main)
	await process_frame
	await process_frame
	return main


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


func _test_prompt_device_switching(viewport: Window, panel: ClassSelectionPanel) -> void:
	viewport.size = Vector2i(1920, 1080)
	panel.apply_viewport_size(Vector2(viewport.size))
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"mage", RunSetupClassProjection.Compatibility.COMPATIBLE))
	panel.open(panel.selection_focus(&"fighter"))
	await _wait_for_layout(panel, "prompt switching fixture")
	var fighter := panel.selection_focus(&"fighter")
	await _give_focus(viewport, fighter, "prompt switching starts from Fighter focus")
	var prompt := panel.get_node("Content/Margin/Layout/Footer/InputPrompt") as ForgeInputPrompt
	var p1_ready := panel.get_node("Content/Margin/Layout/Body/LeftColumn/Seats/Seat_1/Content/Ready") as Label
	var original_actions := _enabled_action_ids(panel)
	var original_selected := panel.selected_class_id()
	var original_previewed := panel.previewed_class_id()
	var original_status := (panel.get_node("Content/Margin/Layout/Status") as Label).text
	_assert(panel.active_prompt_mode() == &"keyboard_mouse", "lobby starts in keyboard/mouse prompt mode")
	_assert((prompt.get_node("Content/Label") as Label).text.ends_with("Start Run"), "Ready lobby prompt contextualizes ui_accept as Start Run")
	_assert(p1_ready.text == "READY · PROMPTS: KEYBOARD + MOUSE", "desktop P1 line names keyboard and mouse prompt style")

	await _send_joy_button(viewport, JOY_BUTTON_LEFT_STICK)
	_assert(panel.active_prompt_mode() == &"controller", "real controller button switches prompt mode")
	await _expect_focus(viewport, fighter, "controller prompt switch preserves exact focus")
	_assert((prompt.get_node("Content/Label") as Label).text.begins_with("A —") and (prompt.get_node("Content/Label") as Label).text.ends_with("Start Run"), "controller prompt uses formatted ui_accept and Start Run context")
	_assert(p1_ready.text == "READY · PROMPTS: GAMEPAD", "desktop P1 line names gamepad prompt style")
	_assert(_enabled_action_ids(panel) == original_actions and panel.selected_class_id() == original_selected and panel.previewed_class_id() == original_previewed and (panel.get_node("Content/Margin/Layout/Status") as Label).text == original_status, "controller prompt switch preserves authority, selection, preview, and status")

	await _send_mouse_motion(viewport, Vector2(8.0, 8.0))
	_assert(panel.active_prompt_mode() == &"keyboard_mouse", "real mouse motion restores keyboard/mouse prompt mode")
	await _expect_focus(viewport, fighter, "mouse prompt switch preserves exact focus")
	await _send_joy_button(viewport, JOY_BUTTON_LEFT_STICK)
	_assert(panel.active_prompt_mode() == &"controller", "controller prompt mode is retained before close")
	panel.close()
	await _send_key(viewport, KEY_SHIFT)
	_assert(panel.active_prompt_mode() == &"controller", "closed lobby ignores keyboard prompt observations")
	panel.open(fighter)
	_assert(panel.active_prompt_mode() == &"controller" and p1_ready.text == "READY · PROMPTS: GAMEPAD", "reopened lobby preserves and refreshes the last prompt device")
	await _send_key(viewport, KEY_SHIFT)
	_assert(panel.active_prompt_mode() == &"keyboard_mouse", "real keyboard input restores keyboard/mouse prompts after reopen")
	await _expect_focus(viewport, fighter, "keyboard prompt switch preserves exact focus")

	panel.present(_projection(RunSetupLobbyProjection.State.NO_SELECTION, &"", &"fighter", RunSetupClassProjection.Compatibility.UNKNOWN))
	_assert((prompt.get_node("Content/Label") as Label).text.ends_with("Select Class"), "no-selection prompt contextualizes ui_accept as Select Class")
	panel.present(_projection(RunSetupLobbyProjection.State.CHECKING, &"fighter", &"mage", RunSetupClassProjection.Compatibility.COMPATIBLE))
	_assert((prompt.get_node("Content/Label") as Label).text.ends_with("Confirm"), "Checking prompt falls back to passive Confirm copy")


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
		var actions := panel.get_node("Content/Margin/Layout/Footer") as Control
		var prompt := panel.get_node("Content/Margin/Layout/Footer/InputPrompt") as Control
		var action_bar := panel.get_node("Content/Margin/Layout/Footer/ActionBar") as Control
		var seats := panel.get_node("Content/Margin/Layout/Body/LeftColumn/Seats") as GridContainer
		var roster := panel.get_node("Content/Margin/Layout/Body/LeftColumn/ClassRoster/Scroll/Grid") as GridContainer
		var expected_content_width := minf(float(viewport_size.x), RunSetupResponsiveLayout.MAX_CONTENT_WIDTH)
		var expected_content := Rect2(Vector2((float(viewport_size.x) - expected_content_width) * 0.5, 0.0), Vector2(expected_content_width, float(viewport_size.y)))
		_assert_rect_near(content.get_global_rect(), expected_content, "content cap", viewport_size)
		var compact := viewport_size.x < 1600 or viewport_size.y < 900
		var vertical_margin := 8.0 if compact else 16.0
		var expected_margin := Rect2(expected_content.position + Vector2(24.0, vertical_margin), expected_content.size - Vector2(48.0, vertical_margin * 2.0))
		_assert_rect_near(margin.get_global_rect(), expected_margin, "exact 24px side and responsive vertical margins", viewport_size)
		_assert_enclosed(viewport_rect, panel, "full-screen panel", viewport_size)
		_assert_enclosed(content.get_global_rect(), margin, "24px side and responsive vertical content margin", viewport_size)
		_assert_enclosed(margin.get_global_rect(), body, "body within content margins", viewport_size)
		_assert_enclosed(body.get_global_rect(), left, "left lobby column", viewport_size)
		_assert_enclosed(body.get_global_rect(), hero, "hero stage", viewport_size)
		_assert_enclosed(body.get_global_rect(), details, "details column", viewport_size)
		_assert_no_horizontal_overlap(left, hero, "left and hero", viewport_size)
		_assert_no_horizontal_overlap(hero, details, "hero and details", viewport_size)
		_assert_enclosed(margin.get_global_rect(), status, "status row", viewport_size)
		_assert_enclosed(margin.get_global_rect(), actions, "fixed action footer", viewport_size)
		_assert(body.get_global_rect().end.y <= actions.get_global_rect().position.y, "body does not overlap fixed footer at %dx%d" % [viewport_size.x, viewport_size.y])
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
	var actions := panel.get_node_or_null("Content/Margin/Layout/Footer") as Control
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


func _send_key(viewport: Window, keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	viewport.push_input(pressed)
	await process_frame
	var released := pressed.duplicate() as InputEventKey
	released.pressed = false
	viewport.push_input(released)
	await process_frame


func _send_joy_button(viewport: Window, button: JoyButton) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = 0
	pressed.button_index = button
	pressed.pressed = true
	viewport.push_input(pressed)
	await process_frame
	var released := pressed.duplicate() as InputEventJoypadButton
	released.pressed = false
	viewport.push_input(released)
	await process_frame


func _send_mouse_motion(viewport: Window, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = position - viewport.get_mouse_position()
	viewport.push_input(event)
	await process_frame


func _enabled_action_ids(panel: ClassSelectionPanel) -> Array[StringName]:
	var result: Array[StringName] = []
	for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
		var button := panel.action_focus(action_id) as Button
		if button != null and bool(button.get_meta(&"action_enabled", false)):
			result.append(action_id)
	return result


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
