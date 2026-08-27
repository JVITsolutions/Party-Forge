extends RefCounted

const SCRIPT_PATH := "res://scripts/ui/run_recovery/run_recovery_dialog.gd"
const SCENE_PATH := "res://scenes/ui/run_recovery/run_recovery_dialog.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var script_exists := ResourceLoader.exists(SCRIPT_PATH)
	var scene_exists := ResourceLoader.exists(SCENE_PATH)
	TestAssertions.truthy(script_exists, "run recovery dialog script exists", failures)
	TestAssertions.truthy(scene_exists, "run recovery dialog scene exists", failures)
	if not script_exists or not scene_exists:
		return failures
	var dialog := (load(SCENE_PATH) as PackedScene).instantiate()
	var return_focus := Button.new()
	return_focus.text = "Resume Run"
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(return_focus)
	tree.root.add_child(dialog)
	dialog.call("_ready")
	var dialog_script := dialog.get_script() as Script
	TestAssertions.equal(dialog_script.resource_path if dialog_script != null else "", SCRIPT_PATH, "recovery scene uses the presentation-only controller", failures)
	for signal_name: StringName in [&"resume_requested", &"legacy_class_requested", &"abandon_requested", &"cancelled"]:
		TestAssertions.truthy(dialog.has_signal(signal_name), "recovery dialog exposes %s intent" % signal_name, failures)
	for method_name: StringName in [&"open", &"close", &"is_open", &"show_failure"]:
		TestAssertions.truthy(dialog.has_method(method_name), "recovery dialog exposes %s contract" % method_name, failures)
	if failures.is_empty():
		_test_ready_mode(dialog, return_focus, failures)
		_test_legacy_class_mode(dialog, return_focus, failures)
		_test_invalid_forfeitable_mode(dialog, return_focus, failures)
		_test_cancel_is_nonmutating_and_restores_focus(dialog, return_focus, failures)
		_test_safe_and_technical_failure_copy(dialog, return_focus, failures)
	dialog.call("close")
	dialog.free()
	return_focus.free()
	return failures


func _test_ready_mode(dialog: Node, return_focus: Control, failures: Array[String]) -> void:
	var result := _result(RunRecoveryResult.Code.READY, &"fighter")
	TestAssertions.truthy(bool(dialog.call("open", result, _classes(), "Named Recovery", return_focus)), "ready recovery opens", failures)
	TestAssertions.truthy(_resume_button(dialog).visible and not _resume_button(dialog).disabled, "ready recovery offers resume", failures)
	TestAssertions.truthy(not _class_picker(dialog).visible and not _bind_button(dialog).visible, "ready recovery hides legacy binding", failures)
	TestAssertions.equal(dialog.get("_initial_focus"), _resume_button(dialog), "ready recovery selects Resume as deterministic initial focus", failures)
	_assert_focus_loop(_visible_focus_controls(dialog), failures)
	var resumed: Array[int] = [0]
	dialog.connect("resume_requested", func() -> void: resumed[0] += 1, CONNECT_ONE_SHOT)
	_resume_button(dialog).pressed.emit()
	TestAssertions.equal(resumed[0], 1, "Resume emits one presentation intent", failures)


func _test_legacy_class_mode(dialog: Node, return_focus: Control, failures: Array[String]) -> void:
	dialog.call("close")
	var result := _result(RunRecoveryResult.Code.CLASS_REQUIRED, &"")
	TestAssertions.truthy(bool(dialog.call("open", result, _classes(), "Named Recovery", return_focus)), "legacy class recovery opens", failures)
	TestAssertions.truthy(_class_picker(dialog).visible and not _resume_button(dialog).visible, "legacy recovery requires class binding", failures)
	TestAssertions.truthy(_bind_button(dialog).visible and not _bind_button(dialog).disabled, "legacy recovery offers an explicit Bind action", failures)
	TestAssertions.equal(dialog.get("_initial_focus"), _class_picker(dialog), "legacy recovery selects its class picker as deterministic initial focus", failures)
	_assert_focus_loop(_visible_focus_controls(dialog), failures)
	var selected: Array[StringName] = []
	dialog.connect("legacy_class_requested", func(class_id: StringName) -> void: selected.append(class_id), CONNECT_ONE_SHOT)
	_class_picker(dialog).select(1)
	_bind_button(dialog).pressed.emit()
	TestAssertions.equal(selected, [&"mage"], "Bind emits the exact selected class ID", failures)


func _test_invalid_forfeitable_mode(dialog: Node, return_focus: Control, failures: Array[String]) -> void:
	dialog.call("close")
	var result := _result(RunRecoveryResult.Code.INVALID, &"mage")
	result.error = "PARTY_FORGE_RUN_RECOVERY_ERROR field=selected_leader_class_id reason=incompatible"
	TestAssertions.truthy(bool(dialog.call("open", result, _classes(), "Named Recovery", return_focus)), "invalid forfeitable recovery opens", failures)
	TestAssertions.truthy(not _resume_button(dialog).visible and _abandon_button(dialog).visible, "invalid but forfeitable recovery offers abandon only", failures)
	TestAssertions.equal(dialog.get("_initial_focus"), _abandon_button(dialog), "invalid recovery selects Abandon as deterministic initial focus", failures)
	_abandon_button(dialog).pressed.emit()
	var confirmation := _abandon_confirmation(dialog)
	TestAssertions.truthy(confirmation.dialog_text.contains("run-owned items will be permanently lost"), "abandon warning is explicit", failures)
	TestAssertions.truthy(confirmation.dialog_text.contains("Named Recovery"), "abandon confirmation includes the active profile display name", failures)
	TestAssertions.truthy(confirmation.dialog_text.contains("run-dialog-exact-42"), "abandon confirmation includes the exact run ID", failures)
	var abandoned: Array[StringName] = []
	dialog.connect("abandon_requested", func(run_id: StringName) -> void: abandoned.append(run_id), CONNECT_ONE_SHOT)
	confirmation.confirmed.emit()
	TestAssertions.equal(abandoned, [&"run-dialog-exact-42"], "confirmed abandonment emits the decoded run ID exactly once", failures)


func _test_cancel_is_nonmutating_and_restores_focus(dialog: Node, return_focus: Control, failures: Array[String]) -> void:
	dialog.call("close")
	var mutations: Array[String] = []
	dialog.connect("resume_requested", func() -> void: mutations.append("resume"), CONNECT_ONE_SHOT)
	dialog.connect("legacy_class_requested", func(_class_id: StringName) -> void: mutations.append("bind"), CONNECT_ONE_SHOT)
	dialog.connect("abandon_requested", func(_run_id: StringName) -> void: mutations.append("abandon"), CONNECT_ONE_SHOT)
	var cancelled: Array[int] = [0]
	dialog.connect("cancelled", func() -> void: cancelled[0] += 1, CONNECT_ONE_SHOT)
	dialog.call("open", _result(RunRecoveryResult.Code.READY, &"fighter"), _classes(), "Named Recovery", return_focus)
	TestAssertions.equal(dialog.get("_return_focus"), return_focus, "open retains the exact main-menu return focus", failures)
	_cancel_button(dialog).pressed.emit()
	TestAssertions.equal(cancelled[0], 1, "cancel emits exactly once", failures)
	TestAssertions.equal(mutations, [], "cancel emits no mutating recovery intent", failures)
	TestAssertions.truthy(not bool(dialog.call("is_open")), "cancel closes recovery", failures)
	TestAssertions.equal(dialog.get("_return_focus"), null, "cancel consumes its stored main-menu return focus after restoration", failures)


func _test_safe_and_technical_failure_copy(dialog: Node, return_focus: Control, failures: Array[String]) -> void:
	dialog.call("open", _result(RunRecoveryResult.Code.READY, &"fighter"), _classes(), "Named Recovery", return_focus)
	dialog.call("show_failure", "Unable to recover this run.", "PARTY_FORGE_RUN_RECOVERY_ERROR field=context reason=injected")
	var status := dialog.get_node("Overlay/Frame/Layout/Status") as Label
	var technical := dialog.get_node("Overlay/Frame/Layout/TechnicalDetail") as Label
	TestAssertions.equal(status.text, "Unable to recover this run.", "failure presents safe player-facing copy", failures)
	TestAssertions.truthy(not status.text.contains("PARTY_FORGE"), "safe failure does not expose technical diagnostics", failures)
	TestAssertions.equal(technical.text, "PARTY_FORGE_RUN_RECOVERY_ERROR field=context reason=injected", "technical disclosure preserves exact diagnostics", failures)
	TestAssertions.truthy(technical.visible, "technical failure detail remains available", failures)


func _result(code: RunRecoveryResult.Code, class_id: StringName) -> RunRecoveryResult:
	var result := RunRecoveryResult.new()
	result.code = code
	result.profile = ProfileState.new_profile("profile-dialog", "Named Recovery", 1000)
	result.bootstrap = RunItemBootstrap.create(&"run-dialog-exact-42", 4242, &"player_1", 1, null, class_id)
	result.selected_leader_class_id = class_id
	result.run_id = &"run-dialog-exact-42"
	result.can_forfeit = true
	return result


func _classes() -> Array[ClassDefinition]:
	var result: Array[ClassDefinition] = []
	for values: Array in [[&"fighter", "Fighter"], [&"mage", "Mage"]]:
		var definition := ClassDefinition.new()
		definition.id = values[0]
		definition.display_name = values[1]
		result.append(definition)
	return result


func _visible_focus_controls(dialog: Node) -> Array[Control]:
	var result: Array[Control] = []
	for control: Control in [_class_picker(dialog), _resume_button(dialog), _bind_button(dialog), _abandon_button(dialog), _cancel_button(dialog)]:
		if control.visible and not control.disabled:
			result.append(control)
	return result


func _assert_focus_loop(controls: Array[Control], failures: Array[String]) -> void:
	for index: int in controls.size():
		var current := controls[index]
		var expected_next := controls[(index + 1) % controls.size()]
		var expected_previous := controls[posmod(index - 1, controls.size())]
		TestAssertions.equal(current.get_node(current.focus_next), expected_next, "%s has deterministic next focus" % current.name, failures)
		TestAssertions.equal(current.get_node(current.focus_previous), expected_previous, "%s has deterministic previous focus" % current.name, failures)


func _class_picker(dialog: Node) -> OptionButton: return dialog.get_node("Overlay/Frame/Layout/ClassPicker") as OptionButton
func _resume_button(dialog: Node) -> Button: return dialog.get_node("Overlay/Frame/Layout/Actions/Resume") as Button
func _bind_button(dialog: Node) -> Button: return dialog.get_node("Overlay/Frame/Layout/Actions/Bind") as Button
func _abandon_button(dialog: Node) -> Button: return dialog.get_node("Overlay/Frame/Layout/Actions/Abandon") as Button
func _cancel_button(dialog: Node) -> Button: return dialog.get_node("Overlay/Frame/Layout/Actions/Cancel") as Button
func _abandon_confirmation(dialog: Node) -> ConfirmationDialog: return dialog.get_node("AbandonConfirmation") as ConfirmationDialog
