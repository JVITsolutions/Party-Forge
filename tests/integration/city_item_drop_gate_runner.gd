extends SceneTree

var _failures: Array[String] = []
var _profile_root := ""
var _settings_path := ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture_id := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_profile_root = "user://tests/city_item_drop_gate_profiles_%s" % fixture_id
	_settings_path = "user://tests/city_item_drop_gate_settings_%s.cfg" % fixture_id
	ProfileTestSupport.remove_tree(_profile_root)
	_cleanup_settings()
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return "city-item-gate-profile")
	_assert(manager.bootstrap(_profile_root).is_empty(), "item-gate profile manager bootstraps")
	var created := manager.create_profile("City Item Drop Gate", 1000)
	_assert(created.ok(), "item-gate profile is created")
	if not created.ok():
		_finish()
		return
	var profile_id := created.profile.profile_id
	_assert(ProfileTestSupport.commit_city_victory(profile_id, "city-item-gate-first-victory", _profile_root).ok(), "first victory reveals and roots City")
	var extra_point := ProfileMutationService.new(ProfileStore.new()).grant_passive_points(profile_id, "city-item-gate-route-point", 1, _profile_root)
	_assert(extra_point.ok() and extra_point.profile.passive_points_available == 2, "one additional point funds exactly Equipment Registry and Field Pack")

	var portfolio := LatticewrightRuntimePortfolioRegistry.new()
	var loaded := PassiveTreeCatalog.load_defaults(portfolio)
	_assert(loaded.ok(), "production City tree reloads for allocation")
	if not loaded.ok():
		_finish()
		return
	var effects := PassiveEffectRegistry.new()
	var requirements := PassiveRequirementRegistry.new()
	var progression := PassiveTreeProgressionService.new(effects, requirements, null, portfolio)
	var resolver := PassiveEffectResolver.new(effects)
	var mutations := PassiveTreeMutationService.new(ProfileMutationService.new(ProfileStore.new()), progression, resolver)
	var equipment := mutations.allocate(profile_id, "city-item-gate-equipment-registry", loaded.tree, &"equipment-registry", false, _profile_root)
	_assert(equipment.ok() and not equipment.duplicate and equipment.profile.passive_points_available == 1, "Equipment Registry allocates through production mutation and spends one point")
	_assert("equipment_inventory" in equipment.profile.permanent_feature_unlocks and "inventory" not in equipment.profile.permanent_feature_unlocks and equipment.profile.inventory_columns == 0, "Equipment Registry alone cannot store items")

	var equipment_only_main := await _start_main(profile_id)
	if equipment_only_main == null:
		_finish()
		return
	var equipment_only_context := equipment_only_main.active_run_context as PlayerRunContext
	var equipment_only_registry := equipment_only_main.ground_item_registry as GroundItemRegistry
	var equipment_only_state_before := equipment_only_context.item_state().to_dictionary()
	var equipment_only_spawned_ids: Array[StringName] = []
	equipment_only_registry.record_added.connect(func(record: GroundItemRecord) -> void: equipment_only_spawned_ids.append(record.drop_id))
	var blocked_winning_sequence := _winning_sequence(equipment_only_main)
	_assert(blocked_winning_sequence > 0, "Equipment Registry alone has a deterministic would-win ordinary-drop sequence")
	_emit_defeat(equipment_only_main, blocked_winning_sequence)
	await _frames(4)
	_assert(equipment_only_context.item_state().to_dictionary() == equipment_only_state_before and equipment_only_context.ground_items().occupied_slots().is_empty(), "Equipment Registry alone creates no personal item or owner-ground mutation")
	_assert(equipment_only_spawned_ids.is_empty(), "Equipment Registry alone emits no spawned ground-item ID")
	_assert(equipment_only_registry.all_records().is_empty() and _active_chest_count(equipment_only_main) == 0, "Equipment Registry alone creates no ground record or chest")
	_assert(_forfeit_run(equipment_only_main), "Equipment-Registry-only proof run is forfeited through production recovery without rewards")
	await _cleanup_main(equipment_only_main)

	var field_pack := mutations.allocate(profile_id, "city-item-gate-field-pack", loaded.tree, &"field-pack", false, _profile_root)
	_assert(field_pack.ok() and not field_pack.duplicate and field_pack.profile.passive_points_available == 0, "Field Pack allocates through production mutation and spends the second point")
	_assert("equipment_inventory" in field_pack.profile.permanent_feature_unlocks and "inventory" in field_pack.profile.permanent_feature_unlocks and field_pack.profile.inventory_columns == 1, "Field Pack completes both unlocks and one durable inventory column")

	var unlocked_main := await _start_main(profile_id)
	if unlocked_main == null:
		_finish()
		return
	var context := unlocked_main.active_run_context as PlayerRunContext
	var registry := unlocked_main.ground_item_registry as GroundItemRegistry
	var spawned_ids: Array[StringName] = []
	registry.record_added.connect(func(record: GroundItemRecord) -> void: spawned_ids.append(record.drop_id))
	_assert(context.run_inventory().capacity == 5, "fresh post-Field-Pack run owns five inventory slots")
	var winning_sequence := _winning_sequence(unlocked_main)
	_assert(winning_sequence > 0, "normal 100-basis-point loot chance has a deterministic winning sequence")
	_emit_defeat(unlocked_main, winning_sequence)
	await _frames(4)
	_assert(spawned_ids.size() == 1, "post-Field-Pack ordinary drop follows the deterministic 100-basis-point normal chance and emits one spawned ID")
	var records := registry.all_records()
	_assert(context.ground_items().occupied_slots().size() == 1 and records.size() == 1 and _active_chest_count(unlocked_main) == 1, "authorized ordinary drop reaches owner state, registry, and one projected chest")
	if records.size() == 1 and spawned_ids.size() == 1:
		_assert(records[0].drop_id == spawned_ids[0], "the production defeat signal projects the exact spawned ground-item ID")
	_assert(_forfeit_run(unlocked_main), "unlocked proof run is forfeited through production recovery after evidence")
	await _cleanup_main(unlocked_main)
	_finish()


func _start_main(profile_id: String) -> PartyForgeMain:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = _profile_root
	main.settings_path = _settings_path
	root.add_child(main)
	await _frames(2)
	_assert(main.active_profile() != null and main.active_profile().profile_id == profile_id, "Main selects the exact item-gate profile")
	_assert(main.select_leader_class(&"fighter"), "Player Mode starts a fresh fighter run")
	if main.run_started and main.active_run_context != null:
		return main
	await _cleanup_main(main)
	return null


func _emit_defeat(main: PartyForgeMain, defeat_sequence: int) -> void:
	var context := main.active_run_context as PlayerRunContext
	var event := EnemyDefeatEvent.create(context.run_seed, defeat_sequence, defeat_sequence, &"swarmer", &"ordinary_melee", main.leader.position, 30.0)
	main.spawn_director.enemy_defeated.emit(event)


func _winning_sequence(main: PartyForgeMain) -> int:
	var context := main.active_run_context as PlayerRunContext
	var scope := StringName("personal_drop:%s" % context.run_player_id)
	for sequence: int in range(1, 10000):
		var roll := floori(ItemDeterministicRandom.unit(context.run_seed, sequence, scope, 0) * 10000.0)
		if roll < 100:
			return sequence
	return -1


func _forfeit_run(main: PartyForgeMain) -> bool:
	var context := main.active_run_context as PlayerRunContext
	if context == null:
		return false
	return RunRecoveryService.new().forfeit(context.profile_id, context.run_id, _profile_root).ok()


func _active_chest_count(main: PartyForgeMain) -> int:
	var controller := main.ground_item_world_controller as Node
	return int((controller.get("_chest_by_drop") as Dictionary).size()) if controller != null else -1


func _cleanup_main(main: PartyForgeMain) -> void:
	paused = false
	if main != null and is_instance_valid(main):
		main.free()
	await process_frame


func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _cleanup_settings() -> void:
	if _settings_path.is_empty():
		return
	for path: String in [_settings_path, "%s.tmp" % _settings_path, "%s.bak" % _settings_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	if not _profile_root.is_empty():
		ProfileTestSupport.remove_tree(_profile_root)
	_cleanup_settings()
	if _failures.is_empty():
		print("CITY_ITEM_DROP_GATE_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("CITY_ITEM_DROP_GATE_FAILURE: %s" % failure)
	print("CITY_ITEM_DROP_GATE_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
