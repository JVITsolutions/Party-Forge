extends RefCounted

const SETTINGS_SCENE_PATH := "res://scenes/ui/settings/settings_screen.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(SETTINGS_SCENE_PATH), "Settings scene exists", failures)
	if not ResourceLoader.exists(SETTINGS_SCENE_PATH):
		return failures
	var packed := load(SETTINGS_SCENE_PATH) as PackedScene
	TestAssertions.truthy(packed != null, "Settings scene loads", failures)
	if packed == null:
		return failures
	var screen := packed.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	var return_focus := Button.new()
	return_focus.name = "SettingsReturnFocus"

	var tabs := screen.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var expected := ["Game Settings", "Controls", "Graphics", "Audio", "Additional Settings"]
	var actual: Array[String] = []
	for index: int in range(tabs.get_tab_count()):
		actual.append(tabs.get_tab_title(index))
	TestAssertions.equal(actual, expected, "Settings tabs use approved order", failures)
	TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Game Settings/Content/State").text, "Coming Soon", "Game Settings is honest about availability", failures)
	TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Controls/Content/State").text, "Controls load from InputMap in Task 4", "Controls identifies its next task boundary", failures)
	TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Graphics/Content/State").text, "Coming Soon", "Graphics is honest about availability", failures)
	TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Audio/Content/State").text, "Coming Soon", "Audio is honest about availability", failures)
	TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Additional Settings/Content/State").text, "Developer controls are prepared in Task 5", "Additional Settings identifies its next task boundary", failures)
	TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/NextRunNotice").text, "Run-affecting changes apply when the next run starts.", "Settings shows the next-run notice", failures)
	TestAssertions.equal(screen.process_mode, Node.PROCESS_MODE_ALWAYS, "Settings processes while gameplay is paused", failures)
	TestAssertions.truthy(not bool(screen.call("is_open")), "Settings starts hidden", failures)
	TestAssertions.truthy(screen.has_signal("settings_applied"), "Settings exposes its applied signal", failures)

	var supplied := PartyForgeSettings.new()
	supplied.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	supplied.party_capacity_override = 12
	screen.call("configure", PartyForgeSettingsStore.new(), supplied)
	supplied.party_capacity_override = 2
	var draft := screen.call("current_settings") as PartyForgeSettings
	TestAssertions.equal(draft.party_capacity_override, 12, "Settings drafts a copy of supplied values", failures)
	draft.party_capacity_override = 3
	TestAssertions.equal((screen.call("current_settings") as PartyForgeSettings).party_capacity_override, 12, "Current settings returns an isolated copy", failures)

	screen.call("open", return_focus)
	TestAssertions.truthy(bool(screen.call("is_open")), "Settings opens modally", failures)
	TestAssertions.equal(screen.get("_return_focus"), return_focus, "Settings records the requested return focus", failures)
	screen.call("_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(not bool(screen.call("is_open")), "Cancel closes Settings", failures)
	TestAssertions.equal(screen.get("_return_focus"), null, "Closing Settings clears the handled return focus", failures)

	screen.free()
	return_focus.free()
	return failures


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
