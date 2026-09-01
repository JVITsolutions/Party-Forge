extends SceneTree


class TestRun:
	extends Node
	var seconds := 125.0
	func elapsed_time() -> float:
		return seconds


const LEADER_TEXT_PATHS: Array[NodePath] = [
	NodePath("Surface/Content/Identity/Name"),
	NodePath("Surface/Content/Identity/Class"),
	NodePath("Surface/Content/Meta"),
	NodePath("Surface/Content/Health/Value"),
	NodePath("Surface/Content/StateCue/StateText"),
	NodePath("Surface/LeaderCue/Text"),
]
const READABLE_FONT_FLOOR := 14

var _failures: Array[String] = []
var _sequence := 8800
var _leader_text100_font_sizes: Dictionary = {}


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if not ResourceLoader.exists("res://scripts/ui/hud/combat_alert_tray.gd") or not ResourceLoader.exists("res://scripts/ui/hud/combat_member_inspect_panel.gd"):
		push_error("COMBAT_HUD_PARTY_SCALE_FAILURE: Task 4 combat HUD child routes are missing")
		print("COMBAT_HUD_PARTY_SCALE_SUMMARY: FAIL failures=1")
		quit(1)
		return
	for count: int in [1, 6, 7, 12, 20, 24]:
		await _exercise_party_count(count)
	await _exercise_real_geometry(Vector2i(1920, 1080), 6, 100, 100)
	await _exercise_real_geometry(Vector2i(1920, 1080), 24, 100, 100)
	await _exercise_real_geometry(Vector2i(1920, 1080), 24, 150, 150)
	await _exercise_real_geometry(Vector2i(1280, 720), 6, 100, 100)
	await _exercise_real_geometry(Vector2i(1280, 720), 6, 80, 150)
	await _exercise_real_geometry(Vector2i(1280, 720), 6, 100, 150)
	await _exercise_real_geometry(Vector2i(1280, 720), 6, 150, 150)
	await _exercise_real_geometry(Vector2i(1280, 720), 24, 150, 150)
	_finish()


func _exercise_party_count(count: int) -> void:
	var fixture := _fixture(count)
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	hud.custom_viewport = viewport
	viewport.add_child(hud)
	if hud.get_node_or_null("Margin/CombatStatus") == null:
		_failures.append("party %d is missing the responsive combat shell" % count)
		viewport.free()
		_cleanup_fixture(fixture)
		return
	hud.call("configure", fixture.run, fixture.party, fixture.experience, fixture.context, fixture.settings)
	await process_frame
	await process_frame
	var rich := hud.get_node("Margin/CombatStatus/PartyRegion/RichRoster") as Control
	var compact := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster") as Control
	_assert(rich.visible == (count <= 6), "party %d rich threshold" % count)
	_assert(compact.visible == (count >= 7), "party %d compact threshold" % count)
	var leader := hud.get_node("Margin/CombatStatus/LeaderCard") as Control
	var experience := hud.get_node("Margin/CombatStatus/Experience") as Control
	_assert(int(leader.get_meta("member_id", 0)) == 1, "party %d leader anchor identity" % count)
	if count <= 6:
		_assert(not leader.is_in_group(&"combat_hud_member"), "rich leader anchor is not duplicated in roster navigation")
		_assert(_roster_member_ids(hud).size() == maxi(0, count - 1), "rich party %d contains each follower once" % count)
		_assert((hud.get_node("Margin/CombatStatus/PartyRegion/NoFollowers") as Label).visible == (count == 1), "party %d no-followers treatment" % count)
	else:
		_assert(not leader.is_in_group(&"combat_hud_member"), "compact leader anchor stays out of paged-member counting")
		var reached: Dictionary = {}
		var next := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
		while true:
			for member_id: int in _roster_member_ids(hud):
				reached[member_id] = true
			if next.disabled:
				break
			next.pressed.emit()
			await process_frame
		_assert(reached.size() == count, "compact party %d reaches every member" % count)
		_assert(reached.has(count), "compact party %d reaches the final member" % count)
		for control: Control in _roster_controls(hud):
			var marker_rect := control.get_global_rect()
			_assert(marker_rect.size == Vector2(280.0, 84.0), "compact member %d has actual post-layout 280x84 geometry: %s" % [int(control.get_meta("member_id", 0)), marker_rect])
			_assert(marker_rect.encloses((control.get_node("Surface/Content") as Control).get_global_rect()), "compact member %d contains its real content" % int(control.get_meta("member_id", 0)))
	viewport.free()
	_cleanup_fixture(fixture)


func _exercise_real_geometry(viewport_size: Vector2i, count: int, ui_scale: int, text_scale: int) -> void:
	var fixture := _fixture(count)
	fixture.settings.text_scale_percent = text_scale
	fixture.settings.ui_scale_percent = ui_scale
	fixture.settings.high_contrast = viewport_size.x == 1280
	for member_id: int in range(2, mini(count + 1, 6)):
		(fixture.health_by_member[member_id] as HealthComponent).apply_damage(80.0)
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	hud.custom_viewport = viewport
	viewport.add_child(hud)
	hud.call("configure", fixture.run, fixture.party, fixture.experience, fixture.context, fixture.settings)
	await process_frame
	await process_frame
	if count == 24:
		var reached_member_ids: Dictionary = {}
		var next := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
		while true:
			for member_id: int in _roster_member_ids(hud):
				reached_member_ids[member_id] = true
			if next.disabled:
				break
			next.pressed.emit()
			await process_frame
		_assert(reached_member_ids.size() == count, "scaled compact paging reaches all %d members at %s ui=%d text=%d" % [count, viewport_size, ui_scale, text_scale])
	var shell := hud.get_node("Margin/CombatStatus") as Control
	var party_header := hud.get_node("Margin/CombatStatus/PartyHeader") as Button
	var party_summary := hud.get_node("Margin/CombatStatus/PartyHeader/Content/Summary") as Label
	var leader := hud.get_node("Margin/CombatStatus/LeaderCard") as Control
	var timer := hud.get_node("Margin/CombatStatus/RunTime") as Control
	var party_region := hud.get_node("Margin/CombatStatus/PartyRegion") as Control
	var alerts := hud.get_node("Margin/CombatStatus/AlertRegion") as Control
	var overflow := hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	var rich := hud.get_node("Margin/CombatStatus/PartyRegion/RichRoster") as Control
	var compact := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster") as Control
	var resolved_metrics := CombatHudResponsiveLayout.resolve(viewport_size, ui_scale, text_scale, count, party_header.get_global_rect().size.y)
	if resolved_metrics.mode == CombatHudResponsiveLayout.Mode.COMPACT:
		_assert(_roster_controls(hud).size() == resolved_metrics.visible_member_count, "live compact controls expose the calculated count at %s ui=%d text=%d calculated=%d actual=%d" % [viewport_size, ui_scale, text_scale, resolved_metrics.visible_member_count, _roster_controls(hud).size()])
	if count == 24 and text_scale == 150 and viewport_size.y <= 720:
		_assert(resolved_metrics.visible_member_count == 4, "Text150 with measured Party header uses two bounded two-column rows at %s ui=%d actual=%d" % [viewport_size, ui_scale, resolved_metrics.visible_member_count])
	if count == 24 and text_scale == 150 and viewport_size.y >= 1080:
		_assert(resolved_metrics.visible_member_count == 8, "Text150 retains four bounded two-column rows at %s ui=%d actual=%d" % [viewport_size, ui_scale, resolved_metrics.visible_member_count])
	for control: Control in [shell, party_header, leader, timer, party_region, alerts]:
		_assert_contained(control, Rect2(Vector2.ZERO, Vector2(viewport_size)), "%s %dx%d party=%d" % [control.name, viewport_size.x, viewport_size.y, count])
	_assert(party_header.get_global_rect().size.x >= 48.0 and party_header.get_global_rect().size.y >= 48.0, "Party header has a real post-layout 48x48 target")
	_assert(party_header.get_global_rect().encloses(party_summary.get_global_rect()), "Party summary remains enclosed after responsive layout header=%s summary=%s" % [party_header.get_global_rect(), party_summary.get_global_rect()])
	_assert(not party_header.get_global_rect().intersection(leader.get_global_rect()).has_area(), "Party header and leader do not overlap at %s party=%d" % [viewport_size, count])
	_assert_leader_contents_contained(leader, viewport_size, ui_scale, text_scale)
	_assert_leader_font_scale(leader, viewport_size, ui_scale, text_scale)
	_assert(not leader.get_global_rect().intersection(timer.get_global_rect()).has_area(), "leader and timer do not collide at %s party=%d" % [viewport_size, count])
	_assert(not leader.get_global_rect().intersection(alerts.get_global_rect()).has_area(), "leader and alerts do not collide at %s party=%d" % [viewport_size, count])
	_assert(not party_region.get_global_rect().intersection(alerts.get_global_rect()).has_area(), "party region and alerts do not collide at %s party=%d" % [viewport_size, count])
	if viewport_size == Vector2i(1280, 720) and text_scale == 150:
		_assert(not rich.visible and compact.visible, "720p Text150 uses the bounded compact roster for party=%d ui=%d" % [count, ui_scale])
		for member_control: Control in _roster_controls(hud):
			_assert(party_region.get_global_rect().encloses(member_control.get_global_rect()), "720p Text150 keeps visible member %d inside the reflowed party region at ui=%d region=%s member=%s" % [int(member_control.get_meta(&"member_id", 0)), ui_scale, party_region.get_global_rect(), member_control.get_global_rect()])
	if count == 24:
		var marker_rects: Array[Rect2] = []
		for marker: Control in _roster_controls(hud):
			var marker_rect := marker.get_global_rect()
			_assert(marker_rect.size == Vector2(280.0, 84.0), "final-page compact member has actual 280x84 geometry at %s: %s" % [viewport_size, marker_rect])
			_assert(marker_rect.encloses((marker.get_node("Surface/Content") as Control).get_global_rect()), "final-page compact member contains child content at %s" % viewport_size)
			for prior: Rect2 in marker_rects:
				_assert(not prior.intersection(marker_rect).has_area(), "final-page compact members do not overlap at %s" % viewport_size)
			marker_rects.append(marker_rect)
	if viewport_size == Vector2i(1920, 1080) and count == 6:
		_assert(rich.visible and not compact.visible, "desktop default retains rich follower cards")
		for card: Control in _roster_controls(hud):
			var card_rect := card.get_global_rect()
			var content := card.get_node("Surface/Content") as Control
			var name_label := card.get_node("Surface/Content/Identity/Name") as Label
			_assert(card.custom_minimum_size.x >= 424.0 and card.custom_minimum_size.y >= 184.0, "desktop rich follower preserves canonical 424x184 card minimum")
			_assert(card_rect.size.x >= card.get_combined_minimum_size().x and card_rect.size.y >= card.get_combined_minimum_size().y, "desktop rich follower is never smaller than its combined minimum")
			_assert(card_rect.encloses(content.get_global_rect()) and card_rect.encloses(name_label.get_global_rect()), "desktop rich follower name remains inside its forged plate")
	_assert(overflow.get_global_rect().size.x >= 48.0 and overflow.get_global_rect().size.y >= 48.0, "alert overflow has an actual post-layout 48x48 target")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var rendered_alert_count := 0
	var previous_alert_rect := Rect2()
	for alert: Node in (hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Container).get_children():
		var alert_control := alert as Control
		if not alert_control.visible:
			continue
		rendered_alert_count += 1
		var alert_rect := alert_control.get_global_rect()
		_assert(viewport_rect.encloses(alert_rect), "expanded alert is viewport bounded: %s" % alert_rect)
		var content_rect := (alert_control.get_node("Surface/Content") as Control).get_global_rect()
		_assert(alert_rect.encloses(content_rect), "expanded alert contains its real content card=%s content=%s" % [alert_rect, content_rect])
		if previous_alert_rect.has_area():
			_assert(not previous_alert_rect.intersection(alert_rect).has_area(), "expanded alert cards do not overlap")
		previous_alert_rect = alert_rect
		for action_name: String in ["Inspect", "Ledger"]:
			var action := alert.get_node("Surface/Content/Actions/%s" % action_name) as Button
			if action.visible:
				var action_rect := action.get_global_rect()
				_assert(action_rect.size.x >= 48.0 and action_rect.size.y >= 48.0, "%s alert action has an actual post-layout 48x48 target" % action_name)
				_assert(alert_rect.encloses(action_rect), "%s alert action remains inside its card card=%s action=%s" % [action_name, alert_rect, action_rect])
	var all_alert_count := (hud.get("current_projection") as CombatHudProjection).all_alerts.size()
	if viewport_size == Vector2i(1280, 720) and ui_scale == 150 and text_scale == 150 and all_alert_count > 0:
		_assert(rendered_alert_count < mini(CombatHudProjection.MAX_VISIBLE_ALERTS, all_alert_count), "720p Text150 reduces expanded alerts to the vertical content budget")
		_assert(overflow.visible and overflow.text.begins_with("+%d " % (all_alert_count - rendered_alert_count)), "alert overflow names every alert routed to the tray")
	if overflow.visible:
		overflow.pressed.emit()
		await process_frame
		var tray := hud.get_node("CombatAlertTray") as CombatAlertTray
		_assert(tray.visible, "complete alert tray opens for geometry verification")
		_assert_contained(tray.get_node("Overlay/Frame") as Control, Rect2(Vector2.ZERO, Vector2(viewport_size)), "complete alert tray frame")
		_assert((tray.get_node("Overlay") as Control).theme == LivingForgeThemeCatalog.resolve(fixture.settings.high_contrast, fixture.settings.ui_scale_percent, fixture.settings.text_scale_percent), "complete alert tray inherits the resolved high-contrast scaled theme")
		_assert((tray.get_node("Overlay/Frame") as Control).get_global_rect().encloses((tray.get_node("Overlay/Frame/Layout") as Control).get_global_rect()), "complete alert tray frame contains enlarged child content")
		for tray_card_node: Node in (tray.get_node("Overlay/Frame/Layout/Scroll/Alerts") as Container).get_children():
			var tray_card := tray_card_node as Control
			var tray_card_rect := tray_card.get_global_rect()
			for action_name: String in ["Inspect", "Ledger"]:
				var tray_action := tray_card.get_node("Surface/Content/Actions/%s" % action_name) as Button
				if tray_action.visible:
					_assert(tray_action.get_global_rect().size.x >= 48.0 and tray_action.get_global_rect().size.y >= 48.0, "visible tray %s action has actual 48x48 target" % action_name)
					_assert(tray_card_rect.encloses(tray_action.get_global_rect()), "visible tray %s action remains within its card" % action_name)
			var stable_id := StringName(tray_card.get_meta("stable_alert_id", &""))
			var semantic_alert: CombatAlertProjection
			for candidate: CombatAlertProjection in (hud.get("current_projection") as CombatHudProjection).all_alerts:
				if candidate.stable_id == stable_id:
					semantic_alert = candidate
					break
			_assert(semantic_alert != null and semantic_alert.summary in tray_card.accessibility_name, "scaled tray preserves exact alert accessibility semantics")
		tray.close()
	var leader_member_id := int(leader.get_meta("member_id", 0))
	_assert(bool(hud.call("open_inspector_for_member", leader_member_id, leader)), "inspector opens for modal geometry verification")
	await process_frame
	var inspector := hud.get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel
	_assert((inspector.get_node("Overlay") as Control).theme == LivingForgeThemeCatalog.resolve(fixture.settings.high_contrast, fixture.settings.ui_scale_percent, fixture.settings.text_scale_percent), "member inspector inherits the resolved high-contrast scaled theme")
	_assert_contained(inspector.get_node("Overlay/Frame") as Control, viewport_rect, "member inspector frame")
	_assert((inspector.get_node("Overlay/Frame") as Control).get_global_rect().encloses((inspector.get_node("Overlay/Frame/Layout") as Control).get_global_rect()), "member inspector frame contains enlarged child content")
	_assert("Read only" in (inspector.get_node("Overlay") as Control).accessibility_description and "health" in (inspector.get_node("Overlay") as Control).accessibility_description, "scaled inspector preserves read-only numeric-health semantics")
	inspector.close()
	var enemy := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as EnemyActor
	enemy.configure(load("res://data/enemies/swarmer.tres") as EnemyDefinition)
	hud.set_boss(enemy)
	await process_frame
	var boss_region := hud.get_node("Margin/CombatStatus/BossRegion") as Control
	_assert(boss_region.visible, "boss band appears as one supported region")
	_assert_contained(boss_region, Rect2(Vector2.ZERO, Vector2(viewport_size)), "boss band")
	hud.show_boss_banner()
	hud.show_loot_status("Rare item collected")
	await process_frame
	var banner := hud.get_node("BossBanner") as Control
	var loot := hud.get_node("LootStatus") as Control
	_assert_contained(banner, Rect2(Vector2.ZERO, Vector2(viewport_size)), "boss banner")
	_assert_contained(loot, Rect2(Vector2.ZERO, Vector2(viewport_size)), "loot status")
	_assert(not banner.get_global_rect().intersection(leader.get_global_rect()).has_area(), "boss banner does not collide with leader banner=%s leader=%s viewport=%s party=%d" % [banner.get_global_rect(), leader.get_global_rect(), viewport_size, count])
	_assert(not loot.get_global_rect().intersection(party_region.get_global_rect()).has_area(), "loot status does not collide with party region")
	_assert(not banner.get_global_rect().intersection(alerts.get_global_rect()).has_area(), "boss banner does not collide with alert region")
	_assert(not loot.get_global_rect().intersection(alerts.get_global_rect()).has_area(), "loot status does not collide with alert region")
	hud.set_boss(null)
	_assert(not boss_region.visible, "absent boss hides the whole band")
	enemy.free()
	viewport.free()
	_cleanup_fixture(fixture)


func _fixture(count: int) -> Dictionary:
	_sequence += 1
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(count))
	party.configure_identity(_sequence, catalog.generic_name_pool)
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for _index: int in range(count - 1):
		assert(party.recruit(catalog.class_by_id(&"fighter")))
	var context := PlayerRunContext.new()
	assert(context.configure(StringName("hud-scale-%d" % _sequence), 0, ProfileState.new_profile("hud-scale-profile-%d" % _sequence, "HUD Scale", 1000), _sequence, party, 100).is_empty())
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
		assert(context.bind_actor(member_id, actor))
		actors.append(actor)
		health_by_member[member_id] = health
	return {"party": party, "context": context, "experience": experience, "actors": actors, "health_by_member": health_by_member, "run": TestRun.new(), "settings": PartyForgeSettings.new()}


func _roster_controls(hud: HUD) -> Array[Control]:
	var result: Array[Control] = []
	for node: Node in hud.get_tree().get_nodes_in_group(&"combat_hud_member"):
		if node is Control and hud.is_ancestor_of(node):
			result.append(node as Control)
	return result


func _roster_member_ids(hud: HUD) -> Array[int]:
	var result: Array[int] = []
	for control: Control in _roster_controls(hud):
		result.append(int(control.get_meta("member_id", 0)))
	return result


func _assert_contained(control: Control, outer: Rect2, label: String) -> void:
	var rect := control.get_global_rect()
	_assert(rect.size.x > 0.0 and rect.size.y > 0.0, "%s has positive geometry" % label)
	_assert(outer.encloses(rect), "%s remains viewport bounded: %s" % [label, rect])


func _assert_leader_contents_contained(leader: Control, viewport_size: Vector2i, ui_scale: int, text_scale: int) -> void:
	var padded_card := leader.get_global_rect().grow(-8.0)
	var visible_content_paths: Array[NodePath] = [
		NodePath("Surface/Content"),
		NodePath("Surface/Content/Identity/Name"),
		NodePath("Surface/Content/Identity/Class"),
		NodePath("Surface/Content/Meta"),
		NodePath("Surface/Content/Health/Bar"),
		NodePath("Surface/Content/Health/Value"),
		NodePath("Surface/Content/StateCue/StateShape"),
		NodePath("Surface/Content/StateCue/StateIcon"),
		NodePath("Surface/Content/StateCue/StateText"),
		NodePath("Surface/LeaderCue/Icon"),
		NodePath("Surface/LeaderCue/Text"),
	]
	for path: NodePath in visible_content_paths:
		var content := leader.get_node(path) as Control
		if not content.is_visible_in_tree():
			continue
		_assert(
			padded_card.encloses(content.get_global_rect()),
			"leader %s stays inside its card with 8px padding at %s ui=%d text=%d card=%s content=%s" % [path, viewport_size, ui_scale, text_scale, padded_card, content.get_global_rect()],
		)


func _assert_leader_font_scale(leader: Control, viewport_size: Vector2i, ui_scale: int, text_scale: int) -> void:
	if viewport_size != Vector2i(1280, 720):
		return
	for path: NodePath in LEADER_TEXT_PATHS:
		var label := leader.get_node(path) as Label
		if not label.is_visible_in_tree():
			continue
		var effective_size := label.get_theme_font_size(&"font_size")
		var key := String(path)
		if text_scale == 100:
			_leader_text100_font_sizes[key] = effective_size
			continue
		if text_scale != 150:
			continue
		var text100_size := int(_leader_text100_font_sizes.get(key, 0))
		_assert(text100_size > 0, "leader %s has a captured Text100 font baseline" % path)
		var expected_scaled_size := maxi(roundi(float(text100_size) * float(text_scale) / 100.0), READABLE_FONT_FLOOR)
		_assert(
			effective_size >= expected_scaled_size,
			"leader %s Text150 preserves the expected theme scale at ui=%d baseline=%d expected=%d actual=%d" % [path, ui_scale, text100_size, expected_scaled_size, effective_size],
		)


func _cleanup_fixture(fixture: Dictionary) -> void:
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


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("COMBAT_HUD_PARTY_SCALE_FAILURE: %s" % failure)
	print("COMBAT_HUD_PARTY_SCALE_SUMMARY: FAIL failures=%d" % _failures.size())
	quit(1)
