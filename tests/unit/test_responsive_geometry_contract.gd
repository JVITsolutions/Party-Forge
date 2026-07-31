extends RefCounted

const GEOMETRY_PATH := "res://tests/support/responsive_geometry.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(GEOMETRY_PATH), "responsive geometry helper exists", failures)
	if not ResourceLoader.exists(GEOMETRY_PATH):
		return failures
	var geometry := load(GEOMETRY_PATH) as Script
	TestAssertions.truthy(geometry != null and geometry.can_instantiate(), "responsive geometry helper loads", failures)
	if geometry == null or not geometry.can_instantiate():
		return failures
	_test_anchor_offset_rect(geometry, failures)
	_test_containment_edges(geometry, failures)
	return failures


func _test_anchor_offset_rect(geometry: Script, failures: Array[String]) -> void:
	var control := Control.new()
	control.anchor_left = 0.25
	control.anchor_top = 0.5
	control.anchor_right = 0.75
	control.anchor_bottom = 1.0
	control.offset_left = 5.0
	control.offset_top = -10.0
	control.offset_right = -15.0
	control.offset_bottom = -20.0
	var parent := Rect2(10.0, 20.0, 1000.0, 800.0)
	TestAssertions.equal(
		geometry.call(&"control_rect", control, parent),
		Rect2(265.0, 410.0, 480.0, 390.0),
		"geometry combines parent origin, anchors, and offsets",
		failures,
	)
	control.free()


func _test_containment_edges(geometry: Script, failures: Array[String]) -> void:
	var outer := Rect2(0.0, 0.0, 100.0, 80.0)
	TestAssertions.truthy(bool(geometry.call(&"contains", outer, Rect2(0.0, 0.0, 100.0, 80.0))), "exact edges are contained", failures)
	TestAssertions.truthy(not bool(geometry.call(&"contains", outer, Rect2(-1.0, 0.0, 20.0, 20.0))), "left overflow is rejected", failures)
	TestAssertions.truthy(not bool(geometry.call(&"contains", outer, Rect2(0.0, 61.0, 20.0, 20.0))), "bottom overflow is rejected", failures)
