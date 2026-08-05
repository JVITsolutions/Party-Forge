class_name RunResolutionService
extends RefCounted

const OPERATION := "run_resolution"
const ERROR_PREFIX := "PARTY_FORGE_RUN_RESOLUTION_ERROR"

var _mutations: ProfileMutationService

func _init(mutations: ProfileMutationService = null) -> void:
	_mutations = mutations if mutations != null else ProfileMutationService.new()

func resolve(
	profile_id: String,
	context: PlayerRunContext,
	request: RunResolutionRequest,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> RunResolutionResult:
	var request_error := _validate_request(profile_id, context, request)
	if not request_error.is_empty():
		return RunResolutionResult.failure(request_error)
	var marker_error := context.item_resolution_error(request.transaction_id)
	if not marker_error.is_empty():
		return RunResolutionResult.failure(marker_error)
	var mutation := _mutations.apply_with_resumable_run_revocation(
		profile_id,
		request.transaction_id,
		request.run_id,
		func(candidate: ProfileState) -> String:
			return _resolve_candidate(candidate, context, request),
		root,
		-1,
		OPERATION,
		request.canonical_document(),
	)
	if not mutation.ok():
		return RunResolutionResult.failure(mutation.error)
	context.mark_items_resolved(request.transaction_id)
	return RunResolutionResult.success(mutation.profile, mutation.duplicate)

func _validate_request(profile_id: String, context: PlayerRunContext, request: RunResolutionRequest) -> String:
	if request == null:
		return _error("field=request reason=must not be null")
	if request.transaction_id.strip_edges().is_empty():
		return _error("field=transaction_id reason=must not be empty")
	if profile_id != request.profile_id:
		return _error("field=profile_id reason=profile identity mismatch")
	if String(request.run_id).strip_edges().is_empty():
		return _error("field=run_id reason=must not be empty")
	if request.run_seed <= 0:
		return _error("field=run_seed reason=must be positive")
	if String(request.run_player_id).strip_edges().is_empty():
		return _error("field=run_player_id reason=must not be empty")
	if request.leader_member_id <= 0:
		return _error("field=leader_member_id reason=must be positive")
	for index: int in request.ordinary_selections.size():
		if request.ordinary_selections[index] == null:
			return _error("field=ordinary_selections[%d] reason=must not be null" % index)
	if context == null:
		return _error("field=context reason=must not be null")
	return ""

func _resolve_candidate(
	candidate: ProfileState,
	context: PlayerRunContext,
	request: RunResolutionRequest,
) -> String:
	var identity_error := _validate_identity(candidate, context, request)
	if not identity_error.is_empty():
		return identity_error

	var projection := RunExtractionPolicy.project(context, candidate, request.ordinary_selections)
	if not projection.valid:
		return _error("field=extraction reason=%s" % " | ".join(projection.errors))
	var live_state := context.item_state()
	var live_validation := live_state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not live_validation.is_empty():
		return _error("field=context.item_state reason=%s" % live_validation)

	var profile_decode := _profile_ownership(candidate)
	if not profile_decode.ok():
		return _error("field=profile.ownership reason=%s" % profile_decode.error)
	var profile_state := profile_decode.state
	var profile_registry := profile_state.registry()
	var leader_loadout := profile_state.container(&"leader-loadout")
	var stash_tabs: Array[ItemSlotContainer] = []
	for stash_document: Dictionary in candidate.stash_tabs:
		var container := profile_state.container(StringName(String(stash_document["container_id"])))
		if container == null or container.container_kind != ItemSlotContainer.PROFILE_STASH_TAB:
			return _error("field=profile.stash_tabs reason=stored tab unavailable")
		stash_tabs.append(container)

	var automatic_leader := RunExtractionPolicy.AUTOMATIC_LEADER_UNLOCK in candidate.permanent_feature_unlocks
	var live_registry := live_state.registry()
	var leader_equipment := live_state.container(StringName("run-equipment-%03d" % request.leader_member_id))
	if automatic_leader:
		var eligibility_error := _validate_live_leader_loadout(context, request.leader_member_id, live_registry, leader_equipment)
		if not eligibility_error.is_empty():
			return eligibility_error
	var displaced_item_ids: Array[String] = []
	if automatic_leader:
		for slot: int in leader_loadout.occupied_slots():
			displaced_item_ids.append(leader_loadout.item_id_at(slot))
	var required_stash_slots := displaced_item_ids.size() + projection.selected_item_ids.size()
	if _empty_stash_slots(stash_tabs) < required_stash_slots:
		return _error("field=stash reason=insufficient empty slots required=%d" % required_stash_slots)

	var next_items: Array[ItemInstance] = []
	for instance_id: String in profile_registry.ids():
		next_items.append(profile_registry.item(instance_id))
	if automatic_leader:
		for slot: int in leader_loadout.occupied_slots():
			leader_loadout._clear_slot(slot)
		for instance_id: String in displaced_item_ids:
			var displaced_destination := _first_empty_stash_destination(stash_tabs)
			if displaced_destination.is_empty():
				return _error("field=stash reason=insufficient empty slots")
			(stash_tabs[displaced_destination[0]] as ItemSlotContainer)._set_item_id(displaced_destination[1], instance_id)
		for instance_id: String in projection.automatic_item_ids:
			if profile_registry.has(instance_id):
				return _error("field=item.instance_id reason=already exists in profile %s" % instance_id)
			var source_slot := _slot_for_item(leader_equipment, instance_id)
			if source_slot < 0:
				return _error("field=automatic_item reason=leader source missing %s" % instance_id)
			var item := live_registry.item(instance_id)
			if item == null:
				return _error("field=context.item_state.registry reason=missing item %s" % instance_id)
			next_items.append(item)
			leader_loadout._set_item_id(source_slot, instance_id)

	for instance_id: String in projection.selected_item_ids:
		if profile_registry.has(instance_id):
			return _error("field=item.instance_id reason=already exists in profile %s" % instance_id)
		var item := live_registry.item(instance_id)
		if item == null:
			return _error("field=context.item_state.registry reason=missing item %s" % instance_id)
		var destination := _first_empty_stash_destination(stash_tabs)
		if destination.is_empty():
			return _error("field=stash reason=insufficient empty slots")
		next_items.append(item)
		(stash_tabs[destination[0]] as ItemSlotContainer)._set_item_id(destination[1], instance_id)

	var containers: Array[ItemSlotContainer] = [leader_loadout]
	containers.append_array(stash_tabs)
	var resolved_ownership := ItemOwnershipState.create(candidate.profile_id, ItemRegistry.new(next_items), containers)
	var resolved_error := resolved_ownership.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not resolved_error.is_empty():
		return _error("field=profile.ownership reason=%s" % resolved_error)
	candidate.item_records = resolved_ownership.registry().to_dictionary()
	candidate.leader_loadout = resolved_ownership.container(&"leader-loadout").to_dictionary()
	var resolved_tabs: Array[Dictionary] = []
	for stored_tab: ItemSlotContainer in stash_tabs:
		resolved_tabs.append(resolved_ownership.container(stored_tab.container_id).to_dictionary())
	candidate.stash_tabs = resolved_tabs
	candidate.leader_loadout_class_id = String(_leader_class_id(context, request.leader_member_id))
	candidate.resumable_run = {}
	return ""

func _validate_identity(candidate: ProfileState, context: PlayerRunContext, request: RunResolutionRequest) -> String:
	if candidate == null or candidate.profile_id != request.profile_id:
		return _error("field=profile_id reason=candidate profile mismatch")
	if not candidate.resumable_run.has("item_state"):
		return _error("field=resumable_run reason=strict item run required")
	var durable := ResumableRunItemCodec.decode(candidate.resumable_run, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if durable == null:
		return _error("field=resumable_run reason=invalid strict item run")
	var snapshot := context.profile_snapshot
	if snapshot == null or snapshot.profile_id != request.profile_id or not snapshot.resumable_run.has("item_state"):
		return _error("field=context.profile_snapshot reason=strict item run required")
	var configured := ResumableRunItemCodec.decode(snapshot.resumable_run, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if configured == null:
		return _error("field=context.profile_snapshot reason=invalid strict item run")
	if (
		durable.run_id != request.run_id
		or durable.run_seed != request.run_seed
		or durable.run_player_id != request.run_player_id
		or durable.leader_member_id != request.leader_member_id
		or configured.run_id != request.run_id
		or configured.run_seed != request.run_seed
		or configured.run_player_id != request.run_player_id
		or configured.leader_member_id != request.leader_member_id
		or context.run_id != request.run_id
		or context.run_seed != request.run_seed
		or context.run_player_id != request.run_player_id
		or context.profile_id != request.profile_id
	):
		return _error("field=run_identity reason=profile, snapshot, context, and request must match")
	var leader_id := 0
	var leader_count := 0
	if context.party != null:
		for member: PartyMemberState in context.party.members:
			if member != null and member.is_leader:
				leader_count += 1
				leader_id = member.member_id
	if leader_count != 1 or leader_id != request.leader_member_id:
		return _error("field=leader_member_id reason=live leader mismatch")
	return ""

func _profile_ownership(profile: ProfileState) -> ItemOwnershipStateDecodeResult:
	var containers: Array = [profile.leader_loadout.duplicate(true)]
	containers.append_array(profile.stash_tabs.duplicate(true))
	return ItemOwnershipState.decode({
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": profile.profile_id,
		"registry": profile.item_records.duplicate(true),
		"containers": containers,
	}, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)

func _leader_class_id(context: PlayerRunContext, member_id: int) -> StringName:
	var member := context.party.member_by_id(member_id) if context.party != null else null
	return member.class_definition.id if member != null and member.class_definition != null else &""

func _slot_for_item(container: ItemSlotContainer, instance_id: String) -> int:
	if container == null:
		return -1
	for slot: int in container.occupied_slots():
		if container.item_id_at(slot) == instance_id:
			return slot
	return -1

func _validate_live_leader_loadout(
	context: PlayerRunContext,
	member_id: int,
	registry: ItemRegistry,
	leader_equipment: ItemSlotContainer,
) -> String:
	var member := context.party.member_by_id(member_id) if context != null and context.party != null else null
	if member == null or member.class_definition == null:
		return _error("field=leader_class reason=authoritative live leader class missing")
	if registry == null or leader_equipment == null:
		return _error("field=leader_loadout reason=live ownership unavailable")
	var loadout: Dictionary = {}
	for slot: int in leader_equipment.occupied_slots():
		var slot_id := EquipmentSlotIndex.slot_for(slot)
		var item := registry.item(leader_equipment.item_id_at(slot))
		var definition := GameCatalog.EQUIPMENT_CATALOG.definition(item.base_definition_id) if item != null else null
		if slot_id.is_empty() or definition == null:
			return _error("field=leader_loadout reason=unknown live equipment")
		loadout[slot_id] = definition
	var attributes: Dictionary = {}
	var snapshot := context.party.stats_for(member_id)
	if snapshot == null:
		return _error("field=leader_attributes reason=resolved live attributes missing")
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		attributes[attribute_id] = snapshot.value(attribute_id)
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		var definition := loadout.get(slot_id) as EquipmentBaseDefinition
		if definition == null:
			continue
		var errors := EquipmentEligibility.validate_equip(definition, member.class_definition, slot_id, loadout, attributes)
		if not errors.is_empty():
			return _error("field=leader_loadout reason=ineligible detail=%s" % errors[0])
	var off_hand := loadout.get(&"off_hand") as EquipmentBaseDefinition
	if off_hand != null and off_hand.item_type_id == &"quiver":
		var main_hand := loadout.get(&"main_hand") as EquipmentBaseDefinition
		if main_hand == null:
			return _error("field=leader_loadout reason=ineligible detail=quiver requires a main-hand bow")
		if &"off_hand" not in main_hand.reserved_slot_ids or off_hand.item_type_id not in main_hand.compatible_offhand_item_types:
			return _error("field=leader_loadout reason=ineligible detail=quiver is not permitted by main hand")
		if main_hand.weapon_family_id.is_empty() or off_hand.weapon_family_id != main_hand.weapon_family_id:
			return _error("field=leader_loadout reason=ineligible detail=quiver family does not match main hand")
	return ""

func _empty_stash_slots(stash_tabs: Array[ItemSlotContainer]) -> int:
	var result := 0
	for tab: ItemSlotContainer in stash_tabs:
		result += tab.capacity - tab.occupied_slots().size()
	return result

func _first_empty_stash_destination(stash_tabs: Array[ItemSlotContainer]) -> Array[int]:
	for index: int in stash_tabs.size():
		var slot := stash_tabs[index].first_empty_slot()
		if slot >= 0:
			return [index, slot]
	return []

func _error(detail: String) -> String:
	return "%s %s" % [ERROR_PREFIX, detail]
