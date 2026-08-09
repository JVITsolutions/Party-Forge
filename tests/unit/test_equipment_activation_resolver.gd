extends RefCounted

const RESULT_PATH := "res://scripts/equipment/equipment_activation_result.gd"
const RESOLVER_PATH := "res://scripts/equipment/equipment_activation_resolver.gd"
const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const STATS_PATH := "res://data/stats/core_stats.tres"
const CONTAINER_ID := &"member-1-equipment"

var _resolver: Script

func run() -> Array[String]:
	var failures: Array[String] = []
	_resolver = load(RESOLVER_PATH) as Script
	var result_script := load(RESULT_PATH) as Script
	TestAssertions.truthy(_resolver != null and _resolver.can_instantiate(), "equipment activation resolver script is valid", failures)
	TestAssertions.truthy(result_script != null and result_script.can_instantiate(), "equipment activation result script is valid", failures)
	if _resolver == null or not _resolver.can_instantiate() or result_script == null or not result_script.can_instantiate():
		return failures

	var equipment := _equipment_catalog()
	var foundation := (load(FOUNDATION_PATH) as ItemFoundationCatalog).duplicate(true) as ItemFoundationCatalog
	var stats := load(STATS_PATH) as StatCatalog
	TestAssertions.truthy(equipment != null and foundation != null and stats != null, "activation catalogs load", failures)
	if equipment == null or foundation == null or stats == null:
		return failures
	foundation.affixes.append(_strength_affix())

	_test_support_chain_is_fixed_point_and_deterministic(equipment, foundation, stats, failures)
	_test_self_and_mutual_bootstraps_remain_disabled(equipment, foundation, stats, failures)
	_test_removal_disables_and_restoration_reactivates(equipment, foundation, stats, failures)
	_test_result_copy_and_inputs_are_defensive(equipment, foundation, stats, failures)
	return failures

func _test_support_chain_is_fixed_point_and_deterministic(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	failures: Array[String],
) -> void:
	var support := _item("item-a-support", &"forge_vanguard_sword", [_strength_roll(2.0)], 1)
	var dependent := _item("item-b-dependent", &"forge_vanguard_helmet", [_stout_roll(3.0)], 2)
	var state := _state([dependent, support], {
		EquipmentSlotIndex.index_for(&"helmet"): dependent.instance_id,
		EquipmentSlotIndex.index_for(&"main_hand"): support.instance_id,
	})
	var result: Variant = _resolve(state, equipment, foundation, stats, {&"strength": 3.0}, 41)
	TestAssertions.truthy(result != null and result.ok(), "base-to-support-to-dependent chain resolves", failures)
	if result == null or not result.ok():
		return
	TestAssertions.equal(result.active_item_ids, ["item-a-support", "item-b-dependent"], "active identities are sorted independently of slot and registry order", failures)
	TestAssertions.truthy(result.is_active(support.instance_id), "base attributes activate support item A", failures)
	TestAssertions.truthy(result.is_active(dependent.instance_id), "item A strength activates dependent item B on a later pass", failures)
	TestAssertions.near(result.raw_attributes.value(&"strength"), 5.0, 0.0001, "final raw attributes include active support strength", failures)
	TestAssertions.equal(result.source.modifiers.size(), 2, "final source includes every affix from both active items", failures)
	TestAssertions.equal(result.disabled_reasons(dependent.instance_id), PackedStringArray(), "active dependent has no disabled reasons", failures)

	var repeated: Variant = _resolve(state, equipment, foundation, stats, {&"strength": 3.0}, 41)
	TestAssertions.truthy(repeated != null and repeated.ok(), "repeated activation resolves", failures)
	if repeated != null and repeated.ok():
		TestAssertions.equal(repeated.active_item_ids, result.active_item_ids, "repeated active ordering is deterministic", failures)
		TestAssertions.equal(_source_document(repeated.source), _source_document(result.source), "repeated final source is deterministic", failures)

func _test_self_and_mutual_bootstraps_remain_disabled(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	failures: Array[String],
) -> void:
	var self_supporting := _item("item-self", &"greenwood_boots", [_strength_roll(5.0)], 3)
	var self_state := _state([self_supporting], {
		EquipmentSlotIndex.index_for(&"boots"): self_supporting.instance_id,
	})
	var self_result: Variant = _resolve(self_state, equipment, foundation, stats, {}, 42)
	TestAssertions.truthy(self_result != null and self_result.ok(), "self-requirement state resolves without assignment failure", failures)
	if self_result != null and self_result.ok():
		TestAssertions.truthy(not self_result.is_active(self_supporting.instance_id), "item cannot satisfy its own strength requirement", failures)
		TestAssertions.equal(self_result.active_item_ids, [], "self-supporting item remains outside active set", failures)
		TestAssertions.equal(self_result.source.modifiers.size(), 0, "self-disabled item contributes no affixes", failures)
		TestAssertions.equal(self_result.disabled_reasons(self_supporting.instance_id), PackedStringArray([
			"PARTY_FORGE_EQUIPMENT_ERROR item=greenwood_boots reason=attribute dexterity",
			"PARTY_FORGE_EQUIPMENT_ERROR item=greenwood_boots reason=attribute strength",
		]), "self-disabled item exposes every unmet requirement in deterministic order", failures)

	var left := _item("item-mutual-a", &"windrunner_band", [_strength_roll(5.0)], 4)
	var right := _item("item-mutual-b", &"hawkeye_band", [_strength_roll(5.0)], 5)
	var mutual_state := _state([right, left], {
		EquipmentSlotIndex.index_for(&"ring_left"): left.instance_id,
		EquipmentSlotIndex.index_for(&"ring_right"): right.instance_id,
	})
	var mutual_result: Variant = _resolve(mutual_state, equipment, foundation, stats, {}, 43)
	TestAssertions.truthy(mutual_result != null and mutual_result.ok(), "mutual-requirement state resolves", failures)
	if mutual_result != null and mutual_result.ok():
		TestAssertions.equal(mutual_result.active_item_ids, [], "mutually dependent items cannot bootstrap", failures)
		TestAssertions.equal(mutual_result.source.modifiers.size(), 0, "mutually disabled items contribute no affixes", failures)
		TestAssertions.truthy(not mutual_result.is_active(left.instance_id) and not mutual_result.is_active(right.instance_id), "both mutual items remain disabled", failures)

func _test_removal_disables_and_restoration_reactivates(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	failures: Array[String],
) -> void:
	var support := _item("item-a-support", &"forge_vanguard_sword", [_strength_roll(2.0)], 6)
	var dependent := _item("item-b-dependent", &"forge_vanguard_helmet", [_stout_roll(3.0)], 7)
	var without_support := _state([dependent], {
		EquipmentSlotIndex.index_for(&"helmet"): dependent.instance_id,
	})
	var disabled: Variant = _resolve(without_support, equipment, foundation, stats, {&"strength": 3.0}, 44)
	TestAssertions.truthy(disabled != null and disabled.ok(), "support removal leaves a resolvable candidate", failures)
	if disabled != null and disabled.ok():
		TestAssertions.equal(disabled.active_item_ids, [], "dependent remains equipped but disabled after support removal", failures)
		TestAssertions.equal(without_support.container(CONTAINER_ID).item_id_at(EquipmentSlotIndex.index_for(&"helmet")), dependent.instance_id, "disabled dependent remains in its equipment slot", failures)
		TestAssertions.equal(disabled.source.modifiers.size(), 0, "all dependent affixes are absent while disabled", failures)
		TestAssertions.near(disabled.raw_attributes.value(&"constitution"), 0.0, 0.0001, "disabled dependent constitution affix is excluded from raw attributes", failures)

	var restored_state := _state([dependent, support], {
		EquipmentSlotIndex.index_for(&"helmet"): dependent.instance_id,
		EquipmentSlotIndex.index_for(&"main_hand"): support.instance_id,
	})
	var restored: Variant = _resolve(restored_state, equipment, foundation, stats, {&"strength": 3.0}, 45)
	TestAssertions.truthy(restored != null and restored.ok(), "restored support resolves", failures)
	if restored != null and restored.ok():
		TestAssertions.truthy(restored.is_active(dependent.instance_id), "restoring support automatically reactivates dependent", failures)
		TestAssertions.near(restored.raw_attributes.value(&"constitution"), 3.0, 0.0001, "reactivated dependent restores all affixes", failures)

func _test_result_copy_and_inputs_are_defensive(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	failures: Array[String],
) -> void:
	var support := _item("item-a-support", &"forge_vanguard_sword", [_strength_roll(2.0)], 8)
	var dependent := _item("item-b-dependent", &"forge_vanguard_helmet", [_stout_roll(3.0)], 9)
	var state := _state([dependent, support], {
		EquipmentSlotIndex.index_for(&"helmet"): dependent.instance_id,
		EquipmentSlotIndex.index_for(&"main_hand"): support.instance_id,
	})
	var state_before := var_to_bytes(state.to_dictionary())
	var support_before := JSON.stringify(support.to_dictionary())
	var dependent_before := JSON.stringify(dependent.to_dictionary())
	var equipment_before := JSON.stringify(equipment.definition(&"forge_vanguard_helmet").attribute_requirements)
	var sources: Array[StatModifierSource] = [_ordinary_source()]
	var capabilities: Array[StringName] = []
	var source_before := _source_document(sources[0])
	var result: Variant = _resolver.resolve(1, CONTAINER_ID, state, equipment, foundation, stats, {&"strength": 2.0}, capabilities, sources, 46)
	TestAssertions.truthy(result != null and result.ok(), "defensive-boundary fixture resolves", failures)
	if result == null or not result.ok():
		return
	TestAssertions.equal(var_to_bytes(state.to_dictionary()), state_before, "activation leaves ownership byte-equivalent", failures)
	TestAssertions.equal(JSON.stringify(support.to_dictionary()), support_before, "activation leaves support item immutable", failures)
	TestAssertions.equal(JSON.stringify(dependent.to_dictionary()), dependent_before, "activation leaves dependent item immutable", failures)
	TestAssertions.equal(JSON.stringify(equipment.definition(&"forge_vanguard_helmet").attribute_requirements), equipment_before, "activation leaves equipment definitions immutable", failures)
	TestAssertions.equal(_source_document(sources[0]), source_before, "activation leaves non-equipment sources immutable", failures)

	var result_copy: Variant = result.copy()
	result_copy.source.label = "escaped source"
	var escaped_breakdown: Array[Dictionary] = []
	result_copy.raw_attributes.set_resolved(&"strength", 999.0, escaped_breakdown)
	var escaped_ids: Array[String] = result_copy.active_item_ids
	escaped_ids.clear()
	TestAssertions.equal(result.source.label, "Equipment", "copy source mutation cannot reach original result", failures)
	TestAssertions.near(result.raw_attributes.value(&"strength"), 5.0, 0.0001, "copy raw snapshot mutation cannot reach original result", failures)
	TestAssertions.equal(result.active_item_ids, ["item-a-support", "item-b-dependent"], "copy active IDs cannot reach original result", failures)

func _resolve(
	state: ItemOwnershipState,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	base_values: Dictionary,
	revision: int,
) -> Variant:
	var sources: Array[StatModifierSource] = []
	var capabilities: Array[StringName] = []
	return _resolver.resolve(1, CONTAINER_ID, state, equipment, foundation, stats, base_values, capabilities, sources, revision)

func _equipment_catalog() -> EquipmentCatalog:
	var requirements := {
		&"forge_vanguard_sword": {&"strength": 3.0},
		&"forge_vanguard_helmet": {&"strength": 5.0},
		&"greenwood_boots": {&"strength": 5.0, &"dexterity": 4.0},
		&"windrunner_band": {&"strength": 5.0},
		&"hawkeye_band": {&"strength": 5.0},
	}
	var catalog := EquipmentCatalog.new()
	for definition: EquipmentBaseDefinition in (load(EQUIPMENT_PATH) as EquipmentCatalog).definitions:
		var owned := definition.duplicate(true) as EquipmentBaseDefinition
		if requirements.has(owned.id):
			owned.attribute_requirements = (requirements[owned.id] as Dictionary).duplicate(true)
		catalog.definitions.append(owned)
	return catalog

func _strength_affix() -> ItemAffixDefinition:
	var effect := ItemModifierEffectDefinition.new()
	effect.stat_id = &"strength"
	effect.operation = StatModifier.Operation.FLAT
	var tier := ItemAffixTierDefinition.new()
	tier.tier = 1
	tier.minimum_item_level = 1
	tier.minimum_rolls = [2.0]
	tier.maximum_rolls = [5.0]
	var definition := ItemAffixDefinition.new()
	definition.id = &"task5_strength"
	definition.display_name = "Task 5 Strength"
	definition.affix_kind = "special"
	definition.modifier_family_ids = [&"task5_strength_family"]
	definition.effects = [effect]
	definition.tiers = [tier]
	return definition

func _strength_roll(value: float) -> ItemAffixInstance:
	return _affix(&"task5_strength", "special", &"strength", value)

func _stout_roll(value: float) -> ItemAffixInstance:
	return _affix(&"stout", "prefix", &"constitution", value)

func _affix(definition_id: StringName, kind: String, stat_id: StringName, value: float) -> ItemAffixInstance:
	var roll := ItemModifierRoll.new()
	roll.stat_id = stat_id
	roll.operation = StatModifier.Operation.FLAT
	roll.value = value
	var affix := ItemAffixInstance.new()
	affix.definition_id = definition_id
	affix.affix_kind = kind
	affix.tier = 1
	affix.rolls = [roll]
	return affix

func _item(instance_id: String, base_id: StringName, affixes: Array[ItemAffixInstance], sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 1
	item.rarity_id = &"common"
	item.affixes = affixes
	item.origin = {"issuer_namespace": "activation:test", "seed": 505, "sequence": sequence, "source": "task_5"}
	return item

func _state(items: Array[ItemInstance], slots: Dictionary) -> ItemOwnershipState:
	var container := ItemSlotContainer.create(
		CONTAINER_ID,
		ItemSlotContainer.RUN_MEMBER_EQUIPMENT,
		"run-player-1",
		EquipmentSlotIndex.capacity(),
		slots,
	)
	return ItemOwnershipState.create("run-player-1", ItemRegistry.new(items), [container])

func _ordinary_source() -> StatModifierSource:
	return StatModifierSource.create(&"ordinary_strength", &"growth", "Growth", 1, [
		StatModifier.create(&"strength", StatModifier.Operation.FLAT, 1.0, &"ordinary_strength_modifier", "Growth"),
	])

func _source_document(source: StatModifierSource) -> Dictionary:
	var modifiers: Array[Dictionary] = []
	for modifier: StatModifier in source.modifiers:
		modifiers.append({
			"operation": modifier.operation,
			"required_tags": modifier.required_tags.duplicate(),
			"source_id": String(modifier.source_id),
			"source_label": modifier.source_label,
			"stat_id": String(modifier.stat_id),
			"value": modifier.value,
		})
	return {
		"id": String(source.id),
		"label": source.label,
		"modifiers": modifiers,
		"owner_member_id": source.owner_member_id,
		"source_type": String(source.source_type),
	}
