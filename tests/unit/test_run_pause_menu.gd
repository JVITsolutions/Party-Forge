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
		^"Overlay/Panel/Content/QuitRun",
		^"Overlay/QuitConfirmation/Panel/Content/Message",
		^"Overlay/QuitConfirmation/Panel/Content/Confirm",
		^"Overlay/QuitConfirmation/Panel/Content/Cancel",
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
	var quit_run := menu.get_node("Overlay/Panel/Content/QuitRun") as Button
	var confirmation := menu.get_node("Overlay/QuitConfirmation") as Control
	var confirm := menu.get_node("Overlay/QuitConfirmation/Panel/Content/Confirm") as Button
	TestAssertions.truthy(settings.focus_mode != Control.FOCUS_NONE, "Settings remains focusable", failures)
	TestAssertions.truthy(settings.has_meta("coming_soon") and bool(settings.get_meta("coming_soon")), "Settings is marked Coming Soon", failures)
	settings.pressed.emit()
	TestAssertions.equal(title.text, "Settings: Coming Soon", "Settings shows exact Coming Soon status", failures)
	TestAssertions.truthy(bool(menu.visible) and tree.paused, "Settings performs no navigation or pause release", failures)

	quit_run.pressed.emit()
	TestAssertions.truthy(confirmation.visible and tree.paused, "Quit Run opens confirmation without releasing pause", failures)
	menu.call("_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(bool(menu.visible) and not confirmation.visible, "Cancel closes only confirmation", failures)
	TestAssertions.truthy(quit_run.focus_mode != Control.FOCUS_NONE, "Cancel leaves Quit Run as a valid focus-return target", failures)

	quit_run.pressed.emit()
	var quit_count: Array[int] = [0]
	menu.connect("quit_run_confirmed", func() -> void: quit_count[0] += 1)
	confirm.pressed.emit()
	confirm.pressed.emit()
	TestAssertions.equal(quit_count[0], 1, "confirmed Quit Run emits exactly once", failures)
	menu.call("close")
	TestAssertions.truthy(not tree.paused, "closing after confirmation releases this menu's lease", failures)

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
