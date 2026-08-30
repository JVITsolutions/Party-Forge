class_name RunResultPanel
extends Control

signal restart_run_requested
signal return_to_forge_requested
signal open_armoury_requested(return_focus: Control)
signal quit_application_requested
signal retry_terminal_save_requested
signal retry_resolution_requested
signal retry_projection_requested
signal protect_displaced_gear_requested(return_focus: Control)

const ACTION_PATH := "Frame/Content/Footer/Actions/"
const ACTION_NAMES: Array[String] = [
	"RetryTerminalSave", "RetryResolution", "RetryProjection", "ProtectDisplacedGear",
	"OpenArmoury", "RestartRun", "ReturnToForge", "QuitApplication",
]

var _action_pending := false
var _protection_return_focus: Control
var _allowed_actions: Dictionary = {}

var _state: Label
var _headline: Label
var _reason: Label
var _body: ScrollContainer
var _recap: VBoxContainer
var _confirmation: PanelContainer
var _confirmation_copy: Label
var _cancel_confirmation: Button
var _confirm_protection: Button
var _last_recap_row: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_controls()

func _unhandled_input(event: InputEvent) -> void:
	if _confirmation != null and _confirmation.visible and event.is_action_pressed(&"ui_cancel"):
		_on_cancel_protection()
		get_viewport().set_input_as_handled()

func _bind_controls() -> void:
	_state = get_node("Frame/Content/Header/State") as Label
	_headline = get_node("Frame/Content/Header/OutcomeHeadline") as Label
	_reason = get_node("Frame/Content/Header/ReadableReason") as Label
	_body = get_node("Frame/Content/Body") as ScrollContainer
	_recap = get_node("Frame/Content/Body/Recap") as VBoxContainer
	_confirmation = get_node("Frame/Content/Confirmation") as PanelContainer
	_confirmation_copy = get_node("Frame/Content/Confirmation/Content/Copy") as Label
	_cancel_confirmation = get_node("Frame/Content/Confirmation/Content/Actions/Cancel") as Button
	_confirm_protection = get_node("Frame/Content/Confirmation/Content/Actions/Confirm") as Button
	_connect_action("RetryTerminalSave", _on_retry_terminal_save)
	_connect_action("RetryResolution", _on_retry_resolution)
	_connect_action("RetryProjection", _on_retry_projection)
	_connect_action("ProtectDisplacedGear", _on_protect_displaced_gear)
	_connect_action("OpenArmoury", _on_open_armoury)
	_connect_action("RestartRun", _on_restart_run)
	_connect_action("ReturnToForge", _on_return_to_forge)
	_connect_action("QuitApplication", _on_quit_application)
	if not _cancel_confirmation.pressed.is_connected(_on_cancel_protection):
		_cancel_confirmation.pressed.connect(_on_cancel_protection)
	if not _confirm_protection.pressed.is_connected(_on_confirm_protection):
		_confirm_protection.pressed.connect(_on_confirm_protection)

func present(projection: RunResultProjection) -> void:
	_bind_controls()
	_reset_presentation()
	if projection == null or not projection.valid():
		visible = false
		return
	theme = LivingForgeThemeCatalog.resolve(projection.high_contrast, projection.ui_scale_percent, projection.text_scale_percent)
	visible = true
	match projection.terminal_state:
		RunResultProjection.TerminalState.PENDING:
			_state.text = "SAVING TERMINAL TRUTH"
		RunResultProjection.TerminalState.INTERRUPTED:
			_present_interruption(projection)
		RunResultProjection.TerminalState.FINALIZED:
			_state.text = "RUN FINALIZED"
			_headline.text = _finalized_headline(projection)
			_body.visible = true
			_build_recap(projection.sections)
	_apply_actions(projection)
	_apply_focus_bridge()
	if is_inside_tree() and projection.terminal_state == RunResultProjection.TerminalState.INTERRUPTED and projection.interruption_kind == RunResultProjection.InterruptionKind.PROJECTION:
		_action("RetryProjection").grab_focus()
	elif is_inside_tree() and projection.terminal_state == RunResultProjection.TerminalState.FINALIZED:
		_action("ReturnToForge").grab_focus()

func _reset_presentation() -> void:
	_action_pending = false
	_allowed_actions.clear()
	_protection_return_focus = null
	_last_recap_row = null
	_state.text = ""
	_headline.text = "TERMINAL RECORD"
	_reason.text = ""
	_reason.visible = false
	_body.visible = false
	_body.scroll_vertical = 0
	_confirmation.visible = false
	_cancel_confirmation.disabled = false
	_confirm_protection.disabled = false
	for child: Node in _recap.get_children():
		child.free()
	for action_name: String in ACTION_NAMES:
		var button := _action(action_name)
		button.visible = false
		button.disabled = false
		button.focus_mode = Control.FOCUS_ALL
		if button.is_inside_tree():
			button.release_focus()

func _present_interruption(projection: RunResultProjection) -> void:
	_reason.visible = true
	_reason.text = projection.readable_reason
	match projection.interruption_kind:
		RunResultProjection.InterruptionKind.TERMINAL_STATE_SAVE:
			_state.text = "TERMINAL SAVE INTERRUPTED"
		RunResultProjection.InterruptionKind.RESOLUTION:
			_state.text = "RESOLUTION INTERRUPTED"
		RunResultProjection.InterruptionKind.PROJECTION:
			_state.text = "RESULTS INTERRUPTED"

func _apply_actions(projection: RunResultProjection) -> void:
	var visibility := {
		"RetryTerminalSave": projection.retry_terminal_save_allowed,
		"RetryResolution": projection.retry_resolution_allowed,
		"RetryProjection": projection.retry_projection_allowed,
		"ProtectDisplacedGear": projection.protect_displaced_gear_allowed,
		"OpenArmoury": projection.open_armoury_allowed,
		"RestartRun": projection.restart_run_allowed,
		"ReturnToForge": projection.return_to_forge_allowed,
		"QuitApplication": projection.quit_application_allowed,
	}
	for action_name: String in ACTION_NAMES:
		var allowed := bool(visibility[action_name])
		_allowed_actions[action_name] = allowed
		_action(action_name).visible = allowed
	_action("ProtectDisplacedGear").set_meta(&"displaced_gear_count", projection.displaced_gear_count)

func _build_recap(sections: Array[RunRecapSectionProjection]) -> void:
	var rows: Array[Button] = []
	for section: RunRecapSectionProjection in sections:
		var inset := PanelContainer.new()
		inset.name = "Section_%s" % section.section_id
		inset.theme_type_variation = &"LivingForgeInsetPanel"
		inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_recap.add_child(inset)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)
		inset.add_child(content)
		var title := Label.new()
		title.theme_type_variation = &"LivingForgeSectionLabel"
		title.text = section.title
		content.add_child(title)
		if not section.summary.is_empty():
			var summary := Label.new()
			summary.theme_type_variation = &"LivingForgeCaptionLabel"
			summary.text = section.summary
			summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(summary)
		var index := 0
		for entry: RunRecapEntryProjection in section.entries:
			var row := _entry_row(section.section_id, index, entry)
			content.add_child(row)
			rows.append(row)
			index += 1
	_link_focus(rows)
	_last_recap_row = rows[-1] if not rows.is_empty() else null

func _entry_row(section_id: StringName, index: int, entry: RunRecapEntryProjection) -> Button:
	var row := Button.new()
	row.name = "%s_%03d" % [section_id, index]
	row.custom_minimum_size = Vector2(48.0, 48.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.theme_type_variation = &"LivingForgeSecondaryButton"
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.text = "%s   %s" % [entry.label, entry.value]
	row.accessibility_name = "%s: %s" % [entry.label, entry.value]
	row.tooltip_text = entry.detail
	row.set_meta(&"recap_section_id", section_id)
	row.set_meta(&"recap_entry_label", entry.label)
	var detail := Label.new()
	detail.name = "Detail"
	detail.visible = false
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.theme_type_variation = &"LivingForgeCaptionLabel"
	detail.text = entry.detail
	detail.position = Vector2(16.0, 44.0)
	detail.size = Vector2(720.0, 28.0)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(detail)
	row.pressed.connect(_toggle_detail.bind(row))
	row.focus_entered.connect(_ensure_visible.bind(row))
	return row

func _link_focus(rows: Array[Button]) -> void:
	for index: int in rows.size():
		if index > 0:
			rows[index].focus_neighbor_top = rows[index].get_path_to(rows[index - 1])
		if index + 1 < rows.size():
			rows[index].focus_neighbor_bottom = rows[index].get_path_to(rows[index + 1])

func _apply_focus_bridge() -> void:
	if _last_recap_row == null:
		return
	var footer_actions: Array[Button] = []
	for action_name: String in ACTION_NAMES:
		if bool(_allowed_actions.get(action_name, false)):
			footer_actions.append(_action(action_name))
	if footer_actions.is_empty():
		return
	var bridge := _action("ReturnToForge") if bool(_allowed_actions.get("ReturnToForge", false)) else footer_actions[0]
	_last_recap_row.focus_neighbor_bottom = _last_recap_row.get_path_to(bridge)
	for button: Button in footer_actions:
		button.focus_neighbor_top = button.get_path_to(_last_recap_row)
	for index: int in footer_actions.size():
		if index > 0:
			footer_actions[index].focus_neighbor_left = footer_actions[index].get_path_to(footer_actions[index - 1])
		if index + 1 < footer_actions.size():
			footer_actions[index].focus_neighbor_right = footer_actions[index].get_path_to(footer_actions[index + 1])

func _finalized_headline(projection: RunResultProjection) -> String:
	for section: RunRecapSectionProjection in projection.sections:
		if section.section_id != &"outcome":
			continue
		var outcome := ""
		var duration := ""
		for entry: RunRecapEntryProjection in section.entries:
			if entry.label == "Outcome": outcome = entry.value.to_upper()
			elif entry.label == "Duration": duration = entry.value
		if not outcome.is_empty() and not duration.is_empty():
			return "%s · %s" % [outcome, duration]
	return "TERMINAL RECORD"

func _ensure_visible(row: Control) -> void:
	_body.ensure_control_visible(row)

func _toggle_detail(row: Button) -> void:
	var detail := row.get_node_or_null("Detail") as Label
	if detail == null or detail.text.strip_edges().is_empty():
		return
	detail.visible = not detail.visible
	row.custom_minimum_size.y = 80.0 if detail.visible else 48.0
	_body.ensure_control_visible(row)

func _connect_action(action_name: String, callback: Callable) -> void:
	var button := _action(action_name)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _action(action_name: String) -> Button:
	return get_node(ACTION_PATH + action_name) as Button

func _begin_action(button: Button) -> bool:
	if _action_pending or _confirmation.visible or button == null or not bool(_allowed_actions.get(button.name, false)) or button.disabled:
		return false
	_action_pending = true
	for action_name: String in ACTION_NAMES:
		_action(action_name).disabled = true
	return true

func _on_retry_terminal_save() -> void:
	if _begin_action(_action("RetryTerminalSave")): retry_terminal_save_requested.emit()

func _on_retry_resolution() -> void:
	if _begin_action(_action("RetryResolution")): retry_resolution_requested.emit()

func _on_retry_projection() -> void:
	if _begin_action(_action("RetryProjection")): retry_projection_requested.emit()

func _on_open_armoury() -> void:
	var button := _action("OpenArmoury")
	if _begin_action(button): open_armoury_requested.emit(button)

func _on_restart_run() -> void:
	if _begin_action(_action("RestartRun")): restart_run_requested.emit()

func _on_return_to_forge() -> void:
	if _begin_action(_action("ReturnToForge")): return_to_forge_requested.emit()

func _on_quit_application() -> void:
	if _begin_action(_action("QuitApplication")): quit_application_requested.emit()

func _on_protect_displaced_gear() -> void:
	var button := _action("ProtectDisplacedGear")
	if _action_pending or _confirmation.visible or button.disabled or not button.visible:
		return
	var count := int(button.get_meta(&"displaced_gear_count", 0))
	if count <= 0:
		return
	_protection_return_focus = button
	_confirmation_copy.text = "Move %d current leader items to Recovery Overflow so automatic extraction can continue." % count
	_confirmation.visible = true
	_set_confirmation_focus_scope(true)
	if is_inside_tree():
		_cancel_confirmation.grab_focus()

func _on_cancel_protection() -> void:
	if _action_pending:
		return
	_confirmation.visible = false
	_set_confirmation_focus_scope(false)
	if is_inside_tree() and is_instance_valid(_protection_return_focus):
		_protection_return_focus.grab_focus()

func _on_confirm_protection() -> void:
	if not _confirmation.visible or _action_pending or not is_instance_valid(_protection_return_focus):
		return
	_action_pending = true
	_cancel_confirmation.disabled = true
	_confirm_protection.disabled = true
	protect_displaced_gear_requested.emit(_protection_return_focus)

func _set_confirmation_focus_scope(active: bool) -> void:
	_set_recap_modal_locked(active)
	for action_name: String in ACTION_NAMES:
		var button := _action(action_name)
		button.disabled = active or _action_pending
		button.focus_mode = Control.FOCUS_NONE if active else Control.FOCUS_ALL
	_cancel_confirmation.disabled = false if active else _action_pending
	_confirm_protection.disabled = false if active else _action_pending
	_cancel_confirmation.focus_mode = Control.FOCUS_ALL
	_confirm_protection.focus_mode = Control.FOCUS_ALL
	if active:
		_cancel_confirmation.focus_next = _cancel_confirmation.get_path_to(_confirm_protection)
		_cancel_confirmation.focus_previous = _cancel_confirmation.get_path_to(_confirm_protection)
		_confirm_protection.focus_next = _confirm_protection.get_path_to(_cancel_confirmation)
		_confirm_protection.focus_previous = _confirm_protection.get_path_to(_cancel_confirmation)
		_cancel_confirmation.focus_neighbor_left = _cancel_confirmation.get_path_to(_confirm_protection)
		_cancel_confirmation.focus_neighbor_right = _cancel_confirmation.get_path_to(_confirm_protection)
		_cancel_confirmation.focus_neighbor_top = _cancel_confirmation.get_path_to(_cancel_confirmation)
		_cancel_confirmation.focus_neighbor_bottom = _cancel_confirmation.get_path_to(_cancel_confirmation)
		_confirm_protection.focus_neighbor_left = _confirm_protection.get_path_to(_cancel_confirmation)
		_confirm_protection.focus_neighbor_right = _confirm_protection.get_path_to(_cancel_confirmation)
		_confirm_protection.focus_neighbor_top = _confirm_protection.get_path_to(_confirm_protection)
		_confirm_protection.focus_neighbor_bottom = _confirm_protection.get_path_to(_confirm_protection)

func _set_recap_modal_locked(active: bool) -> void:
	if active:
		_body.set_meta(&"modal_mouse_filter", _body.mouse_filter)
		_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif _body.has_meta(&"modal_mouse_filter"):
		_body.mouse_filter = int(_body.get_meta(&"modal_mouse_filter")) as Control.MouseFilter
		_body.remove_meta(&"modal_mouse_filter")
	var controls: Array[Node] = _recap.find_children("*", "Control", true, false)
	for node: Node in controls:
		var control := node as Control
		if active:
			control.set_meta(&"modal_focus_mode", control.focus_mode)
			control.set_meta(&"modal_mouse_filter", control.mouse_filter)
			control.focus_mode = Control.FOCUS_NONE
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if control is BaseButton:
				control.set_meta(&"modal_disabled", (control as BaseButton).disabled)
				(control as BaseButton).disabled = true
		else:
			if control.has_meta(&"modal_focus_mode"):
				control.focus_mode = int(control.get_meta(&"modal_focus_mode")) as Control.FocusMode
				control.remove_meta(&"modal_focus_mode")
			if control.has_meta(&"modal_mouse_filter"):
				control.mouse_filter = int(control.get_meta(&"modal_mouse_filter")) as Control.MouseFilter
				control.remove_meta(&"modal_mouse_filter")
			if control is BaseButton and control.has_meta(&"modal_disabled"):
				(control as BaseButton).disabled = bool(control.get_meta(&"modal_disabled"))
				control.remove_meta(&"modal_disabled")
