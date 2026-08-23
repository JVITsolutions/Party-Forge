extends RefCounted

const SERVICE_PATH := "res://scripts/combat/overkill_buffer_service.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var service_exists := ResourceLoader.exists(SERVICE_PATH)
	TestAssertions.truthy(service_exists, "run-scoped overkill buffer service exists", failures)
	if not service_exists:
		return failures
	var service_script := load(SERVICE_PATH) as Script
	TestAssertions.truthy(service_script != null, "overkill buffer service loads", failures)
	if service_script == null:
		return failures

	_test_exact_expiration_and_immutability(service_script, failures)
	_test_atomic_replacement(service_script, failures)
	_test_invalid_time_is_ignored(service_script, failures)
	_test_huge_finite_time_remains_safe(service_script, failures)
	_test_buffer_is_absent_from_persistence(failures)
	return failures

func _test_exact_expiration_and_immutability(service_script: Script, failures: Array[String]) -> void:
	var service: Object = service_script.new()
	var metadata := {"attack_id": "triple_crit", "nested": {"instance_count": 3}}
	TestAssertions.truthy(bool(service.call(&"record", &"enemy:buffer", 80.0, metadata)), "valid overkill record is accepted", failures)
	metadata["attack_id"] = "caller_mutation"
	(metadata["nested"] as Dictionary)["instance_count"] = 99
	var initial: Object = service.call(&"get_record", &"enemy:buffer")
	TestAssertions.truthy(initial != null, "record is readable immediately", failures)
	if initial != null:
		TestAssertions.near(float(initial.get("amount")), 80.0, 0.0001, "record keeps total overkill", failures)
		TestAssertions.equal((initial.get("metadata") as Dictionary)["attack_id"], "triple_crit", "record copies caller metadata", failures)
		TestAssertions.equal(((initial.get("metadata") as Dictionary)["nested"] as Dictionary)["instance_count"], 3, "record deep-copies caller metadata", failures)
		initial.set("amount", 999.0)
		var exposed_metadata := initial.get("metadata") as Dictionary
		exposed_metadata["attack_id"] = "returned_mutation"
	var isolated: Object = service.call(&"get_record", &"enemy:buffer")
	if isolated != null:
		TestAssertions.near(float(isolated.get("amount")), 80.0, 0.0001, "record amount is immutable", failures)
		TestAssertions.equal((isolated.get("metadata") as Dictionary)["attack_id"], "triple_crit", "record access is defensively copied", failures)

	TestAssertions.truthy(bool(service.call(&"advance", 1.999)), "deterministic positive elapsed time advances", failures)
	TestAssertions.truthy(service.call(&"get_record", &"enemy:buffer") != null, "record remains readable through elapsed 1.999", failures)
	TestAssertions.truthy(bool(service.call(&"advance", 0.001)), "advance reaches the exact lifetime boundary", failures)
	TestAssertions.equal(service.call(&"get_record", &"enemy:buffer"), null, "record expires at exactly elapsed 2.000", failures)

func _test_atomic_replacement(service_script: Script, failures: Array[String]) -> void:
	var service: Object = service_script.new()
	service.call(&"record", &"enemy:reused", 10.0, {"generation": 1})
	service.call(&"advance", 1.5)
	TestAssertions.truthy(bool(service.call(&"record", &"enemy:reused", 25.0, {"generation": 2})), "same target identity can be re-recorded", failures)
	var replaced: Object = service.call(&"get_record", &"enemy:reused")
	TestAssertions.truthy(replaced != null, "replacement remains readable", failures)
	if replaced != null:
		TestAssertions.near(float(replaced.get("amount")), 25.0, 0.0001, "replacement atomically swaps amount", failures)
		TestAssertions.equal((replaced.get("metadata") as Dictionary)["generation"], 2, "replacement atomically swaps metadata", failures)
	service.call(&"advance", 1.999)
	TestAssertions.truthy(service.call(&"get_record", &"enemy:reused") != null, "replacement receives a fresh full lifetime", failures)
	service.call(&"advance", 0.001)
	TestAssertions.equal(service.call(&"get_record", &"enemy:reused"), null, "replacement expires at its own exact two-second boundary", failures)

func _test_invalid_time_is_ignored(service_script: Script, failures: Array[String]) -> void:
	var service: Object = service_script.new()
	service.call(&"record", &"enemy:invalid_delta", 5.0, {})
	for invalid_delta: float in [-0.001, NAN, INF, -INF]:
		TestAssertions.truthy(not bool(service.call(&"advance", invalid_delta)), "invalid elapsed delta is rejected safely: %s" % invalid_delta, failures)
	TestAssertions.truthy(service.call(&"get_record", &"enemy:invalid_delta") != null, "invalid elapsed deltas do not age records", failures)
	service.call(&"advance", 2.0)
	TestAssertions.equal(service.call(&"get_record", &"enemy:invalid_delta"), null, "valid elapsed time still expires record", failures)
	TestAssertions.truthy(not bool(service.call(&"record", &"", 5.0, {})), "empty stable identity is rejected", failures)
	TestAssertions.truthy(not bool(service.call(&"record", &"enemy:bad_amount", NAN, {})), "non-finite amount is rejected", failures)

func _test_huge_finite_time_remains_safe(service_script: Script, failures: Array[String]) -> void:
	var service: Object = service_script.new()
	service.call(&"record", &"enemy:huge_delta", 5.0, {})
	TestAssertions.truthy(bool(service.call(&"advance", 1.0e308)), "huge finite elapsed time is handled deterministically", failures)
	TestAssertions.truthy(bool(service.call(&"advance", 1.0e308)), "repeated huge finite elapsed time cannot overflow the service clock", failures)
	TestAssertions.truthy(is_finite(float(service.get("elapsed"))), "elapsed state remains finite after repeated huge deltas", failures)
	TestAssertions.truthy(bool(service.call(&"record", &"enemy:after_huge_delta", 7.0, {"generation": 2})), "buffer remains usable after huge elapsed advances", failures)
	TestAssertions.truthy(service.call(&"get_record", &"enemy:after_huge_delta") != null, "post-overflow-probe record receives a real two-second lifetime", failures)
	service.call(&"advance", 1.999)
	TestAssertions.truthy(service.call(&"get_record", &"enemy:after_huge_delta") != null, "post-overflow-probe record remains through 1.999", failures)
	service.call(&"advance", 0.001)
	TestAssertions.equal(service.call(&"get_record", &"enemy:after_huge_delta"), null, "post-overflow-probe record expires at exact 2.000", failures)

func _test_buffer_is_absent_from_persistence(failures: Array[String]) -> void:
	var profile_document := ProfileState.new_profile("profile-transient", "Transient", 1000).to_dictionary()
	var profile_text := JSON.stringify(profile_document).to_lower()
	var run_fields_text := JSON.stringify(ResumableRunItemCodec.FIELDS).to_lower()
	for forbidden: String in ["overkill", "combat_diagnostics", "damage_bundle"]:
		TestAssertions.truthy(not profile_text.contains(forbidden), "profile schema excludes transient %s state" % forbidden, failures)
		TestAssertions.truthy(not run_fields_text.contains(forbidden), "resumable-run schema excludes transient %s state" % forbidden, failures)
	var persistence_sources := "\n".join([
		FileAccess.get_file_as_string("res://scripts/profile/profile_state.gd"),
		FileAccess.get_file_as_string("res://scripts/profile/profile_codec.gd"),
		FileAccess.get_file_as_string("res://scripts/run/resumable_run_item_codec.gd"),
	]).to_lower()
	TestAssertions.truthy(not persistence_sources.contains("overkill_buffer_service"), "profile and run codecs never reference the run-scoped buffer", failures)
	TestAssertions.truthy(not persistence_sources.contains("combat_resolution_service"), "profile and run codecs never reference combat diagnostics", failures)
