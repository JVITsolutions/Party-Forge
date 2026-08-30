extends RefCounted

const SCRIPT_PATH := "res://scripts/ui/warehouse/warehouse_locked_dialog.gd"
const SCENE_PATH := "res://scenes/ui/warehouse/warehouse_locked_dialog.tscn"
const CITY_TREE_AVAILABLE := 0
const PROLOGUE_REQUIRED := 1
const TEMPORARILY_UNAVAILABLE := 2


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(SCRIPT_PATH), "warehouse locked dialog script exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(SCENE_PATH), "warehouse locked dialog scene exists", failures)
	if not failures.is_empty():
		return failures
	var dialog := (load(SCENE_PATH) as PackedScene).instantiate() as Node
	var return_focus := Button.new()
	return_focus.text = "Warehouse"
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 600)
	tree.root.add_child(viewport)
	viewport.add_child(return_focus)
	viewport.add_child(dialog)
	dialog.call("_ready")
	TestAssertions.equal((dialog.get_script() as Script).resource_path, SCRIPT_PATH, "warehouse scene uses its standalone presentation controller", failures)
	for signal_name: StringName in [&"city_tree_requested", &"closed"]:
		TestAssertions.truthy(dialog.has_signal(signal_name), "warehouse dialog exposes %s", failures)
	for method_name: StringName in [&"open", &"close", &"is_open"]:
		TestAssertions.truthy(dialog.has_method(method_name), "warehouse dialog exposes %s", failures)
	_test_guidance_copy_and_focus(dialog, return_focus, failures)
	_test_close_paths_restore_exact_origin(dialog, return_focus, failures)
	_test_city_tree_intent_preserves_exact_origin(dialog, return_focus, failures)
	_test_presentation_has_no_policy_dependencies(failures)
	viewport.free()
	return failures


func _test_guidance_copy_and_focus(dialog: Node, return_focus: Control, failures: Array[String]) -> void:
	TestAssertions.truthy(bool(dialog.call("open", CITY_TREE_AVAILABLE, return_focus)), "available guidance opens", failures)
	TestAssertions.equal(_title(dialog).text, "WAREHOUSE LOCKED", "available guidance title", failures)
	TestAssertions.equal(_requirement(dialog).text, "Requires Stash Access", "available guidance requirement", failures)
	TestAssertions.equal(_body(dialog).text, "Unlock Stash Access in the City tree to open permanent storage.", "available guidance body", failures)
	TestAssertions.truthy(_city_tree(dialog).visible and not _city_tree(dialog).disabled, "available guidance exposes City tree CTA", failures)
	_assert_initial_focus(dialog, _city_tree(dialog), "available guidance initially focuses City tree CTA", failures)
	_assert_focus_loop([_city_tree(dialog), _back(dialog)], failures)

	dialog.call("open", PROLOGUE_REQUIRED, return_focus)
	TestAssertions.equal(_body(dialog).text, "Complete the prologue to access the City tree. Then unlock Stash Access to open the Warehouse.", "prologue guidance body", failures)
	TestAssertions.truthy(not _city_tree(dialog).visible and _back(dialog).visible, "prologue guidance withholds dead CTA", failures)
	_assert_initial_focus(dialog, _back(dialog), "prologue guidance initially focuses Back", failures)
	_assert_focus_loop([_back(dialog)], failures)

	dialog.call("open", TEMPORARILY_UNAVAILABLE, return_focus)
	TestAssertions.equal(_body(dialog).text, "City services are temporarily unavailable. Try again later.", "runtime failure is not mislabeled as progression", failures)
	TestAssertions.truthy(not _city_tree(dialog).visible and _back(dialog).visible, "temporarily unavailable withholds progression CTA", failures)
	_assert_initial_focus(dialog, _back(dialog), "temporarily unavailable initially focuses Back", failures)
	_assert_focus_loop([_back(dialog)], failures)


func _test_close_paths_restore_exact_origin(dialog: Node, return_focus: Control, failures: Array[String]) -> void:
	dialog.call("open", PROLOGUE_REQUIRED, return_focus)
	TestAssertions.equal(dialog.get("_return_focus"), return_focus, "Escape retains the exact Warehouse origin before restoration", failures)
	var city_tree_count: Array[int] = [0]
	dialog.connect("city_tree_requested", func(_origin: Control) -> void: city_tree_count[0] += 1, CONNECT_ONE_SHOT)
	dialog.call("_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(not dialog.is_open(), "Escape closes locked guidance", failures)
	_assert_restored_focus(dialog, return_focus, "Escape restores the exact Warehouse origin", failures)
	TestAssertions.equal(city_tree_count[0], 0, "Escape emits no City tree intent", failures)

	dialog.call("open", PROLOGUE_REQUIRED, return_focus)
	TestAssertions.equal(dialog.get("_return_focus"), return_focus, "Back retains the exact Warehouse origin before restoration", failures)
	(_back(dialog) as Button).pressed.emit()
	TestAssertions.truthy(not dialog.is_open(), "Back closes locked guidance", failures)
	_assert_restored_focus(dialog, return_focus, "Back restores the exact Warehouse origin", failures)
	TestAssertions.equal(city_tree_count[0], 0, "Back emits no City tree intent", failures)


func _test_city_tree_intent_preserves_exact_origin(dialog: Node, return_focus: Control, failures: Array[String]) -> void:
	dialog.call("open", CITY_TREE_AVAILABLE, return_focus)
	var requested_origins: Array[Control] = []
	dialog.connect("city_tree_requested", func(origin: Control) -> void: requested_origins.append(origin), CONNECT_ONE_SHOT)
	_city_tree(dialog).pressed.emit()
	TestAssertions.truthy(not dialog.is_open(), "City tree CTA closes guidance before handoff", failures)
	TestAssertions.equal(requested_origins, [return_focus], "City tree CTA emits the exact Warehouse origin once", failures)


func _test_presentation_has_no_policy_dependencies(failures: Array[String]) -> void:
	var source := FileAccess.get_file_as_string(SCRIPT_PATH).to_lower()
	TestAssertions.truthy(not source.contains("profile") and not source.contains("settings"), "warehouse guidance stays free of profile and settings dependencies", failures)


func _assert_focus_loop(controls: Array[Control], failures: Array[String]) -> void:
	for index: int in controls.size():
		var current := controls[index]
		var expected_next := controls[(index + 1) % controls.size()]
		var expected_previous := controls[posmod(index - 1, controls.size())]
		TestAssertions.equal(current.get_node(current.focus_next), expected_next, "%s has deterministic next focus" % current.name, failures)
		TestAssertions.equal(current.get_node(current.focus_previous), expected_previous, "%s has deterministic previous focus" % current.name, failures)


func _assert_initial_focus(dialog: Node, expected: Control, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(dialog.call("_initial_focus"), expected, "%s target is deterministic in the headless runner" % label, failures)


func _assert_restored_focus(dialog: Node, expected: Control, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(dialog.get("_return_focus"), null, "%s consumes the exact retained origin in the headless runner" % label, failures)


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _title(dialog: Node) -> Label: return dialog.get_node("Overlay/Frame/Layout/Title") as Label
func _requirement(dialog: Node) -> Label: return dialog.get_node("Overlay/Frame/Layout/Requirement") as Label
func _body(dialog: Node) -> Label: return dialog.get_node("Overlay/Frame/Layout/Body") as Label
func _city_tree(dialog: Node) -> Button: return dialog.get_node("Overlay/Frame/Layout/Actions/ViewCityTree") as Button
func _back(dialog: Node) -> Button: return dialog.get_node("Overlay/Frame/Layout/Actions/Back") as Button
