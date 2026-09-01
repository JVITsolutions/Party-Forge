extends SceneTree


class TestRun:
	extends Node
	func elapsed_time() -> float:
		return 42.0


var _failures: Array[String] = []
var _fixture: Dictionary
var _viewport: SubViewport
var _hud: HUD
var _game_run: GameRun
var _ledger: CharacterLedger
var _inspect_intents: Array = []
var _ledger_intents: Array = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if not ResourceLoader.exists("res://scripts/ui/hud/combat_alert_tray.gd") or not ResourceLoader.exists("res://scripts/ui/hud/combat_member_inspect_panel.gd"):
		_failures.append("Task 4 combat HUD input routes are missing")
		_finish()
		return
	_fixture = _make_fixture()
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_viewport)
	_hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	_hud.custom_viewport = _viewport
	_viewport.add_child(_hud)
	(_hud.get_node("ClassSelection") as ClassSelectionPanel).close()
	if _hud.get_node_or_null("Margin/CombatStatus") == null:
		_failures.append("responsive combat HUD shell is missing")
		_cleanup()
		_finish()
		return
	_hud.call("configure", _fixture.run, _fixture.party, _fixture.experience, _fixture.context, PartyForgeSettings.new())
	_game_run = GameRun.new()
	_game_run.configure_seed(9911)
	root.add_child(_game_run)
	_game_run.start_run()
	_ledger = (load("res://scenes/ui/ledger/character_ledger.tscn") as PackedScene).instantiate() as CharacterLedger
	_ledger.custom_viewport = _viewport
	_viewport.add_child(_ledger)
	_ledger.configure(_game_run, _fixture.party, GameCatalog.load_defaults(), _ledger_health, [], null, Callable(_fixture.context, "progression_for"), _fixture.context)
	_ledger.closed.connect(_on_ledger_closed)
	_hud.connect("inspect_requested", _on_inspect_requested)
	_hud.connect("ledger_requested", _on_ledger_requested)
	await process_frame
	await process_frame
	await _exercise_collapsed_summary_focus_contract()
	await _exercise_no_focus_theft_and_page_navigation()
	await _exercise_keyboard_mouse_controller_routes()
	await _exercise_complete_tray_focus_and_cancel()
	await _exercise_nested_pause_and_resolved_fallback()
	await _exercise_child_modal_refresh_ownership()
	_cleanup()
	_finish()


func _exercise_collapsed_summary_focus_contract() -> void:
	_hud.apply_collapse_preferences(false, true)
	await process_frame
	var party_header := _hud.get_node("Margin/CombatStatus/PartyHeader") as Button
	var alerts_content := _hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control
	var tray_action := _hud.get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
	party_header.grab_focus()
	await process_frame
	_assert(_viewport.gui_get_focus_owner() == party_header, "collapsed-summary fixture establishes a real Party-header focus owner")
	(_fixture.health_by_member[12] as HealthComponent).apply_damage(80.0)
	await process_frame
	_assert(
		_hud.alerts_collapsed()
		and not alerts_content.visible
		and _viewport.gui_get_focus_owner() == party_header,
		"a newly appearing collapsed alert updates without expanding or stealing real viewport focus",
	)
	_assert(tray_action.visible and not tray_action.disabled and tray_action.focus_mode == Control.FOCUS_ALL, "new collapsed alert exposes an eligible tray action")
	tray_action.grab_focus()
	await process_frame
	var descriptor := _hud.focus_descriptor_for(tray_action)
	party_header.grab_focus()
	await process_frame
	var restored := _hud.restore_focus_descriptor(descriptor)
	await process_frame
	_assert(
		restored
		and descriptor == {"kind": &"named", "named_control": &"alerts_tray_action"}
		and _viewport.gui_get_focus_owner() == tray_action,
		"alerts_tray_action named descriptor round-trips the exact real focus owner",
	)
	(_fixture.health_by_member[12] as HealthComponent).heal(100.0)
	await process_frame
	_assert(
		not tray_action.visible
		and tray_action.disabled
		and tray_action.focus_mode == Control.FOCUS_NONE
		and not tray_action.has_focus()
		and _viewport.gui_get_focus_owner() != tray_action,
		"all-clear transition releases real tray-action focus before removing eligibility",
	)
	_hud.apply_collapse_preferences(false, false)
	await process_frame


func _exercise_no_focus_theft_and_page_navigation() -> void:
	var first := _member_control(1)
	_assert(first != null, "compact roster exposes leader marker on the first page")
	if first == null:
		return
	first.grab_focus()
	await process_frame
	(_fixture.health_by_member[7] as HealthComponent).apply_damage(80.0)
	await process_frame
	_assert(first.has_focus(), "a newly appearing alert does not steal combat member focus")
	first.pressed.emit()
	await process_frame
	var member_inspector := _hud.get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel
	_assert(member_inspector.visible, "member activation opens the real read-only inspector")
	(_fixture.health_by_member[8] as HealthComponent).apply_damage(80.0)
	await process_frame
	await _press_controller_cancel()
	_assert(not member_inspector.visible and first.has_focus(), "member inspector Cancel restores the exact surviving member before alert fallbacks")
	var dpad_right := InputEventJoypadButton.new()
	dpad_right.device = 0
	dpad_right.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad_right.pressed = true
	_viewport.push_input(dpad_right)
	await process_frame
	var focus_owner := _viewport.gui_get_focus_owner() as Control
	_assert(focus_owner != null and focus_owner.is_in_group(&"combat_hud_member") and int(focus_owner.get_meta("member_id", 0)) != 1, "controller D-pad follows explicit spatial member neighbors")
	var next := _hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
	next.grab_focus()
	await _press_keyboard(KEY_ENTER)
	_assert(int((_member_controls()[0] as Control).get_meta("member_id", 0)) > 1, "keyboard activates deterministic compact paging")
	var previous := _hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious") as Button
	previous.grab_focus()
	await _press_controller_accept()
	_assert(int((_member_controls()[0] as Control).get_meta("member_id", 0)) == 1, "controller activation returns to the previous compact page")


func _exercise_keyboard_mouse_controller_routes() -> void:
	for member_id: int in range(2, 7):
		(_fixture.health_by_member[member_id] as HealthComponent).apply_damage(80.0)
	await process_frame
	var expanded := _hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Container
	_assert(expanded.get_child_count() == 3, "three real expanded alert cards are present")
	if expanded.get_child_count() < 3:
		return
	var keyboard_card := expanded.get_child(0) as Control
	var keyboard_inspect := keyboard_card.get_node("Surface/Content/Actions/Inspect") as Button
	var before_keyboard := _inspect_intents.size()
	keyboard_inspect.grab_focus()
	await _press_keyboard(KEY_ENTER)
	_assert(_inspect_intents.size() == before_keyboard + 1 and int(_inspect_intents[-1][0]) == int(keyboard_card.get_meta("member_id", 0)), "keyboard Inspect carries exact member identity")
	var inspector := _hud.get_node("CombatMemberInspectPanel") as CanvasLayer
	_assert(inspector.visible and paused, "keyboard Inspect opens the pause-safe read-only child")
	await _press_keyboard(KEY_ESCAPE)
	_assert(not inspector.visible and keyboard_inspect.has_focus(), "keyboard Cancel closes Inspect and restores exact action focus")

	var controller_card := expanded.get_child(1) as Control
	var controller_ledger := controller_card.get_node("Surface/Content/Actions/Ledger") as Button
	if not controller_ledger.visible:
		# A critical alert intentionally has no Ledger route; turn this member downed.
		var member_id := int(controller_card.get_meta("member_id", 0))
		(_fixture.health_by_member[member_id] as HealthComponent).apply_damage(1000.0)
		await process_frame
		controller_card = expanded.get_child(0) as Control
		controller_ledger = controller_card.get_node("Surface/Content/Actions/Ledger") as Button
	controller_ledger.grab_focus()
	await _press_controller_accept()
	_assert(_ledger_intents.size() == 1 and int(_ledger_intents[0][0]) == int(controller_card.get_meta("member_id", 0)), "controller Ledger carries exact member identity")
	_assert(_ledger_intents[0][1] == controller_ledger if not _ledger_intents.is_empty() else false, "controller Ledger carries the initiating action control")
	_assert(_ledger.visible and paused and _ledger.context.selected_member_id == int(controller_card.get_meta("member_id", 0)) and _ledger.context.active_page_id == &"stats", "controller opens the paused actual Ledger at exact member and stats page")
	await _press_controller_cancel()
	_assert(not _ledger.visible and controller_ledger.has_focus(), "controller Cancel closes actual Ledger and restores exact action focus")
	await _press_controller_accept()
	var rebound_member_id := int(controller_card.get_meta("member_id", 0))
	var replacement_actor := Node3D.new()
	var replacement_health := HealthComponent.new()
	replacement_health.name = "HealthComponent"
	replacement_actor.add_child(replacement_health)
	replacement_health.configure(100.0, false, 8.0, 0.5, false)
	assert(_fixture.context.bind_actor(rebound_member_id, replacement_actor))
	(_fixture.actors as Array).append(replacement_actor)
	(_fixture.health_by_member as Dictionary)[rebound_member_id] = replacement_health
	await process_frame
	await _press_controller_cancel()
	var ledger_fallback := _viewport.gui_get_focus_owner() as Control
	_assert(not _ledger.visible and ledger_fallback != null and _hud.is_ancestor_of(ledger_fallback), "Ledger close after stale initiating alert uses stable HUD fallback owner=%s" % (ledger_fallback.get_path() if ledger_fallback != null else NodePath("<null>")))

	var mouse_card := expanded.get_child(2) as Control
	var mouse_inspect := mouse_card.get_node("Surface/Content/Actions/Inspect") as Button
	var before_mouse := _inspect_intents.size()
	await _click_mouse(mouse_inspect)
	_assert(_inspect_intents.size() == before_mouse + 1, "mouse Inspect emits exactly once")
	if inspector.visible:
		inspector.call("close")
		await process_frame


func _exercise_complete_tray_focus_and_cancel() -> void:
	var overflow := _hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	_assert(overflow.visible and overflow.text.begins_with("+"), "overflow control is real and exact")
	overflow.grab_focus()
	await _click_mouse(overflow)
	var tray := _hud.get_node("CombatAlertTray") as CanvasLayer
	_assert(tray.visible and paused, "mouse overflow opens the paused complete tray")
	var cards := tray.get_node("Overlay/Frame/Layout/Scroll/Alerts") as Container
	var projection := _hud.get("current_projection") as CombatHudProjection
	_assert(cards.get_child_count() == projection.all_alerts.size(), "tray receives current_projection.all_alerts unchanged")
	if cards.get_child_count() > 3:
		var expected := cards.get_child(3) as Control
		var expected_action := expected.get_node("Surface/Content/Actions/Inspect") as Button
		if not expected_action.visible or expected_action.disabled:
			expected_action = expected.get_node("Surface/Content/Actions/Ledger") as Button
		var focused := _viewport.gui_get_focus_owner() as Control
		_assert(focused == expected_action, "tray initially focuses the first non-expanded alert's first real action")
		await _press_controller_accept()
		var inspector := _hud.get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel
		_assert(inspector.visible, "controller activation from initial tray focus opens the real Inspect child")
		var removed_member_id := int(expected.get_meta("member_id", 0))
		(_fixture.health_by_member[removed_member_id] as HealthComponent).heal(1000.0)
		await process_frame
		await _press_controller_cancel()
		var restored := _viewport.gui_get_focus_owner() as Control
		_assert(restored != null and tray.is_ancestor_of(restored) and restored is Button, "closing child after initiating alert removal restores a surviving real tray action")
	await _press_keyboard(KEY_ESCAPE)
	_assert(not tray.visible and overflow.has_focus(), "keyboard Cancel closes tray and restores exact overflow focus")

	overflow.pressed.emit()
	await process_frame
	await _press_controller_cancel()
	_assert(not tray.visible and overflow.has_focus(), "controller Cancel has tray-close parity")


func _exercise_nested_pause_and_resolved_fallback() -> void:
	var external := RunPauseLease.new()
	external.acquire(self)
	var overflow := _hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	overflow.pressed.emit()
	await process_frame
	var tray := _hud.get_node("CombatAlertTray") as CanvasLayer
	tray.call("close")
	_assert(paused, "closing the tray preserves an already-owned pause")
	external.release(self)
	_assert(not paused, "releasing the final pause owner restores the original run state")

	overflow.pressed.emit()
	await process_frame
	var cards := tray.get_node("Overlay/Frame/Layout/Scroll/Alerts") as Container
	if cards.get_child_count() <= 3:
		_failures.append("fallback fixture has no overflow alert")
		return
	var focused_card := cards.get_child(3) as Control
	var focused_member_id := int(focused_card.get_meta("member_id", 0))
	(focused_card.get_node("Surface/Content/Actions/Inspect") as Button).grab_focus()
	await process_frame
	(_fixture.health_by_member[focused_member_id] as HealthComponent).heal(100.0)
	await process_frame
	var next_focus := _viewport.gui_get_focus_owner() as Control
	_assert(next_focus != null and next_focus != focused_card and (tray.is_ancestor_of(next_focus) or next_focus == tray.get_node("Overlay/Frame/Layout/Close")), "resolved focused alert falls forward then backward then Close")

	for member_id: int in range(1, 13):
		var healthy_actor := Node3D.new()
		var healthy := HealthComponent.new()
		healthy.name = "HealthComponent"
		healthy_actor.add_child(healthy)
		healthy.configure(100.0, member_id == 1, 8.0, 0.5, member_id == 1)
		assert(_fixture.context.bind_actor(member_id, healthy_actor))
		(_fixture.actors as Array).append(healthy_actor)
		(_fixture.health_by_member as Dictionary)[member_id] = healthy
	await process_frame
	_assert(not tray.visible, "all-alerts-resolved refresh closes the tray")
	var safe_focus := _viewport.gui_get_focus_owner() as Control
	_assert(safe_focus != null and (safe_focus.is_in_group(&"combat_hud_member") or safe_focus == _hud.get_node("Margin/CombatStatus/LeaderCard")), "all-alerts-resolved close uses a named current-member fallback owner=%s" % (safe_focus.get_path() if safe_focus != null else NodePath("<null>")))
	var resolved := _hud.get_node("AlertResolvedMessage") as Label
	_assert(resolved.visible and resolved.text == "All alerts resolved.", "all-alerts-resolved closure announces concise status")


func _exercise_child_modal_refresh_ownership() -> void:
	for member_id: int in range(2, 9):
		(_fixture.health_by_member[member_id] as HealthComponent).apply_damage(80.0)
	await process_frame
	var overflow := _hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	var tray := _hud.get_node("CombatAlertTray") as CombatAlertTray
	overflow.pressed.emit()
	await process_frame
	var cards := tray.get_node("Overlay/Frame/Layout/Scroll/Alerts") as Container
	var inspector_card := cards.get_child(3) as Control
	var inspect_action := inspector_card.get_node("Surface/Content/Actions/Inspect") as Button
	inspect_action.grab_focus()
	await _press_controller_accept()
	await process_frame
	var inspector := _hud.get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel
	(inspector.get_node("Overlay/Frame/Layout/Close") as Button).grab_focus()
	await process_frame
	await process_frame
	_assert((inspector.get_node("Overlay/Frame/Layout/Close") as Button).has_focus(), "Inspector modal owns focus before tray refresh")
	var inspector_member_id := int(inspector_card.get_meta("member_id", 0))
	_replace_with_healthy_actor(inspector_member_id)
	await process_frame
	var inspector_focus := _viewport.gui_get_focus_owner() as Control
	_assert(inspector.visible and inspector_focus != null and inspector.is_ancestor_of(inspector_focus), "tray refresh does not steal focus after initiating alert removal while Inspector is topmost owner=%s inspector_visible=%s" % [inspector_focus.get_path() if inspector_focus != null else NodePath("<null>"), inspector.visible])
	_replace_all_with_healthy_actors()
	await process_frame
	inspector_focus = _viewport.gui_get_focus_owner() as Control
	_assert(not tray.visible and inspector.visible and paused and inspector_focus != null and inspector.is_ancestor_of(inspector_focus), "tray auto-close defers HUD fallback while Inspector owns focus and pause owner=%s tray=%s inspector=%s paused=%s" % [inspector_focus.get_path() if inspector_focus != null else NodePath("<null>"), tray.visible, inspector.visible, paused])
	await _press_controller_cancel()
	var inspector_return := _viewport.gui_get_focus_owner() as Control
	_assert(not inspector.visible and inspector_return != null and _hud.is_ancestor_of(inspector_return), "Inspector close resolves the deferred stable HUD fallback")

	for member_id: int in range(2, 9):
		(_fixture.health_by_member[member_id] as HealthComponent).apply_damage(1000.0)
	await process_frame
	overflow.pressed.emit()
	await process_frame
	cards = tray.get_node("Overlay/Frame/Layout/Scroll/Alerts") as Container
	var ledger_card := cards.get_child(3) as Control
	var ledger_action := ledger_card.get_node("Surface/Content/Actions/Ledger") as Button
	_assert(ledger_action.visible and not ledger_action.disabled, "real Ledger modal fixture exposes an available tray action")
	ledger_action.grab_focus()
	await _press_controller_accept()
	await process_frame
	(_ledger.get_node("Overlay/Frame/Layout/Close") as Button).grab_focus()
	await process_frame
	await process_frame
	_assert((_ledger.get_node("Overlay/Frame/Layout/Close") as Button).has_focus(), "Ledger modal owns focus before tray refresh")
	var ledger_member_id := int(ledger_card.get_meta("member_id", 0))
	_replace_with_healthy_actor(ledger_member_id)
	await process_frame
	var ledger_focus := _viewport.gui_get_focus_owner() as Control
	_assert(_ledger.visible and ledger_focus != null and _ledger.is_ancestor_of(ledger_focus), "tray refresh does not steal focus after initiating alert removal while Ledger is topmost owner=%s ledger=%s" % [ledger_focus.get_path() if ledger_focus != null else NodePath("<null>"), _ledger.visible])
	_replace_all_with_healthy_actors()
	await process_frame
	ledger_focus = _viewport.gui_get_focus_owner() as Control
	_assert(not tray.visible and _ledger.visible and paused and ledger_focus != null and _ledger.is_ancestor_of(ledger_focus), "tray auto-close defers HUD fallback while real Ledger owns focus and pause owner=%s tray=%s ledger=%s paused=%s" % [ledger_focus.get_path() if ledger_focus != null else NodePath("<null>"), tray.visible, _ledger.visible, paused])
	await _press_controller_cancel()
	var ledger_return := _viewport.gui_get_focus_owner() as Control
	_assert(not _ledger.visible and not paused and ledger_return != null and _hud.is_ancestor_of(ledger_return), "Ledger close resolves the deferred stable HUD fallback")


func _replace_with_healthy_actor(member_id: int) -> void:
	var actor := Node3D.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	actor.add_child(health)
	health.configure(100.0, member_id == 1, 8.0, 0.5, member_id == 1)
	assert(_fixture.context.bind_actor(member_id, actor))
	(_fixture.actors as Array).append(actor)
	(_fixture.health_by_member as Dictionary)[member_id] = health


func _replace_all_with_healthy_actors() -> void:
	for member_id: int in range(1, 13):
		_replace_with_healthy_actor(member_id)


func _on_inspect_requested(member_id: int, return_focus: Control) -> void:
	_inspect_intents.append([member_id, return_focus])
	_hud.call("open_inspector_for_member", member_id, return_focus)


func _on_ledger_requested(member_id: int, return_focus: Control) -> void:
	_ledger_intents.append([member_id, return_focus])
	_ledger.open_for_member(member_id, &"stats", return_focus, _hud.focus_descriptor_for(return_focus))


func _on_ledger_closed(_return_focus: Control, descriptor: Dictionary) -> void:
	_hud.restore_focus_descriptor(descriptor)


func _ledger_health(member_id: int) -> Dictionary:
	var health := _fixture.health_by_member.get(member_id) as HealthComponent
	if health == null:
		return {}
	return {"current": health.current_health, "maximum": health.max_health, "is_downed": health.is_downed, "is_dead": health.is_dead, "component": health}


func _make_fixture() -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(12))
	party.configure_identity(9907, catalog.generic_name_pool)
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for _index: int in range(11):
		assert(party.recruit(catalog.class_by_id(&"fighter")))
	var context := PlayerRunContext.new()
	assert(context.configure(&"hud-input", 0, ProfileState.new_profile("hud-input-profile", "HUD Input", 1000), 9907, party, 100).is_empty())
	var experience := ExperienceSystem.new()
	experience.configure_context(context, 1)
	var actors: Array[Node3D] = []
	var health_by_member: Dictionary = {}
	for member_id: int in range(1, 13):
		var actor := Node3D.new()
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		actor.add_child(health)
		health.configure(100.0, member_id == 1, 8.0, 0.5, member_id == 1)
		assert(context.bind_actor(member_id, actor))
		actors.append(actor)
		health_by_member[member_id] = health
	return {"party": party, "context": context, "experience": experience, "actors": actors, "health_by_member": health_by_member, "run": TestRun.new()}


func _member_controls() -> Array[Control]:
	var result: Array[Control] = []
	for node: Node in get_nodes_in_group(&"combat_hud_member"):
		if node is Control and _hud.is_ancestor_of(node):
			result.append(node as Control)
	return result


func _member_control(member_id: int) -> Control:
	for control: Control in _member_controls():
		if int(control.get_meta("member_id", 0)) == member_id:
			return control
	return null


func _press_keyboard(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_viewport.push_input(event)
	var released := event.duplicate() as InputEventKey
	released.pressed = false
	_viewport.push_input(released)
	await process_frame


func _press_controller_accept() -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	_viewport.push_input(event)
	var released := event.duplicate() as InputEventJoypadButton
	released.pressed = false
	_viewport.push_input(released)
	await process_frame


func _press_controller_cancel() -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_B
	event.pressed = true
	_viewport.push_input(event)
	var released := event.duplicate() as InputEventJoypadButton
	released.pressed = false
	_viewport.push_input(released)
	await process_frame


func _click_mouse(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	_viewport.push_input(motion)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = point
	pressed.pressed = true
	_viewport.push_input(pressed)
	var released := pressed.duplicate() as InputEventMouseButton
	released.pressed = false
	_viewport.push_input(released)
	await process_frame


func _cleanup() -> void:
	paused = false
	if _viewport != null and is_instance_valid(_viewport):
		_viewport.free()
	if _game_run != null and is_instance_valid(_game_run):
		_game_run.free()
	if not _fixture.is_empty():
		var experience := _fixture.experience as ExperienceSystem
		if experience != null:
			experience.free()
		var party := _fixture.party as PartyManager
		if party != null:
			party.free()
		for actor: Node3D in _fixture.actors as Array:
			actor.free()
		var run := _fixture.run as Node
		if run != null:
			run.free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("COMBAT_HUD_INPUT_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("COMBAT_HUD_INPUT_FAILURE: %s" % failure)
	print("COMBAT_HUD_INPUT_SUMMARY: FAIL failures=%d" % _failures.size())
	quit(1)
