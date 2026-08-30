class_name ProfileItemStorageService
extends RefCounted

const OPERATION := "item_storage_transaction"
const PERSISTENT_OPERATIONS: Array[String] = [
	ItemTransactionRequest.CREATE_AND_PLACE,
	ItemTransactionRequest.MOVE_TO_EMPTY,
	ItemTransactionRequest.SWAP_OCCUPIED,
]

var _mutations: ProfileMutationService
var _transactions: ItemContainerTransactionService

func _init(
	mutations: ProfileMutationService = null,
	transactions: ItemContainerTransactionService = null
) -> void:
	_mutations = mutations if mutations != null else ProfileMutationService.new()
	_transactions = transactions if transactions != null else ItemContainerTransactionService.new()

func apply(
	profile_id: String,
	request: ItemTransactionRequest,
	root: String = ProfileStore.DEFAULT_ROOT
) -> ProfileMutationResult:
	if request == null:
		return _failure("PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request reason=must not be null")
	var container_error := _validate_container_domain(request)
	if not container_error.is_empty():
		return _failure(container_error)
	if request.operation not in PERSISTENT_OPERATIONS:
		return _failure(
			"PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.operation reason=unsupported persistent operation %s"
			% request.operation
		)
	var canonical_request := request.canonical_document()
	return _mutations.apply(
		profile_id,
		request.transaction_id,
		func(profile: ProfileState) -> String:
			var container_documents: Array = [profile.leader_loadout.duplicate(true)]
			container_documents.append_array(profile.stash_tabs.duplicate(true))
			container_documents.append(profile.terminal_recovery_overflow.duplicate(true))
			var ownership := ItemOwnershipState.decode(
				{
					"schema_version": ItemOwnershipState.SCHEMA_VERSION,
					"owner_id": profile.profile_id,
					"registry": profile.item_records.duplicate(true),
					"containers": container_documents,
				},
				GameCatalog.EQUIPMENT_CATALOG,
				GameCatalog.ITEM_FOUNDATION_CATALOG
			)
			if not ownership.ok():
				return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=ownership reason=%s" % ownership.error
			if request.operation == ItemTransactionRequest.CREATE_AND_PLACE:
				var create_error := _validate_create(profile, request)
				if not create_error.is_empty():
					return create_error
			var overflow_error := _validate_overflow_request(profile, ownership.state, request)
			if not overflow_error.is_empty():
				return overflow_error
			var transaction_result := _transactions.apply(
				ownership.state,
				request,
				ItemTransactionJournal.new(),
				GameCatalog.EQUIPMENT_CATALOG,
				GameCatalog.ITEM_FOUNDATION_CATALOG
			)
			if transaction_result.code != ItemTransactionResult.Code.OK:
				return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR code=%s" % _code_name(transaction_result.code)
			var candidate := transaction_result.next_state
			if candidate == null:
				return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR code=INVALID_ITEM"
			profile.item_records = candidate.registry().to_dictionary()
			var stash_ids: Array[StringName] = []
			for stash_document: Dictionary in profile.stash_tabs:
				stash_ids.append(StringName(String(stash_document["container_id"])))
			profile.stash_tabs = []
			for stash_id: StringName in stash_ids:
				profile.stash_tabs.append(candidate.container(stash_id).to_dictionary())
			profile.terminal_recovery_overflow = candidate.container(
				ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID
			).to_dictionary()
			if request.operation == ItemTransactionRequest.CREATE_AND_PLACE:
				profile.next_item_sequence += 1
			return ""
	,
		root,
		-1,
		OPERATION,
		canonical_request
	)

static func _validate_container_domain(request: ItemTransactionRequest) -> String:
	if request.source_container_id == "leader-loadout":
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.source_container_id reason=leader-loadout is reserved for equipment assignment"
	if request.destination_container_id == "leader-loadout":
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.destination_container_id reason=leader-loadout is reserved for equipment assignment"
	if request.destination_container_id == String(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID):
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.destination_container_id reason=recovery overflow is source only"
	if request.source_container_id == String(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID) and request.operation != ItemTransactionRequest.MOVE_TO_EMPTY:
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.operation reason=recovery overflow permits only move_to_empty"
	return ""

func _validate_overflow_request(
	profile: ProfileState,
	state: ItemOwnershipState,
	request: ItemTransactionRequest,
) -> String:
	if request.source_container_id != String(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID):
		return ""
	var source := state.container(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID)
	var destination := state.container(StringName(request.destination_container_id))
	if source == null or source.container_kind != ItemSlotContainer.PROFILE_TERMINAL_RECOVERY_OVERFLOW:
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.source_container_id reason=recovery overflow source is unavailable"
	if destination == null or destination.container_kind != ItemSlotContainer.PROFILE_STASH_TAB:
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.destination_container_id reason=recovery overflow may move only to ordinary stash"
	if request.destination_slot < 0 or request.destination_slot >= destination.capacity:
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.destination_slot reason=out of bounds"
	if not destination.item_id_at(request.destination_slot).is_empty():
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.destination_slot reason=recovery overflow requires an empty ordinary stash slot"
	var terminal := RunTerminalRecoveryCodec.decode(profile.terminal_resolution) if not profile.terminal_resolution.is_empty() else null
	if not profile.terminal_resolution.is_empty() and (terminal == null or not terminal.ok()):
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=terminal_resolution reason=current recovery protection is invalid"
	if terminal != null and terminal.ok() and request.expected_instance_id in terminal.record.protected_displaced_item_ids:
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.expected_instance_id reason=Available after terminal resolution"
	return ""

func _validate_create(profile: ProfileState, request: ItemTransactionRequest) -> String:
	var item := request.create_item
	if item == null:
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=create_item reason=must not be null"
	var expected_namespace := "profile:%s" % profile.profile_id
	var namespace_value: Variant = item.origin.get("issuer_namespace")
	if typeof(namespace_value) != TYPE_STRING or String(namespace_value) != expected_namespace:
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=create_item.origin.issuer_namespace reason=must equal %s" % expected_namespace
	var sequence_value: Variant = item.origin.get("sequence")
	if not _is_nonnegative_json_int(sequence_value) or int(sequence_value) != profile.next_item_sequence:
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=create_item.origin.sequence reason=must equal next_item_sequence %d" % profile.next_item_sequence
	if profile.next_item_sequence >= ProfileCodec.JSON_SAFE_INTEGER_MAX:
		return "PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=next_item_sequence reason=sequence exhausted"
	return ""

static func _is_nonnegative_json_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 0 and int(value) <= ProfileCodec.JSON_SAFE_INTEGER_MAX
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return (
		is_finite(number)
		and number == floor(number)
		and number >= 0.0
		and number <= float(ProfileCodec.JSON_SAFE_INTEGER_MAX)
	)

static func _code_name(code: ItemTransactionResult.Code) -> String:
	var names := ItemTransactionResult.Code.keys()
	return String(names[int(code)]) if int(code) >= 0 and int(code) < names.size() else "INVALID_REQUEST"

static func _failure(error: String) -> ProfileMutationResult:
	var result := ProfileMutationResult.new()
	result.error = error
	return result
