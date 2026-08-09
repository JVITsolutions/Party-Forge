extends SceneTree

const SCRIPT_ERROR_CAPTURE := preload("res://tests/support/test_script_error_capture.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var script_errors := SCRIPT_ERROR_CAPTURE.new()
	OS.add_logger(script_errors)
	var suites := OS.get_cmdline_user_args()
	if suites.is_empty():
		failures.append("FOCUSED_TEST_RUNNER_ERROR: no suite path arguments")
	for suite_path: String in suites:
		var script := load(suite_path) as Script
		if script == null:
			failures.append("%s :: suite failed to load" % suite_path)
			continue
		var suite_result: Variant = (script.new() as RefCounted).call(&"run")
		if not suite_result is Array:
			failures.append("%s :: suite did not return a failure array" % suite_path)
			continue
		for failure: String in suite_result as Array:
			failures.append("%s :: %s" % [suite_path, failure])
	OS.remove_logger(script_errors)
	for script_error: String in script_errors.drain_after_detach():
		failures.append("SCRIPT ERROR :: %s" % script_error)
	for failure: String in failures:
		push_error("TEST_FAILURE: %s" % failure)
	print("TEST_SUMMARY: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
