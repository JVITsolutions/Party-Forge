extends SceneTree

const OWNER_IDS: Array[StringName] = [&"player_1", &"player_2", &"player_3", &"player_4"]
const PROFILE_IDS: Array[String] = ["profile-live-p1", "profile-live-p2", "profile-live-p3", "profile-live-p4"]
const COLOR_IDS: Array[StringName] = [&"red", &"blue", &"yellow", &"green"]
const FORCED_DEFEAT_SEQUENCE := 13001
const WORLD_CONTROLLER := preload("res://scripts/world/ground_item_world_controller.gd")
const SPATIAL_INDEX := preload("res://scripts/loot/ground_item_spatial_index.gd")
const TARGETING_SERVICE := preload("res://scripts/loot/ground_item_targeting_service.gd")
const PICKUP_SERVICE := preload("res://scripts/loot/ground_item_pickup_service.gd")
const PICKUP_RESULT := preload("res://scripts/loot/ground_item_pickup_result.gd")

var _failures: Array[String] = []
var _contexts := RunContextRegistry.new()
var _parties: Array[PartyManager] = []
var _actors: Array[Node3D] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	for slot: int in OWNER_IDS.size():
		var inventory_columns := 0 if slot == 1 else 1
		var position := Vector3.ZERO if slot < 2 else Vector3(100.0 + float(slot), 0.0, 0.0)
		var context := _context(OWNER_IDS[slot], PROFILE_IDS[slot], slot, COLOR_IDS[slot], inventory_columns, position)
		_assert(_contexts.register_context(context, slot).ok(), "P%d context registers on distinct device %d" % [slot + 1, slot])
	_assert(_contexts.all_contexts().size() == 4, "four real run contexts register")
	for slot: int in OWNER_IDS.size():
		_assert(_contexts.device_for(OWNER_IDS[slot]) == slot, "P%d retains device %d" % [slot + 1, slot])

	var identity_assignment := LocalPlayerIdentityService.new().assign(_contexts.all_contexts())
	_assert(identity_assignment.ok(), "four distinct profile colors receive session identities")
	var identities := identity_assignment.identities()
	for slot: int in OWNER_IDS.size():
		var identity := identities.get(OWNER_IDS[slot], {}) as Dictionary
		_assert(int(identity.get("player_number", 0)) == slot + 1, "P%d identity uses its exact player number" % [slot + 1])
		_assert(StringName(identity.get("color_id", &"")) == COLOR_IDS[slot], "P%d identity uses distinct %s color" % [slot + 1, COLOR_IDS[slot]])

	var loot_tuning := PersonalLootTuning.new()
	loot_tuning.drop_basis_points = {&"ordinary_melee": 0, &"ordinary_specialist": 0, &"elite": 0, &"boss": 0}
	var roll := PersonalLootRollService.new()
	_assert(roll.configure(_contexts, RewardDistributionTuning.new(), loot_tuning, func(_context: PlayerRunContext) -> bool: return true).is_empty(), "production roll service configures")
	var registry := GroundItemRegistry.new()
	var coordinator := PersonalLootDropCoordinator.new()
	_assert(
		coordinator.configure(
			roll,
			_contexts,
			identities,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
			registry,
		).is_empty(),
		"production drop coordinator configures",
	)

	var forced_event := EnemyDefeatEvent.create(
		131313,
		FORCED_DEFEAT_SEQUENCE,
		FORCED_DEFEAT_SEQUENCE,
		&"swarmer",
		&"ordinary_melee",
		Vector3.ZERO,
		180.0,
	)
	var forced_decisions := roll.resolve(forced_event, true)
	_assert(forced_decisions.size() == 4, "one defeat resolves all four participants independently")
	if forced_decisions.size() == 4:
		_assert(forced_decisions[0].success and forced_decisions[0].reason == &"forced_success", "P1 deterministically succeeds for the selected forced defeat")
		_assert(forced_decisions[1].success and forced_decisions[1].reason == &"forced_success", "P2 deterministically succeeds for the selected forced defeat")
		_assert(not forced_decisions[2].success and forced_decisions[2].reason == &"leader_out_of_range", "P3 independently fails the same defeat outside reward range")
		_assert(not forced_decisions[3].success and forced_decisions[3].reason == &"leader_out_of_range", "P4 independently fails the same defeat outside reward range")
	var report := coordinator.resolve_defeat(forced_event)
	_assert(report.get("spawned_drop_ids", []) == [&"drop:player_1:13001", &"drop:player_2:13001"], "the cached forced defeat creates only the two independently successful owner drops")
	_assert((report.get("diagnostics", []) as Array).is_empty(), "mixed same-defeat outcomes create no generation diagnostics")
	var p1_record := registry.record(&"drop:player_1:13001")
	var p2_record := registry.record(&"drop:player_2:13001")
	_assert(p1_record != null and p2_record != null, "both successful owners retain canonical ground records before projection")
	var p1_item_id := p1_record.item_id if p1_record != null else ""

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
	var world := WORLD_CONTROLLER.new() as Node
	host.add_child(world)
	world.configure(registry, identities, Callable(self, "_detail_for"), camera, chests, tooltip_layer)
	await process_frame
	_assert((world.get("_chest_by_drop") as Dictionary).size() == 2, "both owners' chests remain simultaneously visible in the production projection")
	_assert(_projected_chest(world, &"drop:player_1:13001", 1) != null, "P1 chest shows its explicit owner marker")
	_assert(_projected_chest(world, &"drop:player_2:13001", 2) != null, "foreign P2 chest remains visible with its explicit owner marker")

	var spatial_index := SPATIAL_INDEX.new(registry, 4.0) as RefCounted
	var targeting := TARGETING_SERVICE.new() as RefCounted
	var pickup := PICKUP_SERVICE.new(registry, _contexts, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, 3.5) as RefCounted
	world.configure_interaction(spatial_index, targeting, pickup, _contexts, 30.0)
	var p1_targets := targeting.call(&"ordered_for_owner", spatial_index, &"player_1", Vector3.ZERO, 30.0) as Array
	var p2_targets := targeting.call(&"ordered_for_owner", spatial_index, &"player_2", Vector3.ZERO, 30.0) as Array
	_assert(p1_targets.map(func(record: GroundItemRecord) -> StringName: return record.drop_id) == [&"drop:player_1:13001"], "P1 target list excludes the visible foreign chest")
	_assert(p2_targets.map(func(record: GroundItemRecord) -> StringName: return record.drop_id) == [&"drop:player_2:13001"], "P2 target list excludes the visible P1 chest")
	await _dispatch(_dpad_right(0))
	_assert(world.call(&"selection_for_owner", &"player_1") == &"drop:player_1:13001", "device 0 cycles only the P1 chest")
	_assert(StringName(world.call(&"selection_for_owner", &"player_2")).is_empty(), "device 0 cannot target the foreign P2 chest")

	var p1 := _contexts.context_for(&"player_1")
	var p2 := _contexts.context_for(&"player_2")
	var p3 := _contexts.context_for(&"player_3")
	var p4 := _contexts.context_for(&"player_4")
	var states_before := [p1.item_state().to_dictionary(), p2.item_state().to_dictionary(), p3.item_state().to_dictionary(), p4.item_state().to_dictionary()]
	var foreign_result := pickup.call(&"collect", &"drop:player_1:13001", &"player_2") as RefCounted
	_assert(foreign_result.get(&"code") == PICKUP_RESULT.Code.NOT_OWNER, "foreign collection is rejected by the production pickup service")
	_assert(p1.item_state().to_dictionary() == states_before[0] and p2.item_state().to_dictionary() == states_before[1], "foreign collection mutates neither owner")

	var owner_result := pickup.call(&"collect", &"drop:player_1:13001", &"player_1") as RefCounted
	_assert(bool(owner_result.call(&"ok")), "P1 collects its own in-range chest")
	_assert(p1.run_inventory().occupied_slots() == [0] and p1.run_inventory().item_id_at(0) == p1_item_id, "owner pickup moves the exact item only into P1 inventory")
	_assert(p2.item_state().to_dictionary() == states_before[1] and p3.item_state().to_dictionary() == states_before[2] and p4.item_state().to_dictionary() == states_before[3], "owner pickup leaves all foreign canonical states byte-equivalent")
	_assert(registry.record(&"drop:player_1:13001") == null and registry.record(&"drop:player_2:13001") != null, "owner pickup removes only the owner's chest")

	var p2_before_full := p2.item_state().to_dictionary()
	var full_result := pickup.call(&"collect", &"drop:player_2:13001", &"player_2") as RefCounted
	_assert(full_result.get(&"code") == PICKUP_RESULT.Code.INVENTORY_FULL and full_result.get(&"message") == "Inventory full", "P2 full inventory returns the exact production rejection")
	_assert(p2.item_state().to_dictionary() == p2_before_full, "full inventory leaves the owner's canonical state unchanged")
	_assert(registry.all_records().map(func(record: GroundItemRecord) -> StringName: return record.drop_id) == [&"drop:player_2:13001"], "full inventory leaves only that owner's chest live")
	_assert((world.get("_chest_by_drop") as Dictionary).size() == 1 and _projected_chest(world, &"drop:player_2:13001", 2) != null, "live projection retains only the full owner's visible chest")

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
	_finish()


func _context(
	run_player_id: StringName,
	profile_id: String,
	slot: int,
	color_id: StringName,
	inventory_columns: int,
	position: Vector3,
) -> PlayerRunContext:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var profile := ProfileState.new_profile(profile_id, "Live P%d" % [slot + 1], 1000, color_id)
	profile.inventory_columns = inventory_columns
	var context := PlayerRunContext.new()
	_assert(context.configure(run_player_id, slot, profile, 130000 + slot, party, 100).is_empty(), "P%d run context configures" % [slot + 1])
	var actor := Node3D.new()
	actor.position = position
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(100.0, true, 8.0, 0.5)
	actor.add_child(health)
	_actors.append(actor)
	_assert(context.bind_actor(1, actor), "P%d leader binds at %s" % [slot + 1, position])
	return context


func _detail_for(record: GroundItemRecord) -> Dictionary:
	var context := _contexts.context_for(record.run_player_id)
	var item := context.item_state().registry().item(record.item_id) if context != null else null
	var class_definition := context.party.members[0].class_definition if context != null and context.party != null else null
	return ItemPresentationProjector.project(
		item,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		GameCatalog.STAT_CATALOG,
		class_definition,
		GameCatalog.DAMAGE_TYPES,
	)


func _projected_chest(world: Node, drop_id: StringName, player_number: int) -> Node3D:
	var chest := (world.get("_chest_by_drop") as Dictionary).get(drop_id) as Node3D
	if chest == null or not chest.visible or int(chest.get("player_number")) != player_number:
		return null
	var marker := chest.get_node_or_null("OwnerMarker") as Node3D
	var label := marker.get_node_or_null("OwnerLabel") as Label3D if marker != null else null
	return chest if label != null and label.text == "P%d" % player_number else null


func _dpad_right(device: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_DPAD_RIGHT
	event.pressed = true
	return event


func _dispatch(event: InputEventJoypadButton) -> void:
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("LIVE_PERSONAL_LOOT_MULTIPLAYER_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LIVE_PERSONAL_LOOT_MULTIPLAYER_FAILURE: %s" % failure)
	print("LIVE_PERSONAL_LOOT_MULTIPLAYER_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
