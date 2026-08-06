extends SceneTree

const PANEL_SCENE := preload("res://scenes/ui/storage/item_tooltip_panel.tscn")
const TARGET_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const COMPATIBILITY_SIZE := Vector2i(1280, 720)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var keep_alive := Timer.new()
	keep_alive.wait_time = 3600.0
	keep_alive.autostart = true
	root.add_child(keep_alive)
	var sizes: Array[Vector2i] = [COMPATIBILITY_SIZE]
	sizes.append_array(TARGET_SIZES)
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	viewport.add_child(host)
	for viewport_size: Vector2i in sizes:
		await _exercise_size(viewport, host, viewport_size)
		if viewport_size == COMPATIBILITY_SIZE:
			print("ITEM_TOOLTIP_COMPATIBILITY_PASS size=1280x720")
		else:
			print("ITEM_TOOLTIP_RESPONSIVE_SIZE_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])
	if _failures.is_empty():
		viewport.free()
		keep_alive.free()
		print("ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("ITEM_TOOLTIP_RESPONSIVE_FAILURE: %s" % failure)
	viewport.free()
	keep_alive.free()
	print("ITEM_TOOLTIP_RESPONSIVE_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _exercise_size(viewport: SubViewport, host: Control, viewport_size: Vector2i) -> void:
	viewport.size = viewport_size
	host.size = viewport_size
	var anchors := _anchors(host, viewport_size)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var cases: Array[Dictionary] = []
	for anchor_index: int in anchors.size():
		var anchor := anchors[anchor_index]
		for comparison_count: int in 3:
			for mode: StringName in [&"normal", &"comparison", &"advanced", &"combined"]:
				var panel := PANEL_SCENE.instantiate() as Control
				host.add_child(panel)
				var comparisons := _comparisons(comparison_count)
				var source_id := StringName("%d_%d_%d_%s" % [viewport_size.x, anchor_index, comparison_count, mode])
				_assert(bool(panel.call("show_item", _detail("inspected"), comparisons, anchor, source_id, false)), "item opens %s" % source_id)
				panel.call("set_compare_active", mode in [&"comparison", &"combined"])
				panel.call("set_advanced_active", mode in [&"advanced", &"combined"])
				var expected_cards := comparison_count + 1 if mode in [&"comparison", &"combined"] else 1
				var context := "%dx%d edge=%d comparisons=%d mode=%s" % [viewport_size.x, viewport_size.y, anchor_index, comparison_count, mode]
				cases.append({"panel": panel, "expected_cards": expected_cards, "context": context})
	await _wait_for_layout()
	for case: Dictionary in cases:
		var panel := case["panel"] as Control
		var context := String(case["context"])
		var tooltip_rect := panel.get_global_rect()
		_assert(viewport_rect.grow(0.5).encloses(tooltip_rect), "tooltip remains inside viewport at %s rect=%s" % [context, tooltip_rect])
		_assert(int(panel.call("card_count")) == int(case["expected_cards"]), "all comparison candidates remain visible at %s" % context)
		var pin_rect := panel.call("pin_button_rect") as Rect2
		var scrollbar_rect := panel.call("scrollbar_rect") as Rect2
		_assert(tooltip_rect.grow(0.5).encloses(pin_rect), "pin remains reachable at %s" % context)
		_assert(tooltip_rect.grow(0.5).encloses(scrollbar_rect), "scrollbar remains reachable at %s" % context)
		_assert(viewport_rect.grow(0.5).encloses(scrollbar_rect), "scrollbar remains inside viewport at %s" % context)
		var first_card := panel.get_node("Layout/BodyScroll/Cards").get_child(0) as Control
		var rendered := String(first_card.call("rendered_text"))
		_assert(not rendered.contains("inspected-instance-id"), "Player Mode hides technical identifiers at %s" % context)
		panel.free()
	for anchor: Control in anchors:
		anchor.free()


func _anchors(host: Control, viewport_size: Vector2i) -> Array[Control]:
	var positions: Array[Vector2] = [
		Vector2(8.0, 8.0),
		Vector2(viewport_size.x - 86.0, 8.0),
		Vector2(8.0, viewport_size.y - 86.0),
		Vector2(viewport_size.x - 86.0, viewport_size.y - 86.0),
	]
	var result: Array[Control] = []
	for index: int in positions.size():
		var anchor := Button.new()
		anchor.name = "EdgeAnchor%d" % index
		anchor.position = positions[index]
		anchor.size = Vector2(78.0, 78.0)
		host.add_child(anchor)
		result.append(anchor)
	return result


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _comparisons(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in count:
		result.append({
			"slot_id": "ring_%s" % ("left" if index == 0 else "right"),
			"item": _detail("equipped_%d" % index),
			"delta_lines": [{
				"stat_id": "constitution",
				"operation": StatModifier.Operation.FLAT,
				"delta": 2.0 - index,
				"direction": 1,
				"text": "+%d Constitution" % (2 - index),
			}],
		})
	return result


func _detail(name: String) -> Dictionary:
	var affixes: Array[Dictionary] = []
	for index: int in 24:
		affixes.append({
			"definition_id": "of_embers_%02d" % index,
			"display_name": "of Embers %02d" % index,
			"affix_kind": "suffix",
			"tier": 3,
			"rolls": [{
				"stat_id": "fire_damage",
				"stat_name": "Fire Damage",
				"operation": StatModifier.Operation.INCREASED,
				"operation_name": "Increased",
				"value": 0.18,
				"effect_text": "18% increased Fire Damage",
				"minimum_roll": 0.15,
				"maximum_roll": 0.20,
				"roll_fraction": 0.60,
			}],
		})
	return {
		"instance_id": "inspected-instance-id" if name == "inspected" else name,
		"base_definition_id": "windrunner_band",
		"name": name.capitalize(),
		"item_type_id": "ring",
		"rarity_id": "rare",
		"rarity_name": "Rare",
		"item_level": 31,
		"compatible_slot_ids": ["ring_left", "ring_right"],
		"handedness_id": "none",
		"requirement_lines": PackedStringArray(["Requires Dexterity 12"]),
		"equip_warning_lines": PackedStringArray(),
		"core_value_lines": PackedStringArray(["12 Armour"]),
		"affixes": affixes,
	}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
