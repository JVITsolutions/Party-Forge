class_name ProfileCodec
extends RefCounted

static func encode(profile: ProfileState) -> String:
	return JSON.stringify(profile.to_dictionary(), "\t", false)

static func decode(text: String) -> ProfileLoadResult:
	var result := ProfileLoadResult.new()
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK or not parser.data is Dictionary:
		result.error = "PROFILE_DECODE_ERROR line=%d reason=%s" % [parser.get_error_line(), parser.get_error_message()]
		return result
	var data := parser.data as Dictionary
	var schema_value: Variant = data.get("schema_version")
	var schema_matches := false
	if typeof(schema_value) in [TYPE_INT, TYPE_FLOAT]:
		var schema_number := float(schema_value)
		schema_matches = is_finite(schema_number) and schema_number == floor(schema_number) and int(schema_number) == ProfileState.SCHEMA_VERSION
	if not schema_matches:
		result.error = "PROFILE_SCHEMA_ERROR version=%s supported=%d reason=unsupported schema" % [schema_value if schema_value != null else "missing", ProfileState.SCHEMA_VERSION]
		return result
	var profile := ProfileState.new()
	profile.schema_version = int(schema_value)
	profile.profile_id = str(data.get("profile_id", ""))
	profile.display_name = str(data.get("display_name", ""))
	profile.created_at_unix = int(data.get("created_at_unix", 0))
	profile.updated_at_unix = int(data.get("updated_at_unix", profile.created_at_unix))
	profile.prologue_state = int(data.get("prologue_state", ProfileState.PrologueState.NOT_STARTED))
	profile.last_safe_checkpoint = _dictionary(data.get("last_safe_checkpoint", {}))
	profile.gold = int(data.get("gold", 0))
	profile.passive_points_available = int(data.get("passive_points_available", 0))
	profile.passive_points_lifetime_earned = int(data.get("passive_points_lifetime_earned", 0))
	profile.milestones = _strings(data.get("milestones", []))
	profile.permanent_feature_unlocks = _strings(data.get("permanent_feature_unlocks", []))
	profile.discovered_buildings = _strings(data.get("discovered_buildings", []))
	profile.discovered_trees = _strings(data.get("discovered_trees", []))
	profile.tree_allocations = _dictionary(data.get("tree_allocations", {}))
	profile.tree_visibility_progress = _dictionary(data.get("tree_visibility_progress", {}))
	profile.owned_characters = _dictionary(data.get("owned_characters", {}))
	profile.squad_capacity = int(data.get("squad_capacity", 1))
	profile.inventory_columns = int(data.get("inventory_columns", 0))
	profile.stash_tabs = _dictionaries(data.get("stash_tabs", []))
	profile.extraction_capacity = int(data.get("extraction_capacity", 0))
	profile.run_history = _dictionaries(data.get("run_history", []))
	profile.resumable_run = _dictionary(data.get("resumable_run", {}))
	profile.applied_transactions = _dictionary(data.get("applied_transactions", {}))
	profile.normalize()
	result.error = validate_profile(profile)
	if result.error.is_empty():
		result.profile = profile
	return result

static func validate_profile(profile: ProfileState) -> String:
	if profile == null:
		return "PROFILE_VALIDATION_ERROR reason=profile is null"
	if profile.profile_id.length() < 8 or not profile.profile_id.is_valid_filename():
		return "PROFILE_VALIDATION_ERROR profile=%s reason=invalid profile id" % profile.profile_id
	if profile.display_name.is_empty() or profile.display_name.length() > 32:
		return "PROFILE_VALIDATION_ERROR profile=%s reason=display name must contain 1-32 characters" % profile.profile_id
	if profile.updated_at_unix < profile.created_at_unix:
		return "PROFILE_VALIDATION_ERROR profile=%s reason=updated time predates creation" % profile.profile_id
	return ""

static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

static func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			if typeof(item) == TYPE_STRING:
				result.append(item)
	return result

static func _dictionaries(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result
