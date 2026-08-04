extends RefCounted

const SELECTOR_SCRIPT_PATH := "res://scripts/ui/class_selection_panel.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(SELECTOR_SCRIPT_PATH), "selector reusable script exists", failures)
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	var panel := hud.get_node("ClassSelection")
	var panel_script := panel.get_script() as Script
	TestAssertions.equal(panel_script.resource_path if panel_script != null else "", SELECTOR_SCRIPT_PATH, "selector uses reusable script", failures)
	if panel_script != null and panel_script.resource_path == SELECTOR_SCRIPT_PATH:
		panel.call("_ready")
		var catalog := GameCatalog.load_defaults()
		panel.call("configure", catalog.classes)
		_test_scene_and_class_contract(panel, catalog, failures)
		_test_lifecycle_and_run_hud_contract(panel, hud, failures)
		_test_back_intent_is_side_effect_free(panel, hud, failures)
		_test_focus_wiring(panel, failures)
	hud.free()
	return failures


func _test_scene_and_class_contract(panel: Control, catalog: GameCatalog, failures: Array[String]) -> void:
	for method: StringName in [&"open", &"close", &"is_open", &"confirm_run_started"]:
		TestAssertions.truthy(panel.has_method(method), "selector exposes %s lifecycle contract" % method, failures)
	TestAssertions.truthy(panel.has_signal(&"back_requested"), "selector exposes Back intent", failures)
	var back := panel.get_node_or_null("Content/Actions/Back") as Button
	TestAssertions.truthy(back != null, "selector keeps stable Back action beside Settings", failures)
	var grid := panel.get_node("Content/Scroll/Grid") as GridContainer
	TestAssertions.equal(grid.columns, 3, "selector uses three-column grid", failures)
	TestAssertions.equal(grid.get_child_count(), 9, "selector renders all nine classes", failures)
	var selected: Array[StringName] = []
	panel.connect("class_selected", func(class_id: StringName) -> void: selected.append(class_id))
	for index: int in range(catalog.classes.size()):
		var definition := catalog.classes[index]
		var button := grid.get_child(index) as Button
		TestAssertions.equal(button.name, "Class_%s" % definition.id, "%s stable button name" % definition.id, failures)
		TestAssertions.truthy(definition.display_name in button.text, "%s display name shown" % definition.id, failures)
		button.pressed.emit()
		TestAssertions.equal(selected[-1], definition.id, "%s emits exact id" % definition.id, failures)
	TestAssertions.equal(selected.size(), 9, "each button emits once", failures)
	var settings_requested: Array[int] = [0]
	panel.connect("settings_requested", func() -> void: settings_requested[0] += 1)
	var settings := panel.get_node("Content/Actions/Settings") as Button
	settings.pressed.emit()
	TestAssertions.equal(settings_requested[0], 1, "Settings emits one request", failures)
	TestAssertions.equal(settings.name, &"Settings", "Settings keeps its stable return-focus path", failures)


func _test_lifecycle_and_run_hud_contract(panel: Control, hud: CanvasLayer, failures: Array[String]) -> void:
	if not panel.has_method(&"open") or not panel.has_method(&"close") or not panel.has_method(&"is_open"):
		return
	var status_block := hud.get_node("Margin") as Control
	panel.call(&"close")
	TestAssertions.truthy(not bool(panel.call(&"is_open")), "close hides run setup", failures)
	status_block.visible = true
	panel.call(&"open")
	TestAssertions.truthy(bool(panel.call(&"is_open")), "open reveals run setup", failures)
	TestAssertions.truthy(not status_block.visible, "open hides the run HUD status block", failures)
	var grid := panel.get_node("Content/Scroll/Grid") as GridContainer
	var first_class := grid.get_child(0) as Button
	TestAssertions.equal(panel.get("_pending_initial_focus"), first_class, "open selects the first eligible class before tree entry", failures)
	first_class.disabled = true
	panel.call(&"close")
	panel.call(&"open")
	TestAssertions.equal(panel.get("_pending_initial_focus"), grid.get_child(1), "open skips an ineligible initial class", failures)
	first_class.disabled = false
	panel.call(&"close")
	TestAssertions.truthy(not bool(panel.call(&"is_open")), "close is reusable after open", failures)
	TestAssertions.equal(panel.get("_pending_initial_focus"), null, "close clears pending run-setup focus", failures)
	TestAssertions.truthy(not status_block.visible, "close does not falsely reveal the run HUD", failures)
	panel.call(&"open")
	(grid.get_child(0) as Button).pressed.emit()
	TestAssertions.truthy(not status_block.visible, "a class selection attempt does not reveal the run HUD", failures)
	TestAssertions.truthy(bool(panel.call(&"is_open")), "a class selection attempt does not own run-setup closure", failures)
	if panel.has_method(&"confirm_run_started"):
		panel.call(&"confirm_run_started")
		TestAssertions.truthy(not bool(panel.call(&"is_open")), "confirmed run start closes run setup", failures)
		TestAssertions.truthy(status_block.visible, "confirmed run start reveals the run HUD status block", failures)


func _test_back_intent_is_side_effect_free(panel: Control, hud: CanvasLayer, failures: Array[String]) -> void:
	var back := panel.get_node_or_null("Content/Actions/Back") as Button
	if back == null or not panel.has_signal(&"back_requested") or not panel.has_method(&"open"):
		return
	var status_block := hud.get_node("Margin") as Control
	var back_requests: Array[int] = [0]
	panel.connect(&"back_requested", func() -> void: back_requests[0] += 1)
	panel.call(&"open")
	back.pressed.emit()
	TestAssertions.equal(back_requests[0], 1, "Back button emits one request", failures)
	TestAssertions.truthy(bool(panel.call(&"is_open")), "Back intent leaves lifecycle ownership to composition", failures)
	TestAssertions.truthy(not status_block.visible, "Back intent does not reveal or start the run HUD", failures)
	panel.call(&"_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.equal(back_requests[0], 2, "ui_cancel emits the same Back intent", failures)
	TestAssertions.truthy(bool(panel.call(&"is_open")), "ui_cancel does not mutate run setup before composition handles Back", failures)
	TestAssertions.truthy(not status_block.visible, "ui_cancel does not mutate run HUD visibility", failures)


func _test_focus_wiring(panel: Control, failures: Array[String]) -> void:
	var grid := panel.get_node("Content/Scroll/Grid") as GridContainer
	var settings := panel.get_node("Content/Actions/Settings") as Button
	var back := panel.get_node_or_null("Content/Actions/Back") as Button
	if back == null:
		return
	var controls: Array[Button] = []
	for child: Node in grid.get_children():
		controls.append(child as Button)
	controls.append(settings)
	controls.append(back)
	for index: int in range(controls.size()):
		var current := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var previous := controls[posmod(index - 1, controls.size())]
		TestAssertions.equal(current.focus_mode, Control.FOCUS_ALL, "%s accepts mouse, keyboard, and controller focus" % current.name, failures)
		TestAssertions.equal(current.focus_next, current.get_path_to(next), "%s has explicit keyboard-forward focus" % current.name, failures)
		TestAssertions.equal(current.focus_previous, current.get_path_to(previous), "%s has explicit keyboard-backward focus" % current.name, failures)
	var class_1 := controls[0]
	var class_2 := controls[1]
	var class_5 := controls[4]
	var class_7 := controls[6]
	var class_8 := controls[7]
	var class_9 := controls[8]
	TestAssertions.equal(class_1.focus_neighbor_right, class_1.get_path_to(class_2), "first class moves right within the grid", failures)
	TestAssertions.equal(class_2.focus_neighbor_bottom, class_2.get_path_to(class_5), "class grid moves down by one row", failures)
	TestAssertions.equal(class_7.focus_neighbor_bottom, class_7.get_path_to(settings), "left bottom class reaches Settings", failures)
	TestAssertions.equal(class_8.focus_neighbor_bottom, class_8.get_path_to(settings), "middle bottom class reaches Settings", failures)
	TestAssertions.equal(class_9.focus_neighbor_bottom, class_9.get_path_to(back), "right bottom class reaches Back", failures)
	TestAssertions.equal(settings.focus_neighbor_top, settings.get_path_to(class_8), "Settings returns to the class grid", failures)
	TestAssertions.equal(settings.focus_neighbor_right, settings.get_path_to(back), "Settings moves right to Back", failures)
	TestAssertions.equal(back.focus_neighbor_top, back.get_path_to(class_9), "Back returns to the class grid", failures)
	TestAssertions.equal(back.focus_neighbor_left, back.get_path_to(settings), "Back moves left to Settings", failures)


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
