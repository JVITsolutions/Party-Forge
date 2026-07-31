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
	hud.free()
	return failures
