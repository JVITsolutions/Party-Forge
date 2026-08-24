extends SceneTree

const RECORD_COUNT := 2000
const CRITICAL_IDS: Array[StringName] = [&"zz-selected", &"zz-hover", &"zz-focus"]
const OWNER_IDS: Array[StringName] = [&"scale_p1", &"scale_p2", &"scale_p3", &"scale_p4"]
const COLOR_IDS: Array[StringName] = [&"red", &"blue", &"yellow", &"green"]
const FRAME_SAMPLES := 60
const WORLD_CONTROLLER := preload("res://scripts/world/ground_item_world_controller.gd")
const SPATIAL_INDEX := preload("res://scripts/loot/ground_item_spatial_index.gd")
const TARGETING_SERVICE := preload("res://scripts/loot/ground_item_targeting_service.gd")
const PICKUP_SERVICE := preload("res://scripts/loot/ground_item_pickup_service.gd")

var _failures: Array[String] = []
var _contexts := RunContextRegistry.new()
var _parties: Array[PartyManager] = []
var _actors: Array[Node3D] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for slot: int in OWNER_IDS.size():
		var context := _context(slot)
		_assert(_contexts.register_context(context, slot).ok(), "scale context P%d registers on device %d" % [slot + 1, slot])
	var identity_assignment := LocalPlayerIdentityService.new().assign(_contexts.all_contexts())
	_assert(identity_assignment.ok(), "scale contexts receive four distinct production identities")
	var identities := identity_assignment.identities()

	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var registry := GroundItemRegistry.new(RECORD_COUNT + CRITICAL_IDS.size())
	for record_index: int in RECORD_COUNT:
		var owner_index := record_index % OWNER_IDS.size()
		_assert(registry.add(_record(record_index, owner_index)), "scale record %d registers" % record_index)
	_assert(registry.add(_critical_record(CRITICAL_IDS[0], 0, Vector3(-12.0, 0.0, -10.5))), "late-sorting selected record registers")
	_assert(registry.add(_critical_record(CRITICAL_IDS[1], 1, Vector3(0.0, 0.0, 0.0))), "late-sorting hover record registers")
	_assert(registry.add(_critical_record(CRITICAL_IDS[2], 2, Vector3(8.0, 0.0, 0.0))), "late-sorting focus record registers")
	(_actors[0] as Node3D).position = Vector3(-12.0, 0.0, -10.5)
	_assert(registry.all_records().size() == RECORD_COUNT + CRITICAL_IDS.size(), "2,000 ordinary and three critical records exist before frame measurement")
	for owner_id: StringName in OWNER_IDS:
		_assert(registry.for_owner(owner_id).size() >= RECORD_COUNT / OWNER_IDS.size(), "%s retains at least 500 ordinary records" % owner_id)

	var host := Node.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var chests := Node3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(viewport.size)
	var camera := Camera3D.new()
	host.add_child(chests)
	host.add_child(tooltip_layer)
	host.add_child(camera)
	viewport.add_child(host)
	root.add_child(viewport)
	camera.look_at_from_position(Vector3(0.0, 80.0, 80.0), Vector3.ZERO)
	camera.current = true
	var world := WORLD_CONTROLLER.new() as Node
	host.add_child(world)
	world.configure(registry, identities, Callable(self, "_detail_for"), camera, chests, tooltip_layer)
	var spatial_index := SPATIAL_INDEX.new(registry, 8.0) as RefCounted
	var targeting := TARGETING_SERVICE.new() as RefCounted
	var pickup := PICKUP_SERVICE.new(registry, _contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.5) as RefCounted
	var modal := [false]
	world.configure_interaction(spatial_index, targeting, pickup, _contexts, 30.0, Callable(), func() -> bool: return modal[0])
	await process_frame
	_assert((world.get("_chest_by_drop") as Dictionary).size() == RECORD_COUNT + CRITICAL_IDS.size(), "production world controller projects all 2,000 ordinary and three critical chests")
	var nearby := targeting.call(&"ordered_for_owner", spatial_index, OWNER_IDS[0], Vector3.ZERO, 12.0) as Array
	_assert(not nearby.is_empty() and nearby.size() < RECORD_COUNT / OWNER_IDS.size(), "owner spatial query remains bounded below the 500-record owner set")
	_assert(nearby.all(func(record: GroundItemRecord) -> bool: return record.run_player_id == OWNER_IDS[0]), "bounded spatial query returns only its requested owner")
	var p1_origin := (_contexts.context_for(OWNER_IDS[0]).member_position(1) as Dictionary).get("position", Vector3.ZERO) as Vector3
	var p1_targets := targeting.call(&"ordered_for_owner", spatial_index, OWNER_IDS[0], p1_origin, 30.0) as Array
	_assert(not p1_targets.is_empty() and (p1_targets[0] as GroundItemRecord).drop_id == CRITICAL_IDS[0], "late-sorting selected fixture is the nearest P1 target")
	var constants := (load("res://scripts/world/ground_item_world_controller.gd") as Script).get_script_constant_map()
	_assert(int(constants.get("MAX_INACTIVE_CHESTS", 0)) == 64, "production chest pool has the exact bounded inactive limit")

	for _warmup: int in 3:
		await process_frame
	await _dispatch(viewport, _button(0, JOY_BUTTON_DPAD_RIGHT))
	_assert(world.selection_for_owner(OWNER_IDS[0]) == CRITICAL_IDS[0], "actual controller input selects the nearest late-sorting owned record")
	var selected_anchor := _anchor_for(world, CRITICAL_IDS[0])
	var hover_anchor := _anchor_for(world, CRITICAL_IDS[1])
	var focus_anchor := _anchor_for(world, CRITICAL_IDS[2])
	var ordinary_anchor := _anchor_for(world, &"scale-drop-1999")
	_assert(selected_anchor != null and hover_anchor != null and focus_anchor != null and ordinary_anchor != null, "critical and ordinary anchors are projected")
	var selected_position_before_pause := selected_anchor.position if selected_anchor != null else Vector2.ZERO
	camera.position.x += 5.0
	modal[0] = true
	paused = true
	await process_frame
	var paused_projection := world.call(&"projection_diagnostics") as Dictionary
	_assert(world.process_mode == Node.PROCESS_MODE_ALWAYS, "scale world controller remains scheduled for pause-safe modal synchronization")
	_assert(selected_anchor != null and selected_anchor.mouse_filter == Control.MOUSE_FILTER_IGNORE, "pause-driven modal suppresses an existing scale anchor")
	_assert(int(paused_projection.get("last_frame_work", -1)) == 0 and selected_anchor != null and selected_anchor.position == selected_position_before_pause, "paused scale controller performs zero projection work despite camera motion")
	for _paused_sample: int in 3:
		camera.position.x += 1.0
		await process_frame
		_assert(int((world.call(&"projection_diagnostics") as Dictionary).get("last_frame_work", -1)) == 0, "stable paused scale frame performs zero projection work")
	modal[0] = false
	paused = false
	camera.position.x = 0.0
	await process_frame
	_assert(selected_anchor != null and selected_anchor.mouse_filter == Control.MOUSE_FILTER_STOP, "unpaused scale controller restores ground-anchor pointer capture")
	if hover_anchor != null:
		hover_anchor.mouse_entered.emit()
	if focus_anchor != null:
		focus_anchor.grab_focus()
	await process_frame
	var selected_position_before := selected_anchor.position if selected_anchor != null else Vector2.ZERO
	var hover_position_before := hover_anchor.position if hover_anchor != null else Vector2.ZERO
	var focus_position_before := focus_anchor.position if focus_anchor != null else Vector2.ZERO
	var ordinary_position_before := ordinary_anchor.position if ordinary_anchor != null else Vector2.ZERO
	var selected_distance_before := selected_anchor.accessibility_name if selected_anchor != null else ""
	var hover_distance_before := hover_anchor.accessibility_name if hover_anchor != null else ""
	var focus_distance_before := focus_anchor.accessibility_name if focus_anchor != null else ""
	for actor_index: int in 3:
		(_actors[actor_index] as Node3D).position.x += 1.0
	camera.position.x += 7.0
	viewport.size = Vector2i(2560, 1440)
	tooltip_layer.size = Vector2(viewport.size)
	await process_frame
	_assert(selected_anchor != null and selected_anchor.position != selected_position_before and selected_anchor.accessibility_name != selected_distance_before, "late selected chest refreshes anchor and leader distance in the invalidation frame")
	_assert(hover_anchor != null and hover_anchor.position != hover_position_before and hover_anchor.accessibility_name != hover_distance_before, "late hovered chest refreshes anchor and leader distance in the invalidation frame")
	_assert(focus_anchor != null and focus_anchor.position != focus_position_before and focus_anchor.accessibility_name != focus_distance_before, "late focus-inspected chest refreshes anchor and leader distance in the invalidation frame")
	_assert(ordinary_anchor != null and ordinary_anchor.position == ordinary_position_before, "late ordinary work remains queued after critical same-frame projection")
	var peak_frame_ms := 0.0
	var peak_projection_work := 0
	var peak_pending_projection := 0
	_assert(world.has_method(&"projection_diagnostics") and world.has_signal(&"projection_diagnostics_changed"), "production controller publishes bounded runtime projection diagnostics")
	for sample: int in FRAME_SAMPLES:
		camera.position.x = sin(float(sample) * 0.37) * 18.0
		camera.position.z = 80.0 + cos(float(sample) * 0.21) * 12.0
		camera.look_at(Vector3.ZERO)
		viewport.size = Vector2i(1920, 1080) if sample % 2 == 0 else Vector2i(2560, 1440)
		tooltip_layer.size = Vector2(viewport.size)
		await process_frame
		peak_frame_ms = maxf(peak_frame_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		if world.has_method(&"projection_diagnostics"):
			var projection := world.call(&"projection_diagnostics") as Dictionary
			peak_projection_work = maxi(peak_projection_work, int(projection.get("last_frame_work", 0)))
			peak_pending_projection = maxi(peak_pending_projection, int(projection.get("pending", 0)))
	var settle_frames := 0
	if world.has_method(&"projection_diagnostics"):
		while int((world.call(&"projection_diagnostics") as Dictionary).get("pending", 0)) > 0 and settle_frames < 128:
			await process_frame
			settle_frames += 1
		_assert(int((world.call(&"projection_diagnostics") as Dictionary).get("pending", 0)) == 0, "moving-camera projection reaches eventual correctness after motion stops")
	_assert(ordinary_anchor != null and ordinary_anchor.position != ordinary_position_before, "late ordinary projection reaches eventual correctness after motion stops")
	var memory_after := Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_peak := Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	var projection_limit := int(constants.get("MAX_PROJECTIONS_PER_FRAME", 0))
	_assert(projection_limit > 0 and peak_projection_work <= projection_limit, "moving camera/viewport projection work stays within the production per-frame bound")
	_assert(int((world.call(&"projection_diagnostics") as Dictionary).get("peak_work", 0)) >= peak_projection_work, "production runtime diagnostics retain peak critical-plus-ordinary projection work")
	_assert(peak_pending_projection > 0, "moving camera/viewport leaves observable bounded work pending")
	_assert(is_finite(peak_frame_ms) and peak_frame_ms >= 0.0, "peak frame observation is finite and nonnegative")
	_assert(is_finite(memory_before) and is_finite(memory_after) and is_finite(memory_peak), "static memory observations are finite")
	_assert(memory_before >= 0.0 and memory_after >= memory_before and memory_peak >= memory_after, "static memory observations are ordered and nonnegative")

	print("LIVE_LOOT_MEMORY_SUMMARY: before_bytes=%d after_bytes=%d peak_bytes=%d projected=%d pool_limit=%d frame_samples=%d" % [
		int(memory_before), int(memory_after), int(memory_peak), (world.get("_chest_by_drop") as Dictionary).size(),
		int(constants.get("MAX_INACTIVE_CHESTS", 0)), FRAME_SAMPLES,
	])
	print("LIVE_LOOT_SCALE_SUMMARY: chests=%d owners=%d peak_frame_ms=%.3f" % [registry.all_records().size(), 4, peak_frame_ms])
	print("LIVE_LOOT_MOVING_CAMERA_SUMMARY: records=%d samples=%d peak_frame_ms=%.3f peak_projection_work=%d peak_pending=%d settle_frames=%d memory_peak_bytes=%d" % [
		registry.all_records().size(), FRAME_SAMPLES, peak_frame_ms, peak_projection_work, peak_pending_projection, settle_frames, int(memory_peak),
	])
	var hard_failure := registry.all_records().size() < 2000 or peak_frame_ms > 33.4

	paused = false
	world.clear_projection()
	viewport.free()
	_contexts.clear()
	for actor: Node3D in _actors:
		actor.free()
	for party: PartyManager in _parties:
		party.free()
	_actors.clear()
	_parties.clear()
	RenderingServer.force_sync()
	if not hard_failure and _failures.is_empty():
		print("LIVE_LOOT_PERFORMANCE_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LIVE_LOOT_PERFORMANCE_FAILURE: %s" % failure)
	if hard_failure:
		push_error("LIVE_LOOT_PERFORMANCE_FAILURE: hard gate requires 2,000 records and peak frame <= 33.4ms")
	print("LIVE_LOOT_PERFORMANCE_SUMMARY: FAIL")
	quit(1)


func _context(slot: int) -> PlayerRunContext:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var profile := ProfileState.new_profile("scale-profile-%d" % [slot + 1], "Scale P%d" % [slot + 1], 1000, COLOR_IDS[slot])
	profile.inventory_columns = 1
	var context := PlayerRunContext.new()
	_assert(context.configure(OWNER_IDS[slot], slot, profile, 140000 + slot, party, 100).is_empty(), "scale P%d run context configures" % [slot + 1])
	var actor := Node3D.new()
	actor.position = Vector3(float(slot) * 3.0, 0.0, 0.0)
	_actors.append(actor)
	_assert(context.bind_actor(1, actor), "scale P%d leader binds" % [slot + 1])
	return context


func _record(record_index: int, owner_index: int) -> GroundItemRecord:
	var owner_record_index := record_index / OWNER_IDS.size()
	var record := GroundItemRecord.new()
	record.drop_id = StringName("scale-drop-%04d" % record_index)
	record.item_id = "scale-item-%04d" % record_index
	record.run_player_id = OWNER_IDS[owner_index]
	record.profile_id = "scale-profile-%d" % [owner_index + 1]
	record.player_number = owner_index + 1
	record.color_id = COLOR_IDS[owner_index]
	record.world_position = Vector3(float(owner_record_index % 25) - 12.0, 0.0, float(owner_record_index / 25) - 10.0)
	record.rarity_id = [&"common", &"magic", &"rare"][record_index % 3]
	record.source_id = &"ordinary_enemy"
	record.ground_slot = owner_record_index
	return record


func _critical_record(drop_id: StringName, owner_index: int, position: Vector3) -> GroundItemRecord:
	var record := _record(owner_index, owner_index)
	record.drop_id = drop_id
	record.item_id = "critical-item-%s" % drop_id
	record.world_position = position
	record.ground_slot = 700 + owner_index
	return record


func _anchor_for(world: Node, drop_id: StringName) -> Button:
	var chest := (world.get("_chest_by_drop") as Dictionary).get(drop_id) as Node3D
	return chest.call(&"tooltip_anchor") as Button if chest != null else null


func _button(device: int, button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	return event


func _dispatch(viewport: SubViewport, event: InputEventJoypadButton) -> void:
	viewport.push_input(event)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _detail_for(record: GroundItemRecord) -> Dictionary:
	return {
		"instance_id": record.item_id,
		"name": "Scale Chest %s" % record.item_id,
		"rarity_id": String(record.rarity_id),
		"rarity_name": String(record.rarity_id).capitalize(),
		"item_level": 1,
		"compatible_slot_ids": [],
		"affixes": [],
		"modifier_totals": {},
	}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
