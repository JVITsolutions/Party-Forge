extends RefCounted

const PARTICIPANT_PATH := "res://scripts/run/local_run_setup_participant.gd"
const COORDINATOR_PATH := "res://scripts/run/local_run_setup_coordinator.gd"
const PARTICIPANT_SCRIPT := preload(PARTICIPANT_PATH)
const COORDINATOR_SCRIPT := preload(COORDINATOR_PATH)

var _root_counter := 0
var _parties: Array[PartyManager] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_api_and_participant_defense(failures)
	_test_begin_validation_and_state_atomicity(failures)
	_test_cancellation_stale_assignment_and_wrong_decisions(failures)
	_test_four_profile_isolation_and_stable_registry_lock(failures)
	for party: PartyManager in _parties:
		party.free()
	_parties.clear()
	return failures

func _test_api_and_participant_defense(failures: Array[String]) -> void:
	var participant: Object = _participant("profile-local-alpha", -1, 3, &"fighter")
	var coordinator: Object = COORDINATOR_SCRIPT.new() as Object
	for property_name: StringName in [&"profile_id", &"device_id", &"player_slot", &"selected_class_id", &"decision_state", &"ready", &"projection"]:
		TestAssertions.truthy(_has_property(participant, property_name), "participant exposes %s" % property_name, failures)
	for method_name: StringName in [&"begin", &"submit", &"cancel", &"ready_contexts", &"armoury_projection", &"is_locked", &"participant", &"run_context_registry"]:
		TestAssertions.truthy(coordinator.has_method(method_name), "coordinator exposes %s" % method_name, failures)
	TestAssertions.equal(participant.get("profile_id"), "profile-local-alpha", "participant captures exact profile id", failures)
	TestAssertions.equal(participant.get("device_id"), -1, "participant identifies the unique keyboard and mouse owner", failures)
	TestAssertions.equal(participant.get("player_slot"), 3, "participant captures stable player slot", failures)
	TestAssertions.equal(participant.get("selected_class_id"), &"fighter", "participant captures authoritative class id", failures)
	participant.set("profile_id", "escaped-profile")
	participant.set("device_id", 99)
	TestAssertions.equal(participant.get("profile_id"), "profile-local-alpha", "participant identity is externally read-only", failures)
	TestAssertions.equal(participant.get("device_id"), -1, "participant device ownership is externally read-only", failures)

func _test_begin_validation_and_state_atomicity(failures: Array[String]) -> void:
	var root := _case_root("begin_validation")
	var store := ProfileStore.new()
	var alpha := _profile("profile-begin-alpha", "Alpha", &"fighter", &"forge_vanguard_sword", 9, 1, 0, 11, ["alpha_unlock"])
	_save(store, alpha, root, "begin alpha", failures)
	var assignments := _assignment_map([_participant(alpha.profile_id, -1, 0, &"fighter")])
	var coordinator: Object = _coordinator(store, root, assignments)
	var valid: Array = [_participant(alpha.profile_id, -1, 0, &"fighter")]
	TestAssertions.equal(coordinator.call("begin", valid), PackedStringArray(), "valid single participant begins", failures)
	TestAssertions.truthy(coordinator.call("participant", alpha.profile_id) != null, "valid begin captures the participant", failures)

	var invalid_cases: Array[Dictionary] = [
		{"label": "null participant", "participants": [null], "expected": "participant"},
		{"label": "duplicate profile", "participants": [_participant(alpha.profile_id, -1, 0, &"fighter"), _participant(alpha.profile_id, 0, 1, &"mage")], "expected": "duplicate profile"},
		{"label": "duplicate keyboard device", "participants": [_participant(alpha.profile_id, -1, 0, &"fighter"), _participant("profile-begin-beta", -1, 1, &"mage")], "expected": "duplicate device"},
		{"label": "duplicate controller device", "participants": [_participant(alpha.profile_id, 2, 0, &"fighter"), _participant("profile-begin-beta", 2, 1, &"mage")], "expected": "duplicate device"},
		{"label": "duplicate slot", "participants": [_participant(alpha.profile_id, -1, 0, &"fighter"), _participant("profile-begin-beta", 0, 0, &"mage")], "expected": "duplicate player slot"},
		{"label": "negative slot", "participants": [_participant(alpha.profile_id, -1, -1, &"fighter")], "expected": "player slot"},
		{"label": "invalid device", "participants": [_participant(alpha.profile_id, -2, 0, &"fighter")], "expected": "device"},
		{"label": "invalid profile id", "participants": [_participant("short", -1, 0, &"fighter")], "expected": "profile_id"},
		{"label": "unknown class", "participants": [_participant(alpha.profile_id, -1, 0, &"unknown")], "expected": "selected class"},
		{"label": "empty setup", "participants": [], "expected": "participant count"},
	]
	for test_case: Dictionary in invalid_cases:
		var errors: PackedStringArray = coordinator.call("begin", test_case["participants"])
		TestAssertions.truthy(not errors.is_empty() and errors[0].contains(String(test_case["expected"])), "%s rejects deterministically" % test_case["label"], failures)
		TestAssertions.truthy(coordinator.call("participant", alpha.profile_id) != null, "%s preserves the previous setup" % test_case["label"], failures)
	var five: Array = []
	for index: int in 5:
		five.append(_participant("profile-five-%02d" % index, index, index, &"fighter"))
	var too_many: PackedStringArray = coordinator.call("begin", five)
	TestAssertions.truthy(not too_many.is_empty() and too_many[0].contains("participant count"), "more than four participants rejects", failures)
	TestAssertions.truthy(coordinator.call("participant", alpha.profile_id) != null, "unsupported count preserves previous state", failures)
	ProfileTestSupport.remove_tree(root)

func _test_cancellation_stale_assignment_and_wrong_decisions(failures: Array[String]) -> void:
	var root := _case_root("decision_rejections")
	var store := ProfileStore.new()
	var profile := _profile("profile-decision-beta", "Beta", &"cleric", &"storm_chaplain_vestments", 1, 0, 0, 22, ["beta_unlock"])
	_save(store, profile, root, "decision profile", failures)
	var participant: Object = _participant(profile.profile_id, 0, 1, &"mage")
	var assignments := _assignment_map([participant])
	var coordinator: Object = _coordinator(store, root, assignments)
	var events: Array[Dictionary] = []
	coordinator.connect("decision_required", func(profile_id: String, projection: LoadoutCompatibilityProjection) -> void:
		events.append({"profile_id": profile_id, "projection": projection})
	)
	TestAssertions.equal(coordinator.call("begin", [participant]), PackedStringArray(), "incompatible participant begins behind its own warning", failures)
	TestAssertions.equal(events.size(), 1, "one incompatible profile emits one independent warning", failures)
	var path := store.profile_path(profile.profile_id, root)
	var bytes_before := FileAccess.get_file_as_bytes(path)
	var captured: Object = coordinator.call("participant", profile.profile_id) as Object
	var projection := captured.get("projection") as LoadoutCompatibilityProjection
	var escaped := projection.incompatible_items
	escaped[0]["instance_id"] = "escaped-item"
	TestAssertions.truthy((coordinator.call("participant", profile.profile_id) as Object).get("projection").incompatible_items[0]["instance_id"] != "escaped-item", "participant projection getter is defensive", failures)
	var decision := _decision(profile.profile_id, projection, "decision-current", false)

	var stale := decision.duplicate(true)
	stale["state_fingerprint"] = "0".repeat(64)
	_assert_submit_rejects(coordinator, profile.profile_id, stale, "stale", path, bytes_before, failures)
	var wrong_class := decision.duplicate(true)
	wrong_class["selected_class_id"] = "fighter"
	_assert_submit_rejects(coordinator, profile.profile_id, wrong_class, "selected class", path, bytes_before, failures)
	var wrong_profile := decision.duplicate(true)
	wrong_profile["profile_id"] = "profile-decision-other"
	_assert_submit_rejects(coordinator, profile.profile_id, wrong_profile, "profile", path, bytes_before, failures)
	var unknown_errors: PackedStringArray = coordinator.call("submit", "profile-decision-unknown", decision)
	TestAssertions.truthy(not unknown_errors.is_empty() and unknown_errors[0].contains("unknown profile"), "unknown decision profile rejects", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), bytes_before, "unknown profile rejection performs no write", failures)

	assignments[profile.profile_id] = {"device_id": 0, "player_slot": 1, "selected_class_id": "fighter"}
	_assert_submit_rejects(coordinator, profile.profile_id, decision, "assignment changed", path, bytes_before, failures)
	assignments[profile.profile_id] = {"device_id": 0, "player_slot": 1, "selected_class_id": "mage"}
	var cancelled := _decision(profile.profile_id, projection, "decision-cancel", true)
	TestAssertions.equal(coordinator.call("submit", profile.profile_id, cancelled), PackedStringArray(), "exact fresh cancellation is accepted", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), bytes_before, "cancellation performs no profile write", failures)
	TestAssertions.equal(coordinator.call("participant", profile.profile_id), null, "cancellation returns the whole coordinator to editable empty state", failures)
	TestAssertions.truthy(not bool(coordinator.call("is_locked")), "cancellation leaves coordinator unlocked", failures)
	TestAssertions.truthy(not bool(coordinator.call("cancel")), "repeated cancellation is deterministic and does no work", failures)
	ProfileTestSupport.remove_tree(root)

func _test_four_profile_isolation_and_stable_registry_lock(failures: Array[String]) -> void:
	var root := _case_root("four_profile")
	var store := ProfileStore.new()
	var profiles: Array[ProfileState] = [
		_profile("profile-local-alpha", "Alpha", &"fighter", &"forge_vanguard_sword", 9, 1, 1, 101, ["bring_in_gear"]),
		_profile("profile-local-beta", "Beta", &"ranger", &"greenwood_gloves", 2, 0, 0, 202, ["equipment_inventory", "stash"]),
		_profile("profile-local-gamma", "Gamma", &"mage", &"emberweave_wand", 9, 2, 2, 303, ["bring_in_gear", "leader_loadout_extraction"]),
		_profile("profile-local-delta", "Delta", &"cleric", &"storm_chaplain_vestments", 1, 3, 3, 404, ["equipment_inventory", "stash", "delta_unlock"]),
	]
	for profile: ProfileState in profiles:
		_save(store, profile, root, profile.display_name, failures)
	var joined: Array = [
		_participant(profiles[0].profile_id, -1, 3, &"fighter"),
		_participant(profiles[1].profile_id, 0, 0, &"mage"),
		_participant(profiles[2].profile_id, 1, 2, &"ranger"),
		_participant(profiles[3].profile_id, 2, 1, &"rogue"),
	]
	var assignments := _assignment_map(joined)
	var coordinator: Object = _coordinator(store, root, assignments)
	var warning_profiles: Array[String] = []
	coordinator.connect("decision_required", func(profile_id: String, _projection: LoadoutCompatibilityProjection) -> void:
		warning_profiles.append(profile_id)
	)
	var paths: Dictionary = {}
	var initial_bytes: Dictionary = {}
	var initial_artifacts: Dictionary = {}
	for profile: ProfileState in profiles:
		paths[profile.profile_id] = store.profile_path(profile.profile_id, root)
		initial_bytes[profile.profile_id] = FileAccess.get_file_as_bytes(paths[profile.profile_id])
		initial_artifacts[profile.profile_id] = _profile_artifact_bytes(paths[profile.profile_id])
	TestAssertions.equal(coordinator.call("begin", joined), PackedStringArray(), "four distinct joined profiles begin independently", failures)
	TestAssertions.equal(warning_profiles, [profiles[1].profile_id, profiles[2].profile_id, profiles[3].profile_id], "only each incompatible profile emits its own warning", failures)
	for profile: ProfileState in profiles:
		TestAssertions.equal(FileAccess.get_file_as_bytes(paths[profile.profile_id]), initial_bytes[profile.profile_id], "begin performs no write for %s" % profile.profile_id, failures)
	TestAssertions.equal((coordinator.call("ready_contexts") as Array).size(), 0, "one or more unresolved warnings block final readiness", failures)
	var armoury := coordinator.call("armoury_projection", profiles[0].profile_id) as ProfileStorageProjection
	TestAssertions.truthy(armoury != null and armoury.valid and armoury.profile_id == profiles[0].profile_id, "pending peers do not block another profile's Armoury inspection", failures)
	var armoury_items := armoury.item_records
	armoury_items.clear()
	TestAssertions.truthy(not (coordinator.call("armoury_projection", profiles[0].profile_id) as ProfileStorageProjection).item_records.is_empty(), "Armoury inspection output is defensive", failures)

	var beta_projection := (coordinator.call("participant", profiles[1].profile_id) as Object).get("projection") as LoadoutCompatibilityProjection
	var beta_decision := _decision(profiles[1].profile_id, beta_projection, "four-beta", false)
	TestAssertions.equal(coordinator.call("submit", profiles[1].profile_id, beta_decision), PackedStringArray(), "Beta resolves only Beta's warning", failures)
	TestAssertions.truthy(FileAccess.get_file_as_bytes(paths[profiles[1].profile_id]) != initial_bytes[profiles[1].profile_id], "Beta transition changes Beta bytes", failures)
	for profile_index: int in [0, 2, 3]:
		var profile := profiles[profile_index]
		TestAssertions.equal(FileAccess.get_file_as_bytes(paths[profile.profile_id]), initial_bytes[profile.profile_id], "Beta transition preserves exact %s bytes" % profile.profile_id, failures)
		TestAssertions.equal(_profile_artifact_bytes(paths[profile.profile_id]), initial_artifacts[profile.profile_id], "Beta transition preserves exact %s primary and backup artifacts" % profile.profile_id, failures)
	TestAssertions.equal((coordinator.call("ready_contexts") as Array).size(), 0, "Gamma and Delta remain independent blockers", failures)
	TestAssertions.truthy((coordinator.call("armoury_projection", profiles[0].profile_id) as ProfileStorageProjection).valid, "Alpha inspection remains available after Beta transition", failures)

	for profile_index: int in [2, 3]:
		var profile := profiles[profile_index]
		var pending_projection := (coordinator.call("participant", profile.profile_id) as Object).get("projection") as LoadoutCompatibilityProjection
		TestAssertions.equal(coordinator.call("submit", profile.profile_id, _decision(profile.profile_id, pending_projection, "four-%d" % profile_index, false)), PackedStringArray(), "%s resolves independently" % profile.display_name, failures)
	var contexts: Array = coordinator.call("ready_contexts") as Array
	TestAssertions.equal(contexts.size(), 4, "all four resolved profiles produce four contexts", failures)
	if contexts.size() == 4:
		TestAssertions.equal([contexts[0].player_slot_index, contexts[1].player_slot_index, contexts[2].player_slot_index, contexts[3].player_slot_index], [0, 1, 2, 3], "ready contexts use ascending stable player-slot order", failures)
		TestAssertions.equal([contexts[0].profile_id, contexts[1].profile_id, contexts[2].profile_id, contexts[3].profile_id], [profiles[1].profile_id, profiles[3].profile_id, profiles[2].profile_id, profiles[0].profile_id], "slot order preserves exact profile ownership", failures)
	TestAssertions.truthy(bool(coordinator.call("is_locked")), "first successful ready call locks Arena join-before-run roster", failures)
	var registry := coordinator.call("run_context_registry") as RunContextRegistry
	TestAssertions.truthy(registry != null and registry.is_arena_roster_locked() and registry.all_contexts().size() == 4, "coordinator consumes the existing RunContextRegistry lock contract", failures)
	var locked_bytes: Dictionary = {}
	var locked_artifacts: Dictionary = {}
	for profile: ProfileState in profiles:
		locked_bytes[profile.profile_id] = FileAccess.get_file_as_bytes(paths[profile.profile_id])
		locked_artifacts[profile.profile_id] = _profile_artifact_bytes(paths[profile.profile_id])
	TestAssertions.equal((coordinator.call("ready_contexts") as Array).size(), 0, "repeated ready call after lock returns the explicit empty sentinel", failures)
	var locked_submit: PackedStringArray = coordinator.call("submit", profiles[1].profile_id, beta_decision)
	TestAssertions.truthy(not locked_submit.is_empty() and locked_submit[0].contains("locked"), "submission after lock rejects", failures)
	TestAssertions.truthy(not bool(coordinator.call("cancel")), "cancellation after lock rejects", failures)
	var locked_begin: PackedStringArray = coordinator.call("begin", joined)
	TestAssertions.truthy(not locked_begin.is_empty() and locked_begin[0].contains("locked"), "begin after lock rejects", failures)
	for profile: ProfileState in profiles:
		TestAssertions.equal(FileAccess.get_file_as_bytes(paths[profile.profile_id]), locked_bytes[profile.profile_id], "post-lock operations preserve %s bytes" % profile.profile_id, failures)
		TestAssertions.equal(_profile_artifact_bytes(paths[profile.profile_id]), locked_artifacts[profile.profile_id], "post-lock operations preserve %s primary and backup artifacts" % profile.profile_id, failures)

	var saved_alpha := store.load_profile(profiles[0].profile_id, root).profile
	var saved_beta := store.load_profile(profiles[1].profile_id, root).profile
	var saved_gamma := store.load_profile(profiles[2].profile_id, root).profile
	var saved_delta := store.load_profile(profiles[3].profile_id, root).profile
	TestAssertions.equal(_profile_item_ids(saved_alpha), ["item-profile-local-alpha", "stash-profile-local-alpha-000"], "Alpha retains its exact item ids", failures)
	TestAssertions.equal(_profile_item_ids(saved_beta), [], "Beta destroys only its own confirmed overflow item", failures)
	TestAssertions.equal(_profile_item_ids(saved_gamma), ["item-profile-local-gamma", "stash-profile-local-gamma-000", "stash-profile-local-gamma-001"], "Gamma moves but preserves its exact item ids", failures)
	TestAssertions.equal(_profile_item_ids(saved_delta), ["item-profile-local-delta", "stash-profile-local-delta-000", "stash-profile-local-delta-001", "stash-profile-local-delta-002"], "Delta moves but preserves its exact item ids", failures)
	TestAssertions.equal([saved_alpha.stash_tabs.size(), saved_beta.stash_tabs.size(), saved_gamma.stash_tabs.size(), saved_delta.stash_tabs.size()], [1, 0, 2, 3], "four profiles retain different stash capacities", failures)
	TestAssertions.equal([_stash_occupancy(saved_alpha), _stash_occupancy(saved_beta), _stash_occupancy(saved_gamma), _stash_occupancy(saved_delta)], [1, 0, 3, 4], "four profiles retain independent distinct stash occupancy after their own transitions", failures)
	TestAssertions.equal([saved_alpha.gold, saved_beta.gold, saved_gamma.gold, saved_delta.gold], [101, 202, 303, 404], "all four gold balances remain isolated", failures)
	TestAssertions.equal([saved_alpha.extraction_capacity, saved_beta.extraction_capacity, saved_gamma.extraction_capacity, saved_delta.extraction_capacity], [1, 0, 2, 3], "all four extraction capacities remain isolated", failures)
	TestAssertions.equal([saved_alpha.permanent_feature_unlocks, saved_beta.permanent_feature_unlocks, saved_gamma.permanent_feature_unlocks, saved_delta.permanent_feature_unlocks], [profiles[0].permanent_feature_unlocks, profiles[1].permanent_feature_unlocks, profiles[2].permanent_feature_unlocks, profiles[3].permanent_feature_unlocks], "all four unlock sets remain isolated", failures)
	ProfileTestSupport.remove_tree(root)

func _coordinator(store: ProfileStore, root: String, assignments: Dictionary) -> Object:
	return COORDINATOR_SCRIPT.new({
		"profile_store": store,
		"profile_root": root,
		"assignment_guard": func(participant: Object) -> bool:
			var current := assignments.get(String(participant.get("profile_id")), {}) as Dictionary
			return (
				int(current.get("device_id", -999)) == int(participant.get("device_id"))
				and int(current.get("player_slot", -999)) == int(participant.get("player_slot"))
				and StringName(current.get("selected_class_id", "")) == participant.get("selected_class_id")
			),
		"context_factory": func(participant: Object, profile: ProfileState) -> PlayerRunContext:
			var catalog := GameCatalog.load_defaults()
			var party := PartyManager.new()
			party.initialize(catalog.class_by_id(participant.get("selected_class_id")), catalog.traits)
			_parties.append(party)
			var context := PlayerRunContext.new()
			var slot := int(participant.get("player_slot"))
			var errors := context.configure(
				StringName("local-player-%02d" % slot),
				slot,
				profile,
				5100 + slot,
				party,
				100,
			)
			return context if errors.is_empty() else null,
	}) as Object

func _participant(profile_id: String, device_id: int, player_slot: int, class_id: StringName) -> Object:
	return PARTICIPANT_SCRIPT.new(profile_id, device_id, player_slot, class_id) as Object

func _assignment_map(participants: Array) -> Dictionary:
	var result: Dictionary = {}
	for participant: Object in participants:
		result[String(participant.get("profile_id"))] = {
			"device_id": int(participant.get("device_id")),
			"player_slot": int(participant.get("player_slot")),
			"selected_class_id": String(participant.get("selected_class_id")),
		}
	return result

func _decision(profile_id: String, projection: LoadoutCompatibilityProjection, transaction_id: String, cancelled: bool) -> Dictionary:
	return {
		"cancelled": cancelled,
		"confirmation_token": projection.confirmation_token,
		"confirmed": not cancelled,
		"incompatible_sources": projection.incompatible_sources(),
		"overflow_item_ids": projection.overflow_item_ids,
		"planned_stash_destinations": projection.planned_stash_destinations,
		"profile_id": profile_id,
		"selected_class_id": String(projection.selected_class_id),
		"state_fingerprint": projection.state_fingerprint,
		"transaction_id": transaction_id,
	}

func _profile(
	profile_id: String,
	display_name: String,
	loadout_class_id: StringName,
	base_id: StringName,
	slot: int,
	extraction_capacity: int,
	stash_tab_count: int,
	gold: int,
	unlocks: Array[String],
) -> ProfileState:
	var profile := ProfileState.new_profile(profile_id, display_name, 1000)
	profile.inventory_columns = clampi(extraction_capacity + 1, 1, 8)
	profile.extraction_capacity = extraction_capacity
	profile.gold = gold
	profile.permanent_feature_unlocks = unlocks.duplicate()
	var item := _item(profile_id, base_id)
	var items: Array[ItemInstance] = [item]
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout",
		ItemSlotContainer.PROFILE_LEADER_EQUIPMENT,
		profile_id,
		EquipmentSlotIndex.capacity(),
		{slot: item.instance_id},
	).to_dictionary()
	profile.leader_loadout_class_id = String(loadout_class_id)
	for index: int in stash_tab_count:
		var filler := _item_with_id(profile_id, "stash-%s-%03d" % [profile_id, index], &"forge_vanguard_ring_left", index + 1)
		items.append(filler)
		profile.stash_tabs.append(ItemSlotContainer.create(
			StringName("stash-tab-%03d" % index),
			ItemSlotContainer.PROFILE_STASH_TAB,
			profile_id,
			ItemSlotContainer.STASH_CAPACITY,
			{0: filler.instance_id},
		).to_dictionary())
	profile.item_records = ItemRegistry.new(items).to_dictionary()
	return profile

func _item(profile_id: String, base_id: StringName) -> ItemInstance:
	return _item_with_id(profile_id, "item-%s" % profile_id, base_id, 0)

func _item_with_id(profile_id: String, instance_id: String, base_id: StringName, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 20
	item.rarity_id = &"common"
	item.origin = {
		"issuer_namespace": "profile:%s" % profile_id,
		"seed": 9001,
		"sequence": sequence,
		"source": "local_setup_test",
	}
	return item

func _save(store: ProfileStore, profile: ProfileState, root: String, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(store.save_profile(profile, root), "", "%s profile saves" % label, failures)
	TestAssertions.equal(store.save_profile(profile, root), "", "%s profile creates a stable recovery generation" % label, failures)

func _assert_submit_rejects(
	coordinator: Object,
	profile_id: String,
	decision: Dictionary,
	expected: String,
	path: String,
	bytes_before: PackedByteArray,
	failures: Array[String],
) -> void:
	var errors: PackedStringArray = coordinator.call("submit", profile_id, decision)
	TestAssertions.truthy(not errors.is_empty() and errors[0].contains(expected), "%s decision rejects" % expected, failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), bytes_before, "%s rejection performs no write" % expected, failures)

func _profile_item_ids(profile: ProfileState) -> Array[String]:
	var decoded := ItemRegistry._decode(profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not String(decoded["error"]).is_empty():
		return []
	return (decoded["value"] as ItemRegistry).ids()

func _stash_occupancy(profile: ProfileState) -> int:
	var result := 0
	for tab: Dictionary in profile.stash_tabs:
		result += (tab.get("slots", {}) as Dictionary).size()
	return result

func _profile_artifact_bytes(path: String) -> Dictionary:
	var result := {"primary": FileAccess.get_file_as_bytes(path)}
	var backup_path := "%s.bak" % path
	if FileAccess.file_exists(backup_path):
		result["backup"] = FileAccess.get_file_as_bytes(backup_path)
	return result

func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false

func _case_root(label: String) -> String:
	_root_counter += 1
	var root := "user://tests/local_setup_%s_%d_%d_%d" % [label, OS.get_process_id(), Time.get_ticks_usec(), _root_counter]
	ProfileTestSupport.remove_tree(root)
	return root
