class_name EquipmentAssetManifestContract
extends RefCounted

const SCHEMA_VERSION := 1
const ROW_KINDS: Array[String] = ["rig", "body", "equipment"]
const BODY_PRESETS: Array[String] = ["masculine", "feminine"]
const FIT_POLICIES: Array[String] = ["shared", "variant"]
const ATTACHMENT_MODES: Array[String] = ["rigid_socket", "shared_skin"]

const CANONICAL_RIG_ID := "pf_humanoid_v1"
const CANONICAL_REST_QUANTIZATION := "1e-6"
const NAMED_BIND_POLICY := "ordered_named_binds"
const ERROR_PREFIX := "PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR"


func validate_document(document: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var schema_value: Variant = document.get("schema_version")
	if schema_value != SCHEMA_VERSION:
		errors.append("%s field=schema_version value=%s reason=expected %d" % [ERROR_PREFIX, str(schema_value), SCHEMA_VERSION])

	var assets_value: Variant = document.get("assets")
	if not assets_value is Array:
		errors.append("%s field=assets reason=must be an array" % ERROR_PREFIX)
		errors.append("%s field=canonical_rig reason=exactly one canonical rig row required" % ERROR_PREFIX)
		return errors

	var seen_ids := {}
	var canonical_rig_count := 0
	var canonical_rig_row := {}
	var body_coverage_counts := {"masculine": 0, "feminine": 0}
	var assets := assets_value as Array
	for row_index: int in assets.size():
		var row_value: Variant = assets[row_index]
		if not row_value is Dictionary:
			errors.append("%s row=%d reason=must be a dictionary" % [ERROR_PREFIX, row_index])
			continue
		var row := row_value as Dictionary
		var asset_id := _string_value(row.get("asset_id"))
		if asset_id.is_empty():
			errors.append("%s row=%d field=asset_id reason=must be non-empty" % [ERROR_PREFIX, row_index])
		if seen_ids.has(asset_id):
			errors.append("%s row=%d field=asset_id reason=duplicate" % [ERROR_PREFIX, row_index])
		else:
			seen_ids[asset_id] = true

		var kind := _string_value(row.get("kind"))
		if kind not in ROW_KINDS:
			errors.append("%s row=%d field=kind value=%s reason=expected rig, body, or equipment" % [ERROR_PREFIX, row_index, kind])
		if kind == "rig":
			canonical_rig_count += 1
			canonical_rig_row = row
			_validate_canonical_rig(row, row_index, errors)
		elif kind == "body":
			var covered_bodies := _validate_body(row, row_index, errors)
			for body_preset: String in covered_bodies:
				body_coverage_counts[body_preset] = int(body_coverage_counts.get(body_preset, 0)) + 1
		elif kind == "equipment":
			_validate_equipment(row, row_index, errors)

		_validate_runtime_paths(row, row_index, errors)
		_require_non_empty_string(row, "runtime_sha256", row_index, errors)
		_validate_provenance(row, row_index, errors)
		_validate_sha256_fields(row, row_index, "", errors)
		_validate_approval(row, row_index, errors)
	if int(body_coverage_counts["masculine"]) != 1 or int(body_coverage_counts["feminine"]) != 1:
		errors.append("%s field=body_coverage reason=requires exactly one masculine and one feminine body row" % ERROR_PREFIX)

	if canonical_rig_count != 1:
		errors.append("%s field=canonical_rig reason=exactly one canonical rig row required" % ERROR_PREFIX)
	else:
		_validate_shared_skin_signatures(assets, canonical_rig_row, errors)
	return errors


func _validate_body(row: Dictionary, row_index: int, errors: PackedStringArray) -> PackedStringArray:
	var body_coverage := _validate_string_array(row, "body_coverage", row_index, BODY_PRESETS, true, errors)
	if body_coverage.size() != 1:
		errors.append("%s row=%d field=body_coverage reason=body row must cover exactly one body preset" % [ERROR_PREFIX, row_index])
	if _string_value(row.get("canonical_rig_id")) != CANONICAL_RIG_ID:
		errors.append("%s row=%d field=canonical_rig_id value=%s reason=expected %s" % [ERROR_PREFIX, row_index, _string_value(row.get("canonical_rig_id")), CANONICAL_RIG_ID])
	_require_non_empty_string(row, "topology_sha256", row_index, errors)
	_require_non_empty_string(row, "canonical_rest_sha256", row_index, errors)
	var binds_value: Variant = row.get("skin_named_bind_sha256")
	if not binds_value is Dictionary:
		errors.append("%s row=%d field=skin_named_bind_sha256 reason=must map the body preset to its ordered named-bind hash" % [ERROR_PREFIX, row_index])
	else:
		var binds := binds_value as Dictionary
		for body_preset: String in body_coverage:
			if not binds.has(body_preset) or not _is_sha256(_string_value(binds.get(body_preset))):
				errors.append("%s row=%d field=skin_named_bind_sha256.%s reason=required ordered named-bind hash" % [ERROR_PREFIX, row_index, body_preset])
	_validate_asset_metrics(row, row_index, errors)
	return body_coverage


func _validate_canonical_rig(row: Dictionary, row_index: int, errors: PackedStringArray) -> void:
	if _string_value(row.get("asset_id")) != CANONICAL_RIG_ID:
		errors.append("%s row=%d field=asset_id expected=%s reason=canonical rig id mismatch" % [ERROR_PREFIX, row_index, CANONICAL_RIG_ID])
	_require_non_empty_string(row, "topology_sha256", row_index, errors)
	_require_non_empty_string(row, "canonical_rest_sha256", row_index, errors)
	if not row.has("canonical_rest_quantization"):
		errors.append("%s row=%d field=canonical_rest_quantization reason=required" % [ERROR_PREFIX, row_index])
	elif _string_value(row.get("canonical_rest_quantization")) != CANONICAL_REST_QUANTIZATION:
		errors.append("%s row=%d field=canonical_rest_quantization expected=%s reason=canonical rest quantization mismatch" % [ERROR_PREFIX, row_index, CANONICAL_REST_QUANTIZATION])

	var roles_value: Variant = row.get("semantic_roles")
	if not roles_value is Dictionary or (roles_value as Dictionary).is_empty():
		errors.append("%s row=%d field=semantic_roles reason=must be a non-empty mapping" % [ERROR_PREFIX, row_index])
	else:
		var roles := roles_value as Dictionary
		for role_key: Variant in _sorted_keys(roles):
			if _string_value(role_key).is_empty() or _string_value(roles[role_key]).is_empty():
				errors.append("%s row=%d field=semantic_roles.%s reason=role and bind name must be non-empty" % [ERROR_PREFIX, row_index, str(role_key)])

	if not row.has("named_bind_policy"):
		errors.append("%s row=%d field=named_bind_policy reason=required" % [ERROR_PREFIX, row_index])
	elif _string_value(row.get("named_bind_policy")) != NAMED_BIND_POLICY:
		errors.append("%s row=%d field=named_bind_policy value=%s reason=expected %s" % [ERROR_PREFIX, row_index, _string_value(row.get("named_bind_policy")), NAMED_BIND_POLICY])


func _validate_equipment(row: Dictionary, row_index: int, errors: PackedStringArray) -> void:
	_require_non_empty_string(row, "set_id", row_index, errors)
	_validate_string_array(row, "slot_ids", row_index, PackedStringArray(), true, errors)

	var fit_policy := _string_value(row.get("fit_policy"))
	if fit_policy not in FIT_POLICIES:
		errors.append("%s row=%d field=fit_policy value=%s reason=expected shared or variant" % [ERROR_PREFIX, row_index, fit_policy])
	var attachment_mode := _string_value(row.get("attachment_mode"))
	if attachment_mode not in ATTACHMENT_MODES:
		errors.append("%s row=%d field=attachment_mode value=%s reason=expected rigid_socket or shared_skin" % [ERROR_PREFIX, row_index, attachment_mode])

	var body_coverage := _validate_string_array(row, "body_coverage", row_index, BODY_PRESETS, true, errors)
	_validate_asset_metrics(row, row_index, errors)
	for icon_field: String in ["master_icon_path", "runtime_icon_path"]:
		_validate_required_res_path(row, icon_field, row_index, errors)
	for icon_hash_field: String in ["master_icon_sha256", "runtime_icon_sha256"]:
		_require_non_empty_string(row, icon_hash_field, row_index, errors)
	if attachment_mode != "shared_skin":
		return
	if not body_coverage.has("masculine") or not body_coverage.has("feminine"):
		errors.append("%s row=%d field=body_coverage reason=shared_skin requires masculine and feminine" % [ERROR_PREFIX, row_index])
	if _string_value(row.get("canonical_rig_id")) != CANONICAL_RIG_ID:
		errors.append("%s row=%d field=canonical_rig_id value=%s reason=expected %s" % [ERROR_PREFIX, row_index, _string_value(row.get("canonical_rig_id")), CANONICAL_RIG_ID])
	_require_non_empty_string(row, "topology_sha256", row_index, errors)
	_require_non_empty_string(row, "canonical_rest_sha256", row_index, errors)

	var binds_value: Variant = row.get("skin_named_bind_sha256")
	if not binds_value is Dictionary:
		errors.append("%s row=%d field=skin_named_bind_sha256 reason=must map approved Skins to ordered named-bind hashes" % [ERROR_PREFIX, row_index])
		return
	var binds := binds_value as Dictionary
	for body_preset: String in BODY_PRESETS:
		if not binds.has(body_preset) or _string_value(binds.get(body_preset)).is_empty():
			errors.append("%s row=%d field=skin_named_bind_sha256.%s reason=required ordered named-bind hash" % [ERROR_PREFIX, row_index, body_preset])
		elif not _is_sha256(_string_value(binds.get(body_preset))):
			errors.append("%s row=%d field=skin_named_bind_sha256.%s value=%s reason=must be 64 lowercase hexadecimal characters" % [ERROR_PREFIX, row_index, body_preset, _string_value(binds.get(body_preset))])


func _validate_shared_skin_signatures(assets: Array, canonical_rig_row: Dictionary, errors: PackedStringArray) -> void:
	for row_index: int in assets.size():
		var row_value: Variant = assets[row_index]
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		var kind := _string_value(row.get("kind"))
		if kind != "body" and (kind != "equipment" or _string_value(row.get("attachment_mode")) != "shared_skin"):
			continue
		for signature_field: String in ["topology_sha256", "canonical_rest_sha256"]:
			if _string_value(row.get(signature_field)) != _string_value(canonical_rig_row.get(signature_field)):
				errors.append("%s row=%d field=%s reason=does not match canonical rig" % [ERROR_PREFIX, row_index, signature_field])


func _validate_runtime_paths(row: Dictionary, row_index: int, errors: PackedStringArray) -> void:
	if not row.has("runtime_paths"):
		errors.append("%s row=%d field=runtime_paths reason=required" % [ERROR_PREFIX, row_index])
		return
	var paths_value: Variant = row.get("runtime_paths")
	if not paths_value is Dictionary:
		errors.append("%s row=%d field=runtime_paths reason=must be a mapping" % [ERROR_PREFIX, row_index])
		return
	var paths := paths_value as Dictionary
	if paths.is_empty():
		errors.append("%s row=%d field=runtime_paths reason=must be non-empty" % [ERROR_PREFIX, row_index])
	for path_key: Variant in _sorted_keys(paths):
		var field := "runtime_paths.%s" % str(path_key)
		var path := _string_value(paths[path_key])
		if not path.begins_with("res://"):
			errors.append("%s row=%d field=%s value=%s reason=must be a res:// path" % [ERROR_PREFIX, row_index, field, path])
			continue
		var relative := path.trim_prefix("res://")
		var segments := relative.split("/", true)
		if segments.has(".."):
			errors.append("%s row=%d field=%s value=%s reason=path traversal" % [ERROR_PREFIX, row_index, field, path])
		elif relative.is_empty() or "\\" in path or segments.has(".") or segments.has(""):
			errors.append("%s row=%d field=%s value=%s reason=not normalized" % [ERROR_PREFIX, row_index, field, path])


func _validate_provenance(row: Dictionary, row_index: int, errors: PackedStringArray) -> void:
	if not row.has("provenance"):
		errors.append("%s row=%d field=provenance reason=required" % [ERROR_PREFIX, row_index])
		return
	var provenance_value: Variant = row.get("provenance")
	if not provenance_value is Dictionary:
		errors.append("%s row=%d field=provenance reason=must be a mapping" % [ERROR_PREFIX, row_index])
		return
	var provenance := provenance_value as Dictionary
	for required_field: String in ["generator", "workflow", "model_name", "model_version", "license_evidence", "blender_version"]:
		_require_nested_non_empty_string(provenance, required_field, row_index, "provenance", errors)
	if not provenance.has("seed") or not provenance.get("seed") is int:
		errors.append("%s row=%d field=provenance.seed reason=required integer" % [ERROR_PREFIX, row_index])
	var source_hashes := _validate_string_array(provenance, "source_image_sha256", row_index, PackedStringArray(), true, errors, "provenance")
	for source_index: int in source_hashes.size():
		if not _is_sha256(source_hashes[source_index]):
			errors.append("%s row=%d field=provenance.source_image_sha256.%d value=%s reason=must be 64 lowercase hexadecimal characters" % [ERROR_PREFIX, row_index, source_index, source_hashes[source_index]])
	_require_nested_non_empty_string(provenance, "prompt_sha256", row_index, "provenance", errors)
	for id_field: String in ["attempt_id", "revision_id"]:
		var id_value := _string_value(provenance.get(id_field))
		if not _is_immutable_id(id_value):
			errors.append("%s row=%d field=provenance.%s value=%s reason=must be an immutable id" % [ERROR_PREFIX, row_index, id_field, id_value])
	for hash_field: String in ["attempt_sha256", "revision_sha256"]:
		if not provenance.has(hash_field):
			errors.append("%s row=%d field=provenance.%s reason=required immutable hash" % [ERROR_PREFIX, row_index, hash_field])
	_validate_no_absolute_machine_paths(provenance, row_index, "provenance", errors)


func _validate_no_absolute_machine_paths(value: Variant, row_index: int, field: String, errors: PackedStringArray) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key: Variant in _sorted_keys(dictionary):
			_validate_no_absolute_machine_paths(dictionary[key], row_index, "%s.%s" % [field, str(key)], errors)
	elif value is Array:
		var array := value as Array
		for index: int in array.size():
			_validate_no_absolute_machine_paths(array[index], row_index, "%s.%d" % [field, index], errors)
	elif value is String or value is StringName:
		var string_value := str(value)
		if _is_absolute_machine_path(string_value):
			errors.append("%s row=%d field=%s value=%s reason=absolute machine paths are forbidden" % [ERROR_PREFIX, row_index, field, string_value])


func _validate_sha256_fields(value: Variant, row_index: int, field: String, errors: PackedStringArray) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key: Variant in _sorted_keys(dictionary):
			var child_field := str(key) if field.is_empty() else "%s.%s" % [field, str(key)]
			_validate_sha256_fields(dictionary[key], row_index, child_field, errors)
	elif value is Array:
		var array := value as Array
		for index: int in array.size():
			_validate_sha256_fields(array[index], row_index, "%s.%d" % [field, index], errors)
	elif field.ends_with("_sha256") and not _is_sha256(_string_value(value)):
		errors.append("%s row=%d field=%s value=%s reason=must be 64 lowercase hexadecimal characters" % [ERROR_PREFIX, row_index, field, _string_value(value)])


func _validate_approval(row: Dictionary, row_index: int, errors: PackedStringArray) -> void:
	var approval_value: Variant = row.get("approval")
	if not approval_value is Dictionary:
		errors.append("%s row=%d field=approval reason=required mapping" % [ERROR_PREFIX, row_index])
		return
	var approval := approval_value as Dictionary
	if _string_value(approval.get("validation_result")) != "approved":
		errors.append("%s row=%d field=approval.validation_result reason=must be approved" % [ERROR_PREFIX, row_index])
		return
	for field: String in ["reviewer", "reviewed_at_utc", "notes"]:
		if _string_value(approval.get(field)).is_empty():
			errors.append("%s row=%d field=approval.%s reason=required for approved row" % [ERROR_PREFIX, row_index, field])
	var timestamp := _string_value(approval.get("reviewed_at_utc"))
	if not timestamp.is_empty() and not _is_utc_timestamp(timestamp):
		errors.append("%s row=%d field=approval.reviewed_at_utc value=%s reason=must be UTC ISO-8601" % [ERROR_PREFIX, row_index, timestamp])


func _validate_string_array(row: Dictionary, field: String, row_index: int, allowed: PackedStringArray, require_non_empty: bool, errors: PackedStringArray, field_prefix: String = "") -> PackedStringArray:
	var result := PackedStringArray()
	var qualified_field := field if field_prefix.is_empty() else "%s.%s" % [field_prefix, field]
	var value: Variant = row.get(field)
	if not value is Array and not value is PackedStringArray:
		errors.append("%s row=%d field=%s reason=must be an array" % [ERROR_PREFIX, row_index, qualified_field])
		return result
	for entry: Variant in value:
		var string_entry := _string_value(entry)
		if string_entry.is_empty():
			errors.append("%s row=%d field=%s reason=entries must be non-empty" % [ERROR_PREFIX, row_index, qualified_field])
		elif not allowed.is_empty() and string_entry not in allowed:
			errors.append("%s row=%d field=%s value=%s reason=unknown value" % [ERROR_PREFIX, row_index, qualified_field, string_entry])
		elif string_entry in result:
			errors.append("%s row=%d field=%s value=%s reason=duplicate" % [ERROR_PREFIX, row_index, qualified_field, string_entry])
		else:
			result.append(string_entry)
	if require_non_empty and result.is_empty():
		errors.append("%s row=%d field=%s reason=must be non-empty" % [ERROR_PREFIX, row_index, qualified_field])
	return result


func _validate_asset_metrics(row: Dictionary, row_index: int, errors: PackedStringArray) -> void:
	_validate_string_array(row, "hidden_body_region_ids", row_index, PackedStringArray(), false, errors)
	_validate_string_array(row, "texture_set", row_index, PackedStringArray(), true, errors)
	var dimensions: Variant = row.get("dimensions_m")
	if not dimensions is Array or (dimensions as Array).size() != 3:
		errors.append("%s row=%d field=dimensions_m reason=must contain three dimensions" % [ERROR_PREFIX, row_index])
	else:
		for dimension: Variant in dimensions as Array:
			if not (dimension is int or dimension is float) or not is_finite(float(dimension)) or float(dimension) <= 0.0:
				errors.append("%s row=%d field=dimensions_m reason=dimensions must be finite and positive" % [ERROR_PREFIX, row_index])
				break
	for count_field: String in ["triangle_count", "material_count"]:
		var count: Variant = row.get(count_field)
		var minimum := 0 if count_field == "triangle_count" else 1
		if not count is int or int(count) < minimum:
			errors.append("%s row=%d field=%s reason=must be an integer at least %d" % [ERROR_PREFIX, row_index, count_field, minimum])
	for status_field: String in ["uv_status", "tangent_status", "skin_weight_status"]:
		_require_non_empty_string(row, status_field, row_index, errors)


func _validate_required_res_path(row: Dictionary, field: String, row_index: int, errors: PackedStringArray) -> void:
	if not row.has(field):
		errors.append("%s row=%d field=%s reason=required" % [ERROR_PREFIX, row_index, field])
		return
	var path := _string_value(row.get(field))
	if not _is_normalized_res_path(path):
		errors.append("%s row=%d field=%s value=%s reason=must be a normalized res:// path" % [ERROR_PREFIX, row_index, field, path])


func _is_normalized_res_path(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	var relative := path.trim_prefix("res://")
	var segments := relative.split("/", true)
	return not relative.is_empty() and "\\" not in path and not segments.has(".") and not segments.has("..") and not segments.has("")


func _require_nested_non_empty_string(row: Dictionary, field: String, row_index: int, field_prefix: String, errors: PackedStringArray) -> void:
	if not row.has(field):
		errors.append("%s row=%d field=%s.%s reason=required" % [ERROR_PREFIX, row_index, field_prefix, field])
	elif _string_value(row.get(field)).is_empty():
		errors.append("%s row=%d field=%s.%s reason=must be non-empty" % [ERROR_PREFIX, row_index, field_prefix, field])


func _require_non_empty_string(row: Dictionary, field: String, row_index: int, errors: PackedStringArray) -> void:
	if not row.has(field):
		errors.append("%s row=%d field=%s reason=required" % [ERROR_PREFIX, row_index, field])
	elif _string_value(row.get(field)).is_empty():
		errors.append("%s row=%d field=%s reason=must be non-empty" % [ERROR_PREFIX, row_index, field])


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _is_immutable_id(value: String) -> bool:
	if value.is_empty() or _is_absolute_machine_path(value):
		return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			return false
	return value[0] in "abcdefghijklmnopqrstuvwxyz0123456789"


func _is_absolute_machine_path(value: String) -> bool:
	if value.begins_with("/") or value.begins_with("\\\\"):
		return true
	return value.length() >= 3 and value[1] == ":" and value[2] in "/\\"


func _is_utc_timestamp(value: String) -> bool:
	if value.length() != 20 or not value.ends_with("Z"):
		return false
	var has_valid_shape := (
		value[4] == "-" and value[7] == "-" and value[10] == "T"
		and value[13] == ":" and value[16] == ":"
		and _is_ascii_digits(value.substr(0, 4))
		and _is_ascii_digits(value.substr(5, 2))
		and _is_ascii_digits(value.substr(8, 2))
		and _is_ascii_digits(value.substr(11, 2))
		and _is_ascii_digits(value.substr(14, 2))
		and _is_ascii_digits(value.substr(17, 2))
	)
	if not has_valid_shape:
		return false
	var year := int(value.substr(0, 4))
	var month := int(value.substr(5, 2))
	var day := int(value.substr(8, 2))
	var hour := int(value.substr(11, 2))
	var minute := int(value.substr(14, 2))
	var second := int(value.substr(17, 2))
	if year < 1 or month < 1 or month > 12 or hour < 0 or hour > 23 or minute < 0 or minute > 59 or second < 0 or second > 59:
		return false
	var days_in_month := [31, 28 + (1 if _is_leap_year(year) else 0), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return day >= 1 and day <= days_in_month[month - 1]


func _is_leap_year(year: int) -> bool:
	return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)


func _is_ascii_digits(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if character not in "0123456789":
			return false
	return true


func _sorted_keys(dictionary: Dictionary) -> Array:
	var keys := dictionary.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	return keys


func _string_value(value: Variant) -> String:
	return str(value) if value is String or value is StringName else ""
