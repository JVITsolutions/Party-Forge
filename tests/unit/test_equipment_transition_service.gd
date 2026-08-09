extends RefCounted

const RESULT_PATH := "res://scripts/equipment/equipment_transition_result.gd"
const SERVICE_PATH := "res://scripts/equipment/equipment_transition_service.gd"
const INVENTORY_ID := &"run-inventory"
const EQUIPMENT_ID := &"run-equipment-001"

class InvalidPreviewPartyManager extends PartyManager:
	func member_sources_without_equipment(member_id: int) -> Array[StatModifierSource]:
		var result := super.member_sources_without_equipment(member_id)
		result.append(StatModifierSource.create(&"invalid_preview", &"growth", "Invalid Preview", member_id, [
			StatModifier.create(&"missing_stat", StatModifier.Operation.FLAT, 1.0, &"invalid_preview_roll", "Invalid Preview"),
		]))
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

func _party(manager: PartyManager) -> PartyManager:
	var catalog := GameCatalog.load_defaults()
	manager.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	return manager

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
