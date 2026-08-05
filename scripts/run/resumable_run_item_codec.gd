class_name ResumableRunItemCodec
extends RefCounted

const FIELDS: Array[String] = ["item_state", "leader_member_id", "run_id", "run_player_id", "run_seed"]

static func encode(bootstrap: RunItemBootstrap) -> Dictionary:
	if bootstrap == null or bootstrap.item_state() == null:
		return {}
	return {
		"item_state": bootstrap.item_state().to_dictionary(),
		"leader_member_id": bootstrap.leader_member_id,
		"run_id": String(bootstrap.run_id),
		"run_player_id": String(bootstrap.run_player_id),
		"run_seed": bootstrap.run_seed,
	}

static func decode(
	document: Variant,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> RunItemBootstrap:
	if not validate_document(document, equipment, foundation).is_empty():
		return null
	var data := document as Dictionary
	var decoded_state := ItemOwnershipState.decode(data["item_state"], equipment, foundation)
	return RunItemBootstrap.create(
		StringName(data["run_id"] as String),
		int(data["run_seed"]),
		StringName(data["run_player_id"] as String),
		int(data["leader_member_id"]),
		decoded_state.state,
	)

static func validate_document(
	document: Variant,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> String:
	if not document is Dictionary:
		return _error("document", "must be a dictionary")
	var data := document as Dictionary
	var fields_error := ItemRegistry._exact_fields(data, FIELDS, "resumable_run")
	if not fields_error.is_empty():
		return fields_error.replace("PARTY_FORGE_ITEM_REGISTRY_ERROR", "PARTY_FORGE_RESUMABLE_RUN_ERROR")
	for field: String in ["run_id", "run_player_id"]:
		if typeof(data[field]) != TYPE_STRING or String(data[field]).strip_edges().is_empty():
			return _error(field, "must be a non-empty string")
	if not ItemInstanceCodec._is_json_int(data["run_seed"], 1, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
		return _error("run_seed", "must be a positive JSON-safe integer")
	if not ItemInstanceCodec._is_json_int(data["leader_member_id"], 1, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
		return _error("leader_member_id", "must be a positive JSON-safe integer")
	var decoded_state := ItemOwnershipState.decode(data["item_state"], equipment, foundation)
	if not decoded_state.ok():
		return _error("item_state", decoded_state.error)
	if decoded_state.state.owner_id != String(data["run_player_id"]):
		return _error("item_state.owner_id", "must match run_player_id")
	return ""

static func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_RESUMABLE_RUN_ERROR field=%s reason=%s" % [field, reason]
