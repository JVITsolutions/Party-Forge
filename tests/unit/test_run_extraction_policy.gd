extends RefCounted

const PROFILE_ID := "profile-extract001"
const RUN_PLAYER_ID := &"extract_player"
const RUN_ID := &"run-extract-001"
const RUN_SEED := 6006
const LEADER_ID := 1

const LEADER_ITEM := "item-leader"
const FOLLOWER_TWO_ITEM := "item-follower-2"
const FOLLOWER_THREE_ITEM := "item-follower-3"
const INVENTORY_ZERO_ITEM := "item-inventory-0"
const INVENTORY_FOUR_ITEM := "item-inventory-4"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_source_projection_parity(failures)
	_test_unlock_precedence_and_canonical_order(failures)
	_test_capacity_and_selection_matrix(failures)
	_test_invalid_selection_matrix(failures)
	_test_context_and_owner_rejections(failures)
	_test_defensive_and_pure_contract(failures)
	_test_deterministic_projection(failures)
	return failures

func _test_source_projection_parity(failures: Array[String]) -> void:
	var fixture := _fixture(3, ["leader_loadout_extraction"])
	var selections: Array[ExtractionSelection] = [
		ExtractionSelection.create(FOLLOWER_TWO_ITEM, &"run-equipment-002", 7),
		ExtractionSelection.create(INVENTORY_FOUR_ITEM, &"run-inventory", 4),
	]
	var source_type := load("res://scripts/extraction/run_resolution_source.gd") as Script
	if source_type == null:
		failures.append("resolution source type is required")
		_free_fixture(fixture)
		return
	var source_result: Variant = source_type.call(&"from_context", fixture.context, LEADER_ID)
	TestAssertions.truthy(source_result.ok(), "source projection fixture captures", failures)
	if source_result.ok():
		var live := RunExtractionPolicy.project(fixture.context, fixture.profile, selections)
		var policy_type := load("res://scripts/extraction/run_extraction_policy.gd") as Script
		var source: Variant = policy_type.call(&"project_source", source_result.source, fixture.profile, selections)
		TestAssertions.equal(source.to_dictionary(), live.to_dictionary(), "source extraction projection matches live wrapper exactly", failures)
	_free_fixture(fixture)

func _test_unlock_precedence_and_canonical_order(failures: Array[String]) -> void:
	var ordinary := _fixture(3, [])
	var ordinary_projection := RunExtractionPolicy.project(ordinary.context, ordinary.profile, [])
	TestAssertions.truthy(ordinary_projection.valid, "ordinary extraction projection is valid", failures)
	TestAssertions.equal(ordinary_projection.automatic_item_ids, [], "ordinary extraction has no automatic items", failures)
	TestAssertions.equal(_eligible_ids(ordinary_projection), [
		LEADER_ITEM,
		FOLLOWER_TWO_ITEM,
		FOLLOWER_THREE_ITEM,
		INVENTORY_ZERO_ITEM,
		INVENTORY_FOUR_ITEM,
	], "ordinary extraction orders leader, followers by member ID, then inventory slot", failures)
	TestAssertions.equal(ordinary_projection.lost_item_ids, [
		LEADER_ITEM,
		FOLLOWER_TWO_ITEM,
		FOLLOWER_THREE_ITEM,
		INVENTORY_ZERO_ITEM,
		INVENTORY_FOUR_ITEM,
	], "unselected ordinary items are lost in canonical order", failures)
	_free_fixture(ordinary)

	var unlocked := _fixture(3, ["leader_loadout_extraction", "leader_loadout_extraction"])
	var automatic_projection := RunExtractionPolicy.project(unlocked.context, unlocked.profile, [])
	TestAssertions.truthy(automatic_projection.valid, "automatic extraction projection is valid", failures)
	TestAssertions.equal(automatic_projection.automatic_item_ids, [LEADER_ITEM], "leader gear becomes automatic exactly once", failures)
	TestAssertions.equal(_eligible_ids(automatic_projection), [
		FOLLOWER_TWO_ITEM,
		FOLLOWER_THREE_ITEM,
		INVENTORY_ZERO_ITEM,
		INVENTORY_FOUR_ITEM,
	], "automatic leader gear is excluded before ordinary eligibility", failures)
	TestAssertions.truthy(LEADER_ITEM not in automatic_projection.lost_item_ids, "automatic leader gear cannot be lost", failures)
	_free_fixture(unlocked)

	var slot_order := _fixture(3, [], true)
	var slot_projection := RunExtractionPolicy.project(slot_order.context, slot_order.profile, [])
	TestAssertions.equal(_eligible_ids(slot_projection), [
		LEADER_ITEM,
		FOLLOWER_THREE_ITEM,
		FOLLOWER_TWO_ITEM,
		INVENTORY_ZERO_ITEM,
		INVENTORY_FOUR_ITEM,
	], "same-member equipment orders by canonical equipment index", failures)
	_free_fixture(slot_order)

func _test_capacity_and_selection_matrix(failures: Array[String]) -> void:
	var zero := _fixture(0, [])
	var zero_projection := RunExtractionPolicy.project(zero.context, zero.profile, [])
	TestAssertions.truthy(zero_projection.valid, "capacity zero permits no ordinary selections", failures)
	TestAssertions.equal(zero_projection.capacity, 0, "capacity zero is projected exactly", failures)
	TestAssertions.equal(zero_projection.selected_item_ids, [], "capacity zero selects nothing", failures)
	_free_fixture(zero)

	var one := _fixture(1, [])
	var one_selection: Array[ExtractionSelection] = [
		ExtractionSelection.create(INVENTORY_ZERO_ITEM, &"run-inventory", 0),
	]
	var one_projection := RunExtractionPolicy.project(one.context, one.profile, one_selection)
	TestAssertions.truthy(one_projection.valid, "one selection fits capacity one", failures)
	TestAssertions.equal(one_projection.selected_item_ids, [INVENTORY_ZERO_ITEM], "capacity one selects the exact item", failures)
	TestAssertions.truthy(INVENTORY_ZERO_ITEM not in one_projection.lost_item_ids, "selected item is not lost", failures)
	_free_fixture(one)

	var three := _fixture(3, [])
	var three_selections: Array[ExtractionSelection] = [
		ExtractionSelection.create(INVENTORY_FOUR_ITEM, &"run-inventory", 4),
		ExtractionSelection.create(FOLLOWER_THREE_ITEM, &"run-equipment-003", 1),
		ExtractionSelection.create(LEADER_ITEM, &"run-equipment-001", 9),
	]
	var three_projection := RunExtractionPolicy.project(three.context, three.profile, three_selections)
	TestAssertions.truthy(three_projection.valid, "three selections fit capacity three", failures)
	TestAssertions.equal(three_projection.selected_item_ids, [LEADER_ITEM, FOLLOWER_THREE_ITEM, INVENTORY_FOUR_ITEM], "selected IDs use canonical candidate order, not click order", failures)
	_free_fixture(three)

func _test_invalid_selection_matrix(failures: Array[String]) -> void:
	var fixture := _fixture(3, ["leader_loadout_extraction"])
	var cases: Array[Dictionary] = [
		{
			"label": "duplicate selection",
			"selections": [
				ExtractionSelection.create(INVENTORY_ZERO_ITEM, &"run-inventory", 0),
				ExtractionSelection.create(INVENTORY_ZERO_ITEM, &"run-inventory", 0),
			],
			"errors": ["PARTY_FORGE_EXTRACTION_ERROR field=selections[1].item_id reason=duplicate selection item-inventory-0"],
		},
		{
			"label": "unknown item",
			"selections": [ExtractionSelection.create("item-unknown", &"run-inventory", 0)],
			"errors": ["PARTY_FORGE_EXTRACTION_ERROR field=selections[0].item_id reason=unknown item item-unknown"],
		},
		{
			"label": "stale source container",
			"selections": [ExtractionSelection.create(INVENTORY_ZERO_ITEM, &"run-equipment-002", 0)],
			"errors": ["PARTY_FORGE_EXTRACTION_ERROR field=selections[0].source reason=expected run-equipment-002[0] but item is at run-inventory[0]"],
		},
		{
			"label": "stale source slot",
			"selections": [ExtractionSelection.create(INVENTORY_ZERO_ITEM, &"run-inventory", 1)],
			"errors": ["PARTY_FORGE_EXTRACTION_ERROR field=selections[0].source reason=expected run-inventory[1] but item is at run-inventory[0]"],
		},
		{
			"label": "automatic leader selection",
			"selections": [ExtractionSelection.create(LEADER_ITEM, &"run-equipment-001", 9)],
			"errors": ["PARTY_FORGE_EXTRACTION_ERROR field=selections[0].item_id reason=item item-leader is automatic"],
		},
	]
	for test_case: Dictionary in cases:
		var typed_selections: Array[ExtractionSelection] = []
		for selection: ExtractionSelection in test_case.selections:
			typed_selections.append(selection)
		var projection := RunExtractionPolicy.project(fixture.context, fixture.profile, typed_selections)
		TestAssertions.truthy(not projection.valid, "%s is rejected" % test_case.label, failures)
		TestAssertions.equal(projection.errors, test_case.errors, "%s has stable errors" % test_case.label, failures)

	var over_capacity := _fixture(1, [])
	var over_selections: Array[ExtractionSelection] = [
		ExtractionSelection.create(FOLLOWER_TWO_ITEM, &"run-equipment-002", 7),
		ExtractionSelection.create(INVENTORY_ZERO_ITEM, &"run-inventory", 0),
	]
	var over_projection := RunExtractionPolicy.project(over_capacity.context, over_capacity.profile, over_selections)
	TestAssertions.truthy(not over_projection.valid, "over-capacity selection is rejected", failures)
	TestAssertions.equal(over_projection.errors, ["PARTY_FORGE_EXTRACTION_ERROR field=selections reason=2 selected items exceed capacity 1"], "over-capacity error is stable", failures)
	_free_fixture(over_capacity)
	_free_fixture(fixture)

func _test_context_and_owner_rejections(failures: Array[String]) -> void:
	var fixture := _fixture(1, [])
	var wrong_profile: ProfileState = (fixture.profile as ProfileState).copy()
	wrong_profile.profile_id = "profile-other"
	var wrong_profile_projection := RunExtractionPolicy.project(fixture.context, wrong_profile, [])
	TestAssertions.equal(wrong_profile_projection.errors, ["PARTY_FORGE_EXTRACTION_ERROR field=profile.profile_id reason=must match configured context profile"], "wrong profile context is rejected", failures)

	var unconfigured_projection := RunExtractionPolicy.project(PlayerRunContext.new(), fixture.profile, [])
	TestAssertions.equal(unconfigured_projection.errors, ["PARTY_FORGE_EXTRACTION_ERROR field=context reason=must be configured"], "unconfigured context is rejected", failures)

	fixture.context._item_state.owner_id = "wrong-owner"
	var wrong_owner_projection := RunExtractionPolicy.project(fixture.context, fixture.profile, [])
	TestAssertions.equal(wrong_owner_projection.errors, ["PARTY_FORGE_EXTRACTION_ERROR field=item_state.owner_id reason=must match configured run player"], "wrong run owner is rejected", failures)
	_free_fixture(fixture)

func _test_defensive_and_pure_contract(failures: Array[String]) -> void:
	var fixture := _fixture(3, ["leader_loadout_extraction", "leader_loadout_extraction"])
	var selections: Array[ExtractionSelection] = [
		ExtractionSelection.create(FOLLOWER_TWO_ITEM, &"run-equipment-002", 7),
	]
	var context_before: Dictionary = (fixture.context as PlayerRunContext).item_state().to_dictionary()
	var profile_before: Dictionary = (fixture.profile as ProfileState).to_dictionary()
	var party_before := _party_snapshot(fixture.party)
	var selections_before: Array[Dictionary] = []
	for selection: ExtractionSelection in selections:
		selections_before.append(selection.to_dictionary())

	var projection := RunExtractionPolicy.project(fixture.context, fixture.profile, selections)
	TestAssertions.equal(fixture.context.item_state().to_dictionary(), context_before, "projection does not mutate run ownership", failures)
	TestAssertions.equal(fixture.profile.to_dictionary(), profile_before, "projection does not mutate profile", failures)
	TestAssertions.equal(_party_snapshot(fixture.party), party_before, "projection does not mutate party", failures)
	var selections_after: Array[Dictionary] = []
	for selection: ExtractionSelection in selections:
		selections_after.append(selection.to_dictionary())
	TestAssertions.equal(selections_after, selections_before, "projection does not mutate selection inputs", failures)

	var automatic := projection.automatic_item_ids
	automatic.clear()
	var selected := projection.selected_item_ids
	selected.append("escaped")
	var lost := projection.lost_item_ids
	lost.clear()
	var errors := projection.errors
	errors.append("escaped")
	var eligible := projection.eligible_items
	eligible[0]._item_id = "escaped"
	eligible.clear()
	TestAssertions.equal(projection.automatic_item_ids, [LEADER_ITEM], "automatic IDs are defensive", failures)
	TestAssertions.equal(projection.selected_item_ids, [FOLLOWER_TWO_ITEM], "selected IDs are defensive", failures)
	TestAssertions.truthy(not projection.lost_item_ids.is_empty(), "lost IDs are defensive", failures)
	TestAssertions.equal(projection.errors, [], "errors are defensive", failures)
	TestAssertions.equal(projection.eligible_items[0].item_id, FOLLOWER_TWO_ITEM, "eligible projections and their records are defensive", failures)

	var selection_document := selections[0].to_dictionary()
	selection_document["item_id"] = "escaped"
	TestAssertions.equal(selections[0].item_id, FOLLOWER_TWO_ITEM, "immutable selection document is defensive", failures)
	_free_fixture(fixture)

func _test_deterministic_projection(failures: Array[String]) -> void:
	var fixture := _fixture(3, ["leader_loadout_extraction", "leader_loadout_extraction"])
	var selections: Array[ExtractionSelection] = [
		ExtractionSelection.create(INVENTORY_FOUR_ITEM, &"run-inventory", 4),
		ExtractionSelection.create(FOLLOWER_TWO_ITEM, &"run-equipment-002", 7),
	]
	var first := RunExtractionPolicy.project(fixture.context, fixture.profile, selections).to_dictionary()
	var second := RunExtractionPolicy.project(fixture.context, fixture.profile, selections).to_dictionary()
	TestAssertions.equal(second, first, "repeated extraction projection is byte-order deterministic", failures)
	_free_fixture(fixture)

func _fixture(capacity: int, unlocks: Array[String], same_follower := false) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	assert(party.recruit(catalog.class_by_id(&"ranger")))
	assert(party.recruit(catalog.class_by_id(&"mage")))
	var items: Array[ItemInstance] = [
		_item(LEADER_ITEM, 0),
		_item(FOLLOWER_TWO_ITEM, 1, &"windrunner_band"),
		_item(FOLLOWER_THREE_ITEM, 2, &"greenwood_jerkin" if same_follower else &"emberweave_robe"),
		_item(INVENTORY_ZERO_ITEM, 3),
		_item(INVENTORY_FOUR_ITEM, 4),
	]
	var equipment_two_slots := {7: FOLLOWER_TWO_ITEM}
	var equipment_three_slots := {1: FOLLOWER_THREE_ITEM}
	if same_follower:
		equipment_two_slots = {7: FOLLOWER_TWO_ITEM, 1: FOLLOWER_THREE_ITEM}
		equipment_three_slots = {}
	var state := ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new(items), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10, {
			0: INVENTORY_ZERO_ITEM,
			4: INVENTORY_FOUR_ITEM,
		}),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), {9: LEADER_ITEM}),
		ItemSlotContainer.create(&"run-equipment-002", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), equipment_two_slots),
		ItemSlotContainer.create(&"run-equipment-003", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), equipment_three_slots),
	])
	assert(state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).is_empty())
	var bootstrap := RunItemBootstrap.create(RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, state)
	var profile := ProfileState.new_profile(PROFILE_ID, "Extraction Tester", 1000)
	profile.inventory_columns = 2
	profile.extraction_capacity = capacity
	profile.permanent_feature_unlocks = unlocks.duplicate()
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	assert(context.configure(RUN_PLAYER_ID, 0, profile, RUN_SEED, party, 100, bootstrap).is_empty())
	return {"catalog": catalog, "party": party, "profile": profile, "context": context}

func _item(instance_id: String, sequence: int, base_definition_id: StringName = &"forge_vanguard_sword") -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_definition_id
	item.item_level = 28
	item.rarity_id = &"common"
	item.affixes = []
	item.origin = {
		"issuer_namespace": "run:%s:%d:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID],
		"seed": RUN_SEED,
		"sequence": sequence,
		"source": "extraction_policy_test",
	}
	return item

func _eligible_ids(projection: RunExtractionProjection) -> Array[String]:
	var result: Array[String] = []
	for item: ExtractionSelection in projection.eligible_items:
		result.append(item.item_id)
	return result

func _party_snapshot(party: PartyManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for member: PartyMemberState in party.members:
		result.append({
			"member_id": member.member_id,
			"class_id": String(member.class_definition.id),
			"is_leader": member.is_leader,
		})
	return result

func _free_fixture(fixture: Dictionary) -> void:
	(fixture.party as PartyManager).free()
