class_name RunExtractionPolicy
extends RefCounted

const AUTOMATIC_LEADER_UNLOCK := "leader_loadout_extraction"
const ERROR_PREFIX := "PARTY_FORGE_EXTRACTION_ERROR"

static func project(
	context: PlayerRunContext,
	profile: ProfileState,
	selections: Array[ExtractionSelection],
) -> RunExtractionProjection:
	var capacity := maxi(0, profile.extraction_capacity) if profile != null else 0
	if not _context_is_configured(context):
		return _failure(capacity, "field=context reason=must be configured")
	if profile == null:
		return _failure(capacity, "field=profile reason=must be provided")
	if profile.profile_id != context.profile_id:
		return _failure(capacity, "field=profile.profile_id reason=must match configured context profile")
	if context.item_state().owner_id != String(context.run_player_id):
		return _failure(capacity, "field=item_state.owner_id reason=must match configured run player")
	var leaders: Array[PartyMemberState] = []
	for member: PartyMemberState in context.party.members:
		if member != null and member.is_leader:
			leaders.append(member)
	if leaders.size() != 1:
		return _failure(capacity, "field=party.leader reason=must contain exactly one leader")
	var party_rows: Array[Dictionary] = []
	for member: PartyMemberState in context.party.members:
		if member == null:
			continue
		party_rows.append({
			"member_id": member.member_id,
			"class_id": String(member.class_definition.id) if member.class_definition != null else "",
			"is_leader": member.is_leader,
		})
	return _project_owned(context.profile_id, String(context.run_player_id), context.item_state(), party_rows, profile, selections)

static func project_source(
	source: RunResolutionSource,
	profile: ProfileState,
	selections: Array[ExtractionSelection],
) -> RunExtractionProjection:
	var capacity := maxi(0, profile.extraction_capacity) if profile != null else 0
	if source == null:
		return _failure(capacity, "field=source reason=must be provided")
	if profile == null:
		return _failure(capacity, "field=profile reason=must be provided")
	if profile.profile_id != source.profile_id:
		return _failure(capacity, "field=profile.profile_id reason=must match resolution source profile")
	var state := source.item_state
	if state == null or state.owner_id != String(source.run_player_id):
		return _failure(capacity, "field=item_state.owner_id reason=must match resolution source run player")
	return _project_owned(source.profile_id, String(source.run_player_id), state, source.party_members, profile, selections)

static func _project_owned(
	profile_id: String,
	run_player_id: String,
	state: ItemOwnershipState,
	party_members: Array[Dictionary],
	profile: ProfileState,
	selections: Array[ExtractionSelection],
) -> RunExtractionProjection:
	var capacity := maxi(0, profile.extraction_capacity) if profile != null else 0
	if profile == null or profile.profile_id != profile_id:
		return _failure(capacity, "field=profile.profile_id reason=must match projection source profile")
	if state == null or state.owner_id != run_player_id:
		return _failure(capacity, "field=item_state.owner_id reason=must match projection source run player")
	var leader_rows: Array[Dictionary] = []
	var follower_rows: Array[Dictionary] = []
	for row: Dictionary in party_members:
		if bool(row["is_leader"]): leader_rows.append(row)
		else: follower_rows.append(row)
	if leader_rows.size() != 1:
		return _failure(capacity, "field=source.party_members reason=must contain exactly one leader")
	leader_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["member_id"]) < int(right["member_id"]))
	follower_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["member_id"]) < int(right["member_id"]))
	var ordered_members: Array[Dictionary] = []
	ordered_members.append_array(leader_rows)
	ordered_members.append_array(follower_rows)
	var automatic_leader := _has_unlock(profile.permanent_feature_unlocks, AUTOMATIC_LEADER_UNLOCK)
	var automatic_ids: Array[String] = []
	var eligible: Array[ExtractionSelection] = []
	var structure_errors: Array[String] = []
	var registry := state.registry()
	for member: Dictionary in ordered_members:
		var container_id := StringName("run-equipment-%03d" % int(member["member_id"]))
		var container := state.container(container_id)
		if container == null or container.container_kind != ItemSlotContainer.RUN_MEMBER_EQUIPMENT:
			structure_errors.append(_error("field=item_state.container reason=missing member equipment %s" % container_id))
			continue
		if container.owner_id != state.owner_id:
			structure_errors.append(_error("field=item_state.container.owner_id reason=must match run owner"))
			continue
		for slot: int in container.occupied_slots():
			var item_id := container.item_id_at(slot)
			if not registry.has(item_id):
				structure_errors.append(_error("field=item_state.registry reason=unknown item %s" % item_id))
				continue
			var candidate := ExtractionSelection.create(item_id, container.container_id, slot)
			if automatic_leader and bool(member["is_leader"]):
				automatic_ids.append(item_id)
			else:
				eligible.append(candidate)

	var inventory := state.container(&"run-inventory")
	if inventory == null or inventory.container_kind != ItemSlotContainer.RUN_INVENTORY:
		structure_errors.append(_error("field=item_state.container reason=missing run inventory"))
	elif inventory.owner_id != state.owner_id:
		structure_errors.append(_error("field=item_state.container.owner_id reason=must match run owner"))
	else:
		for slot: int in inventory.occupied_slots():
			var item_id := inventory.item_id_at(slot)
			if not registry.has(item_id):
				structure_errors.append(_error("field=item_state.registry reason=unknown item %s" % item_id))
				continue
			eligible.append(ExtractionSelection.create(item_id, inventory.container_id, slot))
	if not structure_errors.is_empty():
		return RunExtractionProjection.create(automatic_ids, eligible, [], _item_ids(eligible), capacity, structure_errors, RunExtractionProjection.FailureKind.SOURCE_INVALID)

	var automatic_set: Dictionary = {}
	for item_id: String in automatic_ids:
		automatic_set[item_id] = true
	var eligible_by_id: Dictionary = {}
	for candidate: ExtractionSelection in eligible:
		eligible_by_id[candidate.item_id] = candidate

	var selection_errors: Array[String] = []
	var seen: Dictionary = {}
	var selected_set: Dictionary = {}
	for index: int in selections.size():
		var selection := selections[index]
		if selection == null:
			selection_errors.append(_error("field=selections[%d] reason=must be provided" % index))
			continue
		if seen.has(selection.item_id):
			selection_errors.append(_error("field=selections[%d].item_id reason=duplicate selection %s" % [index, selection.item_id]))
			continue
		seen[selection.item_id] = true
		if automatic_set.has(selection.item_id):
			selection_errors.append(_error("field=selections[%d].item_id reason=item %s is automatic" % [index, selection.item_id]))
			continue
		var actual := eligible_by_id.get(selection.item_id) as ExtractionSelection
		if actual == null:
			selection_errors.append(_error("field=selections[%d].item_id reason=unknown item %s" % [index, selection.item_id]))
			continue
		if (
			selection.expected_source_container_id != actual.expected_source_container_id
			or selection.expected_source_slot != actual.expected_source_slot
		):
			selection_errors.append(_error(
				"field=selections[%d].source reason=expected %s[%d] but item is at %s[%d]" % [
					index,
					selection.expected_source_container_id,
					selection.expected_source_slot,
					actual.expected_source_container_id,
					actual.expected_source_slot,
				]
			))
			continue
		selected_set[selection.item_id] = true
	var failure_kind := RunExtractionProjection.FailureKind.STALE_SELECTION if not selection_errors.is_empty() else RunExtractionProjection.FailureKind.NONE
	if selected_set.size() > capacity:
		selection_errors.append(_error("field=selections reason=%d selected items exceed capacity %d" % [selected_set.size(), capacity]))
		if failure_kind == RunExtractionProjection.FailureKind.NONE:
			failure_kind = RunExtractionProjection.FailureKind.OVER_CAPACITY

	var selected_ids: Array[String] = []
	var lost_ids: Array[String] = []
	for candidate: ExtractionSelection in eligible:
		if selected_set.has(candidate.item_id):
			selected_ids.append(candidate.item_id)
		else:
			lost_ids.append(candidate.item_id)
	return RunExtractionProjection.create(
		automatic_ids,
		eligible,
		selected_ids,
		lost_ids,
		capacity,
		selection_errors,
		failure_kind,
	)

static func _context_is_configured(context: PlayerRunContext) -> bool:
	return (
		context != null
		and not context.run_player_id.is_empty()
		and not context.profile_id.is_empty()
		and context.party != null
		and context.item_state() != null
	)

static func _has_unlock(unlocks: Array[String], wanted: String) -> bool:
	var unique: Dictionary = {}
	for unlock: String in unlocks:
		unique[unlock] = true
	return unique.has(wanted)

static func _member_id_less(left: PartyMemberState, right: PartyMemberState) -> bool:
	return left.member_id < right.member_id

static func _item_ids(values: Array[ExtractionSelection]) -> Array[String]:
	var result: Array[String] = []
	for value: ExtractionSelection in values:
		result.append(value.item_id)
	return result

static func _failure(capacity: int, detail: String) -> RunExtractionProjection:
	return RunExtractionProjection.create([], [], [], [], capacity, [_error(detail)], RunExtractionProjection.FailureKind.SOURCE_INVALID)

static func _error(detail: String) -> String:
	return "%s %s" % [ERROR_PREFIX, detail]
