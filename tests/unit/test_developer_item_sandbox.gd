extends RefCounted

const SANDBOX_SCRIPT_PATH := "res://scripts/ui/developer_item_sandbox.gd"
const SANDBOX_SCENE_PATH := "res://scenes/ui/developer_item_sandbox.tscn"
const MAIN_SCENE_PATH := "res://scenes/game/main.tscn"
const DOCUMENT_PATH := "user://developer_item_sandbox/sandbox.json"
const SANDBOX_ROOT := "user://developer_item_sandbox"
const INVENTORY_ID := &"developer-inventory"
const STASH_ID := &"developer-stash-000"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(SANDBOX_SCRIPT_PATH), "developer item sandbox script exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(SANDBOX_SCENE_PATH), "developer item sandbox scene exists", failures)
	if not failures.is_empty():
		return failures
	var packed := load(SANDBOX_SCENE_PATH) as PackedScene
	TestAssertions.truthy(packed != null, "developer item sandbox scene loads", failures)
	if packed == null:
		return failures
	_cleanup_sandbox_files()
	_test_modal_contract(packed, failures)
	_cleanup_sandbox_files()
	_test_failure_atomic_ui(packed, failures)
	_cleanup_sandbox_files()
	_test_main_route_and_profile_isolation(failures)
	_cleanup_sandbox_files()
	return failures


func _test_modal_contract(packed: PackedScene, failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var sandbox: Variant = packed.instantiate()
	tree.root.add_child(sandbox)
	var return_focus := Button.new()
	return_focus.name = "SandboxReturnFocus"
	tree.root.add_child(return_focus)
	sandbox.call(&"_ready")
	TestAssertions.equal(sandbox.layer, 14, "sandbox renders at exact layer 14", failures)
	TestAssertions.equal(sandbox.process_mode, Node.PROCESS_MODE_ALWAYS, "sandbox processes while paused", failures)
	TestAssertions.truthy(not sandbox.visible, "sandbox starts hidden", failures)
	var overlay := sandbox.get_node_or_null("Overlay") as Control
	var frame := sandbox.get_node_or_null("Overlay/Frame") as Control
	TestAssertions.truthy(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "sandbox overlay blocks pointer input behind it", failures)
	TestAssertions.truthy(frame != null, "sandbox owns a safe-margin frame", failures)
	if frame != null:
		for viewport_size: Vector2 in [Vector2(1920, 1080), Vector2(2560, 1440), Vector2(3840, 2160)]:
			var top_left := Vector2(viewport_size.x * frame.anchor_left + frame.offset_left, viewport_size.y * frame.anchor_top + frame.offset_top)
			var bottom_right := Vector2(viewport_size.x * frame.anchor_right + frame.offset_right, viewport_size.y * frame.anchor_bottom + frame.offset_bottom)
			TestAssertions.truthy(top_left.x >= 32.0 and top_left.y >= 24.0, "sandbox keeps top-left safe margins at %s" % viewport_size, failures)
			TestAssertions.truthy(bottom_right.x <= viewport_size.x - 32.0 and bottom_right.y <= viewport_size.y - 24.0, "sandbox keeps bottom-right safe margins at %s" % viewport_size, failures)
	var inventory_grid := sandbox.get_node_or_null("Overlay/Frame/Layout/Body/InventoryPanel/InventorySlots") as GridContainer
	var stash_scroll := sandbox.get_node_or_null("Overlay/Frame/Layout/Body/StashPanel/StashScroll") as ScrollContainer
	var stash_grid := sandbox.get_node_or_null("Overlay/Frame/Layout/Body/StashPanel/StashScroll/StashSlots") as GridContainer
	var tooltip := sandbox.get_node_or_null("Overlay/ItemTooltip") as Control
	var control_hints := sandbox.get_node_or_null("Overlay/Frame/Layout/ControlHints") as Label
	TestAssertions.truthy(inventory_grid != null and inventory_grid.get_child_count() == 5, "sandbox owns exactly five inventory slot buttons", failures)
	TestAssertions.truthy(stash_grid != null and stash_grid.columns == 10 and stash_grid.get_child_count() == 100, "sandbox owns exactly 100 stash slots in ten columns", failures)
	TestAssertions.truthy(stash_scroll != null and stash_scroll.follow_focus, "stash grid is scrollable and follows controller focus", failures)
	TestAssertions.truthy(sandbox.get_node_or_null("Overlay/Frame/Layout/Body/InspectorPanel") == null, "sandbox removes the persistent inspector column", failures)
	TestAssertions.truthy(tooltip != null, "sandbox owns the shared item tooltip overlay", failures)
	TestAssertions.truthy(control_hints != null and control_hints.text.contains("drag") and control_hints.text.contains("X / Square") and control_hints.text.contains("A / Cross"), "sandbox shows mouse and controller held-item hints", failures)
	TestAssertions.truthy(sandbox.has_signal(&"held_item_changed"), "sandbox exposes exact held-item state changes", failures)
	TestAssertions.truthy(InputMap.has_action(&"item_sandbox_pickup"), "sandbox registers a dedicated pickup action", failures)
	if InputMap.has_action(&"item_sandbox_pickup"):
		TestAssertions.truthy(InputMap.action_get_events(&"item_sandbox_pickup").any(func(event: InputEvent) -> bool:
			return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_X
		), "west/left controller face button maps to sandbox pickup", failures)
	for path: NodePath in [
		^"Overlay/Frame/Layout/Header/Status",
		^"Overlay/Frame/Layout/Header/Close",
		^"Overlay/Frame/Layout/Actions/FirstEmptyInventory",
		^"Overlay/Frame/Layout/Actions/FirstEmptyStash",
		^"Overlay/Frame/Layout/Actions/Save",
		^"Overlay/Frame/Layout/Actions/Reload",
		^"Overlay/Frame/Layout/Actions/IntegrityScan",
		^"Overlay/Frame/Layout/Actions/Reset",
	]:
		TestAssertions.truthy(sandbox.get_node_or_null(path) is Control, "sandbox exposes required control %s" % path, failures)
	if inventory_grid == null or stash_grid == null:
		sandbox.free()
		return_focus.free()
		return
	for index: int in inventory_grid.get_child_count():
		_assert_slot_metadata(inventory_grid.get_child(index) as Button, INVENTORY_ID, index, failures)
	for index: int in stash_grid.get_child_count():
		_assert_slot_metadata(stash_grid.get_child(index) as Button, STASH_ID, index, failures)

	TestAssertions.truthy(bool(sandbox.call(&"open", return_focus)), "sandbox opens a usable isolated fixture", failures)
	TestAssertions.truthy(sandbox.visible, "sandbox open makes only its layer visible", failures)
	var initial_projection: Dictionary = sandbox.call(&"projection")
	TestAssertions.equal(int(initial_projection.get("schema_version", 0)), 1, "sandbox exposes a defensive state projection", failures)
	initial_projection["owner_id"] = "mutated-ui-copy"
	TestAssertions.equal(String((sandbox.call(&"projection") as Dictionary).get("owner_id", "")), "developer-item-sandbox", "UI projection cannot mutate domain state", failures)
	var inventory_zero := inventory_grid.get_child(0) as Button
	var inventory_one := inventory_grid.get_child(1) as Button
	var stash_zero := stash_grid.get_child(0) as Button
	var stash_one := stash_grid.get_child(1) as Button
	var stash_two := stash_grid.get_child(2) as Button
	var held_events: Array[Dictionary] = []
	if sandbox.has_signal(&"held_item_changed"):
		sandbox.connect(&"held_item_changed", func(held: bool, container_id: StringName, slot: int) -> void:
			held_events.append({"held": held, "container_id": container_id, "slot": slot})
		)
	TestAssertions.truthy(not inventory_zero.disabled and not stash_zero.disabled, "slot buttons support keyboard and controller activation", failures)
	TestAssertions.equal(inventory_zero.text, "", "empty inventory cell has no rendered index or Empty label", failures)
	TestAssertions.truthy(inventory_zero.accessibility_name.contains("Empty storage slot"), "empty inventory cell remains accessible", failures)
	TestAssertions.equal(stash_one.text, "", "occupied sandbox cell is icon-only", failures)
	TestAssertions.truthy(stash_one.icon != null, "occupied sandbox cell renders the authored icon", failures)
	stash_one.focus_entered.emit()
	var focus_item_id := String((sandbox.call(&"selected_item") as Dictionary).get("instance_id", ""))
	TestAssertions.truthy(not focus_item_id.is_empty(), "focus alone updates the selected item", failures)
	stash_one.pressed.emit()
	var selected_item_id := String((sandbox.call(&"selected_item") as Dictionary).get("instance_id", ""))
	TestAssertions.truthy(not selected_item_id.is_empty(), "mouse click selects a populated slot", failures)
	TestAssertions.truthy(not bool(sandbox.call(&"is_holding_item")), "ordinary mouse click does not enter held-item mode", failures)
	if tooltip != null:
		TestAssertions.truthy(tooltip.visible, "focus opens the shared sandbox item tooltip", failures)
		var card := tooltip.get_node("Layout/BodyScroll/Cards").get_child(0) as Control
		TestAssertions.truthy((card.get_node("Layout/TechnicalToggle") as Button).visible, "sandbox tooltip exposes Developer Mode technical details", failures)
		card.call("set_technical_expanded", true)
		var technical_text := String(card.call("rendered_text"))
		for required_text: String in ["Instance ID:", "Base ID:", "Container:", "Slot:"]:
			TestAssertions.truthy(technical_text.contains(required_text), "sandbox tooltip renders %s" % required_text, failures)
	var drag_data: Variant = stash_one.call(&"_get_drag_data", Vector2.ZERO)
	TestAssertions.truthy(drag_data is Dictionary and bool(sandbox.call(&"is_holding_item")), "dragging a populated slot enters held-item mode", failures)
	var shared_held_state := stash_one.get_property_list().any(func(property: Dictionary) -> bool: return String(property.get("name", "")) == "_held")
	TestAssertions.truthy(shared_held_state and stash_one.get("_held") == true and bool(inventory_zero.get_meta("drop_target", false)), "held source and destinations show affordances", failures)
	TestAssertions.equal(stash_one.text, "", "held affordance never restores index/name text", failures)
	TestAssertions.truthy(bool(inventory_zero.call(&"_can_drop_data", Vector2.ZERO, drag_data)), "empty inventory slot accepts valid drag data", failures)
	inventory_zero.call(&"_drop_data", Vector2.ZERO, drag_data)
	TestAssertions.equal(String(inventory_zero.get_meta("item_id", "")), selected_item_id, "empty destination performs exact canonical move", failures)
	TestAssertions.truthy(not bool(sandbox.call(&"is_holding_item")), "successful drop clears held-item mode", failures)
	var swap_source_id := String(stash_zero.get_meta("item_id", ""))
	var swap_data: Variant = stash_zero.call(&"_get_drag_data", Vector2.ZERO)
	TestAssertions.truthy(bool(inventory_zero.call(&"_can_drop_data", Vector2.ZERO, swap_data)), "occupied slot accepts canonical swap drag", failures)
	inventory_zero.call(&"_drop_data", Vector2.ZERO, swap_data)
	TestAssertions.equal(String(inventory_zero.get_meta("item_id", "")), swap_source_id, "occupied destination receives the canonical swap source", failures)
	TestAssertions.equal(String(stash_zero.get_meta("item_id", "")), selected_item_id, "occupied destination item returns to the source slot", failures)
	TestAssertions.truthy(held_events.any(func(event: Dictionary) -> bool: return bool(event["held"])) and held_events.any(func(event: Dictionary) -> bool: return not bool(event["held"])), "mouse drag emits held start and clear state", failures)

	var before_cancel_projection: Dictionary = sandbox.call(&"projection")
	var before_cancel_bytes := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	var outside_drag: Variant = stash_two.call(&"_get_drag_data", Vector2.ZERO)
	TestAssertions.truthy(outside_drag is Dictionary and bool(sandbox.call(&"is_holding_item")), "outside-drop fixture begins a real drag", failures)
	sandbox.call(&"_finish_drag", false)
	TestAssertions.truthy(not bool(sandbox.call(&"is_holding_item")), "release outside clears held-item mode", failures)
	TestAssertions.equal(sandbox.call(&"projection"), before_cancel_projection, "release outside preserves the usable projection", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), before_cancel_bytes, "release outside preserves persisted bytes", failures)

	stash_two.focus_entered.emit()
	var controller_item_id := String(stash_two.get_meta("item_id", ""))
	var pickup := InputEventJoypadButton.new()
	pickup.button_index = JOY_BUTTON_X
	pickup.pressed = true
	TestAssertions.truthy(pickup.is_action_pressed(&"item_sandbox_pickup"), "west face input resolves through the dedicated action", failures)
	sandbox.call(&"_unhandled_input", pickup)
	TestAssertions.truthy(bool(sandbox.call(&"is_holding_item")), "west face picks up the focused populated item", failures)
	inventory_one.focus_entered.emit()
	sandbox.call(&"_input", _action_event(&"ui_accept"))
	TestAssertions.equal(String(inventory_one.get_meta("item_id", "")), controller_item_id, "south face places the held item on the focused slot", failures)
	TestAssertions.truthy(not bool(sandbox.call(&"is_holding_item")), "south placement clears held-item mode", failures)

	var controller_source := stash_grid.get_child(3) as Button
	controller_source.focus_entered.emit()
	sandbox.call(&"_unhandled_input", pickup)
	var controller_cancel_projection: Dictionary = sandbox.call(&"projection")
	var controller_cancel_bytes := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	sandbox.call(&"_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(sandbox.visible and not bool(sandbox.call(&"is_holding_item")), "controller cancel clears held mode before closing the modal", failures)
	TestAssertions.equal(sandbox.call(&"projection"), controller_cancel_projection, "controller held cancel preserves projection", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), controller_cancel_bytes, "controller held cancel preserves bytes", failures)
	var ordinary_accept_projection: Dictionary = sandbox.call(&"projection")
	controller_source.focus_entered.emit()
	sandbox.call(&"_input", _action_event(&"ui_accept"))
	controller_source.pressed.emit()
	TestAssertions.truthy(not bool(sandbox.call(&"is_holding_item")), "ordinary south activation inspects without picking up", failures)
	TestAssertions.equal(sandbox.call(&"projection"), ordinary_accept_projection, "ordinary south inspection performs no mutation", failures)

	(controller_source as Button).pressed.emit()
	(sandbox.get_node("Overlay/Frame/Layout/Actions/FirstEmptyInventory") as Button).pressed.emit()
	TestAssertions.truthy((sandbox.get_node("Overlay/Frame/Layout/Header/Status") as Label).text.begins_with("OK FIRST_EMPTY_INVENTORY"), "first-empty inventory reports stable success", failures)
	(sandbox.get_node("Overlay/Frame/Layout/Actions/FirstEmptyStash") as Button).pressed.emit()
	TestAssertions.truthy((sandbox.get_node("Overlay/Frame/Layout/Header/Status") as Label).text.begins_with("OK FIRST_EMPTY_STASH"), "first-empty stash reports stable success", failures)
	for action_name: String in ["Save", "Reload", "IntegrityScan", "Reset"]:
		(sandbox.get_node("Overlay/Frame/Layout/Actions/%s" % action_name) as Button).pressed.emit()
		TestAssertions.truthy((sandbox.get_node("Overlay/Frame/Layout/Header/Status") as Label).text.begins_with("OK "), "%s reports stable success" % action_name, failures)

	var all_focus_controls: Array[Control] = []
	for child: Node in inventory_grid.get_children() + stash_grid.get_children():
		all_focus_controls.append(child as Control)
	for path: NodePath in [^"Overlay/Frame/Layout/Actions/FirstEmptyInventory", ^"Overlay/Frame/Layout/Actions/FirstEmptyStash", ^"Overlay/Frame/Layout/Actions/Save", ^"Overlay/Frame/Layout/Actions/Reload", ^"Overlay/Frame/Layout/Actions/IntegrityScan", ^"Overlay/Frame/Layout/Actions/Reset", ^"Overlay/Frame/Layout/Header/Close"]:
		all_focus_controls.append(sandbox.get_node(path) as Control)
	for control: Control in all_focus_controls:
		TestAssertions.truthy(control.focus_mode != Control.FOCUS_NONE, "%s is keyboard/controller focusable" % control.name, failures)
		for property_name: StringName in [&"focus_next", &"focus_previous", &"focus_neighbor_top", &"focus_neighbor_bottom", &"focus_neighbor_left", &"focus_neighbor_right"]:
			var target_path := control.get(property_name) as NodePath
			TestAssertions.truthy(not target_path.is_empty() and control.get_node_or_null(target_path) in all_focus_controls, "%s %s stays inside sandbox" % [control.name, property_name], failures)

	sandbox.call(&"_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(not sandbox.visible, "controller cancel closes only the sandbox", failures)
	if tree.root.get_viewport() != null:
		TestAssertions.equal(tree.root.get_viewport().gui_get_focus_owner(), return_focus, "sandbox close restores exact return focus", failures)
	else:
		TestAssertions.equal(sandbox.get("_return_focus"), null, "sandbox close consumes the exact return-focus request", failures)
	sandbox.free()
	return_focus.free()


func _test_main_route_and_profile_isolation(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var token := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var profile_root := "user://tests/task9-profile-%s" % token
	var settings_path := "user://tests/task9-settings-%s.cfg" % token
	ProfileTestSupport.remove_tree(profile_root)
	_cleanup_settings_artifacts(settings_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(settings_path.get_base_dir()))
	var store := PartyForgeSettingsStore.new()
	var player_settings := PartyForgeSettings.new()
	player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	player_settings.unlock_all_implemented_content = true
	TestAssertions.equal(store.save_settings(player_settings, settings_path), "", "Player Simulation route fixture saves", failures)
	var main: Variant = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	main.set("profile_root", profile_root)
	main.set("settings_path", settings_path)
	tree.root.add_child(main)
	main.call(&"_ready")
	var created: Variant = main.profile_manager.create_profile("Task 9 Profile")
	TestAssertions.truthy(created.ok(), "profile-isolation fixture creates an active profile", failures)
	var settings: Variant = main.get_node("SettingsScreen")
	var additional: Variant = settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings")
	var launch := additional.get_node("Layout/OpenDeveloperItemSandbox") as Button
	var modal: Variant = main.get_node("DeveloperItemSandbox")
	var forged_cached := PartyForgeSettings.new()
	forged_cached.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	forged_cached.unlock_all_implemented_content = true
	main.set("saved_settings", forged_cached)
	settings.call(&"open_additional", launch)
	settings.emit_signal(&"item_sandbox_requested")
	TestAssertions.truthy(not modal.visible, "forged Settings signal cannot bypass authoritative Player Simulation", failures)
	TestAssertions.truthy(settings.is_open(), "denied forged request restores Settings", failures)
	main.call(&"_open_developer_item_sandbox")
	TestAssertions.truthy(not modal.visible, "direct method call and Unlock All cannot bypass saved Player Simulation", failures)

	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	TestAssertions.equal(store.save_settings(developer_settings, settings_path), "", "Developer Mode route fixture saves authoritatively", failures)
	main.set("saved_settings", player_settings)
	settings.call(&"open_additional", launch)
	var profile_id: String = main.profile_manager.active_profile().profile_id
	var profile_path := ProfileStore.new().profile_path(profile_id, profile_root)
	var before_bytes := FileAccess.get_file_as_bytes(profile_path)
	var before_hash := JSON.stringify(main.active_profile().to_dictionary()).sha256_text()
	settings.emit_signal(&"item_sandbox_requested")
	TestAssertions.truthy(modal.visible and not settings.is_open(), "authoritative Developer Mode hides Settings and opens sandbox", failures)
	TestAssertions.equal(main.get_children().filter(func(child: Node) -> bool: return child.name == &"DeveloperItemSandbox").size(), 1, "main owns exactly one sandbox modal", failures)
	main.call(&"_open_developer_item_sandbox")
	TestAssertions.equal(main.get_children().filter(func(child: Node) -> bool: return child.name == &"DeveloperItemSandbox").size(), 1, "repeated open is idempotent", failures)
	var stash_zero := modal.get_node("Overlay/Frame/Layout/Body/StashPanel/StashScroll/StashSlots").get_child(0) as Button
	var inventory_zero := modal.get_node("Overlay/Frame/Layout/Body/InventoryPanel/InventorySlots").get_child(0) as Button
	var isolated_drag: Variant = stash_zero.call(&"_get_drag_data", Vector2.ZERO)
	inventory_zero.call(&"_drop_data", Vector2.ZERO, isolated_drag)
	TestAssertions.truthy(not String(inventory_zero.get_meta("item_id", "")).is_empty(), "profile-isolation route performs a real sandbox drag mutation", failures)
	modal.call(&"_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(not modal.visible and settings.is_open(), "cancel closes top sandbox and restores Settings", failures)
	TestAssertions.equal(settings.get_node("Overlay/Frame/Layout/Tabs").get_tab_control(settings.get_node("Overlay/Frame/Layout/Tabs").current_tab), additional, "sandbox close restores Additional Settings tab", failures)
	if tree.root.get_viewport() != null:
		TestAssertions.equal(tree.root.get_viewport().gui_get_focus_owner(), launch, "sandbox close restores exact launch-button focus", failures)
	else:
		TestAssertions.truthy(launch.focus_mode != Control.FOCUS_NONE, "sandbox close restores a valid launch-button focus target", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(profile_path), before_bytes, "sandbox open/use/close preserves active profile bytes", failures)
	TestAssertions.equal(JSON.stringify(main.active_profile().to_dictionary()).sha256_text(), before_hash, "sandbox open/use/close preserves active profile semantic hash", failures)

	TestAssertions.equal(store.save_settings(player_settings, settings_path), "", "route fixture returns to Player Simulation", failures)
	main.call(&"_open_developer_item_sandbox")
	TestAssertions.truthy(not modal.visible, "Player Simulation can never leave sandbox visible", failures)
	if tree.root.get_viewport() != null:
		TestAssertions.truthy(tree.root.get_viewport().gui_get_focus_owner() != modal.get_node("Overlay/Frame/Layout/Body/InventoryPanel/InventorySlots").get_child(0), "Player Simulation can never leave sandbox focused", failures)
	else:
		TestAssertions.truthy(not modal.visible, "Player Simulation exposes no focusable sandbox surface", failures)
	main.free()
	ProfileTestSupport.remove_tree(profile_root)
	_cleanup_settings_artifacts(settings_path)


func _test_failure_atomic_ui(packed: PackedScene, failures: Array[String]) -> void:
	var seed := DeveloperItemSandboxState.new()
	TestAssertions.equal(seed.reset(), "", "failure-atomic UI fixture seeds usable bytes", failures)
	var failing_atomic := AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE)
	var state := DeveloperItemSandboxState.new(DeveloperItemSandboxStore.new(failing_atomic))
	TestAssertions.equal(state.reload(), "", "failure-atomic UI state reloads the usable fixture", failures)
	var sandbox: Variant = packed.instantiate()
	TestAssertions.truthy(sandbox.has_method(&"configure"), "sandbox exposes bounded state dependency configuration", failures)
	if not sandbox.has_method(&"configure"):
		sandbox.free()
		return
	sandbox.call(&"configure", state)
	sandbox.call(&"_ready")
	TestAssertions.truthy(bool(sandbox.call(&"open")), "failure-atomic sandbox opens from usable state", failures)
	var inventory_zero := sandbox.get_node("Overlay/Frame/Layout/Body/InventoryPanel/InventorySlots").get_child(0) as Button
	var stash_zero := sandbox.get_node("Overlay/Frame/Layout/Body/StashPanel/StashScroll/StashSlots").get_child(0) as Button
	var baseline_projection: Dictionary = sandbox.call(&"projection")
	var baseline_bytes := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	var drag_data: Variant = stash_zero.call(&"_get_drag_data", Vector2.ZERO)
	inventory_zero.call(&"_drop_data", Vector2.ZERO, drag_data)
	var status := sandbox.get_node("Overlay/Frame/Layout/Header/Status") as Label
	TestAssertions.truthy(status.text.contains("stage=promote"), "failed drag move displays the exact atomic error", failures)
	TestAssertions.equal(sandbox.call(&"projection"), baseline_projection, "failed drag move preserves the last usable projection", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), baseline_bytes, "failed drag move preserves persisted bytes", failures)
	for action_name: String in ["Save", "Reset"]:
		(sandbox.get_node("Overlay/Frame/Layout/Actions/%s" % action_name) as Button).pressed.emit()
		TestAssertions.truthy(status.text.contains("stage=promote"), "failed %s displays the exact atomic error" % action_name, failures)
		TestAssertions.equal(sandbox.call(&"projection"), baseline_projection, "failed %s preserves the last usable projection" % action_name, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), baseline_bytes, "failed %s preserves persisted bytes" % action_name, failures)
	_write_text(DOCUMENT_PATH, "{ corrupt task 9 primary")
	_write_text("%s.bak" % DOCUMENT_PATH, "{ corrupt task 9 backup")
	var corrupt_primary := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	var corrupt_backup := FileAccess.get_file_as_bytes("%s.bak" % DOCUMENT_PATH)
	(sandbox.get_node("Overlay/Frame/Layout/Actions/IntegrityScan") as Button).pressed.emit()
	TestAssertions.truthy(not status.text.begins_with("OK "), "failed integrity scan displays the exact sandbox error", failures)
	TestAssertions.equal(sandbox.call(&"projection"), baseline_projection, "failed integrity scan preserves the last usable projection", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), corrupt_primary, "failed integrity scan preserves primary bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % DOCUMENT_PATH), corrupt_backup, "failed integrity scan preserves backup bytes", failures)
	(sandbox.get_node("Overlay/Frame/Layout/Actions/Reload") as Button).pressed.emit()
	TestAssertions.truthy(not status.text.begins_with("OK "), "failed reload displays the exact sandbox error", failures)
	TestAssertions.equal(sandbox.call(&"projection"), baseline_projection, "failed reload preserves the last usable projection", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), corrupt_primary, "failed reload preserves rejected primary bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % DOCUMENT_PATH), corrupt_backup, "failed reload preserves rejected backup bytes", failures)
	sandbox.free()


func _assert_slot_metadata(button: Button, container_id: StringName, slot: int, failures: Array[String]) -> void:
	TestAssertions.equal(StringName(String(button.get_meta("container_id", ""))), container_id, "%s stores exact container metadata" % button.name, failures)
	TestAssertions.equal(typeof(button.get_meta("slot", null)), TYPE_INT, "%s stores integer slot metadata" % button.name, failures)
	TestAssertions.equal(int(button.get_meta("slot", -1)), slot, "%s stores exact slot metadata" % button.name, failures)


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _cleanup_sandbox_files() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.previous"]:
		var path := "%s%s" % [DOCUMENT_PATH, suffix]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var absolute_root := ProjectSettings.globalize_path(SANDBOX_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func _cleanup_settings_artifacts(path: String) -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var candidate := "%s%s" % [path, suffix]
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


func _write_text(path: String, value: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(value)
		file.close()
