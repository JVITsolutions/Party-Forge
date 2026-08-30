class_name ProfileLoadoutAssignmentService
extends RefCounted

const OPERATION := "profile_loadout_assignment"
const ERROR_PREFIX := "PARTY_FORGE_PROFILE_LOADOUT_ASSIGNMENT_ERROR"
const LEADER_ID := &"leader-loadout"
const DEFAULT_ATTRIBUTE_PROJECTION: AttributeProjectionTuning = preload("res://data/stats/default_attribute_projection.tres")
const CANDIDATE_ACTION_VALIDATION := preload("res://scripts/combat/candidate_action_validation_service.gd")

var _mutations: ProfileMutationService
var _transactions: ItemContainerTransactionService
var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog
var _classes: GameCatalog
var _stats: StatCatalog
var _damage_types: DamageTypeCatalog
var _attribute_tuning: AttributeProjectionTuning

func _init(
	mutations: ProfileMutationService = null,
	transactions: ItemContainerTransactionService = null,
	equipment: EquipmentCatalog = null,
	foundation: ItemFoundationCatalog = null,
	classes: GameCatalog = null,
	stats: StatCatalog = null,
	damage_types: DamageTypeCatalog = null,
	attribute_tuning: AttributeProjectionTuning = null,
) -> void:
	_mutations = mutations if mutations != null else ProfileMutationService.new()
	_transactions = transactions if transactions != null else ItemContainerTransactionService.new()
	_equipment = equipment if equipment != null else GameCatalog.EQUIPMENT_CATALOG
	_foundation = foundation if foundation != null else GameCatalog.ITEM_FOUNDATION_CATALOG
	_classes = classes if classes != null else GameCatalog.load_defaults()
	_stats = stats if stats != null else GameCatalog.STAT_CATALOG
	_damage_types = damage_types if damage_types != null else GameCatalog.DAMAGE_TYPES
	_attribute_tuning = attribute_tuning if attribute_tuning != null else DEFAULT_ATTRIBUTE_PROJECTION

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

func preview(profile: ProfileState, request: ProfileLoadoutAssignmentRequest) -> ProfileMutationResult:
	if profile == null:
		return _failure(_error("field=profile reason=must not be null"))
	var error := _validate_request(profile.profile_id, request)
	if not error.is_empty():
		return _failure(error)
	var candidate := profile.copy()
	if candidate == null:
		return _failure(_error("field=profile reason=copy failed"))
	error = _apply_candidate(candidate, request)
	if not error.is_empty():
		return _failure(error)
	candidate.normalize()
	var validation := ProfileCodec.validate_profile(candidate)
	if not validation.is_empty():
		return _failure(validation)
	var result := ProfileMutationResult.new()
	result.profile = candidate
	return result

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
	if (
		request.source_container_id == ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID
		or request.destination_container_id == ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID
	):
		return _error("field=containers reason=recovery overflow cannot be an equipment assignment endpoint")
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

	var storage_ids: Array[StringName] = []
	for stash_document: Dictionary in candidate.stash_tabs:
		storage_ids.append(StringName(String(stash_document.get("container_id", ""))))
	var planned := EquipmentOwnershipTransitionPlanner.preview(
		state,
		request.item_id,
		request.source_container_id,
		request.source_slot,
		request.destination_container_id,
		request.destination_slot,
		LEADER_ID,
		storage_ids,
		_equipment,
		_foundation,
	)
	if not planned.ok():
		return _error("field=transition reason=%s" % planned.error)
	var next_state := planned.state()
	var eligibility_error := _validate_complete_loadout(next_state, selected_class)
	if not eligibility_error.is_empty():
		return _error("field=leader_loadout reason=ineligible resulting loadout detail=%s" % eligibility_error)
	var activation := EquipmentActivationResolver.resolve(
		1,
		LEADER_ID,
		next_state,
		_equipment,
		_foundation,
		_stats,
		selected_class.stat_base_values(),
		selected_class.capability_tags,
		[],
		0,
	)
	if not activation.ok():
		return _error("field=leader_loadout reason=activation failed detail=%s" % activation.error)
	for item_entering_leader: String in planned.newly_equipped_item_ids():
		if not activation.is_active(item_entering_leader):
			return _error("field=leader_loadout item=%s reason=newly placed item is inactive detail=%s" % [item_entering_leader, "; ".join(activation.disabled_reasons(item_entering_leader))])
	var candidate_error := _validate_candidate_projection(selected_class, activation)
	if not candidate_error.is_empty():
		return _error("field=leader_loadout reason=%s" % candidate_error)

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

func _validate_candidate_projection(
	class_definition: ClassDefinition,
	activation: EquipmentActivationResult,
) -> String:
	var sources: Array[StatModifierSource] = [activation.source]
	var resolution := MemberStatResolutionService.resolve(
		1,
		_stats,
		class_definition.stat_base_values(),
		class_definition.capability_tags,
		sources,
		[],
		0,
		_attribute_tuning,
	)
	if not resolution.ok():
		return "stat resolution failed detail=%s" % resolution.error
	return CANDIDATE_ACTION_VALIDATION.validate(
		class_definition,
		1,
		_stats,
		_damage_types,
		class_definition.stat_base_values(),
		class_definition.capability_tags,
		sources,
		0,
		_attribute_tuning,
		activation.weapon_snapshot(),
	)

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
		var errors := EquipmentEligibility.validate_structure(definition, class_definition, slot_id, loadout)
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
	containers.append(profile.terminal_recovery_overflow.duplicate(true))
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
