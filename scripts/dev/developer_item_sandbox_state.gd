class_name DeveloperItemSandboxState
extends RefCounted

const OWNER_ID := "developer-item-sandbox"
const INVENTORY_ID := &"developer-inventory"
const STASH_ID := &"developer-stash-000"

var _store: DeveloperItemSandboxStore
var _transactions := ItemContainerTransactionService.new()
var _state: ItemOwnershipState
var _journal := ItemTransactionJournal.new()
var _metadata: Dictionary = {}
var _integrity_error: String

func _init(store: DeveloperItemSandboxStore = null) -> void:
	_store = store if store != null else DeveloperItemSandboxStore.new()

func reset() -> String:
	var issued := DeveloperItemFixtureIssuer.issue_all(
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	var issuance_error := String(issued.get("error", ""))
	if not issuance_error.is_empty():
		return _fail(issuance_error)
	var inventory := ItemSlotContainer.create(
		INVENTORY_ID,
		ItemSlotContainer.DEVELOPER_INVENTORY,
		OWNER_ID,
		5
	)
	var stash := ItemSlotContainer.create(
		STASH_ID,
		ItemSlotContainer.DEVELOPER_STASH_TAB,
		OWNER_ID,
		100
	)
	var candidate := ItemOwnershipState.create(
		OWNER_ID,
		ItemRegistry.new(),
		[inventory, stash] as Array[ItemSlotContainer]
	)
	var construction_journal := ItemTransactionJournal.new()
	var items := issued["items"] as Array[ItemInstance]
	for index: int in items.size():
		var request := ItemTransactionRequest.create(
			"sandbox-fixture-create-%016d" % index,
			OWNER_ID,
			STASH_ID,
			index,
			items[index]
		)
		var transaction := _transactions.apply(
			candidate,
			request,
			construction_journal,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG
		)
		if transaction.code != ItemTransactionResult.Code.OK or transaction.next_state == null:
			return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=reset.transaction[%d] reason=code %s" % [index, _code_name(transaction.code)])
		candidate = transaction.next_state
	var metadata := {
		"schema_version": DeveloperItemSandboxStore.SCHEMA_VERSION,
		"owner_id": OWNER_ID,
		"issuer_namespace": DeveloperItemFixtureIssuer.ISSUER_NAMESPACE,
		"issued_count": items.size(),
		"definition_ids": (issued["definition_ids"] as Array).duplicate(true),
		"next_transaction_sequence": 0,
	}
	var candidate_journal := ItemTransactionJournal.new()
	var document := _store.document_for(candidate, metadata, candidate_journal)
	var save_error := _store.reset_document(document)
	if not save_error.is_empty():
		return _fail(save_error)
	return _commit_saved_document(document)

func save() -> String:
	if _state == null:
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=state reason=must reset or reload before save")
	var save_error := _store.save_document(_store.document_for(_state, _metadata, _journal))
	if not save_error.is_empty():
		return _fail(save_error)
	_integrity_error = ""
	return ""

func reload() -> String:
	var loaded := _store.load_document()
	if not loaded.ok():
		var reason := loaded.error if not loaded.error.is_empty() else "sandbox document is missing"
		return _fail(reason)
	var decoded := _store.decode_document(loaded.document)
	var decode_error := String(decoded.get("error", ""))
	if not decode_error.is_empty():
		return _fail(decode_error)
	_commit(
		decoded["state"] as ItemOwnershipState,
		decoded["metadata"] as Dictionary,
		decoded["journal"] as ItemTransactionJournal
	)
	return ""

func registry() -> ItemRegistry:
	return _state.registry() if _state != null else null

func inventory() -> ItemSlotContainer:
	return _state.container(INVENTORY_ID) if _state != null else null

func stash() -> ItemSlotContainer:
	return _state.container(STASH_ID) if _state != null else null

func to_dictionary() -> Dictionary:
	if _state == null:
		return {}
	return _store.document_for(_state, _metadata, _journal).duplicate(true)

func integrity_error() -> String:
	return _integrity_error

func scan_integrity() -> String:
	if _state == null:
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=state reason=must reset or reload before scanning")
	var error := _store.validate_document(_store.document_for(_state, _metadata, _journal))
	if error.is_empty():
		error = _store.scan_persisted_document()
	_integrity_error = error
	return error

func transfer_slots(
	source_container_id: StringName,
	source_slot: int,
	destination_container_id: StringName,
	destination_slot: int
) -> String:
	if _state == null:
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=state reason=must reset or reload before moving")
	var source := _state.container(source_container_id)
	var destination := _state.container(destination_container_id)
	if source == null or destination == null:
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=container reason=unknown source or destination container")
	if source_slot < 0 or source_slot >= source.capacity or destination_slot < 0 or destination_slot >= destination.capacity:
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=slot reason=source or destination is out of bounds")
	if source_container_id == destination_container_id and source_slot == destination_slot:
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=destination reason=source and destination must differ")
	var item_id := source.item_id_at(source_slot)
	if item_id.is_empty():
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=source reason=source slot is empty")
	var sequence := int(_metadata.get("next_transaction_sequence", 0))
	var transaction_id := "sandbox-move-%016d" % sequence
	var request := ItemTransactionRequest.move(
		transaction_id,
		OWNER_ID,
		source_container_id,
		source_slot,
		item_id,
		destination_container_id,
		destination_slot
	) if destination.item_id_at(destination_slot).is_empty() else ItemTransactionRequest.swap(
		transaction_id,
		OWNER_ID,
		source_container_id,
		source_slot,
		item_id,
		destination_container_id,
		destination_slot
	)
	var result := _apply_transaction(request)
	if result.code == ItemTransactionResult.Code.OK:
		return ""
	return _integrity_error if not _integrity_error.is_empty() else "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=transaction reason=code %s" % _code_name(result.code)

func move_to_first_empty_inventory(item_id: String) -> String:
	return _move_to_first_empty(item_id, INVENTORY_ID)

func move_to_first_empty_stash(item_id: String) -> String:
	return _move_to_first_empty(item_id, STASH_ID)

func _apply_transaction(request: ItemTransactionRequest) -> ItemTransactionResult:
	if _state == null or request == null:
		_integrity_error = "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=transaction reason=state and request are required"
		return ItemTransactionResult.create(ItemTransactionResult.Code.INVALID_REQUEST)
	var candidate_journal := _journal.copy()
	var result := _transactions.apply(
		_state,
		request,
		candidate_journal,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	if result.code != ItemTransactionResult.Code.OK:
		_integrity_error = "" if result.code == ItemTransactionResult.Code.TRANSACTION_REPLAY else "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=transaction reason=code %s" % _code_name(result.code)
		return result
	var candidate_state := result.next_state
	if candidate_state == null:
		_integrity_error = "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=transaction reason=missing candidate state"
		return ItemTransactionResult.create(ItemTransactionResult.Code.INVALID_ITEM)
	var candidate_metadata := _metadata.duplicate(true)
	var next_sequence := int(candidate_metadata.get("next_transaction_sequence", 0))
	if next_sequence >= ItemInstanceCodec.JSON_SAFE_INTEGER_MAX:
		_integrity_error = "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=issuance_metadata.next_transaction_sequence reason=sequence exhausted"
		return ItemTransactionResult.create(ItemTransactionResult.Code.INVALID_REQUEST)
	candidate_metadata["next_transaction_sequence"] = next_sequence + 1
	var save_error := _store.save_document(_store.document_for(candidate_state, candidate_metadata, candidate_journal))
	if not save_error.is_empty():
		_integrity_error = save_error
		return ItemTransactionResult.create(ItemTransactionResult.Code.INVALID_ITEM)
	var saved_document := _store.document_for(candidate_state, candidate_metadata, candidate_journal)
	var commit_error := _commit_saved_document(saved_document)
	if not commit_error.is_empty():
		return ItemTransactionResult.create(ItemTransactionResult.Code.INVALID_ITEM)
	return result

func _move_to_first_empty(item_id: String, destination_id: StringName) -> String:
	if _state == null:
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=state reason=must reset or reload before moving")
	if item_id.strip_edges().is_empty() or not _state.registry().has(item_id):
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=item_id reason=unknown item %s" % item_id)
	var source_id := StringName()
	var source_slot := -1
	for container: ItemSlotContainer in _state.containers():
		for slot: int in container.occupied_slots():
			if container.item_id_at(slot) == item_id:
				source_id = container.container_id
				source_slot = slot
				break
		if source_slot >= 0:
			break
	if source_slot < 0:
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=item_id reason=item has no placement")
	if source_id == destination_id:
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=destination reason=item is already in destination container")
	var destination := _state.container(destination_id)
	var destination_slot := destination.first_empty_slot() if destination != null else -1
	if destination_slot < 0:
		return _fail("PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=destination reason=container has no empty slot")
	var sequence := int(_metadata.get("next_transaction_sequence", 0))
	var request := ItemTransactionRequest.move(
		"sandbox-move-%016d" % sequence,
		OWNER_ID,
		source_id,
		source_slot,
		item_id,
		destination_id,
		destination_slot
	)
	var result := _apply_transaction(request)
	if result.code == ItemTransactionResult.Code.OK:
		return ""
	return _integrity_error if not _integrity_error.is_empty() else "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=transaction reason=code %s" % _code_name(result.code)

func _commit(
	state: ItemOwnershipState,
	metadata: Dictionary,
	journal: ItemTransactionJournal
) -> void:
	_state = state.copy()
	_metadata = metadata.duplicate(true)
	_journal = journal.copy()
	_integrity_error = ""

func _commit_saved_document(document: Dictionary) -> String:
	var normalized: Variant = JSON.parse_string(JSON.stringify(document))
	var decoded := _store.decode_document(normalized)
	var decode_error := String(decoded.get("error", ""))
	if not decode_error.is_empty():
		return _fail(decode_error)
	_commit(
		decoded["state"] as ItemOwnershipState,
		decoded["metadata"] as Dictionary,
		decoded["journal"] as ItemTransactionJournal
	)
	return ""

func _fail(error: String) -> String:
	_integrity_error = error
	return error

func _code_name(code: ItemTransactionResult.Code) -> String:
	var names := ItemTransactionResult.Code.keys()
	return String(names[int(code)]) if int(code) >= 0 and int(code) < names.size() else "INVALID_REQUEST"
