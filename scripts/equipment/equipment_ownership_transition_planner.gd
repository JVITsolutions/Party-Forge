class_name EquipmentOwnershipTransitionPlanner
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_EQUIPMENT_OWNERSHIP_TRANSITION_ERROR"

static func preview(
	state: ItemOwnershipState,
	item_id: String,
	source_container_id: StringName,
	source_slot: int,
	destination_container_id: StringName,
	destination_slot: int,
	equipment_container_id: StringName,
	storage_container_ids: Array[StringName],
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> EquipmentAssignmentResult:
	var context := "item=%s source=%s[%d] destination=%s[%d]" % [
		item_id, source_container_id, source_slot, destination_container_id, destination_slot,
	]
	if state == null or equipment == null or foundation == null or item_id.strip_edges().is_empty():
		return _failure(context, "invalid request")
	var state_error := state.validate(equipment, foundation)
	if not state_error.is_empty():
		return _failure(context, "invalid ownership state detail=%s" % state_error)
	if source_container_id == destination_container_id and source_slot == destination_slot:
		return _failure(context, "source and destination must differ")
	var storage_order := _storage_order(
		storage_container_ids, source_container_id, destination_container_id, equipment_container_id,
	)
	if storage_order.is_empty():
		return _failure(context, "storage containers are required")
	if not _is_allowed_endpoint(source_container_id, equipment_container_id, storage_order):
		return _failure(context, "source container is outside transition ownership")
	if not _is_allowed_endpoint(destination_container_id, equipment_container_id, storage_order):
		return _failure(context, "destination container is outside transition ownership")
	var equipment_container := state.container(equipment_container_id)
	var source := state.container(source_container_id)
	var destination := state.container(destination_container_id)
	if equipment_container == null or source == null or destination == null:
		return _failure(context, "transition container is missing")
	if not _slot_in_bounds(source, source_slot) or source.item_id_at(source_slot) != item_id:
		return _failure(context, "stale source item or slot")
	if not _slot_in_bounds(destination, destination_slot):
		return _failure(context, "destination slot is out of bounds")
	for storage_id: StringName in storage_order:
		if state.container(storage_id) == null:
			return _failure(context, "storage container %s is missing" % storage_id)
	var registry := state.registry()
	var moved_item := registry.item(item_id) if registry != null else null
	if moved_item == null or equipment.definition(moved_item.base_definition_id) == null:
		return _failure(context, "requested item definition is unavailable")

	var candidate := state.copy()
	var destination_item_id := destination.item_id_at(destination_slot)
	if destination_item_id.is_empty():
		candidate._clear_slot(source_container_id, source_slot)
		candidate._set_slot(destination_container_id, destination_slot, item_id)
	else:
		candidate._set_slot(source_container_id, source_slot, destination_item_id)
		candidate._set_slot(destination_container_id, destination_slot, item_id)

	var newly_placed := _newly_placed_equipment(state, candidate, equipment_container_id)
	for placement: Dictionary in newly_placed:
		var placed_item_id := String(placement["item_id"])
		var placed_item := registry.item(placed_item_id)
		var placed_definition := equipment.definition(placed_item.base_definition_id) if placed_item != null else null
		if placed_definition == null:
			return _failure(context, "newly equipped item %s definition is unavailable" % placed_item_id)
		var reserved_slots := placed_definition.reserved_slot_ids.duplicate()
		reserved_slots.sort_custom(func(left: StringName, right: StringName) -> bool:
			return EquipmentSlotIndex.index_for(left) < EquipmentSlotIndex.index_for(right)
		)
		for reserved_slot_id: StringName in reserved_slots:
			var reserved_slot := EquipmentSlotIndex.index_for(reserved_slot_id)
			if reserved_slot < 0:
				return _failure(context, "item=%s reserved slot %s is invalid" % [placed_item_id, reserved_slot_id])
			var current_equipment := candidate.container(equipment_container_id)
			var displaced_item_id := current_equipment.item_id_at(reserved_slot) if current_equipment != null else ""
			if displaced_item_id.is_empty() or displaced_item_id == placed_item_id:
				continue
			var displaced_item := registry.item(displaced_item_id)
			var displaced_definition := equipment.definition(displaced_item.base_definition_id) if displaced_item != null else null
			if displaced_definition == null:
				return _failure(context, "displaced item %s definition is unavailable" % displaced_item_id)
			if EquipmentEligibility.is_compatible_reserved_item(placed_definition, displaced_definition):
				continue
			var storage_destination := _first_storage_vacancy(candidate, storage_order)
			if storage_destination.is_empty():
				return _failure(
					context,
					"displaced_item=%s reserved_slot=%s reason=storage capacity insufficient" % [
						displaced_item_id, reserved_slot_id,
					],
				)
			candidate._clear_slot(equipment_container_id, reserved_slot)
			candidate._set_slot(
				StringName(String(storage_destination["container_id"])),
				int(storage_destination["slot"]),
				displaced_item_id,
			)

	var candidate_error := candidate.validate(equipment, foundation)
	if not candidate_error.is_empty():
		return _failure(context, "invalid candidate detail=%s" % candidate_error)
	var final_newly_placed := _newly_placed_equipment(state, candidate, equipment_container_id)
	var newly_equipped_item_ids: Array[String] = []
	for placement: Dictionary in final_newly_placed:
		newly_equipped_item_ids.append(String(placement["item_id"]))
	return EquipmentAssignmentResult.success(candidate, newly_equipped_item_ids)

static func _newly_placed_equipment(
	before: ItemOwnershipState,
	after: ItemOwnershipState,
	equipment_container_id: StringName,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var before_equipment := before.container(equipment_container_id)
	var after_equipment := after.container(equipment_container_id)
	if before_equipment == null or after_equipment == null:
		return result
	for slot: int in EquipmentSlotIndex.capacity():
		var item_id := after_equipment.item_id_at(slot)
		if not item_id.is_empty() and item_id != before_equipment.item_id_at(slot):
			result.append({"slot": slot, "item_id": item_id})
	return result

static func _storage_order(
	configured: Array[StringName],
	source_container_id: StringName,
	destination_container_id: StringName,
	equipment_container_id: StringName,
) -> Array[StringName]:
	var result: Array[StringName] = []
	for storage_id: StringName in configured:
		if storage_id != equipment_container_id and not storage_id.is_empty() and storage_id not in result:
			result.append(storage_id)
	var primary := source_container_id if source_container_id != equipment_container_id else destination_container_id
	if primary in result:
		result.erase(primary)
		result.push_front(primary)
	return result

static func _first_storage_vacancy(state: ItemOwnershipState, storage_order: Array[StringName]) -> Dictionary:
	for storage_id: StringName in storage_order:
		var storage := state.container(storage_id)
		var slot := storage.first_empty_slot() if storage != null else -1
		if slot >= 0:
			return {"container_id": String(storage_id), "slot": slot}
	return {}

static func _is_allowed_endpoint(
	container_id: StringName,
	equipment_container_id: StringName,
	storage_order: Array[StringName],
) -> bool:
	return container_id == equipment_container_id or container_id in storage_order

static func _slot_in_bounds(container: ItemSlotContainer, slot: int) -> bool:
	return container != null and slot >= 0 and slot < container.capacity

static func _failure(context: String, detail: String) -> EquipmentAssignmentResult:
	return EquipmentAssignmentResult.failure("%s %s reason=%s" % [ERROR_PREFIX, context, detail])
