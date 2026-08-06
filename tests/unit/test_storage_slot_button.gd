extends RefCounted

const METRICS_PATH := "res://scripts/ui/storage/equipment_ui_metrics.gd"
const PALETTE_PATH := "res://scripts/ui/storage/item_rarity_palette.gd"
const ICON_PATH := "res://assets/ui/equipment/runtime/greenwood/windrunner_band_128.png"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_support_files(failures)
	_test_slot_contract(failures)
	return failures


func _test_support_files(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(METRICS_PATH), "equipment UI metrics exist", failures)
	TestAssertions.truthy(ResourceLoader.exists(PALETTE_PATH), "item rarity palette exists", failures)
	if not ResourceLoader.exists(METRICS_PATH) or not ResourceLoader.exists(PALETTE_PATH):
		return
	var metrics_script: Script = load(METRICS_PATH)
	var at_1080: Dictionary = metrics_script.call("for_viewport", Vector2(1920, 1080))
	var at_1440: Dictionary = metrics_script.call("for_viewport", Vector2(2560, 1440))
	var at_4k: Dictionary = metrics_script.call("for_viewport", Vector2(3840, 2160))
	var compact: Dictionary = metrics_script.call("for_viewport", Vector2(1280, 720))
	TestAssertions.equal(at_1080.get("slot_size"), Vector2(78, 78), "1080p slot metric is exact", failures)
	TestAssertions.near(float(at_1440.get("scale", 0.0)), 4.0 / 3.0, 0.001, "1440p scale is exact", failures)
	TestAssertions.equal(at_4k.get("scale"), 1.6, "4K scale is bounded", failures)
	TestAssertions.equal(compact.get("scale"), 0.82, "720p compatibility scale is bounded", failures)
	var palette_script: Script = load(PALETTE_PATH)
	var colors: Array[Color] = []
	for rarity: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"mythic", &"eternal"]:
		colors.append(palette_script.call("color_for", rarity) as Color)
		TestAssertions.equal(int(palette_script.call("intensity_for", rarity)), colors.size() - 1, "%s intensity is exact" % rarity, failures)
	TestAssertions.equal(_unique_colors(colors), 7, "functional rarities have distinct colors", failures)


func _test_slot_contract(failures: Array[String]) -> void:
	var button := StorageSlotButton.new()
	TestAssertions.truthy(button.has_method("bind_item"), "shared slot exposes icon binding", failures)
	TestAssertions.truthy(button.has_method("set_selected"), "shared slot exposes selected state", failures)
	TestAssertions.truthy(button.has_method("set_held"), "shared slot exposes held state", failures)
	TestAssertions.truthy(button.has_method("set_drop_target"), "shared slot exposes drop-target state", failures)
	TestAssertions.truthy(button.has_signal("inspection_started"), "shared slot exposes inspection start", failures)
	TestAssertions.truthy(button.has_signal("inspection_ended"), "shared slot exposes inspection end", failures)
	if not button.has_method("bind_item"):
		button.free()
		return
	button.call("_ready")
	button.call("bind_item", &"stash-tab-000", 42, "item-1", {
		"name": "Windrunner Band",
		"icon_path": ICON_PATH,
		"rarity_id": "uncommon",
		"rarity_name": "Uncommon",
	})
	TestAssertions.equal(button.text, "", "occupied slot has no number or item-name text", failures)
	TestAssertions.truthy(button.icon != null, "occupied slot loads its real icon", failures)
	TestAssertions.equal(button.tooltip_text, "", "native tooltip cannot compete with item card", failures)
	TestAssertions.truthy(button.accessibility_name.contains("Windrunner Band"), "accessible name keeps item identity", failures)
	var bound_icon := button.icon
	button.call("set_selected", true)
	button.call("set_held", true)
	button.call("set_drop_target", true, false)
	TestAssertions.equal(button.icon, bound_icon, "interaction states preserve the item icon", failures)
	TestAssertions.equal(button.text, "", "interaction states do not add label text", failures)

	button.call("bind_item", &"stash-tab-000", 43, "missing-icon", {
		"name": "Missing Relic",
		"icon_path": "res://missing/icon.png",
		"rarity_id": "rare",
		"rarity_name": "Rare",
	})
	TestAssertions.equal(button.text, "?", "missing icon uses an intentional glyph", failures)
	TestAssertions.truthy(not button.text.contains("Missing Relic") and not button.text.contains("43"), "missing icon hides name and slot number", failures)
	TestAssertions.truthy(button.accessibility_name.contains("icon unavailable"), "missing icon is accessible", failures)

	button.call("bind_item", &"leader-loadout", 8, "", {}, "Ring Left")
	TestAssertions.equal(button.text, "Ring Left", "named empty equipment slot keeps its label", failures)
	TestAssertions.equal(button.icon, null, "empty slot clears item icon", failures)

	button.call("bind_item", &"stash-tab-000", 42, "item-1", {
		"name": "Windrunner Band",
		"icon_path": ICON_PATH,
		"rarity_id": "uncommon",
		"rarity_name": "Uncommon",
	})
	var events: Array[String] = []
	button.inspection_started.connect(func(_source: Variant) -> void: events.append("start"))
	button.inspection_ended.connect(func(_source: Variant) -> void: events.append("end"))
	button.mouse_entered.emit()
	button.focus_entered.emit()
	button.mouse_exited.emit()
	TestAssertions.equal(events, ["start"], "combined mouse and focus lifetime starts once", failures)
	button.focus_exited.emit()
	TestAssertions.equal(events, ["start", "end"], "inspection ends after mouse and focus leave", failures)
	button.free()


func _unique_colors(colors: Array[Color]) -> int:
	var seen: Dictionary = {}
	for color: Color in colors:
		seen[color.to_html()] = true
	return seen.size()
