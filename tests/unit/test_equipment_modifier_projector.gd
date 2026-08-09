extends RefCounted

const PROJECTOR_PATH := "res://scripts/equipment/equipment_modifier_projector.gd"
const PROJECTION_PATH := "res://scripts/equipment/equipment_modifier_projection.gd"
const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const STATS_PATH := "res://data/stats/core_stats.tres"
const CONTAINER_ID := &"member-1-equipment"

var _projector: Script

func run() -> Array[String]:
	var failures: Array[String] = []
	_projector = load(PROJECTOR_PATH) as Script
	var projection_script := load(PROJECTION_PATH) as Script
	TestAssertions.truthy(_projector != null and _projector.can_instantiate(), "equipment modifier projector script is valid", failures)
	TestAssertions.truthy(projection_script != null and projection_script.can_instantiate(), "equipment modifier projection script is valid", failures)
	if _projector == null or not _projector.can_instantiate() or projection_script == null or not projection_script.can_instantiate():
		return failures

	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var foundation := (load(FOUNDATION_PATH) as ItemFoundationCatalog).duplicate(true) as ItemFoundationCatalog
	var stats := load(STATS_PATH) as StatCatalog
	TestAssertions.truthy(equipment != null and foundation != null and stats != null, "projection catalogs load", failures)
	if equipment == null or foundation == null or stats == null:
		return failures
	foundation.affixes.append(_tagged_melee_affix())

	_test_active_projection_is_deterministic_and_immutable(equipment, foundation, stats, failures)
	_test_empty_active_set_returns_uniform_source(equipment, foundation, stats, failures)
	_test_all_modifier_operations_project(equipment, foundation, stats, failures)
	_test_invalid_rolls_fail_atomically(equipment, foundation, stats, failures)
	_test_invalid_inputs_fail_atomically(equipment, foundation, stats, failures)
	return failures

func _test_active_projection_is_deterministic_and_immutable(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	failures: Array[String],
) -> void:
	var active_item := _active_item()
	var inactive_item := _inactive_item()
	var state := _state([active_item, inactive_item], {
		EquipmentSlotIndex.index_for(&"helmet"): inactive_item.instance_id,
		EquipmentSlotIndex.index_for(&"main_hand"): active_item.instance_id,
	})
	var active_ids: Array[String] = [active_item.instance_id]
	var state_before := var_to_bytes(state.to_dictionary())
	var active_item_before := JSON.stringify(active_item.to_dictionary())
	var inactive_item_before := JSON.stringify(inactive_item.to_dictionary())
	var active_ids_before := active_ids.duplicate()

	var projection: Variant = _projector.project(1, CONTAINER_ID, state, active_ids, equipment, foundation, stats)
	if projection != null:
		TestAssertions.equal(projection.error, "", "valid active projection has no diagnostic", failures)
	TestAssertions.truthy(projection != null and projection.ok(), "active equipment rolls project", failures)
	if projection == null or not projection.ok():
		return
	TestAssertions.equal(projection.error, "", "successful projection has no error", failures)
	TestAssertions.equal(projection.source.id, &"equipment_member_1", "equipment source identity is stable", failures)
	TestAssertions.equal(projection.source.source_type, &"equipment", "equipment source type is canonical", failures)
	TestAssertions.equal(projection.source.label, "Equipment", "equipment source label is canonical", failures)
	TestAssertions.equal(projection.source.owner_member_id, 1, "equipment source belongs to member", failures)
	TestAssertions.equal(projection.source.modifiers.size(), 4, "every active roll appears exactly once", failures)

	var expected_ids: Array[String] = []
	for affix_index: int in active_item.affixes.size():
		var affix := active_item.affixes[affix_index]
		var expected := "equip_m1_smain_hand_i%s_a%d_%s_r0" % [active_item.instance_id, affix_index, affix.definition_id]
		expected_ids.append(expected)
		var modifier := projection.source.modifiers[affix_index] as StatModifier
		TestAssertions.equal(String(modifier.source_id), expected, "equipment modifier identity %d is stable" % affix_index, failures)
	var actual_ids: Array[String] = []
	for modifier: StatModifier in projection.source.modifiers:
		actual_ids.append(String(modifier.source_id))
	TestAssertions.equal(actual_ids, expected_ids, "modifier order follows slot, affix, and roll order", failures)
	TestAssertions.equal(projection.source.modifiers[0].source_label, "Forge Vanguard Sword — Tempered Edge", "implicit label is stable", failures)
	TestAssertions.equal(projection.source.modifiers[1].source_label, "Forge Vanguard Sword — Stout", "prefix label is stable", failures)
	TestAssertions.equal(projection.source.modifiers[2].source_label, "Forge Vanguard Sword — of Rime", "suffix label is stable", failures)
	TestAssertions.equal(projection.source.modifiers[3].source_label, "Forge Vanguard Sword — Battle Rhythm", "tagged roll label is stable", failures)
	TestAssertions.equal(projection.source.modifiers[3].required_tags, [&"melee"], "tagged melee roll preserves its required tag", failures)
	TestAssertions.truthy(actual_ids.all(func(id: String) -> bool: return inactive_item.instance_id not in id), "inactive item IDs contribute nothing", failures)

	TestAssertions.equal(var_to_bytes(state.to_dictionary()), state_before, "ownership state is byte-equivalent after projection", failures)
	TestAssertions.equal(JSON.stringify(active_item.to_dictionary()), active_item_before, "active caller item is byte-equivalent after projection", failures)
	TestAssertions.equal(JSON.stringify(inactive_item.to_dictionary()), inactive_item_before, "inactive caller item is byte-equivalent after projection", failures)
	TestAssertions.equal(active_ids, active_ids_before, "active ID input is unchanged", failures)

	var repeated: Variant = _projector.project(1, CONTAINER_ID, state, active_ids, equipment, foundation, stats)
	TestAssertions.truthy(repeated != null and repeated.ok(), "repeated projection succeeds", failures)
	if repeated != null and repeated.ok():
		TestAssertions.equal(_source_document(repeated.source), _source_document(projection.source), "identical input projects deterministic source content", failures)

func _test_empty_active_set_returns_uniform_source(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	failures: Array[String],
) -> void:
	var item := _active_item()
	var state := _state([item], {EquipmentSlotIndex.index_for(&"main_hand"): item.instance_id})
	var no_active_items: Array[String] = []
	var projection: Variant = _projector.project(7, CONTAINER_ID, state, no_active_items, equipment, foundation, stats)
	TestAssertions.truthy(projection != null and projection.ok(), "empty active set projects", failures)
	if projection != null and projection.ok():
		TestAssertions.equal(projection.source.id, &"equipment_member_7", "empty active set retains replaceable member source", failures)
		TestAssertions.equal(projection.source.modifiers.size(), 0, "empty active set has no modifiers", failures)

func _test_all_modifier_operations_project(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	failures: Array[String],
) -> void:
	var operation_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var operations: Array[int] = [
		StatModifier.Operation.FLAT,
		StatModifier.Operation.INCREASED,
		StatModifier.Operation.REDUCED,
		StatModifier.Operation.MORE,
		StatModifier.Operation.LESS,
	]
	operation_foundation.affixes.append(_operation_matrix_affix(operations))
	var item := _item("item-operation-matrix", &"forge_vanguard_sword", [
		_affix(&"operation_matrix", "special", 1, _rolls_for_operations(operations)),
	], 20)
	var state := _state([item], {EquipmentSlotIndex.index_for(&"main_hand"): item.instance_id})
	var active_ids: Array[String] = [item.instance_id]
	var projection: Variant = _projector.project(3, CONTAINER_ID, state, active_ids, equipment, operation_foundation, stats)
	if projection != null:
		TestAssertions.equal(projection.error, "", "operation projection has no diagnostic", failures)
	TestAssertions.truthy(projection != null and projection.ok(), "all supported modifier operations project", failures)
	if projection != null and projection.ok():
		var actual: Array[int] = []
		for modifier: StatModifier in projection.source.modifiers:
			actual.append(modifier.operation)
		TestAssertions.equal(actual, operations, "flat, increased, reduced, more, and less remain exact", failures)

func _test_invalid_rolls_fail_atomically(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	failures: Array[String],
) -> void:
	var non_finite := _active_item()
	non_finite.affixes[1].rolls[0].value = NAN
	_assert_projection_error(
		_state([non_finite], {EquipmentSlotIndex.index_for(&"main_hand"): non_finite.instance_id}),
		[non_finite.instance_id], equipment, foundation, stats,
		"PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=1 slot=main_hand item=item-active affix=stout roll=0 stat=constitution reason=non-finite value",
		"non-finite roll", failures,
	)

	var unsupported_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var unsupported_definition := unsupported_foundation.affix(&"melee_focus").duplicate(true) as ItemAffixDefinition
	unsupported_definition.effects[0] = unsupported_definition.effects[0].duplicate(true) as ItemModifierEffectDefinition
	unsupported_definition.effects[0].operation = 99
	unsupported_foundation.affixes[unsupported_foundation.affixes.find(unsupported_foundation.affix(&"melee_focus"))] = unsupported_definition
	var unsupported := _active_item()
	unsupported.affixes[3].rolls[0].operation = 99
	_assert_projection_error(
		_state([unsupported], {EquipmentSlotIndex.index_for(&"main_hand"): unsupported.instance_id}),
		[unsupported.instance_id], equipment, unsupported_foundation, stats,
		"PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=1 slot=main_hand item=item-active affix=melee_focus roll=0 stat=attack_speed reason=unsupported operation 99",
		"unsupported operation", failures,
	)

	var unknown_stat_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var unknown_definition := unknown_stat_foundation.affix(&"melee_focus").duplicate(true) as ItemAffixDefinition
	unknown_definition.effects[0] = unknown_definition.effects[0].duplicate(true) as ItemModifierEffectDefinition
	unknown_definition.effects[0].stat_id = &"missing_equipment_stat"
	unknown_stat_foundation.affixes[unknown_stat_foundation.affixes.find(unknown_stat_foundation.affix(&"melee_focus"))] = unknown_definition
	var unknown_stat := _active_item()
	unknown_stat.affixes[3].rolls[0].stat_id = &"missing_equipment_stat"
	_assert_projection_error(
		_state([unknown_stat], {EquipmentSlotIndex.index_for(&"main_hand"): unknown_stat.instance_id}),
		[unknown_stat.instance_id], equipment, unknown_stat_foundation, stats,
		"PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=1 slot=main_hand item=item-active affix=melee_focus roll=0 stat=missing_equipment_stat reason=unknown stat",
		"unknown stat", failures,
	)

	var empty_tag_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var empty_tag_definition := empty_tag_foundation.affix(&"melee_focus").duplicate(true) as ItemAffixDefinition
	empty_tag_definition.effects[0] = empty_tag_definition.effects[0].duplicate(true) as ItemModifierEffectDefinition
	empty_tag_definition.effects[0].required_tags = [&""]
	empty_tag_foundation.affixes[empty_tag_foundation.affixes.find(empty_tag_foundation.affix(&"melee_focus"))] = empty_tag_definition
	var empty_tag := _active_item()
	empty_tag.affixes[3].rolls[0].required_tags = [&""]
	_assert_projection_error(
		_state([empty_tag], {EquipmentSlotIndex.index_for(&"main_hand"): empty_tag.instance_id}),
		[empty_tag.instance_id], equipment, empty_tag_foundation, stats,
		"PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=1 slot=main_hand item=item-active affix=melee_focus roll=0 stat=attack_speed reason=empty required tag",
		"empty required tag", failures,
	)

func _test_invalid_inputs_fail_atomically(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	failures: Array[String],
) -> void:
	var active_ids: Array[String] = ["missing-item"]
	_assert_projection_error(null, active_ids, equipment, foundation, stats,
		"PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=1 slot=<none> item=<none> affix=<none> roll=<none> stat=<none> reason=ownership state is null",
		"missing ownership state", failures)
	var item := _active_item()
	var state := _state([item], {EquipmentSlotIndex.index_for(&"main_hand"): item.instance_id})
	_assert_projection_error(state, [item.instance_id, item.instance_id], equipment, foundation, stats,
		"PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=1 slot=<none> item=item-active affix=<none> roll=<none> stat=<none> reason=duplicate active item id",
		"duplicate active identity", failures)
	_assert_projection_error(state, ["missing-item"], equipment, foundation, stats,
		"PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=1 slot=<none> item=missing-item affix=<none> roll=<none> stat=<none> reason=active item is not equipped in container member-1-equipment",
		"unknown active identity", failures)
	var duplicate_reference_state := _state([item], {
		EquipmentSlotIndex.index_for(&"main_hand"): item.instance_id,
		EquipmentSlotIndex.index_for(&"off_hand"): item.instance_id,
	})
	_assert_projection_error(duplicate_reference_state, [item.instance_id], equipment, foundation, stats,
		"PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=1 slot=<none> item=item-active affix=<none> roll=<none> stat=<none> reason=active item is equipped 2 times in container member-1-equipment",
		"duplicate equipped reference", failures)
	_assert_projection_error(state, [item.instance_id], equipment, foundation, null,
		"PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=1 slot=<none> item=<none> affix=<none> roll=<none> stat=<none> reason=stat catalog is null",
		"missing stat catalog", failures)

func _assert_projection_error(
	state: ItemOwnershipState,
	active_ids_value: Array,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	expected_error: String,
	label: String,
	failures: Array[String],
) -> void:
	var active_ids: Array[String] = []
	for value: Variant in active_ids_value:
		active_ids.append(String(value))
	var before: Variant = var_to_bytes(state.to_dictionary()) if state != null else "<null>"
	var result: Variant = _projector.project(1, CONTAINER_ID, state, active_ids, equipment, foundation, stats)
	TestAssertions.truthy(result != null and not result.ok(), "%s is rejected" % label, failures)
	if result == null:
		return
	TestAssertions.equal(result.source, null, "%s exposes no partial source" % label, failures)
	TestAssertions.equal(result.error, expected_error, "%s has a stable error" % label, failures)
	if state != null:
		TestAssertions.equal(var_to_bytes(state.to_dictionary()), before, "%s leaves ownership byte-equivalent" % label, failures)

func _active_item() -> ItemInstance:
	return _item("item-active", &"forge_vanguard_sword", [
		_affix(&"tempered_edge", "implicit", 1, [_roll(&"physical_damage", StatModifier.Operation.INCREASED, 0.08)]),
		_affix(&"stout", "prefix", 1, [_roll(&"constitution", StatModifier.Operation.FLAT, 2.0)]),
		_affix(&"of_rime", "suffix", 1, [_roll(&"cold_damage", StatModifier.Operation.INCREASED, 0.07)]),
		_affix(&"melee_focus", "special", 1, [_roll(&"attack_speed", StatModifier.Operation.INCREASED, 0.05, [&"melee"])]),
	], 10)

func _inactive_item() -> ItemInstance:
	return _item("item-inactive", &"forge_vanguard_helmet", [
		_affix(&"stout", "prefix", 1, [_roll(&"constitution", StatModifier.Operation.FLAT, 3.0)]),
	], 11)

func _item(instance_id: String, base_id: StringName, affixes: Array[ItemAffixInstance], sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 1
	item.rarity_id = &"epic"
	item.affixes = affixes
	item.origin = {"issuer_namespace": "projection:test", "seed": 404, "sequence": sequence, "source": "task_4"}
	return item

func _affix(definition_id: StringName, kind: String, tier: int, rolls: Array[ItemModifierRoll]) -> ItemAffixInstance:
	var affix := ItemAffixInstance.new()
	affix.definition_id = definition_id
	affix.affix_kind = kind
	affix.tier = tier
	affix.rolls = rolls
	return affix

func _roll(stat_id: StringName, operation: int, value: float, tags: Array[StringName] = []) -> ItemModifierRoll:
	var roll := ItemModifierRoll.new()
	roll.stat_id = stat_id
	roll.operation = operation
	roll.value = value
	roll.required_tags = tags.duplicate()
	return roll

func _tagged_melee_affix() -> ItemAffixDefinition:
	var effect := ItemModifierEffectDefinition.new()
	effect.stat_id = &"attack_speed"
	effect.operation = StatModifier.Operation.INCREASED
	effect.required_tags = [&"melee"]
	var definition := _definition(&"melee_focus", "Battle Rhythm", "special", [effect], [0.04], [0.06])
	return definition

func _operation_matrix_affix(operations: Array[int]) -> ItemAffixDefinition:
	var effects: Array[ItemModifierEffectDefinition] = []
	var minimums: Array[float] = []
	var maximums: Array[float] = []
	for index: int in operations.size():
		var effect := ItemModifierEffectDefinition.new()
		effect.stat_id = &"damage"
		effect.operation = operations[index]
		effects.append(effect)
		minimums.append(0.01 * float(index + 1) - 0.001)
		maximums.append(0.01 * float(index + 1) + 0.001)
	return _definition(&"operation_matrix", "Operation Matrix", "special", effects, minimums, maximums)

func _definition(
	id: StringName,
	display_name: String,
	kind: String,
	effects: Array[ItemModifierEffectDefinition],
	minimums: Array[float],
	maximums: Array[float],
) -> ItemAffixDefinition:
	var tier := ItemAffixTierDefinition.new()
	tier.tier = 1
	tier.minimum_item_level = 1
	tier.minimum_rolls = minimums
	tier.maximum_rolls = maximums
	var definition := ItemAffixDefinition.new()
	definition.id = id
	definition.display_name = display_name
	definition.affix_kind = kind
	definition.modifier_family_ids = [StringName("fixture_%s" % id)]
	definition.effects = effects
	definition.tiers = [tier]
	return definition

func _rolls_for_operations(operations: Array[int]) -> Array[ItemModifierRoll]:
	var rolls: Array[ItemModifierRoll] = []
	for index: int in operations.size():
		rolls.append(_roll(&"damage", operations[index], 0.01 * float(index + 1)))
	return rolls

func _state(items: Array[ItemInstance], slots: Dictionary) -> ItemOwnershipState:
	var container := ItemSlotContainer.create(
		CONTAINER_ID,
		ItemSlotContainer.RUN_MEMBER_EQUIPMENT,
		"run-player-1",
		EquipmentSlotIndex.capacity(),
		slots,
	)
	return ItemOwnershipState.create("run-player-1", ItemRegistry.new(items), [container])

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
