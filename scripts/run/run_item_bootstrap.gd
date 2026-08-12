class_name RunItemBootstrap
extends RefCounted

var _run_id: StringName = &""
var run_id: StringName:
	get:
		return _run_id
var _run_seed := 0
var run_seed: int:
	get:
		return _run_seed
var _run_player_id: StringName = &""
var run_player_id: StringName:
	get:
		return _run_player_id
var _leader_member_id := 0
var leader_member_id: int:
	get:
		return _leader_member_id
var _item_state: ItemOwnershipState

static func create(
	run_id_value: StringName,
	run_seed_value: int,
	run_player_id_value: StringName,
	leader_member_id_value: int,
	item_state_value: ItemOwnershipState,
) -> RunItemBootstrap:
	var result := RunItemBootstrap.new()
	result._run_id = run_id_value
	result._run_seed = run_seed_value
	result._run_player_id = run_player_id_value
	result._leader_member_id = leader_member_id_value
	result._item_state = item_state_value.copy() if item_state_value != null else null
	return result

static func ground_items_container(owner_id: String) -> ItemSlotContainer:
	return ItemSlotContainer.create(
		ItemSlotContainer.RUN_GROUND_ITEMS_ID,
		ItemSlotContainer.RUN_GROUND_ITEMS,
		owner_id,
		ItemSlotContainer.RUN_GROUND_ITEMS_CAPACITY,
	)

static func with_ground_container(state: ItemOwnershipState) -> ItemOwnershipState:
	if state == null:
		return null
	if state.container(ItemSlotContainer.RUN_GROUND_ITEMS_ID) != null:
		return state.copy()
	var containers := state.containers()
	containers.append(ground_items_container(state.owner_id))
	return ItemOwnershipState.create(state.owner_id, state.registry(), containers)

static func with_run_inventory_capacity(state: ItemOwnershipState, capacity: int) -> ItemOwnershipState:
	if state == null or capacity < 0:
		return null
	var inventory := state.container(&"run-inventory")
	if inventory == null or inventory.occupied_slots().any(func(slot: int) -> bool: return slot >= capacity):
		return null
	var containers: Array[ItemSlotContainer] = []
	for container: ItemSlotContainer in state.containers():
		if container.container_id == &"run-inventory":
			containers.append(ItemSlotContainer.create(container.container_id, container.container_kind, container.owner_id, capacity, container.to_dictionary().get("slots", {}) as Dictionary))
		else:
			containers.append(container)
	return ItemOwnershipState.create(state.owner_id, state.registry(), containers)

func item_state() -> ItemOwnershipState:
	return _item_state.copy() if _item_state != null else null
