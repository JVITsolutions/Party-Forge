extends RefCounted

const RESULT_PATH := "res://scripts/equipment/equipment_transition_result.gd"
const SERVICE_PATH := "res://scripts/equipment/equipment_transition_service.gd"
const INVENTORY_ID := &"run-inventory"
const EQUIPMENT_ID := &"run-equipment-001"
const ACTION_ONLY_TAG := &"task10d_action_only"

class InvalidPreviewPartyManager extends PartyManager:
	func member_sources_without_equipment(member_id: int) -> Array[StatModifierSource]:
		var result := super.member_sources_without_equipment(member_id)
		result.append(StatModifierSource.create(&"invalid_preview", &"growth", "Invalid Preview", member_id, [
			StatModifier.create(&"missing_stat", StatModifier.Operation.FLAT, 1.0, &"invalid_preview_roll", "Invalid Preview"),
		]))
		return result

class CandidateActionPartyManager extends PartyManager:
	var candidate_sources: Array[StatModifierSource] = []

	func member_sources_without_equipment(member_id: int) -> Array[StatModifierSource]:
		var result := super.member_sources_without_equipment(member_id)
		for source: StatModifierSource in candidate_sources:
			result.append(source)
		return result

var _service: Script

func run() -> Array[String]:
	var failures: Array[String] = []
	_service = load(SERVICE_PATH) as Script
	var result_script := load(RESULT_PATH) as Script
	TestAssertions.truthy(_service != null and _service.can_instantiate(), "equipment transition service script is valid", failures)
	TestAssertions.truthy(result_script != null and result_script.can_instantiate(), "equipment transition result script is valid", failures)
	if _service == null or not _service.can_instantiate() or result_script == null or not result_script.can_instantiate():
		return failures
	_test_preview_is_pure_and_resolves_final_stats(failures)
	_test_newly_placed_disabled_item_is_rejected(failures)
	_test_projection_failure_is_atomic(failures)
	_test_non_action_aggregate_overflow_is_rejected_atomically(failures)
	_test_candidate_equipment_tagged_overflow_is_rejected(failures)
	_test_candidate_geometry_overflow_is_rejected_atomically(failures)
	_test_mixed_component_and_invalid_type_actions_are_rejected(failures)
	_test_critical_and_rate_overflow_are_rejected(failures)
	_test_healing_projection_validation(failures)
	_test_multi_action_and_missing_primary_contract(failures)
	_test_context_commit_rejection_is_atomic(failures)
	return failures

func _test_preview_is_pure_and_resolves_final_stats(failures: Array[String]) -> void:
	var party := _party(PartyManager.new())
	var item := _stout_helmet("item-transition-success", 1)
	var state := _state(item)
	var state_before := _bytes(state)
	var item_before := JSON.stringify(item.to_dictionary())
	var class_before := JSON.stringify(party.member_by_id(1).class_definition.base_stat_overrides)
	var cached_before := party.stats_for(1)
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	var result: Variant = _service.preview(
		state, 1, item.instance_id, &"helmet", party,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(result != null and result.ok(), "valid equipment transition preview succeeds", failures)
	if result != null and result.ok():
		TestAssertions.equal(result.state().container(EQUIPMENT_ID).item_id_at(EquipmentSlotIndex.index_for(&"helmet")), item.instance_id, "preview owns the complete candidate loadout", failures)
		TestAssertions.truthy(result.activation().is_active(item.instance_id), "newly placed usable item is active", failures)
		TestAssertions.equal(result.activation().source.id, &"equipment_member_1", "preview uses the stable member equipment source", failures)
		TestAssertions.near(result.resolution().final_stats.value(&"max_health"), cached_before.value(&"max_health") + 9.0, 0.0001, "constitution affix reaches final maximum health", failures)
		var exposed_state: ItemOwnershipState = result.state()
		exposed_state._clear_slot(EQUIPMENT_ID, EquipmentSlotIndex.index_for(&"helmet"))
		var exposed_activation: EquipmentActivationResult = result.activation()
		exposed_activation.source.modifiers.clear()
		TestAssertions.equal(result.state().container(EQUIPMENT_ID).item_id_at(EquipmentSlotIndex.index_for(&"helmet")), item.instance_id, "result state getter is defensive", failures)
		TestAssertions.truthy(not result.activation().source.modifiers.is_empty(), "result activation getter is defensive", failures)
	TestAssertions.equal(_bytes(state), state_before, "preview leaves ownership byte-equivalent", failures)
	TestAssertions.equal(JSON.stringify(item.to_dictionary()), item_before, "preview leaves immutable item records unchanged", failures)
	TestAssertions.equal(JSON.stringify(party.member_by_id(1).class_definition.base_stat_overrides), class_before, "preview leaves class resources unchanged", failures)
	TestAssertions.equal(party.stats_for(1), cached_before, "preview leaves the member cache untouched", failures)
	TestAssertions.equal(party.member_by_id(1).modifier_sources.size(), 0, "preview commits no member source", failures)
	TestAssertions.equal(changed, [], "preview emits no stat-change signal", failures)
	party.free()


func _test_candidate_geometry_overflow_is_rejected_atomically(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var fighter := _class_with_action_tag(catalog.class_by_id(&"fighter"), &"fighter_cleave", ACTION_ONLY_TAG)
	fighter.primary_attack.range = 1.0e308
	var party := _party_with_class(PartyManager.new(), fighter)
	var fixture := _tagged_equipment_fixture(&"attack_range", [ACTION_ONLY_TAG], 1.0, 1)
	var item := fixture.item as ItemInstance
	var foundation := fixture.foundation as ItemFoundationCatalog
	var state := _state(item)
	var state_before := _bytes(state)
	var base_before := party.stats_for(1)
	var action_tags := DamageResolver.action_tags_for(fighter.primary_attack)
	var action_before := party.stats_for_action(1, action_tags)
	var revision_before := party.stat_revision()
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	var result: Variant = _service.preview(
		state, 1, item.instance_id, &"helmet", party,
		GameCatalog.EQUIPMENT_CATALOG, foundation,
	)
	_assert_action_rejection(result, item.instance_id, &"helmet", fighter.primary_attack.id, "range", "effective geometry overflow", failures)
	TestAssertions.equal(_bytes(state), state_before, "geometry rejection preserves ownership", failures)
	TestAssertions.truthy(is_same(party.stats_for(1), base_before), "geometry rejection preserves base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "geometry rejection preserves action cache identity", failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "geometry rejection preserves revision", failures)
	TestAssertions.equal(changed, [], "geometry rejection emits no stat signal", failures)
	party.free()

func _test_non_action_aggregate_overflow_is_rejected_atomically(failures: Array[String]) -> void:
	var party := _party(CandidateActionPartyManager.new()) as CandidateActionPartyManager
	party.candidate_sources.append(_non_action_overflow_source())
	var item := _stout_helmet("item-transition-aggregate-overflow", 130)
	var state := _state(item)
	var state_before := _bytes(state)
	var item_before := item.to_dictionary()
	var class_before := party.member_by_id(1).class_definition.base_stat_overrides.duplicate(true)
	var cached_before := party.stats_for(1)
	var revision_before := party.stat_revision()
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	var result: Variant = _service.preview(
		state, 1, item.instance_id, &"helmet", party,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(result != null and not result.ok(), "non-action aggregate overflow rejects equipment preview", failures)
	if result != null:
		TestAssertions.equal(
			result.error,
			"PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR member=1 item=%s slot=helmet reason=stat resolution failed detail=PARTY_FORGE_STAT_RESOLUTION_ERROR member=1 stat=max_health stage=raw value=inf reason=resolved value is non-finite" % item.instance_id,
			"non-action aggregate overflow retains stable nested stat context",
			failures,
		)
		TestAssertions.truthy(result.state() == null and result.activation() == null and result.resolution() == null, "aggregate overflow exposes no partial transition", failures)
	TestAssertions.equal(_bytes(state), state_before, "aggregate overflow preserves ownership", failures)
	TestAssertions.equal(item.to_dictionary(), item_before, "aggregate overflow preserves immutable item bytes", failures)
	TestAssertions.equal(party.member_by_id(1).class_definition.base_stat_overrides, class_before, "aggregate overflow preserves class data", failures)
	TestAssertions.truthy(is_same(party.stats_for(1), cached_before), "aggregate overflow preserves cache identity", failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "aggregate overflow preserves revision", failures)
	TestAssertions.equal(changed, [], "aggregate overflow emits no stat signal", failures)
	party.free()

func _test_newly_placed_disabled_item_is_rejected(failures: Array[String]) -> void:
	var party := _party(PartyManager.new())
	var item := _stout_helmet("item-transition-disabled", 2)
	var state := _state(item)
	var state_before := _bytes(state)
	var equipment := _equipment_with_requirement(&"forge_vanguard_helmet", &"constitution", 999.0)
	var cached_before := party.stats_for(1)
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	var result: Variant = _service.preview(
		state, 1, item.instance_id, &"helmet", party,
		equipment, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(result != null and not result.ok(), "newly placed disabled item is rejected", failures)
	if result != null:
		TestAssertions.truthy(String(result.error).begins_with("PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR member=1 item=%s slot=helmet" % item.instance_id), "disabled-item rejection has stable transition context", failures)
		TestAssertions.truthy(String(result.error).contains("requested item is disabled"), "disabled-item rejection names activation failure", failures)
		TestAssertions.equal(result.state(), null, "disabled-item rejection exposes no candidate state", failures)
	TestAssertions.equal(_bytes(state), state_before, "disabled-item rejection preserves ownership", failures)
	TestAssertions.equal(party.stats_for(1), cached_before, "disabled-item rejection preserves cached stats", failures)
	TestAssertions.equal(changed, [], "disabled-item rejection emits no stat signal", failures)
	party.free()

func _test_projection_failure_is_atomic(failures: Array[String]) -> void:
	var party := _party(InvalidPreviewPartyManager.new())
	var item := _stout_helmet("item-transition-invalid", 3)
	var state := _state(item)
	var state_before := _bytes(state)
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	var result: Variant = _service.preview(
		state, 1, item.instance_id, &"helmet", party,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(result != null and not result.ok(), "invalid candidate projection is rejected", failures)
	if result != null:
		TestAssertions.truthy(String(result.error).begins_with("PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR"), "projection failure has stable transition prefix", failures)
		TestAssertions.truthy(String(result.error).contains("missing_stat"), "projection failure retains nested stat detail", failures)
	TestAssertions.equal(_bytes(state), state_before, "projection failure preserves ownership", failures)
	TestAssertions.equal(party.member_by_id(1).modifier_sources.size(), 0, "projection failure commits no source", failures)
	TestAssertions.equal(changed, [], "projection failure emits no stat signal", failures)
	party.free()

func _test_candidate_equipment_tagged_overflow_is_rejected(failures: Array[String]) -> void:
	var fighter := _class_with_action_tag(GameCatalog.load_defaults().class_by_id(&"fighter"), &"fighter_cleave", ACTION_ONLY_TAG)
	var party := _party_with_class(PartyManager.new(), fighter)
	var fixture := _tagged_equipment_fixture(&"damage", [ACTION_ONLY_TAG], 1.0e31, 10)
	var item := fixture.item as ItemInstance
	var foundation := fixture.foundation as ItemFoundationCatalog
	var state := _state(item)
	var state_before := _bytes(state)
	var cached_before := party.stats_for(1)
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	var result: Variant = _service.preview(
		state, 1, item.instance_id, &"helmet", party,
		GameCatalog.EQUIPMENT_CATALOG, foundation,
	)
	_assert_action_rejection(result, item.instance_id, &"helmet", &"fighter_cleave", "damage", "tagged equipment overflow", failures)
	TestAssertions.equal(_bytes(state), state_before, "tagged equipment rejection preserves ownership", failures)
	TestAssertions.equal(party.stats_for(1), cached_before, "tagged equipment rejection preserves cached stats", failures)
	TestAssertions.equal(party.member_by_id(1).modifier_sources.size(), 0, "tagged equipment rejection commits no source", failures)
	TestAssertions.equal(changed, [], "tagged equipment rejection emits no stat signal", failures)
	party.free()

func _test_mixed_component_and_invalid_type_actions_are_rejected(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var mixed_class := catalog.class_by_id(&"mage").duplicate(true) as ClassDefinition
	mixed_class.primary_attack = _damage_action(
		&"mixed_candidate", [&"area", &"caster", &"projectile"],
		[_component(&"fire", 10.0), _component(&"cold", 5.0)],
	)
	var mixed_party := _party_with_class(CandidateActionPartyManager.new(), mixed_class)
	mixed_party.candidate_sources.append(_overflow_source(&"cold_damage", &"cold"))
	var mixed_item := _stout_helmet("item-transition-mixed", 10)
	var mixed_result: Variant = _service.preview(
		_state(mixed_item), 1, mixed_item.instance_id, &"helmet", mixed_party,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert_action_rejection(mixed_result, mixed_item.instance_id, &"helmet", &"mixed_candidate", "cold", "mixed cold component overflow", failures)
	mixed_party.free()

	var invalid_class := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	invalid_class.primary_attack = invalid_class.primary_attack.duplicate(true) as AttackDefinition
	invalid_class.primary_attack.damage_components = [_component(&"void", 10.0)]
	var invalid_party := _party_with_class(PartyManager.new(), invalid_class)
	var invalid_item := _stout_helmet("item-transition-invalid-type", 11)
	var invalid_result: Variant = _service.preview(
		_state(invalid_item), 1, invalid_item.instance_id, &"helmet", invalid_party,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert_action_rejection(invalid_result, invalid_item.instance_id, &"helmet", invalid_class.primary_attack.id, "unknown component type", "invalid damage type", failures)
	invalid_party.free()

func _test_critical_and_rate_overflow_are_rejected(failures: Array[String]) -> void:
	for case: Dictionary in [
		{
			"modifiers": {&"damage": 1.0e200, &"crit_multiplier": 1.0e200},
			"detail": "critical",
			"label": "critical overflow",
		},
		{
			"modifiers": {&"damage": 1.0e200, &"attack_speed": 1.0e200},
			"detail": "DPS",
			"label": "action-rate overflow",
		},
		{
			"modifiers": {&"damage": 1.0e200, &"cooldown_rate": 1.0e200},
			"detail": "DPS",
			"label": "cooldown-recovery overflow",
		},
	]:
		var fighter := _class_with_action_tag(GameCatalog.load_defaults().class_by_id(&"fighter"), &"fighter_cleave", ACTION_ONLY_TAG)
		var party := _party_with_class(CandidateActionPartyManager.new(), fighter) as CandidateActionPartyManager
		party.candidate_sources.append(_finite_action_overflow_source(case.modifiers))
		var item := _stout_helmet("item-transition-%s" % String(case.label).replace(" ", "-"), 12)
		var result: Variant = _service.preview(
			_state(item), 1, item.instance_id, &"helmet", party,
			GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
		)
		_assert_action_rejection(result, item.instance_id, &"helmet", &"fighter_cleave", case.detail, case.label, failures)
		party.free()

func _test_healing_projection_validation(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := _party_with_class(CandidateActionPartyManager.new(), catalog.class_by_id(&"cleric"))
	party.candidate_sources.append(StatModifierSource.create(&"healing_candidate", &"test", "Healing Candidate", 1, [
		StatModifier.create(&"healing_power", StatModifier.Operation.INCREASED, 0.5, &"healing_candidate_roll", "Healing Candidate", [&"healing"]),
	]))
	var item := _stout_helmet("item-transition-healing", 13)
	var result: Variant = _service.preview(
		_state(item), 1, item.instance_id, &"helmet", party,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(result != null and result.ok(), "healing support action remains valid without a damage archetype estimate", failures)
	party.free()

	var overflow_cleric := _class_with_action_tag(catalog.class_by_id(&"cleric"), &"cleric_heal", ACTION_ONLY_TAG)
	var overflow_party := _party_with_class(CandidateActionPartyManager.new(), overflow_cleric)
	overflow_party.candidate_sources.append(_overflow_source(&"healing_power", ACTION_ONLY_TAG))
	var overflow_item := _stout_helmet("item-transition-healing-overflow", 131)
	var overflow_result: Variant = _service.preview(
		_state(overflow_item), 1, overflow_item.instance_id, &"helmet", overflow_party,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert_action_rejection(overflow_result, overflow_item.instance_id, &"helmet", &"cleric_heal", "healing", "healing projection overflow", failures)
	overflow_party.free()

func _test_multi_action_and_missing_primary_contract(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var multi_class := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	multi_class.support_action = _damage_action(
		&"secondary_strike", [&"melee", &"physical", &"secondary"],
		[_component(&"physical", 6.0)],
	)
	var multi_party := _party_with_class(CandidateActionPartyManager.new(), multi_class)
	multi_party.candidate_sources.append(_overflow_source(&"damage", &"secondary"))
	var multi_item := _stout_helmet("item-transition-multi", 14)
	var multi_result: Variant = _service.preview(
		_state(multi_item), 1, multi_item.instance_id, &"helmet", multi_party,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert_action_rejection(multi_result, multi_item.instance_id, &"helmet", &"secondary_strike", "damage", "secondary owned action overflow", failures)
	multi_party.free()

	var missing_class := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	missing_class.primary_attack = null
	var missing_party := _party_with_class(PartyManager.new(), missing_class)
	var missing_item := _stout_helmet("item-transition-missing-primary", 15)
	var missing_result: Variant = _service.preview(
		_state(missing_item), 1, missing_item.instance_id, &"helmet", missing_party,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(missing_result != null and not missing_result.ok(), "missing primary action rejects equipment preview", failures)
	if missing_result != null:
		TestAssertions.truthy(String(missing_result.error).contains("action=<primary>"), "missing primary rejection identifies the unavailable action", failures)
	missing_party.free()

func _test_context_commit_rejection_is_atomic(failures: Array[String]) -> void:
	var fighter := _class_with_action_tag(GameCatalog.load_defaults().class_by_id(&"fighter"), &"fighter_cleave", ACTION_ONLY_TAG)
	var party := _party_with_class(CandidateActionPartyManager.new(), fighter) as CandidateActionPartyManager
	var context := PlayerRunContext.new()
	var profile := ProfileState.new_profile("task10d-profile", "Task 10D", 1000)
	profile.inventory_columns = 1
	var configure_errors := context.configure(&"task10d-player", 0, profile, 1010, party, 100)
	TestAssertions.equal(configure_errors, PackedStringArray(), "atomic rejection fixture configures", failures)
	if not configure_errors.is_empty():
		party.free()
		return
	var issued := ItemInstanceIssuer.issue(
		"run:task10d-profile:1010:task10d-player", 0, "task_10d", 1010,
		{"affixes": [_stout_affix_document()], "base_definition_id": "forge_vanguard_helmet", "item_level": 1, "rarity_id": "common"},
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(issued.ok(), "atomic rejection fixture item issues", failures)
	if not issued.ok():
		party.free()
		return
	var create_result := context.apply_item_transaction(
		ItemTransactionRequest.create("task10d-create", "task10d-player", &"run-inventory", 0, issued.item),
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(create_result.ok(), "atomic rejection fixture item enters inventory", failures)
	party.candidate_sources.append(_overflow_source(&"damage", ACTION_ONLY_TAG))
	var actor := Node3D.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.configure(party.stats_for(1).value(&"max_health"), true, 8.0, 0.5)
	health.current_health = 42.0
	actor.add_child(health)
	TestAssertions.truthy(context.bind_actor(1, actor), "atomic rejection fixture binds runtime health", failures)
	var state_before := JSON.stringify(context.item_state().to_dictionary())
	var activation_before := context.equipment_activation(1)
	var source_bytes_before := _source_bytes(party.member_by_id(1).modifier_sources)
	var base_cache_before := party.stats_for(1)
	var action_cache_before := party.stats_for_action(1, DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack))
	var revision_before := party.stat_revision()
	var item_before := JSON.stringify(issued.item.to_dictionary())
	var class_before := JSON.stringify(party.member_by_id(1).class_definition.base_stat_overrides)
	var health_before := Vector2(health.current_health, health.max_health)
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	var result := context.assign_equipment(
		1, issued.item.instance_id, &"helmet",
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(not result.ok(), "invalid candidate action rejects before commit", failures)
	TestAssertions.truthy(result.error.contains("action=fighter_cleave"), "commit rejection retains action context", failures)
	TestAssertions.equal(JSON.stringify(context.item_state().to_dictionary()), state_before, "action rejection rolls ownership back atomically", failures)
	TestAssertions.equal(context.equipment_activation(1).active_item_ids, activation_before.active_item_ids, "action rejection preserves activation", failures)
	TestAssertions.equal(_source_bytes(party.member_by_id(1).modifier_sources), source_bytes_before, "action rejection preserves sources", failures)
	TestAssertions.equal(party.stats_for(1), base_cache_before, "action rejection preserves base cache identity", failures)
	TestAssertions.equal(party.stats_for_action(1, DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack)), action_cache_before, "action rejection preserves action cache identity", failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "action rejection preserves stat revision", failures)
	TestAssertions.equal(changed, [], "action rejection emits no stat signal", failures)
	TestAssertions.equal(JSON.stringify(issued.item.to_dictionary()), item_before, "action rejection preserves immutable item", failures)
	TestAssertions.equal(JSON.stringify(party.member_by_id(1).class_definition.base_stat_overrides), class_before, "action rejection preserves immutable class", failures)
	TestAssertions.equal(Vector2(health.current_health, health.max_health), health_before, "action rejection preserves runtime current and maximum health", failures)
	actor.free()
	party.free()

func _party(manager: PartyManager) -> PartyManager:
	var catalog := GameCatalog.load_defaults()
	return _party_with_class(manager, catalog.class_by_id(&"fighter"))

func _party_with_class(manager: PartyManager, class_definition: ClassDefinition) -> PartyManager:
	var catalog := GameCatalog.load_defaults()
	manager.initialize(class_definition, catalog.traits)
	return manager

func _class_with_action_tag(
	class_definition: ClassDefinition,
	action_id: StringName,
	action_tag: StringName,
) -> ClassDefinition:
	var owned := class_definition.duplicate(true) as ClassDefinition
	if owned.primary_attack != null and owned.primary_attack.id == action_id:
		owned.primary_attack = owned.primary_attack.duplicate(true) as AttackDefinition
		if action_tag not in owned.primary_attack.action_tags:
			owned.primary_attack.action_tags.append(action_tag)
	elif owned.support_action != null and owned.support_action.id == action_id:
		owned.support_action = owned.support_action.duplicate(true) as AttackDefinition
		if action_tag not in owned.support_action.action_tags:
			owned.support_action.action_tags.append(action_tag)
	return owned

func _state(item: ItemInstance) -> ItemOwnershipState:
	return ItemOwnershipState.create("transition-owner", ItemRegistry.new([item]), [
		ItemSlotContainer.create(INVENTORY_ID, ItemSlotContainer.RUN_INVENTORY, "transition-owner", 5, {0: item.instance_id}),
		ItemSlotContainer.create(EQUIPMENT_ID, ItemSlotContainer.RUN_MEMBER_EQUIPMENT, "transition-owner", EquipmentSlotIndex.capacity()),
	])

func _stout_helmet(instance_id: String, sequence: int) -> ItemInstance:
	var roll := ItemModifierRoll.new()
	roll.stat_id = &"constitution"
	roll.operation = StatModifier.Operation.FLAT
	roll.value = 3.0
	var affix := ItemAffixInstance.new()
	affix.definition_id = &"stout"
	affix.affix_kind = "prefix"
	affix.tier = 1
	affix.rolls = [roll]
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = &"forge_vanguard_helmet"
	item.item_level = 1
	item.rarity_id = &"common"
	item.affixes = [affix]
	item.origin = {"issuer_namespace": "transition:test", "seed": 6001, "sequence": sequence, "source": "task_6"}
	return item

func _equipment_with_requirement(base_id: StringName, attribute_id: StringName, minimum: float) -> EquipmentCatalog:
	var result := EquipmentCatalog.new()
	for definition: EquipmentBaseDefinition in GameCatalog.EQUIPMENT_CATALOG.definitions:
		var owned := definition.duplicate(true) as EquipmentBaseDefinition
		if owned.id == base_id:
			owned.attribute_requirements = {attribute_id: minimum}
		result.definitions.append(owned)
	return result

func _bytes(state: ItemOwnershipState) -> String:
	return JSON.stringify(state.to_dictionary()) if state != null else "null"

func _assert_action_rejection(
	result: Variant,
	item_id: String,
	slot_id: StringName,
	action_id: StringName,
	detail: String,
	label: String,
	failures: Array[String],
) -> void:
	TestAssertions.truthy(result != null and not result.ok(), "%s rejects equipment preview" % label, failures)
	if result == null:
		return
	var error := String(result.error)
	TestAssertions.truthy(error.begins_with("PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR member=1 item=%s slot=%s" % [item_id, slot_id]), "%s has stable transition context" % label, failures)
	TestAssertions.truthy(error.contains("action=%s" % action_id), "%s identifies the candidate action" % label, failures)
	TestAssertions.truthy(detail.to_lower() in error.to_lower(), "%s retains nested invariant detail" % label, failures)

func _overflow_source(stat_id: StringName, action_tag: StringName) -> StatModifierSource:
	var modifiers: Array[StatModifier] = []
	for index: int in 4:
		modifiers.append(StatModifier.create(
			stat_id, StatModifier.Operation.MORE, 1.0e100,
			StringName("task10d_%s_%d" % [stat_id, index]), "Task 10D Overflow", [action_tag],
		))
	return StatModifierSource.create(StringName("task10d_%s_source" % stat_id), &"test", "Task 10D Overflow", 1, modifiers)

func _finite_action_overflow_source(values: Dictionary) -> StatModifierSource:
	var modifiers: Array[StatModifier] = []
	for stat_value: Variant in values:
		var stat_id := stat_value as StringName
		modifiers.append(StatModifier.create(
			stat_id, StatModifier.Operation.FLAT, float(values[stat_id]),
			StringName("task10d_finite_%s" % stat_id), "Task 10D Finite Action Overflow", [ACTION_ONLY_TAG],
		))
	return StatModifierSource.create(&"task10d_finite_action_overflow", &"test", "Task 10D Finite Action Overflow", 1, modifiers)

func _non_action_overflow_source() -> StatModifierSource:
	var modifiers: Array[StatModifier] = []
	for index: int in 4:
		modifiers.append(StatModifier.create(
			&"max_health", StatModifier.Operation.MORE, 1.0e100,
			StringName("task10i_transition_overflow_%d" % index), "Task 10I Aggregate Overflow",
		))
	return StatModifierSource.create(&"task10i_transition_overflow", &"test", "Task 10I Aggregate Overflow", 1, modifiers)

func _damage_action(id: StringName, tags: Array[StringName], components: Array[AttackDamageComponent]) -> AttackDefinition:
	var result := AttackDefinition.new()
	result.id = id
	result.kind = AttackDefinition.Kind.AREA_PROJECTILE
	result.cooldown = 1.0
	result.range = 8.0
	result.projectile_speed = 10.0
	result.area_radius = 1.0
	result.action_tags = tags
	result.damage_components = components
	result.can_crit = true
	return result

func _component(type_id: StringName, amount: float) -> AttackDamageComponent:
	var result := AttackDamageComponent.new()
	result.damage_type_id = type_id
	result.base_amount = amount
	return result

func _tagged_equipment_fixture(stat_id: StringName, tags: Array[StringName], value: float, effect_count: int) -> Dictionary:
	var foundation := ItemFoundationCatalog.new()
	foundation.known_item_tags = GameCatalog.ITEM_FOUNDATION_CATALOG.known_item_tags.duplicate()
	for tag: StringName in tags:
		if tag not in foundation.known_item_tags:
			foundation.known_item_tags.append(tag)
	foundation.rarities = GameCatalog.ITEM_FOUNDATION_CATALOG.rarities.duplicate()
	var definition := ItemAffixDefinition.new()
	definition.id = &"task10d_tagged"
	definition.display_name = "Task 10D Tagged"
	definition.affix_kind = "prefix"
	var tier := ItemAffixTierDefinition.new()
	tier.tier = 1
	tier.minimum_item_level = 1
	var rolls: Array[ItemModifierRoll] = []
	for _index: int in effect_count:
		var effect := ItemModifierEffectDefinition.new()
		effect.stat_id = stat_id
		effect.operation = StatModifier.Operation.MORE
		effect.required_tags = tags.duplicate()
		definition.effects.append(effect)
		tier.minimum_rolls.append(value * 0.9)
		tier.maximum_rolls.append(value * 1.1)
		var roll := ItemModifierRoll.new()
		roll.stat_id = stat_id
		roll.operation = StatModifier.Operation.MORE
		roll.value = value
		roll.required_tags = tags.duplicate()
		rolls.append(roll)
	definition.tiers = [tier]
	foundation.affixes = [definition]
	var affix := ItemAffixInstance.new()
	affix.definition_id = definition.id
	affix.affix_kind = definition.affix_kind
	affix.tier = 1
	affix.rolls = rolls
	var item := ItemInstance.new()
	item.instance_id = "item-transition-tagged-equipment"
	item.base_definition_id = &"forge_vanguard_helmet"
	item.item_level = 1
	item.rarity_id = &"common"
	item.affixes = [affix]
	item.origin = {"issuer_namespace": "transition:task10d", "seed": 1010, "sequence": 0, "source": "task_10d"}
	return {"foundation": foundation, "item": item}

func _stout_affix_document() -> Dictionary:
	return {
		"definition_id": "stout",
		"affix_kind": "prefix",
		"tier": 1,
		"rolls": [{"stat_id": "constitution", "operation": StatModifier.Operation.FLAT, "value": 3.0, "required_tags": []}],
	}

func _source_bytes(sources: Array[StatModifierSource]) -> String:
	var rows: Array[Dictionary] = []
	for source: StatModifierSource in sources:
		var modifiers: Array[Dictionary] = []
		for modifier: StatModifier in source.modifiers:
			modifiers.append({
				"stat": String(modifier.stat_id),
				"operation": modifier.operation,
				"value": modifier.value,
				"source": String(modifier.source_id),
				"required": modifier.required_action_tags,
			})
		rows.append({"id": String(source.id), "type": String(source.source_type), "modifiers": modifiers})
	return JSON.stringify(rows)
