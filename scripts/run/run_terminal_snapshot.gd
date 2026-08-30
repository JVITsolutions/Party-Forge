class_name RunTerminalSnapshot
extends RefCounted

enum Outcome { VICTORY, DEFEAT }

const SCHEMA_VERSION := 1
const ERROR_PREFIX := "PARTY_FORGE_RUN_TERMINAL_SNAPSHOT_ERROR"
const FIELDS: Array[String] = [
	"schema_version", "outcome", "elapsed_seconds", "profile_id", "run_id",
	"run_seed", "run_player_id", "leader_member_id", "members", "resolution_source",
]

var _outcome := Outcome.VICTORY
var outcome: Outcome:
	get: return _outcome
var _elapsed_seconds := 0.0
var elapsed_seconds: float:
	get: return _elapsed_seconds
var _profile_id := ""
var profile_id: String:
	get: return _profile_id
var _run_id: StringName = &""
var run_id: StringName:
	get: return _run_id
var _run_seed := 0
var run_seed: int:
	get: return _run_seed
var _run_player_id: StringName = &""
var run_player_id: StringName:
	get: return _run_player_id
var _leader_member_id := 0
var leader_member_id: int:
	get: return _leader_member_id
var _members: Array[RunTerminalPartyMemberSnapshot] = []
var members: Array[RunTerminalPartyMemberSnapshot]:
	get:
		var copies: Array[RunTerminalPartyMemberSnapshot] = []
		for member: RunTerminalPartyMemberSnapshot in _members:
			copies.append(member.copy())
		return copies
var _resolution_source: RunResolutionSource
var resolution_source: RunResolutionSource:
	get:
		return _resolution_source.copy() if _resolution_source != null else null

static func create(
	outcome_value: Outcome,
	elapsed_seconds_value: float,
	profile_id_value: String,
	run_id_value: StringName,
	run_seed_value: int,
	run_player_id_value: StringName,
	leader_member_id_value: int,
	member_values: Array[RunTerminalPartyMemberSnapshot],
	resolution_source_value: RunResolutionSource,
) -> RunTerminalSnapshotResult:
	return _create_validated(
		outcome_value, elapsed_seconds_value, profile_id_value, run_id_value, run_seed_value,
		run_player_id_value, leader_member_id_value, member_values, resolution_source_value,
	)

static func from_dictionary(document: Variant) -> RunTerminalSnapshotResult:
	if not document is Dictionary:
		return RunTerminalSnapshotResult.failure(_error("document", "must be a dictionary"))
	var data := document as Dictionary
	var fields_error := ItemRegistry._exact_fields(data, FIELDS, "document")
	if not fields_error.is_empty():
		return RunTerminalSnapshotResult.failure(_error("document", fields_error))
	if not ItemInstanceCodec._is_json_int(data["schema_version"], SCHEMA_VERSION, SCHEMA_VERSION):
		return RunTerminalSnapshotResult.failure(_error("schema_version", "must equal supported schema %d" % SCHEMA_VERSION))
	if not ItemInstanceCodec._is_json_int(data["outcome"], Outcome.VICTORY, Outcome.DEFEAT):
		return RunTerminalSnapshotResult.failure(_error("outcome", "must be VICTORY or DEFEAT"))
	if typeof(data["elapsed_seconds"]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data["elapsed_seconds"])) or float(data["elapsed_seconds"]) < 0.0:
		return RunTerminalSnapshotResult.failure(_error("elapsed_seconds", "must be a finite nonnegative number"))
	for field: String in ["profile_id", "run_id", "run_player_id"]:
		if typeof(data[field]) != TYPE_STRING or String(data[field]).strip_edges().is_empty():
			return RunTerminalSnapshotResult.failure(_error(field, "must be a non-empty string"))
	if not ItemInstanceCodec._is_json_int(data["run_seed"], 1, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
		return RunTerminalSnapshotResult.failure(_error("run_seed", "must be a positive JSON-safe integer"))
	if not ItemInstanceCodec._is_json_int(data["leader_member_id"], 1, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
		return RunTerminalSnapshotResult.failure(_error("leader_member_id", "must be a positive JSON-safe integer"))
	if not data["members"] is Array:
		return RunTerminalSnapshotResult.failure(_error("members", "must be an array"))
	var decoded_members: Array[RunTerminalPartyMemberSnapshot] = []
	for index: int in (data["members"] as Array).size():
		var member_value: Variant = (data["members"] as Array)[index]
		if not member_value is Dictionary:
			return RunTerminalSnapshotResult.failure(_error("members[%d]" % index, "must be a dictionary"))
		var member_data := member_value as Dictionary
		var member_fields_error := ItemRegistry._exact_fields(member_data, RunTerminalPartyMemberSnapshot.FIELDS, "members[%d]" % index)
		if not member_fields_error.is_empty():
			return RunTerminalSnapshotResult.failure(_error("members[%d]" % index, member_fields_error))
		for string_field: String in ["display_name", "class_id", "class_name"]:
			if typeof(member_data[string_field]) != TYPE_STRING or String(member_data[string_field]).strip_edges().is_empty():
				return RunTerminalSnapshotResult.failure(_error("members[%d].%s" % [index, string_field], "must be a non-empty string"))
		if not ItemInstanceCodec._is_json_int(member_data["member_id"], 1, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
			return RunTerminalSnapshotResult.failure(_error("members[%d].member_id" % index, "must be a positive JSON-safe integer"))
		if typeof(member_data["is_leader"]) != TYPE_BOOL:
			return RunTerminalSnapshotResult.failure(_error("members[%d].is_leader" % index, "must be a boolean"))
		if not ItemInstanceCodec._is_json_int(member_data["final_level"], 1, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
			return RunTerminalSnapshotResult.failure(_error("members[%d].final_level" % index, "must be a positive JSON-safe integer"))
		var decoded_member := RunTerminalPartyMemberSnapshot.create(
			int(member_data["member_id"]), String(member_data["display_name"]),
			StringName(member_data["class_id"]), String(member_data["class_name"]),
			bool(member_data["is_leader"]), int(member_data["final_level"]),
		)
		if decoded_member == null:
			return RunTerminalSnapshotResult.failure(_error("members[%d]" % index, "contains invalid member truth"))
		decoded_members.append(decoded_member)
	var source_result := RunResolutionSource.from_dictionary(data["resolution_source"])
	if not source_result.ok():
		return RunTerminalSnapshotResult.failure(_error("resolution_source", source_result.error))
	return _create_validated(
		int(data["outcome"]), float(data["elapsed_seconds"]), String(data["profile_id"]),
		StringName(data["run_id"]), int(data["run_seed"]), StringName(data["run_player_id"]),
		int(data["leader_member_id"]), decoded_members, source_result.source,
	)

static func _create_validated(
	outcome_value: Outcome,
	elapsed_seconds_value: float,
	profile_id_value: String,
	run_id_value: StringName,
	run_seed_value: int,
	run_player_id_value: StringName,
	leader_member_id_value: int,
	member_values: Array[RunTerminalPartyMemberSnapshot],
	resolution_source_value: RunResolutionSource,
) -> RunTerminalSnapshotResult:
	if outcome_value not in [Outcome.VICTORY, Outcome.DEFEAT]:
		return RunTerminalSnapshotResult.failure(_error("outcome", "must be VICTORY or DEFEAT"))
	if not is_finite(elapsed_seconds_value) or elapsed_seconds_value < 0.0:
		return RunTerminalSnapshotResult.failure(_error("elapsed_seconds", "must be finite and nonnegative"))
	if profile_id_value.strip_edges().is_empty():
		return RunTerminalSnapshotResult.failure(_error("profile_id", "must not be empty"))
	if String(run_id_value).strip_edges().is_empty():
		return RunTerminalSnapshotResult.failure(_error("run_id", "must not be empty"))
	if run_seed_value <= 0:
		return RunTerminalSnapshotResult.failure(_error("run_seed", "must be positive"))
	if String(run_player_id_value).strip_edges().is_empty():
		return RunTerminalSnapshotResult.failure(_error("run_player_id", "must not be empty"))
	if leader_member_id_value <= 0:
		return RunTerminalSnapshotResult.failure(_error("leader_member_id", "must be positive"))
	if member_values.is_empty() or member_values.size() > PartyForgeSettings.MAX_PARTY_CAPACITY:
		return RunTerminalSnapshotResult.failure(_error("members", "must contain between 1 and %d members" % PartyForgeSettings.MAX_PARTY_CAPACITY))
	if resolution_source_value == null:
		return RunTerminalSnapshotResult.failure(_error("resolution_source", "must not be null"))
	var validated_source := RunResolutionSource.from_dictionary(resolution_source_value.to_dictionary())
	if not validated_source.ok():
		return RunTerminalSnapshotResult.failure(_error("resolution_source", validated_source.error))
	var source := validated_source.source
	# Godot's JSON parser represents nested integral numbers as floats. Task 7
	# validates those rows as JSON-safe integers; normalize the owned copy so a
	# cold terminal roundtrip returns the same value document as live capture.
	var canonical_source_members := source.party_members
	for row: Dictionary in canonical_source_members:
		row["member_id"] = int(row["member_id"])
	source._party_members = canonical_source_members
	if (
		source.profile_id != profile_id_value
		or source.run_id != run_id_value
		or source.run_seed != run_seed_value
		or source.run_player_id != run_player_id_value
		or source.leader_member_id != leader_member_id_value
	):
		return RunTerminalSnapshotResult.failure(_error("resolution_source", "identity must exactly match terminal identity"))
	if source.party_members.size() != member_values.size():
		return RunTerminalSnapshotResult.failure(_error("members", "must exactly match resolution source party size and order"))
	var seen: Dictionary = {}
	var leader_count := 0
	for index: int in member_values.size():
		var member := member_values[index]
		if member == null:
			return RunTerminalSnapshotResult.failure(_error("members[%d]" % index, "must not be null"))
		if seen.has(member.member_id):
			return RunTerminalSnapshotResult.failure(_error("members[%d].member_id" % index, "must be unique"))
		seen[member.member_id] = true
		if member.is_leader:
			leader_count += 1
			if member.member_id != leader_member_id_value:
				return RunTerminalSnapshotResult.failure(_error("leader_member_id", "must identify the leader member"))
		var source_member := source.party_members[index]
		if (
			int(source_member.get("member_id", 0)) != member.member_id
			or StringName(source_member.get("class_id", "")) != member.class_id
			or bool(source_member.get("is_leader", false)) != member.is_leader
		):
			return RunTerminalSnapshotResult.failure(_error("members[%d]" % index, "must exactly match resolution source identity, class, leader state, and order"))
	if leader_count != 1:
		return RunTerminalSnapshotResult.failure(_error("leader", "members must contain exactly one leader"))
	var result := RunTerminalSnapshot.new()
	result._outcome = outcome_value
	result._elapsed_seconds = elapsed_seconds_value
	result._profile_id = profile_id_value
	result._run_id = run_id_value
	result._run_seed = run_seed_value
	result._run_player_id = run_player_id_value
	result._leader_member_id = leader_member_id_value
	for member: RunTerminalPartyMemberSnapshot in member_values:
		result._members.append(member.copy())
	result._resolution_source = source.copy()
	return RunTerminalSnapshotResult.success(result)

func copy() -> RunTerminalSnapshot:
	var result := RunTerminalSnapshot.new()
	result._outcome = _outcome
	result._elapsed_seconds = _elapsed_seconds
	result._profile_id = _profile_id
	result._run_id = _run_id
	result._run_seed = _run_seed
	result._run_player_id = _run_player_id
	result._leader_member_id = _leader_member_id
	for member: RunTerminalPartyMemberSnapshot in _members:
		result._members.append(member.copy())
	result._resolution_source = _resolution_source.copy() if _resolution_source != null else null
	return result

func to_dictionary() -> Dictionary:
	var member_documents: Array[Dictionary] = []
	for member: RunTerminalPartyMemberSnapshot in _members:
		member_documents.append(member.to_dictionary())
	return {
		"schema_version": SCHEMA_VERSION,
		"outcome": _outcome,
		"elapsed_seconds": _elapsed_seconds,
		"profile_id": _profile_id,
		"run_id": String(_run_id),
		"run_seed": _run_seed,
		"run_player_id": String(_run_player_id),
		"leader_member_id": _leader_member_id,
		"members": member_documents,
		"resolution_source": _resolution_source.to_dictionary() if _resolution_source != null else {},
	}

static func _error(field: String, reason: String) -> String:
	return "%s field=%s reason=%s" % [ERROR_PREFIX, field, reason]
