extends RefCounted

const SANDBOX_SCENE_PATH := "res://scenes/ui/developer_item_sandbox.tscn"
const RUNNER_PATHS: Array[String] = [
	"res://tests/integration/developer_item_sandbox_runner.gd",
	"res://tests/integration/item_storage_profile_runner.gd",
	"res://tests/integration/item_storage_performance_runner.gd",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	for path: String in RUNNER_PATHS:
		TestAssertions.truthy(ResourceLoader.exists(path), "Task 10 runner exists: %s" % path, failures)
	var packed := load(SANDBOX_SCENE_PATH) as PackedScene
	TestAssertions.truthy(packed != null, "developer item sandbox scene loads", failures)
	if packed == null:
		return failures
	var sandbox := packed.instantiate() as DeveloperItemSandbox
	for method: StringName in [&"apply_viewport_size", &"slot_button_count", &"selected_item_detail", &"integrity_error"]:
		TestAssertions.truthy(sandbox.has_method(method), "sandbox exposes useful read-only/responsive method %s" % method, failures)
	if not sandbox.has_method(&"apply_viewport_size"):
		sandbox.free()
		return failures
	var body := sandbox.get_node("Overlay/Frame/Layout/Body") as BoxContainer
	var frame := sandbox.get_node("Overlay/Frame") as Control
	sandbox.call(&"apply_viewport_size", Vector2i(1920, 1080))
	TestAssertions.truthy(not body.vertical, "desktop sandbox body is horizontal", failures)
	TestAssertions.equal(
		Vector4(frame.offset_left, frame.offset_top, frame.offset_right, frame.offset_bottom),
		Vector4(48.0, 36.0, -48.0, -36.0),
		"desktop sandbox uses established safe margins",
		failures
	)
	sandbox.call(&"apply_viewport_size", Vector2i(1099, 1080))
	TestAssertions.truthy(body.vertical, "sandbox uses the shared compact width breakpoint", failures)
	sandbox.call(&"apply_viewport_size", Vector2i(1920, 649))
	TestAssertions.truthy(body.vertical, "sandbox uses the shared compact height breakpoint", failures)
	TestAssertions.equal(
		Vector4(frame.offset_left, frame.offset_top, frame.offset_right, frame.offset_bottom),
		Vector4(16.0, 12.0, -16.0, -12.0),
		"compact sandbox uses established safe margins",
		failures
	)
	if sandbox.has_method(&"slot_button_count"):
		TestAssertions.equal(int(sandbox.call(&"slot_button_count")), 105, "sandbox reports all 105 real slots", failures)
	if sandbox.has_method(&"selected_item_detail"):
		var escaped := sandbox.call(&"selected_item_detail") as Dictionary
		escaped["instance_id"] = "escaped"
		TestAssertions.equal(sandbox.call(&"selected_item_detail"), {}, "selected item diagnostic is defensive and empty before selection", failures)
	if sandbox.has_method(&"integrity_error"):
		TestAssertions.equal(String(sandbox.call(&"integrity_error")), "", "sandbox integrity diagnostic begins clear", failures)
	sandbox.free()
	return failures
