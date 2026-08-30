class_name ProfileMigrator
extends RefCounted

const PlayerColorPalette := preload("res://scripts/profile/player_color_palette.gd")

const EMPTY_ITEM_REGISTRY := {"schema_version": 1, "items": []}

static func migrate_document(document: Dictionary) -> ProfileMigrationResult:
	var result := ProfileMigrationResult.new()
	result.source_schema_version = _source_schema_version(document)
	result.error = ProfileCodec.validate_loadable_document(document)
	if not result.error.is_empty():
		return result
	if result.source_schema_version == ProfileState.SCHEMA_VERSION:
		result.profile = ProfileCodec._profile_from_current_document(document)
		return result
	var candidate := document.duplicate(true)
	if result.source_schema_version == ProfileCodec.LEGACY_SCHEMA_VERSION:
		result.error = _migrate_schema_one_document(candidate)
		if not result.error.is_empty():
			return result
		result.error = ProfileCodec.validate_schema_two_document(candidate)
		if not result.error.is_empty():
			return result
	if result.source_schema_version <= ProfileCodec.SCHEMA_TWO_VERSION:
		result.error = _migrate_schema_two_document(candidate)
		if not result.error.is_empty():
			return result
		result.error = ProfileCodec.validate_schema_three_document(candidate)
		if not result.error.is_empty():
			return result
	if result.source_schema_version <= ProfileCodec.SCHEMA_THREE_VERSION:
		result.error = _migrate_schema_three_document(candidate)
		if not result.error.is_empty():
			return result
		result.error = ProfileCodec.validate_schema_four_document(candidate)
		if not result.error.is_empty():
			return result
	if result.source_schema_version <= ProfileCodec.SCHEMA_FOUR_VERSION:
		result.error = _migrate_schema_four_document(candidate)
		if not result.error.is_empty():
			return result
		result.error = ProfileCodec.validate_schema_five_document(candidate)
		if not result.error.is_empty():
			return result
	if result.source_schema_version <= ProfileCodec.SCHEMA_FIVE_VERSION:
		result.error = _migrate_schema_five_document(candidate)
		if not result.error.is_empty():
			return result
	result.error = ProfileCodec.validate_current_document(candidate)
	if not result.error.is_empty():
		return result
	var profile := ProfileCodec._profile_from_current_document(candidate)
	var round_trip_document := profile.to_dictionary() if profile != null else {}
	result.error = ProfileCodec.validate_current_document(round_trip_document)
	if not result.error.is_empty():
		return result
	var round_trip := ProfileCodec._profile_from_current_document(round_trip_document)
	if round_trip == null or round_trip.to_dictionary() != round_trip_document:
		result.error = "PARTY_FORGE_PROFILE_MIGRATION_ERROR field=document reason=current round trip differs"
		return result
	result.profile = round_trip
	result.migrated = true
	return result

static func _migrate_schema_one_document(document: Dictionary) -> String:
	if not (document["stash_tabs"] as Array).is_empty():
		return "PARTY_FORGE_PROFILE_MIGRATION_ERROR field=stash_tabs reason=unsupported legacy storage"
	var transactions := document["applied_transactions"] as Dictionary
	for transaction_id: Variant in transactions:
		var record := transactions[transaction_id] as Dictionary
		var snapshot := (record["result_profile"] as Dictionary).duplicate(true)
		var snapshot_error := _migrate_schema_one_document(snapshot)
		if not snapshot_error.is_empty():
			return snapshot_error
		snapshot_error = ProfileCodec.validate_schema_two_document(snapshot)
		if not snapshot_error.is_empty():
			return snapshot_error
		record["result_profile"] = snapshot
		record["committed_at_unix"] = int(record["committed_at_unix"])
	document["schema_version"] = ProfileCodec.SCHEMA_TWO_VERSION
	document["item_records"] = EMPTY_ITEM_REGISTRY.duplicate(true)
	document["next_item_sequence"] = 0
	document["resumable_run"] = {}
	return ""

static func _migrate_schema_two_document(document: Dictionary) -> String:
	var transactions := document["applied_transactions"] as Dictionary
	for transaction_id: Variant in transactions:
		var record := transactions[transaction_id] as Dictionary
		var snapshot := (record["result_profile"] as Dictionary).duplicate(true)
		var snapshot_error := _migrate_schema_two_document(snapshot)
		if not snapshot_error.is_empty():
			return snapshot_error
		snapshot_error = ProfileCodec.validate_schema_three_document(snapshot)
		if not snapshot_error.is_empty():
			return snapshot_error
		record["result_profile"] = ProfileCodec._canonical_schema_three_document(snapshot)
		record["committed_at_unix"] = int(record["committed_at_unix"])
	document["schema_version"] = ProfileCodec.SCHEMA_THREE_VERSION
	document["leader_loadout"] = ProfileState._empty_leader_loadout(String(document["profile_id"]))
	document["leader_loadout_class_id"] = ""
	document["resumable_run"] = {}
	return ""

static func _migrate_schema_three_document(document: Dictionary) -> String:
	var transactions := document["applied_transactions"] as Dictionary
	for transaction_id: Variant in transactions:
		var record := transactions[transaction_id] as Dictionary
		var snapshot := (record["result_profile"] as Dictionary).duplicate(true)
		var snapshot_error := _migrate_schema_three_document(snapshot)
		if not snapshot_error.is_empty():
			return snapshot_error
		snapshot_error = ProfileCodec.validate_schema_four_document(snapshot)
		if not snapshot_error.is_empty():
			return snapshot_error
		var canonical := ProfileCodec._profile_from_current_document(snapshot).to_dictionary()
		canonical.erase("terminal_resolution")
		canonical.erase("terminal_recovery_overflow")
		record["result_profile"] = canonical
		record["committed_at_unix"] = int(record["committed_at_unix"])
	document["schema_version"] = ProfileCodec.SCHEMA_FOUR_VERSION
	document["preferred_player_color_id"] = String(PlayerColorPalette.DEFAULT_ID)
	document["resumable_run"] = {}
	return ""

static func _migrate_schema_four_document(document: Dictionary) -> String:
	for transaction_id: Variant in document["applied_transactions"] as Dictionary:
		var record := (document["applied_transactions"] as Dictionary)[transaction_id] as Dictionary
		var snapshot := (record["result_profile"] as Dictionary).duplicate(true)
		var snapshot_error := _migrate_schema_four_document(snapshot)
		if not snapshot_error.is_empty():
			return snapshot_error
		record["result_profile"] = snapshot
	document["schema_version"] = ProfileCodec.SCHEMA_FIVE_VERSION
	var recovery := document["resumable_run"] as Dictionary
	if not recovery.is_empty():
		recovery["selected_leader_class_id"] = ""
	return ""

static func _migrate_schema_five_document(document: Dictionary) -> String:
	for transaction_id: Variant in document["applied_transactions"] as Dictionary:
		var record := (document["applied_transactions"] as Dictionary)[transaction_id] as Dictionary
		var snapshot := (record["result_profile"] as Dictionary).duplicate(true)
		var snapshot_error := _migrate_schema_five_document(snapshot)
		if not snapshot_error.is_empty():
			return snapshot_error
		record["result_profile"] = snapshot
	document["schema_version"] = ProfileState.SCHEMA_VERSION
	document["terminal_resolution"] = {}
	document["terminal_recovery_overflow"] = ProfileState._empty_terminal_recovery_overflow(String(document["profile_id"]))
	return ""

static func _source_schema_version(document: Dictionary) -> int:
	var value: Variant = document.get("schema_version")
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value)):
		return int(value)
	return 0
