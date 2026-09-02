extends RefCounted

const NODE_SCENE_PATH := "res://scenes/ui/passive_tree/passive_tree_node_control.tscn"
const SCREEN_SCENE_PATH := "res://scenes/ui/passive_tree/passive_tree_screen.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_node_control_readability_contract(failures)
	_test_selection_resets_detail_scroll(failures)
	return failures


func _test_node_control_readability_contract(failures: Array[String]) -> void:
	var node_control := (load(NODE_SCENE_PATH) as PackedScene).instantiate() as Button
	(Engine.get_main_loop() as SceneTree).root.add_child(node_control)
	TestAssertions.equal(node_control.custom_minimum_size, Vector2(168.0, 120.0), "passive nodes use the approved enlarged uniform footprint", failures)
	TestAssertions.equal(node_control.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "passive node names wrap at word boundaries", failures)
	TestAssertions.equal(node_control.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "passive node names never ellipsize", failures)
	var visual := node_control.find_child("NodeVisual", false, false) as Control
	TestAssertions.truthy(visual != null, "node shape uses a dedicated visual child", failures)
	if visual != null:
		TestAssertions.truthy(visual.show_behind_parent, "node shape renders behind the native button label", failures)
		TestAssertions.equal(visual.mouse_filter, Control.MOUSE_FILTER_IGNORE, "node shape cannot intercept activation", failures)
	for state: StringName in [&"allocated", &"allocatable", &"available", &"obscured"]:
		var view := PassiveTreeNodeViewData.new(&"readability", Vector2.ZERO, &"small", state, "Readable", "Readable", 1, "1")
		node_control.call(&"bind_view", view)
		var font_color := node_control.get_theme_color("font_color")
		var fill_color := _expected_node_fill(state)
		TestAssertions.truthy(_contrast_ratio(font_color, fill_color) >= 4.5, "%s node label meets WCAG AA contrast" % state, failures)
		TestAssertions.truthy(node_control.get_theme_constant("outline_size") >= 2, "%s node label has a legibility outline" % state, failures)
	node_control.free()


func _test_selection_resets_detail_scroll(failures: Array[String]) -> void:
	var screen := (load(SCREEN_SCENE_PATH) as PackedScene).instantiate() as CanvasLayer
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	var detail_scroll := screen.find_child("DetailScroll", true, false) as ScrollContainer
	var detail_body := screen.find_child("DetailBody", true, false) as Control
	detail_body.custom_minimum_size.y = 2000.0
	detail_scroll.scroll_vertical = 180
	TestAssertions.truthy(detail_scroll.scroll_vertical > 0, "detail scroll fixture starts below the top", failures)
	var view := PassiveTreeNodeViewData.new(&"target", Vector2.ZERO, &"small", &"available", "Target", "Target description", 1, "1")
	screen.set("_views", {&"target": view})
	screen.call(&"_on_selection_changed", &"target")
	TestAssertions.equal(detail_scroll.scroll_vertical, 0, "selecting a node resets detail scroll to the top", failures)
	screen.free()


func _contrast_ratio(first: Color, second: Color) -> float:
	var lighter := maxf(_relative_luminance(first), _relative_luminance(second))
	var darker := minf(_relative_luminance(first), _relative_luminance(second))
	return (lighter + 0.05) / (darker + 0.05)


func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) + 0.7152 * _linear_channel(color.g) + 0.0722 * _linear_channel(color.b)


func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


func _expected_node_fill(state: StringName) -> Color:
	match state:
		&"allocated":
			return Color(0.18, 0.72, 0.48, 0.95)
		&"allocatable":
			return Color(0.2, 0.48, 0.88, 0.95)
		&"obscured":
			return Color(0.12, 0.14, 0.2, 0.98)
		_:
			return Color(0.32, 0.34, 0.42, 0.95)
