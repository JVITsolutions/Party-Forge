extends SceneTree

const REQUIRED := [
	"res://scripts/loot/ground_item_spatial_index.gd",
	"res://scripts/loot/ground_item_targeting_service.gd",
	"res://scripts/loot/ground_item_pickup_service.gd",
]
const MARKER_MOUSE := &"mouse"
const MARKER_CONTROLLER := &"controller"
const MARKER_FULL_INVENTORY := &"full_inventory"
const MARKER_FOREIGN_OWNER := &"foreign_owner"

var _failures: Array[String] = []
var _parties: Array[PartyManager] = []
var _actors: Array[Node3D] = []
var _marker_failed := {
	MARKER_MOUSE: false,
	MARKER_CONTROLLER: false,
	MARKER_FULL_INVENTORY: false,
	MARKER_FOREIGN_OWNER: false,
}

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
	await _test_real_overlapped_mouse_pickup()
	await _test_foreign_mouse_tooltip_release_and_retention()
	await _test_mouse_cannot_impersonate_controller()
	await _test_modal_click_through_and_restore()
	await _test_real_controller_flow()
	await _test_success_advances_selection()
	await _test_pooled_selection_visual_reset()
	await _test_viewport_resize_projection()
	_print_marker("GROUND_ITEM_PICKUP_MOUSE", MARKER_MOUSE)
	_print_marker("GROUND_ITEM_PICKUP_CONTROLLER", MARKER_CONTROLLER)
	_print_marker("GROUND_ITEM_PICKUP_FULL_INVENTORY", MARKER_FULL_INVENTORY)
	_print_marker("GROUND_ITEM_PICKUP_FOREIGN_OWNER", MARKER_FOREIGN_OWNER)
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
	_marker_assert([MARKER_CONTROLLER], condition, message)

func _marker_assert(markers: Array, condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		for marker: StringName in markers:
			_marker_failed[marker] = true

func _print_marker(label: String, marker: StringName) -> void:
	print("%s: %s" % [label, "FAIL" if bool(_marker_failed.get(marker, true)) else "PASS"])

func _test_real_overlapped_mouse_pickup() -> void:
	var shared_markers: Array = [MARKER_MOUSE, MARKER_FULL_INVENTORY, MARKER_FOREIGN_OWNER]
	var contexts := RunContextRegistry.new()
	var context := _context(&"overlap-owner", "profile-overlap-owner", 0, -1, 1)
	_marker_assert(shared_markers, contexts.register_context(context, -1).ok(), "overlap fixture registers the KB/M owner")
	_marker_assert([MARKER_MOUSE], contexts.all_contexts().size() == 1 and context.run_inventory().occupied_slots().is_empty(), "production mouse fixture starts with only device -1 and an empty five-slot inventory")
	var actor := context.actor_for(1)
	actor.position = Vector3(0.0, -2.0, 0.0)
	var request := ItemGenerationRequest.create(7301, 0, 10, &"ordinary_enemy", &"ordinary_drop", [&"common"])
	request.forced_base_id = &"windrunner_band"
	request.forced_rarity_id = &"common"
	var generated := context.issue_ground_item(request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_marker_assert(shared_markers, generated != null and generated.ok(), "overlap fixture issues one canonical owned ground item")
	if generated == null or not generated.ok():
		contexts.clear()
		return
	var registry := GroundItemRegistry.new()
	var record := _record(&"overlap-owned", context.run_player_id, Vector3(0.0, 3.0, 0.0), 0)
	record.item_id = generated.item.instance_id
	record.profile_id = context.profile_id
	_marker_assert(shared_markers, registry.add(record), "overlap fixture registers the canonical owned ground record")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Node.new()
	var chests := Node3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(viewport.size)
	var tooltip := (load("res://scenes/ui/storage/item_tooltip_panel.tscn") as PackedScene).instantiate() as ItemTooltipPanel
	var camera := Camera3D.new()
	viewport.add_child(host)
	host.add_child(chests)
	host.add_child(tooltip_layer)
	tooltip_layer.add_child(tooltip)
	host.add_child(camera)
	host.add_child(actor)
	camera.look_at_from_position(Vector3(0.0, 0.0, 10.0), Vector3.ZERO)
	camera.current = true
	var controller := (load("res://scripts/world/ground_item_world_controller.gd") as Script).new() as Node
	host.add_child(controller)
	controller.call(&"configure", registry, {}, func(value: GroundItemRecord) -> Dictionary: return _detail(value), camera, chests, tooltip_layer)
	controller.call(&"configure_interaction", (load(REQUIRED[0]) as Script).new(registry, 4.0), (load(REQUIRED[1]) as Script).new(), (load(REQUIRED[2]) as Script).new(registry, contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.5), contexts, 20.0)
	var statuses: Array[String] = []
	var feedback: Array[GroundItemPickupResult] = []
	var pickup_requests: Array[Array] = []
	controller.connect(&"status_changed", func(status: String) -> void: statuses.append(status))
	controller.connect(&"pickup_feedback", func(result: GroundItemPickupResult) -> void: feedback.append(result))
	controller.connect(&"pickup_requested", func(drop_id: StringName, owner: StringName) -> void: pickup_requests.append([drop_id, owner]))
	await process_frame
	var chest := _chest_for(chests, record.drop_id)
	var anchor := chest.call(&"tooltip_anchor") as Control if chest != null else null
	_marker_assert(shared_markers, anchor != null and anchor.visible, "overlap fixture projects the real 44 by 44 chest anchor")
	if anchor != null:
		var hover_position := anchor.get_global_rect().get_center()
		await _dispatch_viewport_mouse_motion(viewport, hover_position, 0)
		await process_frame
		_marker_assert([MARKER_MOUSE], tooltip.visible, "tooltip is visible before pickup click")
		var decorative := tooltip.get_node("Layout/Header/Context") as Control
		var overlap := anchor.get_global_rect().intersection(decorative.get_global_rect())
		_marker_assert([MARKER_MOUSE], overlap.has_area(), "decorative tooltip region geometrically covers part of the projected 44 by 44 anchor")
		if overlap.has_area():
			await _dispatch_viewport_mouse_click(viewport, overlap.get_center(), 0)
		_marker_assert([MARKER_MOUSE], registry.record(record.drop_id) != null, "out-of-range real overlapped click leaves the chest")
		_marker_assert([MARKER_MOUSE], anchor.text.contains("Move closer") and statuses.has("Move closer"), "out-of-range real overlapped click shows persistent Move closer")
		_marker_assert([MARKER_MOUSE], not feedback.is_empty() and feedback[-1].code == GroundItemPickupResult.Code.MOVE_CLOSER, "out-of-range real overlapped click emits typed Move closer feedback")
		actor.position = record.world_position
		await process_frame
		_marker_assert([MARKER_MOUSE], tooltip.visible, "tooltip remains visible immediately before eligible retry")
		var requests_before_retry := pickup_requests.size()
		var feedback_before_retry := feedback.size()
		if overlap.has_area():
			await _dispatch_viewport_mouse_click(viewport, overlap.get_center(), 0)
		_marker_assert([MARKER_MOUSE], pickup_requests.size() == requests_before_retry + 1 and pickup_requests[-1] == [record.drop_id, context.run_player_id], "eligible retry emits exactly one pickup request for the owned chest")
		_marker_assert([MARKER_MOUSE], feedback.size() == feedback_before_retry + 1 and feedback[-1].code == GroundItemPickupResult.Code.OK and _feedback_code_count(feedback, GroundItemPickupResult.Code.OK) == 1, "eligible retry emits exactly one successful pickup feedback")
		_marker_assert([MARKER_MOUSE], _inventory_instance_count(context, generated.item.instance_id) == 1, "eligible retry stores exactly one instance in owner inventory")
		_marker_assert([MARKER_MOUSE], registry.record(record.drop_id) == null, "successful pickup consumes only collected chest")
		for sequence: int in range(1, 5):
			var filler_request := ItemGenerationRequest.create(7301 + sequence, sequence, 10, &"ordinary_enemy", &"ordinary_drop", [&"common"])
			filler_request.forced_base_id = &"windrunner_band"
			filler_request.forced_rarity_id = &"common"
			var filler := context.issue_ground_item(filler_request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
			_marker_assert([MARKER_FULL_INVENTORY], filler != null and filler.ok(), "full-inventory fixture issues filler %d" % sequence)
			if filler != null and filler.ok():
				_marker_assert([MARKER_FULL_INVENTORY], context.collect_ground_item(filler.item.instance_id, "full-fixture-%d" % sequence, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).ok(), "full-inventory fixture stores filler %d" % sequence)
		var full_request := ItemGenerationRequest.create(7310, 5, 10, &"ordinary_enemy", &"ordinary_drop", [&"common"])
		full_request.forced_base_id = &"windrunner_band"
		full_request.forced_rarity_id = &"common"
		var full_item := context.issue_ground_item(full_request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
		_marker_assert([MARKER_FULL_INVENTORY, MARKER_FOREIGN_OWNER], full_item != null and full_item.ok(), "full-inventory fixture issues the retained canonical item")
		if full_item != null and full_item.ok():
			var full_record := _record(&"overlap-full", context.run_player_id, record.world_position, 0)
			full_record.item_id = full_item.item.instance_id
			full_record.profile_id = context.profile_id
			_marker_assert([MARKER_FULL_INVENTORY, MARKER_FOREIGN_OWNER], registry.add(full_record), "full-inventory fixture registers the retained record")
			await process_frame
			var full_chest := _chest_for(chests, full_record.drop_id)
			var full_anchor := full_chest.call(&"tooltip_anchor") as Control if full_chest != null else null
			_marker_assert([MARKER_FULL_INVENTORY, MARKER_FOREIGN_OWNER], full_anchor != null, "full-inventory fixture projects its exact chest")
			if full_anchor != null:
				await _dispatch_viewport_mouse_motion(viewport, Vector2(2.0, 318.0), -1)
				await _dispatch_viewport_mouse_motion(viewport, full_anchor.get_global_rect().get_center(), -1)
				await process_frame
				var full_overlap := full_anchor.get_global_rect().intersection(decorative.get_global_rect())
				_marker_assert([MARKER_FULL_INVENTORY, MARKER_FOREIGN_OWNER], tooltip.visible and full_overlap.has_area(), "full-inventory click uses the same visible decorative overlap")
				if full_overlap.has_area():
					await _dispatch_viewport_mouse_click(viewport, full_overlap.get_center(), -1)
				_marker_assert([MARKER_FULL_INVENTORY], registry.record(full_record.drop_id) != null, "full-inventory real click leaves the chest")
				_marker_assert([MARKER_FULL_INVENTORY], full_anchor.text.contains("Inventory full") and statuses.has("Inventory full"), "full-inventory real click shows persistent Inventory full")
				_marker_assert([MARKER_FULL_INVENTORY], not feedback.is_empty() and feedback[-1].code == GroundItemPickupResult.Code.INVENTORY_FULL, "full-inventory real click emits typed capacity feedback")
				var foreign_context := _context(&"foreign-input", "profile-foreign-input", 1, 7, 1)
				_marker_assert([MARKER_FOREIGN_OWNER], contexts.register_context(foreign_context, 7).ok(), "controller-owned fixture registers a distinct joypad device")
				var owner_ground_before := context.ground_items().to_dictionary()
				var foreign_inventory_before := foreign_context.run_inventory().to_dictionary()
				var requests_before_device_seven_mouse := pickup_requests.size()
				if full_overlap.has_area():
					await _dispatch_viewport_mouse_click(viewport, full_overlap.get_center(), 7)
				_marker_assert([MARKER_FOREIGN_OWNER], registry.record(full_record.drop_id) != null, "device 7 mouse click leaves the full KB/M-owned chest")
				_marker_assert([MARKER_FOREIGN_OWNER], context.ground_items().to_dictionary() == owner_ground_before and foreign_context.run_inventory().to_dictionary() == foreign_inventory_before, "device 7 mouse click cannot impersonate the device 7 controller owner")
				_marker_assert([MARKER_FOREIGN_OWNER], pickup_requests.size() == requests_before_device_seven_mouse + 1 and pickup_requests[-1] == [full_record.drop_id, context.run_player_id], "device 7 mouse click still routes to the sole device -1 KB/M owner")
				_marker_assert([MARKER_FOREIGN_OWNER], not feedback.is_empty() and feedback[-1].code == GroundItemPickupResult.Code.INVENTORY_FULL, "device 7 mouse click receives the KB/M owner's typed capacity feedback")
	controller.queue_free()
	await process_frame
	viewport.free()
	contexts.clear()
	RenderingServer.force_sync()

func _test_foreign_mouse_tooltip_release_and_retention() -> void:
	var contexts := RunContextRegistry.new()
	var keyboard_owner := _context(&"tooltip-keyboard", "profile-tooltip-keyboard", 0, -1, 1)
	var foreign_owner := _context(&"tooltip-foreign", "profile-tooltip-foreign", 1, 1, 1)
	_marker_assert([MARKER_MOUSE, MARKER_CONTROLLER, MARKER_FOREIGN_OWNER], contexts.register_context(keyboard_owner, -1).ok(), "tooltip lifecycle fixture registers the KB/M owner")
	_marker_assert([MARKER_MOUSE, MARKER_CONTROLLER, MARKER_FOREIGN_OWNER], contexts.register_context(foreign_owner, 1).ok(), "tooltip lifecycle fixture registers the foreign P2 controller owner")
	var request := ItemGenerationRequest.create(7330, 0, 10, &"ordinary_enemy", &"ordinary_drop", [&"common"])
	request.forced_base_id = &"windrunner_band"
	request.forced_rarity_id = &"common"
	var generated := foreign_owner.issue_ground_item(request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_marker_assert([MARKER_MOUSE, MARKER_CONTROLLER, MARKER_FOREIGN_OWNER], generated != null and generated.ok(), "tooltip lifecycle fixture issues one canonical P2 ground item")
	if generated == null or not generated.ok():
		contexts.clear()
		return
	var registry := GroundItemRegistry.new()
	var record := _record(&"tooltip-p2", foreign_owner.run_player_id, Vector3.ZERO, 0)
	record.item_id = generated.item.instance_id
	record.profile_id = foreign_owner.profile_id
	_marker_assert([MARKER_MOUSE, MARKER_CONTROLLER, MARKER_FOREIGN_OWNER], registry.add(record), "tooltip lifecycle fixture registers its visible foreign P2 chest")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Node.new()
	var chests := Node3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(viewport.size)
	var camera := Camera3D.new()
	viewport.add_child(host)
	host.add_child(chests)
	host.add_child(tooltip_layer)
	host.add_child(camera)
	host.add_child(keyboard_owner.actor_for(1))
	host.add_child(foreign_owner.actor_for(1))
	camera.look_at_from_position(Vector3(0.0, 0.0, 10.0), Vector3.ZERO)
	camera.current = true
	var controller := (load("res://scripts/world/ground_item_world_controller.gd") as Script).new() as Node
	host.add_child(controller)
	controller.call(&"configure", registry, {}, func(value: GroundItemRecord) -> Dictionary: return _detail(value), camera, chests, tooltip_layer)
	var tooltip := tooltip_layer.get_children().filter(func(child: Node) -> bool: return child is ItemTooltipPanel).front() as ItemTooltipPanel
	controller.call(&"configure_interaction", (load(REQUIRED[0]) as Script).new(registry, 4.0), (load(REQUIRED[1]) as Script).new(), (load(REQUIRED[2]) as Script).new(registry, contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.5), contexts, 20.0)
	var feedback: Array[GroundItemPickupResult] = []
	controller.connect(&"pickup_feedback", func(result: GroundItemPickupResult) -> void: feedback.append(result))
	await process_frame
	var chest := _chest_for(chests, record.drop_id)
	var anchor := chest.call(&"tooltip_anchor") as Button if chest != null else null
	_marker_assert([MARKER_MOUSE, MARKER_CONTROLLER, MARKER_FOREIGN_OWNER], anchor != null and anchor.visible, "tooltip lifecycle fixture projects the real 44 by 44 P2 anchor")
	if anchor != null:
		var anchor_center := anchor.get_global_rect().get_center()
		var outside := Vector2(4.0, 596.0)
		var keyboard_inventory_before := keyboard_owner.run_inventory().to_dictionary()
		var foreign_ground_before := foreign_owner.ground_items().to_dictionary()
		await _dispatch_viewport_mouse_motion(viewport, anchor_center, 0)
		_marker_assert([MARKER_MOUSE], tooltip.visible and tooltip.is_current_source(&"ground-loot:tooltip-p2"), "real pointer entry opens the P2 ground tooltip")
		await _dispatch_viewport_mouse_click(viewport, anchor_center, 0)
		_marker_assert([MARKER_MOUSE, MARKER_FOREIGN_OWNER], not feedback.is_empty() and feedback[-1].code == GroundItemPickupResult.Code.NOT_OWNER, "real P1 mouse click receives typed foreign-owner rejection")
		await _dispatch_viewport_mouse_motion(viewport, outside, 0)
		await _wait_for_tooltip_hidden(tooltip)
		_marker_assert([MARKER_MOUSE], not anchor.has_focus(), "mouse click leaves no persistent ground-anchor focus after pointer exit")
		_marker_assert([MARKER_MOUSE], not tooltip.visible and tooltip.current_source_id().is_empty(), "foreign P2 tooltip dismisses after pointer exit and the natural grace window")
		_marker_assert([MARKER_FOREIGN_OWNER], registry.record(record.drop_id) != null and keyboard_owner.run_inventory().to_dictionary() == keyboard_inventory_before and foreign_owner.ground_items().to_dictionary() == foreign_ground_before, "foreign click changes neither inventory nor authoritative P2 ground ownership")

		await _dispatch_viewport_mouse_motion(viewport, anchor_center, 0)
		await _dispatch_viewport_key(viewport, KEY_ALT, true)
		await _dispatch_viewport_mouse_motion(viewport, outside, 0)
		await _wait_past_tooltip_grace()
		_marker_assert([MARKER_MOUSE], tooltip.visible and tooltip.is_current_source(&"ground-loot:tooltip-p2"), "Alt retains the ground tooltip after pointer exit")
		await _dispatch_viewport_key(viewport, KEY_ALT, false)
		await _wait_for_tooltip_hidden(tooltip)
		_marker_assert([MARKER_MOUSE], not tooltip.visible and tooltip.current_source_id().is_empty(), "releasing Alt dismisses the inactive ground tooltip")

		await _dispatch_viewport_mouse_motion(viewport, anchor_center, 0)
		await _dispatch_viewport_button(viewport, 0, JOY_BUTTON_Y)
		await _dispatch_viewport_mouse_motion(viewport, outside, 0)
		await _wait_past_tooltip_grace()
		_marker_assert([MARKER_CONTROLLER], tooltip.visible and tooltip.is_pinned(), "Y or Triangle pins the ground tooltip across pointer exit")
		await _dispatch_viewport_button(viewport, 0, JOY_BUTTON_Y)
		await _wait_for_tooltip_hidden(tooltip)
		_marker_assert([MARKER_CONTROLLER], not tooltip.visible and not tooltip.is_pinned() and tooltip.current_source_id().is_empty(), "unpinned inactive ground tooltip dismisses")

		await _dispatch_viewport_button(viewport, 1, JOY_BUTTON_DPAD_RIGHT)
		await _dispatch_viewport_mouse_motion(viewport, outside, 0)
		await _wait_past_tooltip_grace()
		_marker_assert([MARKER_CONTROLLER], controller.call(&"selection_for_owner", foreign_owner.run_player_id) == record.drop_id and anchor.has_focus(), "P2 D-pad selection keeps real controller focus on its owned anchor")
		_marker_assert([MARKER_CONTROLLER], tooltip.visible and tooltip.is_current_source(&"ground-loot:tooltip-p2"), "controller-focused ground tooltip remains visible without mouse hover")
	await _teardown_controller(controller, chests, tooltip_layer, "tooltip lifecycle teardown")
	viewport.free()
	contexts.clear()
	RenderingServer.force_sync()


func _test_mouse_cannot_impersonate_controller() -> void:
	var contexts := RunContextRegistry.new()
	var controller_owner := _context(&"controller-only", "profile-controller-only", 0, 0, 1)
	_marker_assert([MARKER_MOUSE, MARKER_FOREIGN_OWNER], contexts.register_context(controller_owner, 0).ok(), "controller-only fixture registers device 0 without a KB/M context")
	var request := ItemGenerationRequest.create(7340, 0, 10, &"ordinary_enemy", &"ordinary_drop", [&"common"])
	request.forced_base_id = &"windrunner_band"
	request.forced_rarity_id = &"common"
	var generated := controller_owner.issue_ground_item(request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_marker_assert([MARKER_MOUSE, MARKER_FOREIGN_OWNER], generated != null and generated.ok(), "controller-only fixture issues one canonical owned ground item")
	if generated == null or not generated.ok():
		contexts.clear()
		return
	var registry := GroundItemRegistry.new()
	var record := _record(&"controller-only-drop", controller_owner.run_player_id, Vector3.ZERO, 0)
	record.item_id = generated.item.instance_id
	record.profile_id = controller_owner.profile_id
	_marker_assert([MARKER_MOUSE, MARKER_FOREIGN_OWNER], registry.add(record), "controller-only fixture registers its owned chest")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 320)
	root.add_child(viewport)
	var host := Node.new()
	var chests := Node3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(viewport.size)
	var camera := Camera3D.new()
	viewport.add_child(host)
	host.add_child(chests)
	host.add_child(tooltip_layer)
	host.add_child(camera)
	host.add_child(controller_owner.actor_for(1))
	camera.look_at_from_position(Vector3(0.0, 0.0, 10.0), Vector3.ZERO)
	camera.current = true
	var controller := (load("res://scripts/world/ground_item_world_controller.gd") as Script).new() as Node
	host.add_child(controller)
	controller.call(&"configure", registry, {}, func(value: GroundItemRecord) -> Dictionary: return _detail(value), camera, chests, tooltip_layer)
	controller.call(&"configure_interaction", (load(REQUIRED[0]) as Script).new(registry, 4.0), (load(REQUIRED[1]) as Script).new(), (load(REQUIRED[2]) as Script).new(registry, contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.5), contexts, 20.0)
	var pickup_requests: Array[Array] = []
	var feedback: Array[GroundItemPickupResult] = []
	controller.connect(&"pickup_requested", func(drop_id: StringName, owner: StringName) -> void: pickup_requests.append([drop_id, owner]))
	controller.connect(&"pickup_feedback", func(result: GroundItemPickupResult) -> void: feedback.append(result))
	await process_frame
	var chest := _chest_for(chests, record.drop_id)
	var anchor := chest.call(&"tooltip_anchor") as Control if chest != null else null
	_marker_assert([MARKER_MOUSE, MARKER_FOREIGN_OWNER], anchor != null and anchor.visible, "controller-only fixture projects the real chest anchor")
	if anchor != null:
		await _dispatch_viewport_mouse_click(viewport, anchor.get_global_rect().get_center(), 0)
	_marker_assert([MARKER_MOUSE, MARKER_FOREIGN_OWNER], pickup_requests.is_empty() and feedback.is_empty(), "mouse device 0 cannot impersonate the controller-only device 0 owner")
	_marker_assert([MARKER_MOUSE, MARKER_FOREIGN_OWNER], registry.record(record.drop_id) != null and _inventory_instance_count(controller_owner, generated.item.instance_id) == 0, "controller-only chest and inventory remain unchanged after the mouse click")
	controller.queue_free()
	await process_frame
	viewport.free()
	contexts.clear()
	RenderingServer.force_sync()


func _test_modal_click_through_and_restore() -> void:
	var contexts := RunContextRegistry.new()
	var context := _context(&"modal-owner", "profile-modal-owner", 0, -1, 1)
	_marker_assert([MARKER_MOUSE], contexts.register_context(context, -1).ok(), "modal fixture registers the sole KB/M owner")
	var request := ItemGenerationRequest.create(7350, 0, 10, &"ordinary_enemy", &"ordinary_drop", [&"common"])
	request.forced_base_id = &"windrunner_band"
	request.forced_rarity_id = &"common"
	var generated := context.issue_ground_item(request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_marker_assert([MARKER_MOUSE], generated != null and generated.ok(), "modal fixture issues one canonical owned ground item")
	if generated == null or not generated.ok():
		contexts.clear()
		return
	var registry := GroundItemRegistry.new()
	var record := _record(&"modal-owned", context.run_player_id, Vector3.ZERO, 0)
	record.item_id = generated.item.instance_id
	record.profile_id = context.profile_id
	_marker_assert([MARKER_MOUSE], registry.add(record), "modal fixture registers the owned ground record")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 320)
	root.add_child(viewport)
	var host := Node.new()
	var chests := Node3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(viewport.size)
	var confirmation := Button.new()
	confirmation.name = "ModalConfirmation"
	confirmation.text = "Confirm"
	confirmation.size = Vector2(44.0, 44.0)
	confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
	var camera := Camera3D.new()
	viewport.add_child(host)
	host.add_child(chests)
	host.add_child(tooltip_layer)
	tooltip_layer.add_child(confirmation)
	host.add_child(camera)
	host.add_child(context.actor_for(1))
	camera.look_at_from_position(Vector3(0.0, 0.0, 10.0), Vector3.ZERO)
	camera.current = true
	var controller := (load("res://scripts/world/ground_item_world_controller.gd") as Script).new() as Node
	host.add_child(controller)
	controller.call(&"configure", registry, {}, func(value: GroundItemRecord) -> Dictionary: return _detail(value), camera, chests, tooltip_layer)
	var modal := [false]
	controller.call(&"configure_interaction", (load(REQUIRED[0]) as Script).new(registry, 4.0), (load(REQUIRED[1]) as Script).new(), (load(REQUIRED[2]) as Script).new(registry, contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.5), contexts, 20.0, Callable(), func() -> bool: return modal[0])
	var confirmations := [0]
	var pickup_requests: Array[Array] = []
	var feedback: Array[GroundItemPickupResult] = []
	confirmation.pressed.connect(func() -> void: confirmations[0] += 1)
	controller.connect(&"pickup_requested", func(drop_id: StringName, owner: StringName) -> void: pickup_requests.append([drop_id, owner]))
	controller.connect(&"pickup_feedback", func(result: GroundItemPickupResult) -> void: feedback.append(result))
	await process_frame
	var chest := _chest_for(chests, record.drop_id)
	var anchor := chest.call(&"tooltip_anchor") as Control if chest != null else null
	_marker_assert([MARKER_MOUSE], anchor != null and anchor.visible, "modal fixture projects the real ground anchor")
	if anchor != null:
		confirmation.position = anchor.position
		confirmation.size = anchor.size
		_marker_assert([MARKER_MOUSE], confirmation.get_index() < anchor.get_index(), "modal confirmation is beneath the projected ground anchor at the same point")
		_marker_assert([MARKER_MOUSE], anchor.mouse_filter == Control.MOUSE_FILTER_STOP, "existing ground anchor starts pointer-active before the pause-driven modal opens")
		var click_point := anchor.get_global_rect().get_center()
		var anchor_position_before_pause := anchor.position
		camera.position.x += 2.0
		modal[0] = true
		paused = true
		await process_frame
		_marker_assert([MARKER_MOUSE], controller.process_mode == Node.PROCESS_MODE_ALWAYS, "ground controller continues only its pause-safe synchronization while the SceneTree is paused")
		_marker_assert([MARKER_MOUSE], anchor.mouse_filter == Control.MOUSE_FILTER_IGNORE, "existing ground anchor releases pointer capture after the pause-driven modal opens")
		var paused_projection := controller.call(&"projection_diagnostics") as Dictionary
		_marker_assert([MARKER_MOUSE], int(paused_projection.get("last_frame_work", -1)) == 0 and anchor.position == anchor_position_before_pause, "paused modal synchronization performs zero projection work despite camera motion")
		await _dispatch_viewport_mouse_click(viewport, click_point, 0)
		_marker_assert([MARKER_MOUSE], confirmations[0] == 1, "paused active modal confirmation receives the actual overlapping click")
		_marker_assert([MARKER_MOUSE], pickup_requests.is_empty() and feedback.is_empty() and registry.record(record.drop_id) != null, "paused modal click emits no ground pickup request or feedback")
		camera.position.x -= 2.0
		modal[0] = false
		paused = false
		await process_frame
		_marker_assert([MARKER_MOUSE], anchor.mouse_filter == Control.MOUSE_FILTER_STOP, "existing ground anchor restores pointer capture after unpause and modal close")
		await _dispatch_viewport_mouse_click(viewport, click_point, 0)
		_marker_assert([MARKER_MOUSE], confirmations[0] == 1, "closed modal no longer receives the overlapping click")
		_marker_assert([MARKER_MOUSE], pickup_requests == [[record.drop_id, context.run_player_id]], "ground interaction restores exactly one owned request after modal close")
		_marker_assert([MARKER_MOUSE], feedback.size() == 1 and feedback[0].code == GroundItemPickupResult.Code.OK, "restored ground interaction emits exactly one typed OK result")
		_marker_assert([MARKER_MOUSE], _inventory_instance_count(context, generated.item.instance_id) == 1 and registry.record(record.drop_id) == null, "restored ground interaction stores one instance and removes the chest")
	paused = false
	controller.queue_free()
	await process_frame
	viewport.free()
	contexts.clear()
	RenderingServer.force_sync()


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
	registry.add(_record(&"keyboard-out", &"keyboard", Vector3(-4.0, 0.0, 0.0), 1))
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
	await process_frame
	await _dispatch(_button(1, JOY_BUTTON_DPAD_RIGHT))
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"p2-near", "device 1 selects only P2 owned visible nearby loot")
	_assert(controller.call(&"selection_for_owner", &"player_1") == &"", "device 1 cannot change P1 selection")
	await _dispatch(_button(0, JOY_BUTTON_DPAD_RIGHT))
	_assert(controller.call(&"selection_for_owner", &"player_1") == &"p1-near", "device 0 selects the visible in-viewport P1 entry")
	var selected_chest := _chest_for(chests, &"p1-near")
	var selected_anchor := selected_chest.call(&"tooltip_anchor") as Button if selected_chest != null else null
	var shared_tooltip := tooltip_layer.get_children().filter(func(child: Node) -> bool: return child is ItemTooltipPanel).front() as ItemTooltipPanel
	_assert(selected_anchor != null and selected_anchor.has_focus(), "controller selection focuses the projected chest anchor")
	_assert(shared_tooltip != null and shared_tooltip.visible and shared_tooltip.is_current_source(&"ground-loot:p1-near"), "controller selection presents the one shared tooltip")
	_assert(selected_anchor != null and selected_anchor.text.contains("1.0 m"), "selected chest displays leader-relative distance")
	_assert(selected_chest != null and selected_chest.get_node_or_null("SelectionRing") is MeshInstance3D and (selected_chest.get_node("SelectionRing") as MeshInstance3D).visible, "selected chest exposes a non-color-only ring shape")
	await _dispatch(_button(0, JOY_BUTTON_DPAD_RIGHT))
	_assert(controller.call(&"selection_for_owner", &"player_1") == &"p1-near", "in-front but off-viewport P1 entry is excluded without a custom visibility filter")
	modal[0] = true
	await _dispatch(_button(0, JOY_BUTTON_DPAD_LEFT))
	_assert(controller.call(&"selection_for_owner", &"player_1") == &"p1-near", "modal input suppression preserves selection")
	modal[0] = false
	await process_frame
	_assert(controller.call(&"selection_for_owner", &"player_1") == &"p1-near", "ledger-close equivalent preserves the prior target")
	var forwarded: Array[Array] = []
	var statuses: Array[String] = []
	var feedback: Array[GroundItemPickupResult] = []
	controller.connect(&"pickup_requested", func(drop_id: StringName, owner: StringName) -> void: forwarded.append([drop_id, owner]))
	controller.connect(&"status_changed", func(status: String) -> void: statuses.append(status))
	controller.connect(&"pickup_feedback", func(result: GroundItemPickupResult) -> void: feedback.append(result))
	var chest := _chest_for(chests, &"p1-near")
	_assert(chest != null, "public chest parent exposes the projected P1 chest")
	if chest == null:
		await _teardown_controller(controller, chests, tooltip_layer, "real controller early teardown")
		host.free()
		contexts.clear()
		return
	var keyboard_out_anchor := (_chest_for(chests, &"keyboard-out").call(&"tooltip_anchor") as Button)
	await _dispatch_mouse_click(keyboard_out_anchor, -1)
	_assert(forwarded.has([&"keyboard-out", &"keyboard"]), "actual viewport-dispatched KB/M click reaches the exact out-of-range owned chest")
	_assert(controller.call(&"selection_for_owner", &"keyboard") == &"keyboard-out", "out-of-range mouse click establishes the KB/M-owned selection before collection")
	_assert(statuses.has("Move closer"), "out-of-range mouse activation emits exact Move closer status")
	_assert(controller.call(&"selection_for_owner", &"keyboard") == &"keyboard-out", "out-of-range mouse activation preserves the KB/M selection")
	_assert(keyboard_out_anchor.text.contains("Move closer"), "Move closer remains visible on the retained mouse selection")
	_assert(not feedback.is_empty() and feedback[-1].code == GroundItemPickupResult.Code.MOVE_CLOSER and feedback[-1].message == "Move closer", "out-of-range mouse activation emits typed player-facing feedback")
	await _dispatch(_button(1, JOY_BUTTON_DPAD_RIGHT))
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"p2-out", "real P2 D-pad cycle selects owned visible loot outside pickup range")
	await _dispatch(_button(1, JOY_BUTTON_A))
	modal[0] = true
	await _dispatch(_button(1, JOY_BUTTON_DPAD_LEFT))
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"p2-out", "modal input preserves the real out-of-range selection")
	modal[0] = false
	await process_frame
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"p2-out", "ledger close preserves the real out-of-range selection")
	_assert(registry.record(&"p1-near") != null and controller.call(&"selection_for_owner", &"player_1") == &"p1-near", "failed pickups preserve chest and selection")
	var replacement_live_registry := GroundItemRegistry.new()
	replacement_live_registry.add(_record(&"p2-out", &"player_2", Vector3(4.0, 0.0, 0.0), 0))
	var statuses_before_reconfigure := statuses.size()
	controller.call(&"configure", replacement_live_registry, {}, func(record: GroundItemRecord) -> Dictionary: return _detail(record), camera, chests, tooltip_layer)
	var replacement_index := (load(REQUIRED[0]) as Script).new(replacement_live_registry, 4.0) as RefCounted
	var replacement_targeting := (load(REQUIRED[1]) as Script).new() as RefCounted
	var replacement_pickup := (load(REQUIRED[2]) as Script).new(replacement_live_registry, contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.0) as RefCounted
	controller.call(&"configure_interaction", replacement_index, replacement_targeting, replacement_pickup, contexts, 200.0, Callable(), func() -> bool: return modal[0])
	await process_frame
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"", "same-ID registry reconfigure clears the prior owner selection")
	var rebound_anchor := _chest_for(chests, &"p2-out").call(&"tooltip_anchor") as Button
	_assert(not rebound_anchor.text.contains("Move closer") and rebound_anchor.accessibility_description.is_empty(), "reconfigured chest exposes no stale public Move closer status")
	_assert((controller.get("_status_by_owner") as Dictionary).is_empty(), "reconfigure clears the production-consumed owner status state")
	_assert(not (statuses.slice(statuses_before_reconfigure) as Array).has("Move closer"), "reconfigure emits no stale Move closer status to Main or the badge")
	var statuses_before_reconfigure_accept := statuses.size()
	await _dispatch(_button(1, JOY_BUTTON_A))
	_assert(statuses.size() == statuses_before_reconfigure_accept, "ui_accept cannot collect after reconfigure until a new real selection")
	await _dispatch(_button(1, JOY_BUTTON_DPAD_RIGHT))
	_assert(controller.call(&"selection_for_owner", &"player_2") == &"p2-out", "new registry requires and accepts a fresh real D-pad selection")
	await _dispatch(_button(1, JOY_BUTTON_A))
	_assert(statuses.size() == statuses_before_reconfigure_accept + 1 and statuses[-1] == "Move closer", "ui_accept routes only after the new registry selection")
	await _teardown_controller(controller, chests, tooltip_layer, "real controller teardown")
	host.free()
	contexts.clear()
	RenderingServer.force_sync()

func _test_success_advances_selection() -> void:
	var contexts := RunContextRegistry.new()
	var owner := _context(&"success-owner", "profile-success-owner", 0, 3, 1)
	_assert(contexts.register_context(owner, 3).ok(), "success fixture registers its controller owner")
	var registry := GroundItemRegistry.new()
	for index: int in range(3):
		var request := ItemGenerationRequest.create(7200 + index, index, 10, &"ordinary_enemy", &"ordinary_drop", [&"common"])
		request.forced_base_id = &"windrunner_band"
		request.forced_rarity_id = &"common"
		var generated := owner.issue_ground_item(request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
		_assert(generated != null and generated.ok(), "success fixture issues canonical ground item %d" % index)
		if generated == null or not generated.ok():
			continue
		var record := _record(StringName("success-%d" % index), owner.run_player_id, Vector3(float(index + 1), 0.0, 0.0), index)
		record.item_id = generated.item.instance_id
		record.profile_id = owner.profile_id
		record.player_number = 1
		record.color_id = &"red"
		_assert(registry.add(record), "success fixture registers ground record %d" % index)
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
	controller.call(&"configure", registry, {}, func(record: GroundItemRecord) -> Dictionary: return _detail(record), camera, chests, tooltip_layer)
	controller.call(&"configure_interaction", (load(REQUIRED[0]) as Script).new(registry, 4.0), (load(REQUIRED[1]) as Script).new(), (load(REQUIRED[2]) as Script).new(registry, contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.5), contexts, 20.0)
	await process_frame
	await _dispatch(_button(3, JOY_BUTTON_DPAD_RIGHT))
	_assert(controller.call(&"selection_for_owner", owner.run_player_id) == &"success-0", "nearest owned chest is selected first")
	await _dispatch(_button(3, JOY_BUTTON_A))
	_assert(registry.record(&"success-0") == null, "successful south-face pickup removes the selected authoritative record")
	_assert(controller.call(&"selection_for_owner", owner.run_player_id) == &"success-1", "successful removal advances to the nearest remaining visible owned chest")
	await _dispatch(_button(3, JOY_BUTTON_A))
	_assert(controller.call(&"selection_for_owner", owner.run_player_id) == &"success-2", "second successful removal advances stably again")
	await _dispatch(_button(3, JOY_BUTTON_A))
	_assert(controller.call(&"selection_for_owner", owner.run_player_id) == &"", "collecting the final owned chest clears selection")
	_assert(registry.all_records().is_empty(), "multi-chest success flow removes all three exact records")
	await _teardown_controller(controller, chests, tooltip_layer, "successful pickup teardown")
	host.free()
	contexts.clear()
	RenderingServer.force_sync()

func _test_pooled_selection_visual_reset() -> void:
	var contexts := RunContextRegistry.new()
	var owner := _context(&"pool-owner", "profile-pool-owner", 0, 4, 0)
	_assert(contexts.register_context(owner, 4).ok(), "pool lifecycle fixture registers its controller owner")
	var registry := GroundItemRegistry.new(1)
	_assert(registry.add(_record(&"pooled-selected", owner.run_player_id, Vector3(1.0, 0.0, 0.0), 0)), "pool lifecycle fixture registers the selected record")
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
	controller.call(&"configure", registry, {}, func(record: GroundItemRecord) -> Dictionary: return _detail(record), camera, chests, tooltip_layer)
	controller.call(&"configure_interaction", (load(REQUIRED[0]) as Script).new(registry, 4.0), (load(REQUIRED[1]) as Script).new(), null, contexts, 20.0)
	await process_frame
	await _dispatch(_button(4, JOY_BUTTON_DPAD_RIGHT))
	var selected_chest := _chest_for(chests, &"pooled-selected")
	var selected_anchor := selected_chest.call(&"tooltip_anchor") as Button if selected_chest != null else null
	var selection_ring := selected_chest.get_node_or_null("SelectionRing") as MeshInstance3D if selected_chest != null else null
	var shared_tooltip := tooltip_layer.get_children().filter(func(child: Node) -> bool: return child is ItemTooltipPanel).front() as ItemTooltipPanel
	_assert(selected_chest != null and selected_chest.call(&"is_selected"), "pooled chest starts selected through real controller input")
	_assert(selection_ring != null and selection_ring.visible, "selected pooled chest starts with its ring visible")
	_assert(selected_anchor != null and selected_anchor.text.contains("m") and selected_anchor.get_theme_color("font_color") == Color(0.86, 1.0, 0.78), "selected pooled anchor starts with distance text and selected font style")
	if selected_anchor != null:
		selected_anchor.mouse_entered.emit()
	_assert(shared_tooltip != null and shared_tooltip.visible and shared_tooltip.is_current_source(&"ground-loot:pooled-selected"), "selected pooled chest owns the shared tooltip before removal")
	var removed := registry.remove(&"pooled-selected")
	_assert(removed != null and not selected_chest.visible, "removing the selected record deactivates it into the production pool")
	_assert(registry.add(_record(&"pooled-fresh", owner.run_player_id, Vector3(2.0, 0.0, 0.0), 0)), "pool lifecycle fixture adds a fresh unselected record")
	var reused_chest := _chest_for(chests, &"pooled-fresh")
	var reused_anchor := reused_chest.call(&"tooltip_anchor") as Button if reused_chest != null else null
	_assert(reused_chest == selected_chest, "fresh record reuses the exact pooled production chest")
	_assert(reused_chest != null and not reused_chest.call(&"is_selected"), "reused chest clears its selected state")
	_assert(selection_ring != null and not selection_ring.visible, "reused unselected chest hides the prior selection ring")
	_assert(reused_anchor != null and reused_anchor.text.is_empty() and reused_anchor.get_theme_color("font_color") == Color.WHITE, "reused anchor clears selected distance text and font style")
	_assert(reused_anchor != null and not reused_anchor.has_focus() and reused_anchor.accessibility_description.is_empty(), "reused anchor clears prior focus and selected accessibility description")
	_assert(reused_anchor != null and reused_anchor.accessibility_name.contains("pooled-fresh") and not reused_anchor.accessibility_name.contains("pooled-selected"), "reused anchor publishes only the fresh record accessibility name")
	_assert(controller.call(&"selection_for_owner", owner.run_player_id) == &"", "fresh pooled record remains unselected")
	_assert(shared_tooltip != null and not shared_tooltip.visible and not shared_tooltip.is_current_source(&"ground-loot:pooled-selected") and not shared_tooltip.is_current_source(&"ground-loot:pooled-fresh"), "reused chest leaks no hover or shared-tooltip ownership")
	await _teardown_controller(controller, chests, tooltip_layer, "pooled chest teardown")
	host.free()
	contexts.clear()
	RenderingServer.force_sync()

func _test_viewport_resize_projection() -> void:
	var contexts := RunContextRegistry.new()
	var context := _context(&"resize-owner", "profile-resize-owner", 0, 2, 0)
	_assert(contexts.register_context(context, 2).ok(), "viewport fixture registers device ownership")
	var registry := GroundItemRegistry.new()
	registry.add(_record(&"resize-edge", &"resize-owner", Vector3(6.0, 0.0, -10.0), 0))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 600)
	root.add_child(viewport)
	var host := Node.new()
	var chests := Node3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(800.0, 600.0)
	var camera := Camera3D.new()
	viewport.add_child(host)
	host.add_child(chests)
	host.add_child(tooltip_layer)
	host.add_child(camera)
	camera.current = true
	var controller := (load("res://scripts/world/ground_item_world_controller.gd") as Script).new() as Node
	host.add_child(controller)
	controller.call(&"configure", registry, {}, func(record: GroundItemRecord) -> Dictionary: return _detail(record), camera, chests, tooltip_layer)
	var index := (load(REQUIRED[0]) as Script).new(registry, 4.0) as RefCounted
	var targeting := (load(REQUIRED[1]) as Script).new() as RefCounted
	controller.call(&"configure_interaction", index, targeting, null, contexts, 20.0)
	await process_frame
	var chest := _chest_for(chests, &"resize-edge")
	_assert(chest != null, "viewport fixture projects the edge chest")
	if chest != null:
		var anchor := chest.call(&"tooltip_anchor") as Control
		var position_before := anchor.position
		_assert(anchor.visible, "edge chest starts inside the large viewport")
		viewport.size = Vector2i(80, 60)
		await process_frame
		_assert(anchor.position != position_before and not anchor.visible, "viewport resize reprojects and hides the fixed-size offscreen anchor without record dirtiness")
		await _dispatch(_button(2, JOY_BUTTON_DPAD_RIGHT))
		_assert(controller.call(&"selection_for_owner", &"resize-owner") == &"", "resized-offscreen chest is excluded from real controller cycling")
	await _teardown_controller(controller, chests, tooltip_layer, "viewport teardown")
	viewport.free()
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

func _dispatch(event: InputEvent) -> void:
	root.push_input(event, true)
	await process_frame
	if event is InputEventJoypadButton:
		var released := event.duplicate() as InputEventJoypadButton
		released.pressed = false
		Input.parse_input_event(released)
		await process_frame

func _dispatch_mouse_click(control: Control, device: int) -> void:
	var event := _mouse_button(device)
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	root.push_input(event, true)
	await process_frame
	var released := event.duplicate() as InputEventMouseButton
	released.pressed = false
	root.push_input(released, true)
	await process_frame

func _dispatch_viewport_mouse_motion(viewport: SubViewport, position: Vector2, device: int) -> void:
	var event := InputEventMouseMotion.new()
	event.device = device
	event.position = position
	event.global_position = position
	viewport.push_input(event, true)
	await process_frame

func _dispatch_viewport_mouse_click(viewport: SubViewport, position: Vector2, device: int) -> void:
	var event := _mouse_button(device)
	event.position = position
	event.global_position = position
	viewport.push_input(event, true)
	await process_frame
	var released := event.duplicate() as InputEventMouseButton
	released.pressed = false
	viewport.push_input(released, true)
	await process_frame

func _dispatch_viewport_key(viewport: SubViewport, keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	viewport.push_input(event, true)
	await process_frame

func _dispatch_viewport_button(viewport: SubViewport, device: int, button: JoyButton) -> void:
	var event := _button(device, button)
	viewport.push_input(event, true)
	await process_frame
	var released := event.duplicate() as InputEventJoypadButton
	released.pressed = false
	viewport.push_input(released, true)
	await process_frame

func _wait_for_tooltip_hidden(tooltip: ItemTooltipPanel) -> void:
	for _frame: int in range(120):
		if not tooltip.visible:
			return
		await process_frame

func _wait_past_tooltip_grace() -> void:
	# The production contract intentionally uses a 0.12-second dismissal grace.
	await create_timer(0.16).timeout
	await process_frame

func _inventory_instance_count(context: PlayerRunContext, instance_id: String) -> int:
	var inventory := context.run_inventory()
	if inventory == null:
		return 0
	var count := 0
	for slot: int in inventory.occupied_slots():
		if inventory.item_id_at(slot) == instance_id:
			count += 1
	return count

func _feedback_code_count(feedback: Array[GroundItemPickupResult], code: GroundItemPickupResult.Code) -> int:
	return feedback.filter(func(result: GroundItemPickupResult) -> bool: return result.code == code).size()

func _teardown_controller(controller: Node, chests: Node3D, tooltip_layer: Control, label: String) -> void:
	controller.queue_free()
	await process_frame
	_assert(chests.get_child_count() == 0, "%s clears every active and pooled chest" % label)
	_assert(tooltip_layer.get_child_count() == 0, "%s clears projected anchors and the owned shared tooltip" % label)

func _chest_for(parent: Node3D, drop_id: StringName) -> Node3D:
	for child: Node in parent.get_children():
		if child is Node3D and StringName(child.get("drop_id")) == drop_id:
			return child as Node3D
	return null
