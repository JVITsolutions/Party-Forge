class_name RunLoadoutCheckoutService
extends RefCounted

const CHECKOUT_OPERATION := "run_loadout_checkout"
const FORFEIT_OPERATION := "run_loadout_forfeit"

var _mutations: ProfileMutationService

func _init(mutations: ProfileMutationService = null) -> void:
	_mutations = mutations if mutations != null else ProfileMutationService.new()

func checkout(
	profile_id: String,
	request: RunLoadoutCheckoutRequest,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> ProfileMutationResult:
	if request == null:
		return _failure("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=request reason=must not be null")
	var request_error := _validate_request(profile_id, request)
	if not request_error.is_empty():
		return _failure(request_error)
	return _mutations.apply(
		profile_id,
		request.transaction_id,
		func(candidate: ProfileState) -> String:
			return _apply_checkout(candidate, request),
		root,
		-1,
		CHECKOUT_OPERATION,
		request.canonical_document(),
	)

func forfeit(
	profile_id: String,
	run_id: StringName,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> ProfileMutationResult:
	if String(run_id).strip_edges().is_empty():
		return _failure("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=run_id reason=must not be empty")
	var request_document := {"run_id": String(run_id)}
	return _mutations.apply_with_resumable_run_revocation(
		profile_id,
		"forfeit:%s" % run_id,
		run_id,
		func(candidate: ProfileState) -> String:
			return _forfeit_candidate(candidate, run_id),
		root,
		-1,
		FORFEIT_OPERATION,
		request_document,
	)

func bootstrap_from(profile: ProfileState) -> RunItemBootstrap:
	if profile == null or not profile.resumable_run.has("item_state"):
		return null
	return ResumableRunItemCodec.decode(
		profile.resumable_run.duplicate(true),
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)

func _validate_request(profile_id: String, request: RunLoadoutCheckoutRequest) -> String:
	if profile_id != request.profile_id:
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=profile_id reason=profile identity mismatch"
	if request.transaction_id.strip_edges().is_empty():
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=transaction_id reason=must not be empty"
	if String(request.run_id).strip_edges().is_empty():
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=run_id reason=must not be empty"
	if request.run_seed <= 0:
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=run_seed reason=must be positive"
	if String(request.run_player_id).strip_edges().is_empty():
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=run_player_id reason=must not be empty"
	if request.leader_member_id <= 0:
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=leader_member_id reason=must be positive"
	if request.selected_leader_class_id.is_empty() or GameCatalog.load_defaults().class_by_id(request.selected_leader_class_id) == null:
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=selected_leader_class_id reason=unknown leader class"
	return ""

func _apply_checkout(candidate: ProfileState, request: RunLoadoutCheckoutRequest) -> String:
	if candidate.profile_id != request.profile_id:
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=profile_id reason=profile identity mismatch"
	if not candidate.resumable_run.is_empty():
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=resumable_run reason=active resumable run exists"
	var run_items: Array[ItemInstance] = []
	var equipment_slots: Dictionary = {}
	if request.bring_in_gear:
		var ownership := _profile_ownership(candidate)
		if not ownership.ok():
			return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=profile_items reason=%s" % ownership.error
		var leader := ownership.state.container(&"leader-loadout")
		if leader == null:
			return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=leader_loadout reason=missing"
		if not leader.occupied_slots().is_empty():
			if candidate.leader_loadout_class_id != String(request.selected_leader_class_id):
				return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=selected_leader_class_id reason=leader class mismatch"
			var eligibility_error := _validate_loadout_eligibility(ownership.state, leader, request.selected_leader_class_id)
			if not eligibility_error.is_empty():
				return eligibility_error
		var registry := ownership.state.registry()
		for slot: int in leader.occupied_slots():
			var instance_id := leader.item_id_at(slot)
			var item := registry.item(instance_id)
			if item == null:
				return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=leader_loadout reason=missing equipped instance"
			run_items.append(item)
			equipment_slots[slot] = instance_id

	var run_state := ItemOwnershipState.create(String(request.run_player_id), ItemRegistry.new(run_items), [
		ItemSlotContainer.create(
			&"run-inventory",
			ItemSlotContainer.RUN_INVENTORY,
			String(request.run_player_id),
			candidate.inventory_columns * 5,
		),
		ItemSlotContainer.create(
			StringName("run-equipment-%03d" % request.leader_member_id),
			ItemSlotContainer.RUN_MEMBER_EQUIPMENT,
			String(request.run_player_id),
			EquipmentSlotIndex.capacity(),
			equipment_slots,
		),
		RunItemBootstrap.ground_items_container(String(request.run_player_id)),
	])
	var run_error := run_state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not run_error.is_empty():
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=run_items reason=%s" % run_error
	if request.bring_in_gear and not run_items.is_empty():
		var transferred: Dictionary = {}
		for item: ItemInstance in run_items:
			transferred[item.instance_id] = true
		var remaining: Array[ItemInstance] = []
		var profile_registry_decode := ItemRegistry._decode(
			candidate.item_records,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
		)
		if not String(profile_registry_decode["error"]).is_empty():
			return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=item_records reason=%s" % profile_registry_decode["error"]
		var profile_registry := profile_registry_decode["value"] as ItemRegistry
		for instance_id: String in profile_registry.ids():
			if not transferred.has(instance_id):
				remaining.append(profile_registry.item(instance_id))
		candidate.item_records = ItemRegistry.new(remaining).to_dictionary()
		candidate.leader_loadout = ItemSlotContainer.create(
			&"leader-loadout",
			ItemSlotContainer.PROFILE_LEADER_EQUIPMENT,
			candidate.profile_id,
			EquipmentSlotIndex.capacity(),
		).to_dictionary()
	var bootstrap := RunItemBootstrap.create(
		request.run_id,
		request.run_seed,
		request.run_player_id,
		request.leader_member_id,
		run_state,
		request.selected_leader_class_id,
	)
	candidate.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	return ""

func _forfeit_candidate(candidate: ProfileState, run_id: StringName) -> String:
	if not candidate.resumable_run.has("item_state"):
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=resumable_run reason=matching run identity unavailable"
	var bootstrap := ResumableRunItemCodec.decode(
		candidate.resumable_run,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	if bootstrap == null or bootstrap.run_id != run_id:
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=run_id reason=run identity mismatch"
	candidate.resumable_run = {}
	return ""

func _profile_ownership(profile: ProfileState) -> ItemOwnershipStateDecodeResult:
	var containers: Array = [profile.leader_loadout.duplicate(true)]
	containers.append_array(profile.stash_tabs.duplicate(true))
	return ItemOwnershipState.decode(
		{
			"schema_version": ItemOwnershipState.SCHEMA_VERSION,
			"owner_id": profile.profile_id,
			"registry": profile.item_records.duplicate(true),
			"containers": containers,
		},
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)

func _validate_loadout_eligibility(
	state: ItemOwnershipState,
	leader: ItemSlotContainer,
	class_id: StringName,
) -> String:
	var class_definition := GameCatalog.load_defaults().class_by_id(class_id)
	if class_definition == null:
		return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=selected_leader_class_id reason=unknown leader class"
	var registry := state.registry()
	var loadout: Dictionary = {}
	for slot: int in leader.occupied_slots():
		var item := registry.item(leader.item_id_at(slot))
		var definition := GameCatalog.EQUIPMENT_CATALOG.definition(item.base_definition_id) if item != null else null
		if definition == null:
			return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=leader_loadout reason=unknown equipment definition"
		loadout[EquipmentSlotIndex.slot_for(slot)] = definition
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		var definition := loadout.get(slot_id) as EquipmentBaseDefinition
		if definition == null:
			continue
		var errors := EquipmentEligibility.validate_equip(definition, class_definition, slot_id, loadout)
		if not errors.is_empty():
			return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=leader_loadout reason=ineligible detail=%s" % errors[0]
	var off_hand := loadout.get(&"off_hand") as EquipmentBaseDefinition
	if off_hand != null and off_hand.item_type_id == &"quiver":
		var main_hand := loadout.get(&"main_hand") as EquipmentBaseDefinition
		if main_hand == null:
			return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=leader_loadout reason=ineligible detail=quiver requires a main-hand bow"
		if &"off_hand" not in main_hand.reserved_slot_ids or off_hand.item_type_id not in main_hand.compatible_offhand_item_types:
			return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=leader_loadout reason=ineligible detail=quiver is not permitted by main hand"
		if main_hand.weapon_family_id.is_empty() or off_hand.weapon_family_id != main_hand.weapon_family_id:
			return "PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR field=leader_loadout reason=ineligible detail=quiver family does not match main hand"
	return ""

func _failure(error: String) -> ProfileMutationResult:
	var result := ProfileMutationResult.new()
	result.error = error
	return result
