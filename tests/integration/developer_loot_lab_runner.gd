extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/ui/developer_item_sandbox.tscn")
const SANDBOX_ROOT := "user://developer_item_sandbox"
const PROFILE_ROOT := "user://profiles"
const TARGET_SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]

var _failures: Array[String] = []
var _manifest_helper: RefCounted

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	ProfileTestSupport.remove_tree(SANDBOX_ROOT)
	_assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROFILE_ROOT)) == OK, "isolated profile root exists before Loot Lab manifest capture")
	_manifest_helper = (load("res://tests/support/task10_filesystem_manifest.gd") as Script).new()
	var profile_before := _manifest_helper.call(&"capture", PROFILE_ROOT) as Dictionary
	_assert(String(profile_before.get("error", "")).is_empty(), "profile manifest captures before Loot Lab exercise")
	_assert_input_actions()
	var viewport := SubViewport.new()
	viewport.name = "LootLabInputViewport"
	viewport.size = TARGET_SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sandbox := SANDBOX_SCENE.instantiate() as DeveloperItemSandbox
	viewport.add_child(sandbox)
	await _frames(3)
	sandbox.apply_viewport_size(TARGET_SIZES[0])
	_assert(sandbox.open(), "production sandbox opens in the SubViewport")
	await _frames(3)
	var tabs := sandbox.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	await _joy_button(viewport, JOY_BUTTON_RIGHT_SHOULDER)
	_assert(tabs.current_tab == 2, "RB cycles from Equipment to Loot Lab")
	if tabs.current_tab != 2:
		tabs.current_tab = 2
		await process_frame
	var lab := sandbox.get_node("Overlay/Frame/Layout/Tabs/Loot Lab") as DeveloperLootLab
	_assert(lab.has_method(&"apply_viewport_size"), "Loot Lab exposes deterministic responsive layout")
	if lab.has_method(&"apply_viewport_size"):
		_assert_responsive_modes(lab)
	await _exercise_subtab_navigation(viewport, lab)
	await _exercise_generation(viewport, sandbox, lab)
	await _joy_button(viewport, JOY_BUTTON_LEFT_SHOULDER)
	_assert(tabs.current_tab == 1, "LB cycles back to Equipment")
	await _joy_button(viewport, JOY_BUTTON_RIGHT_SHOULDER)
	_assert(tabs.current_tab == 2, "RB returns to Loot Lab")
	var profile_after := _manifest_helper.call(&"capture", PROFILE_ROOT) as Dictionary
	_assert(bool(_manifest_helper.call(&"equivalent", profile_before, profile_after)), "Loot Lab leaves player profile bytes and manifests unchanged")
	sandbox.cancel_and_clear()
	sandbox.free()
	viewport.free()
	await process_frame
	_finish()

func _assert_input_actions() -> void:
	var expected := {
		&"item_sandbox_previous_tab": {"kind": "button", "value": JOY_BUTTON_LEFT_SHOULDER},
		&"item_sandbox_next_tab": {"kind": "button", "value": JOY_BUTTON_RIGHT_SHOULDER},
		&"item_sandbox_scroll_up": {"kind": "axis", "value": -1.0},
		&"item_sandbox_scroll_down": {"kind": "axis", "value": 1.0},
	}
	for action: StringName in expected:
		_assert(InputMap.has_action(action), "%s action exists" % action)
		if not InputMap.has_action(action):
			continue
		var row := expected[action] as Dictionary
		var matched := false
		for event: InputEvent in InputMap.action_get_events(action):
			if row["kind"] == "button" and event is InputEventJoypadButton:
				matched = (event as InputEventJoypadButton).device == -1 and (event as InputEventJoypadButton).button_index == int(row["value"])
			elif row["kind"] == "axis" and event is InputEventJoypadMotion:
				matched = (event as InputEventJoypadMotion).device == -1 and (event as InputEventJoypadMotion).axis == JOY_AXIS_RIGHT_Y and is_equal_approx((event as InputEventJoypadMotion).axis_value, float(row["value"]))
			if matched:
				break
		_assert(matched, "%s has the device-agnostic controller mapping" % action)

func _assert_responsive_modes(lab: DeveloperLootLab) -> void:
	var workbench := lab.get_node("Layout/Workbench") as BoxContainer
	var request := lab.get_node("Layout/Workbench/RequestScroll") as Control
	var results := lab.get_node("Layout/Workbench/Results") as Control
	var inspector := lab.get_node("Layout/Workbench/InspectorScroll") as Control
	var selectors := lab.get_node("Layout/PaneSelectors") as Control
	var gallery := lab.get_node("Layout/Workbench/Results/SampleScroll/SampleGrid") as GridContainer
	var analysis_table := lab.get_node("Layout/Analysis/Layout/Table") as Tree
	for index: int in TARGET_SIZES.size():
		lab.call(&"apply_viewport_size", TARGET_SIZES[index])
		_assert(not workbench.vertical, "%s desktop Workbench keeps three horizontal panes" % TARGET_SIZES[index])
		_assert(request.visible and results.visible and inspector.visible, "%s desktop Workbench keeps every pane usable" % TARGET_SIZES[index])
		_assert(not selectors.visible, "%s desktop hides compact pane selectors" % TARGET_SIZES[index])
		_assert(gallery.columns == [4, 6, 8][index], "%s scales sample columns without scaling typography" % TARGET_SIZES[index])
	lab.call(&"apply_viewport_size", Vector2i(960, 540))
	_assert(workbench.vertical and selectors.visible, "compact mode exposes pane selectors")
	_assert(int(request.visible) + int(results.visible) + int(inspector.visible) == 1, "compact mode shows exactly one Workbench pane")
	_assert((lab.get_node("Layout/FooterStatus") as Control).visible, "compact mode retains the fixed footer")
	_assert(int((lab.get_node("Layout/Analysis") as LootLabAnalysisView).column_minimum_width(0)) > 0 and int((lab.get_node("Layout/Analysis") as LootLabAnalysisView).column_minimum_width(7)) > 0, "compact Analysis preserves identity and status columns for bounded horizontal scrolling")
	lab.call(&"apply_viewport_size", TARGET_SIZES[0])

func _exercise_subtab_navigation(viewport: SubViewport, lab: DeveloperLootLab) -> void:
	var workbench_button := lab.get_node("Layout/Header/WorkbenchFocusAnchor") as Button
	var analysis_button := lab.get_node("Layout/Header/AnalysisFocusAnchor") as Button
	workbench_button.grab_focus()
	await _joy_button(viewport, JOY_BUTTON_DPAD_DOWN)
	_assert(viewport.gui_get_focus_owner() == analysis_button, "D-pad reaches the Analysis subtab from Workbench")
	await _joy_button(viewport, JOY_BUTTON_A)
	_assert((lab.get_node("Layout/Analysis") as Control).visible, "south face opens the Analysis subtab")
	analysis_button.grab_focus()
	await _joy_button(viewport, JOY_BUTTON_DPAD_DOWN)
	_assert(viewport.gui_get_focus_owner() in lab.focus_controls(), "D-pad enters the visible Analysis actions")
	workbench_button.grab_focus()
	await _joy_button(viewport, JOY_BUTTON_A)
	_assert((lab.get_node("Layout/Workbench") as Control).visible, "south face returns to Workbench")

func _exercise_generation(viewport: SubViewport, sandbox: DeveloperItemSandbox, lab: DeveloperLootLab) -> void:
	var form := lab.get_node("Layout/Workbench/RequestScroll/RequestForm") as LootLabRequestForm
	var permitted_rarities := form.get_node("Fields/PermittedRarityIds") as Control
	var rarities_before_controller := (form.preferences_document().get("permitted_rarity_ids", []) as Array).duplicate()
	permitted_rarities.grab_focus()
	await _joy_button(viewport, JOY_BUTTON_A)
	_assert(permitted_rarities is MenuButton and (permitted_rarities as MenuButton).get_popup().visible, "south face opens the permitted-rarity catalog multi-select")
	if permitted_rarities is MenuButton:
		var rarity_popup := (permitted_rarities as MenuButton).get_popup()
		await _joy_button(viewport, JOY_BUTTON_DPAD_DOWN)
		await _joy_button(viewport, JOY_BUTTON_A)
		_assert((form.preferences_document().get("permitted_rarity_ids", []) as Array) != rarities_before_controller, "D-pad and south face mutate the permitted-rarity selection without a mouse")
		rarity_popup.hide()
	var one := form.preferences_document()
	one["batch_preset"] = 1
	_assert(form.apply_preferences(one).is_empty(), "one-item preset applies")
	var generate := form.get_node("Generate") as Button
	_assert(generate.is_visible_in_tree(), "Generate remains visible after responsive transitions")
	_assert(generate.focus_mode == Control.FOCUS_ALL, "Generate remains in the active closed focus graph")
	generate.grab_focus()
	await _joy_button(viewport, JOY_BUTTON_A)
	for _index: int in 60:
		if not lab.has_active_job():
			break
		await process_frame
	_assert(not lab.has_active_job(), "south face generates a one-item report over bounded frames")
	var gallery := lab.get_node("Layout/Workbench/Results/SampleScroll/SampleGrid") as LootLabSampleGallery
	_assert(gallery.get_child_count() == 1, "generated report presents one sample")
	if gallery.get_child_count() == 1:
		var tile := gallery.get_child(0) as Button
		tile.grab_focus()
		await _joy_button(viewport, JOY_BUTTON_A)
		var issue := lab.get_node("Layout/Workbench/InspectorScroll/TraceInspector/Issue") as Button
		issue.grab_focus()
		_assert(not issue.disabled and viewport.gui_get_focus_owner() == issue, "selected preview enables and focuses Issue")
		await _joy_button(viewport, JOY_BUTTON_A)
		var stash_grid := sandbox.get_node("Overlay/Frame/Layout/Tabs/Equipment/Body/StashPanel/StashScroll/StashSlots") as GridContainer
		var occupied := stash_grid.get_children().filter(func(button: Node) -> bool: return not String(button.get_meta("item_id", "")).is_empty())
		_assert(occupied.size() == 100, "south face selects and issues one preview")
	var sample_batch := form.preferences_document()
	sample_batch["batch_preset"] = 100
	form.apply_preferences(sample_batch)
	generate.grab_focus()
	await _joy_button(viewport, JOY_BUTTON_A)
	for _index: int in 60:
		if not lab.has_active_job():
			break
		await process_frame
	_assert(gallery.get_child_count() == 100, "sample gallery retains its bounded 100 examples")
	viewport.size = Vector2i(960, 540)
	sandbox.apply_viewport_size(Vector2i(960, 540))
	lab.call(&"_set_compact_pane", 1)
	await _frames(3)
	var sample_scroll := lab.get_node("Layout/Workbench/Results/SampleScroll") as ScrollContainer
	sample_scroll.scroll_vertical = 0
	(gallery.get_child(0) as Control).grab_focus()
	(sandbox.get_node("Overlay/ItemTooltip") as ItemTooltipPanel).force_dismiss()
	await _joy_axis(viewport, JOY_AXIS_RIGHT_Y, 1.0)
	_assert(sample_scroll.scroll_vertical > 0, "right stick scrolls the focused sample pane")
	sample_scroll.scroll_vertical = 0
	await _mouse_wheel(viewport, sample_scroll)
	_assert(sample_scroll.scroll_vertical > 0, "mouse wheel remains functional in the sample pane")
	var sample_bar := sample_scroll.get_v_scroll_bar()
	sample_bar.value = sample_bar.max_value
	await process_frame
	_assert(sample_scroll.scroll_vertical > 0, "the draggable sample scrollbar remains bound to content")
	lab.call(&"_set_compact_pane", 2)
	await _frames(3)
	var trace_scroll := lab.get_node("Layout/Workbench/InspectorScroll") as ScrollContainer
	trace_scroll.scroll_vertical = 0
	(lab.get_node("Layout/Workbench/InspectorScroll/TraceInspector/Sequence") as Control).grab_focus()
	await _joy_axis(viewport, JOY_AXIS_RIGHT_Y, 1.0)
	_assert(trace_scroll.scroll_vertical > 0, "right stick scrolls the focused trace pane")
	lab.call(&"_show_analysis")
	var analysis_table := lab.get_node("Layout/Analysis/Layout/Table") as Tree
	analysis_table.grab_focus()
	await _joy_axis(viewport, JOY_AXIS_RIGHT_Y, 1.0)
	_assert(analysis_table.get_selected() != null, "right stick scrolls/selects rows in the Analysis pane")
	lab.call(&"_show_workbench")
	viewport.size = TARGET_SIZES[0]
	sandbox.apply_viewport_size(TARGET_SIZES[0])
	await _frames(3)
	var large := form.preferences_document()
	large["batch_preset"] = 100000
	form.apply_preferences(large)
	generate.grab_focus()
	await _joy_button(viewport, JOY_BUTTON_A)
	_assert((lab.get_node("BatchConfirmation") as ConfirmationDialog).visible and not lab.has_active_job(), "100000 attempts prompts before starting")
	(lab.get_node("BatchConfirmation") as ConfirmationDialog).hide()
	var cancellable := form.preferences_document()
	cancellable["batch_preset"] = 10000
	form.apply_preferences(cancellable)
	generate.grab_focus()
	await _joy_button(viewport, JOY_BUTTON_A)
	await _frames(2)
	var progress := lab.get_node("Layout/Workbench/Results/Progress") as ProgressBar
	_assert(lab.has_active_job() and progress.value > 0.0 and progress.value < progress.max_value, "large job advances across multiple bounded frames")
	await _joy_button(viewport, JOY_BUTTON_B)
	_assert(sandbox.is_open() and not lab.has_active_job(), "east face cancels an active job before closing")
	viewport.size = Vector2i(960, 540)
	sandbox.apply_viewport_size(Vector2i(960, 540))
	lab.call(&"_set_compact_pane", 0)
	await _frames(3)
	var request_scroll := lab.get_node("Layout/Workbench/RequestScroll") as ScrollContainer
	(form.focus_controls().front() as Control).grab_focus()
	request_scroll.scroll_vertical = 0
	await _joy_axis(viewport, JOY_AXIS_RIGHT_Y, 1.0)
	_assert(request_scroll.scroll_vertical > 0, "right stick scrolls the focused request pane")
	viewport.size = TARGET_SIZES[0]
	sandbox.apply_viewport_size(TARGET_SIZES[0])
	await _frames(3)

func _joy_button(viewport: SubViewport, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	viewport.push_input(event, true)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	viewport.push_input(release, true)
	await process_frame

func _joy_axis(viewport: SubViewport, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	viewport.push_input(event, true)
	await process_frame
	var release := event.duplicate() as InputEventJoypadMotion
	release.axis_value = 0.0
	viewport.push_input(release, true)
	await process_frame

func _mouse_wheel(viewport: SubViewport, target: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = target.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	viewport.push_input(event, true)
	await process_frame

func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	ProfileTestSupport.remove_tree(SANDBOX_ROOT)
	_assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SANDBOX_ROOT)), "cleanup removes every Loot Lab sandbox root before summary")
	if _failures.is_empty():
		print("DEVELOPER_LOOT_LAB_INPUT_PASS")
		print("DEVELOPER_LOOT_LAB_RESPONSIVE_PASS")
		print("DEVELOPER_LOOT_LAB_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("DEVELOPER_LOOT_LAB_FAILURE: %s" % failure)
	print("DEVELOPER_LOOT_LAB_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)
