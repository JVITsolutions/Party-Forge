extends SceneTree

const MEMBER_COUNT := 24
const RUN_ID := &"task9-equipment-attribute-run"
const RUN_PLAYER_ID := &"task9_equipment_player"
const RUN_SEED := 9909
const PROFILE_ID := "task9-equipment-profile"
const SUPPORT_ITEM_ID := "task9-attribute-circlet"
const DAMAGE_ITEM_ID := "task9-fire-wand"
const SUPPORT_BASE_ID := &"emberweave_circlet"
const DAMAGE_BASE_ID := &"emberweave_wand"
const SUPPORT_SLOT_ID := &"helmet"
const DAMAGE_SLOT_ID := &"main_hand"
const REQUIRED_CONSTITUTION := 3.0
const ACTION_ONLY_TAG := &"task10d_integration_action_only"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var damage_index := _equipment_index(equipment, DAMAGE_BASE_ID)
	_assert(damage_index >= 0, "live equipment catalog contains the typed-damage base")
	if damage_index < 0:
		_finish(null, null)
		return
	var original_damage_base := equipment.definitions[damage_index]
	var required_damage_base := original_damage_base.duplicate(true) as EquipmentBaseDefinition
	required_damage_base.attribute_requirements = {&"constitution": REQUIRED_CONSTITUTION}
	equipment.definitions[damage_index] = required_damage_base

	var support_item := _item(
		SUPPORT_ITEM_ID,
		SUPPORT_BASE_ID,
		_stout_affix(),
		0,
		foundation,
	)
	var damage_item := _item(
		DAMAGE_ITEM_ID,
		DAMAGE_BASE_ID,
		_of_embers_affix(),
		1,
		foundation,
	)
	_assert(support_item != null, "attribute-support item decodes")
	_assert(damage_item != null, "typed-damage item decodes")
	if support_item == null or damage_item == null:
		equipment.definitions[damage_index] = original_damage_base
		_finish(null, null)
		return

	var initial_state := _initial_item_state([support_item, damage_item])
	_assert(initial_state.validate(equipment, foundation).is_empty(), "24-member item state validates")
	var immutable_item_bytes := _item_bytes(initial_state)
	var initial_bootstrap := RunItemBootstrap.create(
		RUN_ID,
		RUN_SEED,
		RUN_PLAYER_ID,
		1,
		initial_state,
	)
	var initial_profile := _profile("Task 9 Equipment")
	initial_profile.resumable_run = ResumableRunItemCodec.encode(initial_bootstrap)
	var party := _party()
	var context := PlayerRunContext.new()
	var configure_errors := context.configure(
		RUN_PLAYER_ID,
		0,
		initial_profile,
		RUN_SEED,
		party,
		100,
		initial_bootstrap,
	)
	_assert(configure_errors.is_empty(), "24-member equipment context configures")
	if not configure_errors.is_empty():
		equipment.definitions[damage_index] = original_damage_base
		_finish(party, null)
		return

	var mage := party.member_by_id(1).class_definition
	var action_tags := DamageResolver.action_tags_for(mage.primary_attack)
	var untouched := _capture_untouched_snapshots(party, action_tags)
	_assert(untouched.size() == MEMBER_COUNT - 1, "member 2-24 base and action snapshots are cached")
	var changed_members: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed_members.append(member_id))

	var baseline_stats := _snapshot_document(party.stats_for(1))
	var baseline_action := _estimate_document(_estimate(mage, party))
	var revision_before := party.stat_revision()
	var support_result := context.assign_equipment(1, SUPPORT_ITEM_ID, SUPPORT_SLOT_ID, equipment, foundation)
	_assert(support_result.ok(), "member one attribute gear transition succeeds")
	_assert(changed_members == [1], "attribute gear emits stats_changed only for member one")
	_assert(party.stat_revision() == revision_before + 1, "attribute gear advances the stat revision once")
	_assert_untouched_snapshots(party, action_tags, untouched, "attribute equip")
	_assert_item_bytes(context.item_state(), immutable_item_bytes, "attribute equip")
	_assert(
		party.stats_for(1).value(&"max_health") > float((baseline_stats["values"] as Dictionary)["max_health"]),
		"Constitution gear increases final maximum health",
	)

	changed_members.clear()
	revision_before = party.stat_revision()
	var damage_result := context.assign_equipment(1, DAMAGE_ITEM_ID, DAMAGE_SLOT_ID, equipment, foundation)
	_assert(damage_result.ok(), "member one typed-damage gear transition succeeds")
	_assert(changed_members == [1], "typed-damage gear emits stats_changed only for member one")
	_assert(party.stat_revision() == revision_before + 1, "typed-damage gear advances the stat revision once")
	_assert_untouched_snapshots(party, action_tags, untouched, "typed-damage equip")
	_assert_item_bytes(context.item_state(), immutable_item_bytes, "typed-damage equip")
	var active_activation := context.equipment_activation(1)
	var active_stats := _snapshot_document(party.stats_for(1))
	var active_action := _estimate_document(_estimate(mage, party))
	_assert(active_activation.active_item_ids == [SUPPORT_ITEM_ID, DAMAGE_ITEM_ID], "attribute and typed-damage items are active together")
	_assert(float(active_action["average_hit"]) > float(baseline_action["average_hit"]), "typed fire damage increases the Mage action estimate")

	changed_members.clear()
	revision_before = party.stat_revision()
	var disable_result := context.assign_equipment(1, SUPPORT_ITEM_ID, &"", equipment, foundation)
	_assert(disable_result.ok(), "removing attribute support succeeds")
	_assert(changed_members == [1], "disable transition emits stats_changed only for member one")
	_assert(party.stat_revision() == revision_before + 1, "disable transition advances the stat revision once")
	_assert_untouched_snapshots(party, action_tags, untouched, "support removal")
	_assert_item_bytes(context.item_state(), immutable_item_bytes, "support removal")
	var disabled_activation := context.equipment_activation(1)
	var expected_disabled_reasons := PackedStringArray([
		"PARTY_FORGE_EQUIPMENT_ERROR item=emberweave_wand reason=attribute constitution",
	])
	_assert(disabled_activation.active_item_ids.is_empty(), "unsupported typed-damage gear contributes no active item")
	_assert(disabled_activation.disabled_reasons(DAMAGE_ITEM_ID) == expected_disabled_reasons, "disabled gear retains its exact unmet requirement")
	var disabled_stats := _snapshot_document(party.stats_for(1))
	var disabled_action := _estimate_document(_estimate(mage, party))
	_assert(disabled_stats == baseline_stats, "disabled gear restores the exact baseline final stat document")
	_assert(disabled_action == baseline_action, "disabled gear restores the exact baseline action estimate")

	var disabled_state := context.item_state()
	var disabled_bootstrap := RunItemBootstrap.create(
		RUN_ID,
		RUN_SEED,
		RUN_PLAYER_ID,
		1,
		disabled_state,
	)
	var resume_document := ResumableRunItemCodec.encode(disabled_bootstrap)
	_assert(
		JSON.stringify(resume_document["item_state"]) == JSON.stringify(disabled_state.to_dictionary()),
		"resumable document preserves the exact serialized ownership state",
	)
	var decoded_bootstrap := ResumableRunItemCodec.decode(resume_document, equipment, foundation)
	_assert(decoded_bootstrap != null, "disabled equipment document decodes")
	if decoded_bootstrap == null:
		equipment.definitions[damage_index] = original_damage_base
		_finish(party, null)
		return
	_assert_item_bytes(decoded_bootstrap.item_state(), immutable_item_bytes, "resumable decode")

	var resumed_profile := _profile("Task 9 Resumed Equipment")
	resumed_profile.resumable_run = resume_document
	var resumed_party := _party()
	var resumed_context := PlayerRunContext.new()
	var resume_errors := resumed_context.configure(
		RUN_PLAYER_ID,
		0,
		resumed_profile,
		RUN_SEED,
		resumed_party,
		100,
		decoded_bootstrap,
	)
	_assert(resume_errors.is_empty(), "disabled 24-member run resumes")
	if not resume_errors.is_empty():
		equipment.definitions[damage_index] = original_damage_base
		_finish(party, resumed_party)
		return
	var resumed_mage := resumed_party.member_by_id(1).class_definition
	var resumed_activation := resumed_context.equipment_activation(1)
	_assert(resumed_activation.active_item_ids == disabled_activation.active_item_ids, "resume restores identical active item IDs")
	_assert(resumed_activation.disabled_reasons(DAMAGE_ITEM_ID) == expected_disabled_reasons, "resume restores identical disabled reasons")
	_assert(_snapshot_document(resumed_party.stats_for(1)) == disabled_stats, "resume restores identical disabled final stats")
	_assert(_estimate_document(_estimate(resumed_mage, resumed_party)) == disabled_action, "resume restores identical disabled action estimates")
	_assert_item_bytes(resumed_context.item_state(), immutable_item_bytes, "resume reconstruction")

	var resumed_action_tags := DamageResolver.action_tags_for(resumed_mage.primary_attack)
	var resumed_untouched := _capture_untouched_snapshots(resumed_party, resumed_action_tags)
	var resumed_changed_members: Array[int] = []
	resumed_party.stats_changed.connect(func(member_id: int) -> void: resumed_changed_members.append(member_id))
	var resumed_revision_before := resumed_party.stat_revision()
	var reactivate_result := resumed_context.assign_equipment(1, SUPPORT_ITEM_ID, SUPPORT_SLOT_ID, equipment, foundation)
	_assert(reactivate_result.ok(), "resumed attribute support re-equips")
	_assert(resumed_changed_members == [1], "reactivation emits stats_changed only for resumed member one")
	_assert(resumed_party.stat_revision() == resumed_revision_before + 1, "reactivation advances the resumed revision once")
	_assert_untouched_snapshots(resumed_party, resumed_action_tags, resumed_untouched, "resumed reactivation")
	var reactivated := resumed_context.equipment_activation(1)
	_assert(reactivated.active_item_ids == active_activation.active_item_ids, "reactivation restores identical active item IDs")
	_assert(reactivated.disabled_reasons(DAMAGE_ITEM_ID).is_empty(), "reactivation clears disabled reasons")
	_assert(_snapshot_document(resumed_party.stats_for(1)) == active_stats, "reactivation restores identical final stats")
	_assert(_estimate_document(_estimate(resumed_mage, resumed_party)) == active_action, "reactivation restores identical action estimates")
	_assert_item_bytes(resumed_context.item_state(), immutable_item_bytes, "resumed reactivation")

	var rejection_actor := Node3D.new()
	var rejection_health := HealthComponent.new()
	rejection_health.name = "HealthComponent"
	rejection_health.configure(resumed_party.stats_for(1).value(&"max_health"), true, 8.0, 0.5)
	rejection_health.current_health = 42.0
	rejection_actor.add_child(rejection_health)
	_assert(resumed_context.bind_actor(1, rejection_actor), "24-member rejection fixture binds runtime health")
	var overflow_modifiers: Array[StatModifier] = []
	for modifier_index: int in 4:
		overflow_modifiers.append(StatModifier.create(
			&"damage", StatModifier.Operation.MORE, 1.0e100,
			StringName("task10d_integration_overflow_%d" % modifier_index),
			"Task 10D Integration Overflow", [ACTION_ONLY_TAG],
		))
	var overflow_source := StatModifierSource.create(
		&"task10d_integration_overflow", &"test", "Task 10D Integration Overflow", 1, overflow_modifiers,
	)
	resumed_changed_members.clear()
	var rejection_tags := DamageResolver.action_tags_for(resumed_mage.primary_attack)
	var rejection_untouched := _capture_untouched_snapshots(resumed_party, rejection_tags)
	var rejection_state_before := JSON.stringify(resumed_context.item_state().to_dictionary())
	var rejection_activation_before := resumed_context.equipment_activation(1)
	var rejection_source_ids_before := resumed_party.member_by_id(1).modifier_sources.map(
		func(source: StatModifierSource) -> StringName: return source.id
	)
	var rejection_base_before := resumed_party.stats_for(1)
	var rejection_action_before := resumed_party.stats_for_action(1, rejection_tags)
	var rejection_revision_before := resumed_party.stat_revision()
	var rejection_health_before := Vector2(rejection_health.current_health, rejection_health.max_health)
	_assert(not resumed_party.add_member_source(1, overflow_source), "finite tagged overflow rejects the coordinated 24-member refresh")
	_assert(JSON.stringify(resumed_context.item_state().to_dictionary()) == rejection_state_before, "24-member refresh rejection preserves ownership atomically")
	_assert(resumed_context.equipment_activation(1).active_item_ids == rejection_activation_before.active_item_ids, "24-member refresh rejection preserves activation")
	_assert(resumed_party.member_by_id(1).modifier_sources.map(func(source: StatModifierSource) -> StringName: return source.id) == rejection_source_ids_before, "24-member refresh rejection preserves sources")
	_assert(is_same(resumed_party.stats_for(1), rejection_base_before), "24-member refresh rejection preserves member-one base cache identity")
	_assert(is_same(resumed_party.stats_for_action(1, rejection_tags), rejection_action_before), "24-member refresh rejection preserves member-one action cache identity")
	_assert(resumed_party.stat_revision() == rejection_revision_before, "24-member refresh rejection preserves the shared revision")
	_assert(resumed_changed_members.is_empty(), "24-member refresh rejection emits no stat signal")
	_assert(Vector2(rejection_health.current_health, rejection_health.max_health) == rejection_health_before, "24-member refresh rejection preserves current and maximum health")
	_assert_untouched_snapshots(resumed_party, rejection_tags, rejection_untouched, "invalid action refresh rejection")
	_assert_item_bytes(resumed_context.item_state(), immutable_item_bytes, "invalid action refresh rejection")

	var aggregate_modifiers: Array[StatModifier] = []
	for modifier_index: int in 4:
		aggregate_modifiers.append(StatModifier.create(
			&"max_health", StatModifier.Operation.MORE, 1.0e100,
			StringName("task10i_integration_aggregate_%d" % modifier_index),
			"Task 10I Integration Aggregate Overflow",
		))
	var aggregate_source := StatModifierSource.create(
		&"task10i_integration_aggregate", &"test", "Task 10I Integration Aggregate Overflow", 1, aggregate_modifiers,
	)
	resumed_changed_members.clear()
	_assert(not resumed_party.add_member_source(1, aggregate_source), "aggregate non-action overflow rejects the coordinated 24-member refresh")
	_assert(JSON.stringify(resumed_context.item_state().to_dictionary()) == rejection_state_before, "24-member aggregate rejection preserves ownership atomically")
	_assert(resumed_context.equipment_activation(1).active_item_ids == rejection_activation_before.active_item_ids, "24-member aggregate rejection preserves activation")
	_assert(resumed_context.equipment_activation(1).error == rejection_activation_before.error, "24-member aggregate rejection preserves activation error state")
	_assert(resumed_party.member_by_id(1).modifier_sources.map(func(source: StatModifierSource) -> StringName: return source.id) == rejection_source_ids_before, "24-member aggregate rejection preserves sources")
	_assert(is_same(resumed_party.stats_for(1), rejection_base_before), "24-member aggregate rejection preserves member-one base cache identity")
	_assert(is_same(resumed_party.stats_for_action(1, rejection_tags), rejection_action_before), "24-member aggregate rejection preserves member-one action cache identity")
	_assert(resumed_party.stat_revision() == rejection_revision_before, "24-member aggregate rejection preserves the shared revision")
	_assert(resumed_changed_members.is_empty(), "24-member aggregate rejection emits no stat signal")
	_assert(Vector2(rejection_health.current_health, rejection_health.max_health) == rejection_health_before, "24-member aggregate rejection preserves current and maximum health")
	_assert_untouched_snapshots(resumed_party, rejection_tags, rejection_untouched, "aggregate stat refresh rejection")
	_assert_item_bytes(resumed_context.item_state(), immutable_item_bytes, "aggregate stat refresh rejection")
	rejection_actor.free()

	equipment.definitions[damage_index] = original_damage_base
	_finish(party, resumed_party)


func _party() -> PartyManager:
	var catalog := GameCatalog.load_defaults()
	var mage := catalog.class_by_id(&"mage").duplicate(true) as ClassDefinition
	mage.primary_attack = mage.primary_attack.duplicate(true) as AttackDefinition
	mage.primary_attack.action_tags = mage.primary_attack.action_tags.duplicate()
	mage.primary_attack.action_tags.append(ACTION_ONLY_TAG)
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(MEMBER_COUNT))
	party.initialize(mage, catalog.traits)
	for _member_index: int in range(1, MEMBER_COUNT):
		_assert(party.recruit(mage), "24-member fixture recruits member %d" % (_member_index + 1))
	_assert(party.members.size() == MEMBER_COUNT, "developer capacity owns exactly 24 members")
	return party


func _profile(display_name: String) -> ProfileState:
	var profile := ProfileState.new_profile(PROFILE_ID, display_name, 1000)
	profile.inventory_columns = 1
	return profile


func _initial_item_state(items: Array[ItemInstance]) -> ItemOwnershipState:
	var containers: Array[ItemSlotContainer] = [
		ItemSlotContainer.create(
			&"run-inventory",
			ItemSlotContainer.RUN_INVENTORY,
			String(RUN_PLAYER_ID),
			5,
			{0: SUPPORT_ITEM_ID, 1: DAMAGE_ITEM_ID},
		),
	]
	for member_id: int in range(1, MEMBER_COUNT + 1):
		containers.append(ItemSlotContainer.create(
			StringName("run-equipment-%03d" % member_id),
			ItemSlotContainer.RUN_MEMBER_EQUIPMENT,
			String(RUN_PLAYER_ID),
			EquipmentSlotIndex.capacity(),
		))
	return ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new(items), containers)


func _item(
	instance_id: String,
	base_id: StringName,
	affix: Dictionary,
	sequence: int,
	foundation: ItemFoundationCatalog,
) -> ItemInstance:
	var decoded := ItemInstanceCodec.decode({
		"schema_version": ItemInstance.SCHEMA_VERSION,
		"instance_id": instance_id,
		"base_definition_id": String(base_id),
		"item_level": 1,
		"rarity_id": "common",
		"affixes": [affix],
		"origin": {
			"issuer_namespace": "run:%s:%d:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID],
			"seed": RUN_SEED + sequence,
			"sequence": sequence,
			"source": "task_9_equipment_attribute_application",
		},
	}, GameCatalog.EQUIPMENT_CATALOG, foundation)
	return decoded.item if decoded.ok() else null


func _stout_affix() -> Dictionary:
	return {
		"definition_id": "stout",
		"affix_kind": "prefix",
		"tier": 1,
		"rolls": [{
			"stat_id": "constitution",
			"operation": StatModifier.Operation.FLAT,
			"value": REQUIRED_CONSTITUTION,
			"required_tags": [],
		}],
	}


func _of_embers_affix() -> Dictionary:
	return {
		"definition_id": "of_embers",
		"affix_kind": "suffix",
		"tier": 1,
		"rolls": [{
			"stat_id": "fire_damage",
			"operation": StatModifier.Operation.INCREASED,
			"value": 0.1,
			"required_tags": [],
		}],
	}


func _capture_untouched_snapshots(party: PartyManager, action_tags: Array[StringName]) -> Dictionary:
	var result: Dictionary = {}
	for member_id: int in range(2, MEMBER_COUNT + 1):
		var base := party.stats_for(member_id)
		var action := party.stats_for_action(member_id, action_tags)
		result[member_id] = {
			"base": base,
			"base_revision": base.revision,
			"action": action,
			"action_revision": action.revision,
		}
	return result


func _assert_untouched_snapshots(
	party: PartyManager,
	action_tags: Array[StringName],
	before: Dictionary,
	phase: String,
) -> void:
	for member_id: int in range(2, MEMBER_COUNT + 1):
		var record := before[member_id] as Dictionary
		var base := party.stats_for(member_id)
		var action := party.stats_for_action(member_id, action_tags)
		_assert(is_same(base, record["base"]), "%s preserves member %d base snapshot identity" % [phase, member_id])
		_assert(base.revision == int(record["base_revision"]), "%s preserves member %d base snapshot revision" % [phase, member_id])
		_assert(is_same(action, record["action"]), "%s preserves member %d action snapshot identity" % [phase, member_id])
		_assert(action.revision == int(record["action_revision"]), "%s preserves member %d action snapshot revision" % [phase, member_id])


func _snapshot_document(snapshot: ResolvedStatSnapshot) -> Dictionary:
	if snapshot == null:
		return {}
	var values: Dictionary = {}
	var breakdowns: Dictionary = {}
	for definition: StatDefinition in GameCatalog.STAT_CATALOG.definitions:
		values[String(definition.id)] = snapshot.value(definition.id, definition.default_value)
		breakdowns[String(definition.id)] = snapshot.breakdown(definition.id)
	return {
		"capabilities": snapshot.capabilities,
		"values": values,
		"breakdowns": breakdowns,
	}


func _estimate(class_definition: ClassDefinition, party: PartyManager) -> ActionCombatEstimate:
	return ActionCombatEstimateService.estimate(
		class_definition.primary_attack,
		1,
		party,
		GameCatalog.DAMAGE_TYPES,
	)


func _estimate_document(estimate: ActionCombatEstimate) -> Dictionary:
	if estimate == null:
		return {}
	return {
		"action_id": String(estimate.action_id),
		"available": estimate.available,
		"unavailable_reason": estimate.unavailable_reason,
		"can_crit": estimate.can_crit,
		"normal_hit": estimate.normal_hit,
		"critical_hit": estimate.critical_hit,
		"average_hit": estimate.average_hit,
		"attacks_per_second": estimate.attacks_per_second,
		"estimated_dps": estimate.estimated_dps,
		"component_rows": estimate.component_rows.duplicate(true),
	}


func _item_bytes(state: ItemOwnershipState) -> Dictionary:
	var result: Dictionary = {}
	if state == null:
		return result
	var registry := state.registry()
	for item_id: String in registry.ids():
		result[item_id] = JSON.stringify(registry.item(item_id).to_dictionary())
	return result


func _assert_item_bytes(state: ItemOwnershipState, expected: Dictionary, phase: String) -> void:
	var actual := _item_bytes(state)
	_assert(actual.keys().size() == expected.keys().size(), "%s preserves the item record count" % phase)
	for item_id: Variant in expected:
		_assert(actual.get(item_id, "") == expected[item_id], "%s preserves item %s byte-equivalently" % [phase, item_id])


func _equipment_index(catalog: EquipmentCatalog, item_id: StringName) -> int:
	for index: int in catalog.definitions.size():
		if catalog.definitions[index] != null and catalog.definitions[index].id == item_id:
			return index
	return -1


func _finish(party: PartyManager, resumed_party: PartyManager) -> void:
	if party != null:
		party.free()
	if resumed_party != null:
		resumed_party.free()
	if _failures.is_empty():
		print("EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2")
		quit(0)
		return
	for failure: String in _failures:
		push_error("EQUIPMENT_ATTRIBUTE_APPLICATION_FAILURE: %s" % failure)
	print("EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: FAIL failures=%d" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
