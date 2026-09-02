extends RefCounted

const NODE_SCENE_PATH := "res://scenes/ui/passive_tree/passive_tree_node_control.tscn"
const SCREEN_SCENE_PATH := "res://scenes/ui/passive_tree/passive_tree_screen.tscn"
const NODE_SCRIPT_PATH := "res://scripts/ui/passive_tree/passive_tree_node_control.gd"
const SCREEN_SCRIPT_PATH := "res://scripts/ui/passive_tree/passive_tree_screen.gd"
const CANVAS_SCRIPT_PATH := "res://scripts/ui/passive_tree/passive_tree_canvas.gd"

var _root_counter := 0

class RecordingPassiveTreeMutations extends PassiveTreeMutationService:
	var allocation_authorities: Array[bool] = []

	func _init() -> void:
		var effects := PassiveEffectRegistry.new()
		super(ProfileMutationService.new(ProfileStore.new()), PassiveTreeProgressionService.new(effects, PassiveRequirementRegistry.new()), PassiveEffectResolver.new(effects))

	func allocate(
		_profile_id: String,
		_transaction_id: String,
		_tree: PassiveTreeDefinition,
		_node_id: StringName,
		developer_context: bool,
		_root: String = ProfileStore.DEFAULT_ROOT,
	) -> ProfileMutationResult:
		allocation_authorities.append(developer_context)
		var result := ProfileMutationResult.new()
		result.error = "INJECTED_PLAYER_AUTHORITY_PROBE"
		return result


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_scene_and_type_contracts(failures)
	if load(SCREEN_SCENE_PATH) == null or load(NODE_SCENE_PATH) == null:
		return failures
	_test_node_control_copy_activation_and_redaction(failures)
	_test_canvas_copy_draw_zoom_pan_and_navigation(failures)
	_test_canvas_fit_to_content_contract(failures)
	_test_screen_invalid_safe_state_and_geometry(failures)
	_test_screen_obscured_nonleak(failures)
	_test_visible_detail_disclosures_and_permanent_styling(failures)
	_test_lifecycle_pause_ownership_and_focus(failures)
	_test_confirmation_real_mutation_refresh_and_errors(failures)
	_test_developer_preview_commits_with_player_authority(failures)
	_test_confirmation_captures_allocation_and_refund_targets(failures)
	_test_confirmation_invalidation_and_clear_contract(failures)
	_test_keyboard_controller_actions_and_modal_block(failures)
	_test_exact_save_error_surface(failures)
	return failures


func _test_keyboard_controller_actions_and_modal_block(failures: Array[String]) -> void:
	var root := _case_root("input")
	var store := ProfileStore.new()
	var tree := _mutation_tree()
	var profile := ProfileState.new_profile("input-profile", "Input", 1000)
	profile.discovered_trees = [String(tree.id)]
	profile.tree_allocations[String(tree.id)] = ["root"]
	profile.passive_points_available = 2
	profile.passive_points_lifetime_earned = 2
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "input fixture saves", failures)
	var manager := ProfileManager.new()
	TestAssertions.equal(manager.bootstrap(root), "", "input manager bootstraps", failures)
	var screen := _configured_screen(tree, manager, _services(store), true, root)
	var canvas := screen.find_child("Canvas", true, false) as PassiveTreeCanvas
	canvas.select_node(&"root")
	screen.call("_unhandled_input", _action_event(&"passive_tree_navigate_right"))
	TestAssertions.equal(canvas.selected_node_id(), &"target", "tree action navigates to the linked right node", failures)
	screen.call("_unhandled_input", _action_event(&"passive_tree_allocate"))
	TestAssertions.truthy((screen.find_child("Confirmation", true, false) as Control).visible, "allocate action opens confirmation", failures)
	var selected_before := canvas.selected_node_id()
	var pan_before := canvas.pan_value()
	screen.call("_unhandled_input", _action_event(&"passive_tree_navigate_left"))
	var has_continuous_input := screen.has_method(&"_process") and InputMap.has_action(&"passive_tree_pan_right") and InputMap.has_action(&"passive_tree_zoom_in")
	TestAssertions.truthy(has_continuous_input, "tree screen exposes mapped continuous pan and zoom processing", failures)
	if has_continuous_input:
		Input.action_press(&"passive_tree_pan_right", 1.0)
		screen.call("_process", 0.5)
		Input.action_release(&"passive_tree_pan_right")
	TestAssertions.equal(canvas.selected_node_id(), selected_before, "modal confirmation blocks navigation behind it", failures)
	TestAssertions.equal(canvas.pan_value(), pan_before, "modal confirmation blocks pan behind it", failures)
	screen.call("_unhandled_input", _action_event(&"passive_tree_close"))
	TestAssertions.truthy(not (screen.find_child("Confirmation", true, false) as Control).visible and screen.is_open(), "close action cancels confirmation before closing screen", failures)
	if has_continuous_input:
		Input.action_press(&"passive_tree_pan_right", 1.0)
		Input.action_press(&"passive_tree_zoom_in", 1.0)
		screen.call("_process", 0.5)
		Input.action_release(&"passive_tree_pan_right")
		Input.action_release(&"passive_tree_zoom_in")
		TestAssertions.truthy(canvas.pan_value().x > pan_before.x, "right-stick action pans at a bounded delta rate", failures)
		TestAssertions.truthy(canvas.zoom_value() > 1.0 and canvas.zoom_value() <= PassiveTreeCanvas.MAX_ZOOM, "trigger action zooms through the canvas clamp", failures)
	screen.call("_unhandled_input", _action_event(&"passive_tree_close"))
	TestAssertions.truthy(not screen.is_open(), "close action closes the tree when no confirmation is active", failures)
	screen.free()
	ProfileTestSupport.remove_tree(root)


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _test_scene_and_type_contracts(failures: Array[String]) -> void:
	var node_scene := load(NODE_SCENE_PATH) as PackedScene
	var screen_scene := load(SCREEN_SCENE_PATH) as PackedScene
	TestAssertions.truthy(node_scene != null, "passive tree node scene loads as PackedScene", failures)
	TestAssertions.truthy(screen_scene != null, "passive tree screen scene loads as PackedScene", failures)
	if node_scene != null:
		var node_control := node_scene.instantiate()
		TestAssertions.equal(node_control.get_script(), load(NODE_SCRIPT_PATH), "node scene uses the exact typed script", failures)
		node_control.free()
	if screen_scene != null:
		var screen := screen_scene.instantiate()
		TestAssertions.equal(screen.get_script(), load(SCREEN_SCRIPT_PATH), "screen scene uses the exact typed script", failures)
		TestAssertions.equal(screen.process_mode, Node.PROCESS_MODE_ALWAYS, "screen scene always processes while paused", failures)
		var canvas := screen.find_child("Canvas", true, false)
		TestAssertions.truthy(canvas != null and canvas.get_script() == load(CANVAS_SCRIPT_PATH), "screen owns the exact typed canvas", failures)
		for required_name: String in ["Overlay", "Frame", "Title", "Points", "Canvas", "DetailTitle", "DetailDescription", "DetailScroll", "DetailBody", "Status", "Unresolved", "AllocateButton", "RefundButton", "ConfirmationBlocker", "Confirmation", "ConfirmButton", "CancelButton", "CloseButton"]:
			TestAssertions.truthy(screen.find_child(required_name, true, false) != null, "screen exposes stable node %s" % required_name, failures)
		var blocker := screen.find_child("ConfirmationBlocker", true, false) as Control
		var confirmation := screen.find_child("Confirmation", true, false) as Control
		var frame := screen.find_child("Frame", true, false) as Control
		if blocker != null and confirmation != null and frame != null:
			TestAssertions.equal(blocker.mouse_filter, Control.MOUSE_FILTER_STOP, "confirmation blocker consumes underlying mouse input", failures)
			TestAssertions.truthy(blocker.anchor_left == 0.0 and blocker.anchor_top == 0.0 and blocker.anchor_right == 1.0 and blocker.anchor_bottom == 1.0, "confirmation blocker covers the viewport", failures)
			TestAssertions.truthy(frame.get_index() < blocker.get_index() and blocker.get_index() < confirmation.get_index(), "blocker renders above the screen and below the dialog", failures)
			TestAssertions.truthy(not blocker.visible and not confirmation.visible, "confirmation blocker and dialog start hidden together", failures)
		var confirm := screen.find_child("ConfirmButton", true, false) as Button
		var cancel := screen.find_child("CancelButton", true, false) as Button
		if confirm != null and cancel != null:
			for property_name: StringName in [&"focus_next", &"focus_previous", &"focus_neighbor_left", &"focus_neighbor_right", &"focus_neighbor_top", &"focus_neighbor_bottom"]:
				TestAssertions.equal(confirm.get(property_name), confirm.get_path_to(cancel), "Confirm %s is trapped to Cancel" % property_name, failures)
				TestAssertions.equal(cancel.get(property_name), cancel.get_path_to(confirm), "Cancel %s is trapped to Confirm" % property_name, failures)
		screen.free()


func _test_node_control_copy_activation_and_redaction(failures: Array[String]) -> void:
	var node_control := (load(NODE_SCENE_PATH) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(node_control)
	node_control.call(&"_ready")
	var selected_ids: Array[StringName] = []
	node_control.connect(&"node_selected", func(node_id: StringName) -> void: selected_ids.append(node_id))
	var hidden := PassiveTreeNodeViewData.new(&"hidden", Vector2(10, 20), &"keystone", &"obscured", "Secret Name", "Secret Description", 77, "77", ["Secret Effect"], ["Secret Requirement"], ["Secret Keyword"], {"secret": "Secret Metadata"}, true, true, true, &"ok", "Secret Decision")
	node_control.call(&"bind_view", hidden)
	hidden.display_name = "Caller Mutation"
	var copied := node_control.call(&"view_data") as PassiveTreeNodeViewData
	TestAssertions.truthy(copied != hidden and copied.display_name == "???" and copied.description == "???", "node stores a defensive redacted view copy", failures)
	TestAssertions.equal(node_control.text, "???", "obscured node label is redacted", failures)
	TestAssertions.equal(node_control.tooltip_text, "", "obscured node has no tooltip leak", failures)
	TestAssertions.truthy(not _control_surface_text(node_control).contains("Secret"), "obscured node leaks no hidden strings through control surfaces", failures)
	TestAssertions.truthy(node_control.focus_mode != Control.FOCUS_NONE, "node control is keyboard and controller focusable", failures)
	TestAssertions.truthy(not node_control.get_signal_connection_list(&"pressed").is_empty(), "node activation signal is wired", failures)
	node_control.pressed.emit()
	TestAssertions.equal(selected_ids, [&"hidden"], "node activation emits one stable node ID", failures)
	node_control.free()


func _test_visible_detail_disclosures_and_permanent_styling(failures: Array[String]) -> void:
	var root := _case_root("disclosures")
	var store := ProfileStore.new()
	var tree := _mutation_tree()
	var profile := ProfileState.new_profile("disclosure-profile", "Disclosure", 1000)
	profile.discovered_trees = [String(tree.id)]
	profile.tree_allocations[String(tree.id)] = ["root", "removed-zeta", "removed-alpha"]
	profile.passive_points_available = 2
	profile.passive_points_lifetime_earned = 2
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "disclosure fixture saves", failures)
	var manager := ProfileManager.new()
	TestAssertions.equal(manager.bootstrap(root), "", "disclosure manager bootstraps", failures)
	var screen := _configured_screen(tree, manager, _services(store), true, root)
	var canvas := screen.find_child("Canvas", true, false) as PassiveTreeCanvas
	canvas.select_node(&"future")
	var detail := _label(screen, "DetailSections").text
	TestAssertions.truthy(detail.contains("Cost\n1"), "visible detail renders node cost", failures)
	TestAssertions.truthy(detail.contains("Refund Policy\nRefundable"), "visible detail renders explicit refundable policy", failures)
	TestAssertions.truthy(detail.contains("Coming Soon") and detail.contains("Developer Preview"), "Developer detail renders both future-contract disclosures", failures)
	var unresolved_label := _label(screen, "Unresolved")
	TestAssertions.truthy(unresolved_label != null, "screen exposes dedicated unresolved-allocation disclosure", failures)
	if unresolved_label != null:
		TestAssertions.equal(unresolved_label.text, "Unresolved saved allocations: removed-alpha, removed-zeta", "screen discloses sorted unresolved saved IDs", failures)
	canvas.select_node(&"root")
	TestAssertions.truthy(_label(screen, "DetailSections").text.contains("Refund Policy\nPermanent"), "permanent detail is accessible without relying on color", failures)
	var permanent_control := canvas.node_control(&"root") as PassiveTreeNodeControl
	var ordinary_control := canvas.node_control(&"future") as PassiveTreeNodeControl
	TestAssertions.truthy(permanent_control.get_theme_color("font_outline_color") != ordinary_control.get_theme_color("font_outline_color"), "permanent node has distinct outline styling", failures)
	TestAssertions.truthy(permanent_control.tooltip_text.contains("Permanent"), "permanent node tooltip conveys permanence", failures)
	screen.call(&"close")
	screen.free()
	ProfileTestSupport.remove_tree(root)

func _test_developer_preview_commits_with_player_authority(failures: Array[String]) -> void:
	var root := _case_root("developer_authority")
	var store := ProfileStore.new()
	var tree := _mutation_tree()
	var profile := ProfileState.new_profile("developer-authority", "Developer Authority", 1000)
	profile.discovered_trees = [String(tree.id)]
	profile.tree_allocations[String(tree.id)] = ["root"]
	profile.passive_points_available = 2
	profile.passive_points_lifetime_earned = 2
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "Developer authority fixture saves", failures)
	var manager := ProfileManager.new()
	TestAssertions.equal(manager.bootstrap(root), "", "Developer authority manager bootstraps", failures)
	var spy := RecordingPassiveTreeMutations.new()
	var services := _services(store)
	var screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.call(&"_ready")
	screen.call(&"configure", tree, manager, spy, services["view_model"], true, root)
	screen.call(&"open")
	var canvas := screen.find_child("Canvas", true, false)
	TestAssertions.truthy(canvas.call(&"select_node", &"target"), "Developer preview selects implemented target", failures)
	TestAssertions.truthy(not _button(screen, "AllocateButton").disabled, "Developer preview exposes allocation affordance", failures)
	_button(screen, "AllocateButton").pressed.emit()
	_button(screen, "ConfirmButton").pressed.emit()
	TestAssertions.equal(spy.allocation_authorities, [false], "Developer Preview always submits Player Mode allocation authority", failures)
	TestAssertions.equal(_label(screen, "Status").text, "INJECTED_PLAYER_AUTHORITY_PROBE", "authority probe failure stays user-visible", failures)
	TestAssertions.equal(store.load_profile(profile.profile_id, root).profile.to_dictionary(), profile.to_dictionary(), "authority probe persists no profile mutation", failures)
	screen.call(&"close")
	screen.free()
	ProfileTestSupport.remove_tree(root)


func _test_canvas_copy_draw_zoom_pan_and_navigation(failures: Array[String]) -> void:
	var screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate()
	var canvas := screen.find_child("Canvas", true, false)
	var views: Array[PassiveTreeNodeViewData] = [
		_view(&"root", Vector2.ZERO),
		_view(&"z-near", Vector2(10, 0)),
		_view(&"a-near", Vector2(10, 0)),
		_view(&"far", Vector2(20, 0)),
		_view(&"diagonal", Vector2(10, 10)),
	]
	var connections: Array[Dictionary] = [
		{"id": &"reverse-a", "from_id": &"a-near", "to_id": &"root", "direction": &"forward", "metadata": {"nested": {"value": 1}}},
		{"id": &"root-z", "from_id": &"root", "to_id": &"z-near", "direction": &"forward", "metadata": {}},
		{"id": &"root-far", "from_id": &"root", "to_id": &"far", "direction": &"forward", "metadata": {}},
		{"id": &"root-diagonal", "from_id": &"root", "to_id": &"diagonal", "direction": &"forward", "metadata": {}},
	]
	canvas.call(&"rebuild", views, connections)
	views[0].position = Vector2(999, 999)
	connections[0]["metadata"]["nested"]["value"] = 999
	TestAssertions.equal(canvas.call(&"node_ids"), [&"a-near", &"diagonal", &"far", &"root", &"z-near"], "canvas rebuild is deterministic and lexical", failures)
	TestAssertions.equal((canvas.call(&"node_view", &"root") as PassiveTreeNodeViewData).position, Vector2.ZERO, "canvas owns copied node view data", failures)
	TestAssertions.equal((canvas.call(&"connection_views") as Array)[0]["metadata"]["nested"]["value"], 1, "canvas owns value-only connection copies", failures)
	TestAssertions.truthy(not _has_line_child(canvas), "connections remain in canvas draw pass behind child nodes", failures)
	canvas.call(&"set_zoom", 0.1)
	TestAssertions.equal(canvas.call(&"zoom_value"), 0.45, "zoom clamps to inclusive minimum", failures)
	canvas.call(&"set_zoom", 9.0)
	TestAssertions.equal(canvas.call(&"zoom_value"), 2.25, "zoom clamps to inclusive maximum", failures)
	canvas.call(&"set_pan", Vector2(41, -19))
	TestAssertions.equal(canvas.call(&"pan_value"), Vector2(41, -19), "pan is retained in canvas-local coordinates", failures)
	TestAssertions.equal((canvas.call(&"node_view", &"root") as PassiveTreeNodeViewData).position, Vector2.ZERO, "pan and zoom never mutate view positions", failures)
	TestAssertions.truthy(not canvas.call(&"select_connected", Vector2.RIGHT), "navigation fails closed without a selection", failures)
	TestAssertions.truthy(canvas.call(&"select_node", &"root"), "canvas explicitly selects a node", failures)
	TestAssertions.truthy(not canvas.call(&"select_connected", Vector2.ZERO), "zero-direction navigation fails closed", failures)
	TestAssertions.truthy(canvas.call(&"select_connected", Vector2.RIGHT), "authored connection is navigable in either direction", failures)
	TestAssertions.equal(canvas.call(&"selected_node_id"), &"a-near", "navigation uses dot then distance then lexical node ID tie-breaks", failures)
	TestAssertions.truthy(canvas.call(&"select_connected", Vector2.LEFT), "reverse traversal returns through authored connection", failures)
	TestAssertions.equal(canvas.call(&"selected_node_id"), &"root", "reverse traversal selects the linked origin", failures)
	TestAssertions.truthy(not canvas.call(&"select_connected", Vector2.LEFT), "navigation rejects candidates with nonpositive alignment", failures)
	screen.free()


func _test_canvas_fit_to_content_contract(failures: Array[String]) -> void:
	var canvas := PassiveTreeCanvas.new()
	canvas.size = Vector2(900, 600)
	var views: Array[PassiveTreeNodeViewData] = [
		_view(&"left", Vector2(-400, -200)),
		_view(&"center", Vector2.ZERO),
		_view(&"right", Vector2(400, 200)),
	]
	canvas.rebuild(views, [])
	var authored_positions := {
		&"left": Vector2(-400, -200),
		&"center": Vector2.ZERO,
		&"right": Vector2(400, 200),
	}
	var has_fit := canvas.has_method(&"fit_to_content")
	TestAssertions.truthy(has_fit, "canvas exposes the production fit_to_content contract", failures)
	if has_fit:
		TestAssertions.truthy(bool(canvas.call(&"fit_to_content", Vector2(24, 24))), "nonempty positive canvas fits authored content", failures)
		TestAssertions.truthy(is_finite(canvas.zoom_value()) and canvas.zoom_value() >= PassiveTreeCanvas.MIN_ZOOM and canvas.zoom_value() <= PassiveTreeCanvas.MAX_ZOOM, "content fit produces finite clamped zoom", failures)
		TestAssertions.truthy(is_finite(canvas.pan_value().x) and is_finite(canvas.pan_value().y), "content fit produces finite pan", failures)
		var canvas_rect := Rect2(Vector2.ZERO, canvas.size)
		for node_id: StringName in canvas.node_ids():
			TestAssertions.equal(canvas.node_view(node_id).position, authored_positions[node_id], "%s authored position survives content fit" % node_id, failures)
			TestAssertions.truthy(canvas_rect.encloses(canvas.node_control(node_id).get_rect()), "%s fitted control remains inside the canvas" % node_id, failures)

		canvas.rebuild([], [])
		canvas.set_zoom(1.25)
		canvas.set_pan(Vector2(17, -23))
		TestAssertions.truthy(not bool(canvas.call(&"fit_to_content")), "empty canvas rejects content fit", failures)
		TestAssertions.equal(canvas.zoom_value(), 1.25, "empty fit leaves zoom unchanged", failures)
		TestAssertions.equal(canvas.pan_value(), Vector2(17, -23), "empty fit leaves pan unchanged", failures)

		var zero_canvas := PassiveTreeCanvas.new()
		zero_canvas.size = Vector2.ZERO
		zero_canvas.rebuild(views, [])
		zero_canvas.set_zoom(1.5)
		zero_canvas.set_pan(Vector2(-9, 11))
		TestAssertions.truthy(not bool(zero_canvas.call(&"fit_to_content")), "zero-sized canvas rejects content fit", failures)
		TestAssertions.equal(zero_canvas.zoom_value(), 1.5, "zero-sized fit leaves zoom unchanged", failures)
		TestAssertions.equal(zero_canvas.pan_value(), Vector2(-9, 11), "zero-sized fit leaves pan unchanged", failures)
		zero_canvas.free()

		var cramped_canvas := PassiveTreeCanvas.new()
		cramped_canvas.size = Vector2(100, 100)
		cramped_canvas.rebuild(views, [])
		cramped_canvas.set_zoom(1.75)
		cramped_canvas.set_pan(Vector2(5, 7))
		TestAssertions.truthy(not bool(cramped_canvas.call(&"fit_to_content", Vector2(24, 24))), "nonpositive available space rejects content fit", failures)
		TestAssertions.equal(cramped_canvas.zoom_value(), 1.75, "cramped fit leaves zoom unchanged", failures)
		TestAssertions.equal(cramped_canvas.pan_value(), Vector2(5, 7), "cramped fit leaves pan unchanged", failures)
		cramped_canvas.free()
	canvas.free()


func _test_screen_invalid_safe_state_and_geometry(failures: Array[String]) -> void:
	var screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.call(&"_ready")
	var viewport := screen.get_viewport()
	if viewport == null:
		viewport = (Engine.get_main_loop() as SceneTree).root
	TestAssertions.equal(screen.get("_observed_viewport"), viewport, "screen observes its live viewport", failures)
	TestAssertions.truthy(viewport != null, "screen has a live viewport for responsive layout", failures)
	if viewport != null:
		TestAssertions.truthy(viewport.size_changed.is_connected(Callable(screen, "_on_viewport_size_changed")), "screen wires live viewport size changes", failures)
		var initial_size := viewport.get_visible_rect().size
		_assert_actual_layout(screen, initial_size, "initial viewport", failures)
	screen.call(&"configure", null, null, null, null, false)
	screen.call(&"open")
	TestAssertions.truthy(screen.call(&"is_open"), "invalid catalog still opens a safe screen", failures)
	TestAssertions.equal(_label(screen, "Status").text, "City passive tree unavailable", "invalid catalog has the exact safe status", failures)
	TestAssertions.equal((screen.find_child("Canvas", true, false).call(&"node_ids") as Array).size(), 0, "invalid catalog creates no nodes", failures)
	TestAssertions.truthy(_button(screen, "AllocateButton").disabled and _button(screen, "RefundButton").disabled, "invalid catalog disables mutations", failures)
	for size: Vector2 in [Vector2(1920, 1080), Vector2(2560, 1440), Vector2(3840, 2160)]:
		screen.call(&"apply_viewport_size", size)
		_assert_actual_layout(screen, size, "explicit %s" % size, failures)
		var geometry := screen.call(&"layout_snapshot", size) as Dictionary
		TestAssertions.truthy((geometry["frame"] as Rect2).size.x > 0 and (geometry["frame"] as Rect2).size.y > 0, "screen frame has positive geometry at %s" % size, failures)
		for key: String in ["canvas", "detail", "points", "confirmation"]:
			TestAssertions.truthy((geometry["frame"] as Rect2).encloses(geometry[key] as Rect2), "%s remains inside the frame at %s" % [key, size], failures)
	screen.call(&"close")
	screen.free()


func _test_lifecycle_pause_ownership_and_focus(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var focus_host := CanvasLayer.new()
	tree.root.add_child(focus_host)
	var return_focus := Button.new()
	return_focus.name = "ReturnFocus"
	return_focus.process_mode = Node.PROCESS_MODE_ALWAYS
	return_focus.size = Vector2(120, 40)
	focus_host.add_child(return_focus)
	var screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate()
	tree.root.add_child(screen)
	screen.call(&"_ready")
	var close_count := [0]
	screen.connect(&"tree_closed", func() -> void: close_count[0] += 1)
	var external := RunPauseLease.new()
	external.acquire(tree)
	screen.call(&"configure", null, null, null, null, false)
	screen.call(&"open", return_focus)
	TestAssertions.truthy(tree.paused, "opening acquires a pause lease", failures)
	screen.call(&"close")
	TestAssertions.truthy(tree.paused and external.is_active(), "closing releases only the screen pause lease", failures)
	TestAssertions.equal(close_count[0], 1, "closing emits one stable tree_closed event", failures)
	TestAssertions.truthy(is_instance_valid(return_focus) and screen.get("_return_focus") == null, "closing consumes its valid return-focus target", failures)
	external.release(tree)
	TestAssertions.truthy(not tree.paused, "last owner restores the original unpaused state", failures)
	tree.paused = true
	screen.call(&"open")
	screen.call(&"close")
	TestAssertions.truthy(tree.paused, "screen preserves a pre-existing pause", failures)
	tree.paused = false
	screen.call(&"open")
	screen.free()
	TestAssertions.truthy(not tree.paused, "predelete releases the screen's active lease", failures)
	focus_host.free()
	var freed_focus := Button.new()
	var freed_screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate()
	tree.root.add_child(freed_screen)
	freed_screen.call(&"_ready")
	freed_screen.call(&"configure", null, null, null, null, false)
	tree.root.add_child(freed_focus)
	freed_screen.call(&"open", freed_focus)
	freed_focus.free()
	freed_screen.call(&"close")
	TestAssertions.truthy(not freed_screen.call(&"is_open"), "closing ignores a freed return-focus target", failures)
	freed_screen.free()


func _test_screen_obscured_nonleak(failures: Array[String]) -> void:
	var root := _case_root("obscured")
	var store := ProfileStore.new()
	var tree := _obscured_tree()
	var profile := ProfileState.new_profile("obscured-profile", "Obscured", 1000)
	profile.discovered_trees = [String(tree.id)]
	profile.tree_allocations[String(tree.id)] = ["root"]
	profile.passive_points_available = 4
	profile.passive_points_lifetime_earned = 4
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "obscured fixture saves", failures)
	var manager := ProfileManager.new()
	TestAssertions.equal(manager.bootstrap(root), "", "obscured manager bootstraps", failures)
	var services := _services(store)
	var screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.call(&"_ready")
	screen.call(&"configure", tree, manager, services["mutations"], services["view_model"], false, root)
	screen.call(&"open")
	var canvas := screen.find_child("Canvas", true, false)
	TestAssertions.truthy(canvas.call(&"select_node", &"hidden"), "obscured node remains selectable by stable ID", failures)
	var surfaces := _control_surface_text(screen)
	for hidden_text: String in ["Vault Secret", "Do not leak this description", "Experience Gain", "Requires allocated node", "Allocated Node", "Secret Metadata", "Coming Soon", "Developer Preview", "73"]:
		TestAssertions.truthy(not surfaces.contains(hidden_text), "obscured screen does not expose %s" % hidden_text, failures)
	TestAssertions.equal(_label(screen, "DetailTitle").text, "???", "obscured detail title is redacted", failures)
	TestAssertions.equal(_label(screen, "DetailDescription").text, "???", "obscured detail description is redacted", failures)
	TestAssertions.equal(_label(screen, "DetailSections").text, "", "obscured detail reveals no cost, refund, or development presentation", failures)
	TestAssertions.truthy(_button(screen, "AllocateButton").disabled and _button(screen, "RefundButton").disabled, "obscured detail disables mutations", failures)
	screen.call(&"close")
	screen.free()
	ProfileTestSupport.remove_tree(root)


func _test_confirmation_real_mutation_refresh_and_errors(failures: Array[String]) -> void:
	var root := _case_root("mutation")
	var store := ProfileStore.new()
	var tree := _mutation_tree()
	var profile := ProfileState.new_profile("screen-profile", "Screen Tester", 1000)
	profile.discovered_trees = [String(tree.id)]
	profile.tree_allocations[String(tree.id)] = ["root"]
	profile.passive_points_available = 2
	profile.passive_points_lifetime_earned = 2
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "screen mutation fixture saves", failures)
	var manager := ProfileManager.new()
	TestAssertions.equal(manager.bootstrap(root), "", "screen mutation manager bootstraps", failures)
	var services := _services(store)
	var screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.call(&"_ready")
	screen.call(&"configure", tree, manager, services["mutations"], services["view_model"], false, root)
	screen.call(&"open")
	var canvas := screen.find_child("Canvas", true, false)
	TestAssertions.truthy(canvas.call(&"select_node", &"target"), "target can be explicitly selected", failures)
	TestAssertions.truthy(not _button(screen, "AllocateButton").disabled, "selected target exposes allocation", failures)
	TestAssertions.truthy(not _button(screen, "AllocateButton").get_signal_connection_list(&"pressed").is_empty(), "allocation action is wired", failures)
	var selected_title := _label(screen, "DetailTitle").text
	(canvas.call(&"node_control", &"target") as Control).mouse_exited.emit()
	TestAssertions.equal(_label(screen, "DetailTitle").text, selected_title, "detail remains stable after pointer exit", failures)
	_button(screen, "AllocateButton").pressed.emit()
	TestAssertions.truthy((screen.find_child("Confirmation", true, false) as Control).visible, "allocation requires explicit confirmation", failures)
	TestAssertions.equal(store.load_profile("screen-profile", root).profile.passive_points_available, 2, "opening confirmation performs no mutation", failures)
	_button(screen, "CancelButton").pressed.emit()
	TestAssertions.equal(store.load_profile("screen-profile", root).profile.passive_points_available, 2, "cancel performs no mutation", failures)
	_button(screen, "AllocateButton").pressed.emit()
	_button(screen, "ConfirmButton").pressed.emit()
	var refreshed := manager.active_profile()
	TestAssertions.equal(refreshed.passive_points_available, 1, "confirmed allocation atomically refreshes active profile points", failures)
	TestAssertions.truthy("target" in refreshed.tree_allocations[String(tree.id)], "confirmed allocation refreshes saved allocations", failures)
	TestAssertions.equal(canvas.call(&"selected_node_id"), &"target", "successful rebuild retains selected node", failures)
	TestAssertions.equal(_label(screen, "Points").text, "Passive Points: 1 / 2", "successful rebuild refreshes points header", failures)
	TestAssertions.equal(_label(screen, "Status").text, "Allocated Target.", "successful allocation has stable status", failures)
	_button(screen, "RefundButton").pressed.emit()
	TestAssertions.truthy((screen.find_child("Confirmation", true, false) as Control).visible, "refund requires explicit confirmation", failures)
	_button(screen, "ConfirmButton").pressed.emit()
	TestAssertions.equal(_label(screen, "Status").text, PassiveTreeProgressionService.MESSAGES[&"respec_service_required"], "refund decision error is displayed exactly", failures)
	TestAssertions.truthy(screen.call(&"is_open") and not _button(screen, "RefundButton").disabled and not _button(screen, "CloseButton").disabled, "decision failure leaves the screen usable", failures)
	screen.call(&"close")
	screen.free()
	ProfileTestSupport.remove_tree(root)


func _test_exact_save_error_surface(failures: Array[String]) -> void:
	var root := _case_root("save_error")
	var tree := _mutation_tree()
	var good_store := ProfileStore.new()
	var profile := ProfileState.new_profile("save-error-profile", "Save Error", 1000)
	profile.discovered_trees = [String(tree.id)]
	profile.tree_allocations[String(tree.id)] = ["root"]
	profile.passive_points_available = 2
	profile.passive_points_lifetime_earned = 2
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(good_store.save_profile(profile, root), "", "save-error fixture saves through the good store", failures)
	var manager := ProfileManager.new()
	TestAssertions.equal(manager.bootstrap(root), "", "save-error manager bootstraps", failures)
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var services := _services(failing_store)
	var expected := (services["mutations"] as PassiveTreeMutationService).allocate(profile.profile_id, "preflight-save-error", tree, &"target", false, root).error
	TestAssertions.truthy(expected.begins_with("JSON_STORE_SAVE_ERROR") and expected.contains("stage=promote"), "save-error fixture produces exact atomic diagnostics", failures)
	var screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.call(&"_ready")
	screen.call(&"configure", tree, manager, services["mutations"], services["view_model"], false, root)
	screen.call(&"open")
	var canvas := screen.find_child("Canvas", true, false)
	canvas.call(&"select_node", &"target")
	_button(screen, "AllocateButton").pressed.emit()
	_button(screen, "ConfirmButton").pressed.emit()
	TestAssertions.equal(_label(screen, "Status").text, expected, "atomic save error is displayed exactly", failures)
	TestAssertions.equal(manager.active_profile().passive_points_available, 2, "save failure leaves manager and screen profile unchanged", failures)
	TestAssertions.truthy(screen.call(&"is_open") and not _button(screen, "AllocateButton").disabled, "save failure leaves mutation controls usable", failures)
	screen.call(&"close")
	screen.free()
	ProfileTestSupport.remove_tree(root)


func _test_confirmation_captures_allocation_and_refund_targets(failures: Array[String]) -> void:
	var allocation_root := _case_root("captured_allocate")
	var tree := _mutation_tree()
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("captured-allocate", "Captured Allocate", 1000)
	profile.discovered_trees = [String(tree.id)]
	profile.tree_allocations[String(tree.id)] = ["root"]
	profile.passive_points_available = 2
	profile.passive_points_lifetime_earned = 2
	ProfileTestSupport.remove_tree(allocation_root)
	TestAssertions.equal(store.save_profile(profile, allocation_root), "", "captured allocation fixture saves", failures)
	var manager := ProfileManager.new()
	TestAssertions.equal(manager.bootstrap(allocation_root), "", "captured allocation manager bootstraps", failures)
	var services := _services(store)
	var screen := _configured_screen(tree, manager, services, false, allocation_root)
	var canvas := screen.find_child("Canvas", true, false)
	canvas.call(&"select_node", &"target")
	_button(screen, "AllocateButton").pressed.emit()
	TestAssertions.equal(screen.get("_pending_node_id"), &"target", "allocation confirmation captures the requested node", failures)
	TestAssertions.truthy(_is_visible(screen, "ConfirmationBlocker"), "allocation confirmation shows the input blocker", failures)
	canvas.call(&"select_node", &"other")
	_button(screen, "ConfirmButton").pressed.emit()
	var allocated := manager.active_profile()
	TestAssertions.truthy("target" in allocated.tree_allocations[String(tree.id)], "confirmation allocates the captured node", failures)
	TestAssertions.truthy("other" not in allocated.tree_allocations[String(tree.id)], "selection changes cannot redirect allocation", failures)
	TestAssertions.equal(canvas.call(&"selected_node_id"), &"target", "successful allocation rebuild restores the captured target", failures)
	screen.call(&"close")
	screen.free()
	ProfileTestSupport.remove_tree(allocation_root)

	var refund_root := _case_root("captured_refund")
	var refund_profile := ProfileState.new_profile("captured-refund", "Captured Refund", 1000)
	refund_profile.discovered_trees = [String(tree.id)]
	refund_profile.tree_allocations[String(tree.id)] = ["root", "target", "other"]
	refund_profile.passive_points_available = 0
	refund_profile.passive_points_lifetime_earned = 2
	ProfileTestSupport.remove_tree(refund_root)
	TestAssertions.equal(store.save_profile(refund_profile, refund_root), "", "captured refund fixture saves", failures)
	var refund_manager := ProfileManager.new()
	TestAssertions.equal(refund_manager.bootstrap(refund_root), "", "captured refund manager bootstraps", failures)
	var refund_screen := _configured_screen(tree, refund_manager, services, true, refund_root)
	var refund_canvas := refund_screen.find_child("Canvas", true, false)
	refund_canvas.call(&"select_node", &"target")
	_button(refund_screen, "RefundButton").pressed.emit()
	TestAssertions.equal(refund_screen.get("_pending_node_id"), &"target", "refund confirmation captures the requested node", failures)
	refund_canvas.call(&"select_node", &"other")
	_button(refund_screen, "ConfirmButton").pressed.emit()
	var refunded := refund_manager.active_profile()
	TestAssertions.truthy("target" not in refunded.tree_allocations[String(tree.id)], "confirmation refunds the captured node", failures)
	TestAssertions.truthy("other" in refunded.tree_allocations[String(tree.id)], "selection changes cannot redirect refund", failures)
	TestAssertions.equal(refund_canvas.call(&"selected_node_id"), &"target", "successful refund rebuild restores the captured target", failures)
	refund_screen.call(&"close")
	refund_screen.free()
	ProfileTestSupport.remove_tree(refund_root)


func _test_confirmation_invalidation_and_clear_contract(failures: Array[String]) -> void:
	var root := _case_root("confirmation_invalidation")
	var tree := _mutation_tree()
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("confirmation-invalid", "Confirmation Invalid", 1000)
	profile.discovered_trees = [String(tree.id)]
	profile.tree_allocations[String(tree.id)] = ["root"]
	profile.passive_points_available = 2
	profile.passive_points_lifetime_earned = 2
	ProfileTestSupport.remove_tree(root)
	TestAssertions.equal(store.save_profile(profile, root), "", "confirmation invalidation fixture saves", failures)
	var manager := ProfileManager.new()
	TestAssertions.equal(manager.bootstrap(root), "", "confirmation invalidation manager bootstraps", failures)
	var services := _services(store)
	var screen := _configured_screen(tree, manager, services, false, root)
	var canvas := screen.find_child("Canvas", true, false)
	canvas.call(&"select_node", &"target")
	_button(screen, "AllocateButton").pressed.emit()
	((screen.get("_views") as Dictionary)[&"target"] as PassiveTreeNodeViewData).allocatable = false
	_button(screen, "ConfirmButton").pressed.emit()
	TestAssertions.truthy("target" not in manager.active_profile().tree_allocations[String(tree.id)], "invalidated captured allocation is rejected before mutation", failures)
	TestAssertions.truthy(screen.call(&"is_open") and not (screen.find_child("Confirmation", true, false) as Control).visible, "invalidated confirmation fails closed and keeps the screen usable", failures)
	TestAssertions.truthy(not _is_visible(screen, "ConfirmationBlocker"), "invalidated confirmation hides the blocker", failures)

	screen.call(&"_rebuild", &"target")
	canvas.call(&"select_node", &"target")
	_button(screen, "AllocateButton").pressed.emit()
	_button(screen, "CancelButton").pressed.emit()
	_assert_confirmation_cleared(screen, "cancel", failures)
	_button(screen, "AllocateButton").pressed.emit()
	screen.call(&"_rebuild", &"target")
	_assert_confirmation_cleared(screen, "rebuild", failures)
	_button(screen, "AllocateButton").pressed.emit()
	screen.call(&"configure", tree, manager, services["mutations"], services["view_model"], false, root)
	_assert_confirmation_cleared(screen, "configure", failures)
	screen.call(&"close")
	screen.free()
	ProfileTestSupport.remove_tree(root)


func _view(id: StringName, position: Vector2, state: StringName = &"allocatable") -> PassiveTreeNodeViewData:
	return PassiveTreeNodeViewData.new(id, position, &"small", state, String(id), "%s description" % id, 1, "1", ["Effect"], [], [], {}, false, state == &"allocated", state == &"allocatable", &"ok", "Action is available.")


func _mutation_tree() -> PassiveTreeDefinition:
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"root", &"start", Vector2.ZERO, "Root", "Root description", 0),
		PassiveTreeNode.new(&"target", &"small", Vector2(140, 0), "Target", "Target description", 1, [], null, [], [], {"activationState": "implemented"}),
		PassiveTreeNode.new(&"other", &"small", Vector2(-140, 0), "Other", "Other description", 1),
		PassiveTreeNode.new(&"future", &"small", Vector2(0, 140), "Future", "Future description", 1, [], null, [], [], {"activationState": "future"}),
	]
	var connections: Array[PassiveTreeConnection] = [
		PassiveTreeConnection.new(&"root-target", &"root", &"target", &"bidirectional"),
		PassiveTreeConnection.new(&"root-other", &"root", &"other", &"bidirectional"),
		PassiveTreeConnection.new(&"root-future", &"root", &"future", &"bidirectional"),
	]
	var starts: Array[StringName] = [&"root"]
	return PassiveTreeDefinition.new(&"screen-tree", "Screen Tree", starts, nodes, connections)


func _obscured_tree() -> PassiveTreeDefinition:
	var hidden_effects: Array[PassiveTreeEffect] = [PassiveTreeEffect.new(&"experience_gain", &"add_percent", 99, {"scope": "all_run_experience"})]
	var hidden_requirements: Array[PassiveTreeRequirement] = [PassiveTreeRequirement.new(&"allocated_node", &"contains", "two", {"treeId": "obscured-tree"})]
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"root", &"start", Vector2.ZERO, "Root", "Root", 0),
		PassiveTreeNode.new(&"one", &"small", Vector2(100, 0), "One", "One", 1),
		PassiveTreeNode.new(&"two", &"small", Vector2(200, 0), "Two", "Two", 1),
		PassiveTreeNode.new(&"hidden", &"keystone", Vector2(300, 0), "Vault Secret", "Do not leak this description", 73, [], null, hidden_effects, hidden_requirements, {"secret": "Secret Metadata", "integrationStatus": "future-contract", "refundPolicy": "permanent"}),
	]
	var connections: Array[PassiveTreeConnection] = [
		PassiveTreeConnection.new(&"root-one", &"root", &"one", &"bidirectional"),
		PassiveTreeConnection.new(&"one-two", &"one", &"two", &"bidirectional"),
		PassiveTreeConnection.new(&"two-hidden", &"two", &"hidden", &"bidirectional"),
	]
	var starts: Array[StringName] = [&"root"]
	return PassiveTreeDefinition.new(&"obscured-tree", "Obscured Tree", starts, nodes, connections)


func _services(store: ProfileStore) -> Dictionary:
	var effects := PassiveEffectRegistry.new()
	var requirements := PassiveRequirementRegistry.new()
	var progression := PassiveTreeProgressionService.new(effects, requirements)
	return {
		"mutations": PassiveTreeMutationService.new(ProfileMutationService.new(store), progression, PassiveEffectResolver.new(effects)),
		"view_model": PassiveTreeViewModel.new(progression, PassiveEffectResolver.new(effects), effects, requirements),
	}


func _case_root(label: String) -> String:
	_root_counter += 1
	return "user://tests/passive_tree_screen_%s_%d_%d_%d" % [label, OS.get_process_id(), Time.get_ticks_usec(), _root_counter]


func _configured_screen(tree: PassiveTreeDefinition, manager: ProfileManager, services: Dictionary, developer_context: bool, root: String) -> CanvasLayer:
	var screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate() as CanvasLayer
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.call(&"_ready")
	screen.call(&"configure", tree, manager, services["mutations"], services["view_model"], developer_context, root)
	screen.call(&"open")
	return screen


func _assert_confirmation_cleared(screen: CanvasLayer, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(screen.get("_pending_action"), "", "%s clears pending action" % label, failures)
	TestAssertions.equal(screen.get("_pending_node_id"), &"", "%s clears pending node" % label, failures)
	TestAssertions.equal(_label(screen, "ConfirmationText").text, "", "%s clears confirmation text" % label, failures)
	TestAssertions.truthy(not _is_visible(screen, "Confirmation") and not _is_visible(screen, "ConfirmationBlocker"), "%s hides dialog and blocker" % label, failures)


func _assert_actual_layout(screen: CanvasLayer, size: Vector2, label: String, failures: Array[String]) -> void:
	var compact := size.x < 1600.0 or size.y < 900.0
	var frame := screen.find_child("Frame", true, false) as Control
	var body := screen.find_child("Body", true, false) as SplitContainer
	TestAssertions.equal(Vector2(frame.offset_left, frame.offset_top), Vector2(20, 16) if compact else Vector2(48, 36), "%s applies actual frame leading offsets" % label, failures)
	TestAssertions.equal(Vector2(frame.offset_right, frame.offset_bottom), Vector2(-20, -16) if compact else Vector2(-48, -36), "%s applies actual frame trailing offsets" % label, failures)
	var horizontal_margins := 40.0 if compact else 96.0
	TestAssertions.equal(body.split_offset, int(maxf(560.0, (size.x - horizontal_margins) * 0.68)), "%s applies actual body split" % label, failures)


func _is_visible(root: Node, name: String) -> bool:
	var control := root.find_child(name, true, false) as Control
	return control != null and control.visible


func _button(root: Node, name: String) -> Button:
	return root.find_child(name, true, false) as Button


func _label(root: Node, name: String) -> Label:
	return root.find_child(name, true, false) as Label


func _has_line_child(root: Node) -> bool:
	for child: Node in root.get_children():
		if child is Line2D:
			return true
	return false


func _control_surface_text(root: Node) -> String:
	var result := ""
	if root is Control:
		var control := root as Control
		result += control.tooltip_text
		if control is BaseButton:
			result += (control as BaseButton).text
		if control is Label:
			result += (control as Label).text
		var accessible: Variant = control.get("accessibility_description")
		if accessible != null:
			result += String(accessible)
	for child: Node in root.get_children():
		result += _control_surface_text(child)
	return result
