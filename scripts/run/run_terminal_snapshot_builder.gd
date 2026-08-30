class_name RunTerminalSnapshotBuilder
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_RUN_TERMINAL_CAPTURE_ERROR"

func capture(
	outcome: RunTerminalSnapshot.Outcome,
	elapsed_seconds: float,
	context: PlayerRunContext,
) -> RunTerminalSnapshotResult:
	if outcome not in [RunTerminalSnapshot.Outcome.VICTORY, RunTerminalSnapshot.Outcome.DEFEAT]:
		return _failure("outcome", "must be VICTORY or DEFEAT", RunTerminalSnapshotResult.FailureCategory.INVALID_OUTCOME)
	if not is_finite(elapsed_seconds) or elapsed_seconds < 0.0:
		return _failure("elapsed_seconds", "must be finite and nonnegative", RunTerminalSnapshotResult.FailureCategory.INVALID_DURATION)
	if context == null or not context.is_configured():
		return _failure("context", "must be configured", RunTerminalSnapshotResult.FailureCategory.INVALID_CONTEXT)
	if context.profile_id.strip_edges().is_empty():
		return _failure("profile_id", "must not be empty", RunTerminalSnapshotResult.FailureCategory.IDENTITY_MISMATCH)
	if String(context.run_id).strip_edges().is_empty():
		return _failure("run_id", "must not be empty", RunTerminalSnapshotResult.FailureCategory.IDENTITY_MISMATCH)
	if context.run_seed <= 0 or context.run_seed > ItemInstanceCodec.JSON_SAFE_INTEGER_MAX:
		return _failure("run_seed", "must be a positive JSON-safe integer", RunTerminalSnapshotResult.FailureCategory.IDENTITY_MISMATCH)
	if String(context.run_player_id).strip_edges().is_empty():
		return _failure("run_player_id", "must not be empty", RunTerminalSnapshotResult.FailureCategory.IDENTITY_MISMATCH)
	if context.party == null:
		return _failure("party", "must be available", RunTerminalSnapshotResult.FailureCategory.INVALID_PARTY)
	if context.party.members.is_empty() or context.party.members.size() > PartyForgeSettings.MAX_PARTY_CAPACITY:
		return _failure("members", "must contain between 1 and %d members" % PartyForgeSettings.MAX_PARTY_CAPACITY, RunTerminalSnapshotResult.FailureCategory.INVALID_PARTY)
	var member_snapshots: Array[RunTerminalPartyMemberSnapshot] = []
	var seen: Dictionary = {}
	var leader_member_id := 0
	var leader_count := 0
	for index: int in context.party.members.size():
		var member := context.party.members[index]
		if member == null:
			return _failure("members[%d]" % index, "must not be null", RunTerminalSnapshotResult.FailureCategory.INVALID_MEMBER)
		if member.member_id <= 0 or member.member_id > ItemInstanceCodec.JSON_SAFE_INTEGER_MAX:
			return _failure("members[%d].member_id" % index, "must be a positive JSON-safe integer", RunTerminalSnapshotResult.FailureCategory.INVALID_MEMBER)
		if seen.has(member.member_id):
			return _failure("members[%d].member_id" % index, "must be unique", RunTerminalSnapshotResult.FailureCategory.INVALID_MEMBER)
		seen[member.member_id] = true
		if member.class_definition == null:
			return _failure("members[%d].class" % index, "must be available", RunTerminalSnapshotResult.FailureCategory.INVALID_MEMBER)
		if String(member.class_definition.id).strip_edges().is_empty():
			return _failure("members[%d].class_id" % index, "must not be empty", RunTerminalSnapshotResult.FailureCategory.INVALID_MEMBER)
		if member.class_definition.display_name.strip_edges().is_empty():
			return _failure("members[%d].class_name" % index, "must not be empty", RunTerminalSnapshotResult.FailureCategory.INVALID_MEMBER)
		var progression := context.progression_for(member.member_id)
		if progression == null or progression.member_id != member.member_id or progression.level <= 0 or progression.level > ItemInstanceCodec.JSON_SAFE_INTEGER_MAX:
			return _failure("members[%d].final_level" % index, "matching positive JSON-safe progression must be available", RunTerminalSnapshotResult.FailureCategory.PROGRESSION_UNAVAILABLE)
		var display_name := member.character_name.strip_edges()
		if display_name.is_empty():
			display_name = member.class_definition.display_name.strip_edges()
		var member_snapshot := RunTerminalPartyMemberSnapshot.create(
			member.member_id, display_name, member.class_definition.id,
			member.class_definition.display_name, member.is_leader, progression.level,
		)
		if member_snapshot == null:
			return _failure("members[%d]" % index, "contains invalid terminal truth", RunTerminalSnapshotResult.FailureCategory.INVALID_MEMBER)
		member_snapshots.append(member_snapshot)
		if member.is_leader:
			leader_count += 1
			leader_member_id = member.member_id
	if leader_count != 1:
		return _failure("leader", "party must contain exactly one leader", RunTerminalSnapshotResult.FailureCategory.INVALID_PARTY)
	var source_result := RunResolutionSource.from_context(context, leader_member_id)
	if not source_result.ok():
		var category := RunTerminalSnapshotResult.FailureCategory.INVALID_SOURCE
		match source_result.failure_kind:
			RunResolutionSourceResult.FailureKind.IDENTITY_MISMATCH:
				category = RunTerminalSnapshotResult.FailureCategory.IDENTITY_MISMATCH
			RunResolutionSourceResult.FailureKind.OWNERSHIP_VERIFICATION:
				category = RunTerminalSnapshotResult.FailureCategory.OWNERSHIP_VERIFICATION
		return _failure("resolution_source", source_result.error, category)
	return RunTerminalSnapshot.create(
		outcome, elapsed_seconds, context.profile_id, context.run_id, context.run_seed,
		context.run_player_id, leader_member_id, member_snapshots, source_result.source,
	)

static func _error(field: String, reason: String) -> String:
	return "%s field=%s reason=%s" % [ERROR_PREFIX, field, reason]

static func _failure(
	field: String,
	reason: String,
	category: RunTerminalSnapshotResult.FailureCategory,
) -> RunTerminalSnapshotResult:
	return RunTerminalSnapshotResult.failure(_error(field, reason), category)
