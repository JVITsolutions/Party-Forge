extends RefCounted

const SCRIPT_ERROR_CAPTURE := preload("res://tests/support/test_script_error_capture.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(
		SCRIPT_ERROR_CAPTURE.new().has_method(&"drain_after_detach"),
		"script error capture exposes one documented post-detach drain boundary",
		failures,
	)
	for runner_path: String in ["res://tests/focused_test_runner.gd", "res://tests/test_runner.gd"]:
		var source := FileAccess.get_file_as_string(runner_path)
		var detach_index := source.find("OS.remove_logger(script_errors)")
		var drain_index := source.find("script_errors.drain_after_detach()")
		TestAssertions.truthy(
			detach_index >= 0 and drain_index > detach_index,
			"%s detaches the logger before draining captured errors" % runner_path,
			failures,
		)
	return failures
