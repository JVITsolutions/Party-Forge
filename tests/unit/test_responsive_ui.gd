extends RefCounted

const VIEWPORT_SIZES := [
	Vector2(1280.0, 720.0),
	Vector2(1920.0, 1080.0),
	Vector2(3840.0, 2160.0),
]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_project_display_contract(failures)
	_test_responsive_hud_layout(failures)
	return failures

func _test_project_display_contract(failures: Array[String]) -> void:
	TestAssertions.equal(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		1920,
		"logical viewport width is 1920",
		failures,
	)
	TestAssertions.equal(
		int(ProjectSettings.get_setting("display/window/size/viewport_height")),
		1080,
		"logical viewport height is 1080",
		failures,
	)
	TestAssertions.equal(
		str(ProjectSettings.get_setting("display/window/stretch/mode")),
		"canvas_items",
		"UI uses canvas_items stretch mode",
		failures,
	)
	TestAssertions.equal(
		ProjectSettings.has_setting("display/window/stretch/aspect"),
		true,
		"UI stretch aspect is explicitly configured",
		failures,
	)
	TestAssertions.equal(
		str(ProjectSettings.get_setting("display/window/stretch/aspect")),
		"keep",
		"UI preserves the 16:9 aspect ratio",
		failures,
	)

func _test_responsive_hud_layout(failures: Array[String]) -> void:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	var status_margin := hud.get_node("Margin") as Control
	var boss_banner := hud.get_node("BossBanner") as Control
	var class_selection := hud.get_node("ClassSelection") as Control
	var level_up := hud.get_node("LevelUpPanel") as Control
	var result_root := hud.get_node("RunResultPanel") as Control
	var result_panel := hud.get_node("RunResultPanel/Panel") as Control
	_assert_full_rect(result_root, "run result overlay", failures)
	_assert_center_anchors(class_selection, "class selection", failures)
	_assert_center_anchors(level_up, "level-up panel", failures)
	_assert_center_anchors(result_panel, "run result panel", failures)
	_assert_size(boss_banner, Vector2(500.0, 70.0), "boss banner", failures)

	for viewport_size: Vector2 in VIEWPORT_SIZES:
		_assert_centered(class_selection, viewport_size, "class selection", failures)
		_assert_centered(level_up, viewport_size, "level-up panel", failures)
		_assert_centered(result_panel, viewport_size, "run result panel", failures)
		_assert_size(class_selection, Vector2(540.0, 320.0), "class selection", failures)
		_assert_size(level_up, Vector2(700.0, 190.0), "level-up panel", failures)
		_assert_size(result_panel, Vector2(400.0, 260.0), "run result panel", failures)
		TestAssertions.near(
			_rect_center(boss_banner, viewport_size).x,
			viewport_size.x * 0.5,
			0.01,
			"boss banner is horizontally centered at %s" % viewport_size,
			failures,
		)
		TestAssertions.near(
			_rect_top_left(boss_banner, viewport_size).y,
			80.0,
			0.01,
			"boss banner retains top margin at %s" % viewport_size,
			failures,
		)
		var status_position := _rect_top_left(status_margin, viewport_size)
		TestAssertions.near(status_position.x, 16.0, 0.01, "status HUD retains left margin at %s" % viewport_size, failures)
		TestAssertions.near(status_position.y, 16.0, 0.01, "status HUD retains top margin at %s" % viewport_size, failures)

	hud.free()

func _assert_centered(control: Control, viewport_size: Vector2, label: String, failures: Array[String]) -> void:
	var center := _rect_center(control, viewport_size)
	TestAssertions.near(center.x, viewport_size.x * 0.5, 0.01, "%s center x at %s" % [label, viewport_size], failures)
	TestAssertions.near(center.y, viewport_size.y * 0.5, 0.01, "%s center y at %s" % [label, viewport_size], failures)

func _assert_center_anchors(control: Control, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(
		Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom),
		Vector4(0.5, 0.5, 0.5, 0.5),
		"%s uses exact center anchors" % label,
		failures,
	)

func _assert_size(control: Control, expected: Vector2, label: String, failures: Array[String]) -> void:
	var logical_size := Vector2(control.offset_right - control.offset_left, control.offset_bottom - control.offset_top)
	TestAssertions.equal(logical_size, expected, "%s retains logical size" % label, failures)

func _assert_full_rect(control: Control, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(
		Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom),
		Vector4(0.0, 0.0, 1.0, 1.0),
		"%s anchors cover its parent" % label,
		failures,
	)
	TestAssertions.equal(
		Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom),
		Vector4.ZERO,
		"%s has no edge offsets" % label,
		failures,
	)

func _rect_center(control: Control, viewport_size: Vector2) -> Vector2:
	var top_left := _rect_top_left(control, viewport_size)
	var bottom_right := Vector2(
		viewport_size.x * control.anchor_right + control.offset_right,
		viewport_size.y * control.anchor_bottom + control.offset_bottom,
	)
	return (top_left + bottom_right) * 0.5

func _rect_top_left(control: Control, viewport_size: Vector2) -> Vector2:
	return Vector2(
		viewport_size.x * control.anchor_left + control.offset_left,
		viewport_size.y * control.anchor_top + control.offset_top,
	)
