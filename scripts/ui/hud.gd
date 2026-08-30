class_name HUD
extends CanvasLayer

signal inspect_requested(member_id: int, return_focus: Control)
signal ledger_requested(member_id: int, return_focus: Control)

const RICH_MEMBER_SCENE := preload("res://scenes/ui/living_forge/components/forge_party_member_card.tscn")
const COMPACT_MEMBER_SCENE := preload("res://scenes/ui/living_forge/components/forge_party_member_marker.tscn")
const ALERT_CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_alert_card.tscn")

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
var _unavailable_reason := ""
var _deferred_focus_descriptor: Dictionary = {}
var _terminal_suspended_focus_modes: Array[Dictionary] = []
var _terminal_prior_focus: Control
var _terminal_prior_focus_descriptor: Dictionary = {}


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
		if control.focus_mode == Control.FOCUS_NONE:
			continue
		_terminal_suspended_focus_modes.append({"control": control, "focus_mode": control.focus_mode})
		control.focus_mode = Control.FOCUS_NONE


func _restore_non_terminal_focus() -> void:
	for entry: Dictionary in _terminal_suspended_focus_modes:
		var control := entry.get("control") as Control
		if control != null and is_instance_valid(control):
			control.focus_mode = int(entry.get("focus_mode", Control.FOCUS_NONE))
	_terminal_suspended_focus_modes.clear()
	var direct := _terminal_prior_focus
	var descriptor := _terminal_prior_focus_descriptor.duplicate(true)
	_terminal_prior_focus = null
	_terminal_prior_focus_descriptor.clear()
	var direct_disabled := direct is BaseButton and (direct as BaseButton).disabled
	if direct != null and is_instance_valid(direct) and direct.is_visible_in_tree() and direct.focus_mode != Control.FOCUS_NONE and not direct_disabled:
		direct.grab_focus()
		return
	if not descriptor.is_empty():
		restore_focus_descriptor(descriptor)


func _ensure_control_connections() -> void:
	var previous := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious") as Button
	var next := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
	var overflow := get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	if not previous.pressed.is_connected(_on_previous_page): previous.pressed.connect(_on_previous_page)
	if not next.pressed.is_connected(_on_next_page): next.pressed.connect(_on_next_page)
	if not overflow.pressed.is_connected(_on_overflow_pressed): overflow.pressed.connect(_on_overflow_pressed)
	var tray := get_node("CombatAlertTray") as CombatAlertTray
	if not tray.inspect_requested.is_connected(_on_inspect_route): tray.inspect_requested.connect(_on_inspect_route)
	if not tray.ledger_requested.is_connected(_on_ledger_route): tray.ledger_requested.connect(_on_ledger_route)
	if not tray.alerts_resolved.is_connected(_on_alerts_resolved): tray.alerts_resolved.connect(_on_alerts_resolved)
	if not tray.closed.is_connected(_on_modal_closed): tray.closed.connect(_on_modal_closed)
	var inspector := get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel
	if not inspector.closed.is_connected(_on_modal_closed): inspector.closed.connect(_on_modal_closed)


func configure(run: Node, party: PartyManager, experience: ExperienceSystem, context: PlayerRunContext, saved_settings: PartyForgeSettings) -> void:
	_ensure_control_connections()
	_disconnect_authorities()
	_deferred_focus_descriptor.clear()
	game_run = run
	party_manager = party
	experience_system = experience
	run_context = context
	settings = saved_settings if saved_settings != null else PartyForgeSettings.new()
	_high_contrast = settings.high_contrast
	var shell := get_node("Margin/CombatStatus") as Control
	var resolved_theme := LivingForgeThemeCatalog.resolve(_high_contrast, settings.ui_scale_percent, settings.text_scale_percent)
	shell.theme = resolved_theme
	(get_node("CombatAlertTray") as CombatAlertTray).apply_visual_settings(resolved_theme, _high_contrast)
	(get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel).apply_visual_settings(resolved_theme)
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


func restore_focus_descriptor(descriptor: Dictionary) -> bool:
	_deferred_focus_descriptor.clear()
	if descriptor.is_empty():
		return _focus_named_safe_control()
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
	_metrics = CombatHudResponsiveLayout.resolve(_last_viewport_size, settings.ui_scale_percent, settings.text_scale_percent, projection.members.size())
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
	_refresh_open_tray()


func _rebuild_member_controls() -> void:
	_clear_member_controls()
	var members := current_projection.members
	if members.is_empty():
		return
	var leader := _leader_projection(members)
	var leader_card := get_node("Margin/CombatStatus/LeaderCard") as ForgePartyMemberCard
	leader_card.present(leader)
	leader_card.apply_accessibility_variant(_high_contrast)
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
		next.visible = false
		next.disabled = true
		_rebuild_rich_followers(members)
	else:
		_rebuild_compact_page(members)
	_configure_member_focus_neighbors()


func _rebuild_rich_followers(members: Array[PartyMemberHudProjection]) -> void:
	var roster := get_node("Margin/CombatStatus/PartyRegion/RichRoster") as GridContainer
	roster.columns = 2
	for member: PartyMemberHudProjection in members:
		if member.is_leader:
			continue
		var card := RICH_MEMBER_SCENE.instantiate() as ForgePartyMemberCard
		card.custom_minimum_size = Vector2(296.0, 120.0)
		_bind_member_control(card, member)
		roster.add_child(card)


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
	var wanted: Dictionary = {}
	for alert: CombatAlertProjection in current_projection.visible_alerts:
		wanted[alert.stable_id] = true
	for stable_value: Variant in _alert_controls_by_id.keys():
		var stable_id := StringName(stable_value)
		if wanted.has(stable_id):
			continue
		var stale := _alert_controls_by_id[stable_id] as Control
		_alert_controls_by_id.erase(stable_id)
		stale.free()
	var stack := get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as VBoxContainer
	var alerts := current_projection.visible_alerts
	for index: int in alerts.size():
		var alert := alerts[index]
		var card := _alert_controls_by_id.get(alert.stable_id) as ForgeAlertCard
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
		stack.move_child(card, index)
	var overflow := get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	overflow.visible = current_projection.overflow_alert_count > 0
	var overflow_count := current_projection.overflow_alert_count
	overflow.text = "+%d %s" % [overflow_count, "alert" if overflow_count == 1 else "alerts"]
	overflow.accessibility_name = "Open %d additional combat %s" % [overflow_count, "alert" if overflow_count == 1 else "alerts"]
	_configure_alert_focus_neighbors()


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
	label.text = "PARTY %d OF %d" % [_current_page + 1, _metrics.page_count]
	label.accessibility_name = "Party page %d of %d" % [_current_page + 1, _metrics.page_count]


func _on_previous_page() -> void:
	_set_page(_current_page - 1)


func _on_next_page() -> void:
	_set_page(_current_page + 1)


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
	if current_projection != null:
		(get_node("CombatAlertTray") as CombatAlertTray).open(current_projection.all_alerts, get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control)


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
	_refresh_projection(true)


func _on_party_value_changed(_class_id: StringName, _rank: int) -> void:
	_refresh_projection(false)


func _on_party_stats_changed(_member_id: int) -> void:
	_refresh_projection(false)


func _on_progression_changed(_member_id: int) -> void:
	_refresh_projection(false)


func _on_actor_bound(member_id: int, actor: Node3D) -> void:
	_bind_health(member_id, actor)
	_refresh_projection(false)


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
	_refresh_projection(false)


func _on_health_state_changed(_member_id: int) -> void:
	_refresh_projection(false)


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
		(card_value as Control).free()
	_alert_controls_by_id.clear()
	(get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control).visible = false


func _clear_member_controls() -> void:
	for control_value: Variant in _member_controls_by_id.values():
		var control := control_value as Control
		if control != null and is_instance_valid(control):
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
	for index: int in controls.size():
		var control := controls[index]
		control.focus_neighbor_left = control.get_path_to(controls[index - 1] if index > 0 else controls[-1])
		control.focus_neighbor_right = control.get_path_to(controls[index + 1] if index + 1 < controls.size() else controls[0])
		control.focus_neighbor_top = control.get_path_to(controls[index - columns] if index >= columns else controls[0])
		control.focus_neighbor_bottom = control.get_path_to(controls[index + columns] if index + columns < controls.size() else controls[-1])
	if _metrics.mode == CombatHudResponsiveLayout.Mode.COMPACT:
		var previous := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious") as Button
		var next := get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
		previous.focus_neighbor_bottom = previous.get_path_to(controls[0])
		next.focus_neighbor_bottom = next.get_path_to(controls[mini(1, controls.size() - 1)])


func _configure_alert_focus_neighbors() -> void:
	var controls: Array[Control] = []
	for alert: CombatAlertProjection in current_projection.visible_alerts:
		var control := _alert_controls_by_id.get(alert.stable_id) as Control
		if control != null:
			controls.append(control)
	var overflow := get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	for index: int in controls.size():
		var card := controls[index]
		var top: Control = controls[index - 1] if index > 0 else (overflow if overflow.visible else controls[-1])
		var bottom: Control = controls[index + 1] if index + 1 < controls.size() else (overflow if overflow.visible else controls[0])
		card.focus_neighbor_top = card.get_path_to(top)
		card.focus_neighbor_bottom = card.get_path_to(bottom)
	if overflow.visible and not controls.is_empty():
		overflow.focus_neighbor_top = overflow.get_path_to(controls[-1])
		overflow.focus_neighbor_bottom = overflow.get_path_to(controls[0])


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
		card = _alert_controls_by_id.get(stable_id) as Control
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
	var control := _member_controls_by_id.get(member_id) as Control
	if _grab_valid_focus(control):
		return true
	if _metrics != null and _metrics.mode == CombatHudResponsiveLayout.Mode.COMPACT:
		var index := _party_index_for_member(member_id)
		_set_page(floori(float(index) / float(maxi(_metrics.visible_member_count, 1))))
		return _grab_valid_focus(_member_controls_by_id.get(member_id) as Control)
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
