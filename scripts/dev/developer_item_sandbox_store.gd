class_name DeveloperItemSandboxStore
extends RefCounted

const SCHEMA_VERSION := 1
const ROOT := "user://developer_item_sandbox"
const DOCUMENT_PATH := "user://developer_item_sandbox/sandbox.json"
const OWNER_ID := "developer-item-sandbox"
const DOCUMENT_FIELDS: Array[String] = [
	"schema_version",
	"owner_id",
	"ownership_state",
	"issuance_metadata",
	"transaction_journal",
]
const METADATA_FIELDS: Array[String] = [
	"schema_version",
	"owner_id",
	"issuer_namespace",
	"issued_count",
	"definition_ids",
	"next_transaction_sequence",
]
const JOURNAL_FIELDS: Array[String] = ["transaction_id", "fingerprint", "code", "state"]

var _documents: AtomicJsonStore

func _init(documents: AtomicJsonStore = null) -> void:
	_documents = documents if documents != null else AtomicJsonStore.new()

func save_document(document: Dictionary) -> String:
	return _documents.save_document(DOCUMENT_PATH, document, Callable(self, "validate_document"))

func load_document() -> JsonDocumentResult:
	return _documents.load_document(DOCUMENT_PATH, Callable(self, "validate_document"))

func scan_persisted_document() -> String:
	if not FileAccess.file_exists(DOCUMENT_PATH):
		return _error("document", "persisted sandbox document is missing")
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(DOCUMENT_PATH)) != OK:
		return _error("document", "persisted sandbox document must be a valid JSON dictionary")
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return _error("document", "persisted sandbox document must be a valid JSON dictionary")
	return validate_document(parsed as Dictionary)

func validate_document(document: Dictionary) -> String:
	return String(decode_document(document).get("error", ""))

func decode_document(document: Variant) -> Dictionary:
	if not document is Dictionary:
		return _failure("document", "must be a dictionary")
	var data := document as Dictionary
	var fields_error := ItemRegistry._exact_fields(data, DOCUMENT_FIELDS, "document")
	if not fields_error.is_empty():
		return _failure("document", _reason_from_registry_error(fields_error))
	if not ItemInstanceCodec._is_json_int(data["schema_version"], SCHEMA_VERSION, SCHEMA_VERSION):
		return _failure("schema_version", "must equal supported schema %d" % SCHEMA_VERSION)
	if typeof(data["owner_id"]) != TYPE_STRING or String(data["owner_id"]) != OWNER_ID:
		return _failure("owner_id", "must equal %s" % OWNER_ID)
	var ownership := ItemOwnershipState.decode(
		data["ownership_state"],
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	if not ownership.ok():
		return _failure("ownership_state", ownership.error)
	var ownership_error := _validate_ownership_contract(ownership.state)
	if not ownership_error.is_empty():
		return {"error": ownership_error}
	var canonical_result := _canonical_fixture_state()
	if not String(canonical_result.get("error", "")).is_empty():
		return canonical_result
	var canonical_state := canonical_result["state"] as ItemOwnershipState
	var fixture_registry_error := _validate_fixture_registry(
		ownership.state,
		canonical_state,
		"ownership_state"
	)
	if not fixture_registry_error.is_empty():
		return {"error": fixture_registry_error}
	var metadata_result := _decode_metadata(data["issuance_metadata"])
	if not String(metadata_result.get("error", "")).is_empty():
		return metadata_result
	var journal_result := _decode_journal(
		data["transaction_journal"],
		ownership.state,
		int((metadata_result["metadata"] as Dictionary)["next_transaction_sequence"]),
		canonical_state
	)
	if not String(journal_result.get("error", "")).is_empty():
		return journal_result
	return {
		"state": ownership.state,
		"metadata": (metadata_result["metadata"] as Dictionary).duplicate(true),
		"journal": journal_result["journal"],
		"error": "",
	}

func document_for(
	state: ItemOwnershipState,
	metadata: Dictionary,
	journal: ItemTransactionJournal
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"owner_id": OWNER_ID,
		"ownership_state": state.to_dictionary() if state != null else {},
		"issuance_metadata": ItemInstance._json_copy(metadata),
		"transaction_journal": _journal_document(journal),
	}

func _validate_ownership_contract(state: ItemOwnershipState) -> String:
	if state.owner_id != OWNER_ID:
		return _error("ownership_state.owner_id", "must equal %s" % OWNER_ID)
	var registry := state.registry()
	if registry == null or registry.size() != DeveloperItemFixtureIssuer.EXPECTED_DEFINITION_COUNT:
		return _error("ownership_state.registry", "must contain exactly 99 items")
	var inventory := state.container(&"developer-inventory")
	var stash := state.container(&"developer-stash-000")
	if state.containers().size() != 2 or inventory == null or stash == null:
		return _error("ownership_state.containers", "must contain only the developer inventory and stash")
	if inventory.container_kind != ItemSlotContainer.DEVELOPER_INVENTORY or inventory.capacity != 5:
		return _error("ownership_state.containers", "developer inventory contract is invalid")
	if stash.container_kind != ItemSlotContainer.DEVELOPER_STASH_TAB or stash.capacity != 100:
		return _error("ownership_state.containers", "developer stash contract is invalid")
	var seen_bases: Dictionary = {}
	for instance_id: String in registry.ids():
		var item := registry.item(instance_id)
		seen_bases[String(item.base_definition_id)] = int(seen_bases.get(String(item.base_definition_id), 0)) + 1
	for definition: EquipmentBaseDefinition in GameCatalog.EQUIPMENT_CATALOG.definitions:
		if int(seen_bases.get(String(definition.id), 0)) != 1:
			return _error("ownership_state.registry", "equipment base %s must appear exactly once" % definition.id)
	return ""

func _decode_metadata(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _failure("issuance_metadata", "must be a dictionary")
	var data := value as Dictionary
	var fields_error := ItemRegistry._exact_fields(data, METADATA_FIELDS, "issuance_metadata")
	if not fields_error.is_empty():
		return _failure("issuance_metadata", _reason_from_registry_error(fields_error))
	if not ItemInstanceCodec._is_json_int(data["schema_version"], SCHEMA_VERSION, SCHEMA_VERSION):
		return _failure("issuance_metadata.schema_version", "must equal supported schema %d" % SCHEMA_VERSION)
	if typeof(data["owner_id"]) != TYPE_STRING or String(data["owner_id"]) != OWNER_ID:
		return _failure("issuance_metadata.owner_id", "must equal %s" % OWNER_ID)
	if typeof(data["issuer_namespace"]) != TYPE_STRING or String(data["issuer_namespace"]) != DeveloperItemFixtureIssuer.ISSUER_NAMESPACE:
		return _failure("issuance_metadata.issuer_namespace", "must equal %s" % DeveloperItemFixtureIssuer.ISSUER_NAMESPACE)
	if not ItemInstanceCodec._is_json_int(data["issued_count"], 99, 99):
		return _failure("issuance_metadata.issued_count", "must equal 99")
	if not ItemInstanceCodec._is_json_int(data["next_transaction_sequence"], 0, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
		return _failure("issuance_metadata.next_transaction_sequence", "must be a non-negative JSON-safe integer")
	if not data["definition_ids"] is Array or (data["definition_ids"] as Array).size() != 99:
		return _failure("issuance_metadata.definition_ids", "must contain exactly 99 IDs")
	for index: int in GameCatalog.EQUIPMENT_CATALOG.definitions.size():
		var value_at_index: Variant = (data["definition_ids"] as Array)[index]
		var expected := String(GameCatalog.EQUIPMENT_CATALOG.definitions[index].id)
		if typeof(value_at_index) != TYPE_STRING or String(value_at_index) != expected:
			return _failure("issuance_metadata.definition_ids[%d]" % index, "must equal catalog ID %s" % expected)
	return {"metadata": data.duplicate(true), "error": ""}

func _decode_journal(
	value: Variant,
	current_state: ItemOwnershipState,
	next_transaction_sequence: int,
	canonical_state: ItemOwnershipState
) -> Dictionary:
	if not value is Array:
		return _failure("transaction_journal", "must be an array")
	if (value as Array).size() != next_transaction_sequence:
		return _failure(
			"transaction_journal",
			"entry count must equal next transaction sequence %d" % next_transaction_sequence
		)
	var journal := ItemTransactionJournal.new()
	var seen: Dictionary = {}
	var final_state: ItemOwnershipState
	var previous_state := canonical_state.copy()
	if (value as Array).is_empty():
		var canonical_error := _validate_canonical_reset(current_state, canonical_state)
		if not canonical_error.is_empty():
			return {"error": canonical_error}
	for index: int in (value as Array).size():
		var entry_value: Variant = (value as Array)[index]
		var path := "transaction_journal[%d]" % index
		if not entry_value is Dictionary:
			return _failure(path, "must be a dictionary")
		var entry := entry_value as Dictionary
		var fields_error := ItemRegistry._exact_fields(entry, JOURNAL_FIELDS, path)
		if not fields_error.is_empty():
			return _failure(path, _reason_from_registry_error(fields_error))
		if typeof(entry["transaction_id"]) != TYPE_STRING or String(entry["transaction_id"]).strip_edges().is_empty():
			return _failure("%s.transaction_id" % path, "must be a non-empty string")
		var transaction_id := String(entry["transaction_id"])
		var expected_transaction_id := "sandbox-move-%016d" % index
		if transaction_id != expected_transaction_id:
			return _failure(
				"%s.transaction_id" % path,
				"must equal canonical sequence ID %s" % expected_transaction_id
			)
		if seen.has(transaction_id):
			return _failure("%s.transaction_id" % path, "duplicate transaction ID %s" % transaction_id)
		seen[transaction_id] = true
		if typeof(entry["fingerprint"]) != TYPE_STRING or not _is_sha256(String(entry["fingerprint"])):
			return _failure("%s.fingerprint" % path, "must be a lowercase SHA-256 string")
		if not ItemInstanceCodec._is_json_int(entry["code"], ItemTransactionResult.Code.OK, ItemTransactionResult.Code.OK):
			return _failure("%s.code" % path, "must equal OK")
		var decoded_state := ItemOwnershipState.decode(
			entry["state"],
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG
		)
		if not decoded_state.ok():
			return _failure("%s.state" % path, decoded_state.error)
		var state_contract_error := _validate_ownership_contract(decoded_state.state)
		if not state_contract_error.is_empty():
			return {"error": state_contract_error}
		var fixture_registry_error := _validate_fixture_registry(
			decoded_state.state,
			canonical_state,
			"%s.state" % path
		)
		if not fixture_registry_error.is_empty():
			return {"error": fixture_registry_error}
		var transition := _reconstruct_transaction_request(
			previous_state,
			decoded_state.state,
			transaction_id,
			String(entry["fingerprint"]),
			path
		)
		var transition_error := String(transition.get("error", ""))
		if not transition_error.is_empty():
			return {"error": transition_error}
		var request := transition["request"] as ItemTransactionRequest
		if request.fingerprint() != String(entry["fingerprint"]):
			return _failure("%s.fingerprint" % path, "must match canonical Task 4 move request")
		journal._record_success(transaction_id, String(entry["fingerprint"]), ItemTransactionResult.Code.OK, decoded_state.state)
		final_state = decoded_state.state
		previous_state = decoded_state.state
	if final_state != null and final_state.to_dictionary() != current_state.to_dictionary():
		return _failure("transaction_journal", "final entry must contain the current ownership state")
	return {"journal": journal, "error": ""}

func _canonical_fixture_state() -> Dictionary:
	var issued := DeveloperItemFixtureIssuer.issue_all(
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	var issuance_error := String(issued.get("error", ""))
	if not issuance_error.is_empty():
		return _failure("canonical_fixture", issuance_error)
	var items := issued["items"] as Array[ItemInstance]
	var slots: Dictionary = {}
	for index: int in items.size():
		slots[index] = items[index].instance_id
	var state := ItemOwnershipState.create(
		OWNER_ID,
		ItemRegistry.new(items),
		[
			ItemSlotContainer.create(
				&"developer-inventory",
				ItemSlotContainer.DEVELOPER_INVENTORY,
				OWNER_ID,
				5
			),
			ItemSlotContainer.create(
				&"developer-stash-000",
				ItemSlotContainer.DEVELOPER_STASH_TAB,
				OWNER_ID,
				100,
				slots
			),
		] as Array[ItemSlotContainer]
	)
	var validation_error := state.validate(
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	if not validation_error.is_empty():
		return _failure("canonical_fixture", validation_error)
	return {"state": state, "error": ""}

func _validate_fixture_registry(
	state: ItemOwnershipState,
	canonical_state: ItemOwnershipState,
	path: String
) -> String:
	if JSON.stringify(state.registry().to_dictionary()) != JSON.stringify(canonical_state.registry().to_dictionary()):
		return _error("%s.registry" % path, "must equal the exact deterministic 99-item fixture")
	return ""

func _validate_canonical_reset(
	state: ItemOwnershipState,
	canonical_state: ItemOwnershipState
) -> String:
	if not _states_match(state, canonical_state):
		return _error("transaction_journal", "empty journal requires the exact canonical reset state")
	return ""

func _reconstruct_transaction_request(
	previous_state: ItemOwnershipState,
	next_state: ItemOwnershipState,
	transaction_id: String,
	fingerprint: String,
	path: String
) -> Dictionary:
	var changed_ids: Array[String] = []
	for instance_id: String in previous_state.registry().ids():
		if _item_location(previous_state, instance_id) != _item_location(next_state, instance_id):
			changed_ids.append(instance_id)
	if changed_ids.size() not in [1, 2]:
		return _failure(path, "must move one fixture item or swap exactly two fixture items")
	for instance_id: String in changed_ids:
		var source := _item_location(previous_state, instance_id)
		var destination := _item_location(next_state, instance_id)
		var source_id := StringName(String(source.get("container_id", "")))
		var destination_id := StringName(String(destination.get("container_id", "")))
		if not _is_developer_container(source_id) or not _is_developer_container(destination_id):
			continue
		var destination_container := previous_state.container(destination_id)
		if destination_container == null:
			continue
		var destination_slot := int(destination.get("slot", -1))
		var destination_item_id := destination_container.item_id_at(destination_slot)
		var request := ItemTransactionRequest.move(
			transaction_id,
			OWNER_ID,
			source_id,
			int(source.get("slot", -1)),
			instance_id,
			destination_id,
			destination_slot
		) if destination_item_id.is_empty() else ItemTransactionRequest.swap(
			transaction_id,
			OWNER_ID,
			source_id,
			int(source.get("slot", -1)),
			instance_id,
			destination_id,
			destination_slot
		)
		if request.fingerprint() != fingerprint:
			continue
		var applied := ItemContainerTransactionService.new().apply(
			previous_state,
			request,
			ItemTransactionJournal.new(),
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG
		)
		if applied.code == ItemTransactionResult.Code.OK and applied.next_state != null and _states_match(applied.next_state, next_state):
			return {"request": request, "error": ""}
	return _failure(path, "state and fingerprint must equal one exact canonical Task 4 move or swap")

func _item_location(state: ItemOwnershipState, instance_id: String) -> Dictionary:
	for container: ItemSlotContainer in state.containers():
		for slot: int in container.occupied_slots():
			if container.item_id_at(slot) == instance_id:
				return {"container_id": String(container.container_id), "slot": slot}
	return {}

func _is_developer_container(container_id: StringName) -> bool:
	return container_id in [&"developer-inventory", &"developer-stash-000"]

func _states_match(first: ItemOwnershipState, second: ItemOwnershipState) -> bool:
	return JSON.stringify(first.to_dictionary()) == JSON.stringify(second.to_dictionary())

func _journal_document(journal: ItemTransactionJournal) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if journal == null:
		return result
	for transaction_id: String in journal.entries():
		var entry := journal.entry(transaction_id)
		var state := entry.get("state") as ItemOwnershipState
		result.append({
			"transaction_id": transaction_id,
			"fingerprint": String(entry.get("fingerprint", "")),
			"code": int(entry.get("code", ItemTransactionResult.Code.INVALID_REQUEST)),
			"state": state.to_dictionary() if state != null else {},
		})
	return result

func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in value.length():
		if value.substr(index, 1) not in "0123456789abcdef":
			return false
	return true

func _reason_from_registry_error(error: String) -> String:
	var reason_index := error.find(" reason=")
	return error.substr(reason_index + 8) if reason_index >= 0 else error

func _failure(field: String, reason: String) -> Dictionary:
	return {"error": _error(field, reason)}

func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=%s reason=%s" % [field, reason]
