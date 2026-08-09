class_name StatsLedgerPage
extends CharacterLedgerPage

var selected_stat_id: StringName

var _show_all := false
var _stat_buttons: Dictionary = {}
var _first_stat_button: Button
var _compact := false
var _detail_pinned := false
var _pinned_origin: Button

func _ready() -> void:
	_connect_show_all()

func refresh() -> void:
	_connect_show_all()
	var focused_stat_id := _focused_stat_id()
	_clear_generated_groups()
	_stat_buttons.clear()
	_first_stat_button = null
	var member := _selected_member_row()
	if member.is_empty():
		_identity().text = "No party member selected."
		_traits_and_capabilities().text = ""
		_detail_pinned = false
		_pinned_origin = null
		_clear_detail()
		_sync_detail_visibility()
		return
	_render_header(member)
	_render_combat_estimates()
	var rows := provider.stat_rows(context.selected_member_id, _show_all)
	var current_group_id: StringName
	var current_group: VBoxContainer = null
	for row: Dictionary in rows:
		var group_id := row.group_id as StringName
		if current_group == null or group_id != current_group_id:
			current_group_id = group_id
			current_group = _create_group(group_id)
		var button := _create_stat_button(row)
		current_group.add_child(button)
		_stat_buttons[row.stat_id] = button
		if _first_stat_button == null:
			_first_stat_button = button
	if _stat_buttons.has(selected_stat_id):
		select_stat(selected_stat_id)
	elif _first_stat_button != null:
		select_stat(_first_stat_button.get_meta("stat_id") as StringName)
	else:
		selected_stat_id = &""
		_detail_pinned = false
		_pinned_origin = null
		_clear_detail()
	_sync_pinned_origin()
	_sync_detail_visibility()
	_restore_stat_focus(focused_stat_id)

func set_show_all(enabled: bool) -> void:
	_show_all = enabled
	var toggle := _show_all_toggle()
	if toggle.button_pressed != enabled:
		toggle.set_pressed_no_signal(enabled)
	refresh()

func select_stat(stat_id: StringName) -> bool:
	if provider == null or context == null or not _stat_buttons.has(stat_id):
		return false
	var detail := provider.stat_detail(context.selected_member_id, stat_id)
	if detail.is_empty():
		return false
	selected_stat_id = stat_id
	for button_id: Variant in _stat_buttons:
		(_stat_buttons[button_id] as Button).button_pressed = button_id == stat_id
	if _detail_pinned:
		_pinned_origin = _stat_buttons.get(stat_id) as Button
	_detail_title().text = String(detail.get("title", "Missing definition: %s" % stat_id))
	_detail_value().text = String(detail.get("value_text", ""))
	_detail_description().text = String(detail.get("description", ""))
	_detail_cap().text = String(detail.get("cap_text", ""))
	var source_lines := PackedStringArray()
	for source: Dictionary in detail.get("sources", []):
		source_lines.append(_source_line(source))
	_detail_sources().text = "\n".join(source_lines)
	return true

func has_stat(stat_id: StringName) -> bool:
	return _stat_buttons.has(stat_id)

func initial_focus() -> Control:
	return _first_stat_button

func apply_compact(compact: bool) -> void:
	_compact = compact
	_content_split().vertical = compact
	_content_split().split_offset = 112 if compact else 460
	_stat_side().custom_minimum_size = Vector2(0.0, 96.0) if compact else Vector2(420.0, 0.0)
	_detail_panel().custom_minimum_size = Vector2(0.0, 112.0) if compact else Vector2(360.0, 0.0)
	if not compact:
		_detail_pinned = false
		_pinned_origin = null
	_sync_detail_visibility()

func pin_active_detail() -> bool:
	var origin := _stat_buttons.get(selected_stat_id) as Button
	if origin == null:
		return false
	_detail_pinned = true
	_pinned_origin = origin
	_detail_panel().visible = true
	_focus_control(_detail_title())
	return true

func dismiss_pinned_detail() -> bool:
	if not _compact or not _detail_pinned:
		return false
	_detail_pinned = false
	_detail_panel().visible = false
	_focus_control(_pinned_origin)
	_pinned_origin = null
	return true

func _connect_show_all() -> void:
	var toggle := _show_all_toggle()
	if not toggle.toggled.is_connected(set_show_all):
		toggle.toggled.connect(set_show_all)
	toggle.set_pressed_no_signal(_show_all)

func _selected_member_row() -> Dictionary:
	if provider == null or context == null:
		return {}
	for row: Dictionary in provider.member_rows():
		if int(row.member_id) == context.selected_member_id:
			return row
	return {}

func _render_header(member: Dictionary) -> void:
	var character_name := String(member.get("character_name", "")).strip_edges()
	if character_name.is_empty():
		character_name = "Member %d" % int(member.member_id)
	var health_state := ""
	if bool(member.get("is_dead", false)):
		health_state = " | Dead"
	elif bool(member.get("is_downed", false)):
		health_state = " | Downed"
	_identity().text = "%s | %s Rank %d | Level %d | XP %d / %d | %s | Health %s / %s%s" % [
		character_name,
		String(member.class_name),
		int(member.class_rank),
		int(member.character_level),
		int(member.experience),
		int(member.experience_required),
		String(member.role_name),
		_number(float(member.health_current)),
		_number(float(member.health_maximum)),
		health_state,
	]
	_traits_and_capabilities().text = "Traits: %s | Capabilities: %s" % [
		_join_ids(member.get("traits", [])),
		_join_ids(member.get("capabilities", [])),
	]

func _render_combat_estimates() -> void:
	var group := _create_group(&"combat_estimates")
	(group.get_node("Heading") as Label).text = "Combat Estimates"
	group.tooltip_text = "Pre-mitigation damage per target, assuming continuous use whenever each action is ready."
	var estimates := provider.combat_estimate_rows(context.selected_member_id)
	if estimates.is_empty():
		var empty := Label.new()
		empty.name = "Empty"
		empty.text = "No damaging actions available."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		group.add_child(empty)
		return
	for estimate: ActionCombatEstimate in estimates:
		group.add_child(_create_combat_estimate_card(estimate))

func _create_combat_estimate_card(estimate: ActionCombatEstimate) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Action_%s" % estimate.action_id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = (
		"Healing is theoretical per use; excludes missing health, targeting, movement, and AI downtime."
		if estimate.is_healing else
		"Damage is pre-mitigation per target; excludes defenses, misses, travel time, movement, and AI downtime."
	)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.name = "Title"
	title.text = estimate.display_name
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var metrics := Label.new()
	metrics.name = "Metrics"
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if estimate.available:
		if estimate.is_healing:
			metrics.text = "Healing / Use: %s\nUses / Second: %.2f\nEstimated HPS: %s" % [
				_estimate_number(estimate.healing_amount), estimate.attacks_per_second, _estimate_number(estimate.estimated_hps),
			]
		else:
			var critical_text := _estimate_number(estimate.critical_hit) if estimate.can_crit else "Cannot Crit"
			metrics.text = "Normal Hit: %s\nCritical Hit: %s\nAverage Hit: %s\nAttacks / Second: %.2f\nEstimated DPS: %s" % [
				_estimate_number(estimate.normal_hit), critical_text, _estimate_number(estimate.average_hit),
				estimate.attacks_per_second, _estimate_number(estimate.estimated_dps),
			]
	else:
		metrics.text = "Estimate unavailable: %s" % estimate.unavailable_reason
	content.add_child(metrics)
	var components := Label.new()
	components.name = "Components"
	components.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	components.visible = estimate.available and estimate.component_rows.size() > 1
	var component_lines := PackedStringArray()
	for row: Dictionary in estimate.component_rows:
		component_lines.append("%s: %s normal" % [row.display_name, _estimate_number(float(row.normal_hit))])
	components.text = "Damage Types\n%s" % "\n".join(component_lines)
	content.add_child(components)
	panel.add_child(content)
	return panel

func _estimate_number(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")

func _create_group(group_id: StringName) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.name = "Group_%s" % group_id
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = String(group_id).replace("_", " ").capitalize()
	group.add_child(heading)
	_groups().add_child(group)
	return group

func _create_stat_button(row: Dictionary) -> Button:
	var stat_id := row.stat_id as StringName
	var button := Button.new()
	button.name = "Stat_%s" % stat_id
	button.text = "%s    %s" % [String(row.display_name), String(row.formatted_value)]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("stat_id", stat_id)
	var detail := provider.stat_detail(context.selected_member_id, stat_id)
	button.tooltip_text = String(detail.get("description", ""))
	button.pressed.connect(_on_stat_pressed.bind(stat_id))
	button.focus_entered.connect(select_stat.bind(stat_id))
	return button

func _on_stat_pressed(stat_id: StringName) -> void:
	if select_stat(stat_id):
		pin_active_detail()

func _sync_pinned_origin() -> void:
	if _detail_pinned:
		_pinned_origin = _stat_buttons.get(selected_stat_id) as Button
		if _pinned_origin == null:
			_detail_pinned = false

func _sync_detail_visibility() -> void:
	_detail_panel().visible = not _compact or _detail_pinned

func _focus_control(control: Control) -> void:
	if control != null and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()

func _focused_stat_id() -> StringName:
	if not is_inside_tree():
		return &""
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused == null or not focused.has_meta("stat_id"):
		return &""
	var stat_id := focused.get_meta("stat_id") as StringName
	return stat_id if _stat_buttons.get(stat_id) == focused else &""

func _restore_stat_focus(stat_id: StringName) -> void:
	if stat_id.is_empty():
		return
	_focus_control(_stat_buttons.get(stat_id) as Button)

func _clear_generated_groups() -> void:
	for child: Node in _groups().get_children():
		child.free()

func _clear_detail() -> void:
	_detail_title().text = "Select a stat"
	_detail_value().text = ""
	_detail_description().text = ""
	_detail_cap().text = ""
	_detail_sources().text = ""

func _source_line(row: Dictionary) -> String:
	var operation := int(row.get("operation", -1))
	var label := str(row.get("source_label", row.get("source_id", "Unknown")))
	var value := float(row.get("value", 0.0))
	match operation:
		-1:
			return "%s: %s" % [label, _number(value)]
		StatModifier.Operation.FLAT:
			return "%s: %s flat" % [label, _signed_number(value)]
		StatModifier.Operation.INCREASED:
			return "%s: %s%% increased" % [label, _signed_number(value * 100.0)]
		StatModifier.Operation.REDUCED:
			return "%s: %s%% reduced" % [label, _signed_number(value * 100.0)]
		StatModifier.Operation.MORE:
			return "%s: %s%% more" % [label, _signed_number(value * 100.0)]
		StatModifier.Operation.LESS:
			return "%s: %s%% less" % [label, _signed_number(value * 100.0)]
		_:
			return "%s: %s" % [label, _number(value)]

func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.4f" % value).rstrip("0").rstrip(".")

func _signed_number(value: float) -> String:
	var prefix := "+" if value >= 0.0 else "-"
	return prefix + _number(absf(value))

func _join_ids(values: Array) -> String:
	var labels := PackedStringArray()
	for value: Variant in values:
		labels.append(String(value).replace("_", " ").capitalize())
	return ", ".join(labels) if not labels.is_empty() else "None"

func _identity() -> Label:
	return get_node("Layout/Header/Identity") as Label

func _traits_and_capabilities() -> Label:
	return get_node("Layout/Header/TraitsAndCapabilities") as Label

func _show_all_toggle() -> CheckButton:
	return get_node("Layout/Content/StatSide/ShowAll") as CheckButton

func _groups() -> VBoxContainer:
	return get_node("Layout/Content/StatSide/StatScroll/Groups") as VBoxContainer

func _content_split() -> SplitContainer:
	return get_node("Layout/Content") as SplitContainer

func _stat_side() -> VBoxContainer:
	return get_node("Layout/Content/StatSide") as VBoxContainer

func _detail_panel() -> ScrollContainer:
	return get_node("Layout/Content/DetailPanel") as ScrollContainer

func _detail_title() -> Label:
	return get_node("Layout/Content/DetailPanel/Detail/Title") as Label

func _detail_value() -> Label:
	return get_node("Layout/Content/DetailPanel/Detail/Value") as Label

func _detail_description() -> Label:
	return get_node("Layout/Content/DetailPanel/Detail/Description") as Label

func _detail_cap() -> Label:
	return get_node("Layout/Content/DetailPanel/Detail/Cap") as Label

func _detail_sources() -> Label:
	return get_node("Layout/Content/DetailPanel/Detail/Sources") as Label
