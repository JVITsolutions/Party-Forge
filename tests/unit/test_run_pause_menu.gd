extends RefCounted

const MENU_SCENE_PATH := "res://scenes/ui/run_pause_menu.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists(MENU_SCENE_PATH):
		TestAssertions.truthy(false, "run pause menu scene exists", failures)
		return failures
	var menu_scene := load(MENU_SCENE_PATH) as PackedScene
	TestAssertions.truthy(menu_scene != null, "run pause menu scene loads", failures)
	if menu_scene == null:
		return failures
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var menu := menu_scene.instantiate()
	tree.root.add_child(menu)
	var run := GameRun.new()
	run.start_run()
	menu.call("configure", run, func() -> bool: return false)

	for node_path: NodePath in [
		^"Overlay/Panel/Content/Title",
		^"Overlay/Panel/Content/Resume",
		^"Overlay/Panel/Content/Settings",
		^"Overlay/Panel/Content/AbandonRun",
		^"Overlay/AbandonConfirmation/Panel/Content/Message",
		^"Overlay/AbandonConfirmation/Panel/Content/Confirm",
		^"Overlay/AbandonConfirmation/Panel/Content/Cancel",
		^"Overlay/AbandonCommittedError/Panel/Content/Message",
		^"Overlay/AbandonCommittedError/Panel/Content/RetryReturnToForge",
	]:
		TestAssertions.truthy(menu.get_node_or_null(node_path) != null, "pause menu owns %s" % node_path, failures)
	if not failures.is_empty():
		menu.free()
		run.free()
		tree.paused = false
		return failures

	TestAssertions.truthy(bool(menu.call("open")), "pause menu opens during RUNNING", failures)
	TestAssertions.truthy(tree.paused, "pause menu owns a pause lease", failures)
	var title := menu.get_node("Overlay/Panel/Content/Title") as Label
	var resume := menu.get_node("Overlay/Panel/Content/Resume") as Button
	var settings := menu.get_node("Overlay/Panel/Content/Settings") as Button
	var abandon_run := menu.get_node("Overlay/Panel/Content/AbandonRun") as Button
	var confirmation := menu.get_node("Overlay/AbandonConfirmation") as Control
	var confirmation_message := menu.get_node("Overlay/AbandonConfirmation/Panel/Content/Message") as Label
	var confirm := menu.get_node("Overlay/AbandonConfirmation/Panel/Content/Confirm") as Button
	var cancel := menu.get_node("Overlay/AbandonConfirmation/Panel/Content/Cancel") as Button
	var committed_error := menu.get_node("Overlay/AbandonCommittedError") as Control
	var committed_message := menu.get_node("Overlay/AbandonCommittedError/Panel/Content/Message") as Label
	var retry_return := menu.get_node("Overlay/AbandonCommittedError/Panel/Content/RetryReturnToForge") as Button
	TestAssertions.equal(abandon_run.text, "Abandon Run", "active-run destructive action uses exact Abandon Run copy", failures)
	TestAssertions.equal(confirm.text, "Abandon Run", "confirmation uses exact Abandon Run copy", failures)
	TestAssertions.truthy(settings.focus_mode != Control.FOCUS_NONE, "Settings remains focusable", failures)
	TestAssertions.truthy(settings.has_meta("coming_soon") and bool(settings.get_meta("coming_soon")), "Settings is marked Coming Soon", failures)
	settings.pressed.emit()
	TestAssertions.equal(title.text, "Settings: Coming Soon", "Settings shows exact Coming Soon status", failures)
	TestAssertions.truthy(bool(menu.visible) and tree.paused, "Settings performs no navigation or pause release", failures)

	abandon_run.pressed.emit()
	TestAssertions.truthy(confirmation.visible and tree.paused, "Abandon Run opens confirmation without releasing pause", failures)
	TestAssertions.truthy(confirmation_message.text.contains("forfeit") and confirmation_message.text.contains("run-owned progress/items"), "confirmation explains exact forfeiture consequence", failures)
	if menu.is_inside_tree():
		TestAssertions.truthy(tree.root.gui_get_focus_owner() == cancel, "Abandon confirmation defaults safely to Cancel", failures)
	for property_name: StringName in [&"focus_neighbor_left", &"focus_neighbor_top", &"focus_neighbor_right", &"focus_neighbor_bottom", &"focus_next", &"focus_previous"]:
		TestAssertions.equal(confirm.get(property_name), confirm.get_path_to(cancel), "Confirm %s stays inside the modal" % property_name, failures)
		TestAssertions.equal(cancel.get(property_name), cancel.get_path_to(confirm), "Cancel %s stays inside the modal" % property_name, failures)
	menu.call("_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(bool(menu.visible) and not confirmation.visible, "Cancel closes only confirmation", failures)
	TestAssertions.truthy(abandon_run.focus_mode != Control.FOCUS_NONE, "Cancel leaves Abandon Run as a valid focus-return target", failures)

	abandon_run.pressed.emit()
	var abandon_count: Array[int] = [0]
	menu.connect("abandon_run_confirmed", func() -> void: abandon_count[0] += 1)
	confirm.pressed.emit()
	confirm.pressed.emit()
	TestAssertions.equal(abandon_count[0], 1, "confirmed Abandon emits exactly once", failures)
	menu.call("reject_abandon", "Unable to abandon this run.")
	TestAssertions.truthy(menu.visible and tree.paused and not confirmation.visible, "forfeit failure leaves the active-run menu recoverable and paused", failures)
	abandon_run.pressed.emit()
	confirm.pressed.emit()
	TestAssertions.equal(abandon_count[0], 2, "forfeit rejection permits one fresh Abandon attempt", failures)
	menu.call("present_abandon_committed_refresh_error", "Run abandoned, but the profile could not refresh. Retry Return to Forge.")
	TestAssertions.truthy(committed_error.visible and committed_message.text == "Run abandoned, but the profile could not refresh. Retry Return to Forge.", "committed refresh error shows exact durable status", failures)
	TestAssertions.truthy(tree.paused and menu.visible, "committed refresh error keeps the pause lease", failures)
	TestAssertions.truthy(retry_return.visible and not retry_return.disabled, "Retry Return to Forge is the sole enabled action", failures)
	if menu.is_inside_tree():
		TestAssertions.truthy(tree.root.gui_get_focus_owner() == retry_return, "Retry Return to Forge is the only focused action", failures)
	for blocked: Button in [resume, settings, abandon_run, confirm, cancel]:
		TestAssertions.truthy(not blocked.visible or blocked.disabled or blocked.focus_mode == Control.FOCUS_NONE, "committed refresh state blocks %s" % blocked.name, failures)
	menu.call("close")
	TestAssertions.truthy(menu.visible and tree.paused and committed_error.visible, "programmatic close is rejected after committed Abandon", failures)
	for action: StringName in [&"ui_cancel", &"pause_menu"]:
		menu.call("_unhandled_input", _action_event(action))
		TestAssertions.truthy(menu.visible and tree.paused and committed_error.visible, "committed refresh state consumes %s" % action, failures)
	abandon_run.pressed.emit()
	confirm.pressed.emit()
	TestAssertions.equal(abandon_count[0], 2, "committed refresh state cannot emit Abandon again", failures)
	var retry_count: Array[int] = [0]
	menu.connect("retry_abandon_refresh_requested", func() -> void: retry_count[0] += 1)
	retry_return.pressed.emit()
	retry_return.pressed.emit()
	TestAssertions.equal(retry_count[0], 1, "committed refresh retry emits exactly once while pending", failures)
	menu.call("present_abandon_committed_refresh_error", "Run abandoned, but the profile could not refresh. Retry Return to Forge.")
	TestAssertions.truthy(retry_return.visible and not retry_return.disabled, "retry failure restores the same bounded action", failures)
	if menu.is_inside_tree():
		TestAssertions.truthy(tree.root.gui_get_focus_owner() == retry_return, "retry failure restores the same bounded focus", failures)
	menu.call("complete_abandon_return")
	TestAssertions.truthy(not menu.visible and not tree.paused, "successful refresh releases the menu for front-end return", failures)

	tree.paused = true
	TestAssertions.truthy(bool(menu.call("open")), "menu can acquire over a pre-existing pause", failures)
	resume.pressed.emit()
	TestAssertions.truthy(tree.paused, "Resume restores the pre-existing pause owner", failures)
	tree.paused = false
	TestAssertions.truthy(bool(menu.call("open")), "menu reopens for toggle-close coverage", failures)
	menu.call("_unhandled_input", _action_event(&"pause_menu"))
	TestAssertions.truthy(not bool(menu.visible) and not tree.paused, "pause-menu toggle releases only its own lease", failures)

	run.begin_level_up()
	TestAssertions.truthy(not bool(menu.call("open")), "pause menu refuses LEVEL_UP", failures)
	TestAssertions.truthy(tree.paused, "LEVEL_UP refusal preserves the run-owned pause", failures)
	run.resume_run()
	TestAssertions.truthy(not tree.paused, "run resumes after LEVEL_UP fixture", failures)
	run.advance_run_time(RunStateMachine.BOSS_TIME)
	TestAssertions.truthy(bool(menu.call("open")), "pause menu opens during BOSS", failures)
	menu.call("close")
	TestAssertions.truthy(not tree.paused, "BOSS menu close restores running tree", failures)

	menu.call("configure", run, func() -> bool: return true)
	TestAssertions.truthy(not bool(menu.call("open")), "pause menu refuses while ledger is open", failures)
	menu.call("_unhandled_input", _action_event(&"pause_menu"))
	TestAssertions.truthy(not bool(menu.visible) and not tree.paused, "ledger refusal leaves the event available and changes no pause state", failures)

	menu.free()
	run.free()
	tree.paused = false
	return failures


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
