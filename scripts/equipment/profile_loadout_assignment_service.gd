class_name ProfileLoadoutAssignmentService
extends RefCounted

const OPERATION := "profile_loadout_assignment"
const ERROR_PREFIX := "PARTY_FORGE_PROFILE_LOADOUT_ASSIGNMENT_ERROR"
const LEADER_ID := &"leader-loadout"

var _mutations: ProfileMutationService
var _transactions: ItemContainerTransactionService
var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog
var _classes: GameCatalog

func _init(
	mutations: ProfileMutationService = null,
	transactions: ItemContainerTransactionService = null,
	equipment: EquipmentCatalog = null,
	foundation: ItemFoundationCatalog = null,
	classes: GameCatalog = null,
) -> void:
	_mutations = mutations if mutations != null else ProfileMutationService.new()
	_transactions = transactions if transactions != null else ItemContainerTransactionService.new()
	_equipment = equipment if equipment != null else GameCatalog.EQUIPMENT_CATALOG
	_foundation = foundation if foundation != null else GameCatalog.ITEM_FOUNDATION_CATALOG
	_classes = classes if classes != null else GameCatalog.load_defaults()

func apply(profile_id: String, request: ProfileLoadoutAssignmentRequest, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	var error := _validate_request(profile_id, request)
	if not error.is_empty():
		return _failure(error)
	return _mutations.apply(
		profile_id,
		request.transaction_id,
		func(candidate: ProfileState) -> String: return _apply_candidate(candidate, request),
		root,
		-1,
		OPERATION,
		request.canonical_document(),
	)

func _validate_request(profile_id: String, request: ProfileLoadoutAssignmentRequest) -> String:
	if request == null:
		return _error("field=request reason=must not be null")
	if request.transaction_id.strip_edges().is_empty():
		return _error("field=transaction_id reason=must not be empty")
	if profile_id.strip_edges().is_empty() or profile_id != request.profile_id:
		return _error("field=profile_id reason=profile identity mismatch")
	if request.item_id.strip_edges().is_empty():
		return _error("field=item_id reason=must not be empty")
	if request.selected_class_id.is_empty() or _classes.class_by_id(request.selected_class_id) == null:
		return _error("field=selected_class_id reason=unknown authoritative class")
	if request.source_container_id == request.destination_container_id and request.source_slot == request.destination_slot:
		return _error("field=destination reason=source and destination must differ")
	if request.source_container_id != LEADER_ID and request.destination_container_id != LEADER_ID:
		return _error("field=containers reason=one endpoint must be leader-loadout")
	if request.source_container_id == LEADER_ID and request.destination_container_id == LEADER_ID:
		return _error("field=containers reason=assignment cannot move within leader-loadout")
	if request.state_fingerprint.length() != 64 or not request.state_fingerprint.is_valid_hex_number(false):
		return _error("field=state_fingerprint reason=complete preflight fingerprint is required")
	return ""

func _apply_candidate(candidate: ProfileState, request: ProfileLoadoutAssignmentRequest) -> String:
	if candidate == null or candidate.profile_id != request.profile_id:
		return _error("field=profile_id reason=candidate profile mismatch")
	if ProfileLoadoutAssignmentRequest.fingerprint_for(candidate) != request.state_fingerprint:
		return _error("field=state_fingerprint reason=stale profile ownership state")
	var selected_class := _classes.class_by_id(request.selected_class_id)
	if selected_class == null or selected_class.id != request.selected_class_id:
		return _error("field=selected_class_id reason=authoritative class lookup failed")
	var decoded := _profile_ownership(candidate)
	if not decoded.ok():
		return _error("field=ownership reason=%s" % decoded.error)
	var state := decoded.state
	var leader := state.container(LEADER_ID)
	var source := state.container(request.source_container_id)
	var destination := state.container(request.destination_container_id)
	if leader == null or source == null or destination == null:
		return _error("field=containers reason=source or destination is missing")
	if request.source_slot < 0 or request.source_slot >= source.capacity or source.item_id_at(request.source_slot) != request.item_id:
		return _error("field=source reason=stale source item or slot")
	if request.destination_slot < 0 or request.destination_slot >= destination.capacity:
		return _error("field=destination_slot reason=out of bounds")
	var occupied := destination.item_id_at(request.destination_slot)
	if occupied != request.expected_destination_item_id:
		return _error("field=expected_destination_item_id reason=stale destination occupancy")
	var was_nonempty := not leader.occupied_slots().is_empty()
	if was_nonempty and candidate.leader_loadout_class_id != String(request.selected_class_id):
		return _error("field=selected_class_id reason=nonempty loadout requires compatibility transition")

	var transaction_request := ItemTransactionRequest.swap(
		request.transaction_id, candidate.profile_id, request.source_container_id, request.source_slot,
		request.item_id, request.destination_container_id, request.destination_slot,
	) if not occupied.is_empty() else ItemTransactionRequest.move(
		request.transaction_id, candidate.profile_id, request.source_container_id, request.source_slot,
		request.item_id, request.destination_container_id, request.destination_slot,
	)
	var transaction := _transactions.apply(state, transaction_request, ItemTransactionJournal.new(), _equipment, _foundation)
	if transaction.code != ItemTransactionResult.Code.OK or transaction.next_state == null:
		return _error("field=transaction reason=%s" % _transaction_code(transaction.code))
	var next_state := transaction.next_state
	var eligibility_error := _validate_complete_loadout(next_state, selected_class)
	if not eligibility_error.is_empty():
		return _error("field=leader_loadout reason=ineligible resulting loadout detail=%s" % eligibility_error)

	candidate.item_records = next_state.registry().to_dictionary()
	candidate.leader_loadout = next_state.container(LEADER_ID).to_dictionary()
	var stored_tabs: Array[Dictionary] = []
	for stored: Dictionary in candidate.stash_tabs:
		var tab := next_state.container(StringName(String(stored.get("container_id", ""))))
		if tab == null:
			return _error("field=stash_tabs reason=stored tab disappeared")
		stored_tabs.append(tab.to_dictionary())
	candidate.stash_tabs = stored_tabs
	candidate.leader_loadout_class_id = String(request.selected_class_id)
	return ""

func _validate_complete_loadout(state: ItemOwnershipState, class_definition: ClassDefinition) -> String:
	var leader := state.container(LEADER_ID)
	var registry := state.registry()
	if leader == null or registry == null:
		return "leader ownership is unavailable"
	var loadout: Dictionary = {}
	for slot: int in leader.occupied_slots():
		var item := registry.item(leader.item_id_at(slot))
		var definition := _equipment.definition(item.base_definition_id) if item != null else null
		if definition == null:
			return "equipped item definition is unavailable"
		loadout[EquipmentSlotIndex.slot_for(slot)] = definition
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		var definition := loadout.get(slot_id) as EquipmentBaseDefinition
		if definition == null:
			continue
		var errors := EquipmentEligibility.validate_equip(definition, class_definition, slot_id, loadout, class_definition.stat_base_values())
		if not errors.is_empty():
			return errors[0]
	var off_hand := loadout.get(&"off_hand") as EquipmentBaseDefinition
	if off_hand != null and off_hand.item_type_id == &"quiver":
		var main_hand := loadout.get(&"main_hand") as EquipmentBaseDefinition
		if main_hand == null:
			return "quiver %s requires a main-hand bow" % off_hand.id
		if &"off_hand" not in main_hand.reserved_slot_ids or off_hand.item_type_id not in main_hand.compatible_offhand_item_types:
			return "quiver %s is not permitted by %s" % [off_hand.id, main_hand.id]
		if main_hand.weapon_family_id.is_empty() or off_hand.weapon_family_id != main_hand.weapon_family_id:
			return "quiver %s family does not match %s" % [off_hand.id, main_hand.id]
	return ""

func _profile_ownership(profile: ProfileState) -> ItemOwnershipStateDecodeResult:
	var containers: Array = [profile.leader_loadout.duplicate(true)]
	containers.append_array(profile.stash_tabs.duplicate(true))
	return ItemOwnershipState.decode({
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": profile.profile_id,
		"registry": profile.item_records.duplicate(true),
		"containers": containers,
	}, _equipment, _foundation)

func _transaction_code(code: ItemTransactionResult.Code) -> String:
	var names := ItemTransactionResult.Code.keys()
	return String(names[int(code)]) if int(code) >= 0 and int(code) < names.size() else "INVALID_REQUEST"

func _failure(detail: String) -> ProfileMutationResult:
	var result := ProfileMutationResult.new()
	result.error = detail
	return result

func _error(detail: String) -> String:
	return "%s %s" % [ERROR_PREFIX, detail]
