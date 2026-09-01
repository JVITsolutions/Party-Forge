extends SceneTree

const COMBAT_HUD_UNIT_SUITE := preload("res://tests/unit/test_combat_hud.gd")
const SCRIPT_ERROR_CAPTURE := preload("res://tests/support/test_script_error_capture.gd")


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
	var unit_suite := COMBAT_HUD_UNIT_SUITE.new()
	for failure: String in unit_suite.run_scene_tree_focus_hydration_contract(_hud, _viewport):
		_failures.append("scene-tree unit contract: %s" % failure)
	await process_frame
	await _exercise_collapsed_summary_focus_contract()
	await _exercise_no_focus_theft_and_page_navigation()
	await _exercise_keyboard_mouse_controller_routes()
	await _exercise_complete_tray_focus_and_cancel()
	await _exercise_nested_pause_and_resolved_fallback()
	await _exercise_child_modal_refresh_ownership()
	await _exercise_terminal_rebuild_focus_suspension()
	await _exercise_terminal_presentation_ineligibility()
	await _exercise_freed_collapsed_rebuild_restoration()
	await _exercise_region_focus_traversal_and_motion()
	await _exercise_terminal_region_suspension_handoff()
	_cleanup()
	_finish()


func _exercise_collapsed_summary_focus_contract() -> void:
	_hud.apply_collapse_preferences(true, true)
	await process_frame
	var party_region := _hud.get_node("Margin/CombatStatus/PartyRegion") as Control
	(_fixture.health_by_member[1] as HealthComponent).apply_damage(10.0)
	await process_frame
	_assert(_region_focus_modes_are_none(party_region), "collapsed Party live-value refresh immediately reapplies suspension without restoring hidden focus")
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


func _exercise_region_focus_traversal_and_motion() -> void:
	var party_header := _hud.get_node("Margin/CombatStatus/PartyHeader") as Button
	var alerts_header := _hud.get_node("Margin/CombatStatus/AlertRegion/Header") as Button
	var party_glyph := party_header.get_node("Content/DisclosureGlyph/RotatingGlyph") as Label
	var leader := _hud.get_node("Margin/CombatStatus/LeaderCard") as Control
	var party_region := _hud.get_node("Margin/CombatStatus/PartyRegion") as Control
	var alerts_content := _hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control
	var overflow := _hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	var tray_action := _hud.get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
	var motion_settings := PartyForgeSettings.new()
	motion_settings.reduced_motion = true
	_hud.apply_visual_settings(motion_settings)
	await process_frame


	var exact_member := _member_control(2)
	_assert(exact_member != null, "Party focus fixture exposes member two")
	if exact_member == null:
		return
	exact_member.grab_focus()
	await process_frame
	var leader_modulate := leader.modulate
	var roster_modulate := party_region.modulate
	await _click_mouse(party_header)
	_assert(_hud.party_collapsed() and party_header.has_focus(), "mouse collapse moves hidden Party descendant focus to PartyHeader")
	_assert(not leader.visible and not party_region.visible, "Party content visibility changes atomically on collapse")
	_assert(leader.modulate == leader_modulate and party_region.modulate == roster_modulate, "reduced motion never animates Party content opacity on collapse")
	_assert(_disclosure_tween_for(&"party") == null and is_equal_approx(party_glyph.rotation, 0.0), "reduced motion reaches collapsed Party glyph rotation in the same frame with no Tween")
	await _click_mouse(party_header)
	await process_frame
	var rebuilt_member := _member_control(2)
	var rebuilt_focus_owner := _viewport.gui_get_focus_owner() as Control
	_assert(not _hud.party_collapsed() and rebuilt_member != null and rebuilt_focus_owner == rebuilt_member and rebuilt_focus_owner.is_in_group(&"combat_hud_member") and int(rebuilt_focus_owner.get_meta("member_id", 0)) == 2, "mouse expansion restores viewport focus to the rebuilt semantic member two")
	_assert(leader.modulate == leader_modulate and party_region.modulate == roster_modulate, "reduced motion never animates Party content opacity on expand")
	_assert(_disclosure_tween_for(&"party") == null and is_equal_approx(party_glyph.rotation, PI / 2.0), "reduced motion reaches expanded Party glyph rotation in the same frame with no Tween actual=%s" % party_glyph.rotation)
	await _press_controller_direction(JOY_BUTTON_DPAD_UP)
	_assert(party_header.has_focus(), "controller D-pad reaches PartyHeader from a Party descendant")

	for member_id: int in range(2, 8):
		(_fixture.health_by_member[member_id] as HealthComponent).apply_damage(80.0)
	await process_frame
	var first_alert := alerts_content.get_child(0) as Control
	var exact_inspect := first_alert.get_node("Surface/Content/Actions/Inspect") as Button
	exact_inspect.grab_focus()
	await process_frame
	await _press_keyboard(KEY_ENTER, alerts_header)
	_assert(_hud.alerts_collapsed() and alerts_header.has_focus(), "keyboard Alerts collapse moves hidden Inspect focus to Alerts Header")
	_assert(not alerts_content.visible and not overflow.visible, "Alerts cards and overflow hide atomically")
	_assert(_region_focus_modes_are_none(alerts_content) and overflow.focus_mode == Control.FOCUS_NONE, "collapsed Alerts descendants are unreachable with exact FOCUS_NONE")
	await _press_keyboard(KEY_ENTER)
	await process_frame
	_assert(not _hud.alerts_collapsed() and exact_inspect.has_focus(), "keyboard Alerts expansion restores the exact surviving Inspect action")

	exact_inspect.grab_focus()
	await process_frame
	await _press_keyboard(KEY_ENTER, alerts_header)
	var removed_member_id := int(first_alert.get_meta("member_id", 0))
	exact_inspect = null
	first_alert = null
	_replace_with_healthy_actor(removed_member_id)
	await process_frame
	await _press_keyboard(KEY_ENTER)
	await process_frame
	var fallback := _viewport.gui_get_focus_owner() as Control
	_assert(not _hud.alerts_collapsed() and fallback != null and (alerts_content.is_ancestor_of(fallback) or fallback == overflow or fallback == alerts_header), "resolved collapsed alert expands to the first surviving action, Overflow, or Header")

	party_header.grab_focus()
	await process_frame
	await _press_controller_direction(JOY_BUTTON_DPAD_RIGHT)
	_assert(alerts_header.has_focus(), "controller D-pad reaches Alerts Header from PartyHeader")
	await _press_controller_accept()
	_assert(_hud.alerts_collapsed(), "controller accept toggles Alerts collapse")
	await _press_controller_direction(JOY_BUTTON_DPAD_DOWN)
	_assert(tray_action.has_focus(), "controller D-pad reaches AlertsTrayAction from collapsed Alerts Header")
	await _press_controller_accept()
	var tray := _hud.get_node("CombatAlertTray") as CombatAlertTray
	_assert(tray.visible and _focus_within(tray), "controller reaches AlertsTrayAction and accept opens the tray")
	await _press_controller_cancel()
	_assert(not tray.visible and tray_action.has_focus(), "controller Cancel closes the tray to AlertsTrayAction")

	var modal_close := tray.get_node("Overlay/Frame/Layout/Close") as Button
	tray_action.pressed.emit()
	await process_frame
	modal_close.grab_focus()
	await process_frame
	_hud.apply_collapse_preferences(true, true)
	(_fixture.health_by_member[8] as HealthComponent).apply_damage(80.0)
	await process_frame
	_assert(tray.visible and _focus_within(tray), "collapsed summary refresh and hydration preserve topmost tray modal focus")
	await _press_controller_cancel()
	var external := Button.new()
	external.name = "ExternalFocusOwner"
	external.focus_mode = Control.FOCUS_ALL
	_viewport.add_child(external)
	external.grab_focus()
	await process_frame
	_hud.apply_collapse_preferences(false, false)
	await process_frame
	_assert(external.has_focus(), "programmatic expansion hydration never steals external viewport focus")
	_hud.apply_collapse_preferences(true, true)
	await process_frame
	_assert(external.has_focus(), "programmatic collapse hydration never steals external viewport focus")
	external.free()

	exact_member = null
	motion_settings.reduced_motion = false
	motion_settings.hud_party_collapsed = true
	motion_settings.hud_alerts_collapsed = true
	_hud.apply_visual_settings(motion_settings)
	await process_frame
	_assert(_region_focus_modes_are_none(party_region), "collapsed Party dynamic rebuild keeps every live descendant suspended exactly once violations=%s" % [str(_region_focus_mode_violations(party_region))])
	var content_position := alerts_content.position
	var content_modulate := alerts_content.modulate
	alerts_header.pressed.emit()
	var normal_tween := _disclosure_tween_for(&"alerts")
	_assert(normal_tween != null and normal_tween.is_valid(), "normal motion creates an active glyph-only disclosure Tween")
	_assert(alerts_content.position == content_position and alerts_content.modulate == content_modulate, "normal disclosure motion never animates alert content position or opacity")
	await process_frame
	alerts_header.pressed.emit()
	await process_frame
	_hud.apply_collapse_preferences(false, false)
	await process_frame


func _exercise_terminal_rebuild_focus_suspension() -> void:
	var prior_member_id := 3
	var prior_member := _member_control(prior_member_id)
	_assert(prior_member != null, "terminal rebuild fixture exposes a prior member focus owner")
	if prior_member == null:
		return
	prior_member.grab_focus()
	await process_frame
	var prior_weak: WeakRef = weakref(prior_member)
	prior_member = null
	var script_errors := SCRIPT_ERROR_CAPTURE.new()
	OS.add_logger(script_errors)
	_hud.show_terminal_extraction(_terminal_projection())
	await process_frame
	await process_frame
	var terminal := _hud.get_node("TerminalExtraction") as TerminalExtractionPanel
	_assert(terminal.visible and _focus_within(terminal), "Terminal Extraction owns real viewport focus before HUD rebuild")
	_viewport.size = Vector2i(1280, 720)
	_hud.call("_refresh_projection", true)
	(_fixture.health_by_member[9] as HealthComponent).apply_damage(80.0)
	await process_frame
	await process_frame
	await process_frame
	_assert(prior_weak.get_ref() == null, "terminal viewport change performs a structural member-control rebuild")
	var escaped := _terminal_focusable_hud_descendants(terminal)
	_assert(escaped.is_empty(), "new HUD descendants remain unreachable behind Terminal Extraction controls=%s" % [str(escaped)])
	_assert(_terminal_suspension_entries_are_live_unique(), "terminal suspension tracks every live rebuilt control once and discards invalid entries")
	_assert(_focus_within(terminal), "terminal keeps real viewport focus after member and alert rebuilds")
	_hud.hide_terminal_extraction()
	await process_frame
	await process_frame
	OS.remove_logger(script_errors)
	var captured := script_errors.drain_after_detach()
	var restored := _viewport.gui_get_focus_owner() as Control
	_assert(captured.is_empty(), "terminal rebuild and close produce no stale-reference script errors: %s" % [captured])
	_assert(restored != null and restored.is_in_group(&"combat_hud_member") and int(restored.get_meta("member_id", 0)) == prior_member_id, "terminal close restores the valid rebuilt member descriptor")
	_assert(restored != null and restored.focus_mode == Control.FOCUS_ALL, "terminal close restores only the valid rebuilt member focus mode")
	_viewport.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame


func _exercise_freed_collapsed_rebuild_restoration() -> void:
	var header := _hud.get_node("Margin/CombatStatus/PartyHeader") as Button
	var member_id := 4
	var member := _member_control(member_id)
	_assert(member != null, "freed collapsed rebuild fixture exposes member four")
	if member == null:
		return
	member.grab_focus()
	await process_frame
	header.pressed.emit()
	await process_frame
	var member_weak: WeakRef = weakref(member)
	member = null
	var script_errors := SCRIPT_ERROR_CAPTURE.new()
	OS.add_logger(script_errors)
	_hud.call("_clear_member_controls")
	_assert(member_weak.get_ref() == null, "collapsed presentation clear frees the descriptor's original control")
	_hud.call("_rebuild_member_controls")
	header.pressed.emit()
	await process_frame
	await process_frame
	OS.remove_logger(script_errors)
	var captured := script_errors.drain_after_detach()
	var restored := _viewport.gui_get_focus_owner() as Control
	_assert(captured.is_empty(), "collapsed clear/rebuild/expand performs no freed-instance cast or access: %s" % [captured])
	_assert(restored != null and restored.is_in_group(&"combat_hud_member") and int(restored.get_meta("member_id", 0)) == member_id, "collapsed expansion restores the stable descriptor to the rebuilt member")


func _exercise_terminal_region_suspension_handoff() -> void:
	_hud.apply_collapse_preferences(false, false)
	var reduced_motion := PartyForgeSettings.new()
	reduced_motion.reduced_motion = true
	_hud.apply_visual_settings(reduced_motion)
	var party_header := _hud.get_node("Margin/CombatStatus/PartyHeader") as Button
	party_header.grab_focus()
	await process_frame
	var alerts_header := _hud.get_node("Margin/CombatStatus/AlertRegion/Header") as Button
	var party_region := _hud.get_node("Margin/CombatStatus/PartyRegion") as Control
	var alerts_content := _hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control
	var member := _member_control(4)
	var alert_card := alerts_content.get_child(0) as Control
	var alert_stable_id := StringName(alert_card.get_meta(&"stable_alert_id", &""))
	var alert_inspect := alert_card.get_node("Surface/Content/Actions/Inspect") as Button
	_assert(member != null and member.focus_mode == Control.FOCUS_ALL, "terminal region handoff fixture starts with an eligible Party descendant")
	_assert(alert_inspect.visible and not alert_inspect.disabled and alert_inspect.focus_mode == Control.FOCUS_ALL, "terminal region handoff fixture starts with an eligible Alerts descendant")
	member.grab_focus()
	await process_frame
	alert_inspect.grab_focus()
	await process_frame
	member.grab_focus()
	await process_frame
	member = null
	alert_inspect = null
	alert_card = null
	_hud.show_terminal_extraction(_terminal_projection())
	await process_frame
	await process_frame
	var terminal := _hud.get_node("TerminalExtraction") as TerminalExtractionPanel
	_hud.apply_collapse_preferences(true, true)
	await process_frame
	_assert(_focus_within(terminal), "programmatic Party and Alerts collapse preserves real terminal focus")
	_assert(_hud.party_collapsed() and _hud.alerts_collapsed(), "both regions collapse behind Terminal Extraction")
	_hud.hide_terminal_extraction()
	await process_frame
	await process_frame
	_assert(_region_focus_modes_are_none(party_region) and _region_focus_modes_are_none(alerts_content), "terminal close leaves both still-collapsed regions unreachable")
	party_header.pressed.emit()
	await process_frame
	await process_frame
	var expanded_member := _member_control(4)
	_assert(expanded_member != null and expanded_member.focus_mode == Control.FOCUS_ALL, "Party expansion recovers the surviving member's original eligible focus mode after terminal handoff")
	_assert(_viewport.gui_get_focus_owner() == expanded_member, "Party expansion restores the exact saved local member descriptor after terminal handoff")
	alerts_header.pressed.emit()
	await process_frame
	await process_frame
	var expanded_inspect := _hud.call("_alert_action_control", alert_stable_id, &"inspect") as Button
	_assert(expanded_inspect != null and expanded_inspect.focus_mode == Control.FOCUS_ALL, "Alerts expansion recovers the surviving Inspect action's original eligible focus mode after terminal handoff")
	_assert(_viewport.gui_get_focus_owner() == expanded_inspect, "Alerts expansion restores the exact saved local alert descriptor after terminal handoff")
	var second_member := _member_control(5)
	second_member.grab_focus()
	await process_frame
	_hud.show_terminal_extraction(_terminal_projection())
	await process_frame
	await process_frame
	_hud.apply_collapse_preferences(true, true)
	_hud.apply_collapse_preferences(false, false)
	await process_frame
	_assert(_focus_within(terminal), "collapse and expansion before terminal close preserve real terminal focus")
	var expanded_behind_terminal_member := _member_control(5)
	_assert(expanded_behind_terminal_member != null and expanded_behind_terminal_member.focus_mode == Control.FOCUS_NONE and expanded_inspect.focus_mode == Control.FOCUS_NONE, "rebuilt Party and surviving Alerts controls expanded behind the terminal remain suspended until terminal close")
	_assert(_focus_suspension_ownership_is_unique(), "expanded-behind-terminal controls have exactly one suspension owner")
	_hud.hide_terminal_extraction()
	await process_frame
	await process_frame
	var restored_second_member := _member_control(5)
	var restored_second_inspect := _hud.call("_alert_action_control", alert_stable_id, &"inspect") as Button
	_assert(restored_second_member != null and restored_second_member.focus_mode == Control.FOCUS_ALL, "terminal close after Party expansion restores the surviving member mode")
	_assert(restored_second_inspect != null and restored_second_inspect.focus_mode == Control.FOCUS_ALL, "terminal close after Alerts expansion restores the surviving Inspect mode")
	_assert(_viewport.gui_get_focus_owner() == restored_second_member, "terminal close after region expansion restores the exact terminal-prior member")
	party_header.grab_focus()
	await process_frame


func _exercise_terminal_presentation_ineligibility() -> void:
	_hud.apply_collapse_preferences(false, false)
	for health_value: Variant in (_fixture.health_by_member as Dictionary).values():
		(health_value as HealthComponent).heal(1000.0)
	for member_id: int in range(2, 13):
		(_fixture.health_by_member[member_id] as HealthComponent).apply_damage(80.0)
	await process_frame
	await process_frame
	var tray_action := _hud.get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
	var overflow := _hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	var alerts_content := _hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control
	var first_alert := alerts_content.get_child(0) as Control
	var first_inspect := first_alert.get_node("Surface/Content/Actions/Inspect") as Button
	_assert(tray_action.visible and not tray_action.disabled and tray_action.focus_mode == Control.FOCUS_ALL, "terminal inverse fixture starts with an eligible AlertsTrayAction")
	_assert(overflow.visible and not overflow.disabled and overflow.focus_mode == Control.FOCUS_ALL, "terminal inverse fixture starts with an eligible alert overflow action")
	_assert(first_inspect.visible and not first_inspect.disabled and first_inspect.focus_mode == Control.FOCUS_ALL, "terminal inverse fixture starts with an eligible alert descendant")
	tray_action.grab_focus()
	await process_frame
	var inspect_weak: WeakRef = weakref(first_inspect)
	first_inspect = null
	first_alert = null
	_hud.show_terminal_extraction(_terminal_projection())
	await process_frame
	await process_frame
	var terminal := _hud.get_node("TerminalExtraction") as TerminalExtractionPanel
	for health_value: Variant in (_fixture.health_by_member as Dictionary).values():
		(health_value as HealthComponent).heal(1000.0)
	await process_frame
	await process_frame
	await process_frame
	_assert(_focus_within(terminal), "Terminal Extraction keeps viewport focus while alerts become ineligible")
	_assert(not tray_action.visible and tray_action.disabled and tray_action.focus_mode == Control.FOCUS_NONE, "live presentation makes AlertsTrayAction ineligible behind the terminal")
	_assert(not overflow.visible and overflow.disabled and overflow.focus_mode == Control.FOCUS_NONE, "live presentation makes overflow ineligible behind the terminal")
	_assert(inspect_weak.get_ref() == null, "resolved alert descendant is freed behind the terminal")
	_hud.hide_terminal_extraction()
	await process_frame
	await process_frame
	_assert(not tray_action.visible and tray_action.disabled and tray_action.focus_mode == Control.FOCUS_NONE and not tray_action.has_focus(), "terminal close never resurrects stale AlertsTrayAction focus eligibility")
	_assert(not overflow.visible and overflow.disabled and overflow.focus_mode == Control.FOCUS_NONE and not overflow.has_focus(), "terminal close never resurrects stale overflow focus eligibility")
	_assert(_region_focus_modes_are_none(alerts_content), "terminal close leaves resolved alert descendants unreachable")


func _terminal_focusable_hud_descendants(terminal: Control) -> Array[String]:
	var escaped: Array[String] = []
	for node: Node in _hud.find_children("*", "Control", true, false):
		var control := node as Control
		if control == terminal or terminal.is_ancestor_of(control):
			continue
		if not control.is_visible_in_tree() or (control is BaseButton and (control as BaseButton).disabled):
			continue
		if control.focus_mode != Control.FOCUS_NONE:
			escaped.append(String(control.get_path()))
	return escaped


func _terminal_suspension_entries_are_live_unique() -> bool:
	var entries: Variant = _hud.get("_terminal_suspended_focus_modes")
	if not entries is Array:
		return false
	var seen: Dictionary = {}
	for entry_value: Variant in entries as Array:
		if not entry_value is Dictionary:
			return false
		var raw: Variant = (entry_value as Dictionary).get("control")
		if not is_instance_valid(raw):
			return false
		var control := raw as Control
		if control == null or seen.has(control.get_instance_id()):
			return false
		seen[control.get_instance_id()] = true
	return true


func _focus_suspension_ownership_is_unique() -> bool:
	var seen: Dictionary = {}
	for entries_value: Variant in [
		_hud.get("_terminal_suspended_focus_modes"),
		(_hud.get("_collapsed_focus_modes") as Dictionary).get(&"party", []),
		(_hud.get("_collapsed_focus_modes") as Dictionary).get(&"alerts", []),
	]:
		if not entries_value is Array:
			return false
		for entry_value: Variant in entries_value as Array:
			if not entry_value is Dictionary:
				return false
			var raw_control: Variant = (entry_value as Dictionary).get("control")
			if not is_instance_valid(raw_control):
				continue
			var control := raw_control as Control
			if control == null or seen.has(control.get_instance_id()):
				return false
			seen[control.get_instance_id()] = true
	return true


func _terminal_projection() -> TerminalExtractionProjection:
	var item := TerminalExtractionItemProjection.create_with_source(
		"task6-terminal-item",
		"Twin Band",
		"Common",
		&"common",
		"Fighter · Member 3",
		"Fighter Equipment",
		false,
		false,
		true,
		{"name": "Twin Band", "instance_id": "task6-terminal-item"},
		[],
		3,
		"Fighter",
		&"run-equipment-003",
		0,
	)
	return TerminalExtractionProjection.create([], [item], 1, [], [item.item_id], [], "", true)


func _region_focus_modes_are_none(root_control: Control) -> bool:
	return _region_focus_mode_violations(root_control).is_empty()


func _region_focus_mode_violations(root_control: Control) -> Array[String]:
	var violations: Array[String] = []
	if root_control.focus_mode != Control.FOCUS_NONE:
		violations.append(String(root_control.get_path()))
	for node: Node in root_control.find_children("*", "Control", true, false):
		if (node as Control).focus_mode != Control.FOCUS_NONE:
			violations.append(String(node.get_path()))
	return violations


func _focus_within(scope: Node) -> bool:
	var owner := _viewport.gui_get_focus_owner()
	return owner != null and (owner == scope or scope.is_ancestor_of(owner))


func _disclosure_tween_for(region: StringName) -> Tween:
	var value: Variant = _hud.get("_disclosure_tweens")
	if not value is Dictionary:
		return null
	return (value as Dictionary).get(region) as Tween


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


func _press_keyboard(keycode: Key, focus_before: Control = null) -> void:
	if focus_before != null:
		focus_before.grab_focus()
		await process_frame
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_viewport.push_input(event)
	var released := event.duplicate() as InputEventKey
	released.pressed = false
	_viewport.push_input(released)
	await process_frame


func _press_controller_direction(button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = true
	_viewport.push_input(event)
	var released := event.duplicate() as InputEventJoypadButton
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
