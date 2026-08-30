extends SceneTree

const DIALOG_SCENE := preload("res://scenes/ui/warehouse/warehouse_locked_dialog.tscn")
const MAX_WAIT_FRAMES := 30
const CITY_TREE_AVAILABLE := 0
const PROLOGUE_REQUIRED := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var return_focus := Button.new()
	return_focus.name = "WarehouseOrigin"
	return_focus.text = "Warehouse"
	viewport.add_child(return_focus)
	var dialog := DIALOG_SCENE.instantiate() as Node
	dialog.custom_viewport = viewport
	viewport.add_child(dialog)
	await _wait_for_mount(dialog, return_focus, viewport)

	if _failures.is_empty():
		dialog.call("open", CITY_TREE_AVAILABLE, return_focus)
		await _expect_focus(viewport, _city_tree(dialog), "CITY_TREE_AVAILABLE focuses View City Tree")
		dialog.call("open", PROLOGUE_REQUIRED, return_focus)
		await _expect_focus(viewport, _back(dialog), "PROLOGUE_REQUIRED focuses Back")

		dialog.call("open", PROLOGUE_REQUIRED, return_focus)
		await _expect_focus(viewport, _back(dialog), "Escape fixture starts with Back focus")
		await _send_cancel(viewport)
		_assert(not bool(dialog.call("is_open")), "ui_cancel closes Warehouse guidance")
		await _expect_focus(viewport, return_focus, "ui_cancel restores the exact Warehouse origin")

		var city_tree_requests: Array[Control] = []
		dialog.connect("city_tree_requested", func(origin: Control) -> void: city_tree_requests.append(origin))
		dialog.call("open", PROLOGUE_REQUIRED, return_focus)
		await _expect_focus(viewport, _back(dialog), "Back fixture starts with Back focus")
		_back(dialog).pressed.emit()
		_assert(not bool(dialog.call("is_open")), "Back closes Warehouse guidance")
		await _expect_focus(viewport, return_focus, "Back restores the exact Warehouse origin")
		_assert(city_tree_requests.is_empty(), "Back emits no City tree request")

		dialog.call("open", CITY_TREE_AVAILABLE, return_focus)
		await _expect_focus(viewport, _city_tree(dialog), "CTA fixture starts with City tree focus")
		_city_tree(dialog).pressed.emit()
		_assert(not bool(dialog.call("is_open")), "City tree CTA closes guidance before handoff")
		_assert(city_tree_requests == [return_focus], "City tree CTA emits the exact Warehouse origin")
		_assert(viewport.gui_get_focus_owner() != return_focus, "City tree CTA does not restore Warehouse focus before handoff")

	dialog.free()
	return_focus.free()
	viewport.free()
	if _failures.is_empty():
		print("WAREHOUSE_LOCKED_DIALOG_FOCUS_SUMMARY: PASS (0 failures)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("WAREHOUSE_LOCKED_DIALOG_FOCUS_FAILURE: %s" % failure)
	print("WAREHOUSE_LOCKED_DIALOG_FOCUS_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _wait_for_mount(dialog: Node, return_focus: Control, viewport: SubViewport) -> void:
	for _frame: int in MAX_WAIT_FRAMES:
		if dialog.is_inside_tree() and return_focus.is_inside_tree() and dialog.get_viewport() == viewport:
			return
		await process_frame
	_assert(false, "dialog and return focus mount in the configured SubViewport")


func _expect_focus(viewport: SubViewport, expected: Control, label: String) -> void:
	for _frame: int in MAX_WAIT_FRAMES:
		if viewport.gui_get_focus_owner() == expected:
			return
		await process_frame
	var actual := viewport.gui_get_focus_owner()
	_failures.append("%s expected=%s actual=%s" % [label, expected.get_path() if expected != null else NodePath(), actual.get_path() if actual != null else NodePath()])


func _send_cancel(viewport: SubViewport) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	viewport.push_input(event)
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _city_tree(dialog: Node) -> Button: return dialog.get_node("Overlay/Frame/Layout/Actions/ViewCityTree") as Button
func _back(dialog: Node) -> Button: return dialog.get_node("Overlay/Frame/Layout/Actions/Back") as Button
