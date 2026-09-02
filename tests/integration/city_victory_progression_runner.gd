extends SceneTree

const CITY_TREE_ID := "party-forge-city-v1"
const CITY_ROOT_NODE_ID := "city-heart"

var _failures: Array[String] = []
var _profile_root := ""
var _run_sequence := 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_profile_root = "user://tests/city_victory_progression_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_profile_root)
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return "city-victory-profile")
	_assert(manager.bootstrap(_profile_root).is_empty(), "victory profile manager bootstraps")
	var created := manager.create_profile("City Victory Progression", 1000)
	_assert(created.ok(), "clean victory profile is created")
	if not created.ok():
		_finish()
		return
	var profile_id := created.profile.profile_id

	var defeat := _resolve_terminal(profile_id, "defeat", RunTerminalSnapshot.Outcome.DEFEAT, false)
	_assert(bool(defeat.get("ok", false)), "clean defeat resolves through RunTerminalFlow")
	var after_defeat := _load_profile(profile_id)
	_assert(after_defeat != null and after_defeat.passive_points_available == 0 and after_defeat.passive_points_lifetime_earned == 0, "defeat grants no passive point")
	_assert(after_defeat != null and CITY_TREE_ID not in after_defeat.discovered_trees and not after_defeat.tree_allocations.has(CITY_TREE_ID), "defeat neither reveals nor roots City")

	var first := _resolve_terminal(profile_id, "first-victory", RunTerminalSnapshot.Outcome.VICTORY, true)
	_assert(bool(first.get("ok", false)) and bool(first.get("duplicate", false)), "first victory and exact replay resolve through production services")
	var after_first := _load_profile(profile_id)
	_assert(after_first != null and after_first.passive_points_available == 0 and after_first.passive_points_lifetime_earned == 0, "first unique victory reveals City without granting a passive point")
	_assert(after_first != null and after_first.discovered_trees.count(CITY_TREE_ID) == 1, "first unique victory reveals City exactly once")
	_assert(after_first != null and (after_first.tree_allocations.get(CITY_TREE_ID, []) as Array).count(CITY_ROOT_NODE_ID) == 1, "first unique victory roots City Heart exactly once")

	var second := _resolve_terminal(profile_id, "second-victory", RunTerminalSnapshot.Outcome.VICTORY, true)
	_assert(bool(second.get("ok", false)) and bool(second.get("duplicate", false)), "second unique victory and exact replay resolve through production services")
	var after_second := _load_profile(profile_id)
	_assert(after_second != null and after_second.passive_points_available == 1 and after_second.passive_points_lifetime_earned == 1, "second unique victory grants the first passive point")
	_assert(after_second != null and after_second.discovered_trees.count(CITY_TREE_ID) == 1, "second victory does not duplicate City discovery")
	_assert(after_second != null and (after_second.tree_allocations.get(CITY_TREE_ID, []) as Array).count(CITY_ROOT_NODE_ID) == 1, "second victory does not duplicate City Heart")
	_finish()


func _resolve_terminal(profile_id: String, label: String, outcome: RunTerminalSnapshot.Outcome, verify_replay: bool) -> Dictionary:
	_run_sequence += 1
	var store := ProfileStore.new()
	var loaded := store.load_profile(profile_id, _profile_root)
	_assert(loaded.ok(), "%s profile loads before terminal flow" % label)
	if not loaded.ok():
		return {}
	var profile := loaded.profile as ProfileState
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var leader_id := party.members[0].member_id
	var run_id := StringName("city-victory-run-%02d-%s" % [_run_sequence, label])
	var run_player_id := StringName("city-victory-player-%02d" % _run_sequence)
	var run_seed := 63000 + _run_sequence
	var containers: Array[ItemSlotContainer] = [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(run_player_id), profile.inventory_columns * 5),
		ItemSlotContainer.create("run-equipment-%03d" % leader_id, ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(run_player_id), EquipmentSlotIndex.capacity()),
		RunItemBootstrap.ground_items_container(String(run_player_id)),
	]
	var ownership := ItemOwnershipState.create(String(run_player_id), ItemRegistry.new([]), containers)
	var bootstrap := RunItemBootstrap.create(run_id, run_seed, run_player_id, leader_id, ownership, &"fighter")
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var save_error := store.save_profile(profile, _profile_root)
	_assert(save_error.is_empty(), "%s durable run bootstrap saves" % label)
	if not save_error.is_empty():
		return {}

	var context := PlayerRunContext.new()
	var context_errors := context.configure(run_player_id, 0, profile, run_seed, party, 100, bootstrap)
	_assert(context_errors.is_empty(), "%s production run context configures" % label)
	if not context_errors.is_empty():
		_dispose_run_fixture(context, party)
		return {}
	var flow := RunTerminalFlow.new()
	var begun := flow.begin(outcome, 180.0, context, profile, _profile_root)
	_assert(begun.ok() and flow.state() == RunTerminalFlow.State.CHOOSING_EXTRACTION, "%s terminal capture reaches extraction choice" % label)
	if not begun.ok():
		_dispose_run_fixture(context, party)
		return {}
	var fresh := store.load_profile(profile_id, _profile_root)
	_assert(fresh.ok(), "%s profile reloads after terminal capture" % label)
	if not fresh.ok():
		_dispose_run_fixture(context, party)
		return {}
	var preflight := flow.confirm_extraction([], fresh.profile)
	_assert(preflight.ok(), "%s confirms the empty extraction selection" % label)
	if not preflight.ok():
		_dispose_run_fixture(context, party)
		return {}
	var snapshot := flow.snapshot()
	var selections: Array[ExtractionSelection] = []
	var request := RunResolutionRequest.create(flow.transaction_id(), snapshot.profile_id, snapshot.run_id, snapshot.run_seed, snapshot.run_player_id, snapshot.leader_member_id, selections)
	var resolved := flow.resolve(profile_id, _profile_root)
	_assert(resolved.ok() and not resolved.duplicate and flow.state() == RunTerminalFlow.State.RESOLVED_AWAITING_PROJECTION, "%s resolves exactly once" % label)
	if not resolved.ok():
		_dispose_run_fixture(context, party)
		return {}
	var replay_duplicate := false
	if verify_replay:
		var before_replay := ProfileCodec.encode(store.load_profile(profile_id, _profile_root).profile)
		var replayed := RunResolutionService.new().resolve_terminal_source(profile_id, snapshot.resolution_source, request, _profile_root)
		var after_replay := ProfileCodec.encode(store.load_profile(profile_id, _profile_root).profile)
		replay_duplicate = replayed.ok() and replayed.duplicate
		_assert(replay_duplicate, "%s exact terminal transaction replay is reported duplicate" % label)
		_assert(after_replay == before_replay, "%s exact replay leaves durable profile bytes unchanged" % label)
	_assert(flow.finalize() and flow.state() == RunTerminalFlow.State.FINALIZED, "%s terminal flow finalizes" % label)
	var completed := RunTerminalRecoveryService.new().complete_terminal(profile_id, snapshot.run_id, _profile_root)
	_assert(completed.ok(), "%s completed recap clears terminal recovery for the next unique run" % label)
	_dispose_run_fixture(context, party)
	return {"ok": completed.ok(), "duplicate": replay_duplicate}


func _dispose_run_fixture(context: PlayerRunContext, party: PartyManager) -> void:
	if context != null:
		context.release_source_refresh_coordinator()
	if party != null and is_instance_valid(party):
		party.free()


func _load_profile(profile_id: String) -> ProfileState:
	var loaded := ProfileStore.new().load_profile(profile_id, _profile_root)
	_assert(loaded.ok(), "profile reload succeeds")
	return loaded.profile if loaded.ok() else null


func _finish() -> void:
	ProfileTestSupport.remove_tree(_profile_root)
	if _failures.is_empty():
		print("CITY_VICTORY_PROGRESSION_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("CITY_VICTORY_PROGRESSION_FAILURE: %s" % failure)
	print("CITY_VICTORY_PROGRESSION_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
