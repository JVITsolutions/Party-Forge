extends SceneTree

const RECORD_COUNT := 2000
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
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	for slot: int in OWNER_IDS.size():
		var context := _context(slot)
		_assert(_contexts.register_context(context, slot).ok(), "scale context P%d registers on device %d" % [slot + 1, slot])
	var identity_assignment := LocalPlayerIdentityService.new().assign(_contexts.all_contexts())
	_assert(identity_assignment.ok(), "scale contexts receive four distinct production identities")
	var identities := identity_assignment.identities()

	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var registry := GroundItemRegistry.new(RECORD_COUNT)
	for record_index: int in RECORD_COUNT:
		var owner_index := record_index % OWNER_IDS.size()
		_assert(registry.add(_record(record_index, owner_index)), "scale record %d registers" % record_index)
	_assert(registry.all_records().size() == RECORD_COUNT, "all 2,000 records exist before frame measurement")
	for owner_id: StringName in OWNER_IDS:
		_assert(registry.for_owner(owner_id).size() == RECORD_COUNT / OWNER_IDS.size(), "%s owns exactly 500 records" % owner_id)

	var host := Node.new()
	var chests := Node3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(root.size)
	var camera := Camera3D.new()
	host.add_child(chests)
	host.add_child(tooltip_layer)
	host.add_child(camera)
	root.add_child(host)
	camera.look_at_from_position(Vector3(0.0, 80.0, 80.0), Vector3.ZERO)
	camera.current = true
	var world := WORLD_CONTROLLER.new() as Node
	host.add_child(world)
	world.configure(registry, identities, Callable(self, "_detail_for"), camera, chests, tooltip_layer)
	var spatial_index := SPATIAL_INDEX.new(registry, 8.0) as RefCounted
	var targeting := TARGETING_SERVICE.new() as RefCounted
	var pickup := PICKUP_SERVICE.new(registry, _contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.5) as RefCounted
	world.configure_interaction(spatial_index, targeting, pickup, _contexts, 30.0)
	world.call("_process", 0.0)
	_assert((world.get("_chest_by_drop") as Dictionary).size() == RECORD_COUNT, "production world controller projects all 2,000 simultaneous chests")
	var nearby := targeting.call(&"ordered_for_owner", spatial_index, OWNER_IDS[0], Vector3.ZERO, 12.0) as Array
	_assert(not nearby.is_empty() and nearby.size() < RECORD_COUNT / OWNER_IDS.size(), "owner spatial query remains bounded below the 500-record owner set")
	_assert(nearby.all(func(record: GroundItemRecord) -> bool: return record.run_player_id == OWNER_IDS[0]), "bounded spatial query returns only its requested owner")
	var constants := (load("res://scripts/world/ground_item_world_controller.gd") as Script).get_script_constant_map()
	_assert(int(constants.get("MAX_INACTIVE_CHESTS", 0)) == 64, "production chest pool has the exact bounded inactive limit")

	for _warmup: int in 3:
		await process_frame
	var peak_frame_ms := 0.0
	for _sample: int in FRAME_SAMPLES:
		await process_frame
		peak_frame_ms = maxf(peak_frame_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var memory_after := Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_peak := Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	_assert(is_finite(peak_frame_ms) and peak_frame_ms >= 0.0, "peak frame observation is finite and nonnegative")
	_assert(is_finite(memory_before) and is_finite(memory_after) and is_finite(memory_peak), "static memory observations are finite")
	_assert(memory_before >= 0.0 and memory_after >= memory_before and memory_peak >= memory_after, "static memory observations are ordered and nonnegative")

	print("LIVE_LOOT_MEMORY_SUMMARY: before_bytes=%d after_bytes=%d peak_bytes=%d projected=%d pool_limit=%d frame_samples=%d" % [
		int(memory_before), int(memory_after), int(memory_peak), (world.get("_chest_by_drop") as Dictionary).size(),
		int(constants.get("MAX_INACTIVE_CHESTS", 0)), FRAME_SAMPLES,
	])
	print("LIVE_LOOT_SCALE_SUMMARY: chests=%d owners=%d peak_frame_ms=%.3f" % [registry.all_records().size(), 4, peak_frame_ms])
	var hard_failure := registry.all_records().size() != 2000 or peak_frame_ms > 33.4

	world.clear_projection()
	host.free()
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
