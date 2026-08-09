extends RefCounted

class RejectingPartyManager extends PartyManager:
	var reject_growth_source := false

	func replace_member_source(member_id: int, source: StatModifierSource) -> bool:
		if reject_growth_source:
			return false
		return super.replace_member_source(member_id, source)

	func replace_member_equipment_source_atomically(
		member_id: int,
		equipment_source: StatModifierSource,
		authority: RefCounted = null,
	) -> bool:
		if reject_growth_source:
			return false
		return super.replace_member_equipment_source_atomically(member_id, equipment_source, authority)

class SelectiveEquipmentRejectingPartyManager extends PartyManager:
	var rejected_member_id := 0

	func replace_member_source(member_id: int, source: StatModifierSource) -> bool:
		if source != null and source.source_type == &"equipment" and member_id == rejected_member_id:
			return false
		return super.replace_member_source(member_id, source)

	func _commit_member_source_without_invalidation(member_id: int, source: StatModifierSource) -> bool:
		if source != null and source.source_type == &"equipment" and member_id == rejected_member_id:
			return false
		var member := member_by_id(member_id)
		if member == null or source == null:
			return false
		member._replace_modifier_source(source)
		return true

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_configuration_validation_and_copy_ownership(failures)
	_test_initial_member_equipment_is_owned_and_defensive(failures)
	_test_checked_out_item_bootstrap_identity_and_retry(failures)
	_test_configuration_rejects_invalid_member_growth_atomically(failures)
	_test_atomic_progression_and_leader_queue(failures)
	_test_future_recruits_initialize_once(failures)
	_test_actor_binding_availability_and_position(failures)
	_test_atomic_equipment_commit_and_member_local_cache(failures)
	_test_direct_equipment_source_bypasses_reject_atomically(failures)
	_test_equipment_authority_rejections_preserve_runtime(failures)
	_test_equipment_source_rejection_rolls_back(failures)
	_test_configuration_source_batch_is_atomic_and_observable(failures)
	_test_resume_rejects_structurally_invalid_loadouts(failures)
	_test_resume_reconstructs_equipment_activation(failures)
	return failures

func _test_atomic_equipment_commit_and_member_local_cache(failures: Array[String]) -> void:
	var fixture := _configured_fixture(PartyManager.new(), 1)
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as PartyManager
	var has_preview := context.has_method(&"preview_equipment_assignment")
	var has_activation := context.has_method(&"equipment_activation")
	TestAssertions.truthy(has_preview, "run context exposes pure equipment transition preview", failures)
	TestAssertions.truthy(has_activation, "run context exposes resolved equipment activation", failures)
	if not has_preview or not has_activation:
		party.free()
		return
	var item := _issue_stout_helmet(context, 0, 0, failures)
	if item == null:
		party.free()
		return
	var item_before := JSON.stringify(item.to_dictionary())
	var state_before := JSON.stringify(context.item_state().to_dictionary())
	var member_one_before := party.stats_for(1)
	var member_two_before := party.stats_for(2)
	var action_tags: Array[StringName] = [&"ranged", &"physical"]
	var member_two_action_before := party.stats_for_action(2, action_tags)
	var events: Array[int] = []
	var observations: Array[Dictionary] = []
	party.stats_changed.connect(func(member_id: int) -> void:
		events.append(member_id)
		if member_id == 1:
			var activation: EquipmentActivationResult = context.call(&"equipment_activation", 1)
			observations.append({
				"active": activation != null and activation.is_active(item.instance_id),
				"equipped": context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"helmet")),
				"maximum": party.stats_for(1).value(&"max_health"),
				"source_present": party.member_by_id(1).modifier_sources.any(func(source: StatModifierSource) -> bool: return source.id == &"equipment_member_1"),
			})
	)

	var preview: Variant = context.call(
		&"preview_equipment_assignment", 1, item.instance_id, &"helmet",
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(preview != null and preview.ok(), "run-context equipment preview succeeds", failures)
	if preview != null and preview.ok():
		TestAssertions.near(preview.resolution().final_stats.value(&"max_health"), member_one_before.value(&"max_health") + 9.0, 0.0001, "preview resolves constitution-derived health", failures)
	TestAssertions.equal(JSON.stringify(context.item_state().to_dictionary()), state_before, "run-context preview preserves ownership", failures)
	TestAssertions.equal(party.stats_for(1), member_one_before, "run-context preview preserves member cache", failures)
	TestAssertions.equal(events, [], "run-context preview emits no stat signal", failures)

	var equipped := context.assign_equipment(1, item.instance_id, &"helmet", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(equipped.ok(), "run-context equipment commit succeeds", failures)
	TestAssertions.equal(events, [1], "equipment commit emits one member-local stat signal", failures)
	TestAssertions.equal(observations.size(), 1, "synchronous observer runs exactly once", failures)
	if observations.size() == 1:
		TestAssertions.truthy(bool(observations[0]["active"]), "observer sees committed activation", failures)
		TestAssertions.equal(observations[0]["equipped"], item.instance_id, "observer sees committed ownership", failures)
		TestAssertions.truthy(bool(observations[0]["source_present"]), "observer sees committed equipment source", failures)
		TestAssertions.near(float(observations[0]["maximum"]), member_one_before.value(&"max_health") + 9.0, 0.0001, "observer sees final equipment stats", failures)
	TestAssertions.equal(party.stats_for(2), member_two_before, "member one commit preserves member two base cache identity", failures)
	TestAssertions.equal(party.stats_for_action(2, action_tags), member_two_action_before, "member one commit preserves member two action cache identity", failures)
	TestAssertions.equal(JSON.stringify(item.to_dictionary()), item_before, "equipment commit leaves caller item immutable", failures)

	var unequipped := context.assign_equipment(1, item.instance_id, &"", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(unequipped.ok(), "run-context unequip commit succeeds", failures)
	TestAssertions.equal(events, [1, 1], "unequip emits one additional member-local stat signal", failures)
	TestAssertions.near(party.stats_for(1).value(&"max_health"), member_one_before.value(&"max_health"), 0.0001, "unequip removes equipment-derived health", failures)
	TestAssertions.equal(party.stats_for(2), member_two_before, "unequip still preserves member two base cache identity", failures)
	TestAssertions.equal(party.stats_for_action(2, action_tags), member_two_action_before, "unequip still preserves member two action cache identity", failures)
	party.free()

func _test_direct_equipment_source_bypasses_reject_atomically(failures: Array[String]) -> void:
	_assert_direct_equipment_source_rejection(&"add_member_source", true, failures)
	_assert_direct_equipment_source_rejection(&"replace_member_source", false, failures)

func _assert_direct_equipment_source_rejection(
	method_name: StringName,
	duplicate_append: bool,
	failures: Array[String],
) -> void:
	var fixture := _configured_fixture(PartyManager.new(), 1)
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as PartyManager
	var item := _issue_stout_helmet(context, 0, 0, failures)
	if item == null:
		party.free()
		return
	var actor := Node3D.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(137.0, true, 8.0, 0.5)
	health.apply_damage(19.0)
	actor.add_child(health)
	TestAssertions.truthy(context.bind_actor(1, actor), "%s fixture attaches a runtime actor" % method_name, failures)
	var current_activation := context.equipment_activation(1)
	var candidate := current_activation.source.duplicate(true) as StatModifierSource
	if not duplicate_append:
		candidate = StatModifierSource.create(&"equipment_member_1", &"equipment", "Forbidden Equipment", 1, [
			StatModifier.create(&"strength", StatModifier.Operation.FLAT, 19.0, &"task10m_forbidden_strength", "Forbidden Equipment"),
		])
	var sources_before := _source_documents(party.member_by_id(1))
	var activation_before := _activation_document(current_activation, [item.instance_id])
	var state_before := JSON.stringify(context.item_state().to_dictionary())
	var item_before := JSON.stringify(item.to_dictionary())
	var revision_before := party.stat_revision()
	var base_before := party.stats_for(1)
	var action_tags: Array[StringName] = [&"melee", &"physical"]
	var action_before := party.stats_for_action(1, action_tags)
	var maximum_before := health.max_health
	var current_before := health.current_health
	var events: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))

	TestAssertions.truthy(
		not bool(party.call(method_name, 1, candidate)),
		"configured runtime rejects direct equipment %s" % method_name,
		failures,
	)
	TestAssertions.equal(_source_documents(party.member_by_id(1)), sources_before, "%s rejection preserves canonical sources" % method_name, failures)
	TestAssertions.equal(_activation_document(context.equipment_activation(1), [item.instance_id]), activation_before, "%s rejection preserves equipment activation" % method_name, failures)
	TestAssertions.equal(JSON.stringify(context.item_state().to_dictionary()), state_before, "%s rejection preserves ownership containers" % method_name, failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "%s rejection preserves stat revision" % method_name, failures)
	TestAssertions.truthy(is_same(party.stats_for(1), base_before), "%s rejection preserves base cache identity" % method_name, failures)
	TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "%s rejection preserves action cache identity" % method_name, failures)
	TestAssertions.equal(events, [], "%s rejection emits no stats_changed signal" % method_name, failures)
	TestAssertions.equal(health.max_health, maximum_before, "%s rejection preserves runtime maximum health" % method_name, failures)
	TestAssertions.equal(health.current_health, current_before, "%s rejection preserves runtime current health" % method_name, failures)
	TestAssertions.equal(JSON.stringify(item.to_dictionary()), item_before, "%s rejection preserves immutable item bytes" % method_name, failures)
	actor.free()
	party.free()

func _activation_document(activation: EquipmentActivationResult, item_ids: Array[String]) -> String:
	var disabled: Dictionary = {}
	for item_id: String in item_ids:
		disabled[item_id] = activation.disabled_reasons(item_id)
	return JSON.stringify({
		"active_item_ids": activation.active_item_ids,
		"disabled_reasons": disabled,
		"source": _source_documents_from_array([activation.source]),
	})

func _source_documents_from_array(sources: Array[StatModifierSource]) -> String:
	var documents: Array[Dictionary] = []
	for source: StatModifierSource in sources:
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
		documents.append({
			"id": String(source.id),
			"source_type": String(source.source_type),
			"label": source.label,
			"owner_member_id": source.owner_member_id,
			"modifiers": modifiers,
		})
	return JSON.stringify(documents)

func _test_equipment_authority_rejections_preserve_runtime(failures: Array[String]) -> void:
	var fixture := _configured_fixture(PartyManager.new(), 1)
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as PartyManager
	var item := _issue_stout_helmet(context, 0, 0, failures)
	if item == null:
		party.free()
		return
	var actor := Node3D.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(149.0, true, 8.0, 0.5)
	health.apply_damage(23.0)
	actor.add_child(health)
	TestAssertions.truthy(context.bind_actor(1, actor), "authority rejection fixture attaches a runtime actor", failures)
	var candidate := context.equipment_activation(1).source
	var action_tags: Array[StringName] = [&"melee", &"physical"]
	var events: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
	var before := _runtime_integrity_snapshot(context, party, health, item, action_tags)
	var cases: Array[Dictionary] = [
		{
			"label": "missing batch authority",
			"accepted": int(party.call(&"replace_member_equipment_sources_atomically", {1: candidate})) == 0,
		},
		{
			"label": "wrong batch authority",
			"accepted": int(party.call(&"replace_member_equipment_sources_atomically", {1: candidate}, RefCounted.new())) == 0,
		},
		{
			"label": "missing member authority",
			"accepted": bool(party.call(&"replace_member_equipment_source_atomically", 1, candidate)),
		},
		{
			"label": "wrong member authority",
			"accepted": bool(party.call(&"replace_member_equipment_source_atomically", 1, candidate, RefCounted.new())),
		},
	]
	for test_case: Dictionary in cases:
		TestAssertions.truthy(not bool(test_case["accepted"]), "%s is rejected" % test_case["label"], failures)
		_assert_runtime_integrity_snapshot(before, context, party, health, item, action_tags, events, String(test_case["label"]), failures)

	var stale_authority: Variant = context.get("_source_refresh_authority")
	context.release_source_refresh_coordinator()
	var replacement := PlayerRunContext.new()
	var replacement_profile := ProfileState.new_profile("profile-task10m-replacement", "Task 10M Replacement", 1000)
	replacement_profile.inventory_columns = 1
	TestAssertions.equal(
		replacement.configure(&"task10m_replacement", 0, replacement_profile, 7441, party, 100),
		PackedStringArray(),
		"replacement context binds after prior authority release",
		failures,
	)
	TestAssertions.truthy(replacement.bind_actor(1, actor), "replacement context attaches the runtime actor", failures)
	events.clear()
	var replacement_candidate := replacement.equipment_activation(1).source
	var replacement_before := _runtime_integrity_snapshot(replacement, party, health, item, action_tags)
	TestAssertions.truthy(
		int(party.call(&"replace_member_equipment_sources_atomically", {1: replacement_candidate}, stale_authority)) != 0,
		"stale batch authority cannot mutate replacement binding",
		failures,
	)
	_assert_runtime_integrity_snapshot(replacement_before, replacement, party, health, item, action_tags, events, "stale batch authority", failures)
	TestAssertions.truthy(
		not bool(party.call(&"replace_member_equipment_source_atomically", 1, replacement_candidate, stale_authority)),
		"stale member authority cannot mutate replacement binding",
		failures,
	)
	_assert_runtime_integrity_snapshot(replacement_before, replacement, party, health, item, action_tags, events, "stale member authority", failures)
	replacement.release_source_refresh_coordinator()
	actor.free()
	party.free()

func _runtime_integrity_snapshot(
	context: PlayerRunContext,
	party: PartyManager,
	health: HealthComponent,
	item: ItemInstance,
	action_tags: Array[StringName],
) -> Dictionary:
	return {
		"sources": _source_documents(party.member_by_id(1)),
		"activation": _activation_document(context.equipment_activation(1), [item.instance_id]),
		"item_state": JSON.stringify(context.item_state().to_dictionary()),
		"item": JSON.stringify(item.to_dictionary()),
		"revision": party.stat_revision(),
		"base": party.stats_for(1),
		"action": party.stats_for_action(1, action_tags),
		"maximum_health": health.max_health,
		"current_health": health.current_health,
	}

func _assert_runtime_integrity_snapshot(
	before: Dictionary,
	context: PlayerRunContext,
	party: PartyManager,
	health: HealthComponent,
	item: ItemInstance,
	action_tags: Array[StringName],
	events: Array[int],
	label: String,
	failures: Array[String],
) -> void:
	TestAssertions.equal(_source_documents(party.member_by_id(1)), before["sources"], "%s preserves canonical sources" % label, failures)
	TestAssertions.equal(_activation_document(context.equipment_activation(1), [item.instance_id]), before["activation"], "%s preserves equipment activation" % label, failures)
	TestAssertions.equal(JSON.stringify(context.item_state().to_dictionary()), before["item_state"], "%s preserves item ownership containers" % label, failures)
	TestAssertions.equal(JSON.stringify(item.to_dictionary()), before["item"], "%s preserves immutable item bytes" % label, failures)
	TestAssertions.equal(party.stat_revision(), before["revision"], "%s preserves stat revision" % label, failures)
	TestAssertions.truthy(is_same(party.stats_for(1), before["base"]), "%s preserves base cache identity" % label, failures)
	TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), before["action"]), "%s preserves action cache identity" % label, failures)
	TestAssertions.equal(events, [], "%s emits no stats_changed signal" % label, failures)
	TestAssertions.equal(health.max_health, before["maximum_health"], "%s preserves runtime maximum health" % label, failures)
	TestAssertions.equal(health.current_health, before["current_health"], "%s preserves runtime current health" % label, failures)

func _test_equipment_source_rejection_rolls_back(failures: Array[String]) -> void:
	var fixture := _configured_fixture(RejectingPartyManager.new(), 1)
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as RejectingPartyManager
	if not context.has_method(&"equipment_activation"):
		party.free()
		return
	var item := _issue_stout_helmet(context, 0, 0, failures)
	if item == null:
		party.free()
		return
	var state_before := JSON.stringify(context.item_state().to_dictionary())
	var activation_before: EquipmentActivationResult = context.call(&"equipment_activation", 1)
	var snapshot_before := party.stats_for(1)
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	party.reject_growth_source = true
	var result := context.assign_equipment(1, item.instance_id, &"helmet", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(not result.ok(), "rejected equipment source fails commit", failures)
	TestAssertions.equal(result.error, "PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR member=1 reason=stat source commit rejected", "source rejection has stable transition diagnostic", failures)
	TestAssertions.equal(JSON.stringify(context.item_state().to_dictionary()), state_before, "source rejection restores exact ownership", failures)
	var activation_after: EquipmentActivationResult = context.call(&"equipment_activation", 1)
	TestAssertions.equal(activation_after.active_item_ids, activation_before.active_item_ids, "source rejection restores prior activation", failures)
	TestAssertions.equal(party.stats_for(1), snapshot_before, "source rejection preserves cached snapshot identity", failures)
	TestAssertions.equal(changed, [], "source rejection emits no misleading stat signal", failures)
	party.free()

func _test_configuration_source_batch_is_atomic_and_observable(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var rejecting_party := SelectiveEquipmentRejectingPartyManager.new()
	rejecting_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	TestAssertions.truthy(rejecting_party.recruit(catalog.class_by_id(&"ranger")), "atomic configure fixture recruits member two", failures)
	var prior_equipment_source := StatModifierSource.create(
		&"equipment_member_1",
		&"equipment",
		"Prior Equipment",
		1,
		[StatModifier.create(&"damage", StatModifier.Operation.FLAT, 7.0, &"prior_equipment", "Prior Equipment")],
	)
	TestAssertions.truthy(rejecting_party.replace_member_source(1, prior_equipment_source), "atomic configure fixture installs a replaceable member-one source", failures)
	var member_one_sources_before := _source_documents(rejecting_party.member_by_id(1))
	var member_two_sources_before := _source_documents(rejecting_party.member_by_id(2))
	var member_one_snapshot_before := rejecting_party.stats_for(1)
	var member_two_snapshot_before := rejecting_party.stats_for(2)
	var action_tags: Array[StringName] = [&"ranged", &"physical"]
	var member_two_action_before := rejecting_party.stats_for_action(2, action_tags)
	var revision_before := rejecting_party.stat_revision()
	var rejected_events: Array[int] = []
	rejecting_party.stats_changed.connect(func(member_id: int) -> void: rejected_events.append(member_id))
	rejecting_party.rejected_member_id = 2
	var rejected_context := PlayerRunContext.new()
	var rejected_errors := rejected_context.configure(
		&"atomic_reject_player",
		0,
		ProfileState.new_profile("profile-atomic-reject", "Atomic Reject", 1000),
		8811,
		rejecting_party,
		100,
	)
	TestAssertions.equal(rejected_errors, PackedStringArray([
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=equipment_activation member=2 reason=stat source commit rejected",
	]), "member-two source rejection identifies the failed atomic commit", failures)
	_assert_context_unconfigured(rejected_context, "member-two source rejection", failures)
	TestAssertions.equal(_source_documents(rejecting_party.member_by_id(1)), member_one_sources_before, "member-two rejection restores member-one source byte-for-byte", failures)
	TestAssertions.equal(_source_documents(rejecting_party.member_by_id(2)), member_two_sources_before, "member-two rejection preserves member-two sources", failures)
	TestAssertions.equal(rejecting_party.stat_revision(), revision_before, "member-two rejection restores the exact stat revision", failures)
	TestAssertions.equal(rejecting_party.stats_for(1), member_one_snapshot_before, "member-two rejection preserves member-one cached snapshot identity", failures)
	TestAssertions.equal(rejecting_party.stats_for(2), member_two_snapshot_before, "member-two rejection preserves member-two cached snapshot identity", failures)
	TestAssertions.equal(rejecting_party.stats_for_action(2, action_tags), member_two_action_before, "member-two rejection preserves unrelated action cache identity", failures)
	TestAssertions.equal(rejected_events, [], "member-two rejection emits no partial stat signal", failures)
	rejecting_party.free()

	var visible_party := PartyManager.new()
	visible_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	TestAssertions.truthy(visible_party.recruit(catalog.class_by_id(&"ranger")), "observable configure fixture recruits member two", failures)
	var visible_context := PlayerRunContext.new()
	var visible_events: Array[int] = []
	var visible_observations: Array[Dictionary] = []
	var visible_revision_before := visible_party.stat_revision()
	visible_party.stats_changed.connect(func(member_id: int) -> void:
		visible_events.append(member_id)
		visible_observations.append({
			"context_party": visible_context.party == visible_party,
			"item_state": visible_context.item_state() != null,
			"member_one_active": visible_context.equipment_activation(1).ok(),
			"member_two_active": visible_context.equipment_activation(2).ok(),
			"member_one_source": visible_party.member_by_id(1).modifier_sources.any(func(source: StatModifierSource) -> bool: return source.id == &"equipment_member_1"),
			"member_two_source": visible_party.member_by_id(2).modifier_sources.any(func(source: StatModifierSource) -> bool: return source.id == &"equipment_member_2"),
			"member_one_stats": visible_party.stats_for(1) != null,
			"member_two_stats": visible_party.stats_for(2) != null,
		})
	)
	var visible_errors := visible_context.configure(
		&"atomic_visible_player",
		0,
		ProfileState.new_profile("profile-atomic-visible", "Atomic Visible", 1000),
		8812,
		visible_party,
		100,
	)
	TestAssertions.equal(visible_errors, PackedStringArray(), "atomic source batch configures successfully", failures)
	TestAssertions.equal(visible_events, [1, 2], "successful source batch emits one ordered signal per member", failures)
	TestAssertions.equal(visible_party.stat_revision(), visible_revision_before + 1, "successful source batch advances one shared stat revision", failures)
	TestAssertions.equal(visible_observations.size(), 2, "successful source batch yields two synchronous observations", failures)
	for observation: Dictionary in visible_observations:
		for field: String in observation:
			TestAssertions.truthy(bool(observation[field]), "source-batch observer sees committed %s" % field, failures)
	visible_party.free()

func _test_resume_rejects_structurally_invalid_loadouts(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{
			"label": "canonical slot",
			"class_id": &"fighter",
			"expected": "reason=incompatible slot",
			"items": [{"base_id": &"forge_vanguard_sword", "slot_id": &"helmet"}],
		},
		{
			"label": "class compatibility",
			"class_id": &"ranger",
			"expected": "reason=missing weight capability armour_heavy",
			"items": [{"base_id": &"dawn_bulwark_plate", "slot_id": &"body_armour"}],
		},
		{
			"label": "reserved offhand family",
			"class_id": &"marksman",
			"expected": "equipped offhand siege_heavy_quiver is incompatible",
			"items": [
				{"base_id": &"greenwood_recurve_bow", "slot_id": &"main_hand"},
				{"base_id": &"siege_heavy_quiver", "slot_id": &"off_hand"},
			],
		},
	]
	var catalog := GameCatalog.load_defaults()
	for test_case: Dictionary in cases:
		var party := PartyManager.new()
		party.initialize(catalog.class_by_id(test_case["class_id"]), catalog.traits)
		var registry_items: Array[ItemInstance] = []
		var equipped_slots: Dictionary = {}
		var sequence := 0
		for item_case: Dictionary in test_case["items"]:
			var item := _plain_item_record(
				"item-invalid-%s-%d" % [String(test_case["class_id"]), sequence],
				StringName(item_case["base_id"]),
				"profile:profile-invalid-%s" % String(test_case["class_id"]),
				sequence,
			)
			registry_items.append(item)
			equipped_slots[EquipmentSlotIndex.index_for(StringName(item_case["slot_id"]))] = item.instance_id
			sequence += 1
		var owner_id := "invalid_%s_player" % String(test_case["class_id"])
		var state := ItemOwnershipState.create(owner_id, ItemRegistry.new(registry_items), [
			ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, owner_id, 5),
			ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, owner_id, EquipmentSlotIndex.capacity(), equipped_slots),
		])
		var bootstrap := RunItemBootstrap.create(StringName("run-invalid-%s" % String(test_case["class_id"])), 8820 + sequence, StringName(owner_id), 1, state)
		var profile := ProfileState.new_profile("profile-invalid-%s" % String(test_case["class_id"]), "Invalid Resume", 1000)
		profile.inventory_columns = 1
		profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
		var revision_before := party.stat_revision()
		var sources_before := _source_documents(party.member_by_id(1))
		var changed: Array[int] = []
		party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
		var context := PlayerRunContext.new()
		var errors := context.configure(StringName(owner_id), 0, profile, bootstrap.run_seed, party, 100, bootstrap)
		TestAssertions.truthy(not errors.is_empty(), "%s resume is rejected" % test_case["label"], failures)
		if not errors.is_empty():
			TestAssertions.truthy(errors[0].contains(String(test_case["expected"])), "%s resume reports the structural cause" % test_case["label"], failures)
		_assert_context_unconfigured(context, "%s resume" % test_case["label"], failures)
		TestAssertions.equal(_source_documents(party.member_by_id(1)), sources_before, "%s resume preserves member sources" % test_case["label"], failures)
		TestAssertions.equal(party.stat_revision(), revision_before, "%s resume preserves stat revision" % test_case["label"], failures)
		TestAssertions.equal(changed, [], "%s resume emits no stat signal" % test_case["label"], failures)
		party.free()

func _test_resume_reconstructs_equipment_activation(failures: Array[String]) -> void:
	var probe := PlayerRunContext.new()
	if not probe.has_method(&"equipment_activation"):
		return
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var item := _stout_helmet_record("item-resume-stout", "profile:profile-resume01", 0)
	var item_before := JSON.stringify(item.to_dictionary())
	var state := ItemOwnershipState.create("resume_player", ItemRegistry.new([item]), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, "resume_player", 5),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, "resume_player", EquipmentSlotIndex.capacity(), {
			EquipmentSlotIndex.index_for(&"helmet"): item.instance_id,
		}),
	])
	var bootstrap := RunItemBootstrap.create(&"run-resume-task6", 7701, &"resume_player", 1, state)
	var profile := ProfileState.new_profile("profile-resume01", "Resume Task 6", 1000)
	profile.inventory_columns = 1
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var base_maximum := party.stats_for(1).value(&"max_health")
	var context := PlayerRunContext.new()
	var errors := context.configure(&"resume_player", 0, profile, 7701, party, 100, bootstrap)
	TestAssertions.equal(errors, PackedStringArray(), "resume reconstructs valid equipment state", failures)
	if errors.is_empty():
		var activation: EquipmentActivationResult = context.call(&"equipment_activation", 1)
		TestAssertions.truthy(activation.ok() and activation.is_active(item.instance_id), "resume reconstructs active equipment identity", failures)
		TestAssertions.near(party.stats_for(1).value(&"max_health"), base_maximum + 9.0, 0.0001, "resume reconstructs equipment and derived stats", failures)
		TestAssertions.equal(context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"helmet")), item.instance_id, "resume retains exact equipped item", failures)
	TestAssertions.equal(JSON.stringify(item.to_dictionary()), item_before, "resume reconstruction leaves immutable item record unchanged", failures)
	party.free()

func _issue_stout_helmet(context: PlayerRunContext, sequence: int, slot: int, failures: Array[String]) -> ItemInstance:
	var item_data := {
		"affixes": [_stout_affix_document()],
		"base_definition_id": "forge_vanguard_helmet",
		"item_level": 1,
		"rarity_id": "common",
	}
	var issued := ItemInstanceIssuer.issue(
		"run:%s:%s:%s" % [context.profile_id, context.run_seed, context.run_player_id],
		sequence, "task_6", context.run_seed + sequence, item_data,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(issued.ok(), "Task 6 stout helmet issues", failures)
	if not issued.ok():
		return null
	var request := ItemTransactionRequest.create("task6-create-%d" % sequence, String(context.run_player_id), &"run-inventory", slot, issued.item)
	var result := context.apply_item_transaction(request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(result.code, ItemTransactionResult.Code.OK, "Task 6 stout helmet enters run inventory", failures)
	return issued.item if result.ok() else null

func _stout_helmet_record(instance_id: String, issuer_namespace: String, sequence: int) -> ItemInstance:
	var document := {
		"schema_version": ItemInstance.SCHEMA_VERSION,
		"instance_id": instance_id,
		"base_definition_id": "forge_vanguard_helmet",
		"item_level": 1,
		"rarity_id": "common",
		"affixes": [_stout_affix_document()],
		"origin": {"issuer_namespace": issuer_namespace, "seed": 7701, "sequence": sequence, "source": "task_6_resume"},
	}
	var decoded := ItemInstanceCodec.decode(document, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	assert(decoded.ok())
	return decoded.item

func _plain_item_record(instance_id: String, base_definition_id: StringName, issuer_namespace: String, sequence: int) -> ItemInstance:
	var document := {
		"schema_version": ItemInstance.SCHEMA_VERSION,
		"instance_id": instance_id,
		"base_definition_id": String(base_definition_id),
		"item_level": 1,
		"rarity_id": "common",
		"affixes": [],
		"origin": {"issuer_namespace": issuer_namespace, "seed": 8820, "sequence": sequence, "source": "task_6_invalid_resume"},
	}
	var decoded := ItemInstanceCodec.decode(document, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	assert(decoded.ok())
	return decoded.item

func _source_documents(member: PartyMemberState) -> String:
	return _source_documents_from_array(member.modifier_sources)

func _stout_affix_document() -> Dictionary:
	return {
		"definition_id": "stout",
		"affix_kind": "prefix",
		"tier": 1,
		"rolls": [{
			"stat_id": "constitution",
			"operation": StatModifier.Operation.FLAT,
			"value": 3.0,
			"required_tags": [],
		}],
	}

func _test_checked_out_item_bootstrap_identity_and_retry(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var profile := ProfileState.new_profile("profile-bootstrap01", "Bootstrap Owner", 1000)
	profile.inventory_columns = 1
	var item := ItemInstance.new()
	item.instance_id = "item-context-bootstrap"
	item.base_definition_id = &"forge_vanguard_sword"
	item.item_level = 28
	item.rarity_id = &"common"
	item.origin = {
		"issuer_namespace": "profile:profile-bootstrap01",
		"seed": 4410,
		"sequence": 0,
		"source": "context_bootstrap_test",
	}
	var state := ItemOwnershipState.create("bootstrap_player", ItemRegistry.new([item]), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, "bootstrap_player", 5),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, "bootstrap_player", EquipmentSlotIndex.capacity(), {9: item.instance_id}),
	])
	var bootstrap := RunItemBootstrap.create(&"run-bootstrap-001", 4410, &"bootstrap_player", 1, state)
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)

	var missing_context := PlayerRunContext.new()
	var missing_errors := missing_context.configure(&"bootstrap_player", 0, profile, 4410, party, 100)
	TestAssertions.equal(missing_errors, PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=item_bootstrap reason=required for resumable item run"]), "strict resumable profile requires its bootstrap", failures)
	_assert_context_unconfigured(missing_context, "missing bootstrap", failures)

	var cases: Array[Dictionary] = [
		{"label": "wrong seed", "bootstrap": RunItemBootstrap.create(&"run-bootstrap-001", 4411, &"bootstrap_player", 1, state)},
		{"label": "wrong run player", "bootstrap": RunItemBootstrap.create(&"run-bootstrap-001", 4410, &"wrong_player", 1, ItemOwnershipState.create("wrong_player", ItemRegistry.new([item]), [
			ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, "wrong_player", 5),
			ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, "wrong_player", EquipmentSlotIndex.capacity(), {9: item.instance_id}),
		]))},
		{"label": "wrong leader", "bootstrap": RunItemBootstrap.create(&"run-bootstrap-001", 4410, &"bootstrap_player", 2, state)},
		{"label": "wrong run identity", "bootstrap": RunItemBootstrap.create(&"run-bootstrap-other", 4410, &"bootstrap_player", 1, state)},
	]
	for test_case: Dictionary in cases:
		var context := PlayerRunContext.new()
		var errors := context.configure(&"bootstrap_player", 0, profile, 4410, party, 100, test_case["bootstrap"])
		TestAssertions.truthy(not errors.is_empty() and errors[0].contains("field=item_bootstrap"), "%s bootstrap is rejected" % test_case["label"], failures)
		_assert_context_unconfigured(context, test_case["label"], failures)

	var retry_context := PlayerRunContext.new()
	var wrong_profile := profile.copy()
	wrong_profile.resumable_run = ResumableRunItemCodec.encode(RunItemBootstrap.create(&"run-bootstrap-other", 4410, &"bootstrap_player", 1, state))
	var wrong_profile_errors := retry_context.configure(&"bootstrap_player", 0, wrong_profile, 4410, party, 100, bootstrap)
	TestAssertions.truthy(not wrong_profile_errors.is_empty() and wrong_profile_errors[0].contains("field=item_bootstrap"), "wrong profile/run pairing is rejected", failures)
	_assert_context_unconfigured(retry_context, "wrong profile", failures)
	TestAssertions.equal(retry_context.configure(&"bootstrap_player", 0, profile, 4410, party, 100, bootstrap), PackedStringArray(), "failed bootstrap configuration remains retryable", failures)
	TestAssertions.equal(retry_context.item_state().to_dictionary(), state.to_dictionary(), "successful retry adopts exact checked-out item state", failures)
	var exposed := retry_context.item_state()
	exposed._clear_slot(&"run-equipment-001", 9)
	TestAssertions.equal(retry_context.equipment_for(1).item_id_at(9), item.instance_id, "configured bootstrap state is defensive", failures)
	party.free()

func _assert_context_unconfigured(context: PlayerRunContext, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(context.run_player_id, &"", "%s leaves run player unconfigured" % label, failures)
	TestAssertions.equal(context.profile_id, "", "%s leaves profile unconfigured" % label, failures)
	TestAssertions.equal(context.run_seed, 0, "%s leaves seed unconfigured" % label, failures)
	TestAssertions.equal(context.party, null, "%s leaves party unconfigured" % label, failures)
	TestAssertions.equal(context.item_state(), null, "%s leaves no item state" % label, failures)

func _test_initial_member_equipment_is_owned_and_defensive(failures: Array[String]) -> void:
	var fixture := _configured_fixture(PartyManager.new())
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as PartyManager
	TestAssertions.truthy(context.has_method(&"equipment_for"), "run context exposes member equipment", failures)
	if not context.has_method(&"equipment_for"):
		party.free()
		return
	for member_id: int in [1, 2]:
		var equipment := context.call(&"equipment_for", member_id) as ItemSlotContainer
		TestAssertions.truthy(equipment != null, "configured member %d owns equipment" % member_id, failures)
		if equipment == null:
			continue
		TestAssertions.equal(equipment.container_id, StringName("run-equipment-%03d" % member_id), "member %d equipment has stable ID" % member_id, failures)
		TestAssertions.equal(equipment.container_kind, ItemSlotContainer.RUN_MEMBER_EQUIPMENT, "member %d equipment has run kind" % member_id, failures)
		TestAssertions.equal(equipment.owner_id, String(context.run_player_id), "member %d equipment belongs to the run player" % member_id, failures)
		TestAssertions.equal(equipment.capacity, EquipmentSlotIndex.capacity(), "member %d equipment uses all canonical slots" % member_id, failures)
		TestAssertions.equal(equipment.occupied_slots(), [], "member %d equipment starts empty" % member_id, failures)
		equipment.capacity = 0
		TestAssertions.equal((context.call(&"equipment_for", member_id) as ItemSlotContainer).capacity, EquipmentSlotIndex.capacity(), "member %d equipment accessor is defensive" % member_id, failures)
	TestAssertions.equal(context.call(&"equipment_for", 99), null, "unknown member has no equipment", failures)
	party.free()

func _test_configuration_validation_and_copy_ownership(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var uninitialized_party := PartyManager.new()
	var invalid_profile := ProfileState.new()
	var invalid := PlayerRunContext.new()
	TestAssertions.equal(invalid.configure(&"", -1, invalid_profile, 0, uninitialized_party, 99), PackedStringArray([
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=run_player_id",
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=player_slot_index",
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=profile",
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=run_seed",
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=party",
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=experience_multiplier",
	]), "configuration reports stable validation fields", failures)
	TestAssertions.equal(invalid.run_player_id, &"", "failed configuration does not set run player", failures)
	TestAssertions.equal(invalid.party, null, "failed configuration does not set party", failures)
	TestAssertions.truthy(invalid.has_method(&"item_state"), "run context exposes item state after Task 7", failures)
	TestAssertions.truthy(invalid.has_method(&"run_inventory"), "run context exposes run inventory after Task 7", failures)
	TestAssertions.truthy(invalid.has_method(&"apply_item_transaction"), "run context exposes item transactions after Task 7", failures)
	if invalid.has_method(&"item_state"):
		TestAssertions.equal(invalid.call(&"item_state"), null, "failed configuration commits no item state", failures)
	if invalid.has_method(&"run_inventory"):
		TestAssertions.equal(invalid.call(&"run_inventory"), null, "failed configuration commits no run inventory", failures)
	var retry_issue := ItemInstanceIssuer.issue(
		"run:profile-retry001:4004:retry_player",
		0,
		"configuration_retry_test",
		4004,
		{
			"affixes": [],
			"base_definition_id": "forge_vanguard_sword",
			"item_level": 1,
			"rarity_id": "common",
		},
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(retry_issue.ok(), "configuration retry item fixture issues", failures)
	var retry_request := ItemTransactionRequest.create(
		"configuration-retry-create",
		"retry_player",
		&"run-inventory",
		0,
		retry_issue.item,
	)
	if invalid.has_method(&"apply_item_transaction"):
		var unconfigured_result := invalid.call(
			&"apply_item_transaction",
			retry_request,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
		) as ItemTransactionResult
		TestAssertions.equal(unconfigured_result.code, ItemTransactionResult.Code.INVALID_REQUEST, "failed configuration has no usable transaction journal", failures)
	uninitialized_party.free()
	var retry_party := PartyManager.new()
	retry_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var retry_profile := ProfileState.new_profile("profile-retry001", "Retry Owner", 1000)
	retry_profile.inventory_columns = 1
	TestAssertions.equal(
		invalid.configure(&"retry_player", 4, retry_profile, 4004, retry_party, 100),
		PackedStringArray(),
		"failed initial configuration remains retryable",
		failures,
	)
	if invalid.has_method(&"item_state") and invalid.has_method(&"run_inventory"):
		var retry_state := invalid.call(&"item_state") as ItemOwnershipState
		var retry_inventory := invalid.call(&"run_inventory") as ItemSlotContainer
		TestAssertions.truthy(retry_state != null, "valid retry creates one item ownership state", failures)
		TestAssertions.equal(retry_state.registry().size(), 0, "valid retry creates one empty run registry", failures)
		TestAssertions.equal(retry_state.containers().size(), 2, "valid retry creates inventory plus leader equipment", failures)
		TestAssertions.equal(retry_inventory.capacity, 5, "valid retry derives its unlocked five-slot inventory", failures)
		var retry_created := invalid.call(
			&"apply_item_transaction",
			retry_request,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
		) as ItemTransactionResult
		TestAssertions.equal(retry_created.code, ItemTransactionResult.Code.OK, "valid configuration retry creates the item exactly once", failures)
		TestAssertions.equal((invalid.call(&"item_state") as ItemOwnershipState).registry().size(), 1, "configuration retry journal cannot duplicate the item", failures)
		var item_state_before_reconfigure := (invalid.call(&"item_state") as ItemOwnershipState).to_dictionary()
		var replacement_party := PartyManager.new()
		replacement_party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
		var replacement_profile := ProfileState.new_profile("profile-retry-replacement", "Retry Replacement", 2000)
		replacement_profile.inventory_columns = 8
		TestAssertions.equal(
			invalid.configure(&"retry_replacement", 9, replacement_profile, 9999, replacement_party, 250),
			PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=configuration reason=already configured"]),
			"successful configured context rejects valid reconfiguration after an item commit",
			failures,
		)
		TestAssertions.equal((invalid.call(&"item_state") as ItemOwnershipState).to_dictionary(), item_state_before_reconfigure, "rejected valid reconfiguration preserves exact item state", failures)
		var retry_replayed := invalid.call(
			&"apply_item_transaction",
			retry_request,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
		) as ItemTransactionResult
		TestAssertions.equal(retry_replayed.code, ItemTransactionResult.Code.TRANSACTION_REPLAY, "rejected valid reconfiguration preserves the context journal", failures)
		TestAssertions.truthy(retry_replayed.duplicate, "post-reconfiguration replay remains a duplicate success", failures)
		TestAssertions.equal(retry_replayed.next_state.to_dictionary(), item_state_before_reconfigure, "post-reconfiguration replay returns the original committed ownership state", failures)
		var next_retry_issue := ItemInstanceIssuer.issue(
			"run:profile-retry001:4004:retry_player",
			1,
			"configuration_retry_sequence_test",
			4005,
			{
				"affixes": [],
				"base_definition_id": "forge_vanguard_sword",
				"item_level": 1,
				"rarity_id": "common",
			},
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
		)
		TestAssertions.truthy(next_retry_issue.ok(), "post-reconfiguration sequence fixture issues", failures)
		var next_retry_request := ItemTransactionRequest.create(
			"configuration-retry-create-next",
			"retry_player",
			&"run-inventory",
			1,
			next_retry_issue.item,
		)
		var next_retry_created := invalid.call(
			&"apply_item_transaction",
			next_retry_request,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
		) as ItemTransactionResult
		TestAssertions.equal(next_retry_created.code, ItemTransactionResult.Code.OK, "rejected valid reconfiguration preserves next run issuance sequence", failures)
		TestAssertions.equal((invalid.call(&"item_state") as ItemOwnershipState).registry().size(), 2, "post-reconfiguration create commits once in the original context", failures)
		replacement_party.free()
	retry_party.free()

	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var original_profile := ProfileState.new_profile("profile-copy0001", "Copy Owner", 1000)
	original_profile.gold = 17
	var context := PlayerRunContext.new()
	TestAssertions.equal(context.configure(&"player_copy", 3, original_profile, 1337, party, 100), PackedStringArray(), "valid configuration succeeds", failures)
	TestAssertions.equal(context.profile_id, "profile-copy0001", "context exposes owned profile ID", failures)
	TestAssertions.equal(context.player_slot_index, 3, "context exposes player slot", failures)
	TestAssertions.equal(context.run_seed, 1337, "context exposes run seed", failures)
	TestAssertions.equal(context.experience_multiplier_percent, 100, "context exposes XP multiplier", failures)
	original_profile.gold = 99
	var exposed_profile := context.profile_snapshot
	TestAssertions.equal(exposed_profile.gold, 17, "configured profile is privately copied", failures)
	exposed_profile.gold = 123
	TestAssertions.equal(context.profile_snapshot.gold, 17, "profile getter returns a defensive copy", failures)
	var exposed_progression := context.progression_for(1)
	exposed_progression.level = 99
	exposed_progression.core_attribute_gains[&"strength"] = 99
	TestAssertions.equal(context.progression_for(1).level, 1, "progression getter isolates level", failures)
	TestAssertions.equal(context.progression_for(1).core_attribute_gains[&"strength"], 0, "progression getter isolates attributes", failures)
	var actor := Node3D.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(100.0, true, 8.0, 0.5)
	actor.add_child(health)
	TestAssertions.truthy(context.bind_actor(1, actor), "configured context binds its leader actor", failures)
	TestAssertions.truthy(context.award_experience(1, 20).ok(), "configured context can establish progression and queue state", failures)
	var registry := RunContextRegistry.new()
	TestAssertions.truthy(registry.register_context(context).ok(), "configured context registers before immutability checks", failures)
	var distributor := RewardDistributionService.new()
	TestAssertions.equal(
		distributor.configure(registry, load("res://data/progression/reward_distribution.tres") as RewardDistributionTuning),
		PackedStringArray(),
		"reward distributor configures for identity immutability",
		failures,
	)
	var identity_packet := RewardPacket.create(&"identity_immutable_packet", 1, Vector3.ZERO)
	TestAssertions.equal(
		distributor.distribute(identity_packet).awarded_members,
		PackedStringArray(["player_copy:1"]),
		"identity packet resolves under the configured run-player ID",
		failures,
	)

	var before_profile := context.profile_snapshot.to_dictionary()
	var before_progression := context.progression_for(1).to_snapshot()
	var before_queue := context.pending_leader_levels()
	TestAssertions.equal(context.configure(&"replacement", 9, original_profile, 9999, party, 1001), PackedStringArray([
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=configuration reason=already configured",
	]), "invalid reconfiguration is rejected by the single-configuration invariant", failures)
	TestAssertions.equal(context.run_player_id, &"player_copy", "failed reconfiguration preserves run player", failures)
	TestAssertions.equal(context.player_slot_index, 3, "failed reconfiguration preserves slot", failures)
	TestAssertions.equal(context.profile_snapshot.to_dictionary(), before_profile, "failed reconfiguration preserves profile", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), before_progression, "failed reconfiguration preserves progression", failures)
	TestAssertions.equal(context.pending_leader_levels(), before_queue, "failed reconfiguration preserves leader queue", failures)
	TestAssertions.truthy(context.actor_for(1) == actor, "failed reconfiguration preserves actor bindings", failures)
	TestAssertions.truthy(context.party == party, "failed reconfiguration preserves party", failures)

	var replacement_party := PartyManager.new()
	replacement_party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
	var replacement_profile := ProfileState.new_profile("profile-replacement", "Replacement", 2000)
	TestAssertions.equal(context.configure(&"replacement", 9, replacement_profile, 9999, replacement_party, 250), PackedStringArray([
		"PARTY_FORGE_RUN_CONTEXT_ERROR field=configuration reason=already configured",
	]), "valid reconfiguration is rejected by the single-configuration invariant", failures)
	TestAssertions.equal(context.run_player_id, &"player_copy", "valid reconfiguration cannot mutate run player", failures)
	TestAssertions.equal(context.player_slot_index, 3, "valid reconfiguration cannot mutate slot", failures)
	TestAssertions.equal(context.profile_snapshot.to_dictionary(), before_profile, "valid reconfiguration cannot mutate profile", failures)
	TestAssertions.equal(context.run_seed, 1337, "valid reconfiguration cannot mutate run seed", failures)
	TestAssertions.equal(context.experience_multiplier_percent, 100, "valid reconfiguration cannot mutate XP multiplier", failures)
	TestAssertions.truthy(context.party == party, "valid reconfiguration cannot replace the owned party", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), before_progression, "valid reconfiguration cannot reset progression", failures)
	TestAssertions.equal(context.pending_leader_levels(), before_queue, "valid reconfiguration cannot clear leader queue", failures)
	TestAssertions.truthy(context.actor_for(1) == actor, "valid reconfiguration cannot clear actor bindings", failures)
	TestAssertions.truthy(registry.context_for(&"player_copy") == context, "registry lookup remains coherent under the original identity", failures)
	TestAssertions.equal(registry.context_for(&"replacement"), null, "registry gains no lookup for a rejected identity", failures)
	TestAssertions.truthy(distributor.has_resolved(&"identity_immutable_packet", &"player_copy"), "reward idempotency retains the original identity key", failures)
	TestAssertions.truthy(not distributor.has_resolved(&"identity_immutable_packet", &"replacement"), "reward idempotency gains no drifted identity key", failures)
	TestAssertions.equal(distributor.distribute(identity_packet), {
		"awarded_members": PackedStringArray(),
		"skipped_contexts": PackedStringArray(),
		"errors": PackedStringArray(),
	}, "same packet remains idempotent after rejected reconfiguration", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), before_progression, "idempotent retry leaves progression unchanged", failures)
	replacement_party.free()
	actor.free()
	party.free()

func _test_configuration_rejects_invalid_member_growth_atomically(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var missing_party := PartyManager.new()
	missing_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var missing_growth_class := catalog.class_by_id(&"ranger").duplicate(true) as ClassDefinition
	missing_growth_class.growth_definition = null
	TestAssertions.truthy(missing_party.recruit(missing_growth_class), "missing-growth follower joins the fixture party", failures)
	var missing_context := PlayerRunContext.new()
	var missing_signals: Array[String] = []
	missing_context.member_level_ready.connect(func(member_id: int, level: int) -> void: missing_signals.append("level:%d:%d" % [member_id, level]))
	missing_context.progression_changed.connect(func(member_id: int) -> void: missing_signals.append("changed:%d" % member_id))
	TestAssertions.equal(
		missing_context.configure(
			&"missing_growth_player",
			2,
			ProfileState.new_profile("profile-missing-growth", "Missing Growth", 3000),
			3003,
			missing_party,
			100,
		),
		PackedStringArray([
			"PARTY_FORGE_RUN_CONTEXT_ERROR field=party member=2 reason=growth definition missing",
		]),
		"a missing member growth definition prevents context configuration",
		failures,
	)
	_assert_unconfigured_context(missing_context, missing_signals, "missing growth", failures)
	TestAssertions.truthy(missing_party.recruit(catalog.class_by_id(&"cleric")), "missing-growth party can change after rejection", failures)
	TestAssertions.equal(missing_context.progression_for(3), null, "missing-growth rejection connects no member-added callback", failures)
	missing_party.free()

	var malformed_party := PartyManager.new()
	malformed_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var malformed_class := catalog.class_by_id(&"ranger").duplicate(true) as ClassDefinition
	var malformed_growth := ClassGrowthDefinition.new()
	malformed_growth.guaranteed_cycle = [&"damage"]
	malformed_growth.milestone_weights = {&"strength": 0.0}
	malformed_class.growth_definition = malformed_growth
	TestAssertions.truthy(malformed_party.recruit(malformed_class), "malformed-growth follower joins the fixture party", failures)
	var malformed_context := PlayerRunContext.new()
	var malformed_signals: Array[String] = []
	malformed_context.member_level_ready.connect(func(member_id: int, level: int) -> void: malformed_signals.append("level:%d:%d" % [member_id, level]))
	malformed_context.progression_changed.connect(func(member_id: int) -> void: malformed_signals.append("changed:%d" % member_id))
	TestAssertions.equal(
		malformed_context.configure(
			&"malformed_growth_player",
			3,
			ProfileState.new_profile("profile-malformed-growth", "Malformed Growth", 4000),
			4004,
			malformed_party,
			100,
		),
		PackedStringArray([
			"PARTY_FORGE_RUN_CONTEXT_ERROR field=party member=2 reason=PARTY_FORGE_GROWTH_ERROR field=guaranteed_cycle value=damage reason=unknown core attribute",
			"PARTY_FORGE_RUN_CONTEXT_ERROR field=party member=2 reason=PARTY_FORGE_GROWTH_ERROR field=milestone_weights reason=no positive weights",
		]),
		"malformed member growth prevents context configuration with stable reasons",
		failures,
	)
	_assert_unconfigured_context(malformed_context, malformed_signals, "malformed growth", failures)
	TestAssertions.truthy(malformed_party.recruit(catalog.class_by_id(&"cleric")), "malformed-growth party can change after rejection", failures)
	TestAssertions.equal(malformed_context.progression_for(3), null, "malformed-growth rejection connects no member-added callback", failures)
	malformed_party.free()

func _assert_unconfigured_context(context: PlayerRunContext, signals: Array[String], label: String, failures: Array[String]) -> void:
	TestAssertions.equal(context.run_player_id, &"", "%s rejection preserves empty run player" % label, failures)
	TestAssertions.equal(context.player_slot_index, -1, "%s rejection preserves empty slot" % label, failures)
	TestAssertions.equal(context.profile_id, "", "%s rejection preserves empty profile ID" % label, failures)
	TestAssertions.equal(context.profile_snapshot, null, "%s rejection preserves empty profile snapshot" % label, failures)
	TestAssertions.equal(context.run_seed, 0, "%s rejection preserves empty run seed" % label, failures)
	TestAssertions.equal(context.experience_multiplier_percent, 100, "%s rejection preserves default multiplier" % label, failures)
	TestAssertions.equal(context.party, null, "%s rejection preserves empty party" % label, failures)
	TestAssertions.equal(context.progression_for(1), null, "%s rejection creates no leader progression" % label, failures)
	TestAssertions.equal(context.progression_for(2), null, "%s rejection creates no follower progression" % label, failures)
	TestAssertions.equal(context.pending_leader_levels(), [], "%s rejection creates no upgrade queue" % label, failures)
	TestAssertions.equal(signals, [], "%s rejection emits no signals" % label, failures)
	if context.has_method(&"item_state"):
		TestAssertions.equal(context.call(&"item_state"), null, "%s rejection commits no item state" % label, failures)
	if context.has_method(&"run_inventory"):
		TestAssertions.equal(context.call(&"run_inventory"), null, "%s rejection commits no run inventory" % label, failures)

func _test_atomic_progression_and_leader_queue(failures: Array[String]) -> void:
	var fixture := _configured_fixture(RejectingPartyManager.new())
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as RejectingPartyManager
	var fighter := fixture.fighter as ClassDefinition
	TestAssertions.equal(context.progression_for(1).level, 1, "leader starts at level one", failures)
	TestAssertions.equal(context.progression_for(2).level, 1, "follower starts at level one", failures)

	var events: Array[String] = []
	context.member_level_ready.connect(func(member_id: int, level: int) -> void: events.append("level:%d:%d" % [member_id, level]))
	context.progression_changed.connect(func(member_id: int) -> void: events.append("changed:%d" % member_id))
	var leader_award := context.award_experience(1, 20)
	TestAssertions.truthy(leader_award.ok(), "leader XP award succeeds", failures)
	TestAssertions.equal(context.progression_for(1).level, 2, "leader reaches level two", failures)
	TestAssertions.equal(context.progression_for(2).level, 1, "leader award leaves follower unchanged", failures)
	TestAssertions.equal(party.stats_for(1).value(&"strength"), 1.0, "fighter growth source resolves strength", failures)
	var growth_sources := party.member_by_id(1).modifier_sources.filter(func(source: StatModifierSource) -> bool: return source.id == &"character_growth_1")
	TestAssertions.equal(growth_sources.size(), 1, "leader receives one cumulative growth source alongside equipment", failures)
	TestAssertions.equal(growth_sources[0].id if not growth_sources.is_empty() else &"", &"character_growth_1", "leader growth source has stable ID", failures)
	TestAssertions.equal(context.pending_leader_levels(), [2], "leader level enters ordered queue", failures)
	TestAssertions.equal(context.current_pending_level(), 2, "current pending level is queue front", failures)
	TestAssertions.equal(events, ["level:1:2", "changed:1"], "level signal precedes one progression signal", failures)

	var exposed_queue := context.pending_leader_levels()
	exposed_queue.append(99)
	TestAssertions.equal(context.pending_leader_levels(), [2], "leader queue getter is defensive", failures)
	var follower_award := context.award_experience(2, 20)
	TestAssertions.truthy(follower_award.ok(), "follower XP award succeeds", failures)
	TestAssertions.equal(context.progression_for(2).level, 2, "follower reaches level two", failures)
	TestAssertions.equal(party.stats_for(2).value(&"dexterity"), 1.0, "Ranger follower uses Ranger growth", failures)
	TestAssertions.equal(context.pending_leader_levels(), [2], "follower does not queue an upgrade", failures)
	TestAssertions.equal(events, ["level:1:2", "changed:1", "level:2:2", "changed:2"], "follower signals remain ordered without queueing", failures)

	var stored_before := context.progression_for(1).to_snapshot()
	var queue_before := context.pending_leader_levels()
	var source_before := growth_sources[0] as StatModifierSource
	var strength_before := party.stats_for(1).value(&"strength")
	var event_count_before := events.size()
	var original_growth := fighter.growth_definition
	var invalid_growth := ClassGrowthDefinition.new()
	invalid_growth.guaranteed_cycle = [&"unknown_stat"]
	invalid_growth.milestone_weights = {&"strength": 1.0}
	fighter.growth_definition = invalid_growth
	var invalid_award := context.award_experience(1, 30)
	fighter.growth_definition = original_growth
	TestAssertions.truthy(not invalid_award.ok(), "invalid class growth award fails", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), stored_before, "invalid growth preserves progression", failures)
	TestAssertions.equal(context.pending_leader_levels(), queue_before, "invalid growth preserves queue", failures)
	TestAssertions.equal(events.size(), event_count_before, "invalid growth emits no signals", failures)
	TestAssertions.equal(party.stats_for(1).value(&"strength"), strength_before, "invalid growth preserves resolved attributes", failures)
	var growth_after := party.member_by_id(1).modifier_sources.filter(func(source: StatModifierSource) -> bool: return source.id == &"character_growth_1")
	TestAssertions.equal(growth_after[0].id if not growth_after.is_empty() else &"", source_before.id, "invalid growth preserves source ID", failures)
	TestAssertions.equal(growth_after[0].modifiers[0].value if not growth_after.is_empty() else NAN, source_before.modifiers[0].value, "invalid growth preserves source values", failures)

	party.reject_growth_source = true
	var rejected_award := context.award_experience(1, 30)
	TestAssertions.truthy(not rejected_award.ok(), "stat-source rejection fails award", failures)
	TestAssertions.equal(rejected_award.error, "PARTY_FORGE_PROGRESSION_ERROR member=1 reason=stat source rejected", "stat-source rejection has stable diagnostic", failures)
	TestAssertions.equal(context.progression_for(1).to_snapshot(), stored_before, "stat-source rejection preserves progression", failures)
	TestAssertions.equal(context.pending_leader_levels(), queue_before, "stat-source rejection preserves queue", failures)
	TestAssertions.equal(events.size(), event_count_before, "stat-source rejection emits no signals", failures)
	TestAssertions.equal(party.stats_for(1).value(&"strength"), strength_before, "stat-source rejection preserves attributes", failures)

	TestAssertions.truthy(context.consume_pending_leader_level(), "queue consumption removes first level", failures)
	TestAssertions.equal(context.pending_leader_levels(), [], "leader queue is empty after consumption", failures)
	TestAssertions.equal(context.current_pending_level(), 0, "empty queue has no current level", failures)
	TestAssertions.truthy(not context.consume_pending_leader_level(), "empty queue cannot be consumed", failures)
	party.free()

func _test_future_recruits_initialize_once(failures: Array[String]) -> void:
	var fixture := _configured_fixture(PartyManager.new())
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as PartyManager
	var catalog := fixture.catalog as GameCatalog
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"cleric")), "future recruit joins party", failures)
	TestAssertions.equal(context.progression_for(3).level, 1, "future recruit receives fresh progression", failures)
	var recruit_award := context.award_experience(3, 20)
	TestAssertions.truthy(recruit_award.ok(), "future recruit progression can advance", failures)
	TestAssertions.equal(context.progression_for(3).level, 2, "future recruit reaches level two", failures)
	party.member_added.emit(party.member_by_id(3))
	TestAssertions.equal(context.progression_for(3).level, 2, "repeated member-added event cannot reset progression", failures)
	party.free()

func _test_actor_binding_availability_and_position(failures: Array[String]) -> void:
	var fixture := _configured_fixture(PartyManager.new())
	var context := fixture.context as PlayerRunContext
	var party := fixture.party as PartyManager
	var actor := Node3D.new()
	actor.position = Vector3(3.0, 4.0, 5.0)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(100.0, true, 8.0, 0.5)
	actor.add_child(health)
	TestAssertions.truthy(not context.bind_actor(99, actor), "unknown member actor binding is rejected", failures)
	TestAssertions.truthy(context.bind_actor(1, actor), "known member actor binding succeeds", failures)
	TestAssertions.truthy(context.actor_for(1) == actor, "actor lookup returns bound actor", failures)
	TestAssertions.equal(actor.get_meta("party_forge_run_player_id"), &"player_one", "actor receives run-player ownership metadata", failures)
	TestAssertions.equal(actor.get_meta("party_forge_member_id"), 1, "actor receives member ownership metadata", failures)
	TestAssertions.truthy(context.member_is_available(1), "healthy bound member is available", failures)
	TestAssertions.equal(context.member_position(1), {"valid": true, "position": Vector3(3.0, 4.0, 5.0)}, "outside-tree member position uses local position", failures)
	health.is_downed = true
	TestAssertions.truthy(not context.member_is_available(1), "downed member is unavailable", failures)
	health.is_downed = false
	health.is_dead = true
	TestAssertions.truthy(not context.member_is_available(1), "dead member is unavailable", failures)
	TestAssertions.equal(context.member_position(99), {"valid": false}, "unknown member position is invalid", failures)

	var temporary_actor := Node3D.new()
	TestAssertions.truthy(context.bind_actor(2, temporary_actor), "follower actor binding succeeds", failures)
	temporary_actor.free()
	TestAssertions.equal(context.actor_for(2), null, "freed weak actor binding resolves null", failures)
	TestAssertions.truthy(not context.member_is_available(2), "freed actor is unavailable", failures)
	actor.free()
	party.free()

func _configured_fixture(manager: PartyManager, inventory_columns: int = 0) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var fighter := catalog.class_by_id(&"fighter")
	manager.initialize(fighter, catalog.traits)
	manager.recruit(catalog.class_by_id(&"ranger"))
	var context := PlayerRunContext.new()
	var profile := ProfileState.new_profile("profile-player01", "Player One", 1000)
	profile.inventory_columns = inventory_columns
	var errors := context.configure(&"player_one", 0, profile, 1337, manager, 100)
	assert(errors.is_empty())
	return {
		"catalog": catalog,
		"fighter": fighter,
		"party": manager,
		"context": context,
	}
