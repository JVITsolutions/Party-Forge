class_name HUD
extends CanvasLayer

signal inspect_requested(member_id: int, return_focus: Control)
signal ledger_requested(member_id: int, return_focus: Control)
signal collapse_preferences_changed(party_collapsed: bool, alerts_collapsed: bool)

const RICH_MEMBER_SCENE := preload("res://scenes/ui/living_forge/components/forge_party_member_card.tscn")
const COMPACT_MEMBER_SCENE := preload("res://scenes/ui/living_forge/components/forge_party_member_marker.tscn")
const ALERT_CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_alert_card.tscn")
const CRITICAL_STATE_ICON: Texture2D = preload("res://assets/ui/living_forge/icons/tabler-3.46.0/alert-triangle.svg")
const DOWNED_STATE_ICON: Texture2D = preload("res://assets/ui/living_forge/icons/party-forge/downed.svg")
const DEAD_STATE_ICON: Texture2D = preload("res://assets/ui/living_forge/icons/party-forge/dead.svg")
const REGION_PARTY: StringName = &"party"
const REGION_ALERTS: StringName = &"alerts"

var game_run: Node
var party_manager: PartyManager
var experience_system: ExperienceSystem
var run_context: PlayerRunContext
var settings: PartyForgeSettings
var boss: Node3D
var current_projection: CombatHudProjection

var boss_banner_remaining := 0.0
var loot_status_remaining := 0.0
var resolved_status_remaining := 0.0
var _view_model := CombatHudViewModel.new()
var _party_revision := ""
var _current_page := 0
var _metrics: CombatHudResponsiveLayout.Metrics
var _member_controls_by_id: Dictionary = {}
var _alert_controls_by_id: Dictionary = {}
var _health_by_member: Dictionary = {}
var _health_changed_callbacks: Dictionary = {}
var _health_state_callbacks: Dictionary = {}
var _boss_health: HealthComponent
var _boss_health_callback: Callable
var _boss_state_callback: Callable
var _last_viewport_size := Vector2i.ZERO
var _high_contrast := false
var _character_hud_background_opacity_percent := PartyForgeSettings.DEFAULT_CHARACTER_HUD_BACKGROUND_OPACITY_PERCENT
var _actor_binding_refresh_scheduled := false
var _actor_binding_force_structure := false
var _unavailable_reason := ""
var _deferred_focus_descriptor: Dictionary = {}
var _terminal_suspended_focus_modes: Array[Dictionary] = []
var _terminal_prior_focus: Control
var _terminal_prior_focus_descriptor: Dictionary = {}
var _party_collapsed := false
var _alerts_collapsed := false
var _collapsed_focus_descriptors := {REGION_PARTY: {}, REGION_ALERTS: {}}
var _collapsed_focus_modes := {REGION_PARTY: [], REGION_ALERTS: []}
var _disclosure_tweens: Dictionary = {}
var _disclosure_presented_states: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_control_connections()


func show_terminal_extraction(projection: TerminalExtractionProjection) -> void:
	var panel := get_node("TerminalExtraction") as TerminalExtractionPanel
	_suspend_non_terminal_focus(panel)
	panel.apply_visual_settings(settings if settings != null else PartyForgeSettings.new())
	panel.present(projection)


func show_terminal_resolution_pending() -> void:
	var panel := get_node("TerminalExtraction") as TerminalExtractionPanel
	_suspend_non_terminal_focus(panel)
	panel.set_pending(true)


func hide_terminal_extraction() -> void:
	(get_node("TerminalExtraction") as TerminalExtractionPanel).hide_panel()
	_restore_non_terminal_focus()


func _suspend_non_terminal_focus(panel: TerminalExtractionPanel) -> void:
	if not _terminal_suspended_focus_modes.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	_terminal_prior_focus = owner if owner is Control else null
	_terminal_prior_focus_descriptor = focus_descriptor_for(_terminal_prior_focus)
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or control == panel or panel.is_ancestor_of(control):
			continue
		if control.focus_mode == Control.FOCUS_NONE or not _terminal_control_is_presentationally_available(control):
			continue
		_terminal_suspended_focus_modes.append({
			"control": control,
			"focus_mode": control.focus_mode,
			"presentation_focus_mode": control.focus_mode,
		})
		control.focus_mode = Control.FOCUS_NONE


func _restore_non_terminal_focus() -> void:
	for entry: Dictionary in _terminal_suspended_focus_modes:
		var raw_control: Variant = entry.get("control")
		if is_instance_valid(raw_control):
			var control := raw_control as Control
			if control == null:
				continue
			var presentation_mode := int(entry.get("presentation_focus_mode", entry.get("focus_mode", Control.FOCUS_NONE)))
			control.focus_mode = presentation_mode if _terminal_control_is_focus_eligible(control, presentation_mode) else Control.FOCUS_NONE
	_terminal_suspended_focus_modes.clear()
	var direct_value: Variant = _terminal_prior_focus
	var descriptor := _terminal_prior_focus_descriptor.duplicate(true)
	_terminal_prior_focus = null
	_terminal_prior_focus_descriptor.clear()
	for region: StringName in [REGION_PARTY, REGION_ALERTS]:
		if _region_collapsed(region):
			_restore_region_focus_modes(region)
			_suspend_region_focus(region)
		else:
			_restore_region_focus_modes(region)
	var direct: Control
	if is_instance_valid(direct_value):
		direct = direct_value as Control
	var direct_valid := direct != null and is_instance_valid(direct)
	var direct_disabled := direct_valid and direct is BaseButton and (direct as BaseButton).disabled
	if direct_valid and direct.is_visible_in_tree() and direct.focus_mode != Control.FOCUS_NONE and not direct_disabled:
		direct.grab_focus()
		return
	if not descriptor.is_empty():
		restore_focus_descriptor(descriptor)


func _ensure_control_connections() -> void:
	var party_header := get_node("Margin/CombatStatus/PartyHeader") as Button
	var alerts_header := get_node("Margin/CombatStatus/AlertRegion/Header") as Button
	var previous := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious") as Button
	var next := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
	var overflow := get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	var tray_action := get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
	if not party_header.pressed.is_connected(_on_party_header_pressed): party_header.pressed.connect(_on_party_header_pressed)
	if not alerts_header.pressed.is_connected(_on_alerts_header_pressed): alerts_header.pressed.connect(_on_alerts_header_pressed)
	if not previous.pressed.is_connected(_on_previous_page): previous.pressed.connect(_on_previous_page)
	if not next.pressed.is_connected(_on_next_page): next.pressed.connect(_on_next_page)
	if not overflow.pressed.is_connected(_on_overflow_pressed): overflow.pressed.connect(_on_overflow_pressed)
	if not tray_action.pressed.is_connected(_on_alerts_tray_action_pressed): tray_action.pressed.connect(_on_alerts_tray_action_pressed)
	var tray := get_node("CombatAlertTray") as CombatAlertTray
	if not tray.inspect_requested.is_connected(_on_inspect_route): tray.inspect_requested.connect(_on_inspect_route)
	if not tray.ledger_requested.is_connected(_on_ledger_route): tray.ledger_requested.connect(_on_ledger_route)
	if not tray.alerts_resolved.is_connected(_on_alerts_resolved): tray.alerts_resolved.connect(_on_alerts_resolved)
	if not tray.closed.is_connected(_on_modal_closed): tray.closed.connect(_on_modal_closed)
	var inspector := get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel
	if not inspector.closed.is_connected(_on_modal_closed): inspector.closed.connect(_on_modal_closed)
	var viewport := _hud_viewport()
	if not viewport.gui_focus_changed.is_connected(_on_hud_focus_changed): viewport.gui_focus_changed.connect(_on_hud_focus_changed)


func configure(run: Node, party: PartyManager, experience: ExperienceSystem, context: PlayerRunContext, saved_settings: PartyForgeSettings) -> void:
	_ensure_control_connections()
	_disconnect_authorities()
	_deferred_focus_descriptor.clear()
	game_run = run
	party_manager = party
	experience_system = experience
	run_context = context
	settings = saved_settings if saved_settings != null else PartyForgeSettings.new()
	_apply_visual_settings_to_surfaces()
	apply_collapse_preferences(settings.hud_party_collapsed, settings.hud_alerts_collapsed)
	if party_manager != null:
		party_manager.member_added.connect(_on_party_structure_changed)
		party_manager.class_rank_changed.connect(_on_party_value_changed)
		party_manager.stats_changed.connect(_on_party_stats_changed)
	if run_context != null:
		run_context.progression_changed.connect(_on_progression_changed)
		run_context.actor_bound.connect(_on_actor_bound)
		for member: PartyMemberState in run_context.party.members if run_context.party != null else []:
			var actor := run_context.actor_for(member.member_id)
			if actor != null:
				_bind_health(member.member_id, actor)
	_party_revision = ""
	_current_page = 0
	(get_node("Margin") as Control).visible = true
	_refresh_projection(true)


func apply_visual_settings(saved_settings: PartyForgeSettings) -> void:
	settings = saved_settings if saved_settings != null else PartyForgeSettings.new()
	_apply_visual_settings_to_surfaces()
	apply_collapse_preferences(settings.hud_party_collapsed, settings.hud_alerts_collapsed)
	if current_projection != null:
		_refresh_projection(true)


func _apply_visual_settings_to_surfaces() -> void:
	_high_contrast = settings.high_contrast
	_character_hud_background_opacity_percent = clampi(
		settings.character_hud_background_opacity_percent,
		PartyForgeSettings.MIN_CHARACTER_HUD_BACKGROUND_OPACITY_PERCENT,
		PartyForgeSettings.MAX_CHARACTER_HUD_BACKGROUND_OPACITY_PERCENT,
	)
	var shell := get_node("Margin/CombatStatus") as Control
	var resolved_theme := LivingForgeThemeCatalog.resolve(_high_contrast, settings.ui_scale_percent, settings.text_scale_percent)
	shell.theme = resolved_theme
	(get_node("CombatAlertTray") as CombatAlertTray).apply_visual_settings(resolved_theme, _high_contrast)
	(get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel).apply_visual_settings(resolved_theme)


func party_collapsed() -> bool:
	return _party_collapsed


func alerts_collapsed() -> bool:
	return _alerts_collapsed


func apply_collapse_preferences(party_value: bool, alerts_value: bool) -> void:
	_set_party_collapsed(party_value, false)
	_set_alerts_collapsed(alerts_value, false)
	_present_region_headers()


func _set_party_collapsed(value: bool, user_initiated: bool) -> void:
	if _party_collapsed == value:
		return
	if value:
		_prepare_region_collapse(REGION_PARTY, user_initiated)
	_party_collapsed = value
	for path: NodePath in [^"Margin/CombatStatus/LeaderCard", ^"Margin/CombatStatus/Experience", ^"Margin/CombatStatus/PartyRegion"]:
		(get_node(path) as Control).visible = not value
	_present_region_headers()
	if current_projection != null:
		_refresh_projection(true)
	if not value:
		_finish_region_expand(REGION_PARTY, user_initiated)
	if user_initiated:
		collapse_preferences_changed.emit(_party_collapsed, _alerts_collapsed)


func _set_alerts_collapsed(value: bool, user_initiated: bool) -> void:
	if _alerts_collapsed == value:
		return
	if value:
		_prepare_region_collapse(REGION_ALERTS, user_initiated)
	_alerts_collapsed = value
	var expanded := get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control
	var overflow := get_node("Margin/CombatStatus/AlertRegion/Overflow") as BaseButton
	expanded.visible = not value
	if value:
		overflow.visible = false
		overflow.disabled = true
		_set_presentation_focus_mode(overflow, Control.FOCUS_NONE)
	_present_region_headers()
	if not value and current_projection != null:
		_apply_alert_budget()
	else:
		_reflow_alert_rows(false)
	if not value:
		_finish_region_expand(REGION_ALERTS, user_initiated)
	if user_initiated:
		collapse_preferences_changed.emit(_party_collapsed, _alerts_collapsed)


func _region_content_roots(region: StringName) -> Array[Control]:
	if region == REGION_PARTY:
		return [
			get_node("Margin/CombatStatus/LeaderCard") as Control,
			get_node("Margin/CombatStatus/Experience") as Control,
			get_node("Margin/CombatStatus/PartyRegion") as Control,
		]
	return [
		get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control,
		get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control,
	]


func _region_header(region: StringName) -> Button:
	if region == REGION_PARTY:
		return get_node("Margin/CombatStatus/PartyHeader") as Button
	return get_node("Margin/CombatStatus/AlertRegion/Header") as Button


func _region_collapsed(region: StringName) -> bool:
	return _party_collapsed if region == REGION_PARTY else _alerts_collapsed


func _region_contains_control(region: StringName, control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	for root: Control in _region_content_roots(region):
		if control == root or root.is_ancestor_of(control):
			return true
	return false


func _on_hud_focus_changed(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	for region: StringName in [REGION_PARTY, REGION_ALERTS]:
		if _region_collapsed(region) or not _region_contains_control(region, control):
			continue
		var descriptor := focus_descriptor_for(control)
		if not descriptor.is_empty():
			_collapsed_focus_descriptors[region] = descriptor.duplicate(true)


func _suspend_region_focus(region: StringName) -> void:
	var existing := _collapsed_focus_modes.get(region, []) as Array
	if not existing.is_empty():
		return
	var entries: Array = []
	for root: Control in _region_content_roots(region):
		var controls: Array[Control] = [root]
		for node: Node in root.find_children("*", "Control", true, false):
			if node is Control:
				controls.append(node as Control)
		for control: Control in controls:
			var focus_mode := control.focus_mode
			if _terminal_control_is_presentationally_available(control):
				var terminal_focus_mode := _claim_terminal_presentation_focus_mode(control)
				if terminal_focus_mode != Control.FOCUS_NONE:
					focus_mode = terminal_focus_mode
			if focus_mode != Control.FOCUS_NONE:
				entries.append({"control": control, "focus_mode": focus_mode})
				control.focus_mode = Control.FOCUS_NONE
	_collapsed_focus_modes[region] = entries


func _restore_region_focus_modes(region: StringName) -> void:
	for entry: Dictionary in _collapsed_focus_modes.get(region, []) as Array:
		var raw_control: Variant = entry.get("control")
		if is_instance_valid(raw_control):
			var control := raw_control as Control
			if control == null:
				continue
			control.focus_mode = int(entry.get("focus_mode", Control.FOCUS_NONE))
	_collapsed_focus_modes[region] = []


func _reconcile_terminal_focus_suspension() -> void:
	var panel := get_node("TerminalExtraction") as TerminalExtractionPanel
	if not panel.visible and _terminal_suspended_focus_modes.is_empty():
		return
	var reconciled: Array[Dictionary] = []
	var seen: Dictionary = {}
	for entry: Dictionary in _terminal_suspended_focus_modes:
		var raw_control: Variant = entry.get("control")
		if not is_instance_valid(raw_control):
			continue
		var control := raw_control as Control
		if control == null or control == panel or panel.is_ancestor_of(control):
			continue
		var instance_id := control.get_instance_id()
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		var original_mode := int(entry.get("focus_mode", Control.FOCUS_NONE))
		var presentation_mode := int(entry.get("presentation_focus_mode", original_mode))
		if control.focus_mode != Control.FOCUS_NONE:
			presentation_mode = control.focus_mode
		if not _terminal_control_is_presentationally_available(control):
			presentation_mode = Control.FOCUS_NONE
		if _set_region_suspended_focus_mode(control, presentation_mode):
			continue
		reconciled.append({
			"control": control,
			"focus_mode": original_mode,
			"presentation_focus_mode": presentation_mode,
		})
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if (
			control == null
			or control == panel
			or panel.is_ancestor_of(control)
			or control.focus_mode == Control.FOCUS_NONE
			or not _terminal_control_is_presentationally_available(control)
		):
			continue
		if _set_region_suspended_focus_mode(control, control.focus_mode):
			continue
		var instance_id := control.get_instance_id()
		if not seen.has(instance_id):
			seen[instance_id] = true
			reconciled.append({
				"control": control,
				"focus_mode": control.focus_mode,
				"presentation_focus_mode": control.focus_mode,
			})
		control.focus_mode = Control.FOCUS_NONE
	_terminal_suspended_focus_modes = reconciled


func _set_presentation_focus_mode(control: Control, focus_mode: Control.FocusMode) -> void:
	if control == null or not is_instance_valid(control):
		return
	for entry: Dictionary in _terminal_suspended_focus_modes:
		var raw_control: Variant = entry.get("control")
		if not is_instance_valid(raw_control):
			continue
		var suspended_control := raw_control as Control
		if suspended_control == control:
			entry["presentation_focus_mode"] = focus_mode
			control.focus_mode = Control.FOCUS_NONE
			return
	if _set_region_suspended_focus_mode(control, focus_mode):
		return
	if _terminal_focus_suspension_active():
		if focus_mode != Control.FOCUS_NONE and _terminal_control_is_presentationally_available(control):
			_terminal_suspended_focus_modes.append({
				"control": control,
				"focus_mode": focus_mode,
				"presentation_focus_mode": focus_mode,
			})
		control.focus_mode = Control.FOCUS_NONE
		return
	control.focus_mode = focus_mode


func _set_region_suspended_focus_mode(control: Control, focus_mode: int) -> bool:
	for region: StringName in [REGION_PARTY, REGION_ALERTS]:
		var entries := _collapsed_focus_modes.get(region, []) as Array
		for index: int in range(entries.size() - 1, -1, -1):
			var entry := entries[index] as Dictionary
			var raw_control: Variant = entry.get("control")
			if not is_instance_valid(raw_control):
				entries.remove_at(index)
				continue
			var suspended_control := raw_control as Control
			if suspended_control != control:
				continue
			entry["focus_mode"] = focus_mode
			control.focus_mode = Control.FOCUS_NONE
			_collapsed_focus_modes[region] = entries
			return true
		_collapsed_focus_modes[region] = entries
	return false


func _claim_terminal_presentation_focus_mode(control: Control) -> int:
	for index: int in range(_terminal_suspended_focus_modes.size() - 1, -1, -1):
		var entry := _terminal_suspended_focus_modes[index]
		var raw_control: Variant = entry.get("control")
		if not is_instance_valid(raw_control):
			_terminal_suspended_focus_modes.remove_at(index)
			continue
		var suspended_control := raw_control as Control
		if suspended_control != control:
			continue
		var presentation_mode := int(entry.get("presentation_focus_mode", entry.get("focus_mode", Control.FOCUS_NONE)))
		if presentation_mode != Control.FOCUS_NONE:
			_terminal_suspended_focus_modes.remove_at(index)
		return presentation_mode
	return Control.FOCUS_NONE


func _terminal_control_is_presentationally_available(control: Control) -> bool:
	if control == null or not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree():
		return false
	return not (control is BaseButton and (control as BaseButton).disabled)


func _terminal_control_is_focus_eligible(control: Control, presentation_mode: int) -> bool:
	return presentation_mode != Control.FOCUS_NONE and _terminal_control_is_presentationally_available(control)


func _terminal_focus_suspension_active() -> bool:
	var panel := get_node_or_null("TerminalExtraction") as TerminalExtractionPanel
	return (panel != null and panel.visible) or not _terminal_suspended_focus_modes.is_empty()


func _prepare_region_collapse(region: StringName, user_initiated: bool) -> void:
	if user_initiated and not _child_modal_owns_focus():
		var owner := _hud_viewport().gui_get_focus_owner() as Control
		if _region_contains_control(region, owner):
			_collapsed_focus_descriptors[region] = focus_descriptor_for(owner)
		var header := _region_header(region)
		if header.is_inside_tree():
			header.grab_focus()
	_suspend_region_focus(region)


func _finish_region_expand(region: StringName, user_initiated: bool) -> void:
	if not _terminal_focus_suspension_active():
		_restore_region_focus_modes(region)
	if user_initiated:
		call_deferred("_restore_region_focus", region)


func _restore_region_focus(region: StringName) -> void:
	if _child_modal_owns_focus() or _terminal_focus_suspension_active():
		return
	var descriptor := _collapsed_focus_descriptors.get(region, {}) as Dictionary
	if not descriptor.is_empty() and restore_focus_descriptor(descriptor, false):
		return
	if region == REGION_PARTY and current_projection != null:
		var leader := current_projection.leader()
		if leader != null and _focus_member(leader.member_id, &"leader_anchor"):
			return
		for member: PartyMemberHudProjection in current_projection.members:
			if _focus_member(member.member_id, &"roster_member"):
				return
	elif region == REGION_ALERTS and current_projection != null:
		for alert: CombatAlertProjection in current_projection.visible_alerts:
			if _grab_valid_focus(_alert_action_control(alert.stable_id, &"inspect")):
				return
		if _grab_valid_focus(get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control):
			return
	_grab_valid_focus(_region_header(region))


func _present_disclosure(region: StringName, glyph: Label, collapsed: bool) -> void:
	var visual := _disclosure_visual(glyph)
	var target_rotation := 0.0 if collapsed else PI / 2.0
	var prior := _disclosure_tweens.get(region) as Tween
	var already_presented := _disclosure_presented_states.has(region)
	var state_changed := not already_presented or bool(_disclosure_presented_states.get(region, collapsed)) != collapsed
	_disclosure_presented_states[region] = collapsed
	if settings != null and settings.reduced_motion:
		if prior != null and prior.is_valid():
			prior.kill()
		visual.rotation = target_rotation
		_disclosure_tweens.erase(region)
		return
	if not state_changed:
		if prior == null or not prior.is_valid():
			visual.rotation = target_rotation
		return
	if prior != null and prior.is_valid():
		prior.kill()
	if not already_presented or settings == null:
		visual.rotation = target_rotation
		_disclosure_tweens.erase(region)
		return
	var tween := create_tween()
	_disclosure_tweens[region] = tween
	tween.tween_property(visual, "rotation", target_rotation, float(LivingForgeTokens.motion_ms(&"focus", false)) / 1000.0)


func _disclosure_visual(slot: Label) -> Label:
	slot.text = ""
	var existing := slot.get_node_or_null("RotatingGlyph") as Label
	if existing != null:
		existing.pivot_offset = existing.size * 0.5
		return existing
	var minimum := slot.get_combined_minimum_size().max(Vector2(20.0, 20.0))
	slot.custom_minimum_size = minimum
	var visual := Label.new()
	visual.name = "RotatingGlyph"
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.text = "▸"
	visual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(visual)
	visual.pivot_offset = minimum * 0.5
	return visual


func _present_region_headers() -> void:
	var party_header := get_node("Margin/CombatStatus/PartyHeader") as Button
	var party_glyph := get_node("Margin/CombatStatus/PartyHeader/Content/DisclosureGlyph") as Label
	var party_summary := get_node("Margin/CombatStatus/PartyHeader/Content/Summary") as Label
	var party_health := get_node("Margin/CombatStatus/PartyHeader/Content/LeaderHealth") as ProgressBar
	var party_icon := get_node("Margin/CombatStatus/PartyHeader/Content/StateIcon") as TextureRect
	var party_clear := get_node("Margin/CombatStatus/PartyHeader/Content/AllClearGlyph") as Label
	_present_disclosure(REGION_PARTY, party_glyph, _party_collapsed)
	var alerts_header := get_node("Margin/CombatStatus/AlertRegion/Header") as Button
	var alerts_glyph := get_node("Margin/CombatStatus/AlertRegion/Header/Content/DisclosureGlyph") as Label
	var alerts_summary := get_node("Margin/CombatStatus/AlertRegion/Header/Content/Summary") as Label
	var alerts_icon := get_node("Margin/CombatStatus/AlertRegion/Header/Content/StateIcon") as TextureRect
	var alerts_clear := get_node("Margin/CombatStatus/AlertRegion/Header/Content/AllClearGlyph") as Label
	var tray_action := get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
	_present_disclosure(REGION_ALERTS, alerts_glyph, _alerts_collapsed)
	if current_projection == null:
		party_summary.text = "PARTY · UNAVAILABLE"
		alerts_summary.text = "ALERTS · UNAVAILABLE"
		party_header.accessibility_name = "Party unavailable, %s" % _region_state_label(_party_collapsed)
		alerts_header.accessibility_name = "Alerts unavailable, %s" % _region_state_label(_alerts_collapsed)
		party_health.visible = false
		_present_state_cue(party_icon, party_clear, CombatHudProjection.NO_ALERT_SEVERITY, false)
		_present_state_cue(alerts_icon, alerts_clear, CombatHudProjection.NO_ALERT_SEVERITY, false)
		_set_tray_action_eligibility(tray_action, 0)
		_reconcile_terminal_focus_suspension()
		return
	var leader := current_projection.leader()
	var highest_severity := current_projection.highest_alert_severity()
	var dead := current_projection.alert_count_for(CombatAlertProjection.Severity.DEAD)
	var downed := current_projection.alert_count_for(CombatAlertProjection.Severity.DOWNED)
	var critical := current_projection.alert_count_for(CombatAlertProjection.Severity.CRITICAL)
	if leader != null:
		if _party_collapsed:
			party_summary.text = "PARTY · %d MEMBERS · LEADER %s · STATE %s · DEAD %d · DOWNED %d · CRITICAL %d" % [
				current_projection.members.size(),
				leader.display_name.to_upper(),
				_severity_label(highest_severity),
				dead,
				downed,
				critical,
			]
		else:
			party_summary.text = "PARTY · %d MEMBERS" % current_projection.members.size()
		party_health.max_value = leader.max_health
		party_health.value = leader.health
		party_health.visible = _party_collapsed
	party_header.accessibility_name = _party_accessibility_name()
	var highest := current_projection.highest_severity_alert()
	if highest == null:
		alerts_summary.text = "ALERTS · ALL CLEAR"
	elif not _alerts_collapsed:
		alerts_summary.text = "ALERTS · %d" % current_projection.all_alerts.size()
	else:
		alerts_summary.text = "ALERTS %d · %s · %s" % [current_projection.all_alerts.size(), _severity_label(highest.severity), highest.summary]
	alerts_header.accessibility_name = _alerts_accessibility_name()
	_present_state_cue(party_icon, party_clear, highest_severity, true)
	_present_state_cue(alerts_icon, alerts_clear, highest_severity, true)
	_set_tray_action_eligibility(tray_action, current_projection.all_alerts.size())
	_configure_alert_focus_neighbors()
	_reconcile_terminal_focus_suspension()


func _region_state_label(collapsed: bool) -> String:
	return "collapsed" if collapsed else "expanded"


func _severity_label(severity: int) -> String:
	match severity:
		CombatAlertProjection.Severity.DEAD: return "DEAD"
		CombatAlertProjection.Severity.DOWNED: return "DOWNED"
		CombatAlertProjection.Severity.CRITICAL: return "CRITICAL"
	return "ALL CLEAR"


func _severity_icon(severity: int) -> Texture2D:
	match severity:
		CombatAlertProjection.Severity.DEAD: return DEAD_STATE_ICON
		CombatAlertProjection.Severity.DOWNED: return DOWNED_STATE_ICON
		CombatAlertProjection.Severity.CRITICAL: return CRITICAL_STATE_ICON
	return null


func _present_state_cue(icon: TextureRect, all_clear_glyph: Label, severity: int, available: bool) -> void:
	icon.texture = _severity_icon(severity) if available else null
	icon.visible = icon.texture != null
	all_clear_glyph.visible = available and severity == CombatHudProjection.NO_ALERT_SEVERITY


func _party_accessibility_name() -> String:
	if current_projection == null:
		return "Party unavailable, %s" % _region_state_label(_party_collapsed)
	var leader := current_projection.leader()
	var leader_copy := "No leader"
	if leader != null:
		leader_copy = "Leader %s, health %d of %d" % [leader.display_name, roundi(leader.health), roundi(leader.max_health)]
	return "Party, %d members, %s, highest severity %s, dead %d, downed %d, critical %d, %s" % [
		current_projection.members.size(),
		leader_copy,
		_severity_label(current_projection.highest_alert_severity()),
		current_projection.alert_count_for(CombatAlertProjection.Severity.DEAD),
		current_projection.alert_count_for(CombatAlertProjection.Severity.DOWNED),
		current_projection.alert_count_for(CombatAlertProjection.Severity.CRITICAL),
		_region_state_label(_party_collapsed),
	]


func _alerts_accessibility_name() -> String:
	if current_projection == null:
		return "Alerts unavailable, %s" % _region_state_label(_alerts_collapsed)
	if current_projection.all_alerts.is_empty():
		return "Alerts, all clear, %s" % _region_state_label(_alerts_collapsed)
	var highest := current_projection.highest_severity_alert()
	return "Alerts, %d, highest severity %s, %s, %s" % [
		current_projection.all_alerts.size(),
		_severity_label(highest.severity),
		highest.summary,
		_region_state_label(_alerts_collapsed),
	]


func _set_tray_action_eligibility(action: Button, alert_count: int) -> void:
	var eligible := alert_count > 0
	action.visible = eligible
	action.disabled = not eligible
	_set_presentation_focus_mode(action, Control.FOCUS_ALL if eligible else Control.FOCUS_NONE)
	if not eligible and action.has_focus():
		action.release_focus()
	action.text = "VIEW ALL ALERTS (%d)" % alert_count
	action.accessibility_name = "View all %d combat %s" % [alert_count, "alert" if alert_count == 1 else "alerts"] if eligible else "No combat alerts"


func set_leader(_actor: PartyActor) -> void:
	# Kept as a compatibility seam. PlayerRunContext actor bindings are authoritative.
	pass


func set_boss(actor: Node3D) -> void:
	_disconnect_boss_health()
	boss = actor
	if boss != null and is_instance_valid(boss):
		_boss_health = boss.get_node_or_null("HealthComponent") as HealthComponent
		if _boss_health != null:
			_boss_health_callback = _on_boss_health_changed
			_boss_state_callback = _on_boss_state_changed
			_boss_health.health_changed.connect(_boss_health_callback)
			_boss_health.died.connect(_boss_state_callback)
	_refresh_projection(false)


func show_boss_banner() -> void:
	var banner := get_node("BossBanner") as Control
	banner.visible = true
	boss_banner_remaining = 2.0


func show_loot_status(message: String, duration := 2.5) -> void:
	var label := get_node("LootStatus") as Label
	label.text = message
	label.visible = not message.strip_edges().is_empty()
	loot_status_remaining = maxf(duration, 0.0)


func open_inspector_for_member(member_id: int, return_focus: Control) -> bool:
	var member := _member_projection(member_id)
	return (get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel).open(member, return_focus, focus_descriptor_for(return_focus))


func focus_descriptor_for(control: Control) -> Dictionary:
	if control == null or not is_instance_valid(control):
		return {}
	if control == get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction"):
		return {"kind": &"named", "named_control": &"alerts_tray_action"}
	if control == get_node("Margin/CombatStatus/AlertRegion/Overflow"):
		return {"kind": &"overflow", "named_control": &"alert_overflow"}
	var cursor: Node = control
	while cursor != null and cursor != self:
		if cursor.has_meta(&"stable_alert_id"):
			var action := &"inspect" if control.name == &"Inspect" else (&"ledger" if control.name == &"Ledger" else &"")
			return {
				"kind": &"alert_action",
				"stable_alert_id": StringName(cursor.get_meta(&"stable_alert_id", &"")),
				"member_id": int(cursor.get_meta(&"member_id", 0)),
				"action": action,
				"order_index": _alert_order_index(StringName(cursor.get_meta(&"stable_alert_id", &""))),
				"party_index": _party_index_for_member(int(cursor.get_meta(&"member_id", 0))),
			}
		if cursor.has_meta(&"member_id") and int(cursor.get_meta(&"member_id", 0)) > 0:
			var member_id := int(cursor.get_meta(&"member_id", 0))
			var surface := &"leader_anchor" if cursor == get_node("Margin/CombatStatus/LeaderCard") else &"roster_member"
			return {"kind": &"member", "member_id": member_id, "party_index": _party_index_for_member(member_id), "surface": surface}
		cursor = cursor.get_parent()
	for named: Dictionary in [
		{"path": ^"Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious", "name": &"page_previous"},
		{"path": ^"Margin/CombatStatus/PartyRegion/CompactRoster/PageNext", "name": &"page_next"},
	]:
		if control == get_node(named.path):
			return {"kind": &"named", "named_control": named.name}
	return {}


func restore_focus_descriptor(descriptor: Dictionary, allow_global_fallback := true) -> bool:
	_deferred_focus_descriptor.clear()
	if descriptor.is_empty():
		return _focus_named_safe_control() if allow_global_fallback else false
	var kind := StringName(descriptor.get("kind", &""))
	if kind == &"alert_action":
		var exact := _alert_action_control(StringName(descriptor.get("stable_alert_id", &"")), StringName(descriptor.get("action", &"inspect")))
		if _grab_valid_focus(exact):
			return true
	elif kind == &"overflow":
		if _grab_valid_focus(get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control):
			return true
	elif kind == &"member":
		if _focus_member(int(descriptor.get("member_id", 0)), StringName(descriptor.get("surface", &""))):
			return true
	elif kind == &"named":
		if _grab_valid_focus(_named_focus_control(StringName(descriptor.get("named_control", &"")))):
			return true
	if not allow_global_fallback:
		return false
	if kind == &"alert_action":
		if current_projection != null and not current_projection.all_alerts.is_empty():
			var index := clampi(int(descriptor.get("order_index", 0)), 0, current_projection.all_alerts.size() - 1)
			var survivor := current_projection.all_alerts[index]
			if _grab_valid_focus(_alert_action_control(survivor.stable_id, StringName(descriptor.get("action", &"inspect")))):
				return true
	var overflow := get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control
	if _grab_valid_focus(overflow):
		return true
	if current_projection != null:
		for alert: CombatAlertProjection in current_projection.visible_alerts:
			if _grab_valid_focus(_alert_action_control(alert.stable_id, &"inspect")):
				return true
	var member_id := int(descriptor.get("member_id", 0))
	if member_id > 0 and _focus_member(member_id):
		return true
	var party_index := int(descriptor.get("party_index", 0))
	if current_projection != null and not current_projection.members.is_empty():
		var nearest := current_projection.members[clampi(party_index, 0, current_projection.members.size() - 1)]
		if _focus_member(nearest.member_id):
			return true
	return _focus_named_safe_control()


func _process(delta: float) -> void:
	_refresh_runtime_text()
	var viewport_size := _hud_viewport().get_visible_rect().size.round() as Vector2i
	if viewport_size != _last_viewport_size and party_manager != null:
		_refresh_projection(true)
	if boss_banner_remaining > 0.0:
		boss_banner_remaining = maxf(0.0, boss_banner_remaining - maxf(delta, 0.0))
		if boss_banner_remaining <= 0.0:
			(get_node("BossBanner") as Control).visible = false
	if loot_status_remaining > 0.0:
		loot_status_remaining = maxf(0.0, loot_status_remaining - maxf(delta, 0.0))
		if loot_status_remaining <= 0.0:
			(get_node("LootStatus") as Control).visible = false
	if resolved_status_remaining > 0.0:
		resolved_status_remaining = maxf(0.0, resolved_status_remaining - maxf(delta, 0.0))
		if resolved_status_remaining <= 0.0:
			(get_node("AlertResolvedMessage") as Control).visible = false


func _refresh_projection(force_structure: bool) -> void:
	var authority_error := _required_authority_error()
	if not authority_error.is_empty():
		current_projection = null
		_clear_presentation()
		_show_unavailable(authority_error)
		return
	var elapsed := float(game_run.call("elapsed_time")) if game_run.has_method("elapsed_time") else 0.0
	var projection := _view_model.build(party_manager, run_context, _health_snapshot, experience_system, elapsed, boss)
	if projection == null:
		current_projection = null
		_clear_presentation()
		_show_unavailable("combat projection is invalid")
		return
	current_projection = projection
	_clear_unavailable()
	_last_viewport_size = _hud_viewport().get_visible_rect().size.round() as Vector2i
	_present_region_headers()
	var party_header_height := _reflow_party_header()
	_metrics = CombatHudResponsiveLayout.resolve(_last_viewport_size, settings.ui_scale_percent, settings.text_scale_percent, projection.members.size(), party_header_height)
	var leader_card := get_node("Margin/CombatStatus/LeaderCard") as ForgePartyMemberCard
	_reflow_leader_region(leader_card.apply_leader_density(_uses_compact_leader_density()))
	var next_revision := _view_model.ordered_party_revision(party_manager)
	var structure_changed := force_structure or next_revision != _party_revision
	_party_revision = next_revision
	if structure_changed:
		_current_page = _metrics.clamped_page(_current_page)
		_rebuild_member_controls()
	else:
		_present_live_member_controls()
	_present_status()
	_present_alerts()
	_present_region_headers()
	_refresh_open_tray()


func _uses_compact_leader_density() -> bool:
	return _last_viewport_size.y <= 720 and settings.text_scale_percent >= 150


func _reflow_leader_region(leader_height: float) -> void:
	var party_header := get_node("Margin/CombatStatus/PartyHeader") as Control
	var leader := get_node("Margin/CombatStatus/LeaderCard") as Control
	leader.offset_top = party_header.offset_bottom + float(LivingForgeTokens.spacing(&"standard"))
	leader.offset_bottom = leader.offset_top + leader_height
	var experience := get_node("Margin/CombatStatus/Experience") as Control
	experience.offset_top = leader.offset_bottom + 4.0
	experience.offset_bottom = experience.offset_top + maxf(20.0, experience.get_combined_minimum_size().y)
	var party_region := get_node("Margin/CombatStatus/PartyRegion") as Control
	party_region.offset_top = experience.offset_bottom + 8.0


func _reflow_party_header() -> float:
	var header := get_node("Margin/CombatStatus/PartyHeader") as Button
	var summary := get_node("Margin/CombatStatus/PartyHeader/Content/Summary") as Label
	var scale := maxf(float(settings.ui_scale_percent), float(settings.text_scale_percent)) / 100.0
	var maximum_height := maxf(48.0 * scale, _hud_viewport().get_visible_rect().size.y - header.position.y - 16.0)
	var semantic_height := _measure_header_summary_height(header, summary, maximum_height)
	var header_height := clampf(maxf(header.get_combined_minimum_size().y, 48.0 * scale), semantic_height, maximum_height)
	_set_bottom_offset_if_changed(header, header.offset_top + header_height)
	return header_height


func _measure_header_summary_height(header: Button, summary: Label, maximum_height: float) -> float:
	var content := summary.get_parent() as HBoxContainer
	var separation := float(content.get_theme_constant(&"separation"))
	var visible_sibling_count := 0
	var reserved_width := 0.0
	for child: Node in content.get_children():
		if not child is Control or child == summary or not (child as Control).visible:
			continue
		visible_sibling_count += 1
		reserved_width += (child as Control).get_combined_minimum_size().x
	var available_width := clampf(
		maxf(header.size.x, header.custom_minimum_size.x) - reserved_width - separation * float(visible_sibling_count),
		1.0,
		maxf(header.size.x, header.custom_minimum_size.x),
	)
	var font := summary.get_theme_font(&"font")
	var font_size := summary.get_theme_font_size(&"font_size")
	var measured := font.get_multiline_string_size(summary.text, summary.horizontal_alignment, available_width, font_size)
	var line_height := maxf(font.get_height(font_size), 1.0)
	var measured_height := clampf(ceilf(measured.y + line_height + 8.0), line_height, maximum_height)
	summary.custom_minimum_size = Vector2(0.0, measured_height)
	return measured_height


func _rebuild_member_controls() -> void:
	if _party_collapsed:
		_restore_region_focus_modes(REGION_PARTY)
	_clear_member_controls()
	var members := current_projection.members
	if members.is_empty():
		_reconcile_terminal_focus_suspension()
		return
	var leader := _leader_projection(members)
	var leader_card := get_node("Margin/CombatStatus/LeaderCard") as ForgePartyMemberCard
	leader_card.present(leader)
	leader_card.apply_accessibility_variant(_high_contrast)
	leader_card.apply_background_opacity(_character_hud_background_opacity_percent)
	leader_card.set_meta(&"member_id", leader.member_id)
	if not leader_card.activated.is_connected(_on_member_activated):
		leader_card.activated.connect(_on_member_activated.bind(leader_card))
	var rich := get_node("Margin/CombatStatus/PartyRegion/RichRoster") as GridContainer
	var compact := get_node("Margin/CombatStatus/PartyRegion/CompactRoster") as Control
	var no_followers := get_node("Margin/CombatStatus/PartyRegion/NoFollowers") as Label
	var is_rich := _metrics.mode == CombatHudResponsiveLayout.Mode.RICH
	rich.visible = is_rich
	compact.visible = not is_rich
	no_followers.visible = is_rich and members.size() == 1
	if is_rich:
		var previous := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious") as Button
		var next := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
		previous.visible = false
		previous.disabled = true
		_set_presentation_focus_mode(previous, Control.FOCUS_NONE)
		next.visible = false
		next.disabled = true
		_set_presentation_focus_mode(next, Control.FOCUS_NONE)
		_rebuild_rich_followers(members)
	else:
		_rebuild_compact_page(members)
	_configure_member_focus_neighbors()
	if _party_collapsed:
		_suspend_region_focus(REGION_PARTY)
	_reconcile_terminal_focus_suspension()


func _rebuild_rich_followers(members: Array[PartyMemberHudProjection]) -> void:
	var roster := get_node("Margin/CombatStatus/PartyRegion/RichRoster") as GridContainer
	roster.columns = maxi(1, _metrics.column_count)
	for member: PartyMemberHudProjection in members:
		if member.is_leader:
			continue
		var card := RICH_MEMBER_SCENE.instantiate() as ForgePartyMemberCard
		roster.add_child(card)
		_bind_member_control(card, member)
		_synchronize_rich_card_minimum(card)


func _synchronize_rich_card_minimum(card: ForgePartyMemberCard) -> void:
	var content := card.get_node("Surface/Content") as Control
	card.custom_minimum_size = card.custom_minimum_size.max(content.get_combined_minimum_size() + Vector2(32.0, 32.0))


func _rebuild_compact_page(members: Array[PartyMemberHudProjection]) -> void:
	var window := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/MemberWindow") as GridContainer
	window.columns = mini(2, maxi(1, _metrics.column_count))
	var start := _current_page * _metrics.visible_member_count
	var finish := mini(start + _metrics.visible_member_count, members.size())
	for index: int in range(start, finish):
		var marker := COMPACT_MEMBER_SCENE.instantiate() as ForgePartyMemberMarker
		_bind_member_control(marker, members[index])
		window.add_child(marker)
	_present_page_status()


func _bind_member_control(control: ForgePartyMemberCard, member: PartyMemberHudProjection) -> void:
	control.present(member)
	control.apply_accessibility_variant(_high_contrast)
	control.apply_background_opacity(_character_hud_background_opacity_percent)
	control.set_meta(&"member_id", member.member_id)
	control.add_to_group(&"combat_hud_member")
	control.activated.connect(_on_member_activated.bind(control))
	control.inspect_requested.connect(_on_member_route.bind(control))
	control.ledger_requested.connect(_on_member_ledger_route.bind(control))
	_member_controls_by_id[member.member_id] = control


func _present_live_member_controls() -> void:
	if current_projection == null:
		return
	var leader_card := get_node("Margin/CombatStatus/LeaderCard") as ForgePartyMemberCard
	for member: PartyMemberHudProjection in current_projection.members:
		if member.is_leader:
			leader_card.present(member)
		var control := _member_controls_by_id.get(member.member_id) as ForgePartyMemberCard
		if control != null:
			control.present(member)


func _present_status() -> void:
	_refresh_runtime_text()
	var xp := get_node("Margin/CombatStatus/Experience") as ProgressBar
	xp.max_value = maxi(current_projection.experience_next, 1)
	xp.value = current_projection.experience
	xp.accessibility_name = "Leader experience %d of %d" % [current_projection.experience, current_projection.experience_next]
	var boss_region := get_node("Margin/CombatStatus/BossRegion") as Control
	boss_region.visible = not current_projection.boss_name.is_empty()
	if boss_region.visible:
		(get_node("Margin/CombatStatus/BossRegion/BossName") as Label).text = current_projection.boss_name.to_upper()
		var health := get_node("Margin/CombatStatus/BossRegion/BossHealth") as ProgressBar
		health.max_value = current_projection.boss_max_health
		health.value = current_projection.boss_health
		health.accessibility_name = "%s boss health %d of %d" % [current_projection.boss_name, roundi(current_projection.boss_health), roundi(current_projection.boss_max_health)]


func _present_alerts() -> void:
	if _alerts_collapsed:
		_restore_region_focus_modes(REGION_ALERTS)
	var stack := get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as VBoxContainer
	var candidates := current_projection.visible_alerts
	var wanted: Dictionary = {}
	for alert: CombatAlertProjection in candidates:
		wanted[alert.stable_id] = true
	for stable_value: Variant in _alert_controls_by_id.keys():
		var stable_id := StringName(stable_value)
		if wanted.has(stable_id):
			continue
		var stale_value: Variant = _alert_controls_by_id[stable_id]
		_alert_controls_by_id.erase(stable_id)
		if is_instance_valid(stale_value):
			var stale := stale_value as Control
			if stale != null:
				stale.free()
	for index: int in candidates.size():
		var alert := candidates[index]
		var card: ForgeAlertCard
		var card_value: Variant = _alert_controls_by_id.get(alert.stable_id)
		if is_instance_valid(card_value):
			card = card_value as ForgeAlertCard
		if card == null:
			card = ALERT_CARD_SCENE.instantiate() as ForgeAlertCard
			card.custom_minimum_size = Vector2(472.0, 172.0)
			_alert_controls_by_id[alert.stable_id] = card
			stack.add_child(card)
			card.inspect_requested.connect(_on_alert_inspect_requested.bind(card))
			card.ledger_requested.connect(_on_alert_ledger_requested.bind(card))
		card.set_meta(&"stable_alert_id", alert.stable_id)
		card.set_meta(&"member_id", alert.member_id)
		card.present_alert(alert)
		card.apply_accessibility_variant(_high_contrast)
		card.visible = true
		stack.move_child(card, index)
	_apply_alert_budget()
	if _alerts_collapsed:
		_suspend_region_focus(REGION_ALERTS)
	_reconcile_terminal_focus_suspension()


func _apply_alert_budget() -> void:
	var stack := get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as VBoxContainer
	var overflow := get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	if _alerts_collapsed:
		stack.visible = false
		overflow.visible = false
		overflow.disabled = true
		_set_presentation_focus_mode(overflow, Control.FOCUS_NONE)
		if overflow.has_focus():
			overflow.release_focus()
		_reflow_alert_rows(false)
		return
	_reflow_alert_rows(false)
	var separation := float(stack.get_theme_constant(&"separation"))
	var visible_alerts := current_projection.visible_alerts
	var required_height := 0.0
	var card_minimums: Dictionary = {}
	for index: int in visible_alerts.size():
		var candidate := visible_alerts[index]
		var candidate_card := _alert_controls_by_id.get(candidate.stable_id) as ForgeAlertCard
		if candidate_card != null:
			var candidate_minimum := candidate_card.synchronize_content_minimum()
			card_minimums[candidate.stable_id] = candidate_minimum
			required_height += candidate_minimum.y + (separation if index > 0 else 0.0)
	var reserve_overflow := current_projection.all_alerts.size() > visible_alerts.size() or required_height > _alert_stack_vertical_budget(stack)
	_reflow_alert_rows(reserve_overflow)
	var vertical_budget := _alert_stack_vertical_budget(stack)
	var rendered_count := 0
	var used_height := 0.0
	for alert: CombatAlertProjection in visible_alerts:
		var card := _alert_controls_by_id.get(alert.stable_id) as ForgeAlertCard
		if card == null:
			continue
		var card_minimum := card_minimums.get(alert.stable_id, card.get_combined_minimum_size()) as Vector2
		var next_height := used_height + (separation if rendered_count > 0 else 0.0) + card_minimum.y
		var render_card := rendered_count == 0 or next_height <= vertical_budget
		card.set_interaction_disabled(not render_card)
		card.visible = render_card
		if render_card:
			used_height = next_height
			rendered_count += 1
	var overflow_count := maxi(0, current_projection.all_alerts.size() - rendered_count)
	overflow.visible = overflow_count > 0
	overflow.disabled = not overflow.visible
	_set_presentation_focus_mode(overflow, Control.FOCUS_ALL if overflow.visible else Control.FOCUS_NONE)
	if not overflow.visible and overflow.has_focus():
		overflow.release_focus()
	overflow.text = "+%d %s" % [overflow_count, "alert" if overflow_count == 1 else "alerts"]
	overflow.accessibility_name = "Open %d additional combat %s" % [overflow_count, "alert" if overflow_count == 1 else "alerts"]
	_reflow_alert_rows(overflow.visible)
	_configure_alert_focus_neighbors()


func _alert_stack_vertical_budget(stack: Control) -> float:
	var stack_parent := stack.get_parent_control()
	var budget := maxf(
		stack_parent.size.y * (stack.anchor_bottom - stack.anchor_top) + stack.offset_bottom - stack.offset_top,
		0.0,
	)
	if budget <= 0.0:
		return maxf(_hud_viewport().get_visible_rect().size.y - 188.0, 1.0)
	return budget


func _reflow_alert_rows(reserve_overflow: bool) -> void:
	var region := get_node("Margin/CombatStatus/AlertRegion") as Control
	var header := get_node("Margin/CombatStatus/AlertRegion/Header") as Button
	var stack := get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control
	var overflow := get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	var tray_action := get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
	var compact_gap := float(LivingForgeTokens.spacing(&"compact"))
	var summary := get_node("Margin/CombatStatus/AlertRegion/Header/Content/Summary") as Label
	var scale := maxf(float(settings.ui_scale_percent), float(settings.text_scale_percent)) / 100.0
	var tray_height := maxf(48.0, tray_action.get_combined_minimum_size().y)
	var maximum_header_height := maxf(48.0 * scale, region.size.y - (tray_height + compact_gap if tray_action.visible else 0.0))
	var semantic_height := _measure_header_summary_height(header, summary, maximum_header_height)
	var header_height := clampf(maxf(header.get_combined_minimum_size().y, 48.0 * scale), semantic_height, maximum_header_height)
	_set_bottom_offset_if_changed(header, header.offset_top + header_height)
	var tray_width := maxf(192.0, tray_action.get_combined_minimum_size().x)
	_set_offsets_if_changed(tray_action, -tray_width, -tray_height, tray_action.offset_right, 0.0)
	var reserved_bottom := 0.0
	if tray_action.visible:
		reserved_bottom = tray_height + compact_gap
	var overflow_height := maxf(48.0, overflow.get_combined_minimum_size().y)
	if reserve_overflow:
		_set_vertical_offsets_if_changed(overflow, -(reserved_bottom + overflow_height), -reserved_bottom)
		reserved_bottom += overflow_height + compact_gap
	var stack_top := header.offset_bottom + compact_gap
	var stack_bottom := -reserved_bottom
	if region.size.y > 0.0 and stack_top > region.size.y + stack_bottom:
		stack_bottom = stack_top - region.size.y
	_set_vertical_offsets_if_changed(stack, stack_top, stack_bottom)


func _set_bottom_offset_if_changed(control: Control, value: float) -> void:
	if not is_equal_approx(control.offset_bottom, value):
		control.offset_bottom = value


func _set_vertical_offsets_if_changed(control: Control, top: float, bottom: float) -> void:
	if not is_equal_approx(control.offset_top, top):
		control.offset_top = top
	if not is_equal_approx(control.offset_bottom, bottom):
		control.offset_bottom = bottom


func _set_offsets_if_changed(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	if not is_equal_approx(control.offset_left, left):
		control.offset_left = left
	if not is_equal_approx(control.offset_top, top):
		control.offset_top = top
	if not is_equal_approx(control.offset_right, right):
		control.offset_right = right
	if not is_equal_approx(control.offset_bottom, bottom):
		control.offset_bottom = bottom


func _refresh_runtime_text() -> void:
	if game_run == null or not game_run.has_method("elapsed_time"):
		return
	var seconds := float(game_run.call("elapsed_time"))
	var timer := get_node("Margin/CombatStatus/RunTime") as Label
	timer.text = _format_time(seconds)
	var total := maxi(floori(seconds), 0)
	timer.accessibility_name = "Run timer %d minutes %d seconds" % [floori(total / 60.0), total % 60]


func _present_page_status() -> void:
	var previous := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious") as Button
	var next := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
	var label := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageStatus") as Label
	previous.disabled = _current_page <= 0
	next.disabled = _current_page + 1 >= _metrics.page_count
	previous.visible = _metrics.page_count > 1
	next.visible = _metrics.page_count > 1
	_sync_page_action_focus(previous)
	_sync_page_action_focus(next)
	label.text = "PARTY %d OF %d" % [_current_page + 1, _metrics.page_count]
	label.accessibility_name = "Party page %d of %d" % [_current_page + 1, _metrics.page_count]


func _sync_page_action_focus(action: Button) -> void:
	var eligible := action.visible and not action.disabled
	_set_presentation_focus_mode(action, Control.FOCUS_ALL if eligible else Control.FOCUS_NONE)
	if not eligible and action.has_focus():
		action.release_focus()


func _on_previous_page() -> void:
	_set_page(_current_page - 1)


func _on_next_page() -> void:
	_set_page(_current_page + 1)


func _on_party_header_pressed() -> void:
	_set_party_collapsed(not _party_collapsed, true)


func _on_alerts_header_pressed() -> void:
	_set_alerts_collapsed(not _alerts_collapsed, true)


func _set_page(page: int) -> void:
	if _metrics == null:
		return
	var next_page := _metrics.clamped_page(page)
	if next_page == _current_page:
		return
	_current_page = next_page
	_rebuild_member_controls()
	var controls := _ordered_member_controls()
	if not controls.is_empty() and controls[0].is_inside_tree():
		controls[0].grab_focus()


func _on_member_activated(member_id: int, control: Control) -> void:
	inspect_requested.emit(member_id, control)


func _on_member_route(member_id: int, control: Control) -> void:
	inspect_requested.emit(member_id, control)


func _on_member_ledger_route(member_id: int, control: Control) -> void:
	ledger_requested.emit(member_id, control)


func _on_alert_inspect_requested(member_id: int, card: ForgeAlertCard) -> void:
	_on_inspect_route(member_id, card.get_node("Surface/Content/Actions/Inspect") as Control)


func _on_alert_ledger_requested(member_id: int, card: ForgeAlertCard) -> void:
	_on_ledger_route(member_id, card.get_node("Surface/Content/Actions/Ledger") as Control)


func _on_inspect_route(member_id: int, return_focus: Control) -> void:
	inspect_requested.emit(member_id, return_focus)


func _on_ledger_route(member_id: int, return_focus: Control) -> void:
	ledger_requested.emit(member_id, return_focus)


func _on_overflow_pressed() -> void:
	_open_alert_tray(get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control)


func _on_alerts_tray_action_pressed() -> void:
	_open_alert_tray(get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Control)


func _open_alert_tray(return_focus: Control) -> void:
	if current_projection == null or current_projection.all_alerts.is_empty():
		return
	(get_node("CombatAlertTray") as CombatAlertTray).open(current_projection.all_alerts, return_focus)


func _refresh_open_tray() -> void:
	var tray := get_node("CombatAlertTray") as CombatAlertTray
	if tray.visible and current_projection != null:
		tray.open(current_projection.all_alerts, null)


func _on_alerts_resolved(message: String) -> void:
	var label := get_node("AlertResolvedMessage") as Label
	label.text = message
	label.visible = true
	resolved_status_remaining = 2.5


func _on_modal_closed(_return_focus: Control, focus_descriptor: Dictionary) -> void:
	if _child_modal_owns_focus():
		_deferred_focus_descriptor = focus_descriptor.duplicate(true)
		return
	var effective := focus_descriptor if not focus_descriptor.is_empty() else _deferred_focus_descriptor
	restore_focus_descriptor(effective)


func _on_party_structure_changed(_member: PartyMemberState) -> void:
	_refresh_after_actor_binding(true)


func _on_party_value_changed(_class_id: StringName, _rank: int) -> void:
	_refresh_after_actor_binding(false)


func _on_party_stats_changed(_member_id: int) -> void:
	_refresh_after_actor_binding(false)


func _on_progression_changed(_member_id: int) -> void:
	_refresh_after_actor_binding(false)


func _on_actor_bound(member_id: int, actor: Node3D) -> void:
	_bind_health(member_id, actor)
	_refresh_after_actor_binding(false)


func _bind_health(member_id: int, actor: Node3D) -> void:
	_disconnect_health(member_id)
	if actor == null or not is_instance_valid(actor):
		return
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		return
	var changed := _on_health_changed.bind(member_id)
	var state := _on_health_state_changed.bind(member_id)
	health.health_changed.connect(changed)
	health.downed.connect(state)
	health.revived.connect(state)
	health.died.connect(state)
	_health_by_member[member_id] = health
	_health_changed_callbacks[member_id] = changed
	_health_state_callbacks[member_id] = state


func _disconnect_health(member_id: int) -> void:
	var health := _health_by_member.get(member_id) as HealthComponent
	if health != null and is_instance_valid(health):
		var changed := _health_changed_callbacks.get(member_id) as Callable
		var state := _health_state_callbacks.get(member_id) as Callable
		if changed.is_valid() and health.health_changed.is_connected(changed):
			health.health_changed.disconnect(changed)
		for signal_value: Signal in [health.downed, health.revived, health.died]:
			if state.is_valid() and signal_value.is_connected(state):
				signal_value.disconnect(state)
	_health_by_member.erase(member_id)
	_health_changed_callbacks.erase(member_id)
	_health_state_callbacks.erase(member_id)


func _on_health_changed(_current: float, _maximum: float, _member_id: int) -> void:
	_refresh_after_actor_binding(false)


func _on_health_state_changed(_member_id: int) -> void:
	_refresh_after_actor_binding(false)


func _refresh_after_actor_binding(force_structure: bool) -> void:
	if _has_unbound_party_actor():
		_actor_binding_force_structure = _actor_binding_force_structure or force_structure
		if not _actor_binding_refresh_scheduled:
			_actor_binding_refresh_scheduled = true
			call_deferred(&"_flush_actor_binding_refresh")
		return
	_refresh_projection(force_structure)


func _flush_actor_binding_refresh() -> void:
	var force_structure := _actor_binding_force_structure
	_actor_binding_refresh_scheduled = false
	_actor_binding_force_structure = false
	_refresh_projection(force_structure)


func _has_unbound_party_actor() -> bool:
	if party_manager == null or run_context == null:
		return false
	for member: PartyMemberState in party_manager.members:
		if member != null and run_context.actor_for(member.member_id) == null:
			return true
	return false


func _health_snapshot(member_id: int) -> Dictionary:
	var health := _health_by_member.get(member_id) as HealthComponent
	if health == null or not is_instance_valid(health):
		return {}
	return {"current": health.current_health, "max": health.max_health, "downed": health.is_downed, "dead": health.is_dead}


func _disconnect_authorities() -> void:
	if party_manager != null and is_instance_valid(party_manager):
		if party_manager.member_added.is_connected(_on_party_structure_changed): party_manager.member_added.disconnect(_on_party_structure_changed)
		if party_manager.class_rank_changed.is_connected(_on_party_value_changed): party_manager.class_rank_changed.disconnect(_on_party_value_changed)
		if party_manager.stats_changed.is_connected(_on_party_stats_changed): party_manager.stats_changed.disconnect(_on_party_stats_changed)
	if run_context != null and is_instance_valid(run_context):
		if run_context.progression_changed.is_connected(_on_progression_changed): run_context.progression_changed.disconnect(_on_progression_changed)
		if run_context.actor_bound.is_connected(_on_actor_bound): run_context.actor_bound.disconnect(_on_actor_bound)
	for member_id: Variant in _health_by_member.keys():
		_disconnect_health(int(member_id))


func _disconnect_boss_health() -> void:
	if _boss_health != null and is_instance_valid(_boss_health):
		if _boss_health_callback.is_valid() and _boss_health.health_changed.is_connected(_boss_health_callback): _boss_health.health_changed.disconnect(_boss_health_callback)
		if _boss_state_callback.is_valid() and _boss_health.died.is_connected(_boss_state_callback): _boss_health.died.disconnect(_boss_state_callback)
	_boss_health = null
	_boss_health_callback = Callable()
	_boss_state_callback = Callable()


func _on_boss_health_changed(_current: float, _maximum: float) -> void:
	_refresh_projection(false)


func _on_boss_state_changed() -> void:
	_refresh_projection(false)


func _clear_presentation() -> void:
	_clear_member_controls()
	var leader := get_node("Margin/CombatStatus/LeaderCard") as ForgePartyMemberCard
	leader.present(null)
	leader.set_meta(&"member_id", 0)
	(get_node("Margin/CombatStatus/BossRegion") as Control).visible = false
	for card_value: Variant in _alert_controls_by_id.values():
		if is_instance_valid(card_value):
			var card := card_value as Control
			if card != null:
				card.free()
	_alert_controls_by_id.clear()
	(get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control).visible = false
	_present_region_headers()


func _clear_member_controls() -> void:
	for control_value: Variant in _member_controls_by_id.values():
		if is_instance_valid(control_value):
			var control := control_value as Control
			if control != null:
				control.free()
	_member_controls_by_id.clear()


func _leader_projection(members: Array[PartyMemberHudProjection]) -> PartyMemberHudProjection:
	for member: PartyMemberHudProjection in members:
		if member.is_leader:
			return member
	return null


func _member_projection(member_id: int) -> PartyMemberHudProjection:
	if current_projection == null:
		return null
	for member: PartyMemberHudProjection in current_projection.members:
		if member.member_id == member_id:
			return member
	return null


func _ordered_member_controls() -> Array[Control]:
	var result: Array[Control] = []
	var parent: Node = get_node("Margin/CombatStatus/PartyRegion/RichRoster") if _metrics.mode == CombatHudResponsiveLayout.Mode.RICH else get_node("Margin/CombatStatus/PartyRegion/CompactRoster/MemberWindow")
	for child: Node in parent.get_children():
		if child is Control:
			result.append(child as Control)
	return result


func _configure_member_focus_neighbors() -> void:
	var controls := _ordered_member_controls()
	if controls.is_empty():
		return
	var columns := 2
	var party_header := get_node("Margin/CombatStatus/PartyHeader") as Button
	var alerts_header := get_node("Margin/CombatStatus/AlertRegion/Header") as Button
	party_header.focus_neighbor_right = party_header.get_path_to(alerts_header)
	alerts_header.focus_neighbor_left = alerts_header.get_path_to(party_header)
	for index: int in controls.size():
		var control := controls[index]
		control.focus_neighbor_left = control.get_path_to(controls[index - 1] if index > 0 else controls[-1])
		control.focus_neighbor_right = control.get_path_to(controls[index + 1] if index + 1 < controls.size() else controls[0])
		control.focus_neighbor_top = control.get_path_to(controls[index - columns] if index >= columns else party_header)
		control.focus_neighbor_bottom = control.get_path_to(controls[index + columns] if index + columns < controls.size() else controls[-1])
	party_header.focus_neighbor_bottom = party_header.get_path_to(get_node("Margin/CombatStatus/LeaderCard") as Control)
	if _metrics.mode == CombatHudResponsiveLayout.Mode.COMPACT:
		var previous := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious") as Button
		var next := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
		previous.focus_neighbor_top = previous.get_path_to(party_header)
		next.focus_neighbor_top = next.get_path_to(party_header)
		previous.focus_neighbor_bottom = previous.get_path_to(controls[0])
		next.focus_neighbor_bottom = next.get_path_to(controls[mini(1, controls.size() - 1)])


func _configure_alert_focus_neighbors() -> void:
	var actions: Array[Control] = []
	for alert: CombatAlertProjection in current_projection.visible_alerts:
		var card: Control
		var card_value: Variant = _alert_controls_by_id.get(alert.stable_id)
		if is_instance_valid(card_value):
			card = card_value as Control
		if card == null or not card.visible:
			continue
		for action_name: StringName in [&"inspect", &"ledger"]:
			var action := _alert_action_control(alert.stable_id, action_name)
			if action != null and action.is_visible_in_tree() and action.focus_mode != Control.FOCUS_NONE and (not action is BaseButton or not (action as BaseButton).disabled):
				actions.append(action)
	var overflow := get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	var tray_action := get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
	var alerts_header := get_node("Margin/CombatStatus/AlertRegion/Header") as Button
	var party_header := get_node("Margin/CombatStatus/PartyHeader") as Button
	alerts_header.focus_neighbor_left = alerts_header.get_path_to(party_header)
	party_header.focus_neighbor_right = party_header.get_path_to(alerts_header)
	var terminal: Control = overflow if overflow.visible else (tray_action if tray_action.visible else alerts_header)
	alerts_header.focus_neighbor_bottom = alerts_header.get_path_to(actions[0] if not actions.is_empty() else terminal)
	for index: int in actions.size():
		var action := actions[index]
		var top: Control = alerts_header if index == 0 else actions[index - 1]
		var bottom: Control = actions[index + 1] if index + 1 < actions.size() else terminal
		action.focus_neighbor_top = action.get_path_to(top)
		action.focus_neighbor_bottom = action.get_path_to(bottom)
	if overflow.visible:
		overflow.focus_neighbor_top = overflow.get_path_to(actions[-1] if not actions.is_empty() else alerts_header)
		overflow.focus_neighbor_bottom = overflow.get_path_to(tray_action if tray_action.visible else alerts_header)
	if tray_action.visible:
		tray_action.focus_neighbor_top = tray_action.get_path_to(overflow if overflow.visible else (actions[-1] if not actions.is_empty() else alerts_header))
		tray_action.focus_neighbor_left = tray_action.get_path_to(party_header)


func _required_authority_error() -> String:
	if party_manager == null or run_context == null or experience_system == null or game_run == null:
		return "required combat data is unavailable"
	if run_context.party != party_manager:
		return "party context does not match"
	if experience_system.run_context != run_context:
		return "experience authority does not match"
	if not game_run.has_method("elapsed_time"):
		return "run timer authority is unavailable"
	var seen: Dictionary = {}
	var leader_count := 0
	for member: PartyMemberState in party_manager.members:
		if member == null or member.member_id <= 0 or member.class_definition == null or seen.has(member.member_id):
			return "party identity is invalid"
		seen[member.member_id] = true
		leader_count += 1 if member.is_leader else 0
		if _health_snapshot(member.member_id).is_empty():
			return "member health is unavailable"
	if party_manager.members.is_empty() or leader_count != 1:
		return "party identity is invalid"
	return ""


func _show_unavailable(reason: String) -> void:
	var concise := reason.strip_edges()
	if concise.is_empty():
		concise = "combat data is unavailable"
	var label := get_node("Margin/CombatStatus/HudUnavailable") as Label
	label.text = "HUD unavailable: %s" % concise
	label.accessibility_name = label.text
	label.visible = true
	if _unavailable_reason != concise:
		push_error("COMBAT_HUD_UNAVAILABLE reason=%s" % concise)
	_unavailable_reason = concise


func _clear_unavailable() -> void:
	_unavailable_reason = ""
	(get_node("Margin/CombatStatus/HudUnavailable") as Control).visible = false


func _alert_order_index(stable_id: StringName) -> int:
	if current_projection == null:
		return 0
	for index: int in current_projection.all_alerts.size():
		if current_projection.all_alerts[index].stable_id == stable_id:
			return index
	return 0


func _party_index_for_member(member_id: int) -> int:
	if current_projection == null:
		return 0
	for index: int in current_projection.members.size():
		if current_projection.members[index].member_id == member_id:
			return index
	return 0


func _alert_action_control(stable_id: StringName, preferred_action: StringName) -> Control:
	var card: Control
	var tray := get_node("CombatAlertTray") as CombatAlertTray
	if tray.visible:
		for child: Node in (tray.get_node("Overlay/Frame/Layout/Scroll/Alerts") as Container).get_children():
			if StringName(child.get_meta(&"stable_alert_id", &"")) == stable_id:
				card = child as Control
				break
	if card == null:
		var card_value: Variant = _alert_controls_by_id.get(stable_id)
		if is_instance_valid(card_value):
			card = card_value as Control
	if card == null or not card.is_visible_in_tree():
		return null
	for action: StringName in [preferred_action, &"inspect", &"ledger"]:
		if action.is_empty():
			continue
		var title := "Inspect" if action == &"inspect" else "Ledger"
		var button := card.get_node_or_null("Surface/Content/Actions/%s" % title) as Button
		if button != null and button.visible and not button.disabled:
			return button
	return null


func _focus_member(member_id: int, preferred_surface: StringName = &"") -> bool:
	if current_projection == null or _member_projection(member_id) == null:
		return false
	var leader := get_node("Margin/CombatStatus/LeaderCard") as Control
	if preferred_surface == &"leader_anchor" and int(leader.get_meta(&"member_id", 0)) == member_id:
		return _grab_valid_focus(leader)
	var control: Control
	var control_value: Variant = _member_controls_by_id.get(member_id)
	if is_instance_valid(control_value):
		control = control_value as Control
	if _grab_valid_focus(control):
		return true
	if _metrics != null and _metrics.mode == CombatHudResponsiveLayout.Mode.COMPACT:
		var index := _party_index_for_member(member_id)
		_set_page(floori(float(index) / float(maxi(_metrics.visible_member_count, 1))))
		control_value = _member_controls_by_id.get(member_id)
		control = null
		if is_instance_valid(control_value):
			control = control_value as Control
		return _grab_valid_focus(control)
	if int(leader.get_meta(&"member_id", 0)) == member_id:
		return _grab_valid_focus(leader)
	return false


func _focus_named_safe_control() -> bool:
	var leader := get_node("Margin/CombatStatus/LeaderCard") as Control
	if _grab_valid_focus(leader):
		return true
	for path: NodePath in [
		^"Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious",
		^"Margin/CombatStatus/PartyRegion/CompactRoster/PageNext",
	]:
		if _grab_valid_focus(get_node(path) as Control):
			return true
	return false


func _named_focus_control(control_name: StringName) -> Control:
	match control_name:
		&"alerts_tray_action": return get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Control
		&"alert_overflow": return get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control
		&"page_previous": return get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious") as Control
		&"page_next": return get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Control
	return null


func _grab_valid_focus(control: Control) -> bool:
	if (
		control == null
		or not is_instance_valid(control)
		or not control.is_inside_tree()
		or not control.is_visible_in_tree()
		or control.focus_mode == Control.FOCUS_NONE
	):
		return false
	control.grab_focus()
	return true


func _child_modal_owns_focus() -> bool:
	var inspector := get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel
	if inspector.visible:
		return true
	var owner := _hud_viewport().gui_get_focus_owner() as Control
	var cursor: Node = owner
	while cursor != null:
		if cursor is CharacterLedger and (cursor as CharacterLedger).visible:
			return true
		cursor = cursor.get_parent()
	return false


func _format_time(seconds: float) -> String:
	var total := maxi(floori(seconds), 0)
	return "%02d:%02d" % [floori(total / 60.0), total % 60]


func _hud_viewport() -> Viewport:
	if custom_viewport != null and is_instance_valid(custom_viewport):
		return custom_viewport
	return (Engine.get_main_loop() as SceneTree).root
