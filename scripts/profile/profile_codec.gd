class_name ProfileCodec
extends RefCounted

const JSON_SAFE_INTEGER_MAX := 9007199254740991
const LEGACY_SCHEMA_VERSION := 1
const SCHEMA_TWO_VERSION := 2
const HISTORICAL_FIELDS: Array[String] = [
	"schema_version",
	"profile_id",
	"display_name",
	"created_at_unix",
	"updated_at_unix",
	"prologue_state",
	"last_safe_checkpoint",
	"gold",
	"passive_points_available",
	"passive_points_lifetime_earned",
	"milestones",
	"permanent_feature_unlocks",
	"discovered_buildings",
	"discovered_trees",
	"tree_allocations",
	"tree_visibility_progress",
	"owned_characters",
	"squad_capacity",
	"inventory_columns",
	"stash_tabs",
	"extraction_capacity",
	"run_history",
	"resumable_run",
	"applied_transactions",
]
const SCHEMA_TWO_FIELDS: Array[String] = [
	"schema_version",
	"profile_id",
	"display_name",
	"created_at_unix",
	"updated_at_unix",
	"prologue_state",
	"last_safe_checkpoint",
	"gold",
	"passive_points_available",
	"passive_points_lifetime_earned",
	"milestones",
	"permanent_feature_unlocks",
	"discovered_buildings",
	"discovered_trees",
	"tree_allocations",
	"tree_visibility_progress",
	"owned_characters",
	"squad_capacity",
	"inventory_columns",
	"item_records",
	"stash_tabs",
	"next_item_sequence",
	"extraction_capacity",
	"run_history",
	"resumable_run",
	"applied_transactions",
]
const CURRENT_FIELDS: Array[String] = [
	"schema_version",
	"profile_id",
	"display_name",
	"created_at_unix",
	"updated_at_unix",
	"prologue_state",
	"last_safe_checkpoint",
	"gold",
	"passive_points_available",
	"passive_points_lifetime_earned",
	"milestones",
	"permanent_feature_unlocks",
	"discovered_buildings",
	"discovered_trees",
	"tree_allocations",
	"tree_visibility_progress",
	"owned_characters",
	"squad_capacity",
	"inventory_columns",
	"item_records",
	"leader_loadout",
	"leader_loadout_class_id",
	"stash_tabs",
	"next_item_sequence",
	"extraction_capacity",
	"run_history",
	"resumable_run",
	"applied_transactions",
]

static func encode(profile: ProfileState) -> String:
	return JSON.stringify(profile.to_dictionary(), "\t", false)

static func decode(text: String) -> ProfileLoadResult:
	var result := ProfileLoadResult.new()
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK or not parser.data is Dictionary:
		result.error = "PROFILE_DECODE_ERROR line=%d reason=%s" % [parser.get_error_line(), parser.get_error_message()]
		return result
	return decode_document(parser.data as Dictionary)

static func decode_document(data: Dictionary) -> ProfileLoadResult:
	var result := ProfileLoadResult.new()
	var migrated := ProfileMigrator.migrate_document(data)
	result.profile = migrated.profile
	result.error = migrated.error
	result.migrated = migrated.migrated
	result.source_schema_version = migrated.source_schema_version
	return result

static func validate_profile(profile: ProfileState) -> String:
	if profile == null:
		return "PROFILE_VALIDATION_ERROR reason=profile is null"
	return validate_current_document(profile.to_dictionary())

static func validate_document(document: Dictionary) -> String:
	return validate_current_document(document)

static func validate_profile_id(profile_id: Variant) -> String:
	if typeof(profile_id) != TYPE_STRING:
		return _field_error("profile_id", "must be a string")
	var value := profile_id as String
	if value.length() < 8 or not value.is_valid_filename():
		return _field_error("profile_id", "invalid profile id")
	return ""

static func validate_current_document(document: Dictionary) -> String:
	return _validate_document(document, ProfileState.SCHEMA_VERSION, false)

static func validate_schema_two_document(document: Dictionary) -> String:
	return _validate_document(document, SCHEMA_TWO_VERSION, false)

static func validate_loadable_document(document: Dictionary) -> String:
	var schema_value: Variant = document.get("schema_version")
	if _is_json_int(schema_value, LEGACY_SCHEMA_VERSION, LEGACY_SCHEMA_VERSION):
		return _validate_document(document, LEGACY_SCHEMA_VERSION, false)
	if _is_json_int(schema_value, SCHEMA_TWO_VERSION, SCHEMA_TWO_VERSION):
		return _validate_document(document, SCHEMA_TWO_VERSION, false)
	if _is_json_int(schema_value, ProfileState.SCHEMA_VERSION, ProfileState.SCHEMA_VERSION):
		return _validate_document(document, ProfileState.SCHEMA_VERSION, false)
	return _schema_error(schema_value)

static func _validate_document(data: Dictionary, expected_schema: int, result_snapshot: bool) -> String:
	if not _is_json_int(data.get("schema_version"), expected_schema, expected_schema):
		return _schema_error(data.get("schema_version", "missing"))
	var expected_fields := HISTORICAL_FIELDS
	if expected_schema == SCHEMA_TWO_VERSION:
		expected_fields = SCHEMA_TWO_FIELDS
	elif expected_schema == ProfileState.SCHEMA_VERSION:
		expected_fields = CURRENT_FIELDS
	var fields_error := _exact_fields(data, expected_fields)
	if not fields_error.is_empty():
		return fields_error
	for field: String in ["profile_id", "display_name"]:
		if typeof(data[field]) != TYPE_STRING:
			return _field_error(field, "must be a string")
	var profile_id := data["profile_id"] as String
	var display_name := data["display_name"] as String
	var profile_id_error := validate_profile_id(profile_id)
	if not profile_id_error.is_empty():
		return profile_id_error
	if display_name.is_empty() or display_name.length() > 32 or display_name != display_name.strip_edges():
		return _field_error("display_name", "must contain 1-32 trimmed characters")
	if expected_schema == ProfileState.SCHEMA_VERSION and typeof(data["leader_loadout_class_id"]) != TYPE_STRING:
		return _field_error("leader_loadout_class_id", "must be a string")
	for field: String in ["created_at_unix", "updated_at_unix", "gold", "passive_points_available", "passive_points_lifetime_earned", "extraction_capacity"]:
		var error := _integer_field(data, field, 0, JSON_SAFE_INTEGER_MAX)
		if not error.is_empty():
			return error
	var prologue_error := _integer_field(data, "prologue_state", ProfileState.PrologueState.NOT_STARTED, ProfileState.PrologueState.COMPLETED)
	if not prologue_error.is_empty():
		return prologue_error
	var squad_error := _integer_field(data, "squad_capacity", 1, JSON_SAFE_INTEGER_MAX)
	if not squad_error.is_empty():
		return squad_error
	var inventory_error := _integer_field(data, "inventory_columns", 0, 8)
	if not inventory_error.is_empty():
		return inventory_error
	if expected_schema >= SCHEMA_TWO_VERSION:
		var sequence_error := _integer_field(data, "next_item_sequence", 0, JSON_SAFE_INTEGER_MAX)
		if not sequence_error.is_empty():
			return sequence_error
	if int(data["updated_at_unix"]) < int(data["created_at_unix"]):
		return _field_error("updated_at_unix", "updated time predates creation")
	if int(data["passive_points_lifetime_earned"]) < int(data["passive_points_available"]):
		return _field_error("passive_points_lifetime_earned", "must cover available points")
	for field: String in ["last_safe_checkpoint", "tree_allocations", "tree_visibility_progress", "owned_characters", "resumable_run", "applied_transactions"]:
		if not data[field] is Dictionary:
			return _field_error(field, "must be a dictionary")
	for field: String in ["milestones", "permanent_feature_unlocks", "discovered_buildings", "discovered_trees", "stash_tabs", "run_history"]:
		if not data[field] is Array:
			return _field_error(field, "must be an array")
	for field: String in ["milestones", "permanent_feature_unlocks", "discovered_buildings", "discovered_trees"]:
		for item: Variant in data[field] as Array:
			if typeof(item) != TYPE_STRING:
				return _field_error(field, "must contain only strings")
	for tree_id: Variant in data["tree_allocations"] as Dictionary:
		if typeof(tree_id) != TYPE_STRING or not (data["tree_allocations"] as Dictionary)[tree_id] is Array:
			return _field_error("tree_allocations", "must map string tree ids to string arrays")
		for node_id: Variant in (data["tree_allocations"] as Dictionary)[tree_id] as Array:
			if typeof(node_id) != TYPE_STRING:
				return _field_error("tree_allocations", "must map string tree ids to string arrays")
	for tree_id: Variant in data["tree_visibility_progress"] as Dictionary:
		if typeof(tree_id) != TYPE_STRING or not _is_json_int((data["tree_visibility_progress"] as Dictionary)[tree_id], 0, JSON_SAFE_INTEGER_MAX):
			return _field_error("tree_visibility_progress", "must map string tree ids to non-negative integers")
	for character_id: Variant in data["owned_characters"] as Dictionary:
		if typeof(character_id) != TYPE_STRING or not (data["owned_characters"] as Dictionary)[character_id] is Dictionary:
			return _field_error("owned_characters", "must map string character ids to dictionaries")
		if not _is_json_value((data["owned_characters"] as Dictionary)[character_id]):
			return _field_error("owned_characters", "contains a non-JSON value")
	for item: Variant in data["run_history"] as Array:
		if not item is Dictionary or not _is_json_value(item):
			return _field_error("run_history", "must contain only JSON dictionaries")
	for field: String in ["last_safe_checkpoint", "resumable_run"]:
		if not _is_json_value(data[field]):
			return _field_error(field, "contains a non-JSON value")
	if expected_schema == LEGACY_SCHEMA_VERSION:
		for item: Variant in data["stash_tabs"] as Array:
			if not item is Dictionary or not _is_json_value(item):
				return _field_error("stash_tabs", "must contain only JSON dictionaries")
	elif expected_schema == SCHEMA_TWO_VERSION:
		var storage_error := _validate_storage(data, false)
		if not storage_error.is_empty():
			return storage_error
	else:
		var storage_error := _validate_current_storage(data)
		if not storage_error.is_empty():
			return storage_error
	var transactions := data["applied_transactions"] as Dictionary
	if result_snapshot:
		if not transactions.is_empty():
			return _field_error("applied_transactions", "result snapshot transaction journal must be empty")
		return ""
	for transaction_id: Variant in transactions:
		if typeof(transaction_id) != TYPE_STRING or (transaction_id as String).strip_edges().is_empty():
			return _field_error("applied_transactions", "transaction ids must be non-empty strings")
		var record: Variant = transactions[transaction_id]
		if not record is Dictionary:
			return _field_error("applied_transactions", "transaction records must be dictionaries")
		var record_error := _validate_transaction_record(record as Dictionary, expected_schema)
		if not record_error.is_empty():
			return _field_error("applied_transactions", "transaction=%s %s" % [transaction_id, record_error])
	return ""

static func _validate_current_storage(data: Dictionary) -> String:
	return _validate_storage(data, true)

static func _validate_storage(data: Dictionary, include_leader_loadout: bool) -> String:
	if not data["item_records"] is Dictionary:
		return _field_error("item_records", "must be a dictionary")
	var stash_documents := data["stash_tabs"] as Array
	if stash_documents.size() > ProfileState.MAX_STASH_TABS:
		return _field_error("stash_tabs", "count exceeds maximum %d" % ProfileState.MAX_STASH_TABS)
	for index: int in stash_documents.size():
		var document: Variant = stash_documents[index]
		if not document is Dictionary:
			return _field_error("stash_tabs", "entry %d must be a dictionary" % index)
		if typeof((document as Dictionary).get("container_kind")) != TYPE_STRING or String((document as Dictionary).get("container_kind")) != String(ItemSlotContainer.PROFILE_STASH_TAB):
			return _field_error("stash_tabs", "entry %d must be a profile_stash_tab container" % index)
	var container_documents: Array = []
	if include_leader_loadout:
		if not data["leader_loadout"] is Dictionary:
			return _field_error("leader_loadout", "must be a dictionary")
		var leader_document := data["leader_loadout"] as Dictionary
		if typeof(leader_document.get("container_id")) != TYPE_STRING or String(leader_document.get("container_id")) != "leader-loadout":
			return _field_error("leader_loadout", "container_id must equal leader-loadout")
		if typeof(leader_document.get("container_kind")) != TYPE_STRING or String(leader_document.get("container_kind")) != String(ItemSlotContainer.PROFILE_LEADER_EQUIPMENT):
			return _field_error("leader_loadout", "container_kind must equal profile_leader_equipment")
		container_documents.append(leader_document.duplicate(true))
	container_documents.append_array(stash_documents.duplicate(true))
	var ownership_document := {
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": data["profile_id"],
		"registry": (data["item_records"] as Dictionary).duplicate(true),
		"containers": container_documents,
	}
	var decoded := ItemOwnershipState.decode(ownership_document, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not decoded.ok():
		var field := "item_records"
		if include_leader_loadout and decoded.error.contains("containers[0]"):
			field = "leader_loadout"
		elif decoded.error.contains("containers"):
			field = "stash_tabs"
		return _field_error(field, decoded.error)
	return ""

static func _validate_transaction_record(record: Dictionary, expected_schema: int) -> String:
	var expected := ["operation", "fingerprint", "committed_at_unix", "result_profile"]
	if record.size() != expected.size() or not expected.all(func(field: String) -> bool: return record.has(field)):
		return "record fields are invalid"
	if typeof(record["operation"]) != TYPE_STRING or (record["operation"] as String).strip_edges().is_empty():
		return "operation must be a non-empty string"
	if typeof(record["fingerprint"]) != TYPE_STRING or not _is_lower_hex(record["fingerprint"] as String, 64):
		return "request fingerprint must be 64 lowercase hex characters"
	if not _is_json_int(record["committed_at_unix"], 0, JSON_SAFE_INTEGER_MAX):
		return "committed timestamp must be a non-negative integer"
	if not record["result_profile"] is Dictionary:
		return "result profile must be a dictionary"
	var snapshot_error := _validate_document(record["result_profile"] as Dictionary, expected_schema, true)
	if not snapshot_error.is_empty():
		return "result profile is invalid: %s" % snapshot_error
	if int((record["result_profile"] as Dictionary)["updated_at_unix"]) != int(record["committed_at_unix"]):
		return "result profile timestamp does not match committed timestamp"
	return ""

static func _profile_from_current_document(data: Dictionary) -> ProfileState:
	var profile := ProfileState.new()
	profile.schema_version = int(data["schema_version"])
	profile.profile_id = data["profile_id"] as String
	profile.display_name = data["display_name"] as String
	profile.created_at_unix = int(data["created_at_unix"])
	profile.updated_at_unix = int(data["updated_at_unix"])
	profile.prologue_state = int(data["prologue_state"]) as ProfileState.PrologueState
	profile.last_safe_checkpoint = (data["last_safe_checkpoint"] as Dictionary).duplicate(true)
	profile.gold = int(data["gold"])
	profile.passive_points_available = int(data["passive_points_available"])
	profile.passive_points_lifetime_earned = int(data["passive_points_lifetime_earned"])
	profile.milestones = _strings(data["milestones"] as Array)
	profile.permanent_feature_unlocks = _strings(data["permanent_feature_unlocks"] as Array)
	profile.discovered_buildings = _strings(data["discovered_buildings"] as Array)
	profile.discovered_trees = _strings(data["discovered_trees"] as Array)
	profile.tree_allocations = (data["tree_allocations"] as Dictionary).duplicate(true)
	profile.tree_visibility_progress = _integer_dictionary(data["tree_visibility_progress"] as Dictionary)
	profile.owned_characters = (data["owned_characters"] as Dictionary).duplicate(true)
	profile.squad_capacity = int(data["squad_capacity"])
	profile.inventory_columns = int(data["inventory_columns"])
	var container_documents: Array = [(data["leader_loadout"] as Dictionary).duplicate(true)]
	container_documents.append_array((data["stash_tabs"] as Array).duplicate(true))
	var ownership_document := {
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": data["profile_id"],
		"registry": (data["item_records"] as Dictionary).duplicate(true),
		"containers": container_documents,
	}
	var ownership := ItemOwnershipState.decode(ownership_document, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).state
	var registry := ownership.registry()
	profile.item_records = {"schema_version": registry.schema_version, "items": []}
	for item_document: Dictionary in (data["item_records"] as Dictionary)["items"] as Array:
		(profile.item_records["items"] as Array).append(
			registry.item(item_document["instance_id"] as String).to_dictionary()
		)
	profile.leader_loadout = ownership.container(&"leader-loadout").to_dictionary()
	profile.leader_loadout_class_id = data["leader_loadout_class_id"] as String
	profile.stash_tabs = []
	for stash_document: Variant in data["stash_tabs"] as Array:
		var container := ownership.container(StringName(String((stash_document as Dictionary)["container_id"])))
		profile.stash_tabs.append(container.to_dictionary())
	profile.next_item_sequence = int(data["next_item_sequence"])
	profile.extraction_capacity = int(data["extraction_capacity"])
	profile.run_history = _dictionaries(data["run_history"] as Array)
	profile.resumable_run = (data["resumable_run"] as Dictionary).duplicate(true)
	profile.applied_transactions = (data["applied_transactions"] as Dictionary).duplicate(true)
	return profile

static func _exact_fields(data: Dictionary, expected: Array[String]) -> String:
	var missing: Array[String] = []
	for field: String in expected:
		if not data.has(field):
			missing.append(field)
	var unexpected: Array[String] = []
	for key: Variant in data:
		if typeof(key) != TYPE_STRING or String(key) not in expected:
			unexpected.append(String(key))
	unexpected.sort()
	if missing.is_empty() and unexpected.is_empty():
		return ""
	var reasons: Array[String] = []
	if not missing.is_empty():
		reasons.append("missing fields %s" % ",".join(missing))
	if not unexpected.is_empty():
		reasons.append("unexpected fields %s" % ",".join(unexpected))
	return _field_error("document", "; ".join(reasons))

static func _integer_field(data: Dictionary, field: String, minimum: int, maximum: int) -> String:
	if not data.has(field) or not _is_json_int(data[field], minimum, maximum):
		return _field_error(field, "must be an integral JSON number in range %d..%d" % [minimum, maximum])
	return ""

static func _is_json_int(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= minimum and int(value) <= maximum
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	if not is_finite(number) or number != floor(number) or number < float(minimum):
		return false
	return number <= float(maximum)

static func _is_json_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return int(value) >= -JSON_SAFE_INTEGER_MAX and int(value) <= JSON_SAFE_INTEGER_MAX
		TYPE_FLOAT:
			var number := float(value)
			if not is_finite(number):
				return false
			return number != floor(number) or (number >= -float(JSON_SAFE_INTEGER_MAX) and number <= float(JSON_SAFE_INTEGER_MAX))
		TYPE_ARRAY:
			return (value as Array).all(func(item: Variant) -> bool: return _is_json_value(item))
		TYPE_DICTIONARY:
			for key: Variant in value as Dictionary:
				if typeof(key) != TYPE_STRING or not _is_json_value((value as Dictionary)[key]):
					return false
			return true
		_:
			return false

static func _is_lower_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true

static func _schema_error(value: Variant) -> String:
	return "PROFILE_SCHEMA_ERROR field=schema_version version=%s supported=%d reason=unsupported schema" % [value, ProfileState.SCHEMA_VERSION]

static func _field_error(field: String, reason: String) -> String:
	return "PROFILE_VALIDATION_ERROR field=%s reason=%s" % [field, reason]

static func _strings(value: Array) -> Array[String]:
	var result: Array[String] = []
	for item: Variant in value:
		result.append(item as String)
	return result

static func _dictionaries(value: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in value:
		result.append((item as Dictionary).duplicate(true))
	return result

static func _integer_dictionary(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in value:
		result[String(key)] = int(value[key])
	return result
