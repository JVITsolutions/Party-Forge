extends RefCounted

var _parties: Array[PartyManager] = []

class CoordinatorRejectingPartyManager extends PartyManager:
	func bind_member_source_refresh_coordinator(_coordinator: Callable) -> bool:
		return false

func run() -> Array[String]:
	var failures: Array[String] = []
	_assert_registration_contract(failures)
	_assert_party_ownership_contract(failures)
	_assert_bind_failure_is_non_mutating(failures)
	_assert_reinitialize_releases_stale_coordinator(failures)
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
	var alpha_fixture := _configure_stout_context(&"party_owner_alpha", 0, "profile-party-alpha", 7701, shared_party)
	var alpha := alpha_fixture["context"] as PlayerRunContext
	var item := alpha_fixture["item"] as ItemInstance
	TestAssertions.equal(alpha_fixture["errors"], PackedStringArray(), "first party owner configures with equipped attributes", failures)
	TestAssertions.truthy(registry.register_context(alpha, 7).ok(), "first party owner registers", failures)
	var action_tags := DamageResolver.action_tags_for(shared_party.member_by_id(1).class_definition.primary_attack)
	var sources_before := _source_documents(shared_party.member_by_id(1))
	var activation_before := _activation_document(alpha.equipment_activation(1), item.instance_id)
	var base_before := shared_party.stats_for(1)
	var action_before := shared_party.stats_for_action(1, action_tags)
	var revision_before := shared_party.stat_revision()
	var changed: Array[int] = []
	shared_party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	var alias_fixture := _configure_context(&"party_owner_beta", 1, "profile-party-beta", 7702, shared_party)
	var alias := alias_fixture["context"] as PlayerRunContext
	TestAssertions.equal(alias_fixture["errors"], PackedStringArray([
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=source_refresh reason=party coordinator unavailable",
	]), "duplicate context cannot configure against an owned party", failures)
	TestAssertions.equal(_source_documents(shared_party.member_by_id(1)), sources_before, "duplicate configure preserves exact member sources", failures)
	TestAssertions.equal(_activation_document(alpha.equipment_activation(1), item.instance_id), activation_before, "duplicate configure preserves owner activation", failures)
	TestAssertions.equal(shared_party.stat_revision(), revision_before, "duplicate configure preserves stat revision", failures)
	TestAssertions.equal(changed, [], "duplicate configure emits no stat signal", failures)
	TestAssertions.truthy(is_same(shared_party.stats_for(1), base_before), "duplicate configure preserves base cache identity", failures)
	TestAssertions.truthy(is_same(shared_party.stats_for_action(1, action_tags), action_before), "duplicate configure preserves action cache identity", failures)
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

	registry.clear()
	TestAssertions.equal(registry.all_contexts().size(), 0, "clear removes the original party owner", failures)
	var replacement_fixture := _configure_context(&"party_owner_beta", 1, "profile-party-beta", 7703, shared_party)
	var replacement := replacement_fixture["context"] as PlayerRunContext
	TestAssertions.equal(replacement_fixture["errors"], PackedStringArray(), "same PartyManager can bind a replacement after clear", failures)
	TestAssertions.truthy(registry.register_context(replacement, 8).ok(), "replacement becomes the authoritative registered owner", failures)
	TestAssertions.truthy(registry.context_for(&"party_owner_beta") == replacement, "replacement is indexed by exact identity", failures)

	changed.clear()
	var replacement_activation_before := _activation_document(replacement.equipment_activation(1), item.instance_id)
	var replacement_base_before := shared_party.stats_for(1)
	var replacement_action_before := shared_party.stats_for_action(1, action_tags)
	var replacement_revision_before := shared_party.stat_revision()
	var source := StatModifierSource.create(&"registry_replacement_constitution", &"character_growth", "Registry Replacement", 1, [
		StatModifier.create(&"constitution", StatModifier.Operation.FLAT, 1.0, &"registry_replacement_constitution_roll", "Registry Replacement"),
	])
	TestAssertions.truthy(shared_party.replace_member_source(1, source), "replacement owner refreshes a direct non-equipment source", failures)
	TestAssertions.equal(_source_ids(shared_party.member_by_id(1)), PackedStringArray([
		"equipment_member_1",
		"registry_replacement_constitution",
	]), "replacement refresh commits the exact non-equipment and empty-equipment sources", failures)
	TestAssertions.equal(replacement_activation_before, {
		"active": [],
		"disabled": PackedStringArray(),
		"raw_constitution": 0.0,
		"source": _source_document(replacement.equipment_activation(1).source),
	}, "replacement starts with exact empty equipment activation", failures)
	TestAssertions.equal(_activation_document(replacement.equipment_activation(1), item.instance_id), {
		"active": [],
		"disabled": PackedStringArray(),
		"raw_constitution": 1.0,
		"source": _source_document(replacement.equipment_activation(1).source),
	}, "replacement activation refreshes against the new source without stale equipment", failures)
	TestAssertions.near(shared_party.stats_for(1).value(&"max_health"), 263.0, 0.0001, "cleared owner is not invoked after same-party replacement", failures)
	TestAssertions.equal(shared_party.stat_revision(), replacement_revision_before + 1, "replacement refresh advances the revision once", failures)
	TestAssertions.equal(changed, [1], "replacement refresh emits one member-local stat signal", failures)
	TestAssertions.truthy(not is_same(shared_party.stats_for(1), replacement_base_before), "replacement refresh replaces the base cache", failures)
	TestAssertions.truthy(not is_same(shared_party.stats_for_action(1, action_tags), replacement_action_before), "replacement refresh replaces the action cache", failures)
	TestAssertions.equal(_activation_document(alpha.equipment_activation(1), item.instance_id), activation_before, "cleared context retains local state but no longer owns party refresh", failures)

func _assert_bind_failure_is_non_mutating(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := CoordinatorRejectingPartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	_parties.append(party)
	var action_tags := DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack)
	var sources_before := _source_documents(party.member_by_id(1))
	var base_before := party.stats_for(1)
	var action_before := party.stats_for_action(1, action_tags)
	var revision_before := party.stat_revision()
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	var fixture := _configure_context(&"bind_rejected", 0, "profile-bind-rejected", 7801, party)
	var context := fixture["context"] as PlayerRunContext
	TestAssertions.equal(fixture["errors"], PackedStringArray([
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=source_refresh reason=party coordinator unavailable",
	]), "coordinator bind failure is explicit and stable", failures)
	TestAssertions.equal(_source_documents(party.member_by_id(1)), sources_before, "bind failure preserves exact sources", failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "bind failure preserves exact revision", failures)
	TestAssertions.equal(changed, [], "bind failure emits no stat signal", failures)
	TestAssertions.truthy(is_same(party.stats_for(1), base_before), "bind failure preserves base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "bind failure preserves action cache identity", failures)
	TestAssertions.equal(context.equipment_activation(1).error, "PARTY_FORGE_EQUIPMENT_ACTIVATION_ERROR member=1 detail=activation unavailable", "bind failure exposes no partial activation", failures)
	var registration := RunContextRegistry.new().register_context(context)
	TestAssertions.equal(registration.code, RunContextRegistrationResult.Code.INVALID_CONTEXT, "unowned bind failure cannot register", failures)

func _assert_reinitialize_releases_stale_coordinator(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := _party()
	var old_fixture := _configure_stout_context(&"reinitialize_old", 0, "profile-reinitialize-old", 7901, party)
	var old_context := old_fixture["context"] as PlayerRunContext
	var old_item := old_fixture["item"] as ItemInstance
	TestAssertions.equal(old_fixture["errors"], PackedStringArray(), "pre-reinitialize context owns equipped activation", failures)
	TestAssertions.truthy(old_context.equipment_activation(1).is_active(old_item.instance_id), "pre-reinitialize helmet is active", failures)
	var old_registry := RunContextRegistry.new()
	TestAssertions.truthy(old_registry.register_context(old_context).ok(), "pre-reinitialize context registers as owner", failures)
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var replacement_fixture := _configure_context(&"reinitialize_new", 0, "profile-reinitialize-new", 7902, party)
	var replacement := replacement_fixture["context"] as PlayerRunContext
	TestAssertions.equal(replacement_fixture["errors"], PackedStringArray(), "PartyManager reinitialize permits a fresh coordinator", failures)
	old_registry.clear()
	var action_tags := DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack)
	var base_before := party.stats_for(1)
	var action_before := party.stats_for_action(1, action_tags)
	var revision_before := party.stat_revision()
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	var source := StatModifierSource.create(&"reinitialize_constitution", &"character_growth", "Reinitialize", 1, [
		StatModifier.create(&"constitution", StatModifier.Operation.FLAT, 1.0, &"reinitialize_constitution_roll", "Reinitialize"),
	])
	TestAssertions.truthy(party.replace_member_source(1, source), "late clear exact-unbinds the stale owner without releasing the fresh owner", failures)
	TestAssertions.equal(_source_ids(party.member_by_id(1)), PackedStringArray([
		"equipment_member_1",
		"reinitialize_constitution",
	]), "post-reinitialize refresh commits exact fresh-context sources", failures)
	TestAssertions.equal(replacement.equipment_activation(1).active_item_ids, [], "post-reinitialize activation contains no stale item", failures)
	TestAssertions.near(replacement.equipment_activation(1).raw_attributes.value(&"constitution"), 1.0, 0.0001, "post-reinitialize activation sees the direct source", failures)
	TestAssertions.near(party.stats_for(1).value(&"max_health"), 263.0, 0.0001, "post-reinitialize stats exclude stale old-context equipment", failures)
	TestAssertions.equal(party.stat_revision(), revision_before + 1, "post-reinitialize refresh advances one revision", failures)
	TestAssertions.equal(changed, [1], "post-reinitialize refresh emits one signal", failures)
	TestAssertions.truthy(not is_same(party.stats_for(1), base_before), "post-reinitialize refresh replaces base cache", failures)
	TestAssertions.truthy(not is_same(party.stats_for_action(1, action_tags), action_before), "post-reinitialize refresh replaces action cache", failures)

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
	var configured := _configure_context(run_id, slot, profile_id, 1337, party)
	assert((configured["errors"] as PackedStringArray).is_empty())
	return configured["context"] as PlayerRunContext

func _configure_context(run_id: StringName, slot: int, profile_id: String, seed: int, party: PartyManager) -> Dictionary:
	var context := PlayerRunContext.new()
	var errors := context.configure(run_id, slot, ProfileState.new_profile(profile_id, "Registry Fixture", 1000), seed, party, 100)
	return {"context": context, "errors": errors}

func _configure_stout_context(run_id: StringName, slot: int, profile_id: String, seed: int, party: PartyManager) -> Dictionary:
	var owner := String(run_id)
	var item_document := {
		"schema_version": ItemInstance.SCHEMA_VERSION,
		"instance_id": "%s-stout-helmet" % owner,
		"base_definition_id": "forge_vanguard_helmet",
		"item_level": 1,
		"rarity_id": "common",
		"affixes": [{
			"definition_id": "stout",
			"affix_kind": "prefix",
			"tier": 1,
			"rolls": [{
				"stat_id": "constitution",
				"operation": StatModifier.Operation.FLAT,
				"value": 3.0,
				"required_tags": [],
			}],
		}],
		"origin": {"issuer_namespace": "run:%s:%d:%s" % [profile_id, seed, owner], "seed": seed, "sequence": 0, "source": "registry_lifecycle"},
	}
	var decoded := ItemInstanceCodec.decode(item_document, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	assert(decoded.ok())
	var item := decoded.item
	var state := ItemOwnershipState.create(owner, ItemRegistry.new([item]), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, owner, 5),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, owner, EquipmentSlotIndex.capacity(), {
			EquipmentSlotIndex.index_for(&"helmet"): item.instance_id,
		}),
	])
	var bootstrap := RunItemBootstrap.create(StringName("%s-run" % owner), seed, run_id, 1, state)
	var profile := ProfileState.new_profile(profile_id, "Registry Equipped Fixture", 1000)
	profile.inventory_columns = 1
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	var errors := context.configure(run_id, slot, profile, seed, party, 100, bootstrap)
	return {"context": context, "errors": errors, "item": item}

func _activation_document(activation: EquipmentActivationResult, item_id: String) -> Dictionary:
	return {
		"active": activation.active_item_ids,
		"disabled": activation.disabled_reasons(item_id),
		"raw_constitution": activation.raw_attributes.value(&"constitution") if activation.raw_attributes != null else -1.0,
		"source": _source_document(activation.source),
	}

func _source_ids(member: PartyMemberState) -> PackedStringArray:
	var ids := PackedStringArray()
	for source: StatModifierSource in member.modifier_sources:
		ids.append(String(source.id))
	return ids

func _source_documents(member: PartyMemberState) -> String:
	var documents: Array[Dictionary] = []
	for source: StatModifierSource in member.modifier_sources:
		documents.append(_source_document(source))
	return JSON.stringify(documents)

func _source_document(source: StatModifierSource) -> Dictionary:
	if source == null:
		return {}
	var modifiers: Array[Dictionary] = []
	for modifier: StatModifier in source.modifiers:
		modifiers.append({
			"stat_id": String(modifier.stat_id),
			"operation": modifier.operation,
			"value": modifier.value,
			"source_id": String(modifier.source_id),
			"source_label": modifier.source_label,
			"required_tags": modifier.required_tags,
			"excluded_tags": modifier.excluded_tags,
			"required_capability_tags": modifier.required_capability_tags,
			"excluded_capability_tags": modifier.excluded_capability_tags,
			"required_action_tags": modifier.required_action_tags,
			"excluded_action_tags": modifier.excluded_action_tags,
		})
	return {
		"id": String(source.id),
		"source_type": String(source.source_type),
		"label": source.label,
		"owner_member_id": source.owner_member_id,
		"modifiers": modifiers,
	}
