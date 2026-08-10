class_name EquipmentTransitionService
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR"
const CANDIDATE_ACTION_VALIDATION := preload("res://scripts/combat/candidate_action_validation_service.gd")

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
	var candidate_revision := party.stat_revision() + 1
	var activation := _activation_for(candidate, member_id, party, equipment, foundation, candidate_revision)
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
		candidate_revision,
		PartyManager.DEFAULT_ATTRIBUTE_PROJECTION,
	)
	if not resolution.ok():
		return _failure(member_id, item_id, slot_id, "stat resolution failed detail=%s" % resolution.error)
	var action_error := CANDIDATE_ACTION_VALIDATION.validate(
		member.class_definition,
		member_id,
		GameCatalog.STAT_CATALOG,
		GameCatalog.DAMAGE_TYPES,
		party.member_base_values(member_id),
		party.member_capabilities(member_id),
		final_sources,
		candidate_revision,
		PartyManager.DEFAULT_ATTRIBUTE_PROJECTION,
	)
	if not action_error.is_empty():
		return _failure(member_id, item_id, slot_id, action_error)
	return EquipmentTransitionResult.success(candidate, activation, resolution)

static func _activation_for(
	state: ItemOwnershipState,
	member_id: int,
	party: PartyManager,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	candidate_revision: int,
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
		candidate_revision,
	)

static func _failure(member_id: int, item_id: String, slot_id: StringName, detail: String) -> EquipmentTransitionResult:
	return EquipmentTransitionResult.failure(
		"%s member=%d item=%s slot=%s reason=%s" % [ERROR_PREFIX, member_id, item_id, slot_id, detail]
	)
