extends RefCounted

const MISSING_MANIFEST_GATE := 'return "set=%s missing manifest" % set_id'
const MISSING_FOLDER_MAPPING_GATE := 'return "set=%s missing folder mapping" % set_id'
const ALL_REGISTERED_SETS_RETURN := 'if set_id == &"all":\n\t\t\t\t\treturn registered_sets.duplicate()'
const MISSING_MANIFEST_LABEL := "validator rejects folder mapping missing from manifest"
const MISSING_FOLDER_MAPPING_LABEL := "validator rejects manifest set missing from folder mapping"
const ALL_REGISTERED_SETS_LABEL := "all returns the validated registered set list"

func run() -> Array[String]:
	var failures: Array[String] = []
	var source := FileAccess.get_file_as_string("res://tools/validate_equipment_icons.gd")
	_assert_source_contract(source, failures)
	_assert_missing_fragment_is_rejected(source, MISSING_MANIFEST_GATE, MISSING_MANIFEST_LABEL, failures)
	_assert_missing_fragment_is_rejected(source, MISSING_FOLDER_MAPPING_GATE, MISSING_FOLDER_MAPPING_LABEL, failures)
	_assert_missing_fragment_is_rejected(source, ALL_REGISTERED_SETS_RETURN, ALL_REGISTERED_SETS_LABEL, failures)
	return failures

func _assert_source_contract(source: String, failures: Array[String]) -> void:
	TestAssertions.truthy("core_equipment_catalog.tres" in source, "validator uses canonical catalog", failures)
	TestAssertions.truthy("family_for" in source, "validator checks declared visual family", failures)
	TestAssertions.truthy("HashingContext.HASH_SHA256" in source, "validator rejects duplicate pixels", failures)
	TestAssertions.truthy("unique_master" in source and "unique_runtime" in source, "validator reports uniqueness totals", failures)
	TestAssertions.truthy("SET_FOLDERS.keys()" in source and "registered_sets.sort()" in source, "all derives deterministically from registered sets", failures)
	TestAssertions.truthy("var registry_error := _registry_error()" in source and "registries disagree %s" in source, "validator executes the registry agreement gate", failures)
	TestAssertions.truthy(MISSING_MANIFEST_GATE in source, MISSING_MANIFEST_LABEL, failures)
	TestAssertions.truthy(MISSING_FOLDER_MAPPING_GATE in source, MISSING_FOLDER_MAPPING_LABEL, failures)
	TestAssertions.truthy(ALL_REGISTERED_SETS_RETURN in source, ALL_REGISTERED_SETS_LABEL, failures)
	TestAssertions.truthy('return [&"fighter", &"paladin"' not in source, "all does not hardcode the current set list", failures)

func _assert_missing_fragment_is_rejected(source: String, fragment: String, expected_label: String, failures: Array[String]) -> void:
	var mutation_failures: Array[String] = []
	_assert_source_contract(source.replace(fragment, ""), mutation_failures)
	TestAssertions.equal(mutation_failures.size(), 1, "%s mutation has one contract failure" % expected_label, failures)
	TestAssertions.truthy("%s: expected true" % expected_label in mutation_failures, "%s mutation is rejected" % expected_label, failures)
