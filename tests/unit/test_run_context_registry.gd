extends RefCounted

var _parties: Array[PartyManager] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	_assert_registration_contract(failures)
	_assert_unassigned_and_sorted_contract(failures)
	_assert_device_reassignment_contract(failures)
	_assert_join_policy(failures)
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

func _assert_join_policy(failures: Array[String]) -> void:
	TestAssertions.truthy(RunJoinPolicy.can_accept(&"arena", false, false), "Arena accepts while roster is unlocked", failures)
	TestAssertions.truthy(not RunJoinPolicy.can_accept(&"arena", true, true), "Arena rejects while roster is locked", failures)
	TestAssertions.truthy(RunJoinPolicy.can_accept(&"adventure", true, true), "Adventure accepts at safe checkpoint", failures)
	TestAssertions.truthy(not RunJoinPolicy.can_accept(&"adventure", false, false), "Adventure rejects away from safe checkpoint", failures)
	TestAssertions.truthy(not RunJoinPolicy.can_accept(&"unknown", false, true), "unknown mode rejects", failures)

func _context(run_id: StringName, slot: int, profile_id: String) -> PlayerRunContext:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var context := PlayerRunContext.new()
	var errors := context.configure(run_id, slot, ProfileState.new_profile(profile_id, "Registry Fixture", 1000), 1337, party, 100)
	assert(errors.is_empty())
	return context
