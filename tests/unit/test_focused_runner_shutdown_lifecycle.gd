extends RefCounted

const PRELOAD_SUITE := "tests/unit/test_imported_surface_materials.gd"
const TRANSACTION_SUITE := "tests/unit/test_character_body_fit_transaction.gd"
const PASS_SUMMARY := "TEST_SUMMARY: PASS (0 failures)"
const KNOWN_ASSERTION_OWNED_NEGATIVE := "ASSERTION_OWNED_NEGATIVE: expected invalid fixture"
const FAILURE_DIAGNOSTIC_MARKERS: Array[String] = [
	"test_failure",
	"script error",
	"objectdb",
	"resource",
	"orphan",
	"leak",
	"script-unload",
	"script unload",
	"can't unload",
	"cannot unload",
	"still in use",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_child_contract_policy(failures)
	var child_output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--quit-after", "300",
		"--script", "res://tests/focused_test_runner.gd",
		"--", PRELOAD_SUITE, TRANSACTION_SUITE,
	], child_output, true)
	var combined_output := "\n".join(child_output)
	failures.append_array(_child_contract_failures(exit_code, combined_output))
	return failures

func _test_child_contract_policy(failures: Array[String]) -> void:
	_assert_detected("nonzero exit", 9, "%s\nNONZERO_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	_assert_detected("missing summary", 0, "MISSING_SUMMARY_OUTPUT_TOKEN", failures)
	_assert_detected("failed summary", 0, "TEST_SUMMARY: FAIL (3 failures)\nFAILED_SUMMARY_OUTPUT_TOKEN", failures)
	_assert_detected("failed summary alongside pass", 0, "%s\nTEST_SUMMARY: FAIL (1 failures)\nCONTRADICTORY_SUMMARY_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	_assert_detected("test failure marker", 0, "%s\nERROR: TEST_FAILURE: controlled child failure\nTEST_FAILURE_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	_assert_detected("script error marker", 0, "%s\nSCRIPT ERROR: Invalid call\nSCRIPT_ERROR_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	_assert_detected("generic shutdown error", 0, "%s\nERROR: cleanup failed during shutdown\nGENERIC_ERROR_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	_assert_detected("generic shutdown warning", 0, "%s\nWARNING: cleanup incomplete during shutdown\nGENERIC_WARNING_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	_assert_detected("ObjectDB diagnostic", 0, "%s\nObjectDB instances remain at exit\nOBJECTDB_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	_assert_detected("resource diagnostic", 0, "%s\nresources remain referenced at exit\nRESOURCE_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	_assert_detected("orphan diagnostic", 0, "%s\n3 orphan nodes detected\nORPHAN_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	_assert_detected("leak diagnostic", 0, "%s\nRID leak detected\nLEAK_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	_assert_detected("script unload diagnostic", 0, "%s\nscript-unload failed for res://fixture.gd\nSCRIPT_UNLOAD_OUTPUT_TOKEN" % PASS_SUMMARY, failures)
	TestAssertions.equal(_child_contract_failures(0, "%s\nERROR: %s" % [PASS_SUMMARY, KNOWN_ASSERTION_OWNED_NEGATIVE], [KNOWN_ASSERTION_OWNED_NEGATIVE]), [], "explicitly known assertion-owned negative diagnostic remains allowed", failures)
	TestAssertions.equal(_child_contract_failures(0, PASS_SUMMARY), [], "clean child output satisfies the lifecycle contract", failures)

func _assert_detected(label: String, exit_code: int, output: String, failures: Array[String]) -> void:
	var detected := _child_contract_failures(exit_code, output)
	TestAssertions.truthy(not detected.is_empty(), "%s is rejected" % label, failures)
	TestAssertions.truthy(output in "\n".join(detected), "%s surfaces the complete captured child output" % label, failures)

func _child_contract_failures(exit_code: int, combined_output: String, allowed_diagnostics: Array[String] = []) -> Array[String]:
	var failures: Array[String] = []
	if exit_code != 0:
		failures.append("focused lifecycle child exits zero: expected 0, got %d" % exit_code)
	if PASS_SUMMARY not in combined_output:
		failures.append("focused lifecycle child PASS summary is missing or failed")
	if "TEST_SUMMARY: FAIL" in combined_output:
		failures.append("focused lifecycle child emitted a failed summary")
	for raw_line: String in combined_output.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or _diagnostic_is_allowed(line, allowed_diagnostics):
			continue
		var normalized := line.to_lower()
		var rejected := line.begins_with("ERROR:") or line.begins_with("WARNING:")
		if not rejected:
			for marker: String in FAILURE_DIAGNOSTIC_MARKERS:
				if marker in normalized:
					rejected = true
					break
		if rejected:
			failures.append("focused lifecycle child emitted forbidden diagnostic: %s" % line)
	if not failures.is_empty():
		failures.append("focused lifecycle child captured output:\n%s" % combined_output)
	return failures

func _diagnostic_is_allowed(line: String, allowed_diagnostics: Array[String]) -> bool:
	for allowed: String in allowed_diagnostics:
		if not allowed.is_empty() and allowed in line:
			return true
	return false
