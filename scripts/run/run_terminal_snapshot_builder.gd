class_name RunTerminalSnapshotBuilder
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_RUN_TERMINAL_CAPTURE_ERROR"

func capture(
	outcome: RunTerminalSnapshot.Outcome,
	elapsed_seconds: float,
	context: PlayerRunContext,
) -> RunTerminalSnapshotResult:
	if outcome not in [RunTerminalSnapshot.Outcome.VICTORY, RunTerminalSnapshot.Outcome.DEFEAT]:
		return RunTerminalSnapshotResult.failure(_error("outcome", "must be VICTORY or DEFEAT"))
	if not is_finite(elapsed_seconds) or elapsed_seconds < 0.0:
		return RunTerminalSnapshotResult.failure(_error("elapsed_seconds", "must be finite and nonnegative"))
	if context == null or not context.is_configured():
		return RunTerminalSnapshotResult.failure(_error("context", "must be configured"))
	if context.profile_id.strip_edges().is_empty():
		return RunTerminalSnapshotResult.failure(_error("profile_id", "must not be empty"))
	if String(context.run_id).strip_edges().is_empty():
		return RunTerminalSnapshotResult.failure(_error("run_id", "must not be empty"))
	if context.run_seed <= 0:
		return RunTerminalSnapshotResult.failure(_error("run_seed", "must be positive"))
	if String(context.run_player_id).strip_edges().is_empty():
		return RunTerminalSnapshotResult.failure(_error("run_player_id", "must not be empty"))
	if context.party == null:
		return RunTerminalSnapshotResult.failure(_error("party", "must be available"))
	if context.party.members.is_empty() or context.party.members.size() > PartyForgeSettings.MAX_PARTY_CAPACITY:
		return RunTerminalSnapshotResult.failure(_error("members", "must contain between 1 and %d members" % PartyForgeSettings.MAX_PARTY_CAPACITY))
	var member_snapshots: Array[RunTerminalPartyMemberSnapshot] = []
	var seen: Dictionary = {}
	var leader_member_id := 0
	var leader_count := 0
	for index: int in context.party.members.size():
		var member := context.party.members[index]
		if member == null:
			return RunTerminalSnapshotResult.failure(_error("members[%d]" % index, "must not be null"))
		if member.member_id <= 0:
			return RunTerminalSnapshotResult.failure(_error("members[%d].member_id" % index, "must be positive"))
		if seen.has(member.member_id):
			return RunTerminalSnapshotResult.failure(_error("members[%d].member_id" % index, "must be unique"))
		seen[member.member_id] = true
		if member.class_definition == null:
			return RunTerminalSnapshotResult.failure(_error("members[%d].class" % index, "must be available"))
		if String(member.class_definition.id).strip_edges().is_empty():
			return RunTerminalSnapshotResult.failure(_error("members[%d].class_id" % index, "must not be empty"))
		if member.class_definition.display_name.strip_edges().is_empty():
			return RunTerminalSnapshotResult.failure(_error("members[%d].class_name" % index, "must not be empty"))
		var progression := context.progression_for(member.member_id)
		if progression == null or progression.member_id != member.member_id or progression.level <= 0:
			return RunTerminalSnapshotResult.failure(_error("members[%d].final_level" % index, "matching positive progression must be available"))
		var display_name := member.character_name.strip_edges()
		if display_name.is_empty():
			display_name = member.class_definition.display_name.strip_edges()
		var member_snapshot := RunTerminalPartyMemberSnapshot.create(
			member.member_id, display_name, member.class_definition.id,
			member.class_definition.display_name, member.is_leader, progression.level,
		)
		if member_snapshot == null:
			return RunTerminalSnapshotResult.failure(_error("members[%d]" % index, "contains invalid terminal truth"))
		member_snapshots.append(member_snapshot)
		if member.is_leader:
			leader_count += 1
			leader_member_id = member.member_id
	if leader_count != 1:
		return RunTerminalSnapshotResult.failure(_error("leader", "party must contain exactly one leader"))
	var source_result := RunResolutionSource.from_context(context, leader_member_id)
	if not source_result.ok():
		return RunTerminalSnapshotResult.failure(_error("resolution_source", source_result.error))
	return RunTerminalSnapshot.create(
		outcome, elapsed_seconds, context.profile_id, context.run_id, context.run_seed,
		context.run_player_id, leader_member_id, member_snapshots, source_result.source,
	)

static func _error(field: String, reason: String) -> String:
	return "%s field=%s reason=%s" % [ERROR_PREFIX, field, reason]
