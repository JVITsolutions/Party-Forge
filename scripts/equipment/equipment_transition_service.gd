class_name EquipmentTransitionService
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR"

static func preview(
	state: ItemOwnershipState,
	member_id: int,
	item_id: String,
	slot_id: StringName,
	party: PartyManager,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> EquipmentTransitionResult:
	var member := party.member_by_id(member_id) if party != null else null
	if party == null or member == null:
		return _failure(member_id, item_id, slot_id, "member is unavailable")
	var assignment := EquipmentAssignmentService.new().preview(
		state,
		member_id,
		item_id,
		slot_id,
		equipment,
		foundation,
		member.class_definition,
	)
	if not assignment.ok():
		return _failure(member_id, item_id, slot_id, "structural assignment failed detail=%s" % assignment.error)
	var candidate := assignment.state()
	var activation := _activation_for(candidate, member_id, party, equipment, foundation)
	if not activation.ok():
		return _failure(member_id, item_id, slot_id, "activation failed detail=%s" % activation.error)
	for newly_equipped_item_id: String in assignment.newly_equipped_item_ids():
		if activation.is_active(newly_equipped_item_id):
			continue
		var reasons := activation.disabled_reasons(newly_equipped_item_id)
		return _failure(member_id, newly_equipped_item_id, slot_id, "requested item is disabled detail=%s" % "; ".join(reasons))
	var final_sources := party.member_sources_without_equipment(member_id)
	final_sources.append(activation.source)
	var resolution := MemberStatResolutionService.resolve(
		member_id,
		GameCatalog.STAT_CATALOG,
		party.member_base_values(member_id),
		party.member_capabilities(member_id),
		final_sources,
		[],
		party.stat_revision(),
		PartyManager.DEFAULT_ATTRIBUTE_PROJECTION,
	)
	if not resolution.ok():
		return _failure(member_id, item_id, slot_id, "stat resolution failed detail=%s" % resolution.error)
	var action_error := _validate_candidate_actions(
		member.class_definition,
		member_id,
		party,
		final_sources,
	)
	if not action_error.is_empty():
		return _failure(member_id, item_id, slot_id, action_error)
	return EquipmentTransitionResult.success(candidate, activation, resolution)

static func _validate_candidate_actions(
	class_definition: ClassDefinition,
	member_id: int,
	party: PartyManager,
	final_sources: Array[StatModifierSource],
) -> String:
	if class_definition == null or class_definition.primary_attack == null:
		return "action validation failed action=<primary> detail=primary action is unavailable"
	for attack: AttackDefinition in class_definition.owned_actions():
		var action_id := String(attack.id) if not attack.id.is_empty() else "<empty>"
		var action_resolution := MemberStatResolutionService.resolve(
			member_id,
			GameCatalog.STAT_CATALOG,
			party.member_base_values(member_id),
			party.member_capabilities(member_id),
			final_sources,
			DamageResolver.action_tags_for(attack),
			party.stat_revision(),
			PartyManager.DEFAULT_ATTRIBUTE_PROJECTION,
		)
		if not action_resolution.ok():
			return "action stat resolution failed action=%s detail=%s" % [action_id, action_resolution.error]
		var authored_errors := attack.validate(GameCatalog.DAMAGE_TYPES)
		if not authored_errors.is_empty():
			return "action validation failed action=%s detail=%s" % [action_id, authored_errors[0]]
		if attack.is_healing():
			continue
		var estimate := ActionCombatEstimateService.estimate_from_snapshot(
			attack,
			action_resolution.final_stats,
			GameCatalog.DAMAGE_TYPES,
		)
		if estimate == null or not estimate.available:
			var detail := estimate.unavailable_reason if estimate != null else "candidate action is unavailable"
			return "action validation failed action=%s detail=%s" % [action_id, detail]
	return ""

static func _activation_for(
	state: ItemOwnershipState,
	member_id: int,
	party: PartyManager,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> EquipmentActivationResult:
	return EquipmentActivationResolver.resolve(
		member_id,
		StringName("run-equipment-%03d" % member_id),
		state,
		equipment,
		foundation,
		GameCatalog.STAT_CATALOG,
		party.member_base_values(member_id),
		party.member_capabilities(member_id),
		party.member_sources_without_equipment(member_id),
		party.stat_revision(),
	)

static func _failure(member_id: int, item_id: String, slot_id: StringName, detail: String) -> EquipmentTransitionResult:
	return EquipmentTransitionResult.failure(
		"%s member=%d item=%s slot=%s reason=%s" % [ERROR_PREFIX, member_id, item_id, slot_id, detail]
	)
