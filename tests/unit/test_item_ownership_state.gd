extends RefCounted

const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const OWNER_ID := "profile-a"

func run() -> Array[String]:
	var failures: Array[String] = []
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var foundation := load(FOUNDATION_PATH) as ItemFoundationCatalog
	TestAssertions.truthy(equipment != null, "equipment catalog loads for ownership state", failures)
	TestAssertions.truthy(foundation != null, "foundation catalog loads for ownership state", failures)
	if equipment == null or foundation == null:
		return failures
	_assert_exact_placement_and_round_trip(equipment, foundation, failures)
	_assert_defensive_accessors(failures)
	_assert_canonical_ordering(failures)
	_assert_strict_rejections(equipment, foundation, failures)
	return failures

func _assert_exact_placement_and_round_trip(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var item := _make_item("item-owned-0001", 1)
	var state := _valid_state(item)
	TestAssertions.equal(state.validate(equipment, foundation), "", "constructed ownership state validates", failures)
	TestAssertions.equal(state.container(&"run-inventory").capacity, 5, "run inventory capacity is exact", failures)
	TestAssertions.equal(state.container(&"run-inventory").first_empty_slot(), 0, "first empty run slot is exact", failures)
	TestAssertions.equal(state.container(&"stash-tab-000").capacity, 100, "stash capacity is exact", failures)
	TestAssertions.equal(state.container(&"stash-tab-000").item_id_at(42), item.instance_id, "slot 42 is preserved", failures)
	TestAssertions.equal(state.container(&"stash-tab-000").occupied_slots(), [42], "sparse slots remain exact", failures)

	var round_trip := ItemOwnershipState.decode(state.to_dictionary(), equipment, foundation)
	TestAssertions.truthy(round_trip.ok(), "ownership state round trip succeeds", failures)
	if not round_trip.ok():
		failures.append("ownership state round trip error: %s" % round_trip.error)
		return
	TestAssertions.equal(round_trip.state.to_dictionary(), state.to_dictionary(), "ownership state round trip is exact", failures)

func _assert_defensive_accessors(failures: Array[String]) -> void:
	var item := _make_item("item-owned-0001", 1)
	var state := _valid_state(item)

	var registry_copy := state.registry()
	var returned_item := registry_copy.item(item.instance_id)
	returned_item.instance_id = "mutated-id"
	returned_item.origin["seed"] = "mutated"
	var returned_ids := registry_copy.ids()
	returned_ids.append("mutated-id")
	var registry_document := registry_copy.to_dictionary()
	(registry_document["items"] as Array)[0]["instance_id"] = "mutated-document-id"
	TestAssertions.equal(state.registry().item(item.instance_id).instance_id, item.instance_id, "registry item accessor is defensive", failures)
	TestAssertions.equal(state.registry().item(item.instance_id).origin["seed"], 1001, "registry item owns nested values", failures)
	TestAssertions.equal(state.registry().ids(), [item.instance_id], "registry id list is defensive", failures)
	TestAssertions.equal(state.registry().to_dictionary()["items"][0]["instance_id"], item.instance_id, "registry document is defensive", failures)

	var returned_container := state.container(&"stash-tab-000")
	returned_container.capacity = 3
	var slot_document := returned_container.to_dictionary()
	(slot_document["slots"] as Dictionary)["0"] = "mutated-slot-id"
	var returned_containers := state.containers()
	returned_containers[0].capacity = 17
	returned_containers.clear()
	TestAssertions.equal(state.container(&"stash-tab-000").capacity, 100, "container accessor is defensive", failures)
	TestAssertions.equal(state.container(&"stash-tab-000").item_id_at(42), item.instance_id, "slot dictionary is defensive", failures)
	TestAssertions.equal(state.containers().size(), 2, "container list is defensive", failures)
	TestAssertions.equal(state.container(&"run-inventory").capacity, 5, "container list elements are defensive", failures)

	var state_document := state.to_dictionary()
	state_document["owner_id"] = "mutated-owner"
	state_document["registry"]["items"][0]["origin"]["seed"] = "mutated-state-document"
	state_document["containers"][1]["slots"]["42"] = "mutated-state-slot"
	TestAssertions.equal(state.owner_id, OWNER_ID, "state document does not expose owner mutation", failures)
	TestAssertions.equal(state.registry().item(item.instance_id).origin["seed"], 1001, "state document does not expose item mutation", failures)
	TestAssertions.equal(state.container(&"stash-tab-000").item_id_at(42), item.instance_id, "state document does not expose slot mutation", failures)

func _assert_canonical_ordering(failures: Array[String]) -> void:
	var item_z := _make_item("item-z", 2)
	var item_a := _make_item("item-a", 3)
	var registry := ItemRegistry.new([item_z, item_a])
	var container_z := ItemSlotContainer.create(&"z-container", ItemSlotContainer.RUN_INVENTORY, OWNER_ID, 5)
	var container_a := ItemSlotContainer.create(&"a-container", ItemSlotContainer.PROFILE_STASH_TAB, OWNER_ID, 100, {42: item_a.instance_id, 2: item_z.instance_id})
	var state := ItemOwnershipState.create(OWNER_ID, registry, [container_z, container_a])
	var registry_items := registry.to_dictionary()["items"] as Array
	var container_documents := state.to_dictionary()["containers"] as Array
	TestAssertions.equal(registry.ids(), ["item-a", "item-z"], "registry ids are sorted", failures)
	TestAssertions.equal(registry_items[0]["instance_id"], "item-a", "registry documents sort ascending", failures)
	TestAssertions.equal(registry_items[1]["instance_id"], "item-z", "registry document sort is complete", failures)
	TestAssertions.equal(container_documents[0]["container_id"], "a-container", "containers sort ascending", failures)
	TestAssertions.equal(container_documents[1]["container_id"], "z-container", "container sort is complete", failures)
	TestAssertions.equal((container_documents[0]["slots"] as Dictionary).keys(), ["2", "42"], "slot keys sort numerically", failures)

func _assert_strict_rejections(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var item := _make_item("item-owned-0001", 1)
	var document := _valid_state(item).to_dictionary()

	var duplicate_id := document.duplicate(true)
	duplicate_id["registry"]["items"].append(duplicate_id["registry"]["items"][0].duplicate(true))
	_assert_decode_error(duplicate_id, "PARTY_FORGE_ITEM_REGISTRY_ERROR field=registry.items[1].instance_id reason=duplicate instance ID item-owned-0001", equipment, foundation, "duplicate instance ids", failures)

	var duplicate_reference := document.duplicate(true)
	duplicate_reference["containers"][0]["slots"]["0"] = item.instance_id
	_assert_decode_error(duplicate_reference, "PARTY_FORGE_ITEM_REGISTRY_ERROR field=instance_id reason=instance item-owned-0001 has 2 references", equipment, foundation, "two slots reference one item", failures)

	var unknown_reference := document.duplicate(true)
	unknown_reference["containers"][1]["slots"]["42"] = "missing-item"
	_assert_decode_error(unknown_reference, "PARTY_FORGE_ITEM_REGISTRY_ERROR field=containers[1].slots[42] reason=unknown instance ID missing-item", equipment, foundation, "unknown referenced item", failures)

	var orphan := document.duplicate(true)
	orphan["containers"][1]["slots"].clear()
	_assert_decode_error(orphan, "PARTY_FORGE_ITEM_REGISTRY_ERROR field=instance_id reason=instance item-owned-0001 has 0 references", equipment, foundation, "orphan registry item", failures)

	var negative_capacity := document.duplicate(true)
	negative_capacity["containers"][0]["capacity"] = -1
	_assert_decode_error(negative_capacity, "PARTY_FORGE_CONTAINER_ERROR field=containers[0].capacity reason=run_inventory capacity must be in range 0..40", equipment, foundation, "negative inventory capacity", failures)

	var oversized_capacity := document.duplicate(true)
	oversized_capacity["containers"][0]["capacity"] = 41
	_assert_decode_error(oversized_capacity, "PARTY_FORGE_CONTAINER_ERROR field=containers[0].capacity reason=run_inventory capacity must be in range 0..40", equipment, foundation, "oversized inventory capacity", failures)

	var undersized_stash := document.duplicate(true)
	undersized_stash["containers"][1]["capacity"] = 99
	_assert_decode_error(undersized_stash, "PARTY_FORGE_CONTAINER_ERROR field=containers[1].capacity reason=profile_stash_tab capacity must equal 100", equipment, foundation, "undersized stash capacity", failures)

	var oversized_stash := document.duplicate(true)
	oversized_stash["containers"][1]["capacity"] = 101
	_assert_decode_error(oversized_stash, "PARTY_FORGE_CONTAINER_ERROR field=containers[1].capacity reason=profile_stash_tab capacity must equal 100", equipment, foundation, "oversized stash capacity", failures)

	var out_of_bounds := document.duplicate(true)
	out_of_bounds["containers"][0]["slots"]["5"] = item.instance_id
	_assert_decode_error(out_of_bounds, "PARTY_FORGE_CONTAINER_ERROR field=containers[0].slots[5] reason=slot must be in range 0..4", equipment, foundation, "out of bounds slot", failures)

	var duplicate_container := document.duplicate(true)
	duplicate_container["containers"].append(duplicate_container["containers"][0].duplicate(true))
	_assert_decode_error(duplicate_container, "PARTY_FORGE_CONTAINER_ERROR field=containers[2].container_id reason=duplicate container ID run-inventory", equipment, foundation, "duplicate container ids", failures)

	var unknown_kind := document.duplicate(true)
	unknown_kind["containers"][0]["container_kind"] = "future_container"
	_assert_decode_error(unknown_kind, "PARTY_FORGE_CONTAINER_ERROR field=containers[0].container_kind reason=unknown container kind future_container", equipment, foundation, "unknown container kind", failures)

	var owner_mismatch := document.duplicate(true)
	owner_mismatch["containers"][0]["owner_id"] = "profile-b"
	_assert_decode_error(owner_mismatch, "PARTY_FORGE_CONTAINER_ERROR field=containers[0].owner_id reason=must match state owner profile-a", equipment, foundation, "container owner mismatch", failures)

	var empty_owner := document.duplicate(true)
	empty_owner["owner_id"] = ""
	_assert_decode_error(empty_owner, "PARTY_FORGE_CONTAINER_ERROR field=owner_id reason=must be a non-empty string", equipment, foundation, "empty state owner", failures)

	var noncanonical_slot := document.duplicate(true)
	noncanonical_slot["containers"][1]["slots"]["042"] = noncanonical_slot["containers"][1]["slots"]["42"]
	noncanonical_slot["containers"][1]["slots"].erase("42")
	_assert_decode_error(noncanonical_slot, "PARTY_FORGE_CONTAINER_ERROR field=containers[1].slots[042] reason=must be a canonical unsigned decimal string", equipment, foundation, "noncanonical slot key", failures)

	var unexpected_state := document.duplicate(true)
	unexpected_state["surplus"] = true
	_assert_decode_error(unexpected_state, "PARTY_FORGE_CONTAINER_ERROR field=document reason=unexpected fields surplus", equipment, foundation, "unexpected state field", failures)

	var unexpected_registry := document.duplicate(true)
	unexpected_registry["registry"]["surplus"] = true
	_assert_decode_error(unexpected_registry, "PARTY_FORGE_ITEM_REGISTRY_ERROR field=registry reason=unexpected fields surplus", equipment, foundation, "unexpected registry field", failures)

	var unexpected_container := document.duplicate(true)
	unexpected_container["containers"][0]["surplus"] = true
	_assert_decode_error(unexpected_container, "PARTY_FORGE_CONTAINER_ERROR field=containers[0] reason=unexpected fields surplus", equipment, foundation, "unexpected container field", failures)

func _assert_decode_error(
	document: Variant,
	expected_error: String,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	label: String,
	failures: Array[String]
) -> void:
	var decoded := ItemOwnershipState.decode(document, equipment, foundation)
	TestAssertions.truthy(not decoded.ok(), "%s is rejected" % label, failures)
	TestAssertions.equal(decoded.state, null, "%s exposes no partial state" % label, failures)
	TestAssertions.equal(decoded.error, expected_error, "%s error is exact" % label, failures)

func _valid_state(item: ItemInstance) -> ItemOwnershipState:
	var registry := ItemRegistry.new([item])
	var run_inventory := ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, OWNER_ID, 5)
	var stash := ItemSlotContainer.create(&"stash-tab-000", ItemSlotContainer.PROFILE_STASH_TAB, OWNER_ID, 100, {42: item.instance_id})
	return ItemOwnershipState.create(OWNER_ID, registry, [run_inventory, stash])

func _make_item(instance_id: String, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = &"forge_vanguard_sword"
	item.item_level = 28
	item.rarity_id = &"common"
	item.affixes = []
	item.origin = {
		"issuer_namespace": "profile:profile-a",
		"seed": 1000 + sequence,
		"sequence": sequence,
		"source": "ownership_test",
	}
	return item
