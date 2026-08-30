extends SceneTree

const PANEL_SCENE := "res://scenes/ui/run_result/terminal_extraction_panel.tscn"
const CONTROLLER_PATH := "res://scripts/ui/run_result/terminal_extraction_selection_controller.gd"
const ITEM_TYPE_PATH := "res://scripts/ui/run_result/terminal_extraction_item_projection.gd"
const PROJECTION_TYPE_PATH := "res://scripts/ui/run_result/terminal_extraction_projection.gd"

var _failures: Array[String] = []
var _viewport: SubViewport
var _panel: Control
var _toggles: Array[String] = []
var _inspects: Array = []
var _confirms := 0
var _acks := 0
var _underlying_presses := 0

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var controller_type := load(CONTROLLER_PATH) as Script
	var item_type := load(ITEM_TYPE_PATH) as Script
	var projection_type := load(PROJECTION_TYPE_PATH) as Script
	var packed := load(PANEL_SCENE) as PackedScene
	if controller_type == null or item_type == null or projection_type == null or packed == null:
		_failures.append("Task 9 terminal extraction projection, controller, card, and panel contracts are missing")
		_finish()
		return
	_exercise_controller_flow(controller_type)
	await _exercise_real_panel_flow(packed, item_type, projection_type)
	_cleanup()
	_finish()

func _exercise_controller_flow(controller_type: Script) -> void:
	var controller: Variant = controller_type.new()
	controller.call(&"initialize", _policy(0, 3))
	_assert(controller.call(&"selected_item_ids").is_empty(), "capacity zero keeps all ordinary items explicit and unselected")
	_assert(not controller.call(&"needs_unused_capacity_acknowledgement"), "capacity zero has no unused-slot acknowledgement because no slot exists")
	controller.call(&"initialize", _policy(3, 3))
	_assert(controller.call(&"selected_item_ids") == ["item-01", "item-02", "item-03"], "all-fit selects all")
	controller.call(&"initialize", _policy(2, 3))
	_assert(controller.call(&"selected_item_ids").is_empty(), "constrained policy has no preselection")
	controller.call(&"toggle", "item-01")
	_assert(controller.call(&"needs_unused_capacity_acknowledgement"), "fewer-than-capacity loss requires second acknowledgement")
	controller.call(&"acknowledge_unused_capacity")
	_assert(not controller.call(&"needs_unused_capacity_acknowledgement"), "second acknowledgement is accepted")
	var changed: Array = controller.call(&"reconcile", RunExtractionProjection.create([], [ExtractionSelection.create("item-01", &"run-inventory", 0), ExtractionSelection.create("item-02", &"run-equipment-002", 7)], [], ["item-01", "item-02"], 2, []))
	_assert(changed.is_empty() and controller.call(&"selected_item_ids") == ["item-01"], "stale refresh retains exact still-valid selection")
	controller.call(&"set_pending", true)
	_assert(not controller.call(&"toggle", "item-02") and not controller.call(&"toggle", "item-02"), "pending duplicate clicks are blocked")

func _exercise_real_panel_flow(packed: PackedScene, item_type: Script, projection_type: Script) -> void:
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_viewport)
	var underlying := Button.new()
	underlying.name = "UnderlyingCombatControl"
	underlying.position = Vector2(40, 40)
	underlying.size = Vector2(220, 80)
	underlying.text = "Combat Status"
	underlying.pressed.connect(func() -> void: _underlying_presses += 1)
	_viewport.add_child(underlying)
	_panel = packed.instantiate() as Control
	_viewport.add_child(_panel)
	_panel.connect("item_toggle_requested", _on_toggle)
	_panel.connect("inspect_requested", _on_inspect)
	_panel.connect("confirm_requested", _on_confirm)
	_panel.connect("unused_capacity_acknowledged", _on_ack)
	var projection: Variant = _picker_projection(item_type, projection_type, 24, 2)
	_panel.call(&"present", projection)
	_panel.visible = true
	paused = true
	await process_frame
	await process_frame
	_assert(_panel.process_mode == Node.PROCESS_MODE_ALWAYS, "terminal root remains live while the tree is paused")
	_assert(_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "terminal root stops pointer input")
	await _click_mouse(underlying)
	_assert(_underlying_presses == 0, "terminal overlay blocks underlying combat pointer input")
	await _press_keyboard(KEY_ESCAPE)
	_assert(_panel.visible, "Cancel cannot close the terminal picker to combat")
	var grid := _panel.get_node("Frame/Content/Body/Eligible/Scroll/Grid") as Container
	_assert(grid.get_child_count() == 24, "eligible 24-item scroll grid is complete")
	var first := grid.get_child(0) as Button
	var second := grid.get_child(1) as Button
	var third := grid.get_child(2) as Button
	var last := grid.get_child(23) as Button
	first.grab_focus()
	await _press_keyboard(KEY_ENTER)
	_assert(_toggles == ["item-01"], "keyboard activation emits exact stable item ID")
	second.grab_focus()
	await _press_keyboard(KEY_SPACE)
	_assert(_toggles.size() == 2 and _toggles[-1] == "item-02", "Space activation emits exact stable item ID once")
	third.grab_focus()
	await _press_controller_accept()
	_assert(_toggles.size() == 3 and _toggles[-1] == "item-03", "controller activation emits exact stable item ID once")
	first.grab_focus()
	for _step: int in 23:
		await _press_keyboard(KEY_RIGHT)
	await process_frame
	await process_frame
	_assert(last.has_focus(), "D-pad traversal reaches item 24 through the explicit focus graph")
	var scroll := _panel.get_node("Frame/Content/Body/Eligible/Scroll") as ScrollContainer
	var viewport_rect := scroll.get_global_rect()
	var last_rect := last.get_global_rect()
	_assert(viewport_rect.encloses(last_rect), "focused item 24 is fully visible in the scroll viewport")
	await _press_keyboard(KEY_RIGHT)
	var confirm := _panel.get_node("Frame/Content/Actions/Confirm") as Button
	_assert(confirm.has_focus(), "focus traversal reaches the footer confirmation")
	await _press_keyboard(KEY_LEFT)
	_assert(last.has_focus(), "reverse focus traversal returns from the footer to item 24")
	await _click_mouse(last)
	_assert(_toggles.size() == 4 and _toggles[-1] == "item-24", "mouse activation reaches final stable item ID")
	first.call(&"request_inspect")
	await process_frame
	_assert(_inspects.size() == 1 and _inspects[0][0] == "item-01" and _inspects[0][1] == first, "detail intent preserves exact anchor")
	_panel.call(&"show_detail", projection.eligible_items[0], first)
	var detail_close := _panel.get_node("ItemTooltipDetail/Frame/Close") as Button
	detail_close.grab_focus()
	await _press_controller_cancel()
	_assert(first.has_focus(), "detail Cancel returns to the same item")
	confirm.grab_focus()
	await _press_controller_accept()
	_assert(_confirms == 1, "controller confirm emits once")
	_panel.call(&"set_pending", true)
	await _press_controller_accept()
	await _press_controller_accept()
	_assert(_confirms == 1, "pending duplicate confirmation input is blocked")
	_panel.call(&"set_pending", false)
	_panel.call(&"show_unused_capacity_warning", 1, 1, first)
	var acknowledge := _panel.get_node("UnusedCapacityWarning/Frame/Actions/Acknowledge") as Button
	acknowledge.grab_focus()
	await _press_keyboard(KEY_ENTER)
	_assert(_acks == 1 and first.has_focus(), "second acknowledgement emits and restores exact item focus")
	var automatic_only := RunResolutionPreflightResult.failure("internal", RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, "Automatic retained items need more destination space. Retry resolution after making space.")
	_panel.call(&"show_preflight", automatic_only)
	_assert(confirm.disabled, "automatic-only blockage disables confirmation")
	var reducible := RunResolutionPreflightResult.failure("internal", RunResolutionEvaluation.FailureCategory.STASH_REDUCIBLE, "Selected items need 3 open stash slots; 2 are available. Reduce selected items.")
	_panel.call(&"show_preflight", reducible)
	_assert((_panel.get_node("Frame/Content/PlayerError") as Label).text == reducible.player_reason, "reducible stash error uses typed player copy")

func _policy(capacity: int, count: int) -> RunExtractionProjection:
	var eligible: Array[ExtractionSelection] = []
	var lost: Array[String] = []
	for index: int in count:
		var item_id := "item-%02d" % (index + 1)
		eligible.append(ExtractionSelection.create(item_id, &"run-inventory", index))
		lost.append(item_id)
	return RunExtractionProjection.create([], eligible, [], lost, capacity, [])

func _picker_projection(item_type: Script, projection_type: Script, count: int, capacity: int) -> Variant:
	var automatic: Array = [item_type.call(&"create", "automatic", "Automatic Sword", "Common", &"common", "Asha", "Leader Equipment", true, false, false, {"name": "Automatic Sword"}, [])]
	var eligible: Array = []
	for index: int in count:
		var item_id := "item-%02d" % (index + 1)
		eligible.append(item_type.call(&"create", item_id, "Item %02d" % (index + 1), "Common", &"common", "Run Inventory", "Run Inventory", false, false, true, {"name": "Item %02d" % (index + 1)}, []))
	return projection_type.call(&"create", automatic, eligible, capacity, [], [], [], "", true)

func _press_keyboard(keycode: Key) -> void:
	var event := InputEventKey.new(); event.keycode = keycode; event.pressed = true; _viewport.push_input(event)
	var released := event.duplicate() as InputEventKey; released.pressed = false; _viewport.push_input(released)
	await process_frame

func _press_controller_accept() -> void:
	var event := InputEventJoypadButton.new(); event.device = 0; event.button_index = JOY_BUTTON_A; event.pressed = true; _viewport.push_input(event)
	var released := event.duplicate() as InputEventJoypadButton; released.pressed = false; _viewport.push_input(released)
	await process_frame

func _press_controller_cancel() -> void:
	var event := InputEventJoypadButton.new(); event.device = 0; event.button_index = JOY_BUTTON_B; event.pressed = true; _viewport.push_input(event)
	var released := event.duplicate() as InputEventJoypadButton; released.pressed = false; _viewport.push_input(released)
	await process_frame

func _click_mouse(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = point; _viewport.push_input(motion)
	var pressed := InputEventMouseButton.new(); pressed.button_index = MOUSE_BUTTON_LEFT; pressed.position = point; pressed.pressed = true; _viewport.push_input(pressed)
	var released := pressed.duplicate() as InputEventMouseButton; released.pressed = false; _viewport.push_input(released)
	await process_frame

func _on_toggle(item_id: String) -> void: _toggles.append(item_id)
func _on_inspect(item_id: String, anchor: Control) -> void: _inspects.append([item_id, anchor])
func _on_confirm() -> void: _confirms += 1
func _on_ack() -> void: _acks += 1
func _assert(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _cleanup() -> void:
	paused = false
	if _viewport != null and is_instance_valid(_viewport): _viewport.free()

func _finish() -> void:
	for failure: String in _failures: push_error("TERMINAL_EXTRACTION_FLOW_FAILURE: %s" % failure)
	print("TERMINAL_EXTRACTION_FLOW_SUMMARY: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
