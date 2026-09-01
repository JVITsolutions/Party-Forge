extends RefCounted

const CATALOG_PATH := "res://scripts/presentation/humanoid_rig_mapping_catalog.gd"
const MAPPING_PATH := "res://scripts/presentation/humanoid_rig_mapping.gd"
const RESOLUTION_PATH := "res://scripts/presentation/humanoid_rig_mapping_resolution.gd"
const LOADER_PATH := "res://scripts/presentation/humanoid_rig_mapping_loader.gd"
const MASCULINE_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres"
const FEMININE_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres"
const SHARED_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52.tres"
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
	var masculine_resource_exists := ResourceLoader.exists(MASCULINE_PATH)
	var feminine_resource_exists := ResourceLoader.exists(FEMININE_PATH)
	TestAssertions.truthy(masculine_resource_exists, "masculine production mapping resource exists", failures)
	TestAssertions.truthy(feminine_resource_exists, "feminine production mapping resource exists", failures)
	if not masculine_resource_exists or not feminine_resource_exists:
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
		var supplied_mapping: Resource
		var supplied_categories: Array[StringName] = []
		var supplied_messages := PackedStringArray()
		if factory_probe == "invalid_success":
			invalid_result = _resolution_script.call(&"succeeded", &"unknown", "", null)
		elif factory_probe == "invalid_failure":
			invalid_result = _resolution_script.call(&"failed", &"masculine", MASCULINE_PATH, supplied_categories, supplied_messages)
		elif factory_probe == "invalid_direct_constructor":
			supplied_mapping = _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
			supplied_categories = [&"missing_resource"]
			supplied_messages = PackedStringArray(["caller-supplied constructor message"])
			invalid_result = _resolution_script.new(
				RefCounted.new(),
				&"masculine",
				MASCULINE_PATH,
				supplied_mapping,
				supplied_categories,
				supplied_messages
			)
		else:
			OS.remove_logger(logger)
			TestAssertions.truthy(false, "factory contract probe value is recognized", failures)
			return failures
		OS.remove_logger(logger)
		var captured: PackedStringArray = logger.call(&"drain_after_detach")
		if factory_probe == "invalid_direct_constructor":
			TestAssertions.truthy(invalid_result is RefCounted, "invalid_direct_constructor returns allocated RefCounted", failures)
			if not invalid_result is RefCounted:
				return failures
			var inert := invalid_result as RefCounted
			TestAssertions.equal(inert.get_script(), _resolution_script, "invalid_direct_constructor keeps exact runtime script", failures)
			TestAssertions.truthy(not bool(inert.call(&"is_success")), "invalid_direct_constructor is not successful", failures)
			TestAssertions.equal(inert.call(&"get_requested_body_preset"), StringName(), "invalid_direct_constructor stores no preset", failures)
			TestAssertions.equal(inert.call(&"get_selected_resource_path"), "", "invalid_direct_constructor stores no path", failures)
			TestAssertions.equal(inert.call(&"get_mapping"), null, "invalid_direct_constructor stores no mapping", failures)
			TestAssertions.equal(inert.call(&"get_failure_categories"), [] as Array[StringName], "invalid_direct_constructor stores no categories", failures)
			TestAssertions.equal(inert.call(&"get_error_messages"), PackedStringArray(), "invalid_direct_constructor stores no messages", failures)
			TestAssertions.equal(inert.call(&"rejected_by_mapped_rig", PackedStringArray(["ignored"])), inert, "invalid_direct_constructor rejection remains inert", failures)
			var returned_categories: Array = inert.call(&"get_failure_categories")
			var returned_messages: PackedStringArray = inert.call(&"get_error_messages")
			returned_categories.append(&"wrong_resource_type")
			returned_messages.append("returned-copy mutation")
			supplied_mapping.set(&"mapping_id", &"caller_mutation")
			supplied_categories.append(&"wrong_resource_type")
			supplied_messages.append("caller mutation")
			TestAssertions.equal(inert.call(&"get_mapping"), null, "invalid_direct_constructor resists mapping mutation", failures)
			TestAssertions.equal(inert.call(&"get_failure_categories"), [] as Array[StringName], "invalid_direct_constructor categories remain inert", failures)
			TestAssertions.equal(inert.call(&"get_error_messages"), PackedStringArray(), "invalid_direct_constructor messages remain inert", failures)
			TestAssertions.equal(captured.size(), 1, "invalid_direct_constructor emits one programmer-contract error", failures)
			if captured.size() == 1:
				TestAssertions.truthy(
					captured[0].contains("humanoid rig mapping resolution constructor contract failed: invalid factory token"),
					"invalid_direct_constructor emits exact constructor-contract error",
					failures
				)
			return failures
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

	var resolve_argument_count := _method_argument_count(_catalog_script, &"resolve")
	var resolve_return_class := _method_return_class_name(_catalog_script, &"resolve")
	TestAssertions.truthy(resolve_argument_count == 2 and resolve_return_class == &"RefCounted", "catalog exposes per-call exact-path structured resolve", failures)
	if resolve_argument_count != 2 or resolve_return_class != &"RefCounted":
		return failures

	var catalog := _catalog_script.new() as RefCounted
	var all_recorders: Array[LoaderRecorder] = []

	var unknown_recorder := LoaderRecorder.new()
	all_recorders.append(unknown_recorder)
	var unknown_loader: RefCounted = _loader_script.new(Callable(unknown_recorder, &"exists_exact"), Callable(unknown_recorder, &"load_exact"))
	var unknown_result: RefCounted = catalog.call(&"resolve", &"unknown", unknown_loader)
	TestAssertions.equal(_resolution_snapshot(unknown_result, unknown_recorder), {
		&"preset": &"unknown",
		&"path": "",
		&"mapping": null,
		&"categories": [&"unknown_body_preset"],
		&"messages": PackedStringArray(["humanoid rig mapping catalog body preset unknown is unknown"]),
		&"success": false,
		&"existence_calls": PackedStringArray(),
		&"load_calls": PackedStringArray(),
	}, "unknown preset avoids loader and returns exact failure", failures)

	var missing_recorder := LoaderRecorder.new()
	all_recorders.append(missing_recorder)
	var missing_loader: RefCounted = _loader_script.new(Callable(missing_recorder, &"exists_exact"), Callable(missing_recorder, &"load_exact"))
	var missing_result: RefCounted = catalog.call(&"resolve", &"masculine", missing_loader)
	TestAssertions.equal(_resolution_snapshot(missing_result, missing_recorder), {
		&"preset": &"masculine",
		&"path": MASCULINE_PATH,
		&"mapping": null,
		&"categories": [&"missing_resource"],
		&"messages": PackedStringArray(["humanoid rig mapping catalog body preset masculine resource %s does not exist" % MASCULINE_PATH]),
		&"success": false,
		&"existence_calls": PackedStringArray([MASCULINE_PATH]),
		&"load_calls": PackedStringArray(),
	}, "missing resource outcome is exact", failures)

	_assert_default_resource_resolution(
		catalog,
		&"masculine",
		MASCULINE_PATH,
		MASCULINE_ID,
		MASCULINE_SHA,
		MASCULINE_REST,
		failures
	)
	_assert_default_resource_resolution(
		catalog,
		&"feminine",
		FEMININE_PATH,
		FEMININE_ID,
		FEMININE_SHA,
		FEMININE_REST,
		failures
	)

	var failed_load_recorder := LoaderRecorder.new()
	failed_load_recorder.existing_paths[MASCULINE_PATH] = true
	all_recorders.append(failed_load_recorder)
	var failed_load_loader: RefCounted = _loader_script.new(Callable(failed_load_recorder, &"exists_exact"), Callable(failed_load_recorder, &"load_exact"))
	var failed_load_result: RefCounted = catalog.call(&"resolve", &"masculine", failed_load_loader)
	TestAssertions.equal(_resolution_snapshot(failed_load_result, failed_load_recorder), {
		&"preset": &"masculine",
		&"path": MASCULINE_PATH,
		&"mapping": null,
		&"categories": [&"resource_load_failed"],
		&"messages": PackedStringArray(["humanoid rig mapping catalog body preset masculine resource %s could not be loaded" % MASCULINE_PATH]),
		&"success": false,
		&"existence_calls": PackedStringArray([MASCULINE_PATH]),
		&"load_calls": PackedStringArray([MASCULINE_PATH]),
	}, "failed load outcome is exact", failures)

	var wrong_type_recorder := LoaderRecorder.new()
	wrong_type_recorder.existing_paths[MASCULINE_PATH] = true
	wrong_type_recorder.values_by_path[MASCULINE_PATH] = Resource.new()
	all_recorders.append(wrong_type_recorder)
	var wrong_type_loader: RefCounted = _loader_script.new(Callable(wrong_type_recorder, &"exists_exact"), Callable(wrong_type_recorder, &"load_exact"))
	var wrong_type_result: RefCounted = catalog.call(&"resolve", &"masculine", wrong_type_loader)
	TestAssertions.equal(_resolution_snapshot(wrong_type_result, wrong_type_recorder), {
		&"preset": &"masculine",
		&"path": MASCULINE_PATH,
		&"mapping": null,
		&"categories": [&"wrong_resource_type"],
		&"messages": PackedStringArray(["humanoid rig mapping catalog body preset masculine resource %s must be HumanoidRigMapping, got Resource" % MASCULINE_PATH]),
		&"success": false,
		&"existence_calls": PackedStringArray([MASCULINE_PATH]),
		&"load_calls": PackedStringArray([MASCULINE_PATH]),
	}, "wrong resource type outcome is exact", failures)

	var identity_mapping := _mapping(&"wrong", FEMININE_SHA, FEMININE_REST)
	identity_mapping.set(&"canonical_rig_id", &"wrong")
	var identity_recorder := LoaderRecorder.new()
	identity_recorder.existing_paths[MASCULINE_PATH] = true
	identity_recorder.values_by_path[MASCULINE_PATH] = identity_mapping
	all_recorders.append(identity_recorder)
	var identity_loader: RefCounted = _loader_script.new(Callable(identity_recorder, &"exists_exact"), Callable(identity_recorder, &"load_exact"))
	var identity_result: RefCounted = catalog.call(&"resolve", &"masculine", identity_loader)
	TestAssertions.equal(_resolution_snapshot(identity_result, identity_recorder), {
		&"preset": &"masculine",
		&"path": MASCULINE_PATH,
		&"mapping": null,
		&"categories": [&"wrong_mapping_id", &"wrong_canonical_rig_id", &"wrong_source_hash", &"wrong_rest_signature"],
		&"messages": PackedStringArray([
			"humanoid rig mapping catalog body preset masculine mapping id must be %s, got wrong" % MASCULINE_ID,
			"humanoid rig mapping catalog body preset masculine canonical rig id must be pf_humanoid_v1, got wrong",
			"humanoid rig mapping catalog body preset masculine source skeleton hash must be %s, got %s" % [MASCULINE_SHA, FEMININE_SHA],
			"humanoid rig mapping catalog body preset masculine source rest signature must be %s, got %s" % [MASCULINE_REST, FEMININE_REST],
		]),
		&"success": false,
		&"existence_calls": PackedStringArray([MASCULINE_PATH]),
		&"load_calls": PackedStringArray([MASCULINE_PATH]),
	}, "identity mismatch categories and messages are ordered", failures)

	var masculine := _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
	var masculine_recorder := LoaderRecorder.new()
	masculine_recorder.existing_paths[MASCULINE_PATH] = true
	masculine_recorder.values_by_path[MASCULINE_PATH] = masculine
	all_recorders.append(masculine_recorder)
	var masculine_loader: RefCounted = _loader_script.new(Callable(masculine_recorder, &"exists_exact"), Callable(masculine_recorder, &"load_exact"))
	var masculine_result: RefCounted = catalog.call(&"resolve", &"masculine", masculine_loader)
	TestAssertions.equal(_resolution_snapshot(masculine_result, masculine_recorder), {
		&"preset": &"masculine",
		&"path": MASCULINE_PATH,
		&"mapping": masculine,
		&"categories": [],
		&"messages": PackedStringArray(),
		&"success": true,
		&"existence_calls": PackedStringArray([MASCULINE_PATH]),
		&"load_calls": PackedStringArray([MASCULINE_PATH]),
	}, "masculine exact path resolution succeeds", failures)

	var feminine := _mapping(FEMININE_ID, FEMININE_SHA, FEMININE_REST)
	var feminine_recorder := LoaderRecorder.new()
	feminine_recorder.existing_paths[FEMININE_PATH] = true
	feminine_recorder.values_by_path[FEMININE_PATH] = feminine
	all_recorders.append(feminine_recorder)
	var feminine_loader: RefCounted = _loader_script.new(Callable(feminine_recorder, &"exists_exact"), Callable(feminine_recorder, &"load_exact"))
	var feminine_result: RefCounted = catalog.call(&"resolve", &"feminine", feminine_loader)
	TestAssertions.equal(_resolution_snapshot(feminine_result, feminine_recorder), {
		&"preset": &"feminine",
		&"path": FEMININE_PATH,
		&"mapping": feminine,
		&"categories": [],
		&"messages": PackedStringArray(),
		&"success": true,
		&"existence_calls": PackedStringArray([FEMININE_PATH]),
		&"load_calls": PackedStringArray([FEMININE_PATH]),
	}, "feminine exact path resolution succeeds", failures)

	var cross_body_recorder := LoaderRecorder.new()
	cross_body_recorder.existing_paths[MASCULINE_PATH] = true
	cross_body_recorder.values_by_path[MASCULINE_PATH] = feminine
	all_recorders.append(cross_body_recorder)
	var cross_body_loader: RefCounted = _loader_script.new(Callable(cross_body_recorder, &"exists_exact"), Callable(cross_body_recorder, &"load_exact"))
	var cross_body_result: RefCounted = catalog.call(&"resolve", &"masculine", cross_body_loader)
	TestAssertions.equal(_resolution_snapshot(cross_body_result, cross_body_recorder), {
		&"preset": &"masculine",
		&"path": MASCULINE_PATH,
		&"mapping": null,
		&"categories": [&"wrong_mapping_id", &"wrong_source_hash", &"wrong_rest_signature"],
		&"messages": PackedStringArray([
			"humanoid rig mapping catalog body preset masculine mapping id must be %s, got %s" % [MASCULINE_ID, FEMININE_ID],
			"humanoid rig mapping catalog body preset masculine source skeleton hash must be %s, got %s" % [MASCULINE_SHA, FEMININE_SHA],
			"humanoid rig mapping catalog body preset masculine source rest signature must be %s, got %s" % [MASCULINE_REST, FEMININE_REST],
		]),
		&"success": false,
		&"existence_calls": PackedStringArray([MASCULINE_PATH]),
		&"load_calls": PackedStringArray([MASCULINE_PATH]),
	}, "cross-body mapping fails without fallback", failures)

	var retained_mapping := _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
	var retained_recorder := LoaderRecorder.new()
	retained_recorder.existing_paths[MASCULINE_PATH] = true
	retained_recorder.values_by_path[MASCULINE_PATH] = retained_mapping
	all_recorders.append(retained_recorder)
	var retained_loader: RefCounted = _loader_script.new(Callable(retained_recorder, &"exists_exact"), Callable(retained_recorder, &"load_exact"))
	var retained_success: RefCounted = catalog.call(&"resolve", &"masculine", retained_loader)
	var later_failure_recorder := LoaderRecorder.new()
	all_recorders.append(later_failure_recorder)
	var later_failure_loader: RefCounted = _loader_script.new(Callable(later_failure_recorder, &"exists_exact"), Callable(later_failure_recorder, &"load_exact"))
	catalog.call(&"resolve", &"unknown", later_failure_loader)
	TestAssertions.equal(_resolution_snapshot(retained_success), {
		&"preset": &"masculine",
		&"path": MASCULINE_PATH,
		&"mapping": retained_mapping,
		&"categories": [],
		&"messages": PackedStringArray(),
		&"success": true,
		&"existence_calls": PackedStringArray(),
		&"load_calls": PackedStringArray(),
	}, "later catalog failure does not mutate prior success", failures)

	var all_loader_calls := PackedStringArray()
	for case_recorder: LoaderRecorder in all_recorders:
		all_loader_calls.append_array(case_recorder.existence_calls)
		all_loader_calls.append_array(case_recorder.load_calls)
	TestAssertions.truthy(SHARED_PATH not in all_loader_calls, "catalog never requests shared mapping resource", failures)
	var catalog_property_names := PackedStringArray()
	for catalog_property: Dictionary in catalog.get_property_list():
		catalog_property_names.append(String(catalog_property.get("name", "")))
	var forbidden_state_property_found := false
	for catalog_property_name: String in catalog_property_names:
		var normalized_property_name := catalog_property_name.to_lower()
		if "active" in normalized_property_name or "result" in normalized_property_name or "error" in normalized_property_name:
			forbidden_state_property_found = true
			break
	TestAssertions.truthy(not forbidden_state_property_found, "catalog exposes no active result or error state", failures)

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
	TestAssertions.truthy(not resource_paths.has(&"shared") and SHARED_PATH not in resource_paths.values(), "catalog path table has no shared fallback", failures)
	var resolution_resource_paths := _resolution_script.get_script_constant_map().get("_RESOURCE_PATH_BY_BODY_PRESET", {}) as Dictionary
	TestAssertions.equal(resolution_resource_paths, resource_paths, "catalog and resolution path tables are identical", failures)
	return failures

func _assert_default_resource_resolution(
	catalog: RefCounted,
	preset: StringName,
	expected_path: String,
	expected_mapping_id: StringName,
	expected_source_sha: String,
	expected_rest_signature: String,
	failures: Array[String]
) -> void:
	var result := catalog.call(&"resolve", preset) as RefCounted
	TestAssertions.truthy(result != null, "%s default resource returns a result" % preset, failures)
	if result == null:
		return
	TestAssertions.truthy(bool(result.call(&"is_success")), "%s default resource resolves successfully" % preset, failures)
	TestAssertions.equal(result.call(&"get_requested_body_preset"), preset, "%s default result keeps preset" % preset, failures)
	TestAssertions.equal(result.call(&"get_selected_resource_path"), expected_path, "%s default result keeps exact path" % preset, failures)
	TestAssertions.equal(result.call(&"get_failure_categories"), [] as Array[StringName], "%s default result has no failure categories" % preset, failures)
	TestAssertions.equal(result.call(&"get_error_messages"), PackedStringArray(), "%s default result has no error messages" % preset, failures)
	var mapping := result.call(&"get_mapping") as Resource
	TestAssertions.truthy(mapping != null, "%s default result returns mapping" % preset, failures)
	if mapping == null:
		return
	TestAssertions.equal(mapping.get(&"mapping_id"), expected_mapping_id, "%s default mapping id is exact" % preset, failures)
	TestAssertions.equal(mapping.get(&"canonical_rig_id"), &"pf_humanoid_v1", "%s default canonical id is exact" % preset, failures)
	TestAssertions.equal(mapping.get(&"source_skeleton_sha256"), expected_source_sha, "%s default source hash is exact" % preset, failures)
	TestAssertions.equal(mapping.get(&"source_rest_signature"), expected_rest_signature, "%s default rest signature is exact" % preset, failures)

func _mapping(mapping_id: StringName, source_sha: String, rest_signature: String) -> Resource:
	var mapping := _mapping_script.new() as Resource
	mapping.set(&"mapping_id", mapping_id)
	mapping.set(&"canonical_rig_id", &"pf_humanoid_v1")
	mapping.set(&"source_skeleton_sha256", source_sha)
	mapping.set(&"source_rest_signature", rest_signature)
	return mapping

func _resolution_snapshot(result: RefCounted, recorder: LoaderRecorder = null) -> Dictionary:
	return {
		&"preset": result.call(&"get_requested_body_preset"),
		&"path": result.call(&"get_selected_resource_path"),
		&"mapping": result.call(&"get_mapping"),
		&"categories": result.call(&"get_failure_categories"),
		&"messages": result.call(&"get_error_messages"),
		&"success": bool(result.call(&"is_success")),
		&"existence_calls": recorder.existence_calls.duplicate() if recorder != null else PackedStringArray(),
		&"load_calls": recorder.load_calls.duplicate() if recorder != null else PackedStringArray(),
	}

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
