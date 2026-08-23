extends RefCounted

const PRELOAD_SUITE := "tests/unit/test_imported_surface_materials.gd"
const TRANSACTION_SUITE := "tests/unit/test_character_body_fit_transaction.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var child_output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--quit-after", "300",
		"--script", "res://tests/focused_test_runner.gd",
		"--", PRELOAD_SUITE, TRANSACTION_SUITE,
	], child_output, true)
	var combined_output := "\n".join(child_output)
	TestAssertions.equal(exit_code, 0, "focused lifecycle child exits zero", failures)
	TestAssertions.truthy("TEST_SUMMARY: PASS (0 failures)" in combined_output, "focused lifecycle child passes both suites", failures)
	TestAssertions.truthy("ObjectDB instances were leaked at exit" not in combined_output, "focused lifecycle child releases every ObjectDB instance", failures)
	TestAssertions.truthy("resources still in use at exit" not in combined_output, "focused lifecycle child releases every resource", failures)
	return failures
