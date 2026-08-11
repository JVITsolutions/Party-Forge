extends SceneTree

const DOCUMENT_PATH := "user://developer_item_sandbox/sandbox.json"
const SANDBOX_ROOT := "user://developer_item_sandbox"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_cleanup_sandbox_files()
	root.size = Vector2i(1920, 1080)
	var packed := load("res://scenes/ui/developer_item_sandbox.tscn") as PackedScene
	_assert(packed != null, "sandbox scene loads")
	if packed == null:
		_finish()
		return
	var sandbox := packed.instantiate() as DeveloperItemSandbox
	root.add_child(sandbox)
	await _frames(2)
	_assert(sandbox.open(), "sandbox opens in the real tree")
	await _frames(2)
	var stash := sandbox.get_node("Overlay/Frame/Layout/Tabs/Equipment/Body/StashPanel/StashScroll/StashSlots") as GridContainer
	var source := stash.get_child(0) as Button
	var stale_destination := stash.get_child(99) as Button
	var save := sandbox.get_node("Overlay/Frame/Layout/Tabs/Equipment/Actions/Save") as Button
	var integrity_scan := sandbox.get_node("Overlay/Frame/Layout/Tabs/Fixtures/Actions/IntegrityScan") as Button
	var reset := sandbox.get_node("Overlay/Frame/Layout/Tabs/Fixtures/Actions/Reset") as Button
	var tabs := sandbox.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var close_button := sandbox.get_node("Overlay/Frame/Layout/Header/Close") as Button
	for target: Control in [save, close_button]:
		await _assert_accept_ignores_stale_slot(sandbox, source, stale_destination, target)
		reset.pressed.emit()
		await _frames(2)
	for target: Control in [save, close_button]:
		await _assert_pickup_ignores_stale_slot(sandbox, source, target)
	_assert_focus_reachable(source, save)
	_assert_focus_reachable(source, close_button)
	tabs.current_tab = 0
	await _frames(2)
	_assert(source.focus_mode == Control.FOCUS_NONE, "equipment slots leave the focus graph on Fixtures")
	_assert(integrity_scan.focus_mode == Control.FOCUS_ALL and reset.focus_mode == Control.FOCUS_ALL, "fixture actions enter the visible focus graph")
	_assert_focus_reachable(integrity_scan, reset)
	_assert_focus_reachable(integrity_scan, close_button)
	tabs.current_tab = 2
	await _frames(2)
	var loot_anchor := sandbox.get_node("Overlay/Frame/Layout/Tabs/Loot Lab/Layout/Header/WorkbenchFocusAnchor") as Button
	_assert(integrity_scan.focus_mode == Control.FOCUS_NONE, "fixture actions leave the focus graph on Loot Lab")
	_assert(loot_anchor.focus_mode == Control.FOCUS_ALL, "Loot Lab anchor enters the visible focus graph")
	_assert_focus_reachable(loot_anchor, close_button)
	sandbox.queue_free()
	await process_frame
	_cleanup_sandbox_files()
	_finish()


func _assert_accept_ignores_stale_slot(sandbox: DeveloperItemSandbox, source: Button, stale_destination: Button, target: Control) -> void:
	source.grab_focus()
	await process_frame
	_assert(root.gui_get_focus_owner() == source, "%s accept fixture starts on the actual populated source" % target.name)
	await _joy_button(JOY_BUTTON_X)
	_assert(sandbox.is_holding_item(), "west face holds the actual source before focusing %s" % target.name)
	stale_destination.grab_focus()
	await process_frame
	_assert(root.gui_get_focus_owner() == stale_destination, "%s accept fixture visits the stale empty destination" % target.name)
	target.grab_focus()
	await process_frame
	_assert(root.gui_get_focus_owner() == target, "%s becomes the actual non-slot focus owner" % target.name)
	var before_projection := sandbox.projection()
	var before_bytes := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	await _joy_button(JOY_BUTTON_A)
	_assert(sandbox.projection() == before_projection, "south face on actual %s focus cannot transfer to stale slot" % target.name)
	_assert(FileAccess.get_file_as_bytes(DOCUMENT_PATH) == before_bytes, "south face on actual %s focus preserves sandbox bytes" % target.name)
	_assert(not sandbox.is_holding_item(), "south face on actual %s focus safely clears held mode" % target.name)


func _assert_pickup_ignores_stale_slot(sandbox: DeveloperItemSandbox, source: Button, target: Control) -> void:
	source.grab_focus()
	await process_frame
	_assert(root.gui_get_focus_owner() == source, "%s pickup fixture visits the actual populated source" % target.name)
	target.grab_focus()
	await process_frame
	_assert(root.gui_get_focus_owner() == target, "%s remains the actual non-slot focus owner" % target.name)
	var before_projection := sandbox.projection()
	var before_bytes := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	await _joy_button(JOY_BUTTON_X)
	_assert(not sandbox.is_holding_item(), "west face on actual %s focus cannot pick up stale slot" % target.name)
	_assert(sandbox.projection() == before_projection, "west face on actual %s focus preserves state" % target.name)
	_assert(FileAccess.get_file_as_bytes(DOCUMENT_PATH) == before_bytes, "west face on actual %s focus preserves sandbox bytes" % target.name)


func _assert_focus_reachable(source: Control, target: Control) -> void:
	var current := source
	for _step: int in 120:
		if current == target:
			_assert(true, "%s remains reachable through the closed focus graph" % target.name)
			return
		var next_path := current.focus_next
		current = current.get_node_or_null(next_path) as Control if not next_path.is_empty() else null
		if current == null:
			break
	_assert(false, "%s remains reachable through the closed focus graph" % target.name)


func _joy_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure: String in _failures:
		push_error("TASK9_SANDBOX_FOCUS_FAILURE: %s" % failure)
	print("TASK9_SANDBOX_FOCUS_SUMMARY: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _cleanup_sandbox_files() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.previous"]:
		var path := "%s%s" % [DOCUMENT_PATH, suffix]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var absolute_root := ProjectSettings.globalize_path(SANDBOX_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)
