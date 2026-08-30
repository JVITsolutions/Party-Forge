extends RefCounted

const PANEL_SCENE := "res://scenes/ui/run_result/terminal_extraction_panel.tscn"
const ITEM_TYPE_PATH := "res://scripts/ui/run_result/terminal_extraction_item_projection.gd"
const PROJECTION_TYPE_PATH := "res://scripts/ui/run_result/terminal_extraction_projection.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var packed := load(PANEL_SCENE) as PackedScene
	var item_type := load(ITEM_TYPE_PATH) as Script
	var projection_type := load(PROJECTION_TYPE_PATH) as Script
	TestAssertions.truthy(packed != null, "terminal extraction panel scene exists", failures)
	TestAssertions.truthy(item_type != null and projection_type != null, "terminal extraction panel typed projection exists", failures)
	if packed == null or item_type == null or projection_type == null:
		return failures
	var panel := packed.instantiate() as Control
	TestAssertions.truthy(panel != null, "terminal extraction panel instantiates", failures)
	if panel == null:
		return failures
	var projection: Variant = _projection(item_type, projection_type, 24, 3)
	panel.call(&"present", projection)
	TestAssertions.equal((panel.get_node("Frame/Content/Header/Title") as Label).text, "Choose up to 3 items to extract", "header names capacity", failures)
	TestAssertions.equal((panel.get_node("Frame/Content/Summary/Automatic") as Label).text, "Automatic 1", "automatic count is persistent", failures)
	TestAssertions.equal((panel.get_node("Frame/Content/Summary/Selected") as Label).text, "Selected 0 / 3", "selected count is persistent", failures)
	TestAssertions.equal((panel.get_node("Frame/Content/Summary/Lost") as Label).text, "Will be lost 24", "loss count is persistent", failures)
	var automatic := panel.get_node("Frame/Content/Body/Automatic/Items") as Container
	var eligible := panel.get_node("Frame/Content/Body/Eligible/Scroll/Grid") as Container
	TestAssertions.equal(automatic.get_child_count(), 1, "automatic locked group is visible", failures)
	TestAssertions.equal(eligible.get_child_count(), 24, "all 24 eligible items are reachable in the scroll grid", failures)
	if eligible.get_child_count() == 24:
		var first := eligible.get_child(0) as Control
		var last := eligible.get_child(23) as Control
		TestAssertions.equal(String(first.get_meta(&"item_id", "")), "eligible-01", "first stable item identity is exact", failures)
		TestAssertions.equal(String(last.get_meta(&"item_id", "")), "eligible-24", "final stable item identity is reachable", failures)
		TestAssertions.truthy(first.custom_minimum_size.x >= 48.0 and first.custom_minimum_size.y >= 48.0, "item action target is at least 48 px", failures)
		TestAssertions.truthy(first.accessibility_description.contains("Not selected"), "selection has a non-color accessibility state", failures)
		first.call(&"set_selected", true)
		TestAssertions.truthy(first.accessibility_description.contains("Selected"), "selected state has explicit non-color copy", failures)
	var preflight := RunResolutionPreflightResult.failure("internal diagnostic", RunResolutionEvaluation.FailureCategory.STASH_REDUCIBLE, "Stash needs 4 open slots; 2 are available. Reduce selected items.")
	panel.call(&"show_preflight", preflight)
	TestAssertions.equal((panel.get_node("Frame/Content/PlayerError") as Label).text, preflight.player_reason, "typed player reason is presented without diagnostic parsing", failures)
	TestAssertions.truthy((panel.get_node("Frame/Content/Actions/Confirm") as Button).disabled, "invalid confirmation is disabled", failures)
	TestAssertions.truthy(panel.get_node_or_null("ReturnToCombat") == null, "terminal panel has no combat route", failures)
	panel.free()
	return failures

func _projection(item_type: Script, projection_type: Script, count: int, capacity: int) -> Variant:
	var automatic: Array = [item_type.call(&"create", "automatic-01", "Forge Vanguard Sword", "Common", &"common", "Asha", "Leader Equipment", true, false, false, {"name": "Forge Vanguard Sword"}, [])]
	var eligible: Array = []
	var lost: Array[String] = []
	for index: int in count:
		var item_id := "eligible-%02d" % (index + 1)
		eligible.append(item_type.call(&"create", item_id, "Item %02d" % (index + 1), "Common", &"common", "Run Inventory", "Run Inventory", false, false, true, {"name": "Item %02d" % (index + 1)}, []))
		lost.append(item_id)
	return projection_type.call(&"create", automatic, eligible, capacity, [], lost, [], "", true)
