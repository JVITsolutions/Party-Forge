class_name ItemContainerTransactionService
extends RefCounted

func apply(
	state: ItemOwnershipState,
	request: ItemTransactionRequest,
	journal: ItemTransactionJournal,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> ItemTransactionResult:
	if not _request_is_valid(request):
		return _failure(ItemTransactionResult.Code.INVALID_REQUEST)
	if journal == null:
		return _failure(ItemTransactionResult.Code.INVALID_REQUEST)
	if state == null:
		return _failure(ItemTransactionResult.Code.INVALID_REQUEST)
	if request.owner_id != state.owner_id:
		return _failure(ItemTransactionResult.Code.UNKNOWN_OWNER)
	var fingerprint := request.fingerprint()
	if journal.has(request.transaction_id):
		var recorded := journal.entry(request.transaction_id)
		if String(recorded.get("fingerprint", "")) != fingerprint:
			return _failure(ItemTransactionResult.Code.TRANSACTION_COLLISION)
		return ItemTransactionResult.create(
			ItemTransactionResult.Code.TRANSACTION_REPLAY,
			recorded.get("state") as ItemOwnershipState,
			true
		)
	var source: ItemSlotContainer
	var destination: ItemSlotContainer
	if request.operation != ItemTransactionRequest.CREATE_AND_PLACE:
		source = state.container(StringName(request.source_container_id))
		if source == null:
			return _failure(ItemTransactionResult.Code.UNKNOWN_CONTAINER)
	if request.operation != ItemTransactionRequest.SANDBOX_REMOVE:
		destination = state.container(StringName(request.destination_container_id))
		if destination == null:
			return _failure(ItemTransactionResult.Code.UNKNOWN_CONTAINER)

	var registry := state.registry()
	if registry == null or not registry._validation_error(equipment, foundation).is_empty():
		return _failure(ItemTransactionResult.Code.INVALID_ITEM)
	var create_item := request.create_item
	if request.operation == ItemTransactionRequest.CREATE_AND_PLACE:
		if create_item == null or not ItemInstanceCodec.validate(create_item, equipment, foundation).is_empty():
			return _failure(ItemTransactionResult.Code.INVALID_ITEM)
		if registry.has(create_item.instance_id):
			return _failure(ItemTransactionResult.Code.DUPLICATE_INSTANCE)

	if source != null:
		if not _slot_is_in_bounds(source, request.source_slot):
			return _failure(ItemTransactionResult.Code.SLOT_OUT_OF_BOUNDS)
		if source.item_id_at(request.source_slot) != request.expected_instance_id:
			return _failure(ItemTransactionResult.Code.SOURCE_MISMATCH)
		if not registry.has(request.expected_instance_id):
			return _failure(ItemTransactionResult.Code.INVALID_ITEM)
	if destination != null:
		if not _slot_is_in_bounds(destination, request.destination_slot):
			return _failure(ItemTransactionResult.Code.SLOT_OUT_OF_BOUNDS)
		var destination_item_id := destination.item_id_at(request.destination_slot)
		if request.operation == ItemTransactionRequest.SWAP_OCCUPIED:
			if destination_item_id.is_empty():
				return _failure(ItemTransactionResult.Code.SOURCE_MISMATCH)
			if not registry.has(destination_item_id):
				return _failure(ItemTransactionResult.Code.INVALID_ITEM)
		elif not destination_item_id.is_empty():
			return _failure(ItemTransactionResult.Code.DESTINATION_OCCUPIED)

	if _has_duplicate_reference(state):
		return _failure(ItemTransactionResult.Code.DUPLICATE_REFERENCE)
	var candidate := state.copy()
	_apply_candidate_mutation(candidate, request, source, destination, create_item)
	var candidate_error := candidate.validate(equipment, foundation)
	if not candidate_error.is_empty():
		if _has_duplicate_reference(candidate):
			return _failure(ItemTransactionResult.Code.DUPLICATE_REFERENCE)
		return _failure(ItemTransactionResult.Code.INVALID_ITEM)
	journal._record_success(request.transaction_id, fingerprint, ItemTransactionResult.Code.OK, candidate)
	return ItemTransactionResult.create(ItemTransactionResult.Code.OK, candidate)

func _request_is_valid(request: ItemTransactionRequest) -> bool:
	if request == null or request.schema_version != ItemTransactionRequest.SCHEMA_VERSION:
		return false
	if request.transaction_id.strip_edges().is_empty() or request.owner_id.strip_edges().is_empty():
		return false
	match request.operation:
		ItemTransactionRequest.CREATE_AND_PLACE:
			return (
				request.source_container_id.is_empty()
				and request.source_slot == -1
				and request.expected_instance_id.is_empty()
				and not request.destination_container_id.strip_edges().is_empty()
			)
		ItemTransactionRequest.MOVE_TO_EMPTY, ItemTransactionRequest.SWAP_OCCUPIED:
			return (
				not request.source_container_id.strip_edges().is_empty()
				and not request.expected_instance_id.strip_edges().is_empty()
				and not request.destination_container_id.strip_edges().is_empty()
				and request.create_item == null
				and not (
					request.source_container_id == request.destination_container_id
					and request.source_slot == request.destination_slot
				)
			)
		ItemTransactionRequest.SANDBOX_REMOVE:
			return (
				not request.source_container_id.strip_edges().is_empty()
				and not request.expected_instance_id.strip_edges().is_empty()
				and request.destination_container_id.is_empty()
				and request.destination_slot == -1
				and request.create_item == null
			)
		_:
			return false

func _slot_is_in_bounds(container: ItemSlotContainer, slot: int) -> bool:
	return slot >= 0 and slot < container.capacity

func _has_duplicate_reference(state: ItemOwnershipState) -> bool:
	var reference_counts: Dictionary = {}
	for container: ItemSlotContainer in state.containers():
		for slot: int in container.occupied_slots():
			var instance_id := container.item_id_at(slot)
			reference_counts[instance_id] = int(reference_counts.get(instance_id, 0)) + 1
			if int(reference_counts[instance_id]) > 1:
				return true
	return false

func _apply_candidate_mutation(
	candidate: ItemOwnershipState,
	request: ItemTransactionRequest,
	source: ItemSlotContainer,
	destination: ItemSlotContainer,
	create_item: ItemInstance
) -> void:
	match request.operation:
		ItemTransactionRequest.CREATE_AND_PLACE:
			candidate._insert_item(create_item)
			candidate._set_slot(StringName(request.destination_container_id), request.destination_slot, create_item.instance_id)
		ItemTransactionRequest.MOVE_TO_EMPTY:
			candidate._clear_slot(StringName(request.source_container_id), request.source_slot)
			candidate._set_slot(StringName(request.destination_container_id), request.destination_slot, request.expected_instance_id)
		ItemTransactionRequest.SWAP_OCCUPIED:
			var destination_instance_id := destination.item_id_at(request.destination_slot)
			candidate._set_slot(StringName(request.source_container_id), request.source_slot, destination_instance_id)
			candidate._set_slot(StringName(request.destination_container_id), request.destination_slot, request.expected_instance_id)
		ItemTransactionRequest.SANDBOX_REMOVE:
			candidate._clear_slot(StringName(request.source_container_id), request.source_slot)
			candidate._erase_item(request.expected_instance_id)

func _failure(code: ItemTransactionResult.Code) -> ItemTransactionResult:
	return ItemTransactionResult.create(code)
