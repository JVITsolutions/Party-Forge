extends SceneTree

const REQUIRED := [
	"res://scripts/loot/ground_item_spatial_index.gd",
	"res://scripts/loot/ground_item_targeting_service.gd",
	"res://scripts/loot/ground_item_pickup_service.gd",
]

var _failures: Array[String] = []
var _parties: Array[PartyManager] = []
var _actors: Array[Node3D] = []

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	for path: String in REQUIRED:
		_assert(ResourceLoader.exists(path), "%s exists" % path.get_file())
	_assert(InputMap.has_action(&"world_loot_previous"), "world_loot_previous action exists")
	_assert(InputMap.has_action(&"world_loot_next"), "world_loot_next action exists")
	if not _failures.is_empty():
		_finish()
		return
	var previous := InputMap.action_get_events(&"world_loot_previous")
	var next := InputMap.action_get_events(&"world_loot_next")
	var accept := InputMap.action_get_events(&"ui_accept")
	_assert(previous.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.device == -1 and event.button_index == JOY_BUTTON_DPAD_LEFT), "previous uses device-agnostic D-pad left")
	_assert(next.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.device == -1 and event.button_index == JOY_BUTTON_DPAD_RIGHT), "next uses device-agnostic D-pad right")
	_assert(accept.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.device == -1 and event.button_index == JOY_BUTTON_A), "existing ui_accept retains device-agnostic south-face pickup")
	_test_input_normalization()
	_test_real_controller_flow()
	print("GROUND_ITEM_PICKUP_MOUSE: PASS") if _failures.is_empty() else print("GROUND_ITEM_PICKUP_MOUSE: FAIL")
	print("GROUND_ITEM_PICKUP_CONTROLLER: PASS") if _failures.is_empty() else print("GROUND_ITEM_PICKUP_CONTROLLER: FAIL")
	print("GROUND_ITEM_PICKUP_FULL_INVENTORY: PASS") if _failures.is_empty() else print("GROUND_ITEM_PICKUP_FULL_INVENTORY: FAIL")
	print("GROUND_ITEM_PICKUP_FOREIGN_OWNER: PASS") if _failures.is_empty() else print("GROUND_ITEM_PICKUP_FOREIGN_OWNER: FAIL")
	_finish()

func _finish() -> void:
	for actor: Node3D in _actors:
		if is_instance_valid(actor):
			actor.free()
	for party: PartyManager in _parties:
		if is_instance_valid(party):
			party.free()
	_actors.clear()
	_parties.clear()
	if _failures.is_empty():
		print("GROUND_ITEM_PICKUP_INPUT_INTEGRATION: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("GROUND_ITEM_PICKUP_INPUT_INTEGRATION: %s" % failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _test_real_controller_flow() -> void:
	var contexts := RunContextRegistry.new()
	var p1 := _context(&"player_1", "profile-p1", 0, 0, 0)
	var p2 := _context(&"player_2", "profile-p2", 1, 1, 1)
	var keyboard := _context(&"keyboard", "profile-keyboard", 2, -1, 0)
	_assert(contexts.register_context(p1, 0).ok(), "P1 context registers on device 0")
	_assert(contexts.register_context(p2, 1).ok(), "P2 context registers on device 1")
	_assert(contexts.register_context(keyboard, -1).ok(), "keyboard context registers with unassigned device sentinel")
	var registry := GroundItemRegistry.new()
	registry.add(_record(&"p1-near", &"player_1", Vector3(1.0, 0.0, 0.0), 0))
	registry.add(_record(&"p1-offscreen", &"player_1", Vector3(100.0, 0.0, 0.0), 1))
	registry.add(_record(&"p2-near", &"player_2", Vector3(1.0, 0.0, 0.0), 0))
	registry.add(_record(&"p2-out", &"player_2", Vector3(4.0, 0.0, 0.0), 1))
	registry.add(_record(&"keyboard-near", &"keyboard", Vector3(1.0, 0.0, 0.0), 0))
	var host := Node.new()
	var chests := Node3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(root.size)
	var camera := Camera3D.new()
	host.add_child(chests)
	host.add_child(tooltip_layer)
	host.add_child(camera)
	root.add_child(host)
	camera.look_at_from_position(Vector3(0.0, 10.0, 10.0), Vector3.ZERO)
	camera.current = true
	var controller := (load("res://scripts/world/ground_item_world_controller.gd") as Script).new() as Node
	host.add_child(controller)
	_assert(not controller.has_method(&"select_for_owner"), "production exposes no direct selection bypass")
	controller.call(&"configure", registry, {}, func(record: GroundItemRecord) -> Dictionary: return _detail(record), camera, chests, tooltip_layer)
	var controller_owned_index := controller.get("_spatial_index") as RefCounted
	var replacement_registry := GroundItemRegistry.new()
	controller.call(&"configure", replacement_registry, {}, func(record: GroundItemRecord) -> Dictionary: return _detail(record), camera, chests, tooltip_layer)
	_assert(controller_owned_index.call(&"query", &"player_1", Vector3.ZERO, 100.0).is_empty(), "controller reconfigure disposes the prior incremental index subscription")
	controller.call(&"configure", registry, {}, func(record: GroundItemRecord) -> Dictionary: return _detail(record), camera, chests, tooltip_layer)
	var index := (load(REQUIRED[0]) as Script).new(registry, 4.0) as RefCounted
	var targeting := (load(REQUIRED[1]) as Script).new() as RefCounted
	var pickup := (load(REQUIRED[2]) as Script).new(registry, contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.0) as RefCounted
	var modal := [false]
	controller.call(&"configure_interaction", index, targeting, pickup, contexts, 200.0, Callable(), func() -> bool: return modal[0])
	controller.call(&"_process", 0.0)
	controller.call(&"_unhandled_input", _button(1, JOY_BUTTON_DPAD_RIGHT))
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"p2-near", "device 1 selects only P2 owned visible nearby loot")
	_assert(controller.call(&"selection_for_owner", &"player_1") == &"", "device 1 cannot change P1 selection")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	_assert(controller.call(&"_owner_for_event", enter) == &"keyboard", "keyboard event routes only to the unassigned context")
	controller.call(&"_unhandled_input", _button(0, JOY_BUTTON_DPAD_RIGHT))
	_assert(controller.call(&"selection_for_owner", &"player_1") == &"p1-near", "device 0 selects the visible in-viewport P1 entry")
	controller.call(&"_unhandled_input", _button(0, JOY_BUTTON_DPAD_RIGHT))
	_assert(controller.call(&"selection_for_owner", &"player_1") == &"p1-near", "in-front but off-viewport P1 entry is excluded without a custom visibility filter")
	modal[0] = true
	controller.call(&"_unhandled_input", _button(0, JOY_BUTTON_DPAD_LEFT))
	_assert(controller.call(&"selection_for_owner", &"player_1") == &"p1-near", "modal input suppression preserves selection")
	modal[0] = false
	_assert(controller.call(&"selection_for_owner", &"player_1") == &"p1-near", "ledger-close equivalent preserves the prior target")
	var forwarded: Array[Array] = []
	var statuses: Array[String] = []
	controller.connect(&"pickup_requested", func(drop_id: StringName, owner: StringName) -> void: forwarded.append([drop_id, owner]))
	controller.connect(&"status_changed", func(status: String) -> void: statuses.append(status))
	var chest := _chest_for(chests, &"p1-near")
	_assert(chest != null, "public chest parent exposes the projected P1 chest")
	if chest == null:
		controller.call(&"_exit_tree")
		host.free()
		contexts.clear()
		return
	var anchor := chest.call(&"tooltip_anchor") as Control
	anchor.gui_input.emit(_mouse_button(1))
	_assert(forwarded.is_empty(), "foreign mouse pointer owner is rejected")
	modal[0] = true
	anchor.gui_input.emit(_mouse_button(0))
	_assert(forwarded.is_empty(), "modal suppression blocks the real mouse pickup path")
	modal[0] = false
	anchor.gui_input.emit(_mouse_button(0))
	_assert(forwarded == [[&"p1-near", &"player_1"]], "owning mouse pointer reaches the exact chest")
	controller.call(&"_unhandled_input", _button(1, JOY_BUTTON_DPAD_RIGHT))
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"p2-out", "real P2 D-pad cycle selects owned visible loot outside pickup range")
	controller.call(&"_unhandled_input", _button(1, JOY_BUTTON_A))
	_assert(statuses.has("Move closer"), "out-of-range activation emits exact Move closer status")
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"p2-out", "out-of-range activation preserves selection")
	modal[0] = true
	controller.call(&"_unhandled_input", _button(1, JOY_BUTTON_DPAD_LEFT))
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"p2-out", "modal input preserves the real out-of-range selection")
	modal[0] = false
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"p2-out", "ledger close preserves the real out-of-range selection")
	var result_script := load("res://scripts/loot/ground_item_pickup_result.gd") as Script
	var codes := result_script.get_script_constant_map()["Code"] as Dictionary
	var full_result := pickup.call(&"collect", &"p1-near", &"player_1") as RefCounted
	_assert(full_result.get(&"code") == codes["INVENTORY_FULL"] and full_result.get(&"message") == "Inventory full", "full inventory is explicit and preserves the chest")
	var foreign_result := pickup.call(&"collect", &"p1-near", &"player_2") as RefCounted
	_assert(foreign_result.get(&"code") == codes["NOT_OWNER"], "foreign owner rejection is exact")
	_assert(registry.record(&"p1-near") != null and controller.call(&"selection_for_owner", &"player_1") == &"p1-near", "failed pickups preserve chest and selection")
	controller.call(&"_exit_tree")
	host.free()
	contexts.clear()
	RenderingServer.force_sync()

func _test_input_normalization() -> void:
	var config_script := load("res://tools/configure_live_loot_inputs.gd") as Script
	var supports_normalization := config_script.get_script_method_list().any(func(method: Dictionary) -> bool: return method.get("name") == &"normalized_setting")
	_assert(supports_normalization, "input configurator exposes its production normalization seam")
	if not supports_normalization:
		return
	var dirty_key := InputEventKey.new()
	dirty_key.keycode = KEY_Q
	var dirty_specific := InputEventJoypadButton.new()
	dirty_specific.device = 3
	dirty_specific.button_index = JOY_BUTTON_DPAD_LEFT
	var dirty_wrong := InputEventJoypadButton.new()
	dirty_wrong.device = -1
	dirty_wrong.button_index = JOY_BUTTON_DPAD_RIGHT
	var dirty := {"deadzone": 0.9, "events": [dirty_key, dirty_specific, dirty_wrong], "custom": "remove-me"}
	var normalized := config_script.call(&"normalized_setting", dirty, JOY_BUTTON_DPAD_LEFT) as Dictionary
	var normalized_events := normalized.get("events", []) as Array
	_assert(normalized.keys().size() == 2 and normalized.has("deadzone") and normalized.has("events"), "managed action normalization removes unrelated managed-entry fields")
	_assert(normalized_events.is_typed() and normalized_events.get_typed_builtin() == TYPE_OBJECT, "managed action normalization preserves canonical typed input-event serialization")
	_assert(normalized_events.size() == 1 and normalized_events[0] is InputEventJoypadButton and normalized_events[0].device == -1 and normalized_events[0].button_index == JOY_BUTTON_DPAD_LEFT, "dirty managed action becomes exactly device -1 D-pad left")
	var normalized_twice := config_script.call(&"normalized_setting", normalized, JOY_BUTTON_DPAD_LEFT) as Dictionary
	var twice_events := normalized_twice.get("events", []) as Array
	_assert(normalized_twice.get("deadzone") == normalized.get("deadzone") and twice_events.size() == 1 and twice_events[0] is InputEventJoypadButton and twice_events[0].device == -1 and twice_events[0].button_index == JOY_BUTTON_DPAD_LEFT, "managed action normalization is idempotent")

func _context(run_player_id: StringName, profile_id: String, slot: int, device: int, inventory_columns: int) -> PlayerRunContext:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var profile := ProfileState.new_profile(profile_id, "Input Owner", 1000)
	profile.inventory_columns = inventory_columns
	var context := PlayerRunContext.new()
	assert(context.configure(run_player_id, slot, profile, 9200 + device, party, 100).is_empty())
	var actor := Node3D.new()
	_actors.append(actor)
	assert(context.bind_actor(1, actor))
	return context

func _record(drop_id: StringName, owner: StringName, position: Vector3, slot: int) -> GroundItemRecord:
	var record := GroundItemRecord.new()
	record.drop_id = drop_id
	record.item_id = "item-%s" % drop_id
	record.run_player_id = owner
	record.profile_id = "profile-%s" % owner
	record.player_number = 1 if owner == &"player_1" else 2
	record.color_id = &"red" if owner == &"player_1" else &"blue"
	record.world_position = position
	record.rarity_id = &"common"
	record.source_id = &"test"
	record.ground_slot = slot
	return record

func _detail(record: GroundItemRecord) -> Dictionary:
	return {"instance_id": record.item_id, "name": String(record.drop_id), "rarity_id": "common", "rarity_name": "Common", "item_level": 1, "compatible_slot_ids": [], "affixes": [], "modifier_totals": {}}

func _button(device: int, button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	return event

func _mouse_button(device: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.device = device
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

func _chest_for(parent: Node3D, drop_id: StringName) -> Node3D:
	for child: Node in parent.get_children():
		if child is Node3D and StringName(child.get("drop_id")) == drop_id:
			return child as Node3D
	return null
