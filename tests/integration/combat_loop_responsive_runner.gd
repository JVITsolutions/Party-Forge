extends SceneTree

const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
	Vector2i(2560, 1080),
	Vector2i(3440, 1440),
]
const PARTY_COUNTS: Array[int] = [1, 6, 7, 12, 20, 24]
const SCALE_CORNERS: Array[Vector2i] = [
	Vector2i(150, 100),
	Vector2i(100, 150),
	Vector2i(150, 150),
	Vector2i(80, 150),
]
const COLLAPSE_STATES: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(0, 0),
]
const RESULT_FIXTURE_PATH := "res://tests/unit/test_run_recap_projection.gd"
const CONDITION_DEADLINE_MS := 2500


class TestRun:
	extends Node
	var seconds := 125.0

	func elapsed_time() -> float:
		return seconds


var _failures: Array[String] = []
var _sequence := 13000
var _active_viewport: SubViewport


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _exercise_primary_action_bar()
	for viewport_size: Vector2i in VIEWPORT_SIZES:
		if viewport_size == Vector2i(1920, 1080):
			for party_count: int in PARTY_COUNTS:
				await _exercise_hud(viewport_size, party_count, 0, 100, 100)
		else:
			await _exercise_hud(viewport_size, 6, 0, 100, 100)
			await _exercise_hud(viewport_size, 24, 7, 100, 100)
		if viewport_size == Vector2i(1280, 720):
			for alert_count: int in [1, 3, 4]:
				await _exercise_hud(viewport_size, 6, alert_count, 100, 100)
		await _exercise_level_up(viewport_size, 100, 100)
		await _exercise_extraction(viewport_size, 100, 100)
		await _exercise_result(viewport_size, 100, 100)
	for scale_corner: Vector2i in SCALE_CORNERS:
		await _exercise_hud(Vector2i(1280, 720), 24, 7, scale_corner.x, scale_corner.y)
		await _exercise_level_up(Vector2i(1280, 720), scale_corner.x, scale_corner.y)
		await _exercise_extraction(Vector2i(1280, 720), scale_corner.x, scale_corner.y)
		await _exercise_result(Vector2i(1280, 720), scale_corner.x, scale_corner.y)
		if _long_detail_corner(Vector2i(1280, 720), scale_corner.x, scale_corner.y):
			await _exercise_result(Vector2i(1280, 720), scale_corner.x, scale_corner.y, true)
	await _exercise_zero_health_collapsed_track(false)
	await _exercise_zero_health_collapsed_track(true)
	_finish()


func _assert_hud_collapse_geometry(hud: HUD, viewport_rect: Rect2, party_count: int, alert_count: int, party_collapsed: bool, alerts_collapsed: bool, ui_scale: int, text_scale: int, context_label: String) -> void:
	var party_header := hud.get_node("Margin/CombatStatus/PartyHeader") as Button
	var party_summary := hud.get_node("Margin/CombatStatus/PartyHeader/Content/Summary") as Label
	var party_health_cluster := hud.get_node_or_null("Margin/CombatStatus/PartyHeader/Content/LeaderHealthCluster") as Control
	var party_health := party_health_cluster.get_node_or_null("Bar") as ProgressBar if party_health_cluster != null else null
	var party_health_value := party_health_cluster.get_node_or_null("Value") as Label if party_health_cluster != null else null
	var leader := hud.get_node("Margin/CombatStatus/LeaderCard") as Control
	var experience := hud.get_node("Margin/CombatStatus/Experience") as Control
	var party_region := hud.get_node("Margin/CombatStatus/PartyRegion") as Control
	var timer := hud.get_node("Margin/CombatStatus/RunTime") as Control
	var alert_region := hud.get_node("Margin/CombatStatus/AlertRegion") as Control
	var alerts_header := hud.get_node("Margin/CombatStatus/AlertRegion/Header") as Button
	var alerts_summary := hud.get_node("Margin/CombatStatus/AlertRegion/Header/Content/Summary") as Label
	var alerts_stack := hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as VBoxContainer
	var overflow := hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	var tray_action := hud.get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
	for header: Button in [party_header, alerts_header]:
		_assert_contained(header, viewport_rect, "%s %s" % [context_label, header.name])
		_assert(header.get_global_rect().size.x >= 48.0 and header.get_global_rect().size.y >= 48.0, "%s %s keeps a real 48x48 target" % [context_label, header.name])
	_assert(party_header.get_global_rect().encloses(party_summary.get_global_rect()), "%s Party summary remains inside its header header=%s summary=%s" % [context_label, party_header.get_global_rect(), party_summary.get_global_rect()])
	_assert(alerts_header.get_global_rect().encloses(alerts_summary.get_global_rect()), "%s Alerts summary remains inside its header header=%s summary=%s" % [context_label, alerts_header.get_global_rect(), alerts_summary.get_global_rect()])
	_assert(party_health_cluster != null and party_health != null and party_health_value != null, "%s compact leader health uses the dedicated bar-and-value cluster" % context_label)
	if party_health_cluster != null:
		_assert(party_health_cluster.visible == party_collapsed, "%s compact leader health visibility follows Party collapse" % context_label)
		if party_health_cluster.visible:
			var header_rect := party_header.get_global_rect()
			var cluster_rect := party_health_cluster.get_global_rect()
			_assert(header_rect.encloses(cluster_rect), "%s compact leader health cluster remains inside Party header header=%s cluster=%s" % [context_label, header_rect, cluster_rect])
			if party_health != null and party_health_value != null:
				var projected_leader := hud.current_projection.leader() if hud.current_projection != null else null
				var expected_health_text := "%d / %d" % [roundi(projected_leader.health), roundi(projected_leader.max_health)] if projected_leader != null else ""
				var bar_rect := party_health.get_global_rect()
				var value_rect := party_health_value.get_global_rect()
				_assert(cluster_rect.encloses(bar_rect) and cluster_rect.encloses(value_rect), "%s collapsed health bar and exact value remain enclosed by the cluster" % context_label)
				_assert(not bar_rect.intersection(value_rect).has_area(), "%s collapsed health bar and exact value never overlap" % context_label)
				_assert(party_health_value.text == expected_health_text, "%s collapsed leader health exposes exact readable current and maximum expected=%s actual=%s" % [context_label, expected_health_text, party_health_value.text])
				if text_scale == 150:
					_assert(absf(cluster_rect.get_center().y - header_rect.get_center().y) <= 1.0, "%s Text150 health cluster remains vertically centered header=%s cluster=%s" % [context_label, header_rect, cluster_rect])
					_assert(cluster_rect.position.y - header_rect.position.y >= 4.0 and header_rect.end.y - cluster_rect.end.y >= 4.0, "%s Text150 health cluster remains away from the header border" % context_label)
					_assert(party_health_value.get_visible_line_count() == party_health_value.get_line_count(), "%s Text150 exact health value is fully readable" % context_label)
	if text_scale == 150:
		for summary: Label in [party_summary, alerts_summary]:
			_assert(summary.autowrap_mode != TextServer.AUTOWRAP_OFF, "%s %s uses wrapping at Text150" % [context_label, summary.name])
			_assert(summary.get_visible_line_count() == summary.get_line_count(), "%s %s exposes every wrapped line at Text150" % [context_label, summary.name])
	var party_chain: Array[Control] = [party_header]
	if not party_collapsed:
		party_chain.append_array([leader, experience, party_region])
		_assert(leader.visible and experience.visible and party_region.visible, "%s expanded Party exposes leader, XP, and roster" % context_label)
	else:
		_assert(not leader.visible and not experience.visible and not party_region.visible, "%s collapsed Party hides leader, XP, and roster" % context_label)
	var party_rects: Array[Rect2] = []
	for control: Control in party_chain:
		_assert_contained(control, viewport_rect, "%s %s" % [context_label, control.name])
		_assert_no_overlap(control.get_global_rect(), party_rects, "%s Party header/leader/XP/roster chain" % context_label)
		party_rects.append(control.get_global_rect())
		_assert(not control.get_global_rect().intersection(timer.get_global_rect()).has_area(), "%s %s does not overlap timer" % [context_label, control.name])
		_assert(not control.get_global_rect().intersection(alert_region.get_global_rect()).has_area(), "%s %s does not overlap Alerts" % [context_label, control.name])
	_assert_contained(alert_region, viewport_rect, "%s AlertRegion" % context_label)
	var alert_controls: Array[Control] = [alerts_header]
	var rendered_count := 0
	for child: Node in alerts_stack.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			rendered_count += 1
			alert_controls.append(child as Control)
	if overflow.visible:
		alert_controls.append(overflow)
	if tray_action.visible:
		alert_controls.append(tray_action)
	var alert_rects: Array[Rect2] = []
	for control: Control in alert_controls:
		_assert_contained(control, alert_region.get_global_rect(), "%s %s" % [context_label, control.name])
		_assert_no_overlap(control.get_global_rect(), alert_rects, "%s Alerts header/cards/overflow/tray" % context_label)
		alert_rects.append(control.get_global_rect())
	if tray_action.visible:
		_assert(tray_action.get_global_rect().size.x >= 48.0 and tray_action.get_global_rect().size.y >= 48.0, "%s tray action keeps a real 48x48 target" % context_label)
		var header_rect := alerts_header.get_global_rect()
		var tray_rect := tray_action.get_global_rect()
		var stack_rect := alerts_stack.get_global_rect()
		var compact_gap := float(LivingForgeTokens.spacing(&"compact"))
		if viewport_rect.size == Vector2(1920, 1080) and ui_scale == 100 and text_scale == 100:
			_assert(absf(header_rect.position.y - tray_rect.position.y) <= 1.0, "%s fitting Alerts header and tray share one row header=%s tray=%s" % [context_label, header_rect, tray_rect])
			_assert(header_rect.end.x + compact_gap <= tray_rect.position.x + 1.0, "%s fitting Alerts header and tray retain their horizontal gap" % context_label)
		if viewport_rect.size == Vector2(1280, 720) and ui_scale == 150 and text_scale == 150:
			_assert(absf(tray_rect.position.y - (header_rect.end.y + compact_gap)) <= 1.0, "%s constrained Text150 tray wraps immediately below the Alerts header header=%s tray=%s" % [context_label, header_rect, tray_rect])
		_assert(stack_rect.position.y + 1.0 >= maxf(header_rect.end.y, tray_rect.end.y) + compact_gap, "%s ExpandedAlerts begins after the lower header/tray edge" % context_label)
	_assert(tray_action.visible == (alert_count > 0), "%s persistent tray availability matches exact alert truth" % context_label)
	_assert(rendered_count == 0 if alerts_collapsed else rendered_count <= mini(alert_count, CombatHudProjection.MAX_VISIBLE_ALERTS), "%s expanded card count respects collapsed state and projection cap" % context_label)
	var hidden_count := alert_count - rendered_count
	_assert(overflow.visible == (not alerts_collapsed and hidden_count > 0), "%s overflow visibility matches exact rendered budget" % context_label)
	if overflow.visible:
		_assert(overflow.get_global_rect().size.x >= 48.0 and overflow.get_global_rect().size.y >= 48.0, "%s overflow keeps a real 48x48 target" % context_label)
		_assert(overflow.text == "+%d %s" % [hidden_count, "alert" if hidden_count == 1 else "alerts"], "%s overflow names the exact hidden alert count" % context_label)
		_assert(absf(overflow.get_global_rect().end.y - alert_region.get_global_rect().end.y) <= 1.0, "%s overflow remains reserved against the bottom edge" % context_label)
		for child: Node in alerts_stack.get_children():
			if child is Control and (child as Control).is_visible_in_tree():
				_assert((child as Control).get_global_rect().end.y + float(LivingForgeTokens.spacing(&"compact")) <= overflow.get_global_rect().position.y + 1.0, "%s rendered alert cards end before the reserved overflow row" % context_label)
	var metrics := hud.get("_metrics") as CombatHudResponsiveLayout.Metrics
	_assert(metrics != null and metrics.visible_member_count >= 1, "%s paging keeps at least one visible member" % context_label)
	if metrics != null:
		_assert(metrics.page_count == maxi(1, ceili(float(party_count) / float(metrics.visible_member_count))), "%s paging count matches the exact visible window" % context_label)
		_assert(metrics.clamped_page(metrics.page_count - 1) == metrics.page_count - 1, "%s final compact page remains reachable" % context_label)


func _exercise_hud(viewport_size: Vector2i, party_count: int, alert_count: int, ui_scale: int, text_scale: int) -> void:
	var viewport := _new_viewport(viewport_size)
	var context_label := _context("HUD", viewport_size, ui_scale, text_scale, "party=%d alerts=%d" % [party_count, alert_count])
	var fixture := _hud_fixture(party_count, alert_count, ui_scale, text_scale)
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	hud.custom_viewport = viewport
	viewport.add_child(hud)
	hud.configure(fixture.run, fixture.party, fixture.experience, fixture.context, fixture.settings)
	await _wait_until(func() -> bool:
		return hud.current_projection != null \
			and hud.current_projection.members.size() == party_count \
			and hud.current_projection.all_alerts.size() == alert_count
	, "%s authoritative HUD projection" % context_label)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var shell := hud.get_node("Margin/CombatStatus") as Control
	var leader := hud.get_node("Margin/CombatStatus/LeaderCard") as Control
	var party_region := hud.get_node("Margin/CombatStatus/PartyRegion") as Control
	var alert_region := hud.get_node("Margin/CombatStatus/AlertRegion") as Control
	var rich := hud.get_node("Margin/CombatStatus/PartyRegion/RichRoster") as Control
	var compact := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster") as Control
	var overflow := hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	var expected_metrics := CombatHudResponsiveLayout.resolve(viewport_size, ui_scale, text_scale, party_count)
	var rich_expected := expected_metrics.mode == CombatHudResponsiveLayout.Mode.RICH
	await _wait_for_stable_layout([shell, leader, party_region, alert_region], context_label)
	for state: Vector2i in COLLAPSE_STATES:
		hud.apply_collapse_preferences(state.x == 1, state.y == 1)
		await process_frame
		await process_frame
		var collapse_context := _context(
			"HUD_COLLAPSE",
			viewport_size,
			ui_scale,
			text_scale,
			"party=%d alerts=%d party_collapsed=%s alerts_collapsed=%s" % [party_count, alert_count, state.x == 1, state.y == 1],
		)
		_assert_hud_collapse_geometry(hud, viewport_rect, party_count, alert_count, state.x == 1, state.y == 1, ui_scale, text_scale, collapse_context)
	var measured_party_header := (hud.get_node("Margin/CombatStatus/PartyHeader") as Button).size.y
	expected_metrics = CombatHudResponsiveLayout.resolve(viewport_size, ui_scale, text_scale, party_count, measured_party_header)
	rich_expected = expected_metrics.mode == CombatHudResponsiveLayout.Mode.RICH
	for control: Control in [shell, leader, party_region, alert_region]:
		_assert_contained(control, viewport_rect, "%s %s" % [context_label, control.name])
	_assert(not leader.get_global_rect().intersection(alert_region.get_global_rect()).has_area(), "%s leader and alert region do not overlap" % context_label)
	_assert(not party_region.get_global_rect().intersection(alert_region.get_global_rect()).has_area(), "%s party and alert regions do not overlap" % context_label)
	_assert(rich.visible == rich_expected, "%s rich mode follows resolved viewport/scale fit" % context_label)
	_assert(compact.visible == not rich_expected, "%s compact mode follows resolved viewport/scale fit" % context_label)
	_assert(int(leader.get_meta(&"member_id", 0)) == 1, "%s stable leader identity is retained" % context_label)

	var projection := hud.current_projection
	_assert(projection != null and projection.members.size() == party_count, "%s projection retains every party member" % context_label)
	_assert(projection != null and projection.all_alerts.size() == alert_count, "%s projection retains exact alert count" % context_label)
	if projection != null:
		_assert(projection.visible_alerts.size() == mini(alert_count, 3), "%s renders at most three expanded alerts" % context_label)
		_assert(projection.overflow_alert_count == maxi(0, alert_count - 3), "%s exposes exact overflow alert count" % context_label)
	var rendered_alert_count := 0
	for child: Node in (hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Container).get_children():
		if child is Control and (child as Control).visible:
			rendered_alert_count += 1
	_assert(overflow.visible == (alert_count > rendered_alert_count), "%s overflow action visibility matches the resolved vertical alert budget" % context_label)
	if alert_count > rendered_alert_count:
		var overflow_count := alert_count - rendered_alert_count
		_assert(overflow.text == "+%d %s" % [overflow_count, "alert" if overflow_count == 1 else "alerts"], "%s overflow action names exact hidden count" % context_label)
		_assert_target(overflow, "%s overflow action" % context_label)

	var seen_members: Dictionary = {}
	if rich_expected:
		seen_members[1] = true
		var rich_controls := _hud_roster_controls(hud)
		_assert_control_set_geometry(rich_controls, viewport_rect, "%s rich members" % context_label)
		if rich_controls.size() >= 2:
			rich_controls[0].grab_focus()
			await _wait_for_focus(rich_controls[0], "%s first rich member" % context_label)
			await _push_action(&"ui_right")
			await _wait_for_focus(rich_controls[1], "%s second rich member" % context_label)
		for control: Control in rich_controls:
			var member_id := int(control.get_meta(&"member_id", 0))
			_assert(not seen_members.has(member_id), "%s renders member %d exactly once" % [context_label, member_id])
			seen_members[member_id] = true
			_assert_target(control, "%s rich member %d" % [context_label, member_id])
	else:
		var previous := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious") as Button
		var next := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
		var page_guard := 0
		while true:
			var page_controls := _hud_roster_controls(hud)
			_assert_control_set_geometry(page_controls, viewport_rect, "%s compact page %d members" % [context_label, page_guard + 1])
			if page_guard == 0 and page_controls.size() >= 2:
				page_controls[0].grab_focus()
				await _wait_for_focus(page_controls[0], "%s first compact member" % context_label)
				await _push_action(&"ui_right")
				await _wait_for_focus(page_controls[1], "%s second compact member" % context_label)
			for control: Control in page_controls:
				var member_id := int(control.get_meta(&"member_id", 0))
				_assert(not seen_members.has(member_id), "%s paged member %d appears on exactly one page" % [context_label, member_id])
				seen_members[member_id] = true
				_assert_target(control, "%s compact member %d" % [context_label, member_id])
			if next.disabled:
				break
			var prior_page := int(hud.get("_current_page"))
			var prior_control_ids: Dictionary = {}
			for control: Control in page_controls:
				prior_control_ids[control.get_instance_id()] = true
			if _authentic_stress(viewport_size, ui_scale, text_scale):
				next.grab_focus()
				await _wait_for_focus(next, "%s Next page" % context_label)
				await _activate_focused()
			else:
				next.pressed.emit()
			await _wait_until(func() -> bool:
				if int(hud.get("_current_page")) != prior_page + 1:
					return false
				var replacement_controls := _hud_roster_controls(hud)
				if replacement_controls.is_empty():
					return false
				for replacement: Control in replacement_controls:
					if prior_control_ids.has(replacement.get_instance_id()):
						return false
				return true
			, "%s page %d fresh control identities" % [context_label, prior_page + 2])
			await _wait_for_stable_layout(_hud_roster_controls(hud), "%s page %d replacement controls" % [context_label, prior_page + 2])
			page_guard += 1
			if page_guard > 24:
				_assert(false, "%s pagination terminates within 24 pages" % context_label)
				break
		var metrics := hud.get("_metrics") as CombatHudResponsiveLayout.Metrics
		if metrics != null and metrics.page_count > 1:
			_assert(previous.visible and next.visible, "%s multi-page compact actions remain visible" % context_label)
			_assert_bounds(previous, "%s previous page" % context_label)
			_assert_bounds(next, "%s next page" % context_label)
			_assert(not next.has_focus(), "%s disabled final-page action is excluded from focus" % context_label)
		else:
			_assert(not previous.visible and previous.disabled and not previous.has_focus(), "%s one-page compact Previous is hidden, disabled, and excluded from focus" % context_label)
			_assert(not next.visible and next.disabled and not next.has_focus(), "%s one-page compact Next is hidden, disabled, and excluded from focus" % context_label)
		var final_control := _hud_member_control(hud, party_count)
		_assert(final_control != null, "%s final member remains rendered on the final page" % context_label)
		if final_control != null:
			final_control.grab_focus()
			await _wait_for_focus(final_control, "%s final member" % context_label)
			_assert(final_control.has_focus(), "%s final member is keyboard/controller focusable" % context_label)
	_assert(seen_members.size() == party_count, "%s reaches all %d stable member identities" % [context_label, party_count])
	for member_id: int in range(1, party_count + 1):
		_assert(seen_members.has(member_id), "%s reaches stable member %d" % [context_label, member_id])

	var alert_rects: Array[Rect2] = []
	for child: Node in (hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Container).get_children():
		if not child is Control or not (child as Control).visible:
			continue
		var card := child as Control
		_assert_contained(card, viewport_rect, "%s expanded alert" % context_label)
		_assert_no_overlap(card.get_global_rect(), alert_rects, "%s expanded alerts" % context_label)
		alert_rects.append(card.get_global_rect())
		for action_name: String in ["Inspect", "Ledger"]:
			var action := card.get_node("Surface/Content/Actions/%s" % action_name) as Button
			if action.visible:
				_assert_target(action, "%s alert %s" % [context_label, action_name])
				_assert(card.get_global_rect().encloses(action.get_global_rect()), "%s alert %s stays inside its card" % [context_label, action_name])
	var visible_hud_actions := _visible_buttons(hud.get_node("Margin/CombatStatus") as Control)
	_assert_controls_within_owning_surface(visible_hud_actions, viewport_rect, "%s visible actions" % context_label)
	hud.free()
	_cleanup_hud_fixture(fixture)
	viewport.free()
	_active_viewport = null


func _exercise_zero_health_collapsed_track(high_contrast: bool) -> void:
	var viewport_size := Vector2i(1280, 720)
	var viewport := _new_viewport(viewport_size)
	var fixture := _hud_fixture(24, 7, 100, 150)
	(fixture.settings as PartyForgeSettings).high_contrast = high_contrast
	(fixture.health_by_member[1] as HealthComponent).kill()
	var context_label := "HUD_ZERO_HEALTH_720P_TEXT150 high_contrast=%s" % high_contrast
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	hud.custom_viewport = viewport
	viewport.add_child(hud)
	hud.configure(fixture.run, fixture.party, fixture.experience, fixture.context, fixture.settings)
	await _wait_until(func() -> bool:
		return hud.current_projection != null and hud.current_projection.leader() != null and is_zero_approx(hud.current_projection.leader().health)
	, "%s authoritative zero-health projection" % context_label)
	hud.apply_collapse_preferences(true, true)
	var party_header := hud.get_node("Margin/CombatStatus/PartyHeader") as Button
	var cluster := hud.get_node("Margin/CombatStatus/PartyHeader/Content/LeaderHealthCluster") as Control
	var bar := cluster.get_node("Bar") as ProgressBar
	var value := cluster.get_node("Value") as Label
	await _wait_for_stable_layout([party_header, cluster, bar, value], context_label)
	var header_rect := party_header.get_global_rect()
	var cluster_rect := cluster.get_global_rect()
	var bar_rect := bar.get_global_rect()
	var value_rect := value.get_global_rect()
	_assert(header_rect.encloses(cluster_rect) and cluster_rect.encloses(bar_rect), "%s actual Bar remains fully enclosed header=%s cluster=%s bar=%s" % [context_label, header_rect, cluster_rect, bar_rect])
	_assert(bar_rect.size.x >= 96.0 and bar_rect.size.y >= 12.0, "%s actual Bar keeps at least 96x12 geometry: %s" % [context_label, bar_rect])
	_assert(is_zero_approx(bar.value) and value.text == "0 / 100", "%s preserves true zero and exact 0 / 100 text" % context_label)
	_assert(cluster_rect.encloses(value_rect) and not bar_rect.intersection(value_rect).has_area(), "%s exact value remains visible, enclosed, and nonoverlapping bar=%s value=%s" % [context_label, bar_rect, value_rect])
	var track := bar.get_theme_stylebox(&"background") as StyleBoxFlat
	var header_style := party_header.get_theme_stylebox(&"normal") as StyleBoxFlat
	var expected_width := 2 if high_contrast else 1
	_assert(track != null and track.border_width_left == expected_width and track.border_width_top == expected_width and track.border_width_right == expected_width and track.border_width_bottom == expected_width, "%s track uses the required semantic outline width=%d" % [context_label, expected_width])
	_assert(track != null and track.border_color == LivingForgeTokens.color(&"disabled", high_contrast), "%s track uses the muted non-focus outline token" % context_label)
	_assert(track != null and header_style != null and _contrast_ratio(track.border_color, header_style.bg_color) >= 3.0, "%s track outline separates measurably from the actual header surface" % context_label)
	hud.free()
	_cleanup_hud_fixture(fixture)
	viewport.free()
	_active_viewport = null


func _exercise_level_up(viewport_size: Vector2i, ui_scale: int, text_scale: int) -> void:
	var viewport := _new_viewport(viewport_size)
	var context_label := _context("LEVEL_UP", viewport_size, ui_scale, text_scale, "party=24")
	var catalog := GameCatalog.load_defaults()
	var party := _party(24, catalog)
	var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
	viewport.add_child(panel)
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
	var settings := _settings(ui_scale, text_scale)
	settings.reduced_motion = true
	panel.configure_visual_settings(settings)
	var choice := UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality"))
	panel.show_choices([choice], party)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var frame := panel.get_node("Frame") as Control
	var offer_scroll := panel.get_node("Frame/Content/Offer/CardsScroll") as ScrollContainer
	var card := panel.get_node("Frame/Content/Offer/CardsScroll/Cards/Card1") as UpgradeCard
	await _wait_until(func() -> bool: return card.is_visible_in_tree() and card.bound_choice_key() == StringName(choice.key()), "%s offer binding" % context_label)
	await _wait_for_stable_layout([frame, offer_scroll, card], "%s offer" % context_label)
	_assert_contained(frame, viewport_rect, "%s frame" % context_label)
	_assert_contained(offer_scroll, frame.get_global_rect(), "%s offer scroll" % context_label)
	_assert_target(card, "%s offer card" % context_label)
	card.activated.emit(card.bound_choice_key())
	var picker := panel.get_node("Frame/Content/Recipient") as UpgradeRecipientPicker
	var recipient_scroll := picker.get_node("Content/RecipientsScroll") as ScrollContainer
	var rows := picker.get_node("Content/RecipientsScroll/Rows") as VBoxContainer
	await _wait_until(func() -> bool: return picker.is_visible_in_tree() and rows.get_child_count() == 24, "%s 24-recipient picker" % context_label)
	await _wait_for_stable_layout([frame, picker, recipient_scroll, rows], "%s recipient picker" % context_label)
	_assert(picker.visible, "%s targeted choice opens recipient picker" % context_label)
	_assert(rows.get_child_count() == 24, "%s recipient picker renders all 24 members" % context_label)
	var member_24 := rows.get_node_or_null("Member_24") as Button
	_assert(member_24 != null, "%s final recipient exists" % context_label)
	var recipient_rows := _direct_visible_controls(rows, "Button")
	_assert_controls_contained(recipient_rows, rows.get_global_rect(), "%s recipient rows" % context_label)
	_assert_sibling_non_overlap(recipient_rows, "%s recipient rows" % context_label)
	if member_24 != null:
		if _authentic_stress(viewport_size, ui_scale, text_scale):
			var first := rows.get_node("Member_1") as Button
			first.grab_focus()
			await _wait_for_focus(first, "%s first recipient" % context_label)
			for _step: int in 23:
				await _push_action(&"ui_down")
		else:
			var first := rows.get_node("Member_1") as Button
			var second := rows.get_node("Member_2") as Button
			first.grab_focus()
			await _wait_for_focus(first, "%s first recipient" % context_label)
			await _push_action(&"ui_down")
			await _wait_for_focus(second, "%s second recipient" % context_label)
			member_24.grab_focus()
		await _wait_for_focus(member_24, "%s recipient 24" % context_label)
		await _wait_for_scroll_reveal(recipient_scroll, member_24, "%s recipient 24" % context_label)
		var cancel_recipient := picker.get_node("Content/Cancel") as Button
		await _push_action(&"ui_down")
		await _wait_for_focus(cancel_recipient, "%s recipient endpoint Cancel" % context_label)
		await _push_action(&"ui_up")
		await _wait_for_focus(member_24, "%s recipient endpoint return" % context_label)
		_assert(member_24.has_focus(), "%s authentic spatial traversal reaches recipient 24" % context_label)
		_assert(_visible_inside(recipient_scroll, member_24), "%s focused recipient 24 is visible in its scroll viewport" % context_label)
		_assert_target(member_24, "%s recipient 24" % context_label)
		await _activate_focused()
	var confirmation := panel.get_node("Frame/Content/Confirmation") as Control
	var confirmation_body := panel.get_node("Frame/Content/Confirmation/BodyScroll") as ScrollContainer
	var confirmation_actions := panel.get_node("Frame/Content/Confirmation/Actions") as Control
	var confirm := panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button
	await _wait_for_visible(confirmation, "%s confirmation" % context_label)
	await _wait_for_stable_layout([confirmation, confirmation_body, confirmation_actions, confirm], "%s confirmation" % context_label)
	_assert(confirmation.visible, "%s final recipient opens exact confirmation" % context_label)
	_assert_contained(confirmation, frame.get_global_rect(), "%s confirmation" % context_label)
	_assert_contained(confirmation_body, confirmation.get_global_rect(), "%s confirmation body" % context_label)
	_assert(not confirmation_body.is_ancestor_of(confirmation_actions), "%s confirmation actions stay pinned outside prose" % context_label)
	_assert_target(confirm, "%s confirmation action" % context_label)
	confirm.grab_focus()
	await _wait_for_focus(confirm, "%s Level-up Confirm" % context_label)
	_assert_focused_primary_action(confirm, panel.theme, &"LivingForgePrimaryButton", "%s Level-up Confirm" % context_label)
	var confirmation_buttons := _direct_visible_controls(confirmation_actions, "Button")
	_assert_control_set_geometry(confirmation_buttons, confirmation.get_global_rect(), "%s confirmation actions" % context_label)
	_assert_controls_in_parent(_visible_buttons(panel), "%s all visible level-up actions" % context_label)
	panel.show_choices([], party, {&"__empty__": "No eligible upgrades remain."})
	var retry_offers := panel.get_node("Frame/Content/Offer/RetryOffers") as Button
	await _wait_for_visible(retry_offers, "%s Retry Offers" % context_label)
	retry_offers.grab_focus()
	await _wait_for_focus(retry_offers, "%s Retry Offers" % context_label)
	_assert_focused_primary_action(retry_offers, panel.theme, &"LivingForgePrimaryButton", "%s Retry Offers" % context_label)
	panel.free()
	viewport.free()
	_active_viewport = null
	party.free()


func _exercise_extraction(viewport_size: Vector2i, ui_scale: int, text_scale: int) -> void:
	var viewport := _new_viewport(viewport_size)
	var context_label := _context("EXTRACTION", viewport_size, ui_scale, text_scale, "items=24")
	var panel := (load("res://scenes/ui/run_result/terminal_extraction_panel.tscn") as PackedScene).instantiate() as TerminalExtractionPanel
	viewport.add_child(panel)
	panel.apply_visual_settings(_settings(ui_scale, text_scale))
	var projection := _extraction_projection(24, 8, 2)
	panel.present(projection)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var frame := panel.get_node("Frame") as Control
	var header := panel.get_node("Frame/Content/Header") as Control
	var body := panel.get_node("Frame/Content/Body") as ScrollContainer
	var automatic_scroll := panel.get_node("Frame/Content/Body/Sections/Automatic/Scroll") as ScrollContainer
	var actions := panel.get_node("Frame/Content/Actions") as Control
	var confirm := panel.get_node("Frame/Content/Actions/Confirm") as Button
	await _wait_until(func() -> bool: return _extraction_cards(panel).size() == 24, "%s 24 eligible extraction cards" % context_label)
	await _wait_for_stable_layout([frame, body, actions, confirm], context_label)
	confirm.grab_focus()
	await _wait_for_focus(confirm, "%s Confirm Extraction" % context_label)
	_assert_focused_primary_action(confirm, panel.theme, &"LivingForgePrimaryButton", "%s Confirm Extraction" % context_label)
	_assert_contained(frame, viewport_rect, "%s frame" % context_label)
	_assert_contained(body, frame.get_global_rect(), "%s body" % context_label)
	_assert(not body.is_ancestor_of(actions), "%s actions remain pinned outside item scrolling" % context_label)
	_assert_target(confirm, "%s confirm action" % context_label)
	var cards := _extraction_cards(panel)
	_assert(cards.size() == 24, "%s renders all 24 eligible items" % context_label)
	var unique_ids: Dictionary = {}
	for card: Button in cards:
		var item_id := String(card.get_meta(&"item_id", ""))
		_assert(not item_id.is_empty() and not unique_ids.has(item_id), "%s renders stable item %s exactly once" % [context_label, item_id])
		unique_ids[item_id] = true
		_assert_target(card, "%s item %s" % [context_label, item_id])
		_assert_contained(card, (card.get_parent() as Control).get_global_rect(), "%s item %s owning grid" % [context_label, item_id])
		var inspect := card.get_node("Content/Footer/Inspect") as Button
		_assert_target(inspect, "%s item %s Inspect" % [context_label, item_id])
		_assert_contained(inspect, card.get_global_rect(), "%s item %s Inspect" % [context_label, item_id])
		if _extraction_design_corner(viewport_size, ui_scale, text_scale):
			_assert_extraction_card_layout(card, context_label, item_id)
	_assert_sibling_non_overlap(cards, "%s extraction cards" % context_label)
	if _extraction_design_corner(viewport_size, ui_scale, text_scale):
		_assert_extraction_grid_fill(cards, context_label)
	var extraction_actions := _direct_visible_controls(actions, "Button")
	_assert_control_set_geometry(extraction_actions, frame.get_global_rect(), "%s pinned actions" % context_label)
	var automatic_cards := _automatic_extraction_cards(panel)
	if not automatic_cards.is_empty():
		var automatic_card := automatic_cards[0]
		if _extraction_design_corner(viewport_size, ui_scale, text_scale):
			_assert_extraction_card_layout(automatic_card, context_label, String(automatic_card.get_meta(&"item_id", "automatic")))
		var automatic_inspect := automatic_card.get_node("Content/Footer/Inspect") as Button
		automatic_inspect.grab_focus()
		await _wait_for_focus(automatic_inspect, "%s first automatic Inspect" % context_label)
		await _wait_until(func() -> bool: return automatic_scroll.scroll_horizontal == 0 and body.get_global_rect().encloses(automatic_card.get_global_rect()), "%s automatic origin restoration" % context_label)
		_assert(automatic_scroll.get_global_rect().encloses(automatic_card.get_global_rect()), "%s first automatic card is fully visible with its leading edge" % context_label)
	if cards.size() == 24:
		var first_card := cards[0]
		var first_inspect := first_card.get_node("Content/Footer/Inspect") as Button
		var second_card := cards[1]
		first_card.grab_focus()
		await _wait_for_focus(first_card, "%s first extraction card" % context_label)
		await _push_action(&"ui_right")
		await _wait_for_focus(first_inspect, "%s first extraction Inspect" % context_label)
		await _push_action(&"ui_right")
		await _wait_for_focus(second_card, "%s second extraction card" % context_label)
		var final_card := cards[-1]
		final_card.grab_focus()
		await _wait_for_focus(final_card, "%s final extraction card" % context_label)
		await _wait_for_scroll_reveal(body, final_card, "%s final extraction card" % context_label)
		_assert(final_card.has_focus(), "%s final item is keyboard/controller focusable" % context_label)
		_assert(_visible_inside(body, final_card), "%s final focused item is visible inside the extraction body" % context_label)
		var final_inspect := final_card.get_node("Content/Footer/Inspect") as Button
		await _push_action(&"ui_right")
		await _wait_for_focus(final_inspect, "%s final extraction Inspect" % context_label)
		await _push_action(&"ui_right")
		await _wait_for_focus(confirm, "%s extraction endpoint Confirm" % context_label)
		final_card.grab_focus()
		await _wait_for_focus(final_card, "%s final extraction card detail return anchor" % context_label)
		panel.show_detail(projection.eligible_items[-1], final_card)
		var detail := panel.get_node("ItemTooltipDetail") as Control
		var detail_frame := panel.get_node("ItemTooltipDetail/Frame") as Control
		var detail_tooltip := panel.get_node("ItemTooltipDetail/Frame/Tooltip") as ItemTooltipPanel
		var detail_close := panel.get_node("ItemTooltipDetail/Frame/Tooltip/Layout/Header/Close") as Button
		await _wait_for_visible(detail, "%s item detail" % context_label)
		await _wait_for_stable_layout([detail_frame, detail_tooltip, detail_close], "%s item detail" % context_label)
		_assert(detail.visible, "%s final item detail opens" % context_label)
		_assert_contained(detail_frame, viewport_rect, "%s item detail" % context_label)
		_assert_contained(detail_tooltip, detail_frame.get_global_rect(), "%s populated item detail tooltip" % context_label)
		_assert(detail_tooltip.card_count() > 0, "%s item detail exposes real item content" % context_label)
		_assert((detail_tooltip.get_node("Layout/Header") as Control).is_visible_in_tree(), "%s item detail keeps its header visible" % context_label)
		_assert((detail_tooltip.get_node("Layout/InputHints") as Control).is_visible_in_tree(), "%s item detail keeps its input help visible" % context_label)
		var item_card := detail_tooltip.get_node("Layout/BodyScroll/Cards").get_child(0) as ItemTooltipCard
		_assert(item_card != null and not item_card.rendered_text().strip_edges().is_empty(), "%s item detail exposes nonempty rendered item text" % context_label)
		_assert(not detail_close.get_global_rect().intersection((detail_tooltip.get_node("Layout/BodyScroll") as Control).get_global_rect()).has_area(), "%s Back action does not cover the item-detail body" % context_label)
		_assert((panel.get_node("Frame/Content/Summary/AutomaticList") as Button).focus_mode == Control.FOCUS_NONE, "%s detail excludes background controls from focus" % context_label)
		detail_close.pressed.emit()
		await _wait_for_hidden(detail, "%s item detail" % context_label)
		await _wait_for_focus(final_card, "%s detail return" % context_label)
		_assert(final_card.has_focus(), "%s detail restores exact final-item focus" % context_label)
		panel.show_unused_capacity_warning(2, 16, confirm)
		var warning := panel.get_node("UnusedCapacityWarning") as Control
		var warning_frame := panel.get_node("UnusedCapacityWarning/Frame") as Control
		var warning_title := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Title") as Label
		var warning_message := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Message") as Label
		var warning_actions := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions") as HBoxContainer
		var back := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Back") as Button
		var acknowledge := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Acknowledge") as Button
		await _wait_for_visible(warning, "%s unused-capacity warning" % context_label)
		await _wait_for_focus(back, "%s warning Back" % context_label)
		await _wait_for_stable_layout([warning_frame, warning_title, warning_message, warning_actions, back, acknowledge], "%s unused-capacity warning" % context_label)
		_assert(warning.visible and back.has_focus(), "%s unused-capacity warning uses safe Back default" % context_label)
		_assert_contained(warning_frame, viewport_rect, "%s unused-capacity warning" % context_label)
		_assert_controls_contained([warning_title, warning_message, warning_actions], warning_frame.get_global_rect(), "%s warning vertical flow" % context_label)
		_assert_sibling_non_overlap([warning_title, warning_message, warning_actions], "%s warning vertical flow" % context_label)
		_assert_control_set_geometry([back, acknowledge], warning_actions.get_global_rect(), "%s warning actions" % context_label)
		var tallest_warning_button := maxf(back.get_global_rect().size.y, acknowledge.get_global_rect().size.y)
		_assert(warning_actions.get_global_rect().size.y >= 48.0 and warning_actions.get_global_rect().size.y <= tallest_warning_button + 0.5, "%s warning Actions tracks its button row instead of the modal Frame; actions=%s tallest_button=%.2f frame=%s" % [context_label, warning_actions.get_global_rect(), tallest_warning_button, warning_frame.get_global_rect()])
		_assert(warning_title.size.x + 0.5 >= warning_title.get_combined_minimum_size().x and warning_title.size.y + 0.5 >= warning_title.get_combined_minimum_size().y, "%s warning title remains readable without clipping; size=%s minimum=%s" % [context_label, warning_title.size, warning_title.get_combined_minimum_size()])
		_assert(warning_message.size.x + 0.5 >= warning_message.get_combined_minimum_size().x and warning_message.size.y + 0.5 >= warning_message.get_combined_minimum_size().y and warning_message.get_visible_line_count() == warning_message.get_line_count(), "%s warning body remains readable without clipping; size=%s minimum=%s visible_lines=%d lines=%d" % [context_label, warning_message.size, warning_message.get_combined_minimum_size(), warning_message.get_visible_line_count(), warning_message.get_line_count()])
		_assert_target(back, "%s warning Back" % context_label)
		_assert_target(acknowledge, "%s warning Acknowledge" % context_label)
		acknowledge.grab_focus()
		await _wait_for_focus(acknowledge, "%s Accept Consequence" % context_label)
		_assert(viewport.gui_get_focus_owner() == acknowledge, "%s Accept Consequence remains the actual viewport focus owner when requested" % context_label)
		_assert_focused_primary_action(acknowledge, panel.theme, &"LivingForgePrimaryButton", "%s Accept Consequence" % context_label)
		back.grab_focus()
		await _wait_for_focus(back, "%s warning Back before close" % context_label)
		back.pressed.emit()
		await _wait_for_hidden(warning, "%s unused-capacity warning" % context_label)
		await _wait_for_focus(confirm, "%s warning return Confirm" % context_label)
		_assert(confirm.has_focus(), "%s warning returns exact Confirm focus" % context_label)
	if _extraction_design_corner(viewport_size, ui_scale, text_scale):
		var resting_frame := frame.get_global_rect()
		panel.set_pending(true)
		await _wait_for_stable_layout([frame, header, body, actions], "%s pending" % context_label)
		_assert_contained(frame, viewport_rect, "%s pending frame" % context_label)
		_assert_contained(header, frame.get_global_rect(), "%s pending header" % context_label)
		_assert(resting_frame.is_equal_approx(frame.get_global_rect()), "%s pending state preserves the extraction frame geometry" % context_label)
		_assert(automatic_scroll.scroll_horizontal == 0, "%s pending Show Auto focus restores the automatic leading edge" % context_label)
		if not automatic_cards.is_empty():
			_assert(automatic_scroll.get_global_rect().encloses(automatic_cards[0].get_global_rect()), "%s pending state keeps the first automatic card fully visible" % context_label)
			_assert(body.get_global_rect().encloses(automatic_cards[0].get_global_rect()), "%s pending state reveals the complete first automatic card" % context_label)
		panel.set_pending(false)
	_assert_controls_in_parent(_visible_buttons(panel), "%s all visible extraction actions" % context_label)
	panel.free()
	viewport.free()
	_active_viewport = null


func _exercise_result(viewport_size: Vector2i, ui_scale: int, text_scale: int, high_contrast := false) -> void:
	var viewport := _new_viewport(viewport_size)
	var context_label := _context("RESULT", viewport_size, ui_scale, text_scale, "party=24 loot=30 high_contrast=%s" % high_contrast)
	var fixture_type := load(RESULT_FIXTURE_PATH) as Script
	var fixtures: Variant = fixture_type.new()
	var fixture: Dictionary = fixtures.call(&"_fixture", 24, 24, RunTerminalSnapshot.Outcome.VICTORY)
	var build := RunResultViewModel.new().build(fixture.snapshot, fixture.resolution, fixture.profile, [])
	_assert(build.ok(), "%s finalized projection builds from durable truth" % context_label)
	if not build.ok():
		viewport.free()
		_active_viewport = null
		return
	var result_settings := _settings(ui_scale, text_scale)
	result_settings.high_contrast = high_contrast
	var projection := build.projection.with_visual_settings(result_settings)
	var panel := (load("res://scenes/ui/run_result_panel.tscn") as PackedScene).instantiate() as RunResultPanel
	viewport.add_child(panel)
	panel.present(projection)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var frame := panel.get_node("Frame") as Control
	var body := panel.get_node("Frame/Content/Body") as ScrollContainer
	var footer := panel.get_node("Frame/Content/Footer") as Control
	var actions := panel.get_node("Frame/Content/Footer/Actions") as Container
	await _wait_until(func() -> bool:
		return _result_rows(panel, &"party").size() == 24 and _result_rows(panel, &"loot").size() == 30
	, "%s 24-member 30-loot recap" % context_label)
	await _wait_for_stable_layout([frame, body, footer, actions], context_label)
	_assert_contained(frame, viewport_rect, "%s frame" % context_label)
	_assert_contained(body, frame.get_global_rect(), "%s recap body" % context_label)
	_assert_contained(footer, frame.get_global_rect(), "%s footer" % context_label)
	_assert(not body.is_ancestor_of(footer), "%s terminal actions remain pinned outside recap scrolling" % context_label)
	_assert(not body.get_global_rect().intersection(footer.get_global_rect()).has_area(), "%s recap body and pinned footer do not overlap" % context_label)
	var party_rows := _result_rows(panel, &"party")
	var loot_rows := _result_rows(panel, &"loot")
	_assert(party_rows.size() == 24, "%s renders every party member row" % context_label)
	_assert(loot_rows.size() == 30, "%s renders every current supported loot consequence row" % context_label)
	var seen_rows: Dictionary = {}
	for row: Button in party_rows + loot_rows:
		var stable_row := "%s|%s" % [String(row.get_meta(&"recap_section_id", &"")), row.name]
		_assert(not seen_rows.has(stable_row), "%s recap row %s appears once" % [context_label, stable_row])
		seen_rows[stable_row] = true
		_assert_target(row, "%s recap row %s" % [context_label, stable_row])
		_assert_contained(row, (row.get_parent() as Control).get_global_rect(), "%s recap row %s owning section" % [context_label, stable_row])
	_assert_sibling_non_overlap(party_rows + loot_rows, "%s recap rows" % context_label)
	for node: Node in actions.get_children():
		if node is Button and (node as Button).visible:
			_assert_target(node as Button, "%s terminal action %s" % [context_label, node.name])
	var return_action := panel.get_node("Frame/Content/Footer/Actions/ReturnToForge") as Button
	var restart_action := panel.get_node("Frame/Content/Footer/Actions/RestartRun") as Button
	var quit_action := panel.get_node("Frame/Content/Footer/Actions/QuitApplication") as Button
	var result_actions := _direct_visible_controls(actions, "Button")
	_assert_control_set_geometry(result_actions, frame.get_global_rect(), "%s terminal actions" % context_label)
	_assert_controls_in_parent(_visible_buttons(panel), "%s all visible result actions" % context_label)
	await _wait_for_focus(return_action, "%s safe default" % context_label)
	_assert(return_action.has_focus(), "%s defaults to safe Return to Forge" % context_label)
	_assert(not restart_action.has_focus() and not quit_action.has_focus(), "%s destructive/consequence actions are not default-focused" % context_label)
	if not party_rows.is_empty() and not loot_rows.is_empty():
		party_rows[0].grab_focus()
		await _wait_for_focus(party_rows[0], "%s first party row" % context_label)
		await _push_action(&"ui_down")
		await _wait_for_focus(party_rows[1], "%s second party row" % context_label)
		var final_row := loot_rows[-1]
		if _authentic_stress(viewport_size, ui_scale, text_scale):
			party_rows[0].grab_focus()
			await _wait_for_focus(party_rows[0], "%s authentic traversal origin" % context_label)
			for _step: int in party_rows.size() + loot_rows.size() - 1:
				await _push_action(&"ui_down")
		else:
			final_row.grab_focus()
		await _wait_for_focus(final_row, "%s final recap row" % context_label)
		await _wait_for_scroll_reveal(body, final_row, "%s final recap row" % context_label)
		_assert(final_row.has_focus(), "%s spatial traversal reaches the final current-content recap row" % context_label)
		_assert(_visible_inside(body, final_row), "%s final recap row remains visible inside the bounded body" % context_label)
		await _push_action(&"ui_down")
		await _wait_for_focus(return_action, "%s recap-to-footer bridge" % context_label)
		_assert(return_action.has_focus(), "%s focus bridge reaches the pinned safe terminal action" % context_label)
		await _push_action(&"ui_up")
		await _wait_for_focus(final_row, "%s footer-to-recap bridge" % context_label)
		_assert(final_row.has_focus(), "%s focus bridge returns to the final recap row" % context_label)
		if _long_detail_corner(viewport_size, ui_scale, text_scale):
			await _exercise_long_recap_detail(final_row, body, footer, frame, panel.theme, context_label)
	var view_model := RunResultViewModel.new()
	var retry_build := view_model.resolution_interrupted(fixture.snapshot, "Resolution was interrupted.", null)
	_assert(retry_build.ok(), "%s retry focus fixture builds" % context_label)
	if retry_build.ok():
		panel.present(retry_build.projection.with_visual_settings(result_settings))
		var retry := panel.get_node("Frame/Content/Footer/Actions/RetryResolution") as Button
		await _wait_for_visible(retry, "%s Result Retry" % context_label)
		retry.grab_focus()
		await _wait_for_focus(retry, "%s Result Retry" % context_label)
		_assert_focused_primary_action(retry, panel.theme, &"LivingForgePrimaryButton", "%s Result Retry" % context_label)
	var automatic_evaluation := RunResolutionEvaluation.create(fixture.resolution.accepted_extraction, 2, 0, 0, "automatic-only blocked", RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, "Automatic retained items need more destination space.")
	var preflight := RunResolutionPreflightResult.from_evaluation(automatic_evaluation)
	var guarded_build := view_model.resolution_interrupted(fixture.snapshot, preflight.player_reason, _durable_safety(fixture.snapshot), preflight)
	_assert(guarded_build.ok(), "%s Result Confirm focus fixture builds" % context_label)
	if guarded_build.ok():
		panel.present(guarded_build.projection.with_visual_settings(result_settings))
		var protect := panel.get_node("Frame/Content/Footer/Actions/ProtectDisplacedGear") as Button
		await _wait_for_visible(protect, "%s Protect Displaced Gear" % context_label)
		protect.pressed.emit()
		var result_confirmation := panel.get_node("Frame/Content/Confirmation") as Control
		var result_confirm := panel.get_node("Frame/Content/Confirmation/Content/Actions/Confirm") as Button
		await _wait_for_visible(result_confirmation, "%s Result Confirm modal" % context_label)
		result_confirm.grab_focus()
		await _wait_for_focus(result_confirm, "%s Result Confirm" % context_label)
		_assert_focused_primary_action(result_confirm, panel.theme, &"LivingForgePrimaryButton", "%s Result Confirm" % context_label)
	panel.free()
	viewport.free()
	_active_viewport = null


func _hud_fixture(count: int, alert_count: int, ui_scale: int, text_scale: int) -> Dictionary:
	_sequence += 1
	var catalog := GameCatalog.load_defaults()
	var party := _party(count, catalog)
	party.configure_identity(_sequence, catalog.generic_name_pool)
	var context := PlayerRunContext.new()
	assert(context.configure(StringName("responsive-%d" % _sequence), 0, ProfileState.new_profile("responsive-profile-%d" % _sequence, "Responsive", 1000), _sequence, party, 100).is_empty())
	var experience := ExperienceSystem.new()
	experience.configure_context(context, 1)
	var actors: Array[Node3D] = []
	var health_by_member: Dictionary = {}
	for member_id: int in range(1, count + 1):
		var actor := Node3D.new()
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		actor.add_child(health)
		health.configure(100.0, member_id == 1, 8.0, 0.5, member_id == 1)
		if member_id <= alert_count:
			health.apply_damage(80.0)
		assert(context.bind_actor(member_id, actor))
		actors.append(actor)
		health_by_member[member_id] = health
	return {
		"party": party,
		"context": context,
		"experience": experience,
		"actors": actors,
		"health_by_member": health_by_member,
		"run": TestRun.new(),
		"settings": _settings(ui_scale, text_scale),
	}


func _party(count: int, catalog: GameCatalog) -> PartyManager:
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(count))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.members[0].character_name = "Member 1"
	for member_id: int in range(2, count + 1):
		assert(party.recruit(catalog.class_by_id(&"fighter")))
		party.members[-1].character_name = "Member %d" % member_id
	return party


func _settings(ui_scale: int, text_scale: int) -> PartyForgeSettings:
	var result := PartyForgeSettings.new()
	result.ui_scale_percent = ui_scale
	result.text_scale_percent = text_scale
	return result


func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	return (maxf(first_luminance, second_luminance) + 0.05) / (minf(first_luminance, second_luminance) + 0.05)


func _relative_luminance(value: Color) -> float:
	return 0.2126 * _linear_channel(value.r) + 0.7152 * _linear_channel(value.g) + 0.0722 * _linear_channel(value.b)


func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


func _durable_safety(snapshot: RunTerminalSnapshot) -> RunTerminalRecoverySafetyResult:
	var empty: Array[String] = []
	var displaced: Array[String] = []
	var record_result := RunTerminalRecoveryRecord.create(RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION, snapshot, empty, "", displaced, "", null, "")
	return RunTerminalRecoverySafetyResult.success(record_result.record) if record_result.ok() else RunTerminalRecoverySafetyResult.failure(record_result.error)


func _exercise_primary_action_bar() -> void:
	var viewport := _new_viewport(Vector2i(1280, 720))
	var bar := (load("res://scenes/ui/living_forge/components/forge_action_bar.tscn") as PackedScene).instantiate() as ForgeActionBar
	viewport.add_child(bar)
	bar.theme = LivingForgeThemeCatalog.resolve(false, 100, 100)
	bar.present([{"id": &"start", "label": "Start Run", "enabled": true, "kind": &"primary", "accessibility_description": "Start the selected run."}])
	var primary := bar.button_for(&"start") as Button
	await _wait_for_stable_layout([bar, primary], "ForgeActionBar primary")
	primary.grab_focus()
	await _wait_for_focus(primary, "ForgeActionBar primary")
	_assert_focused_primary_action(primary, bar.theme, &"LivingForgePrimaryButton", "ForgeActionBar primary")
	bar.free()
	viewport.free()
	_active_viewport = null


func _assert_focused_primary_action(button: Button, theme: Theme, variation: StringName, label: String) -> void:
	_assert(_active_viewport != null and _active_viewport.gui_get_focus_owner() == button, "%s owns actual viewport focus before focus-style inspection" % label)
	_assert(button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE, "%s is visible and eligible while focused" % label)
	_assert(button.theme_type_variation == variation, "%s uses the shared %s variation" % [label, variation])
	_assert(not button.has_theme_stylebox_override(&"focus"), "%s has no local focus StyleBox override" % label)
	_assert(not button.has_theme_color_override(&"font_focus_color"), "%s has no local focus font override" % label)
	_assert(button.get_theme_stylebox(&"focus", variation) == theme.get_stylebox(&"focus", variation), "%s resolves the shared focus StyleBox" % label)
	_assert(button.get_theme_color(&"font_focus_color", variation) == theme.get_color(&"font_focus_color", variation), "%s resolves the shared focus foreground" % label)


func _extraction_projection(count: int, capacity: int, automatic_count: int) -> TerminalExtractionProjection:
	var automatic: Array[TerminalExtractionItemProjection] = []
	for index: int in automatic_count:
		automatic.append(_extraction_item("automatic-%02d" % (index + 1), true, false, false, 1, index))
	var eligible: Array[TerminalExtractionItemProjection] = []
	var lost: Array[String] = []
	for index: int in count:
		var item_id := "item-%02d" % (index + 1)
		eligible.append(_extraction_item(item_id, false, false, true, 0, index))
		lost.append(item_id)
	return TerminalExtractionProjection.create(automatic, eligible, capacity, [], lost, [], "", true)


func _extraction_item(item_id: String, automatic: bool, selected: bool, lost: bool, member_id: int, slot: int) -> TerminalExtractionItemProjection:
	return TerminalExtractionItemProjection.create_with_source(
		item_id,
		"Forged Relic %02d" % (slot + 1),
		"Common",
		&"common",
		"Fighter · Member %d" % member_id if member_id > 0 else "Run Inventory",
		"Fighter Equipment" if member_id > 0 else "Run Inventory",
		automatic,
		selected,
		lost,
		{"name": "Forged Relic %02d" % (slot + 1), "instance_id": item_id},
		[],
		member_id,
		"Fighter" if member_id > 0 else "",
		StringName("run-equipment-%03d" % member_id) if member_id > 0 else &"run-inventory",
		slot,
	)


func _hud_roster_controls(hud: HUD) -> Array[Control]:
	var result: Array[Control] = []
	for node: Node in hud.get_tree().get_nodes_in_group(&"combat_hud_member"):
		if node is Control and not node.is_queued_for_deletion() and hud.is_ancestor_of(node):
			result.append(node as Control)
	return result


func _hud_member_control(hud: HUD, member_id: int) -> Control:
	for control: Control in _hud_roster_controls(hud):
		if int(control.get_meta(&"member_id", 0)) == member_id:
			return control
	return null


func _extraction_cards(panel: TerminalExtractionPanel) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in panel.find_children("*", "ForgeExtractionItemCard", true, false):
		if String(node.get_meta(&"item_id", "")).begins_with("item-"):
			result.append(node as Button)
	result.sort_custom(func(left: Button, right: Button) -> bool:
		return String(left.get_meta(&"item_id", "")) < String(right.get_meta(&"item_id", ""))
	)
	return result


func _automatic_extraction_cards(panel: TerminalExtractionPanel) -> Array[Button]:
	var result: Array[Button] = []
	var scope := panel.get_node("Frame/Content/Body/Sections/Automatic/Scroll/Items") as Control
	for node: Node in scope.find_children("*", "ForgeExtractionItemCard", true, false):
		result.append(node as Button)
	return result


func _result_rows(panel: RunResultPanel, section_id: StringName) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in panel.find_children("*", "Button", true, false):
		if node.get_meta(&"recap_section_id", &"") == section_id:
			result.append(node as Button)
	return result


func _direct_visible_controls(scope: Node, type_name: String) -> Array[Control]:
	var result: Array[Control] = []
	if scope == null:
		return result
	for child: Node in scope.get_children():
		if child is Control and not child.is_queued_for_deletion() and child.is_class(type_name) and (child as Control).is_visible_in_tree():
			result.append(child as Control)
	return result


func _visible_buttons(scope: Node) -> Array[Control]:
	var result: Array[Control] = []
	if scope == null:
		return result
	for node: Node in scope.find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion() and (node as Button).is_visible_in_tree():
			result.append(node as Control)
	return result


func _assert_controls_contained(controls: Array, outer: Rect2, label: String) -> void:
	for index: int in controls.size():
		var control := controls[index] as Control
		_assert_contained(control, outer, "%s control %d %s" % [label, index + 1, control.name if control != null else "<null>"])


func _assert_sibling_non_overlap(controls: Array, label: String) -> void:
	var rects: Array[Rect2] = []
	for control_value: Variant in controls:
		var control := control_value as Control
		if control == null or not control.is_visible_in_tree():
			continue
		_assert_no_overlap(control.get_global_rect(), rects, label)
		rects.append(control.get_global_rect())


func _assert_control_set_geometry(controls: Array, outer: Rect2, label: String) -> void:
	_assert_controls_contained(controls, outer, label)
	_assert_sibling_non_overlap(controls, label)
	for control_value: Variant in controls:
		var control := control_value as Control
		if control != null and control.is_visible_in_tree():
			_assert_bounds(control, "%s %s" % [label, control.name])


func _assert_controls_within_owning_surface(controls: Array, outer: Rect2, label: String) -> void:
	_assert_controls_contained(controls, outer, label)
	var groups: Dictionary = {}
	for control_value: Variant in controls:
		var control := control_value as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var parent_id := control.get_parent().get_instance_id()
		if not groups.has(parent_id):
			groups[parent_id] = []
		(groups[parent_id] as Array).append(control)
	for sibling_values: Variant in groups.values():
		_assert_sibling_non_overlap(sibling_values as Array, label)


func _assert_controls_in_parent(controls: Array, label: String) -> void:
	var groups: Dictionary = {}
	for control_value: Variant in controls:
		var control := control_value as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var parent := control.get_parent() as Control
		_assert(parent != null, "%s %s has a Control layout owner" % [label, control.name])
		if parent == null:
			continue
		_assert_contained(control, parent.get_global_rect(), "%s %s parent" % [label, control.name])
		var parent_id := parent.get_instance_id()
		if not groups.has(parent_id):
			groups[parent_id] = []
		(groups[parent_id] as Array).append(control)
	for sibling_values: Variant in groups.values():
		_assert_sibling_non_overlap(sibling_values as Array, label)


func _exercise_long_recap_detail(row: Button, body: ScrollContainer, footer: Control, frame: Control, expected_theme: Theme, context_label: String) -> void:
	var primary := row.get_node_or_null("Primary") as Control
	var detail := row.get_node_or_null("Detail") as Label
	_assert(primary != null, "%s expanded-detail fixture has a dedicated Primary label" % context_label)
	_assert(detail != null, "%s expanded-detail fixture has a real Detail label" % context_label)
	if primary == null or detail == null:
		return
	var primary_text := String(primary.get("text"))
	_assert(primary_text.begins_with("Protected displaced gear"), "%s expanded-detail Primary visual carries the protected-gear line" % context_label)
	_assert(detail.text.begins_with("Recovery Overflow · exact item ID"), "%s expanded-detail Detail label carries the Recovery Overflow line" % context_label)
	_assert(row.text.is_empty(), "%s native Button text stays empty so its effective accessibility name cannot append duplicate visual copy" % context_label)
	_assert(row.accessibility_name == primary_text.replace("   ", ": "), "%s recap Button owns the one exact protected-gear accessibility name" % context_label)
	_assert(primary.accessibility_name.strip_edges().is_empty(), "%s visual Primary overlay does not duplicate the Button accessibility name" % context_label)
	_assert(primary.get_theme_font(&"font") == expected_theme.get_font(&"font", row.theme_type_variation), "%s visible Primary resolves the inherited Living Forge Button font" % context_label)
	_assert(primary.get_theme_font_size(&"font_size") == expected_theme.get_font_size(&"font_size", row.theme_type_variation), "%s visible Primary resolves the inherited Living Forge Button font size" % context_label)
	var expected_primary_color := expected_theme.get_color(&"font_color", row.theme_type_variation) if expected_theme.has_color(&"font_color", row.theme_type_variation) else expected_theme.get_color(&"font_color", &"Button")
	_assert(primary.get_theme_color(&"font_color") == expected_primary_color, "%s visible Primary resolves the inherited Living Forge Button semantic color" % context_label)
	_assert(primary.get_theme_color(&"font_color").a > 0.0, "%s visible Primary semantic color is readable rather than transparent" % context_label)
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		_assert(row.get_theme_color(color_name) == Color.TRANSPARENT, "%s native Button %s stays transparent behind the one visual Primary overlay" % [context_label, color_name])
	row.pressed.emit()
	await _wait_for_visible(detail, "%s long recap detail" % context_label)
	await _wait_for_stable_layout([row, primary, detail, body, footer], "%s long recap detail" % context_label)
	row.grab_focus()
	await _wait_for_focus(row, "%s expanded recap row" % context_label)
	await _wait_for_scroll_reveal(body, row, "%s expanded recap row" % context_label)
	_assert_expanded_result_detail_geometry(row, primary, detail, "%s exact semantic detail" % context_label)
	row.pressed.emit()
	await _wait_for_hidden(detail, "%s collapsed exact semantic detail" % context_label)
	detail.text = ("The forge records a deliberately long consequence with current loot identity, destination, loss, and protection context. ").repeat(4)
	row.pressed.emit()
	await _wait_for_visible(detail, "%s wrapping stress detail" % context_label)
	await _wait_for_stable_layout([row, primary, detail, body, footer], "%s wrapping stress detail" % context_label)
	_assert(detail.get_line_count() > 1, "%s long stress detail actually wraps across multiple lines" % context_label)
	_assert_expanded_result_detail_geometry(row, primary, detail, "%s wrapping stress detail" % context_label)
	_assert(_visible_inside(body, row), "%s focused expanded row remains visible through focus-follow" % context_label)
	_assert(frame.get_global_rect().encloses(footer.get_global_rect()), "%s expanded detail keeps footer frame-contained" % context_label)
	_assert(not body.get_global_rect().intersection(footer.get_global_rect()).has_area(), "%s expanded detail keeps footer pinned outside recap scrolling" % context_label)


func _assert_expanded_result_detail_geometry(row: Button, primary: Control, detail: Label, context_label: String) -> void:
	var row_rect := row.get_global_rect()
	var primary_rect := primary.get_global_rect()
	var detail_rect := detail.get_global_rect()
	_assert(row_rect.encloses(primary_rect), "%s row fully contains Primary: row=%s primary=%s" % [context_label, row_rect, primary_rect])
	_assert(row_rect.encloses(detail_rect), "%s row fully contains Detail: row=%s detail=%s" % [context_label, row_rect, detail_rect])
	_assert(not primary_rect.intersection(detail_rect).has_area(), "%s Primary and Detail occupy separate non-overlapping rectangles: primary=%s detail=%s" % [context_label, primary_rect, detail_rect])
	_assert(primary_rect.end.y <= detail_rect.position.y, "%s Primary ends above Detail: primary=%s detail=%s" % [context_label, primary_rect, detail_rect])
	_assert(primary.size.x + 0.5 >= primary.get_combined_minimum_size().x and primary.size.y + 0.5 >= primary.get_combined_minimum_size().y, "%s Primary remains readable: size=%s minimum=%s" % [context_label, primary.size, primary.get_combined_minimum_size()])
	_assert(detail.size.x + 0.5 >= detail.get_combined_minimum_size().x and detail.size.y + 0.5 >= detail.get_combined_minimum_size().y, "%s Detail remains readable: size=%s minimum=%s" % [context_label, detail.size, detail.get_combined_minimum_size()])


func _assert_contained(control: Control, outer: Rect2, label: String) -> void:
	if control == null or not control.is_visible_in_tree():
		_assert(false, "%s is visible for geometry acceptance" % label)
		return
	var rect := control.get_global_rect()
	_assert(rect.size.x > 0.0 and rect.size.y > 0.0, "%s has positive geometry: %s" % [label, rect])
	_assert(outer.encloses(rect), "%s remains contained: outer=%s inner=%s" % [label, outer, rect])


func _assert_no_overlap(rect: Rect2, prior: Array[Rect2], label: String) -> void:
	for other: Rect2 in prior:
		_assert(not rect.intersection(other).has_area(), "%s do not overlap: first=%s second=%s" % [label, other, rect])


func _assert_target(control: Control, label: String) -> void:
	_assert_bounds(control, label)
	if control == null or not control.is_visible_in_tree():
		return
	_assert(control.focus_mode != Control.FOCUS_NONE, "%s remains focusable" % label)
	if control is BaseButton:
		_assert(not (control as BaseButton).disabled, "%s remains enabled" % label)


func _assert_bounds(control: Control, label: String) -> void:
	if control == null or not control.is_visible_in_tree():
		_assert(false, "%s is visible" % label)
		return
	var size := control.get_global_rect().size
	_assert(size.x >= 48.0 and size.y >= 48.0, "%s retains actual 48px bounds: %s" % [label, size])


func _visible_inside(scroll: ScrollContainer, control: Control) -> bool:
	if scroll == null or control == null or not control.is_visible_in_tree():
		return false
	var viewport_rect := scroll.get_global_rect()
	var control_rect := control.get_global_rect()
	var visible := viewport_rect.intersection(control_rect)
	return visible.size.x >= minf(48.0, control_rect.size.x) and visible.size.y >= minf(48.0, control_rect.size.y)


func _push_action(action: StringName) -> void:
	if _active_viewport == null or not is_instance_valid(_active_viewport):
		_assert(false, "responsive input requires an active exact-sized viewport")
		return
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	_active_viewport.push_input(press)
	await process_frame
	var release := press.duplicate() as InputEventAction
	release.pressed = false
	_active_viewport.push_input(release)
	await process_frame


func _activate_focused() -> void:
	await _push_action(&"ui_accept")


func _wait_until(condition: Callable, label: String, deadline_ms: int = CONDITION_DEADLINE_MS) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= deadline_ms:
		if condition.is_valid() and bool(condition.call()):
			return true
		await process_frame
	_assert(false, "CONDITION_TIMEOUT waiting for %s within %dms" % [label, deadline_ms])
	return false


func _wait_for_stable_layout(controls: Array[Control], label: String) -> bool:
	var state := {"signature": "", "stable_frames": 0}
	return await _wait_until(func() -> bool:
		var parts := PackedStringArray()
		var valid := true
		for control: Control in controls:
			if control == null or not is_instance_valid(control) or not control.is_inside_tree():
				valid = false
				break
			var rect := control.get_global_rect()
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				valid = false
				break
			parts.append("%.2f,%.2f,%.2f,%.2f" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y])
		var signature := "|".join(parts)
		if valid and signature == String(state.signature):
			state.stable_frames = int(state.stable_frames) + 1
		else:
			state.signature = signature
			state.stable_frames = 0
		return valid and int(state.stable_frames) >= 1
	, "stable layout: %s" % label)


func _wait_for_focus(control: Control, label: String) -> bool:
	return await _wait_until(func() -> bool:
		return control != null and is_instance_valid(control) and _active_viewport != null and _active_viewport.gui_get_focus_owner() == control
	, "focus: %s" % label)


func _wait_for_visible(control: Control, label: String) -> bool:
	return await _wait_until(func() -> bool:
		return control != null and is_instance_valid(control) and control.is_visible_in_tree()
	, "visible transition: %s" % label)


func _wait_for_hidden(control: Control, label: String) -> bool:
	return await _wait_until(func() -> bool:
		return control != null and is_instance_valid(control) and not control.is_visible_in_tree()
	, "hidden transition: %s" % label)


func _wait_for_scroll_reveal(scroll: ScrollContainer, control: Control, label: String) -> bool:
	return await _wait_until(func() -> bool:
		return _visible_inside(scroll, control)
	, "scroll reveal: %s" % label)


func _cleanup_hud_fixture(fixture: Dictionary) -> void:
	var experience := fixture.experience as ExperienceSystem
	if experience != null:
		experience.free()
	var party := fixture.party as PartyManager
	if party != null:
		party.free()
	for actor: Node3D in fixture.actors as Array:
		actor.free()
	var run := fixture.run as Node
	if run != null:
		run.free()


func _context(surface: String, viewport_size: Vector2i, ui_scale: int, text_scale: int, detail: String) -> String:
	return "%s %dx%d ui=%d text=%d %s" % [surface, viewport_size.x, viewport_size.y, ui_scale, text_scale, detail]


func _new_viewport(viewport_size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	_active_viewport = viewport
	return viewport


func _authentic_stress(viewport_size: Vector2i, ui_scale: int, text_scale: int) -> bool:
	return viewport_size == Vector2i(1280, 720) and ui_scale == 150 and text_scale == 150


func _extraction_design_corner(viewport_size: Vector2i, ui_scale: int, text_scale: int) -> bool:
	return (viewport_size == Vector2i(1920, 1080) and ui_scale == 100 and text_scale == 100) \
		or (viewport_size == Vector2i(1280, 720) and ui_scale == 150 and text_scale == 150)


func _assert_extraction_card_layout(card: Button, context_label: String, item_id: String) -> void:
	var label := "%s item %s" % [context_label, item_id]
	var content := card.get_node("Content") as Control
	var name_label := card.get_node("Content/Name") as Label
	var rarity := card.get_node("Content/Rarity") as Label
	var source := card.get_node("Content/Source") as Label
	var state := card.get_node("Content/Footer/State") as Control
	var state_text := card.get_node("Content/Footer/State/StateText") as Label
	var inspect := card.get_node("Content/Footer/Inspect") as Button
	_assert(content.size.y + 0.5 >= content.get_combined_minimum_size().y, "%s content encloses its combined minimum" % label)
	_assert(card.get_global_rect().encloses(content.get_global_rect()), "%s card contains its inset content; card=%s content=%s" % [label, card.get_global_rect(), content.get_global_rect()])
	for pair: Array in [[name_label, "name"], [rarity, "rarity"], [source, "source"], [state, "state"]]:
		_assert_contained(pair[0] as Control, content.get_global_rect(), "%s %s" % [label, pair[1]])
	_assert(content.position.y + name_label.position.y >= 8.0, "%s name clears the focus border" % label)
	_assert(source.size.y + 0.5 >= source.get_combined_minimum_size().y, "%s source copy is fully visible" % label)
	_assert(state_text.size.x + 0.5 >= state_text.get_combined_minimum_size().x, "%s semantic state copy is untruncated" % label)
	_assert(inspect.size.x + 0.5 >= inspect.get_combined_minimum_size().x and inspect.size.y + 0.5 >= inspect.get_combined_minimum_size().y, "%s Inspect encloses its combined minimum" % label)
	var state_rect := state.get_global_rect()
	var inspect_rect := inspect.get_global_rect()
	_assert(not state_rect.intersection(inspect_rect).has_area(), "%s state and Inspect do not overlap" % label)
	var horizontal_gap := maxf(inspect_rect.position.x - state_rect.end.x, state_rect.position.x - inspect_rect.end.x)
	var vertical_gap := maxf(inspect_rect.position.y - state_rect.end.y, state_rect.position.y - inspect_rect.end.y)
	_assert(maxf(horizontal_gap, vertical_gap) >= 8.0, "%s state and Inspect retain an 8px semantic gap" % label)


func _assert_extraction_grid_fill(cards: Array[Button], context_label: String) -> void:
	var seen_grids: Dictionary = {}
	for card: Button in cards:
		var grid := card.get_parent() as GridContainer
		if grid == null or seen_grids.has(grid.get_instance_id()):
			continue
		seen_grids[grid.get_instance_id()] = true
		var separation := float(grid.get_theme_constant(&"h_separation"))
		var share := (grid.size.x - separation * float(maxi(grid.columns - 1, 0))) / float(maxi(grid.columns, 1))
		for child: Node in grid.get_children():
			if child is ForgeExtractionItemCard:
				_assert((child as Control).size.x + 1.0 >= share, "%s cards fill the responsive column share: actual=%s expected=%s" % [context_label, (child as Control).size.x, share])


func _long_detail_corner(viewport_size: Vector2i, ui_scale: int, text_scale: int) -> bool:
	return viewport_size == Vector2i(1280, 720) and text_scale == 150 and ui_scale in [80, 150]


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_LOOP_RESPONSIVE_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("COMBAT_LOOP_RESPONSIVE_FAILURE: %s" % failure)
	print("COMBAT_LOOP_RESPONSIVE_SUMMARY: FAIL failures=%d" % _failures.size())
	quit(1)
