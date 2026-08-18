extends RefCounted

const PANEL_SCENE_PATH := "res://scenes/ui/storage/item_tooltip_panel.tscn"
const ICON_PATH := "res://assets/ui/equipment/runtime/greenwood/windrunner_band_128.png"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(PANEL_SCENE_PATH), "item tooltip panel scene exists", failures)
	if not ResourceLoader.exists(PANEL_SCENE_PATH):
		return failures
	var scene := load(PANEL_SCENE_PATH) as PackedScene
	TestAssertions.truthy(scene != null, "item tooltip panel scene loads", failures)
	if scene == null:
		return failures
	_test_layer_and_pin_lifecycle(scene, failures)
	_test_aggregate_transparency_and_pointer_surfaces(scene, failures)
	_test_dismissal_grace(scene, failures)
	return failures


func _test_layer_and_pin_lifecycle(scene: PackedScene, failures: Array[String]) -> void:
	var fixture := _fixture(scene)
	var panel: Control = fixture["panel"]
	var anchor: Control = fixture["anchor"]
	var comparisons: Array[Dictionary] = [
		{"slot_id": "ring_left", "item": _detail("left-ring"), "delta_lines": _delta_lines(3.0)},
		{"slot_id": "ring_right", "item": _detail("right-ring"), "delta_lines": _delta_lines(-2.0)},
	]
	TestAssertions.truthy(bool(panel.call("show_item", _detail("inspected"), comparisons, anchor, &"inspected", true)), "first item is accepted", failures)
	TestAssertions.equal(int(panel.call("card_count")), 1, "normal layer starts with one card", failures)
	panel.call("set_compare_active", true)
	TestAssertions.equal(int(panel.call("card_count")), 3, "comparison layer includes both equipped rings", failures)
	panel.call("set_advanced_active", true)
	TestAssertions.truthy(bool(panel.call("comparison_active")), "comparison query is active", failures)
	TestAssertions.truthy(bool(panel.call("advanced_active")), "advanced query is active", failures)
	panel.call("toggle_pin")
	panel.call("release_item", &"inspected")
	panel.call("_process", 0.13)
	panel.call("set_compare_active", false)
	panel.call("set_advanced_active", false)
	TestAssertions.truthy(panel.visible and bool(panel.call("is_pinned")), "main card remains pinned after source release", failures)
	TestAssertions.equal(int(panel.call("card_count")), 1, "temporary comparison cards collapse while pinned", failures)
	TestAssertions.truthy(not bool(panel.call("advanced_active")), "advanced layer collapses while pinned", failures)
	var no_comparisons: Array[Dictionary] = []
	TestAssertions.truthy(not bool(panel.call("show_item", _detail("other"), no_comparisons, anchor, &"other", false)), "pinned card rejects replacement", failures)
	TestAssertions.equal(String(panel.call("current_source_id")), "inspected", "rejected replacement preserves pinned source", failures)
	panel.call("toggle_pin")
	TestAssertions.truthy(not panel.visible and not bool(panel.call("is_pinned")), "unpinning inactive card dismisses", failures)
	(fixture["host"] as Control).free()


func _test_aggregate_transparency_and_pointer_surfaces(scene: PackedScene, failures: Array[String]) -> void:
	var fixture := _fixture(scene)
	var panel: Control = fixture["panel"]
	var no_comparisons: Array[Dictionary] = []
	panel.call("show_item", _detail("inspected"), no_comparisons, fixture["anchor"], &"inspected", false)
	var card := panel.get_node("Layout/BodyScroll/Cards").get_child(0) as Control
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var card_style := card.get_theme_stylebox("panel") as StyleBoxFlat
	TestAssertions.truthy(panel_style != null and card_style != null, "tooltip panel and card expose inspectable backgrounds", failures)
	if panel_style != null and card_style != null:
		var outer_alpha := panel_style.bg_color.a
		var inner_alpha := card_style.bg_color.a
		var outer_owns_background := outer_alpha >= 0.80 and outer_alpha <= 0.88 and inner_alpha <= 0.05
		var inner_owns_background := inner_alpha >= 0.80 and inner_alpha <= 0.88 and outer_alpha <= 0.05
		TestAssertions.truthy(outer_owns_background or inner_owns_background, "tooltip has one 80-88 percent dark background without stacked opacity", failures)
	var icon := card.get_node_or_null("Layout/Header/Icon") as TextureRect
	TestAssertions.truthy(icon != null and icon.texture != null and icon.texture.resource_path == ICON_PATH, "first shared panel card renders the projected icon", failures)
	for label_path: String in ["Layout/Header/Context", "Layout/InputHints"]:
		var label := panel.get_node(label_path) as Label
		TestAssertions.equal(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s decorative panel label ignores pointer input" % label.name, failures)
	TestAssertions.equal((panel.get_node("Layout/Header/Pin") as Button).mouse_filter, Control.MOUSE_FILTER_STOP, "pin remains a pointer interaction surface", failures)
	TestAssertions.equal((panel.get_node("Layout/BodyScroll") as ScrollContainer).mouse_filter, Control.MOUSE_FILTER_STOP, "scroll body remains a pointer interaction surface", failures)
	(fixture["host"] as Control).free()


func _test_dismissal_grace(scene: PackedScene, failures: Array[String]) -> void:
	var fixture := _fixture(scene)
	var panel: Control = fixture["panel"]
	var anchor: Control = fixture["anchor"]
	var no_comparisons: Array[Dictionary] = []
	panel.call("show_item", _detail("grace"), no_comparisons, anchor, &"grace", false)
	panel.call("release_item", &"grace")
	panel.call("_process", 0.05)
	TestAssertions.truthy(panel.visible, "card remains during dismissal grace", failures)
	panel.call("show_item", _detail("grace"), no_comparisons, anchor, &"grace", false)
	panel.call("_process", 0.13)
	TestAssertions.truthy(panel.visible, "same-source reentry cancels dismissal", failures)
	panel.call("release_item", &"grace")
	panel.call("_process", 0.13)
	TestAssertions.truthy(not panel.visible, "inactive unpinned card dismisses after grace", failures)
	(fixture["host"] as Control).free()


func _fixture(scene: PackedScene) -> Dictionary:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	var anchor := Button.new()
	anchor.position = Vector2(300, 180)
	anchor.size = Vector2(78, 78)
	host.add_child(anchor)
	var panel: Control = scene.instantiate()
	host.add_child(panel)
	panel.call("_ready")
	return {"host": host, "anchor": anchor, "panel": panel}


func _detail(instance_id: String) -> Dictionary:
	return {
		"instance_id": instance_id,
		"base_definition_id": "windrunner_band",
		"icon_path": ICON_PATH,
		"name": instance_id.capitalize(),
		"item_type_id": "ring",
		"rarity_id": "rare",
		"rarity_name": "Rare",
		"item_level": 31,
		"compatible_slot_ids": ["ring_left", "ring_right"],
		"handedness_id": "none",
		"requirement_lines": PackedStringArray(),
		"equip_warning_lines": PackedStringArray(),
		"core_value_lines": PackedStringArray(),
		"affixes": [],
	}


func _delta_lines(value: float) -> Array[Dictionary]:
	return [{
		"stat_id": "constitution",
		"operation": StatModifier.Operation.FLAT,
		"delta": value,
		"direction": 1 if value > 0.0 else -1 if value < 0.0 else 0,
		"text": "%s Constitution" % value,
	}]
