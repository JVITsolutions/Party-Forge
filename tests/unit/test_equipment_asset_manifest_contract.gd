extends RefCounted

const CONTRACT := preload("res://scripts/presentation/equipment_asset_manifest_contract.gd")
const SHA_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const SHA_B := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const SHA_C := "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"


func run() -> Array[String]:
	var failures: Array[String] = []
	var contract := CONTRACT.new()
	var constants := (CONTRACT as Script).get_script_constant_map()
	TestAssertions.equal(constants.get("SCHEMA_VERSION"), 1, "manifest schema version is one", failures)
	TestAssertions.equal(constants.get("ROW_KINDS"), ["rig", "body", "equipment"], "manifest row kinds are closed", failures)
	TestAssertions.equal(constants.get("BODY_PRESETS"), ["masculine", "feminine"], "manifest body presets are closed", failures)
	TestAssertions.equal(constants.get("FIT_POLICIES"), ["shared", "variant"], "manifest fit policies are closed", failures)
	TestAssertions.equal(constants.get("ATTACHMENT_MODES"), ["rigid_socket", "shared_skin"], "manifest attachment modes are closed", failures)

	var valid := _valid_document()
	TestAssertions.equal(contract.validate_document(valid), PackedStringArray(), "complete in-memory manifest validates", failures)
	_test_identity_and_kind_rules(contract, failures)
	_test_runtime_path_rules(contract, failures)
	_test_provenance_and_hash_rules(contract, failures)
	_test_equipment_rules(contract, failures)
	_test_canonical_rig_rules(contract, failures)
	_test_shared_skin_rules(contract, failures)
	_test_shared_skin_matches_canonical_rig(contract, failures)
	_test_approval_rules(contract, failures)
	_test_deterministic_errors_and_immutability(contract, failures)
	_test_nested_error_ordering(contract, failures)
	return failures


func _test_identity_and_kind_rules(contract: RefCounted, failures: Array[String]) -> void:
	var wrong_schema := _valid_document()
	wrong_schema["schema_version"] = 2
	_assert_error_contains(contract, wrong_schema, "field=schema_version", "wrong schema version rejects", failures)

	var empty_id := _valid_document()
	(empty_id["assets"] as Array)[1]["asset_id"] = ""
	_assert_error_contains(contract, empty_id, "field=asset_id", "empty asset id rejects", failures)

	var duplicate_id := _valid_document()
	(duplicate_id["assets"] as Array)[2]["asset_id"] = "forge_base_masculine"
	_assert_error_contains(contract, duplicate_id, "reason=duplicate", "duplicate asset id rejects", failures)

	var wrong_kind := _valid_document()
	(wrong_kind["assets"] as Array)[1]["kind"] = "costume"
	_assert_error_contains(contract, wrong_kind, "field=kind", "unknown row kind rejects", failures)


func _test_runtime_path_rules(contract: RefCounted, failures: Array[String]) -> void:
	var absolute_path := _valid_document()
	(absolute_path["assets"] as Array)[1]["runtime_paths"] = {"masculine": "F:/exports/body.glb"}
	_assert_error_contains(contract, absolute_path, "field=runtime_paths.masculine", "absolute runtime path rejects", failures)

	var traversal := _valid_document()
	(traversal["assets"] as Array)[1]["runtime_paths"] = {"masculine": "res://models/../body.glb"}
	_assert_error_contains(contract, traversal, "reason=path traversal", "runtime traversal rejects", failures)

	var unnormalized := _valid_document()
	(unnormalized["assets"] as Array)[1]["runtime_paths"] = {"masculine": "res://models\\body.glb"}
	_assert_error_contains(contract, unnormalized, "reason=not normalized", "backslash runtime path rejects", failures)


func _test_provenance_and_hash_rules(contract: RefCounted, failures: Array[String]) -> void:
	var mutable_reference := _valid_document()
	(mutable_reference["assets"] as Array)[1]["provenance"]["attempt_id"] = "F:/attempts/attempt-0001"
	_assert_error_contains(contract, mutable_reference, "field=provenance.attempt_id", "machine-specific attempt reference rejects", failures)

	var absolute_provenance_path := _valid_document()
	(absolute_provenance_path["assets"] as Array)[1]["provenance"]["source_path"] = "C:\\Users\\builder\\body.blend"
	_assert_error_contains(contract, absolute_provenance_path, "field=provenance.source_path", "absolute provenance path rejects", failures)

	var bad_hash := _valid_document()
	(bad_hash["assets"] as Array)[1]["runtime_sha256"] = SHA_A.to_upper()
	_assert_error_contains(contract, bad_hash, "field=runtime_sha256", "uppercase SHA-256 rejects", failures)

	var short_hash := _valid_document()
	(short_hash["assets"] as Array)[1]["provenance"]["revision_sha256"] = "abc123"
	_assert_error_contains(contract, short_hash, "field=provenance.revision_sha256", "short SHA-256 rejects", failures)


func _test_equipment_rules(contract: RefCounted, failures: Array[String]) -> void:
	for field: String in ["set_id", "slot_ids", "fit_policy", "attachment_mode", "body_coverage"]:
		var missing := _valid_document()
		(missing["assets"] as Array)[3].erase(field)
		_assert_error_contains(contract, missing, "field=%s" % field, "equipment requires %s" % field, failures)

	var wrong_fit := _valid_document()
	(wrong_fit["assets"] as Array)[4]["fit_policy"] = "automatic"
	_assert_error_contains(contract, wrong_fit, "field=fit_policy", "unknown fit policy rejects", failures)

	var wrong_attachment := _valid_document()
	(wrong_attachment["assets"] as Array)[4]["attachment_mode"] = "bone_magic"
	_assert_error_contains(contract, wrong_attachment, "field=attachment_mode", "unknown attachment mode rejects", failures)

	var shared_rigid := _valid_document()
	var rigid_row := (shared_rigid["assets"] as Array)[4] as Dictionary
	TestAssertions.equal(rigid_row["runtime_paths"]["masculine"], rigid_row["runtime_paths"]["feminine"], "fixture uses one rigid export for both bodies", failures)
	TestAssertions.equal(contract.validate_document(shared_rigid), PackedStringArray(), "shared rigid equipment may reuse one export", failures)


func _test_canonical_rig_rules(contract: RefCounted, failures: Array[String]) -> void:
	for field: String in ["topology_sha256", "canonical_rest_sha256", "canonical_rest_quantization", "semantic_roles", "named_bind_policy"]:
		var missing := _valid_document()
		(missing["assets"] as Array)[0].erase(field)
		_assert_error_contains(contract, missing, "field=%s" % field, "canonical rig requires %s" % field, failures)

	var wrong_rig_id := _valid_document()
	(wrong_rig_id["assets"] as Array)[0]["asset_id"] = "another_rig"
	_assert_error_contains(contract, wrong_rig_id, "expected=pf_humanoid_v1", "canonical rig id is fixed", failures)

	var wrong_quantization := _valid_document()
	(wrong_quantization["assets"] as Array)[0]["canonical_rest_quantization"] = "1e-5"
	_assert_error_contains(contract, wrong_quantization, "expected=1e-6", "canonical rest quantization is fixed", failures)

	var empty_roles := _valid_document()
	(empty_roles["assets"] as Array)[0]["semantic_roles"] = {}
	_assert_error_contains(contract, empty_roles, "field=semantic_roles", "canonical rig semantic roles cannot be empty", failures)

	var second_rig := _valid_document()
	var extra_rig := ((second_rig["assets"] as Array)[0] as Dictionary).duplicate(true)
	extra_rig["asset_id"] = "another_rig"
	(second_rig["assets"] as Array).append(extra_rig)
	_assert_error_contains(contract, second_rig, "reason=exactly one canonical rig row required", "manifest has one canonical rig", failures)


func _test_shared_skin_rules(contract: RefCounted, failures: Array[String]) -> void:
	var incomplete_coverage := _valid_document()
	(incomplete_coverage["assets"] as Array)[3]["body_coverage"] = ["masculine"]
	_assert_error_contains(contract, incomplete_coverage, "reason=shared_skin requires masculine and feminine", "shared skin covers both bodies", failures)

	for field: String in ["canonical_rig_id", "topology_sha256", "canonical_rest_sha256", "skin_named_bind_sha256"]:
		var missing := _valid_document()
		(missing["assets"] as Array)[3].erase(field)
		_assert_error_contains(contract, missing, "field=%s" % field, "shared skin requires %s" % field, failures)

	var incomplete_binds := _valid_document()
	(incomplete_binds["assets"] as Array)[3]["skin_named_bind_sha256"] = {"masculine": SHA_C}
	_assert_error_contains(contract, incomplete_binds, "field=skin_named_bind_sha256.feminine", "each approved Skin records ordered named-bind hash", failures)

	for body_preset: String in ["masculine", "feminine"]:
		for malformed_hash: String in ["abc123", SHA_A.to_upper()]:
			var malformed_binds := _valid_document()
			(malformed_binds["assets"] as Array)[3]["skin_named_bind_sha256"][body_preset] = malformed_hash
			_assert_error_contains(
				contract,
				malformed_binds,
				"field=skin_named_bind_sha256.%s" % body_preset,
				"%s ordered named-bind hash must be lowercase SHA-256" % body_preset,
				failures,
			)


func _test_shared_skin_matches_canonical_rig(contract: RefCounted, failures: Array[String]) -> void:
	for signature_field: String in ["topology_sha256", "canonical_rest_sha256"]:
		var mismatch := _valid_document()
		var assets := mismatch["assets"] as Array
		var rig_row: Variant = assets.pop_front()
		assets.append(rig_row)
		(assets[2] as Dictionary)[signature_field] = SHA_A
		_assert_error_contains(
			contract,
			mismatch,
			"field=%s reason=does not match canonical rig" % signature_field,
			"shared skin %s matches canonical rig independent of row order" % signature_field,
			failures,
		)


func _test_approval_rules(contract: RefCounted, failures: Array[String]) -> void:
	for field: String in ["reviewer", "reviewed_at_utc", "notes"]:
		var missing := _valid_document()
		(missing["assets"] as Array)[1]["approval"].erase(field)
		_assert_error_contains(contract, missing, "field=approval.%s" % field, "approved row requires %s" % field, failures)

	var local_timestamp := _valid_document()
	(local_timestamp["assets"] as Array)[1]["approval"]["reviewed_at_utc"] = "2026-08-23 12:00:00"
	_assert_error_contains(contract, local_timestamp, "field=approval.reviewed_at_utc", "approval timestamp is UTC ISO-8601", failures)

	for case: Dictionary in [
		{"timestamp": "2026-13-01T00:00:00Z", "label": "invalid month"},
		{"timestamp": "2026-04-31T00:00:00Z", "label": "invalid day"},
		{"timestamp": "2026-01-01T24:00:00Z", "label": "invalid hour"},
		{"timestamp": "2026-01-01T23:60:00Z", "label": "invalid minute"},
		{"timestamp": "2026-01-01T23:59:60Z", "label": "invalid second"},
		{"timestamp": "2026-02-29T12:00:00Z", "label": "non-leap-year day"},
	]:
		var invalid_instant := _valid_document()
		(invalid_instant["assets"] as Array)[1]["approval"]["reviewed_at_utc"] = case["timestamp"]
		_assert_error_contains(contract, invalid_instant, "field=approval.reviewed_at_utc", "%s rejects" % case["label"], failures)

	var leap_day := _valid_document()
	(leap_day["assets"] as Array)[1]["approval"]["reviewed_at_utc"] = "2028-02-29T23:59:59Z"
	TestAssertions.equal(contract.validate_document(leap_day), PackedStringArray(), "real UTC leap-day instant validates", failures)


func _test_deterministic_errors_and_immutability(contract: RefCounted, failures: Array[String]) -> void:
	var invalid := {
		"schema_version": 2,
		"assets": [
			{"asset_id": "", "kind": "costume"},
			{"asset_id": "", "kind": "body"},
		],
	}
	var source_before := var_to_bytes(invalid)
	var expected := PackedStringArray([
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR field=schema_version value=2 reason=expected 1",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=0 field=asset_id reason=must be non-empty",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=0 field=kind value=costume reason=expected rig, body, or equipment",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=asset_id reason=must be non-empty",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=asset_id reason=duplicate",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR field=canonical_rig reason=exactly one canonical rig row required",
	])
	var first: PackedStringArray = contract.validate_document(invalid)
	var second: PackedStringArray = contract.validate_document(invalid)
	TestAssertions.equal(first, expected, "invalid manifest returns every error in deterministic order", failures)
	TestAssertions.equal(second, expected, "repeated validation returns identical errors", failures)
	TestAssertions.equal(var_to_bytes(invalid), source_before, "validation does not mutate source dictionary", failures)


func _test_nested_error_ordering(contract: RefCounted, failures: Array[String]) -> void:
	var invalid := _valid_document()
	var row := (invalid["assets"] as Array)[1] as Dictionary
	row["runtime_paths"] = {
		"zeta": "res://models/../body.glb",
		"alpha": "F:/exports/body.glb",
	}
	row["runtime_sha256"] = "abc123"
	row["provenance"]["attempt_id"] = "F:/attempts/attempt-0001"
	row["provenance"]["attempt_sha256"] = SHA_A.to_upper()
	row["approval"]["reviewer"] = ""
	row["approval"]["reviewed_at_utc"] = "2026-13-01T24:60:60Z"
	row["approval"]["notes"] = ""
	var expected := PackedStringArray([
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=runtime_paths.alpha value=F:/exports/body.glb reason=must be a res:// path",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=runtime_paths.zeta value=res://models/../body.glb reason=path traversal",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=provenance.attempt_id value=F:/attempts/attempt-0001 reason=must be an immutable id",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=provenance.attempt_id value=F:/attempts/attempt-0001 reason=absolute machine paths are forbidden",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=provenance.attempt_sha256 value=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA reason=must be 64 lowercase hexadecimal characters",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=runtime_sha256 value=abc123 reason=must be 64 lowercase hexadecimal characters",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=approval.reviewer reason=required for approved row",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=approval.notes reason=required for approved row",
		"PARTY_FORGE_EQUIPMENT_MANIFEST_ERROR row=1 field=approval.reviewed_at_utc value=2026-13-01T24:60:60Z reason=must be UTC ISO-8601",
	])
	var source_before := var_to_bytes(invalid)
	TestAssertions.equal(contract.validate_document(invalid), expected, "nested manifest errors have exact deterministic order", failures)
	TestAssertions.equal(var_to_bytes(invalid), source_before, "nested multi-error validation leaves source immutable", failures)


func _assert_error_contains(contract: RefCounted, document: Dictionary, fragment: String, label: String, failures: Array[String]) -> void:
	var source_before := var_to_bytes(document)
	var errors: PackedStringArray = contract.validate_document(document)
	var found := false
	for error: String in errors:
		if fragment in error:
			found = true
			break
	TestAssertions.truthy(found, "%s: %s" % [label, errors], failures)
	TestAssertions.equal(var_to_bytes(document), source_before, "%s leaves source immutable" % label, failures)


func _valid_document() -> Dictionary:
	return {
		"schema_version": 1,
		"assets": [
			_base_row("pf_humanoid_v1", "rig", {"rig": "res://models/rigs/pf_humanoid_v1.glb"}, SHA_A).merged({
				"topology_sha256": SHA_B,
				"canonical_rest_sha256": SHA_C,
				"canonical_rest_quantization": "1e-6",
				"semantic_roles": {"hand_l": "Hand.L", "hand_r": "Hand.R"},
				"named_bind_policy": "ordered_named_binds",
			}, true),
			_base_row("forge_base_masculine", "body", {"masculine": "res://models/bodies/forge_base_masculine.glb"}, SHA_B),
			_base_row("forge_base_feminine", "body", {"feminine": "res://models/bodies/forge_base_feminine.glb"}, SHA_C),
			_base_row("sunweld_plate", "equipment", {
				"masculine": "res://models/equipment/sunweld_plate_masculine.glb",
				"feminine": "res://models/equipment/sunweld_plate_feminine.glb",
			}, SHA_A).merged({
				"set_id": "sunweld_bastion",
				"slot_ids": ["body_armour"],
				"fit_policy": "variant",
				"attachment_mode": "shared_skin",
				"body_coverage": ["masculine", "feminine"],
				"canonical_rig_id": "pf_humanoid_v1",
				"topology_sha256": SHA_B,
				"canonical_rest_sha256": SHA_C,
				"skin_named_bind_sha256": {"masculine": SHA_A, "feminine": SHA_B},
			}, true),
			_base_row("sunweld_crown", "equipment", {
				"masculine": "res://models/equipment/sunweld_crown.glb",
				"feminine": "res://models/equipment/sunweld_crown.glb",
			}, SHA_B).merged({
				"set_id": "sunweld_bastion",
				"slot_ids": ["helmet"],
				"fit_policy": "shared",
				"attachment_mode": "rigid_socket",
				"body_coverage": ["masculine", "feminine"],
			}, true),
		],
	}


func _base_row(asset_id: String, kind: String, runtime_paths: Dictionary, runtime_sha256: String) -> Dictionary:
	return {
		"asset_id": asset_id,
		"kind": kind,
		"runtime_paths": runtime_paths,
		"runtime_sha256": runtime_sha256,
		"provenance": {
			"attempt_id": "attempt-0001",
			"attempt_sha256": SHA_A,
			"revision_id": "revision-0001",
			"revision_sha256": SHA_B,
		},
		"approval": {
			"validation_result": "approved",
			"reviewer": "reviewer@example.invalid",
			"reviewed_at_utc": "2026-08-23T12:00:00Z",
			"notes": "Fixture approval only.",
		},
	}
