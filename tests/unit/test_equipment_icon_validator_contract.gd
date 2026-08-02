extends RefCounted

const MISSING_MANIFEST_CONDITION := "if not ClassEquipmentRows.SET_ITEM_IDS.has(set_id):"
const MISSING_FOLDER_MAPPING_CONDITION := "if not SET_FOLDERS.has(set_id):"
const MISSING_MANIFEST_MESSAGE := 'return "set=%s missing manifest" % set_id'
const MISSING_FOLDER_MAPPING_MESSAGE := 'return "set=%s missing folder mapping" % set_id'
const MISSING_MANIFEST_BRANCH := MISSING_MANIFEST_CONDITION + "\n" + MISSING_MANIFEST_MESSAGE
const MISSING_FOLDER_MAPPING_BRANCH := MISSING_FOLDER_MAPPING_CONDITION + "\n" + MISSING_FOLDER_MAPPING_MESSAGE
const ALL_REGISTERED_SETS_BRANCH := 'if set_id == &"all":\nreturn registered_sets.duplicate()'
const MISSING_MANIFEST_LABEL := "validator rejects folder mapping missing from manifest"
const MISSING_FOLDER_MAPPING_LABEL := "validator rejects manifest set missing from folder mapping"
const ALL_REGISTERED_SETS_LABEL := "all returns the validated registered set list"

func run() -> Array[String]:
	var failures: Array[String] = []
	var source := FileAccess.get_file_as_string("res://tools/validate_equipment_icons.gd")
	_assert_source_contract(source, failures)
	_assert_single_branch_mutation_is_rejected(source.replace(MISSING_MANIFEST_CONDITION, "if ClassEquipmentRows.SET_ITEM_IDS.has(set_id):"), MISSING_MANIFEST_LABEL, "inverted missing-manifest condition", failures)
	_assert_single_branch_mutation_is_rejected(source.replace(MISSING_FOLDER_MAPPING_CONDITION, "if SET_FOLDERS.has(set_id):"), MISSING_FOLDER_MAPPING_LABEL, "inverted missing-folder condition", failures)
	_assert_both_branch_mutations_are_rejected(_swap_fragments(source, MISSING_MANIFEST_CONDITION, MISSING_FOLDER_MAPPING_CONDITION), "swapped registry conditions", failures)
	_assert_both_branch_mutations_are_rejected(_swap_fragments(source, MISSING_MANIFEST_MESSAGE, MISSING_FOLDER_MAPPING_MESSAGE), "swapped registry messages", failures)
	return failures

func _assert_source_contract(source: String, failures: Array[String]) -> void:
	source = _normalized_source(source)
	TestAssertions.truthy("core_equipment_catalog.tres" in source, "validator uses canonical catalog", failures)
	TestAssertions.truthy("family_for" in source, "validator checks declared visual family", failures)
	TestAssertions.truthy("HashingContext.HASH_SHA256" in source, "validator rejects duplicate pixels", failures)
	TestAssertions.truthy("unique_master" in source and "unique_runtime" in source, "validator reports uniqueness totals", failures)
	TestAssertions.truthy("SET_FOLDERS.keys()" in source and "registered_sets.sort()" in source, "all derives deterministically from registered sets", failures)
	TestAssertions.truthy("var registry_error := _registry_error()" in source and "registries disagree %s" in source, "validator executes the registry agreement gate", failures)
	TestAssertions.truthy(MISSING_MANIFEST_BRANCH in source, MISSING_MANIFEST_LABEL, failures)
	TestAssertions.truthy(MISSING_FOLDER_MAPPING_BRANCH in source, MISSING_FOLDER_MAPPING_LABEL, failures)
	TestAssertions.truthy(ALL_REGISTERED_SETS_BRANCH in source, ALL_REGISTERED_SETS_LABEL, failures)
	TestAssertions.truthy('return [&"fighter", &"paladin"' not in source, "all does not hardcode the current set list", failures)

func _assert_single_branch_mutation_is_rejected(mutated_source: String, expected_label: String, mutation_label: String, failures: Array[String]) -> void:
	var mutation_failures: Array[String] = []
	_assert_source_contract(mutated_source, mutation_failures)
	TestAssertions.equal(mutation_failures.size(), 1, "%s has one contract failure" % mutation_label, failures)
	TestAssertions.truthy("%s: expected true" % expected_label in mutation_failures, "%s is rejected" % mutation_label, failures)

func _assert_both_branch_mutations_are_rejected(mutated_source: String, mutation_label: String, failures: Array[String]) -> void:
	var mutation_failures: Array[String] = []
	_assert_source_contract(mutated_source, mutation_failures)
	TestAssertions.equal(mutation_failures.size(), 2, "%s has two contract failures" % mutation_label, failures)
	TestAssertions.truthy("%s: expected true" % MISSING_MANIFEST_LABEL in mutation_failures, "%s rejects missing-manifest branch" % mutation_label, failures)
	TestAssertions.truthy("%s: expected true" % MISSING_FOLDER_MAPPING_LABEL in mutation_failures, "%s rejects missing-folder branch" % mutation_label, failures)

func _swap_fragments(source: String, first: String, second: String) -> String:
	const SWAP_MARKER := "__EQUIPMENT_VALIDATOR_CONTRACT_SWAP__"
	return source.replace(first, SWAP_MARKER).replace(second, first).replace(SWAP_MARKER, second)

func _normalized_source(source: String) -> String:
	var lines: PackedStringArray = []
	for line: String in source.split("\n"):
		lines.append(line.strip_edges())
	return "\n".join(lines)
