class_name RunResolutionSource
extends RefCounted

const SCHEMA_VERSION := 1
const ERROR_PREFIX := "PARTY_FORGE_RUN_RESOLUTION_SOURCE_ERROR"
const FIELDS: Array[String] = [
	"schema_version", "profile_id", "run_id", "run_seed", "run_player_id",
	"leader_member_id", "party_members", "item_state", "leader_class_id",
	"leader_core_attributes",
]
const MEMBER_FIELDS: Array[String] = ["member_id", "class_id", "is_leader"]

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
var _party_members: Array[Dictionary] = []
var party_members: Array[Dictionary]:
	get: return _party_members.duplicate(true)
var _item_state: ItemOwnershipState
var item_state: ItemOwnershipState:
	get: return _item_state.copy() if _item_state != null else null
var _leader_class_id: StringName = &""
var leader_class_id: StringName:
	get: return _leader_class_id
var _leader_core_attributes: Dictionary = {}
var leader_core_attributes: Dictionary:
	get: return _leader_core_attributes.duplicate(true)

static func from_context(context: PlayerRunContext, leader_member_id_value: int) -> RunResolutionSourceResult:
	if context == null or not context.is_configured():
		return RunResolutionSourceResult.failure(_error("context", "must be configured"))
	if leader_member_id_value <= 0:
		return RunResolutionSourceResult.failure(_error("leader_member_id", "must be positive"))
	if context.profile_id.strip_edges().is_empty() or String(context.run_id).strip_edges().is_empty() or context.run_seed <= 0 or String(context.run_player_id).strip_edges().is_empty():
		return RunResolutionSourceResult.failure(_error("run_identity", "configured run identity is incomplete"))
	var snapshot := context.profile_snapshot
	if snapshot == null or snapshot.profile_id != context.profile_id:
		return RunResolutionSourceResult.failure(_error("profile_snapshot", "profile identity does not match the configured run"))
	var durable := ResumableRunItemCodec.decode(snapshot.resumable_run, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if durable == null:
		return RunResolutionSourceResult.failure(_error("profile_snapshot", "strict run identity is unavailable"))
	if durable.run_id != context.run_id or durable.run_seed != context.run_seed or durable.run_player_id != context.run_player_id or durable.leader_member_id != leader_member_id_value:
		return RunResolutionSourceResult.failure(_error("run_identity", "profile snapshot and configured run must match"))
	if context.party == null:
		return RunResolutionSourceResult.failure(_error("party", "must be available"))
	var rows: Array[Dictionary] = []
	for member: PartyMemberState in context.party.members:
		if member == null or member.member_id <= 0 or member.class_definition == null or String(member.class_definition.id).strip_edges().is_empty():
			return RunResolutionSourceResult.failure(_error("party_members", "every member needs exact identity and class"))
		rows.append({"member_id": member.member_id, "class_id": String(member.class_definition.id), "is_leader": member.is_leader})
	var leader := context.party.member_by_id(leader_member_id_value)
	if leader == null or not leader.is_leader or leader.class_definition == null:
		return RunResolutionSourceResult.failure(_error("leader_member_id", "must identify the one live leader"))
	var stats := context.party.stats_for(leader_member_id_value)
	if stats == null:
		return RunResolutionSourceResult.failure(_error("leader_core_attributes", "resolved live attributes are unavailable"))
	var attributes: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		attributes[String(attribute_id)] = stats.value(attribute_id)
	var state := context.item_state()
	if state == null:
		return RunResolutionSourceResult.failure(_error("item_state", "live ownership is unavailable"))
	return _create_validated(
		context.profile_id, context.run_id, context.run_seed, context.run_player_id,
		leader_member_id_value, rows, state, leader.class_definition.id, attributes,
	)

static func from_dictionary(document: Variant) -> RunResolutionSourceResult:
	if not document is Dictionary:
		return RunResolutionSourceResult.failure(_error("document", "must be a dictionary"))
	var data := document as Dictionary
	var fields_error := ItemRegistry._exact_fields(data, FIELDS, "document")
	if not fields_error.is_empty():
		return RunResolutionSourceResult.failure(_error("document", fields_error))
	if not ItemInstanceCodec._is_json_int(data["schema_version"], SCHEMA_VERSION, SCHEMA_VERSION):
		return RunResolutionSourceResult.failure(_error("schema_version", "must equal supported schema %d" % SCHEMA_VERSION))
	for field: String in ["profile_id", "run_id", "run_player_id", "leader_class_id"]:
		if typeof(data[field]) != TYPE_STRING or String(data[field]).strip_edges().is_empty():
			return RunResolutionSourceResult.failure(_error(field, "must be a non-empty string"))
	if not ItemInstanceCodec._is_json_int(data["run_seed"], 1, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
		return RunResolutionSourceResult.failure(_error("run_seed", "must be a positive JSON-safe integer"))
	if not ItemInstanceCodec._is_json_int(data["leader_member_id"], 1, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
		return RunResolutionSourceResult.failure(_error("leader_member_id", "must be a positive JSON-safe integer"))
	if not data["party_members"] is Array:
		return RunResolutionSourceResult.failure(_error("party_members", "must be an array"))
	var rows: Array[Dictionary] = []
	for row_value: Variant in data["party_members"] as Array:
		rows.append((row_value as Dictionary).duplicate(true) if row_value is Dictionary else {})
	var ownership := ItemOwnershipState.decode(data["item_state"], GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not ownership.ok():
		return RunResolutionSourceResult.failure(_error("item_state", ownership.error))
	if not data["leader_core_attributes"] is Dictionary:
		return RunResolutionSourceResult.failure(_error("leader_core_attributes", "must be a dictionary"))
	return _create_validated(
		String(data["profile_id"]), StringName(data["run_id"]), int(data["run_seed"]),
		StringName(data["run_player_id"]), int(data["leader_member_id"]), rows,
		ownership.state, StringName(data["leader_class_id"]),
		(data["leader_core_attributes"] as Dictionary).duplicate(true),
	)

static func _create_validated(
	profile_id_value: String, run_id_value: StringName, run_seed_value: int,
	run_player_id_value: StringName, leader_member_id_value: int,
	party_member_values: Array[Dictionary], item_state_value: ItemOwnershipState,
	leader_class_id_value: StringName, leader_attribute_values: Dictionary,
) -> RunResolutionSourceResult:
	if profile_id_value.strip_edges().is_empty() or String(run_id_value).strip_edges().is_empty() or run_seed_value <= 0 or String(run_player_id_value).strip_edges().is_empty() or leader_member_id_value <= 0:
		return RunResolutionSourceResult.failure(_error("run_identity", "identity fields must be complete and positive"))
	if item_state_value == null:
		return RunResolutionSourceResult.failure(_error("item_state", "must be available"))
	var ownership_error := item_state_value.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not ownership_error.is_empty():
		return RunResolutionSourceResult.failure(_error("item_state", ownership_error))
	if item_state_value.owner_id != String(run_player_id_value):
		return RunResolutionSourceResult.failure(_error("item_state.owner_id", "must match run_player_id"))
	if party_member_values.is_empty():
		return RunResolutionSourceResult.failure(_error("party_members", "must not be empty"))
	var seen: Dictionary = {}
	var leader_count := 0
	var resolved_leader_class := ""
	for index: int in party_member_values.size():
		var row := party_member_values[index]
		var row_fields_error := ItemRegistry._exact_fields(row, MEMBER_FIELDS, "party_members[%d]" % index)
		if not row_fields_error.is_empty():
			return RunResolutionSourceResult.failure(_error("party_members[%d]" % index, row_fields_error))
		if not ItemInstanceCodec._is_json_int(row["member_id"], 1, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
			return RunResolutionSourceResult.failure(_error("party_members[%d].member_id" % index, "must be positive"))
		if typeof(row["class_id"]) != TYPE_STRING or String(row["class_id"]).strip_edges().is_empty():
			return RunResolutionSourceResult.failure(_error("party_members[%d].class_id" % index, "must be a non-empty string"))
		if typeof(row["is_leader"]) != TYPE_BOOL:
			return RunResolutionSourceResult.failure(_error("party_members[%d].is_leader" % index, "must be a boolean"))
		var member_id := int(row["member_id"])
		if seen.has(member_id):
			return RunResolutionSourceResult.failure(_error("party_members[%d].member_id" % index, "must be unique"))
		seen[member_id] = true
		if bool(row["is_leader"]):
			leader_count += 1
			if member_id != leader_member_id_value:
				return RunResolutionSourceResult.failure(_error("leader_member_id", "must identify the leader row"))
			resolved_leader_class = String(row["class_id"])
	if leader_count != 1:
		return RunResolutionSourceResult.failure(_error("party_members", "must contain exactly one leader"))
	if resolved_leader_class != String(leader_class_id_value):
		return RunResolutionSourceResult.failure(_error("leader_class_id", "must match the leader row"))
	var expected_attribute_fields: Array[String] = []
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		expected_attribute_fields.append(String(attribute_id))
	var attributes_error := ItemRegistry._exact_fields(leader_attribute_values, expected_attribute_fields, "leader_core_attributes")
	if not attributes_error.is_empty():
		return RunResolutionSourceResult.failure(_error("leader_core_attributes", attributes_error))
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		var value: Variant = leader_attribute_values[String(attribute_id)]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) < 0.0:
			return RunResolutionSourceResult.failure(_error("leader_core_attributes.%s" % attribute_id, "must be a finite nonnegative number"))
	var source := RunResolutionSource.new()
	source._profile_id = profile_id_value
	source._run_id = run_id_value
	source._run_seed = run_seed_value
	source._run_player_id = run_player_id_value
	source._leader_member_id = leader_member_id_value
	source._party_members = party_member_values.duplicate(true)
	source._item_state = item_state_value.copy()
	source._leader_class_id = leader_class_id_value
	source._leader_core_attributes = leader_attribute_values.duplicate(true)
	return RunResolutionSourceResult.success(source)

func copy() -> RunResolutionSource:
	var result := RunResolutionSource.new()
	result._profile_id = _profile_id
	result._run_id = _run_id
	result._run_seed = _run_seed
	result._run_player_id = _run_player_id
	result._leader_member_id = _leader_member_id
	result._party_members = _party_members.duplicate(true)
	result._item_state = _item_state.copy() if _item_state != null else null
	result._leader_class_id = _leader_class_id
	result._leader_core_attributes = _leader_core_attributes.duplicate(true)
	return result

func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": _profile_id,
		"run_id": String(_run_id),
		"run_seed": _run_seed,
		"run_player_id": String(_run_player_id),
		"leader_member_id": _leader_member_id,
		"party_members": _party_members.duplicate(true),
		"item_state": _item_state.to_dictionary() if _item_state != null else {},
		"leader_class_id": String(_leader_class_id),
		"leader_core_attributes": _leader_core_attributes.duplicate(true),
	}

static func _error(field: String, reason: String) -> String:
	return "%s field=%s reason=%s" % [ERROR_PREFIX, field, reason]
