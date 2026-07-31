extends RefCounted

const CONTROLS_SCENE_PATH := "res://scenes/ui/settings/controls_settings_page.tscn"
const SETTINGS_SCENE_PATH := "res://scenes/ui/settings/settings_screen.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_formatter(failures)
	_test_controls_page(failures)
	_test_settings_integration(failures)
	return failures


func _test_formatter(failures: Array[String]) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	TestAssertions.equal(InputBindingFormatter.event_text(key), key.as_text(), "key uses engine text", failures)

	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	TestAssertions.equal(InputBindingFormatter.event_text(mouse), "Mouse 1", "mouse uses stable button index", failures)

	var button := InputEventJoypadButton.new()
	button.button_index = 0
	TestAssertions.equal(InputBindingFormatter.event_text(button), button.as_text(), "joypad button uses engine text", failures)

	var axis := InputEventJoypadMotion.new()
	axis.axis = 0
	axis.axis_value = 1.0
	TestAssertions.equal(InputBindingFormatter.event_text(axis), "%s +/-" % axis.as_text(), "joypad axis shows both directions", failures)

	var duplicate_keys: Array[InputEvent] = [key, key.duplicate() as InputEvent]
	TestAssertions.equal(InputBindingFormatter.events_for_device(duplicate_keys, false), key.as_text(), "device formatter deduplicates bindings", failures)
	TestAssertions.equal(InputBindingFormatter.events_for_device(duplicate_keys, true), "Missing binding", "device formatter filters keyboard from controller", failures)

	var missing_action := &"task_4_missing_binding"
	if InputMap.has_action(missing_action):
		InputMap.erase_action(missing_action)
	InputMap.add_action(missing_action)
	TestAssertions.equal(InputBindingFormatter.events_for_device(InputMap.action_get_events(missing_action), false), "Missing binding", "action with no events reports missing binding", failures)
	InputMap.erase_action(missing_action)


func _test_controls_page(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(CONTROLS_SCENE_PATH), "Controls page scene exists", failures)
	if not ResourceLoader.exists(CONTROLS_SCENE_PATH):
		return
	var packed := load(CONTROLS_SCENE_PATH) as PackedScene
	TestAssertions.truthy(packed != null, "Controls page scene loads", failures)
	if packed == null:
		return
	var page := packed.instantiate() as ControlsSettingsPage
	TestAssertions.truthy(page != null, "Controls page has its typed script", failures)
	if page == null:
		return
	page.refresh_bindings()

	TestAssertions.truthy(page.get_node_or_null("Layout/Scroll/Groups") is VBoxContainer, "Controls page is scrollable", failures)
	for section: String in ["Gameplay", "Menus", "Character Ledger"]:
		var section_node := page.get_node_or_null("Layout/Scroll/Groups/Group_%s" % section.to_snake_case())
		TestAssertions.truthy(section_node != null, "Controls contains %s section" % section, failures)
		if section_node != null:
			TestAssertions.equal((section_node.get_node("Heading") as Label).text, section, "%s section has stable heading" % section, failures)
	TestAssertions.equal((page.get_node("Layout/Footer") as Label).text, "Rebinding: Coming Soon", "Controls states rebinding boundary", failures)

	for action_id: StringName in [&"move_left", &"pause_menu", &"character_ledger", &"settings_previous_tab", &"settings_next_tab"]:
		var row := page.row_for(action_id)
		TestAssertions.truthy(not row.is_empty(), "Controls lists %s" % action_id, failures)
		if row.is_empty():
			continue
		TestAssertions.equal(row.get("action_id"), action_id, "%s row exposes action ID" % action_id, failures)
		TestAssertions.equal(String(row.get("keyboard_text")), InputBindingFormatter.events_for_device(InputMap.action_get_events(action_id), false), "%s keyboard text comes from InputMap" % action_id, failures)
		TestAssertions.equal(String(row.get("controller_text")), InputBindingFormatter.events_for_device(InputMap.action_get_events(action_id), true), "%s controller text comes from InputMap" % action_id, failures)
		TestAssertions.truthy(row.has("missing_binding"), "%s row exposes missing state" % action_id, failures)

	var move_row := page.row_for(&"move_left")
	TestAssertions.truthy(bool(move_row.get("missing_binding", false)), "Move Left records its missing controller binding", failures)
	var move_controller := page.get_node("Layout/Scroll/Groups/Group_gameplay/Rows/Row_move_left/Controller") as Label
	TestAssertions.equal(move_controller.text, "Missing binding", "Missing controller side is visible", failures)
	TestAssertions.truthy(not move_controller.tooltip_text.is_empty(), "Missing controller side has warning tooltip", failures)
	move_row["keyboard_text"] = "Changed by caller"
	TestAssertions.truthy(String(page.row_for(&"move_left").get("keyboard_text")) != "Changed by caller", "row_for returns isolated metadata", failures)
	page.free()


func _test_settings_integration(failures: Array[String]) -> void:
	var packed := load(SETTINGS_SCENE_PATH) as PackedScene
	var screen := packed.instantiate()
	var controls := screen.get_node_or_null("Overlay/Frame/Layout/Tabs/Controls")
	TestAssertions.truthy(controls is ControlsSettingsPage, "Settings uses the InputMap Controls page", failures)
	screen.free()
