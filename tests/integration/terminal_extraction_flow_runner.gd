extends SceneTree

const PANEL_SCENE := "res://scenes/ui/run_result/terminal_extraction_panel.tscn"
const HUD_SCENE := "res://scenes/ui/hud.tscn"
const CONTROLLER_PATH := "res://scripts/ui/run_result/terminal_extraction_selection_controller.gd"
const ITEM_TYPE_PATH := "res://scripts/ui/run_result/terminal_extraction_item_projection.gd"
const PROJECTION_TYPE_PATH := "res://scripts/ui/run_result/terminal_extraction_projection.gd"

var _failures: Array[String] = []
var _viewport: SubViewport
var _panel: Control
var _active_projection: Variant
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
	underlying.focus_mode = Control.FOCUS_ALL
	underlying.process_mode = Node.PROCESS_MODE_ALWAYS
	underlying.pressed.connect(func() -> void: _underlying_presses += 1)
	_viewport.add_child(underlying)
	_panel = packed.instantiate() as Control
	_viewport.add_child(_panel)
	_panel.connect("item_toggle_requested", _on_toggle)
	_panel.connect("inspect_requested", _on_inspect)
	_panel.connect("confirm_requested", _on_confirm)
	_panel.connect("unused_capacity_acknowledged", _on_ack)
	_active_projection = _picker_projection(item_type, projection_type, 24, 2)
	_panel.call(&"present", _active_projection)
	_panel.visible = true
	paused = true
	await _frames(2)
	_assert(_panel.process_mode == Node.PROCESS_MODE_ALWAYS, "terminal root remains live while the tree is paused")
	_assert(_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "terminal root stops pointer input")
	await _click_mouse(underlying)
	_assert(_underlying_presses == 0, "terminal overlay blocks underlying combat pointer input")
	await _press_key(KEY_ESCAPE)
	_assert(_panel.visible, "Cancel cannot close the terminal picker to combat")
	var cards := _eligible_cards()
	_assert(cards.size() == 24, "eligible 24-item scroll grid is complete")
	if cards.size() != 24:
		return
	_assert(_item_ids(cards) == _expected_item_ids(24), "contiguous source grouping never changes canonical policy item order")
	var sections := _panel.get_node_or_null("Frame/Content/Body/Sections/Eligible/Sections") as Container
	_assert(sections != null and sections.get_child_count() == 5, "interleaved duplicate-display items create five ordered contiguous source sections")
	if sections != null:
		var headings: Array[String] = []
		for section: Node in sections.get_children():
			var heading := section.get_node_or_null("Heading") as Label
			headings.append(heading.text if heading != null else "")
		_assert(headings[0].contains("MEMBER 2") and headings[2].contains("MEMBER 2") and headings[3].contains("MEMBER 3"), "same-class members and repeated sources stay distinguishable without merging order")
	var first := cards[0]
	var second := cards[1]
	var third := cards[2]
	var last := cards[23]
	first.grab_focus()
	await _press_key(KEY_ENTER)
	_assert(_toggles == ["item-01"], "keyboard activation emits exact stable item ID")
	second.grab_focus()
	await _press_key(KEY_SPACE)
	_assert(_toggles.size() == 2 and _toggles[-1] == "item-02", "Space activation emits exact stable item ID once")
	third.grab_focus()
	await _press_joy(JOY_BUTTON_A)
	_assert(_toggles.size() == 3 and _toggles[-1] == "item-03", "controller activation emits exact stable item ID once")
	first.grab_focus()
	for _step: int in 46:
		await _press_joy(JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	_assert(last.has_focus(), "real controller D-pad traversal reaches item 24")
	var scroll := _panel.get_node("Frame/Content/Body") as ScrollContainer
	_assert(scroll.get_global_rect().encloses(last.get_global_rect()), "focused item 24 is fully visible in the scroll viewport")
	await _press_joy(JOY_BUTTON_DPAD_RIGHT)
	await _press_joy(JOY_BUTTON_DPAD_RIGHT)
	var confirm := _panel.get_node("Frame/Content/Actions/Confirm") as Button
	_assert(confirm.has_focus(), "controller traversal reaches footer confirmation")
	await _press_joy(JOY_BUTTON_DPAD_LEFT)
	await _press_joy(JOY_BUTTON_DPAD_LEFT)
	_assert(last.has_focus(), "controller reverse traversal returns from footer to item 24")
	await _click_mouse(last)
	_assert(_toggles.size() == 4 and _toggles[-1] == "item-24", "mouse activation reaches final stable item ID")
	await _exercise_authentic_inspect(first, third, last)
	await _exercise_focus_scopes(first, underlying)
	confirm.grab_focus()
	await _press_joy(JOY_BUTTON_A)
	_assert(_confirms == 1, "controller confirm emits once")
	_panel.call(&"set_pending", true)
	await _press_joy(JOY_BUTTON_A)
	await _press_joy(JOY_BUTTON_A)
	_assert(_confirms == 1, "pending duplicate confirmation input is blocked")
	_panel.call(&"set_pending", false)
	_panel.call(&"show_unused_capacity_warning", 1, 1, first)
	var acknowledge := _panel.get_node("UnusedCapacityWarning/Frame/Actions/Acknowledge") as Button
	acknowledge.grab_focus()
	await _press_key(KEY_ENTER)
	_assert(_acks == 1 and first.has_focus(), "second acknowledgement emits and restores exact item focus")
	var automatic_only := RunResolutionPreflightResult.failure("internal", RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, "Automatic retained items need more destination space. Retry resolution after making space.")
	_panel.call(&"show_preflight", automatic_only)
	_assert(confirm.disabled, "automatic-only blockage disables confirmation")
	var reducible := RunResolutionPreflightResult.failure("internal", RunResolutionEvaluation.FailureCategory.STASH_REDUCIBLE, "Selected items need 3 open stash slots; 2 are available. Select fewer ordinary items.")
	_panel.call(&"show_preflight", reducible)
	_assert((_panel.get_node("Frame/Content/PlayerError") as Label).text == reducible.player_reason, "reducible stash error uses typed player copy")
	await _exercise_availability_focus_resolution(item_type, projection_type, underlying)
	await _exercise_stale_detail_fallback(item_type, projection_type)
	await _exercise_responsive_settings(item_type, projection_type)
	await _exercise_hud_focus_ownership(item_type, projection_type)

func _exercise_authentic_inspect(first: Button, third: Button, last: Button) -> void:
	first.grab_focus()
	await _press_mapped_key_action(&"tooltip_hold")
	_assert(_inspects.size() == 1 and _inspects[0][0] == "item-01" and _inspects[0][1] == first, "mapped keyboard Inspect emits exact stable item and anchor")
	_assert((_panel.get_node("ItemTooltipDetail") as Control).visible, "mapped keyboard Inspect opens the real detail surface through the intent seam")
	var tooltip := _panel.get_node("ItemTooltipDetail/Frame/Tooltip") as ItemTooltipPanel
	_assert(tooltip.current_source_id() == &"terminal-extraction:item-01" and tooltip.card_count() > 0, "detail surface renders exact item source and content")
	await _press_joy(JOY_BUTTON_B)
	_assert(first.has_focus(), "detail controller Cancel returns to exact item")
	var inspect_action := third.get_node_or_null("Content/Footer/Inspect") as Button
	_assert(inspect_action != null and inspect_action.focus_mode == Control.FOCUS_ALL, "eligible card exposes a controller-reachable Inspect action")
	if inspect_action != null:
		inspect_action.grab_focus()
		await _press_joy(JOY_BUTTON_A)
		_assert(_inspects.size() == 2 and _inspects[-1][0] == "item-03", "controller Inspect action emits exact stable item once")
		await _press_joy(JOY_BUTTON_B)
	last.grab_focus()
	await _frames(2)
	await _right_click_mouse(last)
	_assert(_inspects.size() == 3 and _inspects[-1][0] == "item-24", "mouse right-click Inspect emits exact stable item")
	await _press_joy(JOY_BUTTON_B)
	var automatic_card := _card_with_id_prefix("automatic-")
	var automatic_inspect := automatic_card.get_node_or_null("Content/Footer/Inspect") as Button if automatic_card != null else null
	_assert(automatic_inspect != null and automatic_inspect.focus_mode == Control.FOCUS_ALL, "automatic retained item exposes its real focusable Inspect action")
	if automatic_inspect != null:
		automatic_inspect.grab_focus()
		await _press_joy(JOY_BUTTON_A)
		_assert(_inspects.size() == 4 and _inspects[-1][0] == "automatic-00" and _inspects[-1][1] == automatic_inspect, "automatic controller Inspect emits the exact initiating Inspect action anchor")
		await _press_joy(JOY_BUTTON_B)
		_assert(automatic_inspect.has_focus(), "automatic detail controller Cancel returns to the exact initiating Inspect action")

func _exercise_focus_scopes(first: Button, underlying: Button) -> void:
	var list_button := _panel.get_node("Frame/Content/Summary/AutomaticList") as Button
	list_button.grab_focus()
	await _press_joy(JOY_BUTTON_A)
	_assert((_panel.get_node("Frame/Content/Body/Sections/SummaryLists/AutomaticItems") as Control).visible, "summary exact list is reachable with controller Accept")
	for _step: int in 12:
		await _press_key(KEY_TAB)
		_assert(_focus_is_within(_panel) and not underlying.has_focus(), "forward Tab remains in base terminal focus scope; owner=%s" % _focus_owner_path())
	for _step: int in 12:
		await _press_shift_tab()
		_assert(_focus_is_within(_panel) and not underlying.has_focus(), "reverse Tab remains in base terminal focus scope; owner=%s" % _focus_owner_path())
	_panel.call(&"show_detail", _active_projection.eligible_items[0], first)
	var detail := _panel.get_node("ItemTooltipDetail") as Control
	for direction: JoyButton in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		await _press_joy(direction)
		_assert(_focus_is_within(detail) and not underlying.has_focus(), "detail controller directions remain trapped")
	await _press_key(KEY_TAB)
	_assert(_focus_is_within(detail), "detail forward Tab remains trapped")
	await _press_shift_tab()
	_assert(_focus_is_within(detail), "detail reverse Tab remains trapped")
	await _press_joy(JOY_BUTTON_B)
	_panel.call(&"show_unused_capacity_warning", 1, 1, first)
	var warning := _panel.get_node("UnusedCapacityWarning") as Control
	for direction: JoyButton in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		await _press_joy(direction)
		_assert(_focus_is_within(warning) and not underlying.has_focus(), "warning controller directions remain trapped")
	await _press_key(KEY_TAB)
	_assert(_focus_is_within(warning), "warning forward Tab remains trapped")
	await _press_shift_tab()
	_assert(_focus_is_within(warning), "warning reverse Tab remains trapped")
	await _press_joy(JOY_BUTTON_B)
	_assert(first.has_focus(), "warning Cancel returns to exact initiating item")
	_panel.call(&"show_unused_capacity_warning", 1, 1, null)
	await _press_joy(JOY_BUTTON_B)
	_assert(first.has_focus(), "warning Cancel without an initiating control returns to the deterministic first eligible item")

func _exercise_availability_focus_resolution(item_type: Script, projection_type: Script, underlying: Button) -> void:
	_active_projection = _picker_projection(item_type, projection_type, 6, 2)
	_panel.call(&"present", _active_projection)
	var cards := _eligible_cards()
	var first := cards[0]
	var first_inspect := first.get_node("Content/Footer/Inspect") as Button
	var confirm := _panel.get_node("Frame/Content/Actions/Confirm") as Button
	var retry := _panel.get_node("Frame/Content/Actions/Retry") as Button
	var automatic_list := _panel.get_node("Frame/Content/Summary/AutomaticList") as Button
	confirm.grab_focus()
	_panel.call(&"set_pending", true)
	await _frames(2)
	_assert(automatic_list.has_focus() and not underlying.has_focus(), "Confirm becoming pending resolves focus to the deterministic first enabled summary action")
	await _press_key(KEY_TAB)
	_assert(_focus_is_within(_panel) and not underlying.has_focus(), "keyboard traversal after Confirm-to-pending never becomes ownerless or reaches combat")
	var retryable := RunResolutionPreflightResult.failure("internal", RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, "Automatic retained items need more destination space. Retry resolution after making space.")
	_panel.call(&"show_preflight", retryable)
	_panel.call(&"set_pending", false)
	await _frames(2)
	_assert(retry.has_focus() and not underlying.has_focus(), "pending-to-retry-only failure prioritizes the enabled Retry action")
	await _press_joy(JOY_BUTTON_DPAD_RIGHT)
	_assert(_focus_is_within(_panel) and not underlying.has_focus(), "controller traversal from retry-only focus remains terminal-owned")
	_panel.call(&"present", _active_projection)
	cards = _eligible_cards()
	var middle := cards[3]
	middle.grab_focus()
	var reducible := RunResolutionPreflightResult.failure("internal", RunResolutionEvaluation.FailureCategory.STASH_REDUCIBLE, "Selected items need 3 open stash slots; 2 are available. Select fewer ordinary items.")
	_panel.call(&"show_preflight", reducible)
	await _frames(2)
	_assert(middle.has_focus() and not underlying.has_focus(), "editable reducible failure preserves the still-enabled exact item focus")
	_panel.call(&"show_preflight", retryable)
	await _frames(2)
	_assert(retry.has_focus() and not underlying.has_focus(), "locking the focused item for a retry-only failure resolves focus to Retry")
	_panel.call(&"present", _active_projection)
	cards = _eligible_cards()
	cards[3].grab_focus()
	var invalid_projection := projection_type.call(&"create", _active_projection.automatic_items, _active_projection.eligible_items, _active_projection.capacity, _active_projection.selected_item_ids, _active_projection.lost_item_ids, [], "Extraction information changed. Review the available actions.", false) as TerminalExtractionProjection
	_panel.call(&"present", invalid_projection)
	await _frames(2)
	first_inspect = (_eligible_cards()[0].get_node("Content/Footer/Inspect") as Button)
	_assert(first_inspect.has_focus() and not underlying.has_focus(), "an invalid projection resolves a disabled item to the deterministic first enabled base action")
	await _press_joy(JOY_BUTTON_DPAD_DOWN)
	_assert(_focus_is_within(_panel) and not underlying.has_focus(), "controller traversal after invalid projection remains terminal-owned")
	_panel.call(&"present", _active_projection)
	cards = _eligible_cards()
	first = cards[0]
	first_inspect = first.get_node("Content/Footer/Inspect") as Button
	first.grab_focus()
	_panel.call(&"set_pending", true)
	var success := RunResolutionPreflightResult.new()
	success._extraction = RunExtractionProjection.create([], [], [], [], 0, [])
	_panel.call(&"show_preflight", success)
	await _frames(2)
	_assert(automatic_list.has_focus() and not underlying.has_focus(), "successful preflight cannot steal deterministic fallback focus while pending dominates")
	_panel.call(&"set_pending", false)
	await _frames(2)
	_assert(automatic_list.has_focus() and not underlying.has_focus(), "clearing pending after success preserves the still-enabled exact summary action focus")

func _exercise_stale_detail_fallback(item_type: Script, projection_type: Script) -> void:
	_active_projection = _picker_projection(item_type, projection_type, 24, 2)
	_panel.call(&"present", _active_projection)
	var target := _eligible_cards()[-1]
	target.grab_focus()
	await _frames(2)
	var body_scroll := _panel.get_node("Frame/Content/Body") as ScrollContainer
	_assert(body_scroll.get_global_rect().encloses(target.get_global_rect()), "stale fixture target is fully visible before authentic mouse Inspect; scroll=%s target=%s owner=%s" % [body_scroll.get_global_rect(), target.get_global_rect(), _focus_owner_path()])
	await _right_click_mouse(target)
	_assert((_panel.get_node("ItemTooltipDetail") as Control).visible, "stale fixture opens detail before reconcile; scroll=%s target=%s owner=%s inspects=%d" % [body_scroll.get_global_rect(), target.get_global_rect(), _focus_owner_path(), _inspects.size()])
	_active_projection = _picker_projection(item_type, projection_type, 23, 2)
	_panel.call(&"present", _active_projection)
	await _frames(2)
	_assert(not (_panel.get_node("ItemTooltipDetail") as Control).visible, "stale re-projection force-dismisses removed item detail")
	_assert((_panel.get_node("ItemTooltipDetail/Frame/Tooltip") as ItemTooltipPanel).current_source_id().is_empty(), "stale detail leaves no pinned or hover source")
	var fallback_cards := _eligible_cards()
	_assert(fallback_cards[-1].has_focus() and String(fallback_cards[-1].get_meta(&"item_id", "")) == "item-23", "removed detail item uses deterministic nearest canonical fallback")

func _exercise_responsive_settings(item_type: Script, projection_type: Script) -> void:
	for row: Dictionary in [
		{"ui": 150, "text": 150, "hc": true, "label": "150/150 high contrast"},
		{"ui": 80, "text": 150, "hc": false, "label": "80/150 normal contrast"},
	]:
		_viewport.size = Vector2i(1280, 720)
		var settings := PartyForgeSettings.new()
		settings.ui_scale_percent = int(row["ui"])
		settings.text_scale_percent = int(row["text"])
		settings.high_contrast = bool(row["hc"])
		_panel.call(&"apply_visual_settings", settings)
		_active_projection = _picker_projection(item_type, projection_type, 24, 2, 8)
		_panel.call(&"present", _active_projection)
		await _frames(3)
		var label := String(row["label"])
		var viewport_bounds := Rect2(Vector2.ZERO, Vector2(_viewport.size))
		var frame := _panel.get_node("Frame") as Control
		var body := _panel.get_node("Frame/Content/Body") as Control
		var actions := _panel.get_node("Frame/Content/Actions") as Control
		_assert(viewport_bounds.encloses(frame.get_global_rect()), "terminal frame remains bounded at %s; viewport=%s frame=%s" % [label, viewport_bounds, frame.get_global_rect()])
		_assert(frame.get_global_rect().encloses(actions.get_global_rect()), "footer remains visible and bounded at %s" % label)
		_assert(not body.get_global_rect().intersection(actions.get_global_rect()).has_area(), "scroll body never overlaps pinned footer at %s" % label)
		var lost_list_toggle := _panel.get_node("Frame/Content/Summary/LostList") as Button
		lost_list_toggle.grab_focus()
		await _press_joy(JOY_BUTTON_A)
		await _frames(2)
		var expanded_lost := _panel.get_node("Frame/Content/Body/Sections/SummaryLists/LostItems") as Control
		_assert(expanded_lost.visible and viewport_bounds.encloses(frame.get_global_rect()) and body.is_ancestor_of(expanded_lost), "expanded exact consequence lists stay inside the bounded body scroll at %s" % label)
		await _press_joy(JOY_BUTTON_A)
		var automatic_scroll := _panel.get_node_or_null("Frame/Content/Body/Sections/Automatic/Scroll") as ScrollContainer
		var automatic_card := _panel.find_child("ForgeExtractionItemCard", true, false) as Button
		if automatic_card != null:
			(automatic_card.get_node("Content/Footer/Inspect") as Button).grab_focus()
			await _frames(3)
		var automatic_contained := automatic_scroll != null and automatic_card != null and body.get_global_rect().encloses(automatic_card.get_global_rect())
		var automatic_overflows := automatic_scroll != null and automatic_scroll.get_h_scroll_bar().max_value > automatic_scroll.size.x
		_assert(automatic_contained and automatic_overflows, "many automatic retained items remain reachable in a bounded horizontal subscroll at %s; body=%s card=%s scroll_max=%s viewport_width=%s" % [label, body.get_global_rect(), automatic_card.get_global_rect() if automatic_card != null else Rect2(), automatic_scroll.get_h_scroll_bar().max_value if automatic_scroll != null else -1.0, automatic_scroll.size.x if automatic_scroll != null else -1.0])
		var sections := _panel.get_node_or_null("Frame/Content/Body/Sections/Eligible/Sections") as Container
		_assert(sections != null and sections.get_child_count() == 5, "source sections remain visible without canonical flattening at %s" % label)
		if sections != null:
			for grid_node: Node in sections.find_children("Grid", "GridContainer", true, false):
				_assert((grid_node as GridContainer).columns <= 2, "150%% text reflows item grid before cards become cramped at %s" % label)
		for control_node: Node in _panel.find_children("*", "Button", true, false):
			var control := control_node as Button
			if control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
				_assert(control.size.x >= 48.0 and control.size.y >= 48.0, "interactive target remains at least 48px at %s: %s" % [label, control.name])
		var cards := _eligible_cards()
		var last := cards[-1]
		last.grab_focus()
		await _frames(3)
		var scroll := _panel.get_node("Frame/Content/Body") as ScrollContainer
		_assert(scroll.get_global_rect().encloses(last.get_global_rect()), "item 24 remains fully reachable at %s; scroll=%s card=%s" % [label, scroll.get_global_rect(), last.get_global_rect()])
		var focus_style := (last.get_node("FocusFrame") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat
		_assert(focus_style != null and focus_style.border_color == LivingForgeTokens.color(&"focus_outline", bool(row["hc"])), "focus boundary resolves the shared semantic token at %s" % label)

func _exercise_hud_focus_ownership(item_type: Script, projection_type: Script) -> void:
	_panel.call(&"hide_panel")
	var hud_scene := load(HUD_SCENE) as PackedScene
	_assert(hud_scene != null, "HUD scene is available for terminal focus ownership")
	if hud_scene == null:
		return
	var hud := hud_scene.instantiate() as HUD
	_viewport.add_child(hud)
	var underlying := Button.new()
	underlying.name = "UnderlyingHudAction"
	underlying.text = "Underlying HUD Action"
	underlying.focus_mode = Control.FOCUS_ALL
	underlying.position = Vector2(320, 40)
	underlying.size = Vector2(220, 64)
	underlying.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(underlying)
	underlying.grab_focus()
	var prior_mode := underlying.focus_mode
	hud.show_terminal_extraction(_picker_projection(item_type, projection_type, 3, 2))
	await _frames(2)
	_assert(underlying.focus_mode == Control.FOCUS_NONE and not underlying.has_focus(), "HUD show disables the underlying combat focus surface")
	var terminal := hud.get_node("TerminalExtraction") as Control
	for _step: int in 16:
		await _press_key(KEY_TAB)
		_assert(_focus_is_within(terminal), "HUD terminal Tab scope cannot enter underlying combat controls")
	hud.hide_terminal_extraction()
	await _frames(2)
	_assert(underlying.focus_mode == prior_mode and underlying.has_focus(), "HUD hide restores exact prior focus mode and owner")
	hud.free()

func _policy(capacity: int, count: int) -> RunExtractionProjection:
	var eligible: Array[ExtractionSelection] = []
	var lost: Array[String] = []
	for index: int in count:
		var item_id := "item-%02d" % (index + 1)
		eligible.append(ExtractionSelection.create(item_id, &"run-inventory", index))
		lost.append(item_id)
	return RunExtractionProjection.create([], eligible, [], lost, capacity, [])

func _picker_projection(item_type: Script, projection_type: Script, count: int, capacity: int, automatic_count: int = 1) -> Variant:
	var automatic: Array = []
	for automatic_index: int in automatic_count:
		automatic.append(_item(item_type, "automatic-%02d" % automatic_index, "Twin Band", true, false, false, 1, "Fighter", &"run-equipment-001", automatic_index))
	var eligible: Array = []
	var lost: Array[String] = []
	for index: int in count:
		var item_id := "item-%02d" % (index + 1)
		var member_id := 2 if index < 4 or (index >= 8 and index < 12) else 3 if index >= 12 and index < 16 else 0
		var class_label := "Ranger" if member_id > 0 else ""
		var container_id := StringName("run-equipment-%03d" % member_id) if member_id > 0 else &"run-inventory"
		eligible.append(_item(item_type, item_id, "Twin Band", false, false, true, member_id, class_label, container_id, index))
		lost.append(item_id)
	return projection_type.call(&"create", automatic, eligible, capacity, [], lost, [], "", true)

func _item(item_type: Script, item_id: String, item_name: String, automatic: bool, selected: bool, lost: bool, member_id: int, class_label: String, container_id: StringName, slot: int) -> Variant:
	var owner := "%s · Member %d" % [class_label, member_id] if member_id > 0 else "Run Inventory"
	var container_label := "%s Equipment" % class_label if member_id > 0 else "Run Inventory"
	var detail := {"name": item_name, "instance_id": item_id}
	if item_type.has_method(&"create_with_source"):
		return item_type.call(&"create_with_source", item_id, item_name, "Common", &"common", owner, container_label, automatic, selected, lost, detail, [], member_id, class_label, container_id, slot)
	return item_type.call(&"create", item_id, item_name, "Common", &"common", owner, container_label, automatic, selected, lost, detail, [])

func _on_toggle(item_id: String) -> void:
	_toggles.append(item_id)

func _on_inspect(item_id: String, anchor: Control) -> void:
	_inspects.append([item_id, anchor])
	if _active_projection == null:
		return
	var items: Array = _active_projection.automatic_items
	items.append_array(_active_projection.eligible_items)
	for item: Variant in items:
		if item.item_id == item_id:
			_panel.call(&"show_detail", item, anchor)
			return

func _on_confirm() -> void:
	_confirms += 1

func _on_ack() -> void:
	_acks += 1

func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_viewport.push_input(event)
	var released := event.duplicate() as InputEventKey
	released.pressed = false
	_viewport.push_input(released)
	await process_frame

func _press_shift_tab() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.shift_pressed = true
	event.pressed = true
	_viewport.push_input(event)
	var released := event.duplicate() as InputEventKey
	released.pressed = false
	_viewport.push_input(released)
	await process_frame

func _press_joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	_viewport.push_input(event)
	var released := event.duplicate() as InputEventJoypadButton
	released.pressed = false
	_viewport.push_input(released)
	await process_frame

func _press_mapped_key_action(action: StringName) -> void:
	var mapped: InputEventKey
	for candidate: InputEvent in InputMap.action_get_events(action):
		if candidate is InputEventKey:
			mapped = candidate.duplicate() as InputEventKey
			break
	_assert(mapped != null, "%s has an actual mapped keyboard event" % action)
	if mapped == null:
		return
	mapped.pressed = true
	_viewport.push_input(mapped)
	var released := mapped.duplicate() as InputEventKey
	released.pressed = false
	_viewport.push_input(released)
	await process_frame

func _click_mouse(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	_viewport.push_input(motion)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = point
	pressed.pressed = true
	_viewport.push_input(pressed)
	var released := pressed.duplicate() as InputEventMouseButton
	released.pressed = false
	_viewport.push_input(released)
	await process_frame

func _right_click_mouse(control: Control) -> void:
	var point := control.get_global_rect().position + Vector2(16, 16)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	_viewport.push_input(motion)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_RIGHT
	pressed.position = point
	pressed.pressed = true
	_viewport.push_input(pressed)
	var released := pressed.duplicate() as InputEventMouseButton
	released.pressed = false
	_viewport.push_input(released)
	await process_frame

func _eligible_cards() -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in _panel.find_children("*", "ForgeExtractionItemCard", true, false):
		if String(node.get_meta(&"item_id", "")).begins_with("item-"):
			result.append(node as Button)
	return result

func _card_with_id_prefix(prefix: String) -> Button:
	for node: Node in _panel.find_children("*", "ForgeExtractionItemCard", true, false):
		if String(node.get_meta(&"item_id", "")).begins_with(prefix):
			return node as Button
	return null

func _item_ids(cards: Array[Button]) -> Array[String]:
	var result: Array[String] = []
	for card: Button in cards:
		result.append(String(card.get_meta(&"item_id", "")))
	return result

func _expected_item_ids(count: int) -> Array[String]:
	var result: Array[String] = []
	for index: int in count:
		result.append("item-%02d" % (index + 1))
	return result

func _focus_is_within(scope: Control) -> bool:
	var owner := _viewport.gui_get_focus_owner()
	return owner != null and (owner == scope or scope.is_ancestor_of(owner))

func _focus_owner_path() -> String:
	var owner := _viewport.gui_get_focus_owner()
	return "<none>" if owner == null else String(owner.get_path())

func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _cleanup() -> void:
	paused = false
	if _viewport != null and is_instance_valid(_viewport):
		_viewport.free()

func _finish() -> void:
	for failure: String in _failures:
		push_error("TERMINAL_EXTRACTION_FLOW_FAILURE: %s" % failure)
	print("TERMINAL_EXTRACTION_FLOW_SUMMARY: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
