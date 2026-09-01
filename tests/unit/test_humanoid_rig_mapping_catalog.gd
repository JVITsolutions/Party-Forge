extends RefCounted

const CATALOG_PATH := "res://scripts/presentation/humanoid_rig_mapping_catalog.gd"
const MAPPING_PATH := "res://scripts/presentation/humanoid_rig_mapping.gd"
const RESOLUTION_PATH := "res://scripts/presentation/humanoid_rig_mapping_resolution.gd"
const LOADER_PATH := "res://scripts/presentation/humanoid_rig_mapping_loader.gd"
const MASCULINE_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres"
const FEMININE_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres"
const MASCULINE_ID := &"pf_humanoid_v1_mixamo52_masculine"
const FEMININE_ID := &"pf_humanoid_v1_mixamo52_feminine"
const MASCULINE_SHA := "8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4"
const FEMININE_SHA := "173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667"
const MASCULINE_REST := "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda"
const FEMININE_REST := "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85"

var _catalog_script: Script
var _mapping_script: Script
var _resolution_script: Script
var _loader_script: Script

class LoaderRecorder:
	extends RefCounted

	var existing_paths: Dictionary = {}
	var values_by_path: Dictionary = {}
	var existence_calls := PackedStringArray()
	var load_calls := PackedStringArray()

	func exists_exact(resource_path: String) -> bool:
		existence_calls.append(resource_path)
		return bool(existing_paths.get(resource_path, false))

	func load_exact(resource_path: String) -> Variant:
		load_calls.append(resource_path)
		return values_by_path.get(resource_path)

func run() -> Array[String]:
	var failures: Array[String] = []
	var resolution_exists := FileAccess.file_exists(RESOLUTION_PATH)
	var loader_exists := FileAccess.file_exists(LOADER_PATH)
	TestAssertions.truthy(resolution_exists, "read-only mapping resolution exists", failures)
	TestAssertions.truthy(loader_exists, "exact-path mapping loader exists", failures)
	if not resolution_exists or not loader_exists:
		return failures
	_resolution_script = load(RESOLUTION_PATH) as Script
	_loader_script = load(LOADER_PATH) as Script
	TestAssertions.truthy(_resolution_script != null, "read-only mapping resolution loads", failures)
	TestAssertions.truthy(_loader_script != null, "exact-path mapping loader loads", failures)
	if _resolution_script == null or _loader_script == null:
		return failures
	var catalog_exists := FileAccess.file_exists(CATALOG_PATH)
	TestAssertions.truthy(catalog_exists, "body-specific mapping catalog exists", failures)
	if not catalog_exists:
		return failures
	_catalog_script = load(CATALOG_PATH) as Script
	_mapping_script = load(MAPPING_PATH) as Script
	TestAssertions.truthy(_catalog_script != null, "body-specific mapping catalog loads", failures)
	TestAssertions.truthy(_mapping_script != null, "mapping resource script loads", failures)
	if _catalog_script == null or _mapping_script == null:
		return failures
	var interface_shape_is_exact := (
		_method_argument_count(_resolution_script, &"succeeded") == 3
		and _method_argument_count(_resolution_script, &"failed") == 4
		and _method_argument_count(_resolution_script, &"get_requested_body_preset") == 0
		and _method_argument_count(_resolution_script, &"get_selected_resource_path") == 0
		and _method_argument_count(_resolution_script, &"get_mapping") == 0
		and _method_argument_count(_resolution_script, &"get_failure_categories") == 0
		and _method_argument_count(_resolution_script, &"get_error_messages") == 0
		and _method_argument_count(_resolution_script, &"is_success") == 0
		and _method_argument_count(_resolution_script, &"rejected_by_mapped_rig") == 1
		and _method_argument_count(_loader_script, &"exists_exact") == 1
		and _method_argument_count(_loader_script, &"load_exact") == 1
		and _method_return_class_name(_resolution_script, &"succeeded") == &"RefCounted"
		and _method_return_class_name(_resolution_script, &"failed") == &"RefCounted"
		and _method_return_class_name(_resolution_script, &"rejected_by_mapped_rig") == &"RefCounted"
	)
	TestAssertions.truthy(interface_shape_is_exact, "A1 result and loader interfaces have exact method shapes", failures)
	if not interface_shape_is_exact:
		return failures

	var factory_probe := OS.get_environment("PF_RIG_FACTORY_CONTRACT_PROBE")
	if not factory_probe.is_empty():
		var error_capture_script := load("res://tests/support/test_error_capture.gd") as Script
		TestAssertions.truthy(error_capture_script != null, "factory contract error capture loads", failures)
		if error_capture_script == null:
			return failures
		var logger := error_capture_script.new() as Logger
		OS.add_logger(logger)
		var invalid_result: Variant
		if factory_probe == "invalid_success":
			invalid_result = _resolution_script.call(&"succeeded", &"unknown", "", null)
		elif factory_probe == "invalid_failure":
			var no_failure_categories: Array[StringName] = []
			invalid_result = _resolution_script.call(&"failed", &"masculine", MASCULINE_PATH, no_failure_categories, PackedStringArray())
		else:
			OS.remove_logger(logger)
			TestAssertions.truthy(false, "factory contract probe value is recognized", failures)
			return failures
		OS.remove_logger(logger)
		var captured: PackedStringArray = logger.call(&"drain_after_detach")
		TestAssertions.equal(invalid_result, null, "%s returns no observable result" % factory_probe, failures)
		TestAssertions.equal(captured.size(), 1, "%s emits exactly one programmer-contract error" % factory_probe, failures)
		if captured.size() == 1:
			var expected_reason := (
				"humanoid rig mapping resolution factory contract failed: success body preset unknown is invalid; success mapping is missing"
				if factory_probe == "invalid_success"
				else "humanoid rig mapping resolution factory contract failed: failure categories are empty; failure messages are empty"
			)
			TestAssertions.truthy(captured[0].contains(expected_reason), "%s error preserves exact ordered defects" % factory_probe, failures)
		return failures

	TestAssertions.equal(RESOLUTION_PATH, "res://scripts/presentation/humanoid_rig_mapping_resolution.gd", "resolution script path is exact", failures)
	var identity_script: Script = _resolution_script
	TestAssertions.truthy(identity_script != null, "resolution script loads for runtime identity", failures)
	if identity_script == null:
		return failures

	var resolution_mapping := _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
	var success: RefCounted = _resolution_script.call(
		&"succeeded", &"masculine", MASCULINE_PATH, resolution_mapping
	)
	TestAssertions.truthy(success != null, "success factory returns non-null RefCounted", failures)
	if success == null:
		return failures
	TestAssertions.equal(success.get_script(), identity_script, "success result keeps exact runtime script", failures)
	TestAssertions.truthy(success != null and bool(success.call(&"is_success")), "valid success result is observable", failures)
	TestAssertions.equal(success.call(&"get_requested_body_preset"), &"masculine", "success preset is read-only", failures)
	TestAssertions.equal(success.call(&"get_selected_resource_path"), MASCULINE_PATH, "success path is exact", failures)
	TestAssertions.equal(success.call(&"get_mapping"), resolution_mapping, "mapping getter returns the validated Resource reference", failures)
	var no_categories: Array[StringName] = []
	TestAssertions.equal(success.call(&"get_failure_categories"), no_categories, "success categories are empty", failures)
	TestAssertions.equal(success.call(&"get_error_messages"), PackedStringArray(), "success messages are empty", failures)

	resolution_mapping.set(&"mapping_id", &"mutated_after_resolution")
	TestAssertions.equal((success.call(&"get_mapping") as Resource).get(&"mapping_id"), &"mutated_after_resolution", "resolution does not freeze mapping Resource internals", failures)

	var categories: Array[StringName] = [&"missing_resource"]
	var messages := PackedStringArray(["humanoid rig mapping catalog body preset masculine resource %s does not exist" % MASCULINE_PATH])
	var failure: RefCounted = _resolution_script.call(&"failed", &"masculine", MASCULINE_PATH, categories, messages)
	TestAssertions.truthy(failure != null, "failure factory returns non-null RefCounted", failures)
	if failure == null:
		return failures
	TestAssertions.equal(failure.get_script(), identity_script, "failure result keeps exact runtime script", failures)
	categories.append(&"wrong_resource_type")
	messages.append("caller mutation")
	var returned_categories: Array = failure.call(&"get_failure_categories")
	var returned_messages: PackedStringArray = failure.call(&"get_error_messages")
	returned_categories.append(&"wrong_mapping_id")
	returned_messages.append("returned-copy mutation")
	var expected_missing_categories: Array[StringName] = [&"missing_resource"]
	TestAssertions.equal(failure.call(&"get_failure_categories"), expected_missing_categories, "stored categories resist caller mutation", failures)
	TestAssertions.equal((failure.call(&"get_error_messages") as PackedStringArray).size(), 1, "stored messages resist caller mutation", failures)
	TestAssertions.truthy(not bool(failure.call(&"is_success")), "failed result remains failed after caller mutation", failures)

	var validator_errors := PackedStringArray(["first mapped error", "second mapped error"])
	var rejected: RefCounted = success.call(&"rejected_by_mapped_rig", validator_errors)
	TestAssertions.truthy(rejected != null, "mapped rejection returns non-null RefCounted", failures)
	if rejected == null:
		return failures
	TestAssertions.equal(rejected.get_script(), identity_script, "mapped rejection keeps exact runtime script", failures)
	validator_errors.append("caller mutation")
	var expected_rejection_categories: Array[StringName] = [
		&"mapped_rig_validation_failed",
		&"mapped_rig_validation_failed",
	]
	TestAssertions.equal(rejected.call(&"get_failure_categories"), expected_rejection_categories, "mapped rejection preserves category cardinality", failures)
	TestAssertions.equal(rejected.call(&"get_error_messages"), PackedStringArray([
		"humanoid rig mapping catalog body preset masculine resource %s mapped rig validation failed: first mapped error" % MASCULINE_PATH,
		"humanoid rig mapping catalog body preset masculine resource %s mapped rig validation failed: second mapped error" % MASCULINE_PATH,
	]), "mapped rejection preserves validator order", failures)
	TestAssertions.equal(success.call(&"get_mapping"), resolution_mapping, "mapped rejection does not mutate successful result", failures)
	TestAssertions.equal(success.call(&"rejected_by_mapped_rig", PackedStringArray()), success, "empty mapped rejection returns original success", failures)
	TestAssertions.equal(failure.call(&"rejected_by_mapped_rig", PackedStringArray(["ignored"])), failure, "existing failure remains unchanged", failures)

	var property_names := PackedStringArray()
	for property: Dictionary in success.get_property_list():
		property_names.append(String(property.get("name", "")))
	for public_name: String in ["requested_body_preset", "selected_resource_path", "mapping", "failure_categories", "error_messages"]:
		TestAssertions.truthy(public_name not in property_names, "result exposes no public field %s" % public_name, failures)
	for setter_name: StringName in [&"set_requested_body_preset", &"set_selected_resource_path", &"set_mapping", &"set_failure_categories", &"set_error_messages"]:
		TestAssertions.truthy(not success.has_method(setter_name), "result exposes no setter %s" % setter_name, failures)

	var recorder := LoaderRecorder.new()
	recorder.existing_paths[MASCULINE_PATH] = true
	recorder.values_by_path[MASCULINE_PATH] = resolution_mapping
	var loader: RefCounted = _loader_script.new(Callable(recorder, &"exists_exact"), Callable(recorder, &"load_exact"))
	TestAssertions.truthy(bool(loader.call(&"exists_exact", MASCULINE_PATH)), "loader forwards existence callable", failures)
	TestAssertions.equal(loader.call(&"load_exact", MASCULINE_PATH), resolution_mapping, "loader forwards load callable", failures)
	TestAssertions.equal(recorder.existence_calls, PackedStringArray([MASCULINE_PATH]), "loader records exact existence path", failures)
	TestAssertions.equal(recorder.load_calls, PackedStringArray([MASCULINE_PATH]), "loader records exact load path", failures)
	TestAssertions.truthy(not bool(loader.call(&"exists_exact", FEMININE_PATH)), "loader does not substitute missing feminine existence", failures)
	TestAssertions.equal(loader.call(&"load_exact", FEMININE_PATH), null, "loader does not substitute missing feminine value", failures)
	TestAssertions.equal(recorder.existence_calls, PackedStringArray([MASCULINE_PATH, FEMININE_PATH]), "loader never substitutes existence path", failures)
	TestAssertions.equal(recorder.load_calls, PackedStringArray([MASCULINE_PATH, FEMININE_PATH]), "loader never substitutes load path", failures)

	var masculine := _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
	var feminine := _mapping(FEMININE_ID, FEMININE_SHA, FEMININE_REST)
	var injected := {&"masculine": masculine, &"feminine": feminine}
	var catalog := _catalog_script.new(injected) as RefCounted

	TestAssertions.equal(catalog.call(&"resolve", &"masculine"), masculine, "masculine resolves only its exact injected mapping", failures)
	TestAssertions.equal(catalog.call(&"resolve", &"feminine"), feminine, "feminine resolves only its exact injected mapping", failures)

	var active_mapping := masculine
	active_mapping = _activate_if_resolved(catalog, &"unknown", active_mapping)
	TestAssertions.equal(active_mapping, masculine, "failed unknown selection leaves active mapping unchanged", failures)

	var crossed_catalog := _catalog_script.new({&"masculine": feminine, &"feminine": masculine}) as RefCounted
	active_mapping = _activate_if_resolved(crossed_catalog, &"masculine", active_mapping)
	TestAssertions.equal(active_mapping, masculine, "failed cross-body masculine selection leaves active mapping unchanged", failures)
	TestAssertions.equal(crossed_catalog.call(&"resolve", &"feminine"), null, "cross-body feminine selection fails", failures)

	var wrong_canonical := _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
	wrong_canonical.set(&"canonical_rig_id", &"wrong")
	var wrong_canonical_catalog := _catalog_script.new({&"masculine": wrong_canonical}) as RefCounted
	TestAssertions.equal(wrong_canonical_catalog.call(&"resolve", &"masculine"), null, "wrong canonical identity rejects", failures)

	var wrong_id := _mapping(&"wrong", MASCULINE_SHA, MASCULINE_REST)
	var wrong_id_catalog := _catalog_script.new({&"masculine": wrong_id}) as RefCounted
	TestAssertions.equal(wrong_id_catalog.call(&"resolve", &"masculine"), null, "wrong mapping id rejects", failures)

	var wrong_source := _mapping(MASCULINE_ID, FEMININE_SHA, MASCULINE_REST)
	var wrong_source_catalog := _catalog_script.new({&"masculine": wrong_source}) as RefCounted
	TestAssertions.equal(wrong_source_catalog.call(&"resolve", &"masculine"), null, "wrong source hash rejects", failures)

	var wrong_rest := _mapping(MASCULINE_ID, MASCULINE_SHA, FEMININE_REST)
	var wrong_rest_catalog := _catalog_script.new({&"masculine": wrong_rest}) as RefCounted
	TestAssertions.equal(wrong_rest_catalog.call(&"resolve", &"masculine"), null, "wrong source rest signature rejects", failures)

	injected[&"masculine"] = feminine
	TestAssertions.equal(catalog.call(&"resolve", &"masculine"), masculine, "constructor duplicates injected dictionary", failures)

	var script_constants := _catalog_script.get_script_constant_map()
	var resource_paths := script_constants.get("RESOURCE_PATH_BY_BODY_PRESET", {}) as Dictionary
	TestAssertions.equal(
		resource_paths.get(&"masculine"),
		"res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
		"masculine future resource path is exact",
		failures
	)
	TestAssertions.equal(
		resource_paths.get(&"feminine"),
		FEMININE_PATH,
		"feminine future resource path is exact",
		failures
	)
	var resolution_resource_paths := _resolution_script.get_script_constant_map().get("_RESOURCE_PATH_BY_BODY_PRESET", {}) as Dictionary
	TestAssertions.equal(resolution_resource_paths, resource_paths, "catalog and resolution path tables are identical", failures)
	return failures

func _mapping(mapping_id: StringName, source_sha: String, rest_signature: String) -> Resource:
	var mapping := _mapping_script.new() as Resource
	mapping.set(&"mapping_id", mapping_id)
	mapping.set(&"canonical_rig_id", &"pf_humanoid_v1")
	mapping.set(&"source_skeleton_sha256", source_sha)
	mapping.set(&"source_rest_signature", rest_signature)
	return mapping

func _activate_if_resolved(catalog: RefCounted, body_preset_id: StringName, active_mapping: Resource) -> Resource:
	var resolved := catalog.call(&"resolve", body_preset_id) as Resource
	return resolved if resolved != null else active_mapping

func _method_argument_count(script: Script, method_name: StringName) -> int:
	for method_value: Variant in script.get_script_method_list():
		var method := method_value as Dictionary
		if StringName(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return -1

func _method_return_class_name(script: Script, method_name: StringName) -> StringName:
	for method_value: Variant in script.get_script_method_list():
		var method := method_value as Dictionary
		if StringName(method.get("name", "")) == method_name:
			var return_info := method.get("return", {}) as Dictionary
			return StringName(return_info.get("class_name", ""))
	return &""
