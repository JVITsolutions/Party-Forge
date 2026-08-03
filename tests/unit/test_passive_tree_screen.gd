extends RefCounted

const NODE_SCENE_PATH := "res://scenes/ui/passive_tree/passive_tree_node_control.tscn"
const SCREEN_SCENE_PATH := "res://scenes/ui/passive_tree/passive_tree_screen.tscn"
const NODE_SCRIPT_PATH := "res://scripts/ui/passive_tree/passive_tree_node_control.gd"
const SCREEN_SCRIPT_PATH := "res://scripts/ui/passive_tree/passive_tree_screen.gd"
const CANVAS_SCRIPT_PATH := "res://scripts/ui/passive_tree/passive_tree_canvas.gd"

var _root_counter := 0


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_scene_and_type_contracts(failures)
	if load(SCREEN_SCENE_PATH) == null or load(NODE_SCENE_PATH) == null:
		return failures
	_test_node_control_copy_activation_and_redaction(failures)
	_test_canvas_copy_draw_zoom_pan_and_navigation(failures)
	_test_screen_invalid_safe_state_and_geometry(failures)
	_test_screen_obscured_nonleak(failures)
	_test_lifecycle_pause_ownership_and_focus(failures)
	_test_confirmation_real_mutation_refresh_and_errors(failures)
	_test_exact_save_error_surface(failures)
	return failures


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
		for required_name: String in ["Overlay", "Frame", "Title", "Points", "Canvas", "DetailTitle", "DetailDescription", "DetailScroll", "DetailBody", "Status", "AllocateButton", "RefundButton", "Confirmation", "ConfirmButton", "CancelButton", "CloseButton"]:
			TestAssertions.truthy(screen.find_child(required_name, true, false) != null, "screen exposes stable node %s" % required_name, failures)
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


func _test_screen_invalid_safe_state_and_geometry(failures: Array[String]) -> void:
	var screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.call(&"_ready")
	screen.call(&"configure", null, null, null, null, false)
	screen.call(&"open")
	TestAssertions.truthy(screen.call(&"is_open"), "invalid catalog still opens a safe screen", failures)
	TestAssertions.equal(_label(screen, "Status").text, "City passive tree unavailable", "invalid catalog has the exact safe status", failures)
	TestAssertions.equal((screen.find_child("Canvas", true, false).call(&"node_ids") as Array).size(), 0, "invalid catalog creates no nodes", failures)
	TestAssertions.truthy(_button(screen, "AllocateButton").disabled and _button(screen, "RefundButton").disabled, "invalid catalog disables mutations", failures)
	for size: Vector2 in [Vector2(1920, 1080), Vector2(2560, 1440), Vector2(3840, 2160)]:
		screen.call(&"apply_viewport_size", size)
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
	for hidden_text: String in ["Vault Secret", "Do not leak this description", "Experience Gain", "Requires allocated node", "Allocated Node", "Secret Metadata", "73"]:
		TestAssertions.truthy(not surfaces.contains(hidden_text), "obscured screen does not expose %s" % hidden_text, failures)
	TestAssertions.equal(_label(screen, "DetailTitle").text, "???", "obscured detail title is redacted", failures)
	TestAssertions.equal(_label(screen, "DetailDescription").text, "???", "obscured detail description is redacted", failures)
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


func _view(id: StringName, position: Vector2, state: StringName = &"allocatable") -> PassiveTreeNodeViewData:
	return PassiveTreeNodeViewData.new(id, position, &"small", state, String(id), "%s description" % id, 1, "1", ["Effect"], [], [], {}, false, state == &"allocated", state == &"allocatable", &"ok", "Action is available.")


func _mutation_tree() -> PassiveTreeDefinition:
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"root", &"start", Vector2.ZERO, "Root", "Root description", 0),
		PassiveTreeNode.new(&"target", &"small", Vector2(140, 0), "Target", "Target description", 1),
	]
	var connections: Array[PassiveTreeConnection] = [PassiveTreeConnection.new(&"root-target", &"root", &"target", &"bidirectional")]
	var starts: Array[StringName] = [&"root"]
	return PassiveTreeDefinition.new(&"screen-tree", "Screen Tree", starts, nodes, connections)


func _obscured_tree() -> PassiveTreeDefinition:
	var hidden_effects: Array[PassiveTreeEffect] = [PassiveTreeEffect.new(&"experience_gain", &"add_percent", 99, {"scope": "all_run_experience"})]
	var hidden_requirements: Array[PassiveTreeRequirement] = [PassiveTreeRequirement.new(&"allocated_node", &"contains", "two", {"treeId": "obscured-tree"})]
	var nodes: Array[PassiveTreeNode] = [
		PassiveTreeNode.new(&"root", &"start", Vector2.ZERO, "Root", "Root", 0),
		PassiveTreeNode.new(&"one", &"small", Vector2(100, 0), "One", "One", 1),
		PassiveTreeNode.new(&"two", &"small", Vector2(200, 0), "Two", "Two", 1),
		PassiveTreeNode.new(&"hidden", &"keystone", Vector2(300, 0), "Vault Secret", "Do not leak this description", 73, [], null, hidden_effects, hidden_requirements, {"secret": "Secret Metadata"}),
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
