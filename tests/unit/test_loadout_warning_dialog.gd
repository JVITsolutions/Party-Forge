extends RefCounted

const SCRIPT_PATH := "res://scripts/ui/loadout_warning/loadout_warning_dialog.gd"
const SCENE_PATH := "res://scenes/ui/loadout_warning/loadout_warning_dialog.tscn"
const INPUT_RUNNER_PATH := "res://tests/integration/loadout_warning_input_runner.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	var script_exists := ResourceLoader.exists(SCRIPT_PATH)
	var scene_exists := ResourceLoader.exists(SCENE_PATH)
	TestAssertions.truthy(script_exists, "loadout warning dialog script exists", failures)
	TestAssertions.truthy(scene_exists, "loadout warning dialog scene exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(INPUT_RUNNER_PATH), "windowed warning input runner exists", failures)
	if not script_exists or not scene_exists:
		return failures
	var dialog := (load(SCENE_PATH) as PackedScene).instantiate()
	dialog.call("_ready")
	var dialog_script := dialog.get_script() as Script
	TestAssertions.equal(dialog_script.resource_path if dialog_script != null else "", SCRIPT_PATH, "warning scene uses the intent-only dialog controller", failures)
	for signal_name: StringName in [&"go_to_armoury", &"choose_another_class", &"continue_anyway", &"destroy_confirmed", &"cancelled"]:
		TestAssertions.truthy(dialog.has_signal(signal_name), "warning exposes %s intent" % signal_name, failures)
	for method_name: StringName in [&"open", &"close", &"is_open", &"state", &"projection", &"details_text", &"show_error", &"advance_destroy_hold", &"apply_viewport_size"]:
		TestAssertions.truthy(dialog.has_method(method_name), "warning exposes %s contract" % method_name, failures)
	if failures.is_empty():
		_test_incompatible_and_destructive_states(dialog, failures)
		_test_nonoverflow_continue_and_safe_cancellation(dialog, failures)
	dialog.free()
	return failures


func _test_incompatible_and_destructive_states(dialog: Node, failures: Array[String]) -> void:
	var projection := _projection(true)
	TestAssertions.truthy(dialog.call("open", projection), "valid incompatible projection opens warning", failures)
	TestAssertions.equal(dialog.call("state"), 1, "warning begins in INCOMPATIBLE state", failures)
	var displayed := String(dialog.call("details_text"))
	for exact_text: String in [
		"Selected Class: mage",
		"Forge Vanguard Sword",
		"main_hand (slot 1)",
		"class fighter required",
		"Move to stash-tab-alpha slot 8",
		"Iron Crown",
		"head (slot 10)",
	]:
		TestAssertions.truthy(displayed.contains(exact_text), "first warning displays exact detail: %s" % exact_text, failures)
	TestAssertions.truthy(not displayed.contains("â"), "warning details contain no mojibake", failures)
	var escaped := dialog.call("projection") as LoadoutCompatibilityProjection
	var escaped_items := escaped.incompatible_items
	escaped_items[0]["display_name"] = "Escaped"
	TestAssertions.equal((dialog.call("projection") as LoadoutCompatibilityProjection).incompatible_items[0]["display_name"], "Forge Vanguard Sword", "dialog owns a defensive projection", failures)

	var continue_count: Array[int] = [0]
	dialog.connect("continue_anyway", func() -> void: continue_count[0] += 1, CONNECT_ONE_SHOT)
	(dialog.get_node("Overlay/Frame/Layout/Actions/Continue") as Button).pressed.emit()
	TestAssertions.equal(dialog.call("state"), 2, "overflow Continue changes only to DESTRUCTIVE_CONFIRMATION", failures)
	TestAssertions.equal(continue_count[0], 0, "overflow Continue emits no transition intent", failures)
	displayed = String(dialog.call("details_text"))
	for exact_text: String in [
		"Move: Forge Vanguard Sword to stash-tab-alpha slot 8",
		"Destroy: Iron Crown",
		"Destroyed equipment cannot be recovered.",
	]:
		TestAssertions.truthy(displayed.contains(exact_text), "destructive warning displays exact detail: %s" % exact_text, failures)

	var confirmations: Array[String] = []
	dialog.connect("destroy_confirmed", func(token: String) -> void: confirmations.append(token))
	dialog.call("_input", _action_event(&"ui_accept", true))
	dialog.call("advance_destroy_hold", 1.24, true)
	TestAssertions.equal(confirmations, [], "ordinary accept and short hold cannot confirm destruction", failures)
	dialog.call("advance_destroy_hold", 0.0, false)
	dialog.call("advance_destroy_hold", 0.2, true)
	dialog.call("advance_destroy_hold", 0.0, false)
	TestAssertions.equal(confirmations, [], "tap and release reset destructive progress", failures)
	dialog.call("advance_destroy_hold", 1.25, true)
	dialog.call("advance_destroy_hold", 4.0, true)
	TestAssertions.equal(confirmations, [projection.confirmation_token], "one continuous hold emits the exact token exactly once", failures)


func _test_nonoverflow_continue_and_safe_cancellation(dialog: Node, failures: Array[String]) -> void:
	dialog.call("close")
	var projection := _projection(false)
	var continued: Array[int] = [0]
	dialog.connect("continue_anyway", func() -> void: continued[0] += 1)
	TestAssertions.truthy(dialog.call("open", projection), "nonoverflow projection opens", failures)
	(dialog.get_node("Overlay/Frame/Layout/Actions/Continue") as Button).pressed.emit()
	TestAssertions.equal(continued[0], 1, "nonoverflow Continue emits exactly one transition intent", failures)
	TestAssertions.equal(dialog.call("state"), 1, "nonoverflow intent leaves lifecycle ownership to composition", failures)
	var cancelled: Array[int] = [0]
	dialog.connect("cancelled", func() -> void: cancelled[0] += 1)
	dialog.call("_input", _action_event(&"ui_cancel", true))
	TestAssertions.equal(cancelled[0], 1, "cancel emits exactly once", failures)
	TestAssertions.truthy(not bool(dialog.call("is_open")), "cancel closes safely", failures)
	TestAssertions.equal(dialog.call("state"), 0, "cancel returns state to CLOSED", failures)


func _projection(with_overflow: bool) -> LoadoutCompatibilityProjection:
	var incompatibles: Array[Dictionary] = [
		{
			"base_definition_id": "forge_vanguard_sword",
			"display_name": "Forge Vanguard Sword",
			"instance_id": "item-sword",
			"reasons": ["PARTY_FORGE_EQUIPMENT_ERROR item=forge_vanguard_sword reason=class fighter required"],
			"slot_id": "main_hand",
			"source_container_id": "leader-loadout",
			"source_slot": 0,
		},
	]
	var overflow: Array[String] = []
	if with_overflow:
		incompatibles.append({
			"base_definition_id": "iron_crown",
			"display_name": "Iron Crown",
			"instance_id": "item-crown",
			"reasons": ["PARTY_FORGE_EQUIPMENT_ERROR item=iron_crown reason=class fighter required"],
			"slot_id": "head",
			"source_container_id": "leader-loadout",
			"source_slot": 9,
		})
		overflow = ["item-crown"]
	return LoadoutCompatibilityProjection.success(
		&"mage",
		[],
		incompatibles,
		[{"instance_id": "item-sword", "destination_container_id": "stash-tab-alpha", "destination_slot": 7}],
		overflow,
		"a".repeat(64),
	)


func _action_event(action: StringName, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event
