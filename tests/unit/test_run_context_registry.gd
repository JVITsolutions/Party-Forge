extends RefCounted

var _parties: Array[PartyManager] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	_assert_registration_contract(failures)
	_assert_party_ownership_contract(failures)
	_assert_item_ownership_registration_contract(failures)
	_assert_unassigned_and_sorted_contract(failures)
	_assert_device_reassignment_contract(failures)
	_assert_join_policy(failures)
	_assert_local_setup_registry_seam(failures)
	for party: PartyManager in _parties:
		party.free()
	_parties.clear()
	return failures

func _assert_registration_contract(failures: Array[String]) -> void:
	var registry := RunContextRegistry.new()
	TestAssertions.equal(registry.register_context(null).code, RunContextRegistrationResult.Code.INVALID_CONTEXT, "null context is invalid", failures)
	TestAssertions.equal(registry.register_context(PlayerRunContext.new()).code, RunContextRegistrationResult.Code.INVALID_CONTEXT, "unconfigured context is invalid", failures)
	var alpha := _context(&"player_alpha", 0, "profile-alpha")
	TestAssertions.equal(registry.register_context(alpha, 0).code, RunContextRegistrationResult.Code.OK, "first context registers", failures)
	TestAssertions.equal(registry.register_context(alpha, 0).code, RunContextRegistrationResult.Code.DUPLICATE_RUN_PLAYER, "run player is unique", failures)
	TestAssertions.equal(registry.register_context(_context(&"player_beta", 1, "profile-alpha"), 1).code, RunContextRegistrationResult.Code.DUPLICATE_PROFILE, "profile is unique", failures)
	TestAssertions.equal(registry.register_context(_context(&"player_beta", 0, "profile-beta"), 1).code, RunContextRegistrationResult.Code.DUPLICATE_SLOT, "slot is unique", failures)
	TestAssertions.equal(registry.register_context(_context(&"player_beta", 1, "profile-beta"), 0).code, RunContextRegistrationResult.Code.DUPLICATE_DEVICE, "assigned device is unique", failures)
	TestAssertions.equal(registry.all_contexts().size(), 1, "rejections do not partially register", failures)
	registry.lock_arena_roster()
	TestAssertions.equal(registry.register_context(alpha, 0).code, RunContextRegistrationResult.Code.ARENA_RUN_LOCKED, "Arena lock has rejection priority", failures)
	TestAssertions.equal(registry.register_context(_context(&"player_beta", 1, "profile-beta"), 1).code, RunContextRegistrationResult.Code.ARENA_RUN_LOCKED, "Arena roster rejects late joins", failures)
	registry.clear()
	TestAssertions.equal(registry.all_contexts().size(), 0, "clear releases registrations", failures)
	TestAssertions.truthy(not registry.is_arena_roster_locked(), "clear releases Arena roster lock", failures)

func _assert_party_ownership_contract(failures: Array[String]) -> void:
	var registry := RunContextRegistry.new()
	var shared_party := _party()
	var alpha := _context_for_party(&"party_owner_alpha", 0, "profile-party-alpha", shared_party)
	var alias := _context_for_party(&"party_owner_beta", 1, "profile-party-beta", shared_party)
	TestAssertions.truthy(registry.register_context(alpha, 7).ok(), "first party owner registers", failures)
	var alias_result := registry.register_context(alias, 8)
	TestAssertions.equal(
		RunContextRegistrationResult.Code.keys()[alias_result.code],
		"DUPLICATE_PARTY",
		"one mutable party cannot be shared by two registered contexts",
		failures,
	)
	TestAssertions.equal(
		alias_result.message,
		"PARTY_FORGE_RUN_CONTEXT_ERROR code=DUPLICATE_PARTY reason=party already registered",
		"duplicate party rejection is stable and grep-friendly",
		failures,
	)
	TestAssertions.equal(registry.all_contexts().size(), 1, "duplicate party rejection does not append a context", failures)
	TestAssertions.equal(registry.context_for(&"party_owner_beta"), null, "duplicate party rejection does not index run player", failures)
	TestAssertions.equal(registry.device_for(&"party_owner_beta"), -1, "duplicate party rejection does not index device", failures)

	var replacement := _context(&"party_owner_beta", 1, "profile-party-beta")
	TestAssertions.truthy(registry.register_context(replacement, 8).ok(), "same identity and device can retry with an unowned party", failures)
	TestAssertions.equal(registry.all_contexts().size(), 2, "successful retry proves all rejected indexes stayed unchanged", failures)
	TestAssertions.truthy(registry.context_for(&"party_owner_alpha") == alpha, "duplicate party rejection preserves original lookup", failures)

func _assert_item_ownership_registration_contract(failures: Array[String]) -> void:
	var registry := RunContextRegistry.new()
	var alpha := _context(&"item_owner_alpha", 0, "profile-item-alpha")
	var beta := _context(&"item_owner_beta", 1, "profile-item-beta")
	TestAssertions.truthy(alpha.has_method(&"item_state"), "registered contexts expose run item ownership", failures)
	TestAssertions.truthy(alpha.has_method(&"run_inventory"), "registered contexts expose fixed run inventories", failures)
	if not alpha.has_method(&"item_state") or not alpha.has_method(&"run_inventory"):
		return
	TestAssertions.truthy(registry.register_context(alpha, 10).ok(), "first item-owning context registers", failures)
	TestAssertions.truthy(registry.register_context(beta, 11).ok(), "second item-owning context registers", failures)
	var alpha_state := alpha.call(&"item_state") as ItemOwnershipState
	var beta_state := beta.call(&"item_state") as ItemOwnershipState
	TestAssertions.equal(alpha_state.owner_id, "item_owner_alpha", "first registered context keeps its item owner", failures)
	TestAssertions.equal(beta_state.owner_id, "item_owner_beta", "second registered context keeps its item owner", failures)
	alpha_state.owner_id = "escaped-registry-owner"
	var alpha_inventory := alpha.call(&"run_inventory") as ItemSlotContainer
	alpha_inventory.capacity = 40
	TestAssertions.equal((registry.context_for(&"item_owner_alpha").call(&"item_state") as ItemOwnershipState).owner_id, "item_owner_alpha", "registry lookup cannot observe an escaped item-state mutation", failures)
	TestAssertions.equal((registry.context_for(&"item_owner_alpha").call(&"run_inventory") as ItemSlotContainer).capacity, 0, "registry lookup retains the configured zero-capacity inventory", failures)
	TestAssertions.equal((registry.context_for(&"item_owner_beta").call(&"run_inventory") as ItemSlotContainer).capacity, 0, "second registered context remains isolated", failures)

func _assert_unassigned_and_sorted_contract(failures: Array[String]) -> void:
	var registry := RunContextRegistry.new()
	var late_slot := _context(&"player_late", 4, "profile-late")
	var early_slot := _context(&"player_early", 1, "profile-early")
	TestAssertions.equal(registry.register_context(late_slot).code, RunContextRegistrationResult.Code.OK, "first unassigned context registers", failures)
	TestAssertions.equal(registry.register_context(early_slot, -1).code, RunContextRegistrationResult.Code.OK, "unassigned sentinel may repeat", failures)
	TestAssertions.equal(registry.device_for(&"player_late"), -1, "omitted device remains unassigned", failures)
	TestAssertions.equal(registry.device_for(&"player_early"), -1, "explicit negative device remains unassigned", failures)
	var sorted: Array[PlayerRunContext] = registry.all_contexts()
	TestAssertions.equal(sorted.size(), 2, "both unassigned contexts register", failures)
	TestAssertions.truthy(sorted[0] == early_slot, "contexts sort by ascending slot", failures)
	TestAssertions.truthy(sorted[1] == late_slot, "registration order does not control sorting", failures)

func _assert_device_reassignment_contract(failures: Array[String]) -> void:
	var registry := RunContextRegistry.new()
	var alpha := _context(&"player_alpha", 0, "profile-alpha")
	var beta := _context(&"player_beta", 1, "profile-beta")
	TestAssertions.equal(registry.register_context(alpha, 0).code, RunContextRegistrationResult.Code.OK, "Alpha registers on device 0", failures)
	TestAssertions.equal(registry.register_context(beta, 1).code, RunContextRegistrationResult.Code.OK, "Beta registers on device 1", failures)
	TestAssertions.equal(registry.reassign_device(&"player_alpha", 2).code, RunContextRegistrationResult.Code.OK, "Alpha reassigns to device 2", failures)
	TestAssertions.truthy(registry.context_for(&"player_alpha") == alpha, "reassignment preserves identical context", failures)
	TestAssertions.equal(registry.device_for(&"player_alpha"), 2, "device 2 reports Alpha", failures)
	TestAssertions.equal(registry.register_context(_context(&"player_gamma", 2, "profile-gamma"), 0).code, RunContextRegistrationResult.Code.OK, "old device becomes free", failures)
	TestAssertions.equal(registry.reassign_device(&"player_alpha", 1).code, RunContextRegistrationResult.Code.DUPLICATE_DEVICE, "assigned device cannot be stolen", failures)
	TestAssertions.equal(registry.device_for(&"player_alpha"), 2, "failed reassignment preserves Alpha device", failures)
	TestAssertions.equal(registry.device_for(&"player_beta"), 1, "failed reassignment preserves Beta device", failures)
	registry.lock_arena_roster()
	var current_result := registry.reassign_device(&"player_alpha", 2)
	TestAssertions.equal(current_result.code, RunContextRegistrationResult.Code.ARENA_RUN_LOCKED, "Arena lock rejects reassignment to the current device", failures)
	TestAssertions.equal(current_result.message, "PARTY_FORGE_RUN_CONTEXT_ERROR code=ARENA_RUN_LOCKED reason=Arena roster is locked", "locked current-device rejection is stable", failures)
	var collision_result := registry.reassign_device(&"player_alpha", 1)
	TestAssertions.equal(collision_result.code, RunContextRegistrationResult.Code.ARENA_RUN_LOCKED, "Arena lock has priority over a collision destination", failures)
	TestAssertions.equal(collision_result.message, "PARTY_FORGE_RUN_CONTEXT_ERROR code=ARENA_RUN_LOCKED reason=Arena roster is locked", "locked collision rejection is stable", failures)
	TestAssertions.equal(registry.device_for(&"player_alpha"), 2, "locked reassignments preserve Alpha device", failures)
	TestAssertions.equal(registry.device_for(&"player_beta"), 1, "locked reassignments preserve Beta device", failures)

func _assert_join_policy(failures: Array[String]) -> void:
	TestAssertions.truthy(RunJoinPolicy.can_accept(&"arena", false, false), "Arena accepts while roster is unlocked", failures)
	TestAssertions.truthy(not RunJoinPolicy.can_accept(&"arena", true, true), "Arena rejects while roster is locked", failures)
	TestAssertions.truthy(RunJoinPolicy.can_accept(&"adventure", true, true), "Adventure accepts at safe checkpoint", failures)
	TestAssertions.truthy(not RunJoinPolicy.can_accept(&"adventure", false, false), "Adventure rejects away from safe checkpoint", failures)
	TestAssertions.truthy(not RunJoinPolicy.can_accept(&"unknown", false, true), "unknown mode rejects", failures)

func _assert_local_setup_registry_seam(failures: Array[String]) -> void:
	var coordinator := LocalRunSetupCoordinator.new()
	TestAssertions.truthy(coordinator.has_method(&"ready_contexts"), "local setup exposes one final context handoff", failures)
	TestAssertions.truthy(coordinator.has_method(&"run_context_registry"), "local setup exposes the existing registry contract", failures)
	var source := FileAccess.get_file_as_string("res://scripts/run/local_run_setup_coordinator.gd")
	TestAssertions.truthy(source.contains("RunContextRegistry.new()"), "local setup validates final ownership with RunContextRegistry", failures)
	TestAssertions.truthy(source.contains("register_context(contexts[index], sorted[index].device_id)"), "local setup registers exact per-player device ownership only after every context validates", failures)
	TestAssertions.truthy(source.contains("lock_arena_roster()"), "local setup locks Arena only after every joined participant is ready", failures)
	TestAssertions.truthy(not source.contains("RunJoinPolicy.ADVENTURE"), "local setup does not add Adventure drop-in behavior", failures)

func _context(run_id: StringName, slot: int, profile_id: String) -> PlayerRunContext:
	return _context_for_party(run_id, slot, profile_id, _party())

func _party() -> PartyManager:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	return party

func _context_for_party(run_id: StringName, slot: int, profile_id: String, party: PartyManager) -> PlayerRunContext:
	var context := PlayerRunContext.new()
	var errors := context.configure(run_id, slot, ProfileState.new_profile(profile_id, "Registry Fixture", 1000), 1337, party, 100)
	assert(errors.is_empty())
	return context
