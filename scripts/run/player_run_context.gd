class_name PlayerRunContext
extends RefCounted

signal progression_changed(member_id: int)
signal member_level_ready(member_id: int, level: int)

const DEFAULT_EXPERIENCE_TUNING: ExperienceTuning = preload("res://data/progression/default_experience.tres")

var _run_player_id: StringName = &""
var run_player_id: StringName:
	get:
		return _run_player_id
var _player_slot_index := -1
var player_slot_index: int:
	get:
		return _player_slot_index
var _profile_id := ""
var profile_id: String:
	get:
		return _profile_id
var _profile_snapshot: ProfileState
var profile_snapshot: ProfileState:
	get:
		return _profile_snapshot.copy() if _profile_snapshot != null else null
var _run_seed := 0
var run_seed: int:
	get:
		return _run_seed
var _experience_multiplier_percent := 100
var experience_multiplier_percent: int:
	get:
		return _experience_multiplier_percent
var party: PartyManager
var experience_tuning: ExperienceTuning = DEFAULT_EXPERIENCE_TUNING

var _progression_by_member: Dictionary = {}
var _pending_leader_levels: Array[int] = []
var _actor_by_member: Dictionary = {}
var _item_state: ItemOwnershipState
var _item_journal: ItemTransactionJournal
var _next_item_sequence := 0
var _equipment_activation_by_member: Dictionary = {}
var _configured := false
var _run_id: StringName = &""
var run_id: StringName:
	get:
		return _run_id
var _item_resolution_transaction_id := ""

func configure(
	run_player_id_value: StringName,
	slot: int,
	profile: ProfileState,
	run_seed_value: int,
	manager: PartyManager,
	experience_multiplier: int,
	item_bootstrap: RunItemBootstrap = null,
) -> PackedStringArray:
	if _configured:
		return PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=configuration reason=already configured"])
	var errors := PackedStringArray()
	if run_player_id_value.is_empty():
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=run_player_id")
	if slot < 0:
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=player_slot_index")
	if profile == null or not ProfileCodec.validate_profile(profile).is_empty():
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=profile")
	if run_seed_value <= 0:
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=run_seed")
	errors.append_array(_party_validation_errors(manager))
	if experience_multiplier < 100 or experience_multiplier > 1000:
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=experience_multiplier")
	var strict_resumable := profile != null and profile.resumable_run.has("item_state")
	if strict_resumable and item_bootstrap == null:
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=item_bootstrap reason=required for resumable item run")
	elif item_bootstrap != null:
		var encoded_bootstrap := ResumableRunItemCodec.encode(item_bootstrap)
		if (
			profile == null
			or encoded_bootstrap.is_empty()
			or profile.resumable_run != encoded_bootstrap
			or item_bootstrap.run_seed != run_seed_value
			or item_bootstrap.run_player_id != run_player_id_value
		):
			errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=item_bootstrap reason=identity mismatch")
		elif manager == null or not manager.members.any(func(member: PartyMemberState) -> bool:
			return member != null and member.is_leader and member.member_id == item_bootstrap.leader_member_id
		):
			errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=item_bootstrap reason=leader mismatch")
	if not errors.is_empty():
		_reset_unconfigured_item_fields()
		return errors

	var next_progression: Dictionary = {}
	for member: PartyMemberState in manager.members:
		var state := CharacterProgressionState.fresh(member.member_id, DEFAULT_EXPERIENCE_TUNING)
		if state == null:
			return PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=party"])
		next_progression[member.member_id] = state
	var owned_profile := profile.copy()
	if owned_profile == null:
		_reset_unconfigured_item_fields()
		return PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=profile"])
	var inventory := ItemSlotContainer.create(
		&"run-inventory",
		ItemSlotContainer.RUN_INVENTORY,
		String(run_player_id_value),
		owned_profile.inventory_columns * 5,
	)
	var item_containers: Array[ItemSlotContainer] = [inventory]
	for member: PartyMemberState in manager.members:
		item_containers.append(_run_equipment_container(member.member_id, String(run_player_id_value)))
	var next_item_state := ItemOwnershipState.create(
		String(run_player_id_value),
		ItemRegistry.new(),
		item_containers,
	)
	var item_state_error := next_item_state.validate(
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	if not item_state_error.is_empty():
		_reset_unconfigured_item_fields()
		return PackedStringArray([
			"PARTY_FORGE_RUN_CONTEXT_ERROR field=item_state reason=%s" % item_state_error,
		])
	if item_bootstrap != null:
		var bootstrap_state := item_bootstrap.item_state()
		var bootstrap_error := _validate_bootstrap_state(bootstrap_state, next_item_state)
		if not bootstrap_error.is_empty():
			_reset_unconfigured_item_fields()
			return PackedStringArray([
				"PARTY_FORGE_RUN_CONTEXT_ERROR field=item_bootstrap reason=%s" % bootstrap_error,
			])
		next_item_state = bootstrap_state
	var next_item_journal := ItemTransactionJournal.new()
	var reconstruction := _preview_equipment_reconstruction(next_item_state, manager)
	if not String(reconstruction["error"]).is_empty():
		_reset_unconfigured_item_fields()
		return PackedStringArray([String(reconstruction["error"])])
	var next_equipment_activations := reconstruction["activations"] as Dictionary
	for member: PartyMemberState in manager.members:
		var activation := next_equipment_activations.get(member.member_id) as EquipmentActivationResult
		if activation == null or not manager.replace_member_source(member.member_id, activation.source):
			_reset_unconfigured_item_fields()
			return PackedStringArray([
				"PARTY_FORGE_RUN_CONTEXT_ERROR field=equipment_activation member=%d reason=stat source commit rejected" % member.member_id,
			])

	var member_added_callback := Callable(self, "_on_member_added")
	if party != null and party.member_added.is_connected(member_added_callback):
		party.member_added.disconnect(member_added_callback)
	_run_player_id = run_player_id_value
	_player_slot_index = slot
	_profile_id = owned_profile.profile_id
	_profile_snapshot = owned_profile
	_run_seed = run_seed_value
	_experience_multiplier_percent = experience_multiplier
	party = manager
	experience_tuning = DEFAULT_EXPERIENCE_TUNING
	_progression_by_member = next_progression
	_pending_leader_levels.clear()
	_actor_by_member.clear()
	_item_state = next_item_state
	_item_journal = next_item_journal
	_equipment_activation_by_member.clear()
	for member_id: Variant in next_equipment_activations:
		_equipment_activation_by_member[int(member_id)] = (next_equipment_activations[member_id] as EquipmentActivationResult).copy()
	_next_item_sequence = 0
	_run_id = item_bootstrap.run_id if item_bootstrap != null else &""
	_item_resolution_transaction_id = ""
	if not party.member_added.is_connected(member_added_callback):
		party.member_added.connect(member_added_callback)
	_configured = true
	return errors

func item_state() -> ItemOwnershipState:
	return _item_state.copy() if _item_state != null else null

func run_inventory() -> ItemSlotContainer:
	return _item_state.container(&"run-inventory") if _item_state != null else null

func equipment_for(member_id: int) -> ItemSlotContainer:
	return _item_state.container(_run_equipment_id(member_id)) if _item_state != null else null

func equipment_activation(member_id: int) -> EquipmentActivationResult:
	var activation := _equipment_activation_by_member.get(member_id) as EquipmentActivationResult
	if activation == null:
		return EquipmentActivationResult.failure(
			"PARTY_FORGE_EQUIPMENT_ACTIVATION_ERROR member=%d detail=activation unavailable" % member_id
		)
	return activation.copy()

func item_resolution_error(transaction_id: String) -> String:
	if transaction_id.strip_edges().is_empty():
		return "PARTY_FORGE_RUN_CONTEXT_ERROR field=item_resolution.transaction_id reason=must not be empty"
	if not _item_resolution_transaction_id.is_empty() and _item_resolution_transaction_id != transaction_id:
		return "PARTY_FORGE_RUN_CONTEXT_ERROR field=item_resolution reason=already resolved transaction=%s" % _item_resolution_transaction_id
	return ""

func mark_items_resolved(transaction_id: String) -> void:
	_item_resolution_transaction_id = transaction_id

func assign_equipment(
	member_id: int,
	item_id: String,
	slot_id: StringName,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> EquipmentAssignmentResult:
	var preview := preview_equipment_assignment(
		member_id,
		item_id,
		slot_id,
		equipment,
		foundation,
	)
	if not preview.ok():
		return EquipmentAssignmentResult.failure(preview.error)
	var previous_state := _item_state
	var previous_activation := equipment_activation(member_id)
	var next_activation := preview.activation()
	_item_state = preview.state()
	_equipment_activation_by_member[member_id] = next_activation.copy()
	if party == null or not party.replace_member_source(member_id, next_activation.source):
		_item_state = previous_state
		_equipment_activation_by_member[member_id] = previous_activation
		return EquipmentAssignmentResult.failure(
			"PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR member=%d reason=stat source commit rejected" % member_id
		)
	return EquipmentAssignmentResult.success(_item_state)

func preview_equipment_assignment(
	member_id: int,
	item_id: String,
	slot_id: StringName,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> EquipmentTransitionResult:
	return EquipmentTransitionService.preview(
		_item_state,
		member_id,
		item_id,
		slot_id,
		party,
		equipment,
		foundation,
	)

func apply_item_transaction(
	request: ItemTransactionRequest,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> ItemTransactionResult:
	if not _configured or _item_state == null or _item_journal == null:
		return _item_transaction_failure(ItemTransactionResult.Code.INVALID_REQUEST)
	if request == null or equipment == null or foundation == null:
		return _item_transaction_failure(ItemTransactionResult.Code.INVALID_REQUEST)
	var service := ItemContainerTransactionService.new()
	if not service._request_is_valid(request):
		return _item_transaction_failure(ItemTransactionResult.Code.INVALID_REQUEST)
	if request.operation not in [
		ItemTransactionRequest.CREATE_AND_PLACE,
		ItemTransactionRequest.MOVE_TO_EMPTY,
		ItemTransactionRequest.SWAP_OCCUPIED,
	]:
		return _item_transaction_failure(ItemTransactionResult.Code.INVALID_REQUEST)
	if (
		request.operation != ItemTransactionRequest.CREATE_AND_PLACE
		and not _container_is_run_inventory(request.source_container_id)
	) or not _container_is_run_inventory(request.destination_container_id):
		return _item_transaction_failure(ItemTransactionResult.Code.INVALID_REQUEST)
	if request.owner_id != _item_state.owner_id:
		return service.apply(_item_state, request, _item_journal, equipment, foundation)
	if request.operation == ItemTransactionRequest.CREATE_AND_PLACE:
		var create_item := request.create_item
		if create_item != null:
			var expected_namespace := "run:%s:%s:%s" % [profile_id, run_seed, run_player_id]
			if String(create_item.origin.get("issuer_namespace", "")) != expected_namespace:
				return _item_transaction_failure(ItemTransactionResult.Code.INVALID_ITEM)
			var sequence_value: Variant = create_item.origin.get("sequence")
			if not _is_nonnegative_json_int(sequence_value):
				return _item_transaction_failure(ItemTransactionResult.Code.INVALID_ITEM)
			if not _item_journal.has(request.transaction_id) and int(sequence_value) != _next_item_sequence:
				return _item_transaction_failure(ItemTransactionResult.Code.INVALID_ITEM)
	var result := service.apply(_item_state, request, _item_journal, equipment, foundation)
	if result.ok():
		_item_state = result.next_state
		if request.operation == ItemTransactionRequest.CREATE_AND_PLACE and not result.duplicate:
			_next_item_sequence += 1
	return result

func progression_for(member_id: int) -> CharacterProgressionState:
	var state := _progression_by_member.get(member_id) as CharacterProgressionState
	return state.copy() if state != null else null

func award_experience(member_id: int, amount: int) -> CharacterProgressionAward:
	var member := party.member_by_id(member_id) if party != null else null
	var current := _progression_by_member.get(member_id) as CharacterProgressionState
	if member == null or current == null or member.class_definition == null:
		return CharacterProgressionAward.failure("member=%d unavailable" % member_id)
	var award := CharacterProgressionService.preview_award(
		current,
		member.class_definition.growth_definition,
		experience_tuning,
		amount,
		experience_multiplier_percent,
		run_seed,
		run_player_id,
		member_id,
	)
	if not award.ok():
		return award
	if not award.gained_levels.is_empty():
		var source := CharacterProgressionService.source_for(member_id, award.next_state)
		if source == null or not party.replace_member_source(member_id, source):
			var failure := CharacterProgressionAward.new()
			failure.error = "PARTY_FORGE_PROGRESSION_ERROR member=%d reason=stat source rejected" % member_id
			return failure
	_progression_by_member[member_id] = award.next_state.copy()
	if member.is_leader:
		_pending_leader_levels.append_array(award.gained_levels)
	for earned_level: int in award.gained_levels:
		member_level_ready.emit(member_id, earned_level)
	progression_changed.emit(member_id)
	return award

func pending_leader_levels() -> Array[int]:
	return _pending_leader_levels.duplicate()

func current_pending_level() -> int:
	return _pending_leader_levels[0] if not _pending_leader_levels.is_empty() else 0

func consume_pending_leader_level() -> bool:
	if _pending_leader_levels.is_empty():
		return false
	_pending_leader_levels.pop_front()
	return true

func bind_actor(member_id: int, actor: Node3D) -> bool:
	if party == null or party.member_by_id(member_id) == null or actor == null:
		return false
	actor.set_meta("party_forge_run_player_id", run_player_id)
	actor.set_meta("party_forge_member_id", member_id)
	_actor_by_member[member_id] = weakref(actor)
	return true

func actor_for(member_id: int) -> Node3D:
	var reference := _actor_by_member.get(member_id) as WeakRef
	var actor := reference.get_ref() as Node3D if reference != null else null
	if actor == null:
		_actor_by_member.erase(member_id)
	return actor

func member_is_available(member_id: int) -> bool:
	var actor := actor_for(member_id)
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent if actor != null else null
	return health != null and not health.is_dead and not health.is_downed

func member_position(member_id: int) -> Dictionary:
	var actor := actor_for(member_id)
	if actor == null:
		return {"valid": false}
	return {"valid": true, "position": actor.global_position if actor.is_inside_tree() else actor.position}

func _on_member_added(member: PartyMemberState) -> void:
	if member == null or member.member_id <= 0 or _progression_by_member.has(member.member_id):
		return
	if _item_state == null or _item_state.container(_run_equipment_id(member.member_id)) != null:
		return
	var next_progression := CharacterProgressionState.fresh(member.member_id, experience_tuning)
	if next_progression == null:
		return
	var next_containers := _item_state.containers()
	next_containers.append(_run_equipment_container(member.member_id, _item_state.owner_id))
	var next_item_state := ItemOwnershipState.create(_item_state.owner_id, _item_state.registry(), next_containers)
	if not next_item_state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).is_empty():
		return
	var activation := _preview_member_equipment_activation(next_item_state, member.member_id, party)
	if not activation.ok():
		return
	var previous_state := _item_state
	var previous_activation := equipment_activation(member.member_id)
	_item_state = next_item_state
	_equipment_activation_by_member[member.member_id] = activation.copy()
	if party == null or not party.replace_member_source(member.member_id, activation.source):
		_item_state = previous_state
		_equipment_activation_by_member[member.member_id] = previous_activation
		return
	_progression_by_member[member.member_id] = next_progression

func _run_equipment_id(member_id: int) -> StringName:
	return StringName("run-equipment-%03d" % member_id)

func _run_equipment_container(member_id: int, owner_id: String) -> ItemSlotContainer:
	return ItemSlotContainer.create(
		_run_equipment_id(member_id),
		ItemSlotContainer.RUN_MEMBER_EQUIPMENT,
		owner_id,
		EquipmentSlotIndex.capacity(),
	)

func _party_validation_errors(manager: PartyManager) -> PackedStringArray:
	var errors := PackedStringArray()
	if manager == null or manager.members.is_empty():
		errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=party")
		return errors
	var member_ids: Dictionary = {}
	for member: PartyMemberState in manager.members:
		if member == null or member.member_id <= 0 or member.class_definition == null or member_ids.has(member.member_id):
			return PackedStringArray(["PARTY_FORGE_RUN_CONTEXT_ERROR field=party"])
		member_ids[member.member_id] = true
		var growth := member.class_definition.growth_definition
		if growth == null:
			errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=party member=%d reason=growth definition missing" % member.member_id)
			continue
		for reason: String in growth.validate():
			errors.append("PARTY_FORGE_RUN_CONTEXT_ERROR field=party member=%d reason=%s" % [member.member_id, reason])
	return errors

func _reset_unconfigured_item_fields() -> void:
	_item_state = null
	_item_journal = null
	_equipment_activation_by_member.clear()
	_next_item_sequence = 0
	_run_id = &""
	_item_resolution_transaction_id = ""

func _preview_equipment_reconstruction(state: ItemOwnershipState, manager: PartyManager) -> Dictionary:
	var activations: Dictionary = {}
	for member: PartyMemberState in manager.members:
		var activation := _preview_member_equipment_activation(state, member.member_id, manager)
		if not activation.ok():
			return {
				"error": "PARTY_FORGE_RUN_CONTEXT_ERROR field=equipment_activation member=%d reason=%s" % [member.member_id, activation.error],
				"activations": {},
			}
		activations[member.member_id] = activation.copy()
	return {"error": "", "activations": activations}

func _preview_member_equipment_activation(
	state: ItemOwnershipState,
	member_id: int,
	manager: PartyManager,
) -> EquipmentActivationResult:
	var activation := EquipmentActivationResolver.resolve(
		member_id,
		_run_equipment_id(member_id),
		state,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		GameCatalog.STAT_CATALOG,
		manager.member_base_values(member_id),
		manager.member_capabilities(member_id),
		manager.member_sources_without_equipment(member_id),
		manager.stat_revision(),
	)
	if not activation.ok():
		return activation
	var final_sources := manager.member_sources_without_equipment(member_id)
	final_sources.append(activation.source)
	var resolution := MemberStatResolutionService.resolve(
		member_id,
		GameCatalog.STAT_CATALOG,
		manager.member_base_values(member_id),
		manager.member_capabilities(member_id),
		final_sources,
		[],
		manager.stat_revision(),
		PartyManager.DEFAULT_ATTRIBUTE_PROJECTION,
	)
	if not resolution.ok():
		return EquipmentActivationResult.failure(
			"PARTY_FORGE_EQUIPMENT_ACTIVATION_ERROR member=%d detail=%s" % [member_id, resolution.error]
		)
	return activation

func _validate_bootstrap_state(state: ItemOwnershipState, empty_candidate: ItemOwnershipState) -> String:
	if state == null:
		return "item state is missing"
	var validation := state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not validation.is_empty():
		return validation
	if state.owner_id != empty_candidate.owner_id:
		return "owner mismatch"
	var expected := empty_candidate.containers()
	var actual := state.containers()
	if actual.size() != expected.size():
		return "container set mismatch"
	for expected_container: ItemSlotContainer in expected:
		var actual_container := state.container(expected_container.container_id)
		if actual_container == null:
			return "container set mismatch"
		if (
			actual_container.container_kind != expected_container.container_kind
			or actual_container.owner_id != expected_container.owner_id
			or actual_container.capacity != expected_container.capacity
		):
			return "container contract mismatch"
	return ""

func _item_transaction_failure(code: ItemTransactionResult.Code) -> ItemTransactionResult:
	return ItemTransactionResult.create(code)

func _container_is_run_inventory(container_id: String) -> bool:
	var container := _item_state.container(StringName(container_id))
	return container != null and container.container_kind == ItemSlotContainer.RUN_INVENTORY

func _is_nonnegative_json_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 0 and int(value) <= ItemInstanceCodec.JSON_SAFE_INTEGER_MAX
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return (
		is_finite(number)
		and number == floor(number)
		and number >= 0.0
		and number <= float(ItemInstanceCodec.JSON_SAFE_INTEGER_MAX)
	)
