extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var suites := OS.get_cmdline_user_args()
	for suite_path: String in suites:
		var script := load(suite_path) as Script
		if script == null:
			failures.append("%s :: suite failed to load" % suite_path)
			continue
		for failure: String in (script.new() as RefCounted).call(&"run"):
			failures.append("%s :: %s" % [suite_path, failure])
	for failure: String in failures:
		push_error("TEST_FAILURE: %s" % failure)
	print("TEST_SUMMARY: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
