extends RefCounted

const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu/main_menu_screen.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(MAIN_MENU_SCENE_PATH), "Main-menu scene exists", failures)
	if not ResourceLoader.exists(MAIN_MENU_SCENE_PATH):
		return failures
	var packed := load(MAIN_MENU_SCENE_PATH) as PackedScene
	TestAssertions.truthy(packed != null, "Main-menu scene loads", failures)
	if packed == null:
		return failures
	var screen := packed.instantiate() as CanvasLayer
	TestAssertions.truthy(screen != null, "Main-menu scene instantiates its screen contract", failures)
	if screen == null:
		return failures
	screen.call(&"_ready")
	_test_scene_contract(screen, failures)
	_test_projection_and_lifecycle(screen, failures)
	_test_action_signals_and_cancel(screen, failures)
	_test_focus_loop(screen, failures)
	screen.free()
	return failures


func _test_scene_contract(screen: CanvasLayer, failures: Array[String]) -> void:
	TestAssertions.truthy(screen is CanvasLayer, "Main menu is a full-screen CanvasLayer", failures)
	for method: StringName in [&"present", &"open", &"close", &"is_open", &"projection"]:
		TestAssertions.truthy(screen.has_method(method), "Main menu exposes %s lifecycle contract" % method, failures)
	for path: String in [
		"Backdrop",
		"Title",
		"ActiveProfile",
		"PrimaryAction",
		"CityTree",
		"DeveloperQuickStart",
		"Settings",
		"Quit",
		"Status",
	]:
		TestAssertions.truthy(screen.get_node_or_null(path) != null, "Main menu keeps stable %s path" % path, failures)
	var backdrop := screen.get_node_or_null("Backdrop") as Control
	if backdrop != null:
		TestAssertions.equal(backdrop.anchors_preset, Control.PRESET_FULL_RECT, "Backdrop fills the viewport", failures)
		TestAssertions.equal(backdrop.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Presentation backdrop never consumes menu input", failures)
		TestAssertions.truthy(not _has_button_descendant(backdrop), "Backdrop subtree is presentation-only", failures)
	TestAssertions.truthy(screen.has_signal(&"route_requested"), "Main menu exposes route intents", failures)
	TestAssertions.truthy(screen.has_signal(&"cancel_requested"), "Main menu exposes a cancel intent", failures)


func _test_projection_and_lifecycle(screen: CanvasLayer, failures: Array[String]) -> void:
	var projection := MainMenuViewModel.build(null, PartyForgeSettings.new(), true)
	screen.call(&"present", projection)
	projection.primary_label = "Mutated outside"
	TestAssertions.equal((screen.get_node("PrimaryAction") as Button).text, "Play", "Presentation takes an owned projection copy", failures)
	var returned := screen.call(&"projection") as MainMenuProjection
	returned.settings_label = "Mutated copy"
	TestAssertions.equal((screen.call(&"projection") as MainMenuProjection).settings_label, "Settings", "Projection access returns a defensive copy", failures)
	TestAssertions.equal(_visible_action_names(screen), [&"PrimaryAction", &"Settings", &"Quit"], "First launch shows exactly Play, Settings, and Quit", failures)
	TestAssertions.equal((screen.get_node("ActiveProfile") as Label).text, "No active profile", "Active-profile copy is rendered", failures)
	TestAssertions.equal((screen.get_node("Status") as Label).text, "Create or choose a profile to play.", "Player-facing status copy is rendered", failures)
	TestAssertions.truthy(not bool(screen.call(&"is_open")), "Main menu starts closed", failures)
	screen.call(&"open")
	TestAssertions.truthy(bool(screen.call(&"is_open")), "Open reveals the main menu", failures)
	TestAssertions.equal((screen.get_node("PrimaryAction") as Button).focus_mode, Control.FOCUS_ALL, "Open exposes an immediately input-ready primary action", failures)
	screen.call(&"close")
	TestAssertions.truthy(not bool(screen.call(&"is_open")), "Close hides the main menu", failures)
	TestAssertions.equal(screen.get("_pending_preferred_focus"), null, "Close clears pending menu focus", failures)

	projection = MainMenuViewModel.build(null, PartyForgeSettings.new(), true)
	projection.reduced_motion = true
	screen.call(&"present", projection)
	screen.call(&"open", screen.get_node("Settings") as Control)
	TestAssertions.equal(screen.get("_pending_preferred_focus"), screen.get_node("Settings"), "Reduced motion records preferred focus without delay before tree entry", failures)
	TestAssertions.truthy((screen.get_node("ActiveProfile") as Control).accessibility_description.contains("No active profile"), "Active profile exposes accessible copy", failures)
	TestAssertions.truthy((screen.get_node("CityTree") as Control).accessibility_description.contains("City"), "City-tree control has an accessible description", failures)
	TestAssertions.truthy((screen.get_node("DeveloperQuickStart") as Control).accessibility_description.contains("Developer"), "Developer-only control is explicitly described", failures)
	screen.call(&"close")


func _test_action_signals_and_cancel(screen: CanvasLayer, failures: Array[String]) -> void:
	var projection := _all_actions_projection()
	screen.call(&"present", projection)
	screen.call(&"open")
	var routes: Array[StringName] = []
	var cancel_count: Array[int] = [0]
	screen.connect(&"route_requested", func(route_id: StringName) -> void: routes.append(route_id))
	screen.connect(&"cancel_requested", func() -> void: cancel_count[0] += 1)
	for action_name: StringName in [&"PrimaryAction", &"CityTree", &"DeveloperQuickStart", &"Settings", &"Quit"]:
		(screen.get_node(NodePath(action_name)) as Button).pressed.emit()
	TestAssertions.equal(routes, [
		&"prologue_start",
		&"city_tree",
		&"developer_quick_start",
		&"settings",
		&"quit",
	], "Mouse/accept activation emits each stable route intent", failures)
	screen.call(&"_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.equal(cancel_count[0], 1, "Cancel emits an intent for the composition root", failures)
	TestAssertions.truthy(bool(screen.call(&"is_open")), "Cancel does not close or quit from inside the screen", failures)
	screen.call(&"close")


func _test_focus_loop(screen: CanvasLayer, failures: Array[String]) -> void:
	var projection := _all_actions_projection()
	projection.developer_quick_start_enabled = false
	screen.call(&"present", projection)
	var expected: Array[Button] = [
		screen.get_node("PrimaryAction") as Button,
		screen.get_node("CityTree") as Button,
		screen.get_node("Settings") as Button,
		screen.get_node("Quit") as Button,
	]
	for index: int in range(expected.size()):
		var current := expected[index]
		var next := expected[(index + 1) % expected.size()]
		var previous := expected[posmod(index - 1, expected.size())]
		TestAssertions.equal(current.focus_next, current.get_path_to(next), "%s loops forward through available actions" % current.name, failures)
		TestAssertions.equal(current.focus_previous, current.get_path_to(previous), "%s loops backward through available actions" % current.name, failures)
		TestAssertions.equal(current.focus_neighbor_bottom, current.get_path_to(next), "%s maps controller down to the next action" % current.name, failures)
		TestAssertions.equal(current.focus_neighbor_top, current.get_path_to(previous), "%s maps controller up to the previous action" % current.name, failures)
	var unavailable := screen.get_node("DeveloperQuickStart") as Button
	TestAssertions.truthy(unavailable.visible and unavailable.disabled, "Unavailable visible action remains explanatory but disabled", failures)
	TestAssertions.equal(unavailable.focus_mode, Control.FOCUS_NONE, "Disabled action is excluded from focus traversal", failures)
	TestAssertions.truthy(not bool(screen.call(&"_is_available_action", unavailable)), "Unavailable action cannot become preferred focus", failures)
	TestAssertions.equal(screen.call(&"_first_available_action"), expected[0], "Unavailable preferred focus falls back to the first action", failures)
	screen.call(&"open", unavailable)
	screen.call(&"close")


func _all_actions_projection() -> MainMenuProjection:
	var result := MainMenuProjection.new()
	result.primary_label = "Play"
	result.primary_visible = true
	result.primary_enabled = true
	result.primary_route_id = &"prologue_start"
	result.city_tree_label = "City Passive Tree"
	result.city_tree_visible = true
	result.city_tree_enabled = true
	result.city_tree_route_id = &"city_tree"
	result.developer_quick_start_label = "Developer Quick Start"
	result.developer_quick_start_visible = true
	result.developer_quick_start_enabled = true
	result.developer_quick_start_route_id = &"developer_quick_start"
	result.settings_label = "Settings"
	result.settings_visible = true
	result.settings_enabled = true
	result.settings_route_id = &"settings"
	result.quit_label = "Quit"
	result.quit_visible = true
	result.quit_enabled = true
	result.quit_route_id = &"quit"
	result.active_profile_text = "Active Profile: Menu Tester"
	result.status_text = "Ready."
	return result


func _visible_action_names(screen: CanvasLayer) -> Array[StringName]:
	var result: Array[StringName] = []
	for action_name: StringName in [&"PrimaryAction", &"CityTree", &"DeveloperQuickStart", &"Settings", &"Quit"]:
		var button := screen.get_node(NodePath(action_name)) as Button
		if button.visible:
			result.append(action_name)
	return result


func _has_button_descendant(root: Node) -> bool:
	for child: Node in root.get_children():
		if child is Button or _has_button_descendant(child):
			return true
	return false


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
