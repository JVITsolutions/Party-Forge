extends RefCounted

const VIEWPORTS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160), Vector2i(2560, 1080)]
const PARTY_COUNTS: Array[int] = [1, 6, 7, 12, 20, 24]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_mode_boundaries_and_final_pages(failures)
	_test_supported_viewports_and_scale_corners(failures)
	_test_party_header_reservation(failures)
	return failures


func _test_mode_boundaries_and_final_pages(failures: Array[String]) -> void:
	for count: int in [1, 6]:
		TestAssertions.equal(CombatHudResponsiveLayout.resolve(Vector2i(1920, 1080), 100, 100, count).mode, CombatHudResponsiveLayout.Mode.RICH, "one through six use rich mode", failures)
	for count: int in [7, 12, 20, 24]:
		var metrics := CombatHudResponsiveLayout.resolve(Vector2i(1280, 720), 150, 150, count)
		TestAssertions.equal(metrics.mode, CombatHudResponsiveLayout.Mode.COMPACT, "seven through twenty-four use compact mode", failures)
		TestAssertions.truthy(metrics.visible_member_count > 0, "compact view has a bounded visible window", failures)
		TestAssertions.equal(metrics.clamped_page(metrics.page_count - 1), metrics.page_count - 1, "final page is reachable", failures)
		TestAssertions.equal(metrics.clamped_page(999), metrics.page_count - 1, "page clamping never hides the final member", failures)


func _test_supported_viewports_and_scale_corners(failures: Array[String]) -> void:
	for viewport_size: Vector2i in VIEWPORTS:
		for count: int in PARTY_COUNTS:
			var metrics := CombatHudResponsiveLayout.resolve(viewport_size, 100, 100, count)
			TestAssertions.truthy(metrics.visible_member_count >= 1 and metrics.visible_member_count <= count, "default layout bounds its visible member count at %s for %d members" % [viewport_size, count], failures)
			TestAssertions.truthy(metrics.column_count >= 1, "layout has at least one column at %s" % viewport_size, failures)
			TestAssertions.truthy(metrics.page_count >= 1, "layout has at least one page at %s" % viewport_size, failures)
			TestAssertions.equal(metrics.clamped_page(-1), 0, "negative pages clamp to the first page at %s" % viewport_size, failures)
			TestAssertions.equal(metrics.clamped_page(metrics.page_count), metrics.page_count - 1, "pages beyond the end clamp to the final page at %s" % viewport_size, failures)

	for scales: Vector2i in [Vector2i(150, 150), Vector2i(80, 150), Vector2i(150, 100), Vector2i(100, 150), Vector2i(80, 80)]:
		var metrics := CombatHudResponsiveLayout.resolve(Vector2i(1280, 720), scales.x, scales.y, 24)
		TestAssertions.equal(metrics.mode, CombatHudResponsiveLayout.Mode.COMPACT, "scaled small viewport retains compact mode", failures)
		TestAssertions.truthy(metrics.visible_member_count >= 1 and metrics.visible_member_count <= 24, "scaled small viewport retains a bounded visible window", failures)
		TestAssertions.equal(metrics.clamped_page(metrics.page_count - 1), metrics.page_count - 1, "scaled small viewport keeps the final page reachable", failures)


func _test_party_header_reservation(failures: Array[String]) -> void:
	var layout_script := load("res://scripts/ui/hud/combat_hud_responsive_layout.gd") as Script
	var resolve_argument_count := 0
	for method: Dictionary in layout_script.get_script_method_list():
		if StringName(method.get(&"name", &"")) == &"resolve":
			resolve_argument_count = (method.get(&"args", []) as Array).size()
			break
	TestAssertions.equal(resolve_argument_count, 5, "responsive layout accepts measured Party header height", failures)
	if resolve_argument_count != 5:
		return
	for scales: Vector2i in [Vector2i(80, 150), Vector2i(100, 150), Vector2i(150, 150)]:
		var without_header := layout_script.call(&"resolve", Vector2i(1280, 720), scales.x, scales.y, 24, 0.0) as CombatHudResponsiveLayout.Metrics
		var with_header := layout_script.call(&"resolve", Vector2i(1280, 720), scales.x, scales.y, 24, 72.0) as CombatHudResponsiveLayout.Metrics
		TestAssertions.equal(with_header.mode, CombatHudResponsiveLayout.Mode.COMPACT, "Text150 with header remains compact", failures)
		TestAssertions.truthy(with_header.visible_member_count <= without_header.visible_member_count, "header reservation never overstates visible members", failures)
		TestAssertions.truthy(with_header.visible_member_count >= 1 and with_header.page_count >= 1, "header reservation remains bounded", failures)
