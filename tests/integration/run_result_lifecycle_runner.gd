extends SceneTree

const PANEL_SCENE := "res://scenes/ui/run_result_panel.tscn"
const FIXTURE_PATH := "res://tests/unit/test_run_recap_projection.gd"
const VIEW_MODEL_PATH := "res://scripts/ui/run_result/run_result_view_model.gd"

var _failures: Array[String] = []
var _panel: Control

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var packed := load(PANEL_SCENE) as PackedScene
	var fixture_type := load(FIXTURE_PATH) as Script
	var view_model_type := load(VIEW_MODEL_PATH) as Script
	_assert(packed != null, "result panel scene loads")
	_assert(fixture_type != null and view_model_type != null, "typed result fixtures load")
	if packed == null or fixture_type == null or view_model_type == null:
		_finish()
		return
	_panel = packed.instantiate() as Control
	root.add_child(_panel)
	root.size = Vector2i(1280, 720)
	_assert(_panel.has_method(&"present") and not _panel.has_method(&"show_result"), "panel exposes only typed present(projection)")
	if not _panel.has_method(&"present"):
		_finish()
		return
	var fixtures: Variant = fixture_type.new()
	var view_model: Variant = view_model_type.new()
	var victory: Dictionary = fixtures.call(&"_fixture", 24, 24, RunTerminalSnapshot.Outcome.VICTORY)
	var defeat: Dictionary = fixtures.call(&"_fixture", 3, 2, RunTerminalSnapshot.Outcome.DEFEAT)

	var victory_result: Variant = view_model.call(&"build", victory.snapshot, victory.resolution, victory.profile, [])
	var defeat_result: Variant = view_model.call(&"build", defeat.snapshot, defeat.resolution, defeat.profile, [])
	_assert(bool(victory_result.call(&"ok")) and bool(defeat_result.call(&"ok")), "victory and defeat both build from durable truth")
	if bool(victory_result.call(&"ok")) and bool(defeat_result.call(&"ok")):
		_assert(_entry_value(victory_result.get("projection"), &"outcome", "Outcome") == "Victory", "victory projection names exact outcome")
		_assert(_entry_value(defeat_result.get("projection"), &"outcome", "Outcome") == "Defeat", "defeat projection names exact outcome")
		_assert(victory_result.get("projection").call(&"section_ids") == [&"outcome", &"party", &"loot"], "unsupported recap sections remain absent")
		_panel.call(&"present", defeat_result.get("projection"))
		await process_frame
		_assert(_entry_text(&"outcome", "Outcome").contains("Defeat"), "rendered defeat outcome is not hardcoded victory")
		_assert(not _entry_rows(&"loot").is_empty(), "rendered defeat retains truthful loss rows")

	var empty_provider: Variant = fixtures.call(&"provider", &"empty", 0, &"empty", 5)
	var failed_provider: Variant = fixtures.call(&"provider", &"failed", 1, &"failure", 4)
	var omitted: Variant = view_model.call(&"build", victory.snapshot, victory.resolution, victory.profile, [failed_provider, empty_provider])
	_assert(bool(omitted.call(&"ok")) and omitted.get("projection").call(&"section_ids") == [&"outcome", &"party", &"loot"], "optional empty/failed providers log and omit")
	var duplicate_a: Variant = fixtures.call(&"provider", &"collision", 0, &"empty", 5)
	var duplicate_b: Variant = fixtures.call(&"provider", &"collision", 1, &"section", 5)
	_assert(not bool(view_model.call(&"build", victory.snapshot, victory.resolution, victory.profile, [duplicate_a, duplicate_b]).call(&"ok")), "provider collision rejects the complete projection")

	await _exercise_states_and_actions(view_model, victory, victory_result.get("projection"))
	await _assert_scaled_recap_origin(victory_result.get("projection"))
	await _exercise_long_reachability(victory_result.get("projection"))
	_finish()

func _assert_scaled_recap_origin(finalized: RunResultProjection) -> void:
	var settings := PartyForgeSettings.new()
	settings.ui_scale_percent = 80
	settings.text_scale_percent = 150
	_panel.call(&"present", finalized.with_visual_settings(settings))
	await process_frame
	await process_frame
	var header := _panel.get_node("Frame/Content/Header") as Control
	var body := _panel.get_node("Frame/Content/Body") as ScrollContainer
	var first_section := _panel.get_node_or_null("Frame/Content/Body/Recap/Section_outcome") as Control
	_assert(body.scroll_vertical == 0, "scaled finalized recap resets to its vertical origin after rebuild")
	_assert(first_section != null, "scaled finalized recap retains its first section")
	if first_section != null:
		_assert(first_section.get_global_rect().position.y >= header.get_global_rect().end.y + 8.0, "scaled finalized first recap entry starts fully below the header with an 8 px inset")
		_assert(first_section.get_global_rect().position.y >= body.get_global_rect().position.y + 8.0, "scaled finalized recap retains an 8 px inset inside the scroll viewport")
	var rows: Array[Button] = []
	for node: Node in _panel.find_children("*", "Button", true, false):
		if node.has_meta(&"recap_section_id"):
			rows.append(node as Button)
	if not rows.is_empty():
		var last_row := rows[-1]
		last_row.grab_focus()
		last_row.pressed.emit()
		for _frame: int in 4:
			await process_frame
		var body_rect := body.get_global_rect()
		var top_visible_row: Button
		for row: Button in rows:
			var row_rect := row.get_global_rect()
			if row_rect.end.y <= body_rect.position.y or row_rect.position.y >= body_rect.end.y:
				continue
			if top_visible_row == null or row_rect.position.y < top_visible_row.get_global_rect().position.y:
				top_visible_row = row
		var visible_debug: Array[String] = []
		for row: Button in rows:
			if row.get_global_rect().end.y > body_rect.position.y and row.get_global_rect().position.y < body_rect.end.y:
				visible_debug.append("%s@%d-%d" % [row.name, roundi(row.get_global_rect().position.y), roundi(row.get_global_rect().end.y)])
		_assert(top_visible_row != null and top_visible_row.get_global_rect().position.y >= body_rect.position.y + 4.0, "expanded scaled recap never leaves its first visible entry clipped behind the header (body=%d-%d scroll=%d visible=%s)" % [roundi(body_rect.position.y), roundi(body_rect.end.y), body.scroll_vertical, visible_debug])

func _exercise_states_and_actions(view_model: Variant, fixture: Dictionary, finalized: Variant) -> void:
	var pending: Variant = view_model.call(&"pending", fixture.snapshot).get("projection")
	var save_interrupted: Variant = view_model.call(&"terminal_save_interrupted", fixture.snapshot, "Terminal record could not be saved.").get("projection")
	var refresh_interrupted: Variant = view_model.call(&"terminal_refresh_interrupted", fixture.snapshot, "Terminal state was saved, but recovery could not refresh.").get("projection")
	var unsafe: Variant = view_model.call(&"resolution_interrupted", fixture.snapshot, "Resolution was interrupted.", null).get("projection")
	var projection_interrupted: Variant = view_model.call(&"projection_interrupted", fixture.snapshot, fixture.resolution, "Results could not be built.").get("projection")
	var automatic_evaluation := RunResolutionEvaluation.create(fixture.resolution.accepted_extraction, 2, 0, 0, "automatic-only blocked", RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, "Automatic retained items need more destination space.")
	var preflight := RunResolutionPreflightResult.from_evaluation(automatic_evaluation)
	var durable := _durable_safety(fixture.snapshot, ["displaced-a", "displaced-b"])
	var guarded: Variant = view_model.call(&"resolution_interrupted", fixture.snapshot, preflight.player_reason, durable, preflight).get("projection")

	_panel.call(&"present", pending)
	await process_frame
	_assert(not (_panel.get_node("Frame/Content/Body") as Control).visible, "pending state exposes no recap")
	_assert(_visible_actions().is_empty(), "pending state disables and hides every action")

	_panel.call(&"present", unsafe)
	await process_frame
	_assert(_visible_action_names() == ["RetryResolution"], "unsafe resolution interruption exposes only Retry Resolution")
	_assert(not _button("RestartRun").visible, "Restart is absent from interrupted truth")

	var counts := {
		"save": 0, "refresh": 0, "resolution": 0, "projection": 0, "protect": 0,
		"armoury": 0, "restart": 0, "return": 0, "quit": 0,
		"protect_focus": null, "armoury_focus": null,
	}
	_panel.retry_terminal_save_requested.connect(func() -> void: counts.save = int(counts.save) + 1)
	_panel.retry_terminal_refresh_requested.connect(func() -> void: counts.refresh = int(counts.refresh) + 1)
	_panel.retry_resolution_requested.connect(func() -> void: counts.resolution = int(counts.resolution) + 1)
	_panel.retry_projection_requested.connect(func() -> void: counts.projection = int(counts.projection) + 1)
	_panel.protect_displaced_gear_requested.connect(func(return_focus: Control) -> void:
		counts.protect = int(counts.protect) + 1
		counts.protect_focus = return_focus
	)
	_panel.open_armoury_requested.connect(func(return_focus: Control) -> void:
		counts.armoury = int(counts.armoury) + 1
		counts.armoury_focus = return_focus
	)
	_panel.restart_run_requested.connect(func() -> void: counts.restart = int(counts.restart) + 1)
	_panel.return_to_forge_requested.connect(func() -> void: counts.return = int(counts.return) + 1)
	_panel.quit_application_requested.connect(func() -> void: counts.quit = int(counts.quit) + 1)

	_panel.call(&"present", projection_interrupted)
	await process_frame
	var retry := _button("RetryProjection")
	_assert(retry.has_focus(), "projection interruption defaults to non-destructive Retry Results")
	await _mouse_activate(retry)
	await _mouse_activate(retry)
	_assert(int(counts.projection) == 1 and retry.disabled, "mouse duplicate pending activation is suppressed")

	_panel.call(&"present", guarded)
	await process_frame
	_assert(_visible_action_names() == ["RetryResolution", "ProtectDisplacedGear", "OpenArmoury", "ReturnToForge", "QuitApplication"], "typed automatic-only and durable safety expose the exact guarded action set")
	_assert(not _button("RestartRun").visible, "guarded interruption omits Restart")
	var synthetic_recap_row := Button.new()
	synthetic_recap_row.name = "SyntheticBackgroundRecapRow"
	synthetic_recap_row.custom_minimum_size = Vector2(120.0, 48.0)
	var synthetic_presses := {"count": 0}
	synthetic_recap_row.pressed.connect(func() -> void: synthetic_presses.count = int(synthetic_presses.count) + 1)
	(_panel.get_node("Frame/Content/Body/Recap") as VBoxContainer).add_child(synthetic_recap_row)
	var protect := _button("ProtectDisplacedGear")
	protect.grab_focus()
	await process_frame
	await _keyboard_activate(protect)
	var confirmation := _panel.get_node("Frame/Content/Confirmation") as PanelContainer
	_assert(confirmation.visible, "protection opens confirmation")
	_assert((confirmation.get_node("Content/Copy") as Label).text == "Move 2 current leader items to Recovery Overflow so automatic extraction can continue.", "protection copy carries exact displaced count")
	var cancel := confirmation.get_node("Content/Actions/Cancel") as Button
	_assert(cancel.has_focus(), "confirmation uses safe Cancel default")
	for footer_action: Button in _visible_actions():
		_assert(footer_action.disabled and footer_action.focus_mode == Control.FOCUS_NONE, "confirmation isolates footer action %s" % footer_action.name)
	_assert(synthetic_recap_row.disabled and synthetic_recap_row.focus_mode == Control.FOCUS_NONE and synthetic_recap_row.mouse_filter == Control.MOUSE_FILTER_IGNORE, "confirmation isolates recap/background controls")
	await _mouse_activate(synthetic_recap_row)
	await _keyboard_activate(synthetic_recap_row)
	_assert(int(synthetic_presses.count) == 0 and not synthetic_recap_row.has_focus(), "isolated recap row cannot focus or toggle")
	var background_before := counts.duplicate()
	for background_action: String in ["RetryTerminalSave", "RetryTerminalRefresh", "RetryResolution", "RetryProjection", "ProtectDisplacedGear", "OpenArmoury", "RestartRun", "ReturnToForge", "QuitApplication"]:
		_button(background_action).pressed.emit()
	_assert(int(counts.save) == int(background_before.save) and int(counts.refresh) == int(background_before.refresh) and int(counts.resolution) == int(background_before.resolution) and int(counts.projection) == int(background_before.projection) and int(counts.protect) == int(background_before.protect) and int(counts.armoury) == int(background_before.armoury) and int(counts.restart) == int(background_before.restart) and int(counts.return) == int(background_before.return) and int(counts.quit) == int(background_before.quit), "all background action signals stay unchanged while confirmation is open")
	_assert(cancel.has_focus(), "isolated confirmation prevents footer focus")
	var confirm := confirmation.get_node("Content/Actions/Confirm") as Button
	await _action_input(&"ui_focus_next")
	_assert(confirm.has_focus(), "Tab moves only from Cancel to Confirm")
	await _action_input(&"ui_focus_next")
	_assert(cancel.has_focus(), "Tab wraps only within confirmation")
	await _action_input(&"ui_focus_prev")
	_assert(confirm.has_focus(), "Shift-Tab stays within confirmation")
	await _action_input(&"ui_focus_prev")
	_assert(cancel.has_focus(), "Shift-Tab wraps back to safe Cancel")
	var cancel_background_before := counts.duplicate()
	await _action_input(&"ui_cancel")
	_assert(protect.has_focus() and not confirmation.visible, "ui_cancel routes through safe Cancel and restores initiating focus")
	_assert(int(counts.protect) == int(cancel_background_before.protect) and int(counts.armoury) == int(cancel_background_before.armoury) and int(counts.resolution) == int(cancel_background_before.resolution) and int(counts.return) == int(cancel_background_before.return) and int(counts.quit) == int(cancel_background_before.quit), "ui_cancel emits no Protect or background action signal")
	await _controller_activate(protect)
	_assert(cancel.has_focus(), "controller reopen still defaults to safe Cancel")
	await _controller_activate(cancel)
	_assert(protect.has_focus() and not confirmation.visible, "controller Cancel restores exact initiating focus")

	_panel.call(&"present", finalized)
	await process_frame
	_assert(_visible_action_names() == ["RestartRun", "ReturnToForge", "QuitApplication"], "finalized state exposes exact terminal exits only")
	_assert(_button("ReturnToForge").has_focus(), "finalized state defaults to safe Return to Forge")
	_assert(not _button("RestartRun").has_focus() and not _button("QuitApplication").has_focus(), "finalized destructive/consequence actions are not default-focused")
	_assert((_panel.get_node("Frame/Content/Header/OutcomeHeadline") as Label).text == "VICTORY · 01:30", "rendered hierarchy leads with verified outcome and duration")

	await _assert_button_parity(save_interrupted, "RetryTerminalSave", "save", counts)
	await _assert_button_parity(refresh_interrupted, "RetryTerminalRefresh", "refresh", counts)
	await _assert_button_parity(unsafe, "RetryResolution", "resolution", counts)
	await _assert_button_parity(projection_interrupted, "RetryProjection", "projection", counts)
	await _assert_button_parity(guarded, "OpenArmoury", "armoury", counts)
	await _assert_button_parity(finalized, "RestartRun", "restart", counts)
	await _assert_button_parity(finalized, "ReturnToForge", "return", counts)
	await _assert_button_parity(finalized, "QuitApplication", "quit", counts)
	await _assert_protect_parity(guarded, counts)

func _exercise_long_reachability(finalized: Variant) -> void:
	_panel.call(&"present", finalized)
	await process_frame
	var party_rows: Array[Button] = []
	var loot_rows: Array[Button] = []
	for node: Node in _panel.find_children("*", "Button", true, false):
		if node.get_meta(&"recap_section_id", &"") == &"party":
			party_rows.append(node as Button)
		elif node.get_meta(&"recap_section_id", &"") == &"loot":
			loot_rows.append(node as Button)
	_assert(party_rows.size() == 24, "all 24 members are concrete focusable rows")
	_assert(loot_rows.size() == 30, "all automatic/selected/lost/protected items are concrete focusable rows")
	if party_rows.size() != 24:
		return
	var final_member := party_rows[23]
	var final_loot := loot_rows[29] if loot_rows.size() == 30 else null
	var scroll := _panel.get_node("Frame/Content/Body") as ScrollContainer
	party_rows[0].grab_focus()
	await process_frame
	var initial_scroll := scroll.scroll_vertical
	for _step: int in 23:
		await _keyboard_move_down()
	_assert(final_member.has_focus(), "24th member is reached by actual keyboard ui_down traversal")
	_assert(scroll.scroll_vertical > initial_scroll, "keyboard traversal scrolls the bounded recap")
	if final_loot != null:
		for _step: int in 30:
			await _keyboard_move_down()
		_assert(final_loot.has_focus(), "final loot item is reached by continued keyboard traversal")
		await _keyboard_move_down()
		_assert(_button("ReturnToForge").has_focus(), "keyboard crosses explicit focus bridge from recap endpoint to footer")
		await _keyboard_move_up()
		_assert(final_loot.has_focus(), "keyboard crosses focus bridge back to recap endpoint")
		await _mouse_activate(final_loot)
		var detail := final_loot.get_node_or_null("Detail") as Label
		_assert(detail != null and detail.visible, "mouse reaches the same final loot detail")
	party_rows[0].grab_focus()
	await process_frame
	for _step: int in 53:
		await _controller_move_down()
	_assert(final_loot != null and final_loot.has_focus(), "simulated controller D-pad reaches the final loot item through Member 24")
	await _controller_move_down()
	_assert(_button("ReturnToForge").has_focus(), "controller crosses explicit focus bridge to footer")
	await _controller_move_up()
	_assert(final_loot != null and final_loot.has_focus(), "controller crosses explicit focus bridge back to recap")
	for upward_step: int in 12:
		await _keyboard_move_up()
		for _settle_frame: int in 5:
			await process_frame
		var focused := root.gui_get_focus_owner() as Control
		_assert(focused != null and focused.has_meta(&"recap_section_id"), "upward traversal step %d retains a concrete recap-row focus owner" % upward_step)
		if focused != null and focused.has_meta(&"recap_section_id"):
			var visible_rect := scroll.get_global_rect()
			var vertical_bar := scroll.get_v_scroll_bar()
			if vertical_bar != null and vertical_bar.is_visible_in_tree():
				visible_rect.size.x -= vertical_bar.get_global_rect().size.x
			var horizontal_bar := scroll.get_h_scroll_bar()
			if horizontal_bar != null and horizontal_bar.is_visible_in_tree():
				visible_rect.size.y -= horizontal_bar.get_global_rect().size.y
			_assert(visible_rect.grow(0.5).encloses(focused.get_global_rect()), "upward traversal step %d keeps the focused recap row fully enclosed" % upward_step)
	if loot_rows.size() > 11:
		var upward_target := loot_rows[10]
		var downward_origin := loot_rows[11]
		upward_target.grab_focus()
		await process_frame
		await _keyboard_move_down()
		_assert(downward_origin.has_focus(), "focused-row eviction fixture first traverses downward to the next recap row")
		var viewport_top := scroll.get_global_rect().position.y
		scroll.scroll_vertical += roundi(upward_target.get_global_rect().position.y - viewport_top + 20.0)
		await process_frame
		_assert(upward_target.get_global_rect().position.y < viewport_top and upward_target.get_global_rect().end.y > viewport_top, "focused-row eviction fixture leaves the upward target partially visible")
		_panel.call(&"_snap_scroll_to_complete_row", upward_target)
		await process_frame
		_assert(scroll.get_global_rect().grow(0.5).encloses(upward_target.get_global_rect()), "complete-row snap helper preserves the row it was asked to protect")
		scroll.scroll_vertical += roundi(upward_target.get_global_rect().position.y - viewport_top + 20.0)
		await process_frame
		await _keyboard_move_up()
		for _settle_frame: int in 5:
			await process_frame
		_assert(upward_target.has_focus(), "real downward-then-upward traversal restores the intended recap row")
		_assert(scroll.get_global_rect().grow(0.5).encloses(upward_target.get_global_rect()), "complete-row snapping never evicts the upward-focused recap row")

func _entry_value(projection: Variant, section_id: StringName, label: String) -> String:
	for section: Variant in projection.get("sections"):
		if section.get("section_id") != section_id:
			continue
		for entry: Variant in section.get("entries"):
			if String(entry.get("label")) == label:
				return String(entry.get("value"))
	return ""

func _entry_rows(section_id: StringName) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in _panel.find_children("*", "Button", true, false):
		if node.get_meta(&"recap_section_id", &"") == section_id:
			result.append(node as Button)
	return result

func _entry_text(section_id: StringName, label: String) -> String:
	for row: Button in _entry_rows(section_id):
		if String(row.get_meta(&"recap_entry_label", "")) == label:
			return row.text
	return ""

func _button(name_value: String) -> Button:
	return _panel.get_node("Frame/Content/Footer/Actions/%s" % name_value) as Button

func _visible_actions() -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in _panel.get_node("Frame/Content/Footer/Actions").get_children():
		if child is Button and (child as Button).visible:
			result.append(child as Button)
	return result

func _visible_action_names() -> Array[String]:
	var result: Array[String] = []
	for button: Button in _visible_actions():
		result.append(button.name)
	return result

func _assert_button_parity(projection: Variant, button_name: String, counter_key: String, counts: Dictionary) -> void:
	for mode: int in 3:
		_panel.call(&"present", projection)
		await process_frame
		var before := int(counts[counter_key])
		var target := _button(button_name)
		if mode == 0:
			await _mouse_activate(target)
		elif mode == 1:
			await _keyboard_activate(target)
		else:
			await _controller_activate(target)
		_assert(int(counts[counter_key]) == before + 1, "%s emits exactly one signal through %s" % [button_name, ["mouse", "keyboard", "controller"][mode]])
		if counter_key == "armoury":
			_assert(counts.armoury_focus == target, "Open Armoury %s payload is the exact initiating action button" % ["mouse", "keyboard", "controller"][mode])

func _assert_protect_parity(projection: Variant, counts: Dictionary) -> void:
	for mode: int in 3:
		_panel.call(&"present", projection)
		await process_frame
		var protect := _button("ProtectDisplacedGear")
		if mode == 0:
			await _mouse_activate(protect)
		elif mode == 1:
			await _keyboard_activate(protect)
		else:
			await _controller_activate(protect)
		var confirm := _panel.get_node("Frame/Content/Confirmation/Content/Actions/Confirm") as Button
		var before := int(counts.protect)
		if mode == 0:
			await _mouse_activate(confirm)
			await _mouse_activate(confirm)
		elif mode == 1:
			await _keyboard_activate(confirm)
			await _keyboard_activate(confirm)
		else:
			await _controller_activate(confirm)
			await _controller_activate(confirm)
		_assert(int(counts.protect) == before + 1, "Protect confirmation emits exactly once through %s" % ["mouse", "keyboard", "controller"][mode])
		_assert(counts.protect_focus == protect, "Protect %s payload is the exact initiating action button" % ["mouse", "keyboard", "controller"][mode])
		_assert(confirm.disabled and protect.disabled, "Protect double activation enters one disabled pending state")

func _keyboard_move_down() -> void:
	var press := InputEventAction.new()
	press.action = &"ui_down"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := press.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _controller_move_down() -> void:
	await _joypad_direction(JOY_BUTTON_DPAD_DOWN)

func _keyboard_move_up() -> void:
	await _action_input(&"ui_up")

func _controller_move_up() -> void:
	await _joypad_direction(JOY_BUTTON_DPAD_UP)

func _controller_move_right() -> void:
	await _joypad_direction(JOY_BUTTON_DPAD_RIGHT)

func _controller_move_left() -> void:
	await _joypad_direction(JOY_BUTTON_DPAD_LEFT)

func _action_input(action_name: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := press.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _joypad_direction(button_index: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button_index
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := press.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _durable_safety(snapshot: RunTerminalSnapshot, displaced_ids: Array[String]) -> RunTerminalRecoverySafetyResult:
	var empty: Array[String] = []
	var record_result := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION, snapshot,
		empty, "", displaced_ids, "", null, "",
	)
	return RunTerminalRecoverySafetyResult.success(record_result.record) if record_result.ok() else RunTerminalRecoverySafetyResult.failure(record_result.error)

func _mouse_activate(target: Button) -> void:
	if target == null or target.disabled:
		return
	var center := target.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	motion.relative = center - root.get_mouse_position()
	root.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = center
	press.global_position = center
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.button_mask = 0
	release.pressed = false
	root.push_input(release, true)
	await process_frame

func _keyboard_activate(target: Button) -> void:
	if target == null or target.disabled:
		return
	target.grab_focus()
	await process_frame
	var press := InputEventAction.new()
	press.action = &"ui_accept"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := press.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _controller_activate(target: Button) -> void:
	if target == null or target.disabled:
		return
	target.grab_focus()
	await process_frame
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := press.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("RUN_RESULT_LIFECYCLE_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("RUN_RESULT_LIFECYCLE_FAILURE: %s" % failure)
	print("RUN_RESULT_LIFECYCLE_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)
