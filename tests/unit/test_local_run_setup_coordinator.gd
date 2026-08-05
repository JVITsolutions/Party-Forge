extends RefCounted

const PARTICIPANT_PATH := "res://scripts/run/local_run_setup_participant.gd"
const COORDINATOR_PATH := "res://scripts/run/local_run_setup_coordinator.gd"
const PARTICIPANT_SCRIPT := preload(PARTICIPANT_PATH)
const COORDINATOR_SCRIPT := preload(COORDINATOR_PATH)


class RecordingCheckout extends RunLoadoutCheckoutService:
	var calls_by_profile: Dictionary = {}
	var tracked_paths: Dictionary = {}
	var observations: Array[Dictionary] = []

	func checkout(
		profile_id: String,
		request: RunLoadoutCheckoutRequest,
		root: String = ProfileStore.DEFAULT_ROOT,
	) -> ProfileMutationResult:
		var before := _artifacts()
		calls_by_profile[profile_id] = int(calls_by_profile.get(profile_id, 0)) + 1
		var result := super.checkout(profile_id, request, root)
		observations.append({
			"profile_id": profile_id,
			"request": request.canonical_document() if request != null else {},
			"before": before,
			"after": _artifacts(),
		})
		return result

	func _artifacts() -> Dictionary:
		var result: Dictionary = {}
		for profile_id: String in tracked_paths:
			var path := String(tracked_paths[profile_id])
			var bytes := {"primary": FileAccess.get_file_as_bytes(path)}
			var backup_path := "%s.bak" % path
			if FileAccess.file_exists(backup_path):
				bytes["backup"] = FileAccess.get_file_as_bytes(backup_path)
			result[profile_id] = bytes
		return result


class RecordingRequestFactory extends RefCounted:
	var calls_by_profile: Dictionary = {}
	var duplicate_all_run_players := false
	var duplicate_on_second_call_profile := ""
	var malformed_slot := -1

	func create(participant: LocalRunSetupParticipant, profile: ProfileState) -> RunLoadoutCheckoutRequest:
		if participant == null or profile == null:
			return null
		var call_count := int(calls_by_profile.get(participant.profile_id, 0)) + 1
		calls_by_profile[participant.profile_id] = call_count
		var run_player_id := StringName("local-player-%02d" % participant.player_slot)
		if duplicate_all_run_players:
			run_player_id = &"local-player-duplicate"
		elif participant.profile_id == duplicate_on_second_call_profile and call_count == 2:
			run_player_id = &"local-player-00"
		return RunLoadoutCheckoutRequest.create(
			"local-checkout-%s" % profile.profile_id,
			"malformed-profile" if participant.player_slot == malformed_slot else profile.profile_id,
			StringName("local-run-%s" % profile.profile_id),
			6100 + participant.player_slot,
			run_player_id,
			1,
			participant.selected_class_id,
			"bring_in_gear" in profile.permanent_feature_unlocks,
		)


class BootstrapContextFactory extends RefCounted:
	var fail_once_slot := -1
	var failed := false
	var received_documents: Dictionary = {}
	var calls_by_profile: Dictionary = {}
	var party_sink: Array[PartyManager]

	func create(
		participant: LocalRunSetupParticipant,
		profile: ProfileState,
		bootstrap: RunItemBootstrap = null,
	) -> PlayerRunContext:
		if participant == null or profile == null or bootstrap == null:
			return null
		calls_by_profile[participant.profile_id] = int(calls_by_profile.get(participant.profile_id, 0)) + 1
		received_documents[participant.profile_id] = ResumableRunItemCodec.encode(bootstrap)
		if participant.player_slot == fail_once_slot and not failed:
			failed = true
			return null
		var catalog := GameCatalog.load_defaults()
		var party := PartyManager.new()
		party.initialize(catalog.class_by_id(participant.selected_class_id), catalog.traits)
		party_sink.append(party)
		var context := PlayerRunContext.new()
		var errors := context.configure(
			bootstrap.run_player_id,
			participant.player_slot,
			profile,
			bootstrap.run_seed,
			party,
			100,
			bootstrap,
		)
		return context if errors.is_empty() else null


class InvalidOnceContextFactory extends RefCounted:
	var mode := ""
	var failed := false
	var calls := 0
	var party_sink: Array[PartyManager]

	func create(
		participant: LocalRunSetupParticipant,
		profile: ProfileState,
		bootstrap: RunItemBootstrap = null,
	) -> PlayerRunContext:
		if participant == null or profile == null or bootstrap == null:
			return null
		calls += 1
		var catalog := GameCatalog.load_defaults()
		var leader_class := catalog.class_by_id(participant.selected_class_id)
		var context_profile := profile
		if not failed and mode == "wrong_class":
			leader_class = catalog.class_by_id(&"mage")
			failed = true
		elif not failed and mode == "altered_profile":
			context_profile.gold += 1
			failed = true
		var party := PartyManager.new()
		party.initialize(leader_class, catalog.traits)
		party_sink.append(party)
		var context := PlayerRunContext.new()
		var errors := context.configure(
			bootstrap.run_player_id,
			participant.player_slot,
			context_profile,
			bootstrap.run_seed,
			party,
			100,
			bootstrap,
		)
		return context if errors.is_empty() else null


class AssignmentGate extends RefCounted:
	var assignments: Dictionary = {}
	var enabled := true

	func validate(participant: LocalRunSetupParticipant) -> bool:
		if not enabled or participant == null:
			return false
		var current := assignments.get(participant.profile_id, {}) as Dictionary
		return (
			int(current.get("device_id", -999)) == participant.device_id
			and int(current.get("player_slot", -999)) == participant.player_slot
			and StringName(current.get("selected_class_id", "")) == participant.selected_class_id
		)


var _root_counter := 0
var _parties: Array[PartyManager] = []
var _context_factories: Array[BootstrapContextFactory] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_api_and_participant_defense(failures)
	_test_begin_validation_and_state_atomicity(failures)
	_test_assignment_guard_fails_closed(failures)
	_test_cancellation_stale_assignment_and_wrong_decisions(failures)
	_test_request_preflight_is_mutation_free(failures)
	_test_partial_checkout_retry_reuses_exact_bootstraps(failures)
	_test_context_contract_retry_reuses_committed_checkout(failures)
	_test_cancellation_checkout_boundary(failures)
	_test_four_profile_isolation_and_stable_registry_lock(failures)
	for party: PartyManager in _parties:
		party.free()
	_parties.clear()
	_context_factories.clear()
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
	TestAssertions.truthy(not _has_property(participant, &"context"), "participant does not expose a stored mutable run context", failures)

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


func _test_assignment_guard_fails_closed(failures: Array[String]) -> void:
	var root := _case_root("assignment_guard")
	var store := ProfileStore.new()
	var profile := _profile("profile-guard-alpha", "Guard Alpha", &"fighter", &"forge_vanguard_sword", 9, 1, 0, 31, ["bring_in_gear"])
	_save(store, profile, root, "assignment guard profile", failures)
	var participant: LocalRunSetupParticipant = _participant(profile.profile_id, -1, 0, &"fighter") as LocalRunSetupParticipant
	var path := store.profile_path(profile.profile_id, root)
	var artifacts_before := _profile_artifact_bytes(path)
	var missing_guard := COORDINATOR_SCRIPT.new({
		"profile_store": store,
		"profile_root": root,
	}) as LocalRunSetupCoordinator
	var missing_errors := missing_guard.begin([participant])
	TestAssertions.truthy(not missing_errors.is_empty() and missing_errors[0].contains("assignment"), "ordinary coordinator without assignment validation fails closed", failures)
	TestAssertions.equal(missing_guard.participant(profile.profile_id), null, "missing guard publishes no captured participant", failures)
	TestAssertions.equal(_profile_artifact_bytes(path), artifacts_before, "missing guard rejection performs no primary or backup write", failures)

	var gate := AssignmentGate.new()
	gate.assignments = _assignment_map([participant])
	var context_factory := BootstrapContextFactory.new()
	context_factory.party_sink = _parties
	var coordinator := _coordinator(store, root, gate.assignments, {
		"assignment_guard": Callable(gate, "validate"),
		"context_factory": Callable(context_factory, "create"),
	}) as LocalRunSetupCoordinator
	TestAssertions.equal(coordinator.begin([participant]), PackedStringArray(), "valid guard captures a compatible participant", failures)
	gate.enabled = false
	TestAssertions.equal(coordinator.ready_contexts(), [], "invalidated assignment blocks readiness", failures)
	TestAssertions.equal(coordinator.armoury_projection(profile.profile_id), null, "invalidated assignment blocks profile inspection", failures)
	TestAssertions.equal(_profile_artifact_bytes(path), artifacts_before, "failed-closed readiness and inspection perform no writes", failures)
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


func _test_request_preflight_is_mutation_free(failures: Array[String]) -> void:
	for malformed_slot: int in [-1, 1]:
		var label := "duplicate" if malformed_slot < 0 else "malformed"
		var root := _case_root("request_preflight_%s" % label)
		var store := ProfileStore.new()
		var profiles: Array[ProfileState] = [
			_profile("profile-preflight-%s-alpha" % label, "Preflight Alpha", &"fighter", &"forge_vanguard_sword", 9, 1, 0, 51, ["bring_in_gear"]),
			_profile("profile-preflight-%s-beta" % label, "Preflight Beta", &"fighter", &"forge_vanguard_sword", 9, 1, 0, 52, ["bring_in_gear"]),
		]
		var joined: Array = [
			_participant(profiles[0].profile_id, -1, 0, &"fighter"),
			_participant(profiles[1].profile_id, 0, 1, &"fighter"),
		]
		var paths: Dictionary = {}
		for profile: ProfileState in profiles:
			_save(store, profile, root, "%s %s" % [label, profile.display_name], failures)
			paths[profile.profile_id] = store.profile_path(profile.profile_id, root)
		var artifacts_before: Dictionary = {}
		for profile: ProfileState in profiles:
			artifacts_before[profile.profile_id] = _profile_artifact_bytes(paths[profile.profile_id])
		var checkout := RecordingCheckout.new(ProfileMutationService.new(store))
		checkout.tracked_paths = paths
		var requests := RecordingRequestFactory.new()
		requests.duplicate_all_run_players = malformed_slot < 0
		requests.malformed_slot = malformed_slot
		var coordinator := _coordinator(store, root, _assignment_map(joined), {
			"checkout_service": checkout,
			"checkout_request_factory": Callable(requests, "create"),
		}) as LocalRunSetupCoordinator
		TestAssertions.equal(coordinator.begin(joined), PackedStringArray(), "%s request fixture begins" % label, failures)
		TestAssertions.equal(coordinator.ready_contexts(), [], "%s request preflight rejects readiness" % label, failures)
		TestAssertions.equal(checkout.observations.size(), 0, "%s request preflight performs zero checkout calls" % label, failures)
		TestAssertions.equal(requests.calls_by_profile, {profiles[0].profile_id: 1, profiles[1].profile_id: 1}, "%s request factory runs exactly once per participant" % label, failures)
		TestAssertions.equal(coordinator.run_context_registry(), null, "%s request preflight publishes no registry" % label, failures)
		TestAssertions.truthy(not coordinator.is_locked(), "%s request preflight remains retryable" % label, failures)
		for profile: ProfileState in profiles:
			var durable := store.load_profile(profile.profile_id, root).profile
			TestAssertions.equal(_profile_artifact_bytes(paths[profile.profile_id]), artifacts_before[profile.profile_id], "%s preflight preserves exact %s primary and backup bytes" % [label, profile.profile_id], failures)
			TestAssertions.equal(durable.resumable_run, {}, "%s preflight creates no resumable run for %s" % [label, profile.profile_id], failures)
			TestAssertions.equal(_operation_count(durable, "run_loadout_checkout"), 0, "%s preflight creates no checkout journal for %s" % [label, profile.profile_id], failures)
		ProfileTestSupport.remove_tree(root)


func _test_partial_checkout_retry_reuses_exact_bootstraps(failures: Array[String]) -> void:
	var root := _case_root("checkout_retry")
	var store := ProfileStore.new()
	var profiles: Array[ProfileState] = []
	var joined: Array = []
	for slot: int in 4:
		var profile := _profile(
			"profile-retry-%02d" % slot,
			"Retry %d" % slot,
			&"fighter",
			&"forge_vanguard_sword",
			9,
			slot + 1,
			slot,
			700 + slot,
			["bring_in_gear"],
		)
		profiles.append(profile)
		joined.append(_participant(profile.profile_id, slot - 1, slot, &"fighter"))
		_save(store, profile, root, profile.display_name, failures)
	var paths: Dictionary = {}
	for profile: ProfileState in profiles:
		paths[profile.profile_id] = store.profile_path(profile.profile_id, root)
	var checkout := RecordingCheckout.new(ProfileMutationService.new(store))
	checkout.tracked_paths = paths
	var requests := RecordingRequestFactory.new()
	requests.duplicate_on_second_call_profile = profiles[3].profile_id
	var context_factory := BootstrapContextFactory.new()
	context_factory.fail_once_slot = 2
	context_factory.party_sink = _parties
	var coordinator := _coordinator(store, root, _assignment_map(joined), {
		"checkout_service": checkout,
		"checkout_request_factory": Callable(requests, "create"),
		"context_factory": Callable(context_factory, "create"),
	}) as LocalRunSetupCoordinator
	TestAssertions.equal(coordinator.begin(joined), PackedStringArray(), "four compatible profiles begin before checkout", failures)
	TestAssertions.equal(coordinator.ready_contexts(), [], "injected third-context failure keeps readiness retryable", failures)
	TestAssertions.equal(coordinator.run_context_registry(), null, "failed readiness publishes no partial registry", failures)
	TestAssertions.truthy(not coordinator.is_locked(), "failed readiness does not lock a partial registry", failures)
	TestAssertions.equal(checkout.observations.size(), 3, "failure after the third committed checkout leaves the fourth unattempted", failures)
	for observation_index: int in checkout.observations.size():
		var observation := checkout.observations[observation_index]
		var changed_profile_id := String(observation["profile_id"])
		for profile: ProfileState in profiles:
			var before: Dictionary = (observation["before"] as Dictionary)[profile.profile_id]
			var after: Dictionary = (observation["after"] as Dictionary)[profile.profile_id]
			if profile.profile_id == changed_profile_id:
				TestAssertions.truthy(after != before, "staggered checkout %d changes only %s artifacts" % [observation_index, profile.profile_id], failures)
			else:
				TestAssertions.equal(after, before, "staggered checkout %d preserves exact %s primary and backup" % [observation_index, profile.profile_id], failures)
	for slot: int in 3:
		var durable := store.load_profile(profiles[slot].profile_id, root).profile
		TestAssertions.truthy(not durable.resumable_run.is_empty(), "partial failure retains committed bootstrap for slot %d" % slot, failures)
		TestAssertions.equal(_operation_count(durable, "run_loadout_checkout"), 1, "partial failure records one checkout journal entry for slot %d" % slot, failures)
	TestAssertions.equal(store.load_profile(profiles[3].profile_id, root).profile.resumable_run, {}, "future profile remains uncommitted after earlier context failure", failures)

	var partial_artifacts: Dictionary = {}
	for profile: ProfileState in profiles:
		partial_artifacts[profile.profile_id] = _profile_artifact_bytes(paths[profile.profile_id])
	TestAssertions.equal(coordinator.ready_contexts(), [], "retry preflights committed recovery together with an invalid fresh request", failures)
	TestAssertions.equal(checkout.observations.size(), 3, "failed retry preflight performs no additional checkout", failures)
	for profile: ProfileState in profiles:
		TestAssertions.equal(_profile_artifact_bytes(paths[profile.profile_id]), partial_artifacts[profile.profile_id], "failed retry preflight preserves exact %s primary and backup bytes" % profile.profile_id, failures)
	TestAssertions.equal(int(requests.calls_by_profile.get(profiles[0].profile_id, 0)), 1, "retry does not regenerate first committed request", failures)
	TestAssertions.equal(int(requests.calls_by_profile.get(profiles[1].profile_id, 0)), 1, "retry does not regenerate second committed request", failures)
	TestAssertions.equal(int(requests.calls_by_profile.get(profiles[2].profile_id, 0)), 1, "retry does not regenerate third committed request", failures)
	TestAssertions.equal(int(requests.calls_by_profile.get(profiles[3].profile_id, 0)), 2, "retry generates the uncommitted request exactly once", failures)

	var contexts := coordinator.ready_contexts()
	TestAssertions.equal(contexts.size(), 4, "retry completes all four contexts from durable continuity", failures)
	if contexts.size() == 4:
		TestAssertions.equal([contexts[0].player_slot_index, contexts[1].player_slot_index, contexts[2].player_slot_index, contexts[3].player_slot_index], [0, 1, 2, 3], "retry preserves stable ascending slot order", failures)
	TestAssertions.truthy(coordinator.run_context_registry() != null and coordinator.run_context_registry().is_arena_roster_locked(), "registry publishes and locks only after retry validates every context", failures)
	for slot: int in 4:
		var profile := store.load_profile(profiles[slot].profile_id, root).profile
		var profile_id := profile.profile_id
		TestAssertions.equal(int(checkout.calls_by_profile.get(profile_id, 0)), 1, "retry performs exactly one checkout call for %s" % profile_id, failures)
		TestAssertions.equal(_operation_count(profile, "run_loadout_checkout"), 1, "retry leaves exactly one checkout journal entry for %s" % profile_id, failures)
		TestAssertions.equal(context_factory.received_documents.get(profile_id, {}), _canonical_resumable(profile.resumable_run), "context factory receives the exact committed bootstrap for %s" % profile_id, failures)
		if contexts.size() == 4:
			TestAssertions.equal(String(contexts[slot].run_id), String(profile.resumable_run.get("run_id", "")), "context uses the committed run id for slot %d" % slot, failures)
			TestAssertions.equal(contexts[slot].run_seed, int(profile.resumable_run.get("run_seed", 0)), "context uses the committed run seed for slot %d" % slot, failures)
			var run_equipment := contexts[slot].equipment_for(1)
			TestAssertions.equal(run_equipment.item_id_at(9), "item-%s" % profile_id, "checked-out gear populates only %s run equipment" % profile_id, failures)
		TestAssertions.equal(_profile_item_ids(profile), _expected_stash_item_ids(profile_id, slot), "bring-in gear leaves %s persistent profile ownership" % profile_id, failures)
	ProfileTestSupport.remove_tree(root)


func _test_context_contract_retry_reuses_committed_checkout(failures: Array[String]) -> void:
	for mode: String in ["wrong_class", "altered_profile"]:
		var root := _case_root("context_contract_%s" % mode)
		var store := ProfileStore.new()
		var profile := _profile("profile-context-%s" % mode, "Context %s" % mode, &"fighter", &"forge_vanguard_sword", 9, 1, 0, 91, ["bring_in_gear"])
		_save(store, profile, root, "%s context profile" % mode, failures)
		var participant := _participant(profile.profile_id, -1, 0, &"fighter") as LocalRunSetupParticipant
		var path := store.profile_path(profile.profile_id, root)
		var checkout := RecordingCheckout.new(ProfileMutationService.new(store))
		checkout.tracked_paths = {profile.profile_id: path}
		var context_factory := InvalidOnceContextFactory.new()
		context_factory.mode = mode
		context_factory.party_sink = _parties
		var coordinator := _coordinator(store, root, _assignment_map([participant]), {
			"checkout_service": checkout,
			"context_factory": Callable(context_factory, "create"),
		}) as LocalRunSetupCoordinator
		TestAssertions.equal(coordinator.begin([participant]), PackedStringArray(), "%s context fixture begins" % mode, failures)
		TestAssertions.equal(coordinator.ready_contexts(), [], "%s context rejects before registry publication" % mode, failures)
		TestAssertions.equal(coordinator.run_context_registry(), null, "%s context publishes no registry" % mode, failures)
		TestAssertions.truthy(not coordinator.is_locked(), "%s context failure remains retryable" % mode, failures)
		var committed := store.load_profile(profile.profile_id, root).profile
		TestAssertions.truthy(not committed.resumable_run.is_empty(), "%s context failure retains committed checkout" % mode, failures)
		TestAssertions.equal(int(checkout.calls_by_profile.get(profile.profile_id, 0)), 1, "%s context failure checks out once" % mode, failures)
		TestAssertions.equal(_operation_count(committed, "run_loadout_checkout"), 1, "%s context failure records one checkout journal" % mode, failures)
		var committed_artifacts := _profile_artifact_bytes(path)
		var contexts := coordinator.ready_contexts()
		TestAssertions.equal(contexts.size(), 1, "%s context retry succeeds from committed recovery" % mode, failures)
		TestAssertions.equal(context_factory.calls, 2, "%s context factory runs once per readiness attempt" % mode, failures)
		if contexts.size() == 1:
			var leader := contexts[0].party.member_by_id(1)
			TestAssertions.truthy(leader != null and leader.is_leader and leader.class_definition.id == &"fighter", "%s retry publishes the selected Fighter leader" % mode, failures)
			TestAssertions.equal(ProfileCodec.encode(contexts[0].profile_snapshot), ProfileCodec.encode(store.load_profile(profile.profile_id, root).profile), "%s retry publishes the exact committed profile snapshot" % mode, failures)
		TestAssertions.equal(int(checkout.calls_by_profile.get(profile.profile_id, 0)), 1, "%s context retry performs no second checkout" % mode, failures)
		TestAssertions.equal(_operation_count(store.load_profile(profile.profile_id, root).profile, "run_loadout_checkout"), 1, "%s context retry retains one checkout journal" % mode, failures)
		TestAssertions.equal(_profile_artifact_bytes(path), committed_artifacts, "%s context retry performs no profile write" % mode, failures)
		TestAssertions.truthy(coordinator.run_context_registry() != null and coordinator.run_context_registry().is_arena_roster_locked(), "%s context retry publishes one locked registry" % mode, failures)
		ProfileTestSupport.remove_tree(root)


func _test_cancellation_checkout_boundary(failures: Array[String]) -> void:
	var root := _case_root("checkout_cancel")
	var store := ProfileStore.new()
	var profiles: Array[ProfileState] = [
		_profile("profile-cancel-alpha", "Cancel Alpha", &"fighter", &"forge_vanguard_sword", 9, 1, 0, 801, ["bring_in_gear"]),
		_profile("profile-cancel-beta", "Cancel Beta", &"fighter", &"forge_vanguard_sword", 9, 2, 1, 802, ["bring_in_gear"]),
	]
	var joined: Array = [
		_participant(profiles[0].profile_id, -1, 0, &"fighter"),
		_participant(profiles[1].profile_id, 0, 1, &"fighter"),
	]
	for profile: ProfileState in profiles:
		_save(store, profile, root, profile.display_name, failures)
	var paths := {
		profiles[0].profile_id: store.profile_path(profiles[0].profile_id, root),
		profiles[1].profile_id: store.profile_path(profiles[1].profile_id, root),
	}
	var checkout := RecordingCheckout.new(ProfileMutationService.new(store))
	checkout.tracked_paths = paths
	var context_factory := BootstrapContextFactory.new()
	context_factory.fail_once_slot = 0
	context_factory.party_sink = _parties
	var coordinator := _coordinator(store, root, _assignment_map(joined), {
		"checkout_service": checkout,
		"context_factory": Callable(context_factory, "create"),
	}) as LocalRunSetupCoordinator
	var before_begin := {
		profiles[0].profile_id: _profile_artifact_bytes(paths[profiles[0].profile_id]),
		profiles[1].profile_id: _profile_artifact_bytes(paths[profiles[1].profile_id]),
	}
	TestAssertions.equal(coordinator.begin(joined), PackedStringArray(), "cancellation fixture begins without checkout", failures)
	TestAssertions.truthy(coordinator.cancel(), "pre-checkout cancellation returns setup to editable state", failures)
	for profile: ProfileState in profiles:
		TestAssertions.equal(_profile_artifact_bytes(paths[profile.profile_id]), before_begin[profile.profile_id], "begin/cancel before checkout writes no %s artifact" % profile.profile_id, failures)

	TestAssertions.equal(coordinator.begin(joined), PackedStringArray(), "cancelled setup can begin again", failures)
	TestAssertions.equal(coordinator.ready_contexts(), [], "injected context failure occurs after the first durable checkout", failures)
	TestAssertions.equal(int(checkout.calls_by_profile.get(profiles[0].profile_id, 0)), 1, "first profile checkout commits once before failure", failures)
	TestAssertions.equal(int(checkout.calls_by_profile.get(profiles[1].profile_id, 0)), 0, "later profile remains unattempted before cancellation", failures)
	var committed_artifacts: Dictionary = {}
	for profile: ProfileState in profiles:
		committed_artifacts[profile.profile_id] = _profile_artifact_bytes(paths[profile.profile_id])
	TestAssertions.truthy(coordinator.cancel(), "post-checkout cancellation follows the explicit no-rollback contract", failures)
	TestAssertions.equal(coordinator.run_context_registry(), null, "post-checkout cancellation publishes no registry", failures)
	for profile: ProfileState in profiles:
		TestAssertions.equal(_profile_artifact_bytes(paths[profile.profile_id]), committed_artifacts[profile.profile_id], "post-checkout cancellation performs no rollback, forfeit, or write for %s" % profile.profile_id, failures)
	var committed := store.load_profile(profiles[0].profile_id, root).profile
	TestAssertions.truthy(not committed.resumable_run.is_empty(), "post-checkout cancellation retains the committed resumable run", failures)
	TestAssertions.equal(_operation_count(committed, "run_loadout_checkout"), 1, "post-checkout cancellation retains one checkout journal entry", failures)
	TestAssertions.equal(_operation_count(committed, "run_loadout_forfeit"), 0, "post-checkout cancellation never forfeits checked-out gear", failures)
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
		TestAssertions.equal(contexts[3].equipment_for(1).item_id_at(9), "item-%s" % profiles[0].profile_id, "Alpha retained bring-in gear populates only Alpha run equipment", failures)
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
	TestAssertions.equal(_profile_item_ids(saved_alpha), ["stash-profile-local-alpha-000"], "Alpha checked-out gear leaves persistent profile ownership", failures)
	TestAssertions.equal(_profile_item_ids(saved_beta), [], "Beta destroys only its own confirmed overflow item", failures)
	TestAssertions.equal(_profile_item_ids(saved_gamma), ["item-profile-local-gamma", "stash-profile-local-gamma-000", "stash-profile-local-gamma-001"], "Gamma moves but preserves its exact item ids", failures)
	TestAssertions.equal(_profile_item_ids(saved_delta), ["item-profile-local-delta", "stash-profile-local-delta-000", "stash-profile-local-delta-001", "stash-profile-local-delta-002"], "Delta moves but preserves its exact item ids", failures)
	for saved: ProfileState in [saved_alpha, saved_beta, saved_gamma, saved_delta]:
		TestAssertions.truthy(not saved.resumable_run.is_empty(), "%s owns an exact committed resumable bootstrap" % saved.profile_id, failures)
		TestAssertions.equal(_operation_count(saved, "run_loadout_checkout"), 1, "%s has exactly one checkout journal entry" % saved.profile_id, failures)
	TestAssertions.equal([saved_alpha.stash_tabs.size(), saved_beta.stash_tabs.size(), saved_gamma.stash_tabs.size(), saved_delta.stash_tabs.size()], [1, 0, 2, 3], "four profiles retain different stash capacities", failures)
	TestAssertions.equal([_stash_occupancy(saved_alpha), _stash_occupancy(saved_beta), _stash_occupancy(saved_gamma), _stash_occupancy(saved_delta)], [1, 0, 3, 4], "four profiles retain independent distinct stash occupancy after their own transitions", failures)
	TestAssertions.equal([saved_alpha.gold, saved_beta.gold, saved_gamma.gold, saved_delta.gold], [101, 202, 303, 404], "all four gold balances remain isolated", failures)
	TestAssertions.equal([saved_alpha.extraction_capacity, saved_beta.extraction_capacity, saved_gamma.extraction_capacity, saved_delta.extraction_capacity], [1, 0, 2, 3], "all four extraction capacities remain isolated", failures)
	TestAssertions.equal([saved_alpha.permanent_feature_unlocks, saved_beta.permanent_feature_unlocks, saved_gamma.permanent_feature_unlocks, saved_delta.permanent_feature_unlocks], [profiles[0].permanent_feature_unlocks, profiles[1].permanent_feature_unlocks, profiles[2].permanent_feature_unlocks, profiles[3].permanent_feature_unlocks], "all four unlock sets remain isolated", failures)
	ProfileTestSupport.remove_tree(root)

func _coordinator(store: ProfileStore, root: String, assignments: Dictionary, overrides: Dictionary = {}) -> Object:
	var context_factory := BootstrapContextFactory.new()
	context_factory.party_sink = _parties
	_context_factories.append(context_factory)
	var dependencies := {
		"profile_store": store,
		"profile_root": root,
		"assignment_guard": func(participant: Object) -> bool:
			var current := assignments.get(String(participant.get("profile_id")), {}) as Dictionary
			return (
				int(current.get("device_id", -999)) == int(participant.get("device_id"))
				and int(current.get("player_slot", -999)) == int(participant.get("player_slot"))
				and StringName(current.get("selected_class_id", "")) == participant.get("selected_class_id")
			),
		"checkout_service": RunLoadoutCheckoutService.new(ProfileMutationService.new(store)),
		"checkout_request_factory": Callable(self, "_request_for_participant"),
		"context_factory": Callable(context_factory, "create"),
	}
	for key: Variant in overrides:
		dependencies[key] = overrides[key]
	return COORDINATOR_SCRIPT.new(dependencies) as Object


func _request_for_participant(participant: LocalRunSetupParticipant, profile: ProfileState) -> RunLoadoutCheckoutRequest:
	if participant == null or profile == null:
		return null
	var slot := participant.player_slot
	return RunLoadoutCheckoutRequest.create(
		"local-checkout-%s" % profile.profile_id,
		profile.profile_id,
		StringName("local-run-%s" % profile.profile_id),
		6100 + slot,
		StringName("local-player-%02d" % slot),
		1,
		participant.selected_class_id,
		"bring_in_gear" in profile.permanent_feature_unlocks,
	)

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


func _expected_stash_item_ids(profile_id: String, stash_count: int) -> Array[String]:
	var result: Array[String] = []
	for index: int in stash_count:
		result.append("stash-%s-%03d" % [profile_id, index])
	return result


func _operation_count(profile: ProfileState, operation: String) -> int:
	var count := 0
	for entry: Variant in profile.applied_transactions.values():
		if entry is Dictionary and String((entry as Dictionary).get("operation", "")) == operation:
			count += 1
	return count


func _canonical_resumable(document: Dictionary) -> Dictionary:
	var bootstrap := ResumableRunItemCodec.decode(document, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	return ResumableRunItemCodec.encode(bootstrap) if bootstrap != null else {}

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
