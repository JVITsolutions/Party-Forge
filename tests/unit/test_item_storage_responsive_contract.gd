extends RefCounted

const SANDBOX_SCENE_PATH := "res://scenes/ui/developer_item_sandbox.tscn"
const MANIFEST_HELPER_PATH := "res://tests/support/task10_filesystem_manifest.gd"
const MANIFEST_FIXTURE_ROOT := "user://task10_manifest_contract"
const RUNNER_PATHS: Array[String] = [
	"res://tests/integration/developer_item_sandbox_runner.gd",
	"res://tests/integration/item_storage_profile_runner.gd",
	"res://tests/integration/item_storage_performance_runner.gd",
	"res://tests/integration/developer_loot_lab_runner.gd",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	for path: String in RUNNER_PATHS:
		TestAssertions.truthy(ResourceLoader.exists(path), "Task 10 runner exists: %s" % path, failures)
	_assert_review_contracts(failures)
	_assert_manifest_sentinel_detection(failures)
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
	var body := sandbox.get_node("Overlay/Frame/Layout/Tabs/Equipment/Body") as BoxContainer
	var frame := sandbox.get_node("Overlay/Frame") as Control
	var lab := sandbox.get_node("Overlay/Frame/Layout/Tabs/Loot Lab") as DeveloperLootLab
	var workbench := lab.get_node("Layout/Workbench") as BoxContainer
	var pane_selectors := lab.get_node("Layout/PaneSelectors") as Control
	var gallery := lab.get_node("Layout/Workbench/Results/SampleScroll/SampleGrid") as GridContainer
	sandbox.call(&"apply_viewport_size", Vector2i(1920, 1080))
	TestAssertions.truthy(not body.vertical, "desktop sandbox body is horizontal", failures)
	TestAssertions.truthy(not workbench.vertical and not pane_selectors.visible and gallery.columns == 4, "1080p Loot Lab keeps three panes and four sample columns", failures)
	sandbox.call(&"apply_viewport_size", Vector2i(2560, 1440))
	TestAssertions.equal(gallery.columns, 6, "1440p Loot Lab adds sample columns without typography scaling", failures)
	sandbox.call(&"apply_viewport_size", Vector2i(3840, 2160))
	TestAssertions.equal(gallery.columns, 8, "4K Loot Lab adds sample columns without typography scaling", failures)
	sandbox.call(&"apply_viewport_size", Vector2i(1920, 1080))
	TestAssertions.equal(
		Vector4(frame.offset_left, frame.offset_top, frame.offset_right, frame.offset_bottom),
		Vector4(48.0, 36.0, -48.0, -36.0),
		"desktop sandbox uses established safe margins",
		failures
	)
	sandbox.call(&"apply_viewport_size", Vector2i(1099, 1080))
	TestAssertions.truthy(body.vertical, "sandbox uses the shared compact width breakpoint", failures)
	TestAssertions.truthy(workbench.vertical and pane_selectors.visible, "compact Loot Lab switches to one-pane selectors", failures)
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


func _assert_review_contracts(failures: Array[String]) -> void:
	var profile_source := FileAccess.get_file_as_string(RUNNER_PATHS[1])
	var performance_source := FileAccess.get_file_as_string(RUNNER_PATHS[2])
	var ui_source := FileAccess.get_file_as_string(RUNNER_PATHS[0])
	TestAssertions.truthy("profile_root_manifest_before" in profile_source and "profile root recursive manifest remains exact" in profile_source, "profile isolation runner compares an exact recursive root manifest", failures)
	TestAssertions.truthy("sandbox confinement manifest" in profile_source, "profile isolation runner validates the sandbox confinement manifest", failures)
	TestAssertions.truthy("root.mode = Window.MODE_WINDOWED" in ui_source and "content_scale_size" in ui_source and "root.size == viewport_size" in ui_source, "sandbox UI runner binds every resolution marker to exact physical window geometry and the logical canvas policy", failures)
	for runner_source: String in [ui_source, profile_source, performance_source]:
		TestAssertions.truthy("cleanup removes every Task 10 root before summary" in runner_source, "Task 10 runner verifies cleanup before its summary marker", failures)
	var ui_cleanup_position := ui_source.find("cleanup removes every Task 10 root before summary")
	var ui_resolution_pass_position := ui_source.find("ITEM_SANDBOX_RESOLUTION_PASS")
	TestAssertions.truthy(ui_cleanup_position >= 0 and ui_resolution_pass_position > ui_cleanup_position, "sandbox UI defers every resolution PASS marker until after cleanup", failures)


func _assert_manifest_sentinel_detection(failures: Array[String]) -> void:
	ProfileTestSupport.remove_tree(MANIFEST_FIXTURE_ROOT)
	TestAssertions.truthy(ResourceLoader.exists(MANIFEST_HELPER_PATH), "Task 10 recursive filesystem manifest helper exists", failures)
	if not ResourceLoader.exists(MANIFEST_HELPER_PATH):
		return
	var helper_script := load(MANIFEST_HELPER_PATH) as Script
	var helper := helper_script.new() as RefCounted
	var helper_source := FileAccess.get_file_as_string(MANIFEST_HELPER_PATH)
	var supports_error_injection := "list_begin_override: Callable" in helper_source and "parent_open_override: Callable" in helper_source
	TestAssertions.truthy(supports_error_injection, "filesystem manifest exposes list-begin and parent-open error injection for focused test support", failures)
	var supports_reported_link := "link_result_override: Callable" in helper_source
	TestAssertions.truthy(supports_reported_link, "filesystem manifest exposes a reported-link result seam for focused test support", failures)
	var absolute_root := ProjectSettings.globalize_path(MANIFEST_FIXTURE_ROOT)
	TestAssertions.truthy(DirAccess.make_dir_recursive_absolute(absolute_root) in [OK, ERR_ALREADY_EXISTS], "manifest fixture root is created", failures)
	_write_fixture_file(MANIFEST_FIXTURE_ROOT.path_join("baseline.dat"), PackedByteArray([65, 65, 65, 65]), failures)
	var nested_root := MANIFEST_FIXTURE_ROOT.path_join("nested")
	var absolute_nested := ProjectSettings.globalize_path(nested_root).simplify_path()
	TestAssertions.truthy(DirAccess.make_dir_recursive_absolute(absolute_nested) in [OK, ERR_ALREADY_EXISTS], "nested manifest fixture directory is created", failures)
	_write_fixture_file(nested_root.path_join("nested.dat"), PackedByteArray([78, 69, 83, 84]), failures)
	if supports_error_injection:
		_assert_manifest_failure_injection(helper, absolute_root.simplify_path(), absolute_nested, supports_reported_link, failures)
	var baseline := helper.call(&"capture", MANIFEST_FIXTURE_ROOT) as Dictionary
	_write_fixture_file(MANIFEST_FIXTURE_ROOT.path_join("sentinel.extra"), PackedByteArray([83]), failures)
	var with_extra := helper.call(&"capture", MANIFEST_FIXTURE_ROOT) as Dictionary
	TestAssertions.truthy(not bool(helper.call(&"equivalent", baseline, with_extra)), "recursive manifest detects a sentinel extra file", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST_FIXTURE_ROOT.path_join("sentinel.extra")))
	_write_fixture_file(MANIFEST_FIXTURE_ROOT.path_join("baseline.dat"), PackedByteArray([66, 66, 66, 66]), failures)
	var with_same_length_change := helper.call(&"capture", MANIFEST_FIXTURE_ROOT) as Dictionary
	TestAssertions.truthy(not bool(helper.call(&"equivalent", baseline, with_same_length_change)), "recursive manifest detects a same-length file byte change by SHA-256", failures)
	ProfileTestSupport.remove_tree(MANIFEST_FIXTURE_ROOT)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(absolute_root), "manifest contract fixture cleans up", failures)


func _assert_manifest_failure_injection(helper: RefCounted, absolute_root: String, absolute_nested: String, supports_reported_link: bool, failures: Array[String]) -> void:
	var begun_paths: Array[String] = []
	var list_failure := helper.call(
		&"capture",
		MANIFEST_FIXTURE_ROOT,
		func(absolute_directory: String) -> Error:
			begun_paths.append(absolute_directory)
			return ERR_CANT_OPEN if absolute_directory == absolute_nested else OK,
		Callable()
	) as Dictionary
	TestAssertions.equal(
		String(list_failure.get("error", "")),
		"cannot begin manifest directory listing code=%d path=%s" % [ERR_CANT_OPEN, absolute_nested],
		"filesystem manifest propagates a stable selectively injected nested list-begin error",
		failures
	)
	TestAssertions.equal(begun_paths, [absolute_root, absolute_nested], "list-begin seam observes real root traversal before selectively failing the nested directory", failures)
	TestAssertions.equal(list_failure.get("entries", []), [], "nested list-begin failure discards every previously accumulated root entry", failures)
	var opened_parent_paths: Array[String] = []
	var parent_failure := helper.call(
		&"capture",
		MANIFEST_FIXTURE_ROOT,
		Callable(),
		func(absolute_parent: String) -> Variant:
			opened_parent_paths.append(absolute_parent)
			return null if absolute_parent == absolute_nested else DirAccess.open(absolute_parent)
	) as Dictionary
	TestAssertions.equal(
		String(parent_failure.get("error", "")),
		"cannot inspect manifest link because parent cannot open: %s" % absolute_nested,
		"filesystem manifest propagates a stable descendant parent-open error after root traversal",
		failures
	)
	TestAssertions.truthy(absolute_nested in opened_parent_paths, "parent-open seam reaches the exact descendant parent", failures)
	TestAssertions.equal(parent_failure.get("entries", []), [], "descendant parent-open failure discards every previously accumulated root entry", failures)
	if not supports_reported_link:
		return
	var reported_link_path := absolute_nested.path_join("nested.dat").simplify_path()
	var link_failure := helper.call(
		&"capture",
		MANIFEST_FIXTURE_ROOT,
		Callable(),
		Callable(),
		func(absolute_path: String) -> Dictionary:
			return {"error": "", "is_link": absolute_path == reported_link_path}
	) as Dictionary
	TestAssertions.equal(
		String(link_failure.get("error", "")),
		"manifest entry is a link/reparse point: %s" % reported_link_path,
		"filesystem manifest rejects a selectively reported descendant link",
		failures
	)
	TestAssertions.equal(link_failure.get("entries", []), [], "reported descendant link discards every previously accumulated entry", failures)


func _write_fixture_file(path: String, bytes: PackedByteArray, failures: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	TestAssertions.truthy(file != null, "manifest fixture file opens: %s" % path, failures)
	if file == null:
		return
	file.store_buffer(bytes)
	var error := file.get_error()
	file.close()
	TestAssertions.equal(error, OK, "manifest fixture file writes: %s" % path, failures)
