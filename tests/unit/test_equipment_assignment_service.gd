extends RefCounted

const INVENTORY_ID := &"run-inventory"

var _parties: Array[PartyManager] = []

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_compatible_armour_and_exact_unequip(failures)
	_test_failures_are_atomic_and_diagnostic(failures)
	_test_two_hand_and_quiver_rules(failures)
	_test_result_and_service_boundaries_are_defensive(failures)
	for party: PartyManager in _parties:
		party.free()
	_parties.clear()
	return failures

func _test_compatible_armour_and_exact_unequip(failures: Array[String]) -> void:
	var fixture := _fixture(&"ranger", 8101, 8)
	var context := fixture.context as PlayerRunContext
	var item := _issue_into(context, 0, 0, &"greenwood_jerkin", GameCatalog.EQUIPMENT_CATALOG, failures)
	if item == null:
		return
	var equipped := context.assign_equipment(1, item.instance_id, &"body_armour", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(equipped.ok(), "compatible armour equips", failures)
	TestAssertions.equal(context.run_inventory().item_id_at(0), "", "equip clears the exact inventory source", failures)
	TestAssertions.equal(context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"body_armour")), item.instance_id, "equip moves the exact instance into the canonical slot", failures)
	var unequipped := context.assign_equipment(1, item.instance_id, &"", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(unequipped.ok(), "empty slot request unequips", failures)
	TestAssertions.equal(context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"body_armour")), "", "unequip clears the exact equipment slot", failures)
	TestAssertions.equal(context.run_inventory().item_id_at(0), item.instance_id, "unequip returns the exact instance to the first inventory vacancy", failures)

func _test_failures_are_atomic_and_diagnostic(failures: Array[String]) -> void:
	var fixture := _fixture(&"ranger", 8201, 8)
	var context := fixture.context as PlayerRunContext
	var compatible := _issue_into(context, 0, 0, &"greenwood_jerkin", GameCatalog.EQUIPMENT_CATALOG, failures)
	var incompatible := _issue_into(context, 1, 1, &"dawn_bulwark_plate", GameCatalog.EQUIPMENT_CATALOG, failures)
	var first_ring := _issue_into(context, 2, 2, &"windrunner_band", GameCatalog.EQUIPMENT_CATALOG, failures)
	var second_ring := _issue_into(context, 3, 3, &"hawkeye_band", GameCatalog.EQUIPMENT_CATALOG, failures)
	if compatible == null or incompatible == null or first_ring == null or second_ring == null:
		return
	_assert_assignment_failure(context, 1, incompatible.instance_id, &"body_armour", GameCatalog.EQUIPMENT_CATALOG, "incompatible weight", failures)
	_assert_assignment_failure(context, 99, compatible.instance_id, &"body_armour", GameCatalog.EQUIPMENT_CATALOG, "unknown member", failures)
	_assert_assignment_failure(context, 1, "missing-instance", &"body_armour", GameCatalog.EQUIPMENT_CATALOG, "unknown item", failures)
	_assert_assignment_failure(context, 1, compatible.instance_id, &"unknown", GameCatalog.EQUIPMENT_CATALOG, "unknown slot", failures)
	TestAssertions.truthy(context.assign_equipment(1, first_ring.instance_id, &"ring_left", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).ok(), "first ring occupies destination", failures)
	_assert_assignment_failure(context, 1, second_ring.instance_id, &"ring_left", GameCatalog.EQUIPMENT_CATALOG, "occupied destination", failures)

	var attribute_catalog := _catalog_with_attribute_requirement(&"greenwood_boots", &"strength", 999.0)
	var attribute_item := _issue_into(context, 4, 4, &"greenwood_boots", attribute_catalog, failures)
	if attribute_item != null:
		var before := _bytes(context.item_state())
		var class_definition := (fixture.party as PartyManager).member_by_id(1).class_definition
		var class_before: Array[StringName] = class_definition.normalized_eligibility_tags()
		var structural_preview := EquipmentAssignmentService.new().preview(
			context.item_state(), 1, attribute_item.instance_id, &"boots", attribute_catalog,
			GameCatalog.ITEM_FOUNDATION_CATALOG, class_definition, {},
		)
		TestAssertions.truthy(structural_preview.ok(), "assignment preview leaves attribute activation to the transition layer", failures)
		TestAssertions.equal(_bytes(context.item_state()), before, "structural attribute preview remains pure", failures)
		TestAssertions.equal(class_definition.normalized_eligibility_tags(), class_before, "structural preview leaves class resources unchanged", failures)
		var legacy_errors := EquipmentEligibility.validate_equip(
			attribute_catalog.definition(&"greenwood_boots"), class_definition,
			&"boots", {}, {},
		)
		TestAssertions.truthy(not legacy_errors.is_empty(), "legacy equip validation still reports unmet attributes", failures)

func _test_two_hand_and_quiver_rules(failures: Array[String]) -> void:
	var fixture := _fixture(&"marksman", 8301, 8)
	var context := fixture.context as PlayerRunContext
	var equipment := _catalog_with_required_tags(&"dawn_bulwark_shield", [&"martial"])
	var bow := _issue_into(context, 0, 0, &"greenwood_recurve_bow", equipment, failures)
	var matching := _issue_into(context, 1, 1, &"greenwood_light_quiver", equipment, failures)
	var mismatching := _issue_into(context, 2, 2, &"siege_heavy_quiver", equipment, failures)
	var shield := _issue_into(context, 3, 3, &"dawn_bulwark_shield", equipment, failures)
	if bow == null or matching == null or mismatching == null or shield == null:
		return
	TestAssertions.truthy(context.assign_equipment(1, shield.instance_id, &"off_hand", equipment, GameCatalog.ITEM_FOUNDATION_CATALOG).ok(), "ordinary offhand equips before a reserved main hand", failures)
	_assert_assignment_failure(context, 1, bow.instance_id, &"main_hand", equipment, "two-hand occupied offhand", failures)
	TestAssertions.truthy(context.assign_equipment(1, shield.instance_id, &"", equipment, GameCatalog.ITEM_FOUNDATION_CATALOG).ok(), "shield unequips before bow", failures)
	TestAssertions.truthy(context.assign_equipment(1, bow.instance_id, &"main_hand", equipment, GameCatalog.ITEM_FOUNDATION_CATALOG).ok(), "two-hand bow equips with vacant reserved slot", failures)
	_assert_assignment_failure(context, 1, mismatching.instance_id, &"off_hand", equipment, "mismatching quiver", failures)
	TestAssertions.truthy(context.assign_equipment(1, matching.instance_id, &"off_hand", equipment, GameCatalog.ITEM_FOUNDATION_CATALOG).ok(), "matching quiver is the reserved-slot exception", failures)
	_assert_assignment_failure(context, 1, bow.instance_id, &"", equipment, "orphaned quiver", failures)
	TestAssertions.truthy(context.assign_equipment(1, matching.instance_id, &"", equipment, GameCatalog.ITEM_FOUNDATION_CATALOG).ok(), "matching quiver unequips", failures)
	TestAssertions.truthy(context.assign_equipment(1, bow.instance_id, &"", equipment, GameCatalog.ITEM_FOUNDATION_CATALOG).ok(), "bow unequips after reserved slot is clear", failures)

func _test_result_and_service_boundaries_are_defensive(failures: Array[String]) -> void:
	var fixture := _fixture(&"ranger", 8401, 8)
	var context := fixture.context as PlayerRunContext
	var item := _issue_into(context, 0, 0, &"greenwood_jerkin", GameCatalog.EQUIPMENT_CATALOG, failures)
	if item == null:
		return
	var before := _bytes(context.item_state())
	var service := EquipmentAssignmentService.new()
	var attributes := _attributes(fixture.party.stats_for(1))
	var missing_class := service.preview(context.item_state(), 1, item.instance_id, &"body_armour", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(not missing_class.ok(), "six-argument preview rejects missing class input", failures)
	TestAssertions.equal(missing_class.error, "PARTY_FORGE_EQUIPMENT_ASSIGNMENT_ERROR member=1 reason=class missing", "missing-class preview diagnostic is stable", failures)
	var preview := service.preview(context.item_state(), 1, item.instance_id, &"body_armour", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, fixture.party.member_by_id(1).class_definition, attributes)
	TestAssertions.truthy(preview.ok(), "pure service preview succeeds", failures)
	TestAssertions.equal(_bytes(context.item_state()), before, "pure preview cannot mutate context input", failures)
	var exposed_state := preview.state()
	exposed_state.owner_id = "escaped-owner"
	exposed_state._clear_slot(INVENTORY_ID, 0)
	TestAssertions.equal(preview.state().owner_id, String(context.run_player_id), "result state getter isolates owner", failures)
	TestAssertions.equal(preview.state().container(INVENTORY_ID).item_id_at(0), "", "result retains its independent successful candidate", failures)
	TestAssertions.equal(_bytes(context.item_state()), before, "mutating result state cannot reach context", failures)
	var committed := context.assign_equipment(1, item.instance_id, &"body_armour", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	var committed_bytes := _bytes(context.item_state())
	var committed_state := committed.state()
	committed_state.owner_id = "escaped-committed-owner"
	committed_state._clear_slot(StringName("run-equipment-001"), EquipmentSlotIndex.index_for(&"body_armour"))
	TestAssertions.equal(_bytes(context.item_state()), committed_bytes, "mutating committed result cannot reach private context state", failures)

func _fixture(class_id: StringName, seed: int, columns: int) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(class_id), catalog.traits)
	_parties.append(party)
	var profile := ProfileState.new_profile("profile-equipment-%d" % seed, "Equipment Assignment", 1000)
	profile.inventory_columns = columns
	var context := PlayerRunContext.new()
	assert(context.configure(StringName("equipment_%d" % seed), _parties.size() - 1, profile, seed, party, 100).is_empty())
	return {"context": context, "party": party}

func _issue_into(context: PlayerRunContext, sequence: int, slot: int, base_id: StringName, equipment: EquipmentCatalog, failures: Array[String]) -> ItemInstance:
	var issued := ItemInstanceIssuer.issue(
		"run:%s:%s:%s" % [context.profile_id, context.run_seed, context.run_player_id],
		sequence,
		"equipment-assignment-test",
		context.run_seed + sequence,
		{"affixes": [], "base_definition_id": String(base_id), "item_level": 10, "rarity_id": "common"},
		equipment,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	TestAssertions.truthy(issued.ok(), "%s fixture item issues" % base_id, failures)
	if not issued.ok():
		return null
	var request := ItemTransactionRequest.create("equipment-create-%d" % sequence, String(context.run_player_id), INVENTORY_ID, slot, issued.item)
	var result := context.apply_item_transaction(request, equipment, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.equal(result.code, ItemTransactionResult.Code.OK, "%s fixture enters run inventory" % base_id, failures)
	return issued.item if result.ok() else null

func _catalog_with_attribute_requirement(base_id: StringName, attribute_id: StringName, minimum: float) -> EquipmentCatalog:
	var catalog := EquipmentCatalog.new()
	for definition: EquipmentBaseDefinition in GameCatalog.EQUIPMENT_CATALOG.definitions:
		var owned := definition.duplicate(true) as EquipmentBaseDefinition
		if owned.id == base_id:
			owned.attribute_requirements = {attribute_id: minimum}
		catalog.definitions.append(owned)
	return catalog

func _catalog_with_required_tags(base_id: StringName, tags: Array[StringName]) -> EquipmentCatalog:
	var catalog := EquipmentCatalog.new()
	for definition: EquipmentBaseDefinition in GameCatalog.EQUIPMENT_CATALOG.definitions:
		var owned := definition.duplicate(true) as EquipmentBaseDefinition
		if owned.id == base_id:
			owned.required_all_tags = tags.duplicate()
		catalog.definitions.append(owned)
	return catalog

func _assert_assignment_failure(context: PlayerRunContext, member_id: int, item_id: String, slot_id: StringName, equipment: EquipmentCatalog, label: String, failures: Array[String]) -> void:
	var before := _bytes(context.item_state())
	var result := context.assign_equipment(member_id, item_id, slot_id, equipment, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(not result.ok(), "%s assignment fails" % label, failures)
	TestAssertions.truthy(result.error.begins_with("PARTY_FORGE_EQUIPMENT_ASSIGNMENT_ERROR"), "%s exposes a stable diagnostic prefix" % label, failures)
	TestAssertions.equal(result.state(), null, "%s exposes no candidate state" % label, failures)
	TestAssertions.equal(_bytes(context.item_state()), before, "%s leaves ownership bytes unchanged" % label, failures)

func _bytes(state: ItemOwnershipState) -> String:
	return JSON.stringify(state.to_dictionary()) if state != null else "null"

func _attributes(snapshot: ResolvedStatSnapshot) -> Dictionary:
	var result: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		result[attribute_id] = snapshot.value(attribute_id) if snapshot != null else 0.0
	return result
