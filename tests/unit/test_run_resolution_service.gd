extends RefCounted

const PROFILE_ID := "profile-resolution001"
const RUN_ID := &"run-resolution-001"
const RUN_PLAYER_ID := &"resolution-player"
const RUN_SEED := 7007
const LEADER_ID := 1
const LEADER_HEAD := "item-leader-head"
const LEADER_HAND := "item-leader-hand"
const FOLLOWER_ITEM := "item-follower"
const INVENTORY_ZERO := "item-inventory-zero"
const INVENTORY_FOUR := "item-inventory-four"
const EXISTING_STASH := "item-existing-stash"
const PRIOR_OVERLAP := "item-prior-overlap"
const PRIOR_NONOVERLAP := "item-prior-nonoverlap"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_request_is_exact_and_defensive(failures)
	_test_context_resolution_marker_contract(failures)
	_test_service_type_exists(failures)
	_test_ordinary_resolution_and_irreversible_loss(failures)
	_test_automatic_leader_and_ordinary_follower_resolution(failures)
	_test_automatic_leader_replaces_prior_loadout_without_loss(failures)
	_test_automatic_empty_leader_replaces_prior_loadout_without_loss(failures)
	_test_automatic_replacement_requires_stash_for_displaced_and_selected_items(failures)
	_test_automatic_leader_revalidates_live_equipment(failures)
	_test_live_state_can_advance_past_checkout_snapshot(failures)
	_test_stash_placement_rolls_over_tabs_deterministically(failures)
	_test_failure_atomicity_matrix(failures)
	_test_replay_collision_and_defensive_result(failures)
	return failures

func _test_request_is_exact_and_defensive(failures: Array[String]) -> void:
	var selections: Array[ExtractionSelection] = [
		ExtractionSelection.create("item-one", &"run-inventory", 2),
	]
	var request := RunResolutionRequest.create(
		"resolution-transaction",
		PROFILE_ID,
		RUN_ID,
		RUN_SEED,
		RUN_PLAYER_ID,
		LEADER_ID,
		selections,
	)
	selections[0]._item_id = "escaped"
	selections.clear()
	TestAssertions.equal(request.ordinary_selections[0].item_id, "item-one", "request owns defensive selections", failures)
	TestAssertions.equal(request.canonical_document(), {
		"leader_member_id": LEADER_ID,
		"ordinary_selections": [{
			"expected_source_container_id": "run-inventory",
			"expected_source_slot": 2,
			"item_id": "item-one",
		}],
		"profile_id": PROFILE_ID,
		"run_id": String(RUN_ID),
		"run_player_id": String(RUN_PLAYER_ID),
		"run_seed": RUN_SEED,
		"transaction_id": "resolution-transaction",
	}, "request canonical document fingerprints every identity and selection field", failures)
	var escaped := request.ordinary_selections
	escaped[0]._item_id = "escaped-again"
	escaped.clear()
	TestAssertions.equal(request.ordinary_selections[0].item_id, "item-one", "request getter is defensive", failures)

func _test_context_resolution_marker_contract(failures: Array[String]) -> void:
	var context := PlayerRunContext.new()
	TestAssertions.equal(context.item_resolution_error("resolution-a"), "", "unresolved context accepts first transaction", failures)
	context.mark_items_resolved("resolution-a")
	TestAssertions.equal(context.item_resolution_error("resolution-a"), "", "resolved context accepts same transaction replay", failures)
	TestAssertions.truthy(not context.item_resolution_error("resolution-b").is_empty(), "resolved context rejects a different transaction", failures)

func _test_service_type_exists(failures: Array[String]) -> void:
	var result := RunResolutionResult.failure("expected")
	TestAssertions.truthy(not result.ok() and result.error == "expected", "resolution result exposes stable failure", failures)
	TestAssertions.truthy(RunResolutionService.new() != null, "resolution service is constructible", failures)

func _test_ordinary_resolution_and_irreversible_loss(failures: Array[String]) -> void:
	var fixture := _fixture("ordinary", 3, [], true)
	var store := fixture.store as ProfileStore
	var context := fixture.context as PlayerRunContext
	var path := store.profile_path(PROFILE_ID, fixture.root)
	var history := ProfileMutationService.new(store).grant_gold(PROFILE_ID, "resolution-pre-run-history", 1, fixture.root)
	TestAssertions.truthy(history.ok(), "ordinary fixture records a durable run-bearing historical transaction", failures)
	var old_bytes := FileAccess.get_file_as_bytes(path)
	var residual_path := "%s.tmp" % path
	var residual := FileAccess.open(residual_path, FileAccess.WRITE)
	if residual != null:
		residual.store_buffer(old_bytes)
		residual.close()
	var request := _request("resolution-ordinary", [
		ExtractionSelection.create(LEADER_HAND, &"run-equipment-001", 9),
		ExtractionSelection.create(FOLLOWER_ITEM, &"run-equipment-002", 7),
		ExtractionSelection.create(INVENTORY_ZERO, &"run-inventory", 0),
	])
	var result := RunResolutionService.new(ProfileMutationService.new(store)).resolve(PROFILE_ID, context, request, fixture.root)
	TestAssertions.truthy(result.ok() and not result.duplicate, "ordinary successful resolution commits once", failures)
	var loaded := store.load_profile(PROFILE_ID, fixture.root)
	TestAssertions.truthy(loaded.ok(), "ordinary resolved profile reloads", failures)
	if loaded.ok():
		var saved := loaded.profile
		TestAssertions.equal(saved.resumable_run, {}, "successful resolution clears the strict resumable run", failures)
		TestAssertions.equal(saved.leader_loadout["slots"], {}, "ordinary leader extraction goes to stash before unlock", failures)
		TestAssertions.equal(saved.leader_loadout_class_id, "fighter", "successful empty loadout retains authoritative leader class", failures)
		TestAssertions.equal(saved.stash_tabs[0]["slots"], {
			"0": EXISTING_STASH,
			"1": LEADER_HAND,
			"2": FOLLOWER_ITEM,
			"3": INVENTORY_ZERO,
		}, "ordinary items use canonical projection order and deterministic first-empty stash slots", failures)
		_assert_exact_item(saved, fixture.items[LEADER_HAND], "ordinary leader item", failures)
		_assert_exact_item(saved, fixture.items[FOLLOWER_ITEM], "ordinary follower item", failures)
		_assert_exact_item(saved, fixture.items[INVENTORY_ZERO], "ordinary inventory item", failures)
		var saved_text := JSON.stringify(saved.to_dictionary())
		TestAssertions.truthy(not saved_text.contains(LEADER_HEAD) and not saved_text.contains(INVENTORY_FOUR), "unselected live items are omitted from the committed profile", failures)
	var primary_text := FileAccess.get_file_as_string(path)
	var backup_text := FileAccess.get_file_as_string("%s.bak" % path)
	TestAssertions.truthy(not primary_text.contains(LEADER_HEAD) and not primary_text.contains(INVENTORY_FOUR) and not primary_text.contains("\"item_state\""), "primary cannot resurrect unextracted run items", failures)
	TestAssertions.truthy(not backup_text.contains(LEADER_HEAD) and not backup_text.contains(INVENTORY_FOUR) and not backup_text.contains("\"item_state\""), "backup cannot resurrect unextracted run items", failures)
	var directory := DirAccess.open(fixture.root)
	if directory != null:
		for file_name: String in directory.get_files():
			var artifact_text := FileAccess.get_file_as_string(fixture.root.path_join(file_name))
			TestAssertions.truthy(not artifact_text.contains(LEADER_HEAD) and not artifact_text.contains(INVENTORY_FOUR), "resolution artifact %s contains no lost item" % file_name, failures)
	TestAssertions.truthy(not FileAccess.get_file_as_string("res://scripts/extraction/run_resolution_service.gd").contains("SANDBOX_REMOVE"), "resolution uses context discard rather than production item removal", failures)
	_cleanup(fixture)

func _test_live_state_can_advance_past_checkout_snapshot(failures: Array[String]) -> void:
	var fixture := _fixture("live_advanced", 1, [], true)
	var context := fixture.context as PlayerRunContext
	var live_item := _item("item-live-after-checkout", 50)
	var current := context.item_state()
	var next_items: Array[ItemInstance] = []
	for instance_id: String in current.registry().ids():
		next_items.append(current.registry().item(instance_id))
	next_items.append(live_item)
	var next_containers: Array[ItemSlotContainer] = []
	for container: ItemSlotContainer in current.containers():
		if container.container_id == &"run-inventory":
			container._set_item_id(5, live_item.instance_id)
		next_containers.append(container)
	context._item_state = ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new(next_items), next_containers)
	var initial_snapshot := ResumableRunItemCodec.decode(context.profile_snapshot.resumable_run, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(not initial_snapshot.item_state().registry().has(live_item.instance_id), "configured durable snapshot deliberately predates live loot", failures)
	var result := RunResolutionService.new(ProfileMutationService.new(fixture.store)).resolve(PROFILE_ID, context, _request("resolution-live-advanced", [
		ExtractionSelection.create(live_item.instance_id, &"run-inventory", 5),
	]), fixture.root)
	TestAssertions.truthy(result.ok(), "resolution accepts a valid live item state newer than the checkout snapshot", failures)
	var saved := (fixture.store as ProfileStore).load_profile(PROFILE_ID, fixture.root).profile
	_assert_exact_item(saved, live_item, "post-checkout live item", failures)
	_cleanup(fixture)

func _test_stash_placement_rolls_over_tabs_deterministically(failures: Array[String]) -> void:
	var fixture := _fixture("stash_rollover", 2, [], true)
	var store := fixture.store as ProfileStore
	var candidate := store.load_profile(PROFILE_ID, fixture.root).profile
	var profile_items: Array[ItemInstance] = [fixture.items[EXISTING_STASH]]
	var first_tab_slots := {0: EXISTING_STASH}
	for slot: int in range(1, 99):
		var filler := _profile_item("item-stash-filler-%03d" % slot, 100 + slot)
		profile_items.append(filler)
		first_tab_slots[slot] = filler.instance_id
	candidate.item_records = ItemRegistry.new(profile_items).to_dictionary()
	candidate.stash_tabs = [
		ItemSlotContainer.create(&"stash-tab-001", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, first_tab_slots).to_dictionary(),
		ItemSlotContainer.create(&"stash-tab-000", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100).to_dictionary(),
	]
	TestAssertions.equal(store.save_profile(candidate, fixture.root), "", "cross-tab stash fixture saves", failures)
	var result := RunResolutionService.new(ProfileMutationService.new(store)).resolve(PROFILE_ID, fixture.context, _request("resolution-stash-rollover", [
		ExtractionSelection.create(FOLLOWER_ITEM, &"run-equipment-002", 7),
		ExtractionSelection.create(INVENTORY_ZERO, &"run-inventory", 0),
	]), fixture.root)
	TestAssertions.truthy(result.ok(), "cross-tab extraction resolves", failures)
	var saved := store.load_profile(PROFILE_ID, fixture.root).profile
	TestAssertions.equal(saved.stash_tabs.map(func(tab: Dictionary) -> String: return String(tab["container_id"])), ["stash-tab-001", "stash-tab-000"], "resolution preserves nonlexical stored stash-tab order", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"].get("99", ""), FOLLOWER_ITEM, "first selected item uses final empty slot in first stash tab", failures)
	TestAssertions.equal(saved.stash_tabs[1]["slots"].get("0", ""), INVENTORY_ZERO, "next selected item rolls to first slot in next stash tab", failures)
	_cleanup(fixture)

func _test_automatic_leader_and_ordinary_follower_resolution(failures: Array[String]) -> void:
	var fixture := _fixture("automatic", 1, ["leader_loadout_extraction", "leader_loadout_extraction"], true)
	var store := fixture.store as ProfileStore
	var request := _request("resolution-automatic", [
		ExtractionSelection.create(FOLLOWER_ITEM, &"run-equipment-002", 7),
	])
	var result := RunResolutionService.new(ProfileMutationService.new(store)).resolve(PROFILE_ID, fixture.context, request, fixture.root)
	TestAssertions.truthy(result.ok(), "automatic leader plus ordinary follower resolves", failures)
	var saved := store.load_profile(PROFILE_ID, fixture.root).profile
	TestAssertions.equal(saved.leader_loadout["slots"], {"0": LEADER_HEAD, "9": LEADER_HAND}, "automatic leader equipment preserves exact equipment indices", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {"0": EXISTING_STASH, "1": FOLLOWER_ITEM}, "automatic equipment consumes no ordinary slot", failures)
	TestAssertions.equal(saved.leader_loadout_class_id, "fighter", "automatic leader loadout records live authoritative class", failures)
	_assert_exact_item(saved, fixture.items[LEADER_HEAD], "automatic leader head", failures)
	_assert_exact_item(saved, fixture.items[LEADER_HAND], "automatic leader hand", failures)
	_assert_exact_item(saved, fixture.items[FOLLOWER_ITEM], "automatic ordinary follower", failures)
	var saved_text := JSON.stringify(saved.to_dictionary())
	TestAssertions.truthy(not saved_text.contains(INVENTORY_ZERO) and not saved_text.contains(INVENTORY_FOUR), "automatic resolution still loses unselected ordinary items", failures)
	_cleanup(fixture)

func _test_automatic_leader_replaces_prior_loadout_without_loss(failures: Array[String]) -> void:
	var fixture := _fixture("automatic_prior", 1, ["leader_loadout_extraction"], true)
	var store := fixture.store as ProfileStore
	var prior_overlap := _profile_item_with_base(PRIOR_OVERLAP, 60, &"forge_vanguard_helmet")
	var prior_nonoverlap := _profile_item_with_base(PRIOR_NONOVERLAP, 61, &"forge_vanguard_shield")
	var candidate := store.load_profile(PROFILE_ID, fixture.root).profile
	var existing := fixture.items[EXISTING_STASH] as ItemInstance
	candidate.item_records = ItemRegistry.new([existing, prior_overlap, prior_nonoverlap]).to_dictionary()
	candidate.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID,
		EquipmentSlotIndex.capacity(), {0: PRIOR_OVERLAP, 10: PRIOR_NONOVERLAP},
	).to_dictionary()
	candidate.leader_loadout_class_id = "fighter"
	TestAssertions.equal(store.save_profile(candidate, fixture.root), "", "occupied prior loadout fixture saves", failures)
	var result := RunResolutionService.new(ProfileMutationService.new(store)).resolve(PROFILE_ID, fixture.context, _request("resolution-automatic-prior", [
		ExtractionSelection.create(FOLLOWER_ITEM, &"run-equipment-002", 7),
	]), fixture.root)
	TestAssertions.truthy(result.ok(), "automatic resolution atomically replaces an occupied prior leader loadout", failures)
	var saved := store.load_profile(PROFILE_ID, fixture.root).profile
	TestAssertions.equal(saved.leader_loadout["slots"], {"0": LEADER_HEAD, "9": LEADER_HAND}, "complete final live loadout replaces overlapping and nonoverlapping prior slots", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {
		"0": EXISTING_STASH,
		"1": PRIOR_OVERLAP,
		"2": PRIOR_NONOVERLAP,
		"3": FOLLOWER_ITEM,
	}, "displaced equipment uses canonical equipment-slot order before ordinary projection order", failures)
	_assert_exact_item(saved, prior_overlap, "displaced overlapping prior item", failures)
	_assert_exact_item(saved, prior_nonoverlap, "displaced nonoverlapping prior item", failures)
	_cleanup(fixture)

func _test_automatic_empty_leader_replaces_prior_loadout_without_loss(failures: Array[String]) -> void:
	var fixture := _fixture("automatic_empty_prior", 0, ["leader_loadout_extraction"], true)
	var store := fixture.store as ProfileStore
	var prior_overlap := _profile_item_with_base(PRIOR_OVERLAP, 60, &"forge_vanguard_helmet")
	var prior_nonoverlap := _profile_item_with_base(PRIOR_NONOVERLAP, 61, &"forge_vanguard_shield")
	var candidate := store.load_profile(PROFILE_ID, fixture.root).profile
	var existing := fixture.items[EXISTING_STASH] as ItemInstance
	candidate.item_records = ItemRegistry.new([existing, prior_overlap, prior_nonoverlap]).to_dictionary()
	candidate.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID,
		EquipmentSlotIndex.capacity(), {0: PRIOR_OVERLAP, 10: PRIOR_NONOVERLAP},
	).to_dictionary()
	candidate.leader_loadout_class_id = "fighter"
	TestAssertions.equal(store.save_profile(candidate, fixture.root), "", "empty final loadout fixture saves", failures)
	_remove_live_leader_equipment(fixture.context)
	var result := RunResolutionService.new(ProfileMutationService.new(store)).resolve(PROFILE_ID, fixture.context, _request("resolution-automatic-empty-prior", []), fixture.root)
	TestAssertions.truthy(result.ok(), "automatic resolution installs an empty final live leader loadout", failures)
	var saved := store.load_profile(PROFILE_ID, fixture.root).profile
	TestAssertions.equal(saved.leader_loadout["slots"], {}, "empty final live leader loadout clears every prior equipment slot", failures)
	TestAssertions.equal(saved.stash_tabs[0]["slots"], {"0": EXISTING_STASH, "1": PRIOR_OVERLAP, "2": PRIOR_NONOVERLAP}, "empty final loadout preserves all displaced items in canonical slot order", failures)
	_cleanup(fixture)

func _test_automatic_replacement_requires_stash_for_displaced_and_selected_items(failures: Array[String]) -> void:
	var fixture := _fixture("automatic_prior_no_space", 1, ["leader_loadout_extraction"], false)
	var store := fixture.store as ProfileStore
	var prior_overlap := _profile_item_with_base(PRIOR_OVERLAP, 60, &"forge_vanguard_helmet")
	var prior_nonoverlap := _profile_item_with_base(PRIOR_NONOVERLAP, 61, &"forge_vanguard_shield")
	var candidate := store.load_profile(PROFILE_ID, fixture.root).profile
	candidate.item_records = ItemRegistry.new([prior_overlap, prior_nonoverlap]).to_dictionary()
	candidate.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID,
		EquipmentSlotIndex.capacity(), {0: PRIOR_OVERLAP, 10: PRIOR_NONOVERLAP},
	).to_dictionary()
	candidate.leader_loadout_class_id = "fighter"
	TestAssertions.equal(store.save_profile(candidate, fixture.root), "", "automatic no-space fixture saves", failures)
	_assert_atomic_failure(fixture, _request("resolution-automatic-prior-no-space", [
		ExtractionSelection.create(FOLLOWER_ITEM, &"run-equipment-002", 7),
	]), null, "insufficient empty slots required=3", "displaced plus ordinary stash capacity", failures)
	_cleanup(fixture)

func _test_automatic_leader_revalidates_live_equipment(failures: Array[String]) -> void:
	var fixture := _fixture("automatic_invalid_live", 0, ["leader_loadout_extraction"], true)
	var context := fixture.context as PlayerRunContext
	var current := context.item_state()
	var invalid_hand := current.registry().item(LEADER_HAND)
	invalid_hand.base_definition_id = &"rime_scholar_staff"
	var next_items: Array[ItemInstance] = []
	for instance_id: String in current.registry().ids():
		next_items.append(invalid_hand if instance_id == LEADER_HAND else current.registry().item(instance_id))
	context._item_state = ItemOwnershipState.create(current.owner_id, ItemRegistry.new(next_items), current.containers())
	_assert_atomic_failure(fixture, _request("resolution-automatic-invalid-live", []), null, "ineligible", "forged ineligible live leader loadout", failures)
	_cleanup(fixture)

func _test_failure_atomicity_matrix(failures: Array[String]) -> void:
	var stale := _fixture("failure_stale", 1, [], true)
	_assert_atomic_failure(stale, _request("resolution-stale", [
		ExtractionSelection.create(INVENTORY_ZERO, &"run-inventory", 1),
	]), null, "expected run-inventory[1]", "stale expected source", failures)
	_cleanup(stale)

	var no_stash := _fixture("failure_space", 1, [], false)
	_assert_atomic_failure(no_stash, _request("resolution-no-space", [
		ExtractionSelection.create(INVENTORY_ZERO, &"run-inventory", 0),
	]), null, "insufficient empty slots", "insufficient stash", failures)
	_cleanup(no_stash)

	var identity_cases: Array[Dictionary] = [
		{"label": "wrong profile", "fragment": "profile identity mismatch", "request": RunResolutionRequest.create("wrong-profile", "profile-other", RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, [])},
		{"label": "wrong run", "fragment": "must match", "request": RunResolutionRequest.create("wrong-run", PROFILE_ID, &"run-other", RUN_SEED, RUN_PLAYER_ID, LEADER_ID, [])},
		{"label": "wrong seed", "fragment": "must match", "request": RunResolutionRequest.create("wrong-seed", PROFILE_ID, RUN_ID, RUN_SEED + 1, RUN_PLAYER_ID, LEADER_ID, [])},
		{"label": "wrong run player", "fragment": "must match", "request": RunResolutionRequest.create("wrong-player", PROFILE_ID, RUN_ID, RUN_SEED, &"other-player", LEADER_ID, [])},
		{"label": "wrong leader", "fragment": "must match", "request": RunResolutionRequest.create("wrong-leader", PROFILE_ID, RUN_ID, RUN_SEED, RUN_PLAYER_ID, 2, [])},
	]
	for test_case: Dictionary in identity_cases:
		var fixture := _fixture("failure_%s" % String(test_case.label).replace(" ", "_"), 0, [], true)
		_assert_atomic_failure(fixture, test_case.request, null, test_case.fragment, test_case.label, failures)
		_cleanup(fixture)

	var bad_candidate := _fixture("failure_candidate_identity", 0, [], true)
	var bad_store := bad_candidate.store as ProfileStore
	var changed := bad_store.load_profile(PROFILE_ID, bad_candidate.root).profile
	changed.resumable_run["run_id"] = "run-durable-other"
	TestAssertions.equal(bad_store.save_profile(changed, bad_candidate.root), "", "mismatched durable candidate saves as a valid profile", failures)
	_assert_atomic_failure(bad_candidate, _request("resolution-candidate-mismatch", []), null, "must match", "durable candidate identity", failures)
	_cleanup(bad_candidate)

	var save_failure := _fixture("failure_save", 1, [], true)
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	_assert_atomic_failure(save_failure, _request("resolution-save-failure", [
		ExtractionSelection.create(INVENTORY_ZERO, &"run-inventory", 0),
	]), failing_store, "JSON_STORE_SAVE_ERROR", "injected save failure", failures)
	_cleanup(save_failure)

	var invalid := _fixture("failure_invalid_profile", 0, [], true)
	var invalid_store := invalid.store as ProfileStore
	var invalid_path := invalid_store.profile_path(PROFILE_ID, invalid.root)
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	if invalid_file != null:
		invalid_file.store_string("{\"invalid\":true}")
		invalid_file.close()
	_assert_atomic_failure(invalid, _request("resolution-invalid-profile", []), null, "PROFILE", "invalid profile", failures)
	_cleanup(invalid)

	var resolved := _fixture("failure_already_resolved", 0, [], true)
	(resolved.context as PlayerRunContext).mark_items_resolved("other-resolution")
	_assert_atomic_failure(resolved, _request("resolution-after-closed", []), null, "already resolved", "already-resolved context", failures, false)
	_cleanup(resolved)

func _test_replay_collision_and_defensive_result(failures: Array[String]) -> void:
	var fixture := _fixture("replay", 1, [], true)
	var store := fixture.store as ProfileStore
	var context := fixture.context as PlayerRunContext
	var request := _request("resolution-replay", [
		ExtractionSelection.create(INVENTORY_ZERO, &"run-inventory", 0),
	])
	var service := RunResolutionService.new(ProfileMutationService.new(store))
	var committed := service.resolve(PROFILE_ID, context, request, fixture.root)
	TestAssertions.truthy(committed.ok() and not committed.duplicate, "resolution replay fixture commits", failures)
	var path := store.profile_path(PROFILE_ID, fixture.root)
	var bytes_after := FileAccess.get_file_as_bytes(path)
	var state_after := context.item_state().to_dictionary()
	var replay := service.resolve(PROFILE_ID, context, request, fixture.root)
	TestAssertions.truthy(replay.ok() and replay.duplicate, "same resolution transaction replays as duplicate", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), bytes_after, "resolution replay performs no profile write", failures)
	TestAssertions.equal(context.item_state().to_dictionary(), state_after, "resolution replay performs no second context ownership mutation", failures)
	var escaped_profile := replay.profile
	escaped_profile.gold = 999999
	TestAssertions.truthy(replay.profile.gold != 999999, "resolution result profile is defensive", failures)
	var collision := service.resolve(PROFILE_ID, context, RunResolutionRequest.create(
		request.transaction_id, PROFILE_ID, RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, []
	), fixture.root)
	TestAssertions.truthy(not collision.ok() and collision.error.contains("transaction id conflict"), "changed request under same transaction collides", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), bytes_after, "transaction collision performs no write", failures)
	TestAssertions.equal(context.item_state().to_dictionary(), state_after, "transaction collision leaves closed context ownership unchanged", failures)
	_cleanup(fixture)

func _fixture(label: String, capacity: int, unlocks: Array[String], with_stash: bool) -> Dictionary:
	var root := "user://run_resolution_tests/%s" % label
	ProfileTestSupport.remove_tree(root)
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	assert(party.recruit(catalog.class_by_id(&"ranger")))
	var items := {
		LEADER_HEAD: _item_with_base(LEADER_HEAD, 0, &"forge_vanguard_helmet"),
		LEADER_HAND: _item(LEADER_HAND, 1),
		FOLLOWER_ITEM: _item_with_base(FOLLOWER_ITEM, 2, &"windrunner_band"),
		INVENTORY_ZERO: _item(INVENTORY_ZERO, 3),
		INVENTORY_FOUR: _item(INVENTORY_FOUR, 4),
		EXISTING_STASH: _profile_item(EXISTING_STASH, 40),
	}
	var run_items: Array[ItemInstance] = [items[LEADER_HEAD], items[LEADER_HAND], items[FOLLOWER_ITEM], items[INVENTORY_ZERO], items[INVENTORY_FOUR]]
	var run_state := ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new(run_items), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10, {0: INVENTORY_ZERO, 4: INVENTORY_FOUR}),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), {0: LEADER_HEAD, 9: LEADER_HAND}),
		ItemSlotContainer.create(&"run-equipment-002", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), {7: FOLLOWER_ITEM}),
	])
	assert(run_state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).is_empty())
	var bootstrap := RunItemBootstrap.create(RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, run_state)
	var profile := ProfileState.new_profile(PROFILE_ID, "Resolution Tester", 1000)
	profile.inventory_columns = 2
	profile.extraction_capacity = capacity
	profile.permanent_feature_unlocks = unlocks.duplicate()
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	if with_stash:
		profile.item_records = ItemRegistry.new([items[EXISTING_STASH]]).to_dictionary()
		profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-000", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, {0: EXISTING_STASH}).to_dictionary()]
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(profile, root), "", "%s profile fixture saves" % label, [])
	var context := PlayerRunContext.new()
	assert(context.configure(RUN_PLAYER_ID, 0, profile, RUN_SEED, party, 100, bootstrap).is_empty())
	return {"root": root, "store": store, "profile": profile, "context": context, "party": party, "items": items}

func _request(transaction_id: String, selections: Array[ExtractionSelection]) -> RunResolutionRequest:
	return RunResolutionRequest.create(transaction_id, PROFILE_ID, RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, selections)

func _item(instance_id: String, sequence: int) -> ItemInstance:
	return _item_with_base(instance_id, sequence, &"forge_vanguard_sword")

func _item_with_base(instance_id: String, sequence: int, base_definition_id: StringName) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_definition_id
	item.item_level = 28
	item.rarity_id = &"common"
	item.affixes = []
	item.origin = {"issuer_namespace": "run:%s:%d:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID], "seed": RUN_SEED, "sequence": sequence, "source": "run_resolution_test"}
	return item

func _profile_item(instance_id: String, sequence: int) -> ItemInstance:
	var item := _item(instance_id, sequence)
	item.origin["issuer_namespace"] = "profile:%s" % PROFILE_ID
	return item

func _profile_item_with_base(instance_id: String, sequence: int, base_definition_id: StringName) -> ItemInstance:
	var item := _item_with_base(instance_id, sequence, base_definition_id)
	item.origin["issuer_namespace"] = "profile:%s" % PROFILE_ID
	return item

func _remove_live_leader_equipment(context: PlayerRunContext) -> void:
	var current := context.item_state()
	var leader := current.container(&"run-equipment-001")
	var removed: Dictionary = {}
	for slot: int in leader.occupied_slots():
		removed[leader.item_id_at(slot)] = true
	var items: Array[ItemInstance] = []
	for instance_id: String in current.registry().ids():
		if not removed.has(instance_id):
			items.append(current.registry().item(instance_id))
	var containers: Array[ItemSlotContainer] = []
	for container: ItemSlotContainer in current.containers():
		containers.append(ItemSlotContainer.create(container.container_id, container.container_kind, container.owner_id, container.capacity) if container.container_id == &"run-equipment-001" else container)
	context._item_state = ItemOwnershipState.create(current.owner_id, ItemRegistry.new(items), containers)

func _assert_exact_item(profile: ProfileState, expected: ItemInstance, label: String, failures: Array[String]) -> void:
	var decoded := ItemRegistry._decode(profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	var registry := decoded.value as ItemRegistry
	TestAssertions.equal(registry.item(expected.instance_id).to_dictionary(), expected.to_dictionary(), "%s preserves the exact instance record" % label, failures)

func _assert_atomic_failure(
	fixture: Dictionary,
	request: RunResolutionRequest,
	override_store: ProfileStore,
	error_fragment: String,
	label: String,
	failures: Array[String],
	expect_unresolved := true,
) -> void:
	var store := fixture.store as ProfileStore
	var context := fixture.context as PlayerRunContext
	var path := store.profile_path(PROFILE_ID, fixture.root)
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var before_state := context.item_state().to_dictionary()
	var service_store := override_store if override_store != null else store
	var result := RunResolutionService.new(ProfileMutationService.new(service_store)).resolve(PROFILE_ID, context, request, fixture.root)
	TestAssertions.truthy(not result.ok() and result.profile == null and result.error.contains(error_fragment), "%s returns stable failure without a profile" % label, failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "%s preserves exact profile bytes" % label, failures)
	TestAssertions.equal(context.item_state().to_dictionary(), before_state, "%s preserves exact context ownership" % label, failures)
	if expect_unresolved:
		TestAssertions.equal(context.item_resolution_error("retry-%s" % label), "", "%s leaves context unresolved and retryable" % label, failures)

func _cleanup(fixture: Dictionary) -> void:
	(fixture.party as PartyManager).free()
	ProfileTestSupport.remove_tree(fixture.root)
