extends RefCounted

const BOARD_SCENE := "res://scenes/dev/living_forge_state_board.tscn"
const INTEGRATION_RUNNER := "res://tests/integration/living_forge_state_board_runner.gd"
const EXPECTED_CAPTURE_FILES: Array[String] = [
	"living-forge-state-board-normal.png",
	"living-forge-state-board-compound-states.png",
	"living-forge-state-board-action-states-pressed-proof.png",
	"living-forge-state-board-normal-keyboard-focus.png",
	"living-forge-state-board-normal-controller-focus.png",
	"living-forge-state-board-high-contrast.png",
	"living-forge-state-board-high-contrast-controller-focus.png",
	"living-forge-state-board-class-card-hover-preview.png",
	"living-forge-state-board-normal-mouse-hover.png",
]
const REQUIRED_STATES: Array[StringName] = [
	&"focused", &"previewed", &"selected", &"locked", &"compatible",
	&"needs_attention", &"pending", &"disabled", &"success", &"warning", &"error",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_capture_manifest_contract(failures)
	TestAssertions.truthy(ResourceLoader.exists(BOARD_SCENE), "Living Forge state-board scene exists", failures)
	if not ResourceLoader.exists(BOARD_SCENE):
		return failures
	var packed := load(BOARD_SCENE) as PackedScene
	TestAssertions.truthy(packed != null, "Living Forge state-board scene loads", failures)
	if packed == null:
		return failures
	var board := packed.instantiate() as Control
	TestAssertions.truthy(board != null, "Living Forge state-board instantiates its typed root", failures)
	if board == null:
		return failures
	(Engine.get_main_loop() as SceneTree).root.add_child(board)

	for method: StringName in [&"semantic_state_ids", &"apply_theme_variant", &"component_tree_signature", &"visible_enabled_controls_without_consumers", &"state_control", &"compound_control", &"interaction_action_button", &"set_action_evidence_mode", &"preview_count", &"selection_count"]:
		TestAssertions.truthy(board.has_method(method), "state board exposes %s" % method, failures)
	if not board.has_method(&"semantic_state_ids"):
		board.free()
		return failures

	var state_ids: Array = board.call(&"semantic_state_ids")
	for seat_number: int in range(1, 5):
		var seat := board.get_node_or_null("Margin/Layout/SeatRow/Seat_%d" % seat_number) as Control
		TestAssertions.truthy(seat != null and seat.visible, "state board authors seat %d visibly" % seat_number, failures)
		if seat != null and seat_number >= 2:
			var availability := seat.get_node_or_null("Content/FuturePlate/Row/Availability") as Label
			TestAssertions.equal(availability.text if availability != null else "", "LOCAL CO-OP - COMING SOON", "state board seat %d preserves exact Coming Soon copy" % seat_number, failures)
			TestAssertions.equal(seat.focus_mode, Control.FOCUS_NONE, "state board seat %d remains outside focus" % seat_number, failures)
			TestAssertions.equal(seat.mouse_filter, Control.MOUSE_FILTER_IGNORE, "state board seat %d ignores mouse" % seat_number, failures)
	for state: StringName in REQUIRED_STATES:
		TestAssertions.truthy(state in state_ids, "state board instantiates %s" % state, failures)
		var control := board.call(&"state_control", state) as Control if board.has_method(&"state_control") else null
		# The focused runner executes suites during SceneTree initialization, before
		# the first rendered frame. The windowed integration runner separately proves
		# is_visible_in_tree(); this inventory contract verifies the authored state is visible.
		TestAssertions.truthy(control != null and control.visible, "%s state is authored visible" % state, failures)
		if control != null:
			TestAssertions.truthy(not String(control.get("accessibility_description")).strip_edges().is_empty(), "%s state has a rendered accessibility description" % state, failures)

	for compound_id: StringName in [&"selected_compatible", &"selected_attention", &"focused_selected", &"select_a", &"preview_b"]:
		var card := board.call(&"compound_control", compound_id) as Control if board.has_method(&"compound_control") else null
		TestAssertions.truthy(card != null and card.visible, "state board renders compound example %s" % compound_id, failures)
		if card != null:
			var playstyle := card.get_node("Content/Identity/Playstyle") as Label
			TestAssertions.truthy(not playstyle.text.strip_edges().is_empty() and playstyle.visible, "compound example %s retains authored playstyle visibly" % compound_id, failures)
	if board.has_method(&"compound_control"):
		var selected_compatible := board.call(&"compound_control", &"selected_compatible") as Control
		var selected_attention := board.call(&"compound_control", &"selected_attention") as Control
		var focused_selected := board.call(&"compound_control", &"focused_selected") as Control
		var select_a := board.call(&"compound_control", &"select_a") as Control
		var preview_b := board.call(&"compound_control", &"preview_b") as Control
		if selected_compatible != null:
			TestAssertions.truthy((selected_compatible.get_node("SelectionNotch") as Control).visible and (selected_compatible.get_node("CompatibilityBadge") as Control).visible, "selected+compatible keeps both orthogonal layers", failures)
		if selected_attention != null:
			TestAssertions.truthy((selected_attention.get_node("SelectionNotch") as Control).visible and (selected_attention.get_node("AttentionBadge") as Control).visible, "selected+needs-attention keeps both orthogonal layers", failures)
		if focused_selected != null:
			TestAssertions.truthy(not (focused_selected.get_node("FocusFrame") as Control).visible and (focused_selected.get_node("SelectionNotch") as Control).visible and (focused_selected.get_node("CompatibilityBadge") as Control).visible, "focused+selected proof starts with persistent selection/compatibility but waits for actual live focus", failures)
		if select_a != null and preview_b != null:
			TestAssertions.truthy((select_a.get_node("SelectionNotch") as Control).visible and not (select_a.get_node("PreviewIndicator") as Control).visible, "select A remains committed without false preview", failures)
			TestAssertions.truthy((preview_b.get_node("PreviewIndicator") as Control).visible and not (preview_b.get_node("SelectionNotch") as Control).visible, "preview B remains non-committing", failures)

	if board.has_method(&"interaction_action_button"):
		var primary := board.call(&"interaction_action_button", &"primary") as Button
		var secondary_pressed := board.call(&"interaction_action_button", &"secondary_pressed") as Button
		var unavailable := board.call(&"interaction_action_button", &"unavailable") as Button
		TestAssertions.truthy(secondary_pressed != null and not secondary_pressed.toggle_mode and not secondary_pressed.button_pressed, "normal board does not leave Secondary permanently pressed", failures)
		if board.has_method(&"set_action_evidence_mode"):
			board.call(&"set_action_evidence_mode", true)
		TestAssertions.truthy(primary != null and not primary.disabled, "board renders enabled Primary interaction example", failures)
		TestAssertions.truthy(primary != null and primary.toggle_mode and primary.button_pressed, "board renders Primary through the real pressed draw state", failures)
		TestAssertions.truthy(secondary_pressed != null and secondary_pressed.toggle_mode and secondary_pressed.button_pressed, "board renders a real pressed Secondary state", failures)
		TestAssertions.truthy(unavailable != null and unavailable.disabled, "board renders inert unavailable action state", failures)
		TestAssertions.truthy(primary != null and primary.text.contains("PRIMARY") and primary.text.contains("PRESSED"), "Primary evidence is explicitly labelled as a pressed state sample", failures)
		TestAssertions.truthy(secondary_pressed != null and secondary_pressed.text.contains("SECONDARY") and secondary_pressed.text.contains("PRESSED"), "Secondary evidence is explicitly labelled as a pressed inset sample", failures)
		TestAssertions.truthy(unavailable != null and unavailable.text.contains("UNAVAILABLE") and unavailable.text.contains("INERT"), "unavailable evidence is explicitly labelled inert", failures)
		if board.has_method(&"set_action_evidence_mode"):
			board.call(&"set_action_evidence_mode", false)
		TestAssertions.truthy(primary != null and not primary.toggle_mode and not primary.button_pressed and primary.text == "Confirm Proof", "action evidence exit symmetrically restores Primary", failures)
		TestAssertions.truthy(secondary_pressed != null and not secondary_pressed.toggle_mode and not secondary_pressed.button_pressed and secondary_pressed.text == "Inspect State", "action evidence exit symmetrically restores Secondary", failures)

	var normal_signature: Array = board.call(&"component_tree_signature") if board.has_method(&"component_tree_signature") else []
	if board.has_method(&"apply_theme_variant"):
		board.call(&"apply_theme_variant", false)
		TestAssertions.equal(board.theme, LivingForgeThemeCatalog.resolve(false, 100, 100), "normal state board uses the authoritative normal theme", failures)
		board.call(&"apply_theme_variant", true)
		TestAssertions.equal(board.theme, LivingForgeThemeCatalog.resolve(true, 100, 100), "high-contrast state board uses the authoritative high-contrast theme", failures)
	var contrast_signature: Array = board.call(&"component_tree_signature") if board.has_method(&"component_tree_signature") else []
	TestAssertions.truthy(not normal_signature.is_empty(), "state board exposes a non-empty component tree signature", failures)
	TestAssertions.equal(contrast_signature, normal_signature, "normal and high-contrast modes render the same component tree", failures)

	var unconsumed: Array = board.call(&"visible_enabled_controls_without_consumers") if board.has_method(&"visible_enabled_controls_without_consumers") else [&"missing_contract"]
	TestAssertions.equal(unconsumed, [], "every visible enabled board control has a consumed action", failures)
	var action_counts: Dictionary = board.call(&"exercise_enabled_actions") if board.has_method(&"exercise_enabled_actions") else {}
	TestAssertions.truthy(board.has_method(&"exercise_enabled_actions"), "state board can verify enabled action consumption", failures)
	for action_id: Variant in action_counts:
		TestAssertions.equal(int(action_counts[action_id]), 1, "%s is consumed exactly once" % action_id, failures)
	TestAssertions.truthy(action_counts.size() > 0, "state board exercises at least one enabled action", failures)

	board.free()
	return failures


func _test_capture_manifest_contract(failures: Array[String]) -> void:
	var runner_script := load(INTEGRATION_RUNNER) as Script
	TestAssertions.truthy(runner_script != null, "Living Forge integration runner loads for capture-manifest inspection", failures)
	if runner_script == null:
		return
	var constants := runner_script.get_script_constant_map()
	TestAssertions.truthy(constants.has("EXPECTED_CAPTURE_FILES"), "integration runner declares the exact capture manifest", failures)
	var actual: Array = constants.get("EXPECTED_CAPTURE_FILES", []) as Array
	TestAssertions.equal(actual, EXPECTED_CAPTURE_FILES, "integration runner requires all nine exact capture filenames", failures)
