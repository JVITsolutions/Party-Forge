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
	var automatic := panel.get_node_or_null("Frame/Content/Body/Sections/Automatic/Scroll/Items") as Container
	var eligible := _eligible_cards(panel)
	TestAssertions.truthy(automatic != null and automatic.get_child_count() == 1, "automatic locked group is visible in its bounded region", failures)
	TestAssertions.equal(eligible.size(), 24, "all 24 eligible items are reachable in the scroll grid", failures)
	if eligible.size() == 24:
		var first := eligible[0] as Control
		var last := eligible[23] as Control
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
	_test_composite_availability(panel, projection, failures)
	_test_grouped_exact_consequences(panel, failures)
	_test_unused_capacity_warning_contract(panel, failures)
	_test_primary_action_theme_contracts(panel, failures)
	_test_high_contrast_semantics(panel, failures)
	panel.free()
	return failures

func _test_composite_availability(panel: Control, projection: Variant, failures: Array[String]) -> void:
	var confirm := panel.get_node("Frame/Content/Actions/Confirm") as Button
	var retry := panel.get_node("Frame/Content/Actions/Retry") as Button
	projection.pending = true
	panel.call(&"present", projection)
	var first := _card(panel, "eligible-01")
	TestAssertions.truthy(confirm.disabled, "cold pending projection disables confirmation", failures)
	TestAssertions.truthy(first != null and first.disabled, "cold pending projection immediately disables newly built cards", failures)
	var success := RunResolutionPreflightResult.new()
	success._extraction = RunExtractionProjection.create([], [], [], [], 0, [])
	panel.call(&"show_preflight", success)
	TestAssertions.truthy(confirm.disabled, "successful preflight cannot re-enable confirmation while pending", failures)
	var reducible := RunResolutionPreflightResult.failure("internal", RunResolutionEvaluation.FailureCategory.STASH_REDUCIBLE, "Selected items need 4 open slots; 2 are available. Select fewer ordinary items.")
	panel.call(&"show_preflight", reducible)
	panel.call(&"set_pending", false)
	TestAssertions.truthy(confirm.disabled, "clearing pending cannot erase a failed preflight", failures)
	TestAssertions.truthy(not retry.visible, "reducible failure keeps retry hidden because selection can recover", failures)
	projection.pending = false
	panel.call(&"present", projection)
	TestAssertions.truthy(not confirm.disabled and not retry.visible, "fresh valid projection resets prior preflight disposition", failures)
	var automatic := RunResolutionPreflightResult.failure("internal", RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, "Automatic retained items need more destination space. Retry resolution after making space.")
	panel.call(&"set_pending", true)
	panel.call(&"set_pending", false)
	panel.call(&"show_preflight", automatic)
	TestAssertions.truthy(confirm.disabled and retry.visible, "failed preflight remains authoritative when delivered after pending clears", failures)
	panel.call(&"set_pending", true)
	TestAssertions.truthy(confirm.disabled and retry.disabled, "pending blocks retry interaction without changing failure disposition", failures)
	panel.call(&"set_pending", false)
	TestAssertions.truthy(confirm.disabled and retry.visible and not retry.disabled, "clearing pending restores exact failed-preflight recovery action", failures)

func _test_grouped_exact_consequences(panel: Control, failures: Array[String]) -> void:
	var sections := panel.get_node_or_null("Frame/Content/Body/Sections/Eligible/Sections") as Container
	TestAssertions.truthy(sections != null, "eligible body exposes ordered source sections", failures)
	if sections != null:
		TestAssertions.truthy(sections.get_child_count() >= 2, "canonical inventory/member changes create distinct headings without re-sort", failures)
	var automatic_list := (panel.get_node("Frame/Content/Body/Sections/SummaryLists/AutomaticItems") as Label).text
	var lost_list := (panel.get_node("Frame/Content/Body/Sections/SummaryLists/LostItems") as Label).text
	TestAssertions.truthy(automatic_list.contains("Leader Equipment") and automatic_list.contains("slot"), "automatic consequence list includes exact owner container and slot", failures)
	TestAssertions.truthy(lost_list.contains("Run Inventory") and lost_list.contains("slot"), "lost consequence list includes exact owner container and slot; actual=%s" % lost_list, failures)


func _test_unused_capacity_warning_contract(panel: Control, failures: Array[String]) -> void:
	var frame := panel.get_node("UnusedCapacityWarning/Frame") as PanelContainer
	var padding := panel.get_node("UnusedCapacityWarning/Frame/Padding") as MarginContainer
	var layout := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout") as VBoxContainer
	var title := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Title") as Label
	var message := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Message") as Label
	var actions := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions") as HBoxContainer
	var back := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Back") as Button
	var acknowledge := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Acknowledge") as Button
	TestAssertions.equal(frame.get_child_count(), 1, "unused-capacity Frame has one container layout owner", failures)
	TestAssertions.truthy(padding != null and padding.get_parent() == frame and padding.get_child_count() == 1 and layout.get_parent() == padding, "unused-capacity Frame has one padded vertical layout chain", failures)
	TestAssertions.truthy(layout != null and title.get_parent() == layout and message.get_parent() == layout and actions.get_parent() == layout, "warning Title, Message, and Actions share one vertical-flow owner", failures)
	TestAssertions.equal(title.accessibility_name, "ACCEPT UNUSED CAPACITY?", "warning title exposes exact readable label", failures)
	TestAssertions.truthy(not message.text.strip_edges().is_empty() and message.autowrap_mode != TextServer.AUTOWRAP_OFF, "warning body has readable wrapping consequence copy", failures)
	TestAssertions.equal(back.text, "BACK", "warning safe action keeps exact visible label", failures)
	TestAssertions.equal(acknowledge.text, "ACCEPT CONSEQUENCE", "warning primary action keeps exact visible label", failures)
	TestAssertions.equal(back.accessibility_name, "Back", "warning safe action exposes exact accessibility label", failures)
	TestAssertions.equal(acknowledge.accessibility_name, "Accept Consequence", "warning primary action exposes exact accessibility label", failures)
	var grammar_cases: Array[Dictionary] = [
		{"slots": 1, "lost": 1, "expected": "You are leaving 1 extraction slot unused. 1 item will be lost."},
		{"slots": 2, "lost": 1, "expected": "You are leaving 2 extraction slots unused. 1 item will be lost."},
		{"slots": 1, "lost": 2, "expected": "You are leaving 1 extraction slot unused. 2 items will be lost."},
		{"slots": 2, "lost": 2, "expected": "You are leaving 2 extraction slots unused. 2 items will be lost."},
	]
	for grammar_case: Dictionary in grammar_cases:
		var expected := String(grammar_case["expected"])
		var actual := String(panel.call(&"_unused_capacity_warning_text", int(grammar_case["slots"]), int(grammar_case["lost"])))
		TestAssertions.equal(actual, expected, "warning body pluralizes slot and item nouns independently", failures)


func _test_primary_action_theme_contracts(panel: Control, failures: Array[String]) -> void:
	var settings := PartyForgeSettings.new()
	panel.call(&"apply_visual_settings", settings)
	var confirm := panel.get_node("Frame/Content/Actions/Confirm") as Button
	_assert_shared_primary_action(confirm, "Confirm Extraction", failures)
	var acknowledge := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Acknowledge") as Button
	_assert_shared_primary_action(acknowledge, "Accept Consequence", failures)


func _assert_shared_primary_action(button: Button, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(button.theme_type_variation, &"LivingForgePrimaryButton", "%s uses the shared Primary variation" % label, failures)
	TestAssertions.truthy(not button.has_theme_stylebox_override(&"focus"), "%s has no local focus StyleBox override" % label, failures)
	TestAssertions.truthy(not button.has_theme_color_override(&"font_focus_color"), "%s has no local focus font override" % label, failures)

func _test_high_contrast_semantics(panel: Control, failures: Array[String]) -> void:
	var settings := PartyForgeSettings.new()
	settings.high_contrast = true
	settings.ui_scale_percent = 150
	settings.text_scale_percent = 150
	panel.call(&"apply_visual_settings", settings)
	var first := _card(panel, "eligible-01")
	TestAssertions.truthy(first != null, "high-contrast fixture retains eligible card", failures)
	if first == null:
		return
	first.call(&"apply_accessibility_variant", true)
	var focus_style := (first.get_node("FocusFrame") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat
	TestAssertions.truthy(focus_style != null and focus_style.border_color == LivingForgeTokens.color(&"focus_outline", true), "card focus boundary uses high-contrast semantic token", failures)
	var state_text := first.get_node("Content/Footer/State/StateText") as Label
	TestAssertions.equal(state_text.get_theme_color(&"font_color"), LivingForgeTokens.color(&"warning", true), "loss state uses high-contrast warning treatment plus explicit copy", failures)

func _card(panel: Control, item_id: String) -> Button:
	for node: Node in panel.find_children("*", "ForgeExtractionItemCard", true, false):
		if String(node.get_meta(&"item_id", "")) == item_id:
			return node as Button
	return null

func _eligible_cards(panel: Control) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in panel.find_children("*", "ForgeExtractionItemCard", true, false):
		if String(node.get_meta(&"item_id", "")).begins_with("eligible-"):
			result.append(node as Button)
	return result

func _projection(item_type: Script, projection_type: Script, count: int, capacity: int) -> Variant:
	var automatic: Array = [_item(item_type, "automatic-01", "Forge Vanguard Sword", "Common", &"common", "Fighter · Member 1", "Leader Equipment", true, false, false, {"name": "Forge Vanguard Sword"}, [], 1, "Fighter", &"run-equipment-001", 9)]
	var eligible: Array = []
	var lost: Array[String] = []
	for index: int in count:
		var item_id := "eligible-%02d" % (index + 1)
		var member_id := 2 if index < 8 else 3 if index < 16 else 0
		var owner := "Ranger · Member %d" % member_id if member_id > 0 else "Run Inventory"
		var container_id := StringName("run-equipment-%03d" % member_id) if member_id > 0 else &"run-inventory"
		var container_label := "Ranger Equipment" if member_id > 0 else "Run Inventory"
		eligible.append(_item(item_type, item_id, "Twin Band", "Common", &"common", owner, container_label, false, false, true, {"name": "Twin Band"}, [], member_id, "Ranger" if member_id > 0 else "", container_id, index))
		lost.append(item_id)
	return projection_type.call(&"create", automatic, eligible, capacity, [], lost, [], "", true)

func _item(item_type: Script, item_id: String, item_name: String, rarity: String, rarity_id: StringName, owner: String, container: String, automatic: bool, selected: bool, lost: bool, detail: Dictionary, comparisons: Array, member_id: int, class_label: String, container_id: StringName, slot: int) -> Variant:
	if item_type.has_method(&"create_with_source"):
		return item_type.call(&"create_with_source", item_id, item_name, rarity, rarity_id, owner, container, automatic, selected, lost, detail, comparisons, member_id, class_label, container_id, slot)
	return item_type.call(&"create", item_id, item_name, rarity, rarity_id, owner, container, automatic, selected, lost, detail, comparisons)
